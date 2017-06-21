--[[
模块名称：GPS管理
模块功能：GPS打开与关闭、GPS NEMA数据解析、GPS经纬度高度速度等功能接口
模块最后修改时间：2017.02.21
]]

--定义模块,导入依赖库
local base = _G
local table = require"table"
local uart = require"uart"
local rtos = require"rtos"
local sys = require"sys"
local pio = require"pio"
local pm = require"pm"
local pmd = require"pmd"
local string = require"string"
local common = require"common"
local misc = require"misc"
local os = require"os"
local pack = require"pack"
module(...,package.seeall)

--加载常用的全局函数至本地
local print = base.print
local tonumber = base.tonumber
local tostring = base.tostring
local pairs = base.pairs
local smatch = string.match
local sfind = string.find
local slen = string.len
local ssub = string.sub
local smatch = string.match
local sbyte = string.byte
local sformat = string.format
local srep = string.rep

--gps全局信息表
local gps = {}
--控制功能全局信息表
local c = {}
--是否将NEMA数据抛出，提供给外部应用处理
local nmea_route
--串口读取到的NEMA数据缓冲区
local strgps = ""

--下面的消息和事件，是本功能模块产生内部消息时使用的参数，外部应用功能模块可注册消息处理函数，识别利用消息和事件
--GPS内部消息ID
GPS_STATE_IND = "GPS_STATE_IND"
--GPS关闭事件
GPS_CLOSE_EVT = 0
--GPS打开事件
GPS_OPEN_EVT = 1
--GPS定位成功事件（过滤了前段时间的数据）
GPS_LOCATION_SUC_EVT = 2
--GPS定位失败事件
GPS_LOCATION_FAIL_EVT = 3
--没有GPS芯片事件
GPS_NO_CHIP_EVT = 4
--有GPS芯片事件
GPS_HAS_CHIP_EVT = 5
--GPS定位成功事件（还没有过滤前段时间的数据）
GPS_LOCATION_UNFILTER_SUC_EVT = 6

--省电模式
GPS_POWER_SAVE_MODE = 0
--连续定位模式
GPS_CONTINUOUS_MODE = 1
--仅支持北斗定位
GPS_SINGLE_BEIDOU_GNSS = 2
--仅支持GPS定位
GPS_SINGLE_GPS_GNSS = 3
--GPS和北斗混合定位
GPS_MIX_GNSS = 4
--NEMA协议版本
GPS_NMEA_VERSION = 5
--查询PACC
QRY_PACC = 6

--经纬度为度的格式
GPS_DEGREES = 0
--经纬度为度分的格式
GPS_DEGREES_MINUTES = 1

--格林威治时间
GPS_GREENWICH_TIME = 0
--北京时间
GPS_BEIJING_TIME = 1
--越南时间
GPS_VIETNAM_TIME = 2

--速度单位为海里每小时
GPS_KNOT_SPD = 0
--速度单位为公里每小时
GPS_KILOMETER_SPD = 1

--nogpschipcnt：gps开启后，如果读取nogpschipcnt次串口，都没有收到数据，则认为没有GPS芯片
--hdop,paccflg,paccqry,pacc：判断gps定位精度的4个参数
local nogpschipcnt,hdop,paccflg,paccqry,pacc = 5

--[[
函数名：abs
功能  ：求两个数之差的绝对值
参数  ：
		v1：第一个数
		v2：第二个数
返回值：差的绝对值
]]
local function abs(v1,v2)
	return ((v1>v2) and (v1-v2) or (v2-v1))
end

--[[
local function emptyque()
	gps.dataN,gps.A,gps.L = 0,{},{}
end
]]

local function getmilli(v,vr)
	local L,ov1,v1,v2,R,T,OT = slen(v)
	if (L ~= 4 and L ~= 5) or slen(vr) ~= 5 then
		print("gps data not right", v, vr)
		return
	end
	v2 = ssub(v,1,L-2)
	v1 = tostring(tonumber(ssub(v,L-1,L) .. vr)*10/6)
	ov1 = ssub(v,L-1,L) .. vr
	L = slen(v1)
	if L > 7 then
		v1 = ssub(v1,1,7)
	elseif L < 7 then
		v1 = srep("0", 7-L) .. v1
	end
	L = slen(ov1)
	if L > 7 then
		ov1 = ssub(ov1,1,7)
	elseif L < 7 then
		ov1 = ov1 .. string.rep("0", 7-L)
	end

	T = v2 .. "." .. v1
	OT = v2 .. "." .. ov1
	R = tonumber(v2..ssub(v1,1,5)) * 36 + tonumber(ssub(v1,6,7))*36/100
	return OT,T,R
end

--[[
函数名：getstrength
功能  ：解析GSV数据
参数  ：
		sg：NEMA中的一行GSV数据
返回值：无
]]
local function getstrength(sg)
	local d1,d2,curnum,lineno,total,sgv_str = sfind(sg,gps.gsvprefix.."GSV,(%d),(%d),(%d+),(.*)%*.*")
	if not curnum or not lineno or not total or not sgv_str then
		return
	end
	if tonumber(lineno)== 1  then
		gps.sates = ""
		gps.sn = 0
		--gps.gsv = ""
	end

	local tmpstr,i = sgv_str
	for i=1,4 do
		local d1,d2,id,elevation,azimuth,strength = sfind(tmpstr,"(%d+),(%d*),(%d*),(%d*)")
		if id == nil then
			return
		end
		if strength == "" or not strength then
			strength = "00"
		end
		strength = tonumber(strength)
		if strength and strength < 60 then
			gps.sates = gps.sates .. id .. string.format("%02d",strength) .. " "
			if strength > gps.sn then
				gps.sn = strength
			end
		end
		local idx,cur,fnd,tmpid = 0,id..","..elevation..","..azimuth..","..strength..",",false
		for tmpid in string.gmatch(gps.gsv,"(%d+),%d*,%d*,%d*,") do
			idx = idx + 1
			if tmpid == id then fnd = true break end
		end
		if fnd then
			local pattern,i = ""
			for i=1,idx do
				pattern = pattern.."%d+,%d*,%d*,%d*,"
			end
			local m1,m2 = sfind(gps.gsv,"^"..pattern)
			if m1 and m2 then
				local front = ssub(gps.gsv,1,m2)
				local n1,n2 = sfind(front,"%d+,%d*,%d*,%d*,$")
				if n1 and n2 then
					if (gps.gsvprefix == "GP" and tonumber(id) <= 32) or gps.gsvprefix == "" then
						gps.gsv = ssub(gps.gsv,1,n1-1)..cur..ssub(gps.gsv,n2+1,-1)
					end
				end
			end
		else
			if (gps.gsvprefix == "GP" and tonumber(id) <= 32) or gps.gsvprefix == "" then
				gps.gsv = gps.gsv..cur
			end
		end
		
		tmpstr = ssub(tmpstr,d2+1,-1)
	end
