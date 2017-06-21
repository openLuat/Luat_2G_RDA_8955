local msg = {}
local count = 0

-- 初始化keypad 使用键盘必须先初始化
rtos.init_module(rtos.MOD_KEYPAD, 0, 0x1f, 0x1f)

-- 启动定时器
rtos.timer_start(1, 1000)

while true do
    -- 阻塞等待 
    --msg = rtos.receive(rtos.INF_TIMEOUT)
    -- 超时等待
    msg = rtos.receive(2000) -- receive 消息接口 param1: timeout 以ms为单位
    
    -- timer消息处理 
    if(msg.id == rtos.MSG_TIMER) then  
    
        print("timer id: " .. msg.timer_id)
        
        if(1 == msg.timer_id) then 
           rtos.timer_start(2, 200)
        elseif 2 == msg.timer_id then
           rtos.timer_start(3, 3000)
        elseif 3 == msg.timer_id then
           -- nothing to do, just for test
        end
    
    -- uart/atc消息 通过msg.uart_id区分
    elseif msg.id == rtos.MSG_UART_RXDATA then 
    
        repeat
            s = uart.read(msg.uart_id, "*l", 0)
            print(s)
        until string.len(s) == 0
    
    -- 按键消息处理 目前有3个参数 状态与行列值 pressed row col
    elseif msg.id == rtos.MSG_KEYPAD then
    
        print(msg.pressed)
        print("key_matrix_row:" .. msg.key_matrix_row)
        print("key_matrix_col:" .. msg.key_matrix_col)
        
    -- 等待消息超时, 阻塞等待无需关注该消息
    elseif msg.id == rtos.WAIT_MSG_TIMEOUT then
    
        count = count+1
        print("rtos receive msg timeout count:" .. count)
                
    -- 其他消息
    else
        print("rtos.receive: msg id(" .. msg.id .. ")")
    end
end
