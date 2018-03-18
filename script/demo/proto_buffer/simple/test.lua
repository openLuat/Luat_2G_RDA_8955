local protobuf = require"protobuf"
require"common"
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

--注册proto描述文件
local pbFile = io.open("/ldata/addressbook.pb","rb")
local pbBuf = pbFile:read("*a")
pbFile:close()
protobuf.register(pbBuf)

local addressBook = 
{
	name = "Alice",
	id = 12345,
	phone = 
	{
		{number = "1301234567"},
		{number = "87654321", type = "WORK"},
		{number = "13912345678", type = "MOBILE"},
	},
	email = "username@domain.com"
}

--protobuf.encode：序列化接口
--protobuf.decode：反序列化接口

--使用protobuf.encode序列化，序列化后的二进制数据流以string类型赋值给encodeStr
local encodeStr = protobuf.encode("tutorial.Person", addressBook)
print("\tencodeStr",common.binstohexs(encodeStr))

--使用protobuf.decode反序列化，反序列化后的数据以table类型赋值给decodeTable
decodeTable = protobuf.decode("tutorial.Person", encodeStr)
decodeTable.profile.nick_name = "AHA"
decodeTable.profile.icon = "id:1"
print(string.format('\tid: %d, name: %s, email: %s', decodeTable.id, decodeTable.name, decodeTable.email))
if decodeTable.profile then
	print(string.format('\tnick_name: %s, icon: %s', decodeTable.profile.nick_name, decodeTable.profile.icon))
end
for k,v in ipairs(decodeTable.phone) do
	print(string.format("\tphone NO.%s: %s %s", k, v.number, v.type))
end
