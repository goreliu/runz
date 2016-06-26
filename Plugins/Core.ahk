; RunZ:Core
; 核心功能

Core:
    @("Help", "帮助信息")
    @("KeyHelp", "置顶的按键帮助信息")
    @("AhkRun", "使用 Ahk 的 Run() 运行 `; command")
    @("CmdRun", "使用 cmd 运行 : command")
    @("CmdRunOnly", "只使用 cmd 运行")
    @("WinRRun", "使用 win + r 运行")
    @("RunAndDisplay", "使用 cmd 运行，并显示结果")
    @("ReindexFiles", "重新索引待搜索文件")
    @("EditConfig", "编辑配置文件")
    @("RunClipboard", "使用 ahk 的 Run 运行剪切板内容")
    @("CleanupRank", "清理命令权重中的无效命令")
    @("ShowArg", "显示参数：ShowArg arg1 arg2 ...")
    @("AhkTest", "运行参数或者剪切板中的 AHK 代码")
    @("InstallPlugin", "安装插件")
    @("RemovePlugin", "卸载插件")
    @("ListPlugin", "列出插件")
    @("CleanupPlugin", "清理插件")
    @("CountNumber", "计算数量 wc")
    @("Open", "打开")
return

CmdRun:
    RunWithCmd(Arg)
return

CmdRunOnly:
    RunWithCmd(Arg, true)
return

AhkRun:
    if (!g_Conf.Config.DebugMode)
    {
        try
        {
            Run, %Arg%
        }
        catch e
        {
            MsgBox, 运行命令 %Arg% 失败`n设置配置文件中 DebugMode 为 1 可查看错误详情
        }
    }
    else
    {
        Run, %Arg%
    }
return

ShowArg:
    args := StrSplit(Arg, " ")
    result := "共有 " . args.Length() . " 个参数。`n`n"

    for index, argument in args
    {
        result .= "第 " . index . " 个参数：" . argument . "`n"
    }

    DisplayResult(result)
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

AhkTest:
    text := Arg == "" ? clipboard : Arg
    FileDelete, %A_Temp%\RunZ.AhkTest.ahk
    FileAppend, %text%, %A_Temp%\RunZ.AhkTest.ahk
    Run, %A_Temp%\RunZ.AhkTest.ahk
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

Open:
    Run, % StrSplit(FullPipeArg, "`r")[1]
return
