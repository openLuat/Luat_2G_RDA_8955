--- 模块功能：SSD 1306驱动芯片LCD命令配置
-- @author openLuat
-- @module ui.mono_std_spi_ssd1306
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

--[[
注意：disp库目前支持I2C接口和SPI接口的屏，此文件的配置，硬件上使用的是标准的SPI引脚，不是LCD专用的SPI引脚
硬件连线图如下：
Air模块 LCD
GND--地
SPI_CS--片选
SPI_CLK--时钟
SPI_DO--数据
SPI_DI--数据/命令选择
VDDIO--电源
UART1_CTS--复位
注意：Air202早期的开发板，UART1的CTS和RTS的丝印反了
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
        bus = disp.BUS_SPI, --led位标准SPI接口，不可修改
        yoffset = 32, --Y轴偏移
        hwfillcolor = 0x0, --填充色，黑色
        pinrst = pio.P0_3, --reset，复位引脚
        pinrs = pio.P0_12, --rs，命令/数据选择引脚
        --初始化命令
        initcmd =
        {
            0xAE, --display off
            0x20, --Set Memory Addressing Mode    
            0x10, --00,Horizontal Addressing Mode;01,Vertical Addressing Mode;10,Page Addressing Mode (RESET);11,Invalid
            0xb0, --Set Page Start Address for Page Addressing Mode,0-7
            0xc8, --Set COM Output Scan Direction
            0x00, --set low column address
            0x10, --set high column address
            0x60, --set start line address
            0x81, --set contrast control register
            0xdf, --
            0xa1, --set segment re-map 0 to 127
            0xa6, --set normal display
            0xa8, --set multiplex ratio(1 to 64)
            0x3f, --
            0xa4, --0xa4,Output follows RAM content;0xa5,Output ignores RAM content
            0xd3, --set display offset
            0x20, --not offset
            0xd5, --set display clock divide ratio/oscillator frequency
            0xf0, --set divide ratio
            0xd9, --set pre-charge period
            0x22, --
            0xda, --set com pins hardware configuration
            0x12, --
            0xdb, --set vcomh
            0x20, --0x20,0.77xVcc
            0x8d, --set DC-DC enable
            0x14, --
            0xaf, --turn on oled panel 
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

--控制SPI引脚的电压域
pmd.ldoset(6,pmd.LDO_VMMC)
init()
