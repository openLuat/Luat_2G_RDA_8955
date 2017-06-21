/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    lzmalib.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/5/10
 *
 * Description:
 *          lzma压缩文件接口,target端仅含解压缩源码
 **************************************************************************/

#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dlmalloc.h"
#include "7zFile.h"
#include "LzmaDec.h"

static void *SzAlloc(void *p, size_t size) { p = p; return dlmalloc(size); }
static void SzFree(void *p, void *address) { p = p; dlfree(address); }
static ISzAlloc g_Alloc = { SzAlloc, SzFree };

#if 0
#define IN_BUF_SIZE (16*1024)
#define OUT_BUF_SIZE (16*1024)

static SRes Decode2(CLzmaDec *state, ISeqOutStream *outStream, ISeqInStream *inStream,
    UInt64 unpackSize)
{
  int thereIsSize = (unpackSize != (UInt64)(Int64)-1);
  SRes res;
  Byte *inBuf = SzAlloc(NULL, IN_BUF_SIZE);
  Byte *outBuf = SzAlloc(NULL, OUT_BUF_SIZE);
  size_t inPos = 0, inSize = 0, outPos = 0;

  if(inBuf == NULL || outBuf == NULL)
  {
    res = SZ_ERROR_MEM;
    goto decode2_exit;
  }
  
  LzmaDec_Init(state);
  for (;;)
  {
    if (inPos == inSize)
    {
      inSize = IN_BUF_SIZE;
      if((res = inStream->Read(inStream, inBuf, &inSize)) != SZ_OK)
      {
        goto decode2_exit;
      }
      inPos = 0;
    }
    {
      SizeT inProcessed = inSize - inPos;
      SizeT outProcessed = OUT_BUF_SIZE - outPos;
      ELzmaFinishMode finishMode = LZMA_FINISH_ANY;
      ELzmaStatus status;
      if (thereIsSize && outProcessed > unpackSize)
      {
        outProcessed = (SizeT)unpackSize;
        finishMode = LZMA_FINISH_END;
      }
      
      res = LzmaDec_DecodeToBuf(state, outBuf + outPos, &outProcessed,
        inBuf + inPos, &inProcessed, finishMode, &status);
      inPos += inProcessed;
      outPos += outProcessed;
      unpackSize -= outProcessed;
      
      if (outStream)
        if (outStream->Write(outStream, outBuf, outPos) != outPos)
        {
          res = SZ_ERROR_WRITE;
          goto decode2_exit;
        }
        
      outPos = 0;
      
      if (res != SZ_OK || (thereIsSize && unpackSize == 0))
        goto decode2_exit;
      
      if (inProcessed == 0 && outProcessed == 0)
      {
        if (thereIsSize || status != LZMA_STATUS_FINISHED_WITH_MARK)
          res = SZ_ERROR_DATA;
        goto decode2_exit;
      }
    }
  }

decode2_exit:
  if(inBuf)
  {
    SzFree(NULL, inBuf);
  }

  if(outBuf)
  {
    SzFree(NULL, outBuf);
  }
  
  return res;
}

static SRes Decode(ISeqOutStream *outStream, ISeqInStream *inStream)
{
  UInt64 unpackSize;
  int i;
  SRes res = 0;

  CLzmaDec state;

  /* header: 5 bytes of LZMA properties and 8 bytes of uncompressed size */
  unsigned char header[LZMA_PROPS_SIZE + 8];

  /* Read and parse header */

  RINOK(SeqInStream_Read(inStream, header, sizeof(header)));

  unpackSize = 0;
  for (i = 0; i < 8; i++)
    unpackSize += (UInt64)header[LZMA_PROPS_SIZE + i] << (i * 8);

  LzmaDec_Construct(&state);
  RINOK(LzmaDec_Allocate(&state, header, LZMA_PROPS_SIZE, &g_Alloc));
  res = Decode2(&state, outStream, inStream, unpackSize);
  LzmaDec_Free(&state, &g_Alloc);
  return res;
}

