--- 模块功能：时间同步.
-- 注意：本文件仅仅演示了基站同步和NTP同步两种方案，此两种方案都不是百分百可靠
-- 如果产品需要百分百时间同步，则建议使用自建服务器方案来实现
-- @author openLuat
module(...,package.seeall)

require"ril"
require"ntp"

local function printTime()
    local tClock = os.date("*t")
    log.info("printTime", 
        string.format("%04d-%02d-%02d %02d:%02d:%02d",tClock.year,tClock.month,tClock.day,tClock.hour,tClock.min,tClock.sec))
end

--每隔1秒输出1次当前模块系统时间
sys.timerLoopStart(printTime,1000)

--bTimeSyned ：时间是否已经成功同步过
local bTimeSyned

--发送AT+CLTS=1，打开基站同步时间功能
ril.request("AT+CLTS=1")
--注册基站时间同步的URC消息处理函数
ril.regUrc("*PSUTTZ", function()    
    log.info("cell.timeSync")
    printTime()    
    bTimeSyned = true
end)

--IP网络准备就绪后，如果基站尚未成功同步时间，则尝试使用NTP同步时间 
sys.subscribe("IP_READY_IND", function()
    if not bTimeSyned then                          
        ntp.timeSync(nil,function(tClock,success)        
            log.info("ntp.timeSync",success)
            printTime()
            bTimeSyned = success
        end)
    end 
end)

--如果NTP时间同步失败，并且存在用户自建服务器同步时间的方案，则自行实现自建服务器同步时间代码
