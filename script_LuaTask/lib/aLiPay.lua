--- 模块功能：蚂蚁金服支付宝功能.
-- @module aLiPay
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2019.03.31

require"link"

module(..., package.seeall)

local sDeviceSupplier,sMerchantUser,sItemId,sProductKey,sGetTerminalIdFnc
local sConfigErrorCnt,sConfiged = 0
local sOpenErrorCnt,sOpend,sClosed = 0
local sDid = ""
local sTranscationCbFnc,sProductInfoCbFnc,sActCbFnc
local sSignCbFnc,sCloseCbFnc
local evtCb = {}

--[[
函数名：rsp
功能  ：本功能模块内“通过虚拟串口发送到底层core软件的AT命令”的应答处理
参数  ：
cmd：此应答对应的AT命令
success：AT命令执行结果，true或者false
response：AT命令的应答中的执行结果字符串
intermediate：AT命令的应答中的中间信息
返回值：无
]]
local function rsp(cmd,success,response,intermediate)
    local prefix = string.match(cmd, "AT(%+%u+)")
    if prefix=="+ALIPAYCFG" then
        if success then
            sConfiged = true
            sConfigErrorCnt = 0
        else
            sConfigErrorCnt = sConfigErrorCnt+1
            if sConfigErrorCnt>=10 then sys.restart("aLiPay.configError") end
            sys.timerStart(config,2000)
        end
    elseif prefix=="+ALIPAYOPEN" then
        if success then
            sOpened = true
        else
            sOpenErrorCnt,sOpened = sOpenErrorCnt+1
            if sOpenErrorCnt>=10 then sys.restart("aLiPay.openError") end
            sys.timerStart(open,2000)
        end
    elseif prefix=="+ALIPAYSHUT" then
        if sCloseCbFnc then sCloseCbFnc(success) end
    elseif prefix=="+ALIPAYDID" then
        if success then
            sDid = intermediate:match("^%+ALIPAYDID: 0,(.+)$")            
        end
        if evtCb["connect"] then evtCb["connect"](success) end
    elseif prefix=="+ALIPAYSIGN" then
        local result,data
        if success then
            result,data = intermediate:match("^%+ALIPAYSIGN: ([%-]*%d+)")
            if result=="0" then
                data = intermediate:match("^%+ALIPAYSIGN: 0,%d+,(.+)")
            end
        end
        if sSignCbFnc then sSignCbFnc(result=="0",data) end
    elseif prefix=="+ALIPAYREP" then
        if success then
            if intermediate then success=(intermediate=="+ALIPAYREP: 0") end
        end
        if sTranscationCbFnc then sTranscationCbFnc(success) end
    elseif prefix=="+ALIPAYPINFO" then
        if success then
            if intermediate then success=(intermediate=="+ALIPAYPINFO: 0") end
        end
        if sProductInfoCbFnc then sProductInfoCbFnc(success) end
    elseif prefix=="+ALIPAYACT" then
        if success then
            if intermediate then success=(intermediate=="+ALIPAYACT: 0") end
        end
        if sActCbFnc then sActCbFnc(success) end
    end
end

--[[
函数名：urc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
data：通知的完整字符串信息
prefix：通知的前缀
返回值：无
]]
local function urc(data,prefix)
    --打开通知
    if prefix=="+ALIPAYOPEN" then
        --打开成功
        if data == "+ALIPAYOPEN: 0" then
            sOpenErrorCnt,sOpened = 0,true
            ril.request("AT+ALIPAYDID")            
        --打开失败
        else
            sOpenErrorCnt,sOpened = sOpenErrorCnt+1
            if sOpenErrorCnt>=10 then sys.restart("aLiPay.openError") end
            sys.timerStart(open,2000)
        end    
    end
end

function config()
    log.info("aLiPay.config",sConfiged)
    if not sConfiged then
        ril.request("AT+ALIPAYCFG="..sDeviceSupplier..","..sMerchantUser..","..sItemId..","..sProductKey..",0,"..sGetTerminalIdFnc())
    end
end

function open()
    log.info("aLiPay.open",sOpened,sClosed)
    if sClosed then log.error("aLiPay.open","not allowed") return end
    if not sOpened then
        ril.request("AT+ALIPAYOPEN")
    end
end

--- 关闭aLiPay（注意：关闭aLiPay之后，只能重启才能再次自动开启）
-- @function[opt=nil] cbFnc，关闭结果的回调函数
-- 回调函数的调用形式为：cbFnc(result)。result为true表示关闭成功，false或者nil表示关闭失败
-- @return nil
-- @usage
-- aLiPay.close(cbFnc)
function close(cbFnc)
    sCloseCbFnc = cbFnc
    ril.request("AT+ALIPAYSHUT")
end

--- 配置支付宝产品参数
-- @string deviceSupplier，设备供应商编号
-- @string merchantUser，设备运营商编号
-- @string itemId，产品身份识别号
-- @string productKey，设备行业和设备形态的精简描述
-- @function getTerminalIdFnc，获取设备的序列号的函数
-- @return nil
-- @usage
-- aLiPay.setup("201903131900940927","201903131900940927","2019031301993185","SMART_RETAIL_MODULE",getTerminalId)
function setup(deviceSupplier,merchantUser,itemId,productKey,getTerminalIdFnc)
    sDeviceSupplier,sMerchantUser,sItemId,sProductKey,sGetTerminalIdFnc = deviceSupplier,merchantUser,itemId,productKey,getTerminalIdFnc
