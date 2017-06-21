
#ifndef _UTIL_H_
#define _UTIL_H_

#include "type.h"

#define READ_NET_16( buffer, pos) ( ((uint16) buffer[pos+1]) | (((uint16)buffer[pos  ]) << 8))
#define READ_NET_32( buffer, pos) ( ((uint32) buffer[pos+3]) | (((uint32)buffer[pos+2]) << 8) | (((uint32)buffer[pos+1]) << 16) | (((uint32) buffer[pos])) << 24)

__inline void net_store_16(uint8 *buffer, uint16 pos, uint16 value){
    buffer[pos++] = value >> 8;
    buffer[pos++] = value;
}

__inline void net_store_32(uint8 *buffer, uint16 pos, uint32 value){
    buffer[pos++] = value >> 24;
    buffer[pos++] = value >> 16;
    buffer[pos++] = value >> 8;
    buffer[pos++] = value;
}

#endif