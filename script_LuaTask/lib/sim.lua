--- 模块功能：查询sim卡状态、iccid、imsi、mcc、mnc
-- @module sim
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.02.13
require "ril"
require "sys"
module(..., package.seeall)


--sim卡的imsi、sim卡的iccid
local imsi, iccid, status
local sNumber,bQueryNumber = ""

--- 获取sim卡的iccid
-- @return string ,返回iccid，如果还没有读取出来，则返回nil
-- @usage 注意：开机lua脚本运行之后，会发送at命令去查询iccid，所以需要一定时间才能获取到iccid。开机后立即调用此接口，基本上返回nil
-- @usage sim.getIccid()
function getIccid()
    return iccid
end

--- 获取sim卡的imsi
-- @return string ,返回imsi，如果还没有读取出来，则返回nil
-- @usage 开机lua脚本运行之后，会发送at命令去查询imsi，所以需要一定时间才能获取到imsi。开机后立即调用此接口，基本上返回nil
-- @usage sim.getImsi()
function getImsi()
    return imsi
end

--- 获取sim卡的mcc
-- @return string ,返回值：mcc，如果还没有读取出来，则返回""
-- @usage 注意：开机lua脚本运行之后，会发送at命令去查询imsi，所以需要一定时间才能获取到imsi。开机后立即调用此接口，基本上返回""
-- @usage sim.getMcc()
function getMcc()
    return (imsi ~= nil and imsi ~= "") and string.sub(imsi, 1, 3) or ""
end

--- 获取sim卡的getmnc
-- @return string ,返回mnc，如果还没有读取出来，则返回""
-- @usage   注意：开机lua脚本运行之后，会发送at命令去查询imsi，所以需要一定时间才能获取到imsi。开机后立即调用此接口，基本上返回""
-- @usage sim.getMnc()
function getMnc()
    return (imsi ~= nil and imsi ~= "") and string.sub(imsi, 4, 5) or ""
end

--- 获取sim卡的状态
-- @return bool ,true表示sim卡正常，false或者nil表示未检测到卡或者卡异常
-- @usage   开机lua脚本运行之后，会发送at命令去查询状态，所以需要一定时间才能获取到状态。开机后立即调用此接口，基本上返回nil
-- @usage sim.getStatus()
function getStatus()
    return status
end

--- 获取sim卡类型
-- @return string ,"UNSUPPORT"表示core软件不支持此功能，"NO_RDY_SIM"表示SIM卡未就绪；"VSIM"表示虚拟SIM卡，"REAL_SIM"表示实体SIM卡
-- @usage sim.getType()
function getType()
    if type(rtos.is_vsim)=="function" then
        return status and (rtos.is_vsim() and "VSIM" or "REAL_SIM") or "NO_RDY_SIM"
    else
        return "UNSUPPORT"
    end 
end

--- 设置“是否打开查询本机号码”的功能
-- @bool flag，开启或者关闭查询功能的标志，false或者nil为关闭，其余为开启
-- @return nil
-- @usage sim.setQueryNumber(true)
function setQueryNumber(flag)
    bQueryNumber = flag
end

--- 获取sim卡的本机号码
-- @return string ,返回值：sNumber，如果还没有读取出来或者读取失败，则返回""
-- @usage 注意：开机lua脚本运行之后，会发送at命令去查询本机号码，所以需要一定时间才能获取到本机号码。开机后立即调用此接口，基本上返回""
-- @usage 注意：此功能需要卡商支持，卡商必须把卡写到sim卡中，模块才能从卡中读出号码；目前市场上的很多卡，没有写入号码，是无法读取得
-- @usage sim.getMcc()
function getNumber()
    return sNumber or ""
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
    if cmd == "AT+CCID" then
        iccid = intermediate
    elseif cmd == "AT+CIMI" then
        imsi = intermediate
        --产生一个内部消息IMSI_READY，通知已经读取imsi
        sys.publish("IMSI_READY")
    elseif cmd == "AT+CNUM" then
        if success then
            if intermediate then sNumber = intermediate:match("%+CNUM:%s*\".-\",\"[%+]*(%d+)\",") end
        else
            sys.timerStart(ril.request,5000,"AT+CNUM")
        end
    end
end

--[[
函数名：urc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
data：通知的完整字符串信息
prefix：通知的前缀
返回值：无
]]
local function urc(data, prefix)
    --sim卡状态通知
    if prefix == "+CPIN" then
        status = false
        --sim卡正常
        if data == "+CPIN: READY" then
            status = true
            ril.request("AT+CCID")
            ril.request("AT+CIMI")
            if bQueryNumber then ril.request("AT+CNUM") end
            sys.publish("SIM_IND", "RDY")
        --未检测到sim卡
        elseif data == "+CPIN: NOT INSERTED" then
            sys.publish("SIM_IND", "NIST")
        else
            --sim卡pin开启
            if data == "+CPIN: SIM PIN" then
                sys.publish("SIM_IND_SIM_PIN")
            end
            sys.publish("SIM_IND", "NORDY")
        end
    end
end

--注册AT+CCID命令的应答处理函数
ril.regRsp("+CCID", rsp)
--注册AT+CIMI命令的应答处理函数
ril.regRsp("+CIMI", rsp)
ril.regRsp("+CNUM", rsp)
--注册+CPIN通知的处理函数
ril.regUrc("+CPIN", urc)
--关闭sim卡的STK功能，有的sim卡STK功能开机会不断的发送短信，影响数据业务的稳定工作
ril.request("AT+STON=0")
