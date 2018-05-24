--- 模块功能：阿里云功能测试.
-- 支持数据传输和OTA功能
-- @author openLuat
-- @module aLiYun.testALiYun
-- @license MIT
-- @copyright openLuat
-- @release 2018.04.14

module(...,package.seeall)

require"aLiYun"
require"misc"

--阿里云华东2站点上创建的产品的ProductKey，用户根据实际值自行修改
local PRODUCT_KEY = "b0FMK1Ga5cp"
--采用“一机一密”认证方案除了上面的PRODUCT_KEY外，还需要设备名称和设备密钥
--设备名称使用函数getDeviceName的返回值，默认为设备的IMEI
--设备密钥使用函数getDeviceSecret的返回值，默认为设备的SN
--单体测试时，可以直接修改getDeviceName和getDeviceSecret的返回值
--批量量产时，使用设备的IMEI和SN；合宙生产的模块，都有唯一的IMEI，用户可以在自己的产线批量写入跟IMEI（设备名称）对应的SN（设备密钥）
--或者用户自建一个服务器，设备上报IMEI给服务器，服务器返回对应的设备密钥，然后调用misc.setSn接口写到设备的SN中

--local PRODUCT_KEY = "a1AoVqkCIbG"
--local PRODUCE_SECRET="7eCdPyR6fYPntFcM"
--采用“一型一密”认证方案时打开上面的注释，比“一机一密”认证方式额外提供提供PRODUCE_SECRET，PRODUCE_SECRET的值根据实际值自行修改
--设备请求接入时，云端动态下发该设备的DeviceSecret，DeviceSecret的保存方法默认使用setDeviceSecret将设备的SN替换成DeviceSecret
--之后设备密钥的获取便使用函数getDeviceSecret的返回值，然后使用ProductKey、DeviceName和DeviceSecret进行认证并建立连接。
--请参考126行的aLiYun.setup(PRODUCT_KEY,PRODUCE_SECRET,getDeviceName,getDeviceSecret,setDeviceSecret)去配置参数 

--[[
函数名：getDeviceName
功能  ：获取设备名称
参数  ：无
返回值：设备名称
]]
local function getDeviceName()
    --默认使用设备的IMEI作为设备名称
    --用户单体测试时，可以在此处直接返回阿里云的iot控制台上注册的设备名称，例如return "868575021150844"
    --return "Air202Test13"
    --return "862991419835241"
    return misc.getImei()
end

--[[
函数名：setDeviceSecret
功能  ：修改设备密钥
参数  ：设备密钥
返回值：无
]]
local function setDeviceSecret(s)
    --默认使用设备的SN作为设备密钥
    misc.setSn(s)
end


--[[
函数名：getDeviceSecret
功能  ：获取设备密钥
参数  ：无
返回值：设备密钥
]]
local function getDeviceSecret()
    --默认使用设备的SN作为设备密钥
    --用户单体测试时，可以在此处直接返回阿里云的iot控制台上生成的设备密钥，例如return "y7MTCG6Gk33Ux26bbWSpANl4OaI0bg5Q"
    --return "y7MTCG6Gk33Ux26bbWSpANl4OaI0bg5Q"
    return misc.getSn()
end

--阿里云客户端是否处于连接状态
local sConnected

local publishCnt = 1

--[[
函数名：pubqos1testackcb
功能  ：发布1条qos为1的消息后收到PUBACK的回调函数
参数  ：
		usertag：调用mqttclient:publish时传入的usertag
		result：true表示发布成功，false或者nil表示失败
返回值：无
]]
local function publishTestCb(result,para)
    log.info("testALiYun.publishTestCb",result,para)
    sys.timerStart(publishTest,20000)
    publishCnt = publishCnt+1
end

--发布一条QOS为1的消息
function publishTest()
    if sConnected then
        --注意：在此处自己去控制payload的内容编码，aLiYun库中不会对payload的内容做任何编码转换
        aLiYun.publish("/"..PRODUCT_KEY.."/"..getDeviceName().."/update","qos1data",1,publishTestCb,"publishTest_"..publishCnt)
    end
end

---数据接收的处理函数
-- @string topic，UTF8编码的消息主题
-- @number qos，消息质量等级
-- @string payload，原始编码的消息负载
local function rcvCbFnc(topic,qos,payload)
    log.info("testALiYun.rcvCbFnc",topic,qos,payload)
