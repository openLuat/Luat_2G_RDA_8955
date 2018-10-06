--- 模块功能：键盘测试
-- @module powerKey
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.06.13

require"audio"
module(..., package.seeall)


local keyName =
{
    ["00"] = "1",["10"] = "2",["20"] = "3",["30"] = "A",
    ["01"] = "4",["11"] = "5",["21"] = "6",["31"] = "B",
    ["02"] = "7",["12"] = "8",["22"] = "9",["32"] = "C",
    ["03"] = "*",["13"] = "0",["23"] = "#",["33"] = "D",
}


-- 按键消息处理函数
-- @table msg，按键消息体
--               msg.key_matrix_row：number类型，行信息
--               msg.key_matrix_col：number类型，列信息
--               msg.pressed：bool类型，true表示按下，false表示弹起
local function keyMsg(msg)
    log.info("keyMsg",msg.key_matrix_row,msg.key_matrix_col,keyName[msg.key_matrix_row..msg.key_matrix_col],msg.pressed)

    --按下
    if msg.pressed then
        sys.publish("KEY_PRESSED",keyName[msg.key_matrix_row..msg.key_matrix_col])
    --弹起
    else
        
    end
end

--注册按键消息的处理函数
rtos.on(rtos.MSG_KEYPAD,keyMsg)
--初始化键盘阵列
rtos.init_module(rtos.MOD_KEYPAD,0,0x0F,0x0F)
