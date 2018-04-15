--[[
模块名称：数学库管理
模块功能：实现常用的数学库函数
模块最后修改时间：2017.02.14
]]
module("maths")

--[[
函数名：sqrt
功能  ：求平方根
参数  ：
		a：将要求平方根的数值，number类型
返回值：平方根，number类型的整数
]]
function sqrt(a)
	local x
	if a == 0 or a == 1 then return a end
	x=a/2
	for i=1,100 do
		x=(x+a/x)/2
	end
	return x
end
