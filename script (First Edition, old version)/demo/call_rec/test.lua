--[[
模块名称：通话测试
模块功能：测试呼入呼出
模块最后修改时间：2017.02.23
]]

module(...,package.seeall)
require"cc"
require"audio"
require"common"
require"record"
require"audiocore"


local RCD_READ_UNIT = 512
local rcdoffset,rcdsize,rcdcnt,rcdcur
local typ="incoming"
local total,cur

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("ljd test",...)
end

--[[
函数名：connected
功能  ：“通话已建立”消息处理函数
参数  ：无
返回值：无
]]
local function connected()
	print("connected")
	--5秒后播放TTS给对端，底层软件必须支持TTS功能
	--sys.timer_start(audio.play,5000,0,"TTSCC",common.binstohexs(common.gb2312toucs2("通话中播放TTS测试")),audiocore.VOL7)
	--50秒之后主动结束通话
	sys.timer_start(cc.hangup,50000,"AUTO_DISCONNECT")

    if typ=="outgoing" then
        print("connected play")
        audio.play(0,"FILE","/ldata/alarm.amr",audiocore.VOL3,playcb)
    end
end

--[[
函数名：disconnected
功能  ：“通话已结束”消息处理函数
参数  ：
		para：通话结束原因值
			  "LOCAL_HANG_UP"：用户主动调用cc.hangup接口挂断通话
			  "CALL_FAILED"：用户调用cc.dial接口呼出，at命令执行失败
			  "NO CARRIER"：呼叫无应答
			  "BUSY"：占线
			  "NO ANSWER"：呼叫无应答
返回值：无
]]
local function disconnected(para)
	print("disconnected:"..(para or "nil"))
	sys.timer_stop(cc.hangup,"AUTO_DISCONNECT")
    if typ=="incoming" then
    sys.timer_start(openrcd,3000)
    end
    typ=nil
end

function playcb(r)
	print("playcb",r)
	--删除录音文件
	--record.delete()
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
	local f,rt = io.open("/CallRec/rec001.wav","rb")
    --如果打开文件失败，返回内容为空“”
	if not f then print("getdata err：open") return "" end
	if not f:seek("set",offset) then print("getdata err：seek") return "" end
    --读取指定长度的数据
	rt = f:read(len)
	f:close()
	
	return rt or ""
end

--[[
函数名：getsize
功能  ：获取当前录音文件的总长度
参数  ：无
返回值：当前录音文件的总长度，单位是字节
]]
local function getsize()
	local f = io.open("/CallRec/rec001.wav","rb")
	if not f then print("getsize err：open") return 0 end
	local size = f:seek("end")
	if not size or size == 0 then print("getsize err：seek") return 0 end
	f:close()
    return size
end

function sndrcd()
    local data = getdata(rcdoffset,RCD_READ_UNIT)
    sys.dispatch("CMD_RCD_SEND",data)
end

function rcdsndcnf()
    print("rcdsndcnf:","rcdcur:",rcdcur,"rcdcnt:",rcdcnt)
    if rcdcur < rcdcnt then
        rcdcur = rcdcur+1
        rcdoffset = rcdoffset+(rcdcur-1)*RCD_READ_UNIT
        sndrcd()
    else
        print("rcdsnd finish")
        audio.play(0,"FILE","/CallRec/rec001.wav",audiocore.VOL3,playcb)
    end
end

function openrcd()
	print("openrcd:")
	
	rcdsize = getsize()
    rcdcnt = (rcdsize-1)/RCD_READ_UNIT+1
    rcdoffset,rcdcur = 0,1
    sndrcd()

    print("openrcd:","rcdsize:",rcdsize,"rcdcnt",rcdcnt)
    return 
end


--[[
函数名：incoming
功能  ：“来电”消息处理函数
参数  ：
		num：string类型，来电号码
返回值：无
]]
local function incoming(num)
	print("incoming:"..num)
	--接听来电
    typ="incoming"
	cc.accept()
    record.start(5)
end

local function ready()
	print("ready")
    ril.request("AT*EXASSERT=1")
    sys.timer_start(testdial,15000)
end

function testdial()
    typ="outgoing"
    cc.dial("18126324568")
end

local procer = {
	RCD_SEND_CNF = rcdsndcnf,
}
sys.regapp(procer)

--注册消息的用户回调函数
cc.regcb("INCOMING",incoming,"CONNECTED",connected,"READY",ready,"DISCONNECTED",disconnected)--"READY",ready,


