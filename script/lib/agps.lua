--定义模块,导入依赖库
local base = _G
local table = require"table"
local lpack = require"pack"
local rtos = require"rtos"
local sys = require"sys"
local string = require"string"
local link = require"link"
local misc = require"misc"
local net = require"net"
local gps = require"gps"
local bit = require"bit"
require"agpsupgpd"
module(...,package.seeall)

--加载常用的全局函数至本地
local print = base.print
local tonumber = base.tonumber
local fly = base.fly
local sfind = string.find
local slen = string.len
local ssub = string.sub
local sbyte = string.byte
local sformat = string.format
local smatch = string.match
local sgsub = string.gsub
local schar = string.char
local srep = string.rep
local send = link.send
local dispatch = sys.dispatch

local lid,isfix
local ispt,itv,PROT,SVR,PORT,WRITE_INTERVAL = true,(2*3600),"UDP","bs.openluat.com",12412,100
local mode,pwrcb = 0
local gpssupport,eph = true,""
local GET_TIMEOUT,ERROR_PACK_TIMEOUT,GET_RETRY_TIMES,PACKET_LEN,RETRY_TIMES = 10000,5000,3,1024,3
local state,total,last,checksum,packid,getretries,retries,reconnect = "IDLE",0,0,{},0,0,1,false

local PRODUCT_KEY = 0

local mt = {}
local lastLbsLng,lastLbsLat = "",""

local function startupdatetimer()
	if gpssupport and ispt then
		sys.timer_start(connect,itv*1000)
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
	if data == gps.GPS_LOCATION_SUC_EVT or data == gps.GPS_LOCATION_UNFILTER_SUC_EVT then
		sys.dispatch("AGPS_UPDATE_SUC")
		startupdatetimer()
		isfix = true
		setsucstr()
	elseif data == gps.GPS_LOCATION_FAIL_EVT or data == gps.GPS_CLOSE_EVT then
		isfix = false
	elseif data == gps.GPS_NO_CHIP_EVT then
		gpssupport = false
	elseif data == gps.GPS_BINARY_ACK_EVT then
		print("syy gpsind GPS_BINARY_ACK_EVT")
	elseif data==gps.GPS_OPEN_EVT then
		local lng,lat = gps.getLastLocation()
		if lng=="" or lat=="" then
			lng,lat = lastLbsLng,lastLbsLat
		end
		if lng~="" and lat~="" then
			gps.open(gps.TIMERORSUC,{cause="lib.agps.lua.fastFix",val=4})
			local tm = os.date("*t")
			sys.timer_start(function(slng,slat,stm)
								local t = stm.year..","..stm.month..","..stm.day..","..stm.hour..","..stm.min..","..stm.sec.."*"
								print("setFastFix",slat,slng,t)
								writeapgs("$PGKC634,"..t)
								writeapgs("$PGKC635,"..lat..","..lng..",0,"..t)
							end,
							2000,
							lng,lat,common.transftimezone(tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec,8,0))
		end
	end
	return true
end

local function errpack()
	print("errpack")
	upend(false)
end

function retry(para)
	if state ~= "UPDATE" and state ~= "CHECK" then
		return
	end

	if para == "STOP" then
		getretries = 0
		sys.timer_stop(errpack)
		sys.timer_stop(retry)
		return
	end

	if para == "ERROR_PACK" then
		sys.timer_start(errpack,ERROR_PACK_TIMEOUT)
		return
	end

	getretries = getretries + 1
	if getretries < GET_RETRY_TIMES then
		if state == "UPDATE" then
			-- 未达重试次数,继续尝试获取升级包
			reqget(packid)
		else
			reqcheck()
		end
	else
		-- 超过重试次数,升级失败
		upend(false)
	end
end

function reqget(idx)
	send(lid,sformat("Get%d",idx))
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
函数名：writeapgsdata
功能  ：写时间到GPS模块
参数：  无
返回值：无
]]
function writeapgsdata(dat)
	local str = "$PGKC634,"..dat.."*"
	print("writeapgsdata",str)

	writeapgs(str)
end

function writeapgs(str)
	print("syy writeapgs",str,slen(str))
	local tmp = 0
	--str = "$PGKC149,1,115200*"
	for i = 2,slen(str)-1 do
		tmp = bit.bxor(tmp,sbyte(str,i))
	end	
	tmp = string.upper(string.format("%x",tmp))
	if slen(tmp) < 2 then
	tmp = "0"..tmp
	end
	
	str = str..tmp.."\r\n"
	print("syy writeapgs str",str,slen(str))

	gps.writegk(str)
