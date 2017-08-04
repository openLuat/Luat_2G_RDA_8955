
module(...,package.seeall)

require "common"
require"socket"
local lpack=require"pack"

local sfind, slen,sbyte,ssub,sgsub,schar,srep,smatch,sgmatch = string.find ,string.len,string.byte,string.sub,string.gsub,string.char,string.rep,string.match,string.gmatch

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("http",...)
end



--http clients存储表
local tclients = {}

--[[
函数名：getclient
功能  ：返回一个http client在tclients中的索引
参数  ：
	  sckidx：http client对应的socket索引
返回值：sckidx对应的http client在tclients中的索引
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end



--[[
函数名：datinactive
功能  ：数据通信异常处理
参数  ：
		sckidx：socket idx
返回值：无
]]
local function datinactive(sckidx)
    sys.restart("SVRNODATA")
end


--[[
函数名：snd
功能  ：调用发送接口发送数据
参数  ：
		sckidx：socket idx
        data：发送的数据，在发送结果事件处理函数ntfy中，会赋值到item.data中
		para：发送的参数，在发送结果事件处理函数ntfy中，会赋值到item.para中 
返回值：调用发送接口的结果（并不是数据发送是否成功的结果，数据发送是否成功的结果在ntfy中的SEND事件中通知），true为成功，其他为失败
]]
function snd(sckidx,data,para)
    return socket.send(sckidx,data,para)
end


local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20




--[[
函数名：reconn
功能  ：socket重连后台处理
        一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
        如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
        如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
参数  ：
		sckidx：socket idx
返回值：无
]]
function reconn(sckidx)
	local httpclientidx = getclient(sckidx)
	print("reconn"--[[,httpclientidx,tclients[httpclientidx].sckreconncnt,tclients[httpclientidx].sckconning,tclients[httpclientidx].sckreconncyclecnt]])
	--sckconning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致sckreconncnt增加，实际的重连次数减少
	if tclients[httpclientidx].sckconning then return end
	--一个连接周期内的重连
	if tclients[httpclientidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[httpclientidx].sckreconncnt = tclients[httpclientidx].sckreconncnt+1
		link.shut()
		for k,v in pairs(tclients) do
			connect(v.sckidx,v.prot,v.host,v.port)
		end
	--一个连接周期的重连都失败
	else
		tclients[httpclientidx].sckreconncnt,tclients[httpclientidx].sckreconncyclecnt = 0,tclients[httpclientidx].sckreconncyclecnt+1
		if tclients[httpclientidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			if tclients[httpclientidx].sckerrcb then
				tclients[httpclientidx].sckreconncnt=0
				tclients[httpclientidx].sckreconncyclecnt=0
				tclients[httpclientidx].sckerrcb("CONNECT")
			else
				sys.restart("connect fail")
			end
		else
			sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000,sckidx)
		end		
	end
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		result： bool类型，消息事件结果，true为成功，其他为失败
		item：table类型，{data=,para=}，消息回传的参数和数据，目前只是在SEND类型的事件中用到了此参数，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
返回值：无
]]
function ntfy(idx,evt,result,item)
	local httpclientidx = getclient(idx)
	print("ntfy",evt,result,item)
	--连接结果（调用socket.connect后的异步事件）
	if evt == "CONNECT" then
		tclients[httpclientidx].sckconning = false
		--连接成功
		if result then
			tclients[httpclientidx].sckconnected=true
			tclients[httpclientidx].sckreconncnt=0
			tclients[httpclientidx].sckreconncyclecnt=0
			--停止重连定时器
			sys.timer_stop(reconn,idx)
			tclients[httpclientidx].connectedcb()
		--	snd(idx,"GET / HTTP/1.1\r\nHost: www.openluat.com\r\nConnection: keep-alive\r\n\r\n","GET")
		--   连接失败
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--数据发送结果（调用socket.send后的异步事件）
	elseif evt == "SEND" then
		if not result then
			print("error code")	     	
		end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		tclients[httpclientidx].sckconnected=false
		tclients[httpclientidx].httpconnected=false
		tclients[httpclientidx].sckconning = false
		--长连接时使用
--		reconn(idx)
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		tclients[httpclientidx].sckconnected=false
		tclients[httpclientidx].httpconnected=false
		tclients[httpclientidx].sckconning = false
		--长连接时使用
--		reconn(idx)
	--连接主动断开（调用socket.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		tclients[httpclientidx].sckconnected=false
		tclients[httpclientidx].httpconnected=false
		tclients[httpclientidx].sckconning = false
		if item=="USER" then
			if tclients[httpclientidx].discb then tclients[httpclientidx].discb(idx) end
			tclients[httpclientidx].discing = false
		end	
	--长连接时使用
--		reconn(idx)
	--连接主动断开并且销毁（调用socket.close后的异步事件）
	elseif evt == "CLOSE" then
		local cb = tclients[httpclientidx].destroycb
		table.remove(tclients,httpclientidx)
		if cb then cb() end
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((type(result)=="string") and result or "","ERROR") then
		link.shut()
	end
end

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        idx ：socket中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
--[[
函数名：Timerfnc
功能：当接收数据超时时启动定时器
参数：客户端对应的SOCKER的ID
返回值：
]]
function  timerfnc(httpclientidx)
	tclients[httpclientidx].result=3
	tclients[httpclientidx].statuscode=nil
	tclients[httpclientidx].rcvhead=nil
	tclients[httpclientidx].rcvbody=nil
	tclients[httpclientidx].rcvcb(tclients[httpclientidx].result)
	tclients[httpclientidx].status=false
	tclients[httpclientidx].result=nil
	tclients[httpclientidx].statuscode=nil
	tclients[httpclientidx].data=nil
end
--[[
函数名：数据接收处理函数
功能：将服务器返回的数据进行处理
参数：idx：客户端所对应的端口ID data：服务器返回的数据
返回值：无
]]
function rcv(idx,data)
    local httpclientidx = getclient(idx)
	--设置一个定时器，时间为5秒
	sys.timer_start(timerfnc,5000,httpclientidx)
	--如果没有数据
	if not data then 
		print("rcv: no data receive")
	--如果存在接收反馈函数
	elseif tclients[httpclientidx].rcvcb then 
		--创建接收数据
		if not tclients[httpclientidx].data then tclients[httpclientidx].data="" end 
		tclients[httpclientidx].data=tclients[httpclientidx].data..data
		local h1,h2 = sfind(tclients[httpclientidx].data,"\r\n\r\n")
		--得到状态行和首部，判断状态
		--解析状态行和所有头
		if sfind(tclients[httpclientidx].data,"\r\n\r\n") and not tclients[httpclientidx].status then 
			--设置状态参数，如果为真下次就不需要运行此过程
			tclients[httpclientidx].status=true 
			local totil=ssub(tclients[httpclientidx].data,1,h2+1)
			tclients[httpclientidx].statuscode=smatch(totil,"%s(%d+)%s")
			tclients[httpclientidx].contentlen=tonumber(smatch(totil,":%s(%d+)\r\n"),10)
			local total=smatch(totil,"\r\n(.+\r\n)\r\n")
			--判断total是否为空
			if	total~=""	then	
				if	not tclients[httpclientidx].rcvhead	 then	tclients[httpclientidx].rcvhead={}	end
				for k,v in sgmatch(total,"(.-):%s(.-)\r\n") do
					if	v=="chunked"	then
						chunked=true
					end
					tclients[httpclientidx].rcvhead[k]=v
				end
			end
		end
		--如果已经得到首部且存在接收反馈函数
		if	tclients[httpclientidx].rcvhead	and tclients[httpclientidx].rcvcb then
			--是否头部为Transfer-Encoding=chunked，若是则采用的是分块传输编码
			if	chunked	then
				if	sfind(ssub(tclients[httpclientidx].data,h1+2,-1),"\r\n0%s-\r\n")	then
					local h3=sfind(ssub(tclients[httpclientidx].data,h1+2,-1),"\r\n0%s-\r\n")					
					tclients[httpclientidx].rcvbody=ssub(tclients[httpclientidx].data,h2+1,h3)
					tclients[httpclientidx].result=4
					tclients[httpclientidx].rcvcb(tclients[httpclientidx].result,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead,tclients[httpclientidx].rcvbody)
					sys.timer_stop(timerfnc,httpclientidx)
					tclients[httpclientidx].result=nil
					tclients[httpclientidx].statuscode=nil
					tclients[httpclientidx].statuscode=nil
					tclients[httpclientidx].rcvhead=nil
					tclients[httpclientidx].rcvbody=nil
					tclients[httpclientidx].data=""
					tclients[httpclientidx].status=false
					chunked=false
				end		
			--是否得到实体，如果是运行下面	
			elseif ssub(tclients[httpclientidx].data,h2+1,-1) then
				--有实体且实体长度等于实际长度
				if	 slen(ssub(tclients[httpclientidx].data,h2+1,-1)) == tclients[httpclientidx].contentlen	then
					tclients[httpclientidx].result=0
					tclients[httpclientidx].rcvbody=ssub(tclients[httpclientidx].data,h2+1,-1)
					--获得实体
					tclients[httpclientidx].rcvcb(tclients[httpclientidx].result,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead,tclients[httpclientidx].rcvbody)
					sys.timer_stop(timerfnc,httpclientidx)
					tclients[httpclientidx].result=nil
					tclients[httpclientidx].statuscode=nil
					tclients[httpclientidx].statuscode=nil
					tclients[httpclientidx].rcvhead=nil
					tclients[httpclientidx].rcvbody=nil
					tclients[httpclientidx].data=""
					tclients[httpclientidx].status=false
				elseif	slen(ssub(tclients[httpclientidx].data,h2+1,-1)) > tclients[httpclientidx].contentlen	then
					--有实体且实体长度大于实际长度
					tclients[httpclientidx].result=2
					tclients[httpclientidx].rcvbody=nil
					tclients[httpclientidx].rcvcb(tclients[httpclientidx].result,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead)
					sys.timer_stop(timerfnc,httpclientidx)
					tclients[httpclientidx].result=nil
					tclients[httpclientidx].statuscode=nil
					tclients[httpclientidx].statuscode=nil
					tclients[httpclientidx].rcvhead=nil
					tclients[httpclientidx].data=""
					tclients[httpclientidx].status=false										
				end
			--存在首部，但是实体长度为0
			elseif	 tclients[httpclientidx].contentlen==0	then
				tclients[httpclientidx].result=1
				tclients[httpclientidx].rcvcb(tclients[httpclientidx].result,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead)
				sys.timer_stop(timerfnc,httpclientidx)
				tclients[httpclientidx].result=nil
				tclients[httpclientidx].statuscode=nil
				tclients[httpclientidx].statuscode=nil
				tclients[httpclientidx].rcvhead=nil
				tclients[httpclientidx].data=""
				tclients[httpclientidx].status=false
			end
		--有数据且没接收反馈函数	
		elseif	not tclients[httpclientidx].rcvhead	then
			print("no message reback")
		else
			print("rcv",data)
		end
	end
end



--[[
函数名：connect
功能  ：创建到后台服务器的socket连接；
        如果数据网络已经准备好，会理解连接后台；否则，连接请求会被挂起，等数据网络准备就绪后，自动去连接后台
		ntfy：socket状态的处理函数
		rcv：socket接收数据的处理函数
参数  ：
		sckidx：socket idx
		prot：string类型，传输层协议，仅支持"TCP"
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
返回值：无
]]
function connect(sckidx,prot,host,port)
	socket.connect(sckidx,prot,host,port,ntfy,rcv)
	tclients[getclient(sckidx)].sckconning=true
end



--创立元表时所用
local thttp = {}
thttp.__index = thttp


--[[
函数名：create
功能  ：创建一个http client
参数  ：
		prot：string类型，传输层协议，仅支持"TCP"
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
返回值：无
]]
function create(host,port)
	if #tclients>=4 then assert(false,"tclients maxcnt error") return end
	local http_client =
	{
		prot="TCP",
		--默认为"www.openluat.com"
		host=host or "36.7.87.100",
		--默认端口为80
		port=port or 81 ,		
		sckidx=socket.SCK_MAX_CNT-#tclients,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
		httpconnected=false,
		discing=false,
		status=false,
		rcvbody=nil,
		rcvhead={},
		result=nil,
		statuscode=nil,
		contentlen=nil
	}
	setmetatable(http_client,thttp)
	table.insert(tclients,http_client)
	return(http_client)
end



--[[
函数名：connect
功能  ：连接http服务器
参数  ：
        connectedcb:function类型，socket connected 成功回调函数	
		sckerrcb：function类型，socket连接失败的回调函数[可选]
返回值：无
]]
function thttp:connect(connectedcb,sckerrcb)
	self.connectedcb=connectedcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.httpconnected then print("thttp:connect already connected") return end
	if not self.sckconnected then
		--执行
		connect(self.sckidx,self.prot,self.host,self.port) 
    end
end


--[[
函数名：disconnect
功能  ：断开一个http client，并且断开socket
参数  ：
		discb：function类型，断开后的回调函数[可选]
返回值：无
]]
function thttp:disconnect(discb)
	print("thttp:disconnect")
	self.discb=discb
	self.discing = true
	socket.disconnect(self.sckidx,"USER")
end

--[[
函数名：destroy
功能  ：销毁一个http client
参数  ：
		destroycb：function类型，mqtt client销毁后的回调函数[可选]
返回值：无
]]
function thttp:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socket.close(v.sckidx)
		end
	end
end


--[[
函数名：seturl
功能：将所给的参数添加进表里
参数：url   一种通用标识符，描述获取资源的路径
返回值：
]]
function thttp:seturl(url) 
	url=url
	self.url=url
end
--[[
函数名:addhead
功能：添加首部
参数：name ,val  第一个参数是首部的名字，第二个参数是首部的值，首部的方法
返回值：
]]
function thttp:addhead(name,val)
	if not self.head then self.head = {} end
	self.head[name]=val
end

--[[
函数名：setbody
功能：添加实体
参数：body   实体内容
返回值：
]]
function thttp:setbody(body)
	self.body=body
end
 
--[[
函数名：request
功能：将报文数据整合，然后按照所给的命令发送
参数：cmdtyp  (发送报文的方法)
返回值：无
]]
function thttp:request(cmdtyp,rcvcb)
	self.cmdttyp=cmdtye
	self.rcvcb=rcvcb
	--默认url路径为根目录
    if	not	self.url	then
		self.url="/"
	end
	--默认首部为Connection: keep-alive
	if	not	self.head	then
		self.head={}
		self.head["Host"]="36.7.87.100"
		self.head["Connection"]="keep-alive"
	end
	--默认实体为空
	if 	not	self.body	then
		self.body=""
	end
	if	cmdtyp	then
		val=cmdtyp.." "..self.url.." HTTP/1.1"..'\r\n'
		for k,v in pairs(self.head) do
			val=val..k..": "..v..'\r\n'
		end
		if self.body then 
			val=val.."\r\n"..self.body
		end
	end 	
	snd(self.sckidx,val,cmdtyp)	
end

--[[
函数名：getstatus
功能  ：获取HTTP CLIENT的状态
参数  ：无
返回值：HTTP CLIENT的状态，string类型，共3种状态：
		DISCONNECTED：未连接状态
		CONNECTING：连接中状态
		CONNECTED：连接状态
]]
function thttp:getstatus()
	if self.httpconnected then
		return "CONNECTED"
	elseif self.sckconnected or self.sckconning then
		return "CONNECTING"
	elseif self.disconnect then
		return "DISCONNECTED"
	end
end

