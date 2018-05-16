module(...,package.seeall)

require"common"

--[[
加解密算法结果，可对照
http://tool.oschina.net/encrypt?type=2
http://www.ip33.com/crc.html
http://tool.chacuo.net/cryptaes
进行测试
]]

local slen = string.len

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上aliyuniot前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--[[
函数名：base64test
功能  ：base64加解密算法测试
参数  ：无
返回值：无
]]
local function base64test()
	local originstr = "123456crypto.base64_encodemodule(...,package.seeall)sys.timer_start(test,5000)jdklasdjklaskdjklsa"
	local encodestr = crypto.base64_encode(originstr,slen(originstr))
	print("base64_encode",encodestr)
	print("base64_decode",crypto.base64_decode(encodestr,slen(encodestr)))
end

--[[
函数名：hmacmd5test
功能  ：hmac_md5算法测试
参数  ：无
返回值：无
]]
local function hmacmd5test()
	local originstr = "asdasdsadas"
	local signkey = "123456"
	print("hmac_md5",crypto.hmac_md5(originstr,slen(originstr),signkey,slen(signkey)))
end

--[[
函数名：md5test
功能  ：md5算法测试
参数  ：无
返回值：无
]]
local function md5test()
	--计算字符串的md5值
	local originstr = "sdfdsfdsfdsffdsfdsfsdfs1234"
	print("md5",crypto.md5(originstr,slen(originstr)))
	
	--计算文件的md5值(V0020版本后的lod才支持此功能)
	if tonumber(string.match(sys.getcorever(),"Luat_V(%d+)_"))>=20 then
		--crypto.md5，第一个参数为文件路径，第二个参数必须是"file"
		print("sys.lua md5",crypto.md5("/lua/sys.lua","file"))
	end	
end

--[[
函数名：hmacsha1test
功能  ：hmac_sha1算法测试
参数  ：无
返回值：无
]]
local function hmacsha1test()
	local originstr = "asdasdsadasweqcdsjghjvcb"
	local signkey = "12345689012345"
	print("hmac_sha1",crypto.hmac_sha1(originstr,slen(originstr),signkey,slen(signkey)))
end

--[[
函数名：sha1test
功能  ：sha1算法测试
参数  ：无
返回值：无
]]
local function sha1test()
	local originstr = "sdfdsfdsfdsffdsfdsfsdfs1234"
	print("sha1",crypto.sha1(originstr,slen(originstr)))
end

--[[
函数名：crctest
功能  ：crc算法测试
参数  ：无
返回值：无
]]
local function crctest()
	local originstr = "sdfdsfdsfdsffdsfdsfsdfs1234"
	if tonumber(string.match(rtos.get_version(),"Luat_V(%d+)_"))>=21 then
		--crypto.crc16()第一个参数是校验方法，必须为以下几个；第二个参数为计算校验的字符串
		print("crc16_MODBUS",string.format("%04X",crypto.crc16("MODBUS",originstr)))
		print("crc16_IBM",string.format("%04X",crypto.crc16("IBM",originstr)))
		print("crc16_X25",string.format("%04X",crypto.crc16("X25",originstr)))
		print("crc16_MAXIM",string.format("%04X",crypto.crc16("MAXIM",originstr)))
		print("crc16_USB",string.format("%04X",crypto.crc16("USB",originstr)))
		print("crc16_CCITT",string.format("%04X",crypto.crc16("CCITT",originstr)))
		print("crc16_CCITT-FALSE",string.format("%04X",crypto.crc16("CCITT-FALSE",originstr)))
		print("crc16_XMODEM",string.format("%04X",crypto.crc16("XMODEM",originstr)))
		print("crc16_DNP",string.format("%04X",crypto.crc16("DNP",originstr)))
	end
	print("crc16_modbus",string.format("%04X",crypto.crc16_modbus(originstr,slen(originstr))))
	
	print("crc32",string.format("%08X",crypto.crc32(originstr,slen(originstr))))
end

