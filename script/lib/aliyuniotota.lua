--定义模块,导入依赖库
require"aliyuniotssl"
require"https"
module(...,package.seeall)

--gVersion：固件版本号字符串，如果用户没有调用本文件的setVer接口设置，则默认为_G.PROJECT.."_".._G.VERSION.."_"..sys.getcorever()
--gPath：阿里云iot网站上配置的新固件文件下载后，在模块中的保存路径，如果用户没有调用本文件的setName接口设置，则默认为/luazip/update.bin
--gCb：新固件下载成功后，要执行的回调函数
local gVersion,gPath,gCb = _G.PROJECT.."_".._G.VERSION.."_"..sys.getcorever(),"/luazip/update.bin"

--productKey：产品标识
--deviceName：设备名称
local productKey,deviceName

--verRpted：版本号是否已经上报
local verRpted

--httpClient：下载新固件的http client
--httpUrl：get命令中的url字段
local httpClient,httpHost,httpUrl
--阿里云后台下的新固件MD5值
local gFileMD5,gFileSize,gFilePath

--lastStep：最后一次上报的下载新固件的进度
local lastStep


--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上aliyuniotota前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("aliyuniotota",...)
end

--[[
函数名：verRptCb
功能  ：上报固件版本号给云端后，收到PUBACK时的回调函数
参数  ：
		tag：此处无意义
		result：true表示上报成功，false或者nil表示失败
返回值：无
]]
local function verRptCb(tag,result)
	print("verRptCb",result)
	verRpted = result
	if not result then sys.timer_start(verRpt,20000) end
end

--[[
函数名：verRpt
功能  ：上报固件版本号给云端
参数  ：无
返回值：无
]]
function verRpt()
	print("verRpt",gVersion)
	aliyuniotssl.publish("/ota/device/inform/"..productKey.."/"..deviceName,"{\"id\":1,\"params\":{\"version\":\""..gVersion.."\"}}",1,verRptCb)
end

--[[
函数名：connectedCb
功能  ：MQTT CONNECT成功回调函数
参数  ：
		key：ProductKey
		name：设备名称
返回值：无
]]
function connectedCb(key,name)
	print("connectedCb",verRpted)
	productKey,deviceName = key,name
	--订阅主题
	aliyuniotssl.subscribe({{topic="/ota/device/upgrade/"..key.."/"..name,qos=0}, {topic="/ota/device/upgrade/"..key.."/"..name,qos=1}})
	if not verRpted then		
		--上报固件版本号给云端
		verRpt()
	end
end

--[[
函数名：upgradeStepRpt
功能  ：新固件文件下载进度上报
参数  ：
		step：1到100代表下载进度比；-2代表下载失败
		desc：描述信息，可为空或者nil
返回值：无
]]
local function upgradeStepRpt(step,desc)
	print("upgradeStepRpt",step,desc)
	if step<=0 or step==100 then sys.timer_stop(getPercent) end
	lastStep = step
	aliyuniotssl.publish("/ota/device/progress/"..productKey.."/"..deviceName,"{\"id\":1,\"params\":{\"step\":\""..step.."\",\"desc\":\""..(desc or "").."\"}}")
end

--[[
函数名：downloadCb
功能  ：新固件文件下载结束后的处理函数
参数  ：
		result：下载结果，true为成功，false为失败
		filePath：新固件文件保存的完整路径，只有result为true时，此参数才有意义
返回值：无
]]
local function downloadCb(result,filePath)
	print("downloadCb",gCb,result,filePath,gFileSize,io.filesize(filePath))
	sys.setrestart(true,4)
	sys.timer_stop(sys.setrestart,true,4)
	--如果使用的lod版本大于等于V0020，则校验MD5
	if result and tonumber(string.match(sys.getcorever(),"Luat_V(%d+)_"))>=20 then
		local calMD5 = crypto.md5(filePath,"file")
		result = (string.upper(calMD5) == string.upper(gFileMD5))
		print("downloadCb cmp md5",result,calMD5,gFileMD5)		
	end
	if gCb then
		gCb(result,filePath)
	else
		if result then sys.restart("ALIYUN_OTA") end
	end