int LzmaUncompressFile(const char *infile, const char *outfile)
{
  CFileSeqInStream inStream;
  CFileOutStream outStream;
  int res;

  FileSeqInStream_CreateVTable(&inStream);
  File_Construct(&inStream.file);

  FileOutStream_CreateVTable(&outStream);
  File_Construct(&outStream.file);

  if (InFile_Open(&inStream.file, infile) != 0)
  {
    printf("[LzmaUncompressFile]:open infile(%s) failed!", infile);
    return SZ_ERROR_FAIL;
  }

  if (OutFile_Open(&outStream.file, outfile) != 0)
  {
    printf("[LzmaUncompressFile]:open outfile(%s) failed!", outfile);
    return SZ_ERROR_FAIL;
  }

  res = Decode(&outStream.s, &inStream.s);

  File_Close(&outStream.file);
  File_Close(&inStream.file);

  return res;
}
#else
/*+\NEW\liweiqiang\2013.7.1\作长时间运算时自动调节主频加快运算速度*/
extern void platform_sys_set_max_freq(void);
extern void platform_sys_set_min_freq(void);
/*-\NEW\liweiqiang\2013.7.1\作长时间运算时自动调节主频加快运算速度*/

#define LZMA_HEAD_SIZE (LZMA_PROPS_SIZE + 8/*unpack size*/)

static SRes DecodeToBuf(Byte *dstBuf, const Byte *srcBuf, SizeT srcLen, SizeT unpackSize)
{
  int thereIsSize = (unpackSize != -1);
  SRes res = SZ_OK;
  CLzmaDec state;
  ELzmaStatus status;
  SizeT inProcessed = srcLen - LZMA_HEAD_SIZE;
  SizeT outProcessed = unpackSize;

  LzmaDec_Construct(&state);
  RINOK(LzmaDec_Allocate(&state, srcBuf, LZMA_PROPS_SIZE, &g_Alloc));
  LzmaDec_Init(&state);

/*+\NEW\liweiqiang\2013.7.1\作长时间运算时自动调节主频加快运算速度*/
#ifndef WIN32
  platform_sys_set_max_freq();
#endif
  res = LzmaDec_DecodeToBuf(&state, dstBuf, &outProcessed, &srcBuf[LZMA_HEAD_SIZE], &inProcessed, LZMA_FINISH_END, &status);
#ifndef WIN32
  platform_sys_set_min_freq();
#endif
/*-\NEW\liweiqiang\2013.7.1\作长时间运算时自动调节主频加快运算速度*/
  unpackSize -= outProcessed;

/*+\NEW\liweiqiang\2013.5.16\修正不完整的解压文件不会报错的问题 */
  if (thereIsSize)
  {
    res = unpackSize == 0 ? SZ_OK : SZ_ERROR_INPUT_EOF;
  }
  
  if (res != SZ_OK)
  {
    goto decode_exit;
  }
/*-\NEW\liweiqiang\2013.5.16\修正不完整的解压文件不会报错的问题 */
  
  if (inProcessed == 0 && outProcessed == 0)
  {
    if (thereIsSize || status != LZMA_STATUS_FINISHED_WITH_MARK)
      res = SZ_ERROR_DATA;
    goto decode_exit;
  }

decode_exit:
  LzmaDec_Free(&state, &g_Alloc);
  return res;
}

