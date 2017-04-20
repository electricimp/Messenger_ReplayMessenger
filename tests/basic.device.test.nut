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


@include "https://raw.githubusercontent.com/electricimp/ConnectionManager/master/ConnectionManager.class.nut"
@include "https://raw.githubusercontent.com/electricimp/SpiFlashLogger/master/SPIFlashLogger.class.nut"
@include "https://raw.githubusercontent.com/electricimp/Serializer/develop/Serializer.class.nut"
@include "https://raw.githubusercontent.com/electricimp/MessageManager/develop/MessageManager.lib.nut"

// @include "github:electricimp/ConnectionManager/ConnectionManager.class.nut"
// @include "github:electricimp/SPIFlashLogger/SPIFlashLogger.class.nut"
// @include "github:electricimp/Serializer/Serializer.class.nut"
// @include "github:electricimp/MessageManager/MessageManager.lib.nut@develop"

class BasicTests extends ImpTestCase {

    static MSG_COUNT = 100;
    static DATA_MSG_NAME  = "data";
    static INIT_MSG_NAME  = "init";
    static ERROR_MSG_NAME = "errors";

    _cm = null;
    _mm = null;
    _rm = null;
    _errors = null;

    _ConnectionManager = class {
        _errors = 0;
        _onConnect    = null;
        _isConnected  = null;
        _onDisconnect = null;

        constructor() {
            _isConnected = true;
        }

        function isConnected() {
            return _isConnected;
        }

        function log(str) {
            server.log(str);
        }

        function connect() {
            _isConnected = true;
            _onConnect && _onConnect();
        }

        function disconnect() {
            _isConnected = false;
            _onDisconnect && _onDisconnect(true);
        }

        function onConnect(callback) {
            _onConnect = callback;
        }

        function onDisconnect(callback) {
            _onDisconnect = callback;
        }
    }

    function setUp() {
        // Create ConnectionManager
        _cm = _ConnectionManager();

        // Create MessageManager
        local mmOptions = {
            "connectionManager" : _cm
        };
        _mm = MessageManager(mmOptions);
        _mm.onReply(function(msg, response) {
            _errors = response;
        }.bindenv(this));

        // Create ReplayMessenger
        local rmOptions = {
            "connectionManager" : _cm,
            "messageManager"    : _mm,
            "retryInterval"     : 1,
            "debug"             : false
        }
        _rm = ReplayMessenger(rmOptions);
        _rm.eraseAll();

        _rm.send(INIT_MSG_NAME, MSG_COUNT);
    }

    function testTempDisconnect() {
        local disconnectAt = MSG_COUNT / 4;
        local connectAt = MSG_COUNT - disconnectAt;

        for (local i = 0; i < MSG_COUNT; i++) {
            if (i == disconnectAt) {
                _cm.disconnect();
            }

            if (i == connectAt) {
                _cm.connect();
            }

            _rm.send(DATA_MSG_NAME, i);
        }

        _rm.send(ERROR_MSG_NAME, null);

        return Promise(function(resolve, reject) {
            imp.wakeup(20, function() {
                assertEqual(0, _errors, "# of errors: " + _errors);
                resolve();
            }.bindenv(this))
        }.bindenv(this))
    }

    function tearDown() {
    }
}