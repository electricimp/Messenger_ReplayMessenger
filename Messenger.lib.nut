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
const MSGR_DEFAULT_DEBUG              = 0;
const MSGR_DEFAULT_ACK_TIMEOUT_SEC    = 10.0;
const MSGR_DEFAULT_FIRST_MESSAGE_ID   = 0;
// Maximum number of messages to be sent per second
const MSGR_DEFAULT_MAX_MESSAGE_RATE   = 10;

// Other configuration constants
const MSGR_QUEUE_CHECK_INTERVAL_SEC   = 0.5;
// Importance level used for ReplayMessanger functionality, 
// so keep RM_ preface so all importance constants match
const RM_IMPORTANCE_LOW               = 0;

// Message types
const MSGR_MESSAGE_TYPE_ACK           = "RM_ACK";
const MSGR_MESSAGE_TYPE_DATA          = "RM_DATA";

// Error messages
const MSGR_ERR_NO_CONNECTION          = "No connection";
const MSGR_ERR_ACK_TIMEOUT            = "Ack timeout";
const MSGR_ERR_RATE_LIMIT_EXCEEDED    = "Maximum sending rate exceeded";

class Messenger {

    static VERSION = "0.1.0";

    _debug = false;

    // The device or agent object
    _partner = null;

    // Acknowledgement timeout (sec)
    _ackTimeout = null;

    // Queue of the messages pending for acknowledgement
    _sentQueue = null;

    // Next message id
    _nextId = null;

    // Timer for processing pending messages
    _queueTimer = null;

    //--------Handlers--------//

    // Table of name-specific handlers to be called upon receiving a message
    _on = null;

    // Generic handler to be called upon receiving a message without a name-specific handler
    _defaultOn = null;

    // Generic handler to be called when a message is acknowledged
    _onAck = null;

    // Generic handler to be called when a message delivery failed
    _onFail = null;

    //--------Rate measurement variables--------//

    // Maximum message send rate (messages per second)
    _maxRate = null;

    // Counter of sent messages for rate measurement
    _rateCounter = null;

    // Last time (msec) the message send rate was measured
    _lastRateMeasured = null;

    // This class defines the message structure
    Message = class {
        // Message metadata, that can be used for application specific purposes
        metadata = null;

        // Message payload to be sent
        payload = null;

        // Message importance
        _importance = null;

        // Timestamp when the message was sent
        _sentTime = null;

        // Individual message timeout
        _ackTimeout = null;

        // The address of this message on flash memory (if persisted)
        _address = null;

        /**
        * Message constructor
        * Constructor is not going to be called from the application code
        *
        * @constructor
        * @param {integer} id - Message unique identifier.
        * @param {string} name - Message name.
        * @param {any serializable type} data - Message data.
        * @param {integer} importance - Message importance.
        * @param {integer} ackTimeout - Individual message timeout.
        * @param {any serializable type} metadata - Message metadata.
        * @param {integer} [address] - Address of this message on flash memory (if persisted).
        *
        * @return {Message} Message object created
        */
        constructor(id, name, data, importance, ackTimeout, metadata, address = null) {
            payload = {
                "id"  : id,
                "type": MSGR_MESSAGE_TYPE_DATA,
                "name": name,
                "data": data
            };
            this.metadata = metadata;
            this._importance = importance;
            this._ackTimeout = ackTimeout;
            this._address = address;
        }

        function _typeof() {
            return "A Messenger Message";
        }
    }

    /**
    * Messenger constructor.
    *
    * @constructor
    * @param {table} [options] - Key-value table with optional settings.
    *
    * @return {Messenger} Messenger instance created.
    */
    constructor(options = {}) {
        // Read configuration
        _debug      = "debug"       in options ? options["debug"]       : MSGR_DEFAULT_DEBUG;
        _ackTimeout = "ackTimeout"  in options ? options["ackTimeout"]  : MSGR_DEFAULT_ACK_TIMEOUT_SEC;
        _nextId     = "firstMsgId"  in options ? options["firstMsgId"]  : MSGR_DEFAULT_FIRST_MESSAGE_ID;
        _maxRate    = "maxRate"     in options ? options["maxRate"]     : MSGR_DEFAULT_MAX_MESSAGE_RATE;

        // Partner initialization
        _partner = _isAgent() ? device : agent;
        _partner.on(MSGR_MESSAGE_TYPE_ACK, _onAckReceived.bindenv(this));
        _partner.on(MSGR_MESSAGE_TYPE_DATA, _onDataReceived.bindenv(this));

        _sentQueue  = {};
        _rateCounter = 0;
        _lastRateMeasured = 0;
        _on = {};
    }

