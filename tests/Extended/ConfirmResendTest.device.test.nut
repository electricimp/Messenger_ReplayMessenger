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

class ConfirmResendTestCase extends CustomTestCase {
    function testConfirmResendHigh() {
        return _testConfirmResend(RM_IMPORTANCE_HIGH);
    }

    function testConfirmResendCritical() {
        return _testConfirmResend(RM_IMPORTANCE_CRITICAL);
    }

    function _testConfirmResend(importance) {
        return Promise(function(resolve, reject) {
            local sendsCounter = 0;
            local message = null;

            rm.confirmResend(function(msg) {
                this.assertDeepEqual(message.payload, msg.payload);
                sendsCounter++;
                return true;
            }.bindenv(this));

            rm.onAck(function(msg, data) {
                this.assertDeepEqual(message.payload, msg.payload);
                // After the specified number of resends the message should be acked
                if (sendsCounter == CONFIRM_RESEND_MSG_NUM_TO_ACK) {
                    resolve();
                } else {
                    reject();
                }
            }.bindenv(this));

            rm.onFail(function(msg, reason) {
                reject("onFail is called");
            });

            message = rm.send(MESSAGE_NAME_CONFIRM_RESEND, MESSAGE_DATA_INT, importance);
            sendsCounter++;
        }.bindenv(this));
    }
}