end

local AGPD_FILE = "/AGPD.txt"
local function writetxt(f,v)
	local file = io.open(f,"w")
	if file == nil then
		print("AGPS open file to write err",f)
		return
	end
	file:write(v)
	file:close()
end

local function readtxt(f)
	local file,rt = io.open(f,"r")
	if file == nil then
		print("AGPS can not open file",f)
		return ""
	end
	rt = file:read("*a")
	file:close()
	return rt
end

--[[
函数名：agpswrp
功能  ：写经纬度到GPS模块
参数：  无
返回值：无
]]
function agpswrp()
	local clk = os.date("*t")
	print("agpswrp clk",clk.year)
	if clk.year < 2017 then return end
	if mt.year == nil then
		mt = clk
	end
	local agps = readtxt(AGPD_FILE)
	print("agpswrp",agps)
	if agps == "" then return end
	agpswr()
end

--[[
函数名：agpswr
功能  ：写经纬度请求
参数：  无
返回值：无
]]
function agpswr()
	print("syy agpswr")
	local clkstr,s,i = mt
	local clk = common.transftimezone(clkstr.year,clkstr.month,clkstr.day,clkstr.hour,clkstr.min,clkstr.sec,8,0)
	s = string.format("%0d,%02d,%02d,%02d,%02d,%02d",clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec)		
	local str = getagpstr()
	if str then 
		str = str..s..'*'
		writeapgsdata(s)		
		writeapgs(str)
		sys.timer_start(gps.closegps,1000,"AGPS")
		sys.dispatch("AGPS_WRDATE_SUC")
	else
		gps.closegps("AGPS")
	end
	return true	
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

	local s = string.char(base.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. string.rep("\255",n-l)
	elseif l > n then
		s = ssub(s,1,n)
	end

	return s
end

--[[
函数名：encellinfo
功能  ：获取小区基站信息
参数：  无
返回值：无
]]
local function encellinfo(s)
	local ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = "",{}
	print("syy encellinfo",s)
	for mcc,mnc,lac,ci,rssi in string.gmatch(s,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
		mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
		local handle = nil
		for k,v in pairs(t) do
			print("syy v.lac",v.lac,lac,v.mcc,mcc,v.mnc,mnc,#v.rssici)
			if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
				if #v.rssici < 8 then
					table.insert(v.rssici,{rssi=rssi,ci=ci})
				end
				handle = true
				break
			end
		end
		print("syy handle",handle)
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

	return #t,string.char(#t)..ret
end

--[[
函数名：reqcheck
功能  ：向后台获取经纬度请求
参数：  无
返回值：无
]]
function reqcheck()
	state = "CHECK"
	
	local s = net.getcellinfoext()
	
	local num,sr = encellinfo(s)
	
	print("syy num",num)
	
	local str = lpack.pack("bAbAA",slen(PRODUCT_KEY),PRODUCT_KEY,0,bcd(misc.getimei(),8),sr)
	link.send(lid,str)		
	sys.timer_start(retry,GET_TIMEOUT)	
end

function upend(succ)
	state = "IDLE"
	-- 停止充实定时器
	sys.timer_stop(retry)
	sys.timer_stop(errpack)
	-- 断开链接
	link.close(lid)
	getretries,lid = 0
	if succ then
		reconnect = false
		retries = 0
		--写星历信息到GPS芯片
		print("eph rcv",slen(eph))
		--startwrite()
		startupdatetimer()
		if mode==1 then dispatch("AGPS_EVT","END_IND",true) end
	else
		if retries >= RETRY_TIMES then
			reconnect = false
			retries = 0
			startupdatetimer()
			if mode==1 then dispatch("AGPS_EVT","END_IND",false) end
		else
			reconnect = true
			retries = retries + 1
		end
	end
end

local agpsstr
--[[
函数名：setagpstr
功能  ：设置经纬度值
参数：  无
返回值：无
]]
local function setagpstr(str)
	agpsstr = str
	writetxt(AGPD_FILE,agpsstr)	
end

--[[
函数名：getagpstr
功能  ：获取经纬度值
参数：  无
返回值：无
]]
function getagpstr(str)
	return agpsstr	
end

--[[
函数名：setsucstr
功能  ：设置经纬度值
参数：  无
返回值：无
]]
function setsucstr()
	local lng,lat = smatch(gps.getgpslocation(),"[EW]*,(%d+%.%d+),[NS]*,(%d+%.%d+)")
	print("syy setsucstr,lng",lng,lat)
	if lng and lat then
		local str = '$PGKC635,'..lat..','..lng..',0,'
		setagpstr(str)
	end
end

local function unbcd(d)
	local byte,v1,v2
	local t = {}

	for i=1,slen(d) do
		byte = sbyte(d,i)
		v1,v2 = bit.band(byte,0x0f),bit.band(bit.rshift(byte,4),0x0f)

		if v1 == 0x0f then break end
		table.insert(t,v1)

		if v2 == 0x0f then break end
		table.insert(t,v2)
	end

	return table.concat(t)
end

local function trans(lat,lng)
	local la,ln = lat,lng
	if slen(lat)>10 then
		la = ssub(lat,1,10)
	elseif slen(lat)<10 then
		la = lat..srep("0",10-slen(lat))
	end
	if slen(lng)>10 then
		ln = ssub(lng,1,10)
	elseif slen(lng)<10 then
		ln = lng..srep("0",10-slen(lng))
	end
	
	local _,da = sfind(ssub(la,1,3),"^0*")	
	local _,dn = sfind(ssub(ln,1,3),"^0*")	
	local la1,ln1 = ssub(la,da+1,3),ssub(ln,dn+1,3)	
	
	return la1.."."..ssub(la,4,-1),ln1.."."..ssub(ln,4,-1)
end

--[[
函数名：datetime
功能  ：后台获取的时间转换为年月日时分秒
参数  ：后台时间
返回值：无
]]
local function datetime(m,cb)
	if slen(m) ~= 6 then cb(false) return end
	mt.year = 2000+sbyte(m,1)
	mt.month = sbyte(m,2)
	mt.day = sbyte(m,3)
	mt.hour = sbyte(m,4)
	mt.min = sbyte(m,5)
	mt.sec = sbyte(m,6)
	print("datetime",mt.year,mt.month,mt.day,mt.hour,mt.min,mt.sec)
	misc.setclock(mt,cb)
	return true
end

local function setTmCb()
	agpswr()
	upend(true)
end

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        idx ：socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
local function rcv(id,data)
	base.collectgarbage()
	--sys.timer_stop(retry)
	print("syy rcv",slen(data),(slen(data)<270) and common.binstohexs(data) or "")
	if slen(data) >=17 then		
		local lat,lng,latdm,lngdm = trans(unbcd(ssub(data,2,6)),unbcd(ssub(data,7,11)))
		print("syy rcv",lat,lng)
		if not lat or not lng then return end
		lastLbsLng,lastLbsLat = lng,lat  
		local str = '$PGKC635,'..lat..','..lng..',0,'
		print("syy rcv str",str)
		if not gps.isfix() then
			setagpstr(str)
		end
		gps.opengps("AGPS")
		datetime(ssub(data,12,17),setTmCb)		
		return		
	end	

	if isfix or not gpssupport then
		upend(true)
		return
	end
	
	upend(false)
	return
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		val： bool类型，消息事件结果
返回值：无
]]
local function nofity(id,evt,val)
	print("agps notify",lid,id,evt,val,reconnect)
	if id ~= lid then return end
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if evt == "CONNECT" then
		if val == "CONNECT OK" then
			reqcheck()
		else
			upend(false)
		end
	elseif evt == "CLOSE" and reconnect then
		connect()
	elseif evt == "STATE" and val == "CLOSED" then
		upend(false)
	end
end

--[[
函数名：connectcb
功能  ：连接服务器
参数  ：无
返回值：无
]]
local function connectcb()
	if not lid then
		lid = link.open(nofity,rcv)
		link.connect(lid,PROT,SVR,PORT)
	end
end

--[[
函数名：connect
功能  ：连接服务器请求
参数  ：无
返回值：无
]]
function connect()
	if ispt then
		if mode==0 then
			connectcb()
		else
			dispatch("AGPS_EVT","BEGIN_IND",connectcb)
		end		
	end
end


connect()

--注册GPS消息处理函数
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
