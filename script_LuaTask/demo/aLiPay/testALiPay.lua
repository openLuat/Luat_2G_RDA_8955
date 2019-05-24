--- 模块功能：支付宝功能测试.
-- @author openLuat
-- @module aLiYun.testALiYun
-- @license MIT
-- @copyright openLuat
-- @release 2019.03.31

module(...,package.seeall)

require"aLiPay"
require"misc"
require"pm"

--[[
1、客户填写蚂蚁金服IOT设备信息录入模板之后，发送给蚂蚁金服工作人员
2、蚂蚁金服工作人员处理之后，会发送出来类似于下面的配置参数给客户:
机具名称：自助售卖机通信模块
Item ID：2019031301993185
供应商：上海合宙通信科技有限公司供应商
Supplier ID：201903131900940927
设备类别 DEVICE_CATEGORY：SMART_RETAIL_MODULE
]]
--注意：下面的参数是合宙自己的项目参数，客户第一次测试时，一定要更换自己的项目参数
--因为设备只能在第一次绑定的项目下使用
--设备供应商编号,使用蚂蚁金服客服人员提供的Supplier ID参数，如果整机设备供应商和模块供应商是同一家，则使用模块供应商的Supplier ID参数
local sDeviceSupplier = "201903131900940927"
--设备运营商编号,使用蚂蚁金服客服人员提供的Supplier ID参数，如果整机设备运营商和整机设备供应商是同一家，则使用整机设备运营商的Supplier ID参数
local sMerchantUser = "201903131900940927"
--产品身份识别号,使用蚂蚁金服客服人员提供的Item ID参数
local sItemId = "2019031301993185"
--设备行业和设备形态的精简描述,使用蚂蚁金服客服人员提供的设备类别 DEVICE_CATEGORY 参数
local sProductKey = "SMART_RETAIL_MODULE"


--[[
函数名：getDeviceSecret
功能  ：获取设备的序列号
参数  ：无
返回值：设备序列号
]]
local function getTerminalId()
    --默认使用设备的SN作为设备序列号，用户可以根据项目需求自行修改
    return misc.getSn()
    
    --用户单体测试时，可以在此处直接返回固定的字符串
    --return "IGIFHFACBFHIDEB"
    --return "8ad5569a57cf038c"
end

--支付宝客户端是否处于连接状态
local sConnected

local sendTransactionDataCnt,sendProductInfoDataCnt,sendActDataCnt = 0,0,0
local signCnt = 0;

local sendTransactionDataFailCnt = 0
--交易数据缓存结果回调
local function sendTransactionDataCbFnc(result)
    log.info("testALiPay.sendTransactionDataCbFnc",result,sendTransactionDataCnt)
    if result then
        sys.timerStart(sendTransactionDataTest,5000)
        sendTransactionDataFailCnt = 0
    else
        sys.timerStart(sendTransactionDataTest,50000)
        sendTransactionDataFailCnt = sendTransactionDataFailCnt+1
        --因为目前无法获取支付宝连接状态，以及交易数据发送结果
        --如果连续10次缓存交易数据失败，可以考虑重启
        --if( sendTransactionDataFailCnt>=50 then sys.restart("testAlipay.sendTransactionDataFail") end
    end
end

--缓存一条交易数据
function sendTransactionDataTest()
    log.info("testALiPay.sendTransactionDataTest",sConnected)
    if sConnected then
        sendTransactionDataCnt = sendTransactionDataCnt+1
        aLiPay.sendTransactionData("122345","",12,"","",sendTransactionDataCbFnc)
        --[[
        if sendTransactionDataCnt%3==0 then
            aLiPay.sendTransactionData("88899998888","98765",1234,4,5,sendTransactionDataCbFnc)
        elseif sendTransactionDataCnt%3==1 then
            aLiPay.sendTransactionData("12345698765",nil,nil,nil,1,sendTransactionDataCbFnc)
        elseif sendTransactionDataCnt%3==2 then
            aLiPay.sendTransactionData("12345698765","",100,"","",sendTransactionDataCbFnc)
        end
        ]]
    end
end

--产品规格数据缓存结果回调
local function sendProductInfoDataCbFnc(result)
    log.info("testALiPay.sendProductInfoDataCbFnc",result,sendProductInfoDataCnt)
    --根据蚂蚁金服文档说明，产品规格信息数据，每次开机只需要上报一次即可
    if not result then
        sys.timerStart(sendProductInfoDataTest,10000)
    end
end

--缓存一条产品规格信息数据
function sendProductInfoDataTest()
    log.info("testALiPay.sendProductInfoDataTest",sConnected)
    if sConnected then
        sendProductInfoDataCnt = sendProductInfoDataCnt+1
        aLiPay.sendProductInfoData(0x01,sendProductInfoDataCbFnc)
    end
end

--行为数据缓存结果回调
local function sendActDataCbFnc(result)
    log.info("testALiPay.sendActDataCbFnc",result,sendActDataCnt)
    if result then
        --根据蚂蚁金服文档说明，行为数据，每天上报三次即可
        sys.timerStart(sendActDataTest,8*3600*1000)
    else
        sys.timerStart(sendActDataTest,10000)
    end
end

--缓存一条行为数据
function sendActDataTest()
    log.info("testALiPay.sendActDataTest",sConnected)
    if sConnected then
        sendActDataCnt = sendActDataCnt+1
        aLiPay.sendActData(5,6,sendActDataCbFnc)
    end
end

--加签数据结果回调
local function signCbFnc(result,data)
    log.info("testALiPay.signCbFnc",result,data)
    sys.timerStart(signTest,5000)
end

--加签一条数据
function signTest()
    log.info("testALiPay.signTest")
    signCnt = signCnt+1
    local amount = nil
    if signCnt%2==0 then amount=tostring(signCnt) end
    aLiPay.sign((signCnt%4)+1,"sign_data_"..signCnt,amount,signCbFnc)
end


--- 连接结果的处理函数
-- @bool result，连接结果，true表示连接成功，false或者nil表示连接失败
local function connectCbFnc(result)
    log.info("testALiPay.connectCbFnc",result)
    sConnected = result
    if result then
        --打印设备的biztid
        log.info("testALiPay.connectCbFnc","biztid",aLiPay.getBiztid())
        --上报交易数据
        sendTransactionDataTest()
        --上报产品规格信息数据
        --sendProductInfoDataTest()
        --上报行为数据
        --sendActDataTest()
        --加签
        --signTest()
        --测试alipay关闭功能
        --sys.timerStart(aLiPay.close,60000,function(result) log.info("testALiPay.closeCb",result) end)
    end
end

aLiPay.setup(sDeviceSupplier,sMerchantUser,sItemId,sProductKey,getTerminalId)
aLiPay.on("connect",connectCbFnc)

