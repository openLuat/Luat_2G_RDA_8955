--- 模块功能：GPS模块管理
-- @module gpsv2
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.08.28
require "pm"
require "httpv2"
require "utils"
require "lbsLoc"
module(..., package.seeall)

-- 浮点支持
local float = rtos.get_version():upper():find("FLOAT")
-- GPS任务线程ID
local GPS_CO
--串口配置
local uartID, uartBaudrate = 2, 115200
-- 星历的保存地址
local GPD_FILE = "/ephdat.bin"
-- 下载超时设置单位分钟
local timeout = 5 * 60000
-- 设置星历和基站定位的循环定时器时间
local EPH_UPDATE_INTERVAL = 4 * 3600
-- 星历写入标记
local ephFlag = false
--GPS开启标志，true表示开启状态，false或者nil表示关闭状态
local openFlag
--GPS定位标志，true表示，其余表示未定位,hdop 水平精度
local fixFlag, hdop = false, "0"
-- 经纬度类型和数据
local latitudeType, latitude, longitudeType, longitude = "N", "", "E", ""
-- 海拔，速度，时速,方向角
local altitude, speed, kmHour, azimuth = "0", "0", "0", "0"
-- 参与定位的卫星个数,GPS和北斗可见卫星个数
local usedSateCnt, viewedGpsSateCnt, viewedBdSateCnt = "0", "0", "0"
-- 可用卫星号，UTC时间
local SateSn, UtcTime, utcStamp = {}, {}, 0
-- 大地高，度分经度，度分纬度
local Sep, Ggalng, Ggalat
-- GPS和北斗GSV解析保存的表
local gpgsvTab, bdgsvTab = {}, {}
-- GPGSV解析后的CNO信息
local gsvCnoTab = {}
-- 基站定位坐标
local lbs_lat, lbs_lng
-- 日志开关
local isLog = true
--解析GPS模块返回的信息
local function parseNmea(s)
    if not s or s == "" then return end
    if isLog then log.warn("定位模块上报的信息:", s) end
    local lat, lng, spd, cog, gpsFind, gpsTime, gpsDate, locSateCnt, hdp, latTyp, lngTyp, altd
    if s:match("GGA") then
        lat, latTyp, lng, lngTyp, gpsFind, locSateCnt, hdp, altd, sep = s:match("GGA,%d+%.%d+,(%d+%.%d+),([NS]),(%d+%.%d+),([EW]),(%d),(%d+),([%d%.]*),(.*),M,(.*),M")
        if (gpsFind == "1" or gpsFind == "2" or gpsFind == "4") and altd then
            altitude = altd
            usedSateCnt = locSateCnt
            Sep = sep
            hdop = hdp
        end
        Ggalng, Ggalat = (lngTyp == "W" and "-" or "") .. lng, (latTyp == "S" and "-" or "") .. lat
        latitudeType, longitudeType, latitude, longitude = latTyp, lngTyp, lat, lng
    elseif s:match("GSA") then
        local satesn = s:match("GSA,%w*,%d*,(%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,)") or ""
        if #satesn > 0 and s:match("%d+,") then SateSn = satesn end
    elseif s:match("GPGSV") then
        local curnum, lineno, sateNum, gsv_str = s:match("GPGSV,(%d),(%d),(%d+),(.*)%*.*")
        if curnum and lineno and sateNum and gsv_str then
            if tonumber(lineno) == 1 then
                gpgsvTab = {}
                gsvCnoTab = {}
                gpgsvTab.sateNum = sateNum
                gpgsvTab.sateType = "GPS"
            end
            for i = 1, 4 do
                local msg = {id, elevation, azimuth, cno}
                -- 找到的字符串的开始位置，结束位置,仰角，方位角，载波信噪比
                msg.id, msg.elevation, msg.azimuth, msg.cno, gsv_str = gsv_str:match("(%d+),([%-]*%d*),(%d*),(%d*)(.*)")
                if not msg.id then break end
                msg.id, msg.elevation, msg.azimuth, msg.cno = tonumber(msg.id) or 0, tonumber(msg.elevation) or 0, tonumber(msg.azimuth) or 0, tonumber(msg.cno) or 0
                table.insert(gpgsvTab, msg)
                table.insert(gsvCnoTab, msg.cno)
            end
            viewedGpsSateCnt = sateNum or "0"
        end
    -- log.info("GPGSV is value:", json.encode(gsvCnoTab))
    elseif s:match("BDGSV") then
        local curnum, lineno, sateNum, gsv_str = s:match("GPGSV,(%d),(%d),(%d+),(.*)%*.*")
        if curnum and lineno and sateNum and gsv_str then
            if tonumber(lineno) == 1 then
                bdgsvTab = {}
                bdgsvTab.sateNum = sateNum
                bdgsvTab.sateType = "BD"
            end
            -- 将同一消息编号的归类插入同一个编号中
            for i = 1, 4 do
                local msg = {id, elevation, azimuth, cno}
                -- 找到的字符串的开始位置，结束位置,仰角，方位角，载波信噪比
                msg.id, msg.elevation, msg.azimuth, msg.cno, gsv_str = gsv_str:match("(%d+),([%-]*%d*),(%d*),(%d*)(.*)")
                if not msg.id then break end
                msg.id, msg.elevation, msg.azimuth, msg.cno = tonumber(msg.id) or 0, tonumber(msg.elevation) or 0, tonumber(msg.azimuth) or 0, tonumber(msg.cno) or 0
                table.insert(bdgsvTab, msg)
            end
        end
        viewedBdSateCnt = sateNum or "0"
    elseif s:match("RMC") then
        gpsTime, gpsFind, lat, latTyp, lng, lngTyp, spd, cog, gpsDate = s:match("RMC,(%d%d%d%d%d%d)%.%d+,(%w),(%d*%.*%d*),([NS]*),(%d*%.*%d*),([EW]*),(.-),(.-),(%d%d%d%d%d%d),")
        if gpsFind == "A" and cog then
            fixFlag = true
            speed = spd
            azimuth = cog
        else
            fixFlag = false
        end
        latitudeType, longitudeType, latitude, longitude = latTyp, lngTyp, lat, lng
        if gpsFind == "A" and gpsTime and gpsDate and gpsTime ~= "" and gpsDate ~= "" then
            local yy, mm, dd, h, m, s = tonumber(gpsDate:sub(5, 6)), tonumber(gpsDate:sub(3, 4)), tonumber(gpsDate:sub(1, 2)), tonumber(gpsTime:sub(1, 2)), tonumber(gpsTime:sub(3, 4)), tonumber(gpsTime:sub(5, 6))
            utcStamp = os.time({year = 2000 + yy, month = mm, day = dd, hour = h, min = m, sec = s})
            UtcTime = os.date("*t", os.time({year = 2000 + yy, month = mm, day = dd, hour = h, min = m, sec = s}) + 28800)
            -- misc.setClock(UtcTime)
            sys.publish("GPS_TIMING_SUCCEED", UtcTime)
        end
    elseif s:match("VTG") then
        kmHour = s:match("VTG,%d*%.*%d*,%w*,%d*%.*%d*,%w*,%d*%.*%d*,%w*,(%d*%.*%d*)")
        -- if fixFlag then sys.publish("GPS_MSG_REPORT", 1) else sys.publish("GPS_MSG_NOREPORT", 0) end
        sys.publish("GPS_MSG_REPORT", fixFlag and 1 or 0)
    end
