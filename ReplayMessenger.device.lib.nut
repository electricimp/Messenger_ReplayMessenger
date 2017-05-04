// MIT License
//
// Copyright 2016-2017 Electric Imp
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


const RM_TCP_ACK_TIMEOUT_SEC = 30;
const RM_DEFAULT_MESSAGE_TIMEOUT_SEC = 10;
const RM_DEFAULT_RETRY_INTERVAL_SEC  = 0.5;

class ReplayMessenger {

    // MessageManager instance
    _mm = null;

    // ConnectionManager instance
    _cm = null;

    // SPIFlashLogger instance
    _spiFL = null;

    // SPIFlashLogger read options
    _readOptions = null;

    // Handlers to be called when we begin replaying data
    _beforeReplay = null;

    // Handlers to be called when we finish replaying data
    _afterReplay = null;

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

        _beforeReplay = {};
        _afterReplay = {};
        _readOptions = {};

        _cm = "connectionManager" in options ? options["connectionManager"] : ConnectionManager({
            "ackTimeout" : RM_TCP_ACK_TIMEOUT_SEC
        });
        _mm = "messageManager" in options ? options["messageManager"] : MessageManager({
            "messageTimeout"    : RM_DEFAULT_MESSAGE_TIMEOUT_SEC,
            "connectionManager" : _cm
        });
        _debug = "debug" in options ? options["debug"] : debug;
        _retryInterval = "retryInterval" in options ? options["retryInterval"] : RM_DEFAULT_RETRY_INTERVAL_SEC;

        local spiFlashLogger = ("spiFlashLogger" in options) ? options["spiFlashLogger"] : SPIFlashLogger();
        _spiFL = (typeof spiFlashLogger == "table") ? spiFlashLogger : {
            "default" : spiFlashLogger
        };

        // Set MessageManager listeners
        _mm.onAck(_onAck.bindenv(this))
        _mm.onFail(_onFail.bindenv(this))

        // Set ConnectionManager listeners
        _cm.onConnect(_onConnect.bindenv(this));
        _cm.onDisconnect(_onDisconnect.bindenv(this));

        // Schedule routine to retry sending messages
        local scheduleRetry = ("retryOnInit" in options ? options.retryOnInit : true);
        if (scheduleRetry) {
          _scheduleRetryIfConnected();
        }
    }

    function send(messageName, data = null, loggerName = "default", metadata = null) {
        if (!(loggerName in _spiFL)) {
            throw format("Logger \"%s\" does not exist", loggerName);
        }
        if (metadata == null) {
            metadata = {};
        }
        metadata["loggerName"] <- loggerName;
        return _mm.send(messageName, data, null, _retryInterval, metadata);
    }

    function beforeReplay(loggerName, callback = null) {
      if (loggerName == null && callback == null) { //assume the user wants to de-register the callback for the "default" logger
        loggerName = "default";
      }

      if (typeof loggerName == "string" && callback == null) { //de-register callback
        if (loggerName in _beforeReplay) delete _beforeReplay[loggerName]
        return;
      }

      if (typeof loggerName == "function" && callback == null) { //assume this is the callback provided for "default" logger
        callback = loggerName;
        loggerName = "default";
      }

      _beforeReplay[loggerName] <- callback;
    }

    function afterReplay(loggerName, callback = null) {
      if (loggerName == null && callback == null) { //assume the user wants to de-register the callback for the "default" logger
        loggerName = "default";
      }

      if (typeof loggerName == "string" && callback == null) { //de-register callback
        if (loggerName in _afterReplay) delete _afterReplay[loggerName]
        return;
      }

      if (typeof loggerName == "function" && callback == null) { //assume this is the callback provided for "default" logger
        callback = loggerName;
        loggerName = "default";
      }

      _afterReplay[loggerName] <- callback;
    }

    function setLoggerReadOptions(loggerName, options=null) {
      if (typeof loggerName == "table" && options == null) { //assume these are the read options provided for the "default" logger
        options = loggerName;
        loggerName = "default";
      }

      _readOptions[loggerName] <- options;
    }

    function onConnect(callback) {
        _onConnHandler = callback;
    }

    function onDisconnect(callback) {
        _onDiscHandler = callback;
    }

    function eraseAll() {
        foreach (loggerName, logger in _spiFL) {
            logger.eraseAll(true);
        }
    }

    function _onAck(message) {
        if ("metadata" in message && "loggerName" in message.metadata) {
            _log("ACKed message name: '" + message.payload.name + "', data: " + message.payload.data);
            if ("addr" in message.metadata && message.metadata.addr) {
                local addr = message.metadata.addr;
                local logger = _spiFL[message.metadata.loggerName];
                _log("Erasing object at address: " + addr);

                logger.erase(addr);
                message.metadata.addr = null;
                _scheduleRetryIfConnected();
            }
        }
    }

    function _onFail(message, reason, retry) {
        if ("metadata" in message && "loggerName" in message.metadata) {
            local payload = message.payload
            _log("Failed to deliver message name: '" + payload.name + "', data: " + payload.data + ", error: " + reason);
            // On fail write the message to the SPI Flash for further processing
            // only if it's not already there.
            if (!("addr" in message.metadata) || !(message.metadata.addr)) {
                local savedMsg = {
                    "name" :    payload.name,
                    "data" :    payload.data,
                    "metadata": message.metadata //add metadata to message because a user may have something important here
                }

                //TODO: Should we remove "loggerName" from metadata since it is redundant?

                local logger = _spiFL[message.metadata.loggerName];
                logger.write(savedMsg);
            }
            _scheduleRetryIfConnected();
        }
    }

    function _retry() {
        _log("Start processing pending messages...");

        foreach (loggerName, logger in _spiFL) {

            if (loggerName in _beforeReplay && typeof _beforeReplay[loggerName] == "function") {
              _beforeReplay[loggerName]();
            }

            local step = (loggerName in _readOptions && "step" in _readOptions[loggerName] ? _readOptions[loggerName].step : 1);
            local skip = (loggerName in _readOptions && "skip" in _readOptions[loggerName] ? _readOptions[loggerName].skip : 0);

            logger.read(
                function(savedMsg, addr, next) {
                    if (!("data" in savedMsg) || !("name" in savedMsg)) {
                        // _spiFL.erase(addr);
                        next();
                        return;
                    }
                    _log("Reading from the SPI Flash. Data: " + savedMsg.data + " at addr: " + addr);

                    // There's no point of retrying to send pending messages when Ced
                    if (!_cm.isConnected()) {
                        _log("No connection, abort SPI Flash scanning...");
                        // Abort scanning
                        next(false);
                        return;
                    }

                    local metadata;
                    if ("metadata" in savedMsg && typeof savedMsg.metadata == "table") {
                      metadata = savedMsg.metadata;
                    } else {
                      metadata = {};
                    }

                    metadata.addr <- addr;

                    _log("Resending message name: '" + savedMsg.name + "', data: " + savedMsg.data);
                    send(savedMsg.name, savedMsg.data, loggerName, metadata);

                    // Skip to next item
                    next();
                }.bindenv(this),
                function() {
                    _log("Finished processing all pending messages");
                    if (loggerName in _afterReplay && typeof _afterReplay[loggerName] == "function") {
                      _afterReplay[loggerName]();
                    }
                }.bindenv(this),
                step,
                skip
            );
        }
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
