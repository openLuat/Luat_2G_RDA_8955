--[[
模块名称：硬件看门狗
模块功能：支持硬件看门狗功能
模块最后修改时间：2017.02.16
设计文档参考 doc\小蛮GPS定位器相关文档\Watchdog descritption.doc
]]

module(...,package.seeall)

--模块复位单片机引脚
local RST_SCMWD_PIN = pio.P0_30
--模块和单片机相互喂狗引脚
local WATCHDOG_PIN = pio.P0_31

--scm_active：单片机是否运行正常，true表示正常，false或nil表示异常
--get_scm_cnt：“检测单片机对模块喂狗是否正常”的剩余次数
local scm_active,get_scm_cnt = true,20
--testcnt：喂狗测试过程中已经喂狗的次数
--testing：是否正在喂狗测试
local testcnt,testing = 0

--[[
函数名：getscm
功能  ：读取"单片机对模块喂狗的引脚"电平
参数  ：
		tag："normal"表示正常喂狗，"test"表示喂狗测试
返回值：无
]]
local function getscm(tag)
	--如果正在进行喂狗测试，不允许正常喂狗
	if tag=="normal" and testing then return end
	--检测剩余次数减一
	get_scm_cnt = get_scm_cnt - 1
	--如果是喂狗测试，停掉正常喂狗的流程
	if tag=="test" then
		sys.timer_stop(getscm,"normal")
	end
	--检测剩余次数还不为0
	if get_scm_cnt > 0 then
		--喂狗测试
		if tag=="test" then
			--如果检测到高电平
			if pio.pin.getval(WATCHDOG_PIN) == 1 then				
				testcnt = testcnt+1
				--没有满足连续3次喂狗，100毫秒后，继续下次喂狗
				if testcnt<3 then
					sys.timer_start(feed,100,"test")
					get_scm_cnt = 20
					return
				--喂狗测试结束，连续3次喂狗，单片机会复位模块
				else
					testing = nil
				end
			end
		end
		--100毫秒之后接着检测
		sys.timer_start(getscm,100,tag)
	--检测结束
	else
		get_scm_cnt = 20
		if tag=="test" then
			testing = nil
		end
		--正在喂狗 并且 单片机运行异常
		if tag=="normal" and not scm_active then
			--复位单片机
			pio.pin.setval(0,RST_SCMWD_PIN)
			sys.timer_start(pio.pin.setval,100,1,RST_SCMWD_PIN)
			print("wdt reset 153b")
			scm_active = true
		end
	end
	--如果检测到低电平，则表示单片机运行正常
	if pio.pin.getval(WATCHDOG_PIN) == 0 and not scm_active then
		scm_active = true
		print("wdt scm_active = true")
	end
end

--[[
函数名：feedend
功能  ：检测"单片机对模块喂狗"是否正常
参数  ：
		tag："normal"表示正常喂狗，"test"表示喂狗测试
返回值：无
]]
local function feedend(tag)
	--如果正在进行喂狗测试，不允许正常喂狗
	if tag=="normal" and testing then return end
	--相互喂狗引脚配置为输入
	pio.pin.close(WATCHDOG_PIN)
	pio.pin.setdir(pio.INPUT,WATCHDOG_PIN)
	print("wdt feedend",tag)
	--如果是喂狗测试，停掉正常喂狗的流程
	if tag=="test" then
		sys.timer_stop(getscm,"normal")
	end
	--100毫秒后去读一次喂狗引脚的输入电平
	--每100毫秒去读一次，连续读20次，只要有一次读到低电平，就认为"单片机对模块喂狗"正常
	sys.timer_start(getscm,100,tag)
end

--[[
函数名：feed
功能  ：模块开始对单片机喂狗
参数  ：
		tag："normal"表示正常喂狗，"test"表示喂狗测试
返回值：无
]]
function feed(tag)
	--如果正在进行喂狗测试，不允许正常喂狗
	if tag=="normal" and testing then return end
	--如果单片机运行正常 或者 正在进行喂狗测试
	if scm_active or tag=="test" then
		scm_active = false
	end

	--相互喂狗引脚配置为输出，"模块开始对单片机喂狗"，输出2秒的低电平
	pio.pin.close(WATCHDOG_PIN)
	pio.pin.setdir(pio.OUTPUT,WATCHDOG_PIN)
	pio.pin.setval(0,WATCHDOG_PIN)
	print("wdt feed",tag)
	--2分钟启动下次正常喂狗
	sys.timer_start(feed,120000,"normal")
	--如果是喂狗测试，停掉正常喂狗的流程
	if tag=="test" then
		sys.timer_stop(feedend,"normal")
	end
	--2秒后开始检测"单片机对模块喂狗"是否正常
	sys.timer_start(feedend,2000,tag)
end

--[[
函数名：open
功能  ：打开开发板上的硬件看门狗功能，并立即喂狗
参数  ：无
返回值：无
]]
function open()
	pio.pin.setdir(pio.OUTPUT,WATCHDOG_PIN)
	pio.pin.setval(1,WATCHDOG_PIN)
	feed("normal")
end

--[[
函数名：close
功能  ：关闭开发板上的硬件看门狗功能
参数  ：无
返回值：无
]]
function close()
	sys.timer_stop_all(feedend)
	sys.timer_stop_all(feed)
	sys.timer_stop_all(getscm)
	sys.timer_stop(pio.pin.setval,1,RST_SCMWD_PIN)
	pio.pin.close(RST_SCMWD_PIN)
	pio.pin.close(WATCHDOG_PIN)
	scm_active,get_scm_cnt,testcnt,testing = true,20,0
end

--[[
函数名：test
功能  ：测试“开发板上的硬件看门狗复位Air模块”的功能
参数  ：无
返回值：无
]]
function test()
	if not testing then
		testcnt,testing = 0,true
		feed("test")
	end
end


--[[
函数名：begin
功能  ：启动喂狗流程
参数  ：无
返回值：无
]]
local function begin()
	--模块复位单片机引脚，默认输出高电平
	pio.pin.setdir(pio.OUTPUT1,RST_SCMWD_PIN)
	pio.pin.setval(1,RST_SCMWD_PIN)
	open()
end

--[[
函数名：setup
功能  ：配置喂狗使用的两个引脚
参数  ：
		rst：模块复位单片机引脚
		wd：模块和单片机相互喂狗引脚
返回值：无
]]
function setup(rst,wd)
	RST_SCMWD_PIN,WATCHDOG_PIN = rst,wd
	sys.timer_stop(begin)
	begin()
end

sys.timer_start(begin,2000)
