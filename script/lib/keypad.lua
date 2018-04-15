--定义模块,导入依赖库
local base = _G
local sys = require"sys"
local rtos = require"rtos"
module(...)

--[[
sta：按键状态，IDLE表示空闲状态，PRESSED表示已按下状态，LONGPRESSED表示已经长按下状态
longprd：长按键判断时长，默认3秒；按下大于等于3秒再弹起判定为长按键；按下后，在3秒内弹起，判定为短按键
longcb：长按键处理函数
shortcb：短按键处理函数
]]
local sta,longprd,longcb,shortcb = "IDLE",3000

local function print(...)
	base.print("keypad",...)
end

local function longtimercb()
	print("longtimercb")
	sta = "LONGPRESSED"	
end

local function keymsg(msg)
	print("keymsg",msg.key_matrix_row,msg.key_matrix_col,msg.pressed)
	if msg.pressed then
		sta = "PRESSED"
		sys.timer_start(longtimercb,longprd)
	else
		sys.timer_stop(longtimercb)
		if sta=="PRESSED" then
			if shortcb then
				shortcb()
			end
		elseif sta=="LONGPRESSED" then
			if longcb then
				longcb()
			else
				rtos.poweroff()
			end
		end
		sta = "IDLE"
	end
end

--[[
函数名：setup
功能  ：配置power key按键功能
参数  ：
		keylongprd：number类型或者nil，长按键判断时长，单位毫秒，如果是nil，默认3000毫秒
		keylongcb：function类型或者nil，长按弹起时的回调函数，如果为nil，使用默认的处理函数，会自动关机
		keyshortcb：function类型或者nil，短按弹起时的回调函数
返回值：无
]]
function setup(keylongprd,keylongcb,keyshortcb)
	longprd,longcb,shortcb = keylongprd or 3000,keylongcb,keyshortcb
end

sys.regmsg(rtos.MSG_KEYPAD,keymsg)
rtos.init_module(rtos.MOD_KEYPAD,0,0,0)