end


--- 缓存交易信息数据（注意：缓存成功后，并不是立即上报，而是缓存到一定条数之后才会上报）
-- @string[opt=""] businessNo，交易产生的流水号
-- @string[opt=""] qrcode，用户付款码
-- @number[opt=-1] amount，交易金额，单位为分
-- @number[opt=-1] timeConsuming，交易时间耗费，单位为秒
-- @number[opt=0] tradeResult，交易结果
-- @function[opt=nil] cbFnc，数据缓存结果的回调函数
-- 回调函数的调用形式为：cbFnc(result)。result为true表示缓存成功，false或者nil表示缓存失败
-- @return nil
-- @usage
-- aLiPay.sendTransactionData("88899998888","98765",1234,4,5,0,cbFnc)
function sendTransactionData(businessNo,qrcode,amount,timeConsuming,tradeResult,cbFnc)
    local result = tradeResult and (tradeResult=="" and 0 or tradeResult) or 0
    ril.request("AT+ALIPAYREP="..(businessNo or "")..","..(qrcode or "")..","..(amount or "")..","..(timeConsuming or "")..","..result..","..(os.time()+8*3600))
    sTranscationCbFnc = cbFnc
end

--- 缓存产品规格信息数据（注意：缓存成功后，并不是立即上报，而是缓存到一定条数之后才会上报）
-- @number humanVerify，设备核查消费者身份的方式，可以是如下列表中的一种或者多种之和
--      0x01 二维码识别
--      0x02 人脸识别
--      0x04 手机号码识别(SMS/CALL)
--      0x08 声纹识别
--      0x10 NFC识别
--      0x20 指纹识别
--      0x40 邮箱识别
-- @function[opt=nil] cbFnc，数据缓存结果的回调函数
--      回调函数的调用形式为：cbFnc(result)。result为true表示缓存成功，false或者nil表示缓存失败
-- @return nil
-- @usage
-- aLiPay.sendProductInfoData(0x01,cbFnc)
-- aLiPay.sendProductInfoData(0x01+0x02+0x04,cbFnc)
function sendProductInfoData(humanVerify,cbFnc)
    ril.request("AT+ALIPAYPINFO="..humanVerify)
    sProductInfoCbFnc = cbFnc
end

--- 缓存行为数据（注意：缓存成功后，并不是立即上报，而是缓存到一定条数之后才会上报）
-- @number broadcastCnt，语音播报次数增量
-- @number scanCnt，扫码次数增量
-- @function[opt=nil] cbFnc，数据缓存结果的回调函数
--      回调函数的调用形式为：cbFnc(result)。result为true表示缓存成功，false或者nil表示缓存失败
-- @return nil
-- @usage
-- aLiPay.sendActData(1,2,cbFnc)
function sendActData(broadcastCnt,scanCnt,cbFnc)
    ril.request("AT+ALIPAYACT="..broadcastCnt..","..scanCnt)
    sActCbFnc = cbFnc
end

--- 注册事件的处理函数
-- @string evt，事件
-- "connect"表示接入服务器连接结果事件
-- @function cbFnc，事件的处理函数
-- 当evt为"connect"时，cbFnc的调用形式为：cbFnc(result)，result为true表示连接成功，false或者nil表示连接失败
-- @return nil
-- @usage
-- aLiPay.on("connect",connectCbFnc)
function on(evt,cbFnc)
    evtCb[evt] = cbFnc
end

--- 获取设备的biztid(注意，必须在connectCb之后才能获取成功)
-- @return string
-- @usage
-- aLiPay.getBiztid()
function getBiztid()
    return sDid or ""
end

--- 对待交易数据进行加签
-- @number mode，交易数据类型
--      1 用户被扫
--      2 用户人脸
--      3 用户主扫
--      4 第三方代扣
-- @string data，需要加签的数据，最大长度为 128 字节
-- @string[opt=nil] amount，需要加签的数据，单位为元，最大长度为 32 字节，例如"0.01"表示1分钱
-- @function[opt=nil] cbFnc，加签结果的回调函数
--      回调函数的调用形式为：cbFnc(result,signedData)。result为true表示加签成功，false或者nil表示加签失败；signedData为加签后的数据
-- @return nil
-- @usage
-- aLiPay.sign(1,"sign_data","100",cbFnc)
function sign(mode,data,amount,cbFnc)
    ril.request("AT+ALIPAYSIGN="..mode..","..data..(amount and (","..amount) or ""))
    sSignCbFnc = cbFnc
end

ril.regRsp("+ALIPAYCFG",rsp)
ril.regRsp("+ALIPAYOPEN",rsp)
ril.regRsp("+ALIPAYREP",rsp)
ril.regRsp("+ALIPAYPINFO",rsp)
ril.regRsp("+ALIPAYACT",rsp)
ril.regRsp("+ALIPAYDID",rsp)
ril.regRsp("+ALIPAYSIGN",rsp)
ril.regRsp("+ALIPAYSHUT",rsp)
ril.regUrc("+ALIPAYOPEN",urc)



sys.subscribe("IP_READY_IND", function()
    if not sConfiged then
        config()
    end
    open()
end)
