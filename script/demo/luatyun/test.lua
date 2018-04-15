module(...,package.seeall)

require"luatyuniot"

local qos1cnt = 1

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
函数名：pubqos1testackcb
功能  ：发布1条qos为1的消息后收到PUBACK的回调函数
参数  ：
		usertag：调用mqttclient:publish时传入的usertag
		result：true表示发布成功，false或者nil表示失败
返回值：无
]]
local function pubqos1testackcb(usertag,result)
	print("pubqos1testackcb",usertag,result)
	sys.timer_start(pubqos1test,20000)
	qos1cnt = qos1cnt+1
end

--[[
函数名：pubqos1test
功能  ：发布1条qos为1的消息
参数  ：无
返回值：无
]]
function pubqos1test()
	--注意：在此处自己去控制payload的内容编码，luatyuniot库中不会对payload的内容做任何编码转换
	luatyuniot.publish("qos1data",1,pubqos1testackcb,"publish1test_"..qos1cnt)
end

--[[
函数名：rcvmessage
功能  ：收到PUBLISH消息时的回调函数
参数  ：
		topic：消息主题（gb2312编码）
		payload：消息负载（原始编码，收到的payload是什么内容，就是什么内容，没有做任何编码转换）
		qos：消息质量等级
返回值：无
]]
local function rcvmessagecb(topic,payload,qos)
	print("rcvmessagecb",topic,payload,qos)
end

--[[
函数名：connectedcb
功能  ：MQTT CONNECT成功回调函数
参数  ：无		
返回值：无
]]
local function connectedcb()
	print("connectedcb")
	--发布一条qos为1的消息
	pubqos1test()
end

--注册MQTT CONNECT成功回调和收到PUBLISH消息回调
luatyuniot.regcb(connectedcb,rcvmessagecb)

