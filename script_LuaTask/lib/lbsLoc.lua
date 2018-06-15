--- 模块功能：根据基站信息查询经纬度
-- @module lbsLoc
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.25

require"socket"
require"utils"
require"common"
require"misc"
module(..., package.seeall)

local function enCellInfo(s)
    local ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = "",{}
    log.info("lbsLoc.enCellInfo",s)
    for mcc,mnc,lac,ci,rssi in string.gmatch(s,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
        mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
        local handle = nil
        for k,v in pairs(t) do
            if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
                if #v.rssici < 8 then
                    table.insert(v.rssici,{rssi=rssi,ci=ci})
                end
                handle = true
                break
            end
        end
        if not handle then
            table.insert(t,{mcc=mcc,mnc=mnc,lac=lac,rssici={{rssi=rssi,ci=ci}}})
        end
    end
    for k,v in pairs(t) do
        ret = ret .. pack.pack(">HHb",v.lac,v.mcc,v.mnc)
        for m,n in pairs(v.rssici) do
            cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
            ret = ret .. pack.pack(">bH",cntrssi,n.ci)
        end
    end

    return string.char(#t)..ret
end

local function trans(str)
    local s = str
    if str:len()<10 then
        s = str..string.rep("0",10-str:len())
    end
	
    return s:sub(1,3).."."..s:sub(4,10)
end

local function taskClient(cbFnc,reqAddr,timeout,productKey,host,port,reqTime)
    while not socket.isReady() do
        if not sys.waitUntil("IP_READY_IND",timeout) then return cbFnc(1) end
    end
    
    local retryCnt,sck = 0
    local reqStr = pack.pack("bAbAAA",productKey:len(),productKey,(reqAddr and 2 or 0)+(reqTime and 4 or 0),"",common.numToBcdNum(misc.getImei()),enCellInfo(net.getCellInfoExt()))
    log.info("reqStr",reqStr:toHex())
    while true do
        sck = socket.udp()
        if sck:connect(host,port) then
            while true do
                if sck:send(reqStr) then
                    local result,data = sck:recv(5000)
                    if result then                        
                        sck:close()
                        log.info("lbcLoc receive",data:toHex())
                        if data:len()>=11 and data:byte(1)==0 then
                            cbFnc(0,
                                trans(common.bcdNumToNum(data:sub(2,6))),
                                trans(common.bcdNumToNum(data:sub(7,11))),
                                reqAddr and data:sub(13,12+data:byte(12)) or nil,
                                data:sub(reqAddr and (13+data:byte(12)) or 12,-1))
                        else
                            log.warn("lbsLoc.query","根据基站查询经纬度失败")
                            if data:byte(1)==2 then
                                log.warn("lbsLoc.query","main.lua中的PRODUCT_KEY和此设备在iot.openluat.com中所属项目的ProductKey必须一致，请去检查")
                            else
                                log.warn("lbsLoc.query","基站数据库查询不到所有小区的位置信息")
                                log.warn("lbsLoc.query","在trace中向上搜索encellinfo，然后在电脑浏览器中打开http://bs.openluat.com/，手动查找encellinfo后的所有小区位置")
                                log.warn("lbsLoc.query","如果手动可以查到位置，则服务器存在BUG，直接向技术人员反映问题")
                                log.warn("lbsLoc.query","如果手动无法查到位置，则基站数据库还没有收录当前设备的小区位置信息，向技术人员反馈，我们会尽快收录")
                            end
                            cbFnc(5)
                        end                        
                        return
                    else
                        sck:close()
                        retryCnt = retryCnt+1
                        if retryCnt>=3 then return cbFnc(4) end
                    end
                else
                    sck:close()
                    retryCnt = retryCnt+1
                    if retryCnt>=3 then return cbFnc(3) end
                    break
                end
            end
        else
            sck:close()
            retryCnt = retryCnt+1
            if retryCnt>=3 then return cbFnc(2) end
        end
    end    
end

--- 发送根据基站查询经纬度请求（仅支持中国区域的位置查询）
-- @function cbFnc，用户回调函数，回调函数的调用形式为：
--
--              cbFnc(result,lat,lng,addr)
--
--              result：number类型，0表示成功，1表示网络环境尚未就绪，2表示连接服务器失败，3表示发送数据失败，4表示接收服务器应答超时，5表示服务器返回查询失败；为0时，后面的3个参数才有意义
--
--              lat：string类型或者nil，纬度，整数部分3位，小数部分7位，例如"031.2425864"
--
--              lng：string类型或者nil，经度，整数部分3位，小数部分7位，例如"121.4736522"
--
--              addr：string类型，UCS2大端编码的位置字符串。调用lbsLoc.request时传入的第二个参数为true时，才返回本参数
-- @bool[opt=nil] reqAddr，是否需要服务器返回地址字符串信息，true返回，false或者nil不返回
-- @number[opt=20000] timeout，请求超时时间，单位毫秒，默认20000毫秒
-- @string[opt=nil] productKey，IOT网站上的产品证书，此参数可选，用户如果在main.lua中定义了PRODUCT_KEY变量，就不需要传入此参数
-- @string[opt=nil] host，服务器域名，此参数可选，目前仅lib中agps.lua使用此参数。用户脚本中不需要传入此参数
-- @string[opt=nil] port，服务器端口，此参数可选，目前仅lib中agps.lua使用此参数。用户脚本中不需要传入此参数
-- @bool[opt=nil] reqTime，是否需要服务器返回时间信息，true返回，false或者nil不返回，此参数可选，目前仅lib中agps.lua使用此参数。用户脚本中不需要传入此参数
-- @return nil
-- @usage lbsLoc.request(cbFnc)
-- @usage lbsLoc.request(cbFnc,true)
-- @usage lbsLoc.request(cbFnc,nil,20000)
function request(cbFnc,reqAddr,timeout,productKey,host,port,reqTime)
    assert(_G.PRODUCT_KEY or productKey,"undefine PRODUCT_KEY in main.lua")    
    sys.taskInit(taskClient,cbFnc,reqAddr,timeout or 20000,productKey or _G.PRODUCT_KEY,host or "bs.openluat.com",port or "12411",reqTime)
end

