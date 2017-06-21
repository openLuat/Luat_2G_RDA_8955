local msg = {}
local s = ""

uart.setup(0, 115200, 8, uart.PAR_NONE, uart.STOP_1)
uart.setup(uart.ATC, 0, 0, uart.PAR_NONE, uart.STOP_1)

uart.write(0, "start test lua app.\r\n")
-- assert debug
-- uart.write(uart.ATC, "at*exassert=1\r\n")

while true do
    msg = rtos.receive(rtos.INF_TIMEOUT)
    
    if msg.id == rtos.MSG_UART_RXDATA then
        repeat
            s = uart.read(msg.uart_id, "*l", 0)
            if string.len(s) ~= 0 then
                print(msg.uart_id .. ":" .. s)
                if msg.uart_id == 0 then
                    uart.write(uart.ATC, s)
                else
                    uart.write(0, s)
                end
            end
        until string.len(s) == 0
    else
        print("rtos.receive: msg id(" .. msg.id .. ")")
    end
end
