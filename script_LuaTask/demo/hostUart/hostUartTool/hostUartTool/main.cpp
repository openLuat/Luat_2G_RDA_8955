
#include <stdio.h>
#include <windows.h>
#include "debug.h"
#include "serial.h"
#include "rda_host.h"

int g_h_serial_port = -1;

int hal_uart_read(uint8_t *data, int len){
    return serial_read(g_h_serial_port, data, len);
}

int hal_uart_write(uint8_t *data, int len){
    return serial_write(g_h_serial_port, data, len);
}

int main(int argc, char* argv[])
{
	rda_host_packet_t packet;

	if (argc < 2) {
		printf("usage: hostUartTool com_port\nexample: hostUartTool COM1\n");
		return -1;
	}

	if((g_h_serial_port = serial_open(argv[1], 921600)) < 0) {
		log_error("open serial port failed");
		return -1;
	}

	log_info("host uart tool start...");

	while(1){
		rda_host_write_luat_packet((const uint8_t *)"hello", sizeof("hello") - 1);
		
		if(rda_host_read_luat_packet(&packet, 1000) != ERR_HOST_NONE) { // host传输数据有时候会丢包 属于正常现象
			log_warn("no response");
		} else {
			packet.buf[packet.len] = '\0';
			log_info("response: %s", packet.buf);
		}

		Sleep(1000);
	}

	return 0;
}
