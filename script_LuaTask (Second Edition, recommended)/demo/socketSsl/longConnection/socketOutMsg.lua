--- 模块功能：socket客户端数据发送处理
-- @author openLuat
-- @module socketLongConnection.socketOutMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28


module(...,package.seeall)

--数据发送的消息队列
local msgQuene = {}

local function insertMsg(data,user)
    table.insert(msgQuene,{data=data,user=user})
end

local function sndGetCb(result)
    log.info("socketOutMsg.sndLocCb",result)
    if result then sys.timerStart(sndGet,20000) end
end

function sndGet()
    insertMsg("GET / HTTP/1.1\r\nHost: 36.7.87.100\r\nConnection: keep-alive\r\n\r\n",{cb=sndGetCb})
end

--- 初始化“socket客户端数据发送”
-- @return 无
-- @usage socketOutMsg.init()
function init()
    sndGet()
end

--- 去初始化“socket客户端数据发送”
-- @return 无
-- @usage socketOutMsg.unInit()
function unInit()
    sys.timerStop(sndGet)
    while #msgQuene>0 do
        local outMsg = table.remove(msgQuene,1)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(false,outMsg.user.para) end
    end
end

--- socket客户端是否有数据等待发送
-- @return 有数据等待发送返回true，否则返回false
-- @usage socketOutMsg.waitForSend()
function waitForSend()
    return #msgQuene > 0
end

--- socket客户端数据发送处理
-- @param socketClient，socket客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage socketOutMsg.proc(socketClient)
function proc(socketClient)
    while #msgQuene>0 do
        local outMsg = table.remove(msgQuene,1)
        local result = socketClient:send(outMsg.data)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(result,outMsg.user.para) end
        if not result then return end
    end
    return true
end
