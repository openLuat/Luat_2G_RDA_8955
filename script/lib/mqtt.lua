--[[
模块名称：mqtt协议管理
模块功能：实现协议的组包和解包，请首先阅读http://public.dhe.ibm.com/software/dw/webservices/ws-mqtt/mqtt-v3r1.html了解mqtt协议
模块最后修改时间：2017.02.24
]]

--[[
目前只支持QoS=0和QoS=1，不支持QoS=2
]]

module(...,package.seeall)

local lpack = require"pack"
require"common"
require"socket"
require"mqttdup"

local slen,sbyte,ssub,sgsub,schar,srep,smatch,sgmatch = string.len,string.byte,string.sub,string.gsub,string.char,string.rep,string.match,string.gmatch
--报文类型
CONNECT,CONNACK,PUBLISH,PUBACK,PUBREC,PUBREL,PUBCOMP,SUBSCRIBE,SUBACK,UNSUBSCRIBE,UNSUBACK,PINGREQ,PINGRSP,DISCONNECT = 1,2,3,4,5,6,7,8,9,10,11,12,13,14

local CLEANSESS = 1

--报文序列号
local seq = 1

local function print(...)
	_G.print("mqtt",...)
end

local function encutf8(s)
	if not s then return "" end
	local utf8s = common.gb2312toutf8(s)
	return lpack.pack(">HA",slen(utf8s),utf8s)
end

local function enclen(s)
	if not s or slen(s) == 0 then return schar(0) end
	local ret,len,digit = "",slen(s)
	repeat
		digit = len % 128
		len = len / 128
		if len > 0 then
			digit = bit.bor(digit,0x80)
		end
		ret = ret..schar(digit)
	until (len <= 0)
	return ret
end

local function declen(s)
	local i,value,multiplier,digit = 1,0,1 
	repeat
		if i > slen(s) then return end
		digit = sbyte(s,i) 
		value = value + bit.band(digit,127)*multiplier
		multiplier = multiplier * 128
		i = i + 1
	until (bit.band(digit,128) == 0)
	return true,value,i-1
end

local function getseq()
	local s = seq
	seq = (seq+1)%0xFFFF
	if seq == 0 then seq = 1 end
	return lpack.pack(">H",s)
end

local function iscomplete(s)
	local i,typ,flg,len,cnt
	for i=1,slen(s) do
		typ = bit.band(bit.rshift(sbyte(s,i),4),0x0f)
		--print("typ",typ)
		if typ >= CONNECT and typ <= DISCONNECT then
			flg,len,cnt = declen(ssub(s,i+1,-1))
			--print("f",flg,len,cnt,(slen(ssub(s,i+1,-1))-cnt))
			if flg and cnt <= 4 and len <= (slen(ssub(s,i+1,-1))-cnt) then
				return true,i,i+cnt+len,typ,len
			else
				return
			end
		end		
	end
end

