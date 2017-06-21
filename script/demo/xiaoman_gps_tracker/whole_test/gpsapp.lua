
module(...,package.seeall)
require"gps"
require"agps"

--UART2Íâ½ÓUBLOX GPSÄ£¿é
gps.init(nil,nil,true,1000,2,9600,8,uart.PAR_NONE,uart.STOP_1)
