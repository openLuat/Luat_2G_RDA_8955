--- 模块功能：W25Q32/BH25Q32驱动代码
-- @module SPIFlash
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.8.26

module(..., package.seeall)

local READ_ID = 0x90
local WRITE_ENABLE = 0x06
local READ_STATUS = 0x05
local FLASH_READ = 0x03
local ERASE_SECTOR_4K = 0x20
local BLOCK_ERASE_64K = 0xD8
local ERASE_CHIP = 0x60
local PAGE_PROGRAM = 0x02

local gpio_set = pio.pin.setval
local mt = { __index = {} }

local function address24bit(addr)
    return pack.pack('>I', addr):sub(2, 4)
end

--- 创建spi flash驱动实例
-- @param id spi id
-- @param cs spi cs管脚
-- @param timeout 等待flash busy状态解除的最长超时时间，默认60000ms
-- @return 返回spi flash驱动实例
-- @usage w25q32 = spiFlash.setup(spi.SPI_1, pio.P0_10)
function setup(id, cs, timeout)
    pmd.ldoset(6, pmd.LDO_VMMC)

    if not spi.setup(id, 0, 0, 8, 13000000, 1, 1) then
        log.error('BH25Q32.setup', 'spi setup failed')
    end

    pio.pin.close(cs)
    pio.pin.setdir(pio.OUTPUT, cs)
    pio.pin.setval(1, cs)

    local o = {
        id = id,
        cs = cs,
        timeout = timeout or 60000, -- ms
        pagesize = 256,
    }

    setmetatable(o, mt)
    return o
end

--- 释放spi flash驱动实例
-- @param
-- @return
-- @usage w25q32:close()
function mt.__index:close()
    pio.pin.close(self.cs)
    spi.close(self.id)
end

--- 读取flash id
-- @return manufactureID, deviceID 返回两个参数 厂商id，设备id
function mt.__index:readFlashID()
    gpio_set(0, self.cs)
    local r = spi.send_recv(self.id, pack.pack('bAA', READ_ID, address24bit(0), '\255\255'))
    gpio_set(1, self.cs)
    if r then
        return string.byte(r, 5, 6)
    else
        return false
    end
end

--- 读取flash状态寄存器 STATUS S0-S7
-- @return 返回flash状态寄存器bit0-bit7的值
function mt.__index:readStatus()
    gpio_set(0, self.cs)
    local r = spi.send_recv(self.id, string.char(READ_STATUS, 0xff))
    gpio_set(1, self.cs)
    return r and string.byte(r, 2)
end

--- 查询flash是否处于busy状态
-- @return true - 繁忙 false - 空闲
function mt.__index:busy()
    return self:readStatus() % 2 == 1
end

--- 等待flash空闲
-- @param timeout 超时时间 单位ms
--
function mt.__index:waitNotBusy(timeout)
    local status
    local step = 50
    local count = 0
    timeout = timeout or self.timeout
    while true do
        if not self:busy() then break end
        sys.wait(step)
        count = count + 1
        if count > timeout / step then
            log.error('BH25Q32.waitNotBusy', 'timeout')
            return false
        end
    end
    return true
end

--- 向spi flash 传输数据
-- @param send_data 要发送的数据
-- @param read_size 可选参数，需要读取的数据长度，如果是写指令，不填参数或者填0
-- @return nil - 失败 true - 写指令发送成功 string - 返回读取到的数据
function mt.__index:transfer(send_data, read_size)
    if not self:waitNotBusy() then return end

    if type(send_data) == 'number' then send_data = string.char(send_data) end
    if not read_size then read_size = 0 end

    if read_size == 0 then
        gpio_set(0, self.cs)
        spi.send_recv(self.id, string.char(WRITE_ENABLE))
        gpio_set(1, self.cs)
    end

    gpio_set(0, self.cs)
    local r = spi.send_recv(self.id, send_data .. string.rep('\255', read_size))
    gpio_set(1, self.cs)

    if read_size > 0 then
        return string.sub(r, send_data:len() + 1, -1)
    end

    return true
end

--- 读取spi flash 指定地址的数据
-- @param addr flash地址
-- @param len 长度
-- @return nil - 读取失败 string - 读取到的数据
-- @usage w25q32 = spiFlash.setup(spi.SPI_1, pio.P0_10); w25q32:read(0x1000, 6);
function mt.__index:read(addr, len)
    return self:transfer(string.char(FLASH_READ) .. address24bit(addr), len)
end

--- 按擦除sector（4K）的方式擦除指定地址的数据
-- @param addr 擦除的起始地址，会自动做4K对齐
-- @return true - 成功 false - 失败
function mt.__index:erase4K(addr)
    return self:transfer(string.char(ERASE_SECTOR_4K) .. address24bit(addr - addr % 0x1000)) and self:waitNotBusy()
end

--- 按擦除block 64K的方式擦除指定地址的数据
-- @param addr 擦除的起始地址，会自动做64K对齐
-- @return true - 成功 false - 失败
function mt.__index:erase64K(addr)
    return self:transfer(string.char(BLOCK_ERASE_64K) .. address24bit(addr - addr % 0x10000)) and self:waitNotBusy()
end

--- 擦除整个flash芯片的数据
-- @param 无
-- @return true - 成功 false - 失败
function mt.__index:eraseChip()
    return self:transfer(ERASE_CHIP) and self:waitNotBusy()
end

--- 向spi flash指定地址写入数据
-- @param address 写入的地址
-- @param data 数据
-- @return number - 成功写入的数据长度
function mt.__index:write(address, data)
    local ending_address = address + data:len()
    local wrote_len = 0
    local bytes_to_write = 0
    while address < ending_address do
        bytes_to_write = self.pagesize - (address % self.pagesize)
        if wrote_len + bytes_to_write > data:len() then bytes_to_write = data:len() - wrote_len end
        if not self:transfer(pack.pack('bAA', PAGE_PROGRAM, address24bit(address), data:sub(wrote_len + 1, wrote_len + bytes_to_write))) then
            break
        end
        address = address + bytes_to_write
        wrote_len = wrote_len + bytes_to_write
    end
    return wrote_len
end
