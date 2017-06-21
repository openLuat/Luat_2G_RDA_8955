/*********************************************************************************
 * 文件名称: aliyun_iot_common_base64.c
 * 作       者:
 * 版       本:
 * 日       期: 2016-05-30
 * 描       述:
 * 其       它:
 * 历       史:
 **********************************************************************************/
//#include <stdint.h>
#include <stdlib.h>
#include "aliyun_iot_common_datatype.h"
#include "aliyun_iot_common_error.h"
#include "aliyun_iot_common_log.h"
#include "aliyun_iot_common_base64.h"

static INT8 g_encodingTable[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '+', '/'};

static INT8 g_decodingTable[256];
static INT32 g_modTable[] = { 0, 2, 1 };

static void build_decoding_table()
{
    static INT32 signal = 0;
    INT32 i = 0;

    if(signal!=0)
    {
        return;
    }

    for (i = 0; i < 64; i++)
    {
        g_decodingTable[(UINT8) g_encodingTable[i]] = i;
    }

    signal = 1;
    return;
}

IOT_RETURN_CODES_E aliyun_iot_common_base64encode(const UINT8 *data, UINT32 inputLength, UINT32 outputLenMax,UINT8 *encodedData,UINT32 *outputLength)
{
    UINT32 i = 0;
    UINT32 j = 0;

    if(NULL == encodedData)
    {
        WRITE_IOT_ERROR_LOG("pointer of encodedData is NULL!");
        return FAIL_RETURN;
    }

    *outputLength = 4 * ((inputLength + 2) / 3);

    if(outputLenMax < *outputLength)
    {
        WRITE_IOT_ERROR_LOG("the length of output memory is not enough!");
        return FAIL_RETURN;
    }

    for (i = 0, j = 0; i < inputLength;)
    {
        uint32_t octet_a = i < inputLength ? (UINT8) data[i++] : 0;
        uint32_t octet_b = i < inputLength ? (UINT8) data[i++] : 0;
        uint32_t octet_c = i < inputLength ? (UINT8) data[i++] : 0;

        uint32_t triple = (octet_a << 0x10) + (octet_b << 0x08) + octet_c;

        encodedData[j++] = g_encodingTable[(triple >> 3 * 6) & 0x3F];
        encodedData[j++] = g_encodingTable[(triple >> 2 * 6) & 0x3F];
        encodedData[j++] = g_encodingTable[(triple >> 1 * 6) & 0x3F];
        encodedData[j++] = g_encodingTable[(triple >> 0 * 6) & 0x3F];
    }

    for (i = 0; i < g_modTable[inputLength % 3]; i++)
    {
        encodedData[*outputLength - 1 - i] = '=';
    }

    return SUCCESS_RETURN;
}

IOT_RETURN_CODES_E aliyun_iot_common_base64decode(const UINT8 *data, UINT32 inputLength, UINT32 outputLenMax,UINT8 *decodedData,UINT32 *outputLength)
{
    UINT32 i = 0;
    UINT32 j = 0;

	UINT32 sextet_a = 0;
    UINT32 sextet_b = 0;
    UINT32 sextet_c = 0;
    UINT32 sextet_d = 0;
    UINT32 triple = 0;

    build_decoding_table();

    if (inputLength % 4 != 0)
    {
        WRITE_IOT_ERROR_LOG("the input length is error!");
        return FAIL_RETURN;
    }

    *outputLength = inputLength / 4 * 3;


    if (data[inputLength - 1] == '=')
    {
        (*outputLength)--;
    }

    if (data[inputLength - 2] == '=')
    {
        (*outputLength)--;
    }

    if(outputLenMax < *outputLength)
    {
        WRITE_IOT_ERROR_LOG("the length of output memory is not enough!");
        return FAIL_RETURN;
    }    

    for (i = 0, j = 0; i < inputLength;)
    {
        sextet_a = data[i] == '=' ? 0 & i++ : g_decodingTable[data[i++]];
        sextet_b = data[i] == '=' ? 0 & i++ : g_decodingTable[data[i++]];
        sextet_c = data[i] == '=' ? 0 & i++ : g_decodingTable[data[i++]];
        sextet_d = data[i] == '=' ? 0 & i++ : g_decodingTable[data[i++]];

        triple = (sextet_a << 3 * 6) + (sextet_b << 2 * 6) + (sextet_c << 1 * 6) + (sextet_d << 0 * 6);

        if (j < *outputLength)
        {
            decodedData[j++] = (triple >> 2 * 8) & 0xFF;
        }

        if (j < *outputLength)
        {
            decodedData[j++] = (triple >> 1 * 8) & 0xFF;
        }

        if (j < *outputLength)
        {
            decodedData[j++] = (triple >> 0 * 8) & 0xFF;
        }
    }

    return SUCCESS_RETURN;
}