end

--- 连接结果的处理函数
-- @bool result，连接结果，true表示连接成功，false或者nil表示连接失败
local function connectCbFnc(result)
    log.info("testALiYun.connectCbFnc",result)
    sConnected = result
    if result then
        --订阅主题，不需要考虑订阅结果，如果订阅失败，aLiYun库中会自动重连
        aLiYun.subscribe({["/"..PRODUCT_KEY.."/"..getDeviceName().."/get"]=0, ["/"..PRODUCT_KEY.."/"..getDeviceName().."/get"]=1})
        --注册数据接收的处理函数
        aLiYun.on("receive",rcvCbFnc)
        --PUBLISH消息测试
        publishTest()
    end
end

--配置产品key，设备名称和设备密钥；采用一机一密的认证方式是，第二个参数传入nil，采用一型一密认证方式时，需要PRODUCE_SECRET，并提供第五个参数
--注意：如果使用imei和sn作为设备名称和设备证书时，不要把getDeviceName和getDeviceSecret替换为misc.getImei()和misc.getSn()
--注意：采用一型一密认证方式时，仅在首次激活时动态下发DeviceSecret
--因为开机就调用misc.getImei()和misc.getSn()，获取不到值
--一机一密
aLiYun.setup(PRODUCT_KEY,nil,getDeviceName,getDeviceSecret)
--一型一密
--aLiYun.setup(PRODUCT_KEY,PRODUCE_SECRET,getDeviceName,getDeviceSecret,setDeviceSecret)

--setMqtt接口不是必须的，aLiYun.lua中有这个接口设置的参数默认值，如果默认值满足不了需求，参考下面注释掉的代码，去设置参数
--aLiYun.setMqtt(0)
aLiYun.on("connect",connectCbFnc)


--要使用阿里云OTA功能，必须参考本文件124或者126行aLiYun.setup去配置参数
--然后加载阿里云OTA功能模块(打开下面的代码注释)
require"aLiYunOta"
--如果利用阿里云OTA功能去下载升级合宙模块的新固件，默认的固件版本号格式为：_G.PROJECT.."_".._G.VERSION.."_"..sys.getcorever()，下载结束后，直接重启，则到此为止，不需要再看下文说明


--如果下载升级合宙模块的新固件，下载结束后，自己控制是否重启
--如果利用阿里云OTA功能去下载其他升级包，例如模块外接的MCU升级包，则根据实际情况，打开下面的代码注释，调用设置接口进行配置和处理
--设置MCU当前运行的固件版本号
--aLiYunOta.setVer("MCU_VERSION_1.0.0")
--设置新固件下载后保存的文件名
--aLiYunOta.setName("MCU_FIRMWARE.bin")

--[[
函数名：otaCb
功能  ：新固件文件下载结束后的回调函数
参数  ：
		result：下载结果，true为成功，false为失败
		filePath：新固件文件保存的完整路径，只有result为true时，此参数才有意义
返回值：无
]]

local function otaCb(result,filePath)
    log.info("testALiYun.otaCb",result,filePath)
    if result then
        --根据自己的需求，去使用文件filePath
        local fileHandle = io.open(filePath,"rb")
        if not fileHandle then log.error("testALiYun.otaCb open file error") return end
        local current = fileHandle:seek()
        local size = fileHandle:seek("end")
        fileHandle:seek("set",current)
        --输出文件长度
        log.info("testALiYun.otaCb size",size)

        --输出文件内容，如果文件太大，一次性读出文件内容可能会造成内存不足，分次读出可以避免此问题
        if size<=4096 then
            log.data("testALiYun.otaCb data",fileHandle:read("*all"))
        else
            --分段读取文件内容
        end

        fileHandle:close()

        --此处上报新固件版本号（仅供测试使用）
        --用户开发自己的程序时，根据下载下来的新固件，执行升级动作
        --升级成功后，调用aLiYunOta.setVer上报新固件版本号
        --如果升级失败，调用aLiYunOta.setVer上报旧固件版本号
        aLiYunOta.setVer("MCU_VERSION_1.0.1")
    end

    --文件使用完之后，如果以后不再需求，需要自行删除
    if filePath then os.remove(filePath) end
end


--设置新固件下载结果的回调函数
--aLiYunOta.setCb(otaCb)

