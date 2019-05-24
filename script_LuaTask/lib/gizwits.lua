--- 模块功能：机智云物联网套件客户端功能
-- @module gizwits
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.07.04

require"log"
require"http"
require"mqtt"
require"misc"

module(..., package.seeall)
local ssub,schar,smatch,sbyte,slen,sgmatch,sgsub,srep = string.sub,string.char,string.match,string.byte,string.len,string.gmatch,string.gsub,string.rep

local sPRODUCT_KEY,sPRODUCT_SECRET,sgetDeviceNameFnc,getDeviceSecretFnc,getDeviceIdFnc,setDeviceIdFnc,sgetAuthkey
local mqttHeartbeat,sExtra,sServer,sPort

local fotastart

local evtCb = {}

--数据发送的消息队列
local msgQueue = {}

--[[
函数名：encodeData
功能  ：对上报数据进行加密
参数  ：无
返回值：aes加密后的16进制字符串
]]
local function encodeData(originStr)
    if originStr == nil or originStr:len() < 0 then return "" end
    --加密模式：ECB；填充方式：Pkcs7Padding；密钥：sPRODUCT_SECRET；密钥长度：128 bit
    encodeStr = crypto.aes_encrypt("ECB","PKCS7",originStr,string.fromHex(sPRODUCT_SECRET))
    log.info("gizwits.encodeData",originStr,"encode data",string.toHex(encodeStr))
    return string.toHex(encodeStr)
end

--[[
函数名：decodeData
功能  ：对收到的数据进行解密
参数  ：加密的16进制字符串
返回值：aes解密后的字符串
]]
local function decodeData(s)
    if s == nil or s:len() < 0 then return "" end
    --加密模式：ECB；填充方式：Pkcs7Padding；密钥：sPRODUCT_SECRET；密钥长度：128 bit
    decodeStr = crypto.aes_decrypt("ECB","PKCS7",string.fromHex(s),string.fromHex(sPRODUCT_SECRET))
    log.info("gizwits.decodeData",s,"decode data",decodeStr)
    return decodeStr
end

--[[
函数名：insertMsg
功能  ：向MQTT客户端数据发送队列增加publish请求
参数  ：topic,payload,qos,user
返回值：无
]]
local function insertMsg(topic,payload,qos,user)
    table.insert(msgQueue,{t=topic,p=payload,q=qos,user=user})
end


--- 发布一条消息
-- 手动编写并发送一条mqtt消息
-- @string topic，UTF8编码的主题
-- @string payload，负载
-- @number[opt=0] qos，质量等级，0/1/2，默认0
-- @function[opt=nil] cbFnc，消息发布结果的回调函数
-- @string cbPara，标志
-- @return nil
-- @usage publish(topic,msg,0)
-- @usage publish(topic,msgbody,0,{cb=cbFnc,para=cbPara})
function publish(topic,payload,qos,cbFnc,cbPara)
    insertMsg(topic,payload,qos,{cb=cbFnc,para=cbPara})
end

--[[
函数名：mqttOutMsg_proc
功能  ：MQTT客户端数据发送处理
参数  ：mqttClient
返回值：处理成功返回true，处理出错返回false
]]
local function mqttOutMsg_proc(mqttClient)
    while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        local result = mqttClient:publish(outMsg.t,outMsg.p,outMsg.q)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(result,outMsg.user.para) end
        if not result then return end
    end
    return true
end

--[[
函数名：waitForSend
功能  ：MQTT客户端是否有数据等待发送
参数  ：无
返回值：有数据等待发送返回true，否则返回false
]]
local function waitForSend()
    return #msgQueue > 0
end

--计算包长
local function encodeLen(len)
    local s = ""
    local digit
    repeat
        digit = len % 128
        len = (len - digit) / 128
        if len > 0 then
            digit = bit.bor(digit, 0x80)
        end
        s = s .. string.char(digit)
    until (len <= 0)
    return s
end

