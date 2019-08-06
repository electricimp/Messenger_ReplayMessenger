# Messenger & ReplayMessenger #

The **Messenger** library contains the basic features for asynchronous bidirectional agent and device communication. The **ReplayMessenger** library can be added if persistent storage and retry features are desired.

**Messenger** library supports the following features:
- Sending/receiving of named messages
- Acknowledgment of messages
- Manual asynchronous acknowledgment of messages with optional reply data
- Manual dis-acknowledgement of messages

**ReplayMessenger** library adds the following features:
- Persistence of unsent and unacknowledged messages  
- Resending of persisted messages
- Immediate persistence of critically important messages until they are both sent and acknowledged

**ReplayMessenger** is only supported on the device, where messages can be persisted in SPI flash storage. **ReplayMessenger** extends the base **Messenger** library, therefore **Messenger** must be included before and in addition to the **ReplayMessenger** library. 

**To include Messenger library in your project, add the following to the top of your code** 

```
#require "Messenger.lib.nut:0.1.0"
```

or 

**To include ReplayMessenger library in your project, add the following to the top of your device code:** 

```
#require "Messenger.lib.nut:0.1.0"
#require "ReplayMessenger.device.lib.nut:0.1.0"
``` 

## Messenger Usage ##

### Constructor: Messenger(*[options]*) ###

