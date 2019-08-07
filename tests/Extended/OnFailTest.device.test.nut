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

@include __PATH__ + "/../ExtendedTestCase.nut"

class OnFailTestCase extends CustomTestCase {
    function testOnSendFail() {
        return Promise(function(resolve, reject) {
            local origMessage = null;
            rm.onFail(function(msg, reason) {
                _areMessagesEqual(origMessage, msg);
                this.assertEqual(reason, MSGR_ERR_ACK_TIMEOUT);
                resolve();
            }.bindenv(this));

            origMessage = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_LOW);
        }.bindenv(this));
    }

    function testNotConfirmed() {
        return Promise(function(resolve, reject) {
            local origMessage = null;
            rm.confirmResend(function(msg) {
                _areMessagesEqual(origMessage, msg);
                return false;
            }.bindenv(this));

            rm.onFail(function(msg, reason) {
                _areMessagesEqual(origMessage, msg);
                this.assertEqual(reason, RM_ERR_NOT_CONFIRMED);
                resolve();
            }.bindenv(this));

            origMessage = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_CRITICAL);
        }.bindenv(this));
    }

    function testFakeConfirmFunction() {
        return Promise(function(resolve, reject) {
            local origMessage = null;
            local notConfirmResendFunction = MESSAGE_DATA_INT;

            rm.confirmResend(notConfirmResendFunction);

            rm.onFail(function(msg, reason) {
                _areMessagesEqual(origMessage, msg);
                this.assertEqual(reason, RM_ERR_NOT_CONFIRMED);
                resolve();
            }.bindenv(this));

            origMessage = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_CRITICAL);
        }.bindenv(this));
    }

    // This test needs more than default 30 sec timeout
    function testOutOfMemoryFail() {
        const LONG_ACK_TIMEOUT = 10000;
        const SEND_DELAY = 0.2;
        const CHECK_DELAY = 2.0;
        const CHECK_DURATION = 10.0;

        return Promise(function(resolve, reject) {
            local sentMessages = [];
            local deletedMessages = [];
            local send;
            local check;
            local checkStartTime = null;

            rm.onFail(function(msg, reason) {
                deletedMessages.push(msg.payload["id"]);
                this.assertEqual(RM_ERR_OUT_OF_MEMORY, reason);
            }.bindenv(this));

            send = function() {
                local msg = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_STRING, RM_IMPORTANCE_CRITICAL, LONG_ACK_TIMEOUT);
                sentMessages.push(msg.payload["id"]);

                if (deletedMessages.len() == 0) {
                    imp.wakeup(SEND_DELAY, send);
                } else {
                    imp.wakeup(CHECK_DELAY, check);
                }
            }.bindenv(this);

            check = function() {
                if (checkStartTime == null) {
                    checkStartTime = time();
                } else if (time() - checkStartTime > CHECK_DURATION) {
                    reject("The message hasn't been persisted");
                    return;
                }

                if (!_isMsgPersisted(sentMessages.top())) {
                    // Not ready. Wait
                    imp.wakeup(CHECK_DELAY, check);
                    return;
                }

                foreach (id in sentMessages) {
                    local exists = _isMsgPersisted(id);
                    local deleted = _isMsgInArr(id, deletedMessages);
                    this.assertTrue(exists && !deleted || !exists && deleted);
                }
                resolve();
            }.bindenv(this);

            send();
        }.bindenv(this));
    }

    function _isMsgInArr(id, arr) {
        return arr.find(id) != null;
    }

    function _isMsgPersisted(id) {
        local count = 1;
        local messagePayload;
        // In loop synchronously get message payloads from flash and check its id
        while(messagePayload = rm._spiFL.readSync(count++)) {
            local msgFromFlash = rm._messageFromFlash(messagePayload, null);
            if (msgFromFlash.payload.id == id) {
                return true;
            }
        }
        return false;
    }

    function _areMessagesEqual(msg1, msg2) {
        this.assertDeepEqual(msg1.payload, msg2.payload)
        this.assertEqual(msg1.metadata, msg2.metadata);
        this.assertEqual(msg1._importance, msg2._importance);
        this.assertEqual(msg1._ackTimeout, msg2._ackTimeout);
    }
}
