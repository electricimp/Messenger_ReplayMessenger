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

// --------------------------------------------------------------------------------
// Basic example usage for ReplayMessenger Library 
// This example shows the following:
// - Sending messages with importance flag to automatically store and retry failed messages
// - Responding to message with default ACK
// - Use confirmResend handler to delete messages older than specified time
// - Processing ACK data 
// - Register unknown message handler
// Hardware requirements: 
// - imp003 Battery Powered Sensor Node
// Please note this code is intended to illustrate how to use this library. This code 
// is not battery efficient and will drain batteries quickly.
// --------------------------------------------------------------------------------

// Include libraries
#require "Serializer.class.nut:1.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "HTS221.device.lib.nut:2.0.2"
#require "Messenger.lib.nut:0.1.0"
#require "ReplayMessenger.device.lib.nut:0.1.0"

// Define application constants
const LOOP_TIME_SEC       = 30;
const CONNECT_TIMEOUT_SEC = 300;
const STALE_READING_SEC   = 1800;
// Acknowledgment timeout for messages
const RM_ACK_TIMEOUT      = 30;

// Define message names
enum MSG_NAMES {
    TEMP = "temp"
}

// Configure and intialize SPI Flash Logger
sfLogger <- SPIFlashLogger();

// Configure and intialize Connection Manager
cmConfig <- {
    "stayConnected"   : true,
    "blinkupBehavior" : CM_BLINK_ALWAYS,
    "connectTimeout"  : CONNECT_TIMEOUT_SEC
};
cm <- ConnectionManager(cmConfig);

// Configure and intialize Replay Messenger
rmConfig <- {
    "debug"      : true,
    "ackTimeout" : RM_ACK_TIMEOUT
};
rm <- ReplayMessenger(sfLogger, cm, rmConfig)

// Configure TempHumid Sensor
i2c <- hardware.i2cAB;
i2c.configure(CLOCK_SPEED_400_KHZ);
tempHumid <- HTS221(i2c);
tempHumid.setMode(HTS221_MODE.CONTINUOUS, 1);

// Define messenger handlers
function confirmResend(message) {
    // Filter for messages sending readings
    if (message.payload.name == MSG_NAMES.TEMP) {
        local now = time();
        local dataTimestamp = message.payload.data.ts;

        // Drop stale messages
        if (now - dataTimestamp > STALE_READING_SEC) return false;
    }

    // Resend all other messages
    return true;
}

function onUnknownMsg(payload, customAck) {
    local data = payload.data;
    server.log("----------------------------------------------------------");
    // Log message name and payload data
    server.error("Received unknown message: " + payload.name);
    if (typeof data == "table" || typeof data == "array") {
        server.log(http.jsonencode(data));
    } else {
        server.log(data);
    }
    server.log("----------------------------------------------------------");
    // Allow automatic msg ack, so msg is not retried.
}

function onAck(message, ackData) {
    // Store message info in variables
    local payload = message.payload;
    local id = payload.id;
    local name = payload.name;
    local msgData = payload.data;
    local metadata = message.metadata;

    // Log message info
    server.log("Received ack for message " + name + " with id: " + id);

    switch(name) {
        case MSG_NAMES.TEMP: 
            server.log("Temperature reading message acked");
            server.log("----------------------------------------------------------");
            break;
    }
}

// Define application main loop
function loop() {
    server.log("----------------------------------------------------------");
    tempHumid.read(function(result) {
        if ("error" in result) {
            server.error(result.error);
            return;
        }
        // Add timestamp to reading
        result.ts <- time();
        server.log(format("Temperature: %.2f°C, Humidity: %.1f%%", result.temperature, result.humidity));
        local msg = rm.send(MSG_NAMES.TEMP, result, RM_IMPORTANCE_HIGH);
        server.log("Sending temperature message with id " + msg.payload.id + " to agent");
    }.bindenv(this));
    // Schedule next reading
    imp.wakeup(LOOP_TIME_SEC, loop);
}

// Register messenger handlers
rm.confirmResend(confirmResend.bindenv(this));
rm.onAck(onAck.bindenv(this));
rm.defaultOn(onUnknownMsg.bindenv(this));

// Log that code is running
server.log("----------------------------------------------------------");
server.log("Device running...");
server.log(imp.getsoftwareversion());
server.log("----------------------------------------------------------");

// Start application loop
loop();