end

local function getvg(A,L)
	local A1,A2,L1,L2,t1
	t1 = slen(L)
	A1 = ssub(A,1,4)
	A2 = ssub(A,5,8).."0"
	L1 = ssub(L,1,t1-4)
	L2 = ssub(L,t1-3,t1).."0"
	return A1,A2,L1,L2
end

--[[
local function getd(I)
	return abs(gps.A[I],gps.A[I-1]) + abs(gps.L[I],gps.L[I-1])
end
]]

local function push(A,L)
	--print("push", A, L)
	--[[table.insert(gps.A, A)
	table.insert(gps.L, L)
	gps.dataN = gps.dataN + 1
	if gps.dataN > gps.QueL then
		table.remove(gps.A, 1)
		table.remove(gps.L, 1)
		local a1,a2,I
		I = (gps.QueL+1)/2
		a1 = getd(I) + getd(I+1)
		a2 = 0
		for i = 2, gps.QueL do
			if i ~= I and i ~= (I+1) then
				a2 = a2 + getd(i)
			end
		end
		if a2 < gps.errL*(gps.QueL-2) and a1 > gps.errD then
			print("gps run", gps.A[I], gps.L[I])
			gps.A[I] = gps.A[I+1]
			gps.L[I] = gps.L[I+1]
		end
		return getvg(gps.A[I], gps.L[I])
	end]]
	return getvg(A,L)
end

local function filter(LA,RA,LL,RL)
	--print("gps data", LA,RA,LL,RL,gps.dataN,gps.cgen)

	--[[if (c.gps - gps.cgen) > 10 then
		print("longtime no gps",c.gps,gps.cgen)
		emptyque()
	end]]

	if slen(LA) ~= 4 or (slen(LL) ~= 5 and slen(LL) ~= 4) then
		print("err LA or LL", LA, LL)
		return
	end

	if slen(RA) < 4 then
		RA = RA .. srep("0", 4 - slen(RA))
	end
	if slen(RL) < 4 then
		RL = RL .. srep("0", 4 - slen(RL))
	end
	local A = LA .. ssub(RA,1,4)
	local L = LL .. ssub(RL,1,4)
	A = tonumber(A) or 0
	L = tonumber(L) or 0

	gps.cgen = c.gps
	return push(A, L)
end

--[[
函数名：rtctolocal
功能  ：GPS时间转化为本模块内设置的时区时间
参数  ：
		y,m,d,hh,mm,ss：GPS时间中的年月日时分秒
返回值：本模块内设置的时区时间(table类型，t.year,t.month,t.day,t.hour,t.min,t.sec)
]]
local function rtctolocal(y,m,d,hh,mm,ss)
	--print("rtctolocal",y,m,d,hh,mm,ss)
	local flg
	if not y or not m or not d or not hh or not mm or not ss then
		return
	end
	if gps.timezone == GPS_BEIJING_TIME then
		hh = hh + 8
		flg = true
	elseif gps.timezone == GPS_VIETNAM_TIME then
		hh = hh + 7
		flg = true
	end
	if flg then
		if hh >= 24 then
			hh = hh - 24
			d = d + 1
			if m == 4 or m == 6 or m == 9 or m == 11 then
				if d > 30 then
					d = 1
					m = m + 1
				end
			elseif m == 1 or m == 3 or m == 5 or m == 7 or m == 8 or m == 10 then
				if d > 31 then
					d = 1
					m = m + 1
				end
			elseif m == 12 then
				if d > 31 then
					d = 1
					m = 1
					y = y + 1
				end
			elseif m == 2 then
				if (((y+2000)%400) == 0) or (((y+2000)%4 == 0) and ((y+2000)%100 ~=0)) then
					if d > 29 then
						d = 1
						m = 3
					end
				else
					if d > 28 then
						d = 1
						m = 3
					end
				end
			end
		end
	end
	local t = {}
	t.year,t.month,t.day,t.hour,t.min,t.sec = 2000 + y,m,d,hh,mm,ss
	return t
end

--[[
函数名：needupdatetime
功能  ：是否需要更新系统时间为新时间
参数  ：
		newtime：新时间
返回值：true需要更新，false不需要更新
]]
function needupdatetime(newtime)
	if newtime and os.time(newtime) and os.date("*t") and os.time(os.date("*t")) then
		local secdif = os.difftime(os.time(os.date("*t")),os.time(newtime))
		if secdif and secdif >= 60 or secdif <= -60 then
			print("needupdatetime",secdif)
			return true
		end
	end
	return false
end

