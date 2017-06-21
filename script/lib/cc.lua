--[[
模块名称：通话管理
模块功能：呼入、呼出、接听、挂断
模块最后修改时间：2017.02.20
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local pm = require"pm"
module(...)

--加载常用的全局函数至本地
local ipairs,pairs,print,unpack,type = base.ipairs,base.pairs,base.print,base.unpack,base.type
local req = ril.request

--底层通话模块是否准备就绪，true就绪，false或者nil未就绪
local ccready = false
--通话存在标志，在以下状态时为true：
--主叫呼出中，被叫振铃中，通话中
local callexist = false
--记录来电号码保证同一电话多次振铃只提示一次
local incoming_num = nil 
--紧急号码表
local emergency_num = {"112", "911", "000", "08", "110", "119", "118", "999"}
--通话列表
local oldclcc,clcc = {},{}
--状态变化通知回调
local usercbs = {}


--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上cc前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("cc",...)
end

--[[
函数名：dispatch
功能  ：执行每个内部消息对应的用户回调
参数  ：
		evt：消息类型
		para：消息参数
返回值：无
]]
local function dispatch(evt,para)
	local tag = string.match(evt,"CALL_(.+)")
	if usercbs[tag] then usercbs[tag](para) end
end

--[[
函数名：regcb
功能  ：注册一个或者多个消息的用户回调函数
参数  ：
		evt1：消息类型，目前仅支持"READY","INCOMING","CONNECTED","DISCONNECTED","DTMF","ALERTING"
		cb1：消息对应的用户回调函数
		...：evt和cb成对出现
返回值：无
]]
function regcb(evt1,cb1,...)
	usercbs[evt1] = cb1
	local i
	for i=1,arg.n,2 do
		usercbs[unpack(arg,i,i)] = unpack(arg,i+1,i+1)
	end
end

--[[
函数名：deregcb
功能  ：撤销注册一个或者多个消息的用户回调函数
参数  ：
		evt1：消息类型，目前仅支持"READY","INCOMING","CONNECTED","DISCONNECTED","DTMF","ALERTING"
		...：0个或者多个evt
返回值：无
]]
function deregcb(evt1,...)
	usercbs[evt1] = nil
	local i
	for i=1,arg.n do
		usercbs[unpack(arg,i,i)] = nil
	end
end

--[[
函数名：isemergencynum
功能  ：检查号码是否为紧急号码
参数  ：
		num：待检查号码
返回值：true为紧急号码，false不为紧急号码
]]
local function isemergencynum(num)
	for k,v in ipairs(emergency_num) do
		if v == num then
			return true
		end
	end
	return false
end

--[[
函数名：clearincomingflag
功能  ：清除来电号码
参数  ：无
返回值：无
]]
local function clearincomingflag()
	incoming_num = nil
end

--[[
函数名：discevt
功能  ：通话结束消息处理
参数  ：
		reason：结束原因
返回值：无
]]
local function discevt(reason)
	callexist = false -- 通话结束 清除通话状态标志
	if incoming_num then sys.timer_start(clearincomingflag,1000) end
	pm.sleep("cc")
	--产生内部消息CALL_DISCONNECTED，通知用户程序通话结束
	dispatch("CALL_DISCONNECTED",reason)
	sys.timer_stop(qrylist,"MO")
end

--[[
函数名：anycallexist
功能  ：是否存在通话
参数  ：无
返回值：存在通话返回true，否则返回false
]]
function anycallexist()
	return callexist
end

--[[
函数名：qrylist
功能  ：查询通话列表
参数  ：无
返回值：无
]]
function qrylist()
	oldclcc = clcc
	clcc = {}
	req("AT+CLCC")
end

local function proclist()
	local k,v,isactive
	for k,v in pairs(clcc) do
		if v.sta == "0" then isactive = true break end
	end
	if isactive and #clcc > 1 then
		for k,v in pairs(clcc) do
			if v.sta ~= "0" then req("AT+CHLD=1"..v.id) end			
		end
	end
	
	if usercbs["ALERTING"] and #clcc >= 1 then
		for k,v in pairs(clcc) do
			if v.sta == "3" then
				--[[dispatch("CALL_ALERTING")
				break]]
				for m,n in pairs(oldclcc) do
					if v.id==n.id and v.dir==n.dir and n.sta~="3" then
						dispatch("CALL_ALERTING")
						break
					end
				end
			end
		end
	end
end

--[[
函数名：dial
功能  ：呼叫一个号码
参数  ：
		number：号码
		delay：延时delay毫秒后，才发送at命令呼叫，默认不延时
返回值：true表示允许发送at命令拨号并且发送at，false表示不允许at命令拨号
]]
function dial(number,delay)
	if number == "" or number == nil then
		return false
	end

	if ccready == false and not isemergencynum(number) then
		return false
	end

	pm.wake("cc")
	req(string.format("%s%s;","ATD",number),nil,nil,delay)
	callexist = true -- 主叫呼出

	return true
end

--[[
函数名：hangupnxt
功能  ：主动挂断所有通话
参数  ：无
返回值：无
]]
local function hangupnxt()
	req("AT+CHUP")
end

--[[
函数名：hangup
功能  ：主动挂断所有通话
参数  ：无
返回值：无
]]
function hangup()
	--如果存在audio模块
	if audio and type(audio)=="table" and audio.play then
		--先停止音频播放
		sys.dispatch("AUDIO_STOP_REQ",hangupnxt)
	else
		hangupnxt()
	end
end

--[[
函数名：acceptnxt
功能  ：接听来电
参数  ：无
返回值：无
]]
local function acceptnxt()
	req("ATA")
	pm.wake("cc")
end

--[[
函数名：accept
功能  ：接听来电
参数  ：无
返回值：无
]]
function accept()
	--如果存在audio模块
	if audio and type(audio)=="table" and audio.play then
		--先停止音频播放
		sys.dispatch("AUDIO_STOP_REQ",acceptnxt)
	else
		acceptnxt()
	end		
end

--[[
函数名：transvoice
功能  ：通话中发送声音到对端,必须是12.2K AMR格式
参数  ：
返回值：true为成功，false为失败
]]
function transvoice(data,loop,loop2)
	local f = io.open("/RecDir/rec000","wb")

	if f == nil then
		print("transvoice:open file error")
		return false
	end

	-- 有文件头并且是12.2K帧
	if string.sub(data,1,7) == "#!AMR\010\060" then
	-- 无文件头且是12.2K帧
	elseif string.byte(data,1) == 0x3C then
		f:write("#!AMR\010")
	else
		print("transvoice:must be 12.2K AMR")
		return false
	end

	f:write(data)
	f:close()

	req(string.format("AT+AUDREC=%d,%d,2,0,50000",loop2 == true and 1 or 0,loop == true and 1 or 0))

	return true
end

--[[
函数名：dtmfdetect
功能  ：设置dtmf检测是否使能以及灵敏度
参数  ：
		enable：true使能，false或者nil为不使能
		sens：灵敏度，默认3，最灵敏为1
返回值：无
]]
function dtmfdetect(enable,sens)
	if enable == true then
		if sens then
			req("AT+DTMFDET=2,1," .. sens)
		else
			req("AT+DTMFDET=2,1,3")
		end
	end

	req("AT+DTMFDET="..(enable and 1 or 0))
end

--[[
函数名：senddtmf
功能  ：发送dtmf到对端
参数  ：
		str：dtmf字符串
		playtime：每个dtmf播放时间，单位毫秒，默认100
		intvl：两个dtmf间隔，单位毫秒，默认100
返回值：无
]]
function senddtmf(str,playtime,intvl)
	if string.match(str,"([%dABCD%*#]+)") ~= str then
		print("senddtmf: illegal string "..str)
		return false
	end

	playtime = playtime and playtime or 100
	intvl = intvl and intvl or 100

	req("AT+SENDSOUND="..string.format("\"%s\",%d,%d",str,playtime,intvl))
end

local dtmfnum = {[71] = "Hz1000",[69] = "Hz1400",[70] = "Hz2300"}

--[[
函数名：parsedtmfnum
功能  ：dtmf解码，解码后，会产生一个内部消息AUDIO_DTMF_DETECT，携带解码后的DTMF字符
参数  ：
		data：dtmf字符串数据
返回值：无
]]
local function parsedtmfnum(data)
	local n = base.tonumber(string.match(data,"(%d+)"))
	local dtmf

	if (n >= 48 and n <= 57) or (n >=65 and n <= 68) or n == 42 or n == 35 then
		dtmf = string.char(n)
	else
		dtmf = dtmfnum[n]
	end

	if dtmf then
		dispatch("CALL_DTMF",dtmf)
	end
end

--[[
函数名：ccurc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
		data：通知的完整字符串信息
		prefix：通知的前缀
返回值：无
]]
local function ccurc(data,prefix)
	--底层通话模块准备就绪
	if data == "CALL READY" then
		ccready = true
		dispatch("CALL_READY")
		req("AT+CCWA=1")
	--通话建立通知
	elseif data == "CONNECT" then
		qrylist()		
		dispatch("CALL_CONNECTED")
		sys.timer_stop(qrylist,"MO")
		--先停止音频播放
		sys.dispatch("AUDIO_STOP_REQ")
	--通话挂断通知
	elseif data == "NO CARRIER" or data == "BUSY" or data == "NO ANSWER" then
		qrylist()
		discevt(data)
	--来电振铃
	elseif prefix == "+CLIP" then
		qrylist()
		local number = string.match(data,"\"(%+*%d*)\"",string.len(prefix)+1)
		callexist = true -- 被叫振铃
		if incoming_num ~= number then
			incoming_num = number
			dispatch("CALL_INCOMING",number)
		end
	elseif prefix == "+CCWA" then
		qrylist()
	--通话列表信息
	elseif prefix == "+CLCC" then
		local id,dir,sta = string.match(data,"%+CLCC:%s*(%d+),(%d),(%d)")
		if id then
			table.insert(clcc,{id=id,dir=dir,sta=sta})
			proclist()
		end
	--DTMF接收检测
	elseif prefix == "+DTMFDET" then
		parsedtmfnum(data)
	end
end

--[[
函数名：ccrsp
功能  ：本功能模块内“通过虚拟串口发送到底层core软件的AT命令”的应答处理
参数  ：
		cmd：此应答对应的AT命令
		success：AT命令执行结果，true或者false
		response：AT命令的应答中的执行结果字符串
		intermediate：AT命令的应答中的中间信息
返回值：无
]]
local function ccrsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+*%u+)")
	--拨号应答
	if prefix == "D" then
		if not success then
			discevt("CALL_FAILED")
		else
			if usercbs["ALERTING"] then sys.timer_loop_start(qrylist,1000,"MO") end
		end
	--挂断所有通话应答
	elseif prefix == "+CHUP" then
		discevt("LOCAL_HANG_UP")
	--接听来电应答
	elseif prefix == "A" then
		incoming_num = nil
		dispatch("CALL_CONNECTED")
		sys.timer_stop(qrylist,"MO")
	end
	qrylist()
end

--注册以下通知的处理函数
ril.regurc("CALL READY",ccurc)
ril.regurc("CONNECT",ccurc)
ril.regurc("NO CARRIER",ccurc)
ril.regurc("NO ANSWER",ccurc)
ril.regurc("BUSY",ccurc)
ril.regurc("+CLIP",ccurc)
ril.regurc("+CLCC",ccurc)
ril.regurc("+CCWA",ccurc)
ril.regurc("+DTMFDET",ccurc)
--注册以下AT命令的应答处理函数
ril.regrsp("D",ccrsp)
ril.regrsp("A",ccrsp)
ril.regrsp("+CHUP",ccrsp)
ril.regrsp("+CHLD",ccrsp)

--开启拨号音,忙音检测
req("ATX4") 
--开启来电urc上报
req("AT+CLIP=1")
dtmfdetect(true)
