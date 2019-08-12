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

class PersistTestCase extends CustomTestCase {
    function testImportanceCritical() {
        return Promise(function(resolve, reject) {
            rm.confirmResend(function(msg) {
                this.assertTrue(_isMsgPersisted(msg));
                // We need to drop the message before finishing the test so that is will not interfere with the other tests
                resolve();
                return false;
            }.bindenv(this));

            local message = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_INT, RM_IMPORTANCE_CRITICAL);

            // The message must be persisted immediately because the flash memory is (almost)
            // empty and the cleanup of the next sector is not expected to be required
            this.assertTrue(_isMsgPersisted(message));
        }.bindenv(this));
    }

    function testImportanceMedium() {
        return Promise(function(resolve, reject) {
            rm.confirmResend(function(msg) {
                this.assertTrue(_isMsgPersisted(msg));
                resolve();
                return false;
            }.bindenv(this));

            local message = rm.send(MESSAGE_NAME_NO_ACK, MESSAGE_DATA_INT, RM_IMPORTANCE_HIGH);

            // The message must be persisted only after failure
            this.assertTrue(!_isMsgPersisted(message));
        }.bindenv(this));
    }

    function testMessageRemovedAfterAck() {
        const CHECK_DELAY = 2.0;
        const CHECK_DURATION = 10.0;

        return Promise(function(resolve, reject) {
            local message = null;
            local check = null;
            local checkStartTime = null;

            rm.onAck(function(msg,data) {
                check();
            }.bindenv(this));

            check = function() {
                if (checkStartTime == null) {
                    checkStartTime = time();
                } else if (time() - checkStartTime > CHECK_DURATION) {
                    reject("The message hasn't been removed after acknowledgement");
                    return;
                }

                if (!_isMsgPersisted(message)) {
                    resolve();
                } else {
                    imp.wakeup(CHECK_DELAY, check);
                }
            }.bindenv(this);

            message = rm.send(MESSAGE_NAME_ACK, MESSAGE_DATA_INT, RM_IMPORTANCE_CRITICAL);
        }.bindenv(this));
    }

    function _isMsgPersisted(msg) {
        local count = 1;
        local id = msg.payload.id;
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
}
