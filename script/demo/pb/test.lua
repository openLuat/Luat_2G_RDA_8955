--[[
模块名称：电话本测试
模块功能：测试电话本读写
模块最后修改时间：2017.05.23
]]

module(...,package.seeall)
require"pb"

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--[[
函数名：storagecb
功能  ：设置电话本存储区域后的回调函数
参数  ：
		result：设置结果，true为成功，其余为失败
返回值：无
]]
local function storagecb(result)
	print("storagecb",result)
	--删除第1个位置的电话本记录
	pb.deleteitem(1,deletecb)
end

--[[
函数名：writecb
功能  ：写入一条电话本记录后的回调函数
参数  ：
		result：写入结果，true为成功，其余为失败
返回值：无
]]
function writecb(result)
	print("writecb",result)
	--读取第1个位置的电话本记录
	pb.read(1,readcb)
end

--[[
函数名：deletecb
功能  ：删除一条电话本记录后的回调函数
参数  ：
		result：删除结果，true为成功，其余为失败
返回值：无
]]
function deletecb(result)
	print("deletecb",result)
	--写入电话本记录到第1个位置
	pb.writeitem(1,"name1","11111111111",writecb)
end

--[[
函数名：readcb
功能  ：读取一条电话本记录后的回调函数
参数  ：
		result：读取结果，true为成功，其余为失败
		name：姓名
		number：号码		
返回值：无
]]
function readcb(result,name,number)
	print("readcb",result,name,number)
end


local function ready(result,name,number)
	print("ready",result)
	if result then
		sys.timer_stop(pb.read,1,ready)
		--设置电话本存储区域，SM表示sim卡存储，ME表示终端存储，打开下面2行中的1行测试即可
		pb.setstorage("SM",storagecb)
		--pb.setstorage("ME",storagecb)
	end
end

--循环定时器只是为了判断PB功能模块是否ready
sys.timer_loop_start(pb.read,2000,1,ready)
