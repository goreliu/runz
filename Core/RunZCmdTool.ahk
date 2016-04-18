#NoEnv
#NoTrayIcon
SendMode Input
SetWorkingDir %A_ScriptDir%

; 如果该文件报错，说明 UserFunctionsAuto.txt 文件里有重复标签，需要手动修改或删除

global g_UserFunctionsAutoFileName := A_ScriptDir "\..\Conf\UserFunctionsAuto.txt"
global g_FileContent

if (!FileExist(g_UserFunctionsAutoFileName))
{
    FileCopy, %g_UserFunctionsAutoFileName%.template, %g_UserFunctionsAutoFileName%
}

FileRead, g_FileContent, %g_UserFunctionsAutoFileName%

allLabels := Object()
index := 1

Loop, %0%
{
    SplitPath, %A_Index%, fileName, fileDir, fileExt, fileNameNoExt

    if (fileNameNoExt == "")
    {
        continue
    }

    labelName := SafeLabel(fileNameNoExt)
    fileDir := SafeFilename(fileDir)
    fileExt := SafeFilename(fileExt)
    fileName := SafeFilename(fileName)

    uniqueLabelName := labelName

    ; 如果和已有标签重名，添加时间
    if (IsLabel(uniqueLabelName) || allLabels.HasKey(uniqueLabelName))
    {
        uniqueLabelName .= "_" A_Now "_" index
        index++
    }

    AddFile(uniqueLabelName, labelName, fileDir . "\" . fileName, fileDir)
    allLabels[uniqueLabelName] := true
}

FileMove, %g_UserFunctionsAutoFileName%, %g_UserFunctionsAutoFileName%.bak, 1
FileAppend, %g_FileContent%, %g_UserFunctionsAutoFileName%, utf-8

; 打开文件来编辑
Run, %g_UserFunctionsAutoFileName%

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
    StringReplace, label, label, ", ``", All
    StringReplace, label, label, ``, ````, All
    StringReplace, label, label, `%, ```%, All
    StringReplace, label, label, `,, ```,, All
    return label
}

; 伪 @ 函数，用于避免运行出错
@(a = "", b = "", c = "", d = "", e = "", f = "")
{
}

; 用于判断是否有重复标签
#include *i %A_ScriptDir%\..\Conf\UserFunctionsAuto.txt
