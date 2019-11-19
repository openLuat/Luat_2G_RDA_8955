--- 模块功能：阿里云物联网套件客户端功能.
-- 目前的产品节点类型仅支持“设备”，设备认证方式支持“一机一密和“一型一密”
-- @module aLiYun
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.04.16

require"log"
require"http"
require"mqtt"

module(..., package.seeall)

local sProductKey,sProductSecret,sGetDeviceNameFnc,sGetDeviceSecretFnc,sSetDeviceSecretFnc
local sKeepAlive,sCleanSession,sWill
local isSleep--休眠，不去重连服务器
local sErrHandleCo,sErrHandleCb,sErrHandleTmout

local outQueue =
{
    SUBSCRIBE = {},
    PUBLISH = {},
}

local evtCb = {}

local function insert(type,topic,qos,payload,cbFnc,cbPara)
    table.insert(outQueue[type],{t=topic,q=qos,p=payload,cb=cbFnc,para=cbPara})
end

local function remove(type)
    if #outQueue[type]>0 then return table.remove(outQueue[type],1) end
end

local function procSubscribe(client)
    local i
    for i=1,#outQueue["SUBSCRIBE"] do
        if not client:subscribe(outQueue["SUBSCRIBE"][i].t,outQueue["SUBSCRIBE"][i].q) then
            return false,"procSubscribe"
        end
    end
    return true
end

local function procReceive(client)
    local r,data,s
    while true do
        r,data,s = client:receive(60000,"aliyun_publish_ind")
        --接收到数据
        if r and data~="timeout" then
            log.info("aLiYun.procReceive",data.topic,string.toHex(data.payload))
            --OTA消息
            if data.topic=="/ota/device/upgrade/"..sProductKey.."/"..sGetDeviceNameFnc() then
                if aLiYunOta and aLiYunOta.upgrade then
                    aLiYunOta.upgrade(data.payload)
                end
            --其他消息
            else
                if evtCb["receive"] then evtCb["receive"](data.topic,data.qos,data.payload) end
            end

            --如果有等待发送的数据，则立即退出本循环
            if #outQueue["PUBLISH"]>0 then return true,"procReceive" end
        elseif data == "aliyun_publish_ind" and s:find("disconnect") then--主动断开
            client:disconnect()
            return false,"procReceive"
        elseif data == "aliyun_publish_ind" and s:find("send") then--来数据要发了
            log.info("aliyun aliyun_publish_ind")
            return true,"procReceive"
        else
            break
        end
    end

    return data=="timeout" or r,"procReceive"
end

local function procSend(client)
    while #outQueue["PUBLISH"]>0 do
        local item = table.remove(outQueue["PUBLISH"],1)
        local result = client:publish(item.t,item.p,item.q)
        if item.cb then item.cb(result,item.para) end
        if not result then return false,"procSend" end
    end
    return true,"procSend"
end

--- 断开阿里云物联网套件的连接，并且不再重连
-- @return nil
-- @usage
-- aLiYun.sleep()
function sleep()
    isSleep = true
    log.info("aLiYun.sleep","open sleep, stop try reconnect")
    sys.publish("aliyun_publish_ind","disconnect")
end

--- 重新打开阿里云物联网套件的连接
-- @return nil
-- @usage
-- aLiYun.wakeup()
function wakeup()
    isSleep = false
    sys.publish("ALITUN_WAKEUP")
    log.info("aLiYun.wakeup","exit sleep")
end

--- 查看打开阿里云物联网套件的是否允许连接状态
-- @return bool 是否允许连接阿里云
-- @usage
-- local ar = aLiYun.sleepStatus()
function sleepStatus()
    return isSleep
end

