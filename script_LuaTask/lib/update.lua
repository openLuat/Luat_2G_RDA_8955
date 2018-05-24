--- 模块功能：远程升级
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


local sUpdating,sCbFnc,sUrl,sPeriod

local function httpDownloadCbFnc(result,statusCode)
    log.info("update.httpDownloadCbFnc",result,statusCode,sCbFnc,sPeriod)
    sys.publish("UPDATE_DOWNLOAD",result,statusCode)
end

function clientTask()
    sUpdating = true
    --不要省略此处代码，否则下文中的misc.getImei有可能获取不到
    while not socket.isReady() do sys.waitUntil("IP_READY_IND") end
    while true do
    
        local retryCnt = 0
        while true do
            http.request("GET",
                     (sUrl or "iot.openluat.com/api/site/firmware_upgrade").."?project_key=".._G.PRODUCT_KEY
                            .."&imei="..misc.getImei().."&device_key="..misc.getSn()
                            .."&firmware_name=".._G.PROJECT.."_"..rtos.get_version().."&version=".._G.VERSION,
                     nil,nil,nil,60000,httpDownloadCbFnc,UPD_FILE_PATH)
                     
            local _,result,statusCode = sys.waitUntil("UPDATE_DOWNLOAD")
            if result then
                if statusCode=="200" then
                    if sCbFnc then
                        sCbFnc(true)
                    else
                        sys.restart("UPDATE_DOWNLOAD_SUCCESS")
                    end
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
        
        if sPeriod then
            sys.wait(sPeriod)
        else
            break
        end
    end
    sUpdating = false
end

--- 启动远程升级功能
-- @function cbFnc，可选，每次执行远程升级功能后的回调函数，回调函数的调用形式为：
-- cbFnc(result)，result为true表示升级包下载成功，其余表示下载失败
--
--如果没有设置此参数，则升级包下载成功后，会自动重启
-- @string url，可选，使用http的get命令下载升级包的url，如果没有设置此参数，默认使用Luat iot平台的url
--
-- 如果用户设置了url，注意：仅传入完整url的前半部分(如果有参数，即传入?前一部分)，http.lua会自动添加?以及后面的参数，例如：
--
-- 设置的url="www.userserver.com/api/site/firmware_upgrade"，则http.lua会在此url后面补充下面的参数
--
-- "?project_key=".._G.PRODUCT_KEY
-- .."&imei="..misc.getimei()
-- .."&device_key="..misc.getsn()
-- .."&firmware_name=".._G.PROJECT.."_"..rtos.get_version().."&version=".._G.VERSION
-- @number period，可选，单位毫秒，定时启动远程升级功能的间隔，如果没有设置此参数，仅执行一次远程升级功能
-- @return nil
-- @usage
-- update.request()
-- update.request(cbFnc)
-- update.request(cbFnc,"www.userserver.com/update")
-- update.request(cbFnc,nil,4*3600*1000)
function request(cbFnc,url,period)
    sCbFnc,sUrl,sPeriod = cbFnc,url,period
    if not sUpdating then        
        sys.taskInit(clientTask)
    end
end
