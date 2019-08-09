# Messenger 0.1.0 + ReplayMessenger 0.1.0 #

The Messenger library provides basic asynchronous bidirectional agent and device communication. It includes the following features:

- Sending/receiving of named messages.
- Acknowledgment of messages.
- Manual asynchronous acknowledgment of messages with optional reply data.
- Manual dis-acknowledgement of messages.

The ReplayMessenger library can be used alongside Messenger if persistent storage and retry features are required. It adds the following features:

- Persistence of unsent and unacknowledged messages.
- Resending of persisted messages.
- Immediate persistence of critically important messages until they are both sent and acknowledged.

ReplayMessenger is only supported on the device, where messages are able to be persisted in SPI flash storage. ReplayMessenger extends the base Messenger class, therefore Messenger must be included *before* and in addition to ReplayMessenger, as shown in the library inclusion statements below.

**To include the Messenger library in your project, add the following at the top of your agent and device code:**

```
#require "Messenger.lib.nut:0.1.0"
```

**To include the ReplayMessenger library in your project, add the following at the top of your device code:**

```
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.1.0"
#require "ReplayMessenger.device.lib.nut:0.1.0"
```

## Messenger Class Usage ##

In the following discussion, the term ‘partner’ refers to either the agent or the device: the device’s partner is its agent; the agent’s partner is the device.

