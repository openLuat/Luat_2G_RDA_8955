--- 模块功能：通话管理
-- @module cc
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.11.2

module(..., package.seeall)
require"ril"
require"pm"

-- 通话状态
CONNECTED = 0
HOLD = 1
DIALING = 2
ALERTING = 3
INCOMING = 4
WAITING = 5
DISCONNECTING = 98
DISCONNECTED = 99

local req = ril.request
local publish = sys.publish

--底层通话模块是否准备就绪，true就绪，false或者nil未就绪
local ccready = false
--通话列表
local call_list = {n= 0}

--- 是否存在通话
-- @return result 存在通话返回true，否则返回false
-- @usage result = cc.anyCallExist()
function anyCallExist()
    return call_list.n ~= 0
end

--- 查询某个号码的通话状态
-- @param num 查询号码
-- @return state 通话状态，状态值参考本模块定义
-- @usage state = cc.getState('10086')
function getState(num)
    return call_list[num] or DISCONNECTED
end

--- 拨号
-- @param number 号码
-- @param delay 延时delay毫秒后，才发送at命令呼叫，默认不延时
-- @return result true表示允许发送at命令拨号并且发送at，false表示不允许at命令拨号
-- @usage cc.dial('10086')
function dial(number, delay)
    if number == "" or number == nil then return false end
    pm.wake("cc")
    req(string.format("%s%s;", "ATD", number), nil, nil, delay)
    call_list[number] = DIALING
    return true
end

--- 挂断所有通话
-- @param num 号码，若指定号码通话状态不对 则直接退出 不会执行挂断，若挂断时会挂断所有电话
-- @return
-- @usage cc.hangUp('10086')
function hangUp(num)
    if call_list[num] == DISCONNECTING or call_list[num] == DISCONNECTED then return end
    if audio and type(audio.stop)=="function" then audio.stop() end
    req("AT+CHUP")
    call_list[num] = DISCONNECTING
end

--- 接听电话
-- @param num 号码，若指定号码通话状态不对 则直接退出 不会接通
-- @return
-- @usage cc.accept('10086')
function accept(num)
    if call_list[num] ~= INCOMING then return end
    if audio and type(audio.stop)=="function" then audio.stop() end
    req("ATA")
    call_list[num] = CONNECTING
end

--- 通话中发送声音到对端,必须是12.2K AMR格式
-- @param data
-- @param loop
-- @param loop2
-- @return result true为成功，false为失败
-- @usage
function transvoice(data, loop, loop2)
    local f = io.open("/RecDir/rec000", "wb")

    if f == nil then
        log_print("transvoice:open file error")
        return false
    end

    -- 有文件头并且是12.2K帧
    if string.sub(data, 1, 7) == "#!AMR\010\060" then
        -- 无文件头且是12.2K帧
    elseif string.byte(data, 1) == 0x3C then
        f:write("#!AMR\010")
    else
        log.error('cc.transvoice', 'must be 12.2K AMR')
        return false
    end

    f:write(data)
    f:close()

    req(string.format("AT+AUDREC=%d,%d,2,0,50000", loop2 == true and 1 or 0, loop == true and 1 or 0))

    return true
end

--- 设置dtmf检测是否使能以及灵敏度
-- @param enable true使能，false或者nil为不使能
-- @param sens 灵敏度，默认3，最灵敏为1
-- @return
-- @usage cc.dtmfDetect(true)
function dtmfDetect(enable, sens)
    if enable == true then
        if sens then
            req("AT+DTMFDET=2,1," .. sens)
        else
            req("AT+DTMFDET=2,1,3")
        end
    end

    req("AT+DTMFDET=" .. (enable and 1 or 0))
end

--- 发送dtmf到对端
-- @param str dtmf字符串
-- @param playtime 每个dtmf播放时间，单位毫秒，默认100
-- @param intvl 两个dtmf间隔，单位毫秒，默认100
-- @return 无
-- @usage cc.sendDtmf("123")
function sendDtmf(str, playtime, intvl)
    if string.match(str, "([%dABCD%*#]+)") ~= str then
        log_print("sendDtmf: illegal string " .. str)
        return false
    end

    playtime = playtime and playtime or 100
    intvl = intvl and intvl or 100

    req("AT+SENDSOUND=" .. string.format("\"%s\",%d,%d", str, playtime, intvl))
end

local dtmfnum = { [71] = "Hz1000", [69] = "Hz1400", [70] = "Hz2300" }
local function parsedtmfnum(data)
    local n = tonumber(string.match(data, "(%d+)"))
    local dtmf

    if (n >= 48 and n <= 57) or (n >= 65 and n <= 68) or n == 42 or n == 35 then
        dtmf = string.char(n)
    else
        dtmf = dtmfnum[n]
    end

    if dtmf then
        publish("CALL_DTMF_DETECT", dtmf) -- 通话中dtmf解码会产生消息AUDIO_DTMF_DETECT，消息数据为DTMF字符
    end
end

local function ccurc(data, prefix)
    if data == "CALL READY" then --底层通话模块准备就绪
        ccready = true
        publish("CALL_READY")
        req("AT+CCWA=1")
    elseif prefix == "+DTMFDET" then
        parsedtmfnum(data)
    else
        req('AT+CLCC')
        if data == "CONNECT" and audio and type(audio.stop)=="function" then audio.stop() end --先停止音频播放
    end
end

local function ccrsp() req('AT+CLCC') end

--注册以下通知的处理函数
ril.regUrc("CALL READY", ccurc)
ril.regUrc("CONNECT", ccurc)
ril.regUrc("NO CARRIER", ccurc)
ril.regUrc("NO ANSWER", ccurc)
ril.regUrc("BUSY", ccurc)
ril.regUrc("+CLIP", ccurc)
ril.regUrc("+CCWA", ccurc)
ril.regUrc("+DTMFDET", ccurc)
--注册以下AT命令的应答处理函数
ril.regRsp("D", ccrsp)
ril.regRsp("A", ccrsp)
ril.regRsp("+CHUP", ccrsp)
ril.regRsp("+CHLD", ccrsp)
ril.regRsp("+CLCC", function(cmd, success, response, intermediate)
    if success then
        local new = {n = 0 }
        if intermediate and intermediate:len() > 0 then
            for id, dir, stat, num in intermediate:gmatch('%+CLCC:%s*(%d+),(%d),(%d),%d,%d,"([^"]*)".-\r\n') do
                stat = tonumber(stat)
                if stat == WAITING then
                    req('AT+CHLD=1' .. id)
                    return
                end
                if call_list[num] ~= stat then
                    if stat == INCOMING or stat == CONNECTED then
                        pm.wake('cc')
                        publish(stat == INCOMING and 'CALL_INCOMING' or 'CALL_CONNECTED', num)
                    end
                end
                new[num] = stat
                new.n = new.n + 1
            end
        end
        call_list = new
        if new.n == 0 then
            publish('CALL_DISCONNECTED')
            pm.sleep('cc')
        end
    end
end)

--开启拨号音,忙音检测
req("ATX4")
--开启来电urc上报
req("AT+CLIP=1")
