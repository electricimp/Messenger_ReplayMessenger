// MIT License
//
// Copyright 2019 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


// Default configuration values
// If the queue of messages waiting for acknowledgment exceeds this limit, re-sending (replaying) will be postponed
const RM_DEFAULT_RESEND_LIMIT  = 20;

// Other configuration values
// If the current send rate exceeds this threshold (in percentages), re-sending (replaying) will be postponed
const RM_RESEND_RATE_LIMIT_PCT = 50;

// Importance constants
const RM_IMPORTANCE_HIGH       = 1;
const RM_IMPORTANCE_CRITICAL   = 2;

// Error messages
const RM_ERR_OUT_OF_MEMORY     = "Message has been erased. No free space on flash";
const RM_ERR_NOT_CONFIRMED     = "Resending has not been confirmed by the application";


class ReplayMessenger extends Messenger {

    // Generic handler to be called when a message is being "replayed" from the flash memory
    _confirmResend = null;

    // ConnectionManager instance
    _cm = null;

    // SpiFlashLogger instance
    _spiFL = null;

    // Characteristics of the flash logger
    _flDimensions = null;
    _flSectorSize = null;

    // The number of messages in _sentQueue when we already can't re-send more of persisted messages because we don't
    // want to flood _sentQueue with messages from flash memory - we want to send them step-by-step
    _resendLimit = null;

    // Message send rate (messages per second) when we already can't re-send more of persisted messages
    // so that we don't restrict the application from sending new messages
    _maxResendRate = null;

    // Flag which indicates if persisted messages are being read (asynchronously)
    _readingInProcess = false;

    // Queue of the messages to persist
    // We need this queue for the cases when the next sector must be cleaned up before new messages can be persisted
    _persistMessagesQueue = null;

    // Queue of the messages to erase
    // We need this queue for the cases when there are messages that should be erased but
    // they can't because of going-on async reading
    _eraseQueue = null;

    // Flag which indicates if cleanup of the next sector is needed in order to persist new messages
    _cleanupNeeded = null;

    /**
    * ReplayMessenger constructor.
    *
    * @constructor
    * @param {SPIFlashLogger} spiFlashLogger - Instance of spiFlashLogger which will be used to store messages.
    * @param {ConnectionManager} cm - Instance of ConnectionManager which will be used to check the connection state.
    * @param {table} [options] - Key-value table with optional settings.
    *
    * @return {ReplayMessenger} ReplayMessenger instance created.
    */
    constructor(spiFlashLogger, cm, options = {}) {
        // These constants are used during converting a message into a table before persisting
        // We should keep them short to minimize the footprint
        const RM_COMPRESSED_MSG_PAYLOAD     = "p";
        const RM_COMPRESSED_MSG_IMPTC       = "i";
        const RM_COMPRESSED_MSG_METADATA    = "md";
        const RM_COMPRESSED_MSG_ACK_TIMEOUT = "at";

        const RM_CM_ONCONNECT_CB_ID = "RM_ONCONNECT_CB_ID";

        base.constructor(options);

        _spiFL = spiFlashLogger;
        local spiFLVersion = split(_spiFL.VERSION, ".");
        if (spiFLVersion[0].tointeger() < 2 || spiFLVersion[1].tointeger() < 2) {
            throw "ReplayMessenger requires spiFlashLogger version to be not less than v2.2.0";
        }

        _cm = cm;
        local cmVersion = split(_cm.VERSION, ".");
        if (cmVersion[0].tointeger() < 3 || cmVersion[1].tointeger() < 1) {
            throw "ReplayMessenger requires ConnectionManager version to be not less than v3.1.0";
        }

        if (!("firstMsgId" in options)) {
            // Find the maximum message Id on the flash and use it to initialize the Id generator
            // so that our next messages will not interfere (by Id) with pending ones from the flash memory
            try {
                _nextId = _maxMsgId() + 1;
            } catch (e) {
                throw "An error occurred during reading contents from the flash memory. " +
                    "There may be some incompatible data. You probably need to erase it.";
            }
        }

        _resendLimit = "resendLimit" in options ? options["resendLimit"] : RM_DEFAULT_RESEND_LIMIT;
        _maxResendRate = _maxRate * RM_RESEND_RATE_LIMIT_PCT / 100;

        _flDimensions = _spiFL.dimensions();
        _flSectorSize = _flDimensions["sector_size"];

        _persistMessagesQueue = [];
        _eraseQueue = {};

        // Process the pending persisted messages if there are any
        _setTimer();

        _cm.onConnect(_processPersistedMessages.bindenv(this), RM_CM_ONCONNECT_CB_ID);
    }

