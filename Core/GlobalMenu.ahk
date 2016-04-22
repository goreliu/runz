global g_GlobalMenuItems := ""

GlobalMenu:
    AddToGlobalMenu("查看剪切板内容", "Clip")
    ; AddToGlobalMenu("发送文件到记事本", "OpenWithNotepad", "Notepad++")

    WinGetClass, lastWindowClass, A

    for index, element in g_GlobalMenuItems
    {
        if (element[3] == "" || lastWindowClass == element[3])
        {
            Menu, GlobalMenu, Add, % element[1], % element[2]
        }
    }

    Menu, GlobalMenu, Show
    Menu, GlobalMenu, DeleteAll
return

AddToGlobalMenu(name, label, winClass := "")
{
    if (g_GlobalMenuItems == "")
    {
        g_GlobalMenuItems := Object()
    }

    g_GlobalMenuItems.Push([name, label, winClass])
}

OpenWithNotepad:
    WinGetTitle, title, A
    StringReplace, title, title, - Notepad++, , All

    Run, notepad "%title%"
return
