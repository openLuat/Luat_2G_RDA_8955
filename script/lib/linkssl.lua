--[[
模块名称：SSL SOCKET管理
模块功能：SSL SOCKET的创建、连接、数据收发、状态维护
模块最后修改时间：2017.04.26
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
local link = require"link"
module("linkssl",package.seeall)

--加载常用的全局函数至本地
local print = base.print
local pairs = base.pairs
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

local ipstatus,shuting
--最大socket id，从0开始，所以同时支持的socket连接数是8个
local MAXLINKS = 7
--socket连接表
local linklist = {}
--是否初始化
local inited
local crtinputed,crtpending = "",{}


local function print(...)
	_G.print("linkssl",...)
end

--[[
函数名：init
功能  ：初始化ssl功能模块
参数  ：无
返回值：无
]]
local function init()
	if not inited then
		inited = true
		req("AT+SSLINIT")		
	end
	local i,item
	for i=1,#crtpending do
		item = table.remove(crtpending,1)
		req(item.cmd,item.arg)
	end
	crtpending = {}
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
		print("validaction:id nil",id)
		return false
	end

	--同一个状态不重复执行
	if action.."ING" == linklist[id].state then
		print("validaction:",action,linklist[id].state)
		return false
	end

	local ing = string.match(linklist[id].state,"(ING)",-3)

	if ing then
		--有其他任务在处理时,不允许处理连接,断链或者关闭是可以的
		if action == "CONNECT" then
			print("validaction: action running",linklist[id].state,action)
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

	local item = {
		notify = notify,
		recv = recv,
		state = "INITIAL",
		tag = tag,
	}

	linklist[id] = item

	--注册连接urc
	ril.regurc("SSL&"..id,urc)
	
	--激活IP网络
	if not ipstatus then
		link.setupIP()
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
	req("AT+SSLDESTROY="..id)

	return true
end

--[[
函数名：connect
功能  ：socket连接服务器请求
参数  ：
		id：socket id
		protocol：传输层协议，TCP或者UDP
		address：服务器地址
		port：服务器端口
		chksvrcrt：boolean类型，是否检验服务器端证书
		crtconfig：nil或者table类型，{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
返回值：请求成功同步返回true，否则false；
]]
function connect(id,protocol,address,port,chksvrcrt,crtconfig)
	--不允许发起连接动作
	if validaction(id,"CONNECT") == false or linklist[id].state == "CONNECTED" then
		return false
	end

	linklist[id].state = "CONNECTING"

	local createstr = string.format("AT+SSLCREATE=%d,\"%s\",%d",id,address..":"..port,chksvrcrt and 0 or 1)
	local configcrtstr,i = {}
	if crtconfig then
		if chksvrcrt and crtconfig.verifysvrcerts then
			for i=1,#crtconfig.verifysvrcerts do
				inputcrt("cacrt",crtconfig.verifysvrcerts[i])
				table.insert(configcrtstr,"AT+SSLCERT=1,"..id..",\"cacrt\",\""..crtconfig.verifysvrcerts[i].."\"")
			end
		end
		if crtconfig.clientcert then
			inputcrt("localcrt",crtconfig.clientcert)
			table.insert(configcrtstr,"AT+SSLCERT=1,"..id..",\"localcrt\",\""..crtconfig.clientcert.."\",\""..(crtconfig.clientcertpswd or "").."\"")
		end
		if crtconfig.clientkey then
			inputcrt("localprivatekey",crtconfig.clientkey)
			table.insert(configcrtstr,"AT+SSLCERT=1,"..id..",\"localprivatekey\",\""..crtconfig.clientkey.."\"")
		end
	end
	local connstr = "AT+SSLCONNECT="..id

	if not ipstatus or shuting then
		--ip环境未准备好先加入等待
		linklist[id].pending = createstr.."\r\n"
		for i=1,#configcrtstr do
			linklist[id].pending = linklist[id].pending..configcrtstr[i].."\r\n"
		end
		linklist[id].pending = linklist[id].pending..connstr.."\r\n"
	else
		init()
		--发送AT命令连接服务器
		req(createstr)
		for i=1,#configcrtstr do
			req(configcrtstr[i])
		end
		req(connstr)
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
		if not ipstatus and linklist[id].state == "CONNECTING" then
			print("disconnect: ip not ready",ipstatus)
			linklist[id].state = "DISCONNECTING"
			return
		end
	end

	linklist[id].state = "DISCONNECTING"
	--发送AT命令断开
	req("AT+SSLDESTROY="..id)

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
		print("send:error",id)
		return false
	end

	--发送AT命令执行数据发送
	req(string.format("AT+SSLSEND=%d,%d",id,string.len(data)),data)

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
		print("recv:error",id)
		return
	end
	--调用socket id对应的用户注册的数据接收处理函数
	if linklist[id].recv then
		linklist[id].recv(id,data)
	else
		print("recv:nil recv",id)
	end
end

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
	--产生一个内部消息"USER_SOCKETSSL_CONNECT"，通知“用户创建的socket连接状态发生变化”
	if not linklist[id].tag then sys.dispatch("USER_SOCKETSSL_CONNECT",usersckisactive()) end
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
	print("sendcnf",id,result,linklist[id].state)
	--发送失败
	if string.match(result,"ERROR") then
		linklist[id].state = "ERROR"
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
		print("closecnf:error",id)
		return
	end
	print("closecnf",id,result,linklist[id].state)
	--不管任何的close结果,链接总是成功断开了,所以直接按照链接断开处理
	if linklist[id].state == "DISCONNECTING" then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"DISCONNECT","OK")
		usersckntfy(id,false)
	--连接注销,清除维护的连接信息,清除urc关注
	elseif linklist[id].state == "CLOSING" then		
		local tlink = linklist[id]
		usersckntfy(id,false)
		linklist[id] = nil
		ril.deregurc("SSL&"..id,urc)
		tlink.notify(id,"CLOSE","OK")		
	else
		print("closecnf:error",linklist[id].state)
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
	print("statusind",id,state,linklist[id])
	--socket无效
	if linklist[id] == nil then
		print("statusind:nil id",id)
		return
	end	
	print("statusind1",linklist[id].state)
	if linklist[id].state == "CONNECTING" and string.match(state,"SEND ERROR") then
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
				init()
				local item
				for item in string.gmatch(linklist[i].pending,"(.-)\r\n") do
					req(item)
				end
				linklist[i].pending = nil
			end
		end
	end	
end

--[[
函数名：ipstatusind
功能  ：IP网络状态变化处理
参数  ：
		s：IP网络状态
返回值：无
]]
local function ipstatusind(s)
	print("ipstatus:",ipstatus,s)
	if ipstatus ~= s then
		ipstatus = s
		--执行被挂起的socket连接请求
		if s then connpend() end
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
	--关闭成功
	if result == "SHUT OK" then
		ipstatusind(false)
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
			end
		end
	end
end

--维护从AT通道收到的一次“某个socket从服务器接收到的数据”
--id：socket id
--len：这次收到的数据总长度
--data：已经收到的数据内容
local rcvd = {id = 0,len = 0,rcvLen = 0,data = {}}

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
	local restlen = rcvd.len - rcvd.rcvLen
	if  string.len(data) > restlen then -- at通道的内容比剩余未收到的数据多
		-- 截取网络发来的数据
		table.insert(rcvd.data,string.sub(data,1,restlen))
		rcvd.rcvLen = rcvd.rcvLen+restlen
		-- 剩下的数据仍按at进行后续处理
		data = string.sub(data,restlen+1,-1)
	else
		table.insert(rcvd.data,data)
		rcvd.rcvLen = rcvd.rcvLen+data:len()
		data = ""
	end

	if rcvd.len == rcvd.rcvLen then
		--通知接收数据
		recv(rcvd.id,rcvd.len,table.concat(rcvd.data))
		rcvd.id = 0
		rcvd.len = 0
		rcvd.rcvLen = 0
		rcvd.data = {}
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
	print("urc prefix",prefix)
	--socket收到服务器发过来的数据
	if prefix == "+SSL RECEIVE" then
		local lid,len = string.match(data,",(%d),(%d+)",string.len("+SSL RECEIVE")+1)
		rcvd.id = tonumber(lid)
		rcvd.len = tonumber(len)
		return rcvdfilter,rcvd.len
	--socket状态通知
	else
		
		local lid,lstate = string.match(data,"(%d), *([%u :%d]+)")
		print("urc data",data,lid,lstate)
		
		if string.find(lstate,"ERROR:")==1 then return end

		if lid then
			lid = tonumber(lid)
			statusind(lid,lstate)
		end
	end
end

--[[
函数名：getresult
功能  ：解析socket状态字符串
参数  ：
		str：socket状态字符串，例如SSL&1,SEND OK
返回值：socket状态，不包含socket id,例如SEND OK
]]
local function getresult(str)
	return str == "ERROR" and str or string.match(str,"%d, *([%u :%d]+)")
end

local function emptylink()
	for i = 0,MAXLINKS do
		if linklist[i] == nil then
			return i
		end
	end

	return nil
end

--[[
函数名：term
功能  ：关闭ssl功能模块
参数  ：无
返回值：无
]]
local function term()
	if inited then
		local valid,i
		for i = 0,MAXLINKS do
			if linklist[i] and linklist[i].state~="CLOSED" and linklist[i].state~="INITIAL" then
				valid = true
				break
			end
		end
		if not valid then
			inited = false
			req("AT+SSLTERM")
			crtinputed = ""
		end
	end
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
	
	print("rsp",id,prefix,response)
	
	if prefix == "+SSLCONNECT" then
		--statusind(id,getresult(response))
		if response == "ERROR" then
			statusind(id,"ERROR")
		end
	--发送数据到服务器的应答
	elseif prefix == "+SSLSEND" then
		sendcnf(id,getresult(response))
	--关闭socket的应答
	elseif prefix == "+SSLDESTROY" then
		closecnf(id,getresult(response))	
		term()
	end
end

local function ipshutingind(s)
	if s then
		shuting = true
	else
		shutcnf("SHUT OK")
	end
end

local function gprsind(s)
	if s and base.next(linklist) and not ipstatus then
		link.setupIP()
	end
	return true
end

function inputcrt(t,f,d)
	if string.match(crtinputed,t..f.."&") then return end
	if not crtpending then crtpending={} end
	if d then
		table.insert(crtpending,{cmd="AT+SSLCERT=0,\""..t.."\",\""..f.."\",1,"..string.len(d),arg=d})
	else
		local path = (string.sub(f,1,1)=="/") and f or ("/ldata/"..f)
		local fconfig = io.open(path,"rb")
		if not fconfig then print("inputcrt err open",path) return end
		local s = fconfig:read("*a")
		fconfig:close()
		table.insert(crtpending,{cmd="AT+SSLCERT=0,\""..t.."\",\""..f.."\",1,"..string.len(s),arg=s})
	end
	crtinputed = crtinputed..t..f.."&"
end

local procer =
{
	IP_STATUS_IND = ipstatusind,
	IP_SHUTING_IND = ipshutingind,
	NET_GPRS_READY = gprsind,
}

sys.regapp(procer)
--注册以下urc通知的处理函数
ril.regurc("+SSL RECEIVE",urc)
--注册以下AT命令的应答处理函数
ril.regrsp("+SSLCONNECT",rsp)
ril.regrsp("+SSLSEND",rsp)
ril.regrsp("+SSLDESTROY",rsp)

link.regipstatusind()
