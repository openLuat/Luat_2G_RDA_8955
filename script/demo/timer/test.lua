module(...,package.seeall)

--定时器测试程序
--定时器1：循环定时器，循环周期为1秒钟，每次都打印"TimerFunc1 check1"，检测一次定时器2到定时器5是否处于激活状态，打印出来处于激活状态的定时器
--定时器2：单次定时器，启动后5秒钟触发，打印"TimerFunc2"，然后自动关闭自己
--定时器3：单次定时器，启动后10秒钟触发，打印"TimerFunc3"，然后自动关闭自己
--定时器4：循环定时器，循环周期为2秒钟，每次都打印"TimerFunc4"
--定时器5：单次定时器，启动后60秒钟触发，打印"TimerFunc5"，关闭定时器4，启动定时器6、7、8，然后自动关闭自己
--定时器6：循环定时器，循环周期为1秒钟，每次都打印"TimerFunc1 check6"
--定时器7：循环定时器，循环周期为1秒钟，每次都打印"TimerFunc1 check7"
--定时器8：单次定时器，启动后5秒钟触发，打印"CloseTimerFunc1 check check6 check7"，然后自动关闭自己

local function TimerFunc2AndTimerFunc3(id)
	print("TimerFunc"..id)
end

local function TimerFunc4()
	print("TimerFunc4")
end

local function TimerFunc5()
	print("TimerFunc5")
	sys.timer_stop(TimerFunc4)
	sys.timer_loop_start(TimerFunc1,1000,"check6")
	sys.timer_loop_start(TimerFunc1,1000,"check7")
	sys.timer_start(CloseTimerFunc1,5000)
end

function CloseTimerFunc1()
	print("CloseTimerFunc1 check check6 check7")
	sys.timer_stop_all(TimerFunc1)
end

function TimerFunc1(id)
	print("TimerFunc1 "..id)
	if id=="check1" then		
		if sys.timer_is_active(TimerFunc2AndTimerFunc3,2) then print("Timer2 active") end
		if sys.timer_is_active(TimerFunc2AndTimerFunc3,3) then print("Timer3 active") end
		if sys.timer_is_active(TimerFunc4) then print("Timer4 active") end
		if sys.timer_is_active(TimerFunc5) then print("Timer5 active") end
	end
end



sys.timer_loop_start(TimerFunc1,1000,"check1")
sys.timer_start(TimerFunc2AndTimerFunc3,5000,2)
sys.timer_start(TimerFunc2AndTimerFunc3,10000,3)
sys.timer_loop_start(TimerFunc4,2000)
sys.timer_start(TimerFunc5,60000)
