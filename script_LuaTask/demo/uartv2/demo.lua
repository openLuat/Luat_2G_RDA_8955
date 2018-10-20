--- 模块功能：串口功能测试(TASK版)
-- @author openLuat
-- @module uart.testUartTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.10.20
require "utils"
require "pm"
module(..., package.seeall)


-- 配置串口1 -- 蓝牙通信口
pm.wake("mcuUart.lua")
uart.setup(1, 115200, 8, uart.PAR_NONE, uart.STOP_1)
uart.on(1, "receive", function()sys.publish("UART1_RECEIVE") end)

-- 串口读指令
local function read(uid, timeout)
    local cache_data = ""
    if timeout == 0 or timeout == nil then timeout = 20 end
    sys.wait(timeout)
    while true do
        local s = uart.read(uid, "*l")
        if s == "" then
            return cache_data
        else
            cache_data = cache_data .. s
        end
    end
end
function write(uid, s)
    log.info("testUart.write", s)
    uart.write(uid, s)
end
-- 串口收到什么就返回什么
sys.taskInit(function()
    while true do
        if sys.waitUntil("UART1_RECEIVE", 1000) then
            local dat = read(1, 20)
            log.info("串口收到的数据：", dat)
            write(1, dat)
        else
            write(1, "read wait timeout!")
        end
    end
end)
