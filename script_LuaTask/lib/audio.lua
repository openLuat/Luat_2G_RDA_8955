--- 模块功能：音频播放.
-- 支持MP3、amr文件播放；
-- 支持本地TTS播放、通话中TTS播放到对端（需要使用支持TTS功能的core软件）
-- @module audio
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.3.19

require "common"
require "misc"
require "utils"
module(..., package.seeall)

local req = ril.request
local stopCbFnc
--tts速度，默认50
local ttsSpeed = 50
--喇叭音量和mic音量等级
local sVolume,sMicVolume = 4,1

--音频播放的协程ID
local taskID

--sPriority：当前播放的音频优先级
--sType：当前播放的音频类型
--sPath：当前播放的音频数据信息
--sVol：当前播放音量
--sCb：当前播放结束或者出错的回调函数
--sDup：当前播放的音频是否需要重复播放
--sDupInterval：如果sDup为true，此值表示重复播放的间隔(单位毫秒)，默认无间隔
--sStrategy：优先级相同时的播放策略，0(表示继续播放正在播放的音频，忽略请求播放的新音频)，1(表示停止正在播放的音频，播放请求播放的新音频)
local sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval,sStrategy,sStopingType

local function update(priority,type,path,vol,cb,dup,dupInterval)
    print("audio.update",sPriority,priority,type,path,vol,cb,dup,dupInterval)
    if sPriority then
        if priority>sPriority or (priority==sPriority and sStrategy==1) then
            print("audio.update1",priority,type,path,vol,cb,dup,dupInterval)
            --此处第三个参数传入table是因为publish接口无法处理nil后面的参数
            sys.publish("AUDIO_PLAY_END","NEW",{pri=priority,typ=type,pth=path,vl=vol,c=cb,dp=dup,dpIntval=dupInterval})
        else
            log.error("audio.update","priority error")
            return false
        end
    else
        sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval = priority,type,path,vol,cb,dup,dupInterval
        if vol then setVolume(vol) end
    end
    return true
end

local function playEnd(result)
    log.info("audio.playEnd",result,sCb)
    local cb = sCb
    sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval,sStopingType = nil
    if cb then cb(result) end
end

local function isTtsApi()
    return tonumber((rtos.get_version()):match("Luat_V(%d+)_"))>=29
end

local function taskAudio()
    local playFnc =
    {
        FILE = audiocore.play,
        TTS = function(text)
                if isTtsApi() then
                    audiocore.openTTS(ttsSpeed)
                    local _,result = sys.waitUntil("TTS_OPEN_IND")
                    if result then
                        audiocore.playTTS(common.utf8ToUcs2(text))
                    else
                        audiocore.stopTTS()
                        sys.waitUntil("TTS_STOP_IND")
                        audiocore.closeTTS()
                        sys.waitUntil("TTS_CLOSE_IND")
                        _,result = sys.waitUntil("TTS_OPEN_IND")
                        if not result then return false end
                    end
                else
                    req("AT+QTTS=1") req(string.format("AT+QTTS=%d,\"%s\"",2,string.toHex(common.utf8ToUcs2(text))))
                end
             end,
        TTSCC = function(text) req("AT+QTTS=1") req(string.format("AT+QTTS=%d,\"%s\"",4,string.toHex(common.utf8ToUcs2(text)))) end,
        RECORD = function(id) f,d=record.getSize() req("AT+AUDREC=1,0,2," .. id .. "," .. d*1000)end,
    }

    local stopFnc =
    {
        FILE = audiocore.stop,
        TTS = function(text)
                if isTtsApi() then
                    audiocore.stopTTS()
                    sys.waitUntil("TTS_STOP_IND")
                    audiocore.closeTTS()
                    sys.waitUntil("TTS_CLOSE_IND")
                else
                    req("AT+QTTS=3") sys.waitUntil("AUDIO_STOP_END")
                end
             end,
        TTSCC = function() req("AT+QTTS=3") sys.waitUntil("AUDIO_STOP_END") end,
        RECORD = function(id) f,d=record.getSize() req("AT+AUDREC=1,0,3," .. id .. "," .. d*1000) sys.waitUntil("AUDIO_STOP_END") end,
    }

    while true do
        log.info("audio.taskAudio begin",sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval)
        --检查参数
        if not playFnc[sType] then
            playEnd(3)
            if sType==nil then break end
        end
        --开始播放
        if playFnc[sType](sPath)==false then
            playEnd(1)
            if sType==nil then break end
        end
        --挂起播放，等待播放成功、播放失败或者有新的播放请求激活协程
        local _,msg,param = sys.waitUntil("AUDIO_PLAY_END")

        log.info("audio.taskAudio resume msg",msg)
        if msg=="SUCCESS" then
            if sDup then
                if sType=="TTS" and isTtsApi() then
                    stopFnc[sType](sPath)
                end
                if sDupInterval and sDupInterval>0 then
                    sys.waitUntil("AUDIO_PLAY_END",sDupInterval)
                    if sType==nil then break end
                end
            else
                stopFnc[sType or sStopingType](sPath)
                playEnd(0)
                if sType==nil then break end
            end
        elseif msg=="NEW" then
            stopFnc[sType](sPath)
            playEnd(4)
            --if sType==nil then break end
            update(param.pri,param.typ,param.pth,param.vl,param.c,param.dp,param.dpIntval)
        elseif msg=="STOP" then
            if param=="TTS" and isTtsApi() then
                stopFnc[param]()
            end
            playEnd(5)
            break
        else
            stopFnc[sType](sPath)
            playEnd(1)
            if sType==nil then break end
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
local function urc(data,prefix)
    if prefix == "+QTTS" then
        local flag = string.match(data,": *(%d)",string.len(prefix)+1)
        --停止播放tts
        if flag=="0" --[[or flag == "1"]] then
            sys.publish("AUDIO_PLAY_END","SUCCESS")
        end
    end
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
local function rsp(cmd,success,response,intermediate)
    local prefix = string.match(cmd,"AT(%+%u+%?*)")

    if prefix == "+QTTS" then
        local action = string.match(cmd,"QTTS=(%d)")
        if not success then
            if action=="1" or action=="2" then
                sys.publish("AUDIO_PLAY_END","ERROR")
            end
        end
        if action=="3" then
            sys.publish("AUDIO_STOP_END")
        end
    end
