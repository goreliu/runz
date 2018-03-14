global g_TCMatchModule

TCMatchOn(dllPath = "")
{
    static TCMatchDllPath
    if (g_TCMatchModule != "")
    {
        return g_TCMatchModule
    }

    if (dllPath == "" && TCMatchDllPath == "")
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
            TCMatchDllPath := dllPath
        }
    }

    g_TCMatchModule := DllCall("LoadLibrary", "Str", TCMatchDllPath, "Ptr")
    return g_TCMatchModule
}

TCMatchOff()
{
    DllCall("FreeLibrary", "Ptr", g_TCMatchModule)
    g_TCMatchModule := ""
}

TCMatch(aHaystack, aNeedle)
{
    if (A_PtrSize == 8)
    {
        return DllCall("TCMatch64\MatchFileW", "WStr", aNeedle, "WStr", aHaystack)
    }

    return DllCall("TCMatch\MatchFileW", "WStr", aNeedle, "WStr", aHaystack)
}