--[[
函数名：proc
功能  ：处理每条NEMA数据
参数  ：
		s：一条NEMA数据
返回值：无
]]
local function proc(s)
	local latti,lattir,longti,longtir,spd1,cog1,gpsfind,gpstime,gpsdate,numofsate,numoflocationsate,hdp

	if s == "" or s == nil then
		return
	end

	gps.find = ""

	--GGA数据
	if smatch(s, "GGA") then
		local hh,sep
		latti,lattir,gps.latyp,longti,longtir,gps.longtyp,gpsfind,numoflocationsate,hdp,hh,sep = smatch(s,"GGA,%d+%.%d+,(%d+)%.(%d+),([NS]),(%d+)%.(%d+),([EW]),(%d),(%d+),([%d%.]*),(.*),M,(.*),M")
		if (gpsfind == "1" or gpsfind == "2" or gpsfind == "4") and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil then
			gps.find = "S"
			if hh ~= nil then
				gps.haiba = hh
			end
			if sep then gps.sep = sep end
			gps.ggalng,gps.ggalat = longti.."."..longtir,latti.."."..lattir
		end
		if hdp then hdop = hdp end
	--RMC数据
	elseif smatch(s, "RMC") then
		gpstime,gpsfind,latti,lattir,gps.latyp,longti,longtir,gps.longtyp,spd1,cog1,gpsdate = smatch(s,"RMC,(%d%d%d%d%d%d)%.%d+,(%w),(%d+)%.(%d+),([NS]),(%d+)%.(%d+),([EW]),(.-),(.-),(%d%d%d%d%d%d),")
		if gpsfind == "A" and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil  then
			gps.find = "S"
		end
		if gpsfind == "A" and gpstime and gpsdate and gpstime ~= "" and gpsdate ~= "" then
			local yy,mm,dd,h,m,s = tonumber(ssub(gpsdate,5,6)),tonumber(ssub(gpsdate,3,4)),tonumber(ssub(gpsdate,1,2)),tonumber(ssub(gpstime,1,2)),tonumber(ssub(gpstime,3,4)),tonumber(ssub(gpstime,5,6))
			gps.utctime = {year=2000+yy,month=mm,day=dd,hour=h,min=m,sec=s}
			if gps.timezone then
				local newtime = rtctolocal(yy,mm,dd,h,m,s)
				if needupdatetime(newtime) then
					misc.setclock(newtime)
				end
			end
		end
	--GSV数据
	elseif smatch(s,"GSV") then
		numofsate = smatch(s,"GSV,%d+,%d+,(%d+),%d+,%d+,%d+,%d+")
		getstrength(s)
	--GSA数据
	elseif smatch(s,"GSA") then
		local satesn = smatch(s,"GSA,%w*,%d*,(%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,)") or ""
		local mtch,num = true
		if gps.gsaprefix == "GP" then			
			for num in string.gmatch(satesn,"(%d*),") do
				if slen(num) > 0 and tonumber(num) > 32 then
					mtch = false
					break
				end
			end			
		end
		if mtch and slen(satesn) > 0 and smatch(satesn,"%d+,") then
			gps.satesn = satesn
		end
	end

	--定位成功
	if gps.find == "S" then
		if gps.filterbgn == nil and gps.filtertime > 0 then
			gps.filterbgn = c.gps
			gps.find = ""
			print("filter gps " .. gps.filtertime .. " secs begin")
			sys.dispatch(GPS_STATE_IND,GPS_LOCATION_UNFILTER_SUC_EVT)
			return
		elseif gps.filterbgn and c.gps - gps.filterbgn < gps.filtertime then
			gps.find = ""
			return
		end
	end

	--可见卫星个数
	numofsate = tonumber(numofsate or "0")
	if numofsate > 9 then
		numofsate = 9
	end
	if numofsate > 0 then
		gps.satenum = numofsate
	end

	--定位使用的卫星个数
	numoflocationsate = tonumber(numoflocationsate or "0")
	if numoflocationsate > 9 then
		numoflocationsate = 9
	end
	if numoflocationsate > 0 then
		gps.locationsatenum = numoflocationsate
	end

	--速度
	if spd1 and spd1 ~= "" then
		local r1,r2 = smatch(spd1, "(%d+)%.*(%d*)")
		if r1 then
			if gps.spdtyp == GPS_KILOMETER_SPD then
				gps.spd = (tonumber(r1)*1852/1000)
			else
				gps.spd = tonumber(r1)
			end
		end
	end
	
	--方向角
	if cog1 and cog1 ~= "" then
		local r1,r2 = smatch(cog1, "(%d+)%.*(%d*)")
		if r1 then
			gps.cog = tonumber(r1)
			local r3 = abs(gps.cog, gps.lastcog)
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

	--经纬度
	local LA, RA, LL, RL = filter(latti,lattir,longti,longtir)
	--print("filterg", LA, RA, LL, RL)
	if not LA or not RA or not LL or not RL then
		return
	end

	gps.olati, gps.lati, gps.latt_m  = getmilli(LA, RA)
	gps.olong, gps.long, gps.longt_m = getmilli(LL, RL)
	gps.long = gps.long or 0
	gps.lati = gps.lati or 0
	gps.olong = gps.olong or 0
	gps.olati = gps.olati or 0
end

--[[
函数名：diffofloc
功能  ：计算两对经纬度之间的直线距离（近似值）
参数  ：
		latti1：纬度1（度格式，例如31.12345度）
		longti1：经度1（度格式）
		latti2：纬度2（度格式）
		longti2：经度2（度格式）
		typ：距离类型
返回值：typ如果为true，返回的是直线距离(单位米)的平方和；否则返回的是直线距离(单位米)
]]
function diffofloc(latti1, longti1, latti2, longti2,typ) --typ=true:返回a+b ; 否则是平方和
	local I1,I2,R1,R2,diff,d
	I1,R1=smatch(latti1,"(%d+)%.(%d+)")
	I2,R2=smatch(latti2,"(%d+)%.(%d+)")
	if not I1 or not I2 or not R1 or not R2 then
		return 0
	end

	R1 = I1 .. ssub(R1,1,5)
	R2 = I2 .. ssub(R2,1,5)
	d = tonumber(R1)-tonumber(R2)
	d = d*111/100
	if typ == true then
		diff =  (d>0 and d or (-d))
	else
		diff = d * d
	end
		
	I1,R1=smatch(longti1,"(%d+)%.(%d+)")
	I2,R2=smatch(longti2,"(%d+)%.(%d+)")
	if not I1 or not I2 or not R1 or not R2 then
		return 0
	end

	R1 = I1 .. ssub(R1,1,5)
	R2 = I2 .. ssub(R2,1,5)
	d = tonumber(R1)-tonumber(R2)
	if typ == true then
		diff =  diff + (d>0 and d or (-d))
	else
		diff =  diff + d*d
	end
	--diff =  diff + d*d
	print("all diff:", diff)
	return diff
