--[[
模块名称：网络管理
模块功能：信号查询、GSM网络状态查询、网络指示灯控制、临近小区信息查询
模块最后修改时间：2017.02.17
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local sys = require "sys"
local ril = require "ril"
local pio = require"pio"
local sim = require "sim"
module("net")

--加载常用的全局函数至本地
local dispatch = sys.dispatch
local req = ril.request
local smatch,ssub = string.match,string.sub
local tonumber,tostring,print = base.tonumber,base.tostring,base.print
--GSM网络状态：
--INIT：开机初始化中的状态
--REGISTERED：注册上GSM网络
--UNREGISTER：未注册上GSM网络
local state = "INIT"
--SIM卡状态：true为异常，false或者nil为正常
local simerrsta

--lac：位置区ID
--ci：小区ID
--rssi：信号强度
local lac,ci,rssi = "","",0

--csqqrypriod：信号强度定时查询间隔
--cengqrypriod：当前和临近小区信息定时查询间隔
local csqqrypriod,cengqrypriod = 60*1000

--cellinfo：当前小区和临近小区信息表
--flymode：是否处于飞行模式
--csqswitch：定时查询信号强度开关
--cengswitch：定时查询当前和临近小区信息开关
--multicellcb：获取多小区的回调函数
local cellinfo,flymode,csqswitch,cengswitch,multicellcb = {}

--ledstate：网络指示灯状态INIT,FLYMODE,SIMERR,IDLE,CREG,CGATT,SCK
--INIT：功能关闭状态
--FLYMODE：飞行模式
--SIMERR：未检测到SIM卡或者SIM卡锁pin码等异常
--IDLE：未注册GSM网络
--CREG：已注册GSM网络
--CGATT：已附着GPRS数据网络
--SCK：用户socket已连接上后台
--ledontime：指示灯点亮时长(毫秒)
--ledofftime：指示灯熄灭时长(毫秒)
--usersckconnect：用户socket是否连接上后台
--userscksslconnect：用户socket是否连接上后台
local ledstate,ledontime,ledofftime,usersckconnect,userscksslconnect = "INIT",0,0
--ledflg：网络指示灯开关
--ledpin：网络指示灯控制引脚
--ledvalid：引脚输出何种电平会点亮指示灯，1为高，0为低
--ledidleon,ledidleoff,ledcregon,ledcregoff,ledcgatton,ledcgattoff,ledsckon,ledsckoff：IDLE,CREG,CGATT,SCK状态下指示灯的点亮和熄灭时长(毫秒)
local ledflg,ledpin,ledvalid,ledflymodeon,ledflymodeoff,ledsimerron,ledsimerroff,ledidleon,ledidleoff,ledcregon,ledcregoff,ledcgatton,ledcgattoff,ledsckon,ledsckoff = false,((base.MODULE_TYPE=="Air800" or base.MODULE_TYPE=="Air801") and pio.P0_28 or pio.P1_1),1,0,0xFFFF,300,5700,300,3700,300,1700,300,700,100,100

--[[
函数名：creg
功能  ：解析CREG信息
参数  ：
		data：CREG信息字符串，例如+CREG: 2、+CREG: 1,"18be","93e1"、+CREG: 5,"18a7","cb51"
返回值：无
]]
local function creg(data)
	local p1,s
	--获取注册状态
	_,_,p1 = string.find(data,"%d,(%d)")
	if p1 == nil then
		_,_,p1 = string.find(data,"(%d)")
		if p1 == nil then
			return
		end
	end

	--已注册
	if p1 == "1" or p1 == "5" then
		s = "REGISTERED"		
	--未注册
	else
		s = "UNREGISTER"
	end
	--注册状态发生了改变
	if s ~= state then
		--临近小区查询处理
		if not cengqrypriod and s == "REGISTERED" then
			setcengqueryperiod(60000)
		else
			cengquery()
		end
		state = s
		--产生一个内部消息NET_STATE_CHANGED，表示GSM网络注册状态发生变化
		dispatch("NET_STATE_CHANGED",s)
		--指示灯控制
		procled()
	end
	--已注册并且lac或ci发生了变化
	if state == "REGISTERED" then
		p2,p3 = string.match(data,"\"(%x+)\",\"(%x+)\"")
		if lac ~= p2 or ci ~= p3 then
			lac = p2
			ci = p3
			--产生一个内部消息NET_CELL_CHANGED，表示lac或ci发生了变化
			dispatch("NET_CELL_CHANGED")
		end
	end
end

--[[
函数名：resetcellinfo
功能  ：重置当前小区和临近小区信息表
参数  ：无
返回值：无
]]
local function resetcellinfo()
	local i
	cellinfo.cnt = 11 --最大个数
	for i=1,cellinfo.cnt do
		cellinfo[i] = {}
		cellinfo[i].mcc,cellinfo[i].mnc = nil
		cellinfo[i].lac = 0
		cellinfo[i].ci = 0
		cellinfo[i].rssi = 0
		cellinfo[i].ta = 0
	end
end

--[[
函数名：ceng
功能  ：解析当前小区和临近小区信息
参数  ：
		data：当前小区和临近小区信息字符串，例如下面中的每一行：
		+CENG:1,1
		+CENG:0,"573,24,99,460,0,13,49234,10,0,6311,255"
		+CENG:1,"579,16,460,0,5,49233,6311"
		+CENG:2,"568,14,460,0,26,0,6311"
		+CENG:3,"584,13,460,0,10,0,6213"
		+CENG:4,"582,13,460,0,51,50146,6213"
		+CENG:5,"11,26,460,0,3,52049,6311"
		+CENG:6,"29,26,460,0,32,0,6311"
返回值：无
]]
local function ceng(data)
	--只处理有效的CENG信息
	if string.find(data,"%+CENG:%d+,\".+\"") then
		local id,rssi,lac,ci,ta,mcc,mnc
		id = string.match(data,"%+CENG:(%d)")
		id = tonumber(id)
		--第一条CENG信息和其余的格式不同
		if id == 0 then
			rssi,mcc,mnc,ci,lac,ta = string.match(data, "%+CENG:%d,\"%d+,(%d+),%d+,(%d+),(%d+),%d+,(%d+),%d+,%d+,(%d+),(%d+)\"")
		else
			rssi,mcc,mnc,ci,lac,ta = string.match(data, "%+CENG:%d,\"%d+,(%d+),(%d+),(%d+),%d+,(%d+),(%d+)\"")
		end
		--解析正确
		if rssi and ci and lac and mcc and mnc then
			--如果是第一条，清除信息表
			if id == 0 then
				resetcellinfo()
			end
			--保存mcc、mnc、lac、ci、rssi、ta
			cellinfo[id+1].mcc = mcc
			cellinfo[id+1].mnc = mnc
			cellinfo[id+1].lac = tonumber(lac)
			cellinfo[id+1].ci = tonumber(ci)
			cellinfo[id+1].rssi = (tonumber(rssi) == 99) and 0 or tonumber(rssi)
			cellinfo[id+1].ta = tonumber(ta or "0")
			--产生一个内部消息CELL_INFO_IND，表示读取到了新的当前小区和临近小区信息
			if id == 0 then
				dispatch("CELL_INFO_IND",cellinfo)
			end
		end
	end
end

--[[
函数名：neturc
功能  ：本功能模块内“注册的底层core通过虚拟串口主动上报的通知”的处理
参数  ：
		data：通知的完整字符串信息
		prefix：通知的前缀
返回值：无
]]
local function neturc(data,prefix)
	if prefix == "+CREG" then
		--收到网络状态变化时,更新一下信号值
		csqquery()
		--解析creg信息
		creg(data)
	elseif prefix == "+CENG" then
		--解析ceng信息
		ceng(data)
	end
end

--[[
函数名：getstate
功能  ：获取GSM网络注册状态
参数  ：无
返回值：GSM网络注册状态(INIT、REGISTERED、UNREGISTER)
]]
function getstate()
	return state
end

--[[
函数名：getmcc
功能  ：获取当前小区的mcc
参数  ：无
返回值：当前小区的mcc，如果还没有注册GSM网络，则返回sim卡的mcc
]]
function getmcc()
	return cellinfo[1].mcc or sim.getmcc()
end

--[[
函数名：getmnc
功能  ：获取当前小区的mnc
参数  ：无
返回值：当前小区的mnc，如果还没有注册GSM网络，则返回sim卡的mnc
]]
function getmnc()
	return cellinfo[1].mnc or sim.getmnc()
end

--[[
函数名：getlac
功能  ：获取当前位置区ID
参数  ：无
返回值：当前位置区ID(16进制字符串，例如"18be")，如果还没有注册GSM网络，则返回""
]]
function getlac()
	return lac
end

--[[
函数名：getci
功能  ：获取当前小区ID
参数  ：无
返回值：当前小区ID(16进制字符串，例如"93e1")，如果还没有注册GSM网络，则返回""
]]
function getci()
	return ci
end

--[[
函数名：getrssi
功能  ：获取信号强度
参数  ：无
返回值：当前信号强度(取值范围0-31)
]]
function getrssi()
	return rssi
end

--[[
函数名：getcell
功能  ：获取当前和临近小区以及信号强度的拼接字符串
参数  ：无
返回值：当前和临近小区以及信号强度的拼接字符串，例如：49234.30.49233.23.49232.18.
]]
function getcell()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].ci.."."..cellinfo[i].rssi.."."
		end
	end
	return ret
end

--[[
函数名：getcellinfo
功能  ：获取当前和临近位置区、小区以及信号强度的拼接字符串
参数  ：无
返回值：当前和临近位置区、小区以及信号强度的拼接字符串，例如：6311.49234.30;6311.49233.23;6322.49232.18;
]]
function getcellinfo()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].lac.."."..cellinfo[i].ci.."."..cellinfo[i].rssi..";"
		end
	end
	return ret
