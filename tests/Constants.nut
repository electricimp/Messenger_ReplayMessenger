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

// --- AcknowledgingPartner ---
const MESSAGE_NAME_NO_ACK = "NoAck";
const MESSAGE_NAME_EMPTY_CUSTOM_ACK = "EmptyCustomAck";
const MESSAGE_NAME_CUSTOM_ACK = "CustomAck";
const MESSAGE_NAME_ACK = "AutoAck";

// --- Test message data ---
const MESSAGE_DATA_INT = 1234;
const MESSAGE_DATA_STRING = "MyString";
MESSAGE_DATA_TABLE <- {"first" : 1, "second" : 2};

// --- Test RM configuration ---
const ACK_TIMEOUT_TEST = 2;
// SPIFlashLogger start address
const SFL_START_TEST = 0;
// SPIFlashLogger end address
const SFL_END_TEST = 8192;

// --- CommonTestCases:On.partner ---
const MESSAGE_NAME_START = "StartTest";

// --- Extended:ConfirmResendTest ---
// The number of the message which should be acked
const CONFIRM_RESEND_MSG_NUM_TO_ACK = 4;
const MESSAGE_NAME_CONFIRM_RESEND = "ConfirmResend";