end

-- 阻塞模式读取串口数据，需要线程支持
-- @return 返回以\r\n结尾的一行数据
-- @usage local str = gpsv2.read()
local function read()
    local cache_data = ""
    local co = coroutine.running()
    while true do
        local s = uart.read(uartID, "*l")
        if s == "" then
            uart.on(uartID, "receive", function()coroutine.resume(co) end)
            coroutine.yield()
            uart.on(uartID, "receive")
        else
            cache_data = cache_data .. s
            if cache_data:find("\r\n") then return cache_data end
        end
    end
end
-- GPS串口写命令操作
-- @string cmd，GPS指令(cmd格式："$PGKC149,1,115200*"或者"$PGKC149,1,115200*XX\r\n")
-- @bool isFull，cmd是否为完整的指令格式，包括校验和以及\r\n；true表示完整，false或者nil为不完整
-- @return nil
-- @usage gpsv2.writeCmd(cmd)
local function writeCmd(cmd, isFull)
    local tmp = cmd
    if not isFull then
        tmp = 0
        for i = 2, cmd:len() - 1 do
            tmp = bit.bxor(tmp, cmd:byte(i))
        end
        tmp = cmd .. (string.format("%02X", tmp)):upper() .. "\r\n"
    end
    uart.write(uartID, tmp)