int LzmaDecodeBufToBuf(const unsigned char *inbuff, const unsigned int inlen,
                       unsigned char **ppOutBuf)
{
    int ret = SZ_ERROR_FAIL;
    SizeT outlen, i;
    Byte *outbuff = NULL;
    /* header: 5 bytes of LZMA properties and 8 bytes of uncompressed size */
    UInt64 unpackSize = 0;

    if(inlen <= LZMA_HEAD_SIZE)
    {
        printf("[LzmaDecodeBufToBuf]: inbuff len(%d) too short!\n", inlen);
        ret = SZ_ERROR_INPUT_EOF;
        goto uncompress_b2b_exit;
    }

    for (i = 0; i < 8; i++)
        unpackSize += (UInt64)inbuff[LZMA_PROPS_SIZE + i] << (i * 8);
    
    if(unpackSize>>31)
    {
        ret = SZ_ERROR_MEM;
        goto uncompress_b2b_exit;
    }
    
    outlen = (SizeT)unpackSize;
    outbuff = SzAlloc(NULL, outlen);
    if(!outbuff)
    {
        printf("[LzmaDecodeBufToBuf]:not enough memory(%d) for outbuff.\n", outlen);
        ret = SZ_ERROR_MEM;
        goto uncompress_b2b_exit;
    }
    
    if((ret = DecodeToBuf(outbuff, inbuff, inlen, outlen)) != SZ_OK)
    {
        printf("[LzmaDecodeBufToBuf]: decode error(%d)!\n", ret);
        goto uncompress_b2b_exit;
    }

uncompress_b2b_exit:
    if(ret != SZ_OK)
    {
        if(outbuff)
            SzFree(NULL, outbuff);

        outbuff = NULL;
    }

    *ppOutBuf = outbuff;

    return ret;
}

/*+\NEW\2013.7.11\liweiqiang\增加lzma解压buf到文件的接口*/
int LzmaDecodeBufToFile(const unsigned char *inbuff, const unsigned int inlen,
                       const char *outfile)
{
    FILE *fout = NULL;
    int ret = SZ_ERROR_FAIL;
    SizeT outlen, i;
    Byte *outbuff = NULL;
    /* header: 5 bytes of LZMA properties and 8 bytes of uncompressed size */
    UInt64 unpackSize = 0;
    
    if(inlen <= LZMA_HEAD_SIZE)
    {
        printf("[LzmaDecodeBufToFile]: inbuff len(%d) too short!\n", inlen);
        ret = SZ_ERROR_INPUT_EOF;
        goto uncompress_b2f_exit;
    }
    
    for (i = 0; i < 8; i++)
        unpackSize += (UInt64)inbuff[LZMA_PROPS_SIZE + i] << (i * 8);
    
    if(unpackSize>>31)
    {
        ret = SZ_ERROR_MEM;
        goto uncompress_b2f_exit;
    }
    
    outlen = (SizeT)unpackSize;
    outbuff = SzAlloc(NULL, outlen);
    if(!outbuff)
    {
        printf("[LzmaDecodeBufToFile]:not enough memory(%d) for outbuff.\n", outlen);
        ret = SZ_ERROR_MEM;
        goto uncompress_b2f_exit;
    }
    
    if((ret = DecodeToBuf(outbuff, inbuff, inlen, outlen)) != SZ_OK)
    {
        printf("[LzmaDecodeBufToFile]: decode error(%d)!\n", ret);
        goto uncompress_b2f_exit;
    }

/*+\NEW\liweiqiang\2013.10.24\修正二进制文件解压异常 */
    fout = fopen(outfile, "wb");
/*-\NEW\liweiqiang\2013.10.24\修正二进制文件解压异常 */
    if(!fout)
    {
        printf("[LzmaUncompressFile]:out file(%s) open failed!\n", outfile);
        ret = SZ_ERROR_FAIL;
        goto uncompress_b2f_exit;
    }
    
    if(fwrite(outbuff, 1, outlen, fout) != outlen)
    {
        printf("[LzmaUncompressFile]: write file error!\n");
        fclose(fout);
        fout = NULL;
        remove(outfile); //写文件失败,删除已写的文件.
        ret = SZ_ERROR_FAIL;
        goto uncompress_b2f_exit;
    }
    fclose(fout);
    fout = NULL;
    
uncompress_b2f_exit:
    if(outbuff)
        SzFree(NULL, outbuff);
    
    if(fout)
        fclose(fout);
    
    return ret;
}
/*-\NEW\2013.7.11\liweiqiang\增加lzma解压buf到文件的接口*/

