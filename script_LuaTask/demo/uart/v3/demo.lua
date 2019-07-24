--- 模块功能：串口功能测试(TASK版)
-- @author openLuat
-- @module uart.testUartTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.10.20
require "utils"
require "pm"
module(..., package.seeall)


-------------------------------------------- 配置串口 --------------------------------------------
-- 串口ID,串口读缓冲区
local UART_ID, sendQueue = 1, {}
-- 串口超时，串口准备好后发布的消息
local uartimeout, recvReady = 500, "UART_RECV_ID"
--保持系统处于唤醒状态，不会休眠
pm.wake("mcuart")
uart.setup(UART_ID, 115200, 8, uart.PAR_NONE, uart.STOP_1)
uart.on(1, "receive", function(uid, length)
    table.insert(sendQueue, uart.read(uid, length))
    sys.timerStart(sys.publish, uartimeout, recvReady)
end)

-- 向串口发送收到的字符串
sys.subscribe(recvReady, function()
    local str = table.concat(sendQueue)
    log.info("uart read length:", #str, str)
    -- 串口写缓冲区最大1460
    for i = 1, #str, 1460 do
        uart.write(UART_ID, str:sub(i, i + 1460 - 1))
    end
    -- 串口的数据读完后清空缓冲区
    sendQueue = {}
end)
