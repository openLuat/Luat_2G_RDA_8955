---模块功能：网络管理、信号查询、GSM网络状态查询、网络指示灯控制、临近小区信息查询
-- @module net
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.02.17

require "sys"
require "ril"
require "pio"
require "sim"
require "log"
module(..., package.seeall)

--加载常用的全局函数至本地
local publish = sys.publish

--GSM网络状态：
--INIT：开机初始化中的状态
--REGISTERED：注册上GSM网络
--UNREGISTER：未注册上GSM网络
local state = "INIT"
--SIM卡状态：true为异常，false或者nil为正常
local simerrsta
-- 飞行模式状态
flyMode = false

--lac：位置区ID
--ci：小区ID
--rssi：信号强度
local lac, ci, rssi = "", "", 0
--cellinfo：当前小区和临近小区信息表
--multicellcb：获取多小区的回调函数
local cellinfo, multicellcb = {}
--注册标志参数，creg3：true为没注册，为false为注册成功
--local creg3
--[[
函数名：checkCRSM
功能：如果注册被拒绝，运行此函数，先判断是否取得imsi号，再判断是否是中国移动卡
如果确定是中国移动卡，则进行SIM卡限制访问
参数：
返回值：
]]
--[[
local function checkCRSM()
    local imsi = sim.getImsi()
    if imsi and imsi ~= "" then
        if string.sub(imsi, 1, 3) == "460" then
            local mnc = string.sub(imsi, 4, 5)
            if (mnc == "00" or mnc == "02" or mnc == "04" or mnc == "07") and creg3 then
                ril.request("AT+CRSM=176,28539,0,0,12")
            end
        end
    else
        sys.timerStart(checkCRSM, 5000)
    end
end
]]

--[[
函数名：creg
功能  ：解析CREG信息
参数  ：data：CREG信息字符串，例如+CREG: 2、+CREG: 1,"18be","93e1"、+CREG: 5,"18a7","cb51"
返回值：无
]]
local function creg(data)
    local p1, s
    --获取注册状态
    _, _, p1 = string.find(data, "%d,(%d)")
    if p1 == nil then
        _, _, p1 = string.find(data, "(%d)")
        if p1 == nil then
            return
        end
    end
    --creg3 = false
    --已注册
    if p1 == "1" or p1 == "5" then
        s = "REGISTERED"
    --未注册
    else
        --[[
        if p1 == "3" then
            creg3 = true
            checkCRSM()
        end
        ]]
        s = "UNREGISTER"
    end
    --注册状态发生了改变
    if s ~= state then
        --临近小区查询处理
        if s == "REGISTERED" then
            --产生一个内部消息NET_STATE_CHANGED，表示GSM网络注册状态发生变化
            publish("NET_STATE_REGISTERED")
            cengQueryPoll()
        end
        state = s
    
    end
    --已注册并且lac或ci发生了变化
    if state == "REGISTERED" then
        p2, p3 = string.match(data, "\"(%x+)\",\"(%x+)\"")
        if lac ~= p2 or ci ~= p3 then
            lac = p2
            ci = p3
            --产生一个内部消息NET_CELL_CHANGED，表示lac或ci发生了变化
            publish("NET_CELL_CHANGED")
        end
    end
end

--[[
函数名：resetcellinfo
功能  ：重置当前小区和临近小区信息表
参数  ：无
返回值：无
]]
local function resetCellInfo()
    local i
    cellinfo.cnt = 11 --最大个数
    for i = 1, cellinfo.cnt do
        cellinfo[i] = {}
        cellinfo[i].mcc, cellinfo[i].mnc = nil
        cellinfo[i].lac = 0
        cellinfo[i].ci = 0
        cellinfo[i].rssi = 0
        cellinfo[i].ta = 0
    end
end

