--- 模块功能：GPS模块管理
-- @module gps
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.10.23
require"pm"
require"utils"
module(..., package.seeall)

local smatch,sfind,slen,ssub,sbyte,sformat,srep = string.match,string.find,string.len,string.sub,string.byte,string.format,string.rep

--GPS开启标志，true表示开启状态，false或者nil表示关闭状态
local openFlag
--GPS定位标志，"2D"表示2D定位，"3D"表示3D定位，其余表示未定位
--GPS定位标志，true表示，其余表示未定位
local fixFlag
--GPS定位成功后，过滤掉前filterSeconds秒的经纬度信息
--是否已经过滤完成
local filterSeconds,filteredFlag = 0
--从定位成功切换到定位失败，连续定位失败的次数
local fixFailCnt = 0
--经纬度类型和数据
local latitudeType,latitude,longitudeType,longitude = "N","","E",""
--海拔，速度，方向角
local altitude,speed,course = "0","0","0"
--参与定位的卫星个数，所有可见卫星的最大信号值,所有可见卫星的最大信号值中间缓存值
local usedSateCnt,maxSignalStrength,maxSignalStrengthVar = "0",0,0
--可见卫星个数
local viewedGpsSateCnt,viewedBdSateCnt = "0","0"
--可用卫星号，UTC时间，信噪比
local SateSn,UtcTime,Gsv
--大地高，度分经度，度分纬度
local Sep,Ggalng,Ggalat
--是否需要解析项
local psUtcTime,psGsv,psSn

--GPS供电设置函数
local powerCbFnc
--串口配置
uartBaudrate = 115200
local uartID,uartDatabits,uartParity,uartStopbits = 2,8,uart.PAR_NONE,uart.STOP_1
--搜星模式命令字符串，"$PGKC115," .. gps .. "," .. glonass .. "," .. beidou .. "," .. galieo .. "*"
local aerialModeStr,aerialModeSetted = ""
--运行模式命令字符串，"$PGKC105," .. mode .. "," .. rt .. "," .. st .. "*"
local runModeStr,runModeSetted = ""
--正常运行模式下NMEA数据上报间隔命令字符串，"$PGKC101," .. interval .. "*"
local nmeaReportStr,nmeaReportSetted = ""
--每种NEMA数据的输出频率命令字符串
local nmeaReportFreqStr,nmeaReportFreqSetted = ""
--NMEA数据处理模式，0表示仅gps.lua内部处理，1表示仅用户自己处理，2表示gps.lua和用户同时处理
--用户处理一条NMEA数据的回调函数
local nmeaMode,nmeaCbFnc = 0
--NMEA数据输出间隔
local nmeaInterval = 1000
--运行模式
--0，正常运行模式
--1，周期超低功耗跟踪模式
--2，周期低功耗模式
--4，直接进入超低功耗跟踪模式
--8，自动低功耗模式，可以通过串口唤醒
--9, 自动超低功耗跟踪模式，需要force on来唤醒
local runMode = 0
--runMode为1或者2时，GPS运行状态和休眠状态的时长
local runTime,sleepTime

