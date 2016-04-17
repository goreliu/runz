global g_TCMatchDllPath
global g_TCMatchModule

TCMatchOn(dllPath = "")
{
    if (g_TCMatchModule != "")
    {
        return g_TCMatchModule
    }

    if (dllPath == "" && g_TCMatchDllPath == "")
    {
        return 0
    }
    else if (dllPath != "")
    {
        if (!FileExist(dllPath))
        {
            return 0
        }
        else
        {
            g_TCMatchDllPath := dllPath
        }
    }

    if (!g_ReloadTCMatchInternal > 0)
    {
        g_ReloadTCMatchInternal := 1000
    }

    g_TCMatchModule := DllCall("LoadLibrary", "Str", g_TCMatchDllPath, "Ptr")
    return g_TCMatchModule
}

TCMatchOff()
{
    DllCall("FreeLibrary", "Ptr", g_TCMatchModule)
    g_TCMatchModule := ""
}

TCMatch(aHaystack, aNeedle)
{
    ; 这个函数有内存泄漏...
    static matchTimes := 0
    matchTimes++
    if (matchTimes > g_ReloadTCMatchInternal)
    {
        TCMatchOff()
        TCMatchOn()
        matchTimes := 0
    }

    return DllCall("TCMatch\MatchFileW", "WStr", aNeedle, "WStr", aHaystack)
}
