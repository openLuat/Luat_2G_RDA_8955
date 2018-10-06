
--- 验证spi flash驱动接口 目前该驱动兼容w25q32 bh25q32
require"spiFlash"

sys.taskInit(function()
    local spi_flash = spiFlash.setup(spi.SPI_1, pio.P0_10)
    print('spi flash id', spi_flash:readFlashID())
    print('spi flash erase 4K', spi_flash:erase4K(0x1000))
    print('spi flash write', spi_flash:write(0x1000, '123456'))
    print('spi flash read', spi_flash:read(0x1000, 6)) -- '123456'
end)
