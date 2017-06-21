--[[
模块名称：GPIO
模块功能：GPIO配置和操作
模块最后修改时间：2017.02.16
]]
require"pins"
module(...,package.seeall)

--虽然GSENSOR这个脚支持中断，但是中断会唤醒系统，增加功耗
--所以配置为输入方式，在gsensor.lua中去轮询此引脚状态
GSENSOR = {pin=pio.P0_3,dir=pio.INPUT,valid=0}
WATCHDOG = {pin=pio.P0_14,init=false,valid=0}
RST_SCMWD = {pin=pio.P0_12,defval=true,valid=1}

pins.reg(GSENSOR,WATCHDOG,RST_SCMWD)

