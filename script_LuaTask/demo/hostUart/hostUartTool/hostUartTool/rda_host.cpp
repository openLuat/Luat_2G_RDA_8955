
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "defines.h"
#include "debug.h"
#include "rda_host.h"

#define GET_NEXT_READ_ID()          global_read_id = (global_read_id == 0xff ? (1) : (++global_read_id))

static uint8_t global_read_id = 1;

extern int hal_uart_read(uint8_t *data, int len);
extern int hal_uart_write(uint8_t *data, int len);

static void __inline store_16_be(uint8_t *buffer, uint16_t pos, uint16_t value){
    buffer[pos++] = value >> 8;
    buffer[pos++] = value;
}

static void __inline store_32_le(uint8_t *buffer, uint16_t pos, uint32_t value){
    buffer[pos++] = value;
    buffer[pos++] = value >> 8;
    buffer[pos++] = value >> 16;
    buffer[pos++] = value >> 24;
}

void rda_host_init(void){
    global_read_id = 1;
}

static uint8_t calc_crc(const uint8_t *buf, uint16_t len){
    uint16_t i;
    uint8_t crc_val = buf[0];

    for(i = 1; i < len; i++){
        crc_val ^= buf[i];
    }

    return crc_val;
}

static int _read_byte(uint8_t *data){
    int count = 2;

    do {
        if(hal_uart_read(data, 1) > 0){
            return ERR_HOST_NONE;
        }
        Sleep(1);
    } while(--count);

    return ERR_TIMEOUT;
}

static uint8_t __forceinline _write_byte_withesc(uint8_t *buf, uint8_t data){
    uint8_t *p_buf = buf;
    
    if(data == 0x11 || data == 0x13 || data == 0x5c){
        *p_buf++ = 0x5c;
        data = 0xff - data;
    }
    *p_buf++ = data;

    return p_buf - buf;
}

static int _read_without_esc(uint8_t *data, uint16_t len){
    uint16_t rcvd_len = 0;
    uint8_t data_byte;

    do {
        if(_read_byte(&data_byte) < 0){
            return ERR_TIMEOUT;
        }

        if(data_byte != 0x5c){
            data[rcvd_len++] = data_byte;
            continue;
        }

        if(_read_byte(&data_byte) < 0){
            return ERR_TIMEOUT;
        }

        switch(data_byte){
            case 0xee:
                data_byte = 0x11;
                break;
        
            case 0xec:
                data_byte = 0x13;
                break;
        
            case 0xa3:
                data_byte = 0x5c;
                break;
        
            default:
                log_warn("esc char error 0x%02x", data_byte);
                return ERR_ESC_CHAR;
        }
        
        data[rcvd_len++] = data_byte;
    } while(rcvd_len < len);

    return ERR_HOST_NONE;
}

int rda_host_read_luat_packet(rda_host_packet_t *packet, uint32_t timeout_ms){
    uint8_t buf[sizeof(packet->buf)+5];
	clock_t clock_start = clock();
    
    do{
        if(_read_without_esc(buf, 1) < 0){ // read head 0xad
            goto l_continue_read;
        }

        if(buf[0] != 0xad){
            goto l_continue_read;
        }

        if(_read_without_esc(buf, 2) < 0){ // read packet length
            goto l_continue_read;
        }

        memset(packet, 0, sizeof(packet));
        
        packet->len = (buf[0]<<8) | buf[1];

        if(packet->len == 0 || packet->len == 1){ // 不允许只带ID的数据，必须包含ID与数据
            log_warn("[read_packet]:len error %d", packet->len);
            goto l_continue_read;
        }

        if(_read_without_esc(packet->buf, MIN(packet->len, sizeof(buf))) < 0){
            goto l_continue_read;
        }
        
        if(packet->len > sizeof(buf)){
            uint16_t rest = packet->len - sizeof(buf); // 已读过1包数据了
            uint16_t read_len = 0;
            
            do{
                read_len = MIN(rest, sizeof(buf));
                if(_read_without_esc(buf, read_len) < 0){
                    break;
                }
                rest -= read_len;
            }while(rest > 0);

            if(rest > 0) continue; // 出现异常没有读完数据
        }
        
        // read crc
        if(_read_without_esc(buf, 1) < 0){
            goto l_continue_read;
        }

        if(packet->len < sizeof(packet->buf)){ // 只有接收了全部数据才验证crc
            uint8_t data_crc = calc_crc(packet->buf, packet->len);

            if(data_crc != buf[0]){
                log_warn("[read_packet]: crc error %d %d", data_crc, buf[0]);
                goto l_continue_read;
            }
        }
    
        if(packet->buf[0] != LUAT_HOST_PID){
            goto l_continue_read;
        }
		
		// 去掉头部的ID信息
		memmove(packet->buf, &packet->buf[1], packet->len - 1);
		packet->len -= 1;

        // 接收到完整包 退出循环
        return ERR_HOST_NONE;
        
    l_continue_read: ;
    } while((clock() - clock_start)*1000 < (timeout_ms*CLOCKS_PER_SEC));

    return ERR_TIMEOUT;
}

int rda_host_write_packet(uint8_t id, const uint8_t *data, uint16_t len){
    uint8_t head[4];
    uint16_t i;
    uint8_t crc_val;
    uint16_t data_len = len + 1/*id*/;
    uint8_t buf[0xffff];
    uint8_t *p_buf = buf;

    head[0] = 0xad;
    store_16_be(head, 1, data_len);
    head[3] = id;

    for(i = 0; i < sizeof(head); i++){
        p_buf += _write_byte_withesc(p_buf, head[i]);
    }

    crc_val = calc_crc(&head[3], sizeof(head) - 3);

    if(data){
        for (i = 0; i < len; i++){
             p_buf += _write_byte_withesc(p_buf, data[i]);
        }
        
        crc_val = crc_val ^ calc_crc(data, len);
    }

    p_buf += _write_byte_withesc(p_buf, crc_val);

    hal_uart_write(buf, p_buf - buf);
    
    return p_buf - buf;
}
