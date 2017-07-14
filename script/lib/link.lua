--[[
模块名称：数据链路、SOCKET管理
模块功能：数据网络激活，SOCKET的创建、连接、数据收发、状态维护
模块最后修改时间：2017.02.14
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local rtos = require"rtos"
local sim = require"sim"
module(...,package.seeall)

--加载常用的全局函数至本地
local print = base.print
local pairs = base.pairs
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

--最大socket id，从0开始，所以同时支持的socket连接数是8个
local MAXLINKS = 7
--IP环境建立失败时间隔5秒重连
local IPSTART_INTVL = 5000

--socket连接表
local linklist = {}
--ipstatus：IP环境状态
--shuting：是否正在关闭数据网络
local ipstatus,shuting = "IP INITIAL"
--GPRS数据网络附着状态，"1"附着，其余未附着
local cgatt
--apn，用户名，密码
local apnname = "CMNET"
local username=''
local password=''
--socket发起连接请求后，如果在connectnoretinterval毫秒后没有任何应答，如果connectnoretrestart为true，则会重启软件
local connectnoretrestart = false
local connectnoretinterval
--apnflg：本功能模块是否自动获取apn信息，true是，false则由用户应用脚本自己调用setapn接口设置apn、用户名和密码
--checkciicrtm：执行AT+CIICR后，如果设置了checkciicrtm，checkciicrtm毫秒后，没有激活成功，则重启软件（中途执行AT+CIPSHUT则不再重启）
--flymode：是否处于飞行模式
--updating：是否正在执行远程升级功能(update.lua)
--dbging：是否正在执行dbg功能(dbg.lua)
--ntping：是否正在执行NTP时间同步功能(ntp.lua)
--shutpending：是否有等待处理的进入AT+CIPSHUT请求
local apnflag,checkciicrtm,ciicrerrcb,flymode,updating,dbging,ntping,shutpending=true

--[[
函数名：setapn
功能  ：设置apn、用户名和密码
参数  ：
		a：apn
		b：用户名
		c：密码
返回值：无
]]
function setapn(a,b,c)
	apnname,username,password = a,b or '',c or ''
	apnflag=false
end

--[[
函数名：getapn
功能  ：获取apn
参数  ：无
返回值：apn
]]
function getapn()
	return apnname
end

--[[
函数名：connectingtimerfunc
功能  ：socket连接超时没有应答处理函数
参数  ：
		id：socket id
返回值：无
]]
local function connectingtimerfunc(id)
	print("connectingtimerfunc",id,connectnoretrestart)
	if connectnoretrestart then
		sys.restart("link.connectingtimerfunc")
	end
end

--[[
函数名：stopconnectingtimer
功能  ：关闭“socket连接超时没有应答”定时器
参数  ：
		id：socket id
返回值：无
]]
local function stopconnectingtimer(id)
	print("stopconnectingtimer",id)
	sys.timer_stop(connectingtimerfunc,id)
end

--[[
函数名：startconnectingtimer
功能  ：开启“socket连接超时没有应答”定时器
参数  ：
		id：socket id
返回值：无
]]
local function startconnectingtimer(id)
	print("startconnectingtimer",id,connectnoretrestart,connectnoretinterval)
	if id and connectnoretrestart and connectnoretinterval and connectnoretinterval > 0 then
		sys.timer_start(connectingtimerfunc,connectnoretinterval,id)
	end
end

--[[
函数名：setconnectnoretrestart
功能  ：设置“socket连接超时没有应答”的控制参数
参数  ：
		flag：功能开关，true或者false
		interval：超时时间，单位毫秒
返回值：无
]]
function setconnectnoretrestart(flag,interval)
	connectnoretrestart = flag
	connectnoretinterval = interval
end

--[[
函数名：setupIP
功能  ：发送激活IP网络请求
参数  ：无
返回值：无
]]
function setupIP()
	print("link.setupIP:",ipstatus,cgatt,flymode)
	--数据网络已激活或者处于飞行模式，直接返回
	if ipstatus ~= "IP INITIAL" or flymode then
		return
	end
	--gprs数据网络没有附着上
	if cgatt ~= "1" then
		print("setupip: wait cgatt")
		return
	end

	--激活IP网络请求
	req("AT+CSTT=\""..apnname..'\",\"'..username..'\",\"'..password.. "\"")
	req("AT+CIICR")
	--查询激活状态
	req("AT+CIPSTATUS")
	ipstatus = "IP START"
end

--[[
函数名：emptylink
功能  ：获取可用的socket id
参数  ：无
返回值：可用的socket id，如果没有可用的返回nil
]]
local function emptylink()
	for i = 0,MAXLINKS do
		if linklist[i] == nil then
			return i
		end
	end

	return nil
end

--[[
函数名：validaction
功能  ：检查某个socket id的动作是否有效
参数  ：
		id：socket id
		action：动作
返回值：true有效，false无效
]]
local function validaction(id,action)
	--socket无效
	if linklist[id] == nil then
		print("link.validaction:id nil",id)
		return false
	end

	--同一个状态不重复执行
	if action.."ING" == linklist[id].state then
		print("link.validaction:",action,linklist[id].state)
		return false
	end

	local ing = string.match(linklist[id].state,"(ING)",-3)

	if ing then
		--有其他任务在处理时,不允许处理连接,断链或者关闭是可以的
		if action == "CONNECT" then
			print("link.validaction: action running",linklist[id].state,action)
			return false
		end
	end

	-- 无其他任务在执行,允许执行
	return true
end

--[[
函数名：openid
功能  ：保存socket的参数信息
参数  ：
		id：socket id
		notify：socket状态处理函数
		recv：socket数据接收处理函数
		tag：socket创建标记
返回值：true成功，false失败
]]
function openid(id,notify,recv,tag)
	--id越界或者id的socket已经存在
	if id > MAXLINKS or linklist[id] ~= nil then
		print("openid:error",id)
		return false
	end

	local link = {
		notify = notify,
		recv = recv,
		state = "INITIAL",
		tag = tag,
	}

	linklist[id] = link

	--注册连接urc
	ril.regurc(tostring(id),urc)

	--激活IP网络
	if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" then
		setupIP()
	end

	return true
end

--[[
函数名：open
功能  ：创建一个socket
参数  ：
		notify：socket状态处理函数
		recv：socket数据接收处理函数
		tag：socket创建标记
返回值：number类型的id表示成功，nil表示失败
]]
function open(notify,recv,tag)
	local id = emptylink()

	if id == nil then
		return nil,"no empty link"
	end

	openid(id,notify,recv,tag)

	return id
end

--[[
函数名：close
功能  ：关闭一个socket（会清除socket的所有参数信息）
参数  ：
		id：socket id
返回值：true成功，false失败
]]
function close(id)
	--检查是否允许关闭
	if validaction(id,"CLOSE") == false then
		return false
	end
	--正在关闭
	linklist[id].state = "CLOSING"
	--发送AT命令关闭请求
	req("AT+CIPCLOSE="..id)

	return true
end

--[[
函数名：asyncLocalEvent
功能  ：socket异步通知消息的处理函数
参数  ：
		msg：异步通知消息"LINK_ASYNC_LOCAL_EVENT"
		cbfunc：消息回调
		id：socket id
		val：通知消息的参数
返回值：true成功，false失败
]]
function asyncLocalEvent(msg,cbfunc,id,val)
	cbfunc(id,val)
end

--注册消息LINK_ASYNC_LOCAL_EVENT的处理函数
sys.regapp(asyncLocalEvent,"LINK_ASYNC_LOCAL_EVENT")

--[[
函数名：connect
功能  ：socket连接服务器请求
参数  ：
		id：socket id
		protocol：传输层协议，TCP或者UDP
		address：服务器地址
		port：服务器端口
返回值：请求成功同步返回true，否则false；
]]
function connect(id,protocol,address,port)
	--不允许发起连接动作
	if validaction(id,"CONNECT") == false or linklist[id].state == "CONNECTED" then
		return false
	end
	print("link.connect",id,protocol,address,port,ipstatus,shuting,shutpending)

	linklist[id].state = "CONNECTING"

	if cc and cc.anycallexist() then
		--如果打开了通话功能 并且当前正在通话中使用异步通知连接失败
		print("link.connect:failed cause call exist")
		sys.dispatch("LINK_ASYNC_LOCAL_EVENT",statusind,id,"CONNECT FAIL")
		return true
	end

	local connstr = string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s",id,protocol,address,port)

	if (ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING") or shuting or shutpending then
		--ip环境未准备好先加入等待
		linklist[id].pending = connstr
	else
		--发送AT命令连接服务器
		req(connstr)
		startconnectingtimer(id)
	end

	return true
end

--[[
函数名：disconnect
功能  ：断开一个socket（不会清除socket的所有参数信息）
参数  ：
		id：socket id
返回值：true成功，false失败
]]
function disconnect(id)
	--不允许断开动作
	if validaction(id,"DISCONNECT") == false then
		return false
	end
	--如果此socket id对应的连接还在等待中，并没有真正发起
	if linklist[id].pending then
		linklist[id].pending = nil
		if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" and linklist[id].state == "CONNECTING" then
			print("link.disconnect: ip not ready",ipstatus)
			linklist[id].state = "DISCONNECTING"
			sys.dispatch("LINK_ASYNC_LOCAL_EVENT",closecnf,id,"DISCONNECT","OK")
			return
		end
	end

	linklist[id].state = "DISCONNECTING"
	--发送AT命令断开
	req("AT+CIPCLOSE="..id)

	return true
end

--[[
函数名：send
功能  ：发送数据到服务器
参数  ：
		id：socket id
		data：要发送的数据
返回值：true成功，false失败
]]
function send(id,data)
	--socket无效，或者socket未连接
	if linklist[id] == nil or linklist[id].state ~= "CONNECTED" then
		print("link.send:error",id)
		return false
	end

	if cc and cc.anycallexist() then
		-- 如果打开了通话功能 并且当前正在通话中使用异步通知连接失败
		print("link.send:failed cause call exist")
		return false
	end
	--发送AT命令执行数据发送
	req(string.format("AT+CIPSEND=%d,%d",id,string.len(data)),data)

	return true
end

--[[
函数名：getstate
功能  ：获取一个socket的连接状态
参数  ：
		id：socket id
返回值：socket有效则返回连接状态，否则返回"NIL LINK"
]]
function getstate(id)
	return linklist[id] and linklist[id].state or "NIL LINK"
end

--[[
函数名：recv
功能  ：某个socket的数据接收处理函数
参数  ：
		id：socket id
		len：接收到的数据长度，以字节为单位
		data：接收到的数据内容
返回值：无
]]
local function recv(id,len,data)
	--socket id无效
	if linklist[id] == nil then
		print("link.recv:error",id)
		return
	end
	--调用socket id对应的用户注册的数据接收处理函数
	if linklist[id].recv then
		linklist[id].recv(id,data)
	else
		print("link.recv:nil recv",id)
	end
end

--[[ ipstatus查询返回的状态不提示
function linkstatus(data)
end
]]

--[[
函数名：usersckisactive
功能  ：判断用户创建的socket连接是否处于激活状态
参数  ：无
返回值：只要任何一个用户socket处于连接状态就返回true，否则返回nil
]]
local function usersckisactive()
	for i = 0,MAXLINKS do
		--用户自定义的socket，没有tag值
		if linklist[i] and not linklist[i].tag and linklist[i].state=="CONNECTED" then
			return true
		end
	end
end

--[[
函数名：usersckntfy
功能  ：用户创建的socket连接状态变化通知
参数  ：
		id：socket id
返回值：无
]]
local function usersckntfy(id)
	--产生一个内部消息"USER_SOCKET_CONNECT"，通知“用户创建的socket连接状态发生变化”
	if not linklist[id].tag then sys.dispatch("USER_SOCKET_CONNECT",usersckisactive()) end
end

--[[
函数名：sendcnf
功能  ：socket数据发送结果确认
参数  ：
		id：socket id
		result：发送结果字符串
返回值：无
]]
local function sendcnf(id,result)
	local str = string.match(result,"([%u ])")
	--发送失败
	if str == "TCP ERROR" or str == "UDP ERROR" or str == "ERROR" then
		linklist[id].state = result
	end
	--调用用户注册的状态处理函数
	linklist[id].notify(id,"SEND",result)
end

--[[
函数名：closecnf
功能  ：socket关闭结果确认
参数  ：
		id：socket id
		result：关闭结果字符串
返回值：无
]]
function closecnf(id,result)
	--socket id无效
	if not id or not linklist[id] then
		print("link.closecnf:error",id)
		return
	end
	--不管任何的close结果,链接总是成功断开了,所以直接按照链接断开处理
	if linklist[id].state == "DISCONNECTING" then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"DISCONNECT","OK")
		usersckntfy(id,false)
		stopconnectingtimer(id)
	--连接注销,清除维护的连接信息,清除urc关注
	elseif linklist[id].state == "CLOSING" then		
		local tlink = linklist[id]
		usersckntfy(id,false)
		linklist[id] = nil
		ril.deregurc(tostring(id),urc)
		tlink.notify(id,"CLOSE","OK")		
		stopconnectingtimer(id)
	else
		print("link.closecnf:error",linklist[id].state)
	end
end

--[[
函数名：statusind
功能  ：socket状态转化处理
参数  ：
		id：socket id
		state：状态字符串
返回值：无
]]
function statusind(id,state)
	--socket无效
	if linklist[id] == nil then
		print("link.statusind:nil id",id)
		return
	end

	--快发模式下，数据发送失败
	if state == "SEND FAIL" then
		if linklist[id].state == "CONNECTED" then
			linklist[id].notify(id,"SEND",state)
		else
			print("statusind:send fail state",linklist[id].state)
		end
		return
	end

	local evt
	--socket如果处于正在连接的状态，或者返回了连接成功的状态通知
	if linklist[id].state == "CONNECTING" or state == "CONNECT OK" then
		--连接类型的事件
		evt = "CONNECT"		
	else
		--状态类型的事件
		evt = "STATE"
	end

	--除非连接成功,否则连接仍然还是在关闭状态
	if state == "CONNECT OK" then
		linklist[id].state = "CONNECTED"		
	else
		linklist[id].state = "CLOSED"
	end
	--调用usersckntfy判断是否需要通知“用户socket连接状态发生变化”
	usersckntfy(id,state == "CONNECT OK")
	--调用用户注册的状态处理函数
	linklist[id].notify(id,evt,state)
	stopconnectingtimer(id)
end

--[[
函数名：connpend
功能  ：执行因IP网络未准备好被挂起的socket连接请求
参数  ：无
返回值：无
]]
local function connpend()
	for i = 0,MAXLINKS do
		if linklist[i] ~= nil then
			if linklist[i].pending then
				req(linklist[i].pending)
				local id = string.match(linklist[i].pending,"AT%+CIPSTART=(%d)")
				if id then
					startconnectingtimer(tonumber(id))
				end
				linklist[i].pending = nil
			end
		end
	end	
end

local ipstatusind
function regipstatusind()
	ipstatusind = true
end

local function ciicrerrtmfnc()
	print("ciicrerrtmfnc")
	if ciicrerrcb then
		ciicrerrcb()
	else
		sys.restart("ciicrerrtmfnc")
	end
end

--[[
函数名：setIPStatus
功能  ：设置IP网络状态
参数  ：
		status：IP网络状态
返回值：无
]]
local function setIPStatus(status)
	print("ipstatus:",status)
	
	if ipstatusind and ipstatus~=status then
		sys.dispatch("IP_STATUS_IND",status=="IP GPRSACT" or status=="IP PROCESSING" or status=="IP STATUS")
	end
	
	if not sim.getstatus() then
		status = "IP INITIAL"
	end

	if ipstatus ~= status or status=="IP START" or status == "IP CONFIG" or status == "IP GPRSACT" or status == "PDP DEACT" then
		if status=="IP GPRSACT" and checkciicrtm then
			--关闭“AT+CIICR后，IP网络超时未激活成功”的定时器
			print("ciicrerrtmfnc stop")
			sys.timer_stop(ciicrerrtmfnc)
		end
		ipstatus = status
		if ipstatus == "IP PROCESSING" then
		--IP网络准备就绪
		elseif ipstatus == "IP STATUS" then
			--执行被挂起的socket连接请求
			connpend()
		--IP网络关闭
		elseif ipstatus == "IP INITIAL" then
			--IPSTART_INTVL毫秒后，重新激活IP网络
			sys.timer_start(setupIP,IPSTART_INTVL)
		--IP网络激活中
		elseif ipstatus == "IP CONFIG" or ipstatus == "IP START" then
			--2秒钟查询一次IP网络状态
			sys.timer_start(req,2000,"AT+CIPSTATUS")
		--IP网络激活成功
		elseif ipstatus == "IP GPRSACT" then
			--获取IP地址，地址获取成功后，IP网络状态会切换为"IP STATUS"
			req("AT+CIFSR")
			--查询IP网络状态
			req("AT+CIPSTATUS")
		else --其他异常状态关闭至IP INITIAL
			shut()
			sys.timer_stop(req,"AT+CIPSTATUS")
		end
	end
end

--[[
函数名：shutcnf
功能  ：关闭IP网络结果处理
参数  ：
		result：关闭结果字符串
返回值：无
]]
local function shutcnf(result)
	shuting = false
	if ipstatusind then sys.dispatch("IP_SHUTING_IND",false) end
	--关闭成功
	if result == "SHUT OK" or not sim.getstatus() then
		setIPStatus("IP INITIAL")
		--断开所有socket连接，不清除socket参数信息
		for i = 0,MAXLINKS do
			if linklist[i] then
				if linklist[i].state == "CONNECTING" and linklist[i].pending then
					-- 对于尚未进行过的连接请求 不提示close,IP环境建立后自动连接
				elseif linklist[i].state == "INITIAL" then -- 未连接的也不提示
				else
					linklist[i].state = "CLOSED"
					linklist[i].notify(i,"STATE","SHUTED")
					usersckntfy(i,false)
				end
				stopconnectingtimer(i)
			end
		end
	else
		--req("AT+CIPSTATUS")
		sys.timer_start(req,10000,"AT+CIPSTATUS")
	end
	if checkciicrtm and result=="SHUT OK" and not ciicrerrcb then
		--关闭“AT+CIICR后，IP网络超时未激活成功”的定时器
		print("ciicrerrtmfnc stop")
		sys.timer_stop(ciicrerrtmfnc)
	end
end
--[[
local function reconnip(force)
	print("link.reconnip",force,ipstatus,cgatt)
	if force then
		setIPStatus("PDP DEACT")
	else
		if ipstatus == "IP START" or ipstatus == "IP CONFIG" or ipstatus == "IP GPRSACT" or ipstatus == "IP STATUS" or ipstatus == "IP PROCESSING" then
			setIPStatus("PDP DEACT")
		end
		cgatt = "0"
	end
end
]]

--维护从AT通道收到的一次“某个socket从服务器接收到的数据”
--id：socket id
--len：这次收到的数据总长度
--data：已经收到的数据内容
local rcvd = {id = 0,len = 0,data = ""}

--[[
函数名：rcvdfilter
功能  ：从AT通道收取一包数据
参数  ：
		data：解析到的数据
返回值：两个返回值，第一个返回值表示未处理的数据，第二个返回值表示AT通道的数据过滤器函数
]]
local function rcvdfilter(data)
	--如果总长度为0，则本函数不处理收到的数据，直接返回
	if rcvd.len == 0 then
		return data
	end
	--剩余未收到的数据长度
	local restlen = rcvd.len - string.len(rcvd.data)
	if  string.len(data) > restlen then -- at通道的内容比剩余未收到的数据多
		-- 截取网络发来的数据
		rcvd.data = rcvd.data .. string.sub(data,1,restlen)
		-- 剩下的数据仍按at进行后续处理
		data = string.sub(data,restlen+1,-1)
	else
		rcvd.data = rcvd.data .. data
		data = ""
	end

	if rcvd.len == string.len(rcvd.data) then
		--通知接收数据
		recv(rcvd.id,rcvd.len,rcvd.data)
		rcvd.id = 0
		rcvd.len = 0
		rcvd.data = ""
		return data
	else
		return data, rcvdfilter
	end
end

--[[
函数名：urc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
		data：通知的完整字符串信息
		prefix：通知的前缀
返回值：无
]]
function urc(data,prefix)
	--IP网络状态通知
	if prefix == "STATE" then
		setIPStatus(string.sub(data,8,-1))
	elseif prefix == "C" then
		--linkstatus(data)
	--IP网络被动的去激活
	elseif prefix == "+PDP" then
		--req("AT+CIPSTATUS")
		shut()
		sys.timer_stop(req,"AT+CIPSTATUS")
	--socket收到服务器发过来的数据
	elseif prefix == "+RECEIVE" then
		local lid,len = string.match(data,",(%d),(%d+)",string.len("+RECEIVE")+1)
		rcvd.id = tonumber(lid)
		rcvd.len = tonumber(len)
		return rcvdfilter
	--socket状态通知
	else
		local lid,lstate = string.match(data,"(%d), *([%u :%d]+)")

		if lid then
			lid = tonumber(lid)
			statusind(lid,lstate)
		end
	end
end

--[[
函数名：shut
功能  ：关闭IP网络
参数  ：无
返回值：无
]]
function shut()
	--如果正在执行远程升级功能或者dbg功能或者ntp功能，则延迟关闭
	if updating or dbging or ntping then shutpending = true return end
	--发送AT命令关闭
	req("AT+CIPSHUT")
	--设置关闭中标志
	shuting = true
	if ipstatusind then sys.dispatch("IP_SHUTING_IND",true) end
	shutpending = false
end
reset = shut

--[[
函数名：getresult
功能  ：解析socket状态字符串
参数  ：
		str：王铮的状态字符串，例如ERROR、1, SEND OK、1, CLOSE OK
返回值：socket状态，不包含socket id,例如ERROR、SEND OK、CLOSE OK
]]
local function getresult(str)
	return str == "ERROR" and str or string.match(str,"%d, *([%u :%d]+)")
end

--[[
函数名：rsp
功能  ：本功能模块内“通过虚拟串口发送到底层core软件的AT命令”的应答处理
参数  ：
		cmd：此应答对应的AT命令
		success：AT命令执行结果，true或者false
		response：AT命令的应答中的执行结果字符串
		intermediate：AT命令的应答中的中间信息
返回值：无
]]
local function rsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+%u+)")
	local id = tonumber(string.match(cmd,"AT%+%u+=(%d)"))
	--发送数据到服务器的应答
	if prefix == "+CIPSEND" then
		if response == "+PDP: DEACT" then
			req("AT+CIPSTATUS")
			response = "ERROR"
		end
		if string.match(response,"DATA ACCEPT") then
			sendcnf(id,"SEND OK")
		else
			sendcnf(id,getresult(response))
		end
	--关闭socket的应答
	elseif prefix == "+CIPCLOSE" then
		closecnf(id,getresult(response))
	--关闭IP网络的应答
	elseif prefix == "+CIPSHUT" then
		shutcnf(response)
	--连接到服务器的应答
	elseif prefix == "+CIPSTART" then
		if response == "ERROR" then
			statusind(id,"ERROR")
		end
	--激活IP网络的应答
	elseif prefix == "+CIICR" then
		if success then
			--成功后，底层会去激活IP网络，lua应用需要发送AT+CIPSTATUS查询IP网络状态
			if checkciicrtm and not sys.timer_is_active(ciicrerrtmfnc) then
				--启动“激活IP网络超时”定时器
				print("ciicrerrtmfnc start")
				sys.timer_start(ciicrerrtmfnc,checkciicrtm)
			end
		else
			shut()
			sys.timer_stop(req,"AT+CIPSTATUS")
		end
	end
end

--注册以下urc通知的处理函数
ril.regurc("STATE",urc)
ril.regurc("C",urc)
ril.regurc("+PDP",urc)
ril.regurc("+RECEIVE",urc)
--注册以下AT命令的应答处理函数
ril.regrsp("+CIPSTART",rsp)
ril.regrsp("+CIPSEND",rsp)
ril.regrsp("+CIPCLOSE",rsp)
ril.regrsp("+CIPSHUT",rsp)
ril.regrsp("+CIICR",rsp)

--gprs网络未附着时，定时查询附着状态的间隔
local QUERYTIME = 2000

--[[
函数名：cgattrsp
功能  ：查询GPRS数据网络附着状态的应答处理
参数  ：
		cmd：此应答对应的AT命令
		success：AT命令执行结果，true或者false
		response：AT命令的应答中的执行结果字符串
		intermediate：AT命令的应答中的中间信息
返回值：无
]]
local function cgattrsp(cmd,success,response,intermediate)
	--已附着
	if intermediate == "+CGATT: 1" then
		cgatt = "1"
		sys.dispatch("NET_GPRS_READY",true)

		-- 如果存在链接,那么在gprs附着上以后自动激活IP网络
		if base.next(linklist) then
			if ipstatus == "IP INITIAL" then
				setupIP()
			else
				req("AT+CIPSTATUS")
			end
		end
	--未附着
	elseif intermediate == "+CGATT: 0" then
		if cgatt ~= "0" then
			cgatt = "0"
			sys.dispatch("NET_GPRS_READY",false)
		end
		--设置定时器，继续查询
		sys.timer_start(querycgatt,QUERYTIME)
	end
end

--[[
函数名：querycgatt
功能  ：查询GPRS数据网络附着状态
参数  ：无
返回值：无
]]
function querycgatt()
	--不是飞行模式，才去查询
	if not flymode then req("AT+CGATT?",nil,cgattrsp) end
end

-- 配置接口
local qsend = 0
function SetQuickSend(mode)
	--qsend = mode
end

local inited = false
--[[
函数名：initial
功能  ：配置本模块功能的一些初始化参数
参数  ：无
返回值：无
]]
local function initial()
	if not inited then
		inited = true
		req("AT+CIICRMODE=2") --ciicr异步
		req("AT+CIPMUX=1") --多链接
		req("AT+CIPHEAD=1")
		req("AT+CIPQSEND=" .. qsend)--发送模式
	end
end

--[[
函数名：netmsg
功能  ：GSM网络注册状态发生变化的处理
参数  ：无
返回值：true
]]
local function netmsg(id,data)
	--GSM网络已注册
	if data == "REGISTERED" then
		--进行初始化配置
		initial() 
		--定时查询GPRS数据网络附着状态
		sys.timer_start(querycgatt,QUERYTIME)
	end

	return true
end

--sim卡的默认apn表
local apntable =
{
	["46000"] = "CMNET",
	["46002"] = "CMNET",
	["46004"] = "CMNET",
	["46007"] = "CMNET",
	["46001"] = "UNINET",
	["46006"] = "UNINET",
}

--[[
函数名：proc
功能  ：本模块注册的内部消息的处理函数
参数  ：
		id：内部消息id
		para：内部消息参数
返回值：true
]]
local function proc(id,para)
	--IMSI读取成功
	if id=="IMSI_READY" then
		--本模块内部自动获取apn信息进行配置
		if apnflag then
			if apn then
				local temp1,temp2,temp3=apn.get_default_apn(tonumber(sim.getmcc(),16),tonumber(sim.getmnc(),16))
				if temp1 == '' or temp1 == nil then temp1="CMNET" end
				setapn(temp1,temp2,temp3)
			else
				setapn(apntable[sim.getmcc()..sim.getmnc()] or "CMNET")
			end
		end
	--飞行模式状态变化
	elseif id=="FLYMODE_IND" then
		flymode = para
		if para then
			sys.timer_stop(req,"AT+CIPSTATUS")
		else
			req("AT+CGATT?",nil,cgattrsp)
		end
	--远程升级开始
	elseif id=="UPDATE_BEGIN_IND" then
		updating = true
	--远程升级结束
	elseif id=="UPDATE_END_IND" then
		updating = false
		if shutpending then shut() end
	--dbg功能开始
	elseif id=="DBG_BEGIN_IND" then
		dbging = true
	--dbg功能结束
	elseif id=="DBG_END_IND" then
		dbging = false
		if shutpending then shut() end
	--NTP同步开始
	elseif id=="NTP_BEGIN_IND" then
		ntping = true
	--NTP同步结束
	elseif id=="NTP_END_IND" then
		ntping = false
		if shutpending then shut() end
	end
	return true
end

--[[
函数名：checkciicr
功能  ：设置激活IP网络请求后，超时未成功的超时时间。执行AT+CIICR后，如果设置了checkciicrtm，checkciicrtm毫秒后，没有激活成功，则重启软件（中途执行AT+CIPSHUT则不再重启）
参数  ：
		tm：超时时间，单位毫秒
返回值：true
]]
function checkciicr(tm)
	checkciicrtm = tm
	ril.regrsp("+CIICR",rsp)
end

--[[
函数名：setiperrcb
功能  ：设置"激活IP网络请求后，超时未成功"的用户回调函数
参数  ：
		cb：回调函数
返回值：无
]]
function setiperrcb(cb)
	ciicrerrcb = cb
end

--[[
函数名：setretrymode
功能  ：设置"连接过程和数据发送过程中TCP协议的重连参数"
参数  ：
		md：number类型，仅支持0和1
			0为尽可能多的重连（可能会很长时间才会返回连接或者发送接口）
			1为适度重连（如果网络较差或者没有网络，可以10几秒返回失败结果）
返回值：无
]]
function setretrymode(md)
	ril.request("AT+TCPUSERPARAM=6,"..(md==0 and 3 or 2)..",7200")
end

--注册本模块关注的内部消息的处理函数
sys.regapp(proc,"IMSI_READY","FLYMODE_IND","UPDATE_BEGIN_IND","UPDATE_END_IND","DBG_BEGIN_IND","DBG_END_IND","NTP_BEGIN_IND","NTP_END_IND")
sys.regapp(netmsg,"NET_STATE_CHANGED")
checkciicr(120000)
