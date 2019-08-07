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

class ConstructorTestCase extends ImpTestCase {
    rm = null;

    function testBaseConstructor() {
        const FIRST_MESSAGE_ID_TEST = 6;
        const MAX_RATE_TEST = 12;
        const DEBUG_ENABLE = 1;

        rm = Messenger({
            "debug" : DEBUG_ENABLE,
            "ackTimeout" : ACK_TIMEOUT_TEST,
            "firstMsgId" : FIRST_MESSAGE_ID_TEST,
            "maxRate" : MAX_RATE_TEST,
        });

        this.assertEqual(DEBUG_ENABLE, rm._debug);
        this.assertEqual(ACK_TIMEOUT_TEST, rm._ackTimeout);
        this.assertEqual(FIRST_MESSAGE_ID_TEST, rm._nextId);
        this.assertEqual(MAX_RATE_TEST, rm._maxRate);

        rm = Messenger();
        this.assertEqual(MSGR_DEFAULT_DEBUG, rm._debug);
        this.assertEqual(MSGR_DEFAULT_ACK_TIMEOUT_SEC, rm._ackTimeout);
        this.assertEqual(MSGR_DEFAULT_FIRST_MESSAGE_ID, rm._nextId);
        this.assertEqual(MSGR_DEFAULT_MAX_MESSAGE_RATE, rm._maxRate);
    }
}
