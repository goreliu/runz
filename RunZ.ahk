#NoEnv
#SingleInstance, Force
#NoTrayIcon
#MaxHotkeysPerInterval 200

FileEncoding, utf-8
SendMode Input
SetWorkingDir %A_ScriptDir%

; 自动生成的待搜索文件列表
global g_SearchFileList := A_ScriptDir . "\Conf\SearchFileList.txt"
; 用户配置的待搜索文件列表
global g_UserFileList := A_ScriptDir . "\Conf\UserFileList.txt"
; 配置文件
global g_ConfFile := A_ScriptDir . "\Conf\RunZ.ini"
; 自动写入的配置文件
global g_AutoConfFile := A_ScriptDir . "\Conf\RunZ.auto.ini"

if !FileExist(g_ConfFile)
{
    FileCopy, %g_ConfFile%.help.txt, %g_ConfFile%
}

if (FileExist(g_AutoConfFile ".EasyIni.bak"))
{
    MsgBox, % "发现上次写入配置的备份文件：`n"
        . g_AutoConfFile . ".EasyIni.bak"
        . "`n确定则将其恢复，否则请手动检查文件内容再继续"
    FileMove, % g_AutoConfFile ".EasyIni.bak", % g_AutoConfFile
}
else if (!FileExist(g_AutoConfFile))
{
    FileAppend, % "; 此文件由 RunZ 自动写入，如需手动修改请先关闭 RunZ ！`n`n"
        . "[Auto]`n[Rank]`n[History]" , % g_AutoConfFile
}

global g_Conf := class_EasyIni(g_ConfFile)
global g_AutoConf := class_EasyIni(g_AutoConfFile)

