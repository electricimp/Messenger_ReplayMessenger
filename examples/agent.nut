// Agent source code goes here

@include __PATH__ + "/../../MessageManager/MessageManager.lib.nut"

local mm = MessageManager()

local totalCount = 0
local received = array(totalCount, 100)

mm.on("init", function(msg, reply) {
    totalCount = msg.data
    received = array(totalCount, 0)
})

mm.on("name", function(msg, reply) {
    server.log("message received: " + msg.data)
    received[msg.data] += 1
    reply("Got it!")
})

mm.on("result", function(data, reply) {
    local errorCount = 0
    for (local i = 0; i < totalCount; i++) {
        if (received[i] == 0) {
            server.log("  !!! " + i + ": " + received[i])
            errorCount++
        }
    }
    server.log("Error count: " + errorCount)
})