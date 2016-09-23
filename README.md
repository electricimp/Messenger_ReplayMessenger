# ImpPager

The Library for reliable and resilient communication between imp devices and virtual imp agents. It wraps [ConnectionManager](https://github.com/electricimp/connectionmanager/tree/v1.0.1), [Bullwinkle](https://github.com/electricimp/Bullwinkle#bullwinklepackage) and [SpiFlashLogger](https://github.com/electricimp/SpiFlashLogger) libraries.

**To add this library to your project, copy and paste the source code to the top of your device code.**

## Class ImpPager.ConnectionManager

Extends [ConnectionManager](https://github.com/electricimp/connectionmanager/tree/v1.0.1) and overrides onConnect/onDisconnect methods to allow for multiple connect/disconnect handlers to be registered. 

**ImpPager.ConnectionManager should be used instead of [ConnectionManager](https://github.com/electricimp/connectionmanager/tree/v1.0.1). Only a single instance of ImpPager.ConnectionManager should be created per application.**

### Class Usage

#### Constructor: ImpPager.ConnectionManager(*[settings]*)

The ConnectionManager class can be instantiated with an optional table of settings that modify its behavior. The following settings are available:

| key               | default             | notes |
| ----------------- | ------------------- | ----- |
| startDisconnected | `false`             | When set to `true` the device immediately disconnects |
| stayConnected     | `false`             | When set to `true` the device will aggressively attempt to reconnect when disconnected |
| blinkupBehavior   | BLINK_ON_DISCONNECT | See below |
| checkTimeout      | 5                   | Changes how often the ConnectionManager checks the connection state (online / offline). |
| sendTimeout       | 1                   | Timeout for server.setsendtimeoutpolicy. It's recommended that the timeout is a nonzero value, but still small. This will help to avoid TCP buffer overflow and accidental device disconnect issues. |
| sendBufferSize    | 8096                | The value passed to the imp.setsendbuffersize. **NOTE: We've found setting the buffer size to 8096 to be very helpful in many applications using the ConnectionManager class, though your application may require a different buffer size.** |

```squirrel
cm <- ImpPager.ConnectionManager({
    "blinkupBehavior"  : ConnectionManager.BLINK_ALWAYS,
    "stayConnected"    : true,
    "sendTimeout"      : 1,
    "sendBufferSeze"   : 8096
});

```

### Class Methods

#### onDisconnect(callback)

The *onDisconnect* method adds a callback method to the onDisconnect event. The onDisconnect event will fire every time the connection state changes from online to offline, or when the ConnectionManager's *disconnect* method is called (even if the device is already disconnected).

*The callback method takes a single parameter - `expected` - which is `true`when the onDisconnect event fired due to the ConnectionManager's disconnect method being called, and `false` otherwise (an unexpected state change from connected to disconnected).*

```squirrel
cm.onDisconnect(function(expected) {
    if (expected) {
        // log a regular message that we disconnected as expected
        cm.log("Expected Disconnect");
    } else {
        // log an error message that we unexpectedly disconnected
        cm.error("Unexpected Disconnect");
    }
});
```

**NOTE: a callback is added as a weak reference to the function.**

#### onConnect(callback)

The *onConnect* method adds a callback method to the onConnect event. The onConnect event will fire every time the connection state changes from offline to online, or when the ConnectionManager's *connect* method is called (even if the device is already connected).

*The callback method takes zero parameters.*

```squirrel
cm.onConnect(function() {
    // Send a message to the agent indicating that we're online
    agent.send("online", true);
});
```

**NOTE: a callback is added as a weak reference to the function.**

## Class ImpPager

The main library class. There may be multiple isntances of the class created by application.

### Constructor: ImpPager(*connectionManager, [bullwinkle], [spiFlashLogger], [debug]*)

Accepts two optional arguments:
- connectionManager - instance of ImpPager.ConnectionManager class that extends [ConnectionManager](https://github.com/electricimp/connectionmanager/tree/v1.0.1).
- bullwinkle - instance of [Bullwinkle](https://github.com/electricimp/Bullwinkle#bullwinklepackage). If null or not specified, is created by the ImpPager constructor with "messageTimeout" set to IMP_PAGER_MESSAGE_TIMEOUT (=1).
- spiFlashLogger - instance of [SpiFlashLogger](https://github.com/electricimp/SpiFlashLogger)
- debug - the flag that controlls library debug output. Defaults to false.


```squirrel
// Instantiate an Imp Pager
impPager <- ImpPager(cm, null, null, false);
```

### Class Methods

#### send(*messageName, [data]*)

Sends the message of messageName with actual data. The method returns nothing.

```squirrel
impPager <- ImpPager();
... 
impPager.send("data", data);
```

The method uses Bullwinkle.send method to send the data. So it may be received by the Bullwinkle on the agent side:

```squirrel
#require "bullwinkle.class.nut:2.3.1"

bull <- Bullwinkle();

bull.on("data", function(message, reply) {
	server.log("Data received: " + message.data);
});
```

# License

The ImpPager library is licensed under the [MIT License](https://github.com/electricimp/thethingsapi/tree/master/LICENSE).