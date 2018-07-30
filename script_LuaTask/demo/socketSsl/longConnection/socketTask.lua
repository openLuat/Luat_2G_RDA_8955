--- 模块功能：socket ssl长连接功能测试.
-- 与服务器连接成功后
--
-- 每隔20秒钟发送一次HTTP GET报文到服务器
--
-- 与服务器断开连接后，会自动重连
-- @author openLuat
-- @module socketSslLongConnection.socketTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"socket"
require"socketOutMsg"
require"socketInMsg"
require"ntp"

local ready = false

--- socket连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage socketTask.isReady()
function isReady()
    return ready
end

--同步网络时间，因为证书校验时会用到系统时间
ntp.timeSync()
--启动socket客户端任务
sys.taskInit(
    function()
        --单向认证测试时，此变量设置为false；双向认证测试时，此变量设置为true
        local mutualAuth = false
        local socketClient,connectResult
        local retryConnectCnt = 0
        
        while true do
            if not socket.isReady() then
                retryConnectCnt = 0
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND",300000)
            end            
            
            if socket.isReady() then
                --双向认证测试
                if mutualAuth then                   
                    --创建一个socket ssl tcp客户端
                    socketClient = socket.tcp(true,{caCert="ca.crt",clientCert="client.crt",clientKey="client.key"})
                    --阻塞执行socket connect动作，直至成功
                    connectResult = socketClient:connect("36.7.87.100","4434")
                --单向认证测试
                else
                    --创建一个socket ssl tcp客户端
                    socketClient = socket.tcp(true,{caCert="ca.crt"})
                    --阻塞执行socket connect动作，直至成功
                    connectResult = socketClient:connect("36.7.87.100","4433")
                end
                
                if connectResult then
                    retryConnectCnt = 0
                    ready = true
                    
                    socketOutMsg.init()
                    --循环处理接收和发送的数据
                    while true do
                        if not socketInMsg.proc(socketClient) then log.error("socketTask.socketInMsg.proc error") break end
                        if not socketOutMsg.proc(socketClient) then log.error("socketTask.socketOutMsg proc error") break end
                    end
                    socketOutMsg.unInit()

                    ready = false
                else
                    retryConnectCnt = retryConnectCnt+1
                end
                
                --断开socket连接
                socketClient:close()
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
