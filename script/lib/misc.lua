--[[
模块名称：杂项管理
模块功能：序列号、IMEI、底层软件版本号、时钟、是否校准、飞行模式、查询电池电量等功能
模块最后修改时间：2017.02.14
]]

--定义模块,导入依赖库
local string = require"string"
local ril = require"ril"
local sys = require"sys"
local base = _G
local os = require"os"
local io = require"io"
local rtos = require"rtos"
local pmd = require"pmd"
module(...)

--加载常用的全局函数至本地
local type,assert,tonumber,tostring,print,req,smatch = base.type,base.assert,base.tonumber,base.tostring,base.print,ril.request,string.match

--sn：序列号
--snrdy：是否已经成功读取过序列号
--imei：IMEI
--imeirdy：是否已经成功读取过IMEI
--ver：底层软件版本号
--clkswitch：整分时钟通知开关
--updating：是否正在执行远程升级功能(update.lua)
--dbging：是否正在执行dbg功能(dbg.lua)
--ntping：是否正在执行NTP时间同步功能(ntp.lua)
--flypending：是否有等待处理的进入飞行模式请求
local sn,snrdy,imeirdy,--[[ver,]]imei,clkswitch,updating,dbging,ntping,flypending

--calib：校准标志，true为已校准，其余未校准
--setclkcb：执行AT+CCLK命令，应答后的用户自定义回调函数
--wimeicb：执行AT+WIMEI命令，应答后的用户自定义回调函数
--wsncb：执行AT+WISN命令，应答后的用户自定义回调函数
local calib,setclkcb,wimeicb,wsncb

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
	--查询序列号
	if cmd == "AT+WISN?" then
		sn = intermediate
		--如果没有成功读取过序列号，则产生一个内部消息SN_READY，表示已经读取到序列号
		if not snrdy then sys.dispatch("SN_READY") snrdy = true end
	--查询底层软件版本号
	--[[elseif cmd == "AT+VER" then
		ver = intermediate]]
	--查询IMEI
	elseif cmd == "AT+CGSN" then
		imei = intermediate
		--如果没有成功读取过IMEI，则产生一个内部消息IMEI_READY，表示已经读取到IMEI
		if not imeirdy then sys.dispatch("IMEI_READY") imeirdy = true end
	--写IMEI
	elseif smatch(cmd,"AT%+WIMEI=") then
		if wimeicb then wimeicb(success) end
	--写序列号
	elseif smatch(cmd,"AT%+WISN=") then
		if wsncb then wsncb(success) end
	--设置系统时间
	elseif prefix == "+CCLK" then
		startclktimer()
		--AT命令应答处理结束，如果有回调函数
		if setclkcb then
			setclkcb(cmd,success,response,intermediate)
		end
	--查询是否校准
	elseif cmd == "AT+ATWMFT=99" then
		print('ATWMFT',intermediate)
		if intermediate == "SUCC" then
			calib = true
		else
			calib = false
		end
	--进入或退出飞行模式
	elseif smatch(cmd,"AT%+CFUN=[01]") then
		--产生一个内部消息FLYMODE_IND，表示飞行模式状态发生变化
		sys.dispatch("FLYMODE_IND",smatch(cmd,"AT%+CFUN=(%d)")=="0")
	end
	
end

--[[
函数名：setclock
功能  ：设置系统时间
参数  ：
		t：系统时间表，格式参考：{year=2017,month=2,day=14,hour=14,min=2,sec=58}
		rspfunc：设置系统时间后的用户自定义回调函数
返回值：无
]]
function setclock(t,rspfunc)
	if t.year - 2000 > 38 then return end
	setclkcb = rspfunc
	req(string.format("AT+CCLK=\"%02d/%02d/%02d,%02d:%02d:%02d+32\"",string.sub(t.year,3,4),t.month,t.day,t.hour,t.min,t.sec),nil,rsp)
end

--[[
函数名：getclockstr
功能  ：获取系统时间字符串
参数  ：无
返回值：系统时间字符串，格式为YYMMDDhhmmss，例如170214141602，17年2月14日14时16分02秒
]]
function getclockstr()
	local clk = os.date("*t")
	clk.year = string.sub(clk.year,3,4)
	return string.format("%02d%02d%02d%02d%02d%02d",clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec)
end

--[[
函数名：getweek
功能  ：获取星期
参数  ：无
返回值：星期，number类型，1-7分别对应周一到周日
]]
function getweek()
	local clk = os.date("*t")
	return ((clk.wday == 1) and 7 or (clk.wday - 1))
end