end

local function startpaccqry(flg)
	if paccflg then
		if not flg and not paccqry then return end
		paccqry = true
		writegps(QRY_PACC)
	end
end

local function stoppaccqry()
	paccqry = nil
end

--[[
函数名：setmnea
功能  ：设置“是否将NEMA数据抛出，提供给外部应用处理”标志
参数  ：
		flg：true为抛出NEMA数据，false或者nil不抛出；如果设置了抛出，外部应用注册内部消息"GPS_NMEA_DATA"的处理函数即可接收NEMA数据
返回值：无
]]
function setmnea(flg)
	nmea_route = flg
end

--[[
函数名：read
功能  ：串口数据接收处理函数
参数  ：无
返回值：无
]]
local function read()
	local gpsreadloop = true
	if gps.open then
		--启动1秒的定时器，每秒去读一次串口数据
		sys.timer_start(read,gps.period)
	end

	c.gps = c.gps + 1
	while gpsreadloop do
		strgps = strgps..writeack(uart.read(gps.uartid, "*l", 0))
		if slen(strgps) == 0 then
			--连续读了nogpschipcnt次串口，都没有数据，则认为没有gps芯片
			if not c.nogps and c.hasgps == 0 and c.gps >= nogpschipcnt then
				sys.dispatch(GPS_STATE_IND,GPS_NO_CHIP_EVT)
				c.nogps = true
				return
			end
			gpsreadloop = false
		else
			--串口有数据，则认为有gps芯片
			if c.hasgps == 0 then
				c.hasgps = c.gps
				sys.dispatch(GPS_STATE_IND,GPS_HAS_CHIP_EVT)
			end
		end
		--读取一行NEMA数据
		local d1,d2,itemstr = sfind(strgps,"\r\n")
		while d1 do
			itemstr = ssub(strgps,1,d1+1)
			strgps = ssub(strgps,d2+1,-1)
			--解析一行NEMA数据
			proc(itemstr)
			--如果需要抛出NEMA数据给外部应用使用
			if nmea_route then
				sys.dispatch('GPS_NMEA_DATA',itemstr)
			end
			if c.gpsprt ~= c.gps then
				c.gpsprt = c.gps
				print("gps rlt", gps.longtyp,gps.olong,gps.long,gps.latyp,gps.olati,gps.lati,gps.locationsatenum,gps.sn,gps.satenum)
			end
			--定位成功
			if gps.find == "S" then
				gps.findall = true
				c.gpsfind = c.gps
				local oldstat = gps.state
				gps.state = 1
				if oldstat ~= 1 or gps.gnsschange then
					gps.gnsschange = false
					sys.dispatch(GPS_STATE_IND,GPS_LOCATION_SUC_EVT)
					print("dispatch GPS_LOCATION_SUC_EVT")
					lastesttimerfunc()
					startlastesttimer()
					startpaccqry(true)
					c.fixitv = c.gps-c.fixbgn
				end
			--定位失败
			elseif ((c.gps - c.gpsfind) > 20 or gps.gnsschange) and gps.state == 1 then
				print("location fail")
				if not gps.gnsschange then
					c.fixbgn = c.gps
					sys.dispatch(GPS_STATE_IND,GPS_LOCATION_FAIL_EVT)
					print("dispatch GPS_LOCATION_FAIL_EVT")				
					stoppaccqry()
				end
				lastesttimerfunc()
				gps.findall = false
				gps.state = 2
				gps.satenum = 0
				gps.locationsatenum = 0
				gps.filterbgn = nil
				gps.spd = 0			
			end
			d1,d2 = sfind(strgps,"\r\n")
		end

		
	end
end

function writeack(dat)
	if not dat or slen(dat) == 0 or not gps.curwritem or not gps.curwritem.ack then return dat end

	local hexdat = common.binstohexs(dat)
	local cmd = common.binstohexs(gps.curwritem.cmd)
	
	local d1,d2 = sfind(hexdat,"B56205")	
	if d1 and d2 and cmd then
		local ret,id = ssub(hexdat,d2+1,d2+2),ssub(hexdat,d2+7,d2+10)
		print("writeack",ret,id)
		if ret == "01" and id == ssub(cmd,5,8) then
			if id == "063E" then
				gps.gnsschange = true
			end
			resetwrite()
			write()
		elseif ret == "00" then
			sys.timer_stop(writetimeout)
			writetimeout()
		end
		return common.hexstobins(ssub(hexdat,1,d1-1) .. ssub(hexdat,d2+15,-1))
	end
	
	d1,d2 = sfind(hexdat,"B5620101")
	if d1 and d2 and cmd and paccflg then		
		resetwrite()
		write()
		local _,pac = pack.unpack(common.hexstobins(ssub(hexdat,d2+37,d2+44) or "00000000"),"<l")
		if pac then pacc = pac end
		startpaccqry()
	end
	return dat
end

local function writedata()
	gps.curwritem = table.remove(gps.wrquene,1)
	gps.retrywrcnt = 0
	uart.write(gps.uartid,gps.curwritem.cmd)
	print("gps write",common.binstohexs(gps.curwritem.cmd))
	if gps.curwritem.ack then
		sys.timer_start(writetimeout,1500)
	else
		gps.curwritem = nil
	end
end

function write()
	if gps.curwritem then return end

	if #gps.wrquene == 0 then
		closegps("WRGPS")
		return
	end

	if not gps.open then
		opengps("WRGPS")
		uart.write(gps.uartid,"\255")
		sys.timer_start(writedata,600)
		gps.curwritem = {}
	else
		writedata()
	end
end

function resetwrite()
	gps.curwritem = nil
	gps.retrywrcnt = 0
	sys.timer_stop(writetimeout)
end