end

--[[
函数名：getcellinfoext
功能  ：获取当前和临近位置区、小区、mcc、mnc、以及信号强度的拼接字符串
参数  ：无
返回值：当前和临近位置区、小区、mcc、mnc、以及信号强度的拼接字符串，例如：460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;
]]
function getcellinfoext()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].mcc and cellinfo[i].mnc and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].mcc.."."..cellinfo[i].mnc.."."..cellinfo[i].lac.."."..cellinfo[i].ci.."."..cellinfo[i].rssi..";"
		end
	end
	return ret
end

--[[
函数名：getta
功能  ：获取TA值
参数  ：无
返回值：TA值
]]
function getta()
	return cellinfo[1].ta
end

--[[
函数名：startquerytimer
功能  ：空函数，无功能，只是为了兼容之前写的应用脚本
参数  ：无
返回值：无
]]
function startquerytimer() end

--[[
函数名：simind
功能  ：内部消息SIM_IND的处理函数
参数  ：
		para：参数，表示SIM卡状态
返回值：无
]]
local function simind(para)
	print("simind",simerrsta,para)
	if simerrsta ~= (para~="RDY") then
		simerrsta = (para~="RDY")
		procled()
	end
	--sim卡工作不正常
	if para ~= "RDY" then
		--更新GSM网络状态
		state = "UNREGISTER"
		--产生内部消息NET_STATE_CHANGED，表示网络状态发生变化
		dispatch("NET_STATE_CHANGED",state)
	end
	return true
