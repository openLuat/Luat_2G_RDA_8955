--- 模块功能：GPS辅助定位以及星历更新服务
-- @module agps
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.26

require"http"
require"lbsLoc"
require"net"
require"gps"
module(..., package.seeall)

local EPH_TIME_FILE = "/ephTime.txt"
local writeEphIdx,sEphData,writeEphSta = 0
local EPH_UPDATE_INTERVAL = 4*3600

local function runTimer()
    sys.timerStart(updateEph,EPH_UPDATE_INTERVAL*1000)
end

local function writeEphEnd()
    log.info("agps.writeEphEnd")
    gps.writeCmd(("AAF00E0095000000C20100580D0A"):fromHex(),true)
    sys.timerStart(gps.close,2000,gps.TIMER,{tag="lib.agps.lua.eph"})
    writeEphIdx,sEphData,writeEphSta = 0
end

local function writeEph()
    log.info("agps.writeEph",writeEphSta)
    if writeEphSta=="IDLE" then
        gps.writeCmd("$PGKC149,1,115200*")
        writeEphSta = "WAIT_BINARY_CMD_ACK"
    elseif writeEphSta=="WAIT_BINARY_CMD_ACK" or writeEphSta=="WAIT_WRITE_EPH_CMD_ACK" then
        if sEphData and sEphData:len()>0 then
            local hexStr = sEphData:sub(1,1024)            
            if hexStr:len()<1024 then hexStr = hexStr..("F"):rep(1024-hexStr:len()) end
            hexStr = "AAF00B026602"..string.format("%02X",writeEphIdx):upper().."00"..hexStr
            
            local checkSum = 0
            local binStr = hexStr:fromHex()
            for i=3,binStr:len() do
                checkSum = bit.bxor(checkSum,binStr:byte(i))
            end
            string.format("%02X",checkSum):upper()
            
            hexStr = hexStr..(string.format("%02X",checkSum):upper()).."0D0A"
            gps.writeCmd(hexStr:fromHex(),true)
            
            sEphData = sEphData:sub(1025,-1)
            writeEphIdx = writeEphIdx+1
            writeEphSta = "WAIT_WRITE_EPH_CMD_ACK"
        else
            gps.writeCmd(("AAF00B006602FFFF6F0D0A"):fromHex(),true)
            writeEphSta = "WAIT_WRITE_EPH_END_CMD_ACK"
        end
    elseif writeEphSta=="WAIT_WRITE_EPH_END_CMD_ACK" then
        io.writeFile(EPH_TIME_FILE,tostring(os.time()))
        writeEphEnd()
    end
end

local function writeEphBegin()
    writeEphSta = "IDLE"
    writeEph()
end

local function downloadEphCb(result,prompt,head,body)
    log.info("testHttp.cbFnc",result,prompt)
    runTimer()
    if result and body then        
        if gps.isFix() then
            io.writeFile(EPH_TIME_FILE,tostring(os.time()))
        else
            sEphData = body:toHex()
            gps.open(gps.TIMER,{tag="lib.agps.lua.eph",val=10,cb=writeEphEnd})
            sys.timerStart(writeEphBegin,2000)
            return
        end
    end
end

--连接服务器下载星历
function updateEph()
    if gps.isFix() then runTimer() return end
    http.request("GET","download.openluat.com/9501-xingli/brdcGPD.dat_rda",nil,nil,nil,20000,downloadEphCb)
end

--检查是否需要更新星历
local function checkEph()
    local result
    if not gps.isFix() then
        local file = io.open(EPH_TIME_FILE,"rb")
        if not file then return true end
        local lastTm = file:read("*a")
        if not lastTm or lastTm=="" then return true end
        log.info("agps.checkEph",os.time(),tonumber(lastTm))
        result = (os.time()-tonumber(lastTm) >= EPH_UPDATE_INTERVAL) 
    end
    if not result then runTimer() end
    return result
end

local function setFastFix(lng,lat,tm)
    gps.setFastFix(lng,lat,tm)
    if checkEph() then updateEph() end
end

--获取到基站对应的经纬度，写到GPS芯片中
local function getLocCb(result,lat,lng,addr,time)
    log.info("agps.getLocCb",result,lat,lng,time and time:len() or 0)
    
    if result==0 and not gps.isFix() then
        local tm = {year=0,month=0,day=0,hour=0,min=0,sec=0}
        if time:len()==6 then            
            tm = {year=time:byte(1)+2000,month=time:byte(2),day=time:byte(3),hour=time:byte(4),min=time:byte(5),sec=time:byte(6)}
            misc.setClock(tm)
            tm = common.timeZoneConvert(tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec,8,0)
        end
        gps.open(gps.TIMER,{tag="lib.agps.lua.fastFix",val=5})
        sys.timerStart(setFastFix,2000,lng,lat,tm)
    else
        if checkEph() then updateEph() end
    end
    
end


sys.subscribe("GPS_STATE", function(evt,para)
    log.info("agps.GPS_STATE",evt,para)
    if evt=="LOCATION_SUCCESS" or (evt=="CLOSE" and para==true) then
        runTimer()
    elseif evt=="BINARY_CMD_ACK" or evt=="WRITE_EPH_ACK" or evt=="WRITE_EPH_END_ACK" then
        writeEph()
    end
end)
sys.subscribe("IP_READY_IND", function()
    if gps.isFix() then
        runTimer()
    else
        lbsLoc.request(getLocCb,nil,30000,"0","bs.openluat.com","12412",true)
    end
end)
