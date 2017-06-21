collectgarbage("setpause",110)

local smatch = string.match
local BT = "9321A22"
local msg = nil
local atqueue = {
	"ATE0",
	"AT*EXASSERT=0",
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
	u.LUAVER = "3.1.8"
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
	Log.TotalNum = 10
	Log.ztime = 2*60*60
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

	vprint("sendat:",cmd)

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
	rtos.timer_start(t.wd, t.wdlen)
end

local function CloseWd()
	rtos.timer_stop(t.wd)
end

local function handleURC(data)
	if data == "RDY" then
		--sendat(table.remove(atqueue,1))
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
		sendat("AT+AMFGD=\"luaerrinfo.txt\",0")
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

local function ChgWd()
	if p.wd == true then
		pio.pin.sethigh(IO.wd)
	else
		pio.pin.setlow(IO.wd)
	end
	p.wd = not p.wd
	--if (c.gen % 10) == 0 then
		print("wd",p.wd,c.gen,gps.wake,rtos.tick())
	--end
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
	if Log.curnum == nil or Log.znum =