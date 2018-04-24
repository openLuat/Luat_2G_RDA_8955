--- 模块功能：socket客户端数据接收处理
-- @author openLuat
-- @module socketLongConnection.socketInMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

--- socket客户端数据接收处理
-- @param socketClient，socket客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage socketInMsg.proc(socketClient)
function proc(socketClient)
    local result,data
    while true do
        result,data = socketClient:recv(2000)
        --接收到数据
        if result then
            log.info("socketInMsg.proc",data)
                
            --TODO：根据需求自行处理data
            
            --如果socketOutMsg中有等待发送的数据，则立即退出本循环
            if socketOutMsg.waitForSend() then return true end
        else
            break
        end
    end
	
    return result or data=="timeout"
end
