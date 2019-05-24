--- testMqtt
-- @module testMqtt
-- @author ??
-- @license MIT
-- @copyright openLuat.com
-- @release 2017.10.24
require "mqtt"
module(..., package.seeall)

-- 这里请填写修改为自己的IP和端口
local host, port = "lbsmqtt.airm2m.com", 1884

socket.setSendMode(1)

-- 测试MQTT的任务代码
sys.taskInit(function()
    while true do
        while not socket.isReady() do sys.wait(1000) end
        local mqttc = mqtt.client(misc.getImei(), 300, "user", "password")
        while not mqttc:connect(host, port) do sys.wait(2000) end
        if mqttc:subscribe(string.format("/device/%s/req", misc.getImei())) then
            if mqttc:publish(string.format("/device/%s/report", misc.getImei()), "test publish " .. os.time()) then
                while true do
                    local r, data, param = mqttc:receive(120000, "pub_msg")
                    if r then
                        log.info("这是收到了服务器下发的消息:", data.payload or "nil")
                    elseif data == "pub_msg" then
                        log.info("这是收到了订阅的消息和参数显示:", data, param)
                        mqttc:publish(string.format("/device/%s/resp", misc.getImei()), "response " .. param)
                    elseif data == "timeout" then
                        log.info("这是等待超时主动上报数据的显示!")
                        mqttc:publish(string.format("/device/%s/report", misc.getImei()), "test publish " .. os.time())
                    else
                        break
                    end
                end
            end
        end
        mqttc:disconnect()
    end
end)

-- 测试代码,用于发送消息给socket
sys.taskInit(function()
    while true do
        sys.publish("pub_msg", "11223344556677889900AABBCCDDEEFF" .. os.time())
        sys.wait(180000)
    end
end)
