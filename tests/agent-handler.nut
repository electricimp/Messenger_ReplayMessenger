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


@include "https://raw.githubusercontent.com/electricimp/MessageManager/develop/MessageManager.lib.nut"

// @include "github:electricimp/MessageManager/MessageManager.lib.nut@develop"

const MSG_COUNT = 100;
const DATA_MSG_NAME  = "data";
const INIT_MSG_NAME  = "init";
const ERROR_MSG_NAME = "errors";

local mm = MessageManager()

local totalCount = 0
local received = array(MSG_COUNT, 0)

mm.on(INIT_MSG_NAME, function(msg, reply) {
    totalCount = msg.data;
    received = array(totalCount, 0);
})

mm.on(DATA_MSG_NAME, function(msg, reply) {
    // server.log("message received: " + msg.data);
    received[msg.data] += 1;
})

mm.on(ERROR_MSG_NAME, function(data, reply) {
    local errorCount = 0
    for (local i = 0; i < totalCount; i++) {
        if (received[i] == 0) {
            server.log("  !!! " + i + ": " + received[i]);
            errorCount++;
        }
    }
    // server.log("Error count: " + errorCount);
    reply(errorCount);
})