function writetimeout()
	print("gps writetimeout",gps.retrywrcnt)
	if gps.retrywrcnt < gps.retrywrmaxcnt then
		uart.write(gps.uartid,gps.curwritem.cmd)
		sys.timer_start(writetimeout,1500)
		gps.retrywrcnt = gps.retrywrcnt + 1
	else
		resetwrite()
		write()
	end
end

function writegpscmd(ishexstr,dat,ack)
	local cmd = ((ishexstr == true) and common.hexstobins(dat) or dat)
	if cmd == nil or string.len(cmd) == 0 then print("writegpscmd err") return end
	local item = {cmd=cmd,ack=ack}

	table.insert(gps.wrquene,item)

	if not gps.curwritem then
		write()
	end
end

--[[
函数名：writegps
功能  ：向GPS芯片里写命令数据（仅适用于UBLOX GPS模块）
参数  ：
		typ：命令类型
返回值：无
]]
function writegps(typ)
	print("gps writegps",typ)
	--省电模式
	if typ == GPS_POWER_SAVE_MODE then
		--cyclic  update period(10)  search period(60)  acquisition timeout(5)  on time(3)
		writegpscmd(true,"B562063B2C0001060000009002001027000060EA00000000000003000A002C0100004FC1030086020000FE00000064400100FFE2",true)
		writegpscmd(true,"B5620611020008012292",true)
		writegpscmd(true,"B56206090D0000000000FFFF0000000000000721AF",true)
	--连续定位模式
	elseif typ == GPS_CONTINUOUS_MODE then
		writegpscmd(true,"B5620611020008002191",true)
		writegpscmd(true,"B56206090D0000000000FFFF0000000000000721AF",true)
	--仅支持北斗定位
	elseif typ == GPS_SINGLE_BEIDOU_GNSS then
		--gps.gnsschange = true
		writegpscmd(true,"B562063E2C0000002005000810000000010101010300010001010308100001000101050003000100010106080E0000000101FE29",true)
	--仅支持GPS定位
	elseif typ == GPS_SINGLE_GPS_GNSS then
		--gps.gnsschange = true
		writegpscmd(true,"B562063E2C0000002005000810000100010101010300010001010308100000000101050003000100010106080E0001000101FF3D",true)
	--GPS和北斗混合定位
	elseif typ == GPS_MIX_GNSS then
		--gps.gnsschange = true
		writegpscmd(true,"B562063E2C0000002005000810000100010101010300010001010308100001000101050003000100010106080E0000000101FF4D",true)
	--NEMA协议版本
	elseif typ == GPS_NMEA_VERSION then
		writegpscmd(true,"B5620617140000410002000000000000000000E0000000000000546E",true)
	--查询PACC
	elseif typ == QRY_PACC then
		writegpscmd(true,"B562010100000207",true)
	else
		print("writegps err",typ)
	end
end

--[[
函数名：opengps
功能  ：打开GPS
参数  ：
		tag：打开标记，用来表示哪一个应用打开了GPS
返回值：无
]]
function opengps(tag)
	print("opengps",tag)
	gps.opentags[tag] = 1
	if gps.open then
		print("gps has open")
		return
	end
	pm.wake("gps")
	gps.open = true
	openuart()
	gps.filterbgn = nil
	if gps.io then
		if gps.edge then
			pio.pin.sethigh(gps.io)
		else
			pio.pin.setlow(gps.io)
		end
	end
	pmd.ldoset(7,pmd.LDO_VASW)
	gps.gnsschange = false
	--writegps(GPS_NMEA_VERSION)
	print("gps open")
	c.fixbgn = c.gps
	sys.dispatch(GPS_STATE_IND,GPS_OPEN_EVT)
end

--[[
函数名：closegps
功能  ：关闭GPS
参数  ：
		tag：关闭标记，用来表示哪一个应用关闭了GPS
返回值：无
]]
function closegps(tag)
	print("closegps",tag)
	gps.opentags[tag] = 0
	for k,v in pairs(gps.opentags) do
		if v > 0 then
			print("gps close using",k)
			return
		end
	end

	if not gps.open then
		print("gps has close")
		return
	end
	lastesttimerfunc()
	if gps.io then
		if gps.edge then
			pio.pin.setlow(gps.io)
		else
			pio.pin.sethigh(gps.io)
		end
	end
	pmd.ldoset(0,pmd.LDO_VASW)
	closeuart()
	pm.sleep("gps")	
	gps.open = false
	if gps.state == 1 then
		gps.state = 2
	end	
	gps.latt_m = 0
	gps.longt_m = 0
	--gps.lati = 0
	--gps.long = 0
	gps.spd = 0
	gps.cog = 0
	gps.haiba = 0
	gps.sep = ""
	gps.ggalng,gps.ggalat = "",""
	gps.satesn = ""
	gps.lastcog = 0
	gps.cogchange = false
	gps.find = ""
	gps.findall = false
	gps.satenum = 0
	gps.locationsatenum = 0
	gps.sn = 0
	gps.sates = ""
	gps.gsv = ""
	gps.gnsschange = false
	print("gps close")
	sys.dispatch(GPS_STATE_IND,GPS_CLOSE_EVT)
	stoppaccqry()
end

--[[
函数名：getgpslocation
功能  ：获取GPS经纬度信息
参数  ：
		format：经纬度格式，默认为度格式GPS_DEGREES，支持GPS_DEGREES和GPS_DEGREES_MINUTES
返回值：经纬度信息字符串，例如格式为："E,121.12345,N,31.23456"，如果没有经纬度格式为"E,,N,"
]]
function getgpslocation(format)
	local rstr = (gps.longtyp and gps.longtyp or "E") .. ","
	local lo,la
	if format == nil or format == GPS_DEGREES then
		lo,la = gps.long,gps.lati
	elseif format == GPS_DEGREES_MINUTES then
		lo,la = gps.olong,gps.olati
	end
	if lo and lo ~= 0 and lo ~= "0" and lo ~= "" then
		rstr = rstr .. lo
	end
	rstr = rstr .. "," .. (gps.latyp and gps.latyp or "N") .. ","
	if la and la ~= 0 and la ~= "0" and la ~= "" then
		rstr = rstr .. la
	end
	return rstr
