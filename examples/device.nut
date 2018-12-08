// Device source code goes here
#require "SPIFlashLogger.class.nut:2.1.0"
#require "ConnectionManager.class.nut:1.0.1"
#require "Serializer.class.nut:1.0.0"

#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONEncoder.class.nut:1.0.0"
#require "MessageManager.lib.nut:2.2.1"

@include __PATH__ + "/../ReplayMessenger.device.lib.nut"


local cm = ConnectionManager({
    "blinkupBehavior"  : ConnectionManager.BLINK_ALWAYS,
    "stayConnected"    : true,
    "sendTimeout"      : 0,
    "sendBufferSize"   : 8096,
    "ackTimeout"       : 30
});

local mmOptions = {
    "connectionManager" : cm
};

local mm = MessageManager(mmOptions);

local rmOptions = {
    "connectionManager" : cm,
    "messageManager"    : mm,
    "debug"             : true
}
rm <- ReplayMessenger(rmOptions);

const TOTAL_COUNT = 100;
const SEND_PERIOD = 0.1;
local counter = 0;

rm.send("init", TOTAL_COUNT);

function send() {
    rm.send("name", counter++);
    if (counter < TOTAL_COUNT) {
        imp.wakeup(SEND_PERIOD, send);
    }
}

send();

function printResult() {
    rm.send("result", null);
    imp.wakeup(10, printResult);
}

imp.wakeup(10, printResult);

imp.wakeup(2, @() cm.disconnect());
imp.wakeup(7, @() cm.connect());