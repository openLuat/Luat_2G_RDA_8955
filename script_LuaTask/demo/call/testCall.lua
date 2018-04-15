--- 模块功能：通话功能测试.
-- @author openLuat
-- @module call.testCall
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.20

module(...,package.seeall)
require"cc"
require"audio"


--- “通话已建立”消息处理函数
-- @string num，建立通话的对方号码
-- @return 无
local function connected(num)
    log.info("testCall.connected")
    --发送DTMF到对端
    cc.sendDtmf("123")
    --5秒后播放TTS给对端，底层软件必须支持TTS功能
    sys.timerStart(audio.play,5000,0,"TTSCC","通话中播放TTS测试",7)
    --50秒之后主动结束通话
    sys.timerStart(cc.hangUp,50000,num)
end

--- “通话已结束”消息处理函数
-- @return 无
local function disconnected()
    log.info("testCall.disconnected")
    sys.timerStopAll(cc.hangUp)
end

--- “来电”消息处理函数
-- @string num，来电号码
-- @return 无
local function incoming(num)
    log.info("testCall.incoming:"..num)
    --接听来电
    cc.accept(num)
end

--- “通话功能模块准备就绪””消息处理函数
-- @return 无
local function ready()
    log.info("tesCall.ready")
    --呼叫10086
    cc.dial("10086")
end

--- “通话中收到对方的DTMF”消息处理函数
-- @string dtmf，收到的DTMF字符
-- @return 无
local function dtmfDetected(dtmf)
    log.info("testCall.dtmfDetected",dtmf)
end

--订阅消息的用户回调函数
sys.subscribe("CALL_READY",ready)
sys.subscribe("CALL_INCOMING",incoming)
sys.subscribe("CALL_CONNECTED",connected)
sys.subscribe("CALL_DISCONNECTED",disconnected)
cc.dtmfDetect(true)
sys.subscribe("CALL_DTMF_DETECT",dtmfDetected)
