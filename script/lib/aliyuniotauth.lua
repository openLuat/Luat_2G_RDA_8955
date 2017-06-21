--定义模块,导入依赖库
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local sys  = require"sys"
local misc = require"misc"
local link = require"link"
local socket = require"socket"
local crypto = require"crypto"
module(...,package.seeall)


local ssub,schar,smatch,sbyte,slen,sfind = string.sub,string.char,string.match,string.byte,string.len,string.find
local tonumber = base.tonumber


--阿里云鉴权服务器
local SCK_IDX,PROT,ADDR,PORT = 3,"TCP","iot-auth.aliyun.com",80
--与阿里云鉴权服务器的socket连接状态
local linksta
--一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
--如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
--如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20
--reconncnt:当前连接周期内，已经重连的次数
--reconncyclecnt:连续多少个连接周期，都没有连接成功
--一旦连接成功，都会复位这两个标记
--conning:是否在尝试连接
local reconncnt,reconncyclecnt,conning = 0,0
--产品标识，产品密钥，设备名、设备密钥
local productkey,productsecret,devicename,devicesecret
--鉴权信息
local gauthinfo = 
{
	truststorepath = "/aliyuniot_publicKey.crt",
	otherinfopath = "/aliyuniot_otherInfo.info"
}
--全部获取，获取网络参数，获取证书参数
local ALL_SERVER_PARAM,NETWORK_SERVER_PARAM,CERT_SERVER_PARAM = 0,1,2
local gsvrpara
--从鉴权服务器收到的完整报文，报文体中的有效数据
local rcvbuf,rcvalidbody = "",""

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上aliyuniotauth前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("aliyuniotauth",...)
end

local function getdevice(s)
	if s=="name" then
		return devicename or misc.getimei()
	elseif s=="secret" then
		return devicesecret or misc.getsn()
	end
end

--[[
函数名：filexist
功能  ：判断文件是否存在
参数  ：
		path：文件路径
返回值：存在返回true，否则返回nil
]]
local function filexist(path)
	local f = io.open(path,"rb")
	if f then
		f:close()
		return true
	end
end

--[[
函数名：snd
功能  ：调用发送接口发送数据
参数  ：
        data：发送的数据，在发送结果事件处理函数ntfy中，会赋值到item.data中
		para：发送的参数，在发送结果事件处理函数ntfy中，会赋值到item.para中 
返回值：调用发送接口的结果（并不是数据发送是否成功的结果，数据发送是否成功的结果在ntfy中的SEND事件中通知），true为成功，其他为失败
]]
function snd(data,para)
	return socket.send(SCK_IDX,data,para)
end

--[[
函数名：makesign
功能  ：生成签名信息
参数  ：
		typ：参数类型
返回值：签名信息
]]
local function makesign(typ)
	local temp = ""
	if typ==NETWORK_SERVER_PARAM then
		temp = "resFlagip"
	elseif typ==CERT_SERVER_PARAM then
		temp = "resFlagcert"
	end
	local data = "deviceName"..getdevice("name").."productKey"..productkey.."protocolmqtt"..temp.."sdkVersion1.0.0signMethodHmacMD5"
	local signkey = productsecret..getdevice("secret")
	return crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
end

--[[
函数名：postsnd
功能  ：发送POST报文到鉴权服务器
参数  ：
		typ：参数类型
返回值：无
]]
local function postsnd(typ)
	local postbody = "/iot/auth?&sign="..makesign(typ).."&productKey="..productkey.."&deviceName="..getdevice("name").."&protocol=mqtt&sdkVersion=1.0.0&signMethod=HmacMD5"
	if typ==NETWORK_SERVER_PARAM then
		postbody = postbody.."&resFlag=ip"
	elseif typ==CERT_SERVER_PARAM then
		postbody = postbody.."&resFlag=cert"
	end
	local posthead = "POST "..postbody.." HTTP/1.1\r\n" .. "Host: "..ADDR.."\r\n\r\n"
	snd(posthead,"POSTSND")
	gsvrpara = typ
end

