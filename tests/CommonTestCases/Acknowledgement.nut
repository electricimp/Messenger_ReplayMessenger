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

class AcknowledgementTestCase extends CustomTestCase {
    function testCustomAckData() {
        return Promise(function(resolve, reject) {
            local message = null;

            rm.onAck(function(msg, data) {
                this.assertDeepEqual(message, msg);
                this.assertEqual(MESSAGE_DATA_STRING, data);
                _checkMsgNotInSentQueue(msg);
                resolve();
            }.bindenv(this));

            message = rm.send(MESSAGE_NAME_CUSTOM_ACK, MESSAGE_DATA_INT);
        }.bindenv(this));
    }

    function testEmptyCustomAck() {
        return Promise(function(resolve, reject) {
            local message = null;

            rm.onAck(function(msg, data) {
                this.assertDeepEqual(message, msg);
                this.assertEqual(null, data);
                _checkMsgNotInSentQueue(msg);
                resolve();
            }.bindenv(this));

            message = rm.send(MESSAGE_NAME_EMPTY_CUSTOM_ACK, MESSAGE_DATA_INT);
        }.bindenv(this));
    }

    function testAutoAck() {
        return Promise(function(resolve, reject) {
            local message = null;

            rm.onAck(function(msg, data) {
                this.assertDeepEqual(message, msg);
                this.assertEqual(null, data);
                _checkMsgNotInSentQueue(msg);
                resolve();
            }.bindenv(this));

            message = rm.send(MESSAGE_NAME_ACK, MESSAGE_DATA_INT);
        }.bindenv(this));
    }

    function _checkMsgNotInSentQueue(msg) {
        if (msg.payload.id in rm._sentQueue) {
            throw "The message is still in _sentQueue after acknowledgement";
        }
    }
}