--[[
函数名：aestest
功能  ：aes算法测试（参考http://tool.chacuo.net/cryptaes）
参数  ：无
返回值：无
]]
local function aestest()
	--aes.encrypt和aes.decrypt接口测试(V0020版本后的lod才支持此功能)
	if tonumber(string.match(sys.getcorever(),"Luat_V(%d+)_"))>=20 then
		local originStr = "AES128 ECB ZeroPadding test"
		--加密模式：ECB；填充方式：ZeroPadding；密钥：1234567890123456；密钥长度：128 bit
		local encodestr = crypto.aes_encrypt("ECB","ZERO",originStr,"1234567890123456")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","ZERO",encodestr,"1234567890123456"))	
		
		originStr = "AES128 ECB Pkcs5Padding test"
		--加密模式：ECB；填充方式：Pkcs5Padding；密钥：1234567890123456；密钥长度：128 bit
		encodestr = crypto.aes_encrypt("ECB","PKCS5",originStr,"1234567890123456")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","PKCS5",encodestr,"1234567890123456"))	
		
		originStr = "AES128 ECB Pkcs7Padding test"
		--加密模式：ECB；填充方式：Pkcs7Padding；密钥：1234567890123456；密钥长度：128 bit
		encodestr = crypto.aes_encrypt("ECB","PKCS7",originStr,"1234567890123456")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","PKCS7",encodestr,"1234567890123456"))
		
		originStr = "AES192 ECB ZeroPadding test"	
		--加密模式：ECB；填充方式：ZeroPadding；密钥：123456789012345678901234；密钥长度：192 bit
		local encodestr = crypto.aes_encrypt("ECB","ZERO",originStr,"123456789012345678901234")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","ZERO",encodestr,"123456789012345678901234"))	
		
		originStr = "AES192 ECB Pkcs5Padding test"
		--加密模式：ECB；填充方式：Pkcs5Padding；密钥：123456789012345678901234；密钥长度：192 bit
		encodestr = crypto.aes_encrypt("ECB","PKCS5",originStr,"123456789012345678901234")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","PKCS5",encodestr,"123456789012345678901234"))	
		
		originStr = "AES192 ECB Pkcs7Padding test"
		--加密模式：ECB；填充方式：Pkcs7Padding；密钥：123456789012345678901234；密钥长度：192 bit
		encodestr = crypto.aes_encrypt("ECB","PKCS7",originStr,"123456789012345678901234")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","PKCS7",encodestr,"123456789012345678901234"))
		
		originStr = "AES256 ECB ZeroPadding test"	
		--加密模式：ECB；填充方式：ZeroPadding；密钥：12345678901234567890123456789012；密钥长度：256 bit
		local encodestr = crypto.aes_encrypt("ECB","ZERO",originStr,"12345678901234567890123456789012")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","ZERO",encodestr,"12345678901234567890123456789012"))	
		
		originStr = "AES256 ECB Pkcs5Padding test"
		--加密模式：ECB；填充方式：Pkcs5Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit
		encodestr = crypto.aes_encrypt("ECB","PKCS5",originStr,"12345678901234567890123456789012")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","PKCS5",encodestr,"12345678901234567890123456789012"))	
		
		originStr = "AES256 ECB Pkcs7Padding test"
		--加密模式：ECB；填充方式：Pkcs7Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit
		encodestr = crypto.aes_encrypt("ECB","PKCS7",originStr,"12345678901234567890123456789012")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("ECB","PKCS7",encodestr,"12345678901234567890123456789012"))
		
		
		
		
		
		originStr = "AES128 CBC ZeroPadding test"
		--加密模式：CBC；填充方式：ZeroPadding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		local encodestr = crypto.aes_encrypt("CBC","ZERO",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","ZERO",encodestr,"1234567890123456","1234567890666666"))	
		
		originStr = "AES128 CBC Pkcs5Padding test"
		--加密模式：CBC；填充方式：Pkcs5Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CBC","PKCS5",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","PKCS5",encodestr,"1234567890123456","1234567890666666"))	
		
		originStr = "AES128 CBC Pkcs7Padding test"
		--加密模式：CBC；填充方式：Pkcs7Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CBC","PKCS7",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","PKCS7",encodestr,"1234567890123456","1234567890666666"))
		
		originStr = "AES192 CBC ZeroPadding test"	
		--加密模式：CBC；填充方式：ZeroPadding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		local encodestr = crypto.aes_encrypt("CBC","ZERO",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","ZERO",encodestr,"123456789012345678901234","1234567890666666"))	
		
		originStr = "AES192 CBC Pkcs5Padding test"
		--加密模式：CBC；填充方式：Pkcs5Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CBC","PKCS5",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","PKCS5",encodestr,"123456789012345678901234","1234567890666666"))	
		
		originStr = "AES192 CBC Pkcs7Padding test"
		--加密模式：CBC；填充方式：Pkcs7Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CBC","PKCS7",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","PKCS7",encodestr,"123456789012345678901234","1234567890666666"))
		
		originStr = "AES256 CBC ZeroPadding test"	
		--加密模式：CBC；填充方式：ZeroPadding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		local encodestr = crypto.aes_encrypt("CBC","ZERO",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","ZERO",encodestr,"12345678901234567890123456789012","1234567890666666"))	
		
		originStr = "AES256 CBC Pkcs5Padding test"
		--加密模式：CBC；填充方式：Pkcs5Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CBC","PKCS5",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","PKCS5",encodestr,"12345678901234567890123456789012","1234567890666666"))	
		
		originStr = "AES256 CBC Pkcs7Padding test"
		--加密模式：CBC；填充方式：Pkcs7Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CBC","PKCS7",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CBC","PKCS7",encodestr,"12345678901234567890123456789012","1234567890666666"))

		
		
		
		
		originStr = "AES128 CTR ZeroPadding test"
		--加密模式：CTR；填充方式：ZeroPadding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		local encodestr = crypto.aes_encrypt("CTR","ZERO",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","ZERO",encodestr,"1234567890123456","1234567890666666"))	
		
		originStr = "AES128 CTR Pkcs5Padding test"
		--加密模式：CTR；填充方式：Pkcs5Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","PKCS5",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","PKCS5",encodestr,"1234567890123456","1234567890666666"))	
		
		originStr = "AES128 CTR Pkcs7Padding test"
		--加密模式：CTR；填充方式：Pkcs7Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","PKCS7",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","PKCS7",encodestr,"1234567890123456","1234567890666666"))
		
		originStr = "AES128 CTR NonePadding test"
		--加密模式：CTR；填充方式：NonePadding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","NONE",originStr,"1234567890123456","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","NONE",encodestr,"1234567890123456","1234567890666666"))
		
		originStr = "AES192 CTR ZeroPadding test"	
		--加密模式：CTR；填充方式：ZeroPadding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		local encodestr = crypto.aes_encrypt("CTR","ZERO",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","ZERO",encodestr,"123456789012345678901234","1234567890666666"))	
		
		originStr = "AES192 CTR Pkcs5Padding test"
		--加密模式：CTR；填充方式：Pkcs5Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","PKCS5",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","PKCS5",encodestr,"123456789012345678901234","1234567890666666"))	
		
		originStr = "AES192 CTR Pkcs7Padding test"
		--加密模式：CTR；填充方式：Pkcs7Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","PKCS7",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","PKCS7",encodestr,"123456789012345678901234","1234567890666666"))
		
		originStr = "AES192 CTR NonePadding test"
		--加密模式：CTR；填充方式：NonePadding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","NONE",originStr,"123456789012345678901234","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","NONE",encodestr,"123456789012345678901234","1234567890666666"))
		
		originStr = "AES256 CTR ZeroPadding test"	
		--加密模式：CTR；填充方式：ZeroPadding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		local encodestr = crypto.aes_encrypt("CTR","ZERO",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","ZERO",encodestr,"12345678901234567890123456789012","1234567890666666"))	
		
		originStr = "AES256 CTR Pkcs5Padding test"
		--加密模式：CTR；填充方式：Pkcs5Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","PKCS5",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","PKCS5",encodestr,"12345678901234567890123456789012","1234567890666666"))	
		
		originStr = "AES256 CTR Pkcs7Padding test"
		--加密模式：CTR；填充方式：Pkcs7Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","PKCS7",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","PKCS7",encodestr,"12345678901234567890123456789012","1234567890666666"))
		
		originStr = "AES256 CTR NonePadding test"
		--加密模式：CTR；填充方式：NonePadding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
		encodestr = crypto.aes_encrypt("CTR","NONE",originStr,"12345678901234567890123456789012","1234567890666666")
		print(originStr,"encrypt",common.binstohexs(encodestr))
		print("decrypt",crypto.aes_decrypt("CTR","NONE",encodestr,"12345678901234567890123456789012","1234567890666666"))
	end
end

--[[
函数名：test
功能  ：算法测试入口
参数  ：无
返回值：无
]]
local function test()
	base64test()
	hmacmd5test()
	md5test()
	hmacsha1test()
	sha1test()
	crctest()
	aestest()
end

sys.timer_start(test,5000)
