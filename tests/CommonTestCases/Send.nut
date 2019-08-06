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

class SendTestCase extends CustomTestCase {
    isBaseRM = null;

    function setUp() {
        base.setUp();
        isBaseRM = typeof rm == "Messenger";
    }

    function testSend() {
        return Promise(function(resolve, reject) {
            local message = null;

            rm.onAck(function(msg, customAck) {
                this.assertDeepEqual(message, msg);
                resolve();
            }.bindenv(this));

            rm.onFail(function(msg, reason) {
                reject("onFail called");
            }.bindenv(this));

            message = rm.send(MESSAGE_NAME_ACK, MESSAGE_DATA_STRING);
        }.bindenv(this));
    }

    function testSendAckTimeout() {
        const ACK_TIMEOUT = 5.0;
        const MAX_DIFF = 2.0;

        return Promise(function(resolve, reject) {
            local message = null;
            local sendTime = time();

            rm.onAck(function(msg, customAck) {
                reject("We mustn't get ack here");
            }.bindenv(this));

            rm.onFail(function(msg, reason) {
                if (math.abs(time() - sendTime - ACK_TIMEOUT) > MAX_DIFF) {
                    reject();
                } else {
                    resolve();
                }
            }.bindenv(this));

            if (isBaseRM) {
                message = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, ACK_TIMEOUT);
            } else {
                message = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_LOW, ACK_TIMEOUT);
            }
        }.bindenv(this));
    }

    function testSendMetadata1() {
        return Promise(function(resolve, reject) {
            local message = null;
            local sendTime = time();

            rm.onAck(function(msg, customAck) {
                this.assertDeepEqual(message.metadata, msg.metadata);
                resolve();
            }.bindenv(this));

            rm.onFail(function(msg, reason) {
                reject("onFail called");
            }.bindenv(this));

            if (isBaseRM) {
                message = rm.send(MESSAGE_NAME_ACK, MESSAGE_DATA_STRING, null, MESSAGE_DATA_TABLE);
            } else {
                message = rm.send(MESSAGE_NAME_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_LOW, null, MESSAGE_DATA_TABLE);
            }
        }.bindenv(this));
    }

    function testSendMetadata2() {
        return Promise(function(resolve, reject) {
            local message = null;
            local sendTime = time();

            rm.onAck(function(msg, customAck) {
                reject("We mustn't get ack here");
            }.bindenv(this));

            rm.onFail(function(msg, reason) {
                this.assertDeepEqual(message.metadata, msg.metadata);
                resolve();
            }.bindenv(this));

            if (isBaseRM) {
                message = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, null, MESSAGE_DATA_TABLE);
            } else {
                message = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_LOW, null, MESSAGE_DATA_TABLE);
            }
        }.bindenv(this));
    }
}
