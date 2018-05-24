--定义模块,导入依赖库
require"sys"
require"mqttssl"
module(...,package.seeall)

--mqtt客户端对象,数据服务器地址,数据服务器端口表
local mqttclient,gaddr,gports,gclientid,gusername,gpassword
--目前使用的gport表中的index
local gportidx = 1
local gconnectedcb,gconnecterrcb,gevtcbs
local productKey,deviceName
local sKeepAlive,sCleanSession,sWill

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上aliyuniot前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("aliyuniotssl",...)
end

--[[
函数名：sckerrcb
功能  ：SOCKET失败回调函数
参数  ：
		r：string类型，失败原因值
			CONNECT：mqtt内部，socket一直连接失败，不再尝试自动重连
返回值：无
]]
local function sckerrcb(r)
	print("sckerrcb",r,gportidx,#gports)
	if r=="CONNECT" then
		if gportidx<#gports then
			gportidx = gportidx+1
			connect(true)
		else
			sys.restart("aliyuniot sck connect err")
		end
	end
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
	--OTA消息
	if topic=="/ota/device/upgrade/"..productKey.."/"..(type(deviceName)=="function" and deviceName() or (deviceName or misc.getimei())) then
		if aliyuniotota and type(aliyuniotota)=="table" and aliyuniotota.upgrade and type(aliyuniotota.upgrade)=="function" then
			aliyuniotota.upgrade(payload)
		end
	--其他消息
	else
		gevtcbs.MESSAGE(topic,payload,qos)
	end
end

local function consucb()
	if gconnectedcb then gconnectedcb() end
	if aliyuniotota and type(aliyuniotota)=="table" and aliyuniotota.connectedCb and type(aliyuniotota.connectedCb)=="function" then
		aliyuniotota.connectedCb(productKey,type(deviceName)=="function" and deviceName() or (deviceName or misc.getimei()))
	end
end

function connect(change)
	if change then
		mqttclient:change("TCP",gaddr,gports[gportidx])
	else
		--创建一个mqttssl client
		mqttclient = mqttssl.create("TCP",gaddr,gports[gportidx])
	end
	--配置遗嘱参数,如果有需要，打开下面一行代码，并且根据自己的需求调整will参数
	if sWill then
		mqttclient:configwill(1,sWill.qos,sWill.retain,sWill.topic,sWill.payload)
	end
	mqttclient:setcleansession(sCleanSession)
	--连接mqtt服务器
	mqttclient:connect(gclientid,sKeepAlive or 240,gusername,gpassword,consucb,gconnecterrcb,sckerrcb)
end

--[[
函数名：databgn
功能  ：鉴权服务器认证成功，允许设备连接数据服务器
参数  ：无		
返回值：无
]]
local function databgn(host,ports,clientid,username,password)
	gaddr,gports,gclientid,gusername,gpassword = host or gaddr,ports or gports,clientid,username,password or ""
	gportidx = 1
	connect()
end

local procer =
{
	ALIYUN_DATA_BGN = databgn,
}

sys.regapp(procer)


--[[
函数名：config
功能  ：配置阿里云物联网产品信息和设备信息
参数  ：
		productkey：string类型，产品标识，必选参数
		productsecret：string类型，产品密钥，必选参数,如果是阿里云华东2站点，必须传入nil
		devicename: string类型或者function类型，设备名，可选参数
		devicesecret: string类型或者function类型，设备证书，可选参数
返回值：无
]]
function config(productkey,productsecret,devicename,devicesecret)
	if productsecret then
		require"aliyuniotauth"
	else
		require"aliyuniotauthssl"
	end
	productKey,deviceName = productkey,devicename
	sys.dispatch("ALIYUN_AUTH_BGN",productkey,productsecret,devicename,devicesecret)
end

--- 设置MQTT数据通道的参数
-- @number[opt=1] cleanSession 1/0
-- @table[opt=nil] will 遗嘱参数，格式为{qos=, retain=, topic=, payload=}
-- @number[opt=240] keepAlive，单位秒
-- @return nil
-- @usage
-- aliyuniotssl.setMqtt(0)
-- aliyuniotssl.setMqtt(1,{qos=0,retain=1,topic="/willTopic",payload="will payload"})
-- aliyuniotssl.setMqtt(1,{qos=0,retain=1,topic="/willTopic",payload="will payload"},120)
function setMqtt(cleanSession,will,keepAlive)
    sCleanSession,sWill,sKeepAlive = cleanSession,will,keepAlive
end

function regcb(connectedcb,connecterrcb)
	gconnectedcb,gconnecterrcb = connectedcb,connecterrcb
end

function subscribe(topics,ackcb,usertag)
	mqttclient:subscribe(topics,ackcb,usertag)
end

function regevtcb(evtcbs)
	gevtcbs = evtcbs
	mqttclient:regevtcb({MESSAGE=rcvmessagecb})
end

function publish(topic,payload,qos,ackcb,usertag)
	if mqttclient then
		mqttclient:publish(topic,payload,qos,ackcb,usertag)
	else
		if ackcb then ackcb(usertag,false) end
	end
end
