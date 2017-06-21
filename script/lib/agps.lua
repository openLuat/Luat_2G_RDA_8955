--[[
模块名称：AGPS，全称Assisted Global Positioning System，GPS辅助定位管理(仅适用于u-blox的GPS模块)
模块功能：连接AGPS后台，下载GPS星历数据，写入GPS模块，加速GPS定位
模块最后修改时间：2017.02.20
]]

--[[
连接上后台后，应用层协议：
1、发送AGPS到后台
2、后台回复AGPSUPDATE,total,last,sum1,sum2,sum3,......,sumn
   total：包的总个数
   last：最后一个包的字节数
   sum1：第一个包数据的校验和
   sum2：第二个包数据的校验和
   sum3：第三个包数据的校验和
   ......
   sumn：第n个包数据的校验和
3、发送Getidx
   idx是包的索引，范围是1---total
   例如：假设升级文件为4000字节，
   Get1
   Get2
   Get3
   Get4
4、后台回复每个包的内容
   第一个字节和第二个字节，为包的索引，大端
   其余数据为星历数据
]]

--定义模块,导入依赖库
local base = _G
local table = require"table"
local rtos = require"rtos"
local sys = require"sys"
local string = require"string"
local link = require"link"
local gps = require"gps"
module(...)

--加载常用的全局函数至本地
local print = base.print
local tonumber = base.tonumber
local sfind = string.find
local slen = string.len
local ssub = string.sub
local sbyte = string.byte
local sformat = string.format
local send = link.send
local dispatch = sys.dispatch

--lid：socket id
--isfix：GPS是否定位成功
local lid,isfix
--ispt：是否开启AGPS功能
--itv：连接AGPS后台间隔，单位秒，默认2小时，是指2小时连接一次AGPS后台，更新一次星历数据
--PROT,SVR,PORT：AGPS后台传输层协议、地址、端口
--WRITE_INTERVAL：每个星历数据包写入GPS模块的间隔，单位毫秒
local ispt,itv,PROT,SVR,PORT,WRITE_INTERVAL = true,(2*3600),"UDP","zx1.clouddatasrv.com",8072,50
--mode：AGPS功能工作模式，有以下两种（默认为0）
--0：自动连接后台、下载星历数据、写入GPS模块
--1：需要连接后台时，产生内部消息AGPS_EVT，用户程序处理这个消息决定是否需要连接；下载星历数据，写入GPS模块后，结束后产生内部消息AGPS_EVT，通知用户下载结果和写入结果
local mode = 0
--gpssupport：是否有GPS模块
--eph：从AGPS后台下载的星历数据
local gpssupport,eph = true,""
--GET_TIMEOUT：GET命令等待时间，单位毫秒
--ERROR_PACK_TIMEOUT：错误包(包ID或者长度不匹配) 在一段时间后进行重新获取
--GET_RETRY_TIMES：GET命令超时或者错误包时，当前包允许重试的最大次数
--PACKET_LEN：每包的最大数据长度，单位字节
--RETRY_TIMES：连接后台，下载数据过程结束后，会断开连接；如果此次下载过程失败，则会重新连接后台，重新从头开始下载。这个变量指的是允许重新连接后台下载的最大次数
local GET_TIMEOUT,ERROR_PACK_TIMEOUT,GET_RETRY_TIMES,PACKET_LEN,RETRY_TIMES = 10000,5000,3,1024,3
--state：状态机状态
--IDLE：空闲状态
--CHECK：“查询服务器星历数据”状态
--UPDATE：“下载星历数据中”状态
--total：包的总个数，例如星历数据为10221字节，则total=(int)((10221+1021)/1022)=11;升级文件为10220字节，则total=(int)((10220+1021)/1022)=10
--last：最后一个包的字节数，例如升级文件为10225字节，则last=10225%1022=5;升级文件为10220字节，则last=1022
--checksum：每个包星历数据的校验和存储表
--packid：当前包的索引
--getretries：获取每个包已经重试的次数
--retries：重新连接后台下载，已经重试的次数
--reconnect：是否需要重连后台
local state,total,last,checksum,packid,getretries,retries,reconnect = "IDLE",0,0,{},0,0,1,false