    /**
    * Sends a named message.
    *
    * @param {string} name - Name of the message to be sent.
    * @param {any serializable type} [data] - Data to be sent.
    * @param {integer} [ackTimeout] - Individual message timeout.
    * @param {any serializable type} [metadata] - Message metadata.
    *
    * @return {Message}  The message object created
    */
    function send(name, data = null, ackTimeout = null, metadata = null) {
        local msg = Message(_getNextId(), name, data, RM_IMPORTANCE_LOW, ackTimeout, metadata);
        _send(msg);
        return msg;
    }

    /**
    * Sends manual acknowledgement with optional data.
    *
    * @function ack
    *
    * @param {*} [data] - Data to send in the acknowledgment.
    */
    /**
    * Cancels the automatic acknowledgement.
    *
    * @function customAck
    *
    * @return {ack} The function that can be called to send manual acknowledgement with optional data.
    */
    /**
    * The handler to be called when a message received.
    *
    * @callback onMsg
    * @param {table} msg - Payload of the message received.
    * @param {customAck} customAck - The function that can be called to cancel the automatic acknowledgement.
    */
    /**
    * Sets the name-specific message callback which will be called when a message with this name is received.
    *
    * @param {string} name - The name of messages this callback will be used for or `null` to register as the default handler.
    * @param {onMsg} onMsg - The handler.
    */
    function on(name, onMsg) {
        if (name != null) {
            // Set name-specific handler
            _on[name] <- onMsg;
        } else {
            // Set generic handler
            _defaultOn = onMsg;
        }
    }

    /**
    * Sends manual acknowledgement with optional data.
    *
    * @function ack
    *
    * @param {*} [data] - Data to send in the acknowledgment.
    */
    /**
    * Cancels the automatic acknowledgement.
    *
    * @function customAck
    *
    * @return {ack} The function that can be called to send manual acknowledgement with optional data.
    */
    /**
    * The default handler to be called when a message is received.
    *
    * @callback defaultOnMsg
    * @param {table} msg - Payload of the message received.
    * @param {customAck} customAck - The function that can be called to cancel the automatic acknowledgement.
    */
    /**
    * Sets the default handler which will be called when a message doesn't match any of the name-specific handlers.
    *
    * @param {defaultOnMsg} defaultOnMsg - The handler.
    */
    function defaultOn(defaultOnMsg) {
        on(null, defaultOnMsg);
    }

    /**
    * The handler to be called when a message is acknowledged.
    *
    * @callback onAckCallback
    * @param {Message} msg - The message (an instance of class Message) that has been acknowledged.
    * @param {*} data - Optional data sent along with the acknowledgment.
    */
    /**
    * Sets the handler to be called when a message is acknowledged.
    *
    * @param {onAckCallback} onAckCallback - The handler.
    */
    function onAck(onAckCallback) {
        _onAck = onAckCallback;
    }