--[[
函数名：ceng
功能  ：解析当前小区和临近小区信息
参数  ：
data：当前小区和临近小区信息字符串，例如下面中的每一行：
+CENG:1,1
+CENG:0,"573,24,99,460,0,13,49234,10,0,6311,255"
+CENG:1,"579,16,460,0,5,49233,6311"
+CENG:2,"568,14,460,0,26,0,6311"
+CENG:3,"584,13,460,0,10,0,6213"
+CENG:4,"582,13,460,0,51,50146,6213"
+CENG:5,"11,26,460,0,3,52049,6311"
+CENG:6,"29,26,460,0,32,0,6311"
返回值：无
]]
local function ceng(data)
    --只处理有效的CENG信息
    if string.find(data, "%+CENG:%d+,\".+\"") then
        local id, rssi, lac, ci, ta, mcc, mnc
        id = string.match(data, "%+CENG:(%d)")
        id = tonumber(id)
        --第一条CENG信息和其余的格式不同
        if id == 0 then
            rssi, mcc, mnc, ci, lac, ta = string.match(data, "%+CENG: *%d, *\"%d+, *(%d+), *%d+, *(%d+), *(%d+), *%d+, *(%d+), *%d+, *%d+, *(%d+), *(%d+)\"")
        else
            rssi, mcc, mnc, ci, lac, ta = string.match(data, "%+CENG: *%d, *\"%d+, *(%d+), *(%d+), *(%d+), *%d+, *(%d+), *(%d+)\"")
        end
        --解析正确
        if rssi and ci and lac and mcc and mnc then
            --如果是第一条，清除信息表
            if id == 0 then
                resetCellInfo()
            end
            --保存mcc、mnc、lac、ci、rssi、ta
            cellinfo[id + 1].mcc = mcc
            cellinfo[id + 1].mnc = mnc
            cellinfo[id + 1].lac = tonumber(lac)
            cellinfo[id + 1].ci = tonumber(ci)
            cellinfo[id + 1].rssi = (tonumber(rssi) == 99) and 0 or tonumber(rssi)
            cellinfo[id + 1].ta = tonumber(ta or "0")
            --产生一个内部消息CELL_INFO_IND，表示读取到了新的当前小区和临近小区信息
            if id == 0 then
                if multicellcb then multicellcb(cellinfo) end
                publish("CELL_INFO_IND", cellinfo)
            end
        end
    end
end

-- crsm更新计数
--local crsmUpdCnt = 0

-- 更新FPLMN的应答处理
-- @string cmd  ,此应答对应的AT命令
-- @bool success ,AT命令执行结果，true或者false
-- @string response ,AT命令的应答中的执行结果字符串
-- @string intermediate ,AT命令的应答中的中间信息
-- @return 无
--[[
function crsmResponse(cmd, success, response, intermediate)
    log.debug("net.crsmResponse", success)
    if success then
        sys.restart("net.crsmResponse suc")
    else
        crsmUpdCnt = crsmUpdCnt + 1
        if crsmUpdCnt >= 3 then
            sys.restart("net.crsmResponse tmout")
        else
            ril.request("AT+CRSM=214,28539,0,0,12,\"64f01064f03064f002fffff\"", nil, crsmResponse)
        end
    end
end
]]

--[[
函数名：neturc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
data：通知的完整字符串信息
prefix：通知的前缀
返回值：无
]]
local function neturc(data, prefix)
    if prefix == "+CREG" then
        --收到网络状态变化时,更新一下信号值
        csqQueryPoll()
        --解析creg信息
        creg(data)
    elseif prefix == "+CENG" then
        --解析ceng信息
        ceng(data)
    --[[elseif prefix == "+CRSM" then
        local str = string.lower(data)
        if string.match(str, "64f000") or string.match(str, "64f020") or string.match(str, "64f040") or string.match(str, "64f070") then
            ril.request("AT+CRSM=214,28539,0,0,12,\"64f01064f03064f002fffff\"", nil, crsmResponse)
        end]]
    end
end

--- 设置飞行模式
-- @bool mode，true:飞行模式开，false:飞行模式关
-- @return nil
-- @usage net.switchFly(mode)
function switchFly(mode)
    if flyMode == mode then return end
    flyMode = mode
    -- 处理飞行模式
    if mode then
        ril.request("AT+CFUN=0")
    -- 处理退出飞行模式
    else
        ril.request("AT+CFUN=1")
        --处理查询定时器
        csqQueryPoll()
        cengQueryPoll()
        --复位GSM网络状态
        neturc("2", "+CREG")
    end