--[[
函数名：startupdatetimer
功能  ：开启“连接后台，更新星历数据”定时器
参数  ：无
返回值：无
]]
local function startupdatetimer()
	--支持GPS并且支持AGPS
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
	--GPS定位成功
	if data == gps.GPS_LOCATION_SUC_EVT or data == gps.GPS_LOCATION_UNFILTER_SUC_EVT then
		sys.dispatch("AGPS_UPDATE_SUC")
		startupdatetimer()
		isfix = true
	--GPS定位失败或者GPS关闭
	elseif data == gps.GPS_LOCATION_FAIL_EVT or data == gps.GPS_CLOSE_EVT then
		isfix = false
	--没有GPS芯片
	elseif data == gps.GPS_NO_CHIP_EVT then
		gpssupport = false
	end
	return true
end

--[[
函数名：writecmd
功能  ：写每条星历数据到GPS模块
参数  ：
		id：gps.GPS_STATE_IND，不用处理
		data：消息参数类型
返回值：true
]]
local function writecmd()
	if eph and slen(eph) > 0 and not isfix then
		local h1,h2 = sfind(eph,"\181\98")
		if h1 and h2 then
			local id = ssub(eph,h2+1,h2+2)
			if id and slen(id) == 2 then
				local llow,lhigh = sbyte(eph,h2+3),sbyte(eph,h2+4)
				if lhigh and llow then
					local length = lhigh*256 + llow
					print("length",h2+6+length,slen(eph))
					if h2+6+length <= slen(eph) then
						gps.writegpscmd(false,ssub(eph,h1,h2+6+length),false)
						eph = ssub(eph,h2+7+length,-1)
						sys.timer_start(writecmd,WRITE_INTERVAL)
						return
					end
				end
			end
		end
	end
	gps.closegps("AGPS")
	eph = ""
	sys.dispatch("AGPS_UPDATE_SUC")
end

--[[
函数名：startwrite
功能  ：开始写星历数据到GPS模块
参数  ：无
返回值：无
]]
local function startwrite()
	if isfix or not gpssupport then
		eph = ""
		return
	end
	if eph and slen(eph) > 0 then
		gps.opengps("AGPS")
		sys.timer_start(writecmd,WRITE_INTERVAL)
	end
end

--[[
函数名：calsum
功能  ：计算校验和
参数  ：
		str：要计算校验和的数据
返回值：校验和
]]
local function calsum(str)
	local sum,i = 0
	for i=1,slen(str) do
		sum = sum + sbyte(str,i)
	end
	return sum
end

--[[
函数名：errpack
功能  ：错误包处理
参数  ：
		str：要计算校验和的数据
返回值：校验和
]]
local function errpack()
	print("errpack")
	upend(false)
end

--[[
函数名：retry
功能  ：重试动作
参数  ：
		para：如果为STOP，则停止重试；否则，执行重试
返回值：无
]]
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

--[[
函数名：reqget
功能  ：发送“获取第index包的请求数据”到服务器
参数  ：
		index：包的索引，从1开始
返回值：无
]]
function reqget(idx)
	send(lid,sformat("Get%d",idx))
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
函数名：getpack
功能  ：解析从服务器收到的一包数据
参数  ：
		data：包内容
返回值：无
]]
local function getpack(data)
	-- 判断包长度是否正确
	local len = slen(data)
	if (packid < total and len ~= PACKET_LEN) or (packid >= total and len ~= (last+2)) then
		print("getpack:len not match",packid,len,last)
		retry("ERROR_PACK")
		return
	end

	-- 判断包序号是否正确
	local id = sbyte(data,1)*256 + sbyte(data,2)%256
	if id ~= packid then
		print("getpack:packid not match",id,packid)
		retry("ERROR_PACK")
		return
	end

	--判断校验和是否正确
	local sum = calsum(ssub(data,3,-1))
	if checksum[id] ~= sum then
		print("getpack:checksum not match",checksum[id],sum)
		retry("ERROR_PACK")
		return
	end

	-- 停止重试
	retry("STOP")

	-- 保存星历包
	eph = eph .. ssub(data,3,-1)

	-- 获取下一包数据
	if packid == total then
		sum = calsum(eph)
		if checksum[total+1] ~= sum then
			print("getpack:total checksum not match",checksum[total+1],sum)
			upend(false)
		else
			upend(true)
		end
	else
		packid = packid + 1
		reqget(packid)
	end
end