--[[
函数名：pack
功能  ：MQTT组包
参数  ：
		mqttver：mqtt协议版本号
		typ：报文类型
		...：可变参数
返回值：第一个返回值是报文数据，第二个返回值是每种报文自定义的参数
]]
local function pack(mqttver,typ,...)
	local para = {}
	local function connect(alive,id,twill,user,pwd)
		local ret = lpack.pack(">bAbbHA",
						CONNECT*16,
						encutf8(mqttver=="3.1.1" and "MQTT" or "MQIsdp"),
						mqttver=="3.1.1" and 4 or 3,
						(user and 1 or 0)*128+(pwd and 1 or 0)*64+twill.retain*32+twill.qos*8+twill.flg*4+CLEANSESS*2,
						alive,
						encutf8(id))
		if twill.flg==1 then
			ret = ret..encutf8(twill.topic)..encutf8(twill.payload)
		end
		ret = ret..encutf8(user)..encutf8(pwd)
		return ret
	end
	
	local function subscribe(p)
		para.dup,para.topic = true,p.topic
		para.seq = p.seq or getseq()
		print("subscribe",p.dup,para.dup,common.binstohexs(para.seq))
		
		local s = lpack.pack("bA",SUBSCRIBE*16+(p.dup and 1 or 0)*8+2,para.seq)
		for i=1,#p.topic do
			s = s..encutf8(p.topic[i].topic)..schar(p.topic[i].qos or 0)
		end
		return s
	end
	
	local function publish(p)
		para.dup,para.topic,para.payload,para.qos,para.retain = true,p.topic,p.payload,p.qos,p.retain
		para.seq = p.seq or getseq()
		--print("publish",p.dup,para.dup,common.binstohexs(para.seq))
		local s1 = lpack.pack("bAA",PUBLISH*16+(p.dup and 1 or 0)*8+(p.qos or 0)*2+(p.retain and 1 or 0)*1,encutf8(p.topic),((p.qos or 0)>0 and para.seq or ""))
		local s2 = s1..p.payload
		return s2
	end
	
	local function puback(seq)
		return schar(PUBACK*16)..seq
	end
	
	local function pingreq()
		return schar(PINGREQ*16)
	end
	
	local function disconnect()
		return schar(DISCONNECT*16)
	end
	
	local function unsubscribe(p)
		para.dup,para.topic = true,p.topic
		para.seq = p.seq or getseq()
		print("unsubscribe",p.dup,para.dup,common.binstohexs(para.seq))
		
		local s = lpack.pack("bA",UNSUBSCRIBE*16+(p.dup and 1 or 0)*8+2,para.seq)
		for i=1,#p.topic do
			s = s..encutf8(p.topic[i])
		end
		return s
	end

	local procer =
	{
		[CONNECT] = connect,
		[SUBSCRIBE] = subscribe,
		[PUBLISH] = publish,
		[PUBACK] = puback,
		[PINGREQ] = pingreq,
		[DISCONNECT] = disconnect,
		[UNSUBSCRIBE] = unsubscribe,
	}

	local s = procer[typ](...)
	local s1,s2,s3 = ssub(s,1,1),enclen(ssub(s,2,-1)),ssub(s,2,-1)
	s = s1..s2..s3
	print("pack",typ,(slen(s) > 200) and "" or common.binstohexs(s))
	return s,para
end

local rcvpacket = {}

--[[
函数名：unpack
功能  ：MQTT解包
参数  ：
		mqttver：mqtt协议版本号
		s：一条完整的报文
返回值：如果解包成功，返回一个table类型数据，数据元素由报文类型决定；如果解包失败，返回nil
]]
local function unpack(mqttver,s)
	rcvpacket = {}

	local function connack(d)
		print("connack",common.binstohexs(d))
		rcvpacket.suc = (sbyte(d,2)==0)
		rcvpacket.reason = sbyte(d,2)
		return true
	end
	
	local function suback(d)
		print("suback or unsuback",common.binstohexs(d))
		if slen(d) < 2 then return end
		rcvpacket.seq = ssub(d,1,2)
		return true
	end
	
	local function puback(d)
		print("puback",common.binstohexs(d))
		if slen(d) < 2 then return end
		rcvpacket.seq = ssub(d,1,2)
		return true
	end
	
	local function publish(d)
		print("publish",common.binstohexs(d)) --数据量太大时不能打开，内存不足
		if slen(d) < 4 then return end
		local _,tplen = lpack.unpack(ssub(d,1,2),">H")		
		local pay = (rcvpacket.qos > 0 and 5 or 3)
		if slen(d) < tplen+pay-1 then return end
		rcvpacket.topic = ssub(d,3,2+tplen)
		
		if rcvpacket.qos > 0 then
			rcvpacket.seq = ssub(d,tplen+3,tplen+4)
			pay = 5
		end
		rcvpacket.payload = ssub(d,tplen+pay,-1)
		return true
	end
	
	local function empty()
		return true
	end

	local procer =
	{
		[CONNACK] = connack,
		[SUBACK] = suback,
		[PUBACK] = puback,
		[PUBLISH] = publish,
		[PINGRSP] = empty,
		[UNSUBACK] = suback,
	}
	local d1,d2,d3,typ,len = iscomplete(s)	
	if not procer[typ] then print("unpack unknwon typ",typ) return end
	rcvpacket.typ = typ
	rcvpacket.qos = bit.rshift(bit.band(sbyte(s,1),0x06),1)
	rcvpacket.dup = bit.rshift(bit.band(sbyte(s,1),0x08),3)==1
	print("unpack",typ,rcvpacket.qos,(slen(s) > 200) and "" or common.binstohexs(s))
	return procer[typ](ssub(s,slen(s)-len+1,-1)) and rcvpacket or nil
end


--一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
--如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
--如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

