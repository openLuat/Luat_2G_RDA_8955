--- 模块功能：testLed
-- @module default
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.06.30
require "led"
require 'misc'
require "pins"
require "mqtt"
require "utils"
require 'AM2320'
require "update"
require "common"
require "lbsLoc"
require "mono_std_spi_ssd1306"

module(..., package.seeall)

-- 本地存储文件
local DEVICE_CONF = "/device.conf"
local SERVER_CONF = "/server.conf"
local demotype, demoext = "qrcode"
-- 上报遗言的json表
local willmsg = {cmd = "offline", type = "willmsg", imei = ''}
-- 服务器上报数据间隔时长，间隔期间用于阻塞读取服务器下发的指令
local timeout, datalink = 60 * 1000
-- MQTT服务器配置表
serverconf = {
    ip = "mqttluatboard.openluat.com",
    port = 1883,
    sub = "/luatask/demo/cmd/",
    pub = "/luatask/demo/rep/",
    keepalive = 60,
    lastwill = "/luatask/demo/offline/",
    uid = "",
    pwd = "",
    qos = 0,
}
function upServerConf(...)
    return json.encode(serverconf)
end
-- 上报json数据的基础表
local msg = {cmd = "", type = "", lat = "", lng = "", addr = "", ext = {}}
local function getlbs(result, lat, lng, addr)
    if result == 0 then
        msg.lat = lat
        msg.lng = lng
        msg.addr = common.ucs2beToUtf8(addr)
    end
end
sys.subscribe("IP_READY_IND", function()lbsLoc.request(getlbs, true, 30000, "0", "bs.openluat.com", "12412", true) end)
lbsLoc.request(getlbs, true)
function upStatus()
    local c = misc.getClock()
    msg.stamp = string.format('%04d%02d%02d%02d%02d%02d', c.year, c.month, c.day, c.hour, c.min, c.sec)
    msg.cmd = "demo"
    msg.type = demotype
    msg.softVer = _G.VERSION
    msg.lodVer = rtos.get_version()
    msg.csq = net.getRssi()
    return json.encode(msg)
end

-- disp.putqrcode(data, width, display_width, x, y) 显示二维码
-- @param data 从qrencode.encode返回的二维码数据
-- @param width 二维码数据的实际宽度
-- @param display_width 二维码实际显示宽度
-- @param x 二维码显示起始坐标x
-- @param y 二维码显示起始坐标y
--- 二维码显示函数
local function appQRCode(str)
    if str == nil or str == "" then str = 'http://www.openluat.com' end
    mono_std_spi_ssd1306.init(0xFFFF)
    -- qrencode.encode(string) 创建二维码信息
    -- @param string 二维码字符串
    -- @return width 生成的二维码信息宽度
    -- @return data 生成的二维码数据
    -- @usage local width, data = qrencode.encode("http://www.openluat.com")
    local width, data = qrencode.encode(str)
    --LCD分辨率的宽度和高度(单位是像素)
    local WIDTH, HEIGHT = disp.getlcdinfo()
    local displayWidth = width * ((WIDTH > HEIGHT and HEIGHT or WIDTH) / width)
    log.info("displayWidth value is:", displayWidth)
    local x, y = (WIDTH - displayWidth) / 2, (HEIGHT - displayWidth) / 2
    disp.clear()
    -- disp.drawrect(x - 1, y - 1, x + displayWidth + 1, y + displayWidth + 1, 0xffff)
    disp.putqrcode(data, width, displayWidth, x, y)
    disp.update()
end

-- 获取字符串显示的起始X坐标
local function getxpos(width, str)
    return (width - string.len(str) * 8) / 2
end
function uiDemo(str, str2, str3, str4)
    mono_std_spi_ssd1306.init(0x0)
    local WIDTH, HEIGHT = disp.getlcdinfo()
    disp.clear()
    if str == nil or str == "" or str == "logo" then
        if WIDTH == 128 and HEIGHT == 128 then
            --显示logo图片
            disp.putimage("/ldata/logo_" .. "mono.bmp")
        elseif WIDTH == 240 and HEIGHT == 320 then
            disp.puttext(common.utf8ToGb2312("欢迎使用Luat"), getxpos(WIDTH, common.utf8ToGb2312("欢迎使用Luat")), 10)
            --显示logo图片
            disp.putimage("/ldata/logo_color_240X320.png", 0, 80)
        else
            --从坐标16,0位置开始显示"欢迎使用Luat"
            -- disp.puttext(common.utf8ToGb2312("欢迎使用Luat"), getxpos(WIDTH, common.utf8ToGb2312("欢迎使用Luat")), 0)
            --显示logo图片
            disp.putimage("/ldata/logo_" .. "mono.bmp", 32, 0)
            disp.putimage("/ldata/logo_" .. "iot.bmp", 0, 32)
            disp.putimage("/ldata/logo_" .. "ram.bmp", 96, 32)
        end
    else
        -- disp.puttext(common.utf8ToGb2312("str"), lcd.getxpos(common.utf8ToGb2312("待机界面")), 0)
        disp.puttext(common.utf8ToGb2312(str), getxpos(WIDTH, common.utf8ToGb2312(str)), 0)
        if str2 ~= nil then disp.puttext(common.utf8ToGb2312(str2), getxpos(WIDTH, common.utf8ToGb2312(str2)), 16) end
        if str3 ~= nil then disp.puttext(common.utf8ToGb2312(str3), getxpos(WIDTH, common.utf8ToGb2312(str3)), 32) end
        if str4 ~= nil then disp.puttext(common.utf8ToGb2312(str4), getxpos(WIDTH, common.utf8ToGb2312(str4)), 48) end
    end
    --刷新LCD显示缓冲区到LCD屏幕上
    disp.update()
