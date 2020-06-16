; RunZ:System
; 操作系统相关功能

System:
    @("Clip", "显示剪切板内容")
    @("ClearClipboardFormat", "清除剪切板中文字的格式")
    @("EmptyRecycle", "清空回收站")
    @("Logoff", "注销 登出")
    @("RestartMachine", "重启")
    @("ShutdownMachine", "关机")
    @("SuspendMachine", "挂起 睡眠 待机")
    @("HibernateMachine", "休眠")
    @("TurnMonitorOff", "关闭显示器")
    @("ListProcess", "列出进程 ps")
    @("DiskSpace", "查看磁盘空间 df")
    @("IncreaseVolume", "提高音量")
    @("DecreaseVolume", "降低音量")
    @("SystemState", "系统状态 top")
    @("KillProcess", "杀死进程")
    @("SendToClip", "发送到剪切板")
    @("ListWindow", "窗口列表")
    @("ActivateWindow", "激活窗口")
    @("ListRunningService", "列出运行的服务")
    @("ListAllService", "列出所有的服务")
    @("ShowService", "显示服务详情")
    @("ShowProcess", "显示进程详情")
return

Clip:
    GoSub, ActivateRunZ
    DisplayResult("剪切板内容长度 " . StrLen(clipboard) . " ：`n`n" . clipboard)
return

ClearClipboardFormat:
    clipboard := clipboard
return

Logoff:
    MsgBox, 4, , 将要注销，是否执行？
    IfMsgBox Yes
    {
        Shutdown, 0
    }
return

ShutdownMachine:
    MsgBox, 4, , 将要关机，是否执行？
    IfMsgBox Yes
    {
        Shutdown, 1
    }
return

RestartMachine:
    MsgBox, 4, , 将要重启机器，是否执行？
    IfMsgBox Yes
    {
        Shutdown, 2
    }
return

HibernateMachine:
    MsgBox, 4, , 将要休眠，是否执行？
    IfMsgBox Yes
    {
        ; 参数 #1: 使用 1 代替 0 来进行休眠而不是挂起。
        ; 参数 #2: 使用 1 代替 0 来立即挂起而不询问每个应用程序以获得许可。
        ; 参数 #3: 使用 1 而不是 0 来禁止所有的唤醒事件。
        DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
    }
return

SuspendMachine:
    MsgBox, 4, , 将要待机，是否执行？
    IfMsgBox Yes
    {
        DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
    }
return

TurnMonitorOff:
    ; 关闭显示器:
    Sleep, 200
    SendMessage, 0x112, 0xF170, 2, , Program Manager
    ; 0x112 is WM_SYSCOMMAND, 0xF170 is SC_MONITORPOWER.
    ; 对上面命令的注释: 使用 -1 代替 2 来打开显示器.
    ; 使用 1 代替 2 来激活显示器的节能模式.
return

EmptyRecycle:
    Items := ComObjCreate("Shell.Application").Namespace(10).Items()
    Text := "回收站中共有 " . Items.Count() . " 项 （取消可以管理回收站文件）：`n`n"

    Lines := 0
    For F in Items {
        if (Lines >= 30) {
            Text .= "……`n"
            break
        }

        Lines += 1

        Text .= F.Name . " （" . (F.IsFolder == 0 ? F.Size . " 字节）" : "目录）") . "`n"
    }

    if (Lines == 0) {
        MsgBox, , , 回收站是空的，将自动关闭, 0.5
        return
    }

    MsgBox, 3, , % Text . "`n将要清空回收站，是否执行？"

    IfMsgBox Yes
    {
        FileRecycleEmpty
        return
    }

    IfMsgBox Cancel
    {
        Run, explorer.exe ::{645ff040-5081-101b-9f08-00aa002f954e}
    }
return

ListProcess:
    result := ""

    for process in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Process")
    {
        result .= "* | 进程 | " process.Name " | " process.CommandLine "`n"
    }
    Sort, result

    SetCommandFilter("KillProcess|ShowProcess|CountNumber")
    DisplayResult(FilterResult(AlignText(result), Arg))
    TurnOnResultFilter()
return