--mqtt clients存储表
local tclients = {}

--[[
函数名：getclient
功能  ：返回一个mqtt client在tclients中的索引
参数  ：
		sckidx：mqtt client对应的socket索引
返回值：sckidx对应的mqtt client在tclients中的索引
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end

--[[
函数名：mqttconncb
功能  ：发送MQTT CONNECT报文后的异步回调函数
参数  ：		
		sckidx：socket idx
		result： bool类型，发送结果，true为成功，其他为失败
		tpara：table类型，{key="MQTTCONN",val=CONNECT报文数据}
返回值：无
]]
function mqttconncb(sckidx,result,tpara)
	--把MQTT CONNECT报文数据保存起来，如果超时DUP_TIME秒中没有收到CONNACK或者CONNACK返回失败，则会自动重发CONNECT报文
	--重发的触发开关在mqttdup.lua中
	mqttdup.ins(sckidx,tmqttpack["MQTTCONN"].mqttduptyp,tpara.val)
end

--[[
函数名：mqttconndata
功能  ：组包MQTT CONNECT报文数据
参数  ：
		sckidx：socket idx
返回值：CONNECT报文数据和报文参数
]]
function mqttconndata(sckidx)
	local mqttclientidx = getclient(sckidx)
	return pack(tclients[mqttclientidx].mqttver,
				CONNECT,
				tclients[mqttclientidx].keepalive,
				tclients[mqttclientidx].clientid,
				{
					flg=tclients[mqttclientidx].willflg or 0,
					qos=tclients[mqttclientidx].willqos or 0,
					retain=tclients[mqttclientidx].willretain or 0,
					topic=tclients[mqttclientidx].willtopic or "",
					payload=tclients[mqttclientidx].willpayload or "",
				},
				tclients[mqttclientidx].user,
				tclients[mqttclientidx].password)
end

--[[
函数名：mqttsubcb
功能  ：发送SUBSCRIBE报文后的异步回调函数
参数  ：		
		sckidx：socket idx
		result： bool类型，发送结果，true为成功，其他为失败
		tpara：table类型，{key="MQTTSUB", val=para, usertag=usertag, ackcb=ackcb}
返回值：无
]]
local function mqttsubcb(sckidx,result,tpara)	
	--重新封装MQTT SUBSCRIBE报文，重复标志设为true，序列号和topic都是用原始值，数据保存起来，如果超时DUP_TIME秒中没有收到SUBACK，则会自动重发SUBSCRIBE报文
	--重发的触发开关在mqttdup.lua中
	mqttdup.ins(sckidx,tpara.key,pack(tclients[getclient(sckidx)].mqttver,SUBSCRIBE,tpara.val),tpara.val.seq,tpara.ackcb,tpara.usertag)
end

--[[
函数名：mqttpubcb
功能  ：发送PUBLISH报文后的异步回调函数
参数  ：		
		sckidx：socket idx
		result： bool类型，发送结果，true为成功，其他为失败
		tpara：table类型，{key="MQTTPUB", val=para, qos=qos, usertag=usertag, ackcb=ackcb}
返回值：无
]]
local function mqttpubcb(sckidx,result,tpara)	
	if tpara.qos==0 then
		if tpara.ackcb then tpara.ackcb(tpara.usertag,result) end
	elseif tpara.qos==1 then
		--重新封装MQTT PUBLISH报文，重复标志设为true，序列号、topic、payload都是用原始值，数据保存起来，如果超时DUP_TIME秒中没有收到PUBACK，则会自动重发PUBLISH报文
		--重发的触发开关在mqttdup.lua中
		mqttdup.ins(sckidx,tpara.key,pack(tclients[getclient(sckidx)].mqttver,PUBLISH,tpara.val),tpara.val.seq,tpara.ackcb,tpara.usertag)
	end	
end

--[[
函数名：mqttdiscb
功能  ：发送MQTT DICONNECT报文后的异步回调函数
参数  ：		
		sckidx：socket idx
		result： bool类型，发送结果，true为成功，其他为失败
		tpara：table类型，{key="MQTTDISC", val=data, usertag=usrtag}
返回值：无
]]
function mqttdiscb(sckidx,result,tpara)
	--关闭socket连接
	tclients[getclient(sckidx)].discing = true
	socket.disconnect(sckidx,tpara.usertag)
end

--[[
函数名：mqttdiscdata
功能  ：组包MQTT DISCONNECT报文数据
参数  ：
		sckidx：socket idx
返回值：DISCONNECT报文数据和报文参数
]]
function mqttdiscdata(sckidx)
	return pack(tclients[getclient(sckidx)].mqttver,DISCONNECT)
end

--[[
函数名：disconnect
功能  ：发送MQTT DISCONNECT报文
参数  ：
		sckidx：socket idx
		usrtag：用户自定义标记
返回值：true表示发起了动作，nil表示没有发起
]]
local function disconnect(sckidx,usrtag)
	return mqttsnd(sckidx,"MQTTDISC",usrtag)
end

--[[
函数名：mqttpingreqdata
功能  ：组包MQTT PINGREQ报文数据
参数  ：
		sckidx：socket idx
返回值：PINGREQ报文数据和报文参数
]]
function mqttpingreqdata(sckidx)
	return pack(tclients[getclient(sckidx)].mqttver,PINGREQ)
end

--[[
函数名：pingreq
功能  ：发送MQTT PINGREQ报文
参数  ：
		sckidx：socket idx
返回值：无
]]
local function pingreq(sckidx)
	local mqttclientidx = getclient(sckidx)
	mqttsnd(sckidx,"MQTTPINGREQ")
	if not sys.timer_is_active(disconnect,sckidx) then
		--启动定时器：如果保活时间+30秒内，没有收到pingrsp，则发送MQTT DISCONNECT报文
		sys.timer_start(disconnect,(tclients[mqttclientidx].keepalive+30)*1000,sckidx)
	end
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

--mqtt应用报文表
tmqttpack =
{
	MQTTCONN = {sndpara="MQTTCONN",mqttyp=CONNECT,mqttduptyp="CONN",mqttdatafnc=mqttconndata,sndcb=mqttconncb},
	MQTTPINGREQ = {sndpara="MQTTPINGREQ",mqttyp=PINGREQ,mqttdatafnc=mqttpingreqdata},
	MQTTDISC = {sndpara="MQTTDISC",mqttyp=DISCONNECT,mqttdatafnc=mqttdiscdata,sndcb=mqttdiscb},
}

local function getidbysndpara(para)
	for k,v in pairs(tmqttpack) do
		if v.sndpara==para then return k end
	end
end

--[[
函数名：mqttsnd
功能  ：MQTT报文发送总接口，根据报文类型，在mqtt应用报文表中找到组包函数，然后发送数据
参数  ：
		sckidx：socket idx
        typ：报文类型
		usrtag：用户自定义标记
返回值：true表示发起了动作，nil表示没有发起
]]
function mqttsnd(sckidx,typ,usrtag)
	if not tmqttpack[typ] then print("mqttsnd typ error",typ) return end
	local mqttyp = tmqttpack[typ].mqttyp
	local dat,para = tmqttpack[typ].mqttdatafnc(sckidx)
	
	if mqttyp==CONNECT then
		if tmqttpack[typ].mqttduptyp then mqttdup.rmv(sckidx,tmqttpack[typ].mqttduptyp) end
		if not snd(sckidx,dat,{key=tmqttpack[typ].sndpara,val=dat}) and tmqttpack[typ].sndcb then
			tmqttpack[typ].sndcb(sckidx,false,{key=tmqttpack[typ].sndpara,val=dat})
		end
	elseif mqttyp==PINGREQ then
		snd(sckidx,dat,{key=tmqttpack[typ].sndpara})
	elseif mqttyp==DISCONNECT then
		if not snd(sckidx,dat,{key=tmqttpack[typ].sndpara}) and tmqttpack[typ].sndcb then
			tmqttpack[typ].sndcb(sckidx,false,{key=tmqttpack[typ].sndpara,usertag=usrtag})
		end		
	end	
	
	return true
end

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
local function reconn(sckidx)
	local mqttclientidx = getclient(sckidx)
	print("reconn",mqttclientidx,tclients[mqttclientidx].sckreconncnt,tclients[mqttclientidx].sckconning,tclients[mqttclientidx].sckreconncyclecnt)
	--sckconning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致sckreconncnt增加，实际的重连次数减少
	if tclients[mqttclientidx].sckconning then return end
	--一个连接周期内的重连
	if tclients[mqttclientidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[mqttclientidx].sckreconncnt = tclients[mqttclientidx].sckreconncnt+1
		link.shut()
		for k,v in pairs(tclients) do
			connect(v.sckidx,v.prot,v.host,v.port)
		end
		
	--一个连接周期的重连都失败
	else
		tclients[mqttclientidx].sckreconncnt,tclients[mqttclientidx].sckreconncyclecnt = 0,tclients[mqttclientidx].sckreconncyclecnt+1
		if tclients[mqttclientidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			if tclients[mqttclientidx].sckerrcb then
				tclients[mqttclientidx].sckreconncnt=0
				tclients[mqttclientidx].sckreconncyclecnt=0
				tclients[mqttclientidx].sckerrcb("CONNECT")
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
	local mqttclientidx = getclient(idx)
	print("ntfy",evt,result,item)
	--连接结果（调用socket.connect后的异步事件）
	if evt == "CONNECT" then
		tclients[mqttclientidx].sckconning = false
		--连接成功
		if result then
			tclients[mqttclientidx].sckconnected=true
			tclients[mqttclientidx].sckreconncnt=0
			tclients[mqttclientidx].sckreconncyclecnt=0
			tclients[mqttclientidx].sckrcvs=""
			--停止重连定时器
			sys.timer_stop(reconn,idx)
			--发送mqtt connect请求
			mqttsnd(idx,"MQTTCONN")
		--连接失败
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--数据发送结果（调用socket.send后的异步事件）
	elseif evt == "SEND" then
		if not result then
			link.shut()
		else
			if item.para then
				if item.para.key=="MQTTPUB" then
					mqttpubcb(idx,result,item.para)
				elseif item.para.key=="MQTTSUB" then
					mqttsubcb(idx,result,item.para)
				elseif item.para.key=="MQTTDUP" then
					mqttdupcb(idx,result,item.data)
				else
					local id = getidbysndpara(item.para.key)
					print("item.para",type(item.para) == "table",type(item.para) == "table" and item.para.typ or item.para,id)
					if id and tmqttpack[id].sndcb then tmqttpack[id].sndcb(idx,result,item.para) end
				end
			end
		end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		tclients[mqttclientidx].sckconnected=false
		tclients[mqttclientidx].mqttconnected=false
		tclients[mqttclientidx].sckrcvs=""
		if tclients[mqttclientidx].discing then
			if tclients[mqttclientidx].discb then tclients[mqttclientidx].discb() end
			tclients[mqttclientidx].discing = false
		else
			reconn(idx)
		end
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		tclients[mqttclientidx].sckconnected=false
		tclients[mqttclientidx].mqttconnected=false
		tclients[mqttclientidx].sckrcvs=""
		reconn(idx)
	--连接主动断开（调用socket.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		tclients[mqttclientidx].sckconnected=false
		tclients[mqttclientidx].mqttconnected=false
		tclients[mqttclientidx].sckrcvs=""
		if item=="USER" then
			if tclients[mqttclientidx].discb then tclients[mqttclientidx].discb() end
			tclients[mqttclientidx].discing = false
		else
			reconn(idx)
		end
	--连接主动断开并且销毁（调用socket.close后的异步事件）
	elseif evt == "CLOSE" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		local cb = tclients[mqttclientidx].destroycb
		table.remove(tclients,mqttclientidx)
		if cb then cb() end
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((type(result)=="string") and result or "","ERROR") then
		link.shut()
	end
end

--[[
函数名：connack
功能  ：处理服务器下发的MQTT CONNACK报文
参数  ：
        sckidx：socket idx
		packet：解析后的报文格式，table类型{suc=是否连接成功}
返回值：无
]]
local function connack(sckidx,packet)
	local mqttclientidx = getclient(sckidx)
	print("connack",packet.suc)
	if packet.suc then
		tclients[mqttclientidx].mqttconnected = true
		mqttdup.rmv(sckidx,tmqttpack["MQTTCONN"].mqttduptyp)
		if tclients[mqttclientidx].connectedcb then tclients[mqttclientidx].connectedcb() end
	else
		if tclients[mqttclientidx].connecterrcb then tclients[mqttclientidx].connecterrcb(packet.reason) end
	end
end

--[[
函数名：suback
功能  ：处理服务器下发的MQTT SUBACK报文
参数  ：
        sckidx：socket idx
		packet：解析后的报文格式，table类型{seq=对应的SUBSCRIBE报文序列号}
返回值：无
]]
local function suback(sckidx,packet)
	local mqttclientidx = getclient(sckidx)
	local typ,cb,cbtag = mqttdup.getyp(sckidx,packet.seq)
	print("suback",common.binstohexs(packet.seq))
	mqttdup.rmv(sckidx,nil,nil,packet.seq)
	if cb then cb(cbtag,true) end
end

--[[
函数名：puback
功能  ：处理服务器下发的MQTT PUBACK报文
参数  ：
        sckidx：socket idx
		packet：解析后的报文格式，table类型{seq=对应的PUBLISH报文序列号}
返回值：无
]]
local function puback(sckidx,packet)
	local mqttclientidx = getclient(sckidx)
	local typ,cb,cbtag = mqttdup.getyp(sckidx,packet.seq)
	print("puback",common.binstohexs(packet.seq),typ)
	mqttdup.rmv(sckidx,nil,nil,packet.seq)
	if cb then cb(cbtag,true) end
end

--[[
函数名：svrpublish
功能  ：处理服务器下发的MQTT PUBLISH报文
参数  ：
        sckidx：socket idx
		mqttpacket：解析后的报文格式，table类型{qos=,topic,seq,payload}
返回值：无
]]
local function svrpublish(sckidx,mqttpacket)
	local mqttclientidx = getclient(sckidx)
	print("svrpublish",mqttpacket.topic,mqttpacket.seq,mqttpacket.payload)	
	if mqttpacket.qos == 1 then snd(sckidx,pack(tclients[mqttclientidx].mqttver,PUBACK,mqttpacket.seq)) end
	if tclients[mqttclientidx].evtcbs then
		if tclients[mqttclientidx].evtcbs["MESSAGE"] then tclients[mqttclientidx].evtcbs["MESSAGE"](common.utf8togb2312(mqttpacket.topic),mqttpacket.payload,mqttpacket.qos) end
	end
end

--[[
函数名：pingrsp
功能  ：处理服务器下发的MQTT PINGRSP报文
参数  ：
		sckidx：socket idx
返回值：无
]]
local function pingrsp(sckidx)
	sys.timer_stop(disconnect,sckidx)
end

--服务器下发报文处理表
mqttcmds = {
	[CONNACK] = connack,
	[SUBACK] = suback,
	[PUBACK] = puback,
	[PUBLISH] = svrpublish,
	[PINGRSP] = pingrsp,
}

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
函数名：checkdatactive
功能  ：重新开始检测“数据通信是否异常”
参数  ：
		sckidx：socket idx
返回值：无
]]
local function checkdatactive(sckidx)
	local mqttclientidx = getclient(sckidx)
	sys.timer_start(datinactive,tclients[mqttclientidx].keepalive*1000*3+30000,sckidx) --3倍保活时间+半分钟
end

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        idx ：socket中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
function rcv(idx,data)
	local mqttclientidx = getclient(idx)
	print("rcv",slen(data)>200 and slen(data) or common.binstohexs(data))
	sys.timer_start(pingreq,tclients[mqttclientidx].keepalive*1000/2,idx)	
	tclients[mqttclientidx].sckrcvs = tclients[mqttclientidx].sckrcvs..data

	local f,h,t = iscomplete(tclients[mqttclientidx].sckrcvs)

	while f do
		data = ssub(tclients[mqttclientidx].sckrcvs,h,t)
		tclients[mqttclientidx].sckrcvs = ssub(tclients[mqttclientidx].sckrcvs,t+1,-1)
		local packet = unpack(tclients[mqttclientidx].mqttver,data)
		if packet and packet.typ and mqttcmds[packet.typ] then
			mqttcmds[packet.typ](idx,packet)
			if packet.typ ~= CONNACK and packet.typ ~= SUBACK then
				checkdatactive(idx)
			end
		end
		f,h,t = iscomplete(tclients[mqttclientidx].sckrcvs)
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
		prot：string类型，传输层协议，仅支持"TCP"和"UDP"[必选]
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
返回值：无
]]
function connect(sckidx,prot,host,port)
	socket.connect(sckidx,prot,host,port,ntfy,rcv)
	tclients[getclient(sckidx)].sckconning=true
