--- 模块功能：算法功能测试.
-- @author openLuat
-- @module crypto.testCrypto
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.20

module(...,package.seeall)

require"utils"

--[[
加解密算法结果，可对照
http://tool.oschina.net/encrypt?type=2
http://www.ip33.com/crc.html
http://tool.chacuo.net/cryptaes
进行测试
]]

local slen = string.len

--- base64加解密算法测试
-- @return 无
-- @usage base64Test()
local function base64Test()
    local originStr = "123456crypto.base64_encodemodule(...,package.seeall)sys.timerStart(test,5000)jdklasdjklaskdjklsa"
    local encodeStr = crypto.base64_encode(originStr,slen(originStr))
    log.info("testCrypto.base64_encode",encodeStr)
    log.info("testCrypto.base64_decode",crypto.base64_decode(encodeStr,slen(encodeStr)))
end

--- hmac_md5算法测试
-- @return 无
-- @usage hmacMd5Test()
local function hmacMd5Test()
    local originStr = "asdasdsadas"
    local signKey = "123456"
    log.info("testCrypto.hmac_md5",crypto.hmac_md5(originStr,slen(originStr),signKey,slen(signKey)))
end

--- md5算法测试
-- @return 无
-- @usage md5Test()
local function md5Test()
    --计算字符串的md5值
    local originStr = "sdfdsfdsfdsffdsfdsfsdfs1234"
    log.info("testCrypto.md5",crypto.md5(originStr,slen(originStr)))
    
    --计算文件的md5值(V0020版本后的lod才支持此功能)
    if tonumber(string.match(rtos.get_version(),"Luat_V(%d+)_"))>=20 then
        --crypto.md5，第一个参数为文件路径，第二个参数必须是"file"
        log.info("testCrypto.sys.lua md5",crypto.md5("/lua/sys.lua","file"))
    end    
end

--- hmac_sha1算法测试
-- @return 无
-- @usage hmacSha1Test()
local function hmacSha1Test()
    local originStr = "asdasdsadasweqcdsjghjvcb"
    local signKey = "12345689012345"
    log.info("testCrypto.hmac_sha1",crypto.hmac_sha1(originStr,slen(originStr),signKey,slen(signKey)))
end

--- sha1算法测试
-- @return 无
-- @usage sha1Test()
local function sha1Test()
    local originStr = "sdfdsfdsfdsffdsfdsfsdfs1234"
    log.info("testCrypto.sha1",crypto.sha1(originStr,slen(originStr)))
end

--- crc算法测试
-- @return 无
-- @usage crcTest()
local function crcTest()
    local originStr = "sdfdsfdsfdsffdsfdsfsdfs1234"
    log.info("testCrypto.crc16_modbus",string.format("%04X",crypto.crc16_modbus(originStr,slen(originStr))))
    log.info("testCrypto.crc32",string.format("%08X",crypto.crc32(originStr,slen(originStr))))
end