end

--[[
函数名：getgpssatenum
功能  ：获取GPS可见卫星个数
参数  ：无
返回值：GPS可见卫星个数
]]
function getgpssatenum()
	return gps.satenum or 0
end

--[[
函数名：getgpslocationsatenum
功能  ：获取GPS定位使用的卫星个数
参数  ：无
返回值：GPS定位使用的卫星个数
]]
function getgpslocationsatenum()
	return gps.locationsatenum or 0
end

--[[
函数名：getgpsspd
功能  ：获取速度
参数  ：无
返回值：速度
]]
function getgpsspd()
	return gps.spd or 0
end

--[[
函数名：getgpscog
功能  ：获取方向角
参数  ：无
返回值：方向角
]]
function getgpscog()
	return gps.cog or 0
end

--[[
函数名：getgpssn
功能  ：获取最强卫星的信噪比
参数  ：无
返回值：最强卫星的信噪比
]]
function getgpssn()
	return gps.sn or 0
end

function getpara()
	local t = {hdop=0,gsasatecnt=0,gsasateavgsn=0,pacc=0}
	--if isfix() then
		t.hdop = tonumber(smatch(hdop or "","(%d+)%.(%d*)") or "65535");
		
		local gsasate,gsasatesn,id = getsatesn(),{}
		for id in string.gmatch(gsasate,"(%d*),") do
			if id ~= "" then
				t.gsasatecnt = t.gsasatecnt + 1
				gsasatesn[id] = 0
			end
		end
		
		local satecnt,k,v,sn = 0
		for k,v in pairs(gsasatesn) do
			for id,sn in string.gmatch(gps.gsv,"(%d+),%d*,%d*,(%d+),") do
				if k == id then
					satecnt = satecnt + 1
					gsasatesn[id] = tonumber(sn or "0")
				end
			end
		end
		local cnt = isfix() and getgpslocationsatenum() or 3
		if cnt > satecnt then cnt = satecnt end
		if cnt > 3 then cnt = 3 end
		if cnt > 0 then
			for sn=1,cnt do
				local maxv,maxk = -1
				for k,v in pairs(gsasatesn) do
					if v > maxv then
						maxk,maxv = k,v
					end
				end
				if maxk then
					t.gsasateavgsn = t.gsasateavgsn + maxv
					gsasatesn[maxk] = -1
				end
			end
			t.gsasateavgsn = t.gsasateavgsn / cnt
		end
		
		t.pacc = (pacc or 0)/100
	--end
	
	print("gps.getpara",t.hdop,t.gsasatecnt,cnt,t.gsasateavgsn,t.pacc)
	return t
end

--[[
函数名：isfix
功能  ：检查GPS是否定位成功
参数  ：无
返回值：true为定位成功，false为失败
]]
function isfix()
	return gps.state == 1
end

--[[
函数名：isopen
功能  ：检查GPS是否打开
参数  ：无
返回值：true为打开，false为关闭
]]
function isopen()
	return gps.open
end

--[[
函数名：getaltitude
功能  ：获取高度
参数  ：无
返回值：高度
]]
function getaltitude()
	return gps.haiba or 0
end

function getsep()
	return gps.sep or 0
end

function getggaloc()
	return gps.ggalng or "",gps.ggalat or ""
end

function getsatesn()
	return gps.satesn or ""
end

function getgsv()
	return gps.gsv or ""
end

function setgsv(prefix)
	gps.gsvprefix = prefix or ""
end

function setgsa(prefix)
	gps.gsaprefix = prefix or ""
end

function getsatesinfo()
	local tmp = gps.sates
	print("getsatesinfo",tmp)
	local ret = ""
	if string.len(tmp) > 0 then
		tmp = string.sub(tmp,1,-2)
	end
	local sate = ""
	for sate in string.gmatch(tmp, "(%d+)") do
		local id,strength = string.sub(sate,1,2),string.sub(sate,3,4)
		if id and strength and id <= "32" and strength > "00" then
			if ret == "" then
				ret = sate .. " "
			else
				local d1,d2,sn = string.find(ret,id .. "(%d+)")
				if d1 and d2 and sn then
					if strength > sn then
						ret = string.sub(ret,1,d1+1) .. strength .. string.sub(ret,d2+1,-1)
					end
				else
					ret = ret .. sate .. " "
				end
			end
		end
	end
	if string.len(ret) > 0 then
		return string.sub(ret,1,-2)
	else
		return ret
	end
end

--[[
函数名：init
功能  ：配置GPS
参数  ：
		ionum：GPS供电的GPIO
		dir：此参数没用（为了兼容之前的代码，不能去掉），随便传，
		edge：true表示GPIO输出高电平供电，false或者nil表示GPIO输出低电平供电
		period：串口读取NEMA数据间隔，单位毫秒，建议1000毫秒读取一次
		id：串口ID，1表示串口1,2表示串口2
		baud：串口波特率，例如9600
		databits：数据位，例如8
		parity：校验位，例如uart.PAR_NONE
		stopbits：停止位，例如uart.STOP_1
		apgspwronupd：是否允许开机就执行AGPS功能
返回值：无
]]
function init(ionum,dir,edge,period,id,baud,databits,parity,stopbits,apgspwronupd)
	gps.open = false
	gps.wrquene = {}
	gps.curwritem = nil
	gps.retrywrcnt = 0
	gps.retrywrmaxcnt = 3
	gps.latt_m = 0
	gps.longt_m = 0
	gps.lati = 0
	gps.long = 0
	gps.olati = 0
	gps.olong = 0
	gps.latyp = "N"
	gps.longtyp = "E"
	gps.spd = 0
	gps.cog = 0
	gps.haiba = 0
	gps.satesn = ""
	gps.sep = ""
	gps.ggalng,gps.ggalat = "",""
	gps.gsv,gps.gsvprefix = "",""
	gps.gsaprefix = ""
	gps.lastcog = 0
	gps.cogchange = false
	gps.state = 0
	gps.find = ""
	gps.findall = false
	gps.satenum = 0
	gps.locationsatenum = 0
	gps.sn = 0
	gps.sates = ""
	gps.gnsschange = false
	gps.filterbgn = nil
	gps.filtertime = 5
	gps.timezone = nil
	gps.spdtyp = GPS_KILOMETER_SPD	
	gps.opentags = {}
	gps.isagpspwronupd = (apgspwronupd == nil) and true or apgspwronupd

	c.gps = 0
	c.hasgps = 0
	c.gpsfind = 0
	c.GpsPrtMod = 180
	c.gpsprint = 0
	c.fixbgn = 0
	c.fixitv = 0

	--emptyque()
	gps.cgen = 0
	gps.QueL = 7
	gps.errL = 100
	gps.errD = 600

	gps.io = ionum
	gps.edge = edge

	gps.period = period
	gps.uartid = id
	gps.baud = baud
	gps.databits = databits
	gps.parity = parity
	gps.stopbits = stopbits

	if ionum then
		pio.pin.setdir(pio.OUTPUT,ionum)
	end