-- log.info("gpsv2.writecmd", tmp)
end

-- GPS串口写数据操作
-- @string str,HEX形式的字符串
-- @return 无
-- @usage gpsv2.writeData(str)
local function writeData(str)
    uart.write(uartID, (str:fromHex()))
-- log.info("gpsv2.writeData", str)
end
-- AIR530的校验和算法
local function hexCheckSum(str)
    local sum = 0
    for i = 5, str:len(), 2 do
        sum = bit.bxor(sum, tonumber(str:sub(i, i + 1), 16))
    end
    return string.upper(string.format("%02X", sum))
end
local function setFastFix(lat, lng)
    if not lat or not lng or not openFlag or os.time() < 1514779200 then return end
    local tm = os.date("*t")
    tm = common.timeZoneConvert(tm.year, tm.month, tm.day, tm.hour, tm.min, tm.sec, 8, 0)
    t = tm.year .. "," .. tm.month .. "," .. tm.day .. "," .. tm.hour .. "," .. tm.min .. "," .. tm.sec .. "*"
    -- log.info("写入秒定位需要的坐标和时间:", lat, lng, t)
    writeCmd("$PGKC634," .. t)
    writeCmd("$PGKC634," .. t)
    writeCmd("$PGKC635," .. lat .. "," .. lng .. ",0," .. t)
end

-- 定时自动下载坐标和星历的任务
local function getlbs(result, lat, lng, addr)
    if result and lat and lng then
        lbs_lat, lbs_lng = lat, lng
        setFastFix(lat, lng)
    end
end

local function saveEph(timeout)
    sys.taskInit(function()
        while true do
            local code, head, data = httpv2.request("GET", "download.openluat.com/9501-xingli/brdcGPD.dat_rda", timeout)
            if tonumber(code) and tonumber(code) == 200 then
                log.info("保存下载的星历:", io.writeFile(GPD_FILE, data))
                ephFlag = false
                break
            end
        end
    end)
end

