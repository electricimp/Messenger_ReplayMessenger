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

class CustomTestCase extends ImpTestCase {
    logger = null;
    rm = null;
    cm = null;

    function setUp() {
        logger = SPIFlashLogger(SFL_START_TEST, SFL_END_TEST);
        logger.erase();

        cm = ConnectionManager();
        cm.connect();

        rm = ReplayMessenger(logger, cm, {"ackTimeout" : ACK_TIMEOUT_TEST});
    }

    function tearDown() {
        // Cleanup RM safely
        return Promise(function(resolve, reject) {
            local tryToCleanup = null;

            tryToCleanup = function() {
                if (rm._readingInProcess) {
                    imp.wakeup(0.1, tryToCleanup);
                    return;
                }
                rm._sentQueue = {};
                rm._eraseQueue = {};
                rm._persistMessagesQueue = [];
                rm._spiFL.erase();
                resolve();
            }.bindenv(this);

            tryToCleanup();
        }.bindenv(this));
    }
}
