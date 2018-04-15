--[[
模块名称：录音控制
模块功能：录音并且读取录音内容
模块最后修改时间：2017.04.05
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local rtos = require"rtos"
local audio = require"audio"
local sys = require"sys"
local ril = require"ril"
module(...)

--加载常用的全局函数至本地
local smatch = string.match
local print = base.print
local dispatch = sys.dispatch
local tonumber = base.tonumber
local assert = base.assert

--RCD_ID 录音文件编号
--RCD_FILE录音文件名
local RCD_ID,RCD_FILE = 1,"/RecDir/rec001"
--rcding：是否正在录音
--rcdcb：录音回调函数
--reading：是否正在读取录音
--duration：录音时长（毫秒）
local rcding,rcdcb,reading,duration

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上record前缀
参数  ：无
返回值：无
]]
local function print(...)
	base.print("record",...)
end

--[[
函数名：getdata
功能  ：获取录音文件指定位置起的指定长度数据
参数  ：
		offset：number类型，指定位置，取值范围是“0 到 文件长度-1”
        len：number类型，指定长度，如果设置的长度大于文件剩余的长度，则只能读取剩余的长度内容
返回值：指定的录音数据，如果读取失败，返回空字符串""
]]
function getdata(offset,len)
	local f,rt = io.open(RCD_FILE,"rb")
    --如果打开文件失败，返回内容为空“”
	if not f then print("getdata err：open") return "" end
	if not f:seek("set",offset) then print("getdata err：seek") return "" end
    --读取指定长度的数据
	rt = f:read(len)
	f:close()
	print("getdata",string.len(rt or ""))
	return rt or ""
end

--[[
函数名：getsize
功能  ：获取当前录音文件的总长度
参数  ：无
返回值：当前录音文件的总长度，单位是字节
]]
local function getsize()
	local f = io.open(RCD_FILE,"rb")
	if not f then print("getsize err：open") return 0 end
	local size = f:seek("end")
	if not size or size == 0 then print("getsize err：seek") return 0 end
	f:close()
    return size
end


--[[
函数名：rcdcnf
功能  ：AUDIO_RECORD_CNF消息处理函数
参数  ：suc，suc为true表示开始录音否则录音失败
返回值：无
]]
local function rcdcnf(suc)
	print("rcdcnf",suc)
	if suc then
		rcding = true
	else
		if rcdcb then rcdcb() end
	end
end


--[[
函数名：rcdind
功能  ：录音结束处理函数
参数  ：suc：true录音成功；false录音失败
返回值：true
]]
local function rcdind(suc,dur)
	print("rcdind",suc,dur,rcding)	
    --录音失败 或者 不应该产生录音结束的消息
	if not suc or not rcding then	
        --删除录音文件
		delete()
	end
	duration = dur
	if rcdcb then rcdcb(suc and rcding,getsize()) end
	rcding=false
end


--[[
函数名：start
功能  ：开始录音
参数  ：seconds：number类型，录音时长（单位秒）
        cb：function类型，录音回调函数，录音结束后，无论成功还是失败，都会调用cb函数
			调用方式为cb(result,size)，result为true表示成功，false或者nil为失败,size表示录音文件的大小（单位是字节）
返回值：无
]]
function start(seconds,cb)
	print("start",seconds,cb,rcding,reading)
	if seconds<=0 or seconds>50 then
		print("start err：seconds")
		if cb then cb() end
		return
	end
    --如果正在录音或者正在读取录音，则直接返回失败
	if rcding or reading then
		print("start err：ing")
		if cb then cb() end
		return
	end
	
	--设置正在录音标志
	rcding = true
	rcdcb = cb
    --删除以前的录音文件
	delete()
    --开始录音
	audio.beginrecord(RCD_ID,seconds*1000)
end

--[[
函数名：delete
功能  ：删除录音文件
参数  ：无
返回值：无
]]
function delete()
	os.remove(RCD_FILE)
end

--[[
函数名：getfilepath
功能  ：获取录音文件的路径
参数  ：无
返回值：录音文件的路径
]]
function getfilepath()
	return RCD_ID.."&"..(duration or "0")
end

local procer = {
	AUDIO_RECORD_CNF = rcdcnf,
	AUDIO_RECORD_IND = rcdind,
}
--注册本功能模块关注的消息处理函数
sys.regapp(procer)
