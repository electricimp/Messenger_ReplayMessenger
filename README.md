# ReplayMessenger #

ReplayMessenger is a library for asynchronous bidirectional agent to device communication.

ReplayMessenger contains a set of two libraries: the base library **ReplayMessenger** and, if persistent storage features are desired, the **ReplayMessengerPersist** library. 

The **ReplayMessenger** library supports the following features:
- Sending/receiving of named messages
- Acknowledgment of messages
- Manual asynchronous acknowledgment of messages with optional reply data
- Manual dis-acknowledgement of messages

The **ReplayMessengerPersist** library adds the following features:
- Persistence of unsent and unacknowledged messages  
- Resending of persisted messages
- Immediate persistence of critically important messages until they are both sent and acknowledged

The **ReplayMessengerPersist** library is only supported on the device, where messages can be persisted in SPI flash storage. **ReplayMessengerPersist** extends the base **ReplyMessenger** library, therefore **ReplyMessenger** must be included before and in addition to the **ReplayMessengerPersist** library. 

**To include the ReplayMessenger library in your project, add** `#require "ReplayMessenger.lib.nut:0.1.0"` **to the top of your code**.

or 

**To include the ReplayMessengerPersist library in your project, add the following to the top of your device code:** 

```
#require "ReplayMessenger.lib.nut:0.1.0"
#require "ReplayMessengerPersist.device.lib.nut:0.1.0"
``` 

Every message of the **ReplayMessengerPersist** library part has a parameter called `importance`. This parameter can be one of the three different values:
- `RM_IMPORTANCE_LOW` - (default) the message will not be persisted and resent
- `RM_IMPORTANCE_HIGH` - the message will be persisted if it hasn't been sent successfully or hasn't been acknowledged within the timeout period
- `RM_IMPORTANCE_CRITICAL` - the message will be persisted immediately

Every persisted message will be resent (if resending is confirmed by the application). Every persisted message is removed from the storage once it is sent and acknowledged.

The API is briefly described in the comments of the code (please, see [ReplayMessenger](./ReplayMessenger.lib.nut) and [ReplayMessengerPersist](./ReplayMessengerPersist.device.lib.nut)).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory.

## License ##

This library is licensed under the [MIT License](./LICENSE).
