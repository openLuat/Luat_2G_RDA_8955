--- 模块功能：完善luat的c库接口
-- @module clib
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.9.20

local uartReceiveCallbacks = {}
local uartSentCallbacks = {}

--- uart.on
-- @param id uart id: (uart.ATC, 1, 2)
-- @param event uart event: "recieve", "sent"
-- @param callback uart event callback function
-- @return 无
-- @usage uart.on()
uart.on = function(id, event, callback)
    if event == "receive" then
        uartReceiveCallbacks[id] = callback
    elseif event == "sent" then
        uartSentCallbacks[id] = callback
    end
end

rtos.on(rtos.MSG_UART_RXDATA, function(id)
    if uartReceiveCallbacks[id] then
        uartReceiveCallbacks[id]()
    end
end)

rtos.on(rtos.MSG_UART_TX_DONE, function(id)
    if uartSentCallbacks[id] then
        uartSentCallbacks[id]()
    end
end)
