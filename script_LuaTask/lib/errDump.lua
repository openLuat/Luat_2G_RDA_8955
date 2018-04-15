--- 模块功能：系统错误日志dump
-- @module errDump
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.09.26
module(..., package.seeall)

--lowPowerFun：用户自定义的“低电关机处理程序”
--lpring：是否已经启动自动关机定时器
local lowPowerFun, lpring
--错误信息文件以及错误信息内容
local LIB_ERR_FILE, libErr, extLibErr = "/lib_err.txt", ""


--- 获取LIB_ERR_FILE文件中的错误信息，给外部模块使用
-- @return string ,LIB_ERR_FILE文件中的错误信息
-- @usage errDump.getExtLibErr()
function getExtLibErr()
    return extLibErr or (readTxt(LIB_ERR_FILE) or "")
end

--- 读取文本文件中的全部内容
-- @string f：文件路径
-- @return string ,文本文件中的全部内容，读取失败为空字符串或者nil
-- @usage errDump.readTxt(LIB_ERR_FILE,libErr)
function readTxt(f)
    local file, rt = io.open(f, "r")
    if not file then log.info("errDump.readTxt", "no open:", f) return "" end
    rt = file:read("*a")
    file:close()
    return rt
end

--- 写文本文件
-- @string f：文件路径
-- @string v：要写入的文本内容
-- @return 无
-- @usage errDump.writeTxt(LIB_ERR_FILE,libErr)
local function writeTxt(f, v)
    local file = io.open(f, "w")
    if not file then log.info("errDump.writeTxt", "no open:", f) return end
    file:write(v)
    file:close()
end


--- 打印LIB_ERR_FILE文件中的错误信息
-- @return 无
-- @usage readTxt.initErr()
function initErr()
    extLibErr = readTxt(LIB_ERR_FILE) or ""
    log.info("errDump.initErr", extLibErr)
    --删除LIB_ERR_FILE文件
    os.remove(LIB_ERR_FILE)
end


--- 追加错误信息到LIB_ERR_FILE文件中
-- @param s：错误信息，用户自定义，一般是string类型，重启后的trace中会打印出此错误信息
-- @return 无
-- @usage readTxt.appendErr("net working timeout!")
function appendErr(s)
    log.info("errDump.appendErr", s)
    libErr = libErr .. s
    writeTxt(LIB_ERR_FILE, libErr)
end