    /**
    * The handler to be called when a message sending is failed.
    *
    * @callback onFailCallback
    * @param {Message} msg - The message (an instance of class Message) that has been failed.
    * @param {string} reason - The string with the error description.
    */
    /**
    * Sets the handler to be called when a message is failed.
    *
    * @param {onFailCallback} onFailCallback - The handler.
    */
    function onFail(onFailCallback) {
        _onFail = onFailCallback;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // Sends the message and restarts the timer for processing the queues
    function _send(msg) {
        local id = msg.payload.id;
        _log("Trying to send msg. Id: " + id);

        local now = _monotonicMillis();
        if (now - 1000 > _lastRateMeasured || now < _lastRateMeasured) {
            // Reset the counters if the timer's overflowed or
            // more than a second passed from the last measurement
            _rateCounter = 0;
            _lastRateMeasured = now;
        } else if (_rateCounter >= _maxRate) {
            // Rate limit exceeded, raise an error
            _onSendFail(msg, MSGR_ERR_RATE_LIMIT_EXCEEDED);
            return;
        }

        // Try to send
        local payload = msg.payload;
        if (!_partner.send(MSGR_MESSAGE_TYPE_DATA, payload)) {
            // Send complete
            _log("Sent. Id: " + id);

            _rateCounter++;
            // Set sent time, update sentQueue and restart timer
            msg._sentTime = time();
            _sentQueue[id] <- msg;
            _setTimer();
        } else {
            // Sending failed
            _onSendFail(msg, MSGR_ERR_NO_CONNECTION);
        }
    }

    // The handler for message acknowledgement
    function _onAckReceived(payload) {
        local id = payload.id;

        _log("Ack received. Msg id: " + id);

        if (id in _sentQueue) {
            local msg = _sentQueue[id];

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

    // The handler for data messages
    function _onDataReceived(payload) {
        local id = payload["id"];

        _log("Get user message. Id: " + id);

        local name = payload["name"];
        local data = payload["data"];
        local customAckFlag = false;
        local handler = name in _on && _isFunction(_on[name]) ? _on[name] : _defaultOn;

        local error = null;

        // Delete the internal data
        delete payload["type"];

        // Call the message handler
        if (_isFunction(handler)) {
            // Function for manual/custom acknowledgment sending.
            // Optionally called by the application
            local customAck = function() {
                // User chose manual/custom acknowledgment
                customAckFlag = true;

                // Function to send custom acknowledgment with optional data.
                // Optionally called by the application
                local ack = function(data = null) {
                    error = _partner.send(MSGR_MESSAGE_TYPE_ACK, {
                        "id" : id,
                        "data" : data
                    });
                }.bindenv(this);

                return ack;
            }.bindenv(this);

            handler(payload, customAck);
            if (!customAckFlag) {
                // The application hasn't called customAck().
                // Send acknowledgment automatically
                error = _partner.send(MSGR_MESSAGE_TYPE_ACK, {
                    "id" : id
                });
            }
        } else {
            // No valid handler
            _log("No valid handler. Id: " + id);
        }

        if (error) {
            _log("Ack failed. Id: " + id);
        }
    }

    // Calls the error handler if set for the message with the specified error
    function _onSendFail(msg, error) {
        local id = msg.payload.id;
        _log("Failed to send or haven't received Ack. Id: " + id + " Reason: " + error);

        if (id in _sentQueue) {
            delete _sentQueue[id];
        }

        if (_isFunction(_onFail)) {
            _onFail(msg, error);
        }
    }

    // Processes _sentQueue
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

        // Restart the timer if there is something pending
        if (!_isAllProcessed()) {
            _setTimer();
        }
    }

    // Incremental message id generator
    function _getNextId() {
        _nextId %= RAND_MAX;
        return _nextId++;
    }

    // Returns true if there are no messages to process (_sentQueue is empty)
    function _isAllProcessed() {
        return _sentQueue.len() == 0;
    }

    // Returns true if we are on the agent
    function _isAgent() {
        return imp.environment() == ENVIRONMENT_AGENT;
    }

    // Sets a timer for processing queues
    function _setTimer() {
        if (_queueTimer) {
            // The timer is already running
            return;
        }
        _queueTimer = imp.wakeup(MSGR_QUEUE_CHECK_INTERVAL_SEC,
                                _processQueues.bindenv(this));
    }

    // Returns true if the argument is a function and false otherwise
    function _isFunction(f) {
        return f && typeof f == "function";
    }

    // Implements debug logging. Sends the log message to the console output if "debug" configuration flag is set
    function _log(message) {
        if (_debug) {
            server.log("[RM] " + message);
        }
    }

    // Returns the current value of the "monotonic" millisecond timer
    //
    // NOTE: the timer can overflow!!!
    // The primary purpose is rate measurements, where the above
    // limitation is not critical.
    function _monotonicMillis() {
        return _isAgent() ? time() * 1000 + date().usec / 1000 : hardware.millis();
    }

    function _typeof() {
        return "Messenger";
    }
}