end

ril.regUrc("+QTTS",urc)
ril.regRsp("+QTTS",rsp,0)

local function audioMsg(msg)
    sys.publish("AUDIO_PLAY_END",msg.play_end_ind==true and "SUCCESS" or "ERROR")
end

local function ttsMsg(msg)
    log.info("audio.ttsMsg",msg.type,msg.result)
    local tag = {[0]="CLOSE", [1]="OPEN", [2]="PLAY", [3]="STOP"}
    if msg.type==2 then
        sys.publish("AUDIO_PLAY_END",msg.result and "SUCCESS" or "ERROR")
    else
        if tag[msg.type] then sys.publish("TTS_"..tag[msg.type].."_IND",msg.result) end
    end
end
--注册core上报的rtos.MSG_AUDIO消息的处理函数
rtos.on(rtos.MSG_AUDIO,audioMsg)
if isTtsApi() then
    rtos.on(rtos.MSG_TTS,ttsMsg)
end

--- 播放音频
-- @number priority，音频优先级，数值越大，优先级越高
-- @string type，音频类型，目前仅支持"FILE"、"TTS"、"TTSCC","RECORD"
-- @string path，音频文件路径，跟typ有关
--               typ为"FILE"时：表示音频文件路径
--               typ为"TTS"时：表示要播放的UTF8编码格式的数据
--               typ为"TTSCC"时：表示要播放给通话对端的UTF8编码格式的数据
--               typ为"RECORD"时：表示要播放的录音id
-- @number[opt=4] vol，播放音量，取值范围0到7，0为静音
-- @function[opt=nil] cbFnc，音频播放结束时的回调函数，回调函数的调用形式如下：
-- cbFnc(result)
-- result表示播放结果：
--                   0-播放成功结束；
--                   1-播放出错
--                   2-播放优先级不够，没有播放
--                   3-传入的参数出错，没有播放
--                   4-被新的播放请求中止
--                   5-调用audio.stop接口主动停止
-- @bool[opt=nil] dup，是否循环播放，true循环，false或者nil不循环
-- @number[opt=0] dupInterval，循环播放间隔(单位毫秒)，dup为true时，此值才有意义
-- @return result，bool或者nil类型，同步调用成功返回true，否则返回false
-- @usage audio.play(0,"FILE","/ldata/call.mp3")
-- @usage audio.play(0,"FILE","/ldata/call.mp3",7)
-- @usage audio.play(0,"FILE","/ldata/call.mp3",7,cbFnc)
-- @usage 更多用法参考demo/audio/testAudio.lua
function play(priority,type,path,vol,cbFnc,dup,dupInterval)
    if not update(priority,type,path,vol or 4,cbFnc,dup,dupInterval or 0) then
        log.error("audio.play","sync error")
        return false
    end
    if not sType or not taskID or coroutine.status(taskID)=="dead" then
        taskID = sys.taskInit(taskAudio)
    end
    return true
end

