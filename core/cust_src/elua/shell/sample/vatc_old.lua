uart.setup(0, 115200, 8, uart.PAR_NONE, uart.STOP_1)
uart.setup(uart.ATC, 0, 0, uart.PAR_NONE, uart.STOP_1)
uart.write(0, "start test lua app.")
while true do
    local s = uart.read(uart.ATC, "*l", 0)
    if string.len(s) == 0 then
       do
           s = uart.read(0, "*l", 0)
           if string.len(s) == 0 then
               uart.sleep(1000)
           else
               print("uart:" .. s)
               uart.write(uart.ATC, s)
           end
       end
    else
       print("atc:" .. s)
       uart.write(0, "atc:", s)
    end
end