end

local function httpInitConnectCb()
	httpConnectedCb(true)
end

local function httpConnect(init)
	httpClient=https.create(httpHost,443)
	httpClient:connect((init and httpInitConnectCb or httpConnectedCb),httpErrCb)
end

--[[
函数名：httpRcvCb
功能  ：接收回调函数（下载文件）
参数  ：result：数据接收结果(此参数为0时，后面的几个参数才有意义)
				0:成功
				1:失败，还没有接收完整，被服务器断开了
				2:表示实体超出实际实体，错误，不输出实体内容
				3:接收超时
		statuscode：http应答的状态码，string类型或者nil
		head：http应答的头部数据，table类型或者nil
		filename: 下载文件的完整路径名
返回值：无
]]
local function httpRcvCb(result,statuscode,head,filename)
	print("httpRcvCb",result,statuscode,head,filename)
	gFilePath = filename
	if result==0 then
		upgradeStepRpt(100,result)
		sys.timer_start(downloadCb,3000,true,filename)
		httpClient:destroy()
	else
		httpClient:destroy(httpConnect)
	end
end

--[[
函数名：getPercent
功能  ：获取文件下载百分比
参数  ：
返回值：
]]
function getPercent()
	local step = httpClient:getrcvpercent()
	if step~=0 and step~=lastStep then
		upgradeStepRpt(step)
	end
	sys.timer_start(getPercent,5000)
end

--[[
函数名：httpConnectedCb
功能  ：SOCKET connected 成功回调函数
参数  ：
		init：是否为本次下载新固件过程中的第一次连接
返回值：
]]
function httpConnectedCb(init)
	local rangeStr = "Range: bytes="..(init and 0 or io.filesize(gFilePath)).."-"
	gFilePath = httpClient:request("GET",httpUrl,{rangeStr},"",httpRcvCb,gPath)
	if init then os.remove(gFilePath) end
	sys.timer_start(getPercent,5000)
end 

--[[
函数名：httpErrCb
功能  ：SOCKET失败回调函数
参数  ：
		r：string类型，失败原因值
		CONNECT: socket一直连接失败，不再尝试自动重连
		SEND：socket发送数据失败，不再尝试自动重连
返回值：无
]]
function httpErrCb(r)
	print("httpErrCb",r)
	upgradeStepRpt(-2,r)
	downloadCb(false)
	httpClient:destroy()	
end

--[[
函数名：upgrade
功能  ：收到云端固件升级通知消息时的回调函数
参数  ：
		payload：消息负载（原始编码，收到的payload是什么内容，就是什么内容，没有做任何编码转换）
返回值：无
]]
function upgrade(payload)	
	local res,jsonData = pcall(json.decode,payload)
	print("upgrade",res,payload)	
	if res then
		if jsonData.data and jsonData.data.url then
			print("url",jsonData.data.url)
			local host,url = string.match(jsonData.data.url,"https://(.-)/(.+)")
			print("httpUrl",url)
			if host and url then
				httpHost = host
				httpUrl = "/"..url
				httpConnect(true)
			end
			gFileMD5 = jsonData.data.md5
			gFileSize = jsonData.data.size
		end
	end
end

--[[
函数名：setVer
功能  ：设置固件版本号
参数  ：
		version：string类型，固件版本号
返回值：无
]]
function setVer(version)
	local oldVer = gVersion
	gVersion = version
	if verRpted and version~=oldVer then		
		verRpted = false
		verRpt()
	end
end

--[[
函数名：setName
功能  ：设置新固件保存的文件名
参数  ：
		name：string类型，新固件文件名
返回值：无
]]
function setName(name)
	gPath = name
end

--[[
函数名：setCb
功能  ：设置新固件下载后的回调函数
参数  ：
		cb：function类型，新固件下载后的回调函数
返回值：无
]]
function setCb(cb)
	gCb = cb
end

sys.setrestart(false,4)
sys.timer_start(sys.setrestart,300000,true,4)
