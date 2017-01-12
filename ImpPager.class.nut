#require "SPIFlashLogger.class.nut:2.1.0"
#require "ConnectionManager.class.nut:1.0.1"
#require "Serializer.class.nut:1.0.0"
#require "bullwinkle.class.nut:2.3.1"

const IMP_PAGER_MESSAGE_TIMEOUT = 1;
const IMP_PAGER_RETRY_PERIOD_SEC = 0.5;

const IMP_PAGER_CM_DEFAULT_SEND_TIMEOUT = 1;
const IMP_PAGER_CM_DEFAULT_BUFFER_SIZE = 8096;

const IMP_PAGER_RESEND_COMPLETE = "IMP_PAGER_RESEND_COMPLETE"
const IMP_PAGER_SPIFLASH_DUMP_BEGIN = "IMP_PAGER_SPIFLASH_DUMP_BEGIN"
const IMP_PAGER_SPIFLASH_DUMP_COMPLETE = "IMP_PAGER_SPIFLASH_DUMP_COMPLETE"

const ERR_IMPPAGER_FAILED_SENDING_DUMP_BEGIN = "ERR_IMPPAGER_FAILED_SENDING_DUMP_BEGIN";
const ERR_IMPPAGER_FAILED_SENDING_DUMP_COMPLETE = "ERR_IMPPAGER_FAILED_SENDING_DUMP_COMPLETE";

const IMP_PAGER_RTC_INVALID_TIME = 946684800; //Saturday 1st January 2000 12:00:00 AM UTC - this is what time() returns if the RTC signal from the imp cloud has not been received this boot.

const IMP_PAGER_DEFAULT_NAME = "__default__";

class ImpPager {

    // Bullwinkle instance
    _bullwinkle = null;

    // ConnectionManager instance
    _connectionManager = null;

    // Table of SPIFlashLogger instances
    _spiFlashLoggers = null;

    // Using default pagerName
    _usingDefault = null;

    // Message retry timer
    _retryTimer = null;

    // The number of boots that this device has had - used to detect if multiple reboots without a RTC have occurred.  If bootNumber is not set, we will not attempt to recover from a lack of RTC.
    _bootNumber = null;

    // array of [lastTSmillis, lastTStimeSec] used for rebuilding timestamps for if/when we didn't have a RTC.
    _lastTS = null;

    // Debug flag that controlls the debug output
    _debug = false;

    constructor(connectionManager, options = {}) {
        _connectionManager = connectionManager;

        _bullwinkle = ("bullwinkle" in options ? options.bullwinkle : Bullwinkle({"messageTimeout" : IMP_PAGER_MESSAGE_TIMEOUT}));

        if ("spiFlashLoggers" in options) {
          _spiFlashLoggers = {};
          foreach (k,v in options.spiFlashLoggers) {
            if (typeof v == TYPE_TABLE) {
              _spiFlashLoggers[k] <- v;
              if (!("notifyAgent" in _spiFlashLoggers[k])) _spiFlashLoggers[k].notifyAgent <- false;
              if (!("onReplayBegin" in _spiFlashLoggers[k])) _spiFlashLoggers[k].onReplayBegin <- null;
              if (!("onReplayComplete" in _spiFlashLoggers[k])) _spiFlashLoggers[k].onReplayComplete <- null;
            }
            else {_spiFlashLoggers[k] <- {"logger": v, "notifyAgent": false, "onReplayBegin": null, "onReplayComplete": null}}
          }
          _usingDefault = false;
        } else {
          _spiFlashLoggers = {
            [IMP_PAGER_DEFAULT_NAME] =  {
              "logger": SPIFlashLogger()
              "notifyAgent": false,
              "onReplayBegin": null,
              "onReplayComplete": null
            }
          };
          _usingDefault = true;
        }

        // Set ConnectionManager listeners
        _connectionManager.onConnect(_onConnect.bindenv(this));
        _connectionManager.onDisconnect(_onDisconnect.bindenv(this));

        // Set the bootNumber.  If a BootNumber is provided, we will try to rebuild timestamps for conditions where we boot offline and without a RTC.  Otherwise, we won't.
        _bootNumber = ("bootNumber" in options ? options.bootNumber : null);

        _debug = ("debug" in options ? options.debug : false);
    }

