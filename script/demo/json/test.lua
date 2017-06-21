module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

-----------------------encode测试------------------------
local torigin =
{
	KEY1 = "VALUE1",
	KEY2 = "VALUE2",
	KEY3 = "VALUE3",
	KEY4 = "VALUE4",
	KEY5 = {KEY5_1="VALU5_1",KEY5_2="VALU5_2"},
	KEY6 = {1,2,3},
}

local jsondata = json.encode(torigin)
print(jsondata)
-----------------------encode测试------------------------




-----------------------decode测试------------------------
--{"KEY3":"VALUE3","KEY4":"VALUE4","KEY2":"VALUE2","KEY1":"VALUE1","KEY5":{"KEY5_2":"VALU5_2","KEY5_1":"VALU5_1"}},"KEY6":[1,2,3]}
local origin = "{\"KEY3\":\"VALUE3\",\"KEY4\":\"VALUE4\",\"KEY2\":\"VALUE2\",\"KEY1\":\"VALUE1\",\"KEY5\":{\"KEY5_2\":\"VALU5_2\",\"KEY5_1\":\"VALU5_1\"},\"KEY6\":[1,2,3]}"
local tjsondata = json.decode(origin)
print(tjsondata["KEY1"])
print(tjsondata["KEY2"])
print(tjsondata["KEY3"])
print(tjsondata["KEY4"])
print(tjsondata["KEY5"]["KEY5_1"],tjsondata["KEY5"]["KEY5_2"])
print(tjsondata["KEY6"][1],tjsondata["KEY6"][2],tjsondata["KEY6"][3])
-----------------------decode测试------------------------