Calling the Messenger constructor creates a new Messenger instance. An optional *options* table can be passed into the constructor to override default behaviors. 

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *options* | Table | No | An optional table with settings that override default behaviors. See [Options Table](#options-table) below for details. Default: `{}` |

#### Options Table ####

| Key | Data&nbsp;Type | Description |
| ---- | --- | --- |
| *debug* | Boolean | The flag that enables debug library mode, which turns on extended logging. Default: `false` |
| *ackTimeout* | Integer | Changes the default timeout required before a message is considered failed (to be acknowledged). Default: 10s |
| *maxRate* | Integer | Maximum message send rate, which defines the maximum number of messages the library allows to send per second. If the application exceeds the limit, the *onFail* callback is triggered. Default: 10 messages/s<br />**Note** please don’t change the value unless absolutely necessary |
| *firstMsgId* | Integer | Initial value for the auto-incrementing message ID. Default: 0 |

#### Example ####

```squirrel
// Initialize using default settings
local msngr = Messenger();
```

## Messenger Methods ##

### send(*name[, data][,ackTimeout][,metadata]*) ###

This method sends a named message to the partner side and returns an instance of [Messenger's Message](#messengermessage-usage) class. The *data* parameter can be a basic Squirrel type (`1`, `true`, `"A String"`) or more complex data structures such as an array or table, but it must be [a serializable Squirrel value](https://developer.electricimp.com/resources/serialisablesquirrel).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | Name of the message to be sent. |
| *data* | Any serializable type | No | Data to be sent to the partner. Default: `null` |
| *ackTimeout* | Integer | No | Individual message timeout. Default: `null` |
| *metadata* | Any serializable type | No | Message metadata. This data **WILL NOT** be sent to the partner. Default: `null` |

#### Return Value ####

A [Messenger.Message](#messengermessage-usage) class instance.

#### Example ####

```squirrel
// Turn on the lights
msngr.send("lights", true);
```

### on(*name, onMsg*) ###

This method sets a name-specific message callback. The callback function is triggered when a message with the specified name is received from the partner (agent/device).  

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The name of the message with which the registered handler will be associated. |
| *onMsg* | Function | Yes | Callback that is triggered when a message with the specified name is received. See [onMsg Callback](#onmsg-callback) below for function's details. |

#### Return Value ####

Nothing.

#### onMsg Callback ####

The application defined callback that is triggered when a message received from the partner.  

##### onMsg Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | Table | Yes | Payload of the message received. See [Messenger.Message Payload Table](#payload-table) for payload table details. |
| *customAck* | Function | Yes | A function that creates a custom acknowledgement function, when triggered in the **onMsg** callback it prevents the automatic message acknowledgement. See [customAck Callback](#customack-callback) for details. |

#### customAck Callback ####

If the **customAck** function is not triggered in the **onMsg** callback an automatic message acknowledgement will be sent to the partner. However, if you wish to add data or delay the message acknowledgement, then trigger the **customAck** function in your **onMsg** callback and store the return value, an **ack** function, that should be triggered when you wish to acknowledge the original message.

##### customAck Parameters #####

None.

##### customAck Return Value #####

A function to be called when the application is ready to acknowledge the message. See [ack Callback](#ack-callback) below for details.

#### ack Callback ####

A callback function that sends an acknowledgement back to partner. If you wish to add a custom reply data to the acknowledgement, pass the data into this function when triggering.

##### ack Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *data* | Any serializable type | No | Optional data to be sent in acknowledgement message to partner. Default: `null` |

##### ack Return Value #####

Nothing.

#### Example ####

**NOTE** This example is meant to illustrate usage and uses variables defined outside the scope of these few lines.  

```squirrel
// Automatically Acknowledge Message
function lxHandler(payload, customAck) {
    local lightsOn = payload.data;
    (lightsOn) ? led.write(ON) : led.write(OFF);
}

// Create Custom Acknowledgement Message
function tempHandler(payload, customAck) {
    // Delay acknowledgement until we can take a reading
    local ack = customAck();

    // Take a reading
    tempHumid.read(function(result) {
        if ("error" in result) {
            server.error(result.error);
            // Reading failed, send ack with no temp data
            ack();
            return;
        }

        // Reading successful, send ack with temp reading result
        ack(result);
    }.bindenv(this));
}

msngr.on("lights", lxHandler.bindenv(this));
msngr.on("temp", tempHandler.bindenv(this));
```

### defaultOn(*onMsg*) ###

This method sets the default handler which will be called when a message doesn't match any of the name-specific handlers registered with the **on** method. The callback function is triggered when a message is received from the partner.  

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *onMsg* | Function | Yes | Callback that is triggered when a message without an **on** handler is received. See [onMsg Callback](#onmsg-callback) for function's details. |

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

This method sets a global handler to be called when a message is acknowledged.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *onAckCallback* | Function | Yes | Callback that is triggered when a message is acknowledged. See [onAckCallback](#onackcallback) below for function's details. |

#### Return Value ####

Nothing.

#### onAckCallback ####

The application defined function that that is triggered when a message is acknowledged.  

##### onAckCallback Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger.Message](#messengermessage-usage) instance | Yes | The [Messenger.Message](#messengermessage-usage) instance created and returned when the message was sent. |
| *ackData* | Any serializable type | Yes | Data sent in partner's custom acknowledgement, or `null` if no data was sent. |

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

    // TODO: Create switch statement to handle acks for specific messages
} 

msngr.onAck(onAck.bindenv(this));
```

### onFail(*onFailCallback*) ###

This method sets a global handler to be called upon message failure.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *onFailCallback* | Function | Yes | Callback that is triggered when a message fails. See [onFailCallback](#onfailcallback) below for function's details. |

#### Return Value ####

Nothing.

#### onFailCallback ####

The application defined callback function that is triggered when a message fails.  

##### onFailCallback Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger.Message](#messengermessage-usage) instance | Yes | The [Messenger.Message](#messengermessage-usage) instance created and returned when message was sent. |
| *reason* | String | Yes | The description of the message failure. |

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

    // TODO: Create switch statement to handle failures for specific messages
} 

msngr.onFail(onFail.bindenv(this));
```

## Messenger.Message Usage ##

Messages should only be created by calling the **Messenger.send** or **ReplayMessenger.send** methods, never by a user's application. The send method will return an instance of this class. The message instance will also be passed to the global onAck and onFail callbacks.

### Public Properties ###

The Message class doesn't contain any getters, however there are a couple of public properties that may want to be accessed and used. See *onAck* and *onFail* method examples for details.

| Property Name | Data&nbsp;Type | Value | 
| --- | --- | --- |
| *payload* | Table | A table that is sent between partners when the send method is called. See [Payload Table](#payload-table) below for table details. |
| *metadata* | Any serializable type | Optional application defined data containing additional message properties. This data **WILL NOT** be sent to the partner, but can be accessed when the *onAck* or *onFail* handler are triggered. | 

#### Payload Table ####

| Key | Data&nbsp;Type | Description |
| --- | --- | --- | 
| *id* | Integer | Message identifier, an auto-incrementing integer |
| *name* | String | Name of message |
| *data* | Any serializable type | Message data |

## ReplayMessenger Usage ##

**ReplayMessenger** extends the **Messenger** class adding features for resending and persisting messages. **ReplayMessenger** also has dependencies on [**SPIFlashLogger**](https://github.com/electricimp/SpiFlashLogger) and [**ConnectionManager**](https://github.com/electricimp/ConnectionManager) libraries. 

### Constructor: ReplayMessenger(*spiFlashLogger, cm[, options]*) ###

Calling the **ReplayMessenger** constructor creates a new **ReplayMessenger** instance. 

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *spiFlashLogger* | Instance of spiFlashLogger | Yes | Instance of [spiFlashLogger library](https://github.com/electricimp/SpiFlashLogger) which will be used to store messages. Must include library v2.2.0 or above. |
| *connectionManager* | Instance of ConnectionManager | Yes | Instance of [ConnectionManager](https://github.com/electricimp/ConnectionManager) which will be used to check the connection state. Must include library v3.1.0 or above. |
| *options* | Table | No | An optional table with settings that override default behaviors. See [Options Table](#options-table) below for details. Default: `{}` |

#### ReplayMessenger Options Table ####

| Key | Data&nbsp;Type | Description |
| ---- | --- | --- |
| *debug* | Boolean | The flag that enables debug library mode, which turns on extended logging. Default: `false` |
| *ackTimeout* | Integer | Changes the default timeout required before a message is considered failed (to be acknowledged). Default: 10s |
| *maxRate* | Integer | Maximum message send rate, which defines the maximum number of messages the library allows to send per second. If the application exceeds the limit, the *onFail* callback is triggered. Default: 10 messages per second<br />**Note** please don’t change the value unless absolutely necessary |
| *firstMsgId* | Integer | Initial value for the auto-incrementing message ID. Default: 0 |
| *resendLimit* | Integer | Maximum number of messages to queue at any given time when "replaying". Default: 20 |

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

## ReplayMessenger Methods ##

*ALL* methods documented in [Messenger Methods](#messenger-methods) section above are also available to **ReplayMessenger** instances, with one minor update to the *send* method and an additional *confirmResend* method. 

### send(*name[, data][, importance][, ackTimeout][,metadata]*) ###

This method sends a named message to the partner side and returns an instance of [Messenger's Message](#messengermessage-usage) class. 

The *data* parameter can be a basic Squirrel type (`1`, `true`, `"A String"`) or more complex data structures such as an array or table, but it must be [a serializable Squirrel value](https://developer.electricimp.com/resources/serialisablesquirrel).

Every message created by this method has an additional parameter called `importance`. This parameter can be one of the three different values:
- `RM_IMPORTANCE_LOW` - (default) the message will not be persisted and resent
- `RM_IMPORTANCE_HIGH` - the message will be persisted if it hasn't been sent successfully or hasn't been acknowledged within the timeout period
- `RM_IMPORTANCE_CRITICAL` - the message will be persisted immediately

Every persisted message will be resent (if resending is confirmed by the application). Every persisted message is removed from the storage once it is sent and acknowledged.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | Name of the message to be sent. |
| *data* | Any serializable type | No | Data to be sent to the partner. Default: `null` |
| *data* | Any serializable type | No | Data to be sent to the partner. Default: RM_IMPORTANCE_LOW |
| *ackTimeout* | Integer | No | Individual message timeout. Default: `null` |
| *metadata* | Any serializable type | No | Message metadata. This data **WILL NOT** be sent to the partner. Default: `null` |

#### Return Value ####

A [Messenger.Message](#messengermessage-usage) class instance.

#### Example ####

```squirrel
// Turn on the lights
rm.send("lights", true, RM_IMPORTANCE_HIGH);
```

### confirmResend(*confirmResendCallback*) ###

This method sets a global callback to be called when **ReplayMessenger** is replaying a persisted message. The callback function should return `true` to confirm message resending or `false` to drop the message.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *confirmResendCallback* | Function | Yes | Callback that is triggered when a message is "replayed" after it has been persisted. |

#### Return Value ####

Nothing.

#### confirmResendCallback #### 

The callback that is triggered when **ReplayMessenger** is replaying a persisted message.

##### confirmResendCallback Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger.Message](#messengermessage-usage) instance | Yes | The [Messenger.Message](#messengermessage-usage) instance created and returned when the message was sent. |

##### confirmResendCallback Return Value #####

Boolean, `true` to confirm message resending or `false` to drop the message.

#### Example ####

```squirrel
rm.confirmResend(function(msg) {
    // Resend all messages until they are acknowledged
    return true;
});
```

## Testing ##

Tests for the library are provided in the [tests](./tests) directory.

## License ##

These libraries are licensed under the [MIT License](./LICENSE).
