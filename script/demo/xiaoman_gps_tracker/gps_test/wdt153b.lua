--[[
模块名称：硬件看门狗
模块功能：支持153B芯片硬件看门狗功能
模块最后修改时间：2017.02.16
设计文档参考 doc\小蛮GPS定位器相关文档\Watchdog descritption.doc
]]
require"pins"
module(...,package.seeall)

WATCHDOG = {pin=pio.P0_14,init=false,valid=0}
RST_SCMWD = {pin=pio.P0_12,defval=true,valid=1}

pins.reg(WATCHDOG,RST_SCMWD)

local scm_active,get_scm_cnt = true,20

local function getscm()
	get_scm_cnt = get_scm_cnt - 1
	if get_scm_cnt > 0 then
		sys.timer_start(getscm,100)
	else
		get_scm_cnt = 20
	end

	if pins.get(WATCHDOG) then
		scm_active = true
		print("wdt scm_active = true")
	end
end

local function feedend()
	pins.setdir(pio.INPUT,WATCHDOG)
	print("wdt feedend")
	sys.timer_start(getscm,100)
end

local function feed()
	if scm_active then
		scm_active = false
	else
		pins.set(false,RST_SCMWD)
		sys.timer_start(pins.set,100,true,RST_SCMWD)
		print("wdt reset 153b")
	end

	pins.setdir(pio.OUTPUT,WATCHDOG)
	pins.set(true,WATCHDOG)
	print("wdt feed")

	sys.timer_start(feed,120000)
	sys.timer_start(feedend,2000)
end

local function open()
	sys.timer_start(feed,120000)
	pins.set(false,WATCHDOG)
end

sys.timer_start(open,200)