--- aes算法测试（参考http://tool.chacuo.net/cryptaes）
-- @return 无
-- @usage aesTest()
local function aesTest()
    --aes.encrypt和aes.decrypt接口测试(V0020版本后的lod才支持此功能)
    if tonumber(string.match(rtos.get_version(),"Luat_V(%d+)_"))>=20 then
        local originStr = "AES128 ECB ZeroPadding test"
        --加密模式：ECB；填充方式：ZeroPadding；密钥：1234567890123456；密钥长度：128 bit
        local encodeStr = crypto.aes_encrypt("ECB","ZERO",originStr,"1234567890123456")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","ZERO",encodeStr,"1234567890123456"))    
        
        originStr = "AES128 ECB Pkcs5Padding test"
        --加密模式：ECB；填充方式：Pkcs5Padding；密钥：1234567890123456；密钥长度：128 bit
        encodeStr = crypto.aes_encrypt("ECB","PKCS5",originStr,"1234567890123456")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","PKCS5",encodeStr,"1234567890123456"))    
        
        originStr = "AES128 ECB Pkcs7Padding test"
        --加密模式：ECB；填充方式：Pkcs7Padding；密钥：1234567890123456；密钥长度：128 bit
        encodeStr = crypto.aes_encrypt("ECB","PKCS7",originStr,"1234567890123456")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","PKCS7",encodeStr,"1234567890123456"))
        
        originStr = "AES192 ECB ZeroPadding test"    
        --加密模式：ECB；填充方式：ZeroPadding；密钥：123456789012345678901234；密钥长度：192 bit
        local encodeStr = crypto.aes_encrypt("ECB","ZERO",originStr,"123456789012345678901234")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","ZERO",encodeStr,"123456789012345678901234"))    
        
        originStr = "AES192 ECB Pkcs5Padding test"
        --加密模式：ECB；填充方式：Pkcs5Padding；密钥：123456789012345678901234；密钥长度：192 bit
        encodeStr = crypto.aes_encrypt("ECB","PKCS5",originStr,"123456789012345678901234")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","PKCS5",encodeStr,"123456789012345678901234"))    
        
        originStr = "AES192 ECB Pkcs7Padding test"
        --加密模式：ECB；填充方式：Pkcs7Padding；密钥：123456789012345678901234；密钥长度：192 bit
        encodeStr = crypto.aes_encrypt("ECB","PKCS7",originStr,"123456789012345678901234")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","PKCS7",encodeStr,"123456789012345678901234"))
        
        originStr = "AES256 ECB ZeroPadding test"    
        --加密模式：ECB；填充方式：ZeroPadding；密钥：12345678901234567890123456789012；密钥长度：256 bit
        local encodeStr = crypto.aes_encrypt("ECB","ZERO",originStr,"12345678901234567890123456789012")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","ZERO",encodeStr,"12345678901234567890123456789012"))    
        
        originStr = "AES256 ECB Pkcs5Padding test"
        --加密模式：ECB；填充方式：Pkcs5Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit
        encodeStr = crypto.aes_encrypt("ECB","PKCS5",originStr,"12345678901234567890123456789012")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","PKCS5",encodeStr,"12345678901234567890123456789012"))    
        
        originStr = "AES256 ECB Pkcs7Padding test"
        --加密模式：ECB；填充方式：Pkcs7Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit
        encodeStr = crypto.aes_encrypt("ECB","PKCS7",originStr,"12345678901234567890123456789012")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("ECB","PKCS7",encodeStr,"12345678901234567890123456789012"))
        
        
        
        
        
        originStr = "AES128 CBC ZeroPadding test"
        --加密模式：CBC；填充方式：ZeroPadding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        local encodeStr = crypto.aes_encrypt("CBC","ZERO",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","ZERO",encodeStr,"1234567890123456","1234567890666666"))    
        
        originStr = "AES128 CBC Pkcs5Padding test"
        --加密模式：CBC；填充方式：Pkcs5Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CBC","PKCS5",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","PKCS5",encodeStr,"1234567890123456","1234567890666666"))    
        
        originStr = "AES128 CBC Pkcs7Padding test"
        --加密模式：CBC；填充方式：Pkcs7Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CBC","PKCS7",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","PKCS7",encodeStr,"1234567890123456","1234567890666666"))
        
        originStr = "AES192 CBC ZeroPadding test"    
        --加密模式：CBC；填充方式：ZeroPadding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        local encodeStr = crypto.aes_encrypt("CBC","ZERO",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","ZERO",encodeStr,"123456789012345678901234","1234567890666666"))    
        
        originStr = "AES192 CBC Pkcs5Padding test"
        --加密模式：CBC；填充方式：Pkcs5Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CBC","PKCS5",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","PKCS5",encodeStr,"123456789012345678901234","1234567890666666"))    
        
        originStr = "AES192 CBC Pkcs7Padding test"
        --加密模式：CBC；填充方式：Pkcs7Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CBC","PKCS7",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","PKCS7",encodeStr,"123456789012345678901234","1234567890666666"))
        
        originStr = "AES256 CBC ZeroPadding test"    
        --加密模式：CBC；填充方式：ZeroPadding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        local encodeStr = crypto.aes_encrypt("CBC","ZERO",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","ZERO",encodeStr,"12345678901234567890123456789012","1234567890666666"))    
        
        originStr = "AES256 CBC Pkcs5Padding test"
        --加密模式：CBC；填充方式：Pkcs5Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CBC","PKCS5",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","PKCS5",encodeStr,"12345678901234567890123456789012","1234567890666666"))    
        
        originStr = "AES256 CBC Pkcs7Padding test"
        --加密模式：CBC；填充方式：Pkcs7Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CBC","PKCS7",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CBC","PKCS7",encodeStr,"12345678901234567890123456789012","1234567890666666"))

        
        
        
        
        originStr = "AES128 CTR ZeroPadding test"
        --加密模式：CTR；填充方式：ZeroPadding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        local encodeStr = crypto.aes_encrypt("CTR","ZERO",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","ZERO",encodeStr,"1234567890123456","1234567890666666"))    
        
        originStr = "AES128 CTR Pkcs5Padding test"
        --加密模式：CTR；填充方式：Pkcs5Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","PKCS5",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","PKCS5",encodeStr,"1234567890123456","1234567890666666"))    
        
        originStr = "AES128 CTR Pkcs7Padding test"
        --加密模式：CTR；填充方式：Pkcs7Padding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","PKCS7",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","PKCS7",encodeStr,"1234567890123456","1234567890666666"))
        
        originStr = "AES128 CTR NonePadding test"
        --加密模式：CTR；填充方式：NonePadding；密钥：1234567890123456；密钥长度：128 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","NONE",originStr,"1234567890123456","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","NONE",encodeStr,"1234567890123456","1234567890666666"))
        
        originStr = "AES192 CTR ZeroPadding test"    
        --加密模式：CTR；填充方式：ZeroPadding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        local encodeStr = crypto.aes_encrypt("CTR","ZERO",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","ZERO",encodeStr,"123456789012345678901234","1234567890666666"))    
        
        originStr = "AES192 CTR Pkcs5Padding test"
        --加密模式：CTR；填充方式：Pkcs5Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","PKCS5",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","PKCS5",encodeStr,"123456789012345678901234","1234567890666666"))    
        
        originStr = "AES192 CTR Pkcs7Padding test"
        --加密模式：CTR；填充方式：Pkcs7Padding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","PKCS7",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","PKCS7",encodeStr,"123456789012345678901234","1234567890666666"))
        
        originStr = "AES192 CTR NonePadding test"
        --加密模式：CTR；填充方式：NonePadding；密钥：123456789012345678901234；密钥长度：192 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","NONE",originStr,"123456789012345678901234","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","NONE",encodeStr,"123456789012345678901234","1234567890666666"))
        
        originStr = "AES256 CTR ZeroPadding test"    
        --加密模式：CTR；填充方式：ZeroPadding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        local encodeStr = crypto.aes_encrypt("CTR","ZERO",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","ZERO",encodeStr,"12345678901234567890123456789012","1234567890666666"))    
        
        originStr = "AES256 CTR Pkcs5Padding test"
        --加密模式：CTR；填充方式：Pkcs5Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","PKCS5",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","PKCS5",encodeStr,"12345678901234567890123456789012","1234567890666666"))    
        
        originStr = "AES256 CTR Pkcs7Padding test"
        --加密模式：CTR；填充方式：Pkcs7Padding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","PKCS7",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","PKCS7",encodeStr,"12345678901234567890123456789012","1234567890666666"))
        
        originStr = "AES256 CTR NonePadding test"
        --加密模式：CTR；填充方式：NonePadding；密钥：12345678901234567890123456789012；密钥长度：256 bit；偏移量：1234567890666666
        encodeStr = crypto.aes_encrypt("CTR","NONE",originStr,"12345678901234567890123456789012","1234567890666666")
        print(originStr,"encrypt",string.toHex(encodeStr))
        log.info("testCrypto.decrypt",crypto.aes_decrypt("CTR","NONE",encodeStr,"12345678901234567890123456789012","1234567890666666"))
    end
end

--- 算法测试入口
-- @return 无
-- @usage test()
local function test()
    base64Test()
    hmacMd5Test()
    md5Test()
    hmacSha1Test()
    sha1Test()
    crcTest()
    aesTest()
end

sys.timerStart(test,5000)
