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
// Basic example usage for Messenger Library 
// This example shows the following:
// - Sending messages with and without data
// - Responding to message with default ACK and custom ACK
// - Processing ACK data 
// - Registering message failure and unknown message handlers
// Hardware requirements: 
// - imp001 Explorer Kit
// --------------------------------------------------------------------------------

// Include libraries
#require "Messenger.lib.nut:0.1.0"
#require "HTS221.device.lib.nut:2.0.2"
#require "WS2812.class.nut:3.0.0"

// Log that code is running
server.log("----------------------------------------------------------");
server.log("Device running...");
imp.enableblinkup(true);
server.log(imp.getsoftwareversion());
server.log("----------------------------------------------------------");

// Define message names
enum MSG_NAMES {
    LX   = "lights",
    TEMP = "temp"
}

// LED state constants
ON  <- [20, 20, 20];
OFF <- [0, 0, 0];

// Configure LED
led <- WS2812(hardware.spi257, 1);
// Enable power gate, so LED will work
hardware.pin1.configure(DIGITAL_OUT, 1);

// Configure TempHumid Sensor
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tempHumid <- HTS221(hardware.i2c89);
tempHumid.setMode(HTS221_MODE.CONTINUOUS, 1);

// Configure Messenger
msngr <- Messenger();

// Automatically Acknowledge Messages
function lxHandler(payload, customAck) {
    server.log("----------------------------------------------------------");
    server.log("Received lighting message from agent. Toggling LED state.");
    server.log("----------------------------------------------------------");
    // Do NOT call the received custom acknowledgement function
    // to ensure that automatic message acknowledgement takes place
    local lightsOn = payload.data;
    (lightsOn) ? led.fill(ON) : led.fill(OFF);
    led.draw();
}

// Create Custom Acknowledgement Messages
function tempHandler(payload, customAck) {
    server.log("----------------------------------------------------------");
    server.log("Received temp message from agent");
    
    // Call the received custom acknowledgement function to prevent
    // auto-acknowledgement, and store the returned acknowledgement function
    local ack = customAck();

    // Take a reading
    tempHumid.read(function(result) {
        if ("error" in result) {
            server.error(result.error);
            // Acknowledge the message by calling the stored acknowledgement function
            // The reading failed, so don't pass in a data value
            server.log("Sending custom temp ack to agent");
            server.log("----------------------------------------------------------");
            ack();
            return;
        }

        // Acknowledge the message by calling the stored acknowledgement function
        // Reading was successful, so pass in the reading result
        server.log("Sending custom temp ack to agent");
        server.log("----------------------------------------------------------");
        ack(result);
    }.bindenv(this));
}

// Define messenger handlers
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

// Register 'onMsg' callbacks for given names, and generic handler
msngr.on(MSG_NAMES.LX, lxHandler.bindenv(this));
msngr.on(MSG_NAMES.TEMP, tempHandler.bindenv(this));
msngr.defaultOn(onUnknownMsg.bindenv(this));
