--- testSocket
-- @module asyncSocket
-- @author AIRM2M
-- @license MIT
-- @copyright openLuat.com
-- @release 2018.10.27
require "socket"
module(..., package.seeall)

-- 此处的IP和端口请填上你自己的socket服务器和端口
local ip, port, c = "180.97.80.55", "12415"

-- 异步接口演示代码
local asyncClient
sys.taskInit(function()
    local recv_cnt, send_cnt = 0, 0
    while true do
        while not socket.isReady() do sys.wait(1000) end
        asyncClient = socket.tcp()
        while not asyncClient:connect(ip, port) do sys.wait(2000) end
        while asyncClient:asyncSelect(60, "ping") do end
        asyncClient:close()
    end
end)

-- 测试代码，用于异步发送消息
-- 这里演示如何用非线程发送数据
sys.timerLoopStart(function()
    if socket.isReady() then
        asyncClient:asyncSend("0123456789")
    end
end, 10000)

-- 测试代码，异步回调接收数据
sys.subscribe("SOCKET_RECV", function(id)
    if asyncClient.id == id then
        local data = asyncClient:asyncRecv()
        log.info("这是服务器下发数据:", #data, data:sub(1, 30))
    end
end)


sys.timerLoopStart(function()
    log.info("打印占用的内存:", _G.collectgarbage("count"))-- 打印占用的RAM
    log.info("打印可用的空间", rtos.get_fs_free_size())-- 打印剩余FALSH，单位Byte
end, 1000)
