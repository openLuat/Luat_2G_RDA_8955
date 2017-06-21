--定义模块,导入依赖库
local base = _G
local string = require"string"
local sys  = require"sys"
local mqtt = require"mqtt"
require"aliyuniotauth"
module(...,package.seeall)

--mqtt客户端对象,数据服务器地址,数据服务器端口表
local mqttclient,gaddr,gports,gclientid,gusername
--目前使用的gport表中的index
local gportidx = 1
local gconnectedcb,gconnecterrcb

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上aliyuniot前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("aliyuniot",...)
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

function connect(change)
	if change then
		mqttclient:change("TCP",gaddr,gports[gportidx])
	else
		--创建一个mqtt client
		mqttclient = mqtt.create("TCP",gaddr,gports[gportidx])
	end
	--配置遗嘱参数,如果有需要，打开下面一行代码，并且根据自己的需求调整will参数
	--mqttclient:configwill(1,0,0,"/willtopic","will payload")
	--连接mqtt服务器
	mqttclient:connect(gclientid,600,gusername,"",gconnectedcb,gconnecterrcb,sckerrcb)
end

--[[
函数名：databgn
功能  ：鉴权服务器认证成功，允许设备连接数据服务器
参数  ：无		
返回值：无
]]
local function databgn(host,ports,clientid,username)
	gaddr,gports,gclientid,gusername = host or gaddr,ports or gports,clientid,username
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
		productsecret：string类型，产品密钥，必选参数
返回值：无
]]
function config(productkey,productsecret)
	sys.dispatch("ALIYUN_AUTH_BGN",productkey,productsecret)
end

function regcb(connectedcb,connecterrcb)
	gconnectedcb,gconnecterrcb = connectedcb,connecterrcb
end

function subscribe(topics,ackcb,usertag)
	mqttclient:subscribe(topics,ackcb,usertag)
end

function regevtcb(evtcbs)
	mqttclient:regevtcb(evtcbs)
end

function publish(topic,payload,qos,ackcb,usertag)
	mqttclient:publish(topic,payload,qos,ackcb,usertag)
end