end

--[[
函数名：mqttdupcb
功能  ：mqttdup中触发的重发报文发送后的异步回调
参数  ：
		sckidx：socket idx
		result： bool类型，发送结果，true为成功，其他为失败
		v：报文数据
返回值：无
]]
function mqttdupcb(sckidx,result,v)
	mqttdup.rsm(sckidx,v)
end

--[[
函数名：mqttdupind
功能  ：mqttdup中触发的重发报文处理
参数  ：
		sckidx：socket idx
		s：报文数据
返回值：无
]]
local function mqttdupind(sckidx,s)
	if not snd(sckidx,s,{key="MQTTDUP"}) then mqttdupcb(sckidx,false,s) end
end

--[[
函数名：mqttdupfail
功能  ：mqttdup中触发的重发报文，在最大重发次数内，都发送失败的通知消息处理
参数  ：
		sckidx：socket idx
		t：报文的用户自定义类型
		s：报文数据
		cb：用户回调函数
		cbtag：用户回调函数的第一个参数
返回值：无
]]
local function mqttdupfail(sckidx,t,s,cb,cbtag)
    print("mqttdupfail",t)
	if cb then cb(cbtag,false) end
end

--mqttdup重发消息处理函数表
local procer =
{
	MQTT_DUP_IND = mqttdupind,
	MQTT_DUP_FAIL = mqttdupfail,
}
--注册消息的处理函数
sys.regapp(procer)