--[[
函数名：getstrength
功能  ：解析GSV数据
参数  ：
		sg：NEMA中的一行GSV数据
返回值：无
]]
local function getstrength(sg)
    sg = ssub(sg, 4, #sg)
    local d1,d2,curnum,lineno,total,sgv_str = sfind(sg,"GSV,(%d),(%d),(%d+),(.*)%*.*")

    if not curnum or not lineno or not total or not sgv_str then
        return
    end
    if lineno == nil then
        maxSignalStrengthVar = 0
        maxSignalStrength = 0
    elseif tonumber(lineno) == 1 then
        maxSignalStrength = maxSignalStrengthVar
        maxSignalStrengthVar = 0
    end
	
    local tmpstr,i = sgv_str
    for i=1,4 do
        local d1,d2,id,elevation,azimuth,strength = sfind(tmpstr,"(%d+),([%-]*%d*),(%d*),(%d*)")
        if id == nil then return end
        if strength == "" or not strength then
            strength = "00"
        end
        strength = tonumber(strength)
        if strength > maxSignalStrengthVar then
            maxSignalStrengthVar = strength
        end

        local idx,cur,fnd,tmpid = 0,id..","..elevation..","..azimuth..","..strength..",",false
        for tmpid in string.gmatch(Gsv,"(%d+),%d*,%d*,%d*,") do
            idx = idx + 1
            if tmpid == id then fnd = true break end
        end
        if fnd then
            local pattern,i = ""
            for i=1,idx do
                pattern = pattern.."%d+,%d*,%d*,%d*,"
            end
            local m1,m2 = sfind(Gsv,"^"..pattern)
            if m1 and m2 then
                local front = ssub(Gsv,1,m2)
                local n1,n2 = sfind(front,"%d+,%d*,%d*,%d*,$")
                if n1 and n2 then
                    Gsv = ssub(Gsv,1,n1-1)..cur..ssub(Gsv,n2+1,-1)
                end
            end
        else
            Gsv = Gsv..cur
        end

        tmpstr = ssub(tmpstr,d2+1,-1)
    end
end

local function filterTimerFnc()
    log.info("gps.filterTimerFnc end")
    filteredFlag = true
end

local function parseNmea(s)
    if not s or s=="" then return end
    local lat,lng,spd,cog,gpsFind,gpsTime,gpsDate,locSateCnt,hdp,latTyp,lngTyp,altd

    local hexStr = s:toHex()
    if "AAF00C0001009500039B0D0A"==hexStr then
        sys.publish("GPS_STATE","BINARY_CMD_ACK")
        return
    elseif smatch(hexStr,"^AAF00C000300") then
        sys.publish("GPS_STATE",smatch(hexStr,"^AAF00C000300FFFF") and "WRITE_EPH_END_ACK" or "WRITE_EPH_ACK")
        return
    end

    local fixed

    if smatch(s,"GGA") then
        lat,latTyp,lng,lngTyp,gpsFind,locSateCnt,hdp,altd,sep = smatch(s,"GGA,%d+%.%d+,(%d+%.%d+),([NS]),(%d+%.%d+),([EW]),(%d),(%d+),([%d%.]*),(.*),M,(.*),M")
        if (gpsFind=="1" or gpsFind=="2" or gpsFind=="4") and altd then
            fixed = true
            altitude = altd
            latitudeType,longitudeType,latitude,longitude = latTyp,lngTyp,lat,lng
            usedSateCnt = locSateCnt
            Ggalng,Ggalat = (lngTyp=="W" and "-" or "")..lng,(latTyp=="S" and "-" or "")..lat
            Sep = sep
        else
            fixed = false
        end
    elseif smatch(s,"RMC") then
        gpsTime,gpsFind,lat,latTyp,lng,lngTyp,spd,cog,gpsDate = smatch(s,"RMC,(%d%d%d%d%d%d)%.%d+,(%w),(%d*%.*%d*),([NS]*),(%d*%.*%d*),([EW]*),(.-),(.-),(%d%d%d%d%d%d),")
        if gpsFind=="A" and cog then
            fixed = true
            latitudeType,longitudeType,latitude,longitude = latTyp,lngTyp,lat,lng
            speed = spd
            course = cog
        else
            fixed = false
        end
        if psUtcTime and gpsFind == "A" and gpsTime and gpsDate and gpsTime ~= "" and gpsDate ~= "" then
            local yy,mm,dd,h,m,s = tonumber(ssub(gpsDate,5,6)),tonumber(ssub(gpsDate,3,4)),tonumber(ssub(gpsDate,1,2)),tonumber(ssub(gpsTime,1,2)),tonumber(ssub(gpsTime,3,4)),tonumber(ssub(gpsTime,5,6))
            UtcTime = {year=2000+yy,month=mm,day=dd,hour=h,min=m,sec=s}
        end
    elseif smatch(s,"GPGSV") then
        viewedGpsSateCnt = tonumber(smatch(s,"%d+,%d+,(%d+)") or "0")
        if psGsv then getstrength(s) end
    elseif smatch(s,"BDGSV") then
        viewedBdSateCnt = tonumber(smatch(s,"%d+,%d+,(%d+)") or "0")
		if psGsv then getstrength(s) end
    elseif smatch(s,"GSA") then
        if psSn then
            local satesn = smatch(s,"GSA,%w*,%d*,(%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,)") or ""
            if slen(satesn) > 0 and smatch(satesn,"%d+,") then
                SateSn = satesn
            end
        end
    end
    
    if filterSeconds>0 and fixed and not fixFlag and not filteredFlag then
        if not sys.timerIsActive(filterTimerFnc) then
            log.info("gps.filterTimerFnc begin")
            sys.publish("GPS_STATE","LOCATION_FILTER")
            sys.timerStart(filterTimerFnc,filterSeconds*1000)
        end        
        return
    end

    --定位成功
    if fixed then
        if not fixFlag then
            fixFlag,filteredFlag = true,true
            fixFailCnt = 0
            sys.publish("GPS_STATE","LOCATION_SUCCESS")
        end
    elseif fixed==false then
        if fixFlag then
            fixFailCnt = fixFailCnt+1
            if fixFailCnt>=20 then
                fixFlag,filteredFlag = false
                sys.timerStop(filterTimerFnc)
                sys.publish("GPS_STATE","LOCATION_FAIL")
            end
        end
    end
end

local function taskRead()
    local cacheData = ""
    local co = coroutine.running()
    while true do
        local s = uart.read(uartID, "*l")
        if s == "" then
            uart.on(uartID,"receive",function() coroutine.resume(co) end)
            coroutine.yield()
            uart.on(uartID,"receive")
        else
            cacheData = cacheData..s
            local d1,d2,nemaStr = sfind(cacheData,"\r\n")
            while d1 do
                writePendingCmds()
                nemaStr = ssub(cacheData,1,d2)
                cacheData = ssub(cacheData,d2+1,-1)

                if nmeaMode==0 or nmeaMode==2 then
                    --解析一行NEMA数据
                    parseNmea(nemaStr)
                end
                if (nmeaMode==1 or nmeaMode==2) and nmeaCbFnc then
                    nmeaCbFnc(nemaStr)
                end
                d1,d2 = sfind(cacheData,"\r\n")
            end
        end
    end
end

-- GPS串口写命令操作
-- @string cmd，GPS指令(cmd格式："$PGKC149,1,115200*"或者"$PGKC149,1,115200*XX\r\n")
-- @bool isFull，cmd是否为完整的指令格式，包括校验和以及\r\n；true表示完整，false或者nil为不完整
-- @return nil
-- @usage gps.writeCmd(cmd)
function writeCmd(cmd,isFull)
    local tmp = cmd
    if not isFull then
        tmp = 0
        for i=2,cmd:len()-1 do
            tmp = bit.bxor(tmp,cmd:byte(i))
        end
        tmp = cmd..(string.format("%02X",tmp)):upper().."\r\n"
    end
    uart.write(uartID,tmp)
    log.info("gps.writecmd",tmp)
    --log.info("gps.writecmd",tmp:toHex())
end

function writePendingCmds()
    if not aerialModeSetted and aerialModeStr~="" then writeCmd(aerialModeStr) aerialModeSetted=true end
    if not runModeSetted and runModeStr~="" then writeCmd(runModeStr) runModeSetted=true end
    if not nmeaReportSetted and nmeaReportStr~="" then writeCmd(nmeaReportStr) nmeaReportSetted=true end
    if not nmeaReportFreqSetted and nmeaReportFreqStr~="" then writeCmd(nmeaReportFreqStr) nmeaReportFreqSetted=true end
end

local function _open()
    if openFlag then return end
    pm.wake("gps.lua")
    uart.setup(uartID,uartBaudrate,uartDatabits,uartParity,uartStopbits)
    sys.taskInit(taskRead)
    if powerCbFnc then
        powerCbFnc(true)
    else
        pmd.ldoset(7,pmd.LDO_VCAM)
        rtos.sys32k_clk_out(1)
    end
    openFlag = true
    sys.publish("GPS_STATE","OPEN")
    fixFlag,filteredFlag = false
    Ggalng,Ggalat,Gsv,Sep = "","",""    
    log.info("gps._open")
end

local function _close()
    if not openFlag then return end
    if powerCbFnc then
        powerCbFnc(false)
    else
        pmd.ldoset(0,pmd.LDO_VCAM)
        rtos.sys32k_clk_out(0)
    end
    uart.close(uartID)
    pm.sleep("gps.lua")
    openFlag = false
    sys.publish("GPS_STATE","CLOSE",fixFlag)
    fixFlag,filteredFlag = false
    sys.timerStop(filterTimerFnc)
    Ggalng,Ggalat,Gsv,Sep = "","",""
    aerialModeSetted,runModeSetted,nmeaReportSetted,nmeaReportFreqSetted = nil
    log.info("gps._close")
end


--- GPS应用模式1.
--
-- 打开GPS后，GPS定位成功时，如果有回调函数，会调用回调函数
--
-- 使用此应用模式调用gps.open打开的“GPS应用”，必须主动调用gps.close或者gps.closeAll才能关闭此“GPS应用”,主动关闭时，即使有回调函数，也不会调用回调函数
DEFAULT = 1
--- GPS应用模式2.
--
-- 打开GPS后，如果在GPS开启最大时长到达时，没有定位成功，如果有回调函数，会调用回调函数，然后自动关闭此“GPS应用”
--
-- 打开GPS后，如果在GPS开启最大时长内，定位成功，如果有回调函数，会调用回调函数，然后自动关闭此“GPS应用”
--
-- 打开GPS后，在自动关闭此“GPS应用”前，可以调用gps.close或者gps.closeAll主动关闭此“GPS应用”，主动关闭时，即使有回调函数，也不会调用回调函数
TIMERORSUC = 2
--- GPS应用模式3.
--
-- 打开GPS后，在GPS开启最大时长时间到达时，无论是否定位成功，如果有回调函数，会调用回调函数，然后自动关闭此“GPS应用”
--
-- 打开GPS后，在自动关闭此“GPS应用”前，可以调用gps.close或者gps.closeAll主动关闭此“GPS应用”，主动关闭时，即使有回调函数，也不会调用回调函数
TIMER = 3

--“GPS应用”表
local tList = {}

--[[
函数名：delItem
功能  ：从“GPS应用”表中删除一项“GPS应用”，并不是真正的删除，只是设置一个无效标志
参数  ：
        mode：GPS应用模式
        para：
            para.tag：“GPS应用”标记
            para.val：GPS开启最大时长
            para.cb：回调函数
返回值：无
]]
local function delItem(mode,para)
    for i=1,#tList do
        --标志有效 并且 GPS应用模式相同 并且 “GPS应用”标记相同
        if tList[i].flag and tList[i].mode==mode and tList[i].para.tag==para.tag then
            --设置无效标志
            tList[i].flag,tList[i].delay = false
            break
        end
    end
end

--[[
函数名：addItem
功能  ：新增一项“GPS应用”到“GPS应用”表
参数  ：
        mode：GPS应用模式
        para：
            para.tag：“GPS应用”标记
            para.val：GPS开启最大时长
            para.cb：回调函数
返回值：无
]]
local function addItem(mode,para)
    --删除相同的“GPS应用”
    delItem(mode,para)
    local item,i,fnd = {flag=true, mode=mode, para=para}
    --如果是TIMERORSUC或者TIMER模式，初始化GPS工作剩余时间
    if mode==TIMERORSUC or mode==TIMER then item.para.remain = para.val end
    for i=1,#tList do
        --如果存在无效的“GPS应用”项，直接使用此位置
        if not tList[i].flag then
            tList[i] = item
            fnd = true
            break
        end
    end
    --新增一项
    if not fnd then table.insert(tList,item) end
end

local function existTimerItem()
    for i=1,#tList do
        if tList[i].flag and (tList[i].mode==TIMERORSUC or tList[i].mode==TIMER or tList[i].para.delay) then return true end
    end
end

local function timerFnc()
    for i=1,#tList do
        if tList[i].flag then
            log.info("gps.timerFnc@"..i,tList[i].mode,tList[i].para.tag,tList[i].para.val,tList[i].para.remain,tList[i].para.delay)
            local rmn,dly,md,cb = tList[i].para.remain,tList[i].para.delay,tList[i].mode,tList[i].para.cb

            if rmn and rmn>0 then
                tList[i].para.remain = rmn-1
            end
            if dly and dly>0 then
                tList[i].para.delay = dly-1
            end
            rmn = tList[i].para.remain

            if isFix() and md==TIMER and rmn==0 and not tList[i].para.delay then
                tList[i].para.delay = 1
            end

            dly = tList[i].para.delay
            if isFix() then
                if dly and dly==0 then
                    if cb then cb(tList[i].para.tag) end
                    if md == DEFAULT then
                        tList[i].para.delay = nil
                    else
                        close(md,tList[i].para)
                    end
                end
            else
                if rmn and rmn == 0 then
                    if cb then cb(tList[i].para.tag) end
                    close(md,tList[i].para)
                end
            end
        end
    end
    if existTimerItem() then sys.timerStart(timerFnc,1000) end
end

--[[
函数名：statInd
功能  ：处理GPS定位成功的消息
参数  ：
        evt：GPS消息类型
返回值：无
]]
local function statInd(evt)
    --定位成功的消息
    if evt == "LOCATION_SUCCESS" then
        for i=1,#tList do
            log.info("gps.statInd@"..i,tList[i].flag,tList[i].mode,tList[i].para.tag,tList[i].para.val,tList[i].para.remain,tList[i].para.delay,tList[i].para.cb)
            if tList[i].flag then
                if tList[i].mode ~= TIMER then
                    tList[i].para.delay = 1
                    if tList[i].mode == DEFAULT then
                        if existTimerItem() then sys.timerStart(timerFnc,1000) end
                    end
                end
            end
        end
    end
end

--- 打开一个“GPS应用”
-- “GPS应用”：指的是使用GPS功能的一个应用
-- 例如，假设有如下3种需求，要打开GPS，则一共有3个“GPS应用”：
-- “GPS应用1”：每隔1分钟打开一次GPS
-- “GPS应用2”：设备发生震动时打开GPS
-- “GPS应用3”：收到一条特殊短信时打开GPS
-- 只有所有“GPS应用”都关闭了，才会去真正关闭GPS
-- 每个“GPS应用”打开或者关闭GPS时，最多有4个参数，其中 GPS应用模式和GPS应用标记 共同决定了一个唯一的“GPS应用”：
-- 1、GPS应用模式(必选)
-- 2、GPS应用标记(必选)
-- 3、GPS开启最大时长[可选]
-- 4、回调函数[可选]
-- 例如gps.open(gps.TIMERORSUC,{tag="TEST",val=120,cb=testGpsCb})
-- gps.TIMERORSUC为GPS应用模式，"TEST"为GPS应用标记，120秒为GPS开启最大时长，testGpsCb为回调函数
-- @number mode，GPS应用模式，支持gps.DEFAULT，gps.TIMERORSUC，gps.TIMER三种
-- @param para，table类型，GPS应用参数
--               para.tag：string类型，GPS应用标记
--               para.val：number类型，GPS应用开启最大时长，mode参数为gps.TIMERORSUC或者gps.TIMER时，此值才有意义
--               para.cb：GPS应用结束时的回调函数，回调函数的调用形式为para.cb(para.tag)
-- @return nil
-- @usage gps.open(gps.DEFAULT,{tag="TEST1",cb=test1Cb})
-- @usage gps.open(gps.TIMERORSUC,{tag="TEST2",val=60,cb=test2Cb})
-- @usage gps.open(gps.TIMER,{tag="TEST3",val=120,cb=test3Cb})
-- @see DEFAULT,TIMERORSUC,TIMER
function open(mode,para)
    assert((para and type(para) == "table" and para.tag and type(para.tag) == "string"),"gps.open para invalid")
    log.info("gps.open",mode,para.tag,para.val,para.cb)
    --如果GPS定位成功
    if isFix() then
        if mode~=TIMER then
            --执行回调函数
            if para.cb then para.cb(para.tag) end
            if mode==TIMERORSUC then return end
        end
    end
    addItem(mode,para)
    --真正去打开GPS
    _open()
    --启动1秒的定时器
    if existTimerItem() and not sys.timerIsActive(timerFnc) then
        sys.timerStart(timerFnc,1000)
    end
end

--- 关闭一个“GPS应用”
-- 只是从逻辑上关闭一个GPS应用，并不一定真正关闭GPS，是有所有的GPS应用都处于关闭状态，才回去真正关闭GPS
-- @number mode，GPS应用模式，支持gps.DEFAULT，gps.TIMERORSUC，gps.TIMER三种
-- @param para，table类型，GPS应用参数
--               para.tag：string类型，GPS应用标记
--               para.val：number类型，GPS应用开启最大时长，mode参数为gps.TIMERORSUC或者gps.TIMER时，此值才有意义；使用close接口时，不需要传入此参数
--               para.cb：GPS应用结束时的回调函数，回调函数的调用形式为para.cb(para.tag)；使用close接口时，不需要传入此参数
-- @return nil
-- @usage GPS应用模式和GPS应用标记唯一确定一个“GPS应用”，调用本接口关闭时，mode和para.tag要和gps.open打开一个“GPS应用”时传入的mode和para.tag保持一致
-- @usage gps.close(gps.DEFAULT,{tag="TEST1"})
-- @usage gps.close(gps.TIMERORSUC,{tag="TEST2"})
-- @usage gps.close(gps.TIMER,{tag="TEST3"})
-- @see open,DEFAULT,TIMERORSUC,TIMER
function close(mode,para)
    assert((para and type(para)=="table" and para.tag and type(para.tag)=="string"),"gps.close para invalid")
    log.info("gps.close",mode,para.tag,para.val,para.cb)
    --删除此“GPS应用”
    delItem(mode,para)
    local valid,i
    for i=1,#tList do
        if tList[i].flag then
            valid = true
        end
    end
    --如果没有一个“GPS应用”有效，则关闭GPS
    if not valid then _close() end
end

--- 关闭所有“GPS应用”
-- @return nil
-- @usage gps.closeAll()
-- @see open,DEFAULT,TIMERORSUC,TIMER
function closeAll()
    for i=1,#tList do
        if tList[i].flag and tList[i].para.cb then tList[i].para.cb(tList[i].para.tag) end
        close(tList[i].mode,tList[i].para)
    end
end

--- 判断一个“GPS应用”是否处于激活状态
-- @number mode，GPS应用模式，支持gps.DEFAULT，gps.TIMERORSUC，gps.TIMER三种
-- @param para，table类型，GPS应用参数
--               para.tag：string类型，GPS应用标记
--               para.val：number类型，GPS应用开启最大时长，mode参数为gps.TIMERORSUC或者gps.TIMER时，此值才有意义；使用isActive接口时，不需要传入此参数
--               para.cb：GPS应用结束时的回调函数，回调函数的调用形式为para.cb(para.tag)；使用isActive接口时，不需要传入此参数
-- @return bool result，处于激活状态返回true，否则返回nil
-- @usage GPS应用模式和GPS应用标记唯一确定一个“GPS应用”，调用本接口查询状态时，mode和para.tag要和gps.open打开一个“GPS应用”时传入的mode和para.tag保持一致
-- @usage gps.isActive(gps.DEFAULT,{tag="TEST1"})
-- @usage gps.isActive(gps.TIMERORSUC,{tag="TEST2"})
-- @usage gps.isActive(gps.TIMER,{tag="TEST3"})
-- @see open,DEFAULT,TIMERORSUC,TIMER
function isActive(mode,para)
    assert((para and type(para)=="table" and para.tag and type(para.tag)=="string"),"gps.isActive para invalid")
    for i=1,#tList do
        if tList[i].flag and tList[i].mode==mode and tList[i].para.tag==para.tag then return true end
    end
end

--- 设置GPS模块供电控制的回调函数
-- 如果使用的是Air800，或者供电控制使用的是LDO_VCAM，则打开GPS应用前不需要调用此接口进行设置
-- 否则在调用gps.open前，使用此接口，传入自定义的供电控制函数cbFnc，GPS开启时，gps.lua自动执行cbFnc(true)，GPS关闭时，gps.lua自动执行cbFnc(false)
-- @param cbFnc，function类型，用户自定义的GPS供电控制函数
-- @return nil
-- @usage gps.setPowerCbFnc(cbFnc)
function setPowerCbFnc(cbFnc)
    powerCbFnc = cbFnc
end

--- 设置GPS模块和GSM模块之间数据通信的串口参数
-- 如果使用的是Air800，或者使用的UART2(波特率115200，数据位8，无检验位，停止位1)，则打开GPS应用前不需要调用此接口进行设置
-- 否则在调用gps.open前，使用此接口，传入UART参数
-- @number id，UART ID，支持1和2，1表示UART1，2表示UART2
-- @number baudrate，波特率，支持1200,2400,4800,9600,10400,14400,19200,28800,38400,57600,76800,115200,230400,460800,576000,921600,1152000,4000000
-- @number databits，数据位，支持7,8
-- @number parity，校验位，支持uart.PAR_NONE,uart.PAR_EVEN,uart.PAR_ODD
-- @number stopbits，停止位，支持uart.STOP_1,uart.STOP_2
-- @return nil
-- @usage gps.setUart(2,115200,8,uart.PAR_NONE,uart.STOP_1)
function setUart(id,baudrate,databits,parity,stopbits)
    uartID,uartBaudrate,uartDatabits,uartParity,uartStopbits = id,baudrate,databits,parity,stopbits
end

--- 设置GPS模块搜星模式.
-- 如果使用的是Air800或者Air530，不调用此接口配置，则默认同时开启GPS和北斗定位
-- @number gps，GPS定位系统，1是打开，0是关闭
-- @number beidou，中国北斗定位系统，1是打开，0是关闭
-- @number glonass，俄罗斯Glonass定位系统，1是打开，0是关闭
-- @number galieo，欧盟伽利略定位系统，1是打开，0是关闭
-- @return nil
-- @usage gps.setAeriaMode(1,1,0,0)
function setAerialMode(gps,beidou,glonass,galieo)
    local gps = gps or 0
    local glonass = glonass or 0
    local beidou = beidou or 0
    local galieo = galieo or 0
    if gps+glonass+beidou+galieo == 0 then gps=1 beidou=1 end
    local tmpStr = "$PGKC115,"..gps..","..glonass..","..beidou..","..galieo.."*"
    if tmpStr~=aerialModeStr then
        aerialModeStr,aerialModeSetted = tmpStr
    end
end


--- 设置NMEA数据处理模式.
-- 如果不调用此接口配置，则默认仅gps.lua内部处理NMEA数据
-- @number mode，NMEA数据处理模式，0表示仅gps.lua内部处理，1表示仅用户自己处理，2表示gps.lua和用户同时处理
-- @param cbFnc，function类型，用户处理一条NMEA数据的回调函数，mode为1和2时，此值才有意义
-- @return nil
-- @usage gps.setNmeaMode(0)
-- @usage gps.setNmeaMode(1,cbFnc)
-- @usage gps.setNmeaMode(2,cbFnc)
function setNmeaMode(mode,cbFnc)
    nmeaMode,nmeaCbFnc = mode,cbFnc
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
-- @number runTm，单位毫秒，mode为0时表示NEMA数据的上报间隔，mode为1或者2时表示运行时长，其余mode时此值无意义
-- @number sleepTm，单位毫秒，mode为1或者2时表示运行时长，其余mode时此值无意义
-- @return nil
-- @usage gps.setRunMode(0,1000)
-- @usage gps.setRunMode(1,5000,2000)
function setRunMode(mode,runTm,sleepTm)
    local rt,st = runTm or "",sleepTm or ""
    if mode==0 and rt then
        if rt>10000 then rt=10000 end
        if rt<200 then rt=200 end
        nmeaReportStr = "$PGKC101,"..rt.."*"
    end

    local tmpStr = "$PGKC105,"..mode..((mode==1 or mode==2) and (","..rt..","..st) or "").."*"
    if tmpStr~=runModeStr then
        runModeStr,runModeSetted = tmpStr
    end
end

--- 设置NEMA语句的输出频率.
-- @number[opt=1] rmc，单位秒，RMC语句输出频率，取值范围0到10之间的整数，0表示不输出
-- @number[opt=1] gga，单位秒，GGA语句输出频率，取值范围0到10之间的整数，0表示不输出
-- @number[opt=1] gsa，单位秒，GSA语句输出频率，取值范围0到10之间的整数，0表示不输出
-- @number[opt=1] gsv，单位秒，GSV语句输出频率，取值范围0到10之间的整数，0表示不输出
-- @number[opt=1] vtg，单位秒，VTG语句输出频率，取值范围0到10之间的整数，0表示不输出
-- @number[opt=0] gll，单位秒，GLL语句输出频率，取值范围0到10之间的整数，0表示不输出
-- @return nil
-- @usage gps.setNemaReportFreq(5,0,0,0,0,0)
function setNemaReportFreq(rmc,gga,gsa,gsv,vtg,gll)
    local tmpStr = "$PGKC242,"..(gll or 0)..","..(rmc or 1)..","..(vtg or 1)..","..(gga or 1)..","..(gsa or 1)..","..(gsv or 1)..",0,0,0,0,0,0,0,0,0,0,0,0,0".."*"
    if tmpStr~=nmeaReportFreqStr then
        nmeaReportFreqStr,nmeaReportFreqSetted = tmpStr
    end
end

--- 设置GPS定位成功后经纬度的过滤时间.
-- @number[opt=0] seconds，单位秒，GPS定位成功后，丢弃前seconds秒的位置信息
-- @return nil
-- @usage gps.setLocationFilter(2)
function setLocationFilter(seconds)
    filterSeconds = seconds or 0
end

function setFastFix(lat,lng,tm)
    local t = tm.year..","..tm.month..","..tm.day..","..tm.hour..","..tm.min..","..tm.sec.."*"
    log.info("gps.setFastFix",lat,lng,t)
    writeCmd("$PGKC634,"..t)
    writeCmd("$PGKC635,"..lat..","..lng..",0,"..t)
end

--- 获取GPS模块是否处于开启状态
-- @return bool result，true表示开启状态，false或者nil表示关闭状态
-- @usage gps.isOpen()
function isOpen()
    return openFlag
end

--- 获取GPS模块是否定位成功
-- @return bool result，true表示定位成功，false或者nil表示定位失败
-- @usage gps.isFix()
function isFix()
    return fixFlag
end

-- 度分格式转换为度格式
-- @string inStr，度分格式的位置
-- @return string，度格式的位置
-- @usage degreeMinuteToDegree("3114.50931")--->"31.2418218"，31度14.50931分转换为31.2418218度
-- @usage degreeMinuteToDegree("12128.44954")--->"121.4741590"，121度28.44954分转换为121.4741590度
local function degreeMinuteToDegree(inStr)
    local integer,fraction = smatch(inStr,"(%d+)%.(%d+)")
    if integer and fraction then
        local intLen = slen(integer)
        if intLen~=4 and intLen~=5 then log.error("gps.degreeMinuteToDegree integer error",inStr) return "" end
        if slen(fraction)<5 then fraction = fraction..srep("0",5-slen(fraction)) end
        fraction = ssub(fraction,1,5)
        local temp = tonumber(ssub(integer,intLen-1,intLen)..fraction)*10
        fraction = tostring((temp-(temp%6))/6)
        local fracLen = slen(fraction)
        if fracLen>7 then
            fraction = ssub(fraction,1,7)
        elseif fracLen<7 then
            fraction = srep("0",7-fracLen)..fraction
        end
        return ssub(integer,1,intLen-2).."."..fraction
    end

    return ""
end

--- 获取度格式的经纬度信息
-- @string[opt=nil] typ，返回的经纬度格式，typ为"DEGREE_MINUTE"时表示返回度分格式，其余表示返回度格式
-- @return table location
-- 例如typ为"DEGREE_MINUTE"时返回{lngType="E",lng="12128.44954",latType="N",lat="3114.50931"}
-- 例如typ不是"DEGREE_MINUTE"时返回{lngType="E",lng="121.123456",latType="N",lat="31.123456"}
-- lngType：string类型，表示经度类型，取值"E"，"W"
-- lng：string类型，表示度格式的经度值，无效时为""
-- latType：string类型，表示纬度类型，取值"N"，"S"
-- lat：string类型，表示度格式的纬度值，无效时为""
-- @usage gps.getLocation()
function getLocation(typ)
    return {
            lngType=longitudeType,
            lng=isFix() and (typ=="DEGREE_MINUTE" and longitude or degreeMinuteToDegree(longitude)) or "",
            latType=latitudeType,
            lat=isFix() and (typ=="DEGREE_MINUTE" and latitude or degreeMinuteToDegree(latitude)) or ""
         }
end

function getLastLocation(typ)
    if typ=="DEGREE_MINUTE" then
        return {
            lngType=longitudeType,
            lng=longitude,
            latType=latitudeType,
            lat=latitude
         }
    else
        return (longitude and longitude~="") and degreeMinuteToDegree(longitude) or "", (latitude and latitude~="") and degreeMinuteToDegree(latitude) or ""
    end
end

--- 获取海拔
-- @return number altitude，海拔，单位米
-- @usage gps.getAltitude()
function getAltitude()
    return tonumber(smatch(altitude,"(%d+)") or "0")
end

--- 获取速度
-- @return number kmSpeed，第一个返回值为公里每小时的速度
-- @return number nmSpeed，第二个返回值为海里每小时的速度
-- @usage gps.getSpeed()
function getSpeed()
    local integer = tonumber(smatch(speed,"(%d+)") or "0")
    return (integer*1852 - (integer*1852 %1000))/1000,integer
end

--- 获取原始速度,字符串带浮点
-- @return number speed 海里每小时的速度
-- @usage gps.getOrgSpeed()
function getOrgSpeed()
    return speed
end

--- 获取方向角
-- @return number course，方向角
-- @usage gps.getCourse()
function getCourse()
    return tonumber(smatch(course,"(%d+)") or "0")
end

-- 获取所有可见卫星的最大信号强度
-- @return number strength，最大信号强度
-- @usage gps.getMaxSignalStrength()
function getMaxSignalStrength()
    return maxSignalStrength
end

--- 获取可见卫星的个数
-- @return number count，可见卫星的个数
-- @usage gps.getViewedSateCnt()
function getViewedSateCnt()
    return tonumber(viewedGpsSateCnt)+tonumber(viewedBdSateCnt)
end

--- 获取定位使用的卫星个数
-- @return number count，定位使用的卫星个数
-- @usage gps.getUsedSateCnt()
function getUsedSateCnt()
    return tonumber(usedSateCnt)
end

--- 获取GGA语句中度分格式的经纬度信息
-- @return string lng，度分格式的经度值(dddmm.mmmm)，西经会添加一个-前缀，无效时为""；例如"12112.3456"表示东经121度12.3456分，"-12112.3456"表示西经121度12.3456分
-- @return string lat，度分格式的纬度值(ddmm.mmmm)，南纬会添加一个-前缀，无效时为""；例如"3112.3456"表示北纬31度12.3456分，"-3112.3456"表示南纬31度12.3456分
-- @usage gps.getGgaloc()
function getGgaloc()
	return Ggalng or "",Ggalat or ""
end

--- 获取RMC语句中的UTC时间
-- 只有同时满足如下两个条件，返回值才有效
-- 1、开启了GPS，并且定位成功
-- 2、调用setParseItem接口，第一个参数设置为true
-- @return table utcTime，UTC时间，nil表示无效，例如{year=2018,month=4,day=24,hour=11,min=52,sec=10}
-- @usage gps.getUtcTime()
function getUtcTime()
	return UtcTime
end

--- 获取定位使用的大地高
-- @return number sep，大地高
-- @usage gps.getSep()
function getSep()
	return tonumber(Sep or "0")
end

--- 获取GSA语句中的可见卫星号
-- 只有同时满足如下两个条件，返回值才有效
-- 1、开启了GPS，并且定位成功
-- 2、调用setParseItem接口，第三个参数设置为true
-- @return string viewedSateId，可用卫星号，""表示无效
-- @usage gps.getSateSn()
function getSateSn()
	return SateSn or ""
end

--- 获取GSV语句中的可见卫星的信噪比
-- 只有同时满足如下两个条件，返回值才有效
-- 1、开启了GPS，并且定位成功
-- 2、调用setParseItem接口，第二个参数设置为true
-- @return string gsv，信噪比
-- @usage gps.getGsv()
function getGsv()
	return Gsv or ""
end

--- 设置是否需要解析的字段
-- @bool[opt=nil] utcTime，是否解析RMC语句中的UTC时间，true表示解析，false或者nil不解析
-- @bool[opt=nil] gsv，是否解析GSV语句，true表示解析，false或者nil不解析
-- @bool[opt=nil] gsaId，是否解析GSA语句中的卫星ID，true表示解析，false或者nil不解析
-- @usage gps.setParseItem(true,true,true)
function setParseItem(utcTime,gsv,gsaId)
    psUtcTime,psGsv,psSn = utcTime,gsv,gsaId
end

sys.subscribe("GPS_STATE",statInd)
