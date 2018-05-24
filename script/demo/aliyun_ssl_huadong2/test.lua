module(...,package.seeall)

require"aliyuniotssl"
require"misc"

--阿里云华东2站点上创建的产品的ProductKey，用户根据实际值自行修改
local PRODUCT_KEY = "b0FMK1Ga5cp"
--除了上面的PRODUCT_KEY外，还需要设备名称和设备证书
--设备名称使用函数getDeviceName的返回值，默认为设备的IMEI
--设备证书使用函数getDeviceSecret的返回值，默认为设备的SN
--单体测试时，可以直接修改getDeviceName和getDeviceSecret的返回值
--批量量产时，使用设备的IMEI和SN；合宙生产的模块，都有唯一的IMEI，用户可以在自己的产线批量写入跟IMEI（设备名称）对应的SN（设备证书）
--或者用户自建一个服务器，设备上报IMEI给服务器，服务器返回对应的设备证书，然后调用misc.setsn接口写到设备的SN中

--[[
函数名：getDeviceName
功能  ：获取设备名称
参数  ：无
返回值：设备名称
]]
local function getDeviceName()
	--默认使用设备的IMEI作为设备名称
	--return "862991419835241"
	return misc.getimei()
end

--[[
函数名：getDeviceSecret
功能  ：获取设备证书
参数  ：无
返回值：设备证书
]]
local function getDeviceSecret()
	--默认使用设备的SN作为设备证书
	--用户单体测试时，可以在此处直接返回阿里云的iot控制台上生成的设备证书，例如return "y7MTCG6Gk33Ux26bbWSpANl4OaI0bg5Q"
	--return "y7MTCG6Gk33Ux26bbWSpANl4OaI0bg5Q"
	return misc.getsn()
end


local qos1cnt = 1

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上aliyuniot前缀
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
	aliyuniotssl.publish("/"..PRODUCT_KEY.."/"..getDeviceName().."/update","qos1data",1,pubqos1testackcb,"publish1test_"..qos1cnt)
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
	aliyuniotssl.publish("/"..PRODUCT_KEY.."/"..getDeviceName().."/update","device receive:"..payload,qos)
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
	aliyuniotssl.subscribe({{topic="/"..PRODUCT_KEY.."/"..getDeviceName().."/get",qos=0}, {topic="/"..PRODUCT_KEY.."/"..getDeviceName().."/get",qos=1}}, subackcb, "subscribegetopic")
	--注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
	aliyuniotssl.regevtcb({MESSAGE=rcvmessagecb})
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

--配置产品key，设备名称和设备证书；第二个参数必须传入nil（此参数是为了兼容阿里云杭州站点）
--注意：如果使用imei和sn作为设备名称和设备证书时，不要把getDeviceName和getDeviceSecret替换为misc.getimei()和misc.getsn()
--因为开机就调用misc.getimei()和misc.getsn()，获取不到值
aliyuniotssl.config(PRODUCT_KEY,nil,getDeviceName,getDeviceSecret)
--setMqtt接口不是必须的，aLiYun.lua中有这个接口设置的参数默认值，如果默认值满足不了需求，参考下面注释掉的代码，去设置参数
--aliyuniotssl.setMqtt(0)
aliyuniotssl.regcb(connectedcb,connecterrcb)





--[[
重要提醒：
一旦使用了阿里云OTA远程升级模块脚本功能，强烈建议使用dbg功能，打开下面两行注释的代码
因为通过远程升级新版本的脚本后，如果新版本的脚本运行时有语法错误，则会重启自动回退到最后一次本地烧写的版本
回退后，一旦连接上升级服务器，还会继续远程升级。就陷入了一个“远程升级新版本->新版本运行出错，重启->自动回退到旧版本”的死循环，导致功能异常和浪费数据流量
例如本地烧写的版本是1.0.0，服务器上配置了1.0.1版本，但是1.0.1版本运行时有语法错误，则设备会循环“远程升级到1.0.1->1.0.1运行出错，重启->自动回退到1.0.0”
一旦加上dbg功能后，发生语法错误重启后，会将语法错误上报到dbg服务器。开发人员查看语法错误日志，可以及时修正语法错误，持续迭代版本
dbg服务器支持TCP和UDP协议，收到任何上报，都要回复大写的OK
如果不方便自己搭建dbg服务器，可以使用合宙提供的"UDP","ota.airm2m.com",9072服务器
在iot.openluat.com中登录，进入一个产品，在左侧的"查询debug"中可以查询设备上报的错误信息
]]
--require"dbg"
--sys.timer_start(dbg.setup,12000,"UDP","ota.airm2m.com",9072)

--要使用阿里云OTA功能，必须参考本文件138行aliyuniotssl.config(PRODUCT_KEY,nil,getDeviceName,getDeviceSecret)去配置产品key，设备名称和设备证书
--然后加载阿里云OTA功能模块(打开下面的代码注释)
--require"aliyuniotota"
--如果利用阿里云OTA功能去下载升级合宙模块的新固件，默认的固件版本号格式为：_G.PROJECT.."_".._G.VERSION.."_"..sys.getcorever()，则到此为止，不需要再看下文说明


--如果利用阿里云OTA功能去下载其他升级包，例如模块外接的MCU升级包，则根据实际情况，打开下面的代码注释，调用设置接口进行配置和处理
--设置MCU当前运行的固件版本号
--aliyuniotota.setVer("MCU_VERSION_1.0.0")
--设置新固件下载后保存的文件名
--aliyuniotota.setName("MCU_FIRMWARE.bin")

--[[
函数名：otaCb
功能  ：新固件文件下载结束后的回调函数
参数  ：
		result：下载结果，true为成功，false为失败
		filePath：新固件文件保存的完整路径，只有result为true时，此参数才有意义
返回值：无
]]
--[[
local function otaCb(result,filePath)
	print("otaCb",result,filePath)
	if result then
		--根据自己的需求，去使用文件filePath
		local fileHandle = io.open(filePath,"rb")
		if not fileHandle then print("otaCb open file error") return end
		local current = fileHandle:seek()
		local size = fileHandle:seek("end")
		fileHandle:seek("set",current)
		--输出文件长度
		print("otaCb size",size)
		
		--输出文件内容，如果文件太大，一次性读出文件内容可能会造成内存不足，分次读出可以避免此问题
		if size<=4096 then
			print(fileHandle:read("*all"))
		else
			--分段读取文件内容
		end
		
		fileHandle:close()
		
		--此处上报新固件版本号（仅供测试使用）
		--用户开发自己的程序时，根据下载下来的新固件，执行升级动作
		--升级成功后，调用aliyuniotota.setVer上报新固件版本号
		--如果升级失败，调用aliyuniotota.setVer上报旧固件版本号
		aliyuniotota.setVer("MCU_VERSION_1.0.1")
	end
	
	--文件使用完之后，如果以后不再需求，需要自行删除
	if filePath then os.remove(filePath) end
end
]]

--设置新固件下载结果的回调函数
--aliyuniotota.setCb(otaCb)
