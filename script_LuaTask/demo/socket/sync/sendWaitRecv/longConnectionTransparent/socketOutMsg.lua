--- 模块功能：socket客户端数据发送处理
-- @author openLuat
-- @module socketLongConnectionTrasparent.socketOutMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28


module(...,package.seeall)

--数据发送的消息队列
local msgQueue = {}

local function insertMsg(data,user)
    table.insert(msgQueue,{data=data,user=user})
    sys.publish("APP_SOCKET_SEND_DATA")
end


--- 去初始化“socket客户端数据发送”
-- @return 无
-- @usage socketOutMsg.unInit()
function unInit()
    while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(false,outMsg.user.para) end
    end
end

--- socket客户端数据发送处理
-- @param socketClient，socket客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage socketOutMsg.proc(socketClient)
function proc(socketClient)
    while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        local result = socketClient:send(outMsg.data)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(result,outMsg.user.para) end
        if not result then return end
    end
    return true
end

local function uartRecvData(data)
    insertMsg(data)
end
sys.subscribe("UART_RECV_DATA",uartRecvData)
