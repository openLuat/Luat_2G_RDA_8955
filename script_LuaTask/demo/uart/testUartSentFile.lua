--- 模块功能：串口功能测试(非TASK版，串口帧有自定义的结构)
-- @author openLuat
-- @module uart.testUartTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.05.24

module(...,package.seeall)

require"utils"
require"pm"

local uartID = 1

sys.taskInit(
    function()                
        local fileHandle = io.open("/ldata/mcu101.bin","rb")
        if not fileHandle then
            log.error("testALiYun.otaCb1 open file error")
            return
        end
        
        pm.wake("UART_SENT2MCU")
        uart.on(uartID,"sent",function() sys.publish("UART_SENT2MCU_OK") end)
        uart.setup(uartID,115200,8,uart.PAR_NONE,uart.STOP_1,nil,1)
        while true do
            local data = fileHandle:read(1460)
            if not data then break end
            uart.write(uartID,data)
            sys.waitUntil("UART_SENT2MCU_OK")
        end
        
        uart.close(uartID)
        pm.sleep("UART_SENT2MCU")
        fileHandle:close()
    end
)
