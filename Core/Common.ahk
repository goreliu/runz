; http://ahk8.com/archive/index.php/thread-1927.html
UnicodeDecode(text)
{
    while pos := RegExMatch(text, "\\u\w{4}")
    {
        tmp := UrlEncodeEscape(SubStr(text, pos + 2, 4))
        text := RegExReplace(text, "\\u\w{4}", tmp, "", 1)
    }
    return text
}

; http://ahk8.com/archive/index.php/thread-1927.html
UrlEncodeEscape(text)
{
    text := "0x" . text
    VarSetCapacity(LE, 2, "UShort")
    NumPut(text, LE)
    return StrGet(&LE, 2)
}

; https://autohotkey.com/board/topic/113942-solved-get-cpu-usage-in/
CPULoad()
{
    static PIT, PKT, PUT
    if (Pit = "")
    {
        return 0, DllCall("GetSystemTimes", "Int64P", PIT, "Int64P", PKT, "Int64P", PUT)
    }
    DllCall("GetSystemTimes", "Int64P", CIT, "Int64P", CKT, "Int64P", CUT)
    IdleTime := PIT - CIT, KernelTime := PKT - CKT, UserTime := PUT - CUT
    SystemTime := KernelTime + UserTime
    return ((SystemTime - IdleTime) * 100) // SystemTime, PIT := CIT, PKT := CKT, PUT := CUT
}

; https://autohotkey.com/board/topic/113942-solved-get-cpu-usage-in/
GlobalMemoryStatusEx()
{
    static MEMORYSTATUSEX, init := VarSetCapacity(MEMORYSTATUSEX, 64, 0) && NumPut(64, MEMORYSTATUSEX, "UInt")
    if (DllCall("Kernel32.dll\GlobalMemoryStatusEx", "Ptr", &MEMORYSTATUSEX))
    {
        return { 2 : NumGet(MEMORYSTATUSEX,  8, "UInt64")
               , 3 : NumGet(MEMORYSTATUSEX, 16, "UInt64")
               , 4 : NumGet(MEMORYSTATUSEX, 24, "UInt64")
               , 5 : NumGet(MEMORYSTATUSEX, 32, "UInt64") }
    }
}

; https://autohotkey.com/board/topic/113942-solved-get-cpu-usage-in/
GetProcessCount()
{
    proc := ""
    for process in ComObjGet("winmgmts:\\.\root\CIMV2").ExecQuery("SELECT * FROM Win32_Process")
    {
        proc++
    }
    return proc
}