--- 发布一条透传消息
-- 按照机智云带ack的格式发送一条消息
-- @number flag，通讯协议手册中的flag
-- @string ccmd，命令字，ack返回为0094
-- @string sn，包序号
-- @string cmd，业务指令
-- @string topic，UTF8编码的主题
-- @return nil
-- @usage gizwits.transmissionSend(0,string.fromHex("0094"),string.fromHex("00000001"),"cmd","dev2app/12345/67890"))  --回复ack
function transmissionSend(flag,ccmd,sn,cmd,topic)
    local msgbody = schar(flag)..ccmd..sn..cmd
    local length = slen(msgbody)
    local length_str = encodeLen(length)
    msgbody = string.fromHex("00000003")..length_str..msgbody
    publish(topic,msgbody,0)
    log.info("gizwits.ack","replay ack",topic)
end

--[[
函数名：transmissionRev
功能  ：处理解析接收到的透传指令
参数  ：topic,payload
返回值：无
]]
local function transmissionRev(topic,payload)
    log.info("gizwits.ack","ack check",topic)
    local str = ssub(payload, 1, 4)
    if string.toHex(str) == "00000003" and string.find(topic, "app2dev/"..getDeviceIdFnc()) ~= nil then
        str = ssub(payload, 5) --去除包头
        for i=1,6 do
            if sbyte(str,i) / 128 == 0 then  --前7位用于保存长度，后一部用做标识。当最后一位为 1时，表示长度不足
                str = ssub(str, i+1)
                break
            elseif i == 6 then --没搜到flag，数据有误，结束本次ack解析
                return
            end
        end
        local flag = sbyte(str)
        local ccmd = ssub(str,2,3)
        local sn = nil
        local cmd = ssub(str,4)
        if string.toHex(ccmd) == "0093" then
            sn = ssub(str,4,7)
            cmd = ssub(str,8)
        end
        log.info("gizwits.transmissionRev","gizwits message unpack",flag,ccmd,sn)
        if evtCb["transmissionRev"] then evtCb["transmissionRev"](flag,ccmd,sn,cmd,topic) end
    end
end



--[[
函数名：mqttInMsg_proc
功能  ：MQTT客户端数据接收处理
参数  ：mqttClient
返回值：处理成功返回true，处理出错返回false
]]
local function mqttInMsg_proc(mqttClient)
    local result,data
    while true do
        result,data = mqttClient:receive(50)
        --接收到数据
        if result then
            log.info("mqttInMsg.proc",data.topic)
            --TODO：根据需求自行处理data.payload
            if evtCb["receive"] then evtCb["receive"](data.topic,data.qos,data.payload) end
            transmissionRev(data.topic,data.payload)
            --如果mqtt中有等待发送的数据，则立即退出本循环
            if waitForSend() then return true end
        else
            break
        end
    end

    return result or data=="timeout"
end


--[[
函数名：conn_mqtt
功能  ：连接mqtt服务器
参数  ：无
返回值：无
]]
local function conn_mqtt(server_host, server_port)
    local retryCnt = 0
    while true do
        if not socket.isReady() then
            if evtCb["connect"] then evtCb["connect"](false) end
            retryConnectCnt = 0
            --等待网络环境准备就绪，超时时间是5分钟
            sys.waitUntil("IP_READY_IND",300000)
        end

        if socket.isReady() then
            -- 连接mqtt服务器，机智云服务器为3.1，不兼容3.1.1，需要特意声明
            mqttClient = mqtt.client(getDeviceIdFnc(),mqttHeartbeat,getDeviceIdFnc(),getDeviceSecretFnc(),nil,nil,"3.1")
            log.info("gizwits.conn_mqtt",getDeviceIdFnc(),mqttHeartbeat,getDeviceIdFnc(),getDeviceSecretFnc())
            if mqttClient:connect(server_host, server_port,"tcp") then
                retryCnt = 0
                if mqttClient:subscribe({["ser2cli_res/"..getDeviceIdFnc()]=0, ["app2dev/"..getDeviceIdFnc().."/#"]=0, ["app2module/"..getDeviceIdFnc().."/#"]=0}) then
                    log.info("gizwits.conn_mqtt","mqtt subscribe ok")
                    if evtCb["connect"] then evtCb["connect"](true) end
                    --循环处理接收和发送的数据
                    while true do
                        if not mqttInMsg_proc(mqttClient) then log.error("mqttInMsg_proc error") break end
                        if not mqttOutMsg_proc(mqttClient) then log.error("mqttOutMsg_proc error") break end
                    end
                end
            else
                log.info("gizwits.conn_mqtt","mqtt connect fail")
                if evtCb["connect"] then evtCb["connect"](false) end
            end
            --断开MQTT连接
            mqttClient:disconnect()
            if evtCb["connect"] then evtCb["connect"](false) end
            retryCnt = retryCnt + 1
            if retryCnt > 5 then
                retryCnt = 0
                net.switchFly(true)
                sys.wait(20000)
                net.switchFly(false)
            end
            sys.wait(5000)
        else
            --进入飞行模式，20秒之后，退出飞行模式
            if evtCb["connect"] then evtCb["connect"](false) end
            net.switchFly(true)
            sys.wait(20000)
            net.switchFly(false)
        end
    end
