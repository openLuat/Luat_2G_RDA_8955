
#include <stdint.h>
#include <stdio.h>
#include <windows.h>

int serial_open(const char *port_name, int baudrate){
	HANDLE h_port;
	COMMTIMEOUTS timeouts;
	DCB dcb;
    int com_port_no = 0;
    char buf[1024];

    if(sscanf(port_name, "COM%d", &com_port_no) == 0) return -1;

    if(com_port_no > 10){
        sprintf(buf, "\\\\.\\COM%d", com_port_no);
    } else {
        strcpy(buf, port_name);
    }

    h_port = CreateFileA(buf, GENERIC_READ|GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);

	if((int)h_port == -1) return -1;

	memset(&dcb, 0, sizeof(dcb));
	dcb.BaudRate = baudrate;
	dcb.ByteSize = 8;
	dcb.Parity = NOPARITY;
	dcb.StopBits = ONESTOPBIT;
	dcb.fBinary = TRUE;
	SetCommState(h_port, &dcb);

	timeouts.ReadIntervalTimeout = MAXDWORD;
	timeouts.ReadTotalTimeoutMultiplier = 0;
	timeouts.ReadTotalTimeoutConstant = 0;
	timeouts.WriteTotalTimeoutMultiplier = 100;
	timeouts.WriteTotalTimeoutConstant = 500;
	SetCommTimeouts(h_port, &timeouts);

	PurgeComm(h_port, PURGE_TXCLEAR|PURGE_RXCLEAR);

	return (int)h_port;
}

void serial_close(int h_port){
	if(h_port == -1) return;

	CloseHandle((HANDLE)h_port);
}

int serial_write(int h_port, uint8_t *data, uint32_t len){
	DWORD wrote_len;
	if(h_port == -1) return -1;
	PurgeComm((HANDLE)h_port, PURGE_TXABORT|PURGE_RXABORT|PURGE_TXCLEAR|PURGE_RXCLEAR);
	WriteFile((HANDLE)h_port, data, len, &wrote_len, NULL);
	return 0;
}

int serial_read(int h_port, uint8_t *data, uint32_t len){
	int rc;
	DWORD recv_count;

	if(h_port == -1) return -1;
	
	rc = ReadFile((HANDLE)h_port, data, len, &recv_count, NULL);

	if(!rc)
		return -1;
	
	return (int)recv_count;
}
