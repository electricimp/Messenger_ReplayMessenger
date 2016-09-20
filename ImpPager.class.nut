#require "SPIFlashLogger.class.nut:2.1.0"
#require "ConnectionManager.class.nut:1.0.1"
#require "Serializer.class.nut:1.0.0"
#require "bullwinkle.class.nut:2.3.1"

const IMP_PAGER_MESSAGE_TIMEOUT = 1;
const IMP_PAGER_RETRY_PERIOD_SEC = 2;
const IMP_PAGER_ITERATE_OVER_RETRIES_PERIOD_SEC = 0.2;

class ImpPager {

    // Bullwinkle instance
    _bull = null;

    // ConnectionManager instance
    _conn = null;

    // SPIFlashLogger instance
    _logger = null;

    // Message retry timer
    _pendingMessageTimer = null;

    // Map of message -> SPI Flash address
    _messageAddrMap = null;

    // Message counter used for generating unique message id
    _messageCounter = 0;

    constructor(conn = null, logger = null) {
        _bull = Bullwinkle({"messageTimeout" : IMP_PAGER_MESSAGE_TIMEOUT});
        _conn = conn ? conn : ConnectionManager({"stayConnected": true});
        _logger = logger ? logger : SPIFlashLogger();
        _scheduleProcessMessagesTimer();
        _messageAddrMap = {}
        _messageCounter = 0;

        // Override the timeout to make it a nonzero, but still 
        // a small value. This is needed to avoid accedental 
        // imp disconnects when using ConnectionManager library.
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 1);

        // Set the recommended buffer size
        imp.setsendbuffersize(8096);

        _conn.onConnect(_onConnect.bindenv(this));
        _conn.onDisconnect(_onDisconnect.bindenv(this));
    }

    function send(messageName, data = null) {
        local message = {
            "id"  : _getMessageUniqueId(),
            "raw" : data
        };
        _send(messageName, message);
    }    

    function _onSuccess(message) {
        // Erase message from the logger if it was cached
        if (message.data.id in _messageAddrMap) {
            local addr = _messageAddrMap[message.data.id];
            _log_debug("Erasing address: " + addr)
            _logger.erase(addr);
            _messageAddrMap.rawdelete(message);
        }
    }

    function _onFail(err, message, retry) {
        // On fail write the message to the SPI Flash for further processing
        if (!(message.data.id in _messageAddrMap)) {
            _messageAddrMap[message.data.id] <- null;
            _logger.write(message);
        }
    }

    function _send(messageName, message) {
        return _bull.send(messageName, message)
            .onSuccess(_onSuccess.bindenv(this))
            .onFail(_onFail.bindenv(this));
    }

    /**
     * Generates unique message id. It should incrementally increase.
     */
    function _getMessageUniqueId() {
        // Using a local counter seems good enough as there is almost 
        // no chance for subsiquent values to collide even if device reboots.
        return date().time + "-" + (_messageCounter++);
    }

    function _processPendingMessages() {
        _log_debug("Start processing pending messages...");
        _logger.read(
            function(dataPoint, addr, next) {
                if (!_conn.isConnected()) {
                    // The imp is not connected at this point. There's no point of trying to resend messages.
                    return;
                }
                _send(dataPoint.name, dataPoint.data);
                _messageAddrMap[dataPoint.data.id] <- addr;
                _log_debug("Reading from the SPI Flash: " + dataPoint.data.raw + " at addr: " + addr);
                imp.wakeup(IMP_PAGER_ITERATE_OVER_RETRIES_PERIOD_SEC, next);
            }.bindenv(this),
            function() {
                _log_debug("Finished processing all pending messages");
                _scheduleProcessMessagesTimer();
            }.bindenv(this)
        );
    }

    function _onConnect() {
        _log_debug("onConnect: scheduling pending message processor...");
        _scheduleProcessMessagesTimer();        
    }

    function _onDisconnect(expected) {
        _log_debug("onDisconnect: cancelling pending message processor...");
        // Stop any attempts to process pending messages while we are disconnected
        imp.cancelwakeup(_pendingMessageTimer);
    }

    function _scheduleProcessMessagesTimer() {
        if (_pendingMessageTimer) {
            imp.cancelwakeup(_pendingMessageTimer);    
        }
        _pendingMessageTimer = imp.wakeup(
            IMP_PAGER_RETRY_PERIOD_SEC, 
            _processPendingMessages.bindenv(this));
    }

    function _log_debug(str) {
        // _conn.log(str);
    }
}