### Constructor: Messenger(*[options]*) ###

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *options* | Table | No | See [**Messenger Options**](#messenger-options) below for details and default values |

#### Messenger Options ####

| Key | Data&nbsp;Type | Description |
| ---- | --- | --- |
| *ackTimeout* | Integer | The time after which an unacknowledged message is considered to have failed to be sent. Default: 10s |
| *maxRate* | Integer | The maximum message send rate, ie. the maximum number of messages the library allows to be sent in a second. If the application exceeds the limit, the [*onFail* callback](#the-onfail-callback) is triggered. Default: 10 messages/s<br />**Note** Please don’t change this value unless absolutely necessary |
| *firstMsgId* | Integer | An initial value for the auto-incrementing message ID. Default: 0 |
| *debug* | Boolean | A flag that enables or disables extended logging for debugging purposes. Default: `false` |

#### Example ####

```squirrel
// Initialize using the default settings
local msngr = Messenger();
```

## Messenger Class Methods ##

### send(*name[, data][, ackTimeout][, metadata]*) ###

This method sends a named message to the partner and returns an instance of the [Messenger.Message](#messengermessage-class-usage) class.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The name of the message to be sent |
| *data* | Any serializable type | No | The data to be sent. It can be a basic Squirrel type (integer, float, boolean or string) or an array or table, but it must be [a serializable](https://developer.electricimp.com/resources/serialisablesquirrel). Default: `null` |
| *ackTimeout* | Integer | No | An individual message timeout. Default: No timeout |
| *metadata* | Any serializable type | No | Message metadata. It **will not** be sent to the partner. Default: `null` |

#### Return Value ####

[Messenger.Message](#messengermessage-class-usage) instance.

#### Example ####

```squirrel
// Turn on the lights
msngr.send("lights", true);
```

### on(*name, onMsg*) ###

This method registers a name-specific message callback. The callback function is triggered when a message with the specified name is received from the partner.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The name of the message with which the registered function will be associated |
| *onMsg* | Function | Yes | A callback that is triggered when a message with the specified name is received. See [**The onMsg Callback**](#the-onmsg-callback), below, for the function’s details |

#### Return Value ####

Nothing.

#### The onMsg Callback ####

Your *onMsg* function should include the following parameters:

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | Table | Yes | The received message’s payload. See [**Message Payload Table**](#message-payload-table), below, for details |
| *customAck* | Function | Yes | A function that your *onMsg* code can call to customize message acknowledgement. This function takes no parameters. See [**Custom Acknowledgement**](#custom-acknowledgement), below, for details |

#### Custom Acknowledgement ####

If your *onMsg* callback code does not call the function it receives through its *customAck* parameter, an automatic message acknowledgement will be sent by the library to the partner. However, if you wish to add data to and/or delay the message acknowledgement, your code should call the *customAck* function and store the return value, itself a function, that can be called later when you wish to acknowledge the original message.

When called, the acknowledgement function sends an acknowledgement message to the partner. If you wish to add data to this acknowledgement, pass it into the acknowledgement function. The data can be any serializable type and defaults to  `null`. The acknowledgement function does not return a value.

Here is a typical custom acknowledgement flow:

1. Your application registers an *onMsg* callback for a given name.
2. The agent or device receives a message of that name from its partner.
3. The library executes your *onMsg* callback with the message payload and a custom acknowledgement function.
4. Your *onMsg* callback calls the received custom acknowledgement function to prevent auto-acknowledgement.
5. Your *onMsg* callback stores the returned acknowledgement function.
6. Your *onMsg* callback processes the message payload as required by the application.
7. Your *onMsg* callback triggers a function or flow that acknowledges the message by calling the stored acknowledgement function.

This flow is illustrated in the example below.

#### Example ####

**Note** This example is meant to illustrate usage and incorporates variables that are defined outside of the scope of these few lines.

```squirrel
// Automatically Acknowledge Messages
function lxHandler(payload, customAck) {
    // Do NOT call the received custom acknowledgement function
    // to ensure that automatic message acknowledgement takes place
    local lightsOn = payload.data;
    (lightsOn) ? led.write(ON) : led.write(OFF);
}

// Create Custom Acknowledgement Messages
function tempHandler(payload, customAck) {
    // Call the received custom acknowledgement function to prevent
    // auto-acknowledgement, and store the returned acknowledgement function
    local ack = customAck();

    // Take a reading
    tempHumid.read(function(result) {
        if ("error" in result) {
            server.error(result.error);
            // Acknowledge the message by calling the stored acknowledgement function
            // The reading failed, so don't pass in a data value
            ack();
            return;
        }

        // Acknowledge the message by calling the stored acknowledgement function
        // Reading was successful, so pass in the reading result
        ack(result);
    }.bindenv(this));
}

// Register 'onMsg' callbacks for given names
msngr.on("lights", lxHandler.bindenv(this));
msngr.on("temp", tempHandler.bindenv(this));
```

### defaultOn(*onMsg*) ###

This method sets the default callback, which will be executed when a received message’s name doesn't match any of the name-specific handlers registered with [*on*](#onname-onmsg).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *onMsg* | Function | Yes | Callback that is triggered when a message without an *on* handler is received. See [**onMsg Callback**](#the-onmsg-callback), above, for the function’s details |

#### Return Value ####

Nothing.

#### Example ####

```squirrel
function onUnknownMsg(payload, customAck) {
    local data = payload.data;

    // Log message name and payload data
    server.error("Received unknown message: " + payload.name);
    if (typeof data == "table" || typeof data == "array") {
        server.log(http.jsonencode(data));
    } else {
        server.log(data);
    }

    // Allow automatic msg ack, so msg is not retried.
}

msngr.defaultOn(onUnknownMsg.bindenv(this));
```

### onAck(*onAckCallback*) ###

This method registers a global callback that will be executed when a message is acknowledged.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *onAckCallback* | Function | Yes | Callback that is triggered when a message is acknowledged. See [**The onAck Callback**](#the-onack-callback), below, for the function’s details |

#### Return Value ####

Nothing.

#### The onAck Callback ####

Your *onAck* function should include the following parameters:

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger.Message](#messengermessage-class-usage) instance | Yes | The [Messenger.Message](#messengermessage-class-usage) instance created and returned when the message was sent |
| *ackData* | Any serializable type | Yes | The data sent in the partner’s [custom acknowledgement](#custom-acknowledgement), or `null` if no data was sent |

#### Example ####

```squirrel
function onAck(message, ackData) {
    // Store message info in variables
    local payload = message.payload;
    local id = payload.id;
    local name = payload.name;
    local msgData = payload.data;
    local metadata = message.metadata;

    // Log message info
    server.log("Received ack for message " + name + " with id: " + id);

    // Log message ack data if any
    if (ackData != null) server.log(ackData);

    // TODO Create switch statement to handle ACKs for specific messages based on id, name, data or metadata
}

msngr.onAck(onAck.bindenv(this));
```

### onFail(*onFailCallback*) ###

This method registers a global callback that will be executed when message transmission was not acknowledged, ie. the message is not considered to have been sent.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *onFailCallback* | Function | Yes | Callback that is triggered when a message fails. See [**The onFail Callback**](#the-onfail-callback), below, for the function’s details |

#### Return Value ####

Nothing.

#### The onFail Callback ####

Your *onFail* function should include the following parameters:

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger.Message](#messengermessage-class-usage) instance | Yes | The [Messenger.Message](#messengermessage-class-usage) instance created and returned when message was sent |
| *reason* | String | Yes | A description of the message failure |

#### Example ####

```squirrel
function onFail(message, reason) {
    // Store message info in variables
    local payload = message.payload;
    local id = payload.id;
    local name = payload.name;
    local msgData = payload.data;
    local metadata = message.metadata;

    // Log message info
    server.error("Message " + name + " with id " + id + " send failure reason: " reason);

    // TODO: Create switch statement to handle failures for specific messages based on id, name, data or metadata
}

msngr.onFail(onFail.bindenv(this));
```

## Messenger.Message Class Usage ##

Messages should only be created by calling the [*Messenger.send()*](#sendname-data-acktimeout-metadata) or [*ReplayMessenger.send()*](#sendname-data-importance-acktimeout-metadata) methods, never by your application. These methods will return an instance of this class. The message instance will also be passed to the global [*onAck*](#onackonackcallback) and [*onFail*](#onfailonfailcallback) callbacks, and [ReplayMessenger's *confirmResend()*](#confirmresendconfirmresendcallback) function.

#### Public Properties ####

The Message class doesn’t contain any getters and setters. Instead it provides public properties that may you may wist to access directly. Please see the [*onAck()*](#onackonackcallback) and [*onFail()*](#onfailonfailcallback) examples for details.

| Property | Data&nbsp;Type | Value |
| --- | --- | --- |
| *payload* | Table | A table that is sent between partners when a send method is called. See [**Message Payload Table**](#message-payload-table) below for table details |
| *metadata* | Any serializable type | Optional application-defined data containing additional message properties. This data **will not** be sent to the partner, but can be accessed when the [*onAck*](#onackonackcallback) or [*onFail*](#onfailonfailcallback) callbacks are triggered |

#### Message Payload Table ####

| Key | Data&nbsp;Type | Description |
| --- | --- | --- |
| *id* | Integer | A message identifier, an auto-incrementing value |
| *name* | String | The name of the message |
| *data* | Any serializable type | The message data |

## ReplayMessenger Class Usage ##

ReplayMessenger extends Messenger by adding features for resending and persisting messages. ReplayMessenger also depends upon the [SpiFlashLogger](https://github.com/electricimp/SpiFlashLogger) and [ConnectionManager](https://github.com/electricimp/ConnectionManager) libraries.

### Constructor: ReplayMessenger(*spiFlashLogger, connectionManager[, options]*) ###

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *spiFlashLogger* | A [SpiFlashLogger](https://github.com/electricimp/SpiFlashLogger) instance | Yes | Used to store messages in the imp’s SPI Flash. Must be instantiated from  library version 2.2.0 or above |
| *connectionManager* | A [ConnectionManager](https://github.com/electricimp/ConnectionManager) instance | Yes |  Used to check the connection state. Must be instantiated from library version 3.1.0 or above |
| *options* | Table | No | Settings that override default behaviors. See [**ReplayMessenger Options**](#replaymessenger-options), below, for details and defaults values |

#### ReplayMessenger Options ####

| Key | Data&nbsp;Type | Description |
| ---- | --- | --- |
| *ackTimeout* | Integer | The time after which an unacknowledged message is considered to have failed to be sent. Default: 10s |
| *maxRate* | Integer | The maximum message send rate, ie. the maximum number of messages the library allows to be sent in a second. If the application exceeds the limit, the *onFail* callback is triggered. Default: 10 messages/s<br />**Note** Please don’t change this value unless absolutely necessary
| *firstMsgId* | Integer | An initial value for the auto-incrementing message ID. When the default is used, the library will use persisted messages to determine a safe starting value. When overriding the default, the application must define this value in such a way that it will not interfere with the currently persisted messages. Default: 0, or value based on persisted message IDs |
| *resendLimit* | Integer | The maximum number of messages to queue at any given time when replaying. Default: 20 |
| *debug* | Boolean | A flag that enables or disables extended logging for debugging purposes. Default: `false` |

#### Example ####

```squirrel
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.1.0"
#require "ReplayMessenger.device.lib.nut:0.1.0"

local sfl = SPIFlashLogger();
local cm  = ConnectionManager({ "retryOnTimeout" : false });
local rm  = ReplayMessenger(sfl, cm);
```

## ReplayMessenger Class Methods ##

**All** methods documented in the [Messenger Class Methods](#messenger-class-methods) section above are also available to ReplayMessenger instances, with the exception of one minor update to the [*send()*](#sendname-data-importance-acktimeout-metadata) method and an additional method, [*confirmResend()*](#confirmresendconfirmresendcallback).

### send(*name[, data][, importance][, ackTimeout][, metadata]*) ###

This method sends a named message to the partner and returns an instance of the [Messenger.Message](#messengermessage-class-usage) class.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The name of the message to be sent |
| *data* | Any serializable type | No | The data to be sent. It can be a basic Squirrel type (integer, float, boolean or string) or an array or table, but it must be [a serializable](https://developer.electricimp.com/resources/serialisablesquirrel). Default: `null` |
| *importance* | Integer | No | A message priority rating. See [**Message Priority**](#message-priority), below. Default: *RM_IMPORTANCE_LOW* |
| *ackTimeout* | Integer | No | An individual message timeout. Default: No timeout |
| *metadata* | Any serializable type | No | Message metadata. It **will not** be sent to the partner. Default: `null` |

#### Message Priority ####

Every message created by this method has an additional property called *importance* which takes one of the three following values:

- *RM_IMPORTANCE_LOW* &mdash; The message will not be persisted and resent. This is the default.
- *RM_IMPORTANCE_HIGH* &mdash; The message will be persisted if it hasn’t been sent successfully or hasn’t been acknowledged within the timeout period.
- *RM_IMPORTANCE_CRITICAL* &mdash; The message will be persisted immediately.

Every persisted message will be resent if this is confirmed by the application. Every persisted message is removed from the storage once it has been sent and acknowledged.

#### Return Value ####

[Messenger.Message](#messengermessage-class-usage) class instance.

#### Example ####

```squirrel
// Turn on the lights
rm.send("lights", true, RM_IMPORTANCE_HIGH);
```

### confirmResend(*confirmResendCallback*) ###

This method sets a global callback that will be triggered when ReplayMessenger is about to replay a persisted message. This allows the application to decide whether the message should be resent or dropped (and thus removed from storage).


The callback function should return `true` to confirm that the message should be resent, or `false` to drop the message (and remove it from storage).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *confirmResendCallback* | Function | Yes | Callback that is triggered when a message is replayed after it has been persisted. See [**The confirmResend Callback**](#the-confirmresend-callback), below, for the function’s details |

#### Return Value ####

Nothing.

#### The confirmResend Callback ####

Your *confirmResend* function should include the following parameters:

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger.Message](#messengermessage-class-usage) instance | Yes | The [Messenger.Message](#messengermessage-class-usage) instance created and returned when the message was sent |

It should return `true` to confirm that the message should be resent, or `false` to cause the message to be dropped.

#### Examples ####

```squirrel
rm.confirmResend(function(message) {
    // Resend all messages until they are acknowledged
    return true;
});
```

```squirrel
rm.confirmResend(function(message) {
    // Filter for messages sending readings  
    if (message.payload.name == "reading") {
        local now = time();
        local dataTimestamp = message.payload.data.ts;

        // Drop messages that are older than 5min
        if (now - dataTimestamp > 300) return false;
    }

    // Resend all other messages
    return true;    
});
```

## Testing ##

Tests for the library are provided in the [tests](./tests) directory.

## License ##

These libraries are licensed under the [MIT License](./LICENSE).