--[[
函数名：readauthinfo
功能  ：从文件中读取鉴权信息
参数  ：无
返回值：读成功返回true，否则返回nil
]]
local function readauthinfo()
	local f = io.open(gauthinfo.truststorepath,"rb")
	if not f then print("readauthinfo open truststorepath error") return end
	gauthinfo.pubkey = f:read("*a")
	if not gauthinfo.pubkey then f:close() print("readauthinfo read truststorepath error") return end	
	f:close()
	
	f = io.open(gauthinfo.otherinfopath,"rb")
	if not f then print("readauthinfo open otherinfopath error") return end
	local alldata = f:read("*a")
	if not alldata then f:close() print("readauthinfo read otherinfopath error") return end
	
	gauthinfo.pkVersion,gauthinfo.sign,gauthinfo.deviceId = smatch(alldata,"(%w+)\n(%w+)\n(%w+)")
	f:close()
	if not gauthinfo.pkVersion or not gauthinfo.sign or not gauthinfo.deviceId then		
		print("readauthinfo read otherinfopath parse error")
		return
	end
	gauthinfo.pkVersion = tonumber(gauthinfo.pkVersion)
	
	return true
end

--[[
函数名：writeauthinfo
功能  ：写鉴权信息到文件中
参数  ：无
返回值：写成功返回true，否则返回nil
]]
local function writeauthinfo()
	os.remove(gauthinfo.truststorepath)
	os.remove(gauthinfo.otherinfopath)
	
	local f = io.open(gauthinfo.truststorepath,"wb")
	if not f then print("writeauthinfo open truststorepath error") return end
	if not f:write(gauthinfo.pubkey) then f:close() print("writeauthinfo write truststorepath error") return end
	f:close()
	
	f = io.open(gauthinfo.otherinfopath,"wb")
	if not f then print("writeauthinfo open otherinfopath error") return end
	if not f:write(gauthinfo.pkVersion.."\n") then f:close() print("writeauthinfo write otherinfopath pkVersion error") return end
	if not f:write(gauthinfo.certsign.."\n") then f:close() print("writeauthinfo write otherinfopath certsign error") return end	
	if not f:write(gauthinfo.deviceId) then f:close() print("writeauthinfo write otherinfopath deviceId error") return end
	f:close()
	
	return true
end

--[[
函数名：verifycert
功能  ：验证证书的合法性
参数  ：
		typ：参数类型
返回值：合法返回true，否则返回nil
]]
local function verifycert(typ)
	local ptype = typ or gsvrpara
	local data,sign,signkey,pubkeyencode
	if ptype==ALL_SERVER_PARAM then
		pubkeyencode = crypto.base64_encode(gauthinfo.pubkey,slen(gauthinfo.pubkey))
		signkey = productsecret..getdevice("secret")
		data = "deviceId"..gauthinfo.deviceId.."pkVersion"..gauthinfo.pkVersion.."pubkey"..pubkeyencode.."servers"..gauthinfo.servers
		sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
		data = "deviceId"..gauthinfo.deviceId.."pkVersion"..gauthinfo.pkVersion.."pubkey"..pubkeyencode
		gauthinfo.certsign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	elseif ptype==CERT_SERVER_PARAM then
		pubkeyencode = crypto.base64_encode(gauthinfo.pubkey,slen(gauthinfo.pubkey))
		signkey = productsecret..getdevice("secret")
		data = "deviceId"..gauthinfo.deviceId.."pkVersion"..gauthinfo.pkVersion.."pubkey"..pubkeyencode
		sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	elseif ptype==NETWORK_SERVER_PARAM then
		signkey = productsecret..getdevice("secret")
		data = "deviceId"..gauthinfo.deviceId.."servers"..gauthinfo.servers
		sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	end
	
	if ptype==ALL_SERVER_PARAM and sign==gauthinfo.sign then
		if not writeauthinfo() then print("verifycert writeauthinfo error") return end
	end
	
	print("verifycert",ptype,sign==gauthinfo.sign,sign,gauthinfo.sign)
	return sign==gauthinfo.sign
end

