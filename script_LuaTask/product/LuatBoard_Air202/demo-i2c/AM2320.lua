--- AM2320 温湿度传感器驱动
-- @module AM2320
-- @author 稀饭放姜
-- @license MIT
-- @copyright openLuat.com
-- @release 2017.10.19
require "utils"
module(..., package.seeall)

-- 初始化并打开I2C操作
-- @param I2C 内部ID
-- @return number ,I2C的速率
local function i2c_open(id)
    if i2c.setup(id, i2c.SLOW) ~= i2c.SLOW then
        log.error("I2C.init is: ", "fail")
        i2c.close(id)
        return
    end
    return i2c.SLOW
end

--- 读取AM2320的数据
-- @number id, 端口号0-2
-- @return string，string，第一个参数是温度，第二个是湿度
-- @usage tmp, hum = read()
function read(id)    
    i2c.send(id, 0x5C, 0x03)
    i2c.send(id, 0x5C, {0x03, 0x00, 0x04})
    -- sys.wait(2)
    local data = i2c.recv(id, 0x5C, 8)    
    if data == nil or data == 0 then return end
    log.info("AM2320 HEX data: ", data:toHex())
    local _, crc = pack.unpack(data, '<H', 7)
    data = data:sub(1, 6)
    if crc == crypto.crc16_modbus(data, 6) then
        local _, hum, tmp = pack.unpack(string.sub(data, 3, -1), '>H2')
        if tmp >= 0x8000 then tmp = 0x8000 - tmp end
        log.info("AM2320 data: ", tmp, hum)
        return tmp, hum
    end
end
