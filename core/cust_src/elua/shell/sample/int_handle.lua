local function gpio_negedge_handler(resnum)                               
	local port,pin = pio.decode(resnum)
	print(string.format("gpio negedge int on port %d, pin %d", port, pin))
end

local function gpio_posedge_handler(resnum)
	local port,pin = pio.decode(resnum)
	print(string.format("gpio posedge int on port %d, pin %d", port, pin))
end

local count = 0

cpu.set_int_handler(cpu.INT_GPIO_NEGEDGE, gpio_negedge_handler)
cpu.set_int_handler(cpu.INT_GPIO_POSEDGE, gpio_posedge_handler)

while true do
  uart.sleep(1000)
  count = count+1
  if count%5 == 0 then
      print(string.format("main loop count :%d", count))
  end
end
