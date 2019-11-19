#ifndef __DEBUG_H__
#define __DEBUG_H__

#include <stdint.h>
#include <stdio.h>

#define log_error(fmt, ...)		printf("[error]:" ## fmt ## "\r\n", ##__VA_ARGS__)

#define log_warn(fmt, ...)		printf("[warn]:" ## fmt ## "\r\n", ##__VA_ARGS__)
    
#define log_info(fmt, ...)		printf("[info]:" ## fmt ## "\r\n", ##__VA_ARGS__)

#define log_debug(fmt, ...)     printf("[debug]:" ## fmt ## "\r\n", ##__VA_ARGS__)

#endif /*__DEBUG_H__*/

