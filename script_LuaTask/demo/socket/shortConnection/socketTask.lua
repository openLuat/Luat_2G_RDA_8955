--- 模块功能：socket短连接功能测试
-- @author openLuat
-- @module socketShortConnection.socketTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"socket"

--启动socket客户端任务
sys.taskInit(
    function()
        while true do
            if not socket.isReady() then
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND",300000)
            end
            
            if socket.isReady() then
                --创建一个socket tcp客户端
                local socketClient = socket.tcp()
                --阻塞执行socket connect动作，直至成功
                if socketClient:connect("36.7.87.100","6500") then  
                    if socketClient:send("heart data\r\n") then
                        result,data = socketClient:recv(5000)
                        if result then
                            --TODO：处理收到的数据data
                            log.info("socketTask.recv",data)
                        end
                    end
                end
                
                --断开socket连接
                socketClient:close()
                sys.wait(20000)
            else
                --进入飞行模式，20秒之后，退出飞行模式
                net.switchFly(true)
                sys.wait(20000)
                net.switchFly(false)
            end
        end
    end
)
