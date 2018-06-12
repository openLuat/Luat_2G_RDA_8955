module(...,package.seeall)

require"common"
require"socketssl"
require"utils"
local lpack=require"pack"

local sfind,slen,ssub,smatch,sgmatch= string.find,string.len,string.sub,string.match,string.gmatch
local PACKET_LEN = 1460
--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("https",...)
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
    return socketssl.send(sckidx,data,para)
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
	local hidx = getclient(sckidx)
	print("reconn",tclients[hidx].sckreconncnt,tclients[hidx].sckconning,tclients[hidx].sckreconncyclecnt)
	--sckconning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致sckreconncnt增加，实际的重连次数减少
	if tclients[hidx].sckconning then return end
	--一个连接周期内的重连
	if tclients[hidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[hidx].sckreconncnt = tclients[hidx].sckreconncnt+1
		socketssl.disconnect(sckidx,"RECONN")
		tclients[hidx].sckconning = true
	--一个连接周期的重连都失败
	else
		tclients[hidx].sckreconncnt,tclients[hidx].sckreconncyclecnt = 0,tclients[hidx].sckreconncyclecnt+1
		if tclients[hidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT or not tclients[hidx].mode then
			if tclients[hidx].sckerrcb then
				tclients[hidx].sckreconncnt=0
				tclients[hidx].sckreconncyclecnt=0
				tclients[hidx].sckerrcb("CONNECT")
			else
				sys.restart("connect fail")
			end
		else
			for k,v in pairs(tclients) do
				socketssl.disconnect(v.sckidx,"RECONN")
				v.sckconning = true
			end
			link.shut()
		end		
	end
end

local function connectitem(hidx)
	local item = tclients[hidx]
	connect(item.sckidx,item.prot,item.host,item.port,item.crtconfig)
end

--[[
函数名：getnxtsnd
功能  ：获取下次发送的数据信息
参数  ：
        hidx：number类型，http client idx
        sndidx：number类型，当前已经发送成功的数据索引，从0开始，0表示头，其余数值表示body
		sndpos：number类型，当前已经发送成功的数据索引对应的数据内容的位置
返回值：
		如果仍有数据需要发送，返回将要发送的数据内容，将要发送的数据索引，将要发送的数据索引对应的数据内容的位置
		如果没有数据需要发送，返回""
]]
local function getnxtsnd(hidx,sndidx,sndpos)
	local item,idx = tclients[hidx]
	
	if type(item.body[sndidx])=="string" then
		if sndpos>=slen(item.body[sndidx]) then
			idx = sndidx+1
		else
			return ssub(item.body[sndidx],sndpos+1,sndpos+PACKET_LEN),sndidx,sndpos+PACKET_LEN
		end
	elseif type(item.body[sndidx])=="table" then
		if sndpos>=item.body[sndidx].len then
			idx = sndidx+1
		else
			if item.body[sndidx].file_base64 then
				local mdat=io.filedata(item.body[sndidx].file_base64,sndpos/4*3,PACKET_LEN/4*3)
				mdat=crypto.base64_encode(mdat,#mdat)
				return mdat,sndidx,sndpos+PACKET_LEN
			end
			return io.filedata(item.body[sndidx].file,sndpos,PACKET_LEN),sndidx,sndpos+PACKET_LEN
		end
	end
	
	if type(item.body[idx])=="string" then
		return ssub(item.body[idx],1,PACKET_LEN),idx,PACKET_LEN		
	elseif type(item.body[idx])=="table" then
		if item.body[idx].file_base64 then
			local mdat=io.filedata(item.body[idx].file_base64,0,PACKET_LEN/4*3)
			mdat=crypto.base64_encode(mdat,#mdat)
			return mdat,idx,PACKET_LEN
		end
		return io.filedata(item.body[idx].file,0,PACKET_LEN),idx,PACKET_LEN
	end
	
	return ""
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket中维护的socket idx，跟调用socketssl.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		result： bool类型，消息事件结果，true为成功，其他为失败
		item：table类型，{data=,para=}，消息回传的参数和数据，目前只是在SEND类型的事件中用到了此参数，例如调用socketssl.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
返回值：无
]]
function ntfy(idx,evt,result,item)
	local hidx = getclient(idx)
	print("ntfy",evt,result,item)
	--连接结果（调用socketssl.connect后的异步事件）
	if evt == "CONNECT" then
		tclients[hidx].sckconning = false
		--连接成功
		if result then
			tclients[hidx].sckconnected=true
			tclients[hidx].sckreconncnt=0
			tclients[hidx].sckreconncyclecnt=0
			--停止重连定时器
			sys.timer_stop(reconn,idx)
			tclients[hidx].connectedcb()
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--数据发送结果（调用socketssl.send后的异步事件）
	elseif evt == "SEND" then
		if result then
			local sndata,sndIdx,sndPos = getnxtsnd(hidx,item.para.sndidx,item.para.sndpos)
			if sndata~="" then
				if not snd(idx,sndata,{sndidx=sndIdx,sndpos=sndPos}) then
					clrsndbody(hidx)
					if tclients[hidx].sckerrcb then tclients[hidx].sckerrcb("SEND") end
				end
			else
				sys.timer_start(timerfnc,30000,hidx)
			end
		else
			clrsndbody(hidx)
			if tclients[hidx].sckerrcb then
				tclients[hidx].sckreconncnt=0
				tclients[hidx].sckreconncyclecnt=0
				tclients[hidx].sckerrcb("SEND") 
			end
		end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].sckconning = false
		if tclients[hidx].rcvcb then tclients[hidx].rcvcb(tclients[hidx].contentlen==0x7FFFFFFF and 0 or 1,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].filepath or tclients[hidx].rcvbody) end
		sys.timer_stop(timerfnc,hidx)
		sys.timer_stop(reconn,idx)
		resetpara(hidx)
		--长连接时使用
		if tclients[hidx].mode then
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].sckconning = false
		sys.timer_stop(timerfnc,hidx)
		sys.timer_stop(reconn,idx)
		resetpara(hidx)
		--长连接时使用
		if tclients[hidx].mode then
			socketssl.disconnect(idx,"RECONN")
			tclients[hidx].sckconning = true
		end
	--连接主动断开（调用socketssl.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		tclients[hidx].sckconnected=false
		tclients[hidx].sckconning = false
		sys.timer_stop(timerfnc,hidx)
		sys.timer_stop(reconn,idx)
		resetpara(hidx)
		if item=="USER" then
			if tclients[hidx].discb then tclients[hidx].discb(idx) end
			tclients[hidx].discing = false
		end	
	--长连接时使用
		if tclients[hidx].mode or item=="RECONN" then
			connectitem(hidx)
		end
	--连接主动断开并且销毁（调用socketssl.close后的异步事件）
	elseif evt == "CLOSE" then
		tclients[hidx].sckconnected=false
		tclients[hidx].sckconning = false
		sys.timer_stop(timerfnc,hidx)
		sys.timer_stop(reconn,idx)
		resetpara(hidx)
		local cb = tclients[hidx].destroycb
		table.remove(tclients,hidx)
		if cb then cb() end
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((type(result)=="string") and result or "","ERROR") then
		socketssl.disconnect(idx)
	end