--- 停止音频播放
-- @function[opt=nil] cbFnc，停止音频播放的回调函数(停止结果通过此函数通知用户)，回调函数的调用形式为：
--      cbFnc(result)
--      result：number类型
--              0表示停止成功
--              1表示之前已经发送了停止动作，请耐心等待停止结果的回调
-- @return nil
-- @usage audio.stop()
function stop(cbFnc)
    log.info("audio.stop",sType,cbFnc)
    if stopCbFnc and cbFnc then cbFnc(1) return end
    if sType then
        if sType=="FILE" then
            audiocore.stop()
        elseif (sType=="TTS" and not isTtsApi()) or sType=="TTSCC" then
            req("AT+QTTS=3")
        elseif sType=="TTS" and isTtsApi() then
            sStopingType = "TTS"
        elseif sType=="RECORD" then
            f,d=record.getSize() req("AT+AUDREC=1,0,3," .. sPath .. "," .. d*1000)
            --audiocore.stop()
            if cbFnc then
                stopCbFnc = cbFnc
                function recordPlayInd()
                    --sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval = nil
                    sys.publish("AUDIO_PLAY_END","STOP","RECORD")
                    if stopCbFnc then stopCbFnc(0) stopCbFnc=nil end
                    sys.unsubscribe("LIB_RECORD_PLAY_END_IND",recordPlayInd)
                end
                sys.subscribe("LIB_RECORD_PLAY_END_IND",recordPlayInd)
            else
                local typ = sType
                sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval = nil
                sys.publish("AUDIO_PLAY_END","STOP",typ)
            end
        end
        if sType~="RECORD" then
            local typ = sType
            sPriority,sType,sPath,sVol,sCb,sDup,sDupInterval = nil
            sys.publish("AUDIO_PLAY_END","STOP",typ)
            if cbFnc then cbFnc(0) end
        end
    else
        if cbFnc then cbFnc(0) end
    end
end

--- 设置喇叭音量等级
-- @number vol，音量值为0-7，0为静音
-- @return bool result，设置成功返回true，失败返回false
-- @usage audio.setVolume(7)
function setVolume(vol)
    local result = audiocore.setvol(vol)
    if result then sVolume = vol end
    return result
end
--- 设置麦克音量等级
-- @number vol，音量值为0-15，0为静音
-- @return bool result，设置成功返回true,失败返回false
-- @usage audio.setMicVolume(14)
function setMicVolume(vol)
    ril.request("AT+CMIC="..audiocore.LOUDSPEAKER..","..vol)
    return true
end

ril.regRsp("+CMIC",function(cmd,success)
    if success then
        sMicVolume = tonumber(cmd:match("CMIC=%d+,(%d+)"))
    end
end)

--- 获取喇叭音量等级
-- @return number vol，喇叭音量等级
-- @usage audio.getVolume()
function getVolume()
    return sVolume
end

--- 获取麦克音量等级
-- @return number vol，麦克音量等级
-- @usage audio.getMicVolume()
function getMicVolume(vol)
    return sMicVolume
end

--- 设置优先级相同时的播放策略
-- @number strategy，优先级相同时的播放策略；0：表示继续播放正在播放的音频，忽略请求播放的新音频；1：表示停止正在播放的音频，播放请求播放的新音频
-- @return nil
-- @usage audio.setStrategy(0)
-- @usage audio.setStrategy(1)
function setStrategy(strategy)
    sStrategy=strategy
end

--- 设置TTS朗读速度
-- @number speed，速度范围为0-100，默认50
-- @return bool result，设置成功返回true，失败返回false
-- @usage audio.setTTSSpeed(70)
function setTTSSpeed(speed)
    if type(speed) == "number" and speed >= 0 and speed <= 100 then
        ttsSpeed = speed
        return true
    end
end

local function rsp(cmd, success, response, intermediate)
    local prefix = string.match(cmd, "AT(%+%u+)")
    
    log.info("net.rsp",cmd, success, response, intermediate)
    
    if prefix == "+CSQ" then
        if intermediate ~= nil then
            local s = string.match(intermediate, "+CSQ:%s*(%d+)")
            if s ~= nil then
                rssi = tonumber(s)
                rssi = rssi == 99 and 0 or rssi
                --产生一个内部消息GSM_SIGNAL_REPORT_IND，表示读取到了信号强度
                publish("GSM_SIGNAL_REPORT_IND", success, rssi)
            end
        end
    elseif prefix == "+CFUN" then
        if success then publish("FLYMODE", flyMode) end
    end
end

--默认音频通道设置为LOUDSPEAKER，因为目前的模块只支持LOUDSPEAKER通道
audiocore.setchannel(audiocore.LOUDSPEAKER)
--默认音量等级设置为4级，4级是中间等级，最低为0级，最高为7级
setVolume(sVolume)
--默认MIC音量等级设置为1级，最低为0级，最高为15级
setMicVolume(sMicVolume)