end

--[[
函数名：flyind
功能  ：内部消息FLYMODE_IND的处理函数
参数  ：
		para：参数，表示飞行模式状态，true表示进入飞行模式，false表示退出飞行模式
返回值：无
]]
local function flyind(para)
	--飞行模式状态发生变化
	if flymode~=para then
		flymode = para
		--控制网络指示灯
		procled()
	end
	--退出飞行模式
	if not para then
		----处理查询定时器
		startcsqtimer()
		startcengtimer()
		--复位GSM网络状态
		neturc("2","+CREG")
	end
	return true
end

--[[
函数名：workmodeind
功能  ：内部消息SYS_WORKMODE_IND的处理函数
参数  ：
		para：参数，表示系统工作模式
返回值：无
]]
local function workmodeind(para)
	--处理查询定时器
	startcengtimer()
	startcsqtimer()
	return true
end

--[[
函数名：startcsqtimer
功能  ：有选择性的启动“信号强度查询”定时器
参数  ：无
返回值：无
]]
function startcsqtimer()
	--不是飞行模式 并且 (打开了查询开关 或者 工作模式为完整模式)
	if not flymode and (csqswitch or sys.getworkmode()==sys.FULL_MODE) then
		--发送AT+CSQ查询
		csqquery()
		--启动定时器
		sys.timer_start(startcsqtimer,csqqrypriod)
	end
