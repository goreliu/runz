; RunZ:Core
; 核心功能

Core:
    @("Help", "帮助信息")
    @("KeyHelp", "置顶的按键帮助信息")
    @("AhkRun", "使用 Ahk 的 Run() 运行 `; command", true)
    @("CmdRun", "使用 cmd 运行 : command", true)
    @("CmdRunOnly", "只使用 cmd 运行")
    @("WinRRun", "使用 win + r 运行", true)
    @("RunAndDisplay", "使用 cmd 运行，并显示结果", true)
    @("ReindexFiles", "重新索引待搜索文件")
    @("Clip", "显示剪切板内容")
    @("EditConfig", "编辑配置文件")
    @("ClearClipboardFormat", "清除剪切板中文字的格式")
    @("RunClipboard", "使用 ahk 的 Run 运行剪切板内容")
    @("EmptyRecycle", "清空回收站")
    @("Logoff", "注销 登出")
    @("RestartMachine", "重启")
    @("ShutdownMachine", "关机")
    @("SuspendMachine", "挂起 睡眠 待机")
    @("HibernateMachine", "休眠")
    @("TurnMonitorOff", "关闭显示器")
    @("CleanupRank", "清理命令权重中的无效命令")
    @("ListProcess", "列出进程 ps")
    @("DiskSpace", "查看磁盘空间 df")
    @("ArgTest", "参数测试：ArgTest arg1,arg2,...")
    @("AhkTest", "运行参数或者剪切板中的 AHK 代码")
    @("IncreaseVolume", "提高音量")
    @("DecreaseVolume", "降低音量")
    @("SystemState", "系统状态 top")
    @("KillProcess", "杀死进程")
    @("SendToClip", "发送到剪切板")
    @("ListWindow", "窗口列表")
    @("ActivateWindow", "激活窗口")
    @("InstallPlugin", "安装插件")
    @("RemovePlugin", "卸载插件")
    @("ListPlugin", "列出插件")
    @("CleanupPlugin", "清理插件")
    @("CountNumber", "计算数量 wc")
    @("ListRunningService", "列出运行的服务")
    @("ListAllService", "列出运行的服务")
    @("ShowService", "显示服务详情")
    @("ShowProcess", "显示进程详情")
return

CmdRun:
    RunWithCmd(Arg)
return

CmdRunOnly:
    RunWithCmd(Arg, true)
return

AhkRun:
    Run, %Arg%
return

Clip:
    GoSub, ActivateRunZ
    DisplayResult("剪切板内容长度 " . StrLen(clipboard) . " ：`n`n" . clipboard)
return

ArgTest:
    args := StrSplit(Arg, ",")
    result := "共有 " . args.Length() . " 个参数。`n`n"

    for index, argument in args
    {
        result .= "第 " . index . " 个参数：" . argument . "`n"
    }

    DisplayResult(result)
return

ClearClipboardFormat:
    clipboard := clipboard
return

RunClipboard:
    Run, %clipboard%
return

RunAndDisplay:
    DisplayResult(RunAndGetOutput(Arg))
return

WinRRun:
    Send, #r
    Sleep, 100
    Send, %Arg%
    Send, {enter}
return

Logoff:
    MsgBox, 4, , 将要注销，是否执行？
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
    SendMessage, 0x112, 0xF170, 2,, Program Manager
    ; 0x112 is WM_SYSCOMMAND, 0xF170 is SC_MONITORPOWER.
    ; 对上面命令的注释: 使用 -1 代替 2 来打开显示器.
    ; 使用 1 代替 2 来激活显示器的节能模式.
return

EmptyRecycle:
    MsgBox, 4, , 将要清空回收站，是否执行？
    IfMsgBox Yes
    {
        FileRecycleEmpty,
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
        DrivespaceFree, free, %drive%
        SetFormat, float, 5.2
        percent := 100 * (cap - free) / cap
        SetFormat, float, 6.2
        cap /= 1024.0
        free /= 1024.0
        result = %result%* | %drive% | 总共: %cap% G  可用: %free% G | 已使用：%percent%`%  卷标: %label%`n
    }

    DisplayResult(AlignText(result))
return

AhkTest:
    text := Arg == "" ? clipboard : Arg
    FileDelete, %A_Temp%\RunZ.AhkTest.ahk
    FileAppend, %text%, %A_Temp%\RunZ.AhkTest.ahk
    Run, %A_Temp%\RunZ.AhkTest.ahk
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

