#NoEnv
#SingleInstance, Force
#NoTrayIcon

FileEncoding, utf-8
SendMode Input
SetWorkingDir %A_ScriptDir%

; 自动生成的命令文件
global g_SearchFileList := A_ScriptDir . "\SearchFileList.txt"
; 配置文件
global g_ConfFile := A_ScriptDir . "\RunZ.ini"
; 自动写入的配置文件
global g_AutoConfFile := A_ScriptDir . "\RunZ.auto.ini"

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
    FileAppend, % "; 请不要手动修改此文件`n`n[Auto]`n[Rank]`n[History]" , % g_AutoConfFile
}

global g_Conf := class_EasyINI(g_ConfFile)
global g_AutoConf := class_EasyINI(g_AutoConfFile)

; 当前输入命令的参数，数组，为了方便没有添加 g_ 前缀
global Arg
; 不能是 RunZ.ahk 的子串，否则按键绑定会有问题
global g_WindowName := "RunZ "
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
global g_FirstChar := Asc(g_Conf.Gui.FirstChar)
; 在列表中显示的行数
global g_DisplayRows := g_Conf.Gui.DisplayRows
; 在列表中显示的文字列数（多出的会被截断）
global g_DisplayCols := g_Conf.Gui.DisplayCols
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
global g_InputArea := "Edit1"
global g_OutputArea := "Edit3"
global g_CommandArea := "Edit5"

if (g_Conf.Gui.ShowTrayIcon)
{
    Menu, Tray, Icon
}

if (FileExist(g_SearchFileList))
{
    LoadFiles()
}
else
{
    GoSub, ReloadFiles
}

Gui, Font, % "s" g_Conf.Gui.FontSize, % g_Conf.Gui.FontName
Gui, Add, Edit, % "gProcessInputCommand vSearchArea"
        . " w" g_Conf.Gui.WidgetWidth " h" g_Conf.Gui.EditHeight,
Gui, Add, Edit, w0 h0 ReadOnly,
Gui, Add, Edit, % "ReadOnly vDisplayArea "
        . (g_Conf.Gui.HideDisplayAreaVScroll ? "-VScroll " : "")
        . " w" g_Conf.Gui.WidgetWidth " h" g_Conf.Gui.DisplayAreaHeight
        , % SearchCommand("", true)

if (g_Conf.Gui.ShowCurrentCommand)
{
    Gui, Add, Edit, w0 h0 ReadOnly,
    Gui, Add, Edit, % "ReadOnly"
        . " w" g_Conf.Gui.WidgetWidth " h" g_Conf.Gui.EditHeight,
}

if (g_Conf.Gui.HideTitle)
{
    Gui -Caption
}

Gui, Show, , % g_WindowName

if (g_Conf.Config.WindowAlwaysOnTop)
{
    WinSet, AlwaysOnTop, On, A
}

if (g_Conf.Config.ExitIfInactivate)
{
    OnMessage(0x06, "WM_ACTIVATE")
}

Hotkey, IfWinActive, % g_WindowName
; 如果是 ~enter，有时候会响
Hotkey, enter, RunCurrentCommand

; 如果是后台运行模式，Esc 键只关闭窗口，不退出程序
Hotkey, esc, EscFunction
Hotkey, !f4, ExitRunZ

Hotkey, tab, TabFunction
Hotkey, f1, Help
Hotkey, +f1, KeyHelp
Hotkey, f2, EditConfig
Hotkey, ^l, ClearInput
Hotkey, ^d, OpenCurrentFileDir
Hotkey, ^x, DeleteCurrentFile
Hotkey, ^s, ShowCurrentFile
Hotkey, ^r, ReloadFiles
Hotkey, ^h, DisplayHistoryCommands
Hotkey, ^n, IncreaseRank
Hotkey, ^p, DecreaseRank
Hotkey, ^f, NextPage
Hotkey, ^b, PrevPage
Hotkey, ^i, HomeKey
Hotkey, ^o, EndKey
Hotkey, ^j, NextCommand
Hotkey, ^k, PrevCommand
Hotkey, down, NextCommand
Hotkey, up, PrevCommand

; 剩余按键 e g j m q t w n p