end

--[[
函数名：startcengtimer
功能  ：有选择性的启动“当前和临近小区信息查询”定时器
参数  ：无
返回值：无
]]
function startcengtimer()
	--设置了查询间隔 并且 不是飞行模式 并且 (打开了查询开关 或者 工作模式为完整模式)
	if cengqrypriod and not flymode and (cengswitch or sys.getworkmode()==sys.FULL_MODE) then
		--发送AT+CENG?查询
		cengquery()
		--启动定时器
		sys.timer_start(startcengtimer,cengqrypriod)
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

	if intermediate ~= nil then
		if prefix == "+CSQ" then
			local s = smatch(intermediate,"+CSQ:%s*(%d+)")
			if s ~= nil then
				rssi = tonumber(s)
				rssi = rssi == 99 and 0 or rssi
				--产生一个内部消息GSM_SIGNAL_REPORT_IND，表示读取到了信号强度
				dispatch("GSM_SIGNAL_REPORT_IND",success,rssi)
			end
		elseif prefix == "+CENG" then
		end
	end
end

--[[
函数名：setcsqqueryperiod
功能  ：设置“信号强度”查询间隔
参数  ：
		period：查询间隔，单位毫秒
返回值：无
]]
function setcsqqueryperiod(period)
	csqqrypriod = period
	startcsqtimer()
end

--[[
函数名：setcengqueryperiod
功能  ：设置“当前和临近小区信息”查询间隔
参数  ：
		period：查询间隔，单位毫秒。如果小于等于0，表示停止查询功能
返回值：无
]]
function setcengqueryperiod(period)
	if period ~= cengqrypriod then		
		if period <= 0 then
			sys.timer_stop(startcengtimer)
		else
			cengqrypriod = period
			startcengtimer()
		end
	end
end

--[[
函数名：cengquery
功能  ：查询“当前和临近小区信息”
参数  ：无
返回值：无
]]
function cengquery()
	--不是飞行模式，发送AT+CENG?
	if not flymode then	req("AT+CENG?")	end
end

--[[
函数名：setcengswitch
功能  ：设置“当前和临近小区信息”查询开关
参数  ：
		v：true为开启，其余为关闭
返回值：无
]]
function setcengswitch(v)
	cengswitch = v
	--开启并且不是飞行模式
	if v and not flymode then startcengtimer() end
end

--[[
函数名：cellinfoind
功能  ：CELL_INFO_IND消息的处理函数
参数  ：无
返回值：如果有用户自定义的获取多基站信息的回调函数，则返回nil；否则返回true
]]
local function cellinfoind()
	if multicellcb then
		local cb = multicellcb
		multicellcb = nil
		cb(getcellinfoext())
	else
		return true
	end
end

--[[
函数名：getmulticell
功能  ：读取“当前和临近小区信息”
参数  ：
		cb：回调函数，当读取到小区信息后，会调用此回调函数，调用形式为cb(cells)，其中cells为string类型，格式为：
		    当前和临近位置区、小区、mcc、mnc、以及信号强度的拼接字符串，例如：460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;
返回值：无 
]]
function getmulticell(cb)
	multicellcb = cb
	cengquery()
end

--[[
函数名：csqquery
功能  ：查询“信号强度”
参数  ：无
返回值：无
]]
function csqquery()
	--不是飞行模式，发送AT+CSQ
	if not flymode then req("AT+CSQ") end
