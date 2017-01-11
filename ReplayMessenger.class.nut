// Copyright (c) 2016-2017 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const REPLAY_MESSENGER_MESSAGE_TIMEOUT_SEC = 5;
const REPLAY_MESSENGER_RETRY_INTERVAL_SEC  = 0.5;

class ReplayMessenger {

    // MessageManager instance
    _mm = null;

    // ConnectionManager instance
    _cm = null;

    // SPIFlashLogger instance
    _spiFL = null;

    // Message retry timer
    _retryTimer = null;

    // Debug flag that controlls the debug output
    _debug = false;

    // Handler to be called when we get connected
    _onConnHandler = null;

    // Handler to be called when we get disconnected
    _onDiscHandler = null;

    // Retry interval
    _retryInterval = null;

    constructor(options = {}) {

        _cm            = "connectionManager" in options ? options["connectionManager"] : ConnectionManager();
        _mm            = "messageManager"    in options ? options["messageManager"]    : MessageManager({
            "messageTimeout"    : REPLAY_MESSENGER_MESSAGE_TIMEOUT_SEC,
            "connectionManager" : _cm
        });
        _spiFL         = "spiFlashLogger"    in options ? options["spiFlashLogger"]    : SPIFlashLogger();
        _retryInterval = "retryInterval"     in options ? options["retryInterval"]     : REPLAY_MESSENGER_RETRY_INTERVAL_SEC;
        _debug         = "debug"             in options ? options["debug"]             : debug;

        // Set MessageManager listeners
        _mm.onAck(_onAck.bindenv(this))
        _mm.onFail(_onFail.bindenv(this))

        // Set ConnectionManager listeners
        _cm.onConnect(_onConnect.bindenv(this));
        _cm.onDisconnect(_onDisconnect.bindenv(this));

        // Schedule routine to retry sending messages
        _scheduleRetryIfConnected();
    }

    function send(messageName, data = null, metadata = null) {
        return _mm.send(messageName, data, _retryInterval, metadata);
    }

    function onConnect(callback) {
        _onConnHandler = callback;
    }

    function onDisconnect(callback) {
        _onDiscHandler = callback;
    }

    function _onAck(message) {
        // Do nothing
        _log("ACKed message name: '" + message.payload.name + "', data: " + message.payload.data);
        if ("metadata" in message && "addr" in message.metadata && message.metadata.addr) {
            local addr = message.metadata.addr;
            _log("Erasing object at address: " + addr);
            _spiFL.erase(addr);
            message.metadata.addr = null;
            _scheduleRetryIfConnected();
        }
    }

    function _onFail(message, reason, retry) {
        local payload = message.payload
        _log("Failed to deliver message name: '" + payload.name + "', data: " + payload.data + ", error: " + reason);
        // On fail write the message to the SPI Flash for further processing
        // only if it's not already there.
        if (!("metadata" in message) || !("addr" in message.metadata) || !(message.metadata.addr)) {
            local savedMsg = {
                "name" : payload.name,
                "data" : payload.data
            }
            _spiFL.write(savedMsg);
        }
        _scheduleRetryIfConnected();
    }

    function _retry() {
        _log("Start processing pending messages...");
        _spiFL.read(
            function(savedMsg, addr, next) {
                _log("Reading from the SPI Flash. Data: " + savedMsg.data + " at addr: " + addr);

                // There's no point of retrying to send pending messages when disconnected
                if (!_cm.isConnected()) {
                    _log("No connection, abort SPI Flash scanning...");
                    // Abort scanning
                    next(false);
                    return;
                }
                _log("Resending message name: '" + savedMsg.name + "', data: " + savedMsg.data);
                send(savedMsg.name, savedMsg.data, {"addr" : addr});

                // Skip to next item
                next();
            }.bindenv(this),
            function() {
                _log("Finished processing all pending messages");
            }.bindenv(this)
        );
    }

    function _onConnect() {
        _log("onConnect: scheduling pending message processor...");
        _scheduleRetryIfConnected();

        if (_onConnHandler && typeof _onConnHandler == "function") {
            _onConnHandler();
        }
    }

    function _onDisconnect(expected) {
        _log("onDisconnect: cancelling pending message processor...");
        // Stop any attempts to process pending messages while we are disconnected
        _cancelRetryTimer();

        if (_onDiscHandler && typeof _onDiscHandler == "function") {
            _onDiscHandler(expected);
        }
    }

    function _cancelRetryTimer() {
        if (!_retryTimer) {
            return;
        }
        imp.cancelwakeup(_retryTimer);
        _retryTimer = null;
    }

    function _scheduleRetryIfConnected() {
        if (!_cm.isConnected()) {
            return;
        }

        _cancelRetryTimer();
        _retryTimer = imp.wakeup(_retryInterval, _retry.bindenv(this));
    }

    function _log(str) {
        if (_debug) {
            _cm.log("  [RM] " + str);
        }
    }
}