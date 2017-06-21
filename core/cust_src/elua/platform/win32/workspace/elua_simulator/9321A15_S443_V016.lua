collectgarbage("setpause",110)

setmetatable(_G, {
    __newindex = function (_, n)
       error("attempt to write to undeclared variable "..n, 2)
    end,

    __index = function (_, n)
       error("attempt to read undeclared variable "..n, 2)
    end,
})

local msg = {}
local VerboPrint = true
local atcstr=""
local uartstr=""
local d1, d2

local a = {}
local c = {}
local t = {}
local ATS = {}
local cell = {}
local p = {}
local u = {}
local bat = {}
local atom = {}
local UCS2 = {}
local gps ={}
local cP = {}
local shk = {}
local ACC = {}
local s = {}
local map = {["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["0"]=0,
		      ["A"]=10,["B"]=11,["C"]=12,["D"]=13,["E"]=14,["F"]=15}
local map1 = {[1]="1",[2]="2",[3]="3",[4]="4",[5]="5",[6]="6",[7]="7",[8]="8",[9]="9",[0]="0",[10]="A",[11]="B",[12]="C",[13]="D",[14]="E",[15]="F"}


local function FileSize(f)
	local i = 0
	local file = io.open(f,"r")
	if file == nil  then
		return 0
	end
	i =  file:seek("end")
	file:close()
	return i
end

local function NewFile(f,s)
	local file
	file = io.open(f,"w")
	if file ~= nil then
		s = s or nil
		file:write(s)
		file:close()
	end
end

local function AppendFile(f,s)
	local file
	file = io.open(f,"a+")
	if file == nil  then
		print("open file fail",f)
		return
	else
		file:write(s)
	end
	file:close()
end

local function GetCurLogInd()
	local logi
	local file = io.open("/curlog","r")
	if file == nil then
		print("open curlog error")
		return nil
	end
	logi = file:read("*a")
	file:close()
	return logi
end

local function LogFileSize()
	print("logsize",FileSize("/log0"),FileSize("/log1"),GetCurLogInd())
end

local function NewLogFile()
	LogFileSize()
	NewFile("/log0", " ")
	NewFile("/log1", " ")
	NewFile("/curlog", "0")
	print("new log file succ")
end

local function LogInit()
	local file = io.open("/curlog", "r")
	if file == nil then
		NewLogFile()
		return
	end
	file:close()
end

local function SaveLog(s)
	local logind,fname
	logind = GetCurLogInd()
	if logind == nil then
		print("get curlog error")
		return
	end
	fname = "/log" .. logind
	if FileSize(fname) > 200000 then
		logind = tostring((tonumber(logind) + 1)%2)
		fname = "/log" .. logind
		NewFile(fname,"")
		NewFile("/curlog",logind)
	end
	AppendFile(fname,s.."\r\n")
end

local function OutputLog(fname)
	local fsize = FileSize(fname)
	local i, file,s1
	print("size",fname,fsize)
	file = io.open(fname,"r")
	if file == nil  then
		print("can not open file for read",fname)
		return
	end
	for i = 0,fsize,p.LogRLen do
		file:seek("set", i)
		s1 = file:read(p.LogRLen)
		print(s1)
		rtos.sleep(100)
	end
	file:close()
end

local function GetLog()
	local t1 = t.genlen
	local logind = GetCurLogInd()
	if logind == nil then
		print("get curlog error")
		return
	end
	t.genlen = 100000
	print("\r\nbegin of logfile:")
	logind = tostring((tonumber(logind) + 1)%2)
	OutputLog("/log" .. logind)
	logind = tostring((tonumber(logind) + 1)%2)
	OutputLog("/log" .. logind)
	print("r\nend of logfile.")
	t.genlen = t1
end

local function vprint(...)
	local s1=""
	local bools

	if VerboPrint == true then
		for i=1,arg.n do
			if type(arg[i]) == "boolean" then
				bools = arg[i] and "t" or "f"
				s1 = s1..bools
			elseif arg[i] ~= nil then
				s1 = s1..arg[i]
			end

			if i ~= arg.n then
				s1 = s1..","
			end
		end
		SaveLog(s1)
		print(s1)
	end
end

local function abs(v1,v2)
  if v1>v2 then
      return (v1-v2)
  else
      return (v2-v1)
  end
end

local function getlasterr()
	local f = io.open("/luaerrinfo.txt")
	if f == nil then
		print("\r\nlua: no error")
		return
	end
	local err = f:read("*a")
	f:close()
	vprint("\r\nlua.lasterr:",err)
	uart.write(uart.ATC,"AT+AMFGD=\"luaerrinfo.txt\",0\r\n")
end

local function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function SendUART1(str)
	vprint("uart1",str)
	uart.write(1, str)
end

local function SendATC(str)
	vprint("atc",str)
	uart.write(uart.ATC, str .. "\r")
end

local function hex2int(s)
	local len1 = string.len(s)
	local i = 0
	local j = 0
	local char1,char2
	local s = string.upper(s)
	for i =1,len1 do
		j = j+map[string.sub(s, i,i)]*16^(len1-i)
	end
	return j
end

local function Hexs2Str(str)
	local i,j
	local s1 = ""
	for i=1,string.len(str),2 do
	    j = hex2int(string.sub(str,i,i+1))
	    s1=s1..string.char(j)
	end
	return s1
end

local function hex2ascii(str)
	local rltstr = ""
	local len1 = string.len(str)
	local i = 1
	local val,val_l,val_h

	while i <= len1 do
       i,val = pack.unpack(str,"=b1",i)
	   val_l = bit.band(val,0x0F)
	   val_h = bit.rshift(val,4)
	   rltstr = rltstr .. map1[val_h] .. map1[val_l]
	end
	return rltstr
end

local function RestorePara()
	cP["DOMAIN"] = "device.cmmat.com:1087"  --重庆
    cP["FREQ"] = 15
	cP["PULSE"] = 120
	cP["TRACE"] = "1"
	cP["RADIUS"] = 300
	cP["PSW"] = "123456"
	cP["POF"] = "1"
	cP["POFT"] = 120
	cP["SPEED"] = "60"
	cP["VIBGPS"] = "0"
	cP["VIBCHK_X"] = 10
	cP["VIBCHK_Y"] = 2
	cP["ACCLOCK"] = "1"
	cP["ACCLT"] = 120
	cP["WAKEUP"] = "1"
	cP["WAKEUPT"] = 60
	cP["SLEEP"] = "1"
	cP["SLEEPT"] = 2
	cP["VIB"] = "1"
	cP["VIBCALL"] = "0"
	cP["SMS"] = "0"
	cP["CALLLOCK"] = "0"
	cP["CALLDISP"] = "1"
	cP["LBV"] = 3600000
	cP["VIBL"] = 0
end

local function StateInit()
	a.reg = "INIT"
	a.regque = "N"
	a.gprs = "INIT"
	a.term = "INIT"
	a.termque = "N"
end

local function TimerInit()
	t.tcp = 0
	t.tcplen = 60000
	t.gen = 1
	t.genlen = 1000
	t.statechg = 2
	t.statelen = 60000
	t.vib = 4
	t.light = 5
	t.lightlen = 600
	t.term = 6
	t.termlen = 150000
	t.gps = 7
	t.gpslen = 2000
	t.FT = 8
	t.FTlen = 1000
	t.WakeUp = 9
	t.WakeLen = cP["WAKEUPT"]*60000
	t.query = 10
	t.querylen = 30000
	t.ready = 11
	t.readylen = 30000
	t.reset = 12
	t.resetlen = 60000

	t.GpsCloseLen = 1800
	t.gprssleeplen = 54000
	t.DeepSleepLen = 86400
	t.NoNetChgSLen = 1800
	t.NoNetBatSLen = 1800
	t.checkrun = 30
	t.UARTSleepLen = 300
	t.ShakeRadius = 60
	t.CellMoveLen = 120
	t.ResetSensor = 30
	t.GSleepLen = t.gprssleeplen
end

local function CounterInit()
	c.gen = 0
	c.lt = 0
	c.gprsact = 0
	c.gps = 0
	c.GpsPrt = 180
	c.GpsRltPrt = 10
	c.gpsfind = 0
	c.moved = 0   --检查小区位移的时间，p.move时间内不再检查
	c.T2 = 0
	c.T3 = 0
	c.DeepSC = 2^30
	c.GsmLost = 1
	c.checkrun = 0
	c.GpsOpen = 0
	c.resettime = 0
	c.CellMove = 0
	c.LowSig = 0
	c.PrintC = 0
	c.ResetSensor = 0
end

local function ATSInit()
	ATS.init = "AT+CGSN;+CIMI;+VER"
	ATS.sn = "AT+WISN?"
	ATS.query = "AT+CREG?;+CENG?;+CSQ"
	ATS.ceng = "AT+CREG=2;+CNMI=2,2;+CMGF=1;+CENG=1,1;+CIPMUX=0;+CIPQSEND=0"
	ATS.csms = "AT+CNMI=2,2;+CMGF=1;+CENG=1,1"
end

local function CellInit()
	cell.t = {}
	cell.nid = {}
end

local function UpdateTime()
	p.CurTs = os.time()
	local t1 = os.date("*t",p.CurTs)
	p.time = string.format("%04d%02d%02d%02d%02d%02d", t1.year,t1.month,t1.day,t1.hour,t1.min,t1.sec)
	p.htime = string.format("%04d-%02d-%02d %02d:%02d:%02d", t1.year,t1.month,t1.day,t1.hour,t1.min,t1.sec)
end

local function pInit()
	p.queryd = 4
	p.query = 15
	p.move = 60
	p.cellmove = false
	p.gpsmove = false
	p.gpslarge = false
	p.gdata = ""
	p.IMEI = ""
	p.IMSI = ""
	p.MNC = ""
	p.MCC = ""
	p.rssi = "0"
	p.lac_int = ""
	p.ci_int = ""
	p.GsmSucc = false
	p.SOFTVERSION = ""
	p.socktype = "TCP"
	p.fconfig = "/config.txt"
	p.freset = "/reset.txt"
	p.pos = "/pos.txt"
	p.fluaup = "/luaup.txt"
	p.LogRLen = 1000
	p.gsmLt = 0
	p.gpsLt = 0
	p.htime = "2013-08-11 12:00:00"
	p.guard = "OFF"
	p.SleepC = 2^30
	p.DeepTest = 2^30
	p.stop = false
	p.statechg = false
	p.T3sleep = false
	p.UpGoing = false
	p.FTTimes = 0
	p.FTFinish = 20
	p.T5T6 = ""
	p.FirstOn = true
	p.ResetC = 0
	p.ResetSleep = 3
	p.ResetSleepLen = 30
	p.FtRlt = 0
	p.TcpTry = 0
	p.SendTry = 0
	p.TcpReset = 3
	p.SendReset = 1
	p.LowSigLen = 30
	p.LowSig = 9
	p.ExitFly = false
	p.PrevState = ""
	p.WakeReason = 0
	UpdateTime()
end

local function AtomInit()
	atom.sn = "2508010007000033"
	atom.header = "[" .. p.time .. ",1,V1.0.0,"  ..  atom.sn .. ","
	atom.PHONE="13800002222"
	atom.USER="13861511021"
end

local function LuaUpInit()
	u.server = "update.clouddatasrv.com:3000"
	u.socktype = "UDP"
	u.PrjName = "9321"
	u.SmsName = "9321s"
	u.LUAVER = "1.6"
	u.LuaPrj = ""
	u.LuaNum = 0
	u.LuaLastBytes = 0
	u.LuaLastInd = 0
	u.LuaState = 0
	u.wfLua = true
	u.UpSleepLen = 30
	u.LastUp = "20130801000000"
	u.UpType = ""
end

local function BatInit()
	bat.vol = 50
	bat.lev = 0
	bat.chg = true
	bat.lost = 0
	bat.almlen = 15
	bat.lowalmc = 0
	bat.chgalmc = 0
	bat.chgalmLen = 600
	bat.lowalmLen = 300
	bat.chgrep = false
	bat.lowrep = false
end

local function GpsInit()
	gps.open = false
	gps.latt_m = 0
	gps.longt_m = 0
	gps.lati = 0
	gps.long = 0
	gps.spd = 0
	gps.cog = 0
	gps.state = 0
	gps.find = ""
	gps.findall = false
	gps.satenum = 0
	gps.clong = 0
	gps.clat = 0
	gps.oldlong = 0
	gps.oldlat= 0
	gps.gpssn = 0
	gps.MoveAlm = false
	gps.sates = ""
end

local function ShakeInit()
	shk.count = 0
	shk.list = {}
	shk.I = 1
	shk.L = 10
	shk.shake = 2^30
	shk.PTime = 30
	shk.almc = -300
	for i = 1,shk.L do
		shk.list[i] = 0
	end
end

local function AcCInit()
	ACC.level = -1
	ACC.c = 2^30
	ACC.s = -1
	ACC.cs = 2^30
	ACC.lastoff = 2^30
end

local function getSHAKETH()
	if s.sens < 43 or s.sens > 255 then
		vprint("get SHAKe_TH error:",s.sens)
		return 0xAB
	end

	local val

	if s.sens < 128 then
		val = s.sens + 128
	else
		val = s.sens - 128
	end

	return val
end

local function sensorCheckShake()
	if not s.Inited then
		vprint("sensorINT: please init sensor first")
	end
	local regStatus = string.byte(i2c.read(s.i2c_2, 0x03, 1))
	vprint("sensor.TILT:",string.format("0x%02x",regStatus));

	if bit.isset(regStatus,7) then
		rtos.timer_start(t.vib,200)
		return true
	else
		return false
	end
end

local function initsensor()
	local sensorId
	local sensorI2CAddr = 0x4C
	local i2c_2 = s.i2c_2

	if i2c.setup(i2c_2,i2c.SLOW,sensorI2CAddr) ~= i2c.SLOW then
		vprint("i2c.setup:failed")
		return
	end

	sensorId = i2c.read(i2c_2,0x3b,1)

	vprint("sensor.id:",string.byte(sensorId))

	i2c.write(i2c_2, 0x07, 0x43)
	i2c.write(i2c_2, 0x08, 0x00)
	i2c.write(i2c_2, 0x0C, 0x01)
	i2c.write(i2c_2, 0x2B, getSHAKETH())
	i2c.write(i2c_2, 0x0B, 0x00)
	i2c.write(i2c_2, 0x31, 0x80)
	i2c.write(i2c_2, 0x06, 0xC0)
	-- always wakeup
	i2c.write(i2c_2, 0x05, 0x00)
	i2c.write(i2c_2, 0x07, 0x41)

	pio.pin.setdir(pio.INT,pio.P0_5)

	s.Inited = true

	sensorCheckShake()
end

local function configsensor(level)
    if level < 0 or level > 15 then
		vprint("levelerr:", level)
		return
	end
	local sensbase = 43
	local sensstep = (198-sensbase)/15

	s.sens = sensbase + sensstep*level

	local i2c_2 = s.i2c_2
	i2c.write(i2c_2, 0x07, 0x43)
	i2c.write(i2c_2, 0x2B, getSHAKETH())
	i2c.write(i2c_2, 0x07, 0x41)

	vprint("sens",s.sens)
end

local function SensorInit()
	s.i2c_2 = 1
	s.Inited = false
	s.sens = 43
	initsensor()
end

local function FacSet()
	cP.DESTIPPORT = "update.clouddatasrv.com:3000"
	cP.DESTIPPORT = "device.cmmat.com:1087"
	RestorePara()
	StateInit()
	TimerInit()
	CounterInit()
	ATSInit()
	CellInit()
	pInit()
	AtomInit()
	LuaUpInit()
	BatInit()
	GpsInit()
	ShakeInit()
	AcCInit()
end

local function GetLastShake()
	return	shk.list[shk.I]
end

local function tonum(val)
    if val~=nil then
       cP[val]=tonumber(cP[val])
	end
end

local function ReadTxt(f)
	local file, rt
	file = io.open(f,"r")
	if file == nil  then
		vprint("can not open file",f)
		return
	end
	rt = file:read("*a")
	vprint("config_r",rt)
	file:close()
	return rt
end

local function WriteTxt(f,v)
	local file
	file = io.open(f,"w")
	if file == nil then
		vprint("open file to write err",f)
		return
	end
	file:write(v)
	file:close()
end

local function ReadConfig()
	local config_r = ReadTxt(p.fconfig)
    local n={}
	if config_r == nil then
		vprint("read config txt err")
		return
	end
	p.FirstOn = false
	d1,d2,n["DOMAIN"],n["FREQ"],n["PULSE"],n["TRACE"],n["RADIUS"],n["PSW"],n["POF"],n["POFT"],n["SPEED"],n["VIBGPS"],
	n["VIBCHK_X"],n["VIBCHK_Y"],n["ACCLOCK"],n["ACCLT"],n["WAKEUP"],n["WAKEUPT"],n["SLEEP"],n["SLEEPT"],n["VIB"],n["VIBCALL"],
	n["SMS"],n["CALLLOCK"],n["CALLDISP"],n["LBV"],n["VIBL"] = string.find(config_r,"(.-),(%d+),(%d+),(%d),(%d+),(%d+),(%d),(%d+),(%d+),(%d),(%d+),(%d+),(%d),(%d+),(%d),(%d+),(%d),(%d+),(%d),(%d),(%d),(%d),(%d),(%d+),(%d+)")
	if n["DOMAIN"] == nil or n["VIBL"]==nil then
	   return
	end
	cP = n
	tonum("FREQ")
	tonum("PULSE")
	tonum("RADIUS")
	tonum("POFT")
	tonum("VIBCHK_X")
	tonum("VIBCHK_Y")
	tonum("ACCLT")
	tonum("WAKEUPT")
	tonum("SLEEPT")
	tonum("LBV")
    tonum("VIBL")
	cP.DESTIPPORT = "device.cmmat.com:1087"
end

local function SetSleepBgn()
	c.gprsact = c.gen
	vprint("SetSleepBgn", c.gprsact)
end

local function SetSleepLen(v)
	t.GSleepLen = v
	if p.WakeReason == 8 or p.WakeReason == 9 then
		t.GSleepLen = t.gprssleeplen
	end
	vprint("SetSleepLen",t.GSleepLen)
end

local function ReadPos()
	local config_r = ReadTxt(p.pos)
    local lo,la
	if config_r == nil then
		vprint("read pos txt err")
		return
	end
    d1,d2,lo,la=string.find(config_r,"(.+),(.+)")
	if lo~=nil and la~=nil then
		gps.long = lo
		gps.lati = la
		gps.state = 2
	end
end

local function ReadResetC()
	local config_r = ReadTxt(p.freset)
	if config_r == nil then
		vprint("read reset txt err")
		return
	end
	local c1,c2
	vprint("read resetC", config_r)
	d1,d2,c1,c2 = string.find(config_r, "(%d+),(%d+)")
	if c1 == nil or c2 == nil then
		return
	end
    p.ResetC = tonumber(c1)
	c.resettime = tonumber(c2)
end

local function ReadLuaUp()
	local config_r = ReadTxt(p.fluaup)
	if config_r == nil then
		vprint("read luaup txt err")
		return
	end
    u.LastUp = config_r
end

local function WriteConfig()
	local config_w = cP["DOMAIN"] .. "," .. cP["FREQ"] .. "," .. cP["PULSE"] .. "," .. cP["TRACE"] .. "," .. cP["RADIUS"] .. "," .. cP["PSW"]
	config_w = config_w .. "," .. cP["POF"] .. "," .. cP["POFT"] .. "," .. cP["SPEED"] .. "," .. cP["VIBGPS"] .. "," .. cP["VIBCHK_X"]
	config_w = config_w .. "," .. cP["VIBCHK_Y"] .. "," .. cP["ACCLOCK"] .. "," .. cP["ACCLT"] .. "," .. cP["WAKEUP"] .. "," .. cP["WAKEUPT"]
	config_w = config_w .. "," .. cP["SLEEP"] .. "," .. cP["SLEEPT"] .. "," .. cP["VIB"] .. "," .. cP["VIBCALL"] .. "," .. cP["SMS"]
	config_w = config_w .. "," .. cP["CALLLOCK"] .. "," .. cP["CALLDISP"] .. "," .. cP["LBV"] .. "," .. cP["VIBL"]
	vprint("config_w",config_w)
	WriteTxt(p.fconfig,config_w)
end

local function WritePos()
	local config_w = gps.long .. "," .. gps.lati
	WriteTxt(p.pos,config_w)
end

local function WriteResetC()
	local config_w = tostring(p.ResetC) .. "," .. tostring(c.resettime)
	WriteTxt(p.freset,config_w)
end

local function WriteLuaup()
	local w1 = u.LastUp
	WriteTxt(p.fluaup,w1)
end

local function SaveTime(s)
	local y,m,d,nt,c
	--[2013-07-19 14:00:11,S1,1]
    d1, d2, y,m,d,nt = string.find(s,"%[(%d+)-(%d+)-(%d+)%s+(%d+:%d+:%d+),S1,%d")
	if y ~= nil and nt ~= nil then
	    --  13/06/17,11:26:25\"
		c = "AT+CCLK=\"" .. string.sub(y,3,4) .. "/" .. string.format("%02d",m) .. "/" .. string.format("%02d",d) .. "," .. nt .. "\"\r"
		SendATC(c)
	end
end

local function TsEq(state)
	return a.term == state
end

local function TermQue(s)
	a.termque = s
end

local function IsTermQue()
	return a.termque ~= "N"
end

local function GetTermState()
	return a.term
end

local function GetTermQue()
	return a.termque
end

local function GsEq(state)
	return a.gprs == state
end

local function RsEq(state)
	return a.reg == state
end

local function IsGPRSConn()
	return GsEq("CONNECTED")
end

local function TermStateTrans(state)
	rtos.timer_stop(t.term)
	a.term = state
	t.termlen = 0
	if state == "LOGING" then
		t.termlen = 60000
	elseif p.UpGoing then
		t.termlen = 120000
	elseif (state ~= "IDLE" and state ~= "LOGIN" and state ~= "INIT" and state ~= "SLEEP" and state ~= "DSLEEP") then
		t.termlen = 150000
	end
	if t.termlen ~= 0 then
		rtos.timer_start(t.term, t.termlen)
	end

	if state == "LOGIN" and IsTermQue() then
		vprint("que state:", a.termque)
		if IsGPRSConn() and RsEq("IDLE") then
			a.term = a.termque
		else
			vprint("err state", IsGPRSConn(), a.reg, a.termque)
		end
		a.termque = "N"
	end
end

local function TermQueTrans(state)
	if TsEq("LOGIN") then
		TermStateTrans(state)
	elseif a.termque == "T2P" or a.termque == "T2A" or a.termque == "N" or state == "T4P" then
		a.termque = state
	else
		vprint("que full", a.termque, state)
	end
end

local function GetRegState()
	return a.reg
end

local function IsRegQue()
	return a.regque ~= "N"
end

local function IsRegTemp(s)
	return (s ~= "IDLE" and s ~= "INIT" and s ~= "CENG")
end

local function RegStateTrans(state)
	a.reg = state
	if IsRegTemp(a.reg) then
		pmd.sleep(0)
		rtos.timer_start(t.statechg, t.statelen)
		return
	end
	if state == "IDLE" then
		if IsRegQue() then
			a.reg = a.regque
			a.regque = "N"
		end
		if c.gen > t.UARTSleepLen then
			pmd.sleep(1)
		end
	end
	rtos.timer_stop(t.statechg)
end

local function BackRegState()
	RegStateTrans("IDLE")
end

local function RegEventTrans(s1,atcs,s2,st,cond)
	local r

	if (st == "" or st == nil) and (cond ~= "" and cond ~= nil)  then
	    return false
	end
	if st ~= "" and st ~= nil and cond ~= "" and cond ~= nil then
		r = string.find(st,cond)
		if r == nil then
			return false
		end
	end
	if not RsEq(s1) then
	   return false
	end
	if string.len(atcs) > 0 then
	   SendATC(atcs)
	end
	RegStateTrans(s2)
	return true
end

local function gprsStateTrans(state)
	a.gprs = state
	if state ~= "CONNECTED" and state ~= "INIT" and state ~= "IDLE" then
		rtos.timer_start(t.tcp, t.tcplen)
	end
end


local function TermTrans(s1,s2)
	if TsEq(s1) then
		TermStateTrans(s2)
	end
end

local function Login()
	if p.UpGoing then
		return
	end
	if RsEq("IDLE") and TsEq("IDLE") and GsEq("CONNECTED") then
		TermStateTrans("T1P")
	end
end

local function AbnormState()
	return false
end

local function LightOnGsm()
	pmd.ldoset(1, pmd.LDO_LCD)
	p.gsmLt = 2
end

local function LightOffGsm()
	pmd.ldoset(0, pmd.LDO_LCD)
	p.gsmLt = 0
end

local function GsmWorkLight()
	if GsEq("CONNECTED") and  RsEq("IDLE") then  -- 长亮
		if p.gsmLt < 2 then
			LightOnGsm()
		end
	elseif GsEq("CONNECTED") and (RsEq("BEGINSEND") or RsEq("SENDING") or RsEq("SENT")) then --快闪
		if p.gsmLt < 2 then
			LightOnGsm()
		else
			LightOffGsm()
		end
	elseif (RsEq("SIMOK") or RsEq("CENG") or RsEq("IDLE")) and GsEq("CONNECTED") then  --检测到SIM卡就慢闪
		p.gsmLt = (p.gsmLt + 1) % 4
		if p.gsmLt == 0 then
			LightOffGsm()
		elseif p.gsmLt == 2 then
			LightOnGsm()
		end
	end
end

local function LightOnGps()
	pmd.ldoset(1, pmd.LDO_KEYPAD)
	p.gpsLt = 2
end

local function LightOffGps()
	pmd.ldoset(0, pmd.LDO_KEYPAD)
	p.gpsLt = 0
end

local function GpsWorkLight()
	if gps.state == 1 then
	    if p.gpsLt <2 then
		  LightOnGps()
		end
	elseif gps.open then  -- 慢闪
		p.gpsLt = (p.gpsLt + 1) % 4
		if p.gpsLt == 0 then
			LightOffGps()
		elseif p.gpsLt == 2 then
			LightOnGps()
		end
	else
		LightOffGps()
	end
end

local function AllLtOn()
	rtos.timer_stop(t.light)
	LightOnGsm(1)
	LightOnGps(1)
end

local function AllLtOff()
	rtos.timer_stop(t.light)
	LightOffGsm(0)
	LightOffGps(0)
end

local function openGPS()
	if gps.open then
		return
	end
	pmd.sleep(0)
	pio.pin.sethigh(pio.P1_1)
	uart.sleep(200)
	uart.setup(0,9600,8,uart.PAR_NONE,uart.STOP_1)
	rtos.timer_start(t.gps,t.gpslen)
	gps.open = true
	c.GpsOpen = c.gen
	vprint("gps open")
end

local function closeGPS()
	if not gps.open then
		return
	end
	rtos.timer_stop(t.gps)
	uart.close(0)
	pio.pin.setlow(pio.P1_1)
	gps.open = false
	pmd.sleep(1)
	if gps.state == 1 then
		gps.state = 2
	end
	gps.spd = 0
	gps.findall = false
	vprint("gps closed")
end

local function NailCpoint()
	if gps.state ~= 1 then
		return
	end
	gps.clong = gps.long
	gps.clat = gps.lati
	vprint("nailcpoint",gps.clong, gps.clat)
end

local function NilCpoint()
    gps.clong = 0
	gps.clat = 0
	vprint("NilCpoint",gps.clong,gps.clat)
end

local function IsNilCpoint()
	if gps.clong == 0 or gps.clat == 0 then
		return true
	end
	return false
end

local function SetACCLock()
    if cP["ACCLOCK"] == "1" then
		vprint("ACCLOCK",cP["ACCLOCK"],"GPIO1 enabled!")
		pio.pin.setdir(pio.INT,pio.P0_1)
		local t = pio.pin.getval(pio.P0_1)
		if t ~= nil then
			ACC.level = t
			ACC.s = t
			if ACC.s == 1 then
				p.guard = "ON"
				ACC.lastoff = c.gen
			end
			vprint("acc init", ACC.level, ACC.s)
		end
	elseif cP["ACCLOCK"] == "0" then
		vprint("ACCLOCK",cP["ACCLOCK"],"GPIO1 disabled!")
		pio.pin.close(pio.P0_1)
	end
end

local function sysinit()
	getlasterr()
	LogInit()
	FacSet()
	ReadConfig()
	ReadPos()
	ReadResetC()
	ReadLuaUp()
	pmd.sleep(0)
	SetACCLock()
	openGPS()
	uart.setup(uart.ATC, 115200, 8, uart.PAR_NONE, uart.STOP_1)
	uart.setup(1, 115200, 8, uart.PAR_NONE, uart.STOP_1)
	SensorInit()
	pio.pin.setdir(pio.INT, pio.P0_3)

	SendATC("ATE0")
	SendATC("at*exassert=0;*trace=\"sxs\",0,0;+creg=2\r")
	SendATC(ATS.sn)

	rtos.timer_start(t.gen, t.genlen)
	rtos.timer_start(t.light, t.lightlen)
	rtos.timer_start(t.query, t.querylen)
end

local function RegQueEvent(s1,s2)
	if RsEq(s1) then
		RegStateTrans(s2)
	else
		a.regque = s2
	end
end

local function IsSleep()
	return TsEq("SLEEP") or TsEq("DSLEEP")
end

local function EntSleep()
	if IsSleep() then
		return
	end
	closeGPS()
	if not RsEq("IDLE") then
		RegQueEvent("IDLE","TSLEEP")
		return
	end
	if GsEq("CONNECTED") then
		SendATC("AT+CIPCLOSE")
	end
	gprsStateTrans("IDLE")
	TermStateTrans("SLEEP")
	if not RsEq("INIT") then
		RegStateTrans("IDLE")
	end
	t.genlen = 10000
	AllLtOff()
	pmd.sleep(1)
	if p.WakeReason ~= "F" then
		p.SleepC = c.gen
	end
	rtos.timer_start(t.WakeUp, t.WakeLen)
end

local function ResetSys()
	p.ResetC = p.ResetC + 1
	if p.ResetC > p.ResetSleep and (p.CurTs - c.resettime) < 120 then
		p.ResetC = 0
		WriteResetC()
		EntSleep()
		return
	end
	c.resettime = p.CurTs
	WriteResetC()
	if p.ResetC ~= 0 then
		RsEq("INIT")
		SendATC("AT+CFUN=1,1")
	end
end

local function EntFlyMode()
	p.ExitFly = true
	SendATC("AT+CFUN=0")
end

local function ExitFlyMode()
	p.ExitFly = true
	SendATC("AT+CFUN=1")
end

local function ReConnectServer()
	RegStateTrans("IDLE")
	gprsStateTrans("INIT")
	TermStateTrans("INIT")
	SendATC("AT+CIPSHUT")
end

local function ActiveGprs(t1)
	t1 = t1 or 3
	SetSleepLen(t1*60)
	ReConnectServer()
end

local function IncTcpTry()
	vprint("TcpTry", p.TcpTry)
	p.TcpTry = p.TcpTry + 1
	if p.TcpTry > p.TcpReset then
		ResetSys()
	else
		ReConnectServer()
	end
end

local function ProcessTCPTimeout()
	vprint("gprs state timeout")
	if GsEq("CONNECTED") or GsEq("INIT") or GsEq("IDLE") then
		return
	end
	IncTcpTry()
end

local function ReSendGprs()
	RegStateTrans("BEGINSEND")
	TermStateTrans(GetTermState())
	c.T2 = c.gen
end

local function IncSendTry()
	vprint("sendtry", p.SendTry)
	p.SendTry = p.SendTry + 1
	if p.SendTry > p.SendReset then
		ResetSys()
	else
		ReSendGprs()
	end
end

local function ProcessRegTimeout()
	vprint("reg state timeout", a.reg)
	if IsRegTemp(a.reg) then
		IncSendTry()
	end
end

local function ProcessTermTimeout()
	vprint("term state timeout")
	if TsEq("LOGIN") and TsEq("INIT") and TsEq("IDLE") then
		return
	end
	IncSendTry()
end

local function ConnectServer(s)
	if (TsEq("LOGIN")) and GsEq("INIT") then
		gprsStateTrans("IPSTART")
		s = "OK"
	end

	if GsEq("INIT") then
		SendATC("AT+CIPHEAD=1")
		gprsStateTrans("CIPHEAD")
	elseif GsEq("CIPHEAD") and string.find(s, "OK") then
		SendATC("AT+CSTT=\"CMNET\"")
		gprsStateTrans("IPSTART")
	elseif GsEq("IPSHUT") and string.find(s, "SHUT OK")  then
		SendATC("AT+CSTT=\"CMNET\"")
		gprsStateTrans("IPSTART")
	elseif GsEq("IPSTART")  and string.find(s, "OK") then
		SendATC("AT+CIICR")
		gprsStateTrans("CIICR")
	elseif (GsEq("CIICR") or GsEq("IPSHUT") or GsEq("IPSTART")) and string.find(s, "ERROR") then
		IncTcpTry()
	elseif GsEq("CIICR")  and string.find(s, "OK") then
		SendATC("AT+CIFSR")
		gprsStateTrans("CIFSR")
	elseif GsEq("CIFSR") then
		if string.find(s,"ERROR") then
			SendATC("AT+CIPSHUT")
			gprsStateTrans("IPSHUT")
			RegStateTrans("IDLE")
		elseif  string.find(s, "%w+%.%w+%.%w+%.%w+")  then
			local x
			local server,stype,addr, port
			if p.UpGoing then
				server = u.server
				stype = u.socktype
			else
				server = cP.DESTIPPORT
				stype = p.socktype
			end
			d1, d2,x = string.find(s,"(%w+%.%w+%.%w+%.%w+)")
			vprint(x)
			d1, d2,addr,port = string.find(server,"(.-)%s*:%s*(%d+)")
			vprint("addr", addr,port)
			SendATC("AT+CIPSTART=\"" .. stype .. "\",\"" .. addr .. "\"," .. port)
			gprsStateTrans("CONNECTING")
		end
	elseif GsEq("CONNECTING") then
		if string.find(s, "CONNECT%s*OK") then
		    rtos.timer_stop(t.tcp)
			gprsStateTrans("CONNECTED")
			TermStateTrans("IDLE")
			SetSleepBgn()
			p.TcpTry = 0
		elseif string.find(s, "CONNECT%s*FAIL") or string.find(s, "ERROR") then
			rtos.timer_stop(t.tcp)
			SendATC("AT+CIPSHUT")
			gprsStateTrans("IPSHUT")
			RegStateTrans("IDLE")
		end
	end
end

local function SendGprsToServer()
	if p.gdata == "" or p.gdata == nil then
		return
	end

	if (RsEq("SENDING") or RsEq("SENT")) and string.find(atcstr,"ERROR") then
		RegStateTrans("IDLE")
		gprsStateTrans("INIT")
		IncTcpTry()
	end

	local L = string.len(p.gdata)

	if RegEventTrans("BEGINSEND","AT+CIPSEND=" .. L,"SENDING") then
		return
	end

	if RsEq("SENDING") then
		vprint("gprs data",p.gdata)
	end

	if RegEventTrans("SENDING",p["gdata"],"SENT",atcstr,">") then
		return
	end

	if RegEventTrans("SENT","","IDLE",atcstr,"SEND%s*OK") then
		if TsEq("T4A") or TsEq("T8A") or TsEq("T9A") or TsEq("T5A") or TsEq("T6A") then
			p.gdata = ""
		end
		p.SendTry = 0
		TermTrans("T4A","LOGIN")
		TermTrans("T8A","LOGIN")
		TermTrans("T9A","LOGIN")
		TermTrans("T5A","LOGIN")
		TermTrans("T6A","LOGIN")
	end
end

local function SendGprsPre()
	RegQueEvent("IDLE","BEGINSEND")
	c.T2 = c.gen
end

local function GetAllState()
	local s = 0
	if IsSleep() or p.T3sleep then
		s = s + 1
	end
	if p.guard == "ON" then
		s = s + 2
	end
	if p.stop then
		s = s + 4
	end
	if not bat.chg then
		s = s + 8
	end
	return s
end

local function SysWakeup(t1,r)
	if not IsSleep() then
		return
	end
	vprint("system wakeup", r)
	p.WakeReason = r
	if not RsEq("IDLE") and not RsEq("INIT") and not RsEq("WAKE") then
		t.genlen = 1000
		rtos.timer_stop(t.gen)
		rtos.timer_start(t.gen, t.genlen)
		RegQueEvent("IDLE", "WAKE")
		rtos.timer_stop(t.WakeUp)
		return
	end
	t.genlen = 1000
	rtos.timer_stop(t.gen)
	rtos.timer_start(t.gen, t.genlen)
	rtos.timer_stop(t.WakeUp)
	t1 = t1 or 3
	if TsEq("DSLEEP") then
		if r ~= "F" then
			p.SleepC = 2^30
		end
		ExitFlyMode()
		TermTrans("DSLEEP","INIT")
		RegStateTrans("INIT")
		gprsStateTrans("INIT")
	elseif TsEq("SLEEP") then
		ActiveGprs(t1)
	end
	rtos.timer_start(t.light, t.lightlen)
	pmd.sleep(0)
	openGPS()
end

local function PackHead()
	UpdateTime()
	return "[" .. p.htime .. ",1,V1.0.0,"  ..  atom.sn .. ","
end

local function PackAlarm(mtype,long,lati,plac,pci)
    if long=="" or long ==nil or plac == "" or plac==nil then
	   return ""
	end
   	local cellid = p.MCC .. ":" .. p.MNC .. ":" .. plac .. ":" .. pci
	local allstate = GetAllState()
	return mtype .. "," .. gps.state .. ",E," .. long .. ",N," .. lati .. "," .. gps.spd .. "," .. gps.cog .. "," .. allstate .. "," .. cellid
end

local function PackFrame(MsgType)
	if p.rssi == "0" then
		p.rssi = 15
	end
	local sig = p.rssi/3-1
	local b1 = (bat.vol-1)/10
	local v1 = gps.satenum .. sig .. b1
	local AlmMsg=""
	local indication

	if "T1" == MsgType then
	  	AlmMsg  = MsgType .. "," .. atom.PHONE ..  "," .. atom.USER .. "," .. cP["PSW"] .. "," .. p.IMSI .. "," .. p.IMEI .. ",SYCTC]"
	elseif "T2" == MsgType then
		AlmMsg  = MsgType .. "," .. v1 .. "]"
	elseif "T3" == MsgType then
		AlmMsg = PackAlarm(MsgType,gps.long,gps.lati,p.lac_int,p.ci_int) .. "," .. v1 .. "]"
	elseif "T4" == MsgType or "T11" == MsgType or "T12" == MsgType or "T14" == MsgType then
	    AlmMsg = PackAlarm(MsgType,gps.long,gps.lati,p.lac_int,p.ci_int) .. "]"
	elseif "T13" == MsgType then
		AlmMsg  = MsgType .. "," .. bat.lev .. "]"
	elseif "T8" == MsgType or "T9" == MsgType then
        AlmMsg  = MsgType .. ",1]"
	elseif "T5" == MsgType or "T6" == MsgType and p.T5T6 ~= "" then
        AlmMsg  = MsgType .. "," .. p.T5T6
    else
	    AlmMsg = ""
	end

	return AlmMsg
end

local function RequestFrame(MsgType, subtype)
	if RsEq("BEGINSEND") or RsEq("SENDING") or RsEq("SENT") then
		return
	end

	if IsSleep() then
		SysWakeup(3,1)
	end

	if not IsGPRSConn() then
		vprint("gprs deactive")
		return
	end

	if TsEq("IDLE") and MsgType ~= "T1" then
		vprint("not login state")
		return
	end

	vprint("RequestFrame", MsgType)

	if MsgType == "T12" and bat.chg then
		return
	end

	if MsgType == "UP" then
		local nam = ""
		if u.UpType == "SMS" then
			nam = u.SmsName
		elseif u.UpType == "CON" then
			nam = u.PrjName
		else
			p.UpGoing = false
			TermStateTrans("LOGIN")
			EntSleep()
			return
		end
		p.gdata = atom.sn .. "," .. nam .. "," .. u.LUAVER
		SendGprsPre()
		return
	end
	local gd = PackFrame(MsgType)
	gd = gd or ""
	if gd == "" then
		return
	end
	p.gdata = PackHead() .. gd

	SendGprsPre()
end

local function TermGprsTrans(s1,msg,s2)
	if TsEq(s1) then
		if msg ~= nil and msg ~= "" then
			RequestFrame(msg)
		end
		TermStateTrans(s2)
	end
end

local function TermEvent(s1,msg,s2,que)
	if TsEq(s1) then
		TermGprsTrans(s1,msg,s2)
	elseif que ~= nil then
		TermQue(que)
	end
end

local function CheckLuaUp(s1)
	local prj,num,last
	if string.find(s1,"OK") then
		p.UpGoing = false
		EntSleep()
		return false
	end
	d1,d2,prj,num,last = string.find(s1,"LUAUPDATE,(%d+),(%d+),(%d+)")
	if prj == nil or num == nil or last == nil then
		p.UpGoing = false
		EntSleep()
		return false
	end
	u.LuaPrj = prj
	u.LuaNum = tonumber(num)
	u.LuaLastBytes = tonumber(last)
	u.LuaState = 2
	u.LuaLastInd = 1
	p.gdata = "Get" .. tostring(u.LuaLastInd) .. "," .. u.LuaPrj
	SendGprsPre()
	return true
end

local function UpdateLua(s1)
	local str1,luaindex,f
	luaindex = hex2ascii(string.sub(s1,1,2))
	luaindex = string.sub(luaindex,2,2) .. string.sub(luaindex,4,4)
	luaindex = hex2int(luaindex)

	if u.LuaLastInd ~= tonumber(luaindex) then
		vprint("recindex,waitindex",luaindex,u.LuaLastInd)
		ResetSys()
	end

	vprint("writetofile",luaindex)
	if u.wfLua then
		f = io.open("/luazip/main.lua.zip","w+")
		u.wfLua = false
	else
		f = io.open("/luazip/main.lua.zip","a+")
	end
	assert(f ~= nil, "open main.lua failed!")
	str1 = string.sub(s1,3,-1)
	f:write(str1)
	f:close()
	u.LuaLastInd = u.LuaLastInd + 1
	if u.LuaLastInd > tonumber(u.LuaNum) then
		u.LuaState = 3
		WriteLuaup(u.LastUp)
		rtos.sleep(1000)
		ResetSys()
	else
		p.gdata = "Get" .. tostring(u.LuaLastInd) .. "," .. u.LuaPrj
		SendGprsPre()
	end
end

local function LuaUpOngoing(s1)
	if not p.UpGoing then
		return false
	end
	if u.LuaState == 2 then
		UpdateLua(s1)
		return true
	end
	if CheckLuaUp(s1) then
		return true
	end
	return false
end

local function QueryPara(s1)
	local h,paraval
	p.T5T6 = ""
	d1,d2,h = string.find(s1,"S5,(%w+)")
	if h == nil then
		vprint("err S5", s1)
		return
	end
	if h == "CID" then
		vprint("S5 CID", s1)
		return
	elseif h == "GPS" then
		gps.state = gps.state or 0
		paraval = gps.sates
	elseif h == "IMSI" then
	    paraval = p.IMSI
	elseif h == "IMEI" then
	    paraval = p.IMEI
    elseif h == "PHONE"  then
	    paraval = atom.PHONE
    elseif h == "USER" then
	    paraval = atom.USER
	elseif h == "VIBCHK" then
		paraval = cP[h .. "_X"] .. ":" .. cP[h .. "_Y"]
	elseif h == "VBAT" then
	    paraval = bat.lev
	elseif h == "GSM" then
        paraval = p.rssi
	elseif h == "ACC" then
        paraval = ACC.s
	elseif cP[h] == nil then
        return
	else
     	paraval = cP[h]
 	end

	if paraval == nil then
	  return
	end
	p.T5T6 = h .. "=" .. paraval .. "]"
end

local function ChangePara(s1)
	local p0,p1,p2
	p.T5T6 = ""
	d1,d2,p0,p1 = string.find(s1,"S6,(%w+)=(%w+)")
	if p0 == nil or p1 == nil then
		vprint("err S5", s1)
		return false
	end
	p0 = trim(p0)
	p1 = trim(p1)
	if p0 == "DOMAIN" then
		vprint("S6 DOMAIN", s1)
		return false
	elseif p0 == "PHONE" then
		atom.PHONE = p1
	elseif p0=="USER" then
		atom.USER = p1
	elseif p0 == "ACCLOCK" then
		if (cP[p0] =="1" and p1 == "0") or (cP[p0] =="0" and p1== "1") then
			cP[p0] = p1
			SetACCLock()
		end
	elseif p0== "VIBL"  then
		p1= tonumber(p1)
		if p1 > 15 or p1 < 0 then
			vprint("S6 VIBL err", p1)
			return false
		end
		cP[p0]= p1
		configsensor(cP[p0])
    elseif p0 == "FREQ" or p0 =="PULSE" or p0 == "ACCLT" then
		p1 = tonumber(p1)
		if p1 < 15 then
			vprint("S6 para err", p1)
			return false
		end
		cP[p0] = p1
	elseif p0 == "TRACE" or p0 == "POF" or p0 == "VIB"	or p0 == "VIBGPS" or p0 == "WAKEUP" or p0=="SLEEP" or p0 =="VIBCALL" or p0=="SMS" or p0 == "CALLLOCK" or p0== "CALLDISP" then
		if p1 ~= "0" and p1 ~= "1" then
			vprint("S6 para err, not 0 or 1", p1)
			return false
		end
		cP[p0] = p1
	elseif p0 == "POFT" or p0 == "WAKEUPT" or p0 == "RADIUS" then
		p1= tonumber(p1)
		cP[p0] = p1
	elseif p0 == "VIBCHK" then
		d1,d2,p1,p2 = string.find(s1,"VIBCHK=(%d+):(%d+)")
		if p1 == nil or p2 == nil then
			vprint("S6,err VHK")
			return false
		end
		p1 = tonumber(p1)
		p2 = tonumber(p2)
		if p1 < 0 or p2 < 0 then
			return false
		end
		cP[p0.."_X"] = p1
		cP[p0.."_Y"] = p2
	elseif p0 == "LBV"  then
		p1	= tonumber(p1)
		if p1 < 3500000 or p1 > 3800000 then
			vprint("S6,err LBV")
			return false
		end
		cP[p0] = p1
	elseif p0 == "SLEEPT" then
		p1 = tonumber(p1)
		if p1 < 0 then
			vprint("S6,err SLEEPT")
			return false
		end
		cP[p0] = p1
	end
	p.T5T6 = p0 .. ",1]"
	return true
end

local function ResetInitV()
	shk.shake = 2^30
	p.gpsmove = false
	p.cellmove = false
	p.gpslarge = false
	gps.MoveAlm = false
end

local function InitGuardInfo()
	ResetInitV()
	NailCpoint()
end

local function ClearGuardInfo()
	ResetInitV()
	NilCpoint()
end

local function ProcessAck(s1)
	vprint("ProcessAck", s1)
	if LuaUpOngoing(s1) then
		vprint("lua update")
		return
	end
	if string.find(s1,"S3") then
		p.gdata = ""
		TermTrans("T3A","LOGIN")
		p.statechg = false
		p.cellmove = false
		p.gpsmove = false
		if p.T3sleep then
			EntSleep()
			p.T3sleep = false
		end
	elseif string.find(s1,"S4") then
		TermQueTrans("T4P")
	elseif string.find(s1,"S2") then
		p.gdata = ""
		TermTrans("T2A","LOGIN")
	elseif string.find(s1,"S11") then
		p.gdata = ""
		TermTrans("T11A","LOGIN")
	elseif string.find(s1,"S12") then
		p.gdata = ""
		TermTrans("T12A","LOGIN")
	elseif string.find(s1,"S13") then
		p.gdata = ""
		TermTrans("T13A","LOGIN")
	elseif string.find(s1,"S14") then
		p.gdata = ""
		TermTrans("T14A","LOGIN")
	elseif string.find(s1,"S8") then
		InitGuardInfo()
		p.guard = "ON"
		TermQueTrans("T8P")
	elseif string.find(s1,"S9") then
		ClearGuardInfo()
		p.guard = "OFF"
		TermQueTrans("T9P")
	elseif string.find(s1,"S1") then
		local L1
		d1,d2,L1 = string.find(s1,"S1,(%d)")
		if L1 == nil then
			vprint("err S1", s1)
			return
		end
		if L1 ~= "1" then
			EntSleep()
		end
		p.gdata = ""
		TermTrans("T1A","LOGIN")
		if L1 == "1" then
			p.statechg = true
		end
		WriteConfig()
		SaveTime(s1)
	elseif string.find(s1,"S7") then
		ResetSys()
	elseif string.find(s1,"S5") then
		QueryPara(s1)
		TermQueTrans("T5P")
	elseif string.find(s1,"S6") then
		if not ChangePara(s1) then
			TermStateTrans("LOGIN")
		else
			WriteConfig()
			TermQueTrans("T6P")
		end
	end
end

local function processTCPData(s)
	local j,IPDAck

	d1,j=string.find(s,"+IPD,.-:")
	if j == nil or j <= 1 then
		vprint("err ipd:no length", j)
		return
	end

	IPDAck=string.sub(s,j+1,-1)
	ProcessAck(IPDAck)
end

local function processATcmd(str)
	if string.find(str,"+IPD") then
		processTCPData(str)
	end

	str = string.upper(str)
    if string.find(str, "LOG") then
		vprint("log output sms")
        GetLog()
		return
	elseif string.find(str, "UPPROG") then
		vprint("lup up sms")
		p.UpGoing = true
		u.UpType = "SMS"
		if IsSleep() then
			SysWakeup(3,3)
		else
			EntSleep()
		end
		return
    end

	if string.find(str, "+CPIN:%s*NOT") then
		if p.ExitFly then
			p.ExitFly = false
			return
		end
		rtos.timer_start(t.reset, t.resetlen)
	end
	if string.find(str, "CLOSED") and GsEq("CONNECTED") then
		IncTcpTry()
	end

	if RsEq("INIT") and  string.find(str,"%d+OK") then
		local x
		d1,d2,x = string.find(str,"(%d%d%d%d%d+)OK")
		if x ~= nil then
			atom.sn = x
			vprint("sn",atom.sn)
		end
	end
	if string.find(str,"+CPIN:%s*READY") then
		SendATC(ATS.init)
		RegStateTrans("SIMOK")
	end
 	if string.find(str,"SMS%s*READY") then
		RegStateTrans("IDLE")
	end
    if string.find(str,"%d+SW_") or string.find(str,"%d+\+CREG")  or string.find(str,"\+CREG%d+")  then
		local x,y,x1
		d1,d2,x,x1,y = string.find(str, "(%d+)\+CREG:%s+(%d+)(SW_V%d+_AM00%d_LUA)")
		if x1 == nil then
			d1,d2,x,y = string.find(str, "(%d+)(SW_V%d+_AM00%d_LUA)")
			if x == nil then
				d1,d2,x,y = string.find(str, "\+CREG:%s+(%d+)(SW_V%d+_AM00%d_LUA)")
			end
		end
		x = x or ""
		if string.len(x) == 15 then
			x = x .. string.sub(x1, 2,16)
		elseif string.len(x) == 31 then
			x = string.sub(x, 2, 31)
		end

		if string.len(x) ==30 then
			p.IMEI = string.sub(x,1,15)
			p.IMSI = string.sub(x,16,30)
			--p.IMSI = "460079061514166"
			p.MCC = string.sub(p.IMSI,1,3)
			p.MNC = string.sub(p.IMSI,4,5)
		end
		if y ~= nil then
			p.SOFTVERSION = y
		end
		vprint("IMEI,IMSI,MCC,MNC,soft",p.IMEI,p.IMSI,p.MCC,p.MNC,p.SOFTVERSION)
	end
	if string.find(str, "OK") and RsEq("CENG") then
		if not TsEq("IDLE") then
			SendATC(ATS.query)
			TermStateTrans("IDLE")
		end
	end
    if string.find(str,"%+CSQ:") then
		if RsEq("QUERY") then
			RegStateTrans(p.PrevState)
		end
		local t1,tn
		d1, d2,t1 = string.find(str,"%+CSQ:%s*(%d+)%s*,")
		if t1 ~= nil then
			p.rssi = t1
		end
		vprint("rssi", p.rssi)
	end
    if string.find(str,"%+CREG:") then
		local lac,ci
		d1, d2,lac,ci = string.find(str,"\+CREG:%s*%d,%d,\"(%w+)\",\"(%w+)\"")
		if lac == nil or ci == nil then
			d1, d2,lac,ci = string.find(str,"\+CREG:%s*%d,\"(%w+)\",\"(%w+)\"")
		end
		if lac == nil or ci == nil then
			p.GsmSucc = false
			if c.GsmLost == 0 then
				c.GsmLost = c.gen
			end
			vprint("gsm lost")
		else
			if not p.GsmSucc then
				p.GsmSucc = true
				c.GsmLost = 0
				if RsEq("SIMOK") then
					vprint("wait sms ready")
					rtos.timer_start(t.ready, t.readylen)
				end
				if RsEq("INIT") or RsEq("SIMOK")  then
					RegStateTrans("CENG")
					if p.FirstOn then
						SendATC(ATS.ceng)
						p.FirstOn = false
					else
						SendATC(ATS.csms)
					end
				end
				if IsSleep() then
					SysWakeup(3,4)
				end
			end

			p.lac_int = tostring(hex2int(lac))
			p.ci_int = tostring(hex2int(ci))
			vprint("CELL",p.lac_int,p.ci_int)
			cell.nid[0] = p.ci_int
		end
	end
	if string.find(str,"%+CENG:%d,\".+\"") then
		local n,r,c,l,i
		d1,d2,n,r,c,l = string.find(str, "\+CENG:(%d),\"%d+,(%d+),%d+,%d+,%d+,%d+,(%d+),%d+,%d+,(%d+),%d+\"")
		if n ~= nil and r ~= nil and c ~= nil and l ~= nil then
			--cell.nid[0] = tonumber(c)
			print("cell nid 0", cell.nid[0])
		else
			vprint("errr ceng output")
			return
		end
		for n,r,c,l in string.gmatch(str,"\+CENG:(%d),\"%d+,(%d+),%d+,%d+,%d+,(%d+),(%d+)\"") do
			cell.nid[tonumber(n)] = tonumber(c)
			print("cell nid n", n, cell.nid[tonumber(n)])
		end
	end

	if TsEq("FT") then
		if (RsEq("WIMEI") or RsEq("WISN")) and string.find(str, "OK") then
			RegStateTrans("INIT")
			SendUART1("\r\nOK\r\n")
		elseif string.find(str, "OK") then
			local x,y
			d1,d2,x = string.find(str,"(%d+)OK")
			if x ~= nil then
				if RsEq("RIMEI") then
					y = "\r\nAT+CGSN\r\n" .. x .. "\r\nOK\r\n"
				elseif RsEq("RISN") then
					y = "\r\nAT+WISN?\r\n" .. x .. "\r\nOK\r\n"
				end
				SendUART1(y)
				RegStateTrans("INIT")
			end
		end
	end
end

local function GpsManager()
	if not gps.open then
		local sf = false
		local p1 = GetLastShake()
		if (c.gen - p1) < 2 and p1 ~= 0 then
			vprint("v1",p1,c.gen)
			sf = true
		end
		if (c.gen - c.CellMove) <= t.CellMoveLen and c.CellMove ~= 0 then
			vprint("v2",c.CellMove)
			sf = true
		end
		if sf then
			if IsSleep() then
				SysWakeup(3,5)
			end
			openGPS()
		end
		return
	end
	if ACC.s == 0 then
		print("acc0")
		return
	end
	if (c.gen - c.GpsOpen) < t.GpsCloseLen then
		print("gpsman",c.GpsOpen,t.GpsCloseLen)
		return
	end
	if (c.gen - c.CellMove) <= t.CellMoveLen and c.CellMove ~= 0 then
		print("gpsman",c.CellMove,t.CellMoveLen)
		return
	end
	if TsEq("LOGIN") or TsEq("IDLE") then
		closeGPS()
	end
end

local function NormalSleep()
	local sf = false
	local SLen
	if bat.chg then
		SLen = t.NoNetChgSLen
	else
		SLen = t.NoNetBatSLen
	end
	if IsSleep() then
		return
	end
	if (RsEq("INIT") or RsEq("CENG")) and ((c.gen - c.GsmLost) >= SLen and c.GsmLost ~= 0) then
		c.GsmLost = 0
		sf = true
	end
	if GsEq("CONNECTED") and RsEq("IDLE") and (TsEq("LOGIN") or TsEq("IDLE")) then
		if c.gen > t.GSleepLen + c.gprsact then
			sf = true
		end
	end
	if not sf then
		return
	end
	vprint("sleep state")
	p.statechg = true
	p.T3sleep = true
end

local function DeepSleep()
	if not TsEq("SLEEP") then
		return
	end
	if (c.gen - p.SleepC) <= t.DeepSleepLen then
		return
	end
	TermTrans("SLEEP", "DSLEEP")
	RegStateTrans("INIT")
	gprsStateTrans("INIT")
	EntFlyMode()
	c.GsmLost = 0
	c.DeepSC = c.gen
end

local function WakeTest()
	if (c.gen - c.DeepSC) > p.DeepTest then
		c.DeepSC = 2^30
		SysWakeup(3,6)
	end
end

local function QueryNet()
	if RsEq("IDLE") and (TsEq("LOGIN") or TsEq("SLEEP")) then
		SendATC(ATS.query)
		p.PrevState = GetRegState()
		RegStateTrans("QUERY")
	end
end

local function IsCellMove()
	local i
	local s1 ="cellmove,"

	if (c.gen - c.moved) < p.move then
		return false
	end
	c.moved = c.gen
	if cell.nid[0] ~= nil then
		s1 = s1 .. cell.nid[0] .. ","
	end
	if cell.t[0] == nil then
		for i = 0,5 do
			cell.t[i] = cell.nid[i]
		end
		return false
	end

	for i = 0,5 do
		if cell.t[i] ~= nil then
			s1 = s1 .. cell.t[i] .. ","
		end
	end
	vprint(s1)

	for i = 0,5 do
		if cell.t[i] == cell.nid[0] then
			return false
		end
	end
	for i = 0,5 do
		cell.t[i] = cell.nid[i]
	end
	c.CellMove = c.gen
	if IsSleep() then
		SysWakeup(3,7)
	end
	return true
end

local function GetGpsMilli(v,vr)
	local v1,v2,R,T
	local L = string.len(v)
	if (L ~= 4 and L ~= 5) or string.len(vr) ~= 5 then
		vprint("gps data not right", v, vr)
		return
	end
	v2 = string.sub(v,1,L-2)
	v1 = tostring(tonumber(string.sub(v,L-1,L) .. vr)*10/6)
	L = string.len(v1)
	if L > 7 then
		v1 = string.sub(v1,1,7)
	elseif L < 7 then
		v1 = string.rep("0", 7-L) .. v1
	end

	T = v2 .. "." .. v1
	R = tonumber(v2..string.sub(v1,1,5)) * 36 + tonumber(string.sub(v1,6,7))*36/100
	return T,R
end

local function GetGpsStrength(sg)
    local curnum,lineno,total,sgv_str
	local s1,s2,s3,s4, c1,c2,c3,c4
	d2,d2,curnum, lineno,total,sgv_str = string.find(sg,"$GPGSV,(%d),(%d),(%d+),(.*)*.*")
	if curnum == nil or lineno == nil or total == nil or sgv_str == nil then
	  return
	end

	if tonumber(lineno)== 1  then
	   gps.sates = ""
	end

	d1,d2,s1,c1 = string.find(sgv_str,"^(%d+),%d+,%d+,(%d*)")
	if s1 ~= nil then
        if c1=="" then
	       c1="00"
	    end
		gps.sates = gps.sates .. s1 .. c1 .. " "
		d2,d2,s2,c2 = string.find(sgv_str,"^%d+,%d+,%d+,%d*,(%d+),%d+,%d+,(%d*)")
		if s2~=nil then
          if c2=="" then
		     c2="00"
		  end
	      gps.sates = gps.sates .. s2 .. c2 .." "
		  d2,d2,s3,c3 = string.find(sgv_str,"^%d+,%d+,%d+,%d*,%d+,%d+,%d+,%d*,(%d+),%d+,%d+,(%d*)")
		  if s3~= nil then
		      if c3== "" then
		         c3="00"
			  end
	          gps.sates = gps.sates .. s3 .. c3 .." "
			  d2,d2,s4,c4 = string.find(sgv_str,"^%d+,%d+,%d+,%d*,%d+,%d+,%d+,%d*,%d+,%d+,%d+,%d*,(%d+),%d+,%d+,(%d*)")
			  if s4~=nil then
			       if c4=="" then
		              c4="00"
		           end
	               gps.sates = gps.sates .. s4 .. c4 .." "
			  end
		  end
		end
	elseif s1== nil then
	    return
	end
end

local function processGpsData(s)
	local latti,lattir,longti,longtir,spd1,cog1,gpsfind
	local sgps = s

	if sgps == "" or sgps == nil then
		return
	end

	gps.find = ""

	if string.find(sgps, "$GPGGA") then
		local numofsate=""
		d1, d2,latti,lattir,longti,longtir,gpsfind,numofsate = string.find(sgps,"$GPGGA,%d+%.%d+,(%d+)%.(%d+),N,(%d+)%.(%d+),E,(%d),(%d+)")

		if (gpsfind == "1" or gpsfind == "2" or gpsfind == "4") and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil then
			gps.find = "S"
			if numofsate ~= nil or numofsate ~="" then
			  numofsate = tonumber(numofsate)
			  if numofsate >=10 then
			    gps.satenum =  9
			  else
                gps.satenum = numofsate
			  end
			end
		end
	elseif string.find(sgps, "$GPRMC") then
		d1, d2,gpsfind,latti,lattir,longti,longtir,spd1,cog1 = string.find(sgps,"$GPRMC,%d+%.%d+,(%w),(%d+)%.(%d+),N,(%d+)%.(%d+),E,(.-),(.-),")
		if gpsfind == "A" and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil  then
			gps.find = "S"
		end
	elseif string.find(sgps,"$GPGSV") then
		local sn1
		d1,d2,sn1 = string.find(sgps,"$GPGSV,%d*,%d*,%d*,%d*,%d*,%d*,(%d+)")
		if sn1 ~= nil then
			sn1 = tonumber(sn1)
			if sn1 > gps.gpssn and sn1 < 60 then
				gps.gpssn = sn1
			end
		end
		GetGpsStrength(sgps)
	end

	if spd1 ~= nil and spd1 ~= "" then
		local r1,r2
		d1,d2,r1,r2 = string.find(spd1, "(%d+)%.(%d+)")
		if r1 ~= nil then
			gps.spd = r1
			if r2 == nil then
				gps.spd = gps.spd .. "." .. string.sub(r2,1,1)
			end
		end
	end
	if cog1 ~= nil and cog1 ~= "" then
		local r1,r2
		d1,d2,r1,r2 = string.find(cog1, "(%d+)%.(%d+)")
		if r1 ~= nil then
			gps.cog = r1
			if r2 == nil then
				gps.spd = gps.spd .. "." .. string.sub(r2,1,1)
			end
		end
	end

	if gps.find ~= "S" then
		return
	end

	gps.lati, gps.latt_m  = GetGpsMilli(latti,  lattir)
	gps.long, gps.longt_m = GetGpsMilli(longti, longtir)
	gps.long = gps.long or 0
	gps.lati = gps.lati or 0

end

local function DiffOfLoc(latti1, longti1, latti2, longti2)
	local R1,R2
	local diff,d1=0,0
	d1,d2,R1=string.find(latti1,"%d+%.(%d+)")
	d1,d2,R2=string.find(latti2,"%d+%.(%d+)")
	if R1 == nil or R2 == nil then
	  return 0
	end

	R1 = string.sub(R1,1,5)
	R2 = string.sub(R2,1,5)
	d1 = tonumber(R1)-tonumber(R2)
	d1 = d1*111/100
	diff =  d1* d1

	d1,d2,R1=string.find(longti1,"%d+%.(%d+)")
	d1,d2,R2=string.find(longti2,"%d+%.(%d+)")
	if R1 == nil or R2 == nil then
	  return 0
	end

	R1 = string.sub(R1,1,5)
	R2 = string.sub(R2,1,5)
	d1 = tonumber(R1)-tonumber(R2)
	diff =  diff + d1* d1
	vprint("all diff:", diff)
	return diff
end

local function IsMoveRadius(latti1, longti1, latti2, longti2)
	vprint("move gps",latti1, longti1, latti2, longti2)
	local diff1 = DiffOfLoc(latti1, longti1, latti2, longti2)

	if diff1 > cP["RADIUS"]*cP["RADIUS"] then
		return true
	else
		return false
	end
end

local function CheckRadius()
	if (c.gen - GetLastShake()) > t.ShakeRadius then
		return
	end
	if (c.gen - c.checkrun) < t.checkrun then
		return
	end
	if p.guard == "OFF" then
		return
	end
	if gps.MoveAlm then
		return
	end
	if not gps.findall then
		return
	end
	if gps.clat == 0 or gps.clong == 0 then
		return
	end
	c.checkrun = c.gen
	p.gpslarge = IsMoveRadius(gps.clat,gps.clong,gps.lati,gps.long)
	if p.gpslarge then
		TermQueTrans("T14P")
		gps.MoveAlm = true
		p.gpslarge = false
	end
end

local function IncShkInd()
	shk.I = shk.I + 1
	if shk.I > shk.L then
		shk.I = 1
	end
	shk.count = shk.count + 1
end

local function PushShake()
	if shk.list[shk.I] == c.gen and not IsSleep() then
		return
	end
	IncShkInd()
	shk.list[shk.I] = c.gen
end

local function IsShkMeet()
	local t
	if shk.count < cP["VIBCHK_Y"] then
		return false
	end
	local i = shk.I + shk.L - cP["VIBCHK_Y"] + 1
	if i > shk.L then
		i = i % shk.L
	end
	t = c.gen - shk.list[i]
	if t > cP["VIBCHK_X"] then
		return false
	end
	return true
end

local function ShakeProcess()
	PushShake()
	if IsShkMeet() then
		c.GpsOpen = c.gen
		SetSleepBgn()
		vprint("shk.shake", shk.shake)
		if IsSleep() then
			SysWakeup(3,8)
		end
		if shk.shake > 2^29 then
			shk.shake = c.gen
		end
	end
end

local function ShakeInt()
	if not sensorCheckShake() then
		return
	end
	ShakeProcess()
end

local function SimShkInt()
	ShakeProcess()
end

local function ACCInt(v)
	vprint("acc",ACC.level,v)
	if ACC.level ~= v then
		ACC.c = c.gen
		ACC.level = v
	end
end

local function handleInt(id,resnum)
	vprint("int.id",id,"num:",resnum)
	if id == cpu.INT_GPIO_NEGEDGE then
		if resnum == pio.P0_1 then
			ACCInt(0)
		elseif resnum == pio.P0_5 then
			ShakeInt()
		elseif resnum == pio.P0_3 then
			SimShkInt()
		end
    elseif id == cpu.INT_GPIO_POSEDGE then
	    if resnum == pio.P0_1 then
			ACCInt(1)
		end
	end
end

local function HeartTime()
	if ((c.gen- c.T2) >= cP["PULSE"]) then
		TermQueTrans("T2P")
		c.T2 = c.gen
	end
end

local function ShakeAlm()
	if cP["VIB"] ~= "1" then
		return
	end
	if (c.gen - shk.shake) < shk.PTime then
		return
	end
	shk.shake = 2^30
	if (c.gen - shk.almc) <= 300 or p.guard ~= "ON" then
		return
	end
	shk.almc = c.gen
	TermQueTrans("T11P")
end

local function CheckGuard()
	local t1 = c.gen - ACC.cs
	if ACC.s == 0 and t1 >= 0 and t1 < 3 and p.guard == "ON" then   --点火
		p.guard = "OFF"
		p.statechg = true
		ClearGuardInfo()
		vprint("guard off")
	elseif ACC.s == 1 and (c.gen - ACC.cs) >= cP["ACCLT"] and p.guard == "OFF"	then  --熄火
		InitGuardInfo()
		p.guard = "ON"
		p.statechg = true
		ACC.cs = 2^30
		vprint("guard on",ACC.cs)
	end
end

local function CheckACC()
	if ACC.s ~= ACC.level and (ACC.level == 0 or (c.gen - ACC.c) >= 4) then
		ACC.s = ACC.level
		ACC.cs = c.gen
		SetSleepBgn()
		if ACC.s == 1 then
			ACC.lastoff = c.gen
		end
		if ACC.s == 0 then
			if IsSleep() then
				SysWakeup(3,9)
			end
		end
		c.GpsOpen = c.gen
		ResetInitV()
		vprint("checkacc",ACC.s,ACC.cs,ACC.lastoff)
	end
	CheckGuard()
end

local function CheckCharger()
	local sf = false
	local t1 = 0
	if cP["POF"] ~= "1" or bat.chg or bat.chgrep then
		return
	end
	if bat.lost <= 3 then
		return
	end
	if bat.chgalmc ~= 0 and (c.gen - bat.chgalmc) <= bat.chgalmLen then
		return
	end
	if ACC.s == 0 and (c.gen - bat.lost) > bat.almlen then
		sf = true
	end
	if ACC.s == 1 then
		if (bat.lost - ACC.lastoff) >= cP["POFT"] then
			sf = true
		else
			t1 = bat.lost - ACC.c
			if t1 > -5 and t1 < 5 then
				sf = true
			end
		end
	end
	if sf then
		TermQueTrans("T12P")
		bat.chgalmc = c.gen
		bat.chgrep = true
	end
end

local function CheckLowPower()
	if cP["POF"] ~= "1" then
		return
	end
	if bat.chg and bat.lev > cP["LBV"] then
		bat.lowrep = false
	end
	if bat.lowalmc ~= 0 and (c.gen - bat.lowalmc) <= bat.lowalmLen then
		return
	end
	if bat.lowrep then
		return
	end
	if bat.lev <= cP["LBV"] and not bat.chg then
		bat.lowalmc = c.gen
		bat.lowrep = true
		TermQueTrans("T13P")
		if IsSleep() then
			SysWakeup(3,"G")
		end
	end
end

local function IsGpsMove()
	if gps.state ~= 1 then
		return false
	end
	local L1,L2,T1,T2,R
	if (gps.oldlong == 0 and gps.long ~= 0) or (gps.oldlat == 0 and gps.lati ~= 0) then
		gps.oldlong = gps.long
		gps.oldlat = gps.lati
		return true
	end
	R = false
	d1,d2,L1 = string.find(gps.oldlong, "%d+%.(%d+)")
	d1,d2,L2 = string.find(gps.long, "%d+%.(%d+)")
	d1,d2,T1 = string.find(gps.oldlat, "%d+%.(%d+)")
	d1,d2,T2 = string.find(gps.lati, "%d+%.(%d+)")
	L1 = L1 or ""
	L2 = L2 or ""
	T1 = T1 or ""
	T2 = T2 or ""
	if string.sub(L1,1,4) ~= string.sub(L2,1,4) then
		R = true
	end
	if string.sub(T1,1,4) ~= string.sub(T2,1,4) then
		R = true
	end
	if R then
		vprint("gpsmove", L1,L2,T1,T2)
		WritePos()
		gps.oldlong = gps.long
		gps.oldlat = gps.lati
		return true
	end

	return false
end

local function T3Report()
	local T3F = 0
	if not TsEq("LOGIN") then
		return
	end
	if cP["TRACE"] ~= "1" then
		return
	end
	if (c.gen - c.T3) < cP["FREQ"] then
		return
	end
	if p.cellmove or p.gpsmove then
		T3F = T3F + 1
	end
	if (c.gen - shk.shake) < cP["FREQ"] and shk.shake < 2^29 then
		T3F = T3F + 2
	end
	if p.statechg then
		T3F = T3F + 8
	end

	print("T3Enter",c.gen)
	if T3F > 0 then
		TermQueTrans("T3P")
		c.T3 = c.gen
		vprint("T3Report", T3F)
	end
end

local function CheckStop()
	if not bat.chg then
		p.stop = false
		return
	end
	if (c.gen - GetLastShake()) > 300 and c.gen - ACC.lastoff > 300 and ACC.s == 1 and ACC.lastoff > 2 and ACC.lastoff < 2^29 then
		if not p.stop then
			p.stop = true
			vprint("stop state")
			p.statechg = true
		end
	elseif p.stop and ACC.s == 0 then
		p.stop = false
		vprint("outof stop state")
		p.statechg = true
	end
end

local function ReadATC()
	local t1 = ""
	local lenstr = ""
	local lenipd = 0
	local IsIPD = 0
	local readloop = true
	atcstr = ""
	while readloop == true do
		t1 = uart.read(uart.ATC, "*l", 0)
		if string.len(t1) == 0 then
		  readloop = false
		  continue
		end
		if string.find(t1,"%+IPD") then
			d1,d2,lenstr = string.find(t1,"%+IPD,(%d+):")
			if lenstr ~= nil then
				lenipd = string.len(lenstr) + 6 + tonumber(lenstr)
				IsIPD = 1
			end
		end
		if IsIPD == 1 and lenipd > 0 then
			if string.len(t1) > lenipd then
				t1 = string.sub(t1, 1, lenipd)
			end
			atcstr = atcstr .. t1
			lenipd = lenipd - string.len(t1)
		else
			atcstr = atcstr .. trim(t1)
		end
		if lenipd <= 0 then
			IsIPD = 0
		end
	end
	if atcstr ~= "" then
		if string.find(atcstr,"%+CENG") then
			print("atc receive", atcstr)
		else
			vprint("ATC receive", atcstr)
		end
	end

	if p.gdata ~= "" then
    	SendGprsToServer()
	end
	processATcmd(atcstr)

	if RsEq("IDLE") and not GsEq("CONNECTED") and not IsSleep() then
    	ConnectServer(atcstr)
		return
	end

	if not GsEq("CONNECTED") then
		return
	end
end

local function CheckFT()
	local s1
	if p.GsmSucc and (p.FtRlt % 2) == 0 then
		p.FtRlt = p.FtRlt + 1
	end
	if gps.gpssn > 35 and p.FtRlt ~= 2 and p.FtRlt ~= 3 and p.FtRlt ~= 6 and p.FtRlt ~= 7 then
		p.FtRlt = p.FtRlt + 2
	end
	if shk.shake < 2^29 and p.FtRlt < 4 then
		p.FtRlt = p.FtRlt + 4
	end

	if p.FtRlt < 7 then
		vprint("FT timeout1",p.FTTimes)
		rtos.timer_start(t.FT, t.FTlen)
	else
		s1 = "\r\n" .. "+FT9321:" .. "\r\n" .. p.FtRlt .. "\r\n" .. "OK" .. "\r\n"
		SendUART1(s1)
	end
end

local function FTTimeout()
	local s1
	p.FTTimes = p.FTTimes + 1
	vprint("FT timeout",p.FTTimes)
	if p.FTTimes > p.FTFinish then
	    s1 = "\r\n" .. "+FT9321:" .. "\r\n" .. p.FtRlt .. "\r\n" .. "OK" .. "\r\n"
		SendUART1(s1)
		return
	end
	CheckFT()
end

local function processUART1(s1)
    if string.find(s1,"WIMEI") then
		SendATC(s1)
		TermStateTrans("FT")
		RegStateTrans("WIMEI")
	elseif string.find(s1,"CGSN") then
		SendATC(s1)
		RegStateTrans("RIMEI")
	elseif string.find(s1,"WISN%?") then
		SendATC(s1)
		RegStateTrans("RISN")
	elseif string.find(s1,"WISN") then
		SendATC(s1)
		RegStateTrans("WISN")
	end

	if string.find(s1,"AT%+FT9321") then
		vprint("ft begin")
		CheckFT()
	end
end

local function ReadUART1()
	local t1
	local s1 = ""
	local rd = true
	while rd == true do
		t1 = uart.read(1, "*l", 0)
		if string.len(t1) == 0 then
			rd = false
			continue
		end
		s1 = s1 .. trim(t1)
	end

	if s1 ~= "" then
		vprint("uart1 receive:", s1)
	end

	processUART1(s1)
end

local function ReadGPS()
	local strgps = ""
	local gpsreadloop = true

	c.gps = c.gps + 1
	while gpsreadloop == true do
		strgps = uart.read(0, "*l", 0)
		if string.len(strgps) == 0 then
			gpsreadloop = false
			continue
		end

		if c.gps % c.GpsPrt == 0 then
			vprint("gps data:",c.gps, strgps)
		end
		processGpsData(strgps)

		if gps.find == "S" then
			gps.findall = true
			c.gpsfind = c.gps
			gps.state = 1
			if p.guard == "ON" and IsNilCpoint() then
				NailCpoint()
			end
		elseif (c.gps - c.gpsfind) > 20 then
			gps.findall = false
			gps.state = 2
		end
	end
	if c.gps % c.GpsRltPrt == 0 then
		vprint("gps rlt", gps.long,gps.lati,gps.spd,gps.cog,gps.find)
	end
end

local function IsLuaUpTime()
	local h1 = tonumber(string.sub(p.time,9,10))
	if h1 > 6 then
		return false
	end
	local p1 = string.sub(p.time,1,8)
	local p2 = string.sub(u.LastUp,1,8)
	if p1 == p2 then
		return false
	end
	local h2 = c.gen % 7
	if h1 == h2 then
		return true
	end
	return false
end

local function CheckUpdate()
	if p.UpGoing and RsEq("IDLE") and TsEq("IDLE") and GsEq("CONNECTED") then
		TermStateTrans("UPING")
		return
	end

	if p.UpGoing and IsSleep() then
		SysWakeup(3,"A")
	end

	if p.UpGoing then
		return
	end
	if not IsSleep() then
		return
	end
	if c.gen - p.SleepC < u.UpSleepLen then
		return
	end
	p.UpGoing = IsLuaUpTime()
	if not p.UpGoing then
		return
	end
	u.UpType = "CON"
	u.LastUp = p.time
	SysWakeup(3,"B")
end

local Ng, Gg, Tg = {}, {}, {}

Ng["IDLE"] = 0
Ng["QUERY"] = 1
Ng["INIT"] = 2
Ng["BEGINSEND"] = 3
Ng["SENDING"] = 4
Ng["SENT"] = 5
Ng["SIMOK"] = 6
Ng["CENG"] = 7
Ng["WAKE"] = 8
Ng["TSLEEP"] = 9
Ng["N"] = "A"

Gg["CONNECTED"] = 0
Gg["INIT"] = 1
Gg["IDLE"] = 2
Gg["CIPHEAD"] = 3
Gg["IPSHUT"] = 4
Gg["IPSTART"] = 5
Gg["CIICR"] = 6
Gg["CIFSR"] = 7
Gg["CONNECTING"] = 8

Tg["LOGIN"] = 0
Tg["SLEEP"] = 1
Tg["DSLEEP"] = 2
Tg["IDLE"] = 3
Tg["INIT"] = 4
Tg["T1P"] = 5
Tg["T1A"] = 6
Tg["T2P"] = 7
Tg["T2A"] = 8
Tg["T3P"] = 9
Tg["T3A"] = "A"
Tg["T4P"] = "B"
Tg["T4A"] = "C"
Tg["T5P"] = "D"
Tg["T5A"] = "E"
Tg["T6P"] = "F"
Tg["T5A"] = "G"
Tg["T6P"] = "H"
Tg["T6A"] = "I"
Tg["T8P"] = "J"
Tg["T8A"] = "K"
Tg["T9P"] = "L"
Tg["T9A"] = "M"
Tg["T11P"] = "N"
Tg["T11A"] = "O"
Tg["T12P"] = "P"
Tg["T12A"] = "Q"
Tg["T13P"] = "R"
Tg["T13A"] = "S"
Tg["T14P"] = "T"
Tg["T14A"] = "U"
Tg["UPING"] = "V"
Tg["UPA"] = "W"
Tg["N"] = "Z"

local function Bs(t1)
	if t1 then
		return "T"
	else
		return "F"
	end
end

local function PrintVars()
	local s1 = c.gen .. ","
	local pt = string.sub(p.time,5,-1)
	local pu = string.sub(u.LastUp,5,-1)
	local guard1
	if p.guard == "ON" then
		guard1 = "O"
	elseif p.guard == "OFF" then
		guard1 = "F"
	else
		guard1 = "N"
	end
	if c.gen < 30 then
		s1 = s1 .. gps.gpssn .. ","
	end
	if (c.gen - c.PrintC) >= 60 then
		s1 = s1 .. pt .. "," .. pu .. ","
		c.PrintC = c.gen
	end
	print(c.gen, a.reg, a.gprs,a.term,a.termque,shk.shake,ACC.s,p.guard,pt,pu,p.stop,bat.chg,bat.chgrep,p.cellmove,p.gpsmove,p.UpGoing,gps.MoveAlm,gps.open,gps.gpssn,gps.state)
	Ng[a.reg] = Ng[a.reg] or "q"
	Gg[a.gprs] = Gg[a.gprs] or "q"
	Tg[a.term] = Tg[a.term] or "q"
	Ng[a.regque] = Ng[a.regque] or "q"
	Tg[a.termque] = Tg[a.termque] or "q"
	s1 = s1 .. Ng[a.reg] .. Gg[a.gprs] .. Tg[a.term] .. Ng[a.regque] .. Tg[a.termque] .. ACC.s .. guard1 .. p.WakeReason .. Bs(p.stop) .. Bs(p.statechg)
	s1 = s1 .. Bs(bat.chg) .. Bs(bat.chgrep) .. Bs(p.cellmove) .. Bs(p.gpsmove) .. Bs(p.UpGoing) .. Bs(gps.MoveAlm) .. Bs(gps.open) .. gps.state
	vprint(s1)
end

local function ResetSensor()
	if (c.gen - c.ResetSensor) > t.ResetSensor then
		i2c.read(s.i2c_2, 0x03, 1)
		c.ResetSensor = c.gen
	end
end

local function ProcessGenTimer()
	c.gen = c.gen + t.genlen/1000
	if AbnormState() then
		ResetSys()
	end
	if RsEq("WAKE") then
		RegStateTrans("IDLE")
		SysWakeup(3,"C")
	end
	if RsEq("TSLEEP") then
		RegStateTrans("IDLE")
		EntSleep()
	end
	if RsEq("BEGINSEND") and p.gdata ~= "" then
		SendGprsToServer()
	end
	UpdateTime()
	NormalSleep()
	DeepSleep()
	WakeTest()
	Login()
	p.cellmove = IsCellMove()
	p.gpsmove = IsGpsMove()
	CheckACC()
	CheckStop()
	ShakeAlm()
	T3Report()
	CheckRadius()
	CheckCharger()
	CheckLowPower()
	HeartTime()
	CheckUpdate()
	GpsManager()
	ResetSensor()
	PrintVars()
	TermEvent("T1P","T1","T1A")
	TermEvent("T4P","T4","T4A")
	TermEvent("T3P","T3","T3A")
	TermEvent("T14P","T14","T14A")
	TermEvent("T11P","T11","T11A")
	TermEvent("T12P","T12","T12A")
	TermEvent("T13P","T13","T13A")
	TermEvent("T2P","T2","T2A")
	TermEvent("T8P","T8","T8A")
	TermEvent("T9P","T9","T9A")
	TermEvent("T5P","T5","T5A")
	TermEvent("T6P","T6","T6A")
	TermEvent("UPING","UP","UPA")
end

local function ProcessChg(chgmsg)
	if chgmsg.level > 100 then
		return
	end
	if not bat.chg and chgmsg.charger then
		bat.lost = 0
		vprint("chg on state")
		p.statechg = true
		bat.chgrep = false
		if IsSleep() then
			SysWakeup(3,"D")
		end
	end
	if bat.chg and not chgmsg.charger then
		bat.lost = c.gen
		vprint("chg lost state")
		p.statechg = true
		if IsSleep() then
			SysWakeup(3,"E")
		end
	end

	bat.chg = chgmsg.charger
	bat.vol = chgmsg.level
	bat.lev = chgmsg.voltage*1000
	if bat.vol > 100 then
		bat.vol = 100
	end
	vprint("chg msg",chgmsg.present,chgmsg.level,chgmsg.voltage,chgmsg.charger,chgmsg.state)
end

local function SleepTimer()
	SysWakeup(3,"F")
end

local function NetReady()
	RegStateTrans("IDLE")
	if p.WakeReason ~= 0 then
		ActiveGprs()
	end
end

sysinit()

print(u.PrjName .. " Lua " .. u.LUAVER)

while true do
    msg = rtos.receive(2000)
    if msg.id == rtos.MSG_UART_RXDATA then
        if msg.uart_id == uart.ATC then
			ReadATC()
		elseif msg.uart_id == 1 then
			ReadUART1()
		end
	elseif msg.id == rtos.MSG_TIMER then
        if t.gen == msg.timer_id then
			rtos.timer_start(t.gen, t.genlen)
			ProcessGenTimer()
		elseif t.gps == msg.timer_id then
			rtos.timer_start(t.gps, t.gpslen)
			ReadGPS()
		elseif t.statechg == msg.timer_id then
			ProcessRegTimeout()
		elseif t.tcp == msg.timer_id then
			ProcessTCPTimeout()
		elseif t.term == msg.timer_id then
			ProcessTermTimeout()
		elseif t.light == msg.timer_id then
			rtos.timer_start(t.light, t.lightlen)
			c.lt = c.lt + 1
			GsmWorkLight()
			GpsWorkLight()
        elseif t.vib == msg.timer_id then
		    sensorCheckShake()
		elseif t.FT == msg.timer_id then
			FTTimeout()
		elseif t.WakeUp == msg.timer_id then
			SleepTimer()
		elseif t.query == msg.timer_id then
			rtos.timer_start(t.query, t.querylen)
			QueryNet()
		elseif t.ready == msg.timer_id then
			NetReady()
		elseif t.reset == msg.timer_id then
			ResetSys()
		end
     elseif msg.id == rtos.MSG_INT then -- 中断消息
		handleInt(msg.int_id,msg.int_resnum)
	elseif msg.id == rtos.MSG_PMD then
		ProcessChg(msg)
    end
end
