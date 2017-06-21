/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    lzmalib.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/5/10
 *
 * Description:
 *          lzma压缩文件接口,target端仅含解压缩源码
 **************************************************************************/

#ifndef _LZMA_LIB_H_
#define _LZMA_LIB_H_

/*+\NEW\2013.7.11\liweiqiang\增加lzma解压buf到文件的接口*/
int LzmaDecodeBufToFile(const unsigned char *inbuff, const unsigned int inlen,
                        const char *outfile);
/*-\NEW\2013.7.11\liweiqiang\增加lzma解压buf到文件的接口*/

int LzmaUncompressFile(const char *infile, const char *outfile);

#endif/*_LZMA_LIB_H_*/

