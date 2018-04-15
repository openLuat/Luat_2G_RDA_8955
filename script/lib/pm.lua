--[[
模块名称：休眠管理（不是飞行模式）
模块功能：lua脚本应用的休眠控制
使用方式请参考：script/demo/pm
模块最后修改时间：2017.02.13
]]

--[[
关于休眠这一部分的说明：
目前的休眠处理有两种方式，
一种是底层core内部，自动处理，例如tcp发送或者接收数据时，会自动唤醒，发送接收结束后，会自动休眠；这部分不用lua脚本控制
另一种是lua脚本使用pm.sleep和pm.wake自行控制，例如，uart连接外围设备，uart接收数据前，要主动去pm.wake，这样才能保证前面接收的数据不出错，当不需要通信时，调用pm.sleep；如果有lcd的项目，也是同样道理
不休眠时功耗至少30mA左右
如果不是故意控制的不休眠，一定要保证pm.wake("A")了，有地方去调用pm.sleep("A")
]]

--定义模块,导入依赖库
local base = _G
local pmd = require"pmd"
local pairs = base.pairs
local assert = base.assert
module("pm")

--唤醒标记表
local tags = {}
--lua应用是否休眠，true休眠，其余没休眠
local flag = true

--[[
函数名：isleep
功能  ：读取lua应用的休眠状态
参数  ：无
返回值：true休眠，其余没休眠
]]
function isleep()
	return flag
end

--[[
函数名：wake
功能  ：lua应用唤醒系统
参数  ：
		tag：唤醒标记，用户自定义
返回值：无
]]
function wake(tag)
	assert(tag and tag~=nil,"pm.wake tag invalid")
	--唤醒表中此唤醒标记位置置1
	tags[tag] = 1
	--如果lua应用处于休眠状态
	if flag == true then
		--设置为唤醒状态
		flag = false
		--调用底层软件接口，真正唤醒系统
		pmd.sleep(0)
	end
end

--[[
函数名：sleep
功能  ：lua应用休眠系统
参数  ：
		tag：休眠标记，用户自定义，跟wake中的标记保持一致
返回值：无
]]
function sleep(tag)
	assert(tag and tag~=nil,"pm.sleep tag invalid")
	--唤醒表中此休眠标记位置置0
	tags[tag] = 0

	if tags[tag] < 0 then
		base.print("pm.sleep:error",tag)
		tags[tag] = 0
	end

	--只要存在任何一个标记唤醒,则不睡眠
	for k,v in pairs(tags) do
		if v > 0 then
			return
		end
	end

	flag = true
	----调用底层软件接口，真正休眠系统
	pmd.sleep(1)
end
