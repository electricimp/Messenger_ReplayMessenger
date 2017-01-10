// Copyright (c) 2016-2017 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const IMP_PAGER_MESSAGE_TIMEOUT         = 1;
const IMP_PAGER_RETRY_PERIOD_SEC        = 0.5;
const IMP_PAGER_CM_DEFAULT_SEND_TIMEOUT = 1;
const IMP_PAGER_CM_DEFAULT_BUFFER_SIZE  = 8096;

class ImpPager {

    // MessageManager instance
    _messageManager = null;

    // ConnectionManager instance
    _connectionManager = null;

    // SPIFlashLogger instance
    _spiFlashLogger = null;

    // Message retry timer
    _retryTimer = null;

    // Debug flag that controlls the debug output
    _debug = false;

    constructor(connectionManager, messageManager = null, spiFlashLogger = null, debug = false) {
        _connectionManager = connectionManager;

        _messageManager = messageManager ? messageManager : MessageManager({"messageTimeout" : IMP_PAGER_MESSAGE_TIMEOUT});
        _spiFlashLogger = spiFlashLogger ? spiFlashLogger : SPIFlashLogger();

        // Set MessageManager listeners
        _messageManager.onAck(_onAck.bindenv(this))
        _messageManager.onFail(_onFail.bindenv(this))

        // Set ConnectionManager listeners
        _connectionManager.onConnect(_onConnect.bindenv(this));
        _connectionManager.onDisconnect(_onDisconnect.bindenv(this));

        // Schedule routine to retry sending messages
        _scheduleRetryIfConnected();

        _debug = debug;
    }

    function send(messageName, data = null, metadata = null) {
        return _messageManager.send(messageName, data, IMP_PAGER_MESSAGE_TIMEOUT, metadata);
    }

    function _onAck(message) {
        // Do nothing
        _log_debug("ACKed message name: '" + message.payload.name + "', data: " + message.payload.data);
        if ("metadata" in message && "addr" in message.metadata && message.metadata.addr) {
            local addr = message.metadata.addr;
            _spiFlashLogger.erase(addr);
            message.metadata.addr = null;
            _scheduleRetryIfConnected();
        }
    }

    function _onFail(message, reason, retry) {
        _log_debug("Failed to deliver message name: '" + message.name + "', data: " + message.data + ", error: " + reason);
        // On fail write the message to the SPI Flash for further processing
        // only if it's not already there.
        if (!("metadata" in message) || !("addr" in message.metadata) || !(message.metadata.addr)) {
            local savedMsg = {
                "name" : payload.name,
                "data" : payload.data
            }
            _spiFlashLogger.write(savedMsg);
        }
        _scheduleRetryIfConnected();
    }

    function _retry() {
        _log_debug("Start processing pending messages...");
        _spiFlashLogger.read(
            function(savedMsg, addr, next) {
                _log_debug("Reading from the SPI Flash. Data: " + savedMsg.data + " at addr: " + addr);

                // There's no point of retrying to send pending messages when disconnected
                if (!_connectionManager.isConnected()) {
                    _log_debug("No connection, abort SPI Flash scanning...");
                    // Abort scanning
                    next(false);
                    return;
                }
                _log_debug("Resending message name: '" + savedMsg.name + "', data: " + savedMsg.data);
                send(savedMsg.name, savedMsg.data, {"addr" : addr});

                // Don't do any further scanning until we get an ACK for the already sent message
                next(false);
            }.bindenv(this),
            function() {
                _log_debug("Finished processing all pending messages");
            }.bindenv(this)
        );
    }

    function _onConnect() {
        _log_debug("onConnect: scheduling pending message processor...");
        _scheduleRetryIfConnected();
    }

    function _onDisconnect(expected) {
        _log_debug("onDisconnect: cancelling pending message processor...");
        // Stop any attempts to process pending messages while we are disconnected
        _cancelRetryTimer();
    }

    function _cancelRetryTimer() {
        if (!_retryTimer) {
            return;
        }
        imp.cancelwakeup(_retryTimer);
        _retryTimer = null;
    }

    function _scheduleRetryIfConnected() {
        if (!_connectionManager.isConnected()) {
            return;
        }

        _cancelRetryTimer();
        _retryTimer = imp.wakeup(IMP_PAGER_RETRY_PERIOD_SEC, _retry.bindenv(this));
    }

    function _log_debug(str) {
        if (_debug) {
            _connectionManager.log(str);
        }
    }
}

class ImpPager.ConnectionManager extends ConnectionManager {

    // Global list of handlers to be called when device gets connected
    _onConnectHandlers = array();

    // Global list of handlers to be called when device gets disconnected
    _onDisconnectHandlers = array();

    constructor(settings = {}) {
        base.constructor(settings);

        // Override the timeout to make it a nonzero, but still 
        // a small value. This is needed to avoid accedental 
        // imp disconnects when using ConnectionManager library
        local sendTimeout = "sendTimeout" in settings ? 
            settings.sendTimeout : IMP_PAGER_CM_DEFAULT_SEND_TIMEOUT;
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, sendTimeout);

        // Set the recommended buffer size
        local sendBufferSize = "sendBufferSize" in settings ? 
            settings.sendBufferSize : IMP_PAGER_CM_DEFAULT_BUFFER_SIZE;
        imp.setsendbuffersize(sendBufferSize);

        // Seting onConnect/onDisconnect handlers
        base.onConnect(_onConnect);
        base.onDisconnect(_onDisconnect);
    }

    function onConnect(callback) {
        _onConnectHandlers = _addHandlerAndCleanupEmptyOnes(_onConnectHandlers, callback);
    }

    function onDisconnect(callback) {
        _onDisconnectHandlers = _addHandlerAndCleanupEmptyOnes(_onDisconnectHandlers, callback);
    }

    function _onConnect() {
        foreach (index, callback in _onConnectHandlers) {
            if (callback != null) {
                imp.wakeup(0, callback);
            }
        }
    }

    function _onDisconnect(expected) {
        foreach (index, callback in _onDisconnectHandlers) {
            if (callback != null) {
                imp.wakeup(0, function() {
                    callback(expected);
                });
            }
        }
    }

    function _addHandlerAndCleanupEmptyOnes(handlers, callback) {
        if (handlers.find(callback) == null) {
            handlers.append(callback.weakref());
        }
        return handlers.filter(
            function(index, value) {
                return value != null;
            }
        );
    }

};