end


--[[
函数名：proCbFnc
功能  ：获取服务器信息页面的返回值，包含了mqtt服务器数据，aes加密
参数  ：无
返回值：返回值
]]
local function proCbFnc(result,statusCode,head,body)
    log.info("gizwits.proCbFnc",result,statusCode,body)
    sys.publish("GIZWITS_PRO_IND",result,statusCode,body)
end

--[[
函数名：getProvision
功能  ：获取模块所需要的mqtt服务器信息
参数  ：无
返回值：无
]]
local function getProvision()
    while not socket.isReady() do sys.waitUntil("IP_READY_IND") end
    local retryCnt = 0
    while true do
        local body = "did="..encodeData(getDeviceIdFnc()).."&tls=0"
        http.request("GET","http://"..sServer..":"..sPort.."/dev/"..sPRODUCT_KEY.."/device?"..body,nil,nil,nil,30000,proCbFnc)
        local _,result,statusCode,body = sys.waitUntil("GIZWITS_PRO_IND")
        --log.info("gizwits.getProvision","http done",body,result,statusCode)
        if statusCode ~= "200" then
            log.info("gizwits.getProvision","code not right",statusCode)
            clientAuthTask()
            return
        end
        local result_decode = decodeData(body)
        local server_host, server_port, server_ts = string.match(result_decode,"host=(.+)&port=(.+)&server_ts=(.+)&log_host")
        log.info("gizwits.getProvision","get time",server_ts)
        local now_time_table = os.date("*t",tonumber(server_ts))
        misc.setClock(now_time_table)
        if server_host ~= nil and server_port ~= nil then
            log.info("gizwits.getProvision","server get",server_host,server_port)
            conn_mqtt(server_host, server_port)
            break
        else
            clientAuthTask() --获取mqtt信息失败，重新获取did
        end

        retryCnt = retryCnt+1
        if retryCnt==3 then
            log.info("gizwits.getProvision","Provision get fail")
            sys.restart("Provision get fail")
        end
        sys.wait(5000)
    end
end


--[[
函数名：authCbFnc
功能  ：获取设备注册页面的返回值，包含了did数据，aes加密
参数  ：无
返回值：返回值
]]
local function authCbFnc(result,statusCode,head,body)
    log.info("gizwits.authCbFnc",result,statusCode,body)
    sys.publish("GIZWITS_AUTH_IND",result,statusCode,body)
end

--[[
函数名：clientReauthTask
功能  ：重新获取did
参数  ：无
返回值：无
]]
function clientReauthTask()
    if sgetDeviceNameFnc == nil then return end
    local body = "mac="..sgetDeviceNameFnc().."&passcode="..getDeviceSecretFnc()
    if sgetAuthkey() ~= nil then body = body.."&auth_key="..sgetAuthkey() end  --当有sgetAuthkey的时候就加上这个参数
    if sExtra ~= nil then body = body.."&extra="..sExtra end  --当有extra的时候就加上这个参数
    body = "data="..encodeData(body)
    http.request("POST",
                "http://"..sServer..":"..sPort.."/dev/"..sPRODUCT_KEY.."/device",
                nil,
                {["Content-Type"]="application/x-www-form-urlencoded"},
                body,
                30000)
end

