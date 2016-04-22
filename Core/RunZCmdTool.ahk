#NoEnv
#NoTrayIcon
SendMode Input
SetWorkingDir %A_ScriptDir%

FileEncoding, utf-8

; 如果该文件报错，说明 UserFunctionsAuto.txt 文件里有重复标签，需要手动修改或删除

global g_ConfFile := A_ScriptDir . "\..\Conf\RunZ.ini"
global g_Conf := class_EasyINI(g_ConfFile)
global g_UserFunctionsAutoFileName := A_ScriptDir "\..\Conf\UserFunctionsAuto.txt"
global g_UserFileList := A_ScriptDir "\..\Conf\UserFileList.txt"
global g_FileContent

allLabels := Object()
index := 1

Loop, %0%
{
    inputFileName := %A_Index%
    SplitPath, inputFileName, fileName, fileDir, fileExt, fileNameNoExt

    if (fileNameNoExt == "")
    {
        continue
    }

    if (fileExt == "ahk")
    {
        FileReadLine, firstLine, %inputFileName%, 1
        if (InStr(firstLine, " RunZ:"))
        {
            pluginName := StrSplit(firstLine, "; RunZ:")[2]
            if (FileExist(A_ScriptDir "\..\Plugins\" pluginName ".ahk"))
            {
                ToolTip, %pluginName% 插件已存在
                sleep 1500
                ExitApp
            }
            FileMove, %inputFileName%, %A_ScriptDir%\..\Plugins\%pluginName%.ahk
            FileAppend, #include *i `%A_ScriptDir`%\Plugins\%pluginName%.ahk`n
                , %A_ScriptDir%\..\Core\Plugins.ahk
            ToolTip, %pluginName% 插件安装成功，请手动重启 RunZ 以生效
            sleep 1500
            ExitApp
        }
    }

    labelName := SafeLabel(fileNameNoExt)
    fileExt := SafeFilename(fileExt)
    fileDir := SafeFilename(fileDir)
    fileName := SafeFilename(fileName)
    filePath := fileDir "\" fileName
    fileDesc := ""

    if (fileExt == "lnk" && g_Conf.Config.SendToMenuReadLnkFile)
    {
        FileGetShortcut, %filePath%, filePath, fileDir, targetArg, fileDesc

        if (fileDesc = filePath)
        {
            fileDesc := ""
        }

        filePath .= " " targetArg

        if (!g_Conf.Config.SendToMenuSimpleMode)
        {
            filePath := SafeFilename(filePath)
        }
    }

    if (g_Conf.Config.SendToMenuSimpleMode)
    {
        FileAppend, file | %filePath% | %fileDesc%`r`n, %g_UserFileList%

        continue
    }

    if (!FileExist(g_UserFunctionsAutoFileName))
    {
        FileCopy, %g_UserFunctionsAutoFileName%.template, %g_UserFunctionsAutoFileName%
    }

    FileRead, g_FileContent, %g_UserFunctionsAutoFileName%


    uniqueLabelName := labelName

    ; 如果和已有标签重名，添加时间
    if (IsLabel(uniqueLabelName) || allLabels.HasKey(uniqueLabelName))
    {
        uniqueLabelName .= "_" A_Now "_" index
        index++
    }

    AddFile(uniqueLabelName, labelName, filePath, fileDir)
    allLabels[uniqueLabelName] := true
}

if (g_Conf.Config.SendToMenuSimpleMode)
{
    ToolTip, 文件添加完毕，3 秒内生效
    sleep 1500
    ExitApp
}

FileMove, %g_UserFunctionsAutoFileName%, %g_UserFunctionsAutoFileName%.bak, 1
FileAppend, %g_FileContent%, %g_UserFunctionsAutoFileName%, utf-8

; 打开文件来编辑
if (g_Conf.Config.Editor != "")
{
    Run, % g_Conf.Config.Editor " """ g_UserFunctionsAutoFileName """"
}
else
{
    Run, %g_UserFunctionsAutoFileName%
}


return

; 添加一个需要运行的文件
AddFile(name, comment, path, dir)
{
    addFunctionsText = @("%name%", "%comment%")
    addLabelsText = %name%:`r`n    `; 用法：  Run, "文件名" "参数..", 工作目录, Max|Min|Hide`r`n
    addLabelsText = %addLabelsText%    Run, "%path%", "%dir%"`r`nreturn`r`n

    g_FileContent := StrReplace(g_FileContent
        , "    `; -*-*-*-*-*-", "    `; -*-*-*-*-*-`r`n    " addFunctionsText)
    g_FileContent := StrReplace(g_FileContent
        , "`r`n`; -*-*-*-*-*-", "`r`n`; -*-*-*-*-*-`r`n" addLabelsText)
}

SafeLabel(label)
{
    StringReplace, label, label, ", _, All
    return RegExReplace(label, "[ `%```t',]", "_")
}

SafeFilename(label)
{
    StringReplace, label, label, ", `"`", All
    StringReplace, label, label, ``, ````, All
    StringReplace, label, label, `%, ```%, All
    StringReplace, label, label, `,, ```,, All
    return label
}

; 伪 @ 函数，用于避免运行出错
@(a = "", b = "", c = "", d = "", e = "", f = "")
{
}

#include %A_ScriptDir%\..\Lib\EasyIni.ahk
; 用于判断是否有重复标签
#include *i %A_ScriptDir%\..\Conf\UserFunctionsAuto.txt
