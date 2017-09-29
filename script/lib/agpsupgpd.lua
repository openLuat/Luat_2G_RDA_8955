--定义模块,导入依赖库
require"socket"
require"common"
local bit = require"bit"
local gps = require"gps"

module(...,package.seeall)

--加载常用的全局函数至本地
local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len

local SCK_IDX,PROT,ADDR,PORT = 2,"TCP","download.openluat.com",80

local linksta

local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

local reconncnt,reconncyclecnt,conning = 0,0
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

--[[
函数名：snd
功能  ：调用发送接口发送数据
参数  ：
        data：发送的数据，在发送结果事件处理函数ntfy中，会赋值到item.data中
		para：发送的参数，在发送结果事件处理函数ntfy中，会赋值到item.para中 
返回值：调用发送接口的结果（并不是数据发送是否成功的结果，数据发送是否成功的结果在ntfy中的SEND事件中通知），true为成功，其他为失败
]]
function snd(data,para)
	return socket.send(SCK_IDX,data,para)
end

--[[
函数名：gpsup
功能  ：发送“请求星历信息”数据到服务器
参数  ：无
返回值：无
]]
function gpsup()
	print("gpsup",linksta)
	if linksta then
		snd(sendstr,"GPS")		
	end
end

--[[
函数名：reconn
功能  ：重连后台处理
        一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
        如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
        如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
参数  ：无
返回值：无
]]
local function reconn()
	print("reconn",reconncnt,conning,reconncyclecnt)
	--conning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致reconncnt增加，实际的重连次数减少
	if conning then return end
	--一个连接周期内的重连
	if reconncnt < RECONN_MAX_CNT then		
		reconncnt = reconncnt+1
		link.shut()
		connect()
	--一个连接周期的重连都失败
	else
		reconncnt,reconncyclecnt = 0,reconncyclecnt+1
		if reconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			sys.restart("connect fail")
		end
		sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000)
	end
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		result： bool类型，消息事件结果，true为成功，其他为失败
		item：table类型，{data=,para=}，消息回传的参数和数据，目前只是在SEND类型的事件中用到了此参数，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
返回值：无
]]
function ntfy(idx,evt,result,item)
	print("ntfy",evt,result,item)
	--连接结果（调用socket.connect后的异步事件）
	if evt == "CONNECT" then
		conning = false
		--连接成功
		if result then
			reconncnt,reconncyclecnt,linksta = 0,0,true
			--停止重连定时器
			sys.timer_stop(reconn)
			gpsup()
		--连接失败
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000)
		end	
	--数据发送结果（调用socket.send后的异步事件）
	elseif evt == "SEND" then
		--发送失败，RECONN_PERIOD秒后重连后台，不要调用reconn，此时socket状态仍然是CONNECTED，会导致一直连不上服务器
		if not result then sys.timer_start(reconn,RECONN_PERIOD*1000) end
		if not result then link.shut() end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		linksta = false
		--reconn()
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		linksta = false
	--连接主动断开（调用socket.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		linksta = false
		--reconn()		
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((type(result)=="string") and result or "","ERROR") then
		--RECONN_PERIOD秒后重连，不要调用reconn，此时socket状态仍然是CONNECTED，会导致一直连不上服务器
		--sys.timer_start(reconn,RECONN_PERIOD*1000)
		link.shut()
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
	--[[for i = 2,slen(str)-1 do
		tmp = bit.bxor(tmp,sbyte(str,i))
	end	
	tmp = string.format("%x",tmp)
	str = str..tmp.."\r\n"]]
	print("syy writeapgs str",str,slen(str))
	writebg = true
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
	tonum = tolen/1024
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

function changem(m)
	for k,v in pairs(month) do
		if m == v then
			return k
		end
	end
end

function rcv(idx,data)
	print("syy rcv!!!!!!!!!!",slen(data))
	--print("rcv",data)
	local fs = string.find(data,"HTTP/1.1 400 BAD REQUEST")
	if fs then socket.close(idx) return end
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
	if slen(gpd) >= tonumber(gpdlen)*2 then
		socket.close(idx)
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
		if writebg then writegpd() end
		if not writebg then  sys.dispatch("AGPS_WRDATE_END") end
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
	if os.difftime(nowtime,xlt) >= 4*3600 then
		return true
	end
		return false
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
	print("connect uptime",uptimeck(),gps.isfix())
	if not uptimeck() or gps.isfix() then 
		sys.dispatch("AGPS_WRDATE_END")
		return 
	end
	socket.connect(SCK_IDX,PROT,ADDR,PORT,ntfy,rcv)
	conning = true
end

local function proc(id)
	print("AGPS_WRDATE_SUC")
	--writegpdbg()
	connect()
	return true
end

--connect()

function checkup()
	print("checkup",uptimeck())
	if uptimeck() then
		agps.connect()
	end
end

--为GPS提供32K时钟
rtos.sys32k_clk_out(1)
--注册GPS消息处理函数
sys.regapp(proc,"AGPS_WRDATE_SUC")
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