--[[
函数名：clientAuthTask
功能  ：获取模块所需要的did
参数  ：无
返回值：无
]]
function clientAuthTask()
    local retryCnt = 0
    while true do
        local body = "mac="..sgetDeviceNameFnc().."&passcode="..getDeviceSecretFnc()
        if sgetAuthkey ~= nil and sgetAuthkey() ~= nil then
            log.info("sgetAuthkey",sgetAuthkey())
            body = body.."&auth_key="..sgetAuthkey()
        end  --当有sgetAuthkey的时候就加上这个参数
        if sExtra ~= nil then body = body.."&extra="..sExtra end  --当有extra的时候就加上这个参数
        body = "data="..encodeData(body)
        http.request("POST",
                    "http://"..sServer..":"..sPort.."/dev/"..sPRODUCT_KEY.."/device",
                    nil,
                    {["Content-Type"]="application/x-www-form-urlencoded"},
                    body,
                    30000,
                    authCbFnc)
        local _,result,statusCode,body = sys.waitUntil("GIZWITS_AUTH_IND")
        log.info("gizwits.Auth","gizwits auth result",result,statusCode,body)
        local result_decode = decodeData(body)
        setDeviceIdFnc(string.match(result_decode,"did=(.+)&"))
        if getDeviceIdFnc() == nil then
            setDeviceIdFnc(string.match(result_decode,"did=(.+)"))
        end
        if getDeviceIdFnc() ~= nil then
            log.info("gizwits.Auth","did get success",getDeviceIdFnc())
            getProvision()
            break
        end

        retryCnt = retryCnt+1
        if retryCnt==3 then
            log.info("gizwits.Auth","did get fail")
            sys.restart("Provision get fail")
        end
        sys.wait(5000)
    end
end


--[[
函数名：otaCbFnc
功能  ：获取升级检查页面的返回值
参数  ：无
返回值：返回值
]]
local function otaCbFnc(result,statusCode,head,body)
    log.info("gizwits.otaCbFnc",result,statusCode,body)
    sys.publish("GIZWITS_OTA_IND",result,statusCode,body)
end


local function httpDownloadCbFnc(result,statusCode,head)
    log.info("update.httpDownloadCbFnc",result,statusCode)
    sys.publish("UPDATE_DOWNLOAD",result,statusCode,head)
end

--升级处理函数，来源为update.lua
local sProcessedLen = 0
local function processOta(stepData,totalLen,statusCode)
    if stepData and totalLen then
        if statusCode=="200" or statusCode=="206" then
            if rtos.fota_process((sProcessedLen+stepData:len()>totalLen) and stepData:sub(1,totalLen-sProcessedLen) or stepData,totalLen)~=0 then
                log.error("updata.processOta","fail")
                return false
            else
                sProcessedLen = sProcessedLen + stepData:len()
                log.info("updata.processOta",totalLen,sProcessedLen,(sProcessedLen*100/totalLen).."%")
                --if sProcessedLen*100/totalLen==sBraekTest then return false end
                if sProcessedLen*100/totalLen>=100 then return true end
            end
        elseif statusCode:sub(1,1)~="3" and stepData:len()==totalLen and totalLen>0 and totalLen<=200 then
            local msg = stepData:match("\"msg\":%s*\"(.-)\"")
            if msg and msg:len()<=200 then
                log.warn("update.error",common.ucs2beToUtf8((msg:gsub("\\u","")):fromHex()))
            end
        end
    end
end