--[[
函数名：getclock
功能  ：获取系统时间表
参数  ：无
返回值：table类型的时间，例如{year=2017,month=2,day=14,hour=14,min=19,sec=23}
]]
function getclock()
	return os.date("*t")
end

--[[
函数名：startclktimer
功能  ：选择性的启动整分时钟通知定时器
参数  ：无
返回值：无
]]
function startclktimer()
	--开关开启 或者 工作模式为完整模式
	if clkswitch or sys.getworkmode()==sys.FULL_MODE then
		--产生一个内部消息CLOCK_IND，表示现在是整分，例如12点13分00秒、14点34分00秒
		sys.dispatch("CLOCK_IND")
		print('CLOCK_IND',os.date("*t").sec)
		--启动下次通知的定时器
		sys.timer_start(startclktimer,(60-os.date("*t").sec)*1000)
	end
end

--[[
函数名：setclkswitch
功能  ：设置“整分时钟通知”开关
参数  ：
		v：true为开启，其余为关闭
返回值：无
]]
function setclkswitch(v)
	clkswitch = v
	if v then startclktimer() end
end

--[[
函数名：getsn
功能  ：获取序列号
参数  ：无
返回值：序列号，如果未获取到返回""
]]
function getsn()
	--[[
	if imei=="862991419826711" then return "fUECbTzdDm48irb0ng97GnHTBRGFKpYj" end
	if imei=="862991419827115" then return "nvsGyyIpohh1LtzNaiU9eUsGEDWwOFB9" end
	if imei=="862991419827289" then return "nAQDkMNLnwv6Bh7w0sejhDcdKrEE4hXQ" end
	if imei=="862991419826760" then return "b57RRMVXFGiktclTPPoX0Fx2L26z8KBN" end
	if imei=="862991419827255" then return "cO9eOqF80IgQGx7TTSB7rRJbLlTyIscH" end
	]]
	return sn or ""
end

--[[
函数名：isnvalid
功能  ：判断sn是否有效
参数  ：无
返回值：有效返回true，否则返回false
]]
function isnvalid()
	local snstr,sninvalid = getsn(),""
	local len,i = string.len(snstr)
	for i=1,len do
		sninvalid = sninvalid.."0"
	end
	return snstr~=sninvalid
end

--[[
函数名：getimei
功能  ：获取IMEI
参数  ：无
返回值：IMEI号，如果未获取到返回""
注意：开机lua脚本运行之后，会发送at命令去查询imei，所以需要一定时间才能获取到imei。开机后立即调用此接口，基本上返回""
]]
function getimei()
	return imei or ""
end

--[[
函数名：setimei
功能  ：设置IMEI
		如果传入了cb，则设置IMEI后不会自动重启，用户必须自己保证设置成功后，调用sys.restart或者dbg.restart接口进行软重启;
		如果没有传入cb，则设置成功后软件会自动重启
参数  ：
		s：新IMEI
		cb：设置后的回调函数，调用时会将设置结果传出去，true表示设置成功，false或者nil表示失败；
返回值：无
]]
function setimei(s,cb)
	if s==imei then
		if cb then cb(true) end
	else
		req("AT+AMFAC="..(cb and "0" or "1"))
		req("AT+WIMEI=\""..s.."\"")
		wimeicb = cb
	end
end

--[[
函数名：setsn
功能  ：设置SN
		如果传入了cb，则设置SN后不会自动重启，用户必须自己保证设置成功后，调用sys.restart或者dbg.restart接口进行软重启;
		如果没有传入cb，则设置成功后软件会自动重启
参数  ：
		s：新SN
		cb：设置后的回调函数，调用时会将设置结果传出去，true表示设置成功，false或者nil表示失败；
返回值：无
]]
function setsn(s,cb)
	if s==sn then
		if cb then cb(true) end
	else
		req("AT+AMFAC="..(cb and "0" or "1"))
		req("AT+WISN=\""..s.."\"")
		wsncb = cb
	end
end


--[[
函数名：setflymode
功能  ：控制飞行模式
参数  ：
		val：true为进入飞行模式，false为退出飞行模式
返回值：无
]]
function setflymode(val)
	--如果是进入飞行模式
	if val then
		--如果正在执行远程升级功能或者dbg功能或者ntp功能，则延迟进入飞行模式
		if updating or dbging or ntping then flypending = true return end
	end
	--发送AT命令进入或者退出飞行模式
	req("AT+CFUN="..(val and 0 or 1))
	flypending = false
end

--[[
函数名：set
功能  ：兼容之前写的旧程序，目前为空函数
参数  ：无
返回值：无
]]
function set() end