end

--[[
函数名：setcsqswitch
功能  ：设置“信号强度”查询开关
参数  ：
		v：true为开启，其余为关闭
返回值：无
]]
function setcsqswitch(v)
	csqswitch = v
	--开启并且不是飞行模式
	if v and not flymode then startcsqtimer() end
end

--[[
函数名：ledblinkon
功能  ：点亮网络指示灯
参数  ：无
返回值：无
]]
local function ledblinkon()
	--print("ledblinkon",ledstate,ledontime,ledofftime)
	--引脚输出电平控制指示灯点亮
	pio.pin.setval(ledvalid==1 and 1 or 0,ledpin)
	--常灭
	if ledontime==0 and ledofftime==0xFFFF then
		ledblinkoff()
	--常亮
	elseif ledontime==0xFFFF and ledofftime==0 then
		--关闭点亮时长定时器和熄灭时长定时器
		sys.timer_stop(ledblinkon)
		sys.timer_stop(ledblinkoff)
	--闪烁
	else
		--启动点亮时长定时器，定时到了之后，熄灭指示灯
		sys.timer_start(ledblinkoff,ledontime)
	end	
end

--[[
函数名：ledblinkoff
功能  ：熄灭网络指示灯
参数  ：无
返回值：无
]]
function ledblinkoff()
	--print("ledblinkoff",ledstate,ledontime,ledofftime)
	--引脚输出电平控制指示灯熄灭
	pio.pin.setval(ledvalid==1 and 0 or 1,ledpin)
	--常灭
	if ledontime==0 and ledofftime==0xFFFF then
		--关闭点亮时长定时器和熄灭时长定时器
		sys.timer_stop(ledblinkon)
		sys.timer_stop(ledblinkoff)
	--常亮
	elseif ledontime==0xFFFF and ledofftime==0 then
		ledblinkon()
	--闪烁
	else
		--启动熄灭时长定时器，定时到了之后，点亮指示灯
		sys.timer_start(ledblinkon,ledofftime)
	end	
end

--[[
函数名：procled
功能  ：更新网络指示灯状态以及点亮和熄灭时长
参数  ：无
返回值：无
]]
function procled()
	print("procled",ledflg,ledstate,flymode,usersckconnect,userscksslconnect,cgatt,state)
	--如果开启了网络指示灯功能
	if ledflg then
		local newstate,newontime,newofftime = "IDLE",ledidleon,ledidleoff
		--飞行模式
		if flymode then
			newstate,newontime,newofftime = "FLYMODE",ledflymodeon,ledflymodeoff
		elseif simerrsta then
			newstate,newontime,newofftime = "SIMERR",ledsimerron,ledsimerroff
		--用户socket连接到了后台
		elseif usersckconnect or userscksslconnect then
			newstate,newontime,newofftime = "SCK",ledsckon,ledsckoff
		--附着上GPRS数据网络
		elseif cgatt then
			newstate,newontime,newofftime = "CGATT",ledcgatton,ledcgattoff
		--注册上GSM网络
		elseif state=="REGISTERED" then
			newstate,newontime,newofftime = "CREG",ledcregon,ledcregoff		
		end
		--指示灯状态发生变化
		if newstate~=ledstate then
			ledstate,ledontime,ledofftime = newstate,newontime,newofftime
			ledblinkoff()
		end
	end
end

--[[
函数名：usersckind
功能  ：内部消息USER_SOCKET_CONNECT的处理函数
参数  ：
		v：参数，表示用户socket是否连接上后台
返回值：无
]]
local function usersckind(v)
	print("usersckind",v)
	if usersckconnect~=v then
		usersckconnect = v
		procled()
	end
end

local function userscksslind(v)
	print("userscksslind",v)
	if userscksslconnect~=v then
		userscksslconnect = v
		procled()
	end
end