int LzmaUncompressFile(const char *infile, const char *outfile)
{
    FILE *fin = NULL, *fout = NULL;
    int ret = SZ_ERROR_FAIL;
    SizeT inlen, outlen, i;
    unsigned char *inbuff = NULL;
    unsigned char *outbuff = NULL;
    
    /* header: 5 bytes of LZMA properties and 8 bytes of uncompressed size */
    UInt64 unpackSize = 0;

    fin = fopen(infile, "rb");
    if(!fin)
    {
        printf("[LzmaUncompressFile]: open infile(%s) failed!\n", infile);
        ret = SZ_ERROR_FAIL;
        goto uncompress_exit;
    }
    
    fseek(fin, 0, SEEK_END);
    inlen = ftell(fin);

/*+\NEW\liweiqiang\2013.5.16\修正不完整的解压文件不会报错的问题 */
    // 文件长度必须大于头信息的长度
    if(inlen <= LZMA_HEAD_SIZE)
    {
        printf("[LzmaUncompressFile]: infile len(%d) too short!\n", inlen);
        ret = SZ_ERROR_INPUT_EOF;
        goto uncompress_exit;
    }
/*-\NEW\liweiqiang\2013.5.16\修正不完整的解压文件不会报错的问题 */
    
    fseek(fin, 0, SEEK_SET);
    inbuff = SzAlloc(NULL, inlen);
    
    if(!inbuff)
    {
        ret = SZ_ERROR_MEM;
        goto uncompress_exit;
    }
    
    if(fread(inbuff, 1, inlen, fin) != inlen)
    {
        printf("[LzmaUncompressFile]: read file error!\n");
        ret = SZ_ERROR_INPUT_EOF;
        goto uncompress_exit;
    }
    fclose(fin);
    fin = NULL;

    for (i = 0; i < 8; i++)
        unpackSize += (UInt64)inbuff[LZMA_PROPS_SIZE + i] << (i * 8);
    
    if(unpackSize>>31)
    {
        ret = SZ_ERROR_MEM;
        goto uncompress_exit;
    }

    outlen = (SizeT)unpackSize;
    outbuff = SzAlloc(NULL, outlen);
    if(!outbuff)
    {
        printf("[LzmaUncompressFile]:not enough memory(%d) for outbuff.\n", outlen);
        ret = SZ_ERROR_MEM;
        goto uncompress_exit;
    }
    
    if((ret = DecodeToBuf(outbuff, inbuff, inlen, outlen)) != SZ_OK)
    {
        printf("[LzmaUncompressFile]: uncompress file(%s) error(%d)!\n", infile, ret);
        goto uncompress_exit;
    }

/*+\NEW\liweiqiang\2013.10.24\修正二进制文件解压异常 */
    fout = fopen(outfile, "wb");
/*-\NEW\liweiqiang\2013.10.24\修正二进制文件解压异常 */
    if(!fout)
    {
        printf("[LzmaUncompressFile]:out file(%s) open failed!\n", outfile);
        ret = SZ_ERROR_FAIL;
        goto uncompress_exit;
    }
    
    if(fwrite(outbuff, 1, outlen, fout) != outlen)
    {
        printf("[LzmaUncompressFile]: write file error!\n");
        fclose(fout);
        fout = NULL;
        remove(outfile); //写文件失败,删除已写的文件.
        ret = SZ_ERROR_FAIL;
        goto uncompress_exit;
    }
    fclose(fout);
    fout = NULL;
        
uncompress_exit:
    if(inbuff)
        SzFree(NULL, inbuff);

    if(outbuff)
        SzFree(NULL, outbuff);

    if(fin)
        fclose(fin);

    if(fout)
        fclose(fout);

    return ret;
}
#endif

