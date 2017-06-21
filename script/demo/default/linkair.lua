--[[
模块名称：mqtt client应用处理模块
模块功能：连接服务器，发送登陆报文，定时上报多基站信息
模块最后修改时间：2017.03.30
]]

require"misc"
require"mqtt"
module(...,package.seeall)

local lpack = require"pack"
local ssub,schar,smatch,sbyte,slen,sgmatch,sgsub,srep = string.sub,string.char,string.match,string.byte,string.len,string.gmatch,string.gsub,string.rep

--是否支持gps
local gpsupport = false
--如果支持gps，则打开gps
if gpsupport then
	require"agps"
	require"gps"
	gps.init()
	gps.open(gps.DEFAULT,{cause="linkair"})
end

--服务器
local PROT,ADDR,PORT = "TCP","lbsmqtt.airm2m.com",1884
local mqttclient



--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上linkair前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("linkair",...)
end

--[[
函数名：pubqos0loginsndcb
功能  ：“发布1条qos为0的消息”(登陆报文)，发送结果的回调函数
参数  ：
		usertag：调用mqttclient:publish时传入的usertag
		result：true表示发送成功，false或者nil发送失败
返回值：无
]]
local function pubqos0loginsndcb(usertag,result)
	print("pubqos0loginsndcb",usertag,result)
	sys.timer_start(pubqos0login,20000)
end

