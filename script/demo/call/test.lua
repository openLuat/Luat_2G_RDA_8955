--[[
模块名称：通话测试
模块功能：测试呼入呼出
模块最后修改时间：2017.02.23
]]

module(...,package.seeall)
require"cc"
require"audio"
require"common"

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--[[
函数名：connected
功能  ：“通话已建立”消息处理函数
参数  ：无
返回值：无
]]
local function connected()
	print("connected")
	--5秒后播放TTS给对端，底层软件必须支持TTS功能
	sys.timer_start(audio.play,5000,0,"TTSCC",common.binstohexs(common.gb2312toucs2("通话中播放TTS测试")),audiocore.VOL7)
	--50秒之后主动结束通话
	sys.timer_start(cc.hangup,50000,"AUTO_DISCONNECT")
end

--[[
函数名：disconnected
功能  ：“通话已结束”消息处理函数
参数  ：
		para：通话结束原因值
			  "LOCAL_HANG_UP"：用户主动调用cc.hangup接口挂断通话
			  "CALL_FAILED"：用户调用cc.dial接口呼出，at命令执行失败
			  "NO CARRIER"：呼叫无应答
			  "BUSY"：占线
			  "NO ANSWER"：呼叫无应答
返回值：无
]]
local function disconnected(para)
	print("disconnected:"..(para or "nil"))
	sys.timer_stop(cc.hangup,"AUTO_DISCONNECT")
end

--[[
函数名：incoming
功能  ：“来电”消息处理函数
参数  ：
		num：string类型，来电号码
返回值：无
]]
local function incoming(num)
	print("incoming:"..num)
	--接听来电
	cc.accept()
end

--[[
函数名：ready
功能  ：“通话功能模块准备就绪”消息处理函数
参数  ：无
返回值：无
]]
local function ready()
	print("ready")
	--呼叫10086
	cc.dial("10086")
end

--[[
函数名：dtmfdetected
功能  ：“通话中收到对方的DTMF”消息处理函数
参数  ：
		dtmf：string类型，收到的DTMF字符
返回值：无
]]
local function dtmfdetected(dtmf)
	print("dtmfdetected",dtmf)
end

--[[
函数名：alerting
功能  ：“呼叫过程中已收到对方振铃”消息处理函数
参数  ：无
返回值：无
]]
local function alerting()
	print("alerting")
end

--注册消息的用户回调函数
cc.regcb("READY",ready,"INCOMING",incoming,"CONNECTED",connected,"DISCONNECTED",disconnected,"DTMF",dtmfdetected,"ALERTING",alerting)