    function send(pagerName, messageName = null, data = null, ts = null, autoFail = null) {

        //NOTE: Assume that, if the default is being used, then the args need
        //      to be shifted (i.e. g_ImpPager.send("messageName", data, ts)).
        if (_usingDefault) {
          local temp_pagerName = pagerName;
          local temp_messageName = messageName;
          local temp_data = data;
          local temp_ts = ts;

          pagerName = IMP_PAGER_DEFAULT_NAME;
          messageName = temp_pagerName;
          data = temp_messageName;
          ts = temp_data;
          autoFail = temp_ts;
        }

        if(ts == null) ts = time()
        if(_bootNumber != null && ts == IMP_PAGER_RTC_INVALID_TIME) ts = _bootNumber + "-" + hardware.millis()  //provides ms accurate delta times that can be up to 25 days (2^31ms) apart.  We use typeof(ts) == "string" to detect that our RTC has not been set in the .onFail.

        // if (messageName = "METER_PERIODIC") server.log("[IMPPAGER] sending METER_PERIODIC message with ts "+ts+" and autofail "+autoFail);

        _bullwinkle.send(messageName, data, ts, autoFail)
                    .onSuccess(function(message){
                      _onSuccess(pagerName, message);
                    }.bindenv(this))
                    .onFail(function(err, message, retry){
                      _onFail(pagerName, err, message, retry)
                    }.bindenv(this));
    }

    function onReplayBegin(pagerName=null, cb=null) {
      if (pagerName == null && cb == null) pagerName = IMP_PAGER_DEFAULT_NAME; //Remove default logger handler

      if (typeof pagerName == TYPE_FUNCTION) { //Assume that this is for the default logger handler
        cb = pagerName;
        pagerName = IMP_PAGER_DEFAULT_NAME;
      }

      this._spiFlashLoggers[pagerName].onReplayBegin = cb;
    }

    function onReplayComplete(pagerName=null, cb=null) {
      if (pagerName == null && cb == null) pagerName = IMP_PAGER_DEFAULT_NAME; //Remove default logger handler

      if (typeof pagerName == TYPE_FUNCTION) { //Assume that this is for the default logger handler
        cb = pagerName;
        pagerName = IMP_PAGER_DEFAULT_NAME;
      }

      this._spiFlashLoggers[pagerName].onReplayComplete = cb;
    }

    function _onSuccess(pagerName, message) {
        // Do nothing
        _log_debug("Pager \""+pagerName+"\" ACKed message id " + message.id + " with name: '" + message.name + "'");
        if ("metadata" in message && "addr" in message.metadata && message.metadata.addr) {
            local addr = message.metadata.addr;
            _spiFlashLoggers[pagerName].logger.erase(addr);
            _scheduleRetryIfConnected();
        }
    }

    function _onFail(pagerName, err, message, retry) {
        _log_debug("Pager \""+pagerName+"\" failed to deliver message id " + message.id + " with name: '" + message.name + "' and data: "+message.data+" and err: " + err);

        //NOTE: I put this is here because, once upon a time, I was using
        //      ImpPager.send (rather than _bullwinkle.send) to send the
        //      DUMP_BEGIN message, and many of them got written to SPIFlash
        //      so this was for getting rid of those (leaving it in in case
        //      I do something dumb again).
        // if ("metadata" in message && "addr" in message.metadata && message.metadata.addr && message.name.find(IMP_PAGER_SPIFLASH_DUMP_BEGIN) != null) {
        //   _log_debug("Deleting message "+message.id+" from SPIFlash because it had \""+IMP_PAGER_SPIFLASH_DUMP_BEGIN+"\" in the name")
        //   this._spiFlashLoggers[pagerName].logger.erase(message.metadata.addr);
        //   _scheduleRetryIfConnected();
        //   return;
        // }

        // On fail write the message to the SPI Flash for further processing
        // only if it's not already there.
        if (!("metadata" in message) || !("addr" in message.metadata) || !(message.metadata.addr)) {
            delete message.type //Not needed to write to SPIFlash, as the type will always be BULLWINKLE_MESSAGE_TYPE.SEND

            if(typeof(message.ts) == "string") {  // We have a _bootNumber and invalid RTC - add some metadata so that we can try to restore the timestamp once we have RTC.
                message.metadata <- {
                  "boot": split(message.ts, "-")[0].tointeger()
                  "rtc": false
                }
                message.ts = split(message.ts, "-")[1].tointeger()
            }
            _spiFlashLoggers[pagerName].logger.write(message);
            message.type <- BULLWINKLE_MESSAGE_TYPE.FAILED // We are mucking around with the internal logic of Bullwinkle so we need to repair the message object here
        }
        _scheduleRetryIfConnected();
    }

