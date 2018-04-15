--定义模块,导入依赖库
local base = _G
local sys  = require"sys"
local mqtt = require"mqtt"
local misc = require"misc"
local lpack = require"pack"
require"aliyuniotauth"
module(...,package.seeall)

local slen = string.len

--阿里云上创建的key和secret，用户不要修改这两个值，否则无法连接上Luat的云后台
local PRODUCT_KEY,PRODUCT_SECRET = "1000163201","4K8nYcT4Wiannoev"
--mqtt客户端对象,数据服务器地址,数据服务器端口表
local mqttclient,gaddr,gports,gclientid,gusername
--目前使用的gport表中的index
local gportidx = 1
local gconnectedcb,gconnecterrcb,grcvmessagecb

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上luatyuniot前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("luatyuniot",...)
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
			sys.restart("luatyuniot sck connect err")
		end
	end
end

function bcd(d,n)
	local l = slen(d or "")
	local num
	local t = {}

	for i=1,l,2 do
		num = tonumber(string.sub(d,i,i+1),16)

		if i == l then
			num = 0xf0+num
		else
			num = (num%0x10)*0x10 + num/0x10
		end

		table.insert(t,num)
	end

	local s = string.char(_G.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. string.rep("\255",n-l)
	elseif l > n then
		s = string.sub(s,1,n)
	end

	return s
end

local base64bcdimei
local function getbase64bcdimei()
	if not base64bcdimei then
		local imei = misc.getimei()
		local imei1,imei2 = string.sub(imei,1,7),string.sub(imei,8,14)
		imei1,imei2 = string.format("%06X",tonumber(imei1)),string.format("%06X",tonumber(imei2))
		imei = common.hexstobins(imei1..imei2)
		base64bcdimei = crypto.base64_encode(imei,6)
		if string.sub(base64bcdimei,-1,-1)=="=" then base64bcdimei = string.sub(base64bcdimei,1,-2) end
		base64bcdimei = string.gsub(base64bcdimei,"+","-")
		base64bcdimei = string.gsub(base64bcdimei,"/","_")
		base64bcdimei = string.gsub(base64bcdimei,"=","@")
	end
	return base64bcdimei
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
	mqttclient:subscribe({{topic="/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/g",qos=0}, {topic="/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/g",qos=1}}, subackcb, "subscribegetopic")
	assert(_G.PRODUCT_KEY and _G.PROJECT and _G.VERSION,"undefine PRODUCT_KEY or PROJECT or VERSION in main.lua")
	local payload = lpack.pack("bbpbpbpbpbpbp",
								0,
								0,_G.PRODUCT_KEY,
								1,_G.PROJECT.."_"..sys.getcorever(),
								2,bcd(string.gsub(_G.VERSION,"%.","")),
								3,misc.getsn(),
								4,sim.geticcid(),
								5,sim.getimsi()
								)
	mqttclient:publish("/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/1/0",payload,1)
	--注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
	mqttclient:regevtcb({MESSAGE=grcvmessagecb})
	if gconnectedcb then gconnectedcb() end
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
	if gconnecterrcb then gconnecterrcb(r) end
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
	mqttclient:connect(gclientid,600,gusername,"",connectedcb,connecterrcb,sckerrcb)
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
		devicename：string类型，设备名
返回值：无
]]
local function config(productkey,productsecret,devicename)
	sys.dispatch("ALIYUN_AUTH_BGN",productkey,productsecret,devicename)
end

function regcb(connectedcb,rcvmessagecb,connecterrcb)
	gconnectedcb,grcvmessagecb,gconnecterrcb = connectedcb,rcvmessagecb,connecterrcb
end

function publish(payload,qos,ackcb,usertag)
	mqttclient:publish("/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/u",payload,qos,ackcb,usertag)
end

local function imeirdy()
	getbase64bcdimei()
	config(PRODUCT_KEY,PRODUCT_SECRET,getbase64bcdimei())
	return true
end

sys.regapp(imeirdy,"IMEI_READY")
