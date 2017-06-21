
#include <WINDOWS.H>
#include "win_msg.h"
#include "win_trace.h"

#define DAEMON_TIMER_ID         0x1234
#define DAEMON_TIME_OUT         (1000)

#define MAX_WIN_TIMERS          (20)
#define TIMER_ID_BASE           (0x2000)

typedef struct WinTimerInfoTag
{
    int         user_id;
    int         period;
    int         win_timer_id;
}WinTimerInfo;

static HANDLE hDaemonWnd;
static WinTimerInfo winTimer[MAX_WIN_TIMERS];
static short global_timer_id_unique = 0;
static HANDLE hTimerSem;

extern void SendToLuaShellMessage(const MSG *msg);

int win_start_timer(int timer_id, int milliSecond)
{
    int index;
    int winTimerId = 0;

    WaitForSingleObject(hTimerSem, INFINITE);

    for(index = 0; index < MAX_WIN_TIMERS; index++)
    {
        if(winTimer[index].user_id == timer_id)
        {
            KillTimer(hDaemonWnd, winTimer[index].win_timer_id);
            memset(&winTimer[index], 0, sizeof(winTimer[index]));
            break;
        }
    }

    for(index = 0; index < MAX_WIN_TIMERS; index++)
    {
        if(winTimer[index].win_timer_id == 0)
        {
            winTimer[index].win_timer_id = winTimerId = TIMER_ID_BASE + (++global_timer_id_unique);
            winTimer[index].user_id = timer_id;    
            break;
        }
    }

    if(index < MAX_WIN_TIMERS)    
    {
        SetTimer(hDaemonWnd, winTimerId, milliSecond, NULL);
    }
    else
    {
        winTrace("[win_start_timer]: no timer resource");
    }
    
    ReleaseSemaphore(hTimerSem, 1, NULL);

    return winTimerId;
}

int win_stop_timer(int timerId)
{
    int index;
    
    WaitForSingleObject(hTimerSem, INFINITE);

    for(index = 0; index < MAX_WIN_TIMERS; index++)
    {
        if(winTimer[index].user_id == timerId)
        {
            break;
        }
    }

    if(index < MAX_WIN_TIMERS)    
    {
        KillTimer(hDaemonWnd, winTimer[index].win_timer_id);
        memset(&winTimer[index], 0, sizeof(winTimer[index]));
    }
    else
    {
        winTrace("[win_stop_timer]: not find timer.");
    }
    
    ReleaseSemaphore(hTimerSem, 1, NULL);

    return 0;
}

BOOL win_timeout(int timerId)
{
    int index;
    MSG msg;
    int user_id;

    WaitForSingleObject(hTimerSem, INFINITE);

    for(index = 0; index < MAX_WIN_TIMERS; index++)
    {
        if(winTimer[index].win_timer_id == timerId)
        {
            user_id = winTimer[index].user_id;
            break;
        }
    }

    KillTimer(hDaemonWnd, timerId);
    memset(&winTimer[index], 0, sizeof(winTimer[index]));

    ReleaseSemaphore(hTimerSem, 1, NULL);

    msg.message = SIMU_TIMER_MSG_ID;
    msg.wParam = user_id;
    msg.lParam = 0;
    
    SendToLuaShellMessage(&msg);

    return TRUE;
}

static LONG APIENTRY daemonWndProc( HWND hWnd, UINT message, UINT wParam, LONG lParam)
{
    MSG msg;

    switch (message)
    {
    case WM_CREATE:
        //SetTimer(hWnd, DAEMON_TIMER_ID, DAEMON_TIME_OUT, NULL);

        memset(&winTimer, 0, sizeof(winTimer));

        hTimerSem = CreateSemaphore(NULL, 1, 1, NULL);
        //TRACE("[daemonWndProc]: window create 0x%x\r\n", hWnd);
        break;
        
    case WM_TIMER:
        if(wParam == DAEMON_TIMER_ID)
        {
            msg.message = DAEMON_TIMER_MSG_ID;
            msg.wParam = 0;
            msg.lParam = 0;

            SendToLuaShellMessage(&msg);
        }
        else
        {
            if(!win_timeout(wParam))
            {
                winTrace("[daemonWndProc]: timeout id 0x%x\r\n", wParam);            
            }
        }
        break;
        
    case WM_CLOSE:
        CloseHandle(hTimerSem);
        break;
        
    default:
        return (DefWindowProc(hWnd, message, wParam, lParam));    
    }
    
    return 0;
}

static BOOL createWindows(void)
{
    WNDCLASS    wndclass;              //window class
    
    wndclass.style         = CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = (WNDPROC)daemonWndProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = 0;
    
    wndclass.hIcon         = NULL;
    wndclass.hCursor       = NULL;
    wndclass.hbrBackground = NULL;
    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = "daemon_class";
    
    RegisterClass(&wndclass);        //register class
    
    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_ABOVE_NORMAL);
    //Then to create a window
    
    hDaemonWnd = CreateWindowEx(WS_EX_TOOLWINDOW,
        //do not show a icon on task bar
        "daemon_class",       //same as registered class name 
        "dameon_window",       //window name
        WS_POPUP,   //style
        CW_USEDEFAULT,//x 
        CW_USEDEFAULT,//y 
        0,          //width
        0,          //height
        NULL, 
        NULL, 
        0,
        NULL );

    return TRUE;
}

DWORD winSimuMain(LPVOID p)
{
    MSG msg;

    createWindows();

    while(GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}