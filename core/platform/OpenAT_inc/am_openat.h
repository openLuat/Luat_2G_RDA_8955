/*********************************************************
  Copyright (C), AirM2M Tech. Co., Ltd.
  Author: lifei
  Description: AMOPENAT 开放平台
  Others:
  History: 
    Version： Date:       Author:   Modification:
    V0.1      2012.12.14  lifei     创建文件
	V0.2      2012.12.26  brezen    添加pmd接口
	V0.3      2012.12.29  brezen    添加spi接口
	V0.4      2013.01.08  brezen    修改spi接口
	V0.5      2O13.01.14  brezen    1、增加黑白屏初始化参数
	                                2、增加黑白屏清屏接口
									3、减少黑白屏指令处理时间，满足单独使用指令刷屏
    V0.6      2013.01.14  brezen    修改黑白屏清屏接口参数
	V0.7      2013.01.15  brezen    修改黑白屏清屏接口参数
    V0.8      2013.01.17  brezen    1、添加系统电源控制接口 2、添加系统开关机接口
    V0.9      2013.01.23  brezen    修改SPI的编译warning  
    V1.0      2013.01.28  brezen    添加PSAM卡接口
    V1.1      2013.01.30  brezen    修改poweron_system函数参数
    V1.2      2013.02.06  Jack.li   添加摄像头接口
    V1.3      2013.02.07  Jack.li   添加视频录制、视频播放接口
    V1.4      2013.02.10  Jack.li   修改彩屏初始化接口
    V1.5      2013.02.26  brezen    添加enter_deepsleep/exit_deepsleep接口
    V1.6      2013.03.21  maliang    文件系统接口和播放音频文件接口的文件名改为unicode little ending类型
    V1.7      2013.04.03  Jack.li    增加I2C接口
    V1.8      2013.05.15  xc        增加tts接口
	V1.9      2013.07.18  brezen    添加set_dte_at_filter接口
	V2.0      2013.07.22  brezen    添加send_data_to_dte  send_data_to_ci set_dte_device接口
	V2.1      2013.08.20  brezen    针对PSAM卡双向认证失败，rw_psam添加分布发送参数stopClock
	V2.2      2013.09.16  brezen    添加flush_file接口，掉电之前强行写入flash
	V2.3      2013.09.24  brezen    添加NV接口
	V2.4      2013.09.26  brezen    支持两张PSAM卡
	V2.5      2013.12.30  brezen    添加蓝牙接口
	V2.6      2014.6.26   brezen    添加蓝牙spp接口
*********************************************************/
#ifndef AM_OPENAT_H
#define AM_OPENAT_H

#include "am_openat_system.h"
#include "am_openat_fs.h"
#include "am_openat_drv.h"
#include "am_openat_vat.h"
#include "am_openat_socket.h"

/*+\NEW\WZQ\2014.11.7\加入SSL RSA功能*/
#ifdef AM_OPENAT_SSL_RSA_SUPPORT
#include "openat_SSLRSA.h"
#endif
/*-\NEW\WZQ\2014.11.7\加入SSL RSA功能*/