--- 打开GPS模块
-- @number id，UART ID，支持1和2，1表示UART1，2表示UART2
-- @number baudrate，波特率，支持1200,2400,4800,9600,10400,14400,19200,28800,38400,57600,76800,115200,230400,460800,576000,921600,1152000,4000000
-- @nunber mode,功耗模式0正常功耗，2周期唤醒
-- @number sleepTm,间隔唤醒的时间 秒
-- @param fnc,外部模块使用的电源管理函数
-- @return 无
-- @usage gpsv2.open()
-- @usage gpsv2.open(2, 115200, 0, 1)  -- 打开GPS，串口2，波特率115200，正常功耗模式，1秒1个点
-- @usage gpsv2.open(2, 115200, 2, 5) -- 打开GPS，串口2，波特率115200，周期低功耗模式1秒输出，5秒睡眠
function open(id, baudrate, mode, sleepTm, fnc)
    uartID, uartBaudrate = tonumber(id) or uartID, tonumber(baudrate) or uartBaudrate
    mode, sleepTm = tonumber(mode) or 0, tonumber(sleepTm) and sleepTm * 1000 or 1000
    pm.wake("gpsv2.lua")
    uart.close(uartID)
    uart.setup(uartID, uartBaudrate, 8, uart.PAR_NONE, uart.STOP_1)
    if fnc and type(fnc) == "function" then
        fnc()
    else
        pmd.ldoset(7, pmd.LDO_VIB)
        pmd.ldoset(7, pmd.LDO_VCAM)
        rtos.sys32k_clk_out(1)
    end
    openFlag = true
    local fullPowerMode = false
    local wakeFlag = false
    ---------------------------------- 初始化GPS任务--------------------------------------------
    -- 获取基站定位坐标
    lbsLoc.request(getlbs, nil, timeout)
    --连接服务器下载星历
    saveEph(timeout)
    -- 自动定时下载定位坐标
    sys.timerLoopStart(function()lbsLoc.request(getlbs, nil, timeout) end, EPH_UPDATE_INTERVAL * 1000)
    -- 自动定时下载星历数据
    sys.timerLoopStart(saveEph, EPH_UPDATE_INTERVAL * 1000, timeout)
    log.info("----------------------------------- GPS OPEN -----------------------------------")
    GPS_CO = sys.taskInit(function()
        read()
        -- 发送GPD传送结束语句
        writeData("AAF00B006602FFFF6F0D0A")
        -- 切换为NMEA接收模式
        local nmea = "AAF00E00950000" .. (pack.pack("<i", uartBaudrate):toHex())
        nmea = nmea .. hexCheckSum(nmea) .. "0D0A"
        writeData(nmea)
        writeCmd("$PGKC147," .. uartBaudrate .. "*")
        setReport(1000)
        while openFlag do
            if not fixFlag and not ephFlag and io.exists(GPD_FILE) and os.time() > 1514779200 then
                local tmp, data, len = "", io.readFile(GPD_FILE):toHex()
                log.info("模块写星历数据开始!")
                -- 切换到BINARY模式
                while read():toHex() ~= "AAF00C0001009500039B0D0A" do writeCmd("$PGKC149,1," .. uartBaudrate .. "*") end
                -- 写入星历数据
                local cnt = 0 -- 包序号
                for i = 1, #data, 1024 do
                    local tmp = data:sub(i, i + 1023)
                    if tmp:len() < 1024 then tmp = tmp .. ("F"):rep(1024 - tmp:len()) end
                    tmp = "AAF00B026602" .. string.format("%04X", cnt):upper() .. tmp
                    tmp = tmp .. hexCheckSum(tmp) .. "0D0A"
                    writeData(tmp)
                    for j = 1, 30 do
                        local ack, len = read():toHex()
                        if len == 12 or ack:find("AAF00C0003") then break end
                    end
                    cnt = cnt + 1
                end
                -- 发送GPD传送结束语句
                writeData("AAF00B006602FFFF6F0D0A")
                -- 切换为NMEA接收模式
                while not read():find("$G") do writeData(nmea) end
                setFastFix(lbs_lat, lbs_lng)
                ephFlag = true
                fullPowerMode = true
                log.info("模块写星历数据完成!")
            end
            if tonumber(mode) == 2 then
                fixFlag = false
                -- setRunMode(0, 1000, sleepTm)
                setReport(1000)
                while not fixFlag do
                    parseNmea(read())
                end
                parseNmea(read())
                if fixFlag then end
                -- while not read():match("PGKC001,105,(3)") do setRunMode(2, 1000, sleepTm) end
                writeCmd("$PGKC051,1*")
                sys.wait(sleepTm)
            -- while fixFlag do parseNmea(read()) end
            else
                if not wakeFlag then
                    setRunMode(mode, 1000, sleepTm)
                    setReport(sleepTm)
                    wakeFlag = true
                end
                parseNmea(read())
            end
        end
        sys.publish("GPS_CLOSE_MSG")
        log.info("GPS 任务结束退出!")
    end)
end
--- 关闭GPS模块
-- @param fnc,外部模块使用的电源管理函数
-- @return 无
-- @usage gpsv2.close()
function close(id, fnc)
    openFlag = false
    fixFlag = false
    while GPS_CO ~= nil and coroutine.status(GPS_CO) ~= "dead" do coroutine.resume(GPS_CO) end
    uart.close(tonumber(id) or uartID)
    if fnc and type(fnc) == "function" then
        fnc()
    else
        pmd.ldoset(0, pmd.LDO_VIB)
        pmd.ldoset(0, pmd.LDO_VCAM)
        rtos.sys32k_clk_out(0)
    end
    pm.sleep("gpsv2.lua")
    sys.timerStopAll(restart)
    log.info("----------------------------------- GPS CLOSE -----------------------------------")
end
--- 重启GPS模块
-- @number r,重启方式-0:外部电源重置; 1:热启动; 2:温启动; 3:冷启动
-- @return 无
-- @usage gpsv2.restart()
function restart(r)
    r = tonumber(r) or 1
    if r > 0 and r < 4 then writeCmd("$PGKC030," .. r .. "*") end
end