local tmqtt = {}
tmqtt.__index = tmqtt


--[[
函数名：create
功能  ：创建一个mqtt client
参数  ：
		prot：string类型，传输层协议，仅支持"TCP"和"UDP"[必选]
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
		ver：string类型，MQTT协议版本号，仅支持"3.1"和"3.1.1"，默认"3.1"
返回值：无
]]
function create(prot,host,port,ver)
	if #tclients>=2 then assert(false,"tclients maxcnt error") return end
	local mqtt_client =
	{
		prot=prot,
		host=host,
		port=port,		
		sckidx=socket.SCK_MAX_CNT-#tclients,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
		sckrcvs="",
		mqttconnected=false,
		mqttver = ver or "3.1",
	}
	setmetatable(mqtt_client,tmqtt)
	table.insert(tclients,mqtt_client)
	return(mqtt_client)
end

--[[
函数名：change
功能  ：改变一个mqtt client的socket参数
参数  ：
		prot：string类型，传输层协议，仅支持"TCP"和"UDP"[必选]
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
返回值：无
]]
function tmqtt:change(prot,host,port)
	self.prot,self.host,self.port=prot or self.prot,host or self.host,port or self.port
end

--[[
函数名：destroy
功能  ：销毁一个mqtt client
参数  ：
		destroycb：function类型，mqtt client销毁后的回调函数[可选]
返回值：无
]]
function tmqtt:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socket.close(v.sckidx)
		end
	end