InstallPlugin:
    pluginPath := Arg

    if (InStr(pluginPath, "http") == 1)
    {
        DisplayResult("下载中，请稍后...")
        UrlDownloadToFile, %pluginPath%, %A_Temp%\RunZ.Plugin.txt
        pluginPath := A_Temp "\RunZ.Plugin.txt"
    }

    if (FileExist(pluginPath))
    {
        FileReadLine, firstLine, %pluginPath%, 1
        if (!InStr(firstLine, "; RunZ:"))
        {
            DisplayResult(pluginPath " 并不是有效的 RunZ 插件")
            return
        }

        pluginName := StrSplit(firstLine, "; RunZ:")[2]
        if (FileExist(A_ScriptDir "\Plugins\" pluginName ".ahk"))
        {
            DisplayResult("该插件已存在")
            return
        }

        FileMove, %pluginPath%, %A_ScriptDir%\Plugins\%pluginName%.ahk
		FileAppend, #include *i `%A_ScriptDir`%\Plugins\%pluginName%.ahk`n
			, %A_ScriptDir%\Core\Plugins.ahk

		DisplayResult(pluginName " 插件安装成功，RunZ 将重启并启用该插件")
        Sleep, 1000
        GoSub, RestartRunZ
    }
    else
    {
        DisplayResult(pluginPath " 文件不存在")
    }
return

RemovePlugin:
    pluginName := Arg
    if (!FileExist(A_ScriptDir "\Plugins\" pluginName ".ahk"))
    {
        DisplayResult("未安装该插件")
        return
    }

    FileRead, currentPlugins, %A_ScriptDir%\Core\Plugins.ahk
    StringReplace, currentPlugins, currentPlugins
        , #include *i `%A_ScriptDir`%\Plugins\%pluginName%.ahk`r`n
    FileDelete, %A_ScriptDir%\Core\Plugins.ahk
    FileAppend, %currentPlugins%, %A_ScriptDir%\Core\Plugins.ahk
    FileDelete, %A_ScriptDir%\Plugins\%pluginName%.ahk

    DisplayResult(pluginName " 插件删除成功，RunZ 将重启以生效")
    Sleep, 1000
    GoSub, RestartRunZ
return

ListPlugin:
    result := ""
    Loop, Files, %A_ScriptDir%\Plugins\*.ahk
    {
        pluginName := StrReplace(A_LoopFileName, ".ahk")
        FileReadLine, secondLine, %A_LoopFileLongPath%, 2
        if (g_Conf.GetValue("Plugins", pluginName) == 0)
        {
            result .= "* | 插件 | " pluginName " | 已禁用  描述：" SubStr(secondLine, 3) "`n"
        }
        else
        {
            result .= "* | 插件 | " pluginName " | 已启用  描述：" SubStr(secondLine, 3) "`n"
        }
    }

    DisplayResult(AlignText(result))
    TurnOnResultFilter()
    SetCommandFilter("RemovePlugin")
return

CleanupPlugin:
    result := ""
    FileRead, currentPlugins, %A_ScriptDir%\Core\Plugins.ahk
    Loop, Parse, currentPlugins, `n, `r
    {
        SplitPath, A_LoopField , , , , pluginName,
        if (g_Conf.GetValue("Plugins", pluginName) == 0)
        {
            result .= pluginName " 插件已被清理，下次运行 RunZ 将不再引入`n"
            StringReplace, currentPlugins, currentPlugins
                , #include *i `%A_ScriptDir`%\Plugins\%pluginName%.ahk`r`n
        }
    }

    if (result != "")
    {
        DisplayResult(result)
        FileDelete, %A_ScriptDir%\Core\Plugins.ahk
        FileAppend, %currentPlugins%, %A_ScriptDir%\Core\Plugins.ahk
    }
    else
    {
        DisplayResult("无可清理插件")
    }
return

CountNumber:
    result := "* | 数量 | " StrSplit(Arg, " ").Length() " | 以空格为分隔符`n"
    if (SubStr(FullPipeArg, 0, -1) = "`n")
    {
        result .= "* | 数量 | " StrSplit(FullPipeArg, "`n").Length()  - 1 " | 以换行为分隔符`n"
    }
    else
    {
        result .= "* | 数量 | " StrSplit(FullPipeArg, "`n").Length() " | 以换行为分隔符`n"
    }

    DisplayResult(AlignText(result))
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
