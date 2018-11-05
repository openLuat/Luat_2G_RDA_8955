--[[
模块名称：音频控制
模块功能：dtmf编解码、tts（需要底层软件支持）、音频文件的播放和停止、录音、mic和speaker的控制
模块最后修改时间：2017.02.20
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local io = require"io"
local rtos = require"rtos"
local audio = require"audiocore"
local sys = require"sys"
local ril = require"ril"
module(...)

--加载常用的全局函数至本地
local smatch = string.match
local print = base.print
local dispatch = sys.dispatch
local req = ril.request
local tonumber = base.tonumber
local assert = base.assert

--speakervol：speaker音量等级，取值范围为audio.VOL0到audio.VOL7，audio.VOL0为静音
--audiochannel：音频通道，跟硬件设计有关，用户程序需要根据硬件配置
--microphonevol：mic音量等级，取值范围为audio.MIC_VOL0到audio.MIC_VOL15，audio.MIC_VOL0为静音
local speakervol,audiochannel,microphonevol = audio.VOL4,audio.HANDSET,audio.MIC_VOL15
local ttscause
--音频文件路径
local playname

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上audio前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("audio",...)
end

--[[
函数名：playtts
功能  ：播放tts
参数  ：
		text：字符串
		path："net"表示网络播放，其余值表示本地播放
返回值：true
]]
local function playtts(text,path)
	local action = path == "net" and 4 or 2

	req("AT+QTTS=1")
	req(string.format("AT+QTTS=%d,\"%s\"",action,text))
	return true
end

--[[
函数名：stoptts
功能  ：停止播放tts
参数  ：无
返回值：无
]]
local function stoptts()
	req("AT+QTTS=3")
end

--[[
函数名：closetts
功能  ：关闭tts功能
参数  ：
		cause：关闭原因
返回值：无
]]
local function closetts(cause)
	ttscause = cause
	req("AT+QTTS=0")
end

--[[
函数名：beginrecord
功能  ：开始录音
参数  ：
		id：录音id，会根据这个id存储录音文件，取值范围0-4
		duration：录音时长，单位毫秒
返回值：true
]]
function beginrecord(id,duration)
	req(string.format("AT+AUDREC=0,0,1," .. id .. "," .. duration))
	return true
end

--[[
函数名：endrecord
功能  ：结束录音
参数  ：
		id：录音id，会根据这个id存储录音文件，取值范围0-4
		duration：录音时长，单位毫秒
返回值：true
]]
function endrecord(id,duration)
	req(string.format("AT+AUDREC=0,0,0," .. id .. "," .. duration))
	return true
end

--[[
函数名：delrecord
功能  ：删除录音文件
参数  ：
		id：录音id，会根据这个id存储录音文件，取值范围0-4
		duration：录音时长，单位毫秒
返回值：true
]]
function delrecord(id,duration)
	req(string.format("AT+AUDREC=0,0,4," .. id .. "," .. duration))
	return true
end

--[[
函数名：playrecord
功能  ：播放录音文件
参数  ：
		dl：模块下行（耳机或手柄或喇叭）是否可以听到录音播放的声音，true可以听到，false或者nil听不到
		loop：是否循环播放，true为循环，false或者nil为不循环
		id：录音id，会根据这个id存储录音文件，取值范围0-4
		duration：录音时长，单位毫秒
返回值：true
]]
local function playrecord(dl,loop,id,duration)
	req(string.format("AT+AUDREC=" .. (dl and 1 or 0) .. "," .. (loop and 1 or 0) .. ",2," .. id .. "," .. duration))
	return true
end

--[[
函数名：stoprecord
功能  ：停止播放录音文件
参数  ：
		dl：模块下行（耳机或手柄或喇叭）是否可以听到录音播放的声音，true可以听到，false或者nil听不到
		loop：是否循环播放，true为循环，false或者nil为不循环
		id：录音id，会根据这个id存储录音文件，取值范围0-4
		duration：录音时长，单位毫秒
返回值：true
]]
local function stoprecord(dl,loop,id,duration)
	req(string.format("AT+AUDREC=" .. (dl and 1 or 0) .. "," .. (loop and 1 or 0) .. ",3," .. id .. "," .. duration))
	return true
end

--[[
函数名：_play
功能  ：播放音频文件
参数  ：
		name：音频文件路径
		loop：是否循环播放，true为循环，false或者nil为不循环
返回值：调用播放接口是否成功，true为成功，false为失败
]]
local function _play(name,loop)
	if loop then playname = name end
	return audio.play(name)
end

--[[
函数名：_stop
功能  ：停止播放音频文件
参数  ：无
返回值：调用停止播放接口是否成功，true为成功，false为失败
]]
local function _stop()
	playname = nil
	return audio.stop()
end

--[[
函数名：audiourc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
		data：通知的完整字符串信息
		prefix：通知的前缀
返回值：无
]]
local function audiourc(data,prefix)	
	--录音或者录音播放功能
	if prefix == "+AUDREC" then
		local action,duration = string.match(data,"(%d),(%d+)")
		if action and duration then
			duration = base.tonumber(duration)
			--开始录音
			if action == "1" then
				dispatch("AUDIO_RECORD_IND",(duration > 0 and true or false),duration)
			--播放录音
			elseif action == "2" then
				if duration > 0 then
					playend()
				else
					playerr()
				end
			--删除录音
			--[[elseif action == "4" then
				dispatch("AUDIO_RECORD_IND",true,duration)]]
			end
		end
	--tts功能
	elseif prefix == "+QTTS" then
		local flag = string.match(data,": *(%d)",string.len(prefix)+1)
		--停止播放tts
		if flag == "0" --[[or flag == "1"]] then
			playend()
		end	
	end
end

--[[
函数名：audiorsp
功能  ：本功能模块内“通过虚拟串口发送到底层core软件的AT命令”的应答处理
参数  ：
		cmd：此应答对应的AT命令
		success：AT命令执行结果，true或者false
		response：AT命令的应答中的执行结果字符串
		intermediate：AT命令的应答中的中间信息
返回值：无
]]
local function audiorsp(cmd,success,response,intermediate)
	local prefix = smatch(cmd,"AT(%+%u+%?*)")

	--录音或者播放录音确认应答
	if prefix == "+AUDREC" then
		local action = smatch(cmd,"AUDREC=%d,%d,(%d)")		
		if action=="1" then
			dispatch("AUDIO_RECORD_CNF",success)
		elseif action=="3" then
			recordstopind()
		end
	--播放tts或者关闭tts应答
	elseif prefix == "+QTTS" then
		local action = smatch(cmd,"QTTS=(%d)")
		if not success then
			if action == "1" or action == "2" then
				playerr()
			end
		else
			if action == "0" then
				dispatch("TTS_CLOSE_IND",ttscause)
			end
		end
		if action=="3" then
			ttstopind()
		end
	end
end

--注册以下通知的处理函数
ril.regurc("+AUDREC",audiourc)
ril.regurc("+QTTS",audiourc)
--注册以下AT命令的应答处理函数
ril.regrsp("+AUDREC",audiorsp,0)
ril.regrsp("+QTTS",audiorsp,0)

--[[
函数名：setspeakervol
功能  ：设置音频通道的输出音量
参数  ：
		vol：音量等级，取值范围为audiocore.VOL0到audiocore.VOL7，audiocore.VOL0为静音
返回值：无
]]
function setspeakervol(vol)
	audio.setvol(vol)
	speakervol = vol
end

--[[
函数名：getspeakervol
功能  ：读取音频通道的输出音量
参数  ：无
返回值：音量等级
]]
function getspeakervol()
	return speakervol
end

--[[
函数名：setaudiochannel
功能  ：设置音频通道
参数  ：
		channel：音频通道，跟硬件设计有关，用户程序需要根据硬件配置，目前的模块仅支持audiocore.LOUDSPEAKER
返回值：无
]]
local function setaudiochannel(channel)
	audio.setchannel(channel)
	audiochannel = channel
end

--[[
函数名：getaudiochannel
功能  ：读取音频通道
参数  ：无
返回值：音频通道
]]
local function getaudiochannel()
	return audiochannel
end

--[[
函数名：setloopback
功能  ：设置回环测试
参数  ：
		flag：是否打开回环测试，true为打开，false为关闭
		typ：测试回环的音频通道，跟硬件设计有关，用户程序需要根据硬件配置
		setvol：是否设置输出的音量，true为设置，false不设置
		vol：输出的音量
返回值：true设置成功，false设置失败
]]
function setloopback(flag,typ,setvol,vol)
	return audio.setloopback(flag,typ,setvol,vol)
end

--[[
函数名：setmicrophonegain
功能  ：设置MIC的音量
参数  ：
		vol：mic音量等级，取值范围为audio.MIC_VOL0到audio.MIC_VOL15，audio.MIC_VOL0为静音
返回值：无
]]
function setmicrophonegain(vol)
	audio.setmicvol(vol)
	microphonevol = vol
end

--[[
函数名：getmicrophonegain
功能  ：读取MIC的音量等级
参数  ：无
返回值：音量等级
]]
function getmicrophonegain()
	return microphonevol
end

--[[
函数名：audiomsg
功能  ：处理底层上报的rtos.MSG_AUDIO外部消息
参数  ：
		msg：play_end_ind，是否正常播放结束
		     play_error_ind，是否播放错误
返回值：无
]]
local function audiomsg(msg)
	if msg.play_end_ind == true then
		if playname then audio.play(playname) return end
		playend()
	elseif msg.play_error_ind == true then
		if playname then playname = nil end
		playerr()
	end
end

local ttsState,ttsText,ttsCbFnc = "IDLE"
function playTTS(text,vol,speed,cbFnc)
	if vol then setspeakervol(vol) end
	audio.openTTS(speed or 50)
	ttsState,ttsText,ttsCbFnc = "OPENING",text,cbFnc
end

function stopTTS(cbFnc)
	print("stopTTS",ttsState)
	if ttsState=="PLAYING" then
		audio.stopTTS()
		ttsState,ttsCbFnc = "STOPING_USER",cbFnc
	else
		cbFnc(true)
	end
end

local function ttsMsg(msg)
	print("ttsMsg",msg.type,msg.result,ttsState)
	
	if msg.type==0 then
		local state = ttsState
		ttsState = "IDLE"
		if ttsCbFnc and state then ttsCbFnc(state:match("ERR")==nil) end
	elseif msg.type==1 then
		if ttsState=="OPENING" then
			if msg.result then
				audio.playTTS(ttsText)
				ttsState = "PLAYING"
			else
				ttsState = "IDLE"
				if ttsCbFnc then ttsCbFnc(false) end
			end			
		end
	elseif msg.type==2 then
		if ttsState=="PLAYING" then
			audio.stopTTS()
			ttsState = "STOPING_"..(msg.result and "SUC" or "ERR")
		end
	elseif msg.type==3 then
		audio.closeTTS()
		ttsState = string.gsub(ttsState,"STOPING","CLOSING")
	end
end

--注册底层上报的rtos.MSG_AUDIO外部消息的处理函数
sys.regmsg(rtos.MSG_AUDIO,audiomsg)
sys.regmsg(rtos.MSG_TTS,ttsMsg)

--默认音频通道设置为LOUDSPEAKER，因为目前的模块只支持LOUDSPEAKER通道
setaudiochannel(audio.LOUDSPEAKER)
--默认音量等级设置为4级，4级是中间等级，最低为0级，最高为7级
setspeakervol(audio.VOL4)
--默认MIC音量等级设置为1级，最低为0级，最高为15级
setmicrophonegain(audio.MIC_VOL1)


--spriority：当前播放的音频优先级
--styp：当前播放的音频类型
--spath：当前播放的音频文件路径
--svol：当前播放音量
--scb：当前播放结束或者出错的回调函数
--sdup：当前播放的音频是否需要重复播放
--sduprd：如果sdup为true，此值表示重复播放的间隔(单位毫秒)，默认无间隔
--spending：将要播放的音频是否需要正在播放的音频异步结束后，再播放
--sstrategy：优先级相同时的播放策略，0(表示继续播放正在播放的音频，忽略请求播放的新音频)，1(表示停止正在播放的音频，播放请求播放的新音频)
local spriority,styp,spath,svol,scb,sdup,sduprd,sstrategy

--[[
函数名：playbegin
功能  ：关闭上次播放后，再播放本次请求
参数  ：
		priority：音频优先级，数值越小，优先级越高
		typ：音频类型，目前仅支持"FILE"、"TTS"、"TTSCC"、"RECORD"
		path：音频文件路径
		vol：播放音量，取值范围audiocore.VOL0到audiocore.VOL7。此参数可选
		cb：音频播放结束或者出错时的回调函数，回调时包含一个参数：0表示播放成功结束；1表示播放出错；2表示播放优先级不够，没有播放。此参数可选
		dup：是否循环播放，true循环，false或者nil不循环。此参数可选
		duprd：播放间隔(单位毫秒)，dup为true时，此值才有意义。此参数可选
返回值：调用成功返回true，否则返回nil
]]
local function playbegin(priority,typ,path,vol,cb,dup,duprd)
	print("playbegin")
	--重新赋值当前播放参数
	spriority,styp,spath,svol,scb,sdup,sduprd,spending = priority,typ,path,vol,cb,dup,duprd

	--如果存在音量参数，设置音量
	if vol then
		setspeakervol(vol)
    end
	
	--调用播放接口成功
	if (typ=="TTS" and playtts(path))
		or (typ=="TTSCC" and playtts(path,"net"))
		or (typ=="RECORD" and playrecord(true,false,tonumber(smatch(path,"(%d+)&")),tonumber(smatch(path,"&(%d+)"))))
		or (typ=="FILE" and _play(path,dup and (not duprd or duprd==0))) then
		return true
	--调用播放接口失败
	else
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
	end
end

--[[
函数名：setstrategy
功能  ：设置优先级相同时的播放策略
参数  ：
		strategy：优先级相同时的播放策略
				0：表示继续播放正在播放的音频，忽略请求播放的新音频
				1：表示停止正在播放的音频，播放请求播放的新音频
返回值：无
]]
function setstrategy(strategy)
	sstrategy=strategy
end

--[[
函数名：play
功能  ：播放音频
参数  ：
		priority：number类型，必选参数，音频优先级，数值越大，优先级越高
		typ：string类型，必选参数，音频类型，目前仅支持"FILE"、"TTS"、"TTSCC"、"RECORD"
		path：必选参数，音频文件路径，跟typ有关：
		      typ为"FILE"时：string类型，表示音频文件路径
			  typ为"TTS"时：string类型，表示要播放数据的UCS2十六进制字符串
			  typ为"TTSCC"时：string类型，表示要播放给通话对端数据的UCS2十六进制字符串
			  typ为"RECORD"时：string类型，表示录音ID&录音时长（毫秒）
		vol：number类型，可选参数，播放音量，取值范围audiocore.VOL0到audiocore.VOL7
		cb：function类型，可选参数，音频播放结束或者出错时的回调函数，回调时包含一个参数：0表示播放成功结束；1表示播放出错；2表示播放优先级不够，没有播放
		dup：bool类型，可选参数，是否循环播放，true循环，false或者nil不循环
		duprd：number类型，可选参数，播放间隔(单位毫秒)，dup为true时，此值才有意义
返回值：调用成功返回true，否则返回nil
]]
function play(priority,typ,path,vol,cb,dup,duprd)
	assert(priority and typ,"play para err")
	print("play",priority,typ,path,vol,cb,dup,duprd,styp)
	--有音频正在播放
	if styp then
		--将要播放的音频优先级 高于 正在播放的音频优先级
		if priority > spriority or (sstrategy==1 and priority==spriority) then
			--如果正在播放的音频有回调函数，则执行回调，传入参数2
			if scb then scb(2) end
			--停止正在播放的音频
			if not stop() then
				spriority,styp,spath,svol,scb,sdup,sduprd,spending = priority,typ,path,vol,cb,dup,duprd,true
				return
			end
		--将要播放的音频优先级 低于 正在播放的音频优先级
		elseif priority < spriority or (sstrategy~=1 and priority==spriority) then
			if not sdup then return	end	
		end
	end

	playbegin(priority,typ,path,vol,cb,dup,duprd)
end

--[[
函数名：stop
功能  ：停止音频播放
参数  ：无
返回值：如果可以成功同步停止，返回true，否则返回nil
]]
function stop()
	if styp then
		local typ,path = styp,spath		
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
		--停止循环播放定时器
		sys.timer_stop_all(play)
		--停止音频播放
		_stop()
		if typ=="TTS" or typ=="TTSCC" then stoptts() return end
		if typ=="RECORD" then stoprecord(true,false,tonumber(smatch(path,"(%d+)&")),tonumber(smatch(path,"&(%d+)"))) return end
	end
	return true
end

--[[
函数名：playend
功能  ：音频播放成功结束处理函数
参数  ：无
返回值：无
]]
function playend()
	print("playend",sdup,sduprd)
	if (styp=="TTS" or styp=="TTSCC") and not sdup then stoptts() end
	if styp=="RECORD" and not sdup then stoprecord(true,false,tonumber(smatch(spath,"(%d+)&")),tonumber(smatch(spath,"&(%d+)"))) end
	--需要重复播放
	if sdup then
		--存在重复播放间隔
		if sduprd then
			sys.timer_start(play,sduprd,spriority,styp,spath,svol,scb,sdup,sduprd)
		--不存在重复播放间隔
		elseif styp=="TTS" or styp=="TTSCC" or styp=="RECORD" then
			play(spriority,styp,spath,svol,scb,sdup,sduprd)
		end
	--不需要重复播放
	else
		--如果正在播放的音频有回调函数，则执行回调，传入参数0
		if scb then scb(0) end
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
	end
end

--[[
函数名：playerr
功能  ：音频播放失败处理函数
参数  ：无
返回值：无
]]
function playerr()
	print("playerr")
	if styp=="TTS" or styp=="TTSCC" then stoptts() end
	if styp=="RECORD" then stoprecord(true,false,tonumber(smatch(spath,"(%d+)&")),tonumber(smatch(spath,"&(%d+)"))) end
	--如果正在播放的音频有回调函数，则执行回调，传入参数1
	if scb then scb(1) end
	spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
end

local stopreqcb
--[[
函数名：audstopreq
功能  ：lib脚本间发送消息AUDIO_STOP_REQ的处理函数
参数  ：
		cb：音频停止后的回调函数
返回值：无
]]
local function audstopreq(cb)
	if stop() and cb then cb() return end
	stopreqcb = cb
end

--[[
函数名：ttstopind
功能  ：调用stoptts()接口后，tts停止播放后的消息处理函数
参数  ：无
返回值：无
]]
function ttstopind()
	print("ttstopind",spending,stopreqcb)
	if stopreqcb then
		stopreqcb()
		stopreqcb = nil
	elseif spending then
		playbegin(spriority,styp,spath,svol,scb,sdup,sduprd)
	end
end

--[[
函数名：recordstopind
功能  ：调用stoprecord()接口后，record停止播放后的消息处理函数
参数  ：无
返回值：无
]]
function recordstopind()
	print("recordstopind",spending,stopreqcb)
	if stopreqcb then
		stopreqcb()
		stopreqcb = nil
	elseif spending then
		playbegin(spriority,styp,spath,svol,scb,sdup,sduprd)
	end
end

local procer =
{
	AUDIO_STOP_REQ = audstopreq,--lib脚本间通过发送消息来实现音频停止，用户脚本不要发送此消息
}
--注册消息处理函数表
sys.regapp(procer)
