--[[
模块名称：电话本测试
模块功能：测试电话本读写
模块最后修改时间：2017.05.23
]]

module(...,package.seeall)
require"qrencode"

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("ljd test",...)
end

local function test_print()
	print("enter test_main.....")
end

local function test_main_obj()
    local qr_object = qrencode.create("/ldata/test1.jpg")

    print("test_main_obj create",qr_object)

    local wd,ht = qr_object:info()

    print("test_main_obj info",wd,ht)

    local buf = qr_object:buffer()

    print("test_main_obj buffer",buf)

   qr_object:destory()

    print("test_main_obj destory")
end


--循环定时器只是为了判断PB功能模块是否ready
sys.timer_loop_start(test_print,2000)

sys.timer_loop_start(test_main_obj,5000)
