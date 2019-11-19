--- 模块功能：MQTT客户端处理框架
-- @author openLuat
-- @module mqtt.mqttTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

require"misc"
require"mqtt"
require"mqttOutMsg"
require"mqttInMsg"

local ready = false

--[[
TCP协议发送数据时，数据发送出去之后，必须等到服务器返回TCP ACK包，才认为数据发送成功，在网络较差的情况下，这种ACK确认就会导致发送过程很慢。
从而导致用户程序后续的AT处理逻辑一直处于等待状态。例如执行AT+CIPSEND动作发送一包数据后，接下来要执行AT+QTTS播放TTS，但是CIPSEND一直等了1分钟才返回SEND OK，
这时AT+QTTS就会一直等待1分钟，可能不是程序中想看到的。
此时就可以设置为快发模式，AT+CIPSEND可以立即返回一个结果，此结果表示“数据是否被缓冲区所保存”，从而不影响后续其他AT指令的及时执行

AT版本可以通过AT+CIPQSEND指令、Luat版本可以通过socket.setSendMode接口设置发送模式为快发或者慢发

快发模式下，在core中有一个1460*7=10220字节的缓冲区，要发送的数据首先存储到此缓冲区，然后在core中自动循环发送。
如果此缓冲区已满，则AT+CIPSEND会直接返回ERROR，socket:send接口也会直接返回失败

同时满足如下几种条件，适合使用快发模式：
1.	发送的数据量小，并且发送频率低，数据发送速度远远不会超过core中的10220字节大小；
    没有精确地判断标准，可以简单的按照3分钟不超过10220字节来判断；曾经有一个不适合快发模式的例子如下：
    用户使用Luat版本的http上传一个几十K的文件，设置了快发模式，导致一直发送失败，因为循环的向core中的缓冲区插入数据，
    插入数据的速度远远超过发送数据到服务器的速度，所以很快就导致缓冲区慢，再插入数据时，就直接返回失败
2.	对每次发送的数据，不需要确认发送结果
3.	数据发送功能不能影响其他功能的及时响应
]]
--socket.setSendMode(1)

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage mqttTask.isReady()
function isReady()
    return ready
end

--启动MQTT客户端任务
sys.taskInit(
    function()
        local retryConnectCnt = 0
        while true do
            if not socket.isReady() then
                retryConnectCnt = 0
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND",300000)
            end
            
            if socket.isReady() then
                local imei = misc.getImei()
                --创建一个MQTT客户端
                local mqttClient = mqtt.client(imei,600,"user","password")
                --阻塞执行MQTT CONNECT动作，直至成功
                --如果使用ssl连接，打开mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})，根据自己的需求配置
                --mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})
                if mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp") then
                    retryConnectCnt = 0
                    ready = true
                    --订阅主题
                    if mqttClient:subscribe({["/event0"]=0, ["/中文event1"]=1}) then
                        mqttOutMsg.init()
                        --循环处理接收和发送的数据
                        while true do
                            if not mqttInMsg.proc(mqttClient) then log.error("mqttTask.mqttInMsg.proc error") break end
                            if not mqttOutMsg.proc(mqttClient) then log.error("mqttTask.mqttOutMsg proc error") break end
                        end
                        mqttOutMsg.unInit()
                    end
                    ready = false
                else
                    retryConnectCnt = retryConnectCnt+1
                end
                --断开MQTT连接
                mqttClient:disconnect()
                if retryConnectCnt>=5 then link.shut() retryConnectCnt=0 end
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