    // This is a hack to resend the message with metainformation
    function _resendLoggedData(pagerName, dataPoint) {
        _log_debug("Resending Pager \""+pagerName+"\" message id " + dataPoint.id + " with name: '" + dataPoint.name + "' and data: " + dataPoint.data + " at ts: "+dataPoint.ts)

        dataPoint.type <- BULLWINKLE_MESSAGE_TYPE.SEND;

        local package = Bullwinkle.Package(dataPoint)
            .onSuccess(function(message){
              _onSuccess(pagerName, message);
            }.bindenv(this))
            .onFail(function(err, message, retry){
              _onFail(pagerName, err, message, retry);
            }.bindenv(this));

        if(dataPoint.id in _bullwinkle._packages) //Prevent overwriting of any bullwinkle packages with similair IDs
          dataPoint.id = _bullwinkle._generateId()

        _bullwinkle._packages[dataPoint.id] <- package;
        _bullwinkle._sendMessage(dataPoint);
    }


    function _retry() {
      return Promise(function(resolve, reject){
        _log_debug("Start processing pending messages...");

        local count = 0;
        local spiFlashLoggerKeys = [];
        foreach (k,v in _spiFlashLoggers) spiFlashLoggerKeys.push(k);

        Promise.loop(@() count < spiFlashLoggerKeys.len(), function(){
          return Promise(function(resolve, reject){
            local pagerName = spiFlashLoggerKeys[count];
            local opts = this._spiFlashLoggers[pagerName];
            local prefix = (pagerName == IMP_PAGER_DEFAULT_NAME ? "" : pagerName+":");
            _log_debug("[IMPPAGER] Processing messages for Pager \""+pagerName+"\"");

            local replayAllData = function(...) {
              if (opts.onReplayBegin) opts.onReplayBegin({"ts": time()});
              opts.logger.read(
                  function(dataPoint, addr, next) {
                      _log_debug("Reading from SPI Flash. ID: " + dataPoint.id + " at addr: " + addr);

                      // There's no point of retrying to send pending messages when disconnected
                      if (!_connectionManager.isConnected()) {
                          _log_debug("No connection, abort SPI Flash scanning...");
                          // Abort scanning
                          next(false);
                          return;
                      }

                      if(time() == IMP_PAGER_RTC_INVALID_TIME){ // If time is invalid, we aren't ready to resend any data just yet...
                          _log_debug("time() was invalid, abort SPI Flash scanning...");
                          // Abort scanning
                          next(false);
                          return;
                      }

                      // Save SPI Flash address in the message metadata
                      if(!("metadata" in dataPoint)) dataPoint.metadata <- {}
                      dataPoint.metadata.addr <- addr;

                      if("rtc" in dataPoint.metadata && dataPoint.metadata.rtc == false){
                        if(_lastTS == null){
                          _lastTS = [hardware.millis(), time()] //With these two datapoints, we can now re-establish all of our timestamps
                          _log_debug("Discovered most recent datapoint saved to SPIFlash without RTC - " + dataPoint.id + " attempting to rebuild timestamps with ms = " + _lastTS[0] + " and time = " + _lastTS[1])
                        }

                        _log_debug("Found log without RTC. ID=" + dataPoint.id + " and ts=" +dataPoint.ts)

                        if("boot" in dataPoint.metadata && dataPoint.metadata.boot == _bootNumber){
                          local deltaTMillis = _lastTS[0] - dataPoint.ts
                          local deltaTSeconds = math.floor((deltaTMillis+500)/1000).tointeger() //Round to nearest second, but use this int value for updating _lastTS to keep millis() and time() consistent
                          dataPoint.ts = _lastTS[1] - deltaTSeconds  //All integer math, so no need to worry about decimal points

                          _log_debug("Calculated new ts as " + dataPoint.ts + " (deltaT = " + deltaTMillis + " ms)")

                          //update _lastTS so that we can have ~25 days between datapoints instead of 25 days total of timestamps that we can rebuild.
                          //^^^ This is ~98% true.  Its actually slightly less than that since we only subtract the integer seconds (as opposed to ALL of the milliseconds) and avoid rounding problems and/or floating point precission issues associated with taking the full precision amount of millis() off of the time() stored in _lastTS.  You will have slightly a slightly smaller recovery window (losing up to 499ms), but it dramtically simplifies the code and what's half a second compared to 25 days?
                          _lastTS[0] -= (deltaTSeconds*1000).tointeger()
                          _lastTS[1] = dataPoint.ts

                          // Our RTC has been reset - delete the metadata
                          delete dataPoint.metadata.rtc

                        } else {
                          server.error("Warning - dataPoint bootNumber " + dpBootNum + " != device bootNumber " + _bootNumber + " for message ID " + dataPoint.id + ".  Unable to rebuild ts...")
                        }
                      }

                      _resendLoggedData(pagerName, dataPoint)

                      // Don't do any further scanning until we get an ACK for already sent message
                      next(false);
                  }.bindenv(this),

                  function() {
                      _log_debug("[IMPPAGER] Finished processing all pending messages for Pager \""+pagerName+"\"");

                      //NOTE: We don't want to send this via ImpPager because we don't
                      //      want this to be added to the SPIFlashLogger if this fails
                      if (opts.notifyAgent) {
                        this._bullwinkle.send(prefix+IMP_PAGER_SPIFLASH_DUMP_COMPLETE) //Notify the agent that we are finished replaying old data in case it needs to do any special processing on replayed data (newest->oldest to oldest->newest).
                        .onSuccess(function(message) {
                          if (opts.onReplayComplete) opts.onReplayComplete({"ts": time()});
                          _log_debug("[IMPPAGER] Success sending message \""+(prefix+IMP_PAGER_SPIFLASH_DUMP_COMPLETE)+"\" for Pager that should be handled special.")
                          count++;
                          resolve(true)
                        }.bindenv(this))
                        .onFail(function(err, message, retry){
                          if (opts.onReplayComplete) opts.onReplayComplete({"ts": time(), "err": ERR_IMPPAGER_FAILED_SENDING_DUMP_COMPLETE});
                          _log_debug("[IMPPAGER] Error sending message \""+(prefix+IMP_PAGER_SPIFLASH_DUMP_COMPLETE)+"\" for Pager that should be handled special.")
                          count++;
                          resolve(true)
                        }.bindenv(this))
                      } else {
                        count++;
                        resolve(true)
                      }

                  }.bindenv(this),

                  -1  // Read through the data from most recent (which is important for real-time apps) to oldest, 1 at a time.  This also allows us to rebuild our timestamps from newest to oldest
              );
            }

            if (!opts.notifyAgent) replayAllData();
            else {
              //NOTE: We don't want to send this via ImpPager because we don't
              //      want this to be added to the SPIFlashLogger if this fails
              this._bullwinkle.send(prefix+IMP_PAGER_SPIFLASH_DUMP_BEGIN) //TODO: BUG: What do we do if this fails? Probably need to ensure that this is received before we start reading first...
              .onSuccess(replayAllData.bindenv(this))
              .onFail(function(err, message, retry){
                _log_debug("[IMPPAGER] Error sending message \""+(prefix+IMP_PAGER_SPIFLASH_DUMP_BEGIN)+"\" for Pager that should be handled special.")
                count++;
                resolve(true);
              }.bindenv(this));
            }

          }.bindenv(this))
        }.bindenv(this))
        .then(resolve)
        .fail(reject)
      }.bindenv(this))
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
            _log_debug("_scheduleRetryIfConnected: not connected so no retry scheduled.")
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

    function fakeDisconnect(){
      _connected = false;

      // Set the BlinkUp State
      _setBlinkUpState();

      // Run the global onDisconnected Handler if it exists
      imp.wakeup(0, function() { _onDisconnect(true); }.bindenv(this));
    }
}