--[[
函数名：cgattind
功能  ：内部消息NET_GPRS_READY的处理函数
参数  ：
		v：参数，表示是否附着上GPRS数据网络
返回值：无
]]
local function cgattind(v)
	print("cgattind",v)
	if cgatt~=v then
		cgatt = v
		procled()
	end
	return true
end

--[[
函数名：setled
功能  ：设置网络指示灯功能
参数  ：
		v：指示灯开关，true为开启，其余为关闭
		pin：指示灯控制引脚，可选
		valid：引脚输出何种电平会点亮指示灯，1为高，0为低，可选
		flymodeon,flymodeoff,simerron,simerroff,idleon,idleoff,cregon,cregoff,cgatton,cgattoff,sckon,sckoff：FLYMODE,SIMERR,IDLE,CREG,CGATT,SCK状态下指示灯的点亮和熄灭时长(毫秒)，可选
返回值：无
]]
function setled(v,pin,valid,flymodeon,flymodeoff,simerron,simerroff,idleon,idleoff,cregon,cregoff,cgatton,cgattoff,sckon,sckoff)
	local c1 = (ledflg~=v or ledpin~=(pin or ledpin) or ledvalid~=(valid or ledvalid))
	local c2 = (ledidleon~=(idleon or ledidleon) or ledidleoff~=(idleoff or ledidleoff) or flymodeon~=(flymodeon or ledflymodeon) or flymodeoff~=(flymodeoff or ledflymodeoff))
	local c3 = (ledcregon~=(cregon or ledcregon) or ledcregoff~=(cregoff or ledcregoff) or ledcgatton~=(cgatton or ledcgatton) or simerron~=(simerron or ledsimerron))
	local c4 = (ledcgattoff~=(cgattoff or ledcgattoff) or ledsckon~=(sckon or ledsckon) or ledsckoff~=(sckoff or ledsckoff) or simerroff~=(simerroff or ledsimerroff))
	--开关值发生变化 或者其他参数发生变化
	if c1 or c2 or c3 or c4 then
		local oldledflg = ledflg
		ledflg = v
		--开启
		if v then
			ledpin,ledvalid,ledidleon,ledidleoff,ledcregon,ledcregoff = pin or ledpin,valid or ledvalid,idleon or ledidleon,idleoff or ledidleoff,cregon or ledcregon,cregoff or ledcregoff
			ledcgatton,ledcgattoff,ledsckon,ledsckoff = cgatton or ledcgatton,cgattoff or ledcgattoff,sckon or ledsckon,sckoff or ledsckoff
			ledflymodeon,ledflymodeoff,ledsimerron,ledsimerroff = flymodeon or ledflymodeon,flymodeoff or ledflymodeoff,simerron or ledsimerron,simerroff or ledsimerroff
			if not oldledflg then pio.pin.setdir(pio.OUTPUT,ledpin) end
			procled()
		--关闭
		else
			sys.timer_stop(ledblinkon)
			sys.timer_stop(ledblinkoff)
			if oldledflg then
				pio.pin.setval(ledvalid==1 and 0 or 1,ledpin)
				pio.pin.close(ledpin)
			end
			ledstate = "INIT"
		end		
	end
end

--本模块关注的内部消息处理函数表
local procer =
{
	SIM_IND = simind,
	FLYMODE_IND = flyind,
	SYS_WORKMODE_IND = workmodeind,
	USER_SOCKET_CONNECT = usersckind,
	USER_SOCKETSSL_CONNECT = userscksslind,
	NET_GPRS_READY = cgattind,
	CELL_INFO_IND = cellinfoind,
}
--注册消息处理函数表
sys.regapp(procer)
--注册+CREG和+CENG通知的处理函数
ril.regurc("+CREG",neturc)
ril.regurc("+CENG",neturc)
--注册AT+CCSQ和AT+CENG?命令的应答处理函数
ril.regrsp("+CSQ",rsp)
ril.regrsp("+CENG",rsp)
--发送AT命令
req("AT+CREG=2")
req("AT+CREG?")
req("AT+CENG=1,1")
--8秒后查询第一次csq
sys.timer_start(startcsqtimer,8*1000)
resetcellinfo()
setled(true)
