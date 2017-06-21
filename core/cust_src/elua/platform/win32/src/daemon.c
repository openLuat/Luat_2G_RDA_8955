
#include <stdio.h>
#include <WINDOWS.H>
#include "type.h"
#include "event.h"
#include "util.h"

static int daemon_socket = INVALID_SOCKET;
static SOCKADDR_IN server_addr;

void daemon_emit_event(unsigned char id, const char *data, int length){
    uint8 *packet;
    uint16 pos = 0;
    uint16 packet_len;

    if(INVALID_SOCKET == daemon_socket){
        return;
    }

    packet_len = length+1+2;    
    packet = malloc(packet_len);
    
    net_store_16(packet, pos, packet_len);
    pos += 2;

    packet[pos++] = id;

    memcpy(&packet[pos], data, length);

    sendto(daemon_socket, packet, packet_len, 0, (SOCKADDR*)&server_addr, sizeof(SOCKADDR_IN));

    free(packet);
}

void daemon_close(void){
    if(INVALID_SOCKET == daemon_socket){
        return;
    }

    closesocket(daemon_socket);
    daemon_socket = INVALID_SOCKET;
}

DWORD daemon_thread_entry(LPVOID p){
    struct sockaddr_in local_addr;
    WSADATA wsa_data;    
    int ret;
    fd_set fdr;
    uint8 buf[1000];
    int rcvdlen;
    int addrlen = sizeof(struct sockaddr_in);

    // Initialize Windows socket library
    WSAStartup(0x0202, &wsa_data);

    daemon_socket = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    
	
    memset(&local_addr, 0, sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_port = htons(22887);
    local_addr.sin_addr.S_un.S_addr = inet_addr("127.0.0.1");	
	
	
    if(bind(daemon_socket, (struct sockaddr *)&local_addr, sizeof(local_addr)) == -1){			
        printf("error:local port 22887 is used! daemon_socket=%d,id=%d\n",daemon_socket,WSAGetLastError());
        closesocket(daemon_socket);
        system("pause");
        exit(1);
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_addr.S_un.S_addr = inet_addr("127.0.0.1");
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(22888);
    
    FD_ZERO(&fdr);
    FD_SET(daemon_socket, &fdr);

    while(1){
        ret = select(0, &fdr, NULL, NULL, NULL);

        if(ret == 0){
            continue;
        }

        if(FD_ISSET(daemon_socket, &fdr)){
            rcvdlen = recvfrom(daemon_socket, buf, sizeof(buf), 0, (struct sockaddr *)&server_addr, &addrlen);
            if(rcvdlen > 2){
                uint16 packet_len = READ_NET_16(buf, 0);
                
                if(packet_len == rcvdlen){
                    dispatch_event(&buf[2], rcvdlen-2);
                }
            }
        }
    }
}