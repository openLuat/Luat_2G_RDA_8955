--- 模块功能：远程升级.
-- 参考 http://ask.openluat.com/article/916 加深对远程升级功能的理解
-- @module update
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.29

require "misc"
require "http"
require "log"
require "common"

module(..., package.seeall)

-- 升级包保存路径
local UPD_FILE_PATH = "/luazip/update.bin"


local sTaskId,sCbFnc,sUrl,sPeriod,SRedir,sLocation
local sPeriodWait
local sDownloading

local function httpDownloadCbFnc(result,statusCode,head)
    log.info("update.httpDownloadCbFnc",result,statusCode,head,sCbFnc,sPeriod)
    sys.publish("UPDATE_DOWNLOAD",result,statusCode,head)
end

function clientTask()
    --不要省略此处代码，否则下文中的misc.getImei有可能获取不到
    while not socket.isReady() do sys.waitUntil("IP_READY_IND") end
    while true do
    
        local retryCnt = 0
        sDownloading = true
        while true do
            os.remove(UPD_FILE_PATH)
            http.request("GET",
                     sLocation or ((sUrl or "iot.openluat.com/api/site/firmware_upgrade").."?project_key=".._G.PRODUCT_KEY
                            .."&imei="..misc.getImei().."&device_key="..misc.getSn()
                            .."&firmware_name=".._G.PROJECT.."_"..rtos.get_version().."&version=".._G.VERSION..(sRedir and "&need_oss_url=1" or "")),
                     nil,nil,nil,60000,httpDownloadCbFnc,UPD_FILE_PATH)
                     
            sPeriodWait = false
            local _,result,statusCode,head = sys.waitUntil("UPDATE_DOWNLOAD")
            if result then
                if statusCode=="200" then
                    if sCbFnc then
                        sCbFnc(true)
                    else
                        sys.restart("UPDATE_DOWNLOAD_SUCCESS")
                    end
                elseif statusCode:sub(1,1)=="3" and head and head["Location"] then
                    sLocation = head["Location"]
                    print("update.timerStart",head["Location"])
                    return sys.timerStart(request,2000)
                else
                    local fileSize = io.fileSize(UPD_FILE_PATH)
                    if fileSize>0 and fileSize<=200 then
                        local body = io.readFile(UPD_FILE_PATH)
                        local msg = body:match("\"msg\":%s*\"(.-)\"")
                        if msg and msg:len()<=200 then
                            log.warn("update.error",common.ucs2beToUtf8((msg:gsub("\\u","")):fromHex()))
                        end
                    end                    
                    os.remove(UPD_FILE_PATH)
                    if sCbFnc then sCbFnc(false) end
                end
                break
            else
                os.remove(UPD_FILE_PATH)
                retryCnt = retryCnt+1
                if retryCnt==3 then
                    if sCbFnc then sCbFnc(false) end
                    break
                end
            end
        end
        sDownloading = false
        
        if sPeriod then
            sPeriodWait = true
            sys.wait(sPeriod)
        else
            break
        end
    end
end

--- 启动远程升级功能
-- @function[opt=nil] cbFnc，每次执行远程升级功能后的回调函数，回调函数的调用形式为：
-- cbFnc(result)，result为true表示升级包下载成功，其余表示下载失败
--如果没有设置此参数，则升级包下载成功后，会自动重启
-- @string[opt=nil] url，使用http的get命令下载升级包的url，如果没有设置此参数，默认使用Luat iot平台的url
-- 如果用户设置了url，注意：仅传入完整url的前半部分(如果有参数，即传入?前一部分)，http.lua会自动添加?以及后面的参数，例如：
-- 设置的url="www.userserver.com/api/site/firmware_upgrade"，则http.lua会在此url后面补充下面的参数
-- "?project_key=".._G.PRODUCT_KEY
-- .."&imei="..misc.getimei()
-- .."&device_key="..misc.getsn()
-- .."&firmware_name=".._G.PROJECT.."_"..rtos.get_version().."&version=".._G.VERSION
-- 如果redir设置为true，还会补充.."&need_oss_url=1"
-- @number[opt=nil] period，单位毫秒，定时启动远程升级功能的间隔，如果没有设置此参数，仅执行一次远程升级功能
-- @bool[opt=nil] redir，是否访问重定向到阿里云的升级包，使用Luat提供的升级服务器时，此参数才有意义
-- 为了缓解Luat的升级服务器压力，从2018年7月11日起，在iot.openluat.com新增或者修改升级包的升级配置时，升级文件会备份一份到阿里云服务器
-- 如果此参数设置为true，会从阿里云服务器下载升级包；如果此参数设置为false或者nil，仍然从Luat的升级服务器下载升级包
-- @return nil
-- @usage
-- update.request()
-- update.request(cbFnc)
-- update.request(cbFnc,"www.userserver.com/update")
-- update.request(cbFnc,nil,4*3600*1000)
-- update.request(cbFnc,nil,4*3600*1000,true)
function request(cbFnc,url,period,redir)
    sCbFnc,sUrl,sPeriod,sRedir = cbFnc or sCbFnc,url or sUrl,period or sPeriod,sRedir or redir
    print("update.request",sCbFnc,sUrl,sPeriod,sRedir)
    if not sTaskId or coroutine.status(sTaskId)=="dead" then  
        sTaskId = sys.taskInit(clientTask)
    elseif period==nil and coroutine.status(sTaskId)=="suspended" and sPeriodWait then        
        coroutine.resume(sTaskId)
    end
end

function isDownloading()
    return sDownloading
end
