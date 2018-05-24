--- 模块功能：Luat软件提示功能.
-- 每1秒通过串口1输出"This is Luat software, not AT software, please check: wiki.openluat.com for more information!\n"的信息
-- @author openLuat
-- @module default.factory1
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.20

module(...,package.seeall)

require"pm"
require"utils"

local UART_ID = 1

--- 串口接收数据处理
-- @return 无
-- @usage read()
local function read()
    local s
    while true do
        s = uart.read(UART_ID,"*l")
        if not s or string.len(s) == 0 then break end
        log.info("read bin",s)
        log.info("read hex",string.toHex(s))
    end
end

--注册串口数据接收处理函数，收到数据时，以中断方式进入read函数
uart.on(UART_ID,"receive",read)
--配置串口参数
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
--每隔1秒钟通过串口1输出提示信息
sys.timerLoopStart(uart.write,1000,UART_ID,"This is Luat software, not AT software, please check: wiki.openluat.com for more information!\n")
--此功能模块使系统一直处于唤醒状态
pm.wake("factory1")