Loop, % g_DisplayRows
{
    key := Chr(g_FirstChar + A_Index - 1)
    ; lalt +
    Hotkey, !%key%, RunSelectedCommand1
    ; tab +
    Hotkey, ~%key%, RunSelectedCommand2
    ; shift +
    Hotkey, ~+%key%, GotoCommand
}

; 用户映射的按键

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

return

Default:
return

Test:
    MsgBox Test
return

HomeKey:
    Send, {home}
return

EndKey:
    Send, {End}
return

NextPage:
    ControlFocus, %g_OutputArea%
    Send, {pgdn}
return

PrevPage:
    ControlFocus, %g_OutputArea%
    Send, {pgup}
return

ActivateWindow:
    Gui, Show, , % g_WindowName
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
    ChangeCommand(1)
return

PrevCommand:
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

    if (resetCurrentLine || SubStr(g_CurrentInput, 1, 1) != "@")
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
    newInput := "@" currentChar " "

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

    ControlGetText, result, %g_OutputArea%
    result := StrReplace(result, ">| ", " | ")
    if (currentChar == Chr(g_FirstChar))
    {
        result := currentChar ">" SubStr(result, 3)
    }
    else
    {
        result := StrReplace(result, "`n" currentChar " | ", "`n" currentChar ">| ")
    }

    DisplaySearchResult(result)

    ControlSetText, %g_InputArea%, %newInput%
    Send, {end}
}

GuiClose()
{
    if (!g_Conf.Config.RunInBackground)
    {
        GoSub, ExitRunZ
    }
}

ExitRunZ:
    saveConf := false

    if (g_Conf.Config.SaveInputText)
    {
        g_AutoConf.DeleteKey("Auto", "InputText")
        g_AutoConf.AddKey("Auto", "InputText", g_CurrentInput)
        saveConf := true
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

        saveConf := true
    }

    if (g_Conf.Config.AutoRank)
    {
        saveConf := true
    }

    if (saveConf)
    {
        g_AutoConf.Save()

        Loop
        {
            if (!FileExist(g_AutoConfFile))
            {
                MsgBox, 配置文件 %g_AutoConfFile% 写入后丢失，请检查磁盘并点确定来重试
            }
            else
            {
                break
            }
        }

        /*
        应该没有这个问题，备用
        FileGetSize, oldFileSize, %g_AutoConfFile%
        FileCopy, %g_AutoConfFile%, %g_AutoConfFile%.debug
        g_AutoConf.Save()
        ;...
        FileGetSize, newFileSize, %g_AutoConfFile%
        if (oldFileSize - newFileSize >= 50)
        {
            MsgBox, % "配置文件 " g_AutoConfFile
                . "`n减小了 " oldFileSize - newFileSize " 字节"
                . "`n如有疑问请不要退出或重新启动 RunZ，以免配置丢失"
                . "`n配置文件已备份到"
                . "`n" . g_AutoConfFile . ".debug"
        }
        */
    }

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
                        && RegexMatch(A_LoopFileLongPath, g_Conf.Config.SearchFileExclude))
                {
                    continue
                }
                FileAppend, file | %A_LoopFileLongPath%`n, %g_SearchFileList%,
            }
        }
    }
}

ReloadFiles:
    GenerateSearchFileList()

    LoadFiles()
return

ProcessInputCommand:
    ControlGetText, g_CurrentInput, %g_InputArea%

    SearchCommand(g_CurrentInput)
return

SearchCommand(command = "", firstRun = false)
{
    result := ""
    ; 供去重使用
    fullResult := ""
    commandPrefix := SubStr(command, 1, 1)

    if (commandPrefix == ";" || commandPrefix == ":")
    {
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
        result .= Chr(g_FirstChar) ">| " . g_CurrentCommand
        DisplaySearchResult(result)
        return result
    }
    else if (commandPrefix == "@")
    {
        ; 搜索结果被锁定，直接退出
        return
    }
    else if (InStr(command, " ") && g_CurrentCommand != "")
    {
        ; 输入包含空格时锁定搜索结果
        return
    }

    g_CurrentCommandList := Object()

    order := g_FirstChar

    for index, element in g_Commands
    {
        if (InStr(fullResult, element "`n"))
        {
            continue
        }

        splitedElement := StrSplit(element, " | ")

        if (splitedElement[1] == "file")
        {
            SplitPath, % splitedElement[2], , fileDir, , fileNameNoExt

            ; 只搜索和展示不带扩展名的文件名
            elementToSearch := fileNameNoExt
            elementToShow := "file | " . fileNameNoExt

            if (splitedElement.Length() >= 3)
            {
                elementToSearch .= " " . splitedElement[3]
                elementToShow .= "（" . splitedElement[3] . "）"
            }

            elementToShow := SubStr(elementToShow, 1, g_DisplayCols)

            if (g_Conf.Config.SearchFullPath)
            {
                ; TCMatch 在搜索路径时只搜索文件名，强行将 \ 转成空格
                elementToSearch := StrReplace(fileDir, "\", " ") . " " . elementToSearch
            }
        }
        else
        {
            elementToShow := SubStr(element, 1, g_DisplayCols)
            elementToSearch := splitedElement[2]

            if (splitedElement.Length() >= 3)
            {
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
                result .= "`n`n现有 " g_Commands.Length() " 条命令。"
                result .= "`n`n键入内容 搜索，回车 执行当前命令，Alt + 字母 执行，F1 帮助，Esc 退出。"

                break
            }
        }
    }

    if (result == "")
    {
        g_UseFallbackCommands := true
        g_CurrentCommand := g_FallbackCommands[1]
        g_CurrentCommandList := g_FallbackCommands

        for index, element in g_FallbackCommands
        {
            if (index == 1)
            {
                result .= Chr(g_FirstChar - 1 + index++) . ">| " . element
            }
            else
            {
                result .= "`n"
                result .= Chr(g_FirstChar - 1 + index++) . " | " . element
            }
        }
    }
    else
    {
        g_UseFallbackCommands := false
    }

    result := StrReplace(result, "file | ", "文件 | ")
    result := StrReplace(result, "function | ", "功能 | ")
    result := StrReplace(result, "cmd | ", "命令 | ")

    DisplaySearchResult(result)
    return result
}

