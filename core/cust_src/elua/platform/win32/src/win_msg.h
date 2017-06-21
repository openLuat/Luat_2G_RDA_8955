
#ifndef _WIN_MSG_H_
#define _WIN_MSG_H_

#define DAEMON_TIMER_MSG_ID             (WM_USER+1)
#define SIMU_TIMER_MSG_ID               (WM_USER+2)
#define SIMU_UART_ATC_RX_DATA           (WM_USER+3)
#define SIMU_RTOS_MSG_ID                (WM_USER+4)

extern void SendToLuaShellMessage(const MSG *msg);

#endif