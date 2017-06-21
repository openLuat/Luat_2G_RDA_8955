require"pins"
module(...,package.seeall)

--如下配置了开源模块中所有可用作GPIO的引脚，每个配置只是演示需要
--用户最终需根据自己的需求自行修改
--Air202的所有GPIO都支持中断

--pin值定义如下：
--pio.P0_XX：表示GPIOXX，例如pio.P0_15，表示GPIO15

--dir值定义如下（默认值为pio.OUTPUT）：
--pio.OUTPUT：表示输出，初始化是输出低电平
--pio.OUTPUT1：表示输出，初始化是输出高电平
--pio.INPUT：表示输入，需要轮询输入的电平状态
--pio.INT：表示中断，电平状态发生变化时会上报消息，进入本模块的intmsg函数

--valid值定义如下（默认值为1）：
--valid的值跟pins.lua中的set、get接口配合使用
--dir为输出时，配合pins.set接口使用，pins.set的第一个参数如果为true，则会输出valid值表示的电平，0表示低电平，1表示高电平
--dir为输入或中断时，配合get接口使用，如果引脚的电平和valid的值一致，get接口返回true；否则返回false
--dir为中断时，cb为中断引脚的回调函数，有中断产生时，如果配置了cb，会调用cb，如果产生中断的电平和valid的值相同，则cb(true)，否则cb(false)

--等价于PIN8 = {pin=pio.P0_1,dir=pio.OUTPUT,valid=1}
--第8个引脚：GPIO_1，配置为输出，初始化输出低电平；valid=1，调用pins.set(true,PIN8),则输出高电平，调用pins.set(false,PIN8),则输出低电平
PIN8 = {pin=pio.P0_1}

--第9个引脚：GPIO_0；配置为输出，初始化输出高电平；valid=0，调用pins.set(true,PIN9),则输出低电平，调用pins.set(false,PIN9),则输出高电平
PIN9 = {pin=pio.P0_0,dir=pio.OUTPUT1,valid=0}

--如下配置含义和PIN8相似
PIN6 = {pin=pio.P0_3}
PIN7 = {pin=pio.P0_2}
PIN12 = {pin=pio.P0_29}
PIN10 = {pin=pio.P0_31}
PIN11 = {pin=pio.P0_30}
--PIN27 = {pin=pio.P0_4}
PIN30 = {pin=pio.P0_7}
PIN2 = {pin=pio.P0_10}
PIN3 = {pin=pio.P0_8}
PIN4 = {pin=pio.P0_11}
PIN5 = {pin=pio.P0_12}


local function pin29cb(v)
	print("pin29cb",v)
end
--第29个引脚：GPIO_6；配置为中断；valid=1
--intcb表示中断管脚的中断处理函数，产生中断时，如果为高电平，则回调intcb(true)；如果为低电平，则回调intcb(false)
--调用pins.get(PIN29)时，如果为高电平，则返回true；如果为低电平，则返回false
PIN29 = {pin=pio.P0_6,dir=pio.INT,valid=1,intcb=pin29cb}


local function pin27cb(v)
	print("pin27cb",v)
end
PIN27 = {pin=pio.P0_4,dir=pio.INT,valid=1,intcb=pin27cb}


--第28个引脚：GPIO_5；配置为输入；valid=0
--调用pins.get(PIN28)时，如果为高电平，则返回false；如果为低电平，则返回true
PIN28 = {pin=pio.P0_5,dir=pio.INPUT,valid=0}

pins.reg(PIN8,PIN9,PIN6,PIN7,PIN12,PIN10,PIN11,PIN27,PIN28,PIN30,PIN2,PIN3,PIN4,PIN29,PIN5)
