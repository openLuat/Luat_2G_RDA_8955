#include "cos.h"

//#include "assert.h"

extern void dll_test2(void);

const char g_dllstr[] = { "Hello world!" };

char *g_inputstr;

void DllTest(void)
{
    char *pStr = g_dllstr;
    dll_test2();
    //assert(0);
}

void DllTest2(char *pStr)
{
    g_inputstr = pStr;
}