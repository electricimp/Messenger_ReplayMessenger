# Messenger & ReplayMessenger #

**Messenger**, the base library used for asynchronous bidirectional agent to device communication, and **ReplayMessenger**, if persistent storage and retry features are desired.

The **Messenger** library supports the following features:
- Sending/receiving of named messages
- Acknowledgment of messages
- Manual asynchronous acknowledgment of messages with optional reply data
- Manual dis-acknowledgement of messages

The **ReplayMessenger** library adds the following features:
- Persistence of unsent and unacknowledged messages  
- Resending of persisted messages
- Immediate persistence of critically important messages until they are both sent and acknowledged

The **ReplayMessenger** library is only supported on the device, where messages can be persisted in SPI flash storage. **ReplayMessenger** extends the base **Messenger** library, therefore **Messenger** must be included before and in addition to the **ReplayMessenger** library. 

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

Calling the Messenger constructor creates a new Messenger instance. An optional table can be passed into the constructor (as *options*) to override default behaviors. *options* can contain any of the following keys:

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
| *data* | Any serializable type | No | Data to be sent. Default: `null` |
| *ackTimeout* | Integer | No | Individual message timeout. Default: `null` |
| *metadata* | Any serializable type | No | Message metadata. Default: `null` |

#### Return Value ####

A [Messenger's Message](#messengermessage-usage) class instance.

#### Example ####

```squirrel
// Turn on the lights
msngr.send("lights", true);
```

### on(*name, onMsg*) ###

This method sets the name-specific message callback. The callback function is triggered when a message with the specified name is received from the partner (agent/device).  

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The name of messages this callback will be used for or `null` to register as the default handler. |
| *onMsg* | Function | Yes | Callback that is triggered when a message with the specified name is received. See [onMsg Callback](#onmsg-callback) below for function's details. |

#### Return Value ####

Nothing.

#### onMsg Callback ####

The application defined callback that is triggered when a message received from the partner.  

##### onMsg Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | Table | Yes | Payload of the message received. See [Messenge'sr Message](#messengermessage-usage) for keys contained in a message's payload table. |
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
| *onMsg* | Function | Yes | Callback that is triggered when a message without an on handler is received. See [onMsg Callback](#onmsg-callback) for function's details. |

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
| *message* | A [Messenger's Message](#messengermessage-usage) instance | Yes | The [Messenger's Message](#messengermessage-usage) instance created and returned when message was sent. |
| *ackData* | Any serializable type | Yes | Data sent in partner's acknowledgement, or `null` if no data was sent. |

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

The application defined callback function that that is triggered when a message fails.  

##### onFailCallback Parameters #####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | A [Messenger's Message](#messengermessage-usage) instance | Yes | The [Messenger's Message](#messengermessage-usage) instance created and returned when message was sent. |
| *reason* | String | Yes | The error description. |

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

Messages should only be created by calling Messenger.send or ReplayMessenger.send methods, never by a user's application. The send method will return an instance of the Messenger's Message class. The message instance will also be passed to the global onAck and onFail callbacks.

### Public Properties ###

The Message class doesn't contain any getters, however there are a couple of public properties that may want to be accessed and used. See *onAck* and *onFail* method examples for details.

| Property Name | Type | Value | 
| --- | --- | --- |
| *payload* | Table | A table that is sent between partners when the send method is called. See [Payload Table](#payload-table) below for table details. |
| *metadata* | `null` or Table | An optional application defined table with additional message properties. This table **WILL NOT** be sent to the partner, but can be accessed when the *onAck* or *onFail* handler are triggered. | 

#### Payload Table ####

| Key | Value | 
| --- | --- | 
| *id* | Message identifier, an auto-incrementing integer |
| *name* | Name of message |
| *data* | Message data |

## ReplayMessenger Usage ##

### Constructor: ReplayMessenger(*[options]*) ###

Every message of the **ReplayMessenger** library part has a parameter called `importance`. This parameter can be one of the three different values:
- `RM_IMPORTANCE_LOW` - (default) the message will not be persisted and resent
- `RM_IMPORTANCE_HIGH` - the message will be persisted if it hasn't been sent successfully or hasn't been acknowledged within the timeout period
- `RM_IMPORTANCE_CRITICAL` - the message will be persisted immediately

Every persisted message will be resent (if resending is confirmed by the application). Every persisted message is removed from the storage once it is sent and acknowledged.

The API is briefly described in the comments of the code (please, see [Messenger](./Messenger.lib.nut) and [ReplayMessenger](./ReplayMessenger.device.lib.nut)).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory.

## License ##

This library is licensed under the [MIT License](./LICENSE).
