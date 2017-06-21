/**************************************************************************
 *				Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:	cycle_queue.h
 * Author:	liweiqiang
 * Version: V0.1
 * Date:	2012/7/24
 *
 * Description:
 * 
 **************************************************************************/

#ifndef __CYCLE_QUEUE_H__
#define __CYCLE_QUEUE_H__

typedef struct {
    uint8 *buf;
    uint32 size;        
    uint32 head;
    uint32 tail;
    unsigned empty: 1;
    unsigned full:  1;
    unsigned overflow:  1;  
}CycleQueue;

void QueueClean(CycleQueue *Q_ptr);

int QueueInsert(CycleQueue *Q_ptr, uint8 *data, uint32 len);

int QueueDelete(CycleQueue *Q_ptr, uint8 *data, uint32 len);
    
#endif //__CYCLE_QUEUE_H__