--- 模块功能：配置管理-序列号、IMEI、底层软件版本号、时钟、是否校准、飞行模式、查询电池电量等功能
-- @module misc
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.10.20
require "ril"
local req = ril.request
module(..., package.seeall)
--sn：序列号
--imei：IMEI
-- calib 校准标志
local sn, imei, calib, ver, muid
local setSnCbFnc,setImeiCbFnc,setClkCbFnc

local function timeReport()
    sys.publish("TIME_CLK_IND")
    sys.timerStart(setTimeReport,2000)
end

function setTimeReport()
    sys.timerStart(timeReport,(os.time()%60==0) and 50 or (60-os.time()%60)*1000)
end

--[[
函数名：rsp
功能  ：本功能模块内“通过虚拟串口发送到底层core软件的AT命令”的应答处理
参数  ：
cmd：此应答对应的AT命令
success：AT命令执行结果，true或者false
response：AT命令的应答中的执行结果字符串
intermediate：AT命令的应答中的中间信息
返回值：无
]]
local function rsp(cmd, success, response, intermediate)
    local prefix = string.match(cmd, "AT(%+%u+)")
    --查询序列号
    if cmd == "AT+WISN?" then
        sn = intermediate
        if setSnCbFnc then setSnCbFnc(true) end
        sys.publish('SN_READY_IND')
    --查询IMEI
    elseif cmd == "AT+CGSN" then
        imei = intermediate
        if setImeiCbFnc then setImeiCbFnc(true) end
        sys.publish('IMEI_READY_IND')
    elseif cmd == 'AT+VER' then
        ver = intermediate
    --查询是否校准
    elseif cmd == "AT+ATWMFT=99" then
        log.info('misc.ATWMFT', intermediate)
        if intermediate == "SUCC" then
            calib = true
        else
            calib = false
        end
    elseif prefix == '+CCLK' then
        if success then
            sys.publish('TIME_UPDATE_IND')
            setTimeReport()
        end
        if setClkCbFnc then setClkCbFnc(getClock(),success) end
    elseif cmd:match("AT%+WISN=") then
        if success then
            req("AT+WISN?")
        else
            if setSnCbFnc then setSnCbFnc(false) end
        end
    elseif cmd:match("AT%+WIMEI=") then
        if success then
            req("AT+CGSN")
        else
            if setImeiCbFnc then setImeiCbFnc(false) end
        end
    elseif cmd:match("AT%+MUID?") then
        if intermediate then muid = intermediate:match("+MUID:%s*\"(.+)\"") end
    end
end

function getVersion()
    return ver
end

--- 设置系统时间
-- @table t,系统时间，格式参考：{year=2017,month=2,day=14,hour=14,min=2,sec=58}
-- @function[opt=nil] cbFnc，设置结果回调函数，回调函数的调用形式为：
-- cnFnc(time，result)，result为true表示成功，false或者nil为失败；time表示设置之后的系统时间，table类型，例如{year=2017,month=2,day=14,hour=14,min=19,sec=23}
-- @return nil
-- @usage misc.setClock({year=2017,month=2,day=14,hour=14,min=2,sec=58})
function setClock(t,cbFnc)
    if type(t) ~= "table" or (t.year-2000>38) then
        if cbFnc then cbFnc(getClock(),false) end
        return
    end
    setClkCbFnc = cbFnc
    req(string.format("AT+CCLK=\"%02d/%02d/%02d,%02d:%02d:%02d+32\"", string.sub(t.year, 3, 4), t.month, t.day, t.hour, t.min, t.sec), nil, rsp)
end
--- 获取系统时间
-- @return table time,{year=2017,month=2,day=14,hour=14,min=19,sec=23}
-- @usage time = getClock()
function getClock()
    return os.date("*t")
end
--- 获取星期
-- @return number week，1-7分别对应周一到周日
-- @usage week = misc.getWeek()
function getWeek()
    local clk = os.date("*t")
    return ((clk.wday == 1) and 7 or (clk.wday - 1))
end
--- 获取校准标志
-- @return bool calib, true表示已校准，false或者nil表示未校准
-- @usage calib = misc.getCalib()
function getCalib()
    return calib
end
--- 设置SN
-- @string s,新sn的字符串
-- @function[opt=nil] cbFnc,设置结果回调函数，回调函数的调用形式为：
-- cnFnc(result)，result为true表示成功，false或者nil为失败
-- @return nil
-- @usage
-- misc.setSn("1234567890")
-- misc.setSn("1234567890",cbFnc)
function setSn(s, cbFnc)
    if s ~= sn then
        setSnCbFnc = cbFnc
        req("AT+WISN=\"" .. s .. "\"") 
    else
        if cbFnc then cbFnc(true) end
    end