--- 手动检查更新
-- @string hard_version，硬件版本
-- @string soft_version，软件版本
-- @return string，结果
-- @usage
-- checkUpdate("00000001","00000001")
function checkUpdate(hard_version,soft_version)
    local body = "did="..getDeviceIdFnc().."&passcode="..getDeviceSecretFnc().."&type=1&hard_version="..hard_version.."&soft_version="..soft_version.."&product_key="..sPRODUCT_KEY.."&otaid_type=2"
    log.info("gizwits.OTA",body,hard_version,soft_version)
    http.request("POST",
    "http://"..sServer..":"..sPort.."/dev/ota/v4.1/update_and_check/"..getDeviceIdFnc(),
    nil,
    {["Content-Type"]="application/x-www-form-urlencoded"},
    body,
    30000,
    otaCbFnc)
    local _,result,statusCode,body = sys.waitUntil("GIZWITS_OTA_IND")
    log.info("gizwits.OTA","gizwits ota result",result,statusCode,body)
    if result and statusCode=="200" then
        local soft_ver, download_url = string.match(body,"soft_ver=(.+)&download_url=(.+)")
        log.info("gizwits.OTA","gizwits ota result",soft_ver, download_url)
        if download_url ~= nil then
            if _G.moduleType == 2 then
                local UPD_FILE_PATH = "/luazip/update.bin"
                os.remove(UPD_FILE_PATH)
                http.request("GET",download_url,nil,nil,nil,60000,httpDownloadCbFnc,UPD_FILE_PATH)
                local _,result1,statusCode1,head1 = sys.waitUntil("UPDATE_DOWNLOAD")
                if result1 and statusCode1=="200" then
                    log.info("gizwits.OTA","download success")
                    sys.restart("UPDATE_DOWNLOAD_SUCCESS")
                else
                    log.info("gizwits.OTA","download fail")
                end
            elseif _G.moduleType == 4 then
                if rtos.fota_start()~=0 then
                    log.error("gizwits.OTA","fota_start fail")
                    fotastart = false
                    return
                else
                    fotastart = true
                end
                http.request("GET",download_url,nil,nil,nil,60000,httpDownloadCbFnc,processOta)
                local _,result1,statusCode1,head1 = sys.waitUntil("UPDATE_DOWNLOAD")
                if result then
                    rtos.fota_end()
                    if statusCode=="200" then
                        log.info("gizwits.OTA","download success")
                        sys.restart("UPDATE_DOWNLOAD_SUCCESS")
                    end
                else
                    rtos.fota_end()
                    log.info("gizwits.OTA","download fail")
                end
            end
        end
    else
        log.info("gizwits.OTA","no update")
    end
end

--- 初始化机智云注册所需要的数据
-- @string PRODUCT_KEY，机智云应用列表中的Product Key
-- @string PRODUCT_SECRET，机智云应用列表中的Product Secret
-- @function getDeviceName，获取设备mac地址的函数
-- @function getDeviceSecret，获取设备passcode的函数
-- @function getDeviceId，保存获取到的DeviceId
-- @function setDeviceId，获取保存的DeviceId
-- @function[opt=nil] getAuthKey，专用透传设备需要的auth_key的函数
-- @number[opt=120] m2mHT，mqtt心跳时间
-- @string[opt=nil] extra，设备类型
-- @string[opt="api.gizwits.com"] server，服务器
-- @number[opt=80] port，端口
-- @return nil
-- @usage
-- gizwits.setup("PRODUCT_KEY","PRODUCT_SECRET",getDeviceName,getDeviceSecret)
function setup(PRODUCT_KEY,PRODUCT_SECRET,getDeviceName,getDeviceSecret,getDeviceId,setDeviceId,getAuthKey,m2mHT,extra,server,port)
    sPRODUCT_KEY,sPRODUCT_SECRET,sgetDeviceNameFnc,getDeviceSecretFnc,getDeviceIdFnc,setDeviceIdFnc,sgetAuthkey = PRODUCT_KEY,PRODUCT_SECRET,getDeviceName,getDeviceSecret,getDeviceId,setDeviceId,getAuthKey
    mqttHeartbeat = m2mHT and m2mHT or 120
    sExtra,sServer,sPort = extra,server and server or "api.gizwits.com",port and port or 80
    sys.taskInit(getProvision)
end



--- 注册事件的处理函数
-- @string evt，事件
-- "connect"表示连接结果事件
-- "receive"表示接收到消息事件
-- @function cbFnc，事件的处理函数
-- 当evt为"connect"时，cbFnc的调用形式为：cbFnc(result)，result为true表示连接成功，false或者nil表示连接失败
-- 当evt为"receive"时，cbFnc的调用形式为：cbFnc(topic,qos,payload)，topic为UTF8编码的主题(string类型)，qos为质量等级(number类型)，payload为原始编码的负载(string类型)
-- 当evt为"transmissionRev"时，cbFnc的调用形式为：cbFnc(flag,ccmd,sn,cmd,topic)，flag为数值型的量，ccmd为命令字，sn为包序号，cmd为透传消息内容，topic为UTF8编码的主题(string类型)
-- @return nil
-- @usage
-- gizwits.on("transmissionRev",rcvTransCbFnc)
function on(evt,cbFnc)
	evtCb[evt] = cbFnc
end


