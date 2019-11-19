--- host uart通讯参考代码

require "pm"

pm.wake('testHostUart') --- host uart通讯期间要退出系统睡眠状态

uart.setup(3, 921600, 8, uart.PAR_NONE, uart.STOP_1, 2) -- 配置为host uart透传模式

uart.on(3, 'receive', function()
    local s = uart.read(3, 1024)

    log.info('testHostUart', 'receive', s)

    uart.write(3, 'module host echo ' .. s)
end)
