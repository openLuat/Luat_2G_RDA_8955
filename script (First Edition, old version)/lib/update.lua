--[[
模块名称：远程升级
模块功能：只在每次开机或者重启时，连接升级服务器，如果服务器存在新版本，lib和应用脚本远程升级
模块最后修改时间：2017.02.09
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local rtos = require"rtos"
local sys  = require"sys"
local link = require"link"
local misc = require"misc"
local common = require"common"
module(...)

--加载常用的全局函数至本地
local print = base.print
local send = link.send
local dispatch = sys.dispatch

--远程升级模式，可在main.lua中，配置UPDMODE变量，未配置的话默认为0
--0：自动升级模式，脚本更新后，自动重启完成升级
--1：用户自定义模式，如果后台有新版本，会产生一个消息，由用户应用脚本决定是否升级
local updmode = base.UPDMODE or 0

--PROTOCOL：传输层协议，只支持TCP和UDP
--SERVER,PORT为服务器地址和端口
local PROTOCOL,SERVER,PORT = "UDP","firmware.openluat.com",12410
--是否使用用户自定义的升级服务器
local usersvr
--升级包保存路径
local UPDATEPACK = "/luazip/update.bin"

-- GET命令等待时间
local CMD_GET_TIMEOUT = 10000
-- 错误包(包ID或者长度不匹配) 在一段时间后进行重新获取
local ERROR_PACK_TIMEOUT = 10000
-- 每次GET命令重试次数
local CMD_GET_RETRY_TIMES = 5
--socket id
local lid,updsuc
--设置定时升级的时间周期，单位秒，0表示关闭定时升级
local period = 0
--状态机状态
--IDLE：空闲状态
--CHECK：“查询服务器是否有新版本”状态
--UPDATE：升级中状态
local state = "IDLE"
--projectid是项目标识的id,服务器自己维护
--total是包的个数，例如升级文件为10235字节，则total=(int)((10235+1022)/1023)=11;升级文件为10230字节，则total=(int)((10230+1022)/1023)=10
--last是最后一个包的字节数，例如升级文件为10235字节，则last=10235%1023=5;升级文件为10230字节，则last=1023
local projectid,total,last
--packid：当前包的索引
--getretries：获取每个包已经重试的次数
local packid,getretries = 1,0

--时区，本模块支持设置系统时间功能，但是需要服务器返回当前时间
timezone = nil
BEIJING_TIME = 8
GREENWICH_TIME = 0

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上update前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("update",...)
end

--[[
函数名：save
功能  ：保存数据包到升级文件中
参数  ：
		data：数据包
返回值：无
]]
local function save(data)
	--如果是第一个包，则覆盖保存；否则，追加保存
	local mode = packid == 1 and "wb" or "a+"
	--打开文件
	local f = io.open(UPDATEPACK,mode)

	if f == nil then
		print("save:file nil")
		return
	end
	--写文件
	f:write(data)
	f:close()
end

--[[
函数名：retry
功能  ：升级过程中的重试动作
参数  ：
		param：如果为STOP，则停止重试；否则，执行重试
返回值：无
]]
local function retry(param)
	--升级状态已结束直接退出
	if state~="CONNECT" and state~="UPDATE" and state~="CHECK" then
		return
	end
	--停止重试
	if param == "STOP" then
		getretries = 0
		sys.timer_stop(retry)
		return
	end
	--包内容错误，ERROR_PACK_TIMEOUT毫秒后重试当前包
	if param == "ERROR_PACK" then
		sys.timer_start(retry,ERROR_PACK_TIMEOUT)
		return
	end
	--重试次数加1
	getretries = getretries + 1
	if getretries < CMD_GET_RETRY_TIMES then
		-- 未达重试次数,继续尝试获取升级包
		if state == "CONNECT" then
			link.close(lid)
			lid = nil
			connect()
		elseif state == "UPDATE" then
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
function reqget(index)
	send(lid,string.format("%sGet%d,%d",
							usersvr and "" or string.format("0,%s,%s,%s,%s,%s,",base.PRODUCT_KEY,misc.getimei(),misc.isnvalid() and misc.getsn() or "",base.PROJECT.."_"..sys.getcorever(),base.VERSION),
							index,
							projectid))
	--启动“CMD_GET_TIMEOUT毫秒后重试”定时器
	sys.timer_start(retry,CMD_GET_TIMEOUT)
end

--[[
函数名：getpack
功能  ：解析从服务器收到的一包数据
参数  ：
		data：包内容
返回值：无
]]
local function getpack(data)
	--判断包长度是否正确
	local len = string.len(data)
	if (packid < total and len ~= 1024) or (packid >= total and (len - 2) ~= last) then
		print("getpack:len not match",packid,len,last)
		retry("ERROR_PACK")
		return
	end

	--判断包序号是否正确
	local id = string.byte(data,1)*256+string.byte(data,2)
	if id ~= packid then
		print("getpack:packid not match",id,packid)
		retry("ERROR_PACK")
		return
	end

	--停止重试
	retry("STOP")

	--保存升级包
	save(string.sub(data,3,-1))
	--如果是用户自定义模式，产生一个内部消息UP_PROGRESS_IND，表示升级进度
	if updmode == 1 then
		dispatch("UP_EVT","UP_PROGRESS_IND",packid*100/total)
	end

	--获取下一包数据
	if packid == total then
		upend(true)
	else
		packid = packid + 1
		reqget(packid)
	end
end

--[[
函数名：upbegin
功能  ：解析服务器下发的新版本信息
参数  ：
		data：新版本信息
返回值：无
]]
function upbegin(data)
	local p1,p2,p3 = string.match(data,"LUAUPDATE,(%d+),(%d+),(%d+)")
	--后台维护的项目id，包的个数，最后一包的字节数
	p1,p2,p3 = base.tonumber(p1),base.tonumber(p2),base.tonumber(p3)
	--格式正确
	if p1 and p2 and p3 then
		projectid,total,last = p1,p2,p3
		--重试次数清0
		getretries = 0
		--设置为升级中状态
		state = "UPDATE"
		--从第1个升级包开始
		packid = 1
		--发送请求，获取第1个升级包
		reqget(packid)
	--格式错误，升级结束
	else
		upend(false)
	end
end

--[[
函数名：upend
功能  ：升级结束
参数  ：
		succ：结果，true为成功，其余为失败
返回值：无
]]
function upend(succ)
	print("upend",succ)
	updsuc = succ
	local tmpsta = state
	state = "IDLE"
	--停止重试定时器
	sys.timer_stop(retry)
	--断开链接
	link.close(lid)
	lid = nil
	getretries = 0
	sys.setrestart(true,1)
	sys.timer_stop(sys.setrestart,true,1)
	--升级成功并且是自动升级模式则重启
	if succ == true and updmode == 0 then
		sys.restart("update.upend")
	end
	--如果是自定义升级模式，产生一个内部消息UP_END_IND，表示升级结束以及升级结果
	if updmode == 1 and tmpsta ~= "IDLE" then
		dispatch("UP_EVT","UP_END_IND",succ)
	end
	--产生一个内部消息UPDATE_END_IND，目前与飞行模式配合使用
	dispatch("UPDATE_END_IND")
	if period~=0 then sys.timer_start(connect,period*1000,"period") end
end

--[[
函数名：reqcheck
功能  ：发送“检查服务器是否有新版本”请求数据到服务器
参数  ：无
返回值：无
]]
function reqcheck()
	print("reqcheck",usersvr)
	state = "CHECK"
	if usersvr then
		send(lid,string.format("%s,%s,%s",misc.getimei(),base.PROJECT.."_"..sys.getcorever(),base.VERSION))
	else
		send(lid,string.format("0,%s,%s,%s,%s,%s",base.PRODUCT_KEY,misc.getimei(),misc.isnvalid() and misc.getsn() or "",base.PROJECT.."_"..sys.getcorever(),base.VERSION))
	end
	sys.timer_start(retry,CMD_GET_TIMEOUT)
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
	--连接结果
	if evt == "CONNECT" then
		state = "CONNECT"
		--产生一个内部消息UPDATE_BEGIN_IND，目前与飞行模式配合使用
		dispatch("UPDATE_BEGIN_IND")
		--连接成功
		if val == "CONNECT OK" then
			reqcheck()
		--连接失败
		else
			sys.timer_start(retry,CMD_GET_TIMEOUT)
		end
	--连接被动断开
	elseif evt == "STATE" and val == "CLOSED" then		 
		upend(false)
	end
end

--服务器下发的新版本信息，自定义模式中使用
local chkrspdat
--[[
函数名：upselcb
功能  ：自定义模式下，用户选择是否升级的回调处理
参数  ：
        sel：是否允许升级，true为允许，其余为不允许
返回值：无
]]
local upselcb = function(sel)
	--允许升级
	if sel then
		upbegin(chkrspdat)
	--不允许升级
	else
		link.close(lid)
		lid = nil
		dispatch("UPDATE_END_IND")
	end
end

--[[
函数名：recv
功能  ：socket接收数据的处理函数
参数  ：
        id ：socket id，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
local function recv(id,data)
	--停止重试定时器
	sys.timer_stop(retry)
	--“查询服务器是否有新版本”状态
	if state == "CHECK" then
		--服务器上有新版本
		if string.find(data,"LUAUPDATE") == 1 then
			--自动升级模式
			if updmode == 0 then
				upbegin(data)
			--自定义升级模式
			elseif updmode == 1 then
				chkrspdat = data
				dispatch("UP_EVT","NEW_VER_IND",upselcb)
			else
				upend(false)
			end
		--没有新版本
		else
			upend(false)
		end
		--如果用户应用脚本中调用了settimezone接口
		if timezone then
			local clk,a,b = {}
			a,b,clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec = string.find(data,"(%d+)%-(%d+)%-(%d+) *(%d%d):(%d%d):(%d%d)")
			--如果服务器返回了正确的时间格式
			if a and b then
				--设置系统时间
				clk = common.transftimezone(clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec,BEIJING_TIME,timezone)
				misc.setclock(clk)
			end
		end
	--“升级中”状态
	elseif state == "UPDATE" then
		if data == "ERR" then
			upend(false)
		else
			getpack(data)
		end
	else
		upend(false)
	end	
end

--[[
函数名：settimezone
功能  ：设置系统时间的时区
参数  ：
        zone ：时区，目前仅支持格林威治时间和北京时间，BEIJING_TIME和GREENWICH_TIME
返回值：无
]]
function settimezone(zone)
	timezone = zone
end

function connect()
	print("connect",lid,updsuc)
	if not lid and not updsuc then
		lid = link.open(nofity,recv,"update")
		link.connect(lid,PROTOCOL,SERVER,PORT)
	end
end

local function defaultbgn()
	print("defaultbgn",usersvr)
	if not usersvr then
		base.assert(base.PRODUCT_KEY and base.PROJECT and base.VERSION,"undefine PRODUCT_KEY or PROJECT or VERSION in main.lua")
		base.assert(not string.match(base.PROJECT,","),"PROJECT in main.lua format error")
		base.assert(string.match(base.VERSION,"%d%.%d%.%d") and string.len(base.VERSION)==5,"VERSION in main.lua format error")
		connect()
	end
end

--[[
函数名：setup
功能  ：配置服务器的传输协议、地址和端口
参数  ：
        prot ：传输层协议，仅支持TCP和UDP
		server：服务器地址
		port：服务器端口
返回值：无
]]
function setup(prot,server,port)
	if prot and server and port then
		PROTOCOL,SERVER,PORT = prot,server,port
		usersvr = true
		base.assert(base.PROJECT and base.VERSION,"undefine PROJECT or VERSION in main.lua")		
		connect()
	end
end

--[[
函数名：setperiod
功能  ：配置定时升级的周期
参数  ：
        prd：number类型，定时升级的周期，单位秒；0表示关闭定时升级功能，其余值要大于等于60秒
返回值：无
]]
function setperiod(prd)
	base.assert(prd==0 or prd>=60,"setperiod prd error")
	print("setperiod",prd)
	period = prd
	if prd==0 then
		sys.timer_stop(connect,"period")
	else
		sys.timer_start(connect,prd*1000,"period")
	end
end

--[[
函数名：request
功能  ：实时启动一次升级
参数  ：无
返回值：无
]]
function request()
	print("request")
	connect()
end

sys.timer_start(defaultbgn,10000)
sys.setrestart(false,1)
sys.timer_start(sys.setrestart,300000,true,1)