end
function clockDemo(...)
    mono_std_spi_ssd1306.init(0x0)
    local WIDTH, HEIGHT = disp.getlcdinfo()
    disp.clear()
    local c = misc.getClock()
    local date = string.format('%04d年%02d月%02d日', c.year, c.month, c.day)
    local time = string.format('%02d:%02d  星期%d', c.hour, c.min, misc.getWeek())
    disp.puttext(common.utf8ToGb2312(date), getxpos(WIDTH, common.utf8ToGb2312(date)), 4)
    disp.puttext(common.utf8ToGb2312(time), getxpos(WIDTH, common.utf8ToGb2312(time)), 24)
    disp.puttext(common.utf8ToGb2312("LuatBoard-Air202"), getxpos(WIDTH, common.utf8ToGb2312("LuatBoard-Air202")), 44)
    --刷新LCD显示缓冲区到LCD屏幕上
    disp.update()
end

-- NETLED指示灯任务
sys.taskInit(function()
    local ledpin = pins.setup(pio.P0_29, 1)
    -- pmd.ldoset(7, pmd.LDO_VMMC)
    while true do
        -- GSM注册中
        while not link.isReady() do
            led.blinkPwm(ledpin, 500, 500)
            sys.wait(100)
        end
        -- 网络附着中
        while datalink == 0 do
            led.blinkPwm(ledpin, 1000, 200)
            sys.wait(100)
        end
        -- 服务器已链接
        while datalink ~= 0 do
            -- 心跳包维持数据链接
            if datalink == 1 then
                led.blinkPwm(ledpin, 200, 2000)
            -- 发送数据中
            elseif datalink == 2 then
                led.blinkPwm(ledpin, 100, 100)
            end
            sys.wait(100)
        end
        sys.wait(1000)
    end
end)


