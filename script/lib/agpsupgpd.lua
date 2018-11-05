--定义模块,导入依赖库
require"socket"
require"common"
local bit = require"bit"
local gps = require"gps"

module(...,package.seeall)

--加载常用的全局函数至本地
local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len

local PROT,ADDR,PORT,lid = "TCP","download.openluat.com",80

local GPD_FILE = "/GPD.txt"
local GPDTIME_FILE = "/GPDTIME.txt"
local gpdlen,wxlt
local month = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

local head = "AAF00B026602"
local tail,idx,tonum = "0D0A",0

local function print(...)
	_G.print("agpsupgpd",...)
end

local str1 = "GET /9501-xingli/brdcGPD.dat_rda HTTP/1.0\n"
local str2 = "Accept: */*\n"
local str3 = "Accept-Language: cn\n"
local str4 = "User-Agent: Mozilla/4.0\n"
local str5 = "Host: download.openluat.com:80\n"
local str6 = "Connection: Keep-Alive\n"
local str7 = "\n\n"
local str8 = "Content-Length:0"
local sendstr = str1..str2..str3..str4..str5..str6..str7
local gpd = ""

local RETRY_TIMES,retries,reconnect = 3,1

function upend(succ)
	sys.timer_stop(upend,false)
	link.close(lid)
	lid = nil
	if succ then
		retries,reconnect = 0
	else
		if retries >= RETRY_TIMES then
			retries,reconnect = 0
		else
			reconnect = true
			retries = retries + 1
		end
	end
end

function ntfy(idx,evt,val)
	print("ntfy",evt,val)
	--连接结果
	if evt == "CONNECT" then
		if val == "CONNECT OK" then
			link.send(lid,sendstr)
		else
			upend(false)
		end	
	--数据发送结果
	elseif evt == "SEND" then
		if val ~= "SEND OK" then 
			upend(false)
		else
			sys.timer_start(upend,30000,false)
		end
	--连接被动断开
	elseif evt == "STATE" and val == "CLOSED" then
		upend(false)
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and val == "SHUTED" then
		upend(false)
	--连接主动断开
	elseif evt == "CLOSE" and reconnect then
		connect()
	end
end

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        idx ：socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
local function writetxt(f,v)
	local file = io.open(f,"w")
	if file == nil then
		print("GPD open file to write err",f)
		return
	end
	file:write(v)
	file:close()
end

local function readtxt(f)
	local file,rt = io.open(f,"r")
	if file == nil then
		print("GPD can not open file",f)
		return ""
	end
	rt = file:read("*a")
	file:close()
	return rt
end

local writebg
function writegpdbg()
	local tmp = 0
	local str = "$PGKC149,1,115200*15\r\n"
	print("syy writeapgs str",str,slen(str))
	writebg = true
	gps.opengps("AGPSUPGPD")
	sys.timer_start(gps.closegps,20000,"AGPSUPGPD")
	gps.writegk(str)
end

function writed()
	local writend = "AAF00B006602FFFF6F0D0A"
	writend = common.hexstobins(writend)
	gps.writegk(writend)
end

function writeswname()
	local writswn = "AAF00E0095000000C20100580D0A"
	print("writeswname")
	writswn = common.hexstobins(writswn)
	gps.writegk(writswn)
end

function writegpd()
	local tmp,inf,body = 0
	local idx2 = string.format("%x",idx)
	if slen(idx2) < 2 then
		idx2 = "0"..idx2
	end
	local str = head..idx2.."00"
	inf = readtxt(GPD_FILE)
	local tolen = slen(inf)
	tonum = (tolen-tolen%1024)/1024
	print("writegpd inf",idx,idx2,tolen,tonum)
	print("inf",ssub(inf,1,512))
	if idx < tonum then
		body = ssub(inf,idx*1024+1,(idx+1)*1024)
	else
		local snum = tolen - idx*1024
		body = ssub(inf,idx*1024+1,-1)
		body = body..string.rep("F",(1024-snum))
	end
	str = str..body
	print("writegpd",slen(body))
	print("writegpd 2",body)
	local str2 = common.hexstobins(str)

	for i = 3,slen(str2) do
		tmp = bit.bxor(tmp,sbyte(str2,i))
	end	
	tmp = string.upper(string.format("%x",tmp))
	if slen(tmp) < 2 then
	tmp = "0"..tmp
	end
	str = str..tmp..tail
	
	print("syy writegpd tmp",tmp)
	
	gps.writegk(common.hexstobins(str))
	idx = idx+1
