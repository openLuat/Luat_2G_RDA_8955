--- 模块功能：MQTT客户端处理框架
-- @author openLuat
-- @module default.linkTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.20

module(...,package.seeall)

require"misc"
require"mqtt"
require"linkOutMsg"
require"linkInMsg"

local ready = false

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage linkTask.isReady()
function isReady()
    return ready
end

--启动MQTT客户端任务
sys.taskInit(
    function()
        while true do
            if not socket.isReady() then
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND",300000)
            end
            
            if socket.isReady() then
                local imei = misc.getImei()
                --创建一个MQTT客户端
                local mqttClient = mqtt.client(imei,600,"user","password")
                --阻塞执行MQTT CONNECT动作，直至成功
                if mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp") then
                    ready = true
                    --订阅主题
                    if mqttClient:subscribe("/v1/device/"..misc.getImei().."/set",1) then
                        linkOutMsg.init()
                        --循环处理接收和发送的数据
                        while true do
                            if not linkInMsg.proc(mqttClient) then log.error("linkTask.linkInMsg.proc error") break end
                            if not linkOutMsg.proc(mqttClient) then log.error("linkTask.linkOutMsg proc error") break end
                        end
                        linkOutMsg.unInit()
                    end
                    ready = false
                end
                --断开MQTT连接
                mqttClient:disconnect()
                sys.wait(5000)
            else
                --进入飞行模式，20秒之后，退出飞行模式
                net.switchFly(true)
                sys.wait(20000)
                net.switchFly(false)
            end
        end
    end
)
