
#ifndef __SERIAL_H__
#define __SERIAL_H__

int serial_open(const char *port_name, int baudrate);
void serial_close(int h_port);
int serial_write(int h_port, uint8_t *data, uint32_t len);
int serial_read(int h_port, uint8_t *data, uint32_t len);

#endif
