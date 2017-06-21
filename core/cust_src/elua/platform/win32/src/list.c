/**************************************************************************
 *              ATWINCom Copyright (c) ATWINCom Ltd.
 *
 * Name: list.c
 *
 * Author: 李炜镪
 * Verison: V0.1
 * Date: 2009.11.30
 *
 * File Description:
 *
 *      实现通用链表
 **************************************************************************/
#include "list.h"
#define NULL 0
void list_add_before(list_head *node, list_head *pos)
{
  node->prev = pos->prev;
  node->next = pos;
  pos->prev->next = node;
  pos->prev = node;
}

void list_add_after(list_head *node, list_head *pos)
{
  	if(pos->next==NULL && pos->prev == NULL) //空链表
	{
		pos->next = node;
		node->prev= pos;
		node->next =NULL;
	}
  	else
	{
		node->prev = pos;
		node->next = pos->next;
		pos->next->prev = node;
		pos->next = node;
	}
}

void list_del(list_head *node)
{
  node->prev->next = node->next;
  node->next->prev = node->prev;
}

