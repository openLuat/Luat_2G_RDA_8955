--- 模块功能：录音处理
-- @module record
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.11.23

require "log"
require "ril"
module(..., package.seeall)

local ID, FILE = 1, '/RecDir/rec001'
local recording
local stoping
local duration
local recordCallback
local flag_s=false

--- 开始录音
-- @param seconds 录音时长，单位：秒
-- @param cb 录音结果回调
-- @return result true - 开始录音 其他 - 失败
-- @usage result = record.start()
function start(seconds, cb)
    if recording or stoping or seconds <= 0 or seconds > 50 then
        log.error('record.start', recording, stoping, seconds)
        if cb then cb() end
        return
    end
    delete()
    duration = seconds * 1000
    ril.request("AT+AUDREC=0,0,1," .. ID .. "," .. duration)
    recording = true
    recordCallback = cb
    return true
end

--- 停止录音
-- @usage record.stop()
function stop()
    if not recording or stoping then return end
    ril.request("AT+AUDREC=0,0,0," .. ID .. "," .. duration)
    stoping = true
end

--- 读取录音文件的完整路径
-- @return string 录音文件的完整路径
-- @usage filePath = record.getFilePath()
function getFilePath()
    return FILE
end

--- 读取录音数据
-- @param offset 偏移位置
-- @param len 长度
-- @return data 录音数据
-- @usage data = record.getData(0, 1024)
function getData(offset, len)
    local f = io.open(FILE, "rb")
    if not f then log.error('record.getData', 'open failed') return "" end
    if not f:seek("set", offset) then log.error('record.getData', 'seek failed') f:close() return "" end
    local data = f:read(len)
    f:close()
    log.info("record.getData", data and data:len() or 0)
    return data or ""
end

--- 读取录音文件总长度，录音时长
-- @return fileSize 录音文件大小
-- @return duration 录音时长
-- @usage fileSize, duration = record.getSize()
function getSize()
    local size,duration = io.fileSize(FILE),0
    if size>6 then
        duration = ((size-6)-((size-6)%1600))/1600
    end
    return size, duration
end

--- 删除录音
-- @usage record.delete()
function delete()
    os.remove(FILE)
end

--- 判断是否存在录音
-- @return result true - 有录音 false - 无录音
-- @usage result = record.exists()
function exists()
    return io.exists(FILE)
end

--- 是否正在处理录音
-- @return result true - 正在处理 false - 空闲
-- @usage result = record.isBusy()
function isBusy()
    return recording or stoping
end

ril.regUrc("+AUDREC", function(data)
    local action, size = data:match("(%d),(%d+)")
    if action and size then
        size = tonumber(size)
        if action == "1" then
            local result = size > 0 and recording
            if not result then os.remove(FILE) size = 0 end
            duration = size
            if recordCallback then recordCallback(result, size) recordCallback = nil end
            recording = false
            stoping = false
        --录音播放相关
        elseif action=="2" then
            if size > 0 then
                if not flag_s then            
                    sys.publish("AUDIO_PLAY_END","SUCCESS")
                else
                    flag_s=false
                end
			else
			    sys.publish("AUDIO_PLAY_END","ERROR")
            end
        end
    end
end)
ril.regRsp("+AUDREC", function(cmd, success)
    local action = cmd:match("AUDREC=%d,%d,(%d)")
    if action == "1" then
        if not success then
            if recordCallback then
                recordCallback(false, 0)
                recordCallback = nil
            end
            recording = false
        end
    elseif action == '0' then
        if stoping and not success then stoping = false end -- 失败直接结束，成功则等到+AUDREC上报才判定停止录音成功
    --停止播放录音
    elseif action=="3" then
        flag_s=true
		sys.publish("AUDIO_STOP_END")
    end
end)
