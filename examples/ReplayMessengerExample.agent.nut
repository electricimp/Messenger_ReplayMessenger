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

// Include library
#require "Messenger.lib.nut:0.1.0"

// Log that code is running
server.log("----------------------------------------------------------");
server.log("Agent running...");

// Define message names
enum MSG_NAMES {
    TEMP = "temp"
}

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

function onTemp(payload, customAck) {
    local data = payload.data;

    server.log("----------------------------------------------------------");
    try {
        server.log("Received temperature message from device");
        server.log(http.jsonencode(data));
    } catch(e) {
        server.error(e);
    }
    server.log("----------------------------------------------------------");
    
    // Allow automatic msg ack.
}

// Register messenger handlers
msngr.defaultOn(onUnknownMsg.bindenv(this));
msngr.on(MSG_NAMES.TEMP, onTemp.bindenv(this));
