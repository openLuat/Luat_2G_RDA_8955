--- 模块功能：proto buffer功能测试.
-- @author openLuat
-- @module protoBuffer.testProtoBuffer2
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

local protobuf = require"protobuf"
require"utils"

--注册proto描述文件
local pbFile = io.open("/ldata/tracker.pb","rb")
local pbBuf = pbFile:read("*a")
pbFile:close()
protobuf.register(pbBuf)

local logIn = 
{
    message_id = "DEV_LOGIN",
    log_in =
    {
        project_id = 29,
        project_name = "A9352_Luat_V0020_8955_SSL",
        script_version = "1.0.0",
        iccid = "8988512345678901",
        imsi = "460041111111111",
        heart_interval = 120,
    }
}

local locationGPS = 
{
    message_id = "DEV_LOCATION",
    location =
    {
        type = "DEV_TIMER_REPORT",
        gps_exist = true,
        gps_info =
        {
            longitude = 1211234567,
            latitude = 311234567,
            degree = 60,
            speed = 15,
            viewed_sates = 8,
        },
        status =
        {
            shake = false,
            charger = false,
            acc = false,
            gps = true,
            rssi = 28,
            vbat = 3950,
            charge_status = "NOT_CHARGE",
        },
    }
}

local locationLBS = 
{
    message_id = "DEV_LOCATION",
    location =
    {
        type = "SVR_QUERY_RSP",
        cell_exist = true,
        cell_info =
        {
            cells =
            {
                {lac_id=6311, cells={{mcc=460,mnc=0,cell_id=83751,cell_rssi=20}, {mcc=460,mnc=2,cell_id=88751,cell_rssi=18}}},
                {lac_id=6312, cells={{mcc=460,mnc=0,cell_id=83752,cell_rssi=20}, {mcc=460,mnc=2,cell_id=88752,cell_rssi=18}}},
            },
            ta = 1,
        },        
        status =
        {
            shake = true,
            charger = true,
            acc = true,
            gps = false,
            rssi = 20,
            vbat = 3850,
            charge_status = "CHARGING",
        },
    }
}

local function decodeAndPrint(encodeStream)
    --使用protobuf.decode反序列化
    --如果成功，反序列化后的数据以table类型赋值给decodeTable
    --如果失败，返回false
    local decodeTable = protobuf.decode("tracker.Client",encodeStream)
    log.info("protobuf.decodeTable",decodeTable)
    if decodeTable then
        log.info("protobuf.decode message_id",decodeTable.message_id,type(decodeTable.message_id))
        if decodeTable.message_id=="DEV_LOGIN" then
            log.info("protobuf.decode project_id",decodeTable.log_in.project_id)
            log.info("protobuf.decode project_name",decodeTable.log_in.project_name)
            log.info("protobuf.decode script_version",decodeTable.log_in.script_version)
            log.info("protobuf.decode iccid",decodeTable.log_in.iccid)
            log.info("protobuf.decode imsi",decodeTable.log_in.imsi)
            log.info("protobuf.decode heart_interval",decodeTable.log_in.heart_interval)
        elseif decodeTable.message_id=="DEV_LOCATION" then
            log.info("protobuf.decode type",decodeTable.location.type)
            
            if decodeTable.location.gps_exist then
                log.info("protobuf.decode gps_info longitude",decodeTable.location.gps_info.longitude)
                log.info("protobuf.decode gps_info latitude",decodeTable.location.gps_info.latitude)
                log.info("protobuf.decode gps_info degree",decodeTable.location.gps_info.degree)
                log.info("protobuf.decode gps_info speed",decodeTable.location.gps_info.speed)
                log.info("protobuf.decode gps_info viewed_sates",decodeTable.location.gps_info.viewed_sates)
            end
            
            if decodeTable.location.cell_exist then
                for k,v in ipairs(decodeTable.location.cell_info.cells) do
                    if type(v)=="table" then
                        log.info("protobuf.decode cell_info",k,"lac_id",v.lac_id)
                        if type(v.cells)=="table" then
                            for m,n in ipairs(v.cells) do
                                log.info("protobuf.decode cell_info",k,"cells",m,n.mcc,n.mnc,n.cell_id,n.cell_rssi)
                            end
                        end
                    end
                end
                log.info("protobuf.decode ta",decodeTable.location.cell_info.ta)
            end
            
            if type(decodeTable.location.status)=="table" then
                log.info("protobuf.decode status shake",decodeTable.location.status.shake)
                log.info("protobuf.decode status charger",decodeTable.location.status.charger)
                log.info("protobuf.decode status acc",decodeTable.location.status.acc)
                log.info("protobuf.decode status gps",decodeTable.location.status.gps)
                log.info("protobuf.decode status rssi",decodeTable.location.status.rssi)
                log.info("protobuf.decode status vbat",decodeTable.location.status.vbat)
                log.info("protobuf.decode status charge_status",decodeTable.location.status.charge_status)
            end
        end
    end
end

--使用protobuf.encode序列化，序列化后的二进制数据流以string类型赋值给encodeStr

--登录报文的封包和解包
local encodeStr = protobuf.encode("tracker.Client",logIn)
log.info("protobuf.encode logInStr",encodeStr:toHex())
decodeAndPrint(encodeStr)

--GPS位置报文的封包和解包
encodeStr = protobuf.encode("tracker.Client",locationGPS)
log.info("protobuf.encode locationGPSStr",encodeStr:toHex())
decodeAndPrint(encodeStr)

--LBS位置报文的封包和解包
encodeStr = protobuf.encode("tracker.Client",locationLBS)
log.info("protobuf.encode locationLBSStr",encodeStr:toHex())
decodeAndPrint(encodeStr)