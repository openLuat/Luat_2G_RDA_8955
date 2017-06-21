/*********************************************************************************
 * 文件名称: aliyun_iot_common_datatype.h
 * 作       者:
 * 版       本:
 * 日       期: 2016-05-30
 * 描       述:
 * 其       它:
 * 历       史:
 **********************************************************************************/
#ifndef ALIYUN_IOT_COMMON_DATATYPE_H
#define ALIYUN_IOT_COMMON_DATATYPE_H

//typedef void                  VOID;

typedef unsigned char         UINT8;
typedef char                  INT8;

typedef unsigned short        UINT16;
typedef short                 INT16;

typedef unsigned int          UINT32;
typedef unsigned int          uint32_t;
typedef int                   INT32;

#ifdef WIN32
typedef unsigned long    UINT64;
typedef long             INT64;
#else
typedef unsigned long long    UINT64;
typedef long long             INT64;
#endif

typedef float                 FLOAT;
typedef double                DOUBLE;

//typedef unsigned int          BOOL;

#define  TRUE_IOT    1
#define  FALSE_IOT   0

#endif