typedef struct T_AMOPENAT_INTERFACE_VTBL_TAG
{
    /*******************************************
    **                 SYSTEM                 **
    *******************************************/
    /****************************** 线程接口 ******************************/
    HANDLE (*create_task)(                          /* 创建线程接口 */
                            PTASK_MAIN pTaskEntry,  /* 线程主函数 */
                            PVOID pParameter,       /* 作为参数传递给线程主函数 */
                            PVOID pStackAddr,       /* 线程栈地址，当前不支持，请传入NULL */
                            UINT16 nStackSize,      /* 线程栈大小 */
                            UINT8 nPriority,        /* 线程优先级，该参数越大，线程优先级越低 */
                            UINT16 nCreationFlags,  /* 线程启动标记， 请参考E_AMOPENAT_OS_CREATION_FLAG */
                            UINT16 nTimeSlice,      /* 暂时不支持，请传入0 */
                            PCHAR pTaskName         /* 线程名称 */
                          );
    VOID (*start_task)(                             /* 启动线程接口 */
                            HANDLE hTask,           /* 线程句柄，create_task接口返回值 */
                            PVOID pParameter        /* 作为参数传递给线程主函数，会替换create_task接口传入的pParameter参数 */
                      );
    VOID (*stop_task)(                              /* 停止线程接口 */
                            HANDLE hTask            /* 线程句柄，create_task接口返回值 */
                     );
    BOOL (*delete_task)(                            /* 删除线程接口 */
                            HANDLE hTask            /* 线程句柄，create_task接口返回值 */
                       );
    BOOL (*suspend_task)(                           /* 挂起线程接口 */
                            HANDLE hTask            /* 线程句柄，create_task接口返回值 */
                        );
    BOOL (*resume_task)(                            /* 恢复线程接口 */
                            HANDLE hTask            /* 线程句柄，create_task接口返回值 */
                       );
    HANDLE (*current_task)(                         /* 获取当前线程接口 */
                            VOID
                          );
    BOOL (*get_task_info)(                          /* 获取当前线程创建信息接口 */
                            HANDLE hTask,           /* 线程句柄，create_task接口返回值 */
                            T_AMOPENAT_TASK_INFO *pTaskInfo /* 线程信息存储接口 */
                         );

    /*+\NEW\WZQ\2014.11.10\开放sscanf接口*/
    int (*sscanf)(
        const char *buf, 
        const char *fmt, ...);
    /*-\NEW\WZQ\2014.11.10\开放sscanf接口*/

    /****************************** 线程消息队列接口 ******************************/
    BOOL (*wait_message)(                           /* 获取线程消息接口，阻塞接口 */
                            HANDLE hTask,           /* 线程句柄，create_task接口返回值 */
                            PVOID* ppMessage,       /* 存储消息指针 */
                            UINT32 nTimeOut         /* 等待消息超时时间，目前不支持 */
                        );
    BOOL (*send_message)(                           /* 发送消息接口，添加到消息队列尾部 */
                            HANDLE hTask,           /* 线程句柄，create_task接口返回值 */
                            PVOID pMessage          /* 存储消息指针 */
                        );
    BOOL (*send_high_priority_message)(             /* 发送高优先级消息接口，添加到消息队列头部 */
                            HANDLE hTask,           /* 线程句柄，create_task接口返回值 */
                            PVOID pMessage          /* 要发送消息指针 */
                                      );
    BOOL (*available_message)(                      /* 检测消息队列中是否有消息 */
                            HANDLE hTask            /* 线程句柄，create_task接口返回值 */
                             );

    /****************************** 时间&定时器接口 ******************************/
    HANDLE (*create_timer)(                         /* 创建定时器接口 */
                            PTIMER_EXPFUNC pFunc,   /* 定时器到时处理函数 */
                            PVOID pParameter        /* 作为参数传递给定时器到时处理函数 */
                          );
    BOOL (*start_timer)(                            /* 启动定时器接口 */
                            HANDLE hTimer,          /* 定时器句柄，create_timer接口返回值 */
                            UINT32 nMillisecondes   /* 定时器时间 */
                       );
    BOOL (*stop_timer)(                             /* 停止定时器接口 */
                            HANDLE hTimer           /* 定时器句柄，create_timer接口返回值 */
                      );
    BOOL (*delete_timer)(                           /* 删除定时器接口 */
                            HANDLE hTimer           /* 定时器句柄，create_timer接口返回值 */
                        );
    BOOL (*available_timer)(                        /* 检查定时器是否已经启动接口 */
                            HANDLE hTimer           /* 定时器句柄，create_timer接口返回值 */
                           );
    BOOL (*get_minute_tick)(                        /* minute indication infterface */
                            PMINUTE_TICKFUNC pFunc  /* if pFunc != NULL, one MINUTE interval timer will be started. else the timer will be stop */
                           );
    BOOL (*get_system_datetime)(                    /* 获取系统时间接口 */
                            T_AMOPENAT_SYSTEM_DATETIME* pDatetime/* 存储时间指针 */
                           );
    BOOL (*set_system_datetime)(                    /* 设置系统时间接口 */
                            T_AMOPENAT_SYSTEM_DATETIME* pDatetime/* 存储时间指针 */
                           );
    /****************************** ALARM接口 ******************************/
    BOOL (*init_alarm)(                                        /* 闹钟初始化接口 */
                            T_AMOPENAT_ALARM_CONFIG *pConfig   /* 闹钟配置参数 */
                       ); 
    BOOL (*set_alarm)(                                        /* 闹钟设置/删除接口 */
                            T_AMOPENAT_ALARM_PARAM *pAlarmSet    /* 闹钟设置参数 */
                       );
    /****************************** 临界资源接口 ******************************/
    HANDLE (*enter_critical_section)(               /* 进入临界资源区接口，关闭所有中断 */
                            VOID
                                    );
    VOID (*exit_critical_section)(                  /* 退出临界资源区接口，开启中断 */
                            HANDLE hSection         /* 临界资源区句柄，enter_critical_section接口返回值 */
                                 );
    /****************************** 信号量接口 ******************************/
    HANDLE (*create_semaphore)(                     /* 创建信号量接口 */
                            UINT32 nInitCount       /* 信号量数量 */
                              );
    BOOL (*delete_semaphore)(                       /* 删除信号量接口 */
                            HANDLE hSem             /* 信号量句柄，create_semaphore接口返回值 */
                            );
    BOOL (*wait_semaphore)(                         /* 获取信号量接口 */
                            HANDLE hSem,            /* 信号量句柄，create_semaphore接口返回值 */
                            UINT32 nTimeOut         /* 获取信号量超时时间，if nTimeOut < 5ms, means forever */
                          );
    BOOL (*release_semaphore)(
                            HANDLE hSem             /* 信号量句柄，create_semaphore接口返回值 */
                             );
    UINT32 (*get_semaphore_value)                   /* 获取消耗量值*/
                            (
                            HANDLE hSem             /* 信号量句柄，create_semaphore接口返回值 */  
                            );
    /****************************** 内存接口 ******************************/
    PVOID (*malloc)(                                /* 内存申请接口 */
                            UINT32 nSize            /* 申请的内存大小 */
                   );
    PVOID (*realloc)(                               /**/
                            PVOID pMemory,          /* 内存指针，malloc接口返回值 */
                            UINT32 nSize            /* 申请的内存大小 */
                    );
    VOID (*free)(                                   /* 内存释放接口 */
                            PVOID pMemory           /* 内存指针，malloc接口返回值 */
                );
    /****************************** 杂项接口 ******************************/
    BOOL (*sleep)(                                  /* 系统睡眠接口 */
                            UINT32 nMillisecondes   /* 睡眠时间 */
                 );
    UINT32 (*get_system_tick)(                      /* 获取系统tick接口 */
                            VOID
                             );
    UINT32 (*rand)(                                 /* 获取随机数接口 */
                            VOID
                  );
    VOID (*srand)(                                  /* 设置随机数种子接口 */
                            UINT32 seed             /* 随机数种子 */
                 );
    VOID (*shut_down)(                              /* 关机接口 */
                            VOID
                     );
    VOID (*restart)(                                /* 重启接口 */
                            VOID
                   );
/*+\NEW\liweiqiang\2013.7.1\[OpenAt]增加系统主频设置接口*/
    VOID (*sys_request_freq)(                       /* 主频控制接口 */
                            E_AMOPENAT_SYS_FREQ freq/* 主频值 */
                   );
/*-\NEW\liweiqiang\2013.7.1\[OpenAt]增加系统主频设置接口*/
    /*******************************************
    **              FILE SYSTEM               **
    *******************************************/
    INT32 (*open_file)(                             /* 打开文件接口 *//* 正常句柄返回值从0开始，小于0错误发生 */
/*+\BUG WM-719\maliang\2013.3.21\文件系统接口和播放音频文件接口的文件名改为unicode little ending类型*/
                            WCHAR* pszFileNameUniLe,/* 文件全路径名称 unicode little endian*/
                            UINT32 iFlag,           /* 打开标志 */
	                        UINT32 iAttr            /* 文件属性，暂时不支持，请填入0 */
                      );
    INT32 (*close_file)(                            /* 关闭文件接口 */
                            INT32 iFd               /* 文件句柄，open_file 或 create_file 返回的有效参数 */
                       );
    INT32 (*read_file)(                             /* 读取文件接口 */
                            INT32 iFd,              /* 文件句柄，open_file 或 create_file 返回的有效参数 */
                            UINT8 *pBuf,            /* 数据保存指针 */
                            UINT32 iLen             /* buf长度 */
                      );
    INT32 (*write_file)(                            /* 写入文件接口*/
                            INT32 iFd,              /* 文件句柄，open_file 或 create_file 返回的有效参数 */
                            UINT8 *pBuf,            /* 需要写入的数据指针 */
                            UINT32 iLen             /* 数据长度 */
                       );
    INT32 (*flush_file)(                            /* 立即写入flash*/
                            INT32 iFd               /* 文件句柄，open_file 或 create_file 返回的有效参数 */
                       );    
    INT32 (*seek_file)(                             /* 文件定位接口 */
                            INT32 iFd,              /* 文件句柄，open_file 或 create_file 返回的有效参数 */
                            INT32 iOffset,          /* 偏移量 */
                            UINT8 iOrigin           /* 偏移起始位置 */
                      );
    INT32 (*create_file)(                           /* 创建文件接口 */
                            WCHAR* pszFileNameUniLe,/* 文件全路径名称 unicode little endian*/
                            UINT32 iAttr            /* 文件属性，暂时不支持，请填入0 */
                        );
    INT32 (*delete_file)(                           /* 删除文件接口 */
                            WCHAR* pszFileNameUniLe/* 文件全路径名称 unicode little endian*/
                        );
    INT32 (*change_size)(
                        INT32 iFd,
                        UINT32 uSize
                    );
    INT32 (*change_dir)(                            /* 切换当前工作目录接口 */
                            WCHAR* pszDirNameUniLe  /* 目录路径 unicode little endian */
                       );
    INT32 (*make_dir)(                              /* 创建目录接口 */
                            WCHAR* pszDirNameUniLe, /* 目录路径 unicode little endian */
                            UINT32 iMode            /* 目录属性，详细请参见 E_AMOPENAT_FILE_ATTR */
                     );
    INT32 (*remove_dir)(                            /* 删除目录接口 *//* 该目录必须为空，接口才能返回成功 */
                            WCHAR* pszDirNameUniLe  /* 目录路径 unicode little endian */
                       );
    INT32 (*remove_dir_rec)(                        /* 递归删除目录接口 *//* 该目录下所有文件、目录都会被删除 */
                            WCHAR* pszDirNameUniLe  /* 目录路径 unicode little endian */
                           );
    INT32 (*get_current_dir)(                       /* 获取当前目录接口 */
                            WCHAR* pCurDirUniLe,    /* 存储目录信息 unicode little endian */
                            UINT32 uUnicodeSize     /* 存储目录信息空间大小 */
                            );
    INT32 (*find_first_file)(                       /* 查找文件接口 */
                            WCHAR* pszFileNameUniLe,/* 目录路径或文件全路径 unicode little endian */
/*-\BUG WM-719\maliang\2013.3.21\文件系统接口和播放音频文件接口的文件名改为unicode little ending类型*/
                            PAMOPENAT_FS_FIND_DATA  pFindData /* 查找结果数据 */
                            );
    INT32 (*find_next_file)(                        /* 继续查找文件接口 */
                            INT32 iFd,              /* 查找文件句柄，为 find_first_file 接口返回参数 */
                            PAMOPENAT_FS_FIND_DATA  pFindData /* 查找结果数据 */
                           );
    INT32 (*find_close)(                            /* 查找结束接口 */
                            INT32 iFd               /* 查找文件句柄，为 find_first_file 接口返回参数 */
                       );
/*+\NewReq WM-743\maliang\2013.3.28\[OpenAt]增加接口获取文件系统信息*/
    INT32 (*get_fs_info)(                            /* 获取文件系统信息接口 */
                            E_AMOPENAT_FILE_DEVICE_NAME       devName,            /*获取哪块device name的信息*/
                            T_AMOPENAT_FILE_INFO               *fileInfo                   /*文件系统的信息*/
                       );
/*-\NewReq WM-743\maliang\2013.3.28\[OpenAt]增加接口获取文件系统信息*/
    
    /*+\NewReq\Jack.li\2013.1.17\增加T卡接口*/
    INT32 (*init_tflash)(                            /* 初始化T卡接口 */
                            PAMOPENAT_TFLASH_INIT_PARAM pTlashInitParam/* T卡初始化参数 */
                       );
    /*-\NewReq\Jack.li\2013.1.17\增加T卡接口*/

    E_AMOPENAT_MEMD_ERR (*flash_erase)(              /*flash擦写 64K对齐*/
                            UINT32 startAddr,
                            UINT32 endAddr
                       );
    E_AMOPENAT_MEMD_ERR (*flash_write)(              /*写flash*/
                            UINT32 startAddr,
                            UINT32 size,
                            UINT32* writenSize,
                            CONST UINT8* buf
                       );
    E_AMOPENAT_MEMD_ERR (*flash_read)(               /*读flash*/
                            UINT32 startAddr,
                            UINT32 size,
                            UINT32* readSize,
                            UINT8* buf
                       );
    
    /*******************************************
    **                 NV                     **
    *******************************************/    
    /*因为下面的接口会直接操作flash，会引起系统阻塞，不要在中断或者要求比较高的TASK中运行*/    
    INT32 (*nv_init)(                                /*NV 初始化接口*/
                      UINT32 addr1,                  /*NV 存放地址1 4KByte地址对齐 大小4KByte*/
                      UINT32 addr2                   /*NV 存放地址2 4KByte地址对齐 大小4KByte*/
                    );

    INT32 (*nv_add)(                                 /*增加一个NV存储区域*/
                      UINT32 nv_id,                  /*NV ID 目前只支持0-255*/
                      UINT32 nv_size                 /*NV 区域大小,单位Byte,最大512Byte*/
                    );

    INT32 (*nv_delete)(                              /*删除NV*/
                      UINT32 nv_id
                      );                 

    INT32 (*nv_read)(                                /*读取NV内容*/
                     UINT32 nv_id,                   /*NV ID 目前只支持0-255*/
                     UINT8* buf,                     /*buf*/
                     UINT32 bufSize,                 /*buf的大小*/
                     UINT32* readSize                /*实际读取长度*/
                    );
    
    INT32 (*nv_write)(                               /*写入NV内容*/
                      UINT32 nv_id,                  /*NV ID 目前只支持0-255*/
                      UINT8* buf,                    /*buf*/
                      UINT32 bufSize,                /*buf的大小*/
                      UINT32* writeSize              /*实际写入长度*/
                     );          
    /*******************************************
    **                Hardware                **
    *******************************************/
    /****************************** GPIO ******************************/
    BOOL (*config_gpio)(                          
                            E_AMOPENAT_GPIO_PORT port,  /* GPIO编号 */
                            T_AMOPENAT_GPIO_CFG *cfg    /* 输出或输入 */
                       );
    BOOL (*set_gpio)(                               
                            E_AMOPENAT_GPIO_PORT port,  /* GPIO编号 */
                            UINT8 value                 /* 0 or 1 */
                    );
/*+:\NewReq WM-475\brezen\2012.12.14\修改gpio接口 */				
    BOOL (*read_gpio)(                            
                            E_AMOPENAT_GPIO_PORT port,  /* GPIO编号 */
                            UINT8* value                /* 结果 0 or 1 */
                      );
/*-:\NewReq WM-475\brezen\2012.12.14\修改gpio接口 */

/*+\BUG WM-720\rufei\2013.3.21\ 增加gpio的close接口*/
    BOOL (*close_gpio)(                            
                            E_AMOPENAT_GPIO_PORT port/* GPIO编号 */
                      );
/*-\BUG WM-720\rufei\2013.3.21\ 增加gpio的close接口*/
    
    /****************************** PMD ******************************/
    BOOL (*init_pmd)(     
                            E_AMOPENAT_PM_CHR_MODE chrMode,     /* 充电方式 */
/*+\NEW WM-746\rufei\2013.3.30\增加芯片IC充电*/
                            T_AMOPENAT_PMD_CFG*    cfg,         /*充电配置*/
/*-\NEW WM-746\rufei\2013.3.30\增加芯片IC充电*/
                            PPM_MESSAGE            pPmMessage   /* 消息回调函数 */
                    );
    VOID (*get_batteryStatus)(
                            T_AMOPENAT_BAT_STATUS* batStatus    /* 电池状态 OUT */
                             );
    VOID (*get_chargerStatus)(
                            T_AMOPENAT_CHARGER_STATUS* chrStatus/* 充电器状态 OUT */
                             );
/*+\NEW\RUFEI\2014.2.13\增加OPENAT查询充电器HW状态接口*/
    E_AMOPENAT_CHR_HW_STATUS (*get_chargerHwStatus)(
                            VOID
                            );
/*+NEW\zhuwangbin\2017.2.10\添加充电参数查询接口*/
	int (*get_chg_param)(BOOL *battStatus, u16 *battVolt, u8 *battLevel, BOOL *chargerStatus, u8 *chargeState);
/*+NEW\zhuwangbin\2017.2.10\添加充电参数查询接口*/
/*-\NEW\RUFEI\2014.2.13\增加OPENAT查询充电器HW状态接口*/
    BOOL (*poweron_system)(                                     /* 正常开机 */  
                            E_AMOPENAT_STARTUP_MODE simStartUpMode,/* 开启SIM卡方式 */
                            E_AMOPENAT_STARTUP_MODE nwStartupMode/* 开启协议栈方式 */
                          );
    VOID (*poweroff_system)(                                    /* 正常关机，包括关闭协议栈和供电 */        
                            VOID
                           );
    BOOL (*poweron_ldo)(                                        /* 打开LDO */
                            E_AMOPENAT_PM_LDO    ldo,
                            UINT8                level          /*0-7 0:关闭 1~7电压等级*/
                       );
    VOID (*enter_deepsleep)                                     /* 进入睡眠 */
                       (
                         VOID
                       );
    VOID (*exit_deepsleep)                                      /* 退出睡眠 */
                       (
                         VOID
                       );
/*+NEW OPEANT-104\RUFEI\2014.6.17\ 增加获取开机原因值接口*/

     E_AMOPENAT_POWERON_REASON (*get_poweronCasue )(                            /*获取开机原因值*/
                                                    VOID
                                                    );
/*-NEW OPEANT-104\RUFEI\2014.6.17\ 增加获取开机原因值接口*/
    /****************************** UART ******************************/
    BOOL (*config_uart)(
                            E_AMOPENAT_UART_PORT port,          /* UART 编号 */
                            T_AMOPENAT_UART_PARAM *cfg          /* 初始化参数 */
                       );

/*+\NEW\liweiqiang\2013.4.20\增加关闭uart接口*/
    BOOL (*close_uart)(
                            E_AMOPENAT_UART_PORT port           /* UART 编号 */
                       );
/*-\NEW\liweiqiang\2013.4.20\增加关闭uart接口*/

    UINT32 (*read_uart)(                                        /* 实际读取长度 */
                            E_AMOPENAT_UART_PORT port,          /* UART 编号 */
                            UINT8* buf,                         /* 存储数据地址 */
                            UINT32 bufLen,                      /* 存储空间长度 */
                            UINT32 timeoutMs                    /* 读取超时 ms */
                       );

    UINT32 (*write_uart)(                                       /* 实际写入长度 */
                            E_AMOPENAT_UART_PORT port,          /* UART 编号 */
                            UINT8* buf,                         /* 写入数据地址 */
                            UINT32 bufLen,                      /* 写入数据长度 */
                            BOOL bSync                          /* TRUE表示直到UART发送完成才返回 */
                        );
/*+\NEW\liweiqiang\2014.4.12\增加串口接收中断使能接口 */
    BOOL (*uart_enable_rx_int)(
                            E_AMOPENAT_UART_PORT port,          /* UART 编号 */
                            BOOL enable                         /* 是否使能 */
                                );
/*-\NEW\liweiqiang\2014.4.12\增加串口接收中断使能接口 */

/*+\NEW\zhuwangbin\2017.3.10\AIR200 项目添加uart1全pin脚功能*/
#ifdef PRO_AIR200_VERSION
	void (*uart1_all_pin_set)(void);
#endif
/*+\NEW\zhuwangbin\2017.3.10\AIR200 项目添加uart1全pin脚功能*/

/*+\NEW\liweiqiang\2013.12.25\添加host uart发送数据功能 */
    /****************************** HOST ******************************/
    BOOL (*host_init)(PHOST_MESSAGE hostCallback);
    BOOL (*host_send_data)(uint8 *data, uint32 len);
/*-\NEW\liweiqiang\2013.12.25\添加host uart发送数据功能 */

    /******************************* SPI ******************************/
    BOOL (*config_spi)(
                            E_AMOPENAT_SPI_PORT  port,          /* SPI 编号 */
                            T_AMOPENAT_SPI_PARAM *cfg           /* 初始化参数 */
                      );
    UINT32 (*read_spi)(                                         /* 实际读取长度 */
                            E_AMOPENAT_SPI_PORT port,          /* SPI 编号 */
                            UINT8* buf,                         /* 存储数据地址 */
                            UINT32 bufLen                       /* 存储空间长度 */
                      );
    UINT32 (*write_spi)(                                        /* 实际写入长度 */
                            E_AMOPENAT_SPI_PORT port,          /* SPI 编号 */
                            CONST UINT8* buf,                   /* 写入数据地址 */
                            UINT32 bufLen                       /* 写入数据长度 */
                       );
    UINT32 (*rw_spi)(                                          /* 全双工方式读写，读写长度相同 */
                            E_AMOPENAT_SPI_PORT port,          /* SPI 编号 */
                            CONST UINT8* txBuf,                 /* 写缓冲 */
                            UINT8* rxBuf,                       /* 读缓冲*/
                            UINT32 len                          /* 读写长度 */
                    );
                   
    BOOL (*close_spi)(
                            E_AMOPENAT_SPI_PORT  port
                    );      
    /******************************* I2C ******************************/
    BOOL (*open_i2c)(
                            E_AMOPENAT_I2C_PORT  port,          /* I2C 编号 */
                            T_AMOPENAT_I2C_PARAM *param         /* 初始化参数 */
                      );
    BOOL (*close_i2c)(
                            E_AMOPENAT_I2C_PORT  port           /* I2C 编号 */
                      );
    UINT32 (*write_i2c)(                                        /* 实际写入长度 */
                            E_AMOPENAT_I2C_PORT port,          /* I2C 编号 */
                            UINT8 salveAddr,
                            CONST UINT8 *pRegAddr,              /* I2C外设寄存器地址 */
                            CONST UINT8* buf,                   /* 写入数据地址 */
                            UINT32 bufLen                       /* 写入数据长度 */
                       );
    UINT32 (*read_i2c)(                                         /* 实际读取长度 */
                            E_AMOPENAT_I2C_PORT port,          /* I2C 编号 */
                            UINT8 slaveAddr, 
                            CONST UINT8 *pRegAddr,              /* I2C外设寄存器地址 */
                            UINT8* buf,                         /* 存储数据地址 */
                            UINT32 bufLen                       /* 存储空间长度 */
                      );
    BOOL  (*open_bt)(
                            T_AMOPENAT_BT_PARAM* param
                     );
    BOOL  (*close_bt)(
                            VOID
                     );
    BOOL  (*poweron_bt)
                      (
                            VOID
                      );
                      
    BOOL  (*poweroff_bt)
                      (
                            VOID
                      );  
    BOOL  (*send_cmd_bt)
                      (
                            E_AMOPENAT_BT_CMD cmd, 
                            U_AMOPENAT_BT_CMD_PARAM* param
                      );    
    BOOL  (*build_rsp_bt)
                      (
                            E_AMOPENAT_BT_RSP rsp,
                            U_AMOPENAT_BT_RSP_PARAM* param
                      );                              
    BOOL  (*connect_spp)                                        /*本端作为DevA设备，主动发起连接，连接结果OPENAT_BT_SPP_CONNECT_CNF
                                                                  如果作为DevB设备，即对端主动发起连接，那就不需要调用这个接口，
                                                                  对端连接后会收到OPENAT_BT_SPP_CONNECT_IND消息*/
                      (
                            T_AMOPENAT_BT_ADDR* addr,
                            T_AMOPENAT_UART_PARAM* portParam    /*暂时不支持,可以写NULL，默认配置为9600,8(data),1(stop),none(parity)*/
                      );
    BOOL  (*disconnect_spp)                                     /*断开连接，结果 OPENAT_BT_SPP_DISCONNECT_CNF*/
                      (
                            UINT8   port                        /*端口号，会在OPENAT_BT_SPP_CONNECT_IND/OPENAT_BT_SPP_CONNECT_CNF中上报*/
                      );                      
    INT32  (*write_spp)                                         /*发送结果会在回调函数里的OPENAT_BT_SPP_SEND_DATA_CNF事件中上报*/
                                                                /*返回值为实际执行写入的长度，如果为0表示根本没有数据被发送，也没有
                                                                  OPENAT_BT_SPP_SEND_DATA_CNF事件上报*/
                      (
                            UINT8   port,                       /*端口号，会在OPENAT_BT_SPP_CONNECT_IND/OPENAT_BT_SPP_CONNECT_CNF中上报*/
                            UINT8*  buf,                        /*不能传输"rls开头的字符串，否则会认为是设置RFCOMM的状态，例如rls0*/
                            UINT32  bufLen                      /*一次最多传输T_AMOPENAT_BT_SPP_CONN_IND.maxFrameSize大小字节的数据*/
                      );
    INT32  (*read_spp)                                          /*回调函数中收到OPENAT_BT_SPP_DATA_IND事件后，调用该接口读取*/
                                                                /*返回值为实际读取长度*/
                      (
                            UINT8   port,                       /*端口号，会在OPENAT_BT_SPP_CONNECT_IND/OPENAT_BT_SPP_CONNECT_CNF中上报*/
                            UINT8*  buf,
                            UINT32  bufLen
                      );                      
    /****************************** AUDIO ******************************/
    BOOL (*open_tch)(                                           /* 打开语音，在通话开始时调用 */
                            VOID
                    );
    BOOL (*close_tch)(                                          /* 关闭语音，通话结束时调用 */
                            VOID
                     );
    BOOL (*play_tone)(                                          /* 播放TONE音接口 */
                            E_AMOPENAT_TONE_TYPE toneType,      /* TONE音类型 */
                            UINT16 duration,                    /* 播放时长 */
                            E_AMOPENAT_SPEAKER_GAIN volume      /* 播放音量 */
                     );
    BOOL (*stop_tone)(                                          /* 停止播放TONE音接口 */
                            VOID
                     );
    BOOL (*play_dtmf)(                                          /* 播放DTMF音接口 */
                            E_AMOPENAT_DTMF_TYPE dtmfType,      /* DTMF类型 */
                            UINT16 duration,                    /* 播放时长 */
                            E_AMOPENAT_SPEAKER_GAIN volume      /* 播放音量 */
                     );
    BOOL (*stop_dtmf)(                                          /* 停止播放DTMF音接口 */
                            VOID
                     );
/*+\NewReq WM-584\maliang\2013.2.21\[OpenAt]支持T卡播放MP3*/
    BOOL (*play_music)(T_AMOPENAT_PLAY_PARAM*  playParam);
/*-\NewReq WM-584\maliang\2013.2.21\[OpenAt]支持T卡播放MP3*/
    BOOL (*stop_music)(                                         /* 停止音频播放接口 */
                            VOID
                      );
    BOOL (*pause_music)(                                        /* 暂停音频播放接口 */
                            VOID
                       );
    BOOL (*resume_music)(                                       /* 停止音频播放接口 */
                            VOID
                        );
/*+\NewReq WM-710\maliang\2013.3.18\ [OpenAt]增加接口设置MP3播放的音效*/
    BOOL (*set_eq)(                                       /* 设置MP3音效*/
                            E_AMOPENAT_AUDIO_SET_EQ setEQ
                        );
/*-\NewReq WM-710\maliang\2013.3.18\ [OpenAt]增加接口设置MP3播放的音效*/
    BOOL (*open_mic)(                                           /* 开启MIC接口 */
                            VOID
                    );
    BOOL (*close_mic)(                                          /* 关闭MIC接口 */
                            VOID
                     );
    BOOL (*mute_mic)(                                           /* MIC静音接口 */
                            VOID
                    );
    BOOL (*unmute_mic)(                                         /* 解除MIC静音接口 */
                            VOID
                      );
    BOOL (*set_mic_gain)(                                       /* 设置MIC增益接口 */
                            UINT16 micGain                      /* 设置MIC的增益，最大为20 */
                        );
    BOOL (*open_speaker)(                                       /* 打开扬声器接口 */
                            VOID
                        );
    BOOL (*close_speaker)(                                      /* 关闭扬声器接口 */
                            VOID
                         );
    BOOL (*mute_speaker)(                                       /* 扬声器静音接口 */
                            VOID
                        );
    BOOL (*unmute_speaker)(                                     /* 解除扬声器静音接口 */
                            VOID
                          );
    BOOL (*set_speaker_gain)(                                   /* 设置扬声器的增益 */
                            E_AMOPENAT_SPEAKER_GAIN speakerGain /* 设置扬声器的增益 */
                            );
    E_AMOPENAT_SPEAKER_GAIN (*get_speaker_gain)(                /* 获取扬声器的增益接口 */
                            VOID
                                               );
    BOOL (*set_channel)(                                        /* 设置音频通道接口 */
                            E_AMOPENAT_AUDIO_CHANNEL channel    /* 通道 */
                       );
    VOID (*set_channel_with_same_mic)(                          /* 设置共用同一个MIC音频通道接口 */
                        E_AMOPENAT_AUDIO_CHANNEL channel_1,     /* 通道 1 */
                        E_AMOPENAT_AUDIO_CHANNEL channel_2      /* 通道 2 */
                   );
/*+\BUG WM-882\rufei\2013.7.18\完善通道设置*/
    BOOL(*set_hw_channel)(
                          E_AMOPENAT_AUDIO_CHANNEL hfChanne,    /*手柄通道*/
                          E_AMOPENAT_AUDIO_CHANNEL erChanne,    /*耳机通道*/
                          E_AMOPENAT_AUDIO_CHANNEL ldChanne    /*免提通道*/
                         );
/*-\BUG WM-882\rufei\2013.7.18\完善通道设置*/
    E_AMOPENAT_AUDIO_CHANNEL (*get_current_channel)(            
                            VOID
                                                   );
/*+\NewReq WM-711\maliang\2013.3.18\[OpenAt]增加接口打开或关闭音频回环测试*/
/*+\New\lijiaodi\2014.7.30\修改音频回环测试接口，增加IsSpkLevelAdjust跟SpkLevel两参数
                           如果IsSpkLevelAdjust为FALSE,spkLevel为默认的值，否则为SpkLevel指定的值*/
    BOOL  (*audio_loopback)(BOOL  start,                    /*开始或停止回环测试*/
                                        E_AMOPENAT_AUDIO_LOOPBACK_TYPE type,   /*回环测试的类型*/
                                        BOOL IsSpkLevelAdjust,   /*SPK声音大小是否可指定*/
                                        UINT8 SpkLevel);   /*SPK指定的声音大小SpkLevel取值范围AUD_SPK_MUTE--AUD_SPK_VOL_7*/
/*-\New\lijiaodi\2014.7.30\修改音频回环测试接口，增加IsSpkLevelAdjust跟SpkLevel两参数
                           如果IsSpkLevelAdjust为FALSE,spkLevel为默认的值，否则为SpkLevel指定的值*/
/*-\NewReq WM-711\maliang\2013.3.18\[OpenAt]增加接口打开或关闭音频回环测试*/

    BOOL  (*audio_inbandinfo)(PINBANDINFO_CALLBACK callback); 
    
    /****************************** ADC ******************************/
    BOOL (*init_adc)(
                            E_AMOPENAT_ADC_CHANNEL chanle
                    );
    BOOL (*read_adc)(
                            E_AMOPENAT_ADC_CHANNEL chanle,      /* ADC通道 */
                            UINT16* adcValue,                   /* ADC值，可以为空*/   
                            UINT16* voltage                     /* 电压值，可以为空*/
                    );
    /****************************** LCD ******************************/
    /* MONO */                                                  /* 黑白屏*/			
    BOOL (*init_mono_lcd)(                                      /* 屏幕初始化接口 */
                            T_AMOPENAT_MONO_LCD_PARAM*  monoLcdParamP
                    );
    VOID (*send_mono_lcd_command)(                              /* 发送命令接口 */
                            UINT8 cmd                           /* 命令 */
                                 );
    VOID (*send_mono_lcd_data)(                                 /* 发送数据接口 */
                            UINT8 data                          /* 数据 */
                              );
    VOID (*update_mono_lcd_screen)(                             /* 更新屏幕接口 */
                            T_AMOPENAT_LCD_RECT_T* rect         /* 需要刷新的区域 */
                                  );
    VOID (*clear_mono_lcd)(                                     /* 清屏，一般用于实际LCD RAM比显示区域大的情况 */
                            UINT16 realHeight,                  /* 实际LCD RAM 高度 */
                            UINT16 realWidth                    /* 实际LCD RAM 宽度，必须是4的倍数 */
                          );
    /* COLOR */                                                 /* 彩色屏 */
    BOOL (*init_color_lcd)(                                     /* 屏幕初始化接口 */
                            T_AMOPENAT_COLOR_LCD_PARAM *param   /* 彩屏初始化参数 */
                          );
    VOID (*send_color_lcd_command)(                             /* 发送命令接口 */
                            UINT8 cmd                           /* 命令 */
                                  );
    VOID (*send_color_lcd_data)(                                /* 发送数据接口 */
                            UINT8 data                          /* 数据 */
                               );
    VOID (*update_color_lcd_screen)(                            /* 更新屏幕接口 */
                            T_AMOPENAT_LCD_RECT_T* rect,        /* 需要刷新的区域 */
                            UINT16 *pDisplayBuffer              /* 刷新的缓冲区 */
                                   );
    /****************************** CAMERA ******************************/
    BOOL (*camera_init)(                                        /* 摄像头初始化接口 */
                        T_AMOPENAT_CAMERA_PARAM *cameraParam    /* 摄像头初始化参数 */
                        );
    
    BOOL (*camera_poweron)(                                     /* 打开摄像头 */
                        BOOL videoMode                          /* 是否视频模式 */
                        );
    BOOL (*camera_poweroff)(                                    /* 关闭 摄像头 */
                        void
                        );
    BOOL (*camera_preview_open)(                                /* 开始预览*/
                        T_AMOPENAT_CAM_PREVIEW_PARAM *previewParam /* 预览参数 */
                        );
    BOOL (*camera_preview_close)(                               /* 退出预览 */
                        void                    
                        );
    BOOL (*camera_capture)(                                     /* 拍照 */
                        T_AMOPENAT_CAM_CAPTURE_PARAM *captureParam /* 参数 */
                        );
    BOOL (*camera_save_photo)(                                  /* 保存照片 */
                        INT32 iFd                               /* 待保存的照片文件句柄 */
                        );

    /*+\NEW\Jack.li\2013.2.9\增加摄像头视频录制接口 */
    BOOL (*camera_videorecord_start)(                           /* 开始录制视频 */
                        INT32 iFd                               /* 录像文件句柄 */
                        );
    BOOL (*camera_videorecord_pause)(                           /* 暂停录制视频 */
                        void                    
                        );
    BOOL (*camera_videorecord_resume)(                          /* 恢复录制视频 */
                        void                    
                        );
    BOOL (*camera_videorecord_stop)(                            /* 停止录制视频 */
                        void                    
                        );
    /*-\NEW\Jack.li\2013.2.9\增加摄像头视频录制接口 */
    
    /*-\NEW\Jack.li\2013.1.28\增加摄像头驱动*/
    
    /*+\NEW\Jack.li\2013.2.10\增加视频播放接口 */
    BOOL (*video_open)(                                         /* 打开视频环境 */
                        T_AMOPENAT_VIDEO_PARAM *param           /* 视频参数 */
                        );
    BOOL (*video_close)(                                        /* 关闭视频环境 */
                        void
                        );
    BOOL (*video_get_info)(                                     /* 获取视频信息 */
                        T_AMOPENAT_VIDEO_INFO *pInfo            /* 视频信息 */
                        );
    BOOL (*video_play)(                                         /* 播放 */
                        void
                        );
    BOOL (*video_pause)(                                        /* 暂停 */
                        void
                        );
    BOOL (*video_resume)(                                       /* 恢复 */
                        void
                        );
    BOOL (*video_stop)(                                         /* 停止 */
                        void
                        );
    /*-\NEW\Jack.li\2013.2.10\增加视频播放接口 */

    /* NULL */
    /****************************** KEYPAD ******************************/
    BOOL (*init_keypad)(                                        /* 键盘初始化接口 */
                            T_AMOPENAT_KEYPAD_CONFIG *pConfig   /* 键盘配置参数 */
                       );

    /****************************** TOUCHSCREEN ******************************/
    BOOL (*init_touchScreen)(                                   /* 触摸屏初始化接口 */
                            PTOUCHSCREEN_MESSAGE pTouchScreenMessage /* 触屏消息回调函数 */
                            );

    /******************************** PSAM ***********************************/
    /* 注意:::PSAM卡接口在操作设备时会导致调用者被挂起，直到设备有响应或者2s+超时 */
    E_AMOPENAT_PSAM_OPER_RESULT (*open_psam)(                   /* 打开psam */
                            E_AMOPENAT_PSAM_ID id               /* 硬件SIM卡接口 */
                                            );
    VOID (*close_psam)(                                         /* 关闭psam */
                            E_AMOPENAT_PSAM_ID id               /* 硬件SIM卡接口 */
                      );
	/*  rw_psam接口使用说明
		psam 指令包
		-------------------------
	    代码  |	值
		-------------------------
		CLA     80
		INS  	82
		P1	    00
		P2	    00或密钥版本（KID）
		Lc	    08
		DATA	加密数据
		-------------------------

	针对需要DATA参数的PSAM指令，需要分步发送，
	  第一步 发送DATA之前的命令部分，同时设置rxLen=1，stopClock = FALSE
	  	返回值可能为Ins 、 ~Ins 
	  		如果返回是Ins，进入第三步
	  		如果返回是~Ins，则进入第二步
	  第二步 如果DATA中剩余的数据大于1个字节，发送一个字节的DATA剩余数据，同时设置rxLen=1，stopClock = FALSE，
	        否则，直接进入第三步
	     返回值的处理和第一步返回值处理一致
		   
	  第三步发送DATA中的剩余数据，同时设置stopClock=TRUE,rxLen根据需要设置
	*/					  
    E_AMOPENAT_PSAM_OPER_RESULT (*rw_psam)(                     /* 传输数据 */
                            E_AMOPENAT_PSAM_ID id,              /* 硬件SIM卡接口 */
                            CONST UINT8*  txBuf,                /* 写缓存 */
                            UINT16        txLen,                /* 写缓存长度 */
                            UINT8*        rxBuf,                /* 读缓存 */
                            UINT16        rxLen,                /* 读缓存长度 */
                            BOOL          stopClock             /* 命令分开发送设置为FALSE, 命令一次发送或者为分布发送的最后一步设置为TRUE*/  
                                          );
    E_AMOPENAT_PSAM_OPER_RESULT (*reset_psam)(                  /* 复位PSAM */
                            E_AMOPENAT_PSAM_ID id,              /* 硬件SIM卡接口 */
                            UINT8*      atrBuf,                 /* ATR 缓存 */
                            UINT16      atrBufLen,              /* ATR 缓存长度 */
                            E_AMOPENAT_PSAM_VOLT_CLASS volt     /* 工作电压 */
                                             );
    E_AMOPENAT_PSAM_OPER_RESULT (*setfd_psam)(                  /* 设置F值和D值，默认F=372 D=1 */
                            E_AMOPENAT_PSAM_ID id,              /* 硬件SIM卡接口 */
                            UINT16      f,                      /* F值 */
                            UINT8       d                       /* D值 */
                                             );

/*+\BUG WM-690\rufei\2013.3.18\AT+SPWM没有实现PWM1和PWM2*/
    /******************************** PWM ***********************************/
    BOOL (*open_pwm)(
                            E_AMOPENAT_PWM_PORT port
                     );
    BOOL (*close_pwm)(
                            E_AMOPENAT_PWM_PORT port
                      );
    BOOL (*set_pwm)(
                            T_AMOPENAT_PWM_CFG *pwmcfg
                    );
/*-\BUG WM-690\rufei\2013.3.18\AT+SPWM没有实现PWM1和PWM2*/

    /****************************** FM ******************************/
	BOOL (*open_fm)(											/* 打开FM */
                            T_AMOPENAT_FM_PARAM *fmParam        /* 初始化数据 */
                   );

	BOOL (*tune_fm)(											/* 调到指定频率 */
                            UINT32 frequency                    /* 频率(KHZ) */
                   );

	BOOL (*seek_fm)(											/* 搜索下一个台 */
                            BOOL seekDirection					/* TRUE:频率增加的方向 FALSE::频率减小的方向 */		
                   );

	BOOL (*stopseek_fm)(										/* 停止搜索 */
                            void
                       );

	BOOL (*setvol_fm)(											/* 设置音效 */
                            E_AMOPENAT_FM_VOL_LEVEL volume, 	/* 设置音量 */
                            BOOL bassBoost, 
                            BOOL forceMono
                     );

	BOOL (*getrssi_fm)(											/* 获取FM信号 */
                            UINT32* pRssi
                      );

	BOOL (*close_fm)(											/* 关闭FM */
                            void
                    );


    /*******************************************
    **               AT COMMAND               **
    *******************************************/
    BOOL (*init_at)(                                            /* 虚拟AT通路初始化接口 */
                            PAT_MESSAGE pAtMessage              /* AT消息回调函数 */
                   );
    BOOL (*send_at_command)(                                    /* 发送AT命令接口 */
                            UINT8 *pAtCommand,                  /* AT命令 */
                            UINT16 nLength                      /* AT命令长度 */
                           );
#ifdef AM_DTE_AT_DATA_FILTER_SUPPORT							   
    BOOL (*set_dte_at_filter)(                                  /*设置DTE和CI之间AT命令字符过滤函数*/
                            PAT_FILTER_MESSAGE dte_data_ind_cb, /*DTE->CI的数据，一般是AT命令*/
                            PAT_FILTER_MESSAGE ci_data_ind_cb   /*CI->DTE的数据，一般是AT命令返回*/
                            );
    BOOL (*send_data_to_dte)(                                   /*发送数据给DTE设备，暂时只支持AT命令*/
                            UINT8 channel,                      /*通道*/
                            const UINT8* data,                  /*数据*/
                            UINT16  dataLen                     /*数据长度*/
                            );
    BOOL (*send_data_to_ci) (                                   /*发送数据给CI，暂时只支持AT命令*/
                            UINT8 channel,                      /*通道*/
                            const UINT8* data,                  /*数据*/
                            UINT16 dataLen                      /*数据长度*/
                            );
    BOOL (*set_dte_device) (                                    /*设置DTE对应的物理设备，cust_main里设置，
                                                                  暂时不支持使用过程中设置*/
                            T_AMOPENAT_DTE_DEVICE device
                           );
                            
#endif
/*+\NEW WM-733\xc\2013.04.19\修改加密卡流程(添加openat存取接口) */
    /*******************************************
    **               加密卡设置               **
    *******************************************/
    BOOL (*set_encinfo)(                         /* 设置密钥信息 */
                        UINT8 *encInfo,
                        UINT32 len
              );

    BOOL (*get_encinfo)(                         /* 读取密钥信息 */
                        UINT8 *encInfo,
                        UINT32 len
              );

    UINT8 (*get_encresult)(                         /* 读取加密校验结果 */
                        void
              );
/*+\NEW WM-733\xc\2013.05.06\修改加密卡流程5(添加获取卡类型的接口) */
    UINT8 (*get_cardtype)(                         /* 读取卡类型 0未知  1加密卡  2普通卡  */
                        void
              );
/*-\NEW WM-733\xc\2013.05.06\修改加密卡流程5(添加获取卡类型的接口) */
              
/*+\NEW WM-733\xc\2013.04.23\修改加密卡流程2(用openat接口代替at设置密钥信息。添加信号量) */
    BOOL (*set_enc_data_ok)(                         /* mmi中准备好密钥信息后要用这个发出通知 */
                        void
              );
/*-\NEW WM-733\xc\2013.04.23\修改加密卡流程2(用openat接口代替at设置密钥信息。添加信号量) */
/*+\NEW WM-733\xc\2013.04.19\修改加密卡流程(添加openat存取接口) */

/*+\NEW\xiongjunqun\2014.04.02\调整TTS的代码*/
/* delete TTS改用发送AT 指令的形式 */
/*-\NEW\xiongjunqun\2014.04.02\调整TTS的代码*/
/*+\NEW AMOPENAT-91 \zhangyang\2013.11.19\增加USB HID功能*/
    void (*uhid_open)(
        void (*handler)(uint8 *, uint32));
    void (*uhid_close)(
        void);
    int32 (*uhid_write)(
        uint8 *data_p, 
        uint32 length);
/*-\NEW AMOPENAT-91 \zhangyang\2013.11.19\增加USB HID功能*/

/*+\NEW\RUFEI\2014.4.4\增加外部看门狗配置接口*/
#ifdef DSS_CONFIG_EX_WATCH_DOG
    BOOL(*cus_config_ex_watch_dog)(
            E_OPEANT_CUST_EX_WATCH_DOG_MODE mode,
            U_AMOPENAT_EX_WATCH_DOG_CFG *cfg
            );
    BOOL (*cus_reset_ex_watch_dog)(
            void);
    BOOL(*cus_close_ex_watch_dog)(
        E_OPEANT_CUST_EX_WATCH_DOG_MODE mode);
#endif //DSS_CONFIG_EX_WATCH_DOG
/*-\NEW\RUFEI\2014.4.4\增加外部看门狗配置接口*/

/*+\NEW\RUFEI\2014.8.20\增加gps接口实现*/
    /*******************************************
    **               RDAGPS                      **
    *******************************************/
    BOOL (*rdaGps_open)(
        T_AMOPENAT_RDAGPS_PARAM *cfg);
    BOOL (*rdaGps_close)(
        T_AMOPENAT_RDAGPS_PARAM *cfg);
/*-\NEW\RUFEI\2014.8.20\增加gps接口实现*/
    /*******************************************
    **                 DEBUG                  **
    *******************************************/
    VOID (*print)(                                              /* trace log输出接口 */
                            CHAR * fmt, ...
                 );
    VOID (*assert)(                                             /* 断言接口 */
                            BOOL condition,                     /* 条件 */
                            CHAR *func,                         /* 函数名称 */
                            UINT32 line                         /* 行数 */
                  );

    VOID (*enable_watchdog)(BOOL enable);                            /*打开看门狗*/

/*+\NEW\WZQ\2014.11.7\加入SSL RSA功能*/
#ifdef AM_OPENAT_SSL_RSA_SUPPORT
    /*******************************************
      **                 SSL RSA                  **
      *******************************************/

    OPENAT_BIGNUM*(*bn_new)(void);
    
    OPENAT_BN_CTX*(*bn_CTX_new)(void);
    
    OPENAT_BIGNUM*(*bn_bin2bn)(const unsigned char *s,
                        int len,
                        OPENAT_BIGNUM *ret
                        );
    
    int (*bn_bn2bin)(const OPENAT_BIGNUM *a, 
                        unsigned char *to);
    
    int (*bn_mod_exp_mont)(OPENAT_BIGNUM *rr,
                            const OPENAT_BIGNUM *a, 
                            const OPENAT_BIGNUM *p,
                            const OPENAT_BIGNUM *m, 
                            OPENAT_BN_CTX *ctx, 
                            OPENAT_BN_MONT_CTX *in_mont
                            );
    
    int (*bn_mod_exp)(OPENAT_BIGNUM *r,
                        const OPENAT_BIGNUM *a, 
                        const OPENAT_BIGNUM *p, 
                        const OPENAT_BIGNUM *m,
                        OPENAT_BN_CTX *ctx
                        );
    
    void (*bn_free)(OPENAT_BIGNUM *a);
    
    void (*bn_CTX_free)(OPENAT_BN_CTX *ctx);
    
    int (*bn_hex2bn)(OPENAT_BIGNUM **bn, 
                     const char *a
                     );
#endif
/*-\NEW\WZQ\2014.11.7\加入SSL RSA功能*/

/*+\NEW\WZQ\2014.11.7\加入18030字库*/
#ifdef AM_OPENAT_GB18030_SUPPORT
    /*******************************************
       **                 GB18030                  **
       *******************************************/

    const unsigned char* (*get_GB18030_graph)(unsigned char* gbkCode,
                             unsigned int gbkCodeLen);
#endif
/*-\NEW\WZQ\2014.11.7\加入18030字库*/

    int (*get_env_usage)(void );
/*+:\NewReq\brezen\2017.2.22\lua加密 */	
    void (*decode)(UINT32* data, INT32 len);
/*-:\NewReq\brezen\2017.2.22\lua加密 */	
  
    /*******************************************
    **                 socket                 **
    *******************************************/
    INT32 (*socket_init)(  VOID);
    INT32 (*socket_create)(INT32 domain, 
                           SocketType type,
                           INT32 protocol);
                           
    INT32 (*socket_gethostbyname)(const char *name_p,
                                  UINT32 *dest_ip);
                           
    INT32 (*socket_close) (INT32 socket);

    INT32 (*socket_setopt) (INT32 socket, 
                            INT16 level, 
                            INT16 optname,
                            const void *optval_p, 
                            INT16 optlen);
                     
    INT32 (*socket_bind) (INT32 socket, 
                          const struct sockaddr *name_p, 
                          INT16 nameLen);
                          
    INT32 (*socket_connect) (INT32 socket, 
                             const struct sockaddr *name_p,
                             INT16 nameLen);
                             
    INT32 (*socket_listen) (INT32 socket, 
                           INT16 backlog);
    INT32 (*socket_accept) (INT32 socket, 
                            struct sockaddr *addr_p, 
                            INT16 *addrLen_p);
                            
    INT32 (*socket_recv) (INT32 socket, 
                          void *buf_p, 
                          INT16 len,
                          INT16 flags);
    
    INT32 (*socket_recvfrom) (INT32 socket, 
                              void *buf_p, 
                              INT16 len,
                              INT16 flags,
                              struct sockaddr *from_p,
                              INT16 *fromLen_p);

    INT32 (*socket_send) (INT32 socket,
                          const void *buf_p,
                          INT16 len,
                          INT16 flags);
                          
    INT32 (*socket_sendto) (INT32 socket,
                            const void *buf_p,
                            INT16 len,
                            INT16 flags,
                            const struct sockaddr *to_p, 
                            INT16 tolen);
                     
    INT32 (*socket_select) (INT32 maxfdp1, 
                            fd_set *readset,
                            fd_set *writeset,
                            fd_set *exceptset,
                            struct timeval *timeout);
    VOID (*socket_ping)    (
                            const struct sockaddr *addr_p,
                            INT16 pingCount,
                            INT32 Timeout, 
                            F_AMOPENAT_PING_IND ind
                           );
    BOOL(*gsm_get_status)  (
                            T_OPENAT_GSM_STATUS* status //out
                            );
    BOOL(*gsm_set_cb)     (
                            F_OPENAT_GSM_IND_CB indCb
                          );
    BOOL(*gsm_connect)     (
                            T_OPENAT_GSM_CONNECT* connectParam
                          );
                          
    BOOL(*gsm_disconnect)  (
                            VOID
                          );                      
}T_AMOPENAT_INTERFACE_VTBL;

