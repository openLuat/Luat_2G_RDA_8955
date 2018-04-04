--- 模块功能：电话本功能测试.
-- @author openLuat
-- @module pb.testPb
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"pb"


--[[
函数名：storagecb
功能  ：设置电话本存储区域后的回调函数
参数  ：
        result：设置结果，true为成功，其余为失败
返回值：无
]]
local function storagecb(result)
    log.info("testPb.storagecb",result)
    --删除第1个位置的电话本记录
    pb.delete(1,deletecb)
end

--[[
函数名：writecb
功能  ：写入一条电话本记录后的回调函数
参数  ：
        result：写入结果，true为成功，其余为失败
返回值：无
]]
function writecb(result)
    log.info("testPb.writecb",result)
    --读取第1个位置的电话本记录
    pb.read(1,readcb)
end

--[[
函数名：deletecb
功能  ：删除一条电话本记录后的回调函数
参数  ：
        result：删除结果，true为成功，其余为失败
返回值：无
]]
function deletecb(result)
    log.info("testPb.deletecb",result)
    --写入电话本记录到第1个位置
    pb.write(1,"name1","11111111111",writecb)
end

--[[
函数名：readcb
功能  ：读取一条电话本记录后的回调函数
参数  ：
        result：读取结果，true为成功，其余为失败
        name：姓名
        number：号码        
返回值：无
]]
function readcb(result,name,number)
    log.info("testPb.readcb",result,name,number)
end


local function ready(result,name,number)
    log.info("testPb.ready",result)
    if result then
        sys.timerStop(pb.read,1,ready)
        --设置电话本存储区域，SM表示sim卡存储，ME表示终端存储，打开下面2行中的1行测试即可
        --pb.setStorage("SM",storagecb)
        pb.setStorage("ME",storagecb)
    end
end

--循环定时器只是为了判断PB功能模块是否ready
sys.timerLoopStart(pb.read,2000,1,ready)