end
--- 获取模块序列号
-- @return string sn,序列号，如果未获取到返回""
-- 注意：开机lua脚本运行之后，会发送at命令去查询sn，所以需要一定时间才能获取到sn。开机后立即调用此接口，基本上返回""
-- @usage sn = misc.getSn()
function getSn()
    return sn or ""
end
--- 设置IMEI
-- @string s,新IMEI字符串
-- @function[opt=nil] cbFnc,设置结果回调函数，回调函数的调用形式为：
-- cnFnc(result)，result为true表示成功，false或者nil为失败
-- @return nil
-- @usage misc.setImei(”359759002514931”)
function setImei(s, cbFnc)
    if s ~= imei then
        setImeiCbFnc = cbFnc
        req("AT+WIMEI=\"" .. s .. "\"")
    else
        if cbFnc then cbFnc(true) end
    end
end
--- 获取模块IMEI
-- @return string,IMEI号，如果未获取到返回""
-- 注意：开机lua脚本运行之后，会发送at命令去查询imei，所以需要一定时间才能获取到imei。开机后立即调用此接口，基本上返回""
-- @usage imei = misc.getImei()
function getImei()
    return imei or ""
end
--- 获取VBAT的电池电压
-- @return number,电池电压,单位mv
-- @usage vb = getVbatt()
function getVbatt()
    local v1, v2, v3, v4, v5 = pmd.param_get()
    return v2
end

--- 获取模块MUID
-- @return string,MUID号，如果未获取到返回""
-- 注意：开机lua脚本运行之后，会发送at命令去查询muid，所以需要一定时间才能获取到muid。开机后立即调用此接口，基本上返回""
-- @usage muid = misc.getMuid()
function getMuid()
    return muid or ""
end

--- 打开并且配置PWM(支持2路PWM，仅支持输出)
-- 说明：
-- 当id为0时：period 取值在 80-1625 Hz范围内时，level 占空比取值范围为：1-100；
-- period 取值在 1626-65535 Hz范围时，设x=162500/period, y=x * level / 100, x 和 y越是接近正的整数，则输出波形越准确
-- @number id，PWM输出通道，仅支持0和1，0用的是uart2 tx，1用的是uart2 rx
-- @number period，
-- 当id为0时，period表示频率，单位为Hz，取值范围为80-1625，仅支持整数
-- 当id为1时，取值范围为0-7，仅支持整数，表示时钟周期，单位为毫秒，0-7分别对应125、250、500、1000、1500、2000、2500、3000毫秒
-- @number level，
-- 当id为0时，level表示占空比，单位为level%，取值范围为1-100，仅支持整数
-- 当id为1时，取值范围为1-15，仅支持整数，表示一个时钟周期内的高电平时间，单位为毫秒
--                      1-15分别对应15.6、31.2、46.9、62.5、78.1、93.7、110、125、141、156、172、187、203、219、234毫秒
-- @return nil
function openPwm(id, period, level)
    assert(type(id) == "number" and type(period) == "number" and type(level) == "number", "openpwm type error")
    assert(id == 0 or id == 1, "openpwm id error: " .. id)
    local pmin, pmax, lmin, lmax = 80, 1625, 1, 100
    if id == 1 then pmin, pmax, lmin, lmax = 0, 7, 1, 15 end
    assert(period >= pmin and period <= pmax, "openpwm period error: " .. period)
    assert(level >= lmin and level <= lmax, "openpwm level error: " .. level)
    req("AT+SPWM=" .. id .. "," .. period .. "," .. level)
end

--- 关闭PWM
-- @number id，PWM输出通道，仅支持0和1，0用的是uart2 tx，1用的是uart2 rx
-- @return nil
function closePwm(id)
    assert(id == 0 or id == 1, "closepwm id error: " .. id)
    req("AT+SPWM=" .. id .. ",0,0")
end

--注册以下AT命令的应答处理函数
ril.regRsp("+ATWMFT", rsp)
ril.regRsp("+WISN", rsp)
ril.regRsp("+CGSN", rsp)
ril.regRsp("+MUID", rsp)
ril.regRsp("+WIMEI", rsp)
ril.regRsp("+AMFAC", rsp)
ril.regRsp('+VER', rsp, 4, '^[%w_]+$')
req('AT+VER')
--查询是否校准
req("AT+ATWMFT=99")
--查询序列号
req("AT+WISN?")
--查询IMEI
req("AT+CGSN")
req("AT+MUID?")
setTimeReport()
