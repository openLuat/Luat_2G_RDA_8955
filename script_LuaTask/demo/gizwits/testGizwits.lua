--- 模块功能：机智云功能测试.
-- 支持数据传输
-- @author openLuat
-- @module gizwits.testGizwits
-- @license MIT
-- @copyright openLuat
-- @release 2018.07.04

module(...,package.seeall)

require"gizwits"
require"misc"
require"utils"

--机智云上创建的产品的Product Key，用户根据实际值自行修改
local PRODUCT_KEY = "47a2f87bfef4411ebc2cf5b1da3e3d1d"
--机智云上创建的产品的Product Secret，用户根据实际值自行修改
local PRODUCT_SECRET = "7a339fb3bf4f4f41ac4589df2eaed6fd"
--设备mac使用函数getDeviceName的返回值，默认为设备的IMEI
--设备passcode使用函数getDevicePasscode的返回值
--单体测试时，可以直接修改getDeviceName和getDevicePasscode的返回值
--合宙生产的模块，都有唯一的IMEI，用户可以在自己的产线批量写入跟IMEI（设备名称）对应的SN（设备密钥）

--[[
函数名：getDeviceName
功能  ：获取设备mac
参数  ：无
返回值：mac
]]
local function getDeviceName()
    --默认使用设备的IMEI作为设备名称
    return misc.getImei()
end


--[[
函数名：getDevicePasscode
功能  ：获取设备Passcode
参数  ：无
返回值：设备Passcode
]]
local function getDevicePasscode()
    --默认使用设备的IMEI前六位作为设备Passcode
    return misc.getImei():sub(1,6)
end

--[[
函数名：getDeviceId
功能  ：获取设备DeviceId（did）
参数  ：无
返回值：设备DeviceId（did）
]]
local function getDeviceId()
    --默认使用设备的SN作为设备Passcode，重新获取会用新的did覆盖掉SN
    return misc.getSn()
end

--[[
函数名：setDeviceId
功能  ：设置设备DeviceId（did）
参数  ：设置的did值
返回值：无
]]
local function setDeviceId(s)
    --用新的did覆盖掉SN
    misc.setSn(s)
    -- while misc.getSn() ~= s do
    --     sys.wait(100)
    -- end
end

--机智云客户端是否处于连接状态
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
    log.info("testGizwits.publishTestCb",result,para)
    sys.timerStart(publishTest,20000)
    publishCnt = publishCnt+1
end

--发布一条QOS为1的消息
function publishTest()
    if sConnected then
        local AppClientId = "f4b37e8074db4479b46868abd2857b8f"
        --注意：topic和paylad格式请遵循机智云官方文档
        gizwits.publish("dev2app/"..getDeviceId(),string.fromHex("000000030A00009400000001123456"),1,publishTestCb,"with_ack")
        --gizwits.publish("dev2app/"..getDeviceId(),string.fromHex("0000000306000091123456"),1,publishTestCb,"without_ack")
    end
end

--[[
函数名：rcvCbFnc
功能  ：数据接收的处理函数
参数  ：
		topic：UTF8编码的消息主题
        qos：消息质量等级
        payload：原始编码的消息负载
返回值：无
]]
local function rcvCbFnc(topic,qos,payload)
    log.info("testGizwits.rcvCbFnc",topic,qos,payload)
    --此处为手动处理接收到的mqtt消息，请按机智云手册进行处理
    gizwits.publish("dev2app/"..getDeviceId(),string.fromHex("0000000306000091123456"),1,publishTestCb,"without_ack")
end

local function rcvTransCbFnc(flag,ccmd,sn,cmd,topic)
    log.info("testGizwits.rcvTransCbFnc",flag,ccmd,sn,cmd)
    --接收到的透传消息，参数请按机智云手册进行处理
    if string.toHex(ccmd) == "0093" then  --检查是否为透传指令
        if string.toHex(sn) ~= "00000000" then  --sn为0时不用回复ack
            gizwits.transmissionSend(flag,string.fromHex("0094"),sn,cmd,"dev2app"..string.match(topic,"app2dev(.+)"))  --回复ack
        end
    end
end

--[[
函数名：connectCbFnc
功能  ：连接结果的处理函数
参数  ：result：连接结果，true表示连接成功，false或者nil表示连接失败
返回值：无
]]
local function connectCbFnc(result)
    log.info("testGizwits.connectCbFnc",result)
    sConnected = result
    if result then
        --无需手动订阅主题，会自动订阅透传主题
        gizwits.on("receive",rcvCbFnc)
        gizwits.on("transmissionRev",rcvTransCbFnc)
        --PUBLISH透传消息测试
        publishTest()
        --gizwits.ack("?app2dev/"..getDeviceId().."/123456",string.fromHex("000000031A00009300000001").."123456abcdef")
    end
end

--配置产品，设备上线需要先获取设备的did，再根据did获取连接发服务器信息
--因为开机就调用misc.getImei()和misc.getSn()，获取不到值
gizwits.setup(PRODUCT_KEY,PRODUCT_SECRET,getDeviceName,getDevicePasscode,getDeviceId,setDeviceId)

--注册连接mqtt成功后返回的函数
gizwits.on("connect",connectCbFnc)