end

--[[
函数名：setgpsfilter
功能  ：设置GPS定位成功过滤时间
参数  ：
		secs：过滤的秒数，例如5，表示GPS定位成功后，扔掉前5秒的定位信息
返回值：无
]]
function setgpsfilter(secs)
	if secs >= 0 then
		gps.filtertime = secs
	end
end

--[[
函数名：settimezone
功能  ：设置软件系统的时区，调用此接口后，GPS获取到时间后，会设置对应时区的系统时间
参数  ：
		zone：目前支持GPS_GREENWICH_TIME、GPS_BEIJING_TIME、GPS_VIETNAM_TIME
返回值：无
]]
function settimezone(zone)
	gps.timezone = zone
end

--[[
函数名：setspdtyp
功能  ：设置速度类型
参数  ：
		typ：目前支持GPS_KNOT_SPD、GPS_KILOMETER_SPD
返回值：无
]]
function setspdtyp(typ)
	gps.spdtyp = typ
end

function closeuart()
	print("gps closeuart")
	uart.close(gps.uartid)
	--rtos.sleep(400)
	sys.timer_stop(read)
end

function openuart()
	print("gps openuart")
	--uart.sleep(200)
	uart.setup(gps.uartid,gps.baud,gps.databits,gps.parity,gps.stopbits)
	sys.timer_start(read,gps.period)
end

function getutctime()
	return gps.utctime
end

function getfixitv()
	return isfix() and c.fixitv or 0
end

function isagpspwronupd()
	return (gps.isagpspwronupd == nil) and true or gps.isagpspwronupd
end

function lastesttimerfunc()
	if gps.lastestflg and gps.lastestprd and gps.lastestcb then
		gps.lastestcb()
		if not isfix() then
			sys.timer_stop(lastesttimerfunc)
		end
	end
end

function startlastesttimer()
	if isfix() and gps.lastestflg and gps.lastestprd and gps.lastestcb then
		sys.timer_loop_start(lastesttimerfunc,gps.lastestprd)
	end
end

function setlastest(flg,prd,cb)
	gps.lastestflg = flg
	gps.lastestprd = prd or 5000
	gps.lastestcb = cb
	startlastesttimer()
end

function setflag(pacflg)
	paccflg = pacflg
end



--“GPS应用”：指的是使用GPS功能的一个应用
--例如，假设有如下3种需求，要打开GPS，则一共有3个“GPS应用”：
--“GPS应用1”：每隔1分钟打开一次GPS
--“GPS应用2”：设备发生震动时打开GPS
--“GPS应用3”：收到一条特殊短信时打开GPS
--只有所有“GPS应用”都关闭了，才会去真正关闭GPS

--[[
每个“GPS应用”打开或者关闭GPS时，最多有4个参数，其中 GPS工作模式和“GPS应用”标记 共同决定了一个唯一的“GPS应用”：
1、GPS工作模式(必选)
2、“GPS应用”标记(必选)
3、GPS开启最大时长[可选]
4、回调函数[可选]
例如gps.open(gpsapp.TIMERORSUC,{cause="TEST",val=120,cb=testgpscb})
gps.TIMERORSUC为GPS工作模式，"TEST"为“GPS应用”标记，120秒为GPS开启最大时长，testgpscb为回调函数
]]


--[[
GPS工作模式，共有如下3种
1、DEFAULT
   (1)、打开后，GPS定位成功时，如果有回调函数，会调用回调函数
   (2)、使用此工作模式调用gps.open打开的“GPS应用”，必须调用gps.close才能关闭
2、TIMERORSUC
   (1)、打开后，如果在GPS开启最大时长到达时，没有定位成功，如果有回调函数，会调用回调函数，然后自动关闭此“GPS应用”
   (2)、打开后，如果在GPS开启最大时长内，定位成功，如果有回调函数，会调用回调函数，然后自动关闭此“GPS应用”
   (3)、打开后，在自动关闭此“GPS应用”前，可以调用gps.close主动关闭此“GPS应用”，主动关闭时，即使有回调函数，也不会调用回调函数
3、TIMER
   (1)、打开后，在GPS开启最大时长时间到达时，无论是否定位成功，如果有回调函数，会调用回调函数，然后自动关闭此“GPS应用”
   (2)、打开后，在自动关闭此“GPS应用”前，可以调用gps.close主动关闭此“GPS应用”，主动关闭时，即使有回调函数，也不会调用回调函数
]]
DEFAULT,TIMERORSUC,TIMER = 0,1,2

--“GPS应用”表
local tlist = {}

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上gpsapp前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("gpsapp",...)
end

--[[
函数名：delitem
功能  ：从“GPS应用”表中删除一项“GPS应用”，并不是真正的删除，只是设置一个无效标志
参数  ：
		mode：GPS工作模式
		para：
			para.cause：“GPS应用”标记
			para.val：GPS开启最大时长
			para.cb：回调函数
返回值：无
]]
local function delitem(mode,para)
	local i
	for i=1,#tlist do
		--标志有效 并且 GPS工作模式相同 并且 “GPS应用”标记相同
		if tlist[i].flag and tlist[i].mode == mode and tlist[i].para.cause == para.cause then
			--设置无效标志
			tlist[i].flag,tlist[i].delay = false
			break
		end
	end
