# ReplayMessenger #

ReplayMessenger is a library for asynchronous bidirectional agent to device communication.

The library consists of two parts: the **base** part and the **extended** part.

The **base** part of the library supports the following features:
- Sending/receiving of named messages
- Automatical acknowledgment of messages
- Manual asynchronous acknowledgment of messages with optional reply data
- Manual disacknowledgement of messages

The **extended** part additionally supports the following features:
- Persistence of unsent and unacknowledged messages and resending them
- Immediate persistence of critically important messages until they sent and acknowledged

**To add the base part of this library to your project, add** `#require "ReplayMessenger.base.lib.nut:1.0.0"` **to the top of your device code**.

**To add the extended part of this library to your project, add** `#require "ReplayMessenger.extended.lib.nut:1.0.0"` **to the top of your device code**.

**NOTE1**: The **extended** part of the library requires the **base** part to be included firstly.

**NOTE2**: The **extended** part of the library can be used only on the imp device as the agent doesn't provide any persistent storage.

Every message of the **extended** lib part has a parameter called `importance`. This parameter can be one of the three different values:
- `RM_IMPORTANCE_LOW` - (default) the message will not be persisted and resent
- `RM_IMPORTANCE_HIGH` - the message will be persisted if it hasn't been sent successfully or hasn't been acknowledged within the timeout period
- `RM_IMPORTANCE_CRITICAL` - the message will be persisted immediately

Every persisted message will be resent (if resending is confirmed by the application). Every persisted message is removed from the storage once it is sent and acknowledged.

The API is briefly described in the comments of the code (please, see [the base part](./ReplayMessenger.base.lib.nut) and [the extended part](./ReplayMessenger.extended.lib.nut)).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory.

## License ##

This library is licensed under the [MIT License](./LICENSE).
