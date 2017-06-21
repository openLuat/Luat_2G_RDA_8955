/*********************************************************************************
 * 文件名称: aliyun_iot_common_base64.h
 * 作       者:
 * 版       本:
 * 日       期: 2016-05-30
 * 描       述:
 * 其       它:
 * 历       史:
 **********************************************************************************/

#ifndef ALIYUN_IOT_COMMON_BASE64_H
#define ALIYUN_IOT_COMMON_BASE64_H

#include "aliyun_iot_common_datatype.h"
#include "aliyun_iot_common_error.h"

IOT_RETURN_CODES_E aliyun_iot_common_base64encode(const UINT8 *data, UINT32 inputLength, UINT32 outputLenMax,UINT8 *encodedData,UINT32 *outputLength);
IOT_RETURN_CODES_E aliyun_iot_common_base64decode(const UINT8 *data, UINT32 inputLength, UINT32 outputLenMax,UINT8 *decodedData,UINT32 *outputLength);

#endif