sys.taskInit(function()
    local err_dog = 0
    while not socket.isReady() do if not sys.waitUntil('IP_READY_IND', 240 * 1000) then sys.restart("模块未能成功附着网络！") end end
    -- 创建MQTT客户端,客户端ID为IMEI号
    willmsg.imei = misc.getImei()
    local will = {qos = 1, retain = 1, topic = serverconf.lastwill, payload = json.encode(willmsg)}
    local mqttc = mqtt.client(misc.getImei(), serverconf.keepalive, serverconf.uid, serverconf.pwd, 1)
    local pub = string.format(serverconf.pub .. misc.getImei())
    local sub = string.format(serverconf.sub .. misc.getImei())
    while true do
        while not mqttc:connect(serverconf.ip, serverconf.port) do sys.wait(1000) end
        -- 初始化订阅主题
        datalink = 1 -- 数据指示常亮等待数据
        if mqttc:subscribe(sub, serverconf.qos) then
            datalink = 2 -- 数据发送指示快速闪烁
            if not mqttc:publish(pub, upStatus(), serverconf.qos) then break end
            log.info('upload is done!')
            datalink = 1 -- 数据指示灯常亮等待发送
            while true do
                -- 处理服务器的下发数据请求
                local r, packet = mqttc:receive(60 * 1000)-- 处理服务器下发指令
                if r then -- 这里是有数据下发的处理
                    datalink = 2 -- 数据接收指示灯快闪
                    local cnf, result, err = json.decode(packet.payload)
                    if result then
                        log.info("收到服务器下发指令:", packet.payload)
                        if cnf.cmd == 'read' then
                            if cnf.type == 'status' then
                                if not mqttc:publish(pub, upStatus(), serverconf.qos) then break end
                            elseif cnf.type == 'serverconf' then
                                if not mqttc:publish(pub, upServerConf(), serverconf.qos) then break end
                            end
                        elseif cnf.cmd == "syscmd" then
                            if cnf.type == "reboot" then
                                sys.restart("Server remote restart.")
                            elseif cnf.type == "onFly" then
                                net.switchFly(true)
                            else
                                net.switchFly(false)
                            end
                        elseif cnf.cmd == "demo" then
                            demotype, demoext = cnf.type, cnf.ext
                            sys.publish("RECV_CMD_DEMO")
                            if not mqttc:publish(pub, upStatus(), serverconf.qos) then break end
                        end
                    end
                elseif packet == 'timeout' then -- 服务器下发指令超时处理
                    datalink = 2 -- 数据发送指示快速闪烁
                    if not mqttc:publish(pub, upStatus(), serverconf.qos) then break end
                    datalink = 1 -- 数据指示灯常亮等待发送
                    log.info('MqttServer recv is timeout')
                else
                    log.info('The MQTTServer connection is broken.')
                    break
                end
                datalink = 1 -- 数据指示灯常亮等待发送
            end
        end
        mqttc:disconnect()
        err_dog = err_dog + 1
        if err_dog >= 5 then sys.restart("模块未能成功附着网络！") end
        datalink = 0 -- 服务器断开链接数据指示灯慢闪
        sys.wait(1000)
    end
end)
sys.taskInit(function()
    local io33 = pins.setup(pio.P1_1, 0)
    while true do
        if demotype == "ui" then
            log.info("------uiDemo代码正在运行-------")
            uiDemo(demoext)
            sys.waitUntil("RECV_CMD_DEMO")
        elseif demotype == "update" then
            log.info("------远程升级Demo代码正在运行-------")
            if demoext == "reboot" then
                update.request()
            else
                update.request(function()log.info("------远程升级Demo运行完成！-------") end)
            end
            sys.waitUntil("RECV_CMD_DEMO")
        elseif demotype == "i2c" then
            log.info("------i2cDemo代码正在运行-------")
            local temp, hum = AM2320.read(2, 0x5c)
            if not temp then temp, hum = 250, 300 end
            temp = temp / 10 .. "." .. temp % 10 .. "C"
            hum = hum / 10 .. "." .. hum % 10 .. "%"
            msg.ext.temp = temp
            msg.ext.hum = hum
            log.info("hmi ambient temperature and humidity:", temp, hum)
            local c = misc.getClock()
            local date = string.format('%04d年%02d月%02d日', c.year, c.month, c.day)
            uiDemo(date, "温度: " .. temp, "湿度: " .. hum, "LuatBoard-Air202")
            sys.waitUntil("RECV_CMD_DEMO", 10000)
        elseif demotype == "qrcode" then
            log.info("-----二维码Demo代码正在运行-------")
            appQRCode(demoext)
            sys.waitUntil("RECV_CMD_DEMO")
        elseif demotype == "audio" then
            log.info("-----播放mp3Demo代码正在运行-------")
            local file = "/ldata/" .. demoext .. ".mp3"
            if io.exists(file) then
                audio.play(0, "FILE", file, 7)
            end
            sys.waitUntil("RECV_CMD_DEMO", 1000)
        elseif demotype == "led" then
            log.info("-----LedDemo代码正在运行-------")
            ledDemo(demoext)
            sys.waitUntil("RECV_CMD_DEMO", 1000)
        elseif demotype == "lbs" then
            log.info("-----基站定位Demo代码正在运行-------")
            sys.publish('IP_READY_IND')
            uiDemo("经度:" .. msg.lng, "维度:" .. msg.lat, "地址:" .. msg.addr)
            sys.waitUntil("RECV_CMD_DEMO", 60000)
        elseif demotype == "ntp" then
            log.info("-----时间同步Demo代码正在运行-------")
            clockDemo()
            ntp.timeSync(1, function()log.info("----------------> AutoTimeSync is Done ! <----------------")sys.wait(1000)clockDemo() end)
            sys.waitUntil("RECV_CMD_DEMO", 60000)
        elseif demotype == "io" then
            log.info("-----远程控制Demo代码正在运行-------")
            io33(demoext)
            sys.waitUntil("RECV_CMD_DEMO", 1000)
        end
        sys.wait(10)
    end
end)

--- 闪烁灯任务
-- @return 无
-- @usage 每10秒自动切换到下一种指示灯状态
-- @usage 1、正常闪烁 500ms 亮灭
-- @usage 2、心跳灯,100ms亮，1.5秒灭
-- @usage 3、等级指示灯 闪4次，间隔1秒
-- @usage 4、呼吸灯
sys.taskInit(function()
    local ledpin = pins.setup(pio.P1_1, 0)
    while true do
        -- 正常闪烁指示灯 500ms亮 500ms灭
        for i = 1, 10 do
            led.blinkPwm(ledpin, 500, 500)
            sys.wait(10)
        end
        -- 心跳灯
        for i = 1, 10 do
            led.blinkPwm(ledpin, 100, 1500)
            sys.wait(10)
        end
        -- 等级指示灯
        for i = 1, 10 do
            led.levelLed(ledpin, 250, 250, 4, 1000)
            sys.wait(10)
        end
    end
end)