end

--[[
函数名：additem
功能  ：新增一项“GPS应用”到“GPS应用”表
参数  ：
		mode：GPS工作模式
		para：
			para.cause：“GPS应用”标记
			para.val：GPS开启最大时长
			para.cb：回调函数
返回值：无
]]
local function additem(mode,para)
	--删除相同的“GPS应用”
	delitem(mode,para)
	local item,i,fnd = {flag = true, mode = mode, para = para}
	--如果是TIMERORSUC或者TIMER模式，初始化GPS工作剩余时间
	if mode == TIMERORSUC or mode == TIMER then item.para.remain = para.val end
	for i=1,#tlist do
		--如果存在无效的“GPS应用”项，直接使用此位置
		if not tlist[i].flag then
			tlist[i] = item
			fnd = true
			break
		end
	end
	--新增一项
	if not fnd then table.insert(tlist,item) end
end

local function isexisttimeritem()
	local i
	for i=1,#tlist do
		if tlist[i].flag and (tlist[i].mode == TIMERORSUC or tlist[i].mode == TIMER or tlist[i].para.delay) then return true end
	end
end

local function timerfunc()
	local i
	for i=1,#tlist do
		print("timerfunc@"..i,tlist[i].flag,tlist[i].mode,tlist[i].para.cause,tlist[i].para.val,tlist[i].para.remain,tlist[i].para.delay)
		if tlist[i].flag then
			local rmn,dly,md,cb = tlist[i].para.remain,tlist[i].para.delay,tlist[i].mode,tlist[i].para.cb
			if rmn and rmn > 0 then
				tlist[i].para.remain = rmn - 1
			end
			if dly and dly > 0 then
				tlist[i].para.delay = dly - 1
			end
			
			rmn = tlist[i].para.remain
			if isfix() and md == TIMER and rmn == 0 and not tlist[i].para.delay then
				tlist[i].para.delay = 1
			end
			
			dly = tlist[i].para.delay
			if isfix() then
				if dly and dly == 0 then
					if cb then cb(tlist[i].para.cause) end
					if md == DEFAULT then
						tlist[i].para.delay = nil
					else
						close(md,tlist[i].para)
					end
				end
			else
				if rmn and rmn == 0 then
					if cb then cb(tlist[i].para.cause) end
					close(md,tlist[i].para)
				end
			end			
		end
	end
	if isexisttimeritem() then sys.timer_start(timerfunc,1000) end
end

--[[
函数名：gpsstatind
功能  ：处理GPS定位成功的消息
参数  ：
		id：GPS消息id
		evt：GPS消息类型
返回值：无
]]
local function gpsstatind(id,evt)
	--定位成功的消息
	if evt == GPS_LOCATION_SUC_EVT then
		local i
		for i=1,#tlist do
			print("gpsstatind@"..i,tlist[i].flag,tlist[i].mode,tlist[i].para.cause,tlist[i].para.val,tlist[i].para.remain,tlist[i].para.delay,tlist[i].para.cb)
			if tlist[i].flag then
				if tlist[i].mode ~= TIMER then
					tlist[i].para.delay = 1
					if tlist[i].mode == DEFAULT then
						if isexisttimeritem() then sys.timer_start(timerfunc,1000) end
					end
				end				
			end			
		end
	end
	return true
end

--[[
函数名：forceclose
功能  ：强制关闭所有“GPS应用”
参数  ：无
返回值：无
]]
function forceclose()
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].para.cb then tlist[i].para.cb(tlist[i].para.cause) end
		close(tlist[i].mode,tlist[i].para)
	end
end

--[[
函数名：close
功能  ：关闭一个“GPS应用”
参数  ：
		mode：GPS工作模式
		para：
			para.cause：“GPS应用”标记
			para.val：GPS开启最大时长
			para.cb：回调函数
返回值：无
]]
function close(mode,para)
	assert((para and type(para) == "table" and para.cause and type(para.cause) == "string"),"gpsapp.close para invalid")
	print("ctl close",mode,para.cause,para.val,para.cb)
	--删除此“GPS应用”
	delitem(mode,para)
	local valid,i
	for i=1,#tlist do
		if tlist[i].flag then
			valid = true
		end		
	end
	--如果没有一个“GPS应用”有效，则关闭GPS
	if not valid then closegps("gpsapp") end
end

--[[
函数名：open
功能  ：打开一个“GPS应用”
参数  ：
		mode：GPS工作模式
		para：
			para.cause：“GPS应用”标记
			para.val：GPS开启最大时长
			para.cb：回调函数
返回值：无
]]
function open(mode,para)
	assert((para and type(para) == "table" and para.cause and type(para.cause) == "string"),"gpsapp.open para invalid")
	print("ctl open",mode,para.cause,para.val,para.cb)
	--如果GPS定位成功
	if isfix() then
		if mode ~= TIMER then
			--执行回调函数
			if para.cb then para.cb(para.cause) end
			if mode == TIMERORSUC then return end			
		end
	end
	additem(mode,para)
	--真正去打开GPS
	opengps("gpsapp")
	--启动1秒的定时器
	if isexisttimeritem() and not sys.timer_is_active(timerfunc) then
		sys.timer_start(timerfunc,1000)
	end
end

--[[
函数名：isactive
功能  ：判断一个“GPS应用”是否处于激活状态
参数  ：
		mode：GPS工作模式
		para：
			para.cause：“GPS应用”标记
			para.val：GPS开启最大时长
			para.cb：回调函数
返回值：激活返回true，否则返回nil
]]
function isactive(mode,para)
	assert((para and type(para) == "table" and para.cause and type(para.cause) == "string"),"gpsapp.isactive para invalid")
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].mode == mode and tlist[i].para.cause == para.cause then
			return true
		end
	end
end

sys.regapp(gpsstatind,GPS_STATE_IND)
