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

class ResendTestCase extends CustomTestCase {
    function testResendOnConnectHigh() {
        return _resendOnConnect(RM_IMPORTANCE_HIGH);
    }

    function testResendOnConnectCritical() {
        return _resendOnConnect(RM_IMPORTANCE_CRITICAL);
    }

    function _resendOnConnect(importance) {
        const ACK_TIMEOUT = 10.0;
        const CONNECT_AFTER = 8.0;

        return Promise(function(resolve, reject) {
            local confirmResendCalled = false;

            rm.confirmResend(function(msg) {
                this.assertTrue(rm._cm.isConnected());
                confirmResendCalled = true;
                return true;
            }.bindenv(this));

            rm.onAck(function(msg, data) {
                this.assertTrue(confirmResendCalled);
                resolve();
            }.bindenv(this));

            rm._cm.disconnect();
            rm.send(MESSAGE_NAME_ACK, MESSAGE_DATA_STRING, importance, ACK_TIMEOUT);
            imp.wakeup(CONNECT_AFTER, rm._cm.connect.bindenv(rm._cm));
        }.bindenv(this));
    }
}