end

function rcv(idx,data)
	print("syy rcv!!!!!!!!!!",slen(data))
	local fs = string.find(data,"HTTP/1.1 400 BAD REQUEST")
	if fs then upend(false) return end
	local str1 = string.find(data,"Length: ")
	local t1,t2= string.find(data,"Modified: ")
	if t2 then
		local clk = os.date("*t")
		wxlt = string.format("%04d%02d%02d%02d%02d%02d",clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec)
	end
	if str1 then  
		gpdlen = smatch(data,"Content%-Length: (%d+)")
	end
	print("syy len:",str1,gpdlen)
	if str1 then
		local str2 = string.find(data,"\r\n\r\n")
		gpd = ssub(data,str2+slen("\r\n\r\n"))
		gpd = common.binstohexs(gpd)
	else		
		gpd = gpd..common.binstohexs(data)
		print("syy gpd",ssub(gpd,1,8),ssub(gpd,slen(gpd)-8))
	end
	print("syy gpd len:",slen(gpd),tonumber(gpdlen))
	sys.timer_start(upend,30000,false)
	if slen(gpd) >= tonumber(gpdlen)*2 then
		upend(true)
		gpd = ssub(gpd,1,tonumber(gpdlen)*2)
		writegpdbg()
		writetxt(GPD_FILE,gpd)
	end
end

--[[
函数名：gpsstateind
功能  ：处理GPS模块的内部消息
参数  ：
		id：gps.GPS_STATE_IND，不用处理
		data：消息参数类型
返回值：true
]]
local function gpsstateind(id,data)
	print("gpsstateind",id,data)
	if data == gps.GPS_BINARY_ACK_EVT then
		print("syy gpsind GPS_BINARY_ACK_EVT writebg",writebg)
		if writebg then
			writegpd()
		else
			gps.closegps("AGPSUPGPD")
			sys.timer_stop(gps.closegps,"AGPSUPGPD")
		end
	elseif data == gps.GPS_BINW_ACK_EVT then
		print("syy gpsind GPS_BINW_ACK_EVT idx",idx)
		if idx <= tonum then
			writegpd()	
		else
			if writebg then writed() end
			writebg = nil
			idx = 0
		end
	elseif data == gps.GPS_BINW_END_ACK_EVT then
		print("syy gpsind GPS_BINW_END_ACK_EVT")
		writeswname()
		os.remove(GPD_FILE)
		writetxt(GPDTIME_FILE,wxlt)
	elseif data == gps.GPS_OPEN_EVT then
		checkup()	
	end
	return true
end

local function uptimeck()
	local uptime = readtxt(GPDTIME_FILE)
	if uptime == "" then print("uptimeck nil") return true end
	local clk = {}
	local a,b = nil,nil
	a,b,clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec = string.find(uptime,"(%d%d%d%d)(%d%d)(%d%d)(%d%d)(%d%d)(%d%d)")
	print("uptimeck",clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec )
	local xlt = os.time({year=clk.year,month=clk.month,day=clk.day, hour=clk.hour, min=clk.min, sec=clk.sec})
	print("uptimeck",xlt,os.time())
	local nowtime = os.time()
	return os.difftime(nowtime,xlt) >= 4*3600
end

--[[
函数名：connect
功能  ：创建到后台服务器的连接；
        如果数据网络已经准备好，会理解连接后台；否则，连接请求会被挂起，等数据网络准备就绪后，自动去连接后台
		ntfy：socket状态的处理函数
		rcv：socket接收数据的处理函数
参数  ：无
返回值：无
]]
function connect()
	print("connect uptime",uptimeck(),gps.isfix(),lid)
	if not uptimeck() or gps.isfix() then 
		retries,reconnect = 0
		return 
	end
	if not lid then
		lid = link.open(ntfy,rcv)
		link.connect(lid,PROT,ADDR,PORT)
	end	
end

local function proc(id)
	print("AGPS_WRDATE_SUC")
	connect()
end

function checkup()
	print("checkup",uptimeck())
	if uptimeck() then
		agps.connect()
	end
end

--注册GPS消息处理函数
sys.regapp(proc,"AGPS_WRDATE_SUC")
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
