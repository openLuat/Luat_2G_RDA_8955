module(...,package.seeall)

require"aliyuniot"

--阿里云上创建的key和secret，用户如果自己在阿里云上创建项目，根据自己的项目信息，修改这两个值
local PRODUCT_KEY,PRODUCT_SECRET = "1000163201","4K8nYcT4Wiannoev"
--除了上面的两个信息外，还需要DEVICE_NAME和DEVICE_SECRET
--lib中会使用设备的IMEI和SN号用做DEVICE_NAME和DEVICE_SECRET，所以在阿里云上添加设备时，DEVICE_NAME就用IMEI，然后把生成的DEVICE_SECRET当做SN写入设备中

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
	--注意：在此处自己去控制payload的内容编码，aliyuniot库中不会对payload的内容做任何编码转换
	aliyuniot.publish("/"..PRODUCT_KEY.."/"..misc.getimei().."/update","qos1data",1,pubqos1testackcb,"publish1test_"..qos1cnt)
end

--[[
函数名：subackcb
功能  ：MQTT SUBSCRIBE之后收到SUBACK的回调函数
参数  ：
		usertag：调用mqttclient:subscribe时传入的usertag
		result：true表示订阅成功，false或者nil表示失败
返回值：无
]]
local function subackcb(usertag,result)
	print("subackcb",usertag,result)
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
	--订阅主题
	aliyuniot.subscribe({{topic="/"..PRODUCT_KEY.."/"..misc.getimei().."/get",qos=0}, {topic="/"..PRODUCT_KEY.."/"..misc.getimei().."/get",qos=1}}, subackcb, "subscribegetopic")
	--注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
	aliyuniot.regevtcb({MESSAGE=rcvmessagecb})
	--发布一条qos为1的消息
	pubqos1test()
end

--[[
函数名：connecterrcb
功能  ：MQTT CONNECT失败回调函数
参数  ：
		r：失败原因值
			1：Connection Refused: unacceptable protocol version
			2：Connection Refused: identifier rejected
			3：Connection Refused: server unavailable
			4：Connection Refused: bad user name or password
			5：Connection Refused: not authorized
返回值：无
]]
local function connecterrcb(r)
	print("connecterrcb",r)
end

aliyuniot.config(PRODUCT_KEY,PRODUCT_SECRET)
aliyuniot.regcb(connectedcb,connecterrcb)