end

--- 获取GSM网络注册状态
-- @return string state,GSM网络注册状态，
-- "INIT"表示正在初始化
-- "REGISTERED"表示已注册
-- "UNREGISTER"表示未注册
-- @usage net.getState()
function getState()
    return state
end

--- 获取当前小区的mcc
-- @return string mcc,当前小区的mcc，如果还没有注册GSM网络，则返回sim卡的mcc
-- @usage net.getMcc()
function getMcc()
    return cellinfo[1].mcc or sim.getMcc()
end

--- 获取当前小区的mnc
-- @return string mcn,当前小区的mnc，如果还没有注册GSM网络，则返回sim卡的mnc
-- @usage net.getMnc()
function getMnc()
    return cellinfo[1].mnc or sim.getMnc()
end

--- 获取当前位置区ID
-- @return string lac,当前位置区ID(16进制字符串，例如"18be")，如果还没有注册GSM网络，则返回""
-- @usage net.getLac()
function getLac()
    return lac
end

--- 获取当前小区ID
-- @return string ci,当前小区ID(16进制字符串，例如"93e1")，如果还没有注册GSM网络，则返回""
-- @usage net.getCi()
function getCi()
    return ci
end

--- 获取信号强度
-- @return number rssi,当前信号强度(取值范围0-31)
-- @usage net.getRssi()
function getRssi()
    return rssi
end

--- 获取当前和临近位置区、小区以及信号强度的拼接字符串
-- @return string cellInfo,当前和临近位置区、小区以及信号强度的拼接字符串，例如："6311.49234.30;6311.49233.23;6322.49232.18;"
-- @usage net.getCellInfo()
function getCellInfo()
    local i, ret = 1, ""
    for i = 1, cellinfo.cnt do
        if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
            ret = ret .. cellinfo[i].lac .. "." .. cellinfo[i].ci .. "." .. cellinfo[i].rssi .. ";"
        end
    end
    return ret
end

--- 获取当前和临近位置区、小区、mcc、mnc、以及信号强度的拼接字符串
-- @return string cellInfo,当前和临近位置区、小区、mcc、mnc、以及信号强度的拼接字符串，例如："460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;"
-- @usage net.getCellInfoExt()
function getCellInfoExt(dbm)
    local i, ret = 1, ""
    for i = 1, cellinfo.cnt do
        if cellinfo[i] and cellinfo[i].mcc and cellinfo[i].mnc and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
            ret = ret .. cellinfo[i].mcc .. "." .. cellinfo[i].mnc .. "." .. cellinfo[i].lac .. "." .. cellinfo[i].ci .. "." .. (dbm and (cellinfo[i].rssi*2-113) or cellinfo[i].rssi) .. ";"
        end
    end
    return ret
end

--- 获取TA值
-- @return number ta,TA值
-- @usage net.getTa()
function getTa()
    return cellinfo[1].ta
end

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
local function rsp(cmd, success, response, intermediate)
    local prefix = string.match(cmd, "AT(%+%u+)")
    
    log.info("net.rsp",cmd, success, response, intermediate)
    
    if prefix == "+CSQ" then
        if intermediate ~= nil then
            local s = string.match(intermediate, "+CSQ:%s*(%d+)")
            if s ~= nil then
                rssi = tonumber(s)
                rssi = rssi == 99 and 0 or rssi
                --产生一个内部消息GSM_SIGNAL_REPORT_IND，表示读取到了信号强度
                publish("GSM_SIGNAL_REPORT_IND", success, rssi)
            end
        end
    elseif prefix == "+CFUN" then
        if success then publish("FLYMODE", flyMode) end
    end
end

