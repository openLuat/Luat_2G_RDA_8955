local protobuf = require"protobuf"
require"common"
module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

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
	print("decodeTable",decodeTable)
	if decodeTable then
		print("decode message_id",decodeTable.message_id,type(decodeTable.message_id))
		if decodeTable.message_id=="DEV_LOGIN" then
			print("decode project_id",decodeTable.log_in.project_id)
			print("decode project_name",decodeTable.log_in.project_name)
			print("decode script_version",decodeTable.log_in.script_version)
			print("decode iccid",decodeTable.log_in.iccid)
			print("decode imsi",decodeTable.log_in.imsi)
			print("decode heart_interval",decodeTable.log_in.heart_interval)
		elseif decodeTable.message_id=="DEV_LOCATION" then
			print("decode type",decodeTable.location.type)
			
			if decodeTable.location.gps_exist then
				print("decode gps_info longitude",decodeTable.location.gps_info.longitude)
				print("decode gps_info latitude",decodeTable.location.gps_info.latitude)
				print("decode gps_info degree",decodeTable.location.gps_info.degree)
				print("decode gps_info speed",decodeTable.location.gps_info.speed)
				print("decode gps_info viewed_sates",decodeTable.location.gps_info.viewed_sates)
			end
			
			if decodeTable.location.cell_exist then
				for k,v in ipairs(decodeTable.location.cell_info.cells) do
					if type(v)=="table" then
						print("decode cell_info",k,"lac_id",v.lac_id)
						if type(v.cells)=="table" then
							for m,n in ipairs(v.cells) do
								print("decode cell_info",k,"cells",m,n.mcc,n.mnc,n.cell_id,n.cell_rssi)
							end
						end
					end
				end
				print("decode ta",decodeTable.location.cell_info.ta)
			end
			
			if type(decodeTable.location.status)=="table" then
				print("decode status shake",decodeTable.location.status.shake)
				print("decode status charger",decodeTable.location.status.charger)
				print("decode status acc",decodeTable.location.status.acc)
				print("decode status gps",decodeTable.location.status.gps)
				print("decode status rssi",decodeTable.location.status.rssi)
				print("decode status vbat",decodeTable.location.status.vbat)
				print("decode status charge_status",decodeTable.location.status.charge_status)
			end
		end
	end
end

--使用protobuf.encode序列化，序列化后的二进制数据流以string类型赋值给encodeStr

--登录报文的封包和解包
local encodeStr = protobuf.encode("tracker.Client",logIn)
print("logInStr",common.binstohexs(encodeStr))
decodeAndPrint(encodeStr)

--GPS位置报文的封包和解包
encodeStr = protobuf.encode("tracker.Client",locationGPS)
print("locationGPSStr",common.binstohexs(encodeStr))
decodeAndPrint(encodeStr)

--LBS位置报文的封包和解包
encodeStr = protobuf.encode("tracker.Client",locationLBS)
print("locationLBSStr",common.binstohexs(encodeStr))
decodeAndPrint(encodeStr)