/*+\BUG WM-656\lifei\2013.03.07\[OpenAT] 修改cust区域检查条件*/
#define OPENAT_CUST_VTBL_DEFUALT_MAGIC 0x87654321
/*-\BUG WM-656\lifei\2013.03.07\[OpenAT] 修改cust区域检查条件*/
#define OPENAT_CUST_APP_ROM_MAX_LEN       0x50000

typedef enum E_AMOPENAT_CUST_INIT_RESULT_TAG
{
    OPENAT_CUST_INIT_RES_OK,        /* 客户程序初始化成功，可以调用cust_main函数 */
    OPENAT_CUST_INIT_RES_ERROR,     /* 客户程序初始化失败，不会调用cust_main函数 */
    OPENAT_CUST_INIT_RES_MAX
}E_AMOPENAT_CUST_INIT_RESUL;
    
typedef struct T_AMOPENAT_CUST_VTBL_TAG
{
    const UINT32 magic;
    const UINT32 imgROLMA;
    const UINT32 imgROVMA;
    const UINT32 imgROLength;
    const UINT32 imgRWLMA;
    const UINT32 imgRWVMA;
    const UINT32 imgRWLength;
    const UINT32 imgZIBase;
    const UINT32 imgZILength;

    UINT8 (*cust_init)(                                 /* 客户程序初始化接口*/
                            T_AMOPENAT_INTERFACE_VTBL *pVtable/* OPENAT开放平台接口表 */
                      );
    VOID (*cust_main)(                                  /* 客户程序主函数 */
                            VOID
                     );
}T_AMOPENAT_CUST_VTBL;

#endif /* AM_OPENAT_H */

