--- 模块功能：SSD1306驱动
-- @module SSD1306
-- @author 稀饭放姜
-- @license MIT
-- @copyright openLuat
-- @release 2017.10.17
module(..., package.seeall)

--- 初始化LCD屏幕
-- @number id, 端口号0-2
-- @number addr,从设备地址16进制,如0x3c
-- @return 无
-- @usage init()
function init(id, addr)
    local initcmd = {
        0xAE, --turn off oled panel
        0x02, --set low column address
        0x10, --set high column address
        0x40, --set start line address  Set Mapping RAM Display Start Line (0x00~0x3F)
        0x81, --set contrast control register
        0xCF, --et SEG Output Current Brightness
        0xA1, --Set SEG/Column Mapping     0xa0×óóò·′?? 0xa1?y3￡
        0xC8, --Set COM/Row Scan Direction   0xc0é???·′?? 0xc8?y3￡
        0xA6, --set normal display
        0xA8, --set multiplex ratio(1 to 64)
        0x3f, --1/64 duty
        0xD3, --set display offset	Shift Mapping RAM Counter (0x00~0x3F)
        0x00, --not offset
        0xd5, --set display clock divide ratio/oscillator frequency
        0x80, --set divide ratio, Set Clock as 100 Frames/Sec
        0xD9, --set pre-charge period
        0xF1, --Set Pre-Charge as 15 Clocks & Discharge as 1 Clock
        0xDA, --set com pins hardware configuration
        0x12;
        0xDB, --set vcomh
        0x40, --Set VCOM Deselect Level
        0x20, --Set Page Addressing Mode (0x00/0x01/0x02)
        0x02,
        0x8D, --set Charge Pump enable/disable
        0x14, --set(0x10) disable
        0xA4, --Disable Entire Display On (0xa4/0xa5)
        0xA6, --Disable Inverse Display On (0xa6/a7)
        0xAF, --turn on oled panel
        
        0xAF, --/*display ON*/
    }
    for i = 1, #initcmd do i2c.send(id, addr, {0x00, initcmd[i]}) end
    for i = 1, 8 do
        i2c.send(id, addr, {0x0, 0xb0 + i})
        i2c.send(id, addr, {0x0, 0x00})
        i2c.send(id, addr, {0x0, 0x10})
        for j = 1, 128 do
            i2c.send(id, addr, {0x40, 1})
        end
    end
end