function clientDataTask(host,tPorts,clientId,user,password)
    local retryConnectCnt = 0
    local portIdx = 0
    while true do
        if isSleep then sys.waitUntil("ALITUN_WAKEUP") end

        if not socket.isReady() then
            retryConnectCnt = 0
            --等待网络环境准备就绪，超时时间是5分钟
            sys.waitUntil("IP_READY_IND",300000)
        end

        if socket.isReady() then
            local mqttClient = mqtt.client(clientId,sKeepAlive or 240,user,password,sCleanSession,sWill)
            portIdx = portIdx%(#tPorts)+1

            if mqttClient:connect(host,tonumber(tPorts[portIdx]),"tcp_ssl") then
                retryConnectCnt = 0
                if aLiYunOta and aLiYunOta.connectCb then aLiYunOta.connectCb(true,sProductKey,sGetDeviceNameFnc()) end
                if evtCb["connect"] then evtCb["connect"](true) end

                local result,prompt = procSubscribe(mqttClient)
                outQueue["SUBSCRIBE"] = {}
                if result then
                    local procs,k,v = {procSend,procReceive}
                    while true do
                        for k,v in pairs(procs) do
                            result,prompt = v(mqttClient)
                            if not result then log.warn("aLiYun.clientDataTask."..prompt.." error") break end
                        end
                        if not result then break end
                        if sErrHandleCo then coroutine.resume(sErrHandleCo,"feed") end
                    end
                else
                    log.warn("aLiYun.clientDataTask."..prompt.." error")
                end

                while #outQueue["PUBLISH"]>0 do
                    local item = table.remove(outQueue["PUBLISH"],1)
                    if item.cb then item.cb(false,item.para) end
                end
                if aLiYunOta and aLiYunOta.connectCb then aLiYunOta.connectCb(false,sProductKey,sGetDeviceNameFnc()) end
                if evtCb["connect"] then evtCb["connect"](false) end
            else
                retryConnectCnt = retryConnectCnt+1
            end

            mqttClient:disconnect()
            if retryConnectCnt>=5 then link.shut() retryConnectCnt=0 end
            sys.wait(2000)
        else
            --进入飞行模式，20秒之后，退出飞行模式
            net.switchFly(true)
            sys.wait(20000)
            net.switchFly(false)
        end
    end
end


local function getDeviceSecretCb(result,prompt,head,body)
    log.info("aLiYun.getDeviceSecretCb",result,prompt)
    if result and body then
        local tJsonDecode = json.decode(body)
        if tJsonDecode and tJsonDecode["data"] and tJsonDecode["data"]["deviceSecret"] and tJsonDecode["data"]["deviceSecret"]~=""  then
            sSetDeviceSecretFnc(tJsonDecode["data"]["deviceSecret"])
        end
    end
    sys.publish("GetDeviceSecretEnd")

end

local function authCbFnc(result,statusCode,head,body)
    log.info("aLiYun.authCbFnc",result,statusCode,body)
    sys.publish("ALIYUN_AUTH_IND",result,statusCode,body)
end

local function getBody(tag)
    if tag=="auth" then
        local data = "clientId"..sGetDeviceNameFnc().."deviceName"..sGetDeviceNameFnc().."productKey"..sProductKey
        local signKey= sGetDeviceSecretFnc()
        local sign = crypto.hmac_md5(data,data:len(),signKey,signKey:len())
        return "productKey="..sProductKey.."&sign="..sign.."&clientId="..sGetDeviceNameFnc().."&deviceName="..sGetDeviceNameFnc()
    elseif tag=="register" then
        local random=rtos.tick()
        local data = "deviceName"..sGetDeviceNameFnc().."productKey"..sProductKey.."random"..random
        local sign = crypto.hmac_md5(data,data:len(),sProductSecret,sProductSecret:len())
        return "productKey="..sProductKey.."&deviceName="..sGetDeviceNameFnc().."&random="..random.."&sign="..sign.."&signMethod=HmacMD5"
    end
end

function clientAuthTask()
    while not socket.isReady() do sys.waitUntil("IP_READY_IND") end
    while true do
        local retryCnt,authBody = 0,getBody("auth")
        while true do
            http.request("POST",
                     "https://iot-auth.cn-shanghai.aliyuncs.com/auth/devicename",
                     nil,{["Content-Type"]="application/x-www-form-urlencoded"},authBody,20000,authCbFnc)

            local _,result,statusCode,body = sys.waitUntil("ALIYUN_AUTH_IND")
            --log.info("aLiYun.clientAuthTask1",result and statusCode=="200",body)
            if result and statusCode=="200" then
                local tJsonDecode,result = json.decode(body)
                --log.info("aLiYun.clientAuthTask2",result,tJsonDecode["message"],tJsonDecode["data"])
                if result and tJsonDecode["message"]=="success" and tJsonDecode["data"] and type(tJsonDecode["data"])=="table" then
                    --log.info("aLiYun.clientAuthTask3",tJsonDecode["data"]["iotId"],tJsonDecode["data"]["iotToken"])
                    if tJsonDecode["data"]["iotId"] and tJsonDecode["data"]["iotId"]~="" and tJsonDecode["data"]["iotToken"] and tJsonDecode["data"]["iotToken"]~="" then
                        if evtCb["auth"] then evtCb["auth"](true) end
                        local ports,host,returnMqtt = {}
                        if tJsonDecode["data"]["resources"] and type(tJsonDecode["data"]["resources"])=="table" then
                            if tJsonDecode["data"]["resources"]["mqtt"] then
                                returnMqtt,host = true,tJsonDecode["data"]["resources"]["mqtt"]["host"]
                                table.insert(ports,tJsonDecode["data"]["resources"]["mqtt"]["port"])
                            end
                        end

                        sys.taskInit(clientDataTask,returnMqtt and host or sProductKey..".iot-as-mqtt.cn-shanghai.aliyuncs.com",#ports~=0 and ports or {1883},sGetDeviceNameFnc(),tJsonDecode["data"]["iotId"],tJsonDecode["data"]["iotToken"])
                        return
                    end
                end
            end

            if sProductSecret then
                http.request("POST","https://iot-auth.cn-shanghai.aliyuncs.com/auth/register/device",nil,
                    {['Content-Type']="application/x-www-form-urlencoded"},
                    getBody("register"),30000,getDeviceSecretCb)
                sys.waitUntil("GetDeviceSecretEnd")
                sys.wait(1000)
                authBody = getBody("auth")
            end

            retryCnt = retryCnt+1
            if retryCnt==3 then
                break
            end
        end

        if evtCb["auth"] then evtCb["auth"](false) end
        sys.wait(5000)
    end
end

--- 配置阿里云物联网套件的产品信息和设备信息
-- @string productKey，产品标识
-- @string[opt=nil] productSecret，产品密钥
-- 一机一密认证方案时，此参数传入nil
-- 一型一密认证方案时，此参数传入真实的产品密钥
-- @function getDeviceNameFnc，获取设备名称的函数
-- @function getDeviceSecretFnc，获取设备密钥的函数
-- @function[opt=nil] setDeviceSecretFnc，设置设备密钥的函数，一型一密认证方案才需要此参数
-- @return nil
-- @usage
-- aLiYun.setup("b0FMK1Ga5cp",nil,getDeviceNameFnc,getDeviceSecretFnc)
-- aLiYun.setup("a1AoVqkCIbG","7eCdPyR6fYPntFcM",getDeviceNameFnc,getDeviceSecretFnc,setDeviceSecretFnc)
function setup(productKey,productSecret,getDeviceNameFnc,getDeviceSecretFnc,setDeviceSecretFnc)
    sProductKey,sProductSecret,sGetDeviceNameFnc,sGetDeviceSecretFnc,sSetDeviceSecretFnc = productKey,productSecret,getDeviceNameFnc,getDeviceSecretFnc,setDeviceSecretFnc
    sys.taskInit(clientAuthTask)
end

--- 设置MQTT数据通道的参数
-- @number[opt=1] cleanSession 1/0
-- @table[opt=nil] will 遗嘱参数，格式为{qos=, retain=, topic=, payload=}
-- @number[opt=240] keepAlive，单位秒
-- @return nil
-- @usage
-- aLiYun.setMqtt(0)
-- aLiYun.setMqtt(1,{qos=0,retain=1,topic="/willTopic",payload="will payload"})
-- aLiYun.setMqtt(1,{qos=0,retain=1,topic="/willTopic",payload="will payload"},120)
function setMqtt(cleanSession,will,keepAlive)
    sCleanSession,sWill,sKeepAlive = cleanSession,will,keepAlive
end

--- 订阅主题
-- @param topic，string或者table类型，一个主题时为string类型，多个主题时为table类型，主题内容为UTF8编码
-- @param qos，number或者nil，topic为一个主题时，qos为number类型(0/1/2，默认0)；topic为多个主题时，qos为nil
-- @return nil
-- @usage
-- aLiYun.subscribe("/b0FMK1Ga5cp/862991234567890/get", 0)
-- aLiYun.subscribe({["/b0FMK1Ga5cp/862991234567890/get"] = 0, ["/b0FMK1Ga5cp/862991234567890/get"] = 1})
function subscribe(topic,qos)
	insert("SUBSCRIBE",topic,qos)
end

--- 发布一条消息
-- @string topic，UTF8编码的主题
-- @string payload，负载
-- @number[opt=0] qos，质量等级，0/1/2，默认0
-- @function[opt=nil] cbFnc，消息发布结果的回调函数
-- 回调函数的调用形式为：cbFnc(result,cbPara)。result为true表示发布成功，false或者nil表示订阅失败；cbPara为本接口中的第5个参数
-- @param[opt=nil] cbPara，消息发布结果回调函数的回调参数
-- @return nil
-- @usage
-- aLiYun.publish("/b0FMK1Ga5cp/862991234567890/update","test",0)
-- aLiYun.publish("/b0FMK1Ga5cp/862991234567890/update","test",1,cbFnc,"cbFncPara")
function publish(topic,payload,qos,cbFnc,cbPara)
    insert("PUBLISH",topic,qos,payload,cbFnc,cbPara)
    sys.publish("aliyun_publish_ind","send")
    log.info("aliyun aliyun_publish_ind","publish")
end

--- 注册事件的处理函数
-- @string evt，事件
-- "auth"表示鉴权服务器认证结果事件
-- "connect"表示接入服务器连接结果事件
-- "receive"表示接收到接入服务器的消息事件
-- @function cbFnc，事件的处理函数
-- 当evt为"auth"时，cbFnc的调用形式为：cbFnc(result)，result为true表示认证成功，false或者nil表示认证失败
-- 当evt为"connect"时，cbFnc的调用形式为：cbFnc(result)，result为true表示连接成功，false或者nil表示连接失败
-- 当evt为"receive"时，cbFnc的调用形式为：cbFnc(topic,qos,payload)，topic为UTF8编码的主题(string类型)，qos为质量等级(number类型)，payload为原始编码的负载(string类型)
-- @return nil
-- @usage
-- aLiYun.on("b0FMK1Ga5cp",nil,getDeviceNameFnc,getDeviceSecretFnc)
function on(evt,cbFnc)
	evtCb[evt] = cbFnc
end

--- 设置阿里云task连续一段时间工作异常的处理程序
-- @function cbFnc，异常处理函数，cbFnc的调用形式为：cbFnc()
-- @number[opt=150] tmout，连续工作异常的时间，当连续异常到达这个时间之后，会调用cbFnc()
-- @return nil
-- @usage
-- aLiYun.setErrHandle(function() sys.restart("ALIYUN_TASK_INACTIVE") end, 300)
function setErrHandle(cbFnc,tmout)
    sErrHandleCb = cbFnc
    sErrHandleTmout = tmout or 150
    if not sErrHandleCo then
        sErrHandleCo = sys.taskInit(function()
            while true do
                if sys.wait(sErrHandleTmout*1000) == nil then
                    sErrHandleCb()
                end
            end
        end)
    end
end