--- 设置GPS模块搜星模式.
-- 如果使用的是Air800或者Air530，不调用此接口配置，则默认同时开启GPS和北斗定位
-- @number gps，GPS定位系统，1是打开，0是关闭
-- @number beidou，中国北斗定位系统，1是打开，0是关闭
-- @number glonass，俄罗斯Glonass定位系统，1是打开，0是关闭
-- @number galieo，欧盟伽利略定位系统，1是打开，0是关闭
-- @return nil
-- @usage gpsv2.setAeriaMode(1,1,0,0)
function setAerialMode(gps, beidou, glonass, galieo)
    local gps = gps or 0
    local glonass = glonass or 0
    local beidou = beidou or 0
    local galieo = galieo or 0
    if gps + glonass + beidou + galieo == 0 then gps = 1; beidou = 1 end
    if openFlag then writeCmd("$PGKC115," .. gps .. "," .. glonass .. "," .. beidou .. "," .. galieo .. "*") end
end

--- 设置GPS模块的运行模式.
-- 如果不调用此接口配置，则默认为正常运行模式
-- @number mode，运行模式
-- 0：正常运行模式
-- 1：周期超低功耗跟踪模式
-- 2：周期低功耗模式
-- 4：直接进入超低功耗跟踪模式
-- 8：自动低功耗模式，可以通过串口唤醒
-- 9：自动超低功耗跟踪模式，需要force on来唤醒
-- @number runTm，单位毫秒，mode为1或者2时表示运行时长，其余mode时此值无意义
-- @number sleepTm，单位毫秒，mode为1或者2时表示睡眠时长，其余mode时此值无意义
-- @return nil
-- @usage gpsv2.setRunMode(0,1000)
-- @usage gpsv2.setRunMode(1,5000,2000)
function setRunMode(mode, runTm, sleepTm)
    local rt, st = tonumber(runTm) or "", tonumber(sleepTm) or ""
    if openFlag then
        writeCmd("$PGKC105," .. mode .. ((mode == 1 or mode == 2) and ("," .. rt .. "," .. st) or "") .. "*")
    end
end

--- 设置NMEA消息上报的间隔
-- @number tm，上报消息的间隔时间
-- @return 无
-- @usage gpsv2.setReport(tm)
function setReport(tm)
    if openFlag then
        tm = tonumber(tm) or 1000
        if tm > 10000 then tm = 10000 end
        if tm < 200 then tm = 200 end
        writeCmd("$PGKC101," .. tm .. "*")
    end
end

--- 获取GPS模块是否处于开启状态
-- @return bool result，true表示开启状态，false或者nil表示关闭状态
-- @usage gpsv2.isOpen()
function isOpen()
    return openFlag
end

--- 获取GPS模块是否定位成功
-- @return bool result，true表示定位成功，false或者nil表示定位失败
-- @usage gpsv2.isFix()
function isFix()
    return fixFlag
end

