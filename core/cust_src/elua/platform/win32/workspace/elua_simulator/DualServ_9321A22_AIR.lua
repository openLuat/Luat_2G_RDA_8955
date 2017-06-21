collectgarbage("setpause",110)

local smatch = string.match
local BT = "9321A22"
local msg = nil
local atqueue = {
	"ATE0",
	"AT*EXASSERT=1",
	"AT*TRACE=\"SXS\",0,0",
	"AT*TRACE=\"DSS\",0,0",
	"AT*TRACE=\"RDA\",0,0",
	"AT+CREG=2",
	"AT+WISN?",
	"AT+CGSN",
	"AT+CNMI=2,2",
	"AT+CMGF=1",
	"AT+CSCS=\"UCS2\"",
	"AT+CENG=1,1",
	"AT+VER",
	"AT+AMFGM",
	"AT+AMFGL"
}

local Lib =
{
	currcmd = nil,
	cmdtype = 0,
	cmdprefix = nil,
	atproc = false,
	atrsp = { ok = nil, line = nil},
	--ipstatus = "",
	linklist = {},
	maxlinks = 3,
	urcrcvd = {lid = 0,len = 0,data = ""}
}
local timer = {}
local a = {}
local c = {}
local t = {}
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
local air = {}
local IO = {}
local Log = {}

local function AirInit()
	air.server = "s1.clouddatasrv.com"
	air.port = "8018"
	air.imsisend = false
	air.A1Send = 0

	air.RepLen = 20
	air.gpsOn = 20
	air.chgHeart = 120
	air.chgSleep = 300
	air.batHeart = 300
	air.batSleep = 120
	air.accHeart = 600
	air.debug = 0
	air.debuglen = 300
	air.debugsend = -280
end

function RestorePara()
	cP["DOMAIN"] = "device.cmmat.com:1087"
    cP["FREQ"] = 25
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
	cP["LBV"] = 3600
	cP["VIBL"] = 0
end

function StateInit()
	a.term = "INIT"
end

function TimerInit()
	t.gen = 1
	t.genlen = 1000
	t.light = 2
	t.lightlen = 2000
	t.gps = 3
	t.gpslen = 2000
	t.FT = 4
	t.FTlen = 1000
	t.query = 5
	t.querylen = 1000
	t.reset = 6
	t.resetlen = 10000
	t.tcpCMCC = 7
	t.tcpAir = 8
	t.tcplen = 60000
	t.airUdpTry = 10
	t.airUdpLen = 600000
	t.vib = 11
	t.atrsp = 12
	t.atrsplen = 50000
	t.wd = 13
	t.wdlen = 1000

	t.DeepSleepLen = 3600*24
	t.checkrun = 30
	t.UARTSleepLen = 300
	t.ShakeRadius = 60
	t.CellMoveLen = 120
	t.NoGprs = 100
	t.LoginReset = 3600000
	t.ResetNoGprs = 600
	t.A1 = 20
	t.ST = 300
end

local function IsDSleep()
	return (a.term == "DSLEEP")
end

local function IsNSleep()
	return a.term == "SLEEP"
end

function IsSleep()
	return IsNSleep() or IsDSleep()
end

local function UpdateA1Len()
	--保证第一次开机5分钟才进入休眠
	if c.gen > 300 then
		t.ST = air.batSleep
	else
		t.ST = air.chgSleep
	end

	if bat.chg then
		t.ST = air.chgSleep
	end

	if IsSleep() then
		t.A1 = air.batHeart
		if bat.chg then
			t.A1 = air.chgHeart
			if ACC.valid == 1 then
				t.A1 = air.accHeart
			end
		end
	else
		t.A1 = air.RepLen
	end
	print("UpdateA1Len", ACC.rnum,ACC.valid,t.ST,t.A1)
end

function CounterInit()
	c.gen = 0
	c.lt = 0
	c.gprsact = 0
	c.gps = 0
	c.GpsPrt = 180
	c.GpsRltPrt = 1
	c.gpsfind = 0
	c.moved = 0
	c.T2 = 0
	c.T3 = 0
	c.DeepSC = 2^30
	c.checkrun = 0
	c.CellMove = 0
	c.LowSig = 0
	c.PrintC = 0
end

function CellInit()
	cell.t = {}
	cell.nid = {}
end

function UpdateTime()
	p.CurTs = os.time()
	local t1 = os.date("*t",p.CurTs)
	p.time = string.format("%04d%02d%02d%02d%02d%02d", t1.year,t1.month,t1.day,t1.hour,t1.min,t1.sec)
	p.htime = string.format("%04d-%02d-%02d %02d:%02d:%02d", t1.year,t1.month,t1.day,t1.hour,t1.min,t1.sec)
end

function pInit()
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
	p.lac = 0
	p.ci = 0
	p.GsmSucc = false
	p.GprsSucc = false
	p.htime = "2013-08-11 12:00:00"
	p.guard = "OFF"
	p.SleepC = 2^30
	p.DeepTest = 2^30
	p.stop = false
	p.statechg = false
	p.FTTimes = 0
	p.FTFinish = 20
	p.T5T6 = ""
	p.FtRlt = 0
	p.WakeReason = 0
	p.airseq = 0
	p.AS = 0
	p.CS = 0
	p.FastNum = 0
	p.ExitFly = false
	p.ShkQuick = false
	p.smsrec = nil
	p.smsd = ""
	p.airsk = 0
	p.weakrssi = 8
	p.nrssic = 0
	p.weaklen = 600
	p.dsleep = false
	p.wd = true
	p.skh = 0
	p.ftsn = 0
	p.resendnum = {0,0}
	p.lastdata = ""
	p.pinlock = false
	p.restartNum = 10
	p.resettimes = 0
	p.recdata = 0
	UpdateTime()
end

function AtomInit()
	atom.sn = "2508010007000033"
	atom.header = "[" .. p.time .. ",1,V1.0.0,"  ..  atom.sn .. ","
	atom.PHONE="13800002222"
	atom.USER="13861511021"
end

local function LuaUpInit()
	u.PrjName = BT
	u.LUAVER = "3.1.3"
	u.LuaNum = 0
	u.LuaLastBytes = 0
	u.LuaLastInd = 500
	u.LuaState = 0
	u.wfLua = true
	u.lod = ""
	u.zf = "/luazip/main.lua.zip"
end

local function BatInit()
	bat.vol = 50
	bat.lev = 0
	bat.chg = true
	bat.batchg = true
	bat.lost = 0
	bat.almlen = 15
	bat.lowalmc = 0
	bat.chgalmc = 0
	bat.chgalmLen = 600
	bat.lowalmLen = 300
	bat.chgrep = false
	bat.lowrep = false
end

local function EmptyGpsQue()
	gps.dataN = 0
	gps.A = {}
	gps.L = {}
end

local function GpsInit()
	gps.open = false
	gps.latt_m = 0
	gps.longt_m = 0
	gps.lati = 0
	gps.long = 0
	gps.spd = 0
	gps.cog = 0
	gps.haiba = 0
	gps.spdc = 0
	gps.lastcog = 0
	gps.cogchange = false
	gps.state = 0
	gps.find = ""
	gps.findall = false
	gps.satenum = 0
	gps.clong = 0
	gps.clat = 0
	gps.oldlong = 0
	gps.oldlat= 0
	gps.oldtime = 0
	gps.gpssn = 1
	gps.MoveAlm = false
	gps.sates = ""
	EmptyGpsQue()
	gps.cgen = 0
	gps.QueL = 7
	gps.errL = 100
	gps.errD = 600
	gps.gMove = 400
	gps.spdwake = 5
	gps.spdair = 0
	gps.wake = 0
end

local function ShakeInit()
	shk.count = 0
	shk.list = {}
	shk.I = 1
	shk.L = 10
	shk.shake = 2^30
	shk.PTime = 0
	shk.almc = -300
	for i = 1,shk.L do
		shk.list[i] = 0
	end
end

local function AcCInit()
	ACC.rnum = 0
	ACC.ResetNum = 5
	ACC.rt = 0
	ACC.valid = 1
	ACC.level = -1
	ACC.c = 2^30
	ACC.s = -1
	ACC.cs = 2^30
	ACC.lastoff = 2^30
end

local function LogInit()
	Log.fname = "/log.txt"
	Log.stname = "/zipst.txt"
	Log.TotalNum = 50
	Log.ztime = 30*60
	Log.sTime = 0
	Log.sizeL = 100*1024
	Log.OutGoing = false
	Log.fconfig = "/config.txt"
	Log.freset = "/reset.txt"
	Log.fconfig1 = "/c1.txt"
	Log.freset1 = "/r1.txt"
	Log.fconfig2 = "/c2.txt"
	Log.freset2 = "/r2.txt"
	Log.fver = "/ver.txt"
end

local function emptylink()
	for i = 1,Lib.maxlinks do
		if Lib.linklist[i] == nil then
			return i
		end
	end

	return nil
end

function resetlinks()
	for i = 1,Lib.maxlinks do
		if Lib.linklist[i] then
			Lib.linklist[i].login = false
			Lib.linklist[i].state = "STARTING"
			Lib.linklist[i].CurTr = 0
			Lib.linklist[i].sendq = {}
		end
	end
end

