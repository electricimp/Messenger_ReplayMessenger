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
const SFL_END_TEST = 8192

// --- CommonTestCases:On.partner ---
const MESSAGE_NAME_START = "StartTest";

// --- Extended:ConfirmResendTest ---
// The number of the message which should be acked
const CONFIRM_RESEND_MSG_NUM_TO_ACK = 4;
const MESSAGE_NAME_CONFIRM_RESEND = "ConfirmResend";