--- 实时读取“当前和临近小区信息”
-- @function cbFnc，回调函数，当读取到小区信息后，会调用此回调函数，回调函数的调用形式为：
-- cbFnc(cells)，其中cells为string类型，格式为：当前和临近位置区、小区、mcc、mnc、以及信号强度的拼接字符串，例如："460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;"
-- @return nil
function getMultiCell(cbFnc)
    multicellcb = cbFnc
    --发送AT+CENG?查询
    ril.request("AT+CENG?")
end

--- 发起查询基站信息(当前和临近小区信息)的请求
-- @number period 查询间隔，单位毫秒
-- @return bool result, true:查询成功，false:查询失败
-- @usage net.cengQueryPoll() --查询1次
-- @usage net.cengQueryPoll(60000) --每分钟查询1次
function cengQueryPoll(period)
    -- 不是飞行模式 并且 工作模式为完整模式
    if not flyMode then        
        --发送AT+CENG?查询
        ril.request("AT+CENG?")
    else
        log.warn("net.cengQueryPoll", "flymode:", flyMode)
    end
    if nil ~= period then
        --启动定时器
        sys.timerStopAll(cengQueryPoll)
        sys.timerStart(cengQueryPoll, period, period)
    end
    return not flyMode
end

--- 发起查询信号强度的请求
-- @number period 查询间隔，单位毫秒
-- @return bool , true:查询成功，false:查询停止
-- @usage net.csqQueryPoll() --查询1次
-- @usage net.csqQueryPoll(60000) --每分钟查询1次
function csqQueryPoll(period)
    --不是飞行模式 并且 工作模式为完整模式
    if not flyMode then        
        --发送AT+CSQ查询
        ril.request("AT+CSQ")
    else
        log.warn("net.csqQueryPoll", "flymode:", flyMode)
    end
    if nil ~= period then
        --启动定时器
        sys.timerStopAll(csqQueryPoll)
        sys.timerStart(csqQueryPoll, period, period)
    end
    return not flyMode
end


--- 设置查询信号强度和基站信息的间隔
-- @number ... 查询周期,参数可变，参数为nil只查询1次，参数1是信号强度查询周期，参数2是基站查询周期
-- @return bool ，true：设置成功，false：设置失败
-- @usage net.startQueryAll()
-- @usage net.startQueryAll(60000) -- 1分钟查询1次信号强度，只立即查询1次基站信息
-- @usage net.startQueryAll(60000,600000) -- 1分钟查询1次信号强度，10分钟查询1次基站信息
function startQueryAll(...)
    csqQueryPoll(arg[1])
    cengQueryPoll(arg[2])
    if flyMode then        
        log.info("sim.startQuerAll", "flyMode:", flyMode)
    end
    return true
end

--- 停止查询信号强度和基站信息
-- @return 无
-- @usage net.stopQueryAll()
function stopQueryAll()
    sys.timerStopAll(csqQueryPoll)
    sys.timerStopAll(cengQueryPoll)
end

-- 处理SIM卡状态消息，SIM卡工作不正常时更新网络状态为未注册
sys.subscribe("SIM_IND", function(para)
    log.info("SIM.subscribe", simerrsta, para)
    if simerrsta ~= (para ~= "RDY") then
        simerrsta = (para ~= "RDY")
    end
    --sim卡工作不正常
    if para ~= "RDY" then
        --更新GSM网络状态
        state = "UNREGISTER"
        --产生内部消息NET_STATE_CHANGED，表示网络状态发生变化
        publish("NET_STATE_UNREGISTER")
    else
        state = "INIT"
    end
end)

--注册+CREG和+CENG通知的处理函数
ril.regUrc("+CREG", neturc)
ril.regUrc("+CENG", neturc)
--ril.regUrc("+CRSM", neturc)
--注册AT+CCSQ和AT+CENG?命令的应答处理函数
ril.regRsp("+CSQ", rsp)
ril.regRsp("+CENG", rsp)
ril.regRsp("+CFUN", rsp)-- 飞行模式
--发送AT命令
ril.request("AT+CREG=2")
ril.request("AT+CREG?")
ril.request("AT+CENG=1,1")
--重置当前小区和临近小区信息表
resetCellInfo()