--[[
函数名：parsedatasvr
功能  ：解析数据服务器参数(host、port、clientid，username)
参数  ：
返回值：成功返回true，否则返回nil
]]
local function parsedatasvr()
	local clientid = productkey..":"..gauthinfo.deviceId
	local temp = productkey..productsecret..gauthinfo.deviceId..getdevice("secret")
	local username = crypto.md5(temp,slen(temp))
	local host,port = smatch(gauthinfo.servers,"([%w%.]+):([%d|]+)")
	local ports = {}
	if port then
		local h,t,p = sfind(port,"(%d+)")
		while p do
			table.insert(ports,tonumber(p))
			port = ssub(port,t+1,-1)
			h,t,p = sfind(port,"(%d+)")
		end
	end
	
	print("parsedatasvr",host,#ports,clientid,username)
	if host and #ports>0 and clientid and username then
		sys.dispatch("ALIYUN_DATA_BGN",host,ports,clientid,username,productkey,getdevice("name"))
	end
	
	return host and #ports>0 and clientid and username
end

--[[
函数名：preproc
功能  ：鉴权预处理
参数  ：无
返回值：无
]]
function preproc()
	print("preproc",linksta)
	if linksta then
		if filexist(gauthinfo.truststorepath) and filexist(gauthinfo.otherinfopath) then
			if readauthinfo() then
				if verifycert(CERT_SERVER_PARAM) then
					postsnd(NETWORK_SERVER_PARAM)
					return
				end
			end
		end
		postsnd(ALL_SERVER_PARAM)
	end
end

--[[
函数名：sndcb
功能  ：数据发送结果处理
参数  ：          
		item：table类型，{data=,para=}，消息回传的参数和数据，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
		result： bool类型，发送结果，true为成功，其他为失败
返回值：无
]]
local function sndcb(item,result)
	print("sndcb",item.para,result)
	if not item.para then return end
	if item.para=="POSTSND" then
		sys.timer_start(reconn,RECONN_PERIOD*1000)
	end
end


--[[
函数名：reconn
功能  ：重连后台处理
        一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
        如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
        如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
参数  ：无
返回值：无
]]
function reconn()
	print("reconn",reconncnt,conning,reconncyclecnt)
	--conning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致reconncnt增加，实际的重连次数减少
	if conning then return end
	--一个连接周期内的重连
	if reconncnt < RECONN_MAX_CNT then		
		reconncnt = reconncnt+1
		link.shut()
		connect()
	--一个连接周期的重连都失败
	else
		reconncnt,reconncyclecnt = 0,reconncyclecnt+1
		if reconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			sys.restart("connect fail")
		end
		sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000)
	end
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		result： bool类型，消息事件结果，true为成功，其他为失败
		item：table类型，{data=,para=}，消息回传的参数和数据，目前只是在SEND类型的事件中用到了此参数，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
返回值：无
]]
function ntfy(idx,evt,result,item)
	print("ntfy",evt,result,item)
	--连接结果（调用socket.connect后的异步事件）
	if evt == "CONNECT" then
		conning = false
		--连接成功
		if result then
			reconncnt,reconncyclecnt,linksta,rcvbuf,rcvbody = 0,0,true,"",""
			--停止重连定时器
			sys.timer_stop(reconn)
			preproc()
		--连接失败
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000)
		end	
	--数据发送结果（调用socket.send后的异步事件）
	elseif evt == "SEND" then
		if item then
			sndcb(item,result)
		end
		--发送失败，RECONN_PERIOD秒后重连后台，不要调用reconn，此时socket状态仍然是CONNECTED，会导致一直连不上服务器
		--if not result then sys.timer_start(reconn,RECONN_PERIOD*1000) end
		if not result then link.shut() end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		linksta = false
		socket.close(SCK_IDX)
		--reconn()
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		linksta = false
		reconn()
	--连接主动断开（调用socket.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		linksta = false
		--reconn()
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((base.type(result)=="string") and result or "","ERROR") then
		--RECONN_PERIOD秒后重连，不要调用reconn，此时socket状态仍然是CONNECTED，会导致一直连不上服务器
		--sys.timer_start(reconn,RECONN_PERIOD*1000)
		link.shut()
	end