if (g_Conf.Gui.Skin != "")
{
    global g_SkinConf := class_EasyIni(A_ScriptDir "\Conf\Skins\" g_Conf.Gui.Skin ".ini").Gui
}
else
{
    global g_SkinConf := g_Conf.Gui
}

; 当前输入命令的参数，数组，为了方便没有添加 g_ 前缀
global Arg
; 用来调用管道的完整参数（所有列），供有必要的插件使用
global FullPipeArg
; 不能是 RunZ.ahk 的子串，否则按键绑定会有问题
global g_WindowName := "RunZ    "
; 所有命令
global g_Commands
; 当搜索无结果时使用的命令
global g_FallbackCommands
; 编辑框当前内容
global g_CurrentInput
; 当前匹配到的第一条命令
global g_CurrentCommand
; 当前匹配到的所有命令
global g_CurrentCommandList
; 是否启用 TCMatch
global g_EnableTCMatch = TCMatchOn(g_Conf.Config.TCMatchPath)
; 列表第一列的首字母或数字
global g_FirstChar := Asc(g_SkinConf.FirstChar)
; 在列表中显示的行数
global g_DisplayRows := g_SkinConf.DisplayRows
; 命令使用了显示框
global g_UseDisplay
; 历史命令
global g_HistoryCommands
; 运行命令时临时设置，避免因为自身退出无法运行需要提权的软件
global g_DisableAutoExit
; 当前的命令在搜索结果的行数
global g_CurrentLine
; 使用备用的命令
global g_UseFallbackCommands
; 对命令结果进行实时搜索
global g_UseResultFilter
; 当参数改变后实时重新执行命令
global g_UseRealtimeExec
; 排除的命令
global g_ExcludedCommands
; 间隔运行命令的间隔时间
global g_ExecInterval
; 上次间隔运行的功能标签
global g_LastExecLabel
; 用来调用管道的参数（结果第三列）
global g_PipeArg
; 用来补全命令用的
global g_CommandFilter
; 插件列表
global g_Plugins := Object()

global g_InputArea := "Edit1"
global g_DisplayArea := "Edit3"
global g_CommandArea := "Edit4"

FileRead, currentPlugins, %A_ScriptDir%\Core\Plugins.ahk
needRestart := false

Loop, Files, %A_ScriptDir%\Plugins\*.ahk
{
    FileReadLine, firstLine, %A_LoopFileLongPath%, 1
    pluginName := StrSplit(firstLine, ":")[2]
    if (!(g_Conf.GetValue("Plugins", pluginName) == 0))
    {
        if (RegExMatch(currentPlugins, "m)" pluginName ".ahk$"))
        {
            g_Plugins.Push(pluginName)
        }
        else
        {
            FileAppend, #include *i `%A_ScriptDir`%\Plugins\%pluginName%.ahk`n
                , %A_ScriptDir%\Core\Plugins.ahk
            needRestart := true
        }
    }
}

if (needRestart)
{
    Reload
}

if (g_SkinConf.ShowTrayIcon)
{
    Menu, Tray, Icon
    Menu, Tray, NoStandard
    if (g_Conf.Config.RunInBackground)
    {
        Menu, Tray, Add, 显示 &S, ActivateRunZ
        Menu, Tray, Default, 显示 &S
        Menu, Tray, Click, 1
    }
    Menu, Tray, Add, 配置 &C, EditConfig
    Menu, Tray, Add, 帮助 &H, KeyHelp
    Menu, Tray, Add,
    Menu, Tray, Add, 重启 &R, RestartRunZ
    Menu, Tray, Add, 退出 &X, ExitRunZ
}

Menu, Tray, Icon, %A_ScriptDir%\RunZ.ico

if (FileExist(g_SearchFileList))
{
    LoadFiles()
}
else
{
    GoSub, ReindexFiles
}

Gui, Color, % g_SkinConf.BackgroundColor, % g_SkinConf.EditColor

if (FileExist(A_ScriptDir "\Conf\Skins\" g_SkinConf.BackgroundPicture))
{
    Gui, Add, Picture, x0 y0, % A_ScriptDir "\Conf\Skins\" g_SkinConf.BackgroundPicture
}

border := 10
if (g_SkinConf.BorderSize >= 0)
{
    border := g_SkinConf.BorderSize
}
windowHeight := border * 3 + g_SkinConf.EditHeight + g_SkinConf.DisplayAreaHeight

Gui, Font, % "C" g_SkinConf.FontColor " S" g_SkinConf.FontSize, % g_SkinConf.FontName
Gui, Add, Edit, % "x" border " y" border " gProcessInputCommand -WantReturn"
        . " w" g_SkinConf.WidgetWidth " h" g_SkinConf.EditHeight,
Gui, Add, Edit, y+0 w0 h0 ReadOnly -WantReturn
Gui, Add, Button, y+0 w0 h0 Default gRunCurrentCommand
Gui, Add, Edit, % "y+" border " -VScroll ReadOnly -WantReturn"
        . " w" g_SkinConf.WidgetWidth " h" g_SkinConf.DisplayAreaHeight
        , % AlignText(SearchCommand("", true))

if (g_SkinConf.ShowCurrentCommand)
{
    Gui, Add, Edit, % "y+" border " ReadOnly"
        . " w" g_SkinConf.WidgetWidth " h" g_SkinConf.EditHeight,
    windowHeight += border + g_SkinConf.EditHeight
}

if (g_SkinConf.ShowInputBoxOnlyIfEmpty)
{
    windowHeight := border * 2 + g_SkinConf.EditHeight
    SysGet, screenHeight, 79
    windowY := "y" (screenHeight - border * 2 - g_SkinConf.EditHeight - g_SkinConf.DisplayAreaHeight) / 2
}

if (g_SkinConf.HideTitle)
{
    Gui -Caption
}

cmdlineArg = %1%
if (cmdlineArg == "--hide")
{
    hideWindow := " Hide"
}

Gui, Show, % windowY " w" border * 2 + g_SkinConf.WidgetWidth
    . " h" windowHeight hideWindow, % g_WindowName

if (g_SkinConf.RoundCorner > 0)
{
    WinSet, Region, % "0-0 w" border * 2 + g_SkinConf.WidgetWidth " h" windowHeight
        . " r" g_SkinConf.RoundCorner "-" g_SkinConf.RoundCorner, % g_WindowName
}

if (g_Conf.Config.SwitchToEngIME)
{
    SwitchToEngIME()
}

if (g_Conf.Config.WindowAlwaysOnTop)
{
    WinSet, AlwaysOnTop, On, A
}

if (g_Conf.Config.ExitIfInactivate)
{
    OnMessage(0x06, "WM_ACTIVATE")
}

OnMessage(0x0200, "WM_MOUSEMOVE")

Hotkey, IfWinActive, % g_WindowName

Hotkey, Esc, EscFunction
Hotkey, !F4, ExitRunZ

Hotkey, Tab, TabFunction
Hotkey, F1, Help
Hotkey, +F1, KeyHelp
Hotkey, F2, EditConfig
Hotkey, F3, EditAutoConfig
Hotkey, ^q, RestartRunZ
Hotkey, ^l, ClearInput
Hotkey, ^d, OpenCurrentFileDir
Hotkey, ^x, DeleteCurrentFile
Hotkey, ^s, ShowCurrentFile
Hotkey, ^r, ReindexFiles
Hotkey, ^h, DisplayHistoryCommands
Hotkey, ^n, IncreaseRank
Hotkey, ^=, IncreaseRank
Hotkey, ^p, DecreaseRank
Hotkey, ^-, DecreaseRank
Hotkey, ^f, NextPage
Hotkey, ^b, PrevPage
Hotkey, ^i, HomeKey
Hotkey, ^o, EndKey
Hotkey, ^j, NextCommand
Hotkey, ^k, PrevCommand
Hotkey, Down, NextCommand
Hotkey, Up, PrevCommand
Hotkey, ~LButton, ClickFunction
Hotkey, RButton, OpenContextMenu
Hotkey, AppsKey, OpenContextMenu
Hotkey, ^Enter, SaveResultAsArg

; 剩余按键 Ctrl + e g m t w

Loop, % g_DisplayRows
{
    key := Chr(g_FirstChar + A_Index - 1)
    ; lalt +
    Hotkey, !%key%, RunSelectedCommand
    ; tab +
    Hotkey, ~%key%, RunSelectedCommand
    ; shift +
    Hotkey, ~+%key%, GotoCommand
}

for key, label in g_Conf.Hotkey
{
    if (label != "Default")
    {
        Hotkey, %key%, %label%
    }
    else
    {
        Hotkey, %key%, Off
    }
}

Hotkey, IfWinActive

for key, label in g_Conf.GlobalHotkey
{
    if (label != "Default")
    {
        Hotkey, %key%, %label%
    }
    else
    {
        Hotkey, %key%, Off
    }
}

if (g_Conf.Config.SaveInputText && g_AutoConf.Auto.InputText != "")
{
    Send, % g_AutoConf.Auto.InputText
}

if (g_Conf.Config.SaveHistory)
{
    g_HistoryCommands := Object()
    LoadHistoryCommands()
}

UpdateSendTo(g_Conf.Config.CreateSendToLnk, false)
UpdateStartupLnk(g_Conf.Config.CreateStartupLnk, false)

SetTimer, WatchUserFileList, 3000
return

Default:
return

RestartRunZ:
    SaveAutoConf()
    Reload
return

Test:
    MsgBox, 测试
return

HomeKey:
    Send, {home}
return

EndKey:
    Send, {End}
return

NextPage:
    if (!g_UseDisplay)
    {
        return
    }

    ControlFocus, %g_DisplayArea%
    Send, {pgdn}
    ControlFocus, %g_InputArea%
return

PrevPage:
    if (!g_UseDisplay)
    {
        return
    }

    ControlFocus, %g_DisplayArea%
    Send, {pgup}
    ControlFocus, %g_InputArea%
return

ActivateRunZ:
    Gui, Show, , % g_WindowName

    if (g_Conf.Config.SwitchToEngIME)
    {
        SwitchToEngIME()
    }

    Loop, 5
    {
        Sleep, 50

        if (WinActive(g_WindowName))
        {
            ControlFocus, %g_InputArea%
            Send, ^a
            break
        }

        Gui, Show, , % g_WindowName
    }
return

ToggleWindow:
    if (WinActive(g_WindowName))
    {
        if (!g_Conf.Config.KeepInputText)
        {
            ControlSetText, %g_InputArea%, , %g_WindowName%
        }

        Gui, Hide
    }
    else
    {
        GoSub, ActivateRunZ
    }
return

getMouseCurrentLine()
{
    MouseGetPos, , mouseY, , classnn,
    if (classnn != g_DisplayArea)
    {
        return -1
    }

    ControlGetPos, , y, , h, %g_DisplayArea%
    lineHeight := h / g_DisplayRows
    index := Ceil((mouseY - y) / lineHeight)
    return index
}

ClickFunction:
    if (g_UseDisplay)
    {
        return
    }

    index := getMouseCurrentLine()
    if (index < 0)
    {
        return
    }

    if (g_CurrentCommandList[index] != "")
    {
        ChangeCommand(index - 1, true)
    }

    ControlFocus, %g_InputArea%
    Send, {end}

    if (g_Conf.Config.ClickToRun)
    {
        RunCommand(g_CurrentCommand)
    }
return

OpenContextMenu:
    if (!g_UseDisplay)
    {
        currentCommandText := ""
        if (!g_CurrentLine > 0)
        {
            currentCommandText .= Chr(g_FirstChar)
        }
        else
        {
            currentCommandText .= Chr(g_FirstChar + g_CurrentLine - 1)
        }
        Menu, ContextMenu, Add, %currentCommandText%>  运行 &Z, RunCurrentCommand
        Menu, ContextMenu, Add
    }

    Menu, ContextMenu, Add, 编辑配置 &E, EditConfig
    Menu, ContextMenu, Add, 重建索引 &S, ReindexFiles
    Menu, ContextMenu, Add, 显示历史 &H, DisplayHistoryCommands
    Menu, ContextMenu, Add, 更新路径 &C, ChangePath
    Menu, ContextMenu, Add
    Menu, ContextMenu, Add, 显示帮助 &A, Help
    Menu, ContextMenu, Add, 重新启动 &R, RestartRunZ
    Menu, ContextMenu, Add, 退出程序 &X, ExitRunZ
    Menu, ContextMenu, Show
    Menu, ContextMenu, DeleteAll
return

TabFunction:
    ControlGetFocus, ctrl,
    if (ctrl == g_InputArea)
    {
        ; 定位到一个隐藏编辑框
        ControlFocus, Edit2
    }
    else
    {
        ControlFocus, %g_InputArea%
    }
return

EscFunction:
    ToolTip
    if (g_Conf.Config.ClearInputWithEsc && g_CurrentInput != "")
    {
        GoSub, ClearInput
    }
    else
    {
        if (!g_Conf.Config.KeepInputText)
        {
            ControlSetText, %g_InputArea%, , %g_WindowName%
        }
        GoSub, HideOrExit
    }
return

HideOrExit:
    ; 如果是后台运行模式，只关闭窗口，不退出程序
    if (g_Conf.Config.RunInBackground)
    {
        Gui, Hide
    }
    else
    {
        GoSub, ExitRunZ
    }
return

NextCommand:
    if (g_UseDisplay)
    {
        ControlFocus, %g_DisplayArea%
        Send {down}
        return
    }
    ChangeCommand(1)
return

PrevCommand:
    if (g_UseDisplay)
    {
        ControlFocus, %g_DisplayArea%
        Send {up}
        return
    }
    ChangeCommand(-1)
return

GotoCommand:
    ControlGetFocus, ctrl,
    if (ctrl == g_InputArea)
    {
        return
    }

    index := Asc(SubStr(A_ThisHotkey, 0, 1)) - g_FirstChar + 1

    if (g_CurrentCommandList[index] != "")
    {
        ChangeCommand(index - 1, true)
    }
return

ChangeCommand(step, resetCurrentLine = false)
{
    ControlGetText, g_CurrentInput, %g_InputArea%

    if (resetCurrentLine
        || (SubStr(g_CurrentInput, 1, 1) != "@" && SubStr(g_CurrentInput, 1, 2) != "|@"))
    {
        g_CurrentLine := 1
    }

    row := g_CurrentCommandList.Length()
    if (row > g_DisplayRows)
    {
        row := g_DisplayRows
    }

    g_CurrentLine := Mod(g_CurrentLine + step, row)
    if (g_CurrentLine == 0)
    {
        g_CurrentLine := row
    }

    ; 重置当前命令
    g_CurrentCommand := g_CurrentCommandList[g_CurrentLine]

    ; 修改输入框内容
    currentChar := Chr(g_FirstChar + g_CurrentLine - 1)
    if (SubStr(g_CurrentInput, 1, 1) == "|")
    {
        newInput := "|@" currentChar " "
    }
    else
    {
        newInput := "@" currentChar " "
    }

    if (g_UseFallbackCommands)
    {
        if (SubStr(g_CurrentInput, 1, 1) == "@")
        {
            newInput .= SubStr(g_CurrentInput, 4)
        }
        else
        {
            newInput .= g_CurrentInput
        }
    }

    ControlGetText, result, %g_DisplayArea%
    result := StrReplace(result, ">| ", " | ")
    if (currentChar == Chr(g_FirstChar))
    {
        result := currentChar ">" SubStr(result, 3)
    }
    else
    {
        result := StrReplace(result, "`r`n" currentChar " | ", "`r`n" currentChar ">| ")
    }

    DisplaySearchResult(result)

    ControlSetText, %g_InputArea%, %newInput%, %g_WindowName%
    Send, {end}
}

GuiClose()
{
    if (!g_Conf.Config.RunInBackground)
    {
        GoSub, ExitRunZ
    }
}

SaveAutoConf()
{
    if (g_Conf.Config.SaveInputText)
    {
        g_AutoConf.DeleteKey("Auto", "InputText")
        g_AutoConf.AddKey("Auto", "InputText", g_CurrentInput)
    }

    if (g_Conf.Config.SaveHistory)
    {
        g_AutoConf.DeleteSection("History")
        g_AutoConf.AddSection("History")

        for index, element in g_HistoryCommands
        {
            if (element != "")
            {
                g_AutoConf.AddKey("History", index, element)
            }
        }
    }

    Loop
    {
        g_AutoConf.Save()

        if (!FileExist(g_AutoConfFile))
        {
            MsgBox, 配置文件 %g_AutoConfFile% 写入后丢失，请检查磁盘并点确定来重试
        }
        else
        {
            break
        }
    }
}

ExitRunZ:
    SaveAutoConf()
    ExitApp
return

GenerateSearchFileList()
{
    FileDelete, %g_SearchFileList%

    searchFileType := g_Conf.Config.SearchFileType

    for dirIndex, dir in StrSplit(g_Conf.Config.SearchFileDir, " | ")
    {
        if (InStr(dir, "A_") == 1)
        {
            searchPath := %dir%
        }
        else
        {
            searchPath := dir
        }

        for extIndex, ext in StrSplit(searchFileType, " | ")
        {
            Loop, Files, %searchPath%\%ext%, R
            {
                if (g_Conf.Config.SearchFileExclude != ""
                        && RegExMatch(A_LoopFileLongPath, g_Conf.Config.SearchFileExclude))
                {
                    continue
                }
                FileAppend, file | %A_LoopFileLongPath%`n, %g_SearchFileList%,
            }
        }
    }
}

ReindexFiles:
    if (WinActive(g_WindowName))
    {
        ToolTip, 正在重建索引，请稍后...
    }

    GenerateSearchFileList()

    GoSub, CleanupRank

    if (WinActive(g_WindowName))
    {
        ToolTip, 重建索引完毕
        SetTimer, RemoveToolTip, 800
    }
return

EditConfig:
    if (g_Conf.Config.Editor != "")
    {
        Run, % g_Conf.Config.Editor " """ g_ConfFile """"
    }
    else
    {
        Run, % g_ConfFile
    }
return

EditAutoConfig:
    if (g_Conf.Config.Editor != "")
    {
        Run, % g_Conf.Config.Editor " """ g_AutoConfFile """"
    }
    else
    {
        Run, % g_AutoConfFile
    }
return


ProcessInputCommand:
    ControlGetText, g_CurrentInput, %g_InputArea%
    ; https://github.com/goreliu/runz/issues/40
    ; 但如果改了这个，快速输入的话，搜索结果可能不更新
    ;GoSub, ProcessInputCommandCallBack
    ;return

    ; 如果使用异步的方式，TurnOnResultFilter 后会出问题，先绕一下
    if (SubStr(g_CurrentInput, 0, 1) == " ")
    {
        GoSub, ProcessInputCommandCallBack
        return
    }

    ; 为了避免搜索时间过长导致不再调用 ProcessInputCommand
    ; 不清楚这样做是否有其他问题
    SetTimer, ProcessInputCommandCallBack, 0
return

ProcessInputCommandCallBack:
    SetTimer, ProcessInputCommandCallBack, Off

    if (g_SkinConf.ShowInputBoxOnlyIfEmpty)
    {
        if (g_CurrentInput != "")
        {
            if (g_SkinConf.ShowCurrentCommand)
            {
                windowHeight := g_SkinConf.BorderSize * 4
                    + g_SkinConf.EditHeight * 2 + g_SkinConf.DisplayAreaHeight
            }
            else
            {
                windowHeight := g_SkinConf.BorderSize * 3
                    + g_SkinConf.EditHeight + g_SkinConf.DisplayAreaHeight
            }
            WinMove, %g_WindowName%, , , , , %windowHeight%
        }
        else
        {
            windowHeight := g_SkinConf.BorderSize * 2 + g_SkinConf.EditHeight
            WinMove, %g_WindowName%, , , , , %windowHeight%
        }

        if (g_SkinConf.RoundCorner > 0)
        {
            WinSet, Region, % "0-0 w" border * 2 + g_SkinConf.WidgetWidth " h" windowHeight
                . " r" g_SkinConf.RoundCorner "-" g_SkinConf.RoundCorner, % g_WindowName
        }
    }

    SearchCommand(g_CurrentInput)
return

SearchCommand(command = "", firstRun = false)
{
    g_UseDisplay := false
    g_ExecInterval := -1
    result := ""
    ; 供去重使用
    fullResult := ""
    static resultToFilter := ""
    commandPrefix := SubStr(command, 1, 1)

    if (commandPrefix == ";" || commandPrefix == ":")
    {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""
        g_PipeArg := ""

        if (commandPrefix == ";")
        {
            g_CurrentCommand := g_FallbackCommands[1]
        }
        else if (commandPrefix == ":")
        {
            g_CurrentCommand := g_FallbackCommands[2]
        }

        g_CurrentCommandList := Object()
        g_CurrentCommandList.Push(g_CurrentCommand)
        result .= Chr(g_FirstChar) ">| "
            . StrReplace(g_CurrentCommand, "function | ", "功能 | ")
        DisplaySearchResult(result)
        return result
    }
    else if (commandPrefix == "|" && Arg != "")
    {
        ; 记录管道参数
        if (g_PipeArg == "")
        {
            g_PipeArg := Arg
        }
        ; 去掉 |，然后按常规搜索处理
        command := SubStr(command, 2)
        if (SubStr(command, 1, 1) == "@")
        {
            command := SubStr(command, 1, 4)
            return
        }
    }
    else if (InStr(command, " ") && g_CurrentCommand != "")
    {
        g_PipeArg := ""

        ; 输入包含空格时锁定搜索结果

        if (g_UseResultFilter)
        {
            if (resultToFilter == "")
            {
                ControlGetText, resultToFilter, %g_DisplayArea%
            }

            ; 取出空格后边的参数
            needle := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
            DisplayResult(FilterResult(resultToFilter, needle))
        }
        else if (g_UseRealtimeExec)
        {
            RunCommand(g_CurrentCommand)
            resultToFilter := ""
        }
        else
        {
            resultToFilter := ""
        }

        return
    }
    else if (commandPrefix == "@")
    {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""

        ; 搜索结果被锁定，直接退出
        return
    }

    g_UseResultFilter := false
    g_UseRealtimeExec := false
    resultToFilter := ""

    if (commandPrefix != "|")
    {
        g_PipeArg := ""
    }

    g_CurrentCommandList := Object()

    order := g_FirstChar

    for index, element in g_Commands
    {
        if (InStr(fullResult, element "`n") || inStr(g_ExcludedCommands, element "`n"))
        {
            continue
        }

        splitedElement := StrSplit(element, " | ")

        if (splitedElement[1] == "file")
        {
            SplitPath, % splitedElement[2], fileName, fileDir, , fileNameNoExt

            ; 只搜索和展示不带扩展名的文件名
            elementToSearch := fileNameNoExt
            if (g_Conf.Config.ShowFileExt)
            {
                elementToShow := "file | " . fileName " | " splitedElement[3]
            }
            else
            {
                elementToShow := "file | " . fileNameNoExt " | " splitedElement[3]
            }


            if (splitedElement.Length() >= 3)
            {
                elementToSearch .= " " . splitedElement[3]
            }

            if (g_Conf.Config.SearchFullPath)
            {
                ; TCMatch 在搜索路径时只搜索文件名，强行将 \ 转成空格
                elementToSearch := StrReplace(fileDir, "\", " ") . " " . elementToSearch
            }
        }
        else
        {
            elementToShow := splitedElement[1] " | " splitedElement[2]
            elementToSearch := StrReplace(splitedElement[2], "/", " ")
            elementToSearch := StrReplace(elementToSearch, "\", " ")

            if (splitedElement.Length() >= 3)
            {
                elementToShow .= " | " splitedElement[3]
                elementToSearch .= " " . splitedElement[3]
            }
        }

        if (command == "" || MatchCommand(elementToSearch, command))
        {
            fullResult .= element "`n"
            g_CurrentCommandList.Push(element)

            if (order == g_FirstChar)
            {
                g_CurrentCommand := element
                result .= Chr(order++) . ">| " . elementToShow
            }
            else
            {
                result .= "`n" Chr(order++) . " | " . elementToShow
            }

            if (order - g_FirstChar >= g_DisplayRows)
            {
                break
            }
            ; 第一次运行只加载 function 类型
            if (firstRun && (order - g_FirstChar >= g_DisplayRows - 4))
            {
                result .= "`n`n现有 " g_Commands.Length() " 条搜索项。"
                result .= "`n`n键入内容 搜索，回车 执行当前命令，Alt + 字母 执行，F1 帮助，Esc 关闭。"

                break
            }
        }
    }

    if (result == "")
    {
        if (IsLabel("Calc") && Eval(g_CurrentInput) != 0)
        {
            DisplayResult(Eval(g_CurrentInput))
            return
        }

        g_UseFallbackCommands := true
        g_CurrentCommand := g_FallbackCommands[1]
        g_CurrentCommandList := g_FallbackCommands

        for index, element in g_FallbackCommands
        {
            if (index == 1)
            {
                result .= Chr(g_FirstChar - 1 + index++) . ">| " element
            }
            else
            {
                result .= "`n"
                result .= Chr(g_FirstChar - 1 + index++) . " | " element
            }
        }
    }
    else
    {
        g_UseFallbackCommands := false
    }

    if (g_SkinConf.HideCol2)
    {
        result := StrReplace(result, "file | ")
        result := StrReplace(result, "function | ")
        result := StrReplace(result, "cmd | ")
        result := StrReplace(result, "url | ")
    }
    else
    {
        result := StrReplace(result, "file | ", "文件 | ")
        result := StrReplace(result, "function | ", "功能 | ")
        result := StrReplace(result, "cmd | ", "命令 | ")
        result := StrReplace(result, "url | ", "网址 | ")
    }

    DisplaySearchResult(result)
    return result
}

DisplaySearchResult(result)
{
    DisplayControlText(result)

    if (g_CurrentCommandList.Length() == 1 && g_Conf.Config.RunIfOnlyOne)
    {
        RunCommand(g_CurrentCommand)
    }

    if (g_SkinConf.ShowCurrentCommand)
    {
        commandToShow := SubStr(g_CurrentCommand, InStr(g_CurrentCommand, " | ") + 3)
        ControlSetText, %g_CommandArea%, %commandToShow%, %g_WindowName%
    }
}

FilterResult(text, needle)
{
    result := ""
    Loop, Parse, text, `n, `r
    {
        if (!InStr(A_LoopField, " | ") && MatchResult(A_LoopField, needle))
        {
            result .= A_LoopField "`n"
        }
        else if (MatchResult(StrReplace(SubStr(A_LoopField, 5), "\", " "), needle))
        {
            result .= A_LoopField "`n"
        }
    }

    return result
}

TurnOnResultFilter()
{
    if (!g_UseResultFilter)
    {
        g_UseResultFilter := true

        if (!InStr(g_CurrentInput, " "))
        {
            ControlFocus, %g_InputArea%
            Send, {space}
        }
    }
}

TurnOnRealtimeExec()
{
    if (!g_UseRealtimeExec)
    {
        g_UseRealtimeExec := true

        if (!InStr(g_CurrentInput, " "))
        {
            ControlFocus, %g_InputArea%
            Send, {space}
        }
    }
}

SetExecInterval(second)
{
    ; g_ExecInterval 为 0 时，表示可以进入间隔运行状态
    ; g_ExecInterval 为 -1 时，表示状态以被打破，需要退出
    if (g_ExecInterval >= 0)
    {
        g_ExecInterval := second * 1000
        return true
    }
    else
    {
        SetTimer, %g_LastExecLabel%, Off
        return false
    }
}

ClearInput:
    ClearInput()
return

; 给插件用的函数
ClearInput()
{
    ControlSetText, %g_InputArea%, , %g_WindowName%
    ControlFocus, %g_InputArea%
}

RunCurrentCommand:
    RunCommand(g_CurrentCommand)
return

ParseArg:
    if (g_PipeArg != "")
    {
        Arg := g_PipeArg
        return
    }

    commandPrefix := SubStr(g_CurrentInput, 1, 1)

    ; 分号或者冒号的情况，直接取命令为参数
    if (commandPrefix == ";" || commandPrefix == ":")
    {
        Arg := SubStr(g_CurrentInput, 2)
        return
    }
    else if (commandPrefix == "@")
    {
        ; 处理调整过顺序的命令
        Arg := SubStr(g_CurrentInput, 4)
        return
    }

    ; 用空格来判断参数
    if (InStr(g_CurrentInput, " ") && !g_UseFallbackCommands)
    {
        Arg := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
    }
    else if (g_UseFallbackCommands)
    {
        Arg := g_CurrentInput
    }
    else
    {
        Arg := ""
    }
return

MatchCommand(Haystack, Needle)
{
    if (g_EnableTCMatch)
    {
        return TCMatch(Haystack, Needle)
    }

    return InStr(Haystack, Needle)
}

MatchResult(Haystack, Needle)
{
    if (g_EnableTCMatch)
    {
        return TCMatch(Haystack, Needle)
    }

    return InStr(Haystack, Needle)
}

RunCommand(originCmd)
{
    GoSub, ParseArg

    g_UseDisplay := false
    g_DisableAutoExit := true
    g_ExecInterval := 0

    splitedOriginCmd := StrSplit(originCmd, " | ")
    cmd := splitedOriginCmd[2]

    if (splitedOriginCmd[1] == "file")
    {
        if (InStr(cmd, ".lnk"))
        {
            ; 处理 32 位 ahk 运行不了某些 64 位系统 .lnk 的问题
            FileGetShortcut, %cmd%, filePath
            if (!FileExist(filePath))
            {
                filePath := StrReplace(filePath, "C:\Program Files (x86)", "C:\Program Files")
                if (FileExist(filePath))
                {
                    cmd := filePath
                }
            }
        }

        SplitPath, cmd, , fileDir, ,

        if (Arg == "")
        {
            Run, %cmd%, %fileDir%
        }
        else
        {
            Run, %cmd% "%Arg%", %fileDir%
        }
    }
    else if (splitedOriginCmd[1] == "function")
    {
        ; 第四个参数是参数
        if (splitedOriginCmd.Length() >= 4)
        {
            Arg := splitedOriginCmd[4]
        }

        if (IsLabel(cmd))
        {
            GoSub, %cmd%
        }
    }
    else if (splitedOriginCmd[1] == "cmd")
    {
        RunWithCmd(cmd)
    }
    else if (splitedOriginCmd[1] == "url")
    {
        url := splitedOriginCmd[2]
        if (!Instr(url, "http"))
        {
            url := "http://" . url
        }

        Run, %url%
    }

    if (g_Conf.Config.SaveHistory && cmd != "DisplayHistoryCommands")
    {
        if (splitedOriginCmd.Length() == 3 && Arg != "")
        {
            g_HistoryCommands.InsertAt(1, originCmd " | " Arg)
        }
        else if (originCmd != "")
        {
            g_HistoryCommands.InsertAt(1, originCmd)
        }

        if (g_HistoryCommands.Length() > g_Conf.Config.HistorySize)
        {
            g_HistoryCommands.Pop()
        }
    }

    if (g_Conf.Config.AutoRank)
    {
        ChangeRank(originCmd)
    }

    g_DisableAutoExit := false

    if (g_Conf.Config.RunOnce && !g_UseDisplay)
    {
        if (!g_Conf.Config.KeepInputText)
        {
            GoSub, ClearInput
        }
        GoSub, HideOrExit
    }

    if (g_ExecInterval > 0 && splitedOriginCmd[1] == "function")
    {
        SetTimer, %cmd%, %g_ExecInterval%
        g_LastExecLabel := cmd
    }

    g_PipeArg := ""
    FullPipeArg := ""
}

ChangeRank(cmd, show = false, inc := 1)
{
    splitedCmd := StrSplit(cmd, " | ")

    if (splitedCmd.Length() >= 4 && splitedCmd[1] == "function")
    {
        ; 去掉参数
        cmd := splitedCmd[1]  " | " splitedCmd[2] " | " splitedCmd[3]
    }

    cmdRank := g_AutoConf.GetValue("Rank", cmd)
    if cmdRank is integer
    {
        g_AutoConf.DeleteKey("Rank", cmd)
        cmdRank += inc
    }
    else
    {
        cmdRank := inc
    }

    if (cmdRank != 0 && cmd != "")
    {
        ; 如果将到负数，都设置成 -1，然后屏蔽
        if (cmdRank < 0)
        {
            cmdRank := -1
            g_ExcludedCommands .= cmd "`n"
        }

        g_AutoConf.AddKey("Rank", cmd, cmdRank)
    }
    else
    {
        cmdRank := 0
    }

    if (show)
    {
        ToolTip, 调整 %cmd% 的权重到 %cmdRank%
        SetTimer, RemoveToolTip, 800
    }
}

; 比较耗时，必要时才使用，也可以手动编辑 RunZ.auto.ini
CleanupRank:
    ; 先把 g_Commands 里的 Rank 信息清掉
    LoadFiles(false)

    for command, rank in g_AutoConf.Rank
    {
        cleanup := true
        for index, element in g_Commands
        {
            if (InStr(element, command) == 1)
            {
                cleanup := false
                break
            }
        }
        if (cleanup)
        {
            g_AutoConf.DeleteKey("Rank", command)
        }
    }

    Loop
    {
        g_AutoConf.Save()

        if (!FileExist(g_AutoConfFile))
        {
            MsgBox, 配置文件 %g_AutoConfFile% 写入后丢失，请检查磁盘并点确定来重试
        }
        else
        {
            break
        }
    }

    LoadFiles()
return

RunSelectedCommand:
    if (SubStr(A_ThisHotkey, 1, 1) == "~")
    {
        ControlGetFocus, ctrl,
        if (ctrl == g_InputArea)
        {
            return
        }
    }

    index := Asc(SubStr(A_ThisHotkey, 0, 1)) - g_FirstChar + 1

    RunCommand(g_CurrentCommandList[index])
return

IncreaseRank:
    if (g_CurrentCommand != "")
    {
        ChangeRank(g_CurrentCommand, true)
        LoadFiles()
    }
return

DecreaseRank:
    if (g_CurrentCommand != "")
    {
        ChangeRank(g_CurrentCommand, true, -1)
        LoadFiles()
    }
return

LoadFiles(loadRank := true)
{
    g_Commands := Object()
    g_FallbackCommands := Object()

    if (loadRank)
    {
        rankString := ""
        for command, rank in g_AutoConf.Rank
        {
            if (StrLen(command) > 0)
            {
                if (rank >= 1)
                {
                    rankString .= rank "`t" command "`n"
                }
                else
                {
                    g_ExcludedCommands .= command "`n"
                }
            }
        }

        if (rankString != "")
        {
            Sort, rankString, R N

            Loop, Parse, rankString, `n
            {
                if (A_LoopField == "")
                {
                    continue
                }

                g_Commands.Push(StrSplit(A_LoopField, "`t")[2])
            }
        }
    }


    for key, value in g_Conf.Command
    {
        if (value != "")
        {
            g_Commands.Push(key . " | " . value)
        }
        else
        {
            g_Commands.Push(key)
        }
    }

    for index, element in g_Plugins
    {
        if (IsLabel(element))
        {
            GoSub, %element%
        }
        else
        {
            MsgBox, 未在 %A_ScriptDir%\Plugins\%element%.ahk 中发现 %element% 标签，请修改！
        }
    }

    g_FallbackCommands := Object()
    for key, value in g_Conf.FallbackCommand
    {
        if (IsLabel(StrSplit(key, " | ")[2]))
        {
            g_FallbackCommands.Push(key)
        }
    }

    if (g_FallbackCommands.Length() == 0)
    {
        g_FallbackCommands.Push("function | AhkRun | 使用 Ahk 的 Run() 运行")
    }

    if (FileExist(A_ScriptDir "\Conf\UserFunctionsAuto.txt"))
    {
        userFunctionLabel := "UserFunctionsAuto"
        if (IsLabel(userFunctionLabel))
        {
            GoSub, %userFunctionLabel%
        }
        else
        {
            MsgBox, 未在 %A_ScriptDir%\Conf\UserFunctionsAuto.txt 中发现 %userFunctionLabel% 标签，请修改！
        }
    }

    if (FileExist(g_UserFileList))
    {
        Loop, Read, %g_UserFileList%
        {
            g_Commands.Push(A_LoopReadLine)
        }
    }

    Loop, Read, %g_SearchFileList%
    {
        g_Commands.Push(A_LoopReadLine)
    }

    if (g_Conf.Config.LoadControlPanelFunctions)
    {
        Loop, Read, %A_ScriptDir%\Core\ControlPanelFunctions.txt
        {
            g_Commands.Push(A_LoopReadLine)
        }
    }
}

; 用来显示控制界面
DisplayControlText(text)
{
    ControlSetText, %g_DisplayArea%, % AlignText(text), %g_WindowName%
}

; 用来显示命令结果
DisplayResult(result := "")
{
    textToDisplay := StrReplace(result, "`n", "`r`n")
    ControlSetText, %g_DisplayArea%, %textToDisplay%, %g_WindowName%
    g_UseDisplay := true
    result := ""
    textToDisplay := ""
}

LoadHistoryCommands()
{
    historySize := g_Conf.Config.HistorySize

    index := 0
    for key, value in g_AutoConf.History
    {
        if (StrLen(value) > 0)
        {
            g_HistoryCommands.Push(value)
            index++

            if (index == historySize)
            {
                return
            }
        }
    }
}

DisplayHistoryCommands:
    g_UseDisplay := false
    result := ""
    g_CurrentCommandList := Object()
    g_CurrentLine := 1

    for index, element in g_HistoryCommands
    {
        if (index == 1)
        {
            result .= Chr(g_FirstChar + index - 1) . ">| "
            g_CurrentCommand := element
        }
        else
        {
            result .= Chr(g_FirstChar + index - 1) . " | "
        }

        splitedElement := StrSplit(element, " | ")

        result .= splitedElement[1] " | " splitedElement[2]
            . " | " splitedElement[3] " #参数： " splitedElement[4] "`n"

        g_CurrentCommandList.Push(element)
    }

    result := StrReplace(result, "file | ", "文件 | ")
    result := StrReplace(result, "function | ", "功能 | ")
    result := StrReplace(result, "cmd | ", "命令 | ")
    result := StrReplace(result, "url | ", "网址 | ")

    DisplayControlText(result)
return

; 第三个参数不再是 fallback，备用，为了兼容不改变第四个参数的含义
@(label, info, fallback = false, key = "")
{
    if (!IsLabel(label))
    {
        MsgBox, 未找到 %label% 标签，请检查 %A_ScriptDir%\Conf\UserFunctions.ahk 文件格式！
        return
    }

    g_Commands.Push("function | " . label . " | " . info )

    if (key != "")
    {
        Hotkey, %key%, %label%
    }
}

RunAndGetOutput(command)
{
    tempFileName := "RunZ.stdout.log"
    fullCommand = %ComSpec% /C "%command% > %tempFileName%"

    /*
    fullCommand = bash -c "%command% &> %tempFileName%"

    if (!FileExist("c:\msys64\usr\bin\bash.exe"))
    {
        fullCommand = %ComSpec% /C "%command% > %tempFileName%"
    }
    */

    RunWait, %fullCommand%, %A_Temp%, Hide
    FileRead, result, %A_Temp%\%tempFileName%
    FileDelete, %A_Temp%\%tempFileName%
    return result
}

RunWithCmd(command, onlyCmd = false)
{
    if (!onlyCmd && FileExist("c:\msys64\usr\bin\mintty.exe"))
    {
        Run, % "mintty -e sh -c '" command "; read'"
    }
    else
    {
        Run, % ComSpec " /C " command " & pause"
    }
}

OpenPath(filePath)
{
    if (!FileExist(filePath))
    {
        return
    }

    if (FileExist(g_Conf.Config.TCPath))
    {
        TCPath := g_Conf.Config.TCPath
        Run, %TCPath% /O /A /L="%filePath%"
    }
    else
    {
        SplitPath, filePath, , fileDir, ,
        Run, explorer "%fileDir%"
    }
}

GetAllFunctions()
{
    result := ""

    for index, element in g_Commands
    {
        if (InStr(element, "function | ") == 1 and !InStr(result, element "`n"))
        {
            result .= "* | " element "`n"
        }
    }

    result := StrReplace(result, "function | ", "功能 | ")

    return AlignText(result)
}

OpenCurrentFileDir:
    filePath := StrSplit(g_CurrentCommand, " | ")[2]
    OpenPath(filePath)
return

DeleteCurrentFile:
    filePath := StrSplit(g_CurrentCommand, " | ")[2]

    if (!FileExist(filePath))
    {
        return
    }

    FileRecycle, % filePath
    GoSub, ReindexFiles
return

ShowCurrentFile:
    clipboard := StrSplit(g_CurrentCommand, " | ")[2]
    ToolTip, % clipboard
    SetTimer, RemoveToolTip, 800
return

RemoveToolTip:
    ToolTip
    SetTimer, RemoveToolTip, Off
return


WM_MOUSEMOVE(wParam, lParam)
{
    if (wparam = 1) ; LButton
    {
        PostMessage, 0xA1, 2, , , A ; WM_NCLBUTTONDOWN
    }

    if (!g_Conf.Config.ChangeCommandOnMouseMove)
    {
        return
    }

    MouseGetPos, , mouseY, , classnn,
    if (classnn != g_DisplayArea)
    {
        return -1
    }

    ControlGetPos, , y, , h, %g_DisplayArea%
    lineHeight := h / g_DisplayRows
    index := Ceil((mouseY - y) / lineHeight)

    if (g_CurrentCommandList[index] != "")
    {
        ChangeCommand(index - 1, true)
    }
}

WM_ACTIVATE(wParam, lParam)
{
    if (g_DisableAutoExit)
    {
        return
    }

    if (wParam >= 1) ; 窗口激活
    {
        return
    }
    else if (wParam <= 0) ; 窗口非激活
    {
        ; 这样有可能第一次显示主界面时，窗口失去焦点后不关闭
        ; 暂时没有好的解决方法，如果改用 SetTimer 调用，会导致用快捷键显示主窗口失败

		if (!WinExist("RunZ.ahk"))
		{
			if (!g_Conf.Config.KeepInputText)
			{
				ControlSetText, %g_InputArea%, , %g_WindowName%
			}

			GoSub, HideOrExit
		}
    }
}

KeyHelpText()
{
    return AlignText(""
    . "* | 按键 | Shift + F1 | 显示置顶的按键提示`n"
    . "* | 按键 | Alt + F4   | 退出置顶的按键提示`n"
    . "* | 按键 | 回车       | 执行当前命令`n"
    . "* | 按键 | Esc        | 关闭窗口`n"
    . "* | 按键 | Alt +      | 加每列行首字符执行`n"
    . "* | 按键 | Tab +      | 再按每列行首字符执行`n"
    . "* | 按键 | Tab +      | 再按 Shift + 行首字符 定位`n"
    . "* | 按键 | Win  + j   | 显示或隐藏窗口`n"
    . "* | 按键 | Ctrl + j   | 移动到下一条命令`n"
    . "* | 按键 | Ctrl + k   | 移动到上一条命令`n"
    . "* | 按键 | Ctrl + f   | 在输出结果中翻到下一页`n"
    . "* | 按键 | Ctrl + b   | 在输出结果中翻到上一页`n"
    . "* | 按键 | Ctrl + h   | 显示历史记录`n"
    . "* | 按键 | Ctrl + n   | 可增加当前功能的权重`n"
    . "* | 按键 | Ctrl + p   | 可减少当前功能的权重`n"
    . "* | 按键 | Ctrl + l   | 清除编辑框内容`n"
    . "* | 按键 | Ctrl + r   | 重新创建待搜索文件列表`n"
    . "* | 按键 | Ctrl + q   | 重启`n"
    . "* | 按键 | Ctrl + d   | 用 TC 打开第一个文件所在目录`n"
    . "* | 按键 | Ctrl + s   | 显示并复制当前文件的完整路径`n"
    . "* | 按键 | Ctrl + x   | 删除当前文件`n"
    . "* | 按键 | Ctrl + i   | 移动光标当行首`n"
    . "* | 按键 | Ctrl + o   | 移动光标当行尾`n"
    . "* | 按键 | F2         | 编辑配置文件`n"
    . "* | 按键 | F3         | 编辑自动写入的配置文件`n"
    . "* | 功能 | 输入网址   | 可直接输入 www 或 http 开头的网址`n"
    . "* | 功能 | `;         | 以分号开头命令，用 ahk 运行`n"
    . "* | 功能 | :          | 以冒号开头的命令，用 cmd 运行`n"
    . "* | 功能 | 无结果     | 搜索无结果，回车用 ahk 运行`n"
    . "* | 功能 | 空格       | 输入空格后，搜索内容锁定")
}

UpdateSendTo(create = true, overwrite = false)
{
    lnkFilePath := StrReplace(A_StartMenu, "\Start Menu", "\SendTo\") "RunZ.lnk"

    if (!create)
    {
        FileDelete, %lnkFilePath%
        return
    }

    if (!overwrite && FileExist(lnkFilePath))
    {
        return
    }

    FileCreateShortcut, % A_ScriptDir "\RunZ.exe", % A_ScriptDir "\Core\SendToRunZ.lnk"
        , , "%A_ScriptDir%\Core\RunZCmdTool.ahk", 发送到 RunZ, % A_ScriptDir "\RunZ.ico"
    FileCopy, % A_ScriptDir "\Core\SendToRunZ.lnk"
        , % StrReplace(A_StartMenu, "\Start Menu", "\SendTo\") "RunZ.lnk", 1
}

UpdateStartupLnk(create = true, overwrite = false)
{
    lnkFilePath := A_Startup "\RunZ.lnk"

    if (!create)
    {
        FileDelete, %lnkFilePath%
        return
    }

    if (!FileExist(lnkFilePath) || overwrite)
    {
        FileCreateShortcut, % A_ScriptDir "\RunZ.exe", %lnkFilePath%
            , %A_ScriptDir%, RunZ.ahk --hide, RunZ, % A_ScriptDir "\RunZ.ico"
    }
}

ChangePath:
    UpdateSendTo(g_Conf.Config.CreateSendToLnk, true)
    UpdateStartupLnk(g_Conf.Config.CreateStartupLnk, true)
return

AlignText(text)
{
    col3MaxLen := g_SkinConf.DisplayCol3MaxLength
    col4MaxLen := g_SkinConf.DisplayCol4MaxLength
    col3Pos := 10

    StrSpace := " "
    Loop, % col3MaxLen + col4MaxLen
        StrSpace .= " "

    result := ""

    if (g_SkinConf.HideCol2)
    {
        ; 隐藏第二列的话，把第二列的空间分给第三列
        col3MaxLen += 7
        col3Pos := 5

        hasCol2 := true
        Loop, Parse, text, `n, `r
        {
            if (SubStr(text, 3, 1) != "|" || SubStr(text, 8, 1) != "|")
            {
                hasCol2 := false
                break
            }
        }

        if (hasCol2)
        {
            col3Pos := 10
        }
    }

    if (g_SkinConf.HideCol4IfEmpty)
    {
        Loop, Parse, text, `n, `r
        {
            if (StrSplit(SubStr(A_LoopField, col3Pos), " | ")[2] != "")
            {
                hasCol4 := true
                break
            }
        }

        if (!hasCol4)
        {
            ; 加上中间的 " | "
            col3MaxLen += col4MaxLen + 3
            col4MaxLen := 0
        }
    }

    Loop, Parse, text, `n, `r
    {
        if (!InStr(A_LoopField, " | "))
        {
            result .= A_LoopField "`r`n"
            continue
        }

        if (hasCol2)
        {
            ; 内容包含第二列，需要去掉
            result .= SubStr(A_LoopField, 1, 4)
        }
        else
        {
            result .= SubStr(A_LoopField, 1, col3Pos - 1)
        }

        splitedLine := StrSplit(SubStr(A_LoopField, col3Pos), " | ")
        col3RealLen := StrLen(RegExReplace(splitedLine[1], "[^\x00-\xff]", "`t`t"))

        if (col3RealLen > col3MaxLen)
        {
            result .= SubStrByByte(splitedLine[1], col3MaxLen)
        }
        else
        {
            result .= splitedLine[1] . SubStr(StrSpace, 1, col3MaxLen - col3RealLen)
        }

        if (col4MaxLen > 0)
        {
            result .= " | "

            col4RealLen := StrLen(RegExReplace(splitedLine[2], "[^\x00-\xff]", "`t`t"))

            if (col4RealLen > col4MaxLen)
            {
                result .= SubStrByByte(splitedLine[2], col4MaxLen)
            }
            else
            {
                result .= splitedLine[2]
            }
        }

        result .= "`r`n"
    }

    return result
}

WatchUserFileList:
    FileGetTime, newUserFileListModifyTime, %g_UserFileList%
    if (newUserFileListModifyTime == "")
    {
        FileAppend, , %g_UserFileList%
    }

    if (lastUserFileListModifyTime != "" && lastUserFileListModifyTime != newUserFileListModifyTime)
    {
        LoadFiles()
    }
    lastUserFileListModifyTime := newUserFileListModifyTime

    FileGetTime, newConfFileModifyTime, %g_ConfFile%
    if (lastConfFileModifyTime != "" && lastConfFileModifyTime != newConfFileModifyTime)
    {
        GoSub, RestartRunZ
    }
    lastConfFileModifyTime := newConfFileModifyTime
return

SaveResultAsArg:
    Arg := ""
    ControlGetText, result, %g_DisplayArea%

    ; 处理隐藏第二列的情况
    if (g_SkinConf.HideCol2)
    {
        FullPipeArg := ""
        Loop, Parse, result, `n, `r
        {
            FullPipeArg .= SubStr(A_LoopField, 1, 2) "| 占位 | " SubStr(A_LoopField, 5) "`n"
        }
    }
    else
    {
        FullPipeArg := result
    }

    if (InStr(g_CurrentCommand, "file | ") == 1)
    {
        Arg .= StrSplit(g_CurrentCommand, " | ")[2]
    }
    else if (!InStr(result, " | "))
    {
        Arg .= StrReplace(result, "`n", " ")
        Arg := StrReplace(Arg, "`r")
    }
    else
    {
        if (g_SkinConf.HideCol2)
        {
            Loop, Parse, result, `n, `r
            {
                Arg .= Trim(StrSplit(A_LoopField, " | ")[2]) " "
            }
        }
        else
        {
            Loop, Parse, result, `n, `r
            {
                Arg .= Trim(StrSplit(A_LoopField, " | ")[3]) " "
            }
        }
    }

    Arg := Trim(Arg)

    ControlFocus, %g_InputArea%
    ControlSetText, %g_InputArea%, |
    Send, {End}
    if (g_CommandFilter != "")
    {
        ; 第一个 | 代表要用管道执行，不然 g_PipeArg 会被清空
        SearchCommand("|" g_CommandFilter)
        g_CommandFilter := ""
    }
return

; 格式：
; 与 command1&command2
; 或 command1|command2
; 非 !command1
SetCommandFilter(command)
{
    g_CommandFilter := command
}

Help:
    DisplayResult(KeyHelpText() . GetAllFunctions())
return

KeyHelp:
    ToolTip, % KeyHelpText()
    SetTimer, RemoveToolTip, 5000
return


#include %A_ScriptDir%\Lib\EasyIni.ahk
#include %A_ScriptDir%\Lib\TCMatch.ahk
#include %A_ScriptDir%\Core\Common.ahk
#include *i %A_ScriptDir%\Core\Plugins.ahk
; 发送到菜单自动生成的命令
#include *i %A_ScriptDir%\Conf\UserFunctionsAuto.txt
