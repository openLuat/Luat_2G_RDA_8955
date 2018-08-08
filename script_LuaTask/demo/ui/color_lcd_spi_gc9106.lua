--- 模块功能：GC 9106驱动芯片LCD命令配置
-- @author openLuat
-- @module ui.color_lcd_spi_gc9106
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

--[[
注意：disp库目前支持I2C接口和SPI接口的屏，此文件的配置，硬件上使用的是LCD专用的SPI引脚，不是标准的SPI引脚
硬件连线图如下：
Air模块			LCD
GND-------------地
LCD_CS----------片选
LCD_CLK---------时钟
LCD_DATA--------数据
LCD_DC----------数据/命令选择
VDDIO-----------电源
LCD_RST---------复位
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
        height = 128, --分辨率高度，128像素；用户根据屏的参数自行修改
        bpp = 16, --位深度，彩屏仅支持16位
        bus = disp.BUS_SPI4LINE, --LCD专用SPI引脚接口，不可修改
        xoffset = 0, --X轴偏移
        yoffset = 32, --Y轴偏移
        freq = 13000000, --spi时钟频率，支持110K到13M（即110000到13000000）之间的整数（包含110000和13000000）
        pinrst = pio.P0_14, --reset，复位引脚
        pinrs = pio.P0_18, --rs，命令/数据选择引脚
        --初始化命令
        --前两个字节表示类型：0001表示延时，0000或者0002表示命令，0003表示数据
        --延时类型：后两个字节表示延时时间（单位毫秒）
        --命令类型：后两个字节命令的值
        --数据类型：后两个字节数据的值
        initcmd =
        {
            0xfe,
            0xef,
            0xb3,
            0x0030003,
            0x21,
            0x36,
            0x00300c8,
            0x3a,
            0x0030005,
            0xb4,
            0x0030021,
            0xF0,
            0x003002d,
            0x0030054,
            0x0030024,
            0x0030061,
            0x00300ab,
            0x003002e,
            0x003002f, 
            0x0030000,
            0x0030020,
            0x0030010,
            0x0030010,
            0x0030017,
            0x0030013,
            0x003000f, 
            0xF1,
            0x0030002,
            0x0030022,
            0x0030025,
            0x0030035,
            0x00300a8,
            0x0030008,
            0x0030008,
            0x0030000,
            0x0030000,
            0x0030009,
            0x0030009,
            0x0030017,
            0x0030018,
            0x003000f,
            0xfe,
            0xff,
            0x11,
            0x010078,
            0x29,
        },
        --休眠命令
        sleepcmd = {
            0x00020010,
        },
        --唤醒命令
        wakecmd = {
            0x00020011,
        }
    }
    disp.init(para)
    disp.clear()
    disp.update()
end

--控制SPI引脚的电压域
pmd.ldoset(6,pmd.LDO_VLCD)
init()
--打开背光
--实际使用时，用户根据自己的lcd背光控制方式，去修改背光控制代码
pmd.ldoset(6,pmd.KP_LEDR)
