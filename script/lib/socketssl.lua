require"linkssl"
module(...,package.seeall)

local lstate,scks = linkssl.getstate,{}
SCK_MAX_CNT = 10
NORMAL,SVR_CHANGE,DISCTHENTRY = 0,1,2

local function print(...)
	_G.print("socketssl",...)
end

local function checkidx(cause,idx,fnm)
	if (cause == 0 and idx <= SCK_MAX_CNT+1) or (cause == 1 and scks[idx]) then
		return true
	else
		print("checkidx "..fnm.." err",idx)
	end
end

local function checkidx1(idx,fnm)
	return checkidx(0,idx,fnm) and checkidx(1,idx,fnm)
end

local function getidxbyid(id)
	local i
	for i=1,SCK_MAX_CNT+1 do
		if scks[i] and scks[i].id == id then return i end
	end
end

local function conrstpara(idx,suc)
	if not checkidx(1,idx,"conrstpara") then return end
	scks[idx].conretry,scks[idx].concause = 0
	if not suc then	scks[idx].sndpending,scks[idx].sndingitem = {},{} end
	scks[idx].waitingrspitem = {}
end

local function sndrstpara(idx)
	if not checkidx(1,idx,"sndrstpara") then return end
	scks[idx].sndretry,scks[idx].sndingitem = 0,{}
end

local function discrstpara(idx)
	if not checkidx(1,idx,"discrstpara") then return end
	scks[idx].discause = nil
end

local function rsumscksnd(idx)
	if not checkidx(1,idx,"rsumscksnd") then return end
	if lstate(scks[idx].id) ~= "CONNECTED" then
		return linkssl.connect(scks[idx].id,scks[idx].prot,scks[idx].addr,scks[idx].port,scks[idx].chksvrcrt,scks[idx].crtconfig)
	else
		if #scks[idx].sndpending ~= 0 and not scks[idx].sndingitem.data and not scks[idx].waitingrspitem.data then
			local item = table.remove(scks[idx].sndpending,1)
			if linkssl.send(scks[idx].id,item.data) then
				scks[idx].sndingitem = item
			else
				table.insert(scks[idx].sndpending,1,item)
			end
		end
	end
	return true
end

function setwaitingrspitem(idx,item)
	if not checkidx(1,idx,"setwaitingrspitem") then return end
	scks[idx].waitingrspitem = item
	if not item.data then
		rsumscksnd(idx)
	end
end

local function conack(idx,cause,suc)	
	if #scks[idx].sndpending ~= 0 and not suc then
		while #scks[idx].sndpending ~= 0 do
			scks[idx].rsp(idx,"SEND",suc,table.remove(scks[idx].sndpending,1))
		end
	end
	scks[idx].rsp(idx,"CONNECT",suc,cause)
	conrstpara(idx,suc)
end

local function sndnxt(id,idx)
	local item = table.remove(scks[idx].sndpending,1)
	if linkssl.send(id,item.data) then
		scks[idx].sndingitem = item
	else
		table.insert(scks[idx].sndpending,1,item)
	end
end

local function sndack(idx,suc,item)
	sndrstpara(idx)
	scks[idx].rsp(idx,"SEND",suc,item)	
	if #scks[idx].sndpending ~= 0 and not suc then
		while #scks[idx].sndpending ~= 0 do
			scks[idx].rsp(idx,"SEND",suc,table.remove(scks[idx].sndpending,1))
		end
	end
end

