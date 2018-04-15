--- 模块功能：proto buffer功能测试.
-- @author openLuat
-- @module protoBuffer.testProtoBuffer1
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

local protobuf = require"protobuf"
require"utils"

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
log.info("protobuf.encode",encodeStr:toHex())

--使用protobuf.decode反序列化，反序列化后的数据以table类型赋值给decodeTable
decodeTable = protobuf.decode("tutorial.Person", encodeStr)
decodeTable.profile.nick_name = "AHA"
decodeTable.profile.icon = "id:1"
log.info("protobuf.decode",string.format('\tid: %d, name: %s, email: %s', decodeTable.id, decodeTable.name, decodeTable.email))
if decodeTable.profile then
    log.info("protobuf.decode",string.format('\tnick_name: %s, icon: %s', decodeTable.profile.nick_name, decodeTable.profile.icon))
end
for k,v in ipairs(decodeTable.phone) do
    log.info("protobuf.decode",string.format("\tphone NO.%s: %s %s", k, v.number, v.type))
end
