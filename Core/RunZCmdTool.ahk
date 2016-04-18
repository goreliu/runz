#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#NoTrayIcon
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

global g_UserFunctionsAutoFileName := A_ScriptDir "\..\Conf\UserFunctionsAuto.txt"
global g_FileContent

if (!FileExist(g_UserFunctionsAutoFileName))
{
    FileCopy, %g_UserFunctionsAutoFileName%.template, %g_UserFunctionsAutoFileName%
}

FileRead, g_FileContent, %g_UserFunctionsAutoFileName%

Loop, %0%
{
    SplitPath, %A_Index%, fileName, fileDir, fileExt, fileNameNoExt

    AddFile(fileNameNoExt, fileNameNoExt, fileDir "\" fileName)
}

FileMove, %g_UserFunctionsAutoFileName%, %g_UserFunctionsAutoFileName%.bak, 1
FileAppend, %g_FileContent%, %g_UserFunctionsAutoFileName%, utf-8

; 打开文件来编辑
Run, %g_UserFunctionsAutoFileName%

return

; 添加一个需要运行的文件
AddFile(name, comment, path)
{
    addFunctionsText = @("%name%", "%comment%")
    addLabelsText = %name%:`r`n    `; 用法：  Run, "文件名" "参数..", 工作目录, Max|Min|Hide`r`n
    addLabelsText = %addLabelsText%    Run, "%path%"`r`nreturn`r`n

    g_FileContent := StrReplace(g_FileContent
        , "    `; -*-*-*-*-*-", "    `; -*-*-*-*-*-`r`n    " addFunctionsText)
    g_FileContent := StrReplace(g_FileContent
        , "`r`n`; -*-*-*-*-*-", "`r`n`; -*-*-*-*-*-`r`n" addLabelsText)
}
