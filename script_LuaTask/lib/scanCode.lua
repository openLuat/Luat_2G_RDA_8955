--- 模块功能：扫码.
-- 支持二维码、条形码扫描
-- @module scanCode
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.9.19

require"sys"
module(..., package.seeall)

local sCbFnc

--- 设置扫码请求
-- @function cbFnc，扫码返回或者超时未返回的回调函数，回调函数的调用形式为：
--      cbFnc(result,type,str)
--      result：true或者false，true表示扫码成功，false表示超时失败
--      type：string或者nil类型，result为true时，表示扫码类型；result为false时，为nil；支持QR-Code和CODE-128
--      str：string或者nil类型，result为true时，表示扫码结果的字符串；result为false时，为nil
-- @number[opt=10000] timeout，设置请求后，等待扫码结果返回的超时时间，单位毫秒，默认为10秒
-- @usage 
-- scanCode.request(cbFnc)
-- scanCode.request(cbFnc,5000)
function request(cbFnc,timeout)
    sCbFnc = cbFnc
    sys.timerStart(sCbFnc,timeout or 10000,false)
end

local function zbarMsg(msg)
    --log.info("scanCode.zbarMsg",msg.result,sys.timerIsActive(sCbFnc,false))
    if msg.result and sys.timerIsActive(sCbFnc,false) then
        sys.timerStop(sCbFnc,false)
        sCbFnc(true,msg.type,msg.data)
    end
end

--注册core上报的rtos.MSG_ZBAR消息的处理函数
rtos.on(rtos.MSG_ZBAR,zbarMsg)
