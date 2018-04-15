--[[
模块名称：闹钟测试(支持开机闹钟和关机闹钟，同时只能存在一个闹钟，如果想实现多个闹钟，等当前闹钟触发后，再次调用闹钟设置接口去配置下一个闹钟)
模块功能：测试闹钟功能
模块最后修改时间：2017.12.19
]]

--加载ntp模块，同步网络服务器时间
require"ntp"
module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--[[
函数名：ntpind
功能  ：网络服务器同步时间消息的处理函数
参数  ：id：消息id，此处为"NTP_IND"
		result：消息携带的参数，此处为网络同步时间的结果，true为成功，false为失败
返回值：true，true表示其他地方还可以注册NTP_IND消息的处理函数，如果NTP_IND仅被此函数处理，就返回false或者nil
]]
local function ntpind(id,result)
	print("ntpind",id,result)
	--如果跟网络服务器同步时间成功，直接参考当前时间设置闹钟即可
	if result then
		--设置闹钟时间为2017年12月19日12点25分0秒，用户测试时，根据当前时间修改此值
		--set_alarm接口参数说明：第一个参数1表示开启闹钟，0表示关闭闹钟；接下来的6个参数表示年月日时分秒，关闭闹钟时，这6个参数传入0,0,0,0,0,0
		rtos.set_alarm(1,2017,12,19,12,25,0)
		--如果要测试关机闹钟，打开下面这行代码
		rtos.poweroff()
	end
	return true
end

--[[
函数名：alarmsg
功能  ：开机闹钟事件的处理函数
参数  ：无
返回值：无
]]
local function alarmsg()
	print("alarmsg")
end

--如果是关机闹钟开机，则需要软件主动重启一次，才能启动GSM协议栈
if rtos.poweron_reason()==rtos.POWERON_ALARM then
	sys.restart("ALARM")
end

--注册网络服务器同步时间消息的处理函数
sys.regapp(ntpind,"NTP_IND")

--注册闹钟模块
rtos.init_module(rtos.MOD_ALARM)
--注册闹钟消息的处理函数（如果是开机闹钟，闹钟事件到来时会调用alarmsg）
sys.regmsg(rtos.MSG_ALARM,alarmsg)