    /**
    * Sends a named message.
    *
    * @param {string} name - Name of the message to be sent.
    * @param {any serializable type} [data] - Data to be sent.
    * @param {integer} [importance=RM_IMPORTANCE_LOW] - Importance of the message.
    * @param {integer} [ackTimeout] - Individual message timeout.
    * @param {any serializable type} [metadata] - Message metadata.
    *
    * @return {Message} The message object created
    */
    function send(name, data = null, importance = RM_IMPORTANCE_LOW, ackTimeout = null, metadata = null) {
        local msg = Message(_getNextId(), name, data, importance, ackTimeout, metadata);
        _send(msg);
        return msg;
    }

    /**
    * The handler to be called when ReplayMessenger is replaying a persisted message.
    *
    * @callback confirmResendCallback
    * @param {Message} msg - The message (an instance of class Message) being replayed
    *
    * @return {boolean} - `true` to confirm message resending or `false` to drop the message
    */
    /**
    * Sets the handler to be called when ReplayMessenger is replaying a persisted message.
    *
    * @param {confirmResendCallback} confirmResendCallback - The handler.
    *   It should return `true` to confirm message resending or `false` to drop the message.
    */
    function confirmResend(confirmResendCallback) {
        _confirmResend = confirmResendCallback;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // Sends the message (and immediately persists it if needed) and restarts the timer for processing the queues
    function _send(msg) {
        // Check if the message has importance = RM_IMPORTANCE_CRITICAL and not yet persisted
        if (msg._importance == RM_IMPORTANCE_CRITICAL && !_isMsgPersisted(msg)) {
            _persistMessage(msg);
        }

        base._send(msg);
    }

    // The handler for message acknowledgement
    function _onAckReceived(payload) {
        local id = payload.id;

        _log("Ack received. Msg id: " + id);

        if (id in _sentQueue) {
            local msg = _sentQueue[id];

            // If the message is persisted, erase it from the flash
            if (_isMsgPersisted(msg)) {
                _safeEraseMsg(id, msg);
            } else if (msg._importance >= RM_IMPORTANCE_HIGH) {
                // The message can also be in _persistMessagesQueue.
                // If so, we should remove it from there
                foreach (idx, msgToPersist in _persistMessagesQueue) {
                    if (msgToPersist.payload.id == id) {
                        _persistMessagesQueue.remove(idx);
                    }
                }
            }

            delete _sentQueue[id];

            // Check if there is some data sent along with the acknowledgement
            local data = null;
            if ("data" in payload) {
                data = payload.data;
            }

            // Call the handler if set
            if (_isFunction(_onAck)) {
                _onAck(msg, data);
            }
        }
    }

    // Calls the error handler if set for the message with the specified error
    function _onSendFail(msg, error) {
        local id = msg.payload.id;
        _log("Failed to send or haven't received Ack. Id: " + id + " Reason: " + error);

        // If importance is RM_IMPORTANCE_HIGH, persist the message if not yet
        if (msg._importance == RM_IMPORTANCE_HIGH && !_isMsgPersisted(msg)) {
            _persistMessage(msg);
        }

        if (id in _sentQueue) {
            delete _sentQueue[id];
        }

        // Call onFail if message importance is RM_IMPORTANCE_LOW
        if (msg._importance == RM_IMPORTANCE_LOW) {
            if (_isFunction(_onFail)) {
                _onFail(msg, error);
            }
        }
    }

    // Processes both _sentQueue and the messages persisted on the flash
    function _processQueues() {
        // Clean up the timer
        _queueTimer = null;

        local now = time();

        // Call onFail for timed out messages
        foreach (id, msg in _sentQueue) {
            local ackTimeout = msg._ackTimeout ? msg._ackTimeout : _ackTimeout;
            if (now - msg._sentTime >= ackTimeout) {
                _onSendFail(msg, MSGR_ERR_ACK_TIMEOUT);
            }
        }

        _processPersistedMessages();

        // Restart the timer if there is something pending
        if (!_isAllProcessed()) {
            _setTimer();
        }
    }

    // Persists the message if there is enough space in the current sector.
    // If not, adds the message to the _persistMessagesQueue queue (if `enqueue` is `true`).
    // Returns true if the message has been persisted, otherwise false
    function _persistMessage(msg, enqueue = true) {
        if (_cleanupNeeded) {
            if (enqueue) {
                _log("Message added to the queue to be persisted later. Id: " + msg.payload.id);
                _persistMessagesQueue.push(msg);
            }
            return false;
        }

        local payload = _prepareMsgToPersist(msg);

        if (_isEnoughSpace(payload)) {
            msg._address = _spiFL.getPosition();
            _spiFL.write(payload);
            _log("Message persisted. Id: " + msg.payload.id);
            return true;
        } else {
            _log("Need to clean up the next sector");
            _cleanupNeeded = true;
            if (enqueue) {
                _log("Message added to the queue to be persisted later. Id: " + msg.payload.id);
                _persistMessagesQueue.push(msg);
            }
            _processPersistedMessages();
            return false;
        }
    }

    // Processes _persistMessagesQueue while there is enough space in the current sector
    function _processPersistMessagesQueue() {
        while (_persistMessagesQueue.len() > 0) {
            local msg = _persistMessagesQueue[0];
            if (_persistMessage(msg, false)) {
                // The message has been persisted successfully
                _persistMessagesQueue.remove(0);
            } else {
                // The message hasn't been persisted. Stop this process
                return;
            }
        }
    }

    // Processes the messages persisted on the flash
    function _processPersistedMessages() {
        if (_readingInProcess) {
            return;
        }

        local sectorToCleanup = null;

        if (_cleanupNeeded) {
            sectorToCleanup = (_spiFL.getPosition() / _flSectorSize + 1) * _flSectorSize;

            if (sectorToCleanup == _flDimensions["end"]) {
                sectorToCleanup = _flDimensions["start"];
            }
        } else if (!_cm.isConnected() || !_checkResendLimits()) {
            return;
        }

        local onData = function(messagePayload, address, next) {
            // Create a message from payload and call onFail
            local msg = _messageFromFlash(messagePayload, address);
            local id = msg.payload.id;

            local needNextMsg = _cleanupPersistedMsg(sectorToCleanup, address, id, msg) ||
                                _resendPersistedMsg(address, id, msg);

            next(needNextMsg);
        }.bindenv(this);

        local onFinish = function() {
            _log("Processing persisted messages: finished");
            if (sectorToCleanup != null) {
                _onCleanupDone();
            }
            _onReadingFinished();
        }.bindenv(this);

        _log("Processing persisted messages...");
        _readingInProcess = true;
        _spiFL.read(onData, onFinish);
    }

    // If the address is in the sector we need to clean up, erases the message and calls the onFail handler
    // Returns true, if erasing has been done and the next message should be handled
    function _cleanupPersistedMsg(sectorToCleanup, address, id, msg) {
        if (sectorToCleanup != null) {
            // The beginning of the buffer can be located either at the first sector or
            // at the next sector after the current position of the buffer since we are
            // working with log-structured buffer.
            // We start reading from the oldest record (the beginning of the buffer).
            // So if we have any alive records in the next sector, we should get them earlier than the others.
            // Therefore we can consider the next sector cleaned up once we get any record which is out of the next sector.
            if (address >= sectorToCleanup &&
                address < sectorToCleanup + _flSectorSize) {
                if (id in _sentQueue) {
                    delete _sentQueue[id];
                }
                if (id in _eraseQueue) {
                    delete _eraseQueue[id];
                }

                _log("Sector cleanup: message erased. Id: " + id);
                _spiFL.erase(address);
                msg._address = null;

                if (_isFunction(_onFail)) {
                    _onFail(msg, RM_ERR_OUT_OF_MEMORY);
                }

                return true;
            }
        }

        return false;
    }

    // Tries to resend the message if possible and needed. If resending is not confirmed, erases the message
    // Returns true if the resending was possible and the next message should be handled
    function _resendPersistedMsg(address, id, msg) {
        if (!_cm.isConnected() || !_checkResendLimits()) {
            return false;
        }

        if (id in _sentQueue || id in _eraseQueue) {
            // This message has either already been sent and is waiting for an acknowledgment
            // or been picked to erase
            return true;
        }

        if (_isFunction(_confirmResend) && _confirmResend(msg)) {
            // Resending confirmed
            _send(msg);
        } else {
            // Resending not confirmed. Erase the message and call the onFail handler
            _log("Resending not confirmed. Message erased. Id: " + id);
            _spiFL.erase(address);
            msg._address = null;

            if (_isFunction(_onFail)) {
                _onFail(msg, RM_ERR_NOT_CONFIRMED);
            }
        }

        return true;
    }

    // Callback called when the next sector has been cleaned up and ready to be filled with new data
    function _onCleanupDone() {
        _log("Cleaned up the next sector");
        _cleanupNeeded = false;
        _processPersistMessagesQueue();
    }

    // Callback called when async reading (in the _processPersistedMessages method) is finished
    function _onReadingFinished() {
        _readingInProcess = false;

        // Process the queue of messages to be erased
        if (_eraseQueue.len() > 0) {
            _log("Processing the queue of messages to be erased...");
            foreach (id, address in _eraseQueue) {
                _log("Message erased. Id: " + id);
                _spiFL.erase(address);
            }
            _eraseQueue = {};
            _log("Processing the queue of messages to be erased: finished");
        }

        if (_cleanupNeeded) {
            // Restart the processing in order to cleanup the next sector
            _processPersistedMessages();
        }
    }

    // Returns true if resend limits are not exceeded, otherwise false
    function _checkResendLimits() {
        local now = _monotonicMillis();
        if (now - 1000 > _lastRateMeasured || now < _lastRateMeasured) {
            // Reset the counters if the timer's overflowed or
            // more than a second passed from the last measurement
            _rateCounter = 0;
            _lastRateMeasured = now;
        } else if (_rateCounter >= _maxResendRate) {
            // Rate limit exceeded
            _log("Resend rate limit exceeded");
            return false;
        }

        if (_sentQueue.len() >= _resendLimit) {
            _log("Resend queue size limit exceeded");
            return false;
        }

        return true;
    }

    // Returns true if there is enough space in the current flash sector to persist the payload
    function _isEnoughSpace(payload) {
        local nextSector = (_spiFL.getPosition() / _flSectorSize + 1) * _flSectorSize;
        // NOTE: We need to access a private field for optimization
        // Correct work is guaranteed with "SPIFlashLogger.device.lib.nut:2.2.0"
        local payloadSize = _spiFL._serializer.sizeof(payload, SPIFLASHLOGGER_OBJECT_MARKER);

        if (_spiFL.getPosition() + payloadSize <= nextSector) {
            return true;
        } else {
            if (nextSector == _flDimensions["end"]) {
                nextSector = _flDimensions["start"];
            }

            local nextSectorIdx = nextSector / _flSectorSize;
            // NOTE: We need to call a private method for optimization
            // Correct work is guaranteed with "SPIFlashLogger.device.lib.nut:2.2.0"
            local objectsStartCodes = _spiFL._getObjectsStartCodesForSector(nextSectorIdx);
            local nextSectorIsEmpty = objectsStartCodes == null || objectsStartCodes.len() == 0;
            return nextSectorIsEmpty;
        }
    }

    // Erases the message if no async reading is ongoing, otherwise puts it into the queue to erase later
    function _safeEraseMsg(id, msg) {
        if (!_readingInProcess) {
            _log("Message erased. Id: " + id);
            _spiFL.erase(msg._address);
        } else {
            _log("Message added to the queue to be erased later. Id: " + id);
            _eraseQueue[id] <- msg._address;
        }
        msg._address = null;
    }

    // Prepares the message for persisting (creates a payload)
    function _prepareMsgToPersist(msg) {
        local payload = {};
        payload[RM_COMPRESSED_MSG_PAYLOAD] <- msg.payload;
        // We consider RM_IMPORTANCE_HIGH as the default importance.
        // And we can omit it here for memory space economy
        if (msg._importance != RM_IMPORTANCE_HIGH) {
            payload[RM_COMPRESSED_MSG_IMPTC] <- msg._importance;
        }
        if (msg.metadata != null) {
            payload[RM_COMPRESSED_MSG_METADATA] <- msg.metadata;
        }
        // There is no sense to add the ack timeout to the table if it is equal to the default one
        if (msg._ackTimeout != _ackTimeout) {
            payload[RM_COMPRESSED_MSG_ACK_TIMEOUT] <- msg._ackTimeout;
        }
        return payload;
    }

    // Constructs a message from the payload which has been read from the flash memory
    function _messageFromFlash(payload, address) {
        local id = payload[RM_COMPRESSED_MSG_PAYLOAD]["id"];
        local name = payload[RM_COMPRESSED_MSG_PAYLOAD]["name"];
        local data = payload[RM_COMPRESSED_MSG_PAYLOAD]["data"];
        local importance = RM_COMPRESSED_MSG_IMPTC in payload ? payload[RM_COMPRESSED_MSG_IMPTC] : RM_IMPORTANCE_HIGH;
        local ackTimeout = RM_COMPRESSED_MSG_ACK_TIMEOUT in payload ? payload[RM_COMPRESSED_MSG_ACK_TIMEOUT] : _ackTimeout;
        local metadata = RM_COMPRESSED_MSG_METADATA in payload ? payload[RM_COMPRESSED_MSG_METADATA] : null;
        return Message(id, name, data, importance, ackTimeout, metadata, address);
    }

    // Returns true is the message is persisted
    function _isMsgPersisted(msg) {
        return msg._address != null;
    }

    // Finds the greatest message Id on the flash. If no messages, returns -1
    function _maxMsgId() {
        local maxId = -1;
        local index = 1;
        local payload = null;

        while (payload = _spiFL.readSync(index++)) {
            local id = payload[RM_COMPRESSED_MSG_PAYLOAD]["id"];
            maxId = id > maxId ? id : maxId;
        }

        return maxId;
    }

    // Returns true if there are no messages to process (_sentQueue is empty and there are no persisted messages)
    function _isAllProcessed() {
        if (_sentQueue.len() != 0) {
            return false;
        }
        // We can't process persisted messages is we are offline
        return !_cm.isConnected() || _spiFL.readSync(1) == null;
    }

    function _typeof() {
        return "ReplayMessenger";
    }
}
