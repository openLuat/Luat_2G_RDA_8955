--- 模块功能：MQTT客户端数据发送处理
-- @author openLuat
-- @module default.linkOutMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.20


module(...,package.seeall)

local lpack = require"pack"
local ssub,schar,smatch,sbyte,slen,sgmatch,sgsub,srep = string.sub,string.char,string.match,string.byte,string.len,string.gmatch,string.gsub,string.rep

local function nmeaCb(nmeaItem)
    log.info("linkoutMsg.nmeaCb",nmeaItem)
end

--是否支持gps
local gpsSupport = (_G.MODULE_TYPE=="Air8XX")
if gpsSupport then
    require"agps"
    require"gps"
    gps.setNmeaMode(2,nmeaCb)
    gps.open(gps.DEFAULT,{tag="linkair"})
end

--数据发送的消息队列
local msgQuene = {}

local function enTopic(t)
    return "/v1/device/"..misc.getImei().."/"..t
end

local function insertMsg(topic,payload,qos,user)
    table.insert(msgQuene,{t=topic,p=payload,q=qos,user=user})
end

local function enCellInfoExt()
    local info,ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = net.getCellInfoExt(),"",{}
    log.info("linkOutMsg.enCellInfoExt",info)
    for mcc,mnc,lac,ci,rssi in sgmatch(info,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
        mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
        local handle = nil
        for k,v in pairs(t) do
            if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
                if #v.rssici < 8 then
                    table.insert(v.rssici,{rssi=rssi,ci=ci})
                end
                handle = true
                break
            end
        end
        if not handle then
            table.insert(t,{mcc=mcc,mnc=mnc,lac=lac,rssici={{rssi=rssi,ci=ci}}})
        end
    end
    for k,v in pairs(t) do
        ret = ret .. lpack.pack(">HHb",v.lac,v.mcc,v.mnc)
        for m,n in pairs(v.rssici) do
            cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
            ret = ret .. lpack.pack(">bH",cntrssi,n.ci)
        end
    end

    return schar(#t)..ret
end

local function getStatus()
    local t = {}

    t.shake = 0
    t.charger = 0
    t.acc = 0
    t.gps = gpsSupport and 1 or 0
    t.sleep = 0
    t.volt = misc.getVbatt()
    t.fly = 0
    t.poweroff = 0
    t.poweroffreason = 0
    return t
end

local function getGps()
    local t = gps.getLocation()
    if gpsSupport then
        t.fix = gps.isFix()
        t.cog = gps.getCourse()
        t.spd = gps.getSpeed()
    end
    return t
end

local function getGpsStat()
    local t = {}
    if gpsSupport then
        t.satenum = gps.getViewedSateCnt()
    end
    return t
end

local function enStat()    
    local stat = getStatus()
    local rssi = net.getRssi()
    local gpstat = getGpsStat()
    local satenum = gpstat.satenum or 0

    local n1 = stat.shake + stat.charger*2 + stat.acc*4 + stat.gps*8 + stat.sleep*16+stat.fly*32+stat.poweroff*64
    rssi = rssi > 31 and 31 or rssi
    satenum = satenum > 7 and 7 or satenum
    local n2 = rssi + satenum*32
    return lpack.pack(">bbH",n1,n2,stat.volt)
end

local function bcd(d,n)
    local l = slen(d or "")
    local num
    local t = {}

    for i=1,l,2 do
        num = tonumber(ssub(d,i,i+1),16)

        if i == l then
            num = 0xf0+num
        else
            num = (num%0x10)*0x10 + (num-(num%0x10))/0x10
        end

        table.insert(t,num)
    end

    local s = schar(_G.unpack(t))

    l = slen(s)

    if l < n then
        s = s .. srep("\255",n-l)
    elseif l > n then
        s = ssub(s,1,n)
    end

    return s
end

local function enLnLa(v,s)
    if not v then return string.fromHex("FFFFFFFFFF") end
    
    local v1,v2 = smatch(s,"(%d+)%.(%d+)")

    if slen(v1) < 3 then v1 = srep("0",3-slen(v1)) .. v1 end

    return bcd(v1..v2,5)
end

local function locReport()
    local payload
    if gpsSupport then
        local t = getGps()
        lng = enLnLa(t.fix,t.lng)
        lat = enLnLa(t.fix,t.lat)
        payload = lpack.pack(">bAAHbAbA",7,lng,lat,t.cog,t.spd,enCellInfoExt(),net.getTa(),enStat())
    else
        payload = lpack.pack(">bAbA",5,enCellInfoExt(),net.getTa(),enStat())
    end
    insertMsg(enTopic("devdata"),payload,0)
    sys.timerStart(locReport,60*1000)
end

--- 初始化“MQTT客户端数据发送”
-- @return 无
-- @usage linkOutMsg.init()
function init()
    local payload = lpack.pack(">bbHHbHHbHAbHbbHAbHAbHA",
                        14,
                        0,2,22,
                        1,2,300,
                        2,2,bcd(sgsub(_G.VERSION,"%.",""),2),
                        3,1,gpsSupport and 1 or 0,
                        4,slen(sim.getIccid()),sim.getIccid(),
                        8,slen(_G.PROJECT),_G.PROJECT,
                        13,slen(sim.getImsi()),sim.getImsi())
    insertMsg(enTopic("devdata"),payload,0)
    locReport()
end

--- 去初始化“MQTT客户端数据发送”
-- @return 无
-- @usage linkOutMsg.unInit()
function unInit()
    sys.timerStop(locReport)
    while #msgQuene>0 do
        local outMsg = table.remove(msgQuene,1)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(false,outMsg.user.para) end
    end
end

--- MQTT客户端是否有数据等待发送
-- @return 有数据等待发送返回true，否则返回false
-- @usage linkOutMsg.waitForSend()
function waitForSend()
    return #msgQuene > 0
end

--- MQTT客户端数据发送处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage linkOutMsg.proc(mqttClient)
function proc(mqttClient)
    while #msgQuene>0 do
        local outMsg = table.remove(msgQuene,1)
        local result = mqttClient:publish(outMsg.t,outMsg.p,outMsg.q)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(result,outMsg.user.para) end
        if not result then return end
    end
    return true
end
