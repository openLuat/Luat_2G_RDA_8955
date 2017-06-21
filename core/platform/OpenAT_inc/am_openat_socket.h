/*********************************************************
  Copyright (C), AirM2M Tech. Co., Ltd.
  Author: brezen
  Description: AMOPENAT 开放平台
  Others:
  History: 
    Version： Date:       Author:   Modification:
    V0.1      2012.09.24  brezen    创建文件
*********************************************************/
#ifndef AM_OPENAT_SOCKET_H
#define AM_OPENAT_SOCKET_H

#ifdef __cplusplus
#if __cplusplus
extern "C"{
#endif
#endif /* __cplusplus */

/*----------------------------------------------*
 * 包含头文件                                   *
 *----------------------------------------------*/
#include <am_openat_common.h>
/*----------------------------------------------*
 * 宏定义                                       *
 *----------------------------------------------*/

typedef uint32 socklen_t;

#undef  FD_SETSIZE
#define FD_SETSIZE    256
#define FD_SET(n, p)  ((p)->fd_bits[(n)/8] |=  (1 << ((n) & 7)))
#define FD_CLR(n, p)  ((p)->fd_bits[(n)/8] &= ~(1 << ((n) & 7)))
#define FD_ISSET(n,p) ((p)->fd_bits[(n)/8] &   (1 << ((n) & 7)))
#define FD_ZERO(p)    memset((VOID*)(p),0,sizeof(*(p)))

typedef struct fd_set_tag
{
	UINT8 fd_bits[(FD_SETSIZE + 7) / 8];
} fd_set;
struct timeval
{
	uint32 tv_sec;		/* seconds */
	uint32 tv_usec;		/* and microseconds */
};


/*
 * Definitions related to sockets: types, address families, options.
 */

/*
 * Types
 */
typedef enum SocketTypeTag
{
  SOCK_STREAM	   = 1,		/* stream socket */
  SOCK_DGRAM	   = 2,		/* datagram socket */
  SOCK_RAW	     = 3,		/* raw-protocol interface */
  SOCK_RDM	     = 4,		/* reliably-delivered message */
  SOCK_SEQPACKET = 5		/* sequenced packet stream */
} SocketType;

/*
 * Option flags per-socket.
 */
#define SO_DEBUG            0x0001        /* turn on debugging info recording */
#define SO_ACCEPTCONN       0x0002        /* socket has had listen() */
#define SO_REUSEADDR        0x0004        /* allow local address reuse */
#define SO_KEEPALIVE        0x0008        /* keep connections alive */
#define SO_DONTROUTE        0x0010        /* just use interface addresses */
#define SO_BROADCAST        0x0020        /* permit sending of broadcast msgs */
#define SO_USELOOPBACK      0x0040        /* bypass hardware when possible */
#define SO_LINGER           0x0080        /* linger on close if data present */
#define SO_OOBINLINE        0x0100        /* leave received OOB data in line */
#define SO_REUSEPORT        0x0200        /* allow local address & port reuse */
#define SO_TIMESTAMP        0x0400        /* timestamp received dgram traffic */
#define SO_TCP_NODELAY      0x0800        /* tcp no-delay (disable Nagle algo) */
#define SO_TCP_SACKDISABLE  0x1000        /* tcp SACK disable */
/*
 * Additional options, not kept in so_options.
 */
#define SO_SNDBUF	0x1001		/* send buffer size */
#define SO_RCVBUF	0x1002		/* receive buffer size */
#define SO_SNDLOWAT	0x1003		/* send low-water mark */
#define SO_RCVLOWAT	0x1004		/* receive low-water mark */
#define SO_SNDTIMEO	0x1005		/* send timeout */
#define SO_RCVTIMEO	0x1006		/* receive timeout */
#define	SO_ERROR	0x1007		/* get error status and clear */
#define	SO_TYPE		0x1008		/* get socket type */
#define	SO_PRIVSTATE	0x1009		/* get/deny privileged state */

/*
 * Structure used for manipulating linger option.
 */
struct	linger
{
	uint16	l_onoff;		/* option on/off */
	uint16 l_linger;		/* linger time */
};

/*
 * Level number for (get/set)sockopt() to apply to socket itself.
 */
#define	SOL_SOCKET    0xffff    /* options for socket level */
#define IPPROTO_IP    0         /* internet control protocol */
#define IPPROTO_ICMP  1         /* control message protocol */
#define IPPROTO_TCP   6         /* tcp */
#define IPPROTO_UDP   17        /* user datagram protocol */

/*
 * Address families.
 */
#define	AF_UNSPEC	0		/* unspecified */
#define	AF_LOCAL	1		/* local to host (pipes, portals) */
#define	AF_UNIX		AF_LOCAL	/* backward compatibility */
#define	AF_INET		2		/* internetwork: UDP, TCP, etc. */
#define	AF_IMPLINK	3		/* arpanet imp addresses */
#define	AF_PUP		4		/* pup protocols: e.g. BSP */
#define	AF_CHAOS	5		/* mit CHAOS protocols */
#define	AF_NS		6		/* XEROX NS protocols */
#define	AF_ISO		7		/* ISO protocols */
#define	AF_OSI		AF_ISO
#define	AF_ECMA		8		/* European computer manufacturers */
#define	AF_DATAKIT	9		/* datakit protocols */
#define	AF_CCITT	10		/* CCITT protocols, X.25 etc */
#define	AF_SNA		11		/* IBM SNA */
#define AF_DECnet	12		/* DECnet */
#define AF_DLI		13		/* DEC Direct data link interface */
#define AF_LAT		14		/* LAT */
#define	AF_HYLINK	15		/* NSC Hyperchannel */
#define	AF_APPLETALK	16		/* Apple Talk */
#define	AF_ROUTE	17		/* Internal Routing Protocol */
#define	AF_LINK		18		/* Link layer interface */
#define	pseudo_AF_XTP	19		/* eXpress Transfer Protocol (no AF) */
#define	AF_COIP		20		/* connection-oriented IP, aka ST II */
#define	AF_CNT		21		/* Computer Network Technology */
#define pseudo_AF_RTIP	22		/* Help Identify RTIP packets */
#define	AF_IPX		23		/* Novell Internet Protocol */
#define	AF_SIP		24		/* Simple Internet Protocol */
#define	pseudo_AF_PIP	25		/* Help Identify PIP packets */
#define	AF_ISDN		26		/* Integrated Services Digital Network*/
#define	AF_E164		AF_ISDN		/* CCITT E.164 recommendation */
#define	pseudo_AF_KEY	27		/* Internal key-management function */
#define	AF_INET6	28		/* IPv6 */

#define	AF_MAX		29



/*
 * Structure used by kernel to store most
 * addresses.
 */

/*Job102781*/ 
/* WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
 *
 * We have had to do something very dirty here.
 * - The sockaddr struct as defined by BSD only contains 1 byte quantities
 * so it only requires 1 byte alignment.
 * - But, the sockaddr_in struct contains a 4 byte quantity ( the S_addr ) so
 * it requires 4 byte alignment.
 * - There are many places in the code were a sockaddr is cast to a sockaddr_in.
 * - When this occurs a data abort occurs 3 out of 4 times.
 *
 * Hence it is required to force the sockaddr to have 4 byte alignment as well.
 *
 * The simplest way I can see of doing it is to replace the 14-byte byte array
 * with a 2-byte byte array and 3 element uint32 array (which assumes an int is 4 bytes).
 *
 * This way assures :-
 * - that the sockaddr struct has 4-byte alignment, and
 * - that code can just access the byte array and read 14 bytes and get the data they expect.
 * However, it does mean the code is deliberately reading off the end of the byte array!
 *
 * WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
 */
struct sockaddr
{
	//uint8   sa_len;			/* total length */
  uint16   sa_family;		/* address family */
  char     sa_data_8[2];     /* actually longer; address value */
  uint32     sa_data_32[3]; /* actually longer; address value */
};

/** For compatibility with BSD code */
struct in_addr {
	uint32 s_addr;
};


struct in_address{
  uint32 s_addr;
};


struct sockaddr_in {
  //uint8 sin_len;
  uint16 sin_family;
  uint16 sin_port;
  struct in_address sin_addr;
  char sin_zero[8];
};
/* Address to accept any incoming messages. */

/** 255.255.255.255 */
#define INADDR_NONE         ((uint32_t)0xffffffffUL)
/** 127.0.0.1 */
#define INADDR_LOOPBACK     ((uint32_t)0x7f000001UL)
/** 0.0.0.0 */
#define INADDR_ANY          ((uint32_t)0x00000000UL)
/** 255.255.255.255 */
#define INADDR_BROADCAST    ((uint32_t)0xffffffffUL)

#define in_addr_t   ULONG
/*
 * Structure used by kernel to pass protocol
 * information in raw sockets.
 */
struct sockproto
{
	uint16 sp_family;		/* address family */
	uint16 sp_protocol;		/* protocol */
};

/*
 * Protocol families, same as address families for now.
 */
#define	PF_UNSPEC	AF_UNSPEC
#define	PF_LOCAL	AF_LOCAL
#define	PF_UNIX		PF_LOCAL	/* backward compatibility */
#define	PF_INET		AF_INET
#define	PF_IMPLINK	AF_IMPLINK
#define	PF_PUP		AF_PUP
#define	PF_CHAOS	AF_CHAOS
#define	PF_NS		AF_NS
#define	PF_ISO		AF_ISO
#define	PF_OSI		AF_ISO
#define	PF_ECMA		AF_ECMA
#define	PF_DATAKIT	AF_DATAKIT
#define	PF_CCITT	AF_CCITT
#define	PF_SNA		AF_SNA
#define PF_DECnet	AF_DECnet
#define PF_DLI		AF_DLI
#define PF_LAT		AF_LAT
#define	PF_HYLINK	AF_HYLINK
#define	PF_APPLETALK	AF_APPLETALK
#define	PF_ROUTE	AF_ROUTE
#define	PF_LINK		AF_LINK
#define	PF_XTP		pseudo_AF_XTP	/* really just proto family, no AF */
#define	PF_COIP		AF_COIP
#define	PF_CNT		AF_CNT
#define	PF_SIP		AF_SIP
#define	PF_IPX		AF_IPX		/* same format as AF_NS */
#define PF_RTIP		pseudo_AF_RTIP	/* same format as AF_INET */
#define PF_PIP		pseudo_AF_PIP
#define	PF_ISDN		AF_ISDN
#define	PF_KEY		pseudo_AF_KEY
#define	PF_INET6	AF_INET6

#define	PF_MAX		AF_MAX

/*
 * Maximum queue length specifiable by listen.
 */
#define SOMAXCONN   5

#define	MSG_OOB		    0x1     /* process out-of-band data */
#define	MSG_PEEK	    0x2	    /* peek at incoming message */
#define	MSG_DONTROUTE	0x4		  /* send without using routing tables */
#define	MSG_EOR		    0x8		  /* data completes record */
#define	MSG_TRUNC	    0x10	  /* data discarded before delivery */
#define	MSG_CTRUNC	  0x20	  /* control data lost before delivery */
#define	MSG_WAITALL	  0x40  	/* wait for full request or error */
#define	MSG_DONTWAIT	0x80  	/* this message should be nonblocking */
#define	MSG_EOF		    0x100		/* data completes connection */
#define MSG_COMPAT    0x8000	/* used in sendit() */

/*
 * Header for ancillary data objects in msg_control buffer.
 * Used for additional information with/about a datagram
 * not expressible by flags.  The format is a sequence
 * of message elements headed by cmsghdr structures.
 */
struct cmsghdr
{
	uint32	      cmsg_len;	    /* data byte count, including hdr */
	int32 cmsg_level;		/* originating protocol */
	int32 cmsg_type;		/* protocol-specific type */
/* followed by	u_char  cmsg_data[]; */
};

/* given pointer to struct cmsghdr, return pointer to data */
#define	CMSG_DATA(cmsg)		((u_char *)((cmsg) + 1))

/* "Socket"-level control message types: */
#define	SCM_RIGHTS	0x01		/* access rights (array of int) */
#define	SCM_TIMESTAMP	0x02		/* timestamp (struct timeval) */

/*
 * 4.3 compat sockaddr, move to compat file later
 */

/* PLEASE SEE NOTES PRIOR TO sockaddr STRUCTURE */
struct osockaddr
{
	uint16 sa_family;		/* address family */
  char     sa_data_8[2];  /* actually longer; address value */
	uint32	 sa_data_32[3];	/* actually longer; address value */
};

#define INVALID_SOCKET  (0xFFFFFFFFL)
#define SOCKET_ERROR    (0xFFFFFFFFL)



/* shudown() 'how' flags */
#define SD_READ         0x0001
#define SD_WRITE        0x0002
#define SD_BOTH         (SD_READ | SD_WRITE)


/*
  hostent structure - used by gethostbyname() and gethostbyaddr() functions
  to return host information.
*/
struct hostent
{
  char  *h_name;        /* Official host name */
  char  **h_aliases;    /* Null-terminated array of alternative names */
  uint16 h_addrtype;     /* Type of address being returned */
  uint16 h_length;       /* Length of each address, in bytes */
  char  **h_addr_list;  /* Null-terminated list of addresses for the host.
                         * Addresses are returned in network byte order.
                         */
};

/* Socket Event Flags */
#define SOCK_EVENT_READ       0x0001
#define SOCK_EVENT_WRITE      0x0002
#define SOCK_EVENT_OOB        0x0004
#define SOCK_EVENT_ACCEPT     0x0008
#define SOCK_EVENT_CONNECT    0x0010
#define SOCK_EVENT_CLOSE      0x0020
#define SOCK_EVENT_DNS        0x0040
#define SOCK_EVENT_DESTROYED  0x0080
#define SOCK_EVENT_LISTENING  0x0100
#define SOCK_EVENT_RECV_DATA 0x0200

typedef enum
{
  OPENAT_PING_SUCCESS,
  OPENAT_PING_TIMEOUT,
  OPENAT_PING_BUSY,
  OPENAT_PING_ERROR
}E_AMOPENAT_PING_RESULT;

typedef struct SockPingIndTag
{
  INT16                      seqNum;
  E_AMOPENAT_PING_RESULT     pingResult;
  INT32                      timems;
}E_AMOPENAT_PING_IND;

typedef void (*F_AMOPENAT_PING_IND)(E_AMOPENAT_PING_IND* ind);

 

/*----------------------------------------------*
 * 外部变量说明                                 *
 *----------------------------------------------*/

/*----------------------------------------------*
 * 外部函数原型说明                             *
 *----------------------------------------------*/

/*----------------------------------------------*
 * 内部函数原型说明                             *
 *----------------------------------------------*/

/*----------------------------------------------*
 * 全局变量                                     *
 *----------------------------------------------*/

/*----------------------------------------------*
 * 模块级变量                                   *
 *----------------------------------------------*/

/*----------------------------------------------*
 * 常量定义                                     *
 *----------------------------------------------*/

/*----------------------------------------------*
 * 宏定义                                       *
 *----------------------------------------------*/


#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif /* __cplusplus */


#endif /* AM_OPENAT_DRV_H */
