--- 模块功能：SSD 1306驱动芯片LCD命令配置
-- @author openLuat
-- @module ui.mono_i2c_ssd1306
-- @license MIT
-- @copyright openLuat
-- @release 2018.07.03

--[[
注意：disp库目前支持I2C接口和SPI接口的屏，此文件的配置，硬件上使用的是I2C引脚
硬件连线图如下：
Air模块 LCD
GND--GND
SDA--SDA
SCL--SCL
VDDIO--VCC
注意：Air202早期的开发板，UART2的CTS和RTS的丝印反了（也就是说SCL和SDA是反的）
]]

module(...,package.seeall)

--[[
函数名：init
功能  ：初始化LCD参数
参数  ：无
返回值：无
]]
local function init()
    local para =
    {
        width = 128, --分辨率宽度，128像素；用户根据屏的参数自行修改
        height = 64, --分辨率高度，64像素；用户根据屏的参数自行修改
        bpp = 1, --位深度，1表示单色。单色屏就设置为1，不可修改
        bus = disp.BUS_I2C, --标准I2C接口，不可修改
        yoffset = 0, --Y轴偏移
        xoffset = 0, --X轴偏移
        hwfillcolor = 0x0, --填充色，黑色
        slave_addr = 0x3C,
        cmd_addr = 0x00,
        data_addr = 0x40,
        --初始化命令
        initcmd =
        {
            0xAE, --turn off oled panel
            0x02, --set low column address
            0x10, --set high column address
            0x40, --set start line address  Set Mapping RAM Display Start Line (0x00~0x3F)
            0x81, --set contrast control register
            0xCF, --et SEG Output Current Brightness
            0xA1, --Set SEG/Column Mapping     
            0xC8, --Set COM/Row Scan Direction   
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
            0x12,
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
        },
        --休眠命令
        sleepcmd = {
            0xAE,
        },
        --唤醒命令
        wakecmd = {
            0xAF,
        }
    }
    disp.init(para)
    disp.clear()
    disp.update()
end

init()

