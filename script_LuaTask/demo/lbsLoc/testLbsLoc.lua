--- 模块功能：根据基站信息获取经纬度功能测试.
-- @author openLuat
-- @module lbsLoc.testLbsLoc
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.23

module(...,package.seeall)

require"lbsLoc"

--[[
功能  ：发送查询位置请求
参数  ：无
返回值：无
]]
local function reqLbsLoc()   
    lbsLoc.request(getLocCb)
end

--[[
功能  ：获取基站对应的经纬度后的回调函数
参数  ：
		result：number类型，0表示成功，1表示网络环境尚未就绪，2表示连接服务器失败，3表示发送数据失败，4表示接收服务器应答超时，5表示服务器返回查询失败；为0时，后面的3个参数才有意义
		lat：string类型，纬度，整数部分3位，小数部分7位，例如031.2425864
		lng：string类型，经度，整数部分3位，小数部分7位，例如121.4736522
返回值：无
]]
function getLocCb(result,lat,lng)
    log.info("testLbsLoc.getLocCb",result,lat,lng)
    --获取经纬度成功
    if result==0 then
    --失败
    else
    end
    sys.timerStart(reqLbsLoc,20000)
end

reqLbsLoc()
