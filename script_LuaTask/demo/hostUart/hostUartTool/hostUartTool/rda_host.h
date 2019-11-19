
#ifndef __RDA_HOST_H__
#define __RDA_HOST_H__

#include <stdint.h>

#define WAIT_FOREVER                        (0xffffffffU)

typedef struct{
    uint8_t buf[0xffff];
    uint16_t len;
}rda_host_packet_t;

typedef enum {
    ERR_HOST_NONE = 0,
    ERR_TIMEOUT = -1,
    ERR_BUFF_LIMIT = -2,
    ERR_ESC_CHAR = -3,
    ERR_PARAM = -4,
    ERR_PC_REQ = -5,
} rda_host_error_code_t;

// luat host口通讯包的id
#define LUAT_HOST_PID	(0xA2)

void rda_host_init(void);

int rda_host_read_luat_packet(rda_host_packet_t *packet, uint32_t timeout_ms);
int rda_host_write_packet(uint8_t id, const uint8_t *data, uint16_t len);

#define rda_host_write_luat_packet(d, l) rda_host_write_packet(LUAT_HOST_PID, (d), (l))

#endif/*__RDA_HOST_H__*/

