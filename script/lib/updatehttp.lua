--[[
模块名称：远程升级(通过http的get命令)
模块功能：只在每次开机或者重启时，或者根据用户的配置时间点，连接升级服务器，如果服务器存在新版本，lib和应用脚本远程升级
模块最后修改时间：2018.02.08
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
--0：自动升级模式，下载升级包后，自动重启完成升级
--1：用户自定义模式，下载升级包后，会产生一个消息UP_END_IND，由用户脚本决定是否需要重启
local updmode = base.UPDMODE or 0

--PROTOCOL：传输层协议，只支持TCP
--SERVER,PORT为服务器地址和端口
local PROTOCOL,SERVER,PORT,getURL = "TCP","iot.openluat.com",80,"/api/site/firmware_upgrade"
--是否使用用户自定义的升级服务器
local usersvr
--升级包保存路径
local UPDATEPACK = "/luazip/update.bin"
local rcvBuf = ""

-- GET命令等待时间
local CMD_GET_TIMEOUT = 10000
-- GET命令重试次数
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
--getretries：已经重试的次数
local getretries = 0
local contentLen,saveLen = 0,0


--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上updatehttp前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("updatehttp",...)
end

--[[
函数名：save
功能  ：保存数据包到升级文件中
参数  ：
		data：数据包
返回值：保存成功返回true，否则nil
]]
local function save(data)
	--打开文件
	local f = io.open(UPDATEPACK,"a+")

	if f==nil then
		print("save:file nil")
		return
	end
	--写文件
	if f:write(data)==nil then
		print("write:file nil")
		f:close()
		return
	end
	f:close()
	return true
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
	--重试次数加1
	getretries = getretries + 1
	if getretries < CMD_GET_RETRY_TIMES then
		link.close(lid)
		lid = nil
		connect()		
	else
		-- 超过重试次数,升级失败
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
	print("upend",succ,state,updmode)
	if not succ then os.remove(UPDATEPACK) end
	updsuc = succ
	local tmpsta = state
	state = "IDLE"
	rcvBuf = ""
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
	local url = getURL.."?project_key="..base.PRODUCT_KEY
		.."&imei="..misc.getimei().."&device_key="..misc.getsn()
		.."&firmware_name="..base.PROJECT.."_"..rtos.get_version().."&version="..base.VERSION
	if not send(lid,"GET "..url.." HTTP/1.1\r\nConnection: keep-alive\r\nHost: "..SERVER.."\r\n\r\n") then
		sys.timer_start(retry,CMD_GET_TIMEOUT)
	end
	os.remove(UPDATEPACK)
	rcvBuf = ""	
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
	elseif evt == "SEND" then
		sys.timer_start(retry,CMD_GET_TIMEOUT)
	--连接被动断开
	elseif evt == "STATE" and val == "CLOSED" then		 
		upend(false)
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
		rcvBuf = rcvBuf..data
		local _,d = string.find(rcvBuf,"\r\n\r\n")
		if d then
			local statusCode = string.match(rcvBuf,"HTTP/1.1 (%d+)")
			if statusCode~="200" then
				print("statusCode error",statusCode)
				local msg = string.match(rcvBuf,"\"msg\":%s*\"(.-)\"")
				if msg and msg:len()<=200 then
					print("error msg",common.ucs2betoutf8(common.hexstobins(msg:gsub("\\u",""))))
				end
				upend(false)
				return
			end
			
			contentLen = string.match(rcvBuf,"Content%-Length: (%d+)")
			if not contentLen or contentLen=="0" then print("contentLen error",contentLen) sys.timer_start(retry,CMD_GET_TIMEOUT) return end
			contentLen = base.tonumber(contentLen)
			
			state = "UPDATE"
			local buf = string.sub(rcvBuf,d+1,-1)
			if string.len(buf)>0 and not save(buf) then print("save error") sys.timer_start(retry,CMD_GET_TIMEOUT) return end			
			saveLen = string.len(buf)
			rcvBuf = ""
		end		
	--“升级中”状态
	elseif state == "UPDATE" then
		if string.len(data)>0 and not save(data) then print("save error") sys.timer_start(retry,CMD_GET_TIMEOUT) return end			
		saveLen = saveLen+string.len(data)
		if saveLen == contentLen then
			upend(true)
		end
	else
		upend(false)
	end	
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
        prot ：传输层协议，仅支持TCP
		server：服务器地址
		port：服务器端口
		getURL：GET命令的URL，例如"/api/site/firmware_upgrade",注意，发送GET命令报文时，会在此URL之后自动添加下面的参数
				"?project_key="..base.PRODUCT_KEY
				"&imei="..misc.getimei()
				"&device_key="..misc.getsn()
				"&firmware_name="..base.PROJECT.."_"..rtos.get_version()
				"&version="..base.VERSION
返回值：无
]]
function setup(prot,server,port,url)
	if prot and server and port and url then
		PROTOCOL,SERVER,PORT,getURL = prot,server,port,url
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