--[[
函数名：getcalib
功能  ：获取是否校准标志
参数  ：无
返回值：true为校准，其余为没校准
]]
function getcalib()
	return calib
end

--[[
函数名：getvbatvolt
功能  ：获取VBAT的电池电压
参数  ：无
返回值：电压，number类型，单位毫伏
]]
function getvbatvolt()
	local v1,v2,v3,v4,v5 = pmd.param_get()
	return v2
end

--[[
函数名：openpwm
功能  ：打开并且配置PWM(支持2路PWM，仅支持输出)
参数  ：
		id：number类型，PWM输出通道，仅支持0和1，0用的是uart2 tx，1用的是uart2 rx
		period：number类型
				当id为0时，period表示频率，单位为Hz，取值范围为80-1625，仅支持整数
				当id为1时，取值范围为0-7，仅支持整数，表示时钟周期，单位为毫秒，0-7分别对应125、250、500、1000、1500、2000、2500、3000毫秒
		level：number类型
				当id为0时，level表示占空比，单位为level%，取值范围为1-100，仅支持整数
				当id为1时，取值范围为1-15，仅支持整数，表示一个时钟周期内的高电平时间，单位为毫秒
				1-15分别对应15.6、31.2、46.9、62.5、78.1、93.7、110、125、141、156、172、187、203、219、234毫秒
返回值：无
说明：当id为0时：
	  period 取值在 80-1625 Hz范围内时，level 占空比取值范围为：1-100；
	  period 取值在 1626-65535 Hz范围时，设x=162500/period, y=x * level / 100, x 和 y越是接近正的整数，则输出波形越准确
]]
function openpwm(id,period,level)
	assert(type(id)=="number" and type(period)=="number" and type(level)=="number","openpwm type error")
	assert(id==0 or id==1,"openpwm id error: "..id)
	local pmin,pmax,lmin,lmax = 80,1625,1,100
	if id==1 then pmin,pmax,lmin,lmax = 0,7,1,15 end
	assert(period>=pmin and period<=pmax,"openpwm period error: "..period)
	assert(level>=lmin and level<=lmax,"openpwm level error: "..level)
	req("AT+SPWM="..id..","..period..","..level)
end

--[[
函数名：closepwm
功能  ：关闭PWM
参数  ：
		id：number类型，PWM输出通道，仅支持0和1，0用的是uart2 tx，1用的是uart2 rx
返回值：无
]]
function closepwm(id)
	assert(id==0 or id==1,"closepwm id error: "..id)
	req("AT+SPWM="..id..",0,0")
end

--[[
函数名：ind
功能  ：本模块注册的内部消息的处理函数
参数  ：
		id：内部消息id
		para：内部消息参数
返回值：true
]]
local function ind(id,para)
	--工作模式发生变化
	if id=="SYS_WORKMODE_IND" then
		startclktimer()
	--远程升级开始
	elseif id=="UPDATE_BEGIN_IND" then
		updating = true
	--远程升级结束
	elseif id=="UPDATE_END_IND" then
		updating = false
		if flypending then setflymode(true) end
	--dbg功能开始
	elseif id=="DBG_BEGIN_IND" then
		dbging = true
	--dbg功能结束
	elseif id=="DBG_END_IND" then
		dbging = false
		if flypending then setflymode(true) end
	--NTP同步开始
	elseif id=="NTP_BEGIN_IND" then
		ntping = true
	--NTP同步结束
	elseif id=="NTP_END_IND" then
		ntping = false
		if flypending then setflymode(true) end
	end

	return true
end

--注册以下AT命令的应答处理函数
ril.regrsp("+ATWMFT",rsp)
ril.regrsp("+WISN",rsp)
--ril.regrsp("+VER",rsp,4,"^[%w_]+$")
ril.regrsp("+CGSN",rsp)
ril.regrsp("+WIMEI",rsp)
ril.regrsp("+AMFAC",rsp)
ril.regrsp("+CFUN",rsp)
--查询是否校准
req("AT+ATWMFT=99")
--查询序列号
req("AT+WISN?")
--查询底层软件版本号
--req("AT+VER")
--查询IMEI
req("AT+CGSN")
--启动整分时钟通知定时器
startclktimer()
--注册本模块关注的内部消息的处理函数
sys.regapp(ind,"SYS_WORKMODE_IND","UPDATE_BEGIN_IND","UPDATE_END_IND","DBG_BEGIN_IND","DBG_END_IND","NTP_BEGIN_IND","NTP_END_IND")
