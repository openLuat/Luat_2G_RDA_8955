--- 模块功能：SPI接口的FLASH功能测试.
-- 以Waveshare W25Q128FV为例，读取FLASH ID
-- @author openLuat
-- @module spi.testSpiFlash
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"utils"

--[[
注意：此demo测试过程中，硬件上使用的是标准的SPI_1引脚
硬件连线图如下：
Air模块--flash模块
GND--GND
SPI_CS--CS
SPI_CLK--CLK
SPI_DO--DI
SPI_DI--DO
VDDIO--VCC
]]

local function readFlashID()
    --拉低CS开始传输数据
    pio.pin.setval(0,pio.P0_10)
    local recvStr = string.toHex(spi.send_recv(spi.SPI_1,string.fromHex("90000000ffff"))) --读取的值应该为00000000EF17
    log.info("testSpiFlash.readFlashID",recvStr)
    --传输结束拉高CS
    pio.pin.setval(1,pio.P0_10)
end

local function init()
    --打开SPI引脚的供电
    pmd.ldoset(6,pmd.LDO_VMMC) 
    
    --SPI 初始化
    local result = spi.setup(spi.SPI_1,0,0,8,110000,1,1)
    log.info("testSpiFlash.init",result)
    
    --重新配置GPIO10 (CS脚) 配为输出,默认高电平
    pio.pin.close(pio.P0_10)
    pio.pin.setdir(pio.OUTPUT,pio.P0_10)
    pio.pin.setval(1,pio.P0_10)
    
    sys.timerStart(readFlashID,5000)
end


sys.timerStart(init,5000)
