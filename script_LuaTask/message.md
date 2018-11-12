# LuaTask 库消息和注解

## audio

| 消息             | 参数      | 含义                   |
| ---------------- | --------- | ---------------------- |
| "AUDIO_PLAY_END" | "SUCCESS" | 播放结束--成功完成     |
| "AUDIO_PLAY_END" | "ERROR"   | 播放结束--播放失败     |
| "AUDIO_STOP_END" |           | 播放结束--播放停止     |
| "AUDIO_PLAY_END" | "STOP"    | 播放结束--停止音频播放 |

## cc

| 消息                | 参数 | 含义                              |
| ------------------- | ---- | --------------------------------- |
| "CALL_DTMF_DETECT"  | dtmf | 通话中DTMF解码消息,数据为dtmf字符 |
| "CALL_READY"        |      | 底层通话模块准备就绪              |
| "CALL_INCOMING"     |      | 有电话进来                        |
| "CALL_CONNECTED"    |      | 电话已接通                        |
| "CALL_DISCONNECTED" |      | 通话已挂断                        |

## errDump

| 消息                | 参数              | 含义                             |
| ------------------- | ----------------- | -------------------------------- |
| "ERRDUMP_HTTP_POST" | result,statusCode | 错误报告上报远端服务器返回的消息 |

## gps

| 消息        | 参数                | 含义                                           |
| ----------- | ------------------- | ---------------------------------------------- |
| "GPS_STATE" | "OPEN"              | GPS模块状态, GPS模块打开                       |
| "GPS_STATE" | "CLOSE",fixFlag     | GPS模块状态, GPS模块关闭的消息,参数2是定位状态 |
| "GPS_STATE" | "BINARY_CMD_ACK"    | GPS模块状态, 二进制指令ACK消息                 |
| "GPS_STATE" | "WRITE_EPH_ACK"     | GPS模块状态, 写星历指令返回消息                |
| "GPS_STATE" | "WRITE_EPH_END_ACK" | GPS模块状态, 写星历完成返回消息                |
| "GPS_STATE" | "LOCATION_SUCCESS"  | GPS模块状态, 定位成功的消息                    |
| "GPS_STATE" | "LOCATION_FAIL"     | GPS模块状态, 定位失败的消息                    |

## gpsv2

| 消息             | 参数 | 含义                                 |
| ---------------- | ---- | ------------------------------------ |
| "GPS_MSG_REPORT" |      | 定位成功后发布定位报告可以读取的消息 |
| "GPS_CLOSE_MSG"  |      | GPS模块关闭                          |

## link

| 消息            | 参数     | 含义                             |
| --------------- | -------- | -------------------------------- |
| "GPRS_ATTACH"   | attached | GPRS 附着状态,attached是附着状态 |
| "IP_READY_IND"  |          | GPRS 移动场景激活                |
| "IP_SHUT_IND"   |          | GPRS 移动场景激活失败            |
| "IP_ERROR_IND"  |          | GPRS PDP 去激活                  |
| "PDP_DEACT_IND" |          | GPRS PDP 去激活                  |

## misc

| 消息              | 参数 | 含义         |
| ----------------- | ---- | ------------ |
| "SN_READY_IND"    |      | SN可以读取   |
| "IMEI_READY_IND"  |      | IMEI可以读取 |
| "TIME_UPDATE_IND" |      | 模块校准完成 |

## net

| 消息                    | 参数          | 含义                                  |
| ----------------------- | ------------- | ------------------------------------- |
| "NET_STATE_REGISTERED"  |               | GSM 网络发生变化 注册成功             |
| "NET_STATE_UNREGISTER"  |               | GSM 网络发生变化 未注册成功           |
| "NET_CELL_CHANGED"      |               | CELL 发生变化                         |
| "CELL_INFO_IND"         |               | 读取到新的小区信息                    |
| "GSM_SIGNAL_REPORT_IND" | success, rssi | 读取到信号强度                        |
| "FLYMODE"               | flyMode       | 飞行模式发生变化,参数表示飞行模式状态 |

|## netLed

| 消息             | 参数 | 含义               |
| ---------------- | ---- | ------------------ |
| "NET_LED_UPDATE" |      | 网络指示灯状态更新 |

## ntp

| 消息          | 参数 | 含义             |
| ------------- | ---- | ---------------- |
| "NTP_SUCCEED" |      | NTP 时间同步成功 |

## nvm

| 消息                | 参数     | 含义                                    |
| ------------------- | -------- | --------------------------------------- |
| "PARA_CHANGED_IND"  | k,v,r    | 参数被改变,详见nvm.set(k,v,r,s)         |
| "TPARA_CHANGED_IND" | k,kk,v,r | 参数索引被改变,详见nvm.sett(k,kk,v,r,s) |


## record

| 消息             | 参数      | 含义         |
| ---------------- | --------- | ------------ |
| "AUDIO_PLAY_END" | "SUCCESS" | 录音播放成功 |
| "AUDIO_PLAY_END" | "ERROR"   | 录音播放失败 |
| "AUDIO_STOP_END" | "ERROR"   | 录音播放停止 |

## sim

| 消息              | 参数    | 含义           |
| ----------------- | ------- | -------------- |
| "SIM_IND"         | "RDY"   | SIM 已准备好   |
| "SIM_IND"         | "NORDY" | SIM 未准备好   |
| "SIM_IND"         | "NIST"  | SIM 未准备好   |
| "IMSI_READY"      |         | IMSI可以被读取 |
| "SIM_IND_SIM_PIN" |         | SIM卡PIN 开启  |

## SMS

| 消息              | 参数    | 含义                                     |
| ----------------- | ------- | ---------------------------------------- |
| "SMS_READY"       |         | 底层短信模块已经准备好                   |
| "SMS_SEND_CNF"    | success | 短信发送完成,success表示短信是否发送成功 |
| "SMS_DELETE_CNF"  | success | 短信删除,success表示短信是否删除成功     |
| "SMS_NEW_MSG_IND" | pos     | 收到新短信,pos为新短信内容               |

## update

| 消息              | 参数                   | 含义                                    |
| ----------------- | ---------------------- | --------------------------------------- |
| "UPDATE_DOWNLOAD" | result,statusCode,head | 更新的固件下载完成,参数表示返回的头信息 |