end

--[[
函数名：disconnect
功能  ：断开一个mqtt client，并且断开socket
参数  ：
		discb：function类型，断开后的回调函数[可选]
返回值：无
]]
function tmqtt:disconnect(discb)
	self.discb = discb
	if not disconnect(self.sckidx,"USER") and discb then discb() end
end

--[[
函数名：configwill
功能  ：配置遗嘱参数
参数  ：
		flg：number类型，遗嘱标志，仅支持0和1
		qos：number类型，服务器端发布遗嘱消息的服务质量等级，仅支持0,1,2
		retain：number类型，遗嘱保留标志，仅支持0和1
		topic：string类型，服务器端发布遗嘱消息的主题，gb2312编码	
		payload：string类型，服务器端发布遗嘱消息的载荷，gb2312编码
返回值：无
]]
function tmqtt:configwill(flg,qos,retain,topic,payload)
	self.willflg=flg or 0
	self.willqos=qos or 0
	self.willretain=retain or 0
	self.willtopic=topic or ""
	self.willpayload=payload or ""
end

--[[
函数名：connect
功能  ：连接mqtt服务器
参数  ：
		clientid：string类型，client identifier，gb2312编码[必选]
		keepalive：number类型，保活时间，单位秒[可选，默认600]
		user：string类型，用户名，gb2312编码[可选，默认""]
		password：string类型，密码，gb2312编码[可选，默认""]		
		connectedcb：function类型，mqtt连接成功的回调函数[可选]
		connecterrcb：function类型，mqtt连接失败的回调函数[可选]
		sckerrcb：function类型，socket连接失败的回调函数[可选]
返回值：无
]]
function tmqtt:connect(clientid,keepalive,user,password,connectedcb,connecterrcb,sckerrcb)
	self.clientid=clientid
	self.keepalive=keepalive or 600
	self.user=user or ""
	self.password=password or ""
	--if autoreconnect==nil then autoreconnect=true end
	--self.autoreconnect=autoreconnect
	self.connectedcb=connectedcb
	self.connecterrcb=connecterrcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.mqttconnected then print("tmqtt:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port)
		checkdatactive(self.sckidx)
	elseif not self.mqttconnected then
		mqttsnd(self.sckidx,"MQTTCONN")
	else
		if connectedcb then connectedcb() end
	end
end

--[[
函数名：publish
功能  ：发布一条消息
参数  ：
		topic：string类型，消息主题，gb2312编码[必选]
		payload：二进制数据，消息负载，用户自定义编码，本文件不会对数据做任何编码转换处理[必选]
		qos：number类型，服务质量等级，仅支持0和1[可选，默认0]		
		ackcb：function类型，qos为1时表示收到PUBACK的回调函数,qos为0时消息发送结果的回调函数[可选]
		usertag：string类型，用户回调函数ackcb用到的第一个参数[可选]
返回值：无
]]
function tmqtt:publish(topic,payload,qos,ackcb,usertag)
	--检查mqtt连接状态
	if not self.mqttconnected then
		print("tmqtt:publish not connected")
		if ackcb then ackcb(usertag,false) end
		return
	end
	
	--仅支持qos 0和1
	if qos and qos~=0 and qos~=1 then assert(false,"tmqtt:publish not support qos 2") return end
	--打包publish报文
	local dat,para = pack(self.mqttver,PUBLISH,{qos=qos or 0,topic=topic,payload=payload})
	
	--发送
	local tpara = {key="MQTTPUB", val=para, qos=qos or 0, usertag=usertag, ackcb=ackcb}
	if not snd(self.sckidx,dat,tpara) then
		mqttpubcb(self.sckidx,false,tpara)
	end
end

--[[
函数名：subscribe
功能  ：订阅主题
参数  ：
		topics：table类型，一个或者多个主题，主题名gb2312编码，质量等级仅支持0和1，{{topic="/topic1",qos=质量等级}, {topic="/topic2",qos=质量等级}, ...}[必选]
		ackcb：function类型，表示收到SUBACK的回调函数[可选]
		usertag：string类型，用户回调函数ackcb用到的第一个参数[可选]
返回值：无
]]
function tmqtt:subscribe(topics,ackcb,usertag)
	--检查mqtt连接状态
	if not self.mqttconnected then
		print("tmqtt:subscribe not connected")
		if ackcb then ackcb(usertag,false) end
		return
	end
	
	--仅支持qos 0和1
	for k,v in pairs(topics) do
		if v.qos==2 then assert(false,"tmqtt:publish not support qos 2") return end
	end

	--打包subscribe报文
	local dat,para = pack(self.mqttver,SUBSCRIBE,{topic=topics})
	
	--发送
	local tpara = {key="MQTTSUB", val=para, usertag=usertag, ackcb=ackcb}
	if not snd(self.sckidx,dat,tpara) then
		mqttsubcb(self.sckidx,false,tpara)
	end
end

--[[
函数名：regevtcb
功能  ：注册事件的回调函数
参数  ：
		evtcbs：一对或者多对evt和cb，格式为{evt=cb,...}}，evt取值如下：
				"MESSAGE"：表示从服务器收到消息，调用cb时，格式为cb(topic,payload,qos)
返回值：无
]]
function tmqtt:regevtcb(evtcbs)
	self.evtcbs=evtcbs	
end

--[[
函数名：getstatus
功能  ：获取MQTT CLIENT的状态
参数  ：无
返回值：MQTT CLIENT的状态，string类型，共4种状态：
		DISCONNECTED：未连接状态
		CONNECTING：连接中状态
		CONNECTED：连接状态
		DISCONNECTING：断开连接中状态
]]
function tmqtt:getstatus()
	if self.mqttconnected then
		return self.discing and "DISCONNECTING" or "CONNECTED"
	elseif self.sckconnected or self.sckconning then
		return "CONNECTING"
	else
		return "DISCONNECTED"
	end
end
