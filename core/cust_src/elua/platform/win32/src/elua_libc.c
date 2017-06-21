#undef fopen
#undef freopen
#undef malloc
#undef free
#undef printf
#undef fprintf
#undef vfprintf
#undef fwrite
#undef fputs

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>

FILE * elua_fopen(const char *name, const char *mode)
{
    FILE *file;
    static char tmpname[200];

    if(name[0] == '/')
    {
        sprintf(tmpname,"elua%s",name);
    }
    else
    {
        strcpy(tmpname,name);
    }

    file = fopen(tmpname,mode);
#if 0
    if(NULL == file)
    {
        printf("filename:%s\n",tmpname);
        perror("elua_fopen");
    }
#endif
    return file;
}


FILE * elua_freopen(const char *name, const char *mode, FILE *fp)
{
    FILE *file;
    static char tmpname[200];

    if(name[0] == '/')
    {
        sprintf(tmpname,"elua%s",name);
    }
    else
    {
        strcpy(tmpname,name);
    }

    return freopen(tmpname, mode, fp);
}

extern char *getLuaPath(void);
extern char *getLuaDir(void);
extern char *getLuaDataDir(void);

char *lualibc_getenv(const char *name)
{
    if(strcmp(name, "LUA_PATH") == 0)
        return getLuaPath();
    
    if(strcmp(name, "LUA_DIR") == 0)
        return getLuaDir();
    
    if(strcmp(name, "LUA_DATA_DIR") == 0)
        return getLuaDataDir();
    
    return NULL;
}

void *elua_malloc(size_t size)
{
    return malloc(size);
}

void elua_free(void *p)
{
    free(p);
}

extern FILE *ftrace;
static unsigned char newtrace = 1;

void log_time(FILE *fp, const char *buf){
    time_t t;
    struct tm *ts;

    if(newtrace == 0){
        newtrace = strstr(buf, "\n") != NULL ? 1 : 0;
        return;
    }

    t = time(NULL);
    ts = localtime(&t);
    fprintf(fp, "[%04d-%02d-%02d %02d:%02d:%02d]: ", 
                    ts->tm_year+1900, ts->tm_mon+1, ts->tm_mday, 
                    ts->tm_hour, ts->tm_min, ts->tm_sec);
    newtrace = strstr(buf, "\n") != NULL ? 1 : 0;
}

void elua_vfprintf(FILE *fp, const char *fmt, va_list ap){
    if(fp == stdout || fp == stderr){
        vfprintf(stdout, fmt, ap);
        log_time(ftrace, fmt);
        vfprintf(ftrace, fmt, ap);
        fflush(ftrace);
    } else {
        vfprintf(fp, fmt, ap);
    }
}

void elua_printf(const char *format, ...){
    va_list ap;

    va_start(ap, format);
    elua_vfprintf(stdout, format, ap);
    va_end(ap);
}

void elua_fprintf(FILE *fp, const char *fmt, ...){
    va_list ap;
    
    va_start(ap, fmt);
    elua_vfprintf(fp, fmt, ap);
    va_end(ap);
}

size_t elua_fwrite(const void *buf, size_t size, size_t count, FILE *fp){
    size_t written;

    if(fp == stdout || fp == stderr){
        fwrite(buf, size, count, stdout);
        log_time(ftrace, buf);
        written = fwrite(buf, size, count, ftrace);
        fflush(ftrace);
    } else {
        written = fwrite(buf, size, count, fp);
    }
    return written;
}

int elua_fputs(const char *s, FILE *fp){
    return (int)elua_fwrite(s, strlen(s), 1, fp);
}
