--- testSocket
-- @module testSocket
-- @author AIRM2M
-- @license MIT
-- @copyright openLuat.com
-- @release 2018.10.27
require "socket"
module(..., package.seeall)

-- 此处的IP和端口请填上你自己的socket服务器和端口
local ip, port = "180.97.80.55", 12415

socket.setSendMode(1)

-- tcp test
sys.taskInit(function()
    local r, s, p
    
    while true do
        while not socket.isReady() do sys.wait(1000) end
        local c = socket.tcp()
        while not c:connect(ip, port) do sys.wait(2000) end
        while true do
            r, s, p = c:recv(120000, "pub_msg")
            if r then
                log.info("这是收到了服务器下发的消息:", s)
            elseif s == "pub_msg" then
                log.info("这是收到了订阅的消息和参数显示:", s, p)
                if not c:send(p) then break end
            elseif s == "timeout" then
                log.info("这是等待超时发送心跳包的显示!")
                if not c:send("\0") then break end
            else
                log.info("这是socket连接错误的显示!")
                break
            end
        end
        c:close()
    end
end)

-- 测试代码,用于发送消息给socket
sys.taskInit(function()
    while true do
        sys.publish("pub_msg", "11223344556677889900AABBCCDDEEFF" .. os.time())
        sys.wait(180000)
    end
end)
