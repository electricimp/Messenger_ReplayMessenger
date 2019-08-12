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

// Include library
#require "Messenger.lib.nut:0.1.0"

// Log that code is running
server.log("----------------------------------------------------------");
server.log("Agent running...");

// Define message names
enum MSG_NAMES {
    LX   = "lights",
    TEMP = "temp"
}

// Track LED state, so message can toggle the state
ledOn <- false;

// Initialize messenger 
msngr <- Messenger();

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

function onAck(message, ackData) {
    // Store message info in variables
    local payload = message.payload;
    local id = payload.id;
    local name = payload.name;
    local msgData = payload.data;
    local metadata = message.metadata;

    server.log("----------------------------------------------------------");
    // Log message info
    server.log("Received ack for message " + name + " with id: " + id);

    switch(name) {
        case MSG_NAMES.LX: 
            server.log("LED message acked");
            break;
        case MSG_NAMES.TEMP: 
            server.log("Temp message acked");
            if (ackData != null) {
                server.log(format("Temperature: %.2f°C, Humidity: %.1f%%", ackData.temperature, ackData.humidity));
            } else {
                server.log("Temp reading failed");
            }
            break;
    }
    server.log("----------------------------------------------------------");
}

function onFail(message, reason) {
    // Store message info in variables
    local payload = message.payload;
    local id = payload.id;
    local name = payload.name;
    local msgData = payload.data;
    local metadata = message.metadata;

    server.log("----------------------------------------------------------");
    // Log message info
    server.error("Message " + name + " with id " + id + " send failure reason: " + reason);
    server.log("----------------------------------------------------------");
}

// Define Main loop
function loop() {
    server.log("----------------------------------------------------------");
    // Toggle LED
    ledOn = !ledOn;
    local lxMsg = msngr.send(MSG_NAMES.LX, ledOn);
    server.log("Sending lighting message with id " + lxMsg.payload.id + " to device");
    
    // Get temp/humidity reading
    local tempMsg = msngr.send(MSG_NAMES.TEMP);
    server.log("Sending temp message with id " + tempMsg.payload.id + " to device");
    server.log("----------------------------------------------------------");

    imp.wakeup(10, loop);
}

// Register messenger handlers
msngr.onAck(onAck.bindenv(this));
msngr.onFail(onFail.bindenv(this));
msngr.defaultOn(onUnknownMsg.bindenv(this));

// Start Main loop
loop();
