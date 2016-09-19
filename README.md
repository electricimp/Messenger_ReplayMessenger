# ImpPager

Library for reliable and resilient communication between imp devices and virtual imp agents. It wraps [ConnectionManager](https://github.com/electricimp/connectionmanager/tree/v1.0.1), [Bullwinkle](https://github.com/electricimp/Bullwinkle#bullwinklepackage) and [SpiFlashLogger](https://github.com/electricimp/SpiFlashLogger) libraries.

**To add this library to your project, copy and paste the source code to the top of your device code.**

## Constructor: ImpPager(*[conn], [logger]*)

Accepts two optional arguments: conn - instance of Bullwinkle and logger - SPIFlashLogger.

```squirrel

// Instantiate an Imp Pager
impPager <- ImpPager();
```

## Class Methods

### send(*messageName, [data]*)

Sends the message of messageName with actual data. The method returns nothing.

```squirrel
impPager <- ImpPager();

... 
impPager.send("data", data);
```

The method uses Bullwinkle.send method to send the data. It wraps the original message into and object that is sipplied with a unique incrementing message id:

| field | notes |
| ----- | ----- |
| id    | unique message id |
| raw   | original raw data sent to the partner |

To receive and ACK a message on the agent side, the standard Bullwinkle library can be used:

```squirrel
#require "bullwinkle.class.nut:2.3.1"

bull <- Bullwinkle();

bull.on("data", function(message, reply) {
	server.log("Data received: " + message.data.raw);
	reply("OK");
});
```

# License

The ImpPager library is licensed under the [MIT License](https://github.com/electricimp/thethingsapi/tree/master/LICENSE).