DisplaySearchResult(result)
{
    DisplayText(result)

    if (g_CurrentCommandList.Length() == 1 && g_Conf.Config.RunIfOnlyOne)
    {
        RunCommand(g_CurrentCommand)
    }

    if (g_Conf.Gui.ShowCurrentCommand)
    {
        commandToShow := SubStr(g_CurrentCommand, InStr(g_CurrentCommand, " | ") + 3)
        ControlSetText, %g_CommandArea%, %commandToShow%
    }
}

ClearInput:
    ControlSetText, %g_InputArea%,
return

RunCurrentCommand:
    if (GetInputState() == 1)
    {
        Send, {enter}
    }

    if (g_CurrentInput != "")
    {
        RunCommand(g_CurrentCommand)
    }
return

ParseArg:
    commandPrefix := SubStr(g_CurrentInput, 1, 1)

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
    else
    {
        Arg := g_CurrentInput
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

RunCommand(originCmd)
{
    GoSub, ParseArg

    g_UseDisplay := false
    g_DisableAutoExit := true

    splitedOriginCmd := StrSplit(originCmd, " | ")
    ; 去掉括号内的注释
    cmd := StrSplit(splitedOriginCmd[2], "（")[1]

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

        Run, %cmd%
    }
    else if (splitedOriginCmd[1] == "function")
    {
        if (splitedOriginCmd.Length() >= 3)
        {
            Arg := splitedOriginCmd[3]
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

    if (g_Conf.Config.SaveHistory && cmd != "DisplayHistoryCommands")
    {
        if (splitedOriginCmd.Length() == 2 && Arg != "")
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
        IncreaseRank(originCmd)
    }

    g_DisableAutoExit := false

    if (g_Conf.Config.RunOnce && !g_UseDisplay)
    {
        GoSub, EscFunction
    }
}

IncreaseRank(cmd, show = false, inc := 1)
{
    splitedCmd := StrSplit(cmd, " | ")

    if (splitedCmd.Length() >= 3 && splitedCmd[1] == "function")
    {
        ; 去掉参数
        cmd := splitedCmd[1]  " | " splitedCmd[2]
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

    if (cmdRank > 0 && cmd != "")
    {
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

RunSelectedCommand1:
    index := Asc(SubStr(A_ThisHotkey, 0, 1)) - g_FirstChar + 1

    RunCommand(g_CurrentCommandList[index])
return

RunSelectedCommand2:
    ControlGetFocus, ctrl,
    if (ctrl == g_InputArea)
    {
        return
    }

    index := Asc(A_ThisHotkey) - g_FirstChar + 1

    RunCommand(g_CurrentCommandList[index])
return

IncreaseRank:
    if (g_CurrentCommand != "")
    {
        IncreaseRank(g_CurrentCommand, true)
        LoadFiles()
    }
return

DecreaseRank:
    if (g_CurrentCommand != "")
    {
        IncreaseRank(g_CurrentCommand, true, -1)
        LoadFiles()
    }
return

LoadFiles()
{
    g_Commands := Object()
    g_FallbackCommands := Object()

    rankString := ""
    for command, rank in g_AutoConf.Rank
    {
        if (StrLen(command) > 0)
        {
            rankString .= rank "`t" command "`n"
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

            g_Commands.Push(StrSplit(A_loopField, "`t")[2])
        }
    }

    for key, value in g_Conf.Command
    {
        if (value != "")
        {
            g_Commands.Push(key . "（" . value "）")
        }
        else
        {
            g_Commands.Push(key)
        }
    }

    if (FileExist(A_ScriptDir "\UserFunctions.ahk"))
    {
        userFunctionLabel := "UserFunctions"
        if (IsLabel(userFunctionLabel))
        {
            GoSub, %userFunctionLabel%
        }
        else
        {
            MsgBox, 未在 %A_ScriptDir%\UserFunctions.ahk 中发现 %userFunctionLabel% 标签，请修改！
        }
    }

    GoSub, Functions

    Loop, Read, %g_SearchFileList%
    {
        g_Commands.Push(A_LoopReadLine)
    }

    if (g_Conf.Config.LoadControlPanelFunctions)
    {
        Loop, Read, %A_ScriptDir%\ControlPanelFunctions.txt
        {
            g_Commands.Push(A_LoopReadLine)
        }
    }
}

DisplayText(text)
{
    textToDisplay := StrReplace(text, "`n", "`r`n")
    ControlSetText, %g_OutputArea%, %textToDisplay%
}

DisplayResult(result)
{
    DisplayText(result)
    g_UseDisplay := true
}

LoadHistoryCommands()
{
    for key, value in g_AutoConf.History
    {
        if (StrLen(value) > 0)
        {
            g_HistoryCommands.Push(value)
        }
    }
}

DisplayHistoryCommands:
    result := ""
    g_CurrentCommandList := Object()
    g_CurrentLine := 1

    for index, element in g_HistoryCommands
    {
        if (index == 1)
        {
            result .= Chr(g_FirstChar + index - 1) . ">| " . element "`n"
            g_CurrentCommand := element
        }
        else
        {
            result .= Chr(g_FirstChar + index - 1) . " | " . element "`n"
        }

        g_CurrentCommandList.Push(element)
    }

    DisplayResult(result)
return

; AddFunction(label, info, fallback)
@(label, info, fallback = false)
{
    if (!IsLabel(label))
    {
        MsgBox, 未找到 %label% 标签，请检查 %A_ScriptDir%\UserFunctions.ahk 文件格式！
        return
    }

    g_Commands.Push("function | " . label . "（" . info . "）")
    if (fallback)
    {
        g_FallbackCommands.Push("function | " . label . "（" . info . "）")
    }
}

RunAndGetOutput(command)
{
    tempFileName := "RunZ.stdout.log"
    fullCommand = bash -c "%command% &> %tempFileName%"

    if (!FileExist("c:\msys64\usr\bin\bash.exe"))
    {
        fullCommand = %ComSpec% /C "%command% > %tempFileName%"
    }

    RunWait, %fullCommand%, %A_Temp%, Hide
    FileRead, result, %A_Temp%\%tempFileName%
    FileDelete, %A_Temp%\%tempFileName%
    return result
}

RunWithCmd(command)
{
    if (FileExist("c:\msys64\usr\bin\mintty.exe"))
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
            result .= element "`n"
        }
    }

    return result
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
    GoSub, ReloadFiles
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
        SetTimer, ToExit, 50
    }
}

ToExit:
    if (!WinExist("RunZ.ahk"))
    {
        GoSub, ExitRunZ
    }

    SetTimer, ToExit, Off
return

KeyHelpText()
{
    return ""
	. "键入内容 搜索，回车 执行，Alt + 字母 执行，Esc 退出`n"
    . "按 Tab 后再按 字母或数字 也可执行字母对应功能`n"
	. "按 Tab 后 Shift + 字母或数字 定位到对应功能`n"
	. "Ctrl + j 移动到下一条命令`n"
	. "Ctrl + k 移动到上一条命令`n"
	. "Ctrl + f 翻到下一页`n"
	. "Ctrl + b 翻到上一页`n"
	. "Win  + j 激活窗口`n"
	. "Ctrl + h 显示历史记录`n"
	. "Ctrl + n 可增加当前功能的权重`n"
	. "Ctrl + p 可减少当前功能的权重`n"
	. "Ctrl + l 清除编辑框内容`n"
	. "Ctrl + r 重新创建待搜索文件列表`n"
	. "Ctrl + d 用 TC 打开第一个文件所在目录`n"
	. "Ctrl + s 显示并复制当前文件的完整路径`n"
	. "Ctrl + x 删除当前文件`n"
	. "Ctrl + i 移动光标当行首`n"
	. "Ctrl + o 移动光标当行尾`n"
	. "F2       编辑配置文件`n`n"
}

UrlDownloadToString(url)
{
    static whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", url, true)
    whr.Send()
    whr.WaitForResponse()
    return whr.ResponseText
}

; 修改自万年书妖的 Candy 里的 SksSub_UrlEncode 函数，用于转换编码。感谢！
UrlEncode(url, enc = "UTF-8")
{
    enc := trim(enc)
    If enc=
        return url
    formatInteger := A_FormatInteger
    SetFormat, IntegerFast, H
    VarSetCapacity(buff, StrPut(url, enc))
    Loop % StrPut(url, &buff, enc) - 1
    {
        byte := NumGet(buff, A_Index-1, "UChar")
        encoded .= byte > 127 or byte <33 ? "%" Substr(byte, 3) : Chr(byte)
    }
    SetFormat, IntegerFast, %formatInteger%
    return encoded
}

; 0：英文 1：中文
GetInputState(WinTitle = "A")
{
    ControlGet, hwnd, HWND, , , %WinTitle%
    if (A_Cursor = "IBeam")
        return 1
    if (WinActive(WinTitle))
    {
        ptrSize := !A_PtrSize ? 4 : A_PtrSize
        VarSetCapacity(stGTI, cbSize := 4 + 4 + (PtrSize * 6) + 16, 0)
        NumPut(cbSize, stGTI, 0, "UInt")   ;   DWORD   cbSize;
        hwnd := DllCall("GetGUIThreadInfo", Uint, 0, Uint, &stGTI)
                         ? NumGet(stGTI, 8 + PtrSize, "UInt") : hwnd
    }
    return DllCall("SendMessage"
        , UInt, DllCall("imm32\ImmGetDefaultIMEWnd", Uint, hwnd)
        , UInt, 0x0283  ;Message : WM_IME_CONTROL
        , Int, 0x0005  ;wParam  : IMC_GETOPENSTATUS
        , Int, 0)      ;lParam  : 0
}


#include %A_ScriptDir%\Lib\EasyIni.ahk
#include %A_ScriptDir%\Lib\TCMatch.ahk
#include %A_ScriptDir%\Lib\Eval.ahk
#include %A_ScriptDir%\Lib\JSON.ahk
#include %A_ScriptDir%\Lib\Kanji\Kanji.ahk
#include %A_ScriptDir%\Functions.ahk
; 用户自定义命令
#include *i %A_ScriptDir%\UserFunctions.ahk
