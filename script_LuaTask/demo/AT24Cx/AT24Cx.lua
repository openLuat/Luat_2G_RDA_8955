--- 模块功能：AT24Cx驱动代码
-- @module AT24Cx
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.8.9
module(..., package.seeall)

local mt = { __index = {} }

--- 创建一个AT24Cx的实例
-- @param i2cid i2c通道id
-- @param device_address AT24Cx的7位地址
-- @param capcity AT24Cx的字节容量，比如AT24C32的容量是4096字节
-- @param pagesize EEPROM的页大小
-- @return 返回AT24Cx的驱动实例
-- @usage local eeprom = AT24Cx.setup(2, 0x57, 4096, 32);
function setup(i2cid, device_address, capcity, pagesize)
    local o = {
        i2cid = i2cid,
        device_address = device_address,
        capcity = capcity,
        pagesize = pagesize
    }

    setmetatable(o, mt)
    return o
end

--- 往eeprom指定地址写入数据
-- @param address 起始地址
-- @param data 数据
-- @return 出错返回-1，正确返回写入的字节数
-- @usage local eeprom = AT24Cx.setup(2, 0x57, 4096, 32); print(eeprome:write(10, "123456"))
function mt.__index:write(address, data)
    local ending_address = address + data:len()
    if ending_address > self.capcity then ending_address = self.capcity end
    if i2c.setup(self.i2cid, i2c.SLOW) ~= i2c.SLOW then
        log.error('AT24Cx.write', 'i2c setup failed')
        return -1
    end
    local wrote_len = 0
    local bytes_to_write = 0
    while address < ending_address do
        bytes_to_write = self.pagesize - (address % self.pagesize)
        if wrote_len + bytes_to_write > data:len() then bytes_to_write = data:len() - wrote_len end
        if i2c.send(self.i2cid, self.device_address, pack.pack('>H', address) .. string.sub(data, wrote_len + 1, wrote_len + bytes_to_write)) ~= (bytes_to_write + 2) then
            log.error('AT24Cx.write', 'send address failed')
            break
        end
        address = address + bytes_to_write
        wrote_len = wrote_len + bytes_to_write
    end
    i2c.close(self.i2cid)
    return wrote_len
end

--- 从eeprom的指定地址读取指定长度的数据
-- @param address 读取地址
-- @param length 读取长度
-- @return 成功返回读取到的数据 错误返回nil
-- @usage local eeprom = AT24Cx.setup(2, 0x57, 4096, 32); print(eeprome:read(10, 6))
function mt.__index:read(address, length)
    if i2c.setup(self.i2cid, i2c.SLOW) ~= i2c.SLOW then
        log.error('AT24Cx.read', 'i2c setup failed')
        return
    end
    if i2c.send(self.i2cid, self.device_address, pack.pack('>H', address)) ~= 2 then
        log.error('AT24Cx.read', 'send address failed')
        i2c.close(self.i2cid)
        return
    end
    local data = i2c.recv(self.i2cid, self.device_address, length)
    i2c.close(self.i2cid)
    if data:len() ~= length then
        log.error('AT24Cx.read', 'read failed')
        return
    end
    return data
end
