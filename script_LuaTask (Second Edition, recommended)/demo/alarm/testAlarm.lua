--- 模块功能：闹钟功能测试(支持开机闹钟和关机闹钟，同时只能存在一个闹钟，如果想实现多个闹钟，等当前闹钟触发后，再次调用闹钟设置接口去配置下一个闹钟).
-- 开机后，连接网络服务器自动同步时间；同步时间后，设置一个闹钟；闹钟时间到达之后，执行一个处理函数
-- @author openLuat
-- @module alarm.testAlarm
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.14

require"ntp"
module(...,package.seeall)


--[[
函数名：ntpSucceed
功能  ：网络服务器同步时间成功消息的处理函数
参数  ：无
返回值：无
]]
local function ntpSucceed()
    log.info("testAlarm.ntpSucceed")
    --跟网络服务器同步时间成功，直接参考当前时间设置闹钟即可
    --设置闹钟时间为2018年3月14日18点18分0秒，用户测试时，根据当前时间修改此值
    --set_alarm接口参数说明：第一个参数1表示开启闹钟，0表示关闭闹钟；接下来的6个参数表示年月日时分秒，关闭闹钟时，这6个参数传入0,0,0,0,0,0
    rtos.set_alarm(1,2018,3,14,18,18,0)
    --如果要测试关机闹钟，打开下面这行代码
    --rtos.poweroff()
end

--[[
函数名：alarMsg
功能  ：开机闹钟事件的处理函数
参数  ：无
返回值：无
]]
local function alarMsg()
	print("alarMsg")
end

--如果是关机闹钟开机，则需要软件主动重启一次，才能启动GSM协议栈
if rtos.poweron_reason()==rtos.POWERON_ALARM then
	sys.restart("ALARM")
end

--启动网络服务器同步时间功能，同步成功后执行ntpSucceed函数
ntp.timeSync(nil,ntpSucceed)

--注册闹钟模块
rtos.init_module(rtos.MOD_ALARM)
--注册闹钟消息的处理函数（如果是开机闹钟，闹钟事件到来时会调用alarmsg）
rtos.on(rtos.MSG_ALARM,alarMsg)