--- 获取返回值为度的10&7方的整数值（度*10^7的值）
-- @return number,number,INT32整数型,经度,维度,符号(正东负西,正北负南)
-- @usage gpsv2.getIntLocation()
function getIntLocation()
    local lng, lat = "0.0", "0.0"
    lng = longitudeType == "W" and ("-" .. longitude) or longitude
    lat = latitudeType == "S" and ("-" .. latitude) or latitude
    if lng and lat and lng ~= "" and lat ~= "" then
        local integer, decimal = lng:match("(%d+).(%d+)")
        if tonumber(integer) and tonumber(decimal) then
            decimal = decimal:sub(1, 7)
            local tmp = (integer % 100) * 10 ^ 7 + decimal * 10 ^ (7 - #decimal)
            lng = ((integer - integer % 100) / 100) * 10 ^ 7 + (tmp - tmp % 60) / 60
        end
        integer, decimal = lat:match("(%d+).(%d+)")
        if tonumber(integer) and tonumber(decimal) then
            decimal = decimal:sub(1, 7)
            tmp = (integer % 100) * 10 ^ 7 + decimal * 10 ^ (7 - #decimal)
            lat = ((integer - integer % 100) / 100) * 10 ^ 7 + (tmp - tmp % 60) / 60
        end
        return lng, lat
    end
    return 0, 0
end
--- 获取基站定位的经纬度信息dd.dddd
function getDeglbs()
    return lbs_lng or "0.0", lbs_lat or "0.0"
end

--- 获取度格式的经纬度信息dd.dddddd
-- @return string,string,固件为非浮点时返回度格式的字符串经度,维度,符号(正东负西,正北负南)
-- @return float,float,固件为浮点的时候，返回浮点类型
-- @usage gpsv2.getLocation()
function getDegLocation()
    local lng, lat = getIntLocation()
    if float then return lng / 10 ^ 7, lat / 10 ^ 7 end
    return string.format("%d.%07d", lng / 10 ^ 7, lng % 10 ^ 7), string.format("%d.%07d", lat / 10 ^ 7, lat % 10 ^ 7)
end

--- 获取度分格式的经纬度信息ddmm.mmmm
-- @return string,string,返回度格式的字符串经度,维度,符号(正东负西,正北负南)
-- @usage gpsv2.getCentLocation()
function getCentLocation()
    if float then return tonumber(Ggalng or 0), tonumber(Ggalat or 0) end
    return Ggalng or 0, Ggalat or 0
end

--- 获取海拔
-- @return number altitude，海拔，单位米
-- @usage gpsv2.getAltitude()
function getAltitude()
    return tonumber(altitude and altitude:match("(%d+)")) or 0
end

--- 获取速度
-- @return number kmSpeed，第一个返回值为公里每小时的速度
-- @return number nmSpeed，第二个返回值为海里每小时的速度
-- @usage gpsv2.getSpeed()
function getSpeed()
    local integer = tonumber(speed and speed:match("(%d+)")) or 0
    return (integer * 1852 - (integer * 1852 % 1000)) / 1000, integer
end

--- 获取时速(KM/H)的整数型和浮点型(字符串)
function getKmHour()
    return tonumber(kmHour and kmHour:match("(%d+)")) or 0, (float and tonumber(kmHour) or kmHour) or "0"
end

--- 获取方向角
-- @return number Azimuth，方位角
-- @usage gpsv2.getAzimuth()
function getAzimuth()
    return tonumber(azimuth and azimuth:match("(%d+)")) or 0
end

--- 获取可见卫星的个数
-- @return number count，可见卫星的个数
-- @usage gpsv2.getViewedSateCnt()
function getViewedSateCnt()
    return tonumber(viewedGpsSateCnt) or 0 + tonumber(viewedBdSateCnt) or 0
end

--- 获取定位使用的卫星个数
-- @return number count，定位使用的卫星个数
-- @usage gpsv2.getUsedSateCnt()
function getUsedSateCnt()
    return tonumber(usedSateCnt) or 0
end

--- 获取RMC语句中的UTC时间
-- 只有同时满足如下两个条件，返回值才有效
-- 1、开启了GPS，并且定位成功
-- 2、调用setParseItem接口，第一个参数设置为true
-- @return table utcTime，UTC时间，nil表示无效，例如{year=2018,month=4,day=24,hour=11,min=52,sec=10}
-- @usage gpsv2.getUtcTime()
function getUtcTime()
    return UtcTime
end

--- 获取gps的UTC时间戳
-- @retrun number，时间戳
-- @usage gpsv2.getUtcStamp()
function getUtcStamp()
    return utcStamp or 0
end
--- 获取定位使用的大地高
-- @return number sep，大地高
-- @usage gpsv2.getSep()
function getSep()
    return tonumber(Sep) or 0
end

--- 获取水平精度
function getHdop()
    return tonumber(hdop) or 0
end

--- 获取GSA语句中的可见卫星号
-- 只有同时满足如下两个条件，返回值才有效
-- 1、开启了GPS，并且定位成功
-- 2、调用setParseItem接口，第三个参数设置为true
-- @return string viewedSateId，可用卫星号，""表示无效
-- @usage gpsv2.getSateSn()
function getSateSn()
    return tonumber(SateSn) or 0
end
--- 获取BDGSV解析结果
-- @return table, GSV解析后的数组
-- @usage gpsv2.getBDGsv()
function getBDGsv()
    return bdgsvTab
end
--- 获取GPGSV解析结果
-- @return table, GSV解析后的数组
-- @usage gpsv2.getGPGsv()
function getGPGsv()
    return gpgsvTab
end
--- 获取GPSGSV解析后的CNO数据
function getCno()
    return gsvCnoTab
end

--- 是否显示日志
function openLog(v)
    isLog = v == nil and true or v
end