local function sckrsp(id,evt,val)--对此连接的状态通知和处理的程序
	local idx = getidxbyid(id)
	if not idx then print("sckrsp err idx",id,evt,val) return end
	print("sckrsp",id,evt,val)

	if evt == "CONNECT" then
		local cause = scks[idx].concause
		if val ~= "CONNECT OK" then
			scks[idx].conretry = scks[idx].conretry + 1
			if scks[idx].conretry >= 1 then
				conack(idx,cause,false)
			else
				if not linkssl.connect(id,scks[idx].prot,scks[idx].addr,scks[idx].port,scks[idx].chksvrcrt,scks[idx].crtconfig) then
					conack(idx,cause,false)
				end
			end
		else
			conack(idx,cause,true)
			if #scks[idx].sndpending ~= 0 and not scks[idx].sndingitem.data then
				sndnxt(id,idx)
			end
		end
	elseif evt == "SEND" then
		local item = scks[idx].sndingitem
		if val ~= "SEND OK" then
			scks[idx].sndretry = scks[idx].sndretry + 1
			if scks[idx].sndretry >= 1 then
				sndack(idx,false,item)
			else
				if not linkssl.send(id,item.data) then---向服务器发送数据
					sndack(idx,false,item)
				end
			end
		else
			sndack(idx,true,item)
			if #scks[idx].sndpending ~= 0 and not scks[idx].sndingitem.data and not scks[idx].waitingrspitem.data then
				sndnxt(id,idx)
			end
		end
	elseif evt == "DISCONNECT" then
		local cause = scks[idx].discause
		discrstpara(idx)
		if cause == SVR_CHANGE or #scks[idx].sndpending ~= 0 then
			--link.connect(id,scks[idx].prot,scks[idx].addr,scks[idx].port)
			scks[idx].concause = cause
		end
		scks[idx].rsp(idx,"DISCONNECT",true,cause)
	elseif evt == "CLOSE" then
		local rspCb = scks[idx].rsp
		scks[idx] = nil
		rspCb(idx,"CLOSE",true)		
	elseif evt == "STATE" and val == "CLOSED" then
		if #scks[idx].sndpending ~= 0 then
			--link.connect(id,scks[idx].prot,scks[idx].addr,scks[idx].port)
			while #scks[idx].sndpending ~= 0 do
				scks[idx].rsp(idx,"SEND",false,table.remove(scks[idx].sndpending,1))
			end
		end
		scks[idx].rsp(idx,evt,val,nil)
	else
		scks[idx].rsp(idx,evt,val,nil)
	end
end

local function sckrcv(id,data)--对此连接收到数据进行处理的程序
	scks[getidxbyid(id)].rcv(getidxbyid(id),data)
end

function clrsnding(idx)
	if not checkidx1(idx,"clrsnding") then return end
	iscks[idx].sndpending = {}
end

local function init(idx,id,cause,prot,addr,port,rsp,rcv,discause,chksvrcrt,crtconfig)
	scks[idx] =
	{
		id = id,
		addr = addr,
		port = port,
		prot = prot,
		conretry = 0,
		sndretry = 0,
		sndpending = {},
		sndingitem = {},
		waitingrspitem = {},
		rsp = rsp,
		rcv = rcv,
		concause = cause,
		discause = discause,
		chksvrcrt = chksvrcrt,
		crtconfig = crtconfig,
	}
end

