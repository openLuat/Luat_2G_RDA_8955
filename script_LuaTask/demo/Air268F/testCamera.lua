--- 模块功能：camera功能测试.
-- @author openLuat
-- @module fs.testFs
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"pm"
require"scanCode"
require"utils"
require"audio"
require"http"
require"misc"

local WIDTH,HEIGHT = disp.getlcdinfo()
local DEFAULT_WIDTH,DEFAULT_HEIGHT = 240,320

-- 扫码结果回调函数
-- @bool result，true或者false，true表示扫码成功，false表示超时失败
-- @string[opt=nil] codeType，result为true时，表示扫码类型；result为false时，为nil；支持QR-Code和CODE-128两种类型
-- @string[opt=nil] codeStr，result为true时，表示扫码结果的字符串；result为false时，为nil
local function scanCodeCb(result,codeType,codeStr)
    --关闭摄像头预览
    disp.camerapreviewclose()
    --关闭摄像头
    disp.cameraclose()
    --允许系统休眠
    pm.sleep("testScanCode")
    --500毫秒后处理扫描结果
    sys.timerStart(function()
        --如果有LCD，显示扫描结果
        if WIDTH~=0 and HEIGHT~=0 then 
            disp.clear()
            if result then
                disp.puttext(common.utf8ToGb2312("扫描成功"),0,5)
                disp.puttext(common.utf8ToGb2312("类型：")..codeType,0,35)
                log.info("scanCodeCb",codeStr:toHex())
                disp.puttext(common.utf8ToGb2312("结果：")..codeStr,0,65)                
            else
                disp.puttext(common.utf8ToGb2312("扫描失败"),0,5)                
            end
            disp.update()
            
            sys.timerStart(windows.returnIdle,5000)
        end
        
        --TTS播报扫描结果
        audio.play(0,"TTS","扫描"..(result and "成功" or "失败"))
    end,500)
end

--扫码
function scan()
    --唤醒系统
    pm.wake("testScanCode")
    --设置扫码回调函数，默认10秒超时
    scanCode.request(scanCodeCb)
    --打开摄像头
    disp.cameraopen(1,1)
    --打开摄像头预览
    --如果有LCD，使用LCD的宽和高
    --如果无LCD，宽度设置为240像素，高度设置为320像素，240*320是Air268F支持的最大分辨率
    disp.camerapreview(0,0,0,0,WIDTH or DEFAULT_WIDTH,HEIGHT or DEFAULT_HEIGHT)
end

-- 采用multipart/form-data模式，上传照片文件
local function postMultipartFormData(url,cert,params,timeout,cbFnc)
    local boundary,body,k,v,kk,vv = "--------------------------"..os.time()..rtos.tick(),{}
    
    for k,v in pairs(params) do
        if k=="texts" then
            local bodyText = ""
            for kk,vv in pairs(v) do
                bodyText = bodyText.."--"..boundary.."\r\nContent-Disposition: form-data; name=\""..kk.."\"\r\n\r\n"..vv.."\r\n"
            end
            body[#body+1] = bodyText
        elseif k=="files" then
            local contentType =
            {
                jpg = "image/jpeg",
                jpeg = "image/jpeg",
                png = "image/png",                
            }
            for kk,vv in pairs(v) do
                print(kk,vv)
                body[#body+1] = "--"..boundary.."\r\nContent-Disposition: form-data; name=\""..kk.."\"; filename=\""..vv.."\"\r\nContent-Type: "..contentType[vv:match("%.(%w+)$")].."\r\n\r\n"
                body[#body+1] = {file = vv}
                body[#body+1] = "\r\n"
            end
        end
    end    
    body[#body+1] = "--"..boundary.."--\r\n"
        
    http.request(
        "POST",
        url,
        cert,
        {
            ["Content-Type"] = "multipart/form-data; boundary="..boundary,
            ["Connection"] = "keep-alive"
        },
        body,
        timeout,
        cbFnc
        )    
end

-- 上传照片任务
local function postPhoto()
    sys.taskInit(
        function()
            local retryCnt,RETRY_MAX_CNT = 0,3
            while true do
                postMultipartFormData(
                    "http://demo0.openluat.com/api/upload_img",
                    nil,
                    {
                        files =
                        {
                            ["img"] = "/testCamera.jpg"
                        }
                    },
                    60000,
                    function(result,statusCode) sys.publish("CAMERA_HTTP_POST_END",result,statusCode) end
                )
                
                local _,result,statusCode = sys.waitUntil("CAMERA_HTTP_POST_END")
                
                retryCnt = retryCnt+1
                if result or retryCnt>=RETRY_MAX_CNT then
                    disp.clear()
                    disp.puttext(common.utf8ToGb2312("上传"..((result and statusCode=="200") and "成功" or "失败")),0,35)
                    disp.update()
                    
                    audio.play(0,"TTS",("上传"..((result and statusCode=="200") and "成功" or "失败")))
                    
                    --5秒后自动返回提示界面
                    sys.timerStart(windows.returnIdle,5000)
                    break
                end
            end
        end
    )
    
end

-- 拍照
function takePhoto()
    --唤醒系统
    pm.wake("testTakePhoto")
    --打开摄像头
    disp.cameraopen(1,0,0)
    --打开摄像头预览
    --如果有LCD，使用LCD的宽和高
    --如果无LCD，宽度设置为240像素，高度设置为320像素，240*320是Air268F支持的最大分辨率
    disp.camerapreview(0,0,0,0,WIDTH or DEFAULT_WIDTH,HEIGHT or DEFAULT_HEIGHT)
    --设置照片的宽和高像素并且开始拍照
    --此处设置的宽和高和预览时的保持一致
    disp.cameracapture(WIDTH or DEFAULT_WIDTH,HEIGHT or DEFAULT_HEIGHT)
    --设置照片保存路径
    disp.camerasavephoto("/testCamera.jpg")
    log.info("testCamera.takePhoto fileSize",io.fileSize("/testCamera.jpg"))
    --关闭摄像头预览
    disp.camerapreviewclose()
    --关闭摄像头
    disp.cameraclose()
    --允许系统休眠
    pm.sleep("testTakePhoto")    
    --显示拍照图片    
    if WIDTH~=0 and HEIGHT~=0 then
        disp.clear()
        disp.putimage("/testCamera.jpg",0,0)
        disp.puttext(common.utf8ToGb2312("照片尺寸: "..io.fileSize("/testCamera.jpg")),0,5)
        disp.puttext(common.utf8ToGb2312("正在上传..."),0,35)
        disp.update()
    end   
    
    if false then
        --上传照片到服务器
        postPhoto()    
    else
        --5秒后自动返回提示界面
        if WIDTH~=0 and HEIGHT~=0 then
            sys.timerStart(windows.returnIdle,5000)
        end
    end
end
