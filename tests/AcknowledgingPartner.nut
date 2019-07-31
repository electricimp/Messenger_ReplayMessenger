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

@include __PATH__ + "/SetupBase.nut"

local noAckCallback = function(msg, customAck) {
    // We cancel the auto-ack and don't send any ack at all
    customAck();
}
rm.on(MESSAGE_NAME_NO_ACK, noAckCallback);

local emptyCustomAckCallback = function(msg, customAck) {
    local ack = customAck();
    ack();
}
rm.on(MESSAGE_NAME_EMPTY_CUSTOM_ACK, emptyCustomAckCallback);

local customAckCallback = function(msg, customAck) {
    local ack = customAck();
    ack(MESSAGE_DATA_STRING);
}
rm.on(MESSAGE_NAME_CUSTOM_ACK, customAckCallback);

local ackCallback = function(msg,customAck) {
    //Do nothing and send auto-ack
}
rm.on(MESSAGE_NAME_ACK, ackCallback);
