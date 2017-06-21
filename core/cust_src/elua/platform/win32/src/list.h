/**************************************************************************
 *              ATWINCom Copyright (c) ATWINCom Ltd.
 *
 * Name: list.h
 *
 * Author: 李炜镪
 * Verison: V0.1
 * Date: 2009.11.30
 *
 * File Description:
 *
 *      实现通用链表
 **************************************************************************/

typedef struct list_head_tag
{
  struct list_head_tag *prev;
  struct list_head_tag *next;
}list_head;

#define list_for_each(pos, head) \
    for ( pos = (head)->next; \
          pos != (head); \
          pos = pos->next)

#define list_for_each_safe(pos,pos_next,head) \
    for ( pos = (head)->next, pos_next = pos->next; \
          pos != (head); \
          pos = pos_next, pos_next = pos->next)

#define list_empty(head) (head->next == head)

#if 1
/* 为提高通用链表的使用效率,请将list变量定义为结构体的第一个变量 */
#define list_entry(ptr, type, member) ((type*)ptr)
#else
/* 使用该宏定义,可以在使用通用链表时,随便定义list的变量位置 */
#define list_entry(ptr, type, member) ((type*)((char*)ptr - offsetof(type,member)))
#endif


#define init_list_head(ptr) \
    do{\
        (ptr)->prev = ptr;  \
        (ptr)->next = ptr;  \
    }while(0)

extern void list_add_before(list_head *node, list_head *pos);

extern void list_add_after(list_head *node, list_head *pos);

extern void list_del(list_head *node);