end

function resetpara(hidx,clrdata)
	tclients[hidx].statuscode=nil
	tclients[hidx].rcvhead=nil
	tclients[hidx].rcvbody,tclients[hidx].rcvLen=nil
	tclients[hidx].status=nil
	tclients[hidx].result=nil
	tclients[hidx].rcvChunked,tclients[hidx].chunkSize=nil
	tclients[hidx].filelen=nil
	if clrdata or clrdata==nil then tclients[hidx].rcvData="" end
end

--[[
函数名：timerfnc
功能  ：接收数据超时的定时器处理函数
参数  ：
        hidx：http client在tclients表中的索引	
返回值：无
]]
function timerfnc(hidx)
	if tclients[hidx].rcvcb then tclients[hidx].rcvcb(3,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].filepath or tclients[hidx].rcvbody) end
	resetpara(hidx)
end

--[[
函数名：rcv
功能  ：数据接收处理函数
参数  ：
        idx：http client对应的socket id	
        data：收到的数据
返回值：无
]]
function rcv(idx,data)
	local hidx = getclient(idx)
	--设置一个定时器，时间为30秒
	sys.timer_start(timerfnc,30000,hidx)
	
	if data and tclients[hidx].rcvcb then
		tclients[hidx].rcvData = (tclients[hidx].rcvData or "")..data
		local d1,d2,v1
		
		--状态行和头
		if not tclients[hidx].statuscode then
			d1,d2 = sfind(tclients[hidx].rcvData,"\r\n\r\n")
			if not(d1 and d2) then print("wait heads complete") return end
			
			local heads,k,v = ssub(tclients[hidx].rcvData,1,d2)
			tclients[hidx].statuscode = smatch(heads,"%s(%d+)%s")
			local _,crlf = sfind(heads,"\r\n")
			heads = ssub(heads,crlf+1,-1)
			if not tclients[hidx].rcvhead then tclients[hidx].rcvhead={} end
			for k,v in sgmatch(heads,"(.-):%s*(.-)\r\n") do
				tclients[hidx].rcvhead[k] = v
				if (k=="Transfer-Encoding") and (v=="chunked") then tclients[hidx].rcvChunked = true end
				
			end
			if not tclients[hidx].rcvChunked then
				tclients[hidx].contentlen = tonumber(smatch(heads,"Content%-Length:%s*(%d+)\r\n"),10) or 0x7FFFFFFF
			end
			tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,d2+1,-1)
		end
		
		--chunk编码传输(body)
		if tclients[hidx].rcvChunked then
			while true do
				if not tclients[hidx].chunkSize then
					d1,d2,v1 = sfind(tclients[hidx].rcvData,"(%x+)\r\n")
					--print(d1,d2,v1)
					if not v1 then print("wait chunk-size complete") return end
					tclients[hidx].chunkSize = tonumber(v1,16)
					tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,d2+1,-1)
				end
				
				print("chunk-size",tclients[hidx].chunkSize,slen(tclients[hidx].rcvData))
				
				if slen(tclients[hidx].rcvData)<tclients[hidx].chunkSize+2 then print("wait chunk-data complete") return end
				if tclients[hidx].chunkSize>0 then
					local chunkData = ssub(tclients[hidx].rcvData,1,tclients[hidx].chunkSize)
					if tclients[hidx].filepath then	
						local f = io.open(tclients[hidx].filepath,"a+")
						f:write(chunkData)
						f:close()
					else
						tclients[hidx].rcvbody = (tclients[hidx].rcvbody or "")..chunkData
					end
				end

				tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,tclients[hidx].chunkSize+3,-1)
				if tclients[hidx].chunkSize==0 then
					tclients[hidx].rcvcb(0,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].filepath or tclients[hidx].rcvbody)
					sys.timer_stop(timerfnc,hidx)
					resetpara(hidx,false)
				else
					tclients[hidx].chunkSize = nil
				end
			end
		--Content-Length(body)
		else
			local rmnLen = tclients[hidx].contentlen-(tclients[hidx].rcvLen or 0)
			local sData = ssub(tclients[hidx].rcvData,1,rmnLen)
			tclients[hidx].rcvLen = (tclients[hidx].rcvLen or 0)+slen(sData)
			
			if tclients[hidx].filepath then
				local f = io.open(tclients[hidx].filepath,"a+")
				f:write(sData)
				f:close()
			else
				tclients[hidx].rcvbody = (tclients[hidx].rcvbody or "")..sData
			end

			tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,rmnLen+1,-1)			
			if tclients[hidx].rcvLen==tclients[hidx].contentlen then
				tclients[hidx].rcvcb(0,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].filepath or tclients[hidx].rcvbody)
				sys.timer_stop(timerfnc,hidx)
				resetpara(hidx,false)
			end
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
		crtconfig：nil或者table类型，{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
返回值：无
]]
function connect(sckidx,prot,host,port,crtconfig)
	socketssl.connect(sckidx,prot,host,port,ntfy,rcv,crtconfig and crtconfig.verifysvrcerts,crtconfig)
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
	if #tclients>=3 then assert(false,"tclients maxcnt error") return end
	local http_client =
	{
		prot="TCP",
		host=host,
		port=port or 443,		
		sckidx=socketssl.SCK_MAX_CNT-#tclients-3,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
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
函数名：configcrt
功能  ：配置证书
参数  ：
		crtconfig：nil或者table类型，{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
返回值：成功返回true，失败返回nil
]]
function thttp:configcrt(crtconfig)
	self.crtconfig=crtconfig
	return true
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
	
	if self.sckconnected then print("thttp:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port,self.crtconfig) 
	end
end

--[[
函数名：setconnectionmode
功能  ：设置连接模式，长连接还是短链接
参数  ：
		v：true为长连接，false为短链接
返回值：无
]]
function thttp:setconnectionmode(v)
	self.mode=v
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
	socketssl.disconnect(self.sckidx,"USER")
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
			socketssl.close(v.sckidx)
		end
	end
end

function clrsndbody(hidx)	
	local i=0
	while tclients[hidx].body[i] do
		if type(tclients[hidx].body[i])=="table" then
			tclients[hidx].body[i] = nil
		end
		i = i+1
	end
	tclients[hidx].body=nil
end

local function getFileBase64Len(s)
	if s then return (io.filesize(s)+2)/3*4 end
 
end

--[[
函数名：request
功能  ：发送HTTP请求
参数  ：
        cmdtyp：string类型，HTTP的请求方法，"GET"、"POST"或者"HEAD"	
		url：string类型，HTTP请求行中的URL字段
		head：nil、""或者table类型，HTTP的请求头，lib中默认为自动添加Connection和Host请求头
			如果需要添加其他请求头，本参数传入table类型即可，格式为{"head1: value1","head2: value2",...}
        body：HTTP的请求实体,nil、""或者string类型或者table类型
			为table类型时，索引为number类型，从1开始，按照索引对应的内容，逐一进行发送，例如
			{
				[1]="begin",
				[2]={file="/ldata/post.jpg"},
				[3]="end"
			}
			先发送字符串begin，然后发送文件"/ldata/post.jpg"的内容，最后发送字符串end
			如果想对文件内容进行base64编码，请将file改成file_base64,例如：
			{
				[1]="begin",
				[2]={file_base64="/ldata/post.jpg"},
				[3]="end"
			}
		rcvcb：function类型，应答实体的数据回调函数
		filepath：string类型，应答实体的数据保存为文件的路径，例如"download.bin"，[可选]
返回值：如果传入了filepath，返回处理后的文件保存的完整路径；其余情况没有返回值
]]
function thttp:request(cmdtyp,url,head,body,rcvcb,filepath)
	local headstr="" 
	--默认传送方式为"GET"
	self.cmdtyp=cmdtyp or "GET"
	--默认为根目录
	self.url=url or "/"
	--默认实体为空
	self.head={}
	self.body=body or ""
	self.rcvcb=rcvcb
	
	--重构body参数
	if type(self.body)=="string" then
		--self.body = {len=slen(self.body), sndidx=1, sndpos=0, [1]=self.body}
		self.body = {[1]=self.body}
	end
	local bodylen,i = 0,1
	--计算body总长度
	while self.body[i] do
		if type(self.body[i])=="string" then
			bodylen = bodylen+slen(self.body[i])
		elseif type(self.body[i])=="table" then			
			self.body[i].len =getFileBase64Len(self.body[i].file_base64) or io.filesize(self.body[i].file)
			bodylen = bodylen+self.body[i].len
		else
			assert(false,"unsupport body type")
		end
		i = i+1
	end
	self.body.len = bodylen
	
	if filepath then
		self.filepath = (ssub(filepath,1,1)~="/" and "/" or "")..filepath
		if ssub(filepath,1,1)~="/" and rtos.make_dir and rtos.make_dir("/http_down") then self.filepath = "/http_down"..self.filepath end
	else
		self.filepath = nil
	end

	if not head or head=="" or (type(head)=="table" and #head==0) then
		self.head={"Connection: keep-alive", "Host: "..self.host}
		if cmdtyp=="POST" and self.body~="" and self.body~=nil then
			table.insert(self.head,"Content-Length: "..self.body.len)
		end
	elseif type(head)=="table" and #head>0 then
		local connhead,hosthead,conlen,k,v
		for k,v in pairs(head) do
			if sfind(v,"Connection: ")==1 then connhead = true end
			if sfind(v,"Host: ")==1 then hosthead = true end
			if sfind(v,"Content-Length: ")==1 then conlen = true end
			table.insert(self.head,v)
		end
		if not hosthead then table.insert(self.head,1,"Host: "..self.host) end
		if not connhead then table.insert(self.head,1,"Connection: keep-alive") end
		if not conlen and cmdtyp=="POST" and self.body~="" and self.body~=nil then 
			table.insert(self.head,1,"Content-Length: "..self.body.len) 
		end
	else
		assert(false,"head format error")
	end
	
	headstr=cmdtyp.." "..self.url.." HTTP/1.1"..'\r\n'
	for k,v in pairs(self.head) do
		headstr=headstr..v..'\r\n'
	end
	headstr = headstr.."\r\n"
	self.body[0] = headstr
	local sndata,sndpara = headstr,{sndidx=0,sndpos=utils.min(PACKET_LEN,slen(headstr))}
	if type(self.body[1])=="string" and ((slen(self.body[1])+slen(headstr))<=PACKET_LEN) then 
		sndata = headstr..self.body[1]
		sndpara = {sndidx=1,sndpos=utils.min(PACKET_LEN,slen(self.body[1]))}
	end		
	if not snd(self.sckidx,sndata,sndpara) then
		clrsndbody(getclient(self.sckidx))
		if self.sckerrcb then self.sckerrcb("SEND") end
	end
	if filepath then return self.filepath end
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
	if self.sckconnected then
		return "CONNECTED"
	elseif self.sckconning then
		return "CONNECTING"
	else
		return "DISCONNECTED"
	end
end

--[[
函数名：getrcvpercent
功能  ：获取接收到数据的百分比
参数  ：无
返回值：百分比，0到100
]]
function thttp:getrcvpercent()
	if not self.rcvChunked and self.rcvLen and self.rcvLen>0 and self.contentlen and self.contentlen>0 then
		return (100*self.rcvLen-(100*self.rcvLen%self.contentlen))/self.contentlen
	end
	return 0
end