function bcd(d,n)
	local l = slen(d or "")
	local num
	local t = {}

	for i=1,l,2 do
		num = tonumber(ssub(d,i,i+1),16)

		if i == l then
			num = 0xf0+num
		else
			num = (num%0x10)*0x10 + num/0x10
		end

		table.insert(t,num)
	end

	local s = schar(_G.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. srep("\255",n-l)
	elseif l > n then
		s = ssub(s,1,n)
	end

	return s
end

--[[
函数名：pubqos0login
功能  ：发布1条qos为0的消息，登陆报文
参数  ：无
返回值：无
]]
function pubqos0login()
	local payload = lpack.pack(">bbHHbHHbHAbHbbHAbHAbHA",
								14,
								0,2,22,
								1,2,300,
								2,2,bcd(sgsub(_G.VERSION,"%.",""),2),
								3,1,gpsupport and 1 or 0,
								4,slen(sim.geticcid()),sim.geticcid(),
								8,slen(_G.PROJECT),_G.PROJECT,
								13,slen(sim.getimsi()),sim.getimsi())
	mqttclient:publish("/v1/device/"..misc.getimei().."/devdata",payload,0,pubqos0loginsndcb)
end


--[[
函数名：pubqos0locsndcb
功能  ：“发布1条qos为0的消息”(位置报文)，发送结果的回调函数
参数  ：
		usertag：调用mqttclient:publish时传入的usertag
		result：true表示发送成功，false或者nil发送失败
返回值：无
]]
local function pubqos0locsndcb(usertag,result)
	print("pubqos0locsndcb",usertag,result)
	sys.timer_start(pubqos0loc,60000)
end

--[[
函数名：encellinfoext
功能  ：扩展基站定位信息封包处理
参数  ：无
返回值：扩展基基站定位信息封包字符串
]]
local function encellinfoext()
	local info,ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = net.getcellinfoext(),"",{}
	print("encellinfoext",info)
	for mcc,mnc,lac,ci,rssi in sgmatch(info,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
		mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
		local handle = nil
		for k,v in pairs(t) do
			if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
				if #v.rssici < 8 then
					table.insert(v.rssici,{rssi=rssi,ci=ci})
				end
				handle = true
				break
			end
		end
		if not handle then
			table.insert(t,{mcc=mcc,mnc=mnc,lac=lac,rssici={{rssi=rssi,ci=ci}}})
		end
	end
	for k,v in pairs(t) do
		ret = ret .. lpack.pack(">HHb",v.lac,v.mcc,v.mnc)
		for m,n in pairs(v.rssici) do
			cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
			ret = ret .. lpack.pack(">bH",cntrssi,n.ci)
		end
	end

	return schar(#t)..ret
end

local function getstatus()
	local t = {}

	t.shake = 0
	t.charger = 0
	t.acc = 0
	t.gps = gpsupport and 1 or 0
	t.sleep = 0
	t.volt = misc.getvbatvolt()
	t.fly = 0
	t.poweroff = 0
	t.poweroffreason = 0
	return t
end

local function getgps()
	local t = {}
	if gpsupport then
		print("getgps:",gps.getgpslocation(),gps.getgpscog(),gps.getgpsspd())
		t.fix = gps.isfix()
		t.lng,t.lat = smatch(gps.getgpslocation(),"[EW]*,(%d+%.%d+),[NS]*,(%d+%.%d+)")
		t.lng,t.lat = t.lng or "",t.lat or ""
		t.cog = gps.getgpscog()
		t.spd = gps.getgpsspd()
	end
	return t
end

local function getgpstat()
	local t = {}
	if gpsupport then
		t.satenum = gps.getgpssatenum()
	end
	return t
end

--[[
函数名：enstat
功能  ：基本状态信息封包处理
参数  ：无
返回值：基本状态信息封包字符串
]]
local function enstat()	
	local stat = getstatus()
	local rssi = net.getrssi()
	local gpstat = getgpstat()
	local satenum = gpstat.satenum or 0

	local n1 = stat.shake + stat.charger*2 + stat.acc*4 + stat.gps*8 + stat.sleep*16+stat.fly*32+stat.poweroff*64
	rssi = rssi > 31 and 31 or rssi
	satenum = satenum > 7 and 7 or satenum
	local n2 = rssi + satenum*32
	return lpack.pack(">bbH",n1,n2,stat.volt)
end

local function enlnla(v,s)
	if not v then return common.hexstobins("FFFFFFFFFF") end
	
	local v1,v2 = smatch(s,"(%d+)%.(%d+)")

	if slen(v1) < 3 then v1 = srep("0",3-slen(v1)) .. v1 end

	return bcd(v1..v2,5)
end

--[[
函数名：pubqos0loc
功能  ：发布1条qos为0的消息，位置报文
参数  ：无
返回值：无
]]
function pubqos0loc()
	local payload
	if gpsupport then
		local t = getgps()
		lng = enlnla(t.fix,t.lng)
		lat = enlnla(t.fix,t.lat)
		payload = lpack.pack(">bAAHbAbA",7,lng,lat,t.cog,t.spd,encellinfoext(),net.getta(),enstat())
	else
		payload = lpack.pack(">bAbA",5,encellinfoext(),net.getta(),enstat())
	end
	mqttclient:publish("/v1/device/"..misc.getimei().."/devdata",payload,0,pubqos0locsndcb)
end


--[[
函数名：subackcb
功能  ：MQTT SUBSCRIBE之后收到SUBACK的回调函数
参数  ：
		usertag：调用mqttclient:subscribe时传入的usertag
		result：true表示订阅成功，false或者nil表示失败
返回值：无
]]
local function subackcb(usertag,result)
	print("subackcb",usertag,result)
end

--[[
函数名：rcvmessage
功能  ：收到PUBLISH消息时的回调函数
参数  ：
		topic：消息主题
		payload：消息负载
		qos：消息质量等级
返回值：无
]]
local function rcvmessagecb(topic,payload,qos)
	print("rcvmessagecb",topic,common.binstohexs(payload),qos)
	if slen(payload)>2 and ssub(payload,1,2)==common.hexstobins("3C00") then
		sys.timer_stop(pubqos0login)
	end
end

--[[
函数名：connectedcb
功能  ：MQTT CONNECT成功回调函数
参数  ：无		
返回值：无
]]
local function connectedcb()
	print("connectedcb")
	--订阅主题
	mqttclient:subscribe({{topic="/v1/device/"..misc.getimei().."/set",qos=0}},subackcb,"subscribetest")
	--注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
	mqttclient:regevtcb({MESSAGE=rcvmessagecb})
	--发布一条qos为0的消息，登陆报文
	pubqos0login()
	--发布一条qos为1的消息，位置报文
	pubqos0loc()
end

--[[
函数名：connecterrcb
功能  ：MQTT CONNECT失败回调函数
参数  ：
		r：失败原因值
			1：Connection Refused: unacceptable protocol version
			2：Connection Refused: identifier rejected
			3：Connection Refused: server unavailable
			4：Connection Refused: bad user name or password
			5：Connection Refused: not authorized
返回值：无
]]
local function connecterrcb(r)
	print("connecterrcb",r)
end

--[[
函数名：imeirdy
功能  ：IMEI读取成功，成功后，才去创建mqtt client，连接服务器，因为用到了IMEI号
参数  ：无		
返回值：无
]]
local function imeirdy()
	--创建一个mqtt client
	mqttclient = mqtt.create(PROT,ADDR,PORT)
	--连接mqtt服务器
	mqttclient:connect(misc.getimei(),600,"user","password",connectedcb,connecterrcb)
end

local procer =
{
	IMEI_READY = imeirdy,
}
--注册消息的处理函数
sys.regapp(procer)
--设置30秒钟查询一个基站信息
net.setcengqueryperiod(30000)