--[[
函数名：create
功能  ：创建socket（如果socket不存在）
参数  ：
		idx：number类型，socket id，如果使用了mqtt模块，取值范围是1、2、3；如果没使用mqtt模块，取值范围是1、2、3、4、5。[必选]
		prot：string类型，传输层协议，目前仅支持"TCP"和"UDP"
		addr：string类型，服务器地址，支持IP地址和域名
		port：number类型，服务器端口
		rsp：function类型，socket的状态处理函数
		rcv：function类型，socket的数据接收处理函数
		chksvrcrt：boolean类型，是否检验服务器端证书
		crtconfig：table类型，{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
		cause：暂时无用，后续扩展使用
返回值：true表示成功创建了socket，false表示没有成功创建
]]
function create(idx,prot,addr,port,rsp,rcv,chksvrcrt,crtconfig,cause)
	if not checkidx(0,idx,"create") or checkidx(1,idx,"create") then return end
	init(idx,linkssl.open(sckrsp,sckrcv),cause,prot,addr,port,rsp,rcv,nil,chksvrcrt,crtconfig)
	return true
end

--[[
函数名：connect
功能  ：创建socket（如果socket不存在），并且连接服务器
参数  ：
		idx：number类型，socket id，如果使用了mqtt模块，取值范围是1、2、3；如果没使用mqtt模块，取值范围是1、2、3、4、5。[必选]
		prot：string类型，传输层协议，目前仅支持"TCP"和"UDP"
		addr：string类型，服务器地址，支持IP地址和域名
		port：number类型，服务器端口
		rsp：function类型，socket的状态处理函数
		rcv：function类型，socket的数据接收处理函数
		chksvrcrt：boolean类型，是否检验服务器端证书
		crtconfig：table类型，{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
		cause：暂时无用，后续扩展使用
返回值：true表示成功调用了连接接口（连接结果会有异步消息通知到socket状态处理函数中），false表示没有成功调用连接接口
]]
function connect(idx,prot,addr,port,rsp,rcv,chksvrcrt,crtconfig,cause)
	if not checkidx(0,idx,"connect") then return end
	local discause,sckid
	if scks[idx] then
		sckid = scks[idx].id
		scks[idx].crtconfig = crtconfig
		if linkssl.getstate(sckid) == "CONNECTED" then
			if scks[idx].addr == addr and scks[idx].port == port and scks[idx].prot == prot then
				return true
			else
				if linkssl.disconnect(sckid) then discause = cause	end
			end
		else
			if not linkssl.connect(sckid,prot,addr,port,chksvrcrt,crtconfig) then
				print("connect fail1")
				return false
			end
		end
	else
		sckid = linkssl.open(sckrsp,sckrcv)
		if not linkssl.connect(sckid,prot,addr,port,chksvrcrt,crtconfig) then
			print("connect fail2")
			return false
		end
	end
	init(idx,sckid,cause,prot,addr,port,rsp,rcv,discause,chksvrcrt,crtconfig)

	return true
end

--[[
函数名：send
功能  ：发送数据
参数  ：
		idx：number类型，socket id，如果使用了mqtt模块，取值范围是1、2、3；如果没使用mqtt模块，取值范围是1、2、3、4、5。[必选]
		data：要发送的数据
		para：发送的参数
		pos：暂时无用，后续扩展使用
		ins：暂时无用，后续扩展使用
返回值：true表示成功调用了发送接口（发送结果会有异步消息通知到socket状态处理函数中），false表示没有成功调用发送接口
]]
function send(idx,data,para,pos,ins)
	if not checkidx1(idx,"send") then return end
	if not data or string.len(data) == 0 then print("send data empty") return end

	local sckid = scks[idx].id
	local item,tail = {data = data, para = para},#scks[idx].sndpending+1

	if lstate(sckid) ~= "CONNECTED" then
		local res = linkssl.connect(sckid,scks[idx].prot,scks[idx].addr,scks[idx].port,scks[idx].chksvrcrt,scks[idx].crtconfig)
		if res or (not res and ins) then
			table.insert(scks[idx].sndpending,pos or tail,item)
		else
			return
		end
		return true
	else
		if scks[idx].sndingitem.data or scks[idx].waitingrspitem.data then
			table.insert(scks[idx].sndpending,pos or tail,item)
		else
			if linkssl.send(sckid,data) then  --发送数据
				scks[idx].sndingitem = item
			end
		end
	end
	return true
end

--[[
函数名：disconnect
功能  ：断开一个socket连接
参数  ：
		idx：number类型，socket id，如果使用了mqtt模块，取值范围是1、2、3；如果没使用mqtt模块，取值范围是1、2、3、4、5。[必选]
		cause：目前无用，后续扩展使用[可选]
返回值：true表示成功调用了断开接口（断开结果会有异步消息通知到socket的状态处理函数中），false表示没有成功调用断开接口
]]
function disconnect(idx,cause)
	if not checkidx1(idx,"disconnect") then return end
	scks[idx].discause = cause
	return linkssl.disconnect(scks[idx].id) --关闭连接
end

--[[
函数名：close
功能  ：断开一个socket连接,并且销毁
参数  ：
		idx：number类型，socket id，如果使用了mqtt模块，取值范围是1、2、3；如果没使用mqtt模块，取值范围是1、2、3、4、5。[必选]
返回值：true表示成功调用了断开接口（断开结果会有异步消息通知到socket的状态处理函数中），false表示没有成功调用断开接口
]]
function close(idx)
	if not checkidx1(idx,"close") then return end
	return linkssl.close(scks[idx].id) --销毁连接
end

function isactive(idx)
	if not checkidx1(idx,"isactive") then return end	
	return linkssl.getstate(scks[idx].id) == "CONNECTED"
end