DiskSpace:
    result := ""

    DriveGet, list, list
    Loop, Parse, list
    {
        drive := A_LoopField ":"
        DriveGet, label, label, %drive%
        DriveGet, cap, capacity, %drive%
        DriveSpaceFree, free, %drive%
        used := cap - free
        ;SetFormat, float, 5.2
        ;percent := 100 * (cap - free) / cap
        SetFormat, float, 7.2
        cap /= 1024.0
        free /= 1024.0
        used /= 1024.0
        result = %result%* | %drive% | 总共: %cap% G  可用: %free% G | 已用：%used%  卷标: %label%`n
    }

    DisplayResult(AlignText(result))
return

IncreaseVolume:
    SoundSet, +5
return

DecreaseVolume:
    SoundSet, -5
return

SystemState:
    if (!SetExecInterval(1))
    {
        return
    }

    GMSEx := GlobalMemoryStatusEx()
    result := "* | 状态 | 运行时间 | " Round(A_TickCount / 1000 / 3600, 3) " 小时`n"
    result .= "* | 状态 | CPU 占用 | " CPULoad() "% `n"
    result .= "* | 状态 | 内存占用 | " Round(100 * (GMSEx[2] - GMSEx[3]) / GMSEx[2], 2) "% `n"
    result .= "* | 状态 | 进程总数 | " GetProcessCount() "`n"
    result .= "* | 状态 | 内存总量 | " Round(GMSEx[2] / 1024**2, 2) "MB `n"
    result .= "* | 状态 | 可用内存 | " Round(GMSEx[3] / 1024**2, 2) "MB `n"
    DisplayResult(AlignText(result))
return

KillProcess:
    args := StrSplit(Arg, " ")
    for index, argument in args
    {
        Process, Close, %argument%
    }

    DisplayResult("已尝试杀死 " Arg " 进程")
return

SendToClip:
    clipboard := Arg
    GoSub, Clip
return

ListWindow:
    result := ""

    WinGet, id, list, , , Program Manager
    Loop, %id%
    {
        thisId := id%A_Index%
        WinGetTitle, title, ahk_id %thisId%
        WinGet, name, ProcessName, ahk_id %thisId%
        if (title == "")
        {
            continue
        }
        result .= "* | 窗口 | " name " | " title "`n"
    }

    SetCommandFilter("ActivateWindow|KillProcess")
    DisplayResult(AlignText(result))
    TurnOnResultFilter()
return

ActivateWindow:
    DisplayResult()
    ClearInput()

    if (FullPipeArg != "")
    {
        Loop, Parse, FullPipeArg, `n, `r
        {
            if (A_LoopField == "")
            {
                return
            }
            splitedLine := StrSplit(A_LoopField, " | ")
            WinActivate, % Trim(splitedLine[4])
        }
    }
    else
    {
        for index, argument in StrSplit(Arg, " ")
        {
            WinActivate, ahk_exe %argument%
        }
    }
return

ListAllService:
    result :=
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service")
    {
        result .= "* | 服务 | " service.Name " | " service.DisplayName "`n"
    }
    Sort, result

    SetCommandFilter("CountNumber|ShowService")
    DisplayResult(FilterResult(AlignText(result), Arg))
    TurnOnResultFilter()
return

ListRunningService:
    result :=
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service")
    {
        if (service.Started != 0)
        {
            result .= "* | 服务 | " service.Name " | " service.DisplayName "`n"
        }
    }
    Sort, result

    SetCommandFilter("CountNumber|ShowService")
    DisplayResult(FilterResult(AlignText(result), Arg))
    TurnOnResultFilter()
return

ShowService:
    result :=
    ; 暂时只支持一个，选得多了查起来太慢
    for service in ComObjGet("winmgmts:")
        .ExecQuery("select * from Win32_Service where Name = '" StrSplit(Arg, " ")[1] "'")
    {
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa394418%28v=vs.85%29.aspx
        result .= "* | 服务 | 名称 | " service.Name "`n"
        result .= "* | 服务 | 描述 | " service.Description "`n"
        result .= "* | 服务 | 是否在运行 | " service.Started "`n"
        result .= "* | 服务 | 路径 | " service.PathName "`n"
        result .= "* | 服务 | 进程 ID | " service.ProcessId "`n"
        result .= "* | 服务 | 类型 | " service.ServiceType "`n"
        break
    }

    DisplayResult(AlignText(result))
return

ShowProcess:
    result :=
    ; 暂时只支持一个，选得多了查起来太慢
    for process in ComObjGet("winmgmts:")
        .ExecQuery("select * from Win32_Process where Name = '" StrSplit(Arg, " ")[1] "'")
    {
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa394372%28v=vs.85%29.aspx
        result .= "* | 服务 | 名称 | " process.Name "`n"
        result .= "* | 服务 | 描述 | " process.Description "`n"
        result .= "* | 服务 | 命令行 | " process.CommandLine "`n"
        result .= "* | 服务 | 启动时间 | " process.CreationDate "`n"
        result .= "* | 服务 | ID | " process.ProcessId "`n"
        break
    }

    DisplayResult(AlignText(result))
return