--[[
函数名：upbegin
功能  ：解析服务器下发的星历包信息
参数  ：
		data：星历包信息
返回值：无
]]
local function upbegin(data)
	--包的个数，最后一包的字节数
	local d1,d2,p1,p2 = sfind(data,"AGPSUPDATE,(%d+),(%d+)")
	local i
	if d1 and d2 and p1 and p2 then
		p1,p2 = tonumber(p1),tonumber(p2)
		total,last = p1,p2
		local tmpdata = data
		--每包星历数据的校验和
		for i=1,total+1 do
			if d2+2 > slen(tmpdata) then
				upend(false)
				return false
			end
			tmpdata = ssub(tmpdata,d2+2,-1)
			d1,d2,p1 = sfind(tmpdata,"(%d+)")
			if d1 == nil or d2 == nil or p1 == nil then
				upend(false)
				return false
			end
			checksum[i] = tonumber(p1)
		end

		getretries,state,packid,eph = 0,"UPDATE",1,""
		--请求第1包
		reqget(packid)
		return true
	end

	upend(false)
	return false
end

--[[
函数名：reqcheck
功能  ：发送“请求星历信息”数据到服务器
参数  ：无
返回值：无
]]
function reqcheck()
	state = "CHECK"
	send(lid,"AGPS")
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
函数名：upend
功能  ：下载结束
参数  ：
		succ：结果，true为成功，其余为失败
返回值：无
]]
function upend(succ)
	state = "IDLE"
	-- 停止充实定时器
	sys.timer_stop(retry)
	sys.timer_stop(errpack)
	-- 断开链接
	link.close(lid)
	getretries = 0
	if succ then
		reconnect = false
		retries = 0
		--写星历信息到GPS芯片
		print("eph rcv",slen(eph))
		startwrite()
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

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        id ：socket id，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
local function rcv(id,data)
	base.collectgarbage()
	--停止重试定时器
	sys.timer_stop(retry)
	--如果定位成功或者不支持GPS模块
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if state == "CHECK" then
		--返回了星历包总信息
		if sfind(data,"AGPSUPDATE") == 1 then
			upbegin(data)
			return
		end
	elseif state == "UPDATE" then
		if data ~= "ERR" then
			getpack(data)
			return
		end
	end

	upend(false)
	return
end

--[[
函数名：nofity
功能  ：socket状态的处理函数
参数  ：
        id：socket id，程序可以忽略不处理
        evt：消息事件类型
		val： 消息事件参数
返回值：无
]]
local function nofity(id,evt,val)
	print("agps notify",lid,id,evt,val,reconnect)
	if id ~= lid then return end
	--如果定位成功或者不支持GPS模块
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if evt == "CONNECT" then
		--连接成功
		if val == "CONNECT OK" then
			reqcheck()
		--连接失败
		else
			upend(false)
		end
	elseif evt == "CLOSE" and reconnect then
		--重连
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
	lid = link.open(nofity,rcv,"agps")
	link.connect(lid,PROT,SVR,PORT)
end

--[[
函数名：connect
功能  ：连接服务器请求
参数  ：无
返回值：无
]]
function connect()
	if ispt then
		--自动模式
		if mode==0 then
			connectcb()
		--用户控制模式
		else
			dispatch("AGPS_EVT","BEGIN_IND",connectcb)
		end		
	end
end

--[[
函数名：init
功能  ：设置连接服务器更新星历数据间隔和此模块工作模式
参数  ：
		inv：更新间隔，单位秒
		md：工作模式
返回值：无
]]
function init(inv,md)
	itv = inv or itv
	mode = md or 0
	startupdatetimer()
end

--[[
函数名：setspt
功能  ：设置是否开启AGPS功能
参数  ：
		spt：true为开启，false或者nil为关闭
返回值：无
]]
function setspt(spt)
	if spt ~= nil and ispt ~= spt then
		ispt = spt
		if spt then
			startupdatetimer()
		end
	end
end

--[[
函数名：load
功能  ：运行此功能模块
参数  ：无
返回值：无
]]
local function load()
	--(按键开机 或者 充电开机) 并且 允许开机更新星历数据
	if (rtos.poweron_reason() == rtos.POWERON_KEY or rtos.poweron_reason() == rtos.POWERON_CHARGER) and gps.isagpspwronupd() then
		connect()
	else
		startupdatetimer()
	end
end

--注册GPS消息处理函数
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
load()