end

--[[
函数名：parsevalidbody
功能  ：解析鉴权服务器返回的有效报文体
参数  ：无
返回值：无
]]
local function parsevalidbody()
	print("parsevalidbody")
	local tjsondata = json.decode(rcvalidbody)
	print("deviceId",tjsondata["deviceId"])
	print("pkVersion",tjsondata["pkVersion"])
	print("pubkey",tjsondata["pubkey"])
	print("servers",tjsondata["servers"])
	print("sign",tjsondata["sign"])
	print("success",tjsondata["success"])
	if tjsondata["success"]~="true" and tjsondata["success"]~=true then print("parsevalidbody success err",tjsondata["success"]) return end
	if tjsondata["deviceId"] then gauthinfo.deviceId = tjsondata["deviceId"] end
	if tjsondata["pkVersion"] then gauthinfo.pkVersion = tonumber(tjsondata["pkVersion"]) end
	if tjsondata["pubkey"] then gauthinfo.pubkey = crypto.base64_decode(tjsondata["pubkey"],slen(tjsondata["pubkey"])) end
	if tjsondata["servers"] then gauthinfo.servers = tjsondata["servers"] end
	if tjsondata["sign"] then gauthinfo.sign = tjsondata["sign"] end
	--如果解析成功
	if verifycert() and parsedatasvr() then
		sys.timer_stop(reconn)
	end
end

--[[
函数名：parse
功能  ：解析鉴权服务器返回的数据
参数  ：无
返回值：无
]]
local function parse()
	local headend = sfind(rcvbuf,"\r\n\r\n")
	if not headend then print("parse wait head end") return end
	
	local headstr = ssub(rcvbuf,1,headend+3)
	if not smatch(headstr,"200 OK") then print("parse no 200 OK") return end
	
	local contentflg
	if smatch(headstr,"Transfer%-Encoding: chunked") or smatch(headstr,"Transfer%-Encoding: Chunked") then
		contentflg = "chunk"
	elseif smatch(headstr,"Content%-Length: %d+") then
		contentflg = tonumber(smatch(headstr,"Content-Length: (%d+)"))
	end
	if not contentflg then print("parse contentflg error") return end
	
	local rcvbody = ssub(rcvbuf,headend+4,-1)
	if contentflg=="chunk" then	
		rcvalidbody = ""
		if not smatch(rcvbody,"0\r\n\r\n") then print("parse wait chunk end") return end
		local h,t,len
		while true do
			h,t,len = sfind(rcvbody,"(%w+)\r\n")
			if len then
				len = tonumber(len,16)
				if len==0 then break end
				rcvalidbody = rcvalidbody..ssub(rcvbody,t+1,t+len)
				rcvbody = ssub(rcvbody,t+len+1,-1)
			else
				print("parse chunk len err ")
				return
			end
		end
	else
		if slen(rcvbody)~=contentflg then print("parse wait content len end") return end
		rcvalidbody = rcvbody
	end
	
	rcvbuf = ""
	parsevalidbody()
	socket.close(SCK_IDX)
end

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        idx ：socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
function rcv(idx,data)
	print("rcv",data)
	rcvbuf = rcvbuf..data
	parse()
end

--[[
函数名：connect
功能  ：创建到阿里云鉴权服务器的连接；
        如果数据网络已经准备好，会立即连接后台；否则，连接请求会被挂起，等数据网络准备就绪后，自动去连接后台
		ntfy：socket状态的处理函数
		rcv：socket接收数据的处理函数
参数  ：无
返回值：无
]]
function connect()
	socket.connect(SCK_IDX,PROT,ADDR,PORT,ntfy,rcv)
	conning = true
end

--[[
函数名：authbgn
功能  ：发起鉴权
参数  ：无
返回值：无
]]
local function authbgn(pkey,psecret,dname,dsecret)
	productkey,productsecret,devicename,devicesecret = pkey,psecret,dname,dsecret
	connect()
end

local procer =
{
	ALIYUN_AUTH_BGN = authbgn,
}

sys.regapp(procer)

