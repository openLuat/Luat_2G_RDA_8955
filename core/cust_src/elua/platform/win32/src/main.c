
#undef fopen
#undef freopen

#include <stdio.h>
#include <WINDOWS.H>
#include "type.h"
#include "assert.h"
#include <FCNTL.H>
#include "event.h"

DWORD luaShellThreadId;
DWORD winSimuThreadId;
DWORD daemonThreadId;

extern DWORD winSimuMain(LPVOID p);
extern DWORD daemon_thread_entry(LPVOID p);
extern void LuaAppTask(void);

char _lua_script_section_start[LUA_SCRIPT_SIZE];

HDC hConsoleDC;
HWND hMainWnd;

#define LUA_DIR "/lua"
#define LUA_DATA_DIR "/ldata"
#define LUA_DIR_UNI     L"/lua"
#define LUA_DATA_UNI    L"/ldata"

char *getLuaPath(void)
{
    return LUA_DIR "/?.lua";
}

char *getLuaDir(void)
{
    return LUA_DIR;
}

char *getLuaDataDir(void)
{
    return LUA_DATA_DIR;
}

event_handle_t console_evt;

void proc_console_evt(const char *data, int length){
    if(strncmp(data, "close", length) == 0){
        //exit(0);
        daemon_close();
        SendMessage(hMainWnd, WM_CLOSE, 0, 0);
    }
}

void init_console_evt(void){
    console_evt = add_event("console", EVENT_CTRL_CONSOLE, proc_console_evt);
}

BOOL WINAPI ConsoleHandler(DWORD CEvent)
{
    switch(CEvent)
    {            
#if 0
    case CTRL_C_EVENT:
    MessageBox(NULL,
        "CTRL+C received!","CEvent",MB_OK);
        break;
    case CTRL_BREAK_EVENT:
    MessageBox(NULL,
        "CTRL+BREAK received!","CEvent",MB_OK);
        break;
    case CTRL_CLOSE_EVENT:
    MessageBox(NULL,
        "Program being closed!","CEvent",MB_OK);
        break;
    case CTRL_LOGOFF_EVENT:
    MessageBox(NULL,
        "User is logging off!","CEvent",MB_OK);
        break;
    case CTRL_SHUTDOWN_EVENT:
    MessageBox(NULL,
        "User is logging off!","CEvent",MB_OK);
        break;
#else
    case CTRL_CLOSE_EVENT:
        send_event(console_evt, "close", sizeof("close")-1);
        break;
#endif // 0
    }

    return TRUE;
}

static int lua_shell_entry(LPVOID p){
    Sleep(100);

    LuaAppTask();
}
FILE *ftrace = NULL;
void main(int argc, char *argv[])
{
    char *filename = "luadb.bin";
    HANDLE hLuaShellThread, hWinSimuThread, hDaemonThread;
    //FILE *fstderr = fopen("stderr.log","wb+");
    ftrace = fopen("trace.log","wb");

    freopen("CONIN$", "r+t", stdin); // 重定向 STDIN
    //freopen("CONOUT$", "w+t", stdout); // 重定向STDOUT
    //freopen("CONERR$", "w+t", ferr); // 重定向STDERR
    //freopen("CON$","w+t", fstderr);
    freopen("CONOUT$", "w+t", stdout);
    //fprintf(stderr, "test std err!\n");

#if 0
    {
        char arg[200]={0};
        int len;
        
        arg[0]='\"';
        strcpy(arg+1, argv[0]);
        len = strlen(arg);
        arg[len]='\"';
        hMainWnd = FindWindow(NULL, arg);
    }
#else
    {
        typedef HWND (WINAPI *PROCGETCONSOLEWINDOW)();
        PROCGETCONSOLEWINDOW GetConsoleWindow;
        HMODULE hKernel32 = GetModuleHandle("kernel32");
        GetConsoleWindow = (PROCGETCONSOLEWINDOW)GetProcAddress(hKernel32,"GetConsoleWindow");
        hMainWnd = GetConsoleWindow();
    }
#endif

#if 0
    {
        HMENU hMenu;
        hMenu = GetSystemMenu(hMainWnd,FALSE);
        EnableMenuItem(hMenu, SC_CLOSE, MF_GRAYED|MF_BYCOMMAND);
    }
#endif

    hConsoleDC = GetDC(hMainWnd);

    init_console_evt();

    SetConsoleCtrlHandler(ConsoleHandler, TRUE);

    //system("dir");    
    system("rd /s /q elua\\lua");
    system("rd /s /q elua\\ldata");
    system("mkdir elua\\lua");
    system("mkdir elua\\ldata");
    
//     if(argc >= 2){
//         filename = argv[1];
//     } else
    {
        FILE *fset = fopen("set.ini","rb");
        char buf[1024];
        char *p;

        if(fset){
            while(fgets(buf, sizeof(buf), fset)){
                if(strncmp(buf,"luadb=",6) != 0) continue;

                filename = &buf[6];
                if(p = strstr(filename, "\n")){
                    *p = '\0';
                }
                break;
            }
        }
    }
#if 1
    {
        FILE *luaf = fopen(filename, "rb");

        if(luaf)
        {
            int len;

            fseek(luaf, 0, SEEK_END);
            len = ftell(luaf);
            fseek(luaf, 0, SEEK_SET);
            
            ASSERT(len < LUA_SCRIPT_SIZE);

            fread(_lua_script_section_start, len, 1, luaf);

            fclose(luaf);
        }
        else
        {
            printf("file %s not exist!", filename);
            system("pause");
            SendMessage(hMainWnd, WM_CLOSE, 0, 0);
        }
    }
#endif

    platform_uart_init();

    // 创建后台管理线程
    hDaemonThread = CreateThread(NULL , 
                                10*1024, 
                                (LPTHREAD_START_ROUTINE)daemon_thread_entry,
                                0,
                                0,
                                &daemonThreadId);

    // 创建模拟任务线程
    hWinSimuThread = CreateThread(NULL , 
                                10*1024, 
                                (LPTHREAD_START_ROUTINE)winSimuMain,
                                0,
                                0,
                                &winSimuThreadId);
    
    // lua脚本执行线程
    hLuaShellThread = CreateThread(NULL,
                                16*1024, 
                                (LPTHREAD_START_ROUTINE)lua_shell_entry,
                                0,
                                0,
                                &luaShellThreadId);

    WaitForSingleObject(hLuaShellThread, INFINITE);
    
    ReleaseDC(hMainWnd, hConsoleDC);

    system("pause");
    
    send_event(console_evt, "close", sizeof("close")-1);

    fclose(ftrace);

    //ASSERT(0);
}
