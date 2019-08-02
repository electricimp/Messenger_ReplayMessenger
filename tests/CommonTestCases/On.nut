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

class OnTestCase extends CustomTestCase {
    function testOn() {
        return Promise(function(resolve, reject) {
            local on1Called = false;
            local on2Called = false;
            local on3Called = false;

            local check = function() {
                if (on1Called && on2Called && on3Called) {
                    resolve();
                }
            }.bindenv(this);

            local on1 = function(msg, customAck) {
                this.assertTrue(!on1Called);
                this.assertEqual(MESSAGE_DATA_INT, msg.data);
                on1Called = true;
                check();
            }.bindenv(this);
            rm.on("type1", on1);

            local on2 = function(msg, customAck) {
                this.assertTrue(!on2Called);
                this.assertEqual(MESSAGE_DATA_STRING, msg.data);
                on2Called = true;
                check();
            }.bindenv(this);
            rm.on("type2", on2);

            local on3 = function(msg, customAck) {
                this.assertTrue(!on3Called);
                this.assertDeepEqual(MESSAGE_DATA_TABLE, msg.data);
                on3Called = true;
                check();
            }.bindenv(this);
            rm.on("type3", on3);

            this.assertTrue(rm._on["type1"] == on1);
            this.assertTrue(rm._on["type2"] == on2);
            this.assertTrue(rm._on["type3"] == on3);

            rm.send(MESSAGE_NAME_START);
        }.bindenv(this));
    }

    function testDefaultOn1() {
        return Promise(function(resolve, reject) {
            local defaultOnCallback = _setupDefaultOnTest(resolve);
            rm.defaultOn(defaultOnCallback);
            this.assertTrue(rm._defaultOn == defaultOnCallback);
            rm.send(MESSAGE_NAME_START);
        }.bindenv(this));
    }

    function testDefaultOn2() {
        return Promise(function(resolve, reject) {
            local defaultOnCallback = _setupDefaultOnTest(resolve);
            rm.on(null, defaultOnCallback);
            this.assertTrue(rm._defaultOn == defaultOnCallback);
            rm.send(MESSAGE_NAME_START);
        }.bindenv(this));
    }

    function _setupDefaultOnTest(resolve) {
        local type1Received = false;
        local type2Received = false;
        local type3Received = false;

        local check = function() {
            if (type1Received && type2Received && type3Received) {
                resolve();
            }
        }.bindenv(this);

        local defaultOnCallback = function(msg, customAck) {
            if (msg.name == "type1") {
                this.assertTrue(!type1Received);
                this.assertEqual(MESSAGE_DATA_INT, msg.data);
                type1Received = true;
                check();
            } else if (msg.name == "type2") {
                this.assertTrue(!type2Received);
                this.assertEqual(MESSAGE_DATA_STRING, msg.data);
                type2Received = true;
                check();
            }
        }.bindenv(this);

        local on3 = function(msg, customAck) {
            this.assertTrue(!type3Received);
            this.assertDeepEqual(MESSAGE_DATA_TABLE, msg.data);
            type3Received = true;
            check();
        }.bindenv(this);
        rm.on("type3", on3);

        this.assertTrue(rm._on["type3"] == on3);

        return defaultOnCallback;
    }
}
