--- 模块功能：串口功能测试(非TASK版，串口帧有自定义的结构)
-- @author openLuat
-- @module uart.testUart
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"utils"
require"pm"

--[[
功能定义：
uart按照帧结构接收外围设备的输入，收到正确的指令后，回复ASCII字符串

帧结构如下：
帧头：1字节，0x01表示扫描指令，0x02表示控制GPIO命令，0x03表示控制端口命令
帧体：字节不固定，跟帧头有关
帧尾：1字节，固定为0xC0

收到的指令帧头为0x01时，回复"CMD_SCANNER\r\n"给外围设备；例如接收到0x01 0xC0两个字节，就回复"CMD_SCANNER\r\n"
收到的指令帧头为0x02时，回复"CMD_GPIO\r\n"给外围设备；例如接收到0x02 0xC0两个字节，就回复"CMD_GPIO\r\n"
收到的指令帧头为0x03时，回复"CMD_PORT\r\n"给外围设备；例如接收到0x03 0xC0两个字节，就回复"CMD_PORT\r\n"
收到的指令帧头为其余数据时，回复"CMD_ERROR\r\n"给外围设备；例如接收到0x04 0xC0两个字节，就回复"CMD_ERROR\r\n"
]]


--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 1
--帧头类型以及帧尾
local CMD_SCANNER,CMD_GPIO,CMD_PORT,FRM_TAIL = 1,2,3,string.char(0xC0)
--串口读到的数据缓冲区
local rdbuf = ""


--[[
函数名：parse
功能  ：按照帧结构解析处理一条完整的帧数据
参数  ：
        data：所有未处理的数据
返回值：第一个返回值是一条完整帧报文的处理结果，第二个返回值是未处理的数据
]]
local function parse(data)
    if not data then return end    
    
    local tail = string.find(data,string.char(0xC0))
    if not tail then return false,data end    
    local cmdtyp = string.byte(data,1)
    local body,result = string.sub(data,2,tail-1)
    
    log.info("testUart.parse",data:toHex(),cmdtyp,body:toHex())
    
    if cmdtyp == CMD_SCANNER then
        write("CMD_SCANNER")
    elseif cmdtyp == CMD_GPIO then
        write("CMD_GPIO")
    elseif cmdtyp == CMD_PORT then
        write("CMD_PORT")
    else
        write("CMD_ERROR")
    end
    
    return true,string.sub(data,tail+1,-1)    
end

--[[
函数名：proc
功能  ：处理从串口读到的数据
参数  ：
        data：当前一次从串口读到的数据
返回值：无
]]
local function proc(data)
    if not data or string.len(data) == 0 then return end
    --追加到缓冲区
    rdbuf = rdbuf..data    
    
    local result,unproc
    unproc = rdbuf
    --根据帧结构循环解析未处理过的数据
    while true do
        result,unproc = parse(unproc)
        if not unproc or unproc == "" or not result then
            break
        end
    end

    rdbuf = unproc or ""
end

--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
    local data = ""
    --底层core中，串口收到数据时：
    --如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
    --如果接收缓冲器不为空，则不会通知Lua脚本
    --所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
    while true do        
        data = uart.read(UART_ID,"*l")
        if not data or string.len(data) == 0 then break end
        --打开下面的打印会耗时
        log.info("testUart.read bin",data)
        log.info("testUart.read hex",data:toHex())
        proc(data)
    end
end

--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
        s：要发送的数据
返回值：无
]]
function write(s)
    log.info("testUart.write",s)
    uart.write(UART_ID,s.."\r\n")
end

local function writeOk()
    log.info("testUart.writeOk")
end


--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("testUart")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("testUart")后，在不需要串口时调用pm.sleep("testUart")
pm.wake("testUart")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
uart.on(UART_ID,"receive",read)
--注册串口的数据发送通知函数
uart.on(UART_ID,"sent",writeOk)

--配置并且打开串口
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
--如果需要打开“串口发送数据完成后，通过异步消息通知”的功能，则使用下面的这行setup，注释掉上面的一行setup
--uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1,nil,1)
