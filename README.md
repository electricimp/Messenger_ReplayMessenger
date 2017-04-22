# ReplayMessenger

The Library for reliable and resilient communication between imp devices and virtual 
imp agents. It wraps 
[ConnectionManager](https://github.com/electricimp/connectionmanager/tree/v1.0.1), 
[MessageManager](https://github.com/electricimp/MessageManager) and 
[SpiFlashLogger](https://github.com/electricimp/SpiFlashLogger) libraries.

**To add this library to your project, add** 
`#require "ReplayMessenger.device.lib.nut:1.0.0"` 
**to the top of your device code.**

## Class ReplayMessenger

The main library class. There may be multiple instances of the class created by application.

### Constructor: ReplayMessenger(*options*)

Calling the ReplayMessenger constructor creates a new ReplayMessenger instance. 
An optional table can be passed into the constructor (as *options*) to override 
default behaviours. *options* can contain any of the following keys:

| Key | Data Type | Default Value | Description |
| ----- | -------------- | ------------------ | --------------- |
| *debug* | Boolean | `false` | The flag that enables debug library mode, which turns on extended logging |
| *retryInterval* | Integer | 0 | Changes the default timeout parameter passed to the [retry](#mmanager_retry) method |
| *messageTimeout* | Integer | 10 | Changes the default timeout required before a message is considered failed (to be acknowledged or replied to) |
| *connectionManager* | [ConnectionManager](https://github.com/electricimp/ConnectionManager) | `null` | Optional instance of the [ConnectionManager](https://github.com/electricimp/ConnectionManager) library that helps ReplayManager to track the connectivity status |
| *MessageManager* | [MessageManager](https://github.com/electricimp/ConnectionManager) | `null` | Optional instance of the [MessageManager](https://github.com/electricimp/MessageManager) library that helps ReplayManager to exchange data between device and agent |
| *spiFlashLogger* | [SPIFlashLogger](https://github.com/electricimp/ConnectionManager) | `null` | Optional instance or array of instances of the [SPIFlashLogger](https://github.com/electricimp/SPIFlashLogger) library that helps ReplayManager to persist some messenger on a flash or a memory |


### Class Methods

#### send(*messageName, [data]*)

Sends the message of messageName with actual data. The method returns nothing.

```squirrel
rm <- ReplayMessenger();
... 
rm.send("data", data);
```

# License

The ReplayMessenger library is licensed under the [MIT License](https://github.com/electricimp/thethingsapi/tree/master/LICENSE).