function startlink(server,port,protocol,listener)
	local id = emptylink()

	if id == nil then
		return nil
	end

	local link = {
		server = server,
		port = port,
		protocol = protocol,
		listener = listener,
		state = "STARTING",
		login = false,
		CurTr = 0,
		valid = true,
		sendq = {}, --发送队列
	}

	Lib.linklist[id] = link

	if Lib.ipstatus == "IP STATUS" or Lib.ipstatus == "IP PROCESSING" then
		sendat(string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s",id,protocol,server,port))
	else
		setupIP()
	end

	return id
end

function closelink(id)
	if Lib.linklist[id] == nil or Lib.linklist[id].state == "CLOSING" then
		return
	end

	Lib.linklist[id].state = "CLOSING"

	sendat("AT+CIPCLOSE="..id)
end

local function closeAllLink()
	closelink(p.AS)
end

local function connectAll()
	for i = 1,Lib.maxlinks do
		if Lib.linklist[i] then
			connect(i)
		end
	end
end

function connect(id)
	if Lib.linklist[id] == nil then
		vprint("[connect]: link null ",id)
		return
	end
	Lib.linklist[id].login = false
	sendat(string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s",id,Lib.linklist[id].protocol,Lib.linklist[id].server,Lib.linklist[id].port))
end

function disconnect(id)
	if Lib.linklist[id] == nil then
		vprint("[disconnect]: link null ",id)
		return
	end

	sendat("AT+CIPCLOSE="..id)
end

local function setlinkstat(id,state)
	if id and Lib.linklist[id] then
		if Lib.linklist[id].state ~= state then
			if Lib.linklist[id].state == "CLOSING" then
				if state == "CLOSED" then
					Lib.linklist[id] = nil
					if id == p.AS then
						p.AS = 0
					elseif id == p.CS then
						p.CS = 0
					end
				else
					vprint("warning: closing link:",id,"state:",state)
				end
				return
			end

			Lib.linklist[id].state = state

			vprint("id.state:",id,state)

			Lib.linklist[id].listener.notify(state)
		end
	end
end
function SetCMCCLogin(id,s)
	Lib.linklist[id].login = s
end

function linkstatus(data)
	local id,bearer,protocol,addr,port,state = smatch(data,"C: (%d),(%d*),\"([TCPUD]*)\",\"([%w%.]*)\",\"(%d*)\",\"(%w+)\"")

	id = tonumber(id)

	setlinkstat(id,state)
end

function setlinkres(id,res)
	if id and Lib.linklist[id] then
		if Lib.linklist[id].state == "CONNECTED" then
			if res == "CONNECT FAIL" then
				return
			end
		end
	end

	if res == "CONNECT FAIL" then
		Lib.linklist[id].listener.notify(res)
		return
	end

	if res == "CLOSE OK" then
		res = "CLOSED"
	elseif res == "CONNECT OK" then
		res = "CONNECTED"
	end
	setlinkstat(id,res)
end

local function LaterRestart(t1)
	if t1 ~= nil then
		t.resetlen = t1
	else
		t.resetlen = 10000
	end
	vprint("reset later", t.resetlen)
	rtos.timer_start(t.reset, t.resetlen)
end

function GetCurTr(id,s)
	local t1,t = 999,0
	if id == p.CS then
		t = smatch(s,"T(%d+),")
		if t ~= nil then
			t1 = tonumber(t)
		end
	elseif id == p.AS then
		t = string.sub(s,6,8)
		if t ~= nil then
			t = tonumber(t)
		end
		if t ~= nil then
			t1 = t
		end
	end
	return t1
end

function send(id,data)
	if Lib.linklist[id] == nil or Lib.linklist[id].state ~= "CONNECTED" then
		vprint("send failed:",id,Lib.linklist[id].state)
		return
	end

	if Lib.linklist[id].CurTr ~= 0 then
		vprint("rsp msg not recv", Lib.linklist[id].CurTr, p.lastdata)
		if p.resendnum[id] >= p.restartNum then
			LaterRestart()
		end
		p.resendnum[id] = p.resendnum[id] + 1
	end

	if GetCurTr(id,data) == 1 and id == p.CS then
		table.insert(Lib.linklist[id].sendq,1,data)
	else
		table.insert(Lib.linklist[id].sendq,data)
	end

	sendat("AT+CIPSEND="..id)
end

local function Str2UCS2(s)
	local t = ""
	for i = 1, string.len(s) do
		t = t .. "003" .. string.sub(s,i,i)
	end
	return t
end

function sendsms(sdata,cod,nums)
	p.smsdata = sdata
	if cod == "1" then
		sendat("AT+CSMP=17,167,0,8")
		sendat("AT+CSCS=\"UCS2\"")
	else
		sendat("AT+CSMP=17,11,0,0")
		sendat("AT+CSCS=\"IRA\"")
	end
	for s1 in string.gmatch(nums,"(%d+)/*") do
		vprint("s1", s1)
		if cod == "1" then
			s1 = Str2UCS2(s1)
		end
		sendat("AT+CMGS=\"" .. s1 .. "\"")
	end
end

function sendres(id,res)
	if Lib.linklist[id] == nil then
		vprint("[sendres]: link null ",id)
		return
	end

	Lib.linklist[id].listener.notify(res)
end

function recv(id,len,data)
	if Lib.linklist[id] == nil then
		vprint("[recv]: link null ",id)
	end

	Lib.linklist[id].listener.recv(data)
end

function StartTCPTimer(id)
	--vprint("start tcptimer", id, t.tcplen)
	if id == p.CS then
		rtos.timer_stop(t.tcpCMCC)
		rtos.timer_start(t.tcpCMCC, t.tcplen)
	elseif id == p.AS then
		rtos.timer_stop(t.tcpAir)
		rtos.timer_start(t.tcpAir, t.tcplen)
	end
end

local function SetSleepBgn(r)
	if bat.chg then
		c.gprsact = c.gen
		vprint("SetSleepBgn", c.gprsact,r)
	end
end

local function IsGPRSConn(id)
	return Lib.linklist[id].state == "CONNECTED"
end

local function TermStateEqu(state)
	return a.term == state
end

local function TermStateTrans(state)
	a.term = state
end

local function SendUART1(str)
	vprint("uart1",str)
	uart.write(1, str)
end

function linkwrite(id)
	if Lib.linklist[id].state ~= "CONNECTED" then
		uart.write(uart.ATC,"\027")
		rtos.timer_start(t.atrsp, t.atrsplen)
		return
	end
	local s = table.remove(Lib.linklist[id].sendq,1)

	s = s or ""

	Lib.linklist[id].CurTr = GetCurTr(id,s)
	p.lastdata = s
	vprint("gprsdata",id,Lib.linklist[id].CurTr,s)
	uart.write(uart.ATC,s,"\026")
	rtos.timer_start(t.atrsp, t.atrsplen)
	StartTCPTimer(id)
	if id == p.CS and Lib.linklist[id].CurTr ~= 2 and Lib.linklist[id].CurTr ~= 3 then
		SetSleepBgn(1)
	end
end

function ResetCmd()
	Lib.atrsp.ok = nil
	Lib.atrsp.line = nil
	Lib.currcmd = nil
	Lib.cmdtype = nil
	Lib.cmdprefix = nil
end

local function LinkIdle(id)
	local i1
	if Lib.currcmd == nil then
		return false
	end
	i1 = smatch(Lib.currcmd,"AT%+CIPSEND=(%d)")
	if i1 == nil then
		return false
	end
	if tonumber(i1) == id then
		return true
	end
	return false
end

function TCPTimeout(id)
	vprint("tcptimeout", id)
	if u.LuaState > 0 then
		LaterRestart()
	end
	if LinkIdle(id) then
		ResetCmd()
	end
	u.LuaState = 0
	LaterRestart()
	--disconnect(id)
end

function TCPCMCCTimeout()
	TCPTimeout(p.CS)
end

function TCPAirTimeout()
	TCPTimeout(p.AS)
end

function setupIP()
	if Lib.ipstatus == "IP INITING" then
		return
	end

	vprint("setupip.status:",Lib.ipstatus)

	if not p.GprsSucc then
		vprint("setupip: wait cgatt")
		return
	end

	Lib.ipstatus = "IP INITING"

	sendat("AT+CIPMUX=1")
	sendat("AT+CSTT=\"CMNET\"")
	sendat("AT+CIICR")
	sendat("AT+CIFSR")
	sendat("AT+CIPHEAD=1")
	sendat("AT+CIPQSEND=0")
	sendat("AT+CIPSTATUS")
end

function setIPStatus(status)
	if Lib.ipstatus ~= status then
		Lib.ipstatus = status
		if Lib.ipstatus == "IP PROCESSING" then
			-- ip running.
		elseif Lib.ipstatus == "IP STATUS" then
			connectAll()
		elseif Lib.ipstatus == "IP INITIAL" then
			setupIP()
		else
			sendat("AT+CIPSHUT")
			sendat("AT+CIPSTATUS")
		end
	end
	vprint("ipstatus:",status, Lib.ipstatus)
end

local function ChgReadGps(v)
	rtos.timer_stop(t.gps)
	t.gpslen = v
	rtos.timer_start(t.gps,t.gpslen)
end

local function GpsLowPow()
	local rxm = "B5620241080000000000020000004D3B"
	uart.write(0,Hexs2Str(rxm))
end

local function GpsNormPow()
	uart.write(0,Hexs2Str("FF"))
end

local function SleepGPS()
	--GpsLowPow()
	pio.pin.setlow(IO.gps)
	uart.close(0)
	rtos.sleep(400)
	rtos.timer_stop(t.gps)
	gps.wake = 0
	pmd.sleep(1)
	gps.open = false
	if gps.state == 1 then
		gps.state = 2
	end
	gps.spd = 0
	gps.findall = false
	gps.satenum = 0
	gps.gpssn = 0
	vprint("gps sleep")
end

local function WakeGPS(iswake)
	if p.pinlock then
		return
	end
	pmd.sleep(0)
	pio.pin.sethigh(IO.gps)
	uart.sleep(200)
	uart.setup(0,9600,8,uart.PAR_NONE,uart.STOP_1)
	uart.sleep(200)
	--GpsNormPow()
	ChgReadGps(1000)
	iswake = iswake or false
	if iswake then
		gps.wake = 0
	else
		gps.wake = c.gen
	end
	gps.open = true
	vprint("gps wake")
end

local function QueryNet()
	if p.GprsSucc or IsDSleep() or p.FastNum > t.NoGprs then
		t.querylen = 120*1000
	else
		t.querylen = 2000
		p.FastNum = p.FastNum + 1
	end
	if not TermStateEqu("WN") then
		rtos.timer_start(t.query, t.querylen)
	end

	if IsDSleep() then
		return
	end

	if p.GprsSucc and (Lib.ipstatus == nil or Lib.ipstatus == "IP INITING") then
		setupIP()
		return
	end

	sendat("AT+CGATT?")
	sendat("AT+CSQ")
	sendat("AT+CREG?")
	if p.GprsSucc then
		--sendat("AT+CENG?")
	end
end

function hex2int(s)
	local len1 = string.len(s)
	local i = 0
	local j = 0
	local char1,char2
	local s = string.upper(s)
	local map = {["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["0"]=0,
		      ["A"]=10,["B"]=11,["C"]=12,["D"]=13,["E"]=14,["F"]=15}
	for i =1,len1 do
		j = j+map[string.sub(s, i,i)]*16^(len1-i)
	end
	return j
end

function Hexs2Str(str)
	local i,j
	local s1 = ""
	for i=1,string.len(str),2 do
	    j = hex2int(string.sub(str,i,i+1))
	    s1=s1..string.char(j)
	end
	return s1
end

function hex2ascii(str)
	local rltstr = ""
	local len1 = string.len(str)
	local i = 1
	local val,val_l,val_h
	local map1 = {[1]="1",[2]="2",[3]="3",[4]="4",[5]="5",[6]="6",[7]="7",[8]="8",[9]="9",[0]="0",[10]="A",[11]="B",[12]="C",[13]="D",[14]="E",[15]="F"}

	while i <= len1 do
       i,val = pack.unpack(str,"=b1",i)
	   val_l = bit.band(val,0x0F)
	   val_h = bit.rshift(val,4)
	   rltstr = rltstr .. map1[val_h] .. map1[val_l]
	   i = i + 1
	end
	return rltstr
end

local function setnetworkstatus(status)
	local lac,ci,t
	vprint("network:",status)

	t = smatch(status,"%d,(%d)")
	if t == nil then
		t = smatch(status,"(%d)")
		if t ~= nil then
			p.GsmSucc = false
			return
		end
	end
	if t ~= "1" and t ~= "5" then
		p.GsmSucc = false
	else
		if not p.GsmSucc then
			p.GsmSucc = true
		end
		lac,ci = smatch(status,"%d,\"(%x+)\",\"(%x+)\"")
		lac = hex2int(lac)
		ci = hex2int(ci)
		if lac ~= p.lac or ci ~= p.ci then
			p.lac = lac
			p.ci = ci
			vprint("CELL",p.lac,p.ci)
			cell.nid[0] = p.lac
		end
	end
end

local function setsimstatus(status)
	if status == "NOT INSERTED" then
		if p.ExitFly then
			p.ExitFly = false
			return
		end
		LaterRestart(600000)
	elseif status == "READY" then
		sendat("AT+CIMI")
	end
end

--at
function exeat()
	if Lib.currcmd ~= nil then return end

	if #atqueue == 0 then return end

	local cmd = table.remove(atqueue,1)

	if cmd == "AT+CGSN" or cmd == "AT+CIMI" or cmd == "AT+WISN?" or cmd == "AT+VER" then
		Lib.cmdtype = 1
	elseif cmd == "AT+CSQ" or cmd == "AT+CGATT?" or cmd == "AT+CBC" then
		Lib.cmdtype = 2
		Lib.cmdprefix = smatch(cmd,"AT(\+%u+)")
	elseif cmd == "AT+CIFSR" or smatch(cmd,"AT%+CIPSEND") or smatch(cmd,"AT%+CIPCLOSE") then
		Lib.cmdtype = 10
	else
		Lib.cmdtype = 0
	end

	print("sendat:",cmd)

	Lib.currcmd = cmd

	uart.write(uart.ATC,cmd.."\r")
	rtos.timer_start(t.atrsp, t.atrsplen)
end

function sendat(cmd)
	if cmd == nil or string.len(cmd) == 0 then return end

	table.insert(atqueue,cmd)

	if not Lib.atproc then
		exeat()
	end
end

local function AirA2(s)
	p.smsd = s
end

local declaredNames = {_ = true}
function declare (name, initval)
     declaredNames[name] = true
end

setmetatable(_G, {
    __newindex = function (t, n, v)
    if not declaredNames[n] then
       error("attempt to write to undeclared var. "..n, 2)
    else
       rawset(t, n, v)
    end
end,
    __index = function (_, n)
    if not declaredNames[n] then
		error("attempt to read undeclared var. "..n, 2)
    else
       return nil
    end
end,
})

local mtnilerr = {
	__index = function(t,k)
		error("attemp to read key " .. k)
	end,
	__newindex = function(t,k)
		error("attemp to write key " .. k)
	end
}

-- global->local
local sbyte = string.byte
local schar = string.char

declare("SetAllTimer")
declare("IsSleep")
declare("SysWakeup")
declare("EntSleep")
declare("ResetSys")
declare("processUART1")
declare("ProcessGenTimer")
declare("openGPS")
declare("closeGPS")
declare("vprint")
declare("GetLog")
declare("PushAir")

local function GetNumFromUCS2(s)
	local s1 = ""
	local t
	for i =1,string.len(s),4 do
		t = string.sub(s,i+3,i+3)
		if t ~= "B" then
			s1 = s1 .. t
		end
	end
	return s1
end

local function Openwd()
	pio.pin.close(IO.wd)
	pio.pin.setdir(pio.OUTPUT,IO.wd)
end

local function CloseWd()
	pio.pin.close(IO.wd)
	pio.pin.setdir(pio.INPUT,IO.wd)
end

local function handleURC(data)
	if data == "RDY" then
		-- sendat(table.remove(atqueue,1))
	elseif data == "SMS READY" then
		-- sms
	elseif smatch(data,"%+CMT: ") == 1 then
		vprint("sms rec")
		p.smsrec = smatch(data,"%+CMT: \"(%w+)\"")
		p.smsrec = GetNumFromUCS2(p.smsrec)
	elseif string.upper(data) == "LOG" then
		GetLog()
	elseif string.upper(data) == "LINFO" then
		GetLInfo()
	elseif string.upper(data) == "006B0073007A00640067006A" then   --KSZDGJ
		p.ShkQuick = true
	elseif string.upper(data) == "0075007000700072006F0067" then -- upporg
		ResetSys()
	elseif smatch(data,"SIM PIN") then
		sendat("AT+CPIN=\"2973\"")
	elseif smatch(data,"STATE: ") == 1 then
		setIPStatus(string.sub(data,8,-1))
	elseif smatch(data,"C: ") == 1 then
		linkstatus(data)
	elseif p.smsrec ~= nil then
		vprint("sms data",data)
		AirA2(data)
		PushAir("A2")
	else
		local lid,lstate = smatch(data,"(%d),[ ]*([CLOSEDCONNECTOKFAIL ]+)")
		local urcp,prefix,urcv = smatch(data,"(%+*[%w]+),*([^:]*): *(.*)")

		if lid then
			lid = tonumber(lid)
			setlinkres(lid,lstate)
		elseif urcp == "+CPIN" then
			setsimstatus(urcv)
		elseif urcp == "+CREG" then
			setnetworkstatus(urcv)
		elseif urcp == "+CLIP" then
			local callnum = smatch(urcv,"\"(%d+)\"")
		elseif urcp == "STATE" then
			setIPStatus(urcv)
		elseif urcp == "+PDP" then
			sendat("AT+CIPSTATUS")
		elseif urcp == "+IPD" or urcp == "+RECEIVE" then
			local p1,p2 = smatch(prefix,"(%d),(%d+)")
			Lib.urcrcvd.lid = tonumber(p1)
			Lib.urcrcvd.len = tonumber(p2)
		end
	end
end

local function RssiSleep()
	if ACC.s == 0 or not IsNSleep() or tonumber(p.rssi) >= p.weakrssi then
		p.nrssic = c.gen
	end
end

local function handleRSP()
	if Lib.atrsp.ok then
		local line = Lib.atrsp.line
		line = line or ""

		if Lib.currcmd == "AT+CGSN" then
			p.IMEI = line
			vprint("imei:",p.IMEI)
			if TermStateEqu("WN") or p.ftsn == 1 then
				local y = "\r\nAT+CGSN\r\n" .. p.IMEI .. "\r\nOK\r\n"
				SendUART1(y)
				p.ftsn = 0
			end
		elseif Lib.currcmd == "AT+WISN?" then
			atom.sn = line
			vprint("sn:",atom.sn)
			if TermStateEqu("WN") or p.ftsn == 1 then
				local y = "\r\nAT+WISN?\r\n" .. atom.sn .. "\r\nOK\r\n"
				SendUART1(y)
				p.ftsn = 0
			end
		elseif Lib.currcmd == "AT+CIMI" then
			p.IMSI = line
			vprint("imsi:",p.IMSI)
			p.MCC = string.sub(p.IMSI,1,3)
			p.MNC = string.sub(p.IMSI,4,5)
		elseif Lib.currcmd == "AT+CGATT?" then
			local c = smatch(line,"+CGATT: (%d)")
			vprint("cgatt:",c)
			if c == "1" then
				p.GprsSucc = true
			end
		elseif Lib.currcmd == "AT+VER" then
			u.lod = line
			vprint("SOFTVERSION", u.lod)
			if TermStateEqu("WN") then
				local y = "\r\nAT+VER\r\n" .. u.lod .. "," .. u.LUAVER .."\r\nOK\r\n"
				SendUART1(y)
			end
		elseif Lib.currcmd == "AT+CIFSR" then
			--localIP = line
		elseif Lib.currcmd == "AT+CSQ" then
			p.rssi = smatch(line,"+CSQ: (%d+)")
			RssiSleep()
		end
	end

	ResetCmd()
end

local function handleATC(data)
	vprint("atc:",data)

	if Lib.urcrcvd.len ~= 0 then
		Lib.urcrcvd.data = Lib.urcrcvd.data..data
		if string.len(Lib.urcrcvd.data) >= Lib.urcrcvd.len then
			print("recvdata", Lib.urcrcvd.len, string.len(Lib.urcrcvd.data))
			if string.len(Lib.urcrcvd.data) > Lib.urcrcvd.len then
				Lib.urcrcvd.data = string.sub(Lib.urcrcvd.data,1,Lib.urcrcvd.len)
			end
			recv(Lib.urcrcvd.lid,Lib.urcrcvd.len,Lib.urcrcvd.data)
			Lib.urcrcvd.lid = 0
			Lib.urcrcvd.len = 0
			Lib.urcrcvd.data = ""
		end
		return
	end

	if smatch(data,"\r\n",-2) then
		data = string.sub(data,1,-3)
	end

	if Lib.currcmd == nil then
		handleURC(data)
		return
	end

	local isURC = false

	if smatch(data,"OK") or data == "ERROR" or data == "> " then
		rtos.timer_stop(t.atrsp)
	end

	if data == "OK" or data == "SHUT OK" then
		Lib.atrsp.ok = true
			if smatch(Lib.currcmd, "AT%+WIMEI=") and data == "OK" then
				SendUART1("\r\nOK\r\n")
			elseif smatch(Lib.currcmd, "AT%+WISN=") and data == "OK" then
				SendUART1("\r\nOK\r\n")
			end
	elseif data == "ERROR" or data == "NO ANSWER" or data == "NO DIALTONE" then
		Lib.atrsp.ok = false
	elseif data == "> " then
		local linkid = smatch(Lib.currcmd,"AT%+CIPSEND=(%d)")

		if linkid then
			linkid = tonumber(linkid)
			linkwrite(linkid)
		elseif smatch(Lib.currcmd,"AT%+CMGS") == 1 and p.smsdata ~= nil then
			uart.write(uart.ATC,p.smsdata,"\026")
			sendat("AT+CSCS=\"UCS2\"")
		end
	else
		if Lib.cmdtype == 0 then
			isURC = true
		elseif Lib.cmdtype == 1 then
			local p1,_,s = string.find(data,"([%w_]+)")
			if Lib.atrsp.line == nil and p1 == 1 then
				Lib.atrsp.line = s
			else
				isURC = true
			end
		elseif Lib.cmdtype == 2 then
			if Lib.atrsp.line == nil and smatch(data, Lib.cmdprefix) then
				Lib.atrsp.line = data
			else
				isURC = true
			end
		elseif Lib.cmdtype == 10 then
			if Lib.currcmd == "AT+CIFSR" then
				local s = smatch(data,"%d+%.%d+%.%d+%.%d+")
				if s~= nil then
					Lib.atrsp.line = s
					Lib.atrsp.ok = true
				else
					isURC = true
				end
			elseif smatch(Lib.currcmd,"AT%+CIPSEND") then
				local lid,res = smatch(data,"(%d),([%w :]+)")

				if lid and res then
					if res == "SEND OK" or res == "SEND FAIL" or smatch(res,"TCP ERROR") or smatch(res,"UDP ERROR") then
						Lib.atrsp.ok = true
						lid = tonumber(lid)
						sendres(lid,res)
					else
						isURC = true
					end
				else
					isURC = true
				end
			elseif smatch(Lib.currcmd,"AT%+CIPSEND") or smatch(Lib.currcmd,"AT%+CIPCLOSE") then
				local lid,lstate = smatch(data,"(%d),([%w ]+)")
				Lib.atrsp.ok = true
				lid = tonumber(lid)
				setlinkres(lid,lstate)
			end
		else
			vprint("ERROR.Lib.cmdtype:",Lib.cmdtype)
			isURC = true
		end
	end

	if isURC then
		handleURC(data)
	elseif Lib.atrsp.ok ~= nil then
		handleRSP()
	end
end

local function atcreader()
	local readLoop = true
	local s

	Lib.atproc = true
	while readLoop do
		s = uart.read(uart.ATC, "*l", 0)

		if s == "\r\n" then
		elseif string.len(s) ~= 0 then
			handleATC(s)
		else
			readLoop = false
		end
	end
	Lib.atproc = false
	exeat()
end

--timer
local function settimer(id,fnc)
	if timer[id] ~= nil then
		vprint("settimer: not null",id)
		return
	end
	timer[id] = fnc
end

local function handleTimeout(id)
	--print("timeout:",id)
	if timer[id] ~= nil then
		timer[id]()
	end
end

local function sysinit()
	uart.setup(uart.ATC, 0, 0, uart.PAR_NONE, uart.STOP_1)
	uart.setup(1, 115200, 0, uart.PAR_NONE, uart.STOP_1)
	uart.setup(3,921600,8,uart.PAR_NONE,uart.STOP_1,2)
	--pmd.init(IO.pmd)
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
	else
		local err = f:read("*a")
		vprint("\r\nlua.lasterr:",err)
		f:close()
		-- sendat("AT+AMFGD=\"luaerrinfo.txt\",0")
	end

	f = io.open(u.zf,"r")
	if f ~= nil then
		local sizef = f:seek("end")
		vprint("luazipsize",sizef)
		f:close()
	else
		vprint("no luazip")
	end
end

local function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function SetACCLock()
    if cP["ACCLOCK"] == "1" then
		vprint("ACCLOCK",cP["ACCLOCK"],"GPIO1 enabled!")
		local t = pio.pin.getval(IO.acc)
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
		pio.pin.close(IO.acc)
	end
end

local function FacSet()
	AirInit()
	RestorePara()
	StateInit()
	TimerInit()
	CounterInit()
	CellInit()
	pInit()
	AtomInit()
	LuaUpInit()
	BatInit()
	GpsInit()
	ShakeInit()
	AcCInit()
	SetACCLock()
	UpdateA1Len()
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

local function AppendTxt(f,v)
	local file = io.open(f,"r")
	if file == nil then
		print("new file", f)
		file = io.open(f,"w")
	else
		file:close()
		file = io.open(f,"a")
	end
	if file == nil then
		print("open file fail", f)
		return
	end
	file:write(v)
	file:close()
end

local function FileSize(f)
	local file = io.open(f,"r")
	if file == nil  then
		return 0
	end
	local i =  file:seek("end")
	file:close()
	return i
end

local function ClearPreData()
	os.remove(Log.fconfig)
	os.remove(Log.freset)
	os.remove(Log.fconfig1)
	os.remove(Log.freset1)
end

local function WriteConfig()
	local config_w = air.server
	vprint("config_w",config_w)
	WriteTxt(Log.fconfig2,config_w)
end

local function ReadConfig()
	local config_r = ReadTxt(Log.fconfig2)
	if config_r == nil then
		vprint("read config txt err")
		return
	end
	air.server= config_r
end

local function WriteResetC()
	local config_w = air.port .. "," .. air.RepLen .. "," .. air.gpsOn .. "," .. air.accHeart .. "," .. air.chgSleep .. "," .. air.chgHeart
		config_w = config_w .. "," .. air.batHeart .. "," .. air.batSleep .. "," .. ACC.valid .. "," .. air.debug .. "," .. p.resettimes
	vprint("WriteResetC", config_w)
	WriteTxt(Log.freset2,config_w)
end

local function ReadResetC()
	local config_r = ReadTxt(Log.freset2)
	if config_r == nil then
		vprint("read reset txt err")
		return
	end
	local ap,r1,go,ah,cs,ch,bh,bs,av,db,rt
	ap,r1,go,ah,cs,ch,bh,bs,av,db,rt = smatch(config_r, "(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
	if ap == nil or r1 == nil or go == nil or ah == nil or cs == nil or ch == nil or bh == nil or bs == nil or av == nil or db == nil or rt == nil then
		vprint("error resetc")
		return
	end
	air.port = tonumber(ap)
	air.RepLen = tonumber(r1)
	air.gpsOn = tonumber(go)
	air.accHeart = tonumber(ah)
	air.chgSleep = tonumber(cs)
	air.chgHeart = tonumber(ch)
	air.batHeart = tonumber(bh)
	air.batSleep = tonumber(bs)
	ACC.valid = tonumber(av)
	air.debug = tonumber(db)
	p.resettimes = tonumber(rt)
	if ACC.valid == 0 then
		gps.spdwake = 3
	end
	vprint("read resetC", config_r,"rlt", ap,r1,go,ah,cs,ch,bh,bs,av,db,rt)
end

local function WriteLuaVer()
	WriteTxt(Log.fver,u.LUAVER)
end

local function ReadLuaVer()
	CloseWd()
	local f1 = true
	local config_r = ReadTxt(Log.fver)
	if config_r == nil then
		vprint("read ver err")
	elseif config_r == u.LUAVER then
		f1 = false
	end
	if f1 then
		WriteLuaVer()
		ClearPreData()
		WriteConfig()
		WriteResetC()
	else
		ReadConfig()
		ReadResetC()
	end
	Openwd()
end

local error, assert, setmetatable, tostring = error, assert, setmetatable, tostring

local function open_zip(filename, mode)
	mode = mode or 'r'
	local r = mode:find('r', 1, true) and true
	local w = mode:find('w', 1, true) and true
	local level = -1

	local lstart, lend = mode:find('%d')
	if (lstart and lend) then
		level = mode:sub(lstart, lend)
	end

	if (not (r or w)) then
		error('file open mode must specify read or write operation')
	end

	local f, z,fmode

	local mt = {
		__index = {
			read = function(self, ...)
				return z:read(...)
			end,
			write = function(self, ...)
				return z:write(...)
			end,
			seek = function(self, ...)
				error 'seek not supported on gzip files'
			end,
			lines = function(self, ...)
				return z:lines(...)
			end,
			flush = function(self, ...)
				return z:flush(...) and f:flush()
			end,
			close = function(self, ...)
				return z:close() and f:close()
			end,
		},
		__tostring = function(self)
			return 'gzip object (' .. mode .. ') [' .. tostring(z) .. '] [' .. tostring(f) .. ']'
		end,
	}

	if r then
		fmode = 'rb'
	else
		fmode = 'wb'
	end
	f = io.open(filename, fmode)
	if f == nil then
		return
	end
	if r then
		z = zlib.inflate(f)
	else
		z = zlib.deflate(f, level, nil, 15 + 16)
	end
	if z == nil then
		return
	end

	return setmetatable({}, mt)
end

local function ReadZipStatus()
	local s = ReadTxt(Log.stname)
	if s == nil then
		Log.znum = 0
		Log.curnum = 0
		return
	end
	local n,i
	n,i = smatch(s,"(%d+),(%d+)")
	if n == nil or i == nil then
		Log.znum = 0
		Log.curnum = 0
		return
	end
	Log.znum = tonumber(n)
	Log.curnum = tonumber(i)
end

local function ZipLog()
	if Log.curnum == nil or Log.znum == nil then
		return
	end
	Log.curnum = Log.curnum + 1
	if Log.curnum > Log.TotalNum then
		Log.curnum = 1
	end
	if Log.znum < Log.TotalNum then
		Log.znum = Log.znum + 1
	end
	local zname = "/RecDir/zlog" .. Log.curnum .. ".zip"
	print("zipfile", zname)
	local inf = io.open(Log.fname, "rb")
	local outf = open_zip(zname, "wb9")

	local buf
	while true do
		buf = inf:read(500)
		if buf == nil then break end
		outf:write(buf)
	end
	inf:close()
	outf:close()
	return zname
end

--[[
如果输出的文件大于100K，或者超过了10分钟， 就把log压缩到文件中，同时把log文件清除。
log压缩文件名称：zlogxxx.zip, 其中xxx为序号，最大支持100个文件
非压缩文件的名称:log.txt
记录压缩文件数量和当前序号
]]

local function SaveLog(s)
	AppendTxt(Log.fname,s)
	local fsize = FileSize(Log.fname)
	c.gen = c.gen or 0
	if (c.gen % 20) == 0 then
		print("logsave", c.gen, fsize, Log.sTime, Log.znum, Log.curnum)
	end
	if fsize > Log.sizeL or (c.gen - Log.sTime) > Log.ztime then
		Log.sTime = c.gen
		local zfn = ""
		print("ziplogb", Log.znum, Log.curnum, rtos.tick())
		CloseWd()
		zfn = ZipLog()
		Openwd()
		if zfn == nil then
			return
		end
		print("ziploga", Log.znum, Log.curnum, rtos.tick(), zfn, FileSize(zfn))
		WriteTxt(Log.stname, Log.znum .. "," .. Log.curnum)
		WriteTxt(Log.fname,"\n")
	end
end

local function concatstr(arg)
	local t1 = {}
	for i,s in ipairs(arg) do
		if type(s) == "boolean" then
			s = tostring(s)
		end
		table.insert(t1,tostring(s))
	end
	table.insert(t1,"\n")
	local p = table.concat(t1," ")
	return p
end

local function printuart3(s)
	uart.write(3,s)
end

local function OutputZiplog(v)
	local fn = "/RecDir/zlog" .. v .. ".zip"
	local flen = FileSize(fn)
	if flen <= 0 then
		print("fsize err ",fn, flen)
		return
	end
	local outf = open_zip(fn)
	if outf == nil then
		print("failed to open ",fn)
		return
	end

	local buf
	if false then
		while true do
			buf = outf:read(500) -- 100 "*a" "*l"
			if buf == nil then
				break
			end
			print("HisLog",v,buf)
		end
	else
		printuart3("hislog begin" .. v)
		for s in outf:lines() do
			printuart3(s)
			rtos.sleep(20)
		end
		printuart3("hislog end" .. v)
	end
	outf:close()
end

local function GetLInfo()
	local s1 = "F"
	if Log.OutGoing then
		s1 = "T"
	end
	printuart3("loginfo:"..Log.znum.." " .. Log.curnum.." " .. s1)
	if Log.OutGoing then
		return
	end
	for i = 1, Log.znum do
		printuart3("zipsize:" .. i .. " " .. FileSize("/RecDir/zlog" .. i .. ".zip"))
	end
end

local function GetOneLog(v)
	GetLInfo()
	if Log.OutGoing then
		print("rec getonelog when ongoing")
		return
	end
	if Log.curnum <= 0 then
		return
	end
	Log.OutGoing = true
	CloseWd()
	if v <= 0 or v > Log.znum then
		print("error log req", Log.znum, Log.curnum, v)
		return
	end
	OutputZiplog(v)
	Log.OutGoing = false
	Openwd()
end

local function GetLog()
	GetLInfo()
	if Log.OutGoing then
		print("rec getlog when ongoing")
		return
	end
	if Log.curnum <= 0 then
		return
	end
	Log.OutGoing = true
	CloseWd()
	local index
	if Log.znum < Log.TotalNum then
		index = 1
	else
		index = Log.curnum + 1
		if index > Log.TotalNum then
			index = 1
		end
	end
	for i = 1, Log.znum do
		print("beginlogfile:" .. index .. " " .. rtos.tick())
		OutputZiplog(index)
		print("endlogfile:" .. index .. " " .. rtos.tick())
		index = index + 1
		if index > Log.TotalNum then
			index = 1
		end
	end
	Log.OutGoing = false
	Openwd()
end

function vprint(...)
	if Log.OutGoing then
		return
	end
	local p = concatstr(arg)
	print(p)
	SaveLog(p)
end

local function SaveTime(s)
	local y,m,d,nt,c
    y,m,d,nt = smatch(s,"%[(%d+)-(%d+)-(%d+)%s+(%d+:%d+:%d+),S1,%d")
	if y ~= nil and nt ~= nil then
		c = "AT+CCLK=\"" .. string.sub(y,3,4) .. "/" .. string.format("%02d",m) .. "/" .. string.format("%02d",d) .. "," .. nt .. "\"\r"
		sendat(c)
	end
end

local function handleuart1()
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

local function LightGsm(t)
	if BT == "9321A15" then
		if t then
			pmd.ldoset(1, pmd.LDO_LCD)
		else
			pmd.ldoset(0, pmd.LDO_LCD)
		end
	else
		if t then
			pio.pin.sethigh(IO.gsmlt)
		else
			pio.pin.setlow(IO.gsmlt)
		end
	end
end

local function GsmWorkLight()
	if BT ~= "9321A15" then
		LightGsm(p.GprsSucc)
		return
	end
	local t = false
	if c.gen > 2 then
		t = bat.chg
	end
	LightGsm(t)
end

local function LightGps(t)
	if BT == "9321A15" then
		if t then
			pmd.ldoset(1, pmd.LDO_KEYPAD)
		else
			pmd.ldoset(0, pmd.LDO_KEYPAD)
		end
	else
		if t then
			pio.pin.sethigh(IO.gpslt)
		else
			pio.pin.setlow(IO.gpslt)
		end
	end
end

local function GpsWorkLight()
	if not gps.open then
		LightGps(false)
		return
	end
	if gps.state == 1 then
		LightGps(true)
		return
	end
	local t = ((c.lt % 2) == 0)
	LightGps(t)
end

local function AllLtOn()
	rtos.timer_stop(t.light)
	LightGsm(true)
	LightGps(true)
end

local function AllLtOff()
	rtos.timer_stop(t.light)
	LightGsm(false)
	LightGps(false)
end

local function EntFlyMode()
	resetlinks()
	p.ExitFly = true
	sendat("AT+CFUN=0")
end

local function ExitFlyMode()
	p.ExitFly = true
	sendat("AT+CFUN=1")
end

function EntSleep()
	if IsSleep() then
		return
	end
	SleepGPS()
	TermStateTrans("SLEEP")

	t.genlen = 20000
	AllLtOff()
	p.SleepC = c.gen
	UpdateA1Len()
	vprint("system sleep")
end

function SysWakeup(t1,r)
	if not IsSleep() or p.pinlock then
		return
	end
	if not bat.chg and r ~= "D" and r ~= "E" then
		vprint("no chg, no wake")
		return
	end
	vprint("system wakeup", r)
	p.WakeReason = r
	t.genlen = 1000
	rtos.timer_stop(t.gen)
	rtos.timer_start(t.gen, t.genlen)
	rtos.timer_start(t.light, t.lightlen)
	t.querylen = 2000
	rtos.timer_stop(t.query)
	rtos.timer_start(t.query, t.querylen)
	WakeGPS(true)
	if Lib.linklist[p.AS].valid and Lib.linklist[p.AS].state == "CONNECTED" then
		PushAir("A1")
	end
	SetSleepBgn(2)
	if IsDSleep() then
		ExitFlyMode()
	end
	Lib.ipstatus = nil
	TermStateTrans("IDLE")
	UpdateA1Len()
end

local function ChgDeal(cur, income)
	vprint("ChgDeal,cur,income",cur,income)
	bat.chg = income
	c.gprsact = c.gen
	if not cur and income then
		bat.lost = 0
		p.statechg = true
		bat.chgrep = false
		if IsSleep() then
			SysWakeup(3,"D")
		end
	elseif cur and not income then
		bat.lost = c.gen
		p.statechg = true
		--第一次变为没有外电，应该唤醒一次，应对剪线告警
		if IsSleep() then
			SysWakeup(3,"E")
		end
	end
	UpdateA1Len()
end

local function ProcessChg(chgmsg)
	if chgmsg.level > 100 then
		return
	end
	if IO.chg == nil then
		ChgDeal(bat.chg, chgmsg.charger)
		bat.chg = chgmsg.charger
	end

	bat.vol = chgmsg.level
	bat.lev = chgmsg.voltage
	if bat.vol > 100 then
		bat.vol = 100
	end
	vprint("chg msg",chgmsg.present,chgmsg.level,chgmsg.voltage,chgmsg.charger,chgmsg.state)
end

function openGPS()
	if gps.open then
		return
	end
	pmd.sleep(0)
	pio.pin.sethigh(IO.gps)
	uart.sleep(200)
	uart.setup(0,9600,8,uart.PAR_NONE,uart.STOP_1)
	gps.open = true
	rtos.timer_start(t.gps,t.gpslen)
	vprint("gps open")
end

function closeGPS()
	if not gps.open then
		return
	end
	rtos.timer_stop(t.gps)
	uart.close(0)
	pio.pin.setlow(IO.gps)
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

local function QueryPara(s1)
end

local function ChangePara(s1)
end

local function GetAllState()
	local s = 0

	if p.dsleep then
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

local function GetSigBat()
	if p.rssi == "0" then
		p.rssi = 15
	end
	local sig = p.rssi/3-1
	if sig < 0 then
		sig = 0
	end
	local b1 = (bat.vol-1)/10
	if b1 < 0 then
		b1 = 0
	end
	local op = string.sub(p.IMSI, 5,5) or 0
	if op == "1" then
		op = 1
	else
		op = 0
	end
	local s1 = 0
	if bat.chg then
		if a.term ~= "SLEEP" then
			if ACC.valid == 1 then
				s1 = 1
			else
				s1 = 2
			end
		else
			if ACC.valid == 1 then
				s1 = 3
			else
				s1 = 4
			end
		end
	end
	local s2 = string.format("%02d",gps.gpssn)
	return gps.satenum .. sig .. b1 .. op .. s1 .. s2
end

local function AirA1()
	local mchg,imei,imsi = 0,0,0
	local s = ""
	local lowb = GetSigBat()
	local tag = p.IMEI
	local u1 = u.LUAVER .. "." .. p.resettimes

	if bat.chg then
		mchg = 1
	end
	if not air.imsisend then
		imsi = p.IMSI
		imei = p.IMEI
	end
	local sk = p.airsk
	if p.WakeReason == 8 and p.airsk == 0 then
		sk = 1
	end
	if p.WakeReason == "F" and gps.spd == 0 then
		gps.spdair = gps.spdwake
	end
	s = tag .. ",1," .. u1 .. "," .. gps.long .. "," .. gps.lati .. "," .. gps.cog .. "," .. gps.spdair .. ","
	s = s .. sk .. "," .. gps.haiba .. "," .. mchg .. "," .. ACC.s .. "," .. lowb .. "," .. imei .. "," .. imsi
	p.airsk = 0
	p.WakeReason = 0
	gps.spdair = 0
	return s
end

local function AirGuard()
	if ACC.s == 0 then
		p.smsd = "64A49632"
	else
		p.smsd = "8BBE9632"
	end
end

local function PackData(s)
	local len1 = string.len(s)
	local id = p.AS
	p.airseq = p.airseq + 1
	if p.airseq > 999 then
		p.airseq = 1
	end
	local s1 = "B" .. string.format("%04d",len1) .. string.format("%03d",p.airseq) ..  s .. "E"
	return s1
end

local function PackHead()
	UpdateTime()
	return "[" .. p.htime .. ",1,V1.0.0,"  ..  atom.sn .. ","
end

local function PackFrame(MT)
	local tag = p.IMEI
	local s1=""

	if "A1" == MT then
		s1 = PackData(AirA1())
	elseif "A2" == MT then
		local num
		if p.smsrec == nil then
			num = "1"
		else
			num = p.smsrec
			p.smsrec = nil
		end
		s1 = PackData(tag .. ",2," .. num ..",1," .. p.smsd)
	elseif "A3" == MT then
		local av,go = "f","f"
		if ACC.valid == 1 then
			av = "t"
		end
		if gps.open then
			go = "t"
		end
		s1 = tag .. ",9," .. air.RepLen .. ":" .. air.gpsOn .. ":" .. air.chgHeart .. ":" .. air.chgSleep .. ":" .. air.batHeart .. ":" .. air.batSleep .. ":" .. air.accHeart
		s1 = s1 .. ":" .. go .. ":" .. c.gen .. ":" .. av .. ":" .. a.term
		s1 = PackData(s1)
	else
	    s1 = ""
	end

	return s1
end

local function RequestFrame(id,MsgType)
	vprint("Msg type", MsgType)

	local gd = PackFrame(MsgType)
	gd = gd or ""
	if gd == "" then
		return
	end
	if id == p.CS then
		gd = PackHead() .. gd
	end
	p.gdata = gd

	send(id, p.gdata)
end

function PushAir(s)
	if IsDSleep() then
		return
	end
	RequestFrame(p.AS,s)
end

local function PushMsg(s)
end

local function CMCCAck(s1)
end

function ResetSys()
	rtos.restart()
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
	curnum, lineno,total,sgv_str = smatch(sg,"$GPGSV,(%d),(%d),(%d+),(.*)*.*")
	if curnum == nil or lineno == nil or total == nil or sgv_str == nil then
	  return
	end

	if tonumber(lineno)== 1  then
	   gps.sates = ""
	end

	s1,c1 = smatch(sgv_str,"^(%d+),%d+,%d+,(%d*)")
	if s1 ~= nil then
        if c1=="" then
	       c1="00"
	    end
		gps.sates = gps.sates .. s1 .. c1 .. " "
		s2,c2 = smatch(sgv_str,"^%d+,%d+,%d+,%d*,(%d+),%d+,%d+,(%d*)")
		if s2~=nil then
          if c2=="" then
		     c2="00"
		  end
	      gps.sates = gps.sates .. s2 .. c2 .." "
		  s3,c3 = smatch(sgv_str,"^%d+,%d+,%d+,%d*,%d+,%d+,%d+,%d*,(%d+),%d+,%d+,(%d*)")
		  if s3~= nil then
		      if c3== "" then
		         c3="00"
			  end
	          gps.sates = gps.sates .. s3 .. c3 .." "
			  s4,c4 = smatch(sgv_str,"^%d+,%d+,%d+,%d*,%d+,%d+,%d+,%d*,%d+,%d+,%d+,%d*,(%d+),%d+,%d+,(%d*)")
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

local function GetVG(A,L)
	local A1,A2,L1,L2,t1
	t1 = string.len(L)
	A1 = string.sub(A,1,4)
	A2 = string.sub(A,5,8).."0"
	L1 = string.sub(L,1,t1-4)
	L2 = string.sub(L,t1-3,t1).."0"
	return A1,A2,L1,L2
end

local function GetD(I)
	return abs(gps.A[I],gps.A[I-1]) + abs(gps.L[I],gps.L[I-1])
end

local function PushGps(A,L)
	--vprint("pushgps", A, L)
	table.insert(gps.A, A)
	table.insert(gps.L, L)
	gps.dataN = gps.dataN + 1
	if gps.dataN > gps.QueL then
		table.remove(gps.A, 1)
		table.remove(gps.L, 1)
		local a1,a2,I
		I = (gps.QueL+1)/2
		a1 = GetD(I) + GetD(I+1)
		a2 = 0
		for i = 2, gps.QueL do
			if i ~= I and i ~= (I+1) then
				a2 = a2 + GetD(i)
			end
		end
		if a2 < gps.errL*(gps.QueL-2) and a1 > gps.errD then
			vprint("gps run", gps.A[I], gps.L[I])
			gps.A[I] = gps.A[I+1]
			gps.L[I] = gps.L[I+1]
		end
		return GetVG(gps.A[I], gps.L[I])
	end
	return GetVG(A,L)
end

local function FilterGps(LA,RA,LL,RL)
	--vprint("gps data", LA,RA,LL,RL,gps.dataN,c.gen,gps.cgen)

	if (c.gen - gps.cgen) > 10 then
		vprint("longtime no gps",c.gen,gps.cgen)
		EmptyGpsQue()
	end

	if string.len(LA) ~= 4 or (string.len(LL) ~= 5 and string.len(LL) ~= 4) then
		vprint("err LA or LL", LA, LL)
		return
	end

	if string.len(RA) < 4 then
		RA = RA .. string.rep("0", 4 - string.len(RA))
	end
	if string.len(RL) < 4 then
		RL = RL .. string.rep("0", 4 - string.len(RL))
	end
	local A = LA .. string.sub(RA,1,4)
	local L = LL .. string.sub(RL,1,4)
	A = tonumber(A) or 0
	L = tonumber(L) or 0

	gps.cgen = c.gen
	return PushGps(A, L)
end

local function processGpsData(s)
	local latti,lattir,longti,longtir,spd1,cog1,gpsfind
	local sgps = s
	local numofsate

	if sgps == "" or sgps == nil then
		return
	end

	gps.find = ""

	if smatch(sgps, "$GPGGA") then
		local hh
		latti,lattir,longti,longtir,gpsfind,numofsate,hh = smatch(sgps,"$GPGGA,%d+%.%d+,(%d+)%.(%d+),N,(%d+)%.(%d+),E,(%d),(%d+),.*,.*,M,(%d+)")
		if (gpsfind == "1" or gpsfind == "2" or gpsfind == "4") and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil then
			gps.find = "S"
			if hh ~= nil then
				gps.haiba = hh
			end
		end
	elseif smatch(sgps, "$GPRMC") then
		gpsfind,latti,lattir,longti,longtir,spd1,cog1 = smatch(sgps,"$GPRMC,%d+%.%d+,(%w),(%d+)%.(%d+),N,(%d+)%.(%d+),E,(.-),(.-),")
		if gpsfind == "A" and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil  then
			gps.find = "S"
		end
	elseif smatch(sgps,"$GPGSV") then
		local sn1
		numofsate,sn1 = smatch(sgps,"$GPGSV,%d+,%d+,(%d+),%d+,%d+,%d+,(%d+)")
		if sn1 ~= nil then
			sn1 = tonumber(sn1)
			if sn1 > gps.gpssn and sn1 < 60 then
				gps.gpssn = sn1
			end
		end
		GetGpsStrength(sgps)
	end

	numofsate = numofsate or "0"
	numofsate = tonumber(numofsate)
	if numofsate > 9 then
		numofsate = 9
	end
	if numofsate > 0 then
		gps.satenum = numofsate
	end

	if spd1 ~= nil and spd1 ~= "" then
		local r1,r2
		r1,r2 = smatch(spd1, "(%d+)%.*(%d*)")
		if r1 ~= nil then
			gps.spd = tonumber(r1)
			if gps.spd > gps.spdwake then
				gps.spdc = c.gen
				gps.spdair = gps.spd
			end
		end
	end
	if cog1 ~= nil and cog1 ~= "" then
		local r1,r2,r3
		r1,r2 = smatch(cog1, "(%d+)%.*(%d*)")
		if r1 ~= nil then
			gps.cog = tonumber(r1)
			r3 = abs(gps.cog, gps.lastcog)
			if r3 > 45 and r3 < 135 then
				gps.lastcog = gps.cog
				gps.cogchange = true
			else
				gps.cogchange = false
			end
		end
	end

	if gps.find ~= "S" then
		return
	end

	local LA, RA, LL, RL = FilterGps(latti,lattir,longti,longtir)
	--vprint("filterg", LA, RA, LL, RL)
	if LA == nil or RA == nil or LL == nil or RL == nil then
		return
	end

	gps.lati, gps.latt_m  = GetGpsMilli(LA, RA)
	gps.long, gps.longt_m = GetGpsMilli(LL, RL)
	gps.long = gps.long or 0
	gps.lati = gps.lati or 0
end

local function DiffOfLoc(latti1, longti1, latti2, longti2)
	local R1,R2
	local diff,d1=0,0
	R1=smatch(latti1,"%d+%.(%d+)")
	R2=smatch(latti2,"%d+%.(%d+)")
	if R1 == nil or R2 == nil then
	  return 0
	end

	R1 = string.sub(R1,1,5)
	R2 = string.sub(R2,1,5)
	d1 = tonumber(R1)-tonumber(R2)
	d1 = d1*111/100
	diff =  d1* d1

	R1=smatch(longti1,"%d+%.(%d+)")
	R2=smatch(longti2,"%d+%.(%d+)")
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
		PushMsg("T14")
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

local function ShakeProcess()
	PushShake()
	if IsShkMeet() then
		SetSleepBgn(3)
		vprint("shk.shake", shk.shake)
		if IsSleep() then
			SysWakeup(3,8)
		end
		if shk.shake > 2^29 then
			shk.shake = c.gen
		end
	end
end

local function SimShkInt()
	p.airsk = p.airsk + 1
	p.skh = 1
	p.nrssic = c.gen
	ShakeProcess()
end

local function ACCInt(v)
	vprint("acc",ACC.level,v)
	SetSleepBgn(7)
	if (c.gen - ACC.rt) > 30 then
		ACC.rnum = 0
	end
	ACC.rt = c.gen
	ACC.rnum = ACC.rnum + 1
	if ACC.rnum > ACC.ResetNum then
		ResetSys()
	end

	if ACC.level ~= v then
		ACC.c = c.gen
		ACC.level = v
		if IsSleep() then
			SysWakeup(3,9)
		end
	end
	UpdateA1Len()
end

local function handleInt(id,resnum)
	if id == cpu.INT_GPIO_NEGEDGE then
		vprint("int neg1 num:",resnum)
		if resnum == IO.acc then
			ACCInt(0)
		elseif resnum == IO.shake then
			SimShkInt()
		elseif resnum == IO.chg then
			ACC.rnum = 0
			ChgDeal(bat.chg, false)
		elseif resnum == IO.batchg then
			bat.batchg = true
		end
    elseif id == cpu.INT_GPIO_POSEDGE then
		vprint("int pos1 num:",resnum)
	    if resnum == IO.acc then
			ACCInt(1)
		elseif resnum == IO.chg then
			ChgDeal(bat.chg, true)
		elseif resnum == IO.batchg then
			bat.batchg = false
		end
	end
end

local function ShakeAlm()
	if cP["VIB"] ~= "1" then
		return
	end
	if (c.gen - shk.shake) < shk.PTime and not p.ShkQuick then
		return
	end
	if shk.shake == 2^30 then
		return
	end
	shk.shake = 2^30
	if (c.gen - shk.almc) <= 300 or p.guard ~= "ON" then
		return
	end
	shk.almc = c.gen
	PushMsg("T11")
end

local function CheckGuard()
	local t1 = c.gen - ACC.cs
	if ACC.s == 0 and t1 >= 0 and t1 < 3 and p.guard == "ON" then   --点火
		p.guard = "OFF"
		p.statechg = true
		ClearGuardInfo()
		AirGuard()
		PushAir("A2")
		vprint("guard off")
	elseif ACC.s == 1 and (c.gen - ACC.cs) >= cP["ACCLT"] and p.guard == "OFF"	then  --熄火
		InitGuardInfo()
		p.guard = "ON"
		p.statechg = true
		ACC.cs = 2^30
		AirGuard()
		PushAir("A2")
		vprint("guard on",ACC.cs)
	end
end

local function CheckACC()
	if ACC.s ~= ACC.level and (ACC.level == 0 or (c.gen - ACC.c) >= 4) then
		ACC.s = ACC.level
		ACC.cs = c.gen
		SetSleepBgn(4)
		if ACC.s == 1 then
			ACC.lastoff = c.gen
		end
		ResetInitV()
		vprint("checkacc",ACC.s,ACC.cs,ACC.lastoff)
	end
	CheckGuard()
end

local function GetChgStat()
	local t1 = pio.pin.getval(IO.chg)
	local t2 = pio.pin.getval(IO.batchg)
	vprint("chgs",t1,t2)
	if 1 == t1 then
		bat.chg = true
	else
		bat.chg = false
	end
	if 1 == t2 then
		bat.batchg = false
	else
		bat.batchg = true
	end
end

local function CheckCharger()
	GetChgStat()
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
		PushMsg("T12")
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
		PushMsg("T13")
		if IsSleep() then
			SysWakeup(3,"G")
		end
	end
end

local function IsGpsMove()
	if gps.state ~= 1 then
		return false
	end
	if (gps.oldlong == 0 and gps.long ~= 0) or (gps.oldlat == 0 and gps.lati ~= 0) then
		gps.oldlong = gps.long
		gps.oldlat = gps.lati
		gps.oldtime = c.gen
		return true
	end

	local D = DiffOfLoc(gps.oldlat, gps.oldlong, gps.lati, gps.long)
	local R = c.gen - gps.oldtime
	vprint("dofgps", D, R)
	if D > gps.gMove then
		vprint("gpsmove", D, R)
		WriteResetC()
		gps.oldlong = gps.long
		gps.oldlat = gps.lati
		gps.oldtime = c.gen
		return true
	end

	return false
end

local function T3Report()
	if p.CS == 0 or not Lib.linklist[p.CS].login then
		return
	end
	local T3F = 0

	if cP["TRACE"] ~= "1" then
		return
	end
	if (c.gen - c.T3) < cP["FREQ"] then
		return
	end
	if p.cellmove then
		T3F = T3F + 1
	end
	if p.gpsmove then
		T3F = T3F + 2
	end
	if (c.gen - shk.shake) < cP["FREQ"] and shk.shake < 2^29 then
		T3F = T3F + 4
	end
	if p.statechg then
		T3F = T3F + 8
	end

	if T3F > 0 then
		PushMsg("T3")
		c.T3 = c.gen
		p.gpsmove = false
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

local function CheckFT()
	vprint("Ftv",p.GsmSucc,gps.gpssn,p.skh, ACC.s,bat.chg, bat.batchg)
	local s1
	if p.GsmSucc and (p.FtRlt % 2) == 0 then
		p.FtRlt = p.FtRlt + 1
	end
	if gps.gpssn > 35 then
		if (p.FtRlt % 4) < 2 then
			p.FtRlt = p.FtRlt + 2
		end
	end
	if p.skh > 0 then
		if (p.FtRlt % 8) < 4 then
			p.FtRlt = p.FtRlt + 4
		end
	end
	if ACC.s == 0 then
		if (p.FtRlt % 16) < 8 then
			p.FtRlt = p.FtRlt + 8
		end
	end
	if bat.chg then
		if (p.FtRlt % 32) < 16 then
			p.FtRlt = p.FtRlt + 16
		end
	end
	if bat.batchg then
		if p.FtRlt < 32 then
			p.FtRlt = p.FtRlt + 32
		end
	end

	if p.FtRlt < 63 then
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

function processUART1(s1)
	p.ftsn = 1
	s1 = string.upper(s1)
    if smatch(s1,"WIMEI") then
		sendat(s1)
		TermStateTrans("WN")
	elseif smatch(s1,"CGSN") then
		sendat(s1)
	elseif smatch(s1,"WISN%?") then
		sendat(s1)
	elseif smatch(s1,"WISN") then
		sendat(s1)
	elseif smatch(s1,"VER") then
		sendat(s1)
	end

	if smatch(s1,"AT%+FT9321") then
		vprint("ft begin")
		TermStateTrans("FT")
		CheckFT()
	end
end

local function ReadGPS()
	local strgps = ""
	local gpsreadloop = true
	if gps.open then
		rtos.timer_start(t.gps,t.gpslen)
	end

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
		if (c.gen-gps.wake+5) > air.gpsOn and gps.wake > 0 then
			strgps = ""
		end
		processGpsData(strgps)
		if c.gps % c.GpsPrt == 0 then
			vprint("gps rlt", gps.long,gps.lati,gps.spd,gps.cog,gps.find)
		end

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
			gps.satenum = 0
			gps.gpssn = 1
		end

		if gps.spd > gps.spdwake then
			SetSleepBgn(5)
			gps.spd = 0
			if IsSleep() then
				SysWakeup(3,"F")
			end
		end
	end
end

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
		s1 = s1 .. pt .. ","
		c.PrintC = c.gen
	end
	print(c.gen,a.term,shk.shake,ACC.s,p.guard,pt,p.stop,bat.chg,bat.chgrep,p.cellmove,p.gpsmove,gps.MoveAlm,gps.open,gps.gpssn,gps.state)
	s1 = s1 .. ACC.s .. guard1 .. p.WakeReason .. Bs(p.stop) .. Bs(p.statechg) .. Bs(p.GprsSucc)
	s1 = s1 .. Bs(bat.chg) .. Bs(bat.chgrep) .. Bs(p.cellmove) .. Bs(p.gpsmove) .. Bs(gps.MoveAlm) .. Bs(gps.open) .. gps.state
	vprint(s1)
end

local function GetServerPort(s)
	local s1,s2
	s1,s2 = smatch(s,"(.+):(%d+)")
	return s1,s2
end

local function NeekAck(id)
	local tr = Lib.linklist[id].CurTr
	local ack = true
	if id == p.CS and tr <= 9 and tr >= 4 then
		ack = false
	end
	return ack
end

local function CMCCState(state)
	vprint("CMCC", state)
	local id = p.CS
	if state == "CONNECTED" then
		p.FastNum = 0
		Lib.linklist[id].CurTr = 0
		if not Lib.linklist[id].login then
			PushMsg("T1")
		end
	elseif state == "CLOSED" then
		if Lib.linklist[id].valid then
			connect(id)
		end
	end
	if state == "SEND OK" then
		if not NeekAck(id) then
			rtos.timer_stop(t.tcpCMCC)
			Lib.linklist[id].CurTr = 0
		end
	end
	if state == "CONNECT FAIL" then
		LaterRestart(3600000)
	end
end

local function AirPulse()
	if u.LuaState > 0 then
		return
	end
	if Lib.linklist[p.AS].valid and Lib.linklist[p.AS].state == "CONNECTED" then
		PushAir("A1")
	end
end

local function AirState(state)
	vprint("Air", state)
	local id = p.AS
	if state == "CONNECTED" then
		p.FastNum = 0
		Lib.linklist[id].CurTr = 0
		AirPulse()
	elseif state == "CLOSED" then
		if not TermStateEqu("CLOSE") then
			if Lib.linklist[id].valid then
				connect(id)
			end
		end
	end
	if state == "SEND OK" then
		if not NeekAck(id) then
			rtos.timer_stop(t.tcpAir)
		end
	end
end

local function ProcessLt()
	rtos.timer_start(t.light, t.lightlen)
	c.lt = c.lt + 1
	GsmWorkLight()
	GpsWorkLight()
end

local function NormalSleep()
	if not p.GprsSucc and c.gen > t.ResetNoGprs and not IsDSleep() then
		ResetSys()
	end

	if IsSleep() or (ACC.s == 0 and bat.chg) then
		return
	end

	if (c.gen % 10) == 0 then
		vprint("normalcalc",c.gen,t.ST,c.gprsact)
	end

	if c.gen < t.ST + c.gprsact then
		return
	end

	if #atqueue > 0 then
		return
	end
	vprint("sleep state")
	EntSleep()
end

local function EntDSleep()
	a.term = "DSLEEP"
	EntFlyMode()
	p.GprsSucc = false
	c.DeepSC = c.gen
	p.FastNum = 0
end

local function DeepSleep()
	local R = true
	if not IsNSleep() then
		R = false
	end
	if IsDSleep() then
		R = false
	end
	if not R then
		return
	end
	R = false

	local R1 = false
	if (c.gen - p.nrssic + 21) > p.weaklen then
		R1 = true
	end
	if (c.gen - p.SleepC + 30) > t.DeepSleepLen then
		R1 = true
	end
	if not bat.chg and bat.vol < 30 then
		R1 = true
	end

	if (c.gen - p.nrssic) > p.weaklen then
		R = true
	end
	if (c.gen - p.SleepC) > t.DeepSleepLen then
		R = true
	end
	if not bat.chg and bat.vol < 25 then
		R = true
	end
	if R or (not p.statechg and p.dsleep) then
		p.statechg = false
		p.dsleep = false
		EntDSleep()
		return
	end
	if R1 and not p.dsleep then
		p.statechg = true
		p.dsleep = true
	end
end

local function WakeTest()
	if (c.gen - c.DeepSC) > p.DeepTest then
		c.DeepSC = 2^30
		SysWakeup(3,6)
	end
end

local function InitIO()
	print("BT",BT)
	pio.pin.setdir( pio.OUTPUT, pio.P0_15,pio.P0_24,pio.P0_25)
	pio.pin.setdir(pio.INT, pio.P0_1, pio.P0_3, pio.P0_5, pio.P0_6)
	IO.acc = pio.P0_6
	IO.gsensor = nil
	IO.shake = pio.P0_3
	IO.gps = pio.P0_15
	IO.chg = pio.P0_5
	IO.gpslt = pio.P0_24
	IO.gsmlt = pio.P0_25
	IO.wd = pio.P0_14
	IO.batchg = pio.P0_1
	IO.pmd =
	{
		battFullLevel = 4250, -- A9321充满电压4.25v
		battRechargeLevel = 3700, -- 回充电压4.1V
		currentFirst = 150,
		battlevelFirst = 4150,
		currentSecond = 50,
		battlevelSecond = 4190,
		currentThird = 50
	}

	Openwd()
	GetChgStat()
end

function ProcessGenTimer()
	rtos.timer_start(t.gen, t.genlen)
	UpdateTime()
	NormalSleep()
	--DeepSleep()
	WakeTest()
	p.cellmove = IsCellMove()
	p.gpsmove = IsGpsMove()
	CheckACC()
	CheckStop()
	ShakeAlm()
	T3Report()
	CheckRadius()
	CheckCharger()
	CheckLowPower()
	PrintVars()
	if not Lib.atproc then
		exeat()
	end
end

local function AirUdpTry()
	connect(p.AS)
end

local function AtTimeout()
	vprint("restart sys")
	ResetSys()
end

local function AirDebug()
	if u.LuaState > 0 then
		return
	end
	if Lib.linklist[p.AS].valid and Lib.linklist[p.AS].state == "CONNECTED" then
		PushAir("A3")
	end
end

--[[
如果到了醒来的时间，首先打开GPS，搜索定位，得到有效的经纬度之后，并且到了GpsOn时间之后，再上报，同时关闭GPS
如果不是睡眠状态，到时间就直接上报
]]
local function HeartTime()
	if TermStateEqu("CLOSE") then
		if not gps.open then
			SleepGPS()
		end
		return
	end

	if (c.gen % 10) == 0 then
		vprint("HeartTime", c.gen, air.A1Send, t.A1, gps.wake, air.gpsOn, c.T2, air.debugsend, air.debuglen, air.debug)
	end

	if ((c.gen- c.T2) >= cP["PULSE"]) then
		PushMsg("T2")
	end

	if (c.gen - air.A1Send) > t.A1 then
		if not IsSleep() then
			AirPulse()
			air.A1Send = c.gen
		else
			if not gps.open then
				WakeGPS()
			elseif (c.gen-gps.wake) > air.gpsOn and gps.wake > 0 then
				AirPulse()
				air.A1Send = c.gen
				SleepGPS()
			end
		end
	end

	if (c.gen - air.debugsend) > air.debuglen and air.debug == 1 then
		AirDebug()
		air.debugsend = c.gen
	end
end

local function CheckGprs()
	local t1 = air.batHeart
	if t1 < air.chgHeart then
		t1 = air.chgHeart
	end
	if t1 < air.accHeart then
		t1 = air.accHeart
	end
	t1 = t1*2*60
	if (c.gen - p.recdata) > t1 then
		p.resettimes = p.resettimes + 1
		if p.resettimes > 100000 then
			p.resettimes = 1
		end
		p.recdata = c.gen
		WriteResetC()
		EntFlyMode()
		LaterRestart(5000)
	end
end

local function handlewd()
	rtos.timer_start(t.wd,t.wdlen)
	c.gen = c.gen + 1

	if p.wd == true then
		pio.pin.sethigh(IO.wd)
	else
		pio.pin.setlow(IO.wd)
	end

	p.wd = not p.wd
	if (c.gen % 10) == 0 then
		print("wd",p.wd,c.gen,gps.wake)
	end

	HeartTime()
	CheckGprs()
end

function SetAllTimer()
	settimer(t.gen,ProcessGenTimer)
	settimer(t.gps,ReadGPS)
	settimer(t.light,ProcessLt)
	settimer(t.FT,FTTimeout)
	settimer(t.query,QueryNet)
	settimer(t.reset,ResetSys)
	settimer(t.tcpCMCC,TCPCMCCTimeout)
	settimer(t.tcpAir,TCPAirTimeout)
	settimer(t.airUdpTry, AirUdpTry)
	settimer(t.atrsp, AtTimeout)
	settimer(t.wd, handlewd)
end

local function PackUpMsg(num)
	return "Get" .. tostring(num)
end

local function Crc8(s,c)
	local d = 0
	for i = 1,string.len(s) do
		d = d + string.byte(s,i)
	end
	d = d % 256
	vprint("crc8", d, c)
	return d == c
end

local function WriteLua(s)
	local f,of
	if u.wfLua then
		of = "wb"
		u.wfLua = false
	else
		of = "a+"
	end
	f = io.open(u.zf,of)

	assert(f ~= nil, "open main.lua failed!")
	f:write(s)
	f:close()
end

local function UpdateLua(s1)
	local str1,luaindex,crc
	local id = p.AS
	local L = string.len(s1)
	str1 = string.sub(s1,3,-1)
	luaindex = string.byte(s1,1)
	crc = string.byte(s1,2)
	vprint("rec up", luaindex, L, crc)

	if u.LuaLastInd ~= tonumber(luaindex) then
		vprint("recindex,waitindex",luaindex,u.LuaLastInd)
		LaterRestart()
		return
	end
	Lib.linklist[id].CurTr = 0

	if Crc8(str1,crc) then
		vprint("writetofile",luaindex)
		WriteLua(str1)
		u.LuaLastInd = u.LuaLastInd + 1
	end

	if u.LuaLastInd > tonumber(u.LuaNum) then
		u.LuaState = 3
		EntFlyMode()
		LaterRestart(3000)
	else
		p.gdata = PackData(PackUpMsg(u.LuaLastInd))
		send(id, p.gdata)
	end
end

local function UpAck(s)
	local num,last,port
	local id = p.AS

	port,num,last = smatch(s,"3,(%d+),(%d+),(%d+)")
	if num == nil or last == nil then
		return
	end
	Lib.linklist[id].CurTr = 0
	u.LuaNum = tonumber(num)
	u.LuaLastBytes = tonumber(last)
	u.LuaState = 2
	u.LuaLastInd = 1
	vprint("uppara", u.LuaNum, u.LuaLastBytes)
	p.gdata = PackData(PackUpMsg(u.LuaLastInd))
	send(id, p.gdata)
end

local function GetAirData(s)
	return string.sub(trim(s), 9, -2)
end

local function AirAck(s1)
	print("airlua", u.LuaState)
	local seq = GetCurTr(p.AS,s1)
	local id = p.AS
	local ack = GetAirData(s1)
	vprint("airack",seq,trim(s1),ack)
	p.recdata = c.gen
	p.resendnum[id] = 0
	if seq == Lib.linklist[id].CurTr then
		rtos.timer_stop(t.tcpAir)
		Lib.linklist[id].CurTr = 0
	end
	if u.LuaState > 0 then
		UpdateLua(s1)
		return
	end
	if ack == "OK" then
		air.imsisend = true
	end
	if smatch(ack,"^1,.+") then
		local t1
		t1 = smatch(ack,"^1,(%d+)")
		if t1 ~= nil then
			air.RepLen = tonumber(t1)
			UpdateA1Len()
			WriteResetC()
		end
	end
	if smatch(ack, "^2,[%d/]+,.+") then
		local nums,cod,s1
		nums,cod,s1 = smatch(ack,"^2,([%d/]+),(%d),(.+)")
		print("receiveairsms", nums, cod, s1)
		if nums ~= nil and cod ~= nil and s1 ~= nil then
			sendsms(s1,cod,nums)
		end
	end
	if smatch(ack,"^3,.+") then
		vprint("begin lua up")
		UpAck(ack)
		return
	end
	if smatch(ack, "4,.+") then
		local server,port
		server,port = smatch(ack,"^4,(.+),(%d+)")
		port = port or ""
		if server ~= nil then
			air.server = server
			air.port = port
			WriteResetC()
			WriteConfig()
			LaterRestart()
			return
		end
	end
	if smatch(ack, "^5,.+") then
		local go,ah,cs,ch,bh,bs,av
		go,ah,cs,ch,bh,bs,av = smatch(ack,"5,(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
		if go == nil or ah == nil or cs == nil or ch == nil or bh == nil or bs == nil or av == nil then
			return
		end
		air.gpsOn = tonumber(go)
		air.accHeart = tonumber(ah)
		air.chgSleep = tonumber(cs)
		air.chgHeart = tonumber(ch)
		air.batHeart = tonumber(bh)
		air.batSleep = tonumber(bs)
		ACC.valid = tonumber(av)
		if ACC.valid == 0 then
			gps.spdwake = 3
		end
		WriteResetC()
		UpdateA1Len()
		return
	end
	if ack == "ERR" then
		LaterRestart()
	end
	if ack == "SHUTDOWN" then
		TermStateTrans("CLOSE")
		SleepGPS()
		p.pinlock = true
		t.airLen = 60*60*12*1000
	end
	if ack == "DEBUG" then
		air.debug = 1
	end
end

local function StartAllLink()
	p.AS = startlink(air.server,air.port,"UDP",{recv = AirAck,notify = AirState})
end

local function init()
	pmd.sleep(0)
	LogInit()
	InitIO()
	FacSet()
	getlasterr()
	ReadLuaVer()
	ReadZipStatus()
	sysinit()
	openGPS()
	SetAllTimer()
	StartAllLink()
	rtos.timer_start(t.gen, t.genlen)
	rtos.timer_start(t.light, t.lightlen)
	rtos.timer_start(t.query, t.querylen)
	rtos.timer_start(t.wd,t.wdlen)
end

local function handlehost()
	local s
	while true do
		s = uart.read(3,"*l",0)
		if string.len(s) ~= 0 then
			print("rec getlog")
			s = string.upper(s)
			if s == "GETLOG" then
				GetLog()
			elseif s == "GETINFO" then
				GetLInfo()
			elseif smatch(s, "GET%d+") then
				local v = smatch(s, "GET(%d+)")
				if v ~= nil then
					GetOneLog(tonumber(v))
				end
			end
		else
			break
		end
	end
end


init()

print(u.PrjName .. " Lua " .. u.LUAVER)
while true do
	msg = rtos.receive(rtos.INF_TIMEOUT)

	if msg.id == rtos.MSG_UART_RXDATA then
		local aid = msg.uart_id
		if aid == uart.ATC then
			atcreader()
		elseif aid == 1 then
			handleuart1()
		elseif aid == 3 then
			handlehost()
		end
	elseif msg.id == rtos.MSG_TIMER then
		handleTimeout(msg.timer_id)
	elseif msg.id == rtos.MSG_INT then
		handleInt(msg.int_id,msg.int_resnum)
	elseif msg.id == rtos.MSG_PMD then
		ProcessChg(msg)
	else
		vprint("msg.id:",msg.id)
	end
end
