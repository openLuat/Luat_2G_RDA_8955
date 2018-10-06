
--- AT24C32
require"AT24Cx"
local DEVICE_ADDRESS = 0x57
local CAPCITY = 4096
local PAGESIZE = 32
local eeprom = AT24Cx.setup(2, DEVICE_ADDRESS, CAPCITY, PAGESIZE)
print('eeprom write', eeprom:write(10, "123456")) --- 6
print('eeprom read', eeprom:read(10, 6)) --- '123456'
