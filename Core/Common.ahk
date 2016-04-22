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

SwitchIME(dwLayout)
{
    HKL := DllCall("LoadKeyboardLayout", Str, dwLayout, UInt, 1)
    ControlGetFocus, ctl, A
    SendMessage, 0x50, 0, HKL, %ctl%, A
}

SwitchToEngIME()
{
    ; 下方代码可只保留一个
    SwitchIME(0x04090409) ; 英语(美国) 美式键盘
    SwitchIME(0x08040804) ; 中文(中国) 简体中文-美式键盘
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

; 根据字节取子字符串，如果多删了一个字节，补一个空格
SubStrByByte(text, length)
{
    textForCalc := RegExReplace(text, "[^\x00-\xff]", "`t`t")
    textLength := 0
    realRealLength := 0

    Loop, Parse, textForCalc
    {
        if (A_LoopField != "`t")
        {
            textLength++
            textRealLength++
        }
        else
        {
            textLength += 0.5
            textRealLength++
        }

        if (textRealLength >= length)
        {
            break
        }
    }

    result := SubStr(text, 1, round(textLength - 0.5))

    ; 删掉一个汉字，补一个空格
    if (round(textLength - 0.5) != round(textLength))
        result .= " "

    return result
}

; 修改自万年书妖的 Candy 里的 SksSub_UrlEncode 函数，用于转换编码。感谢！
UrlEncode(url, enc = "UTF-8")
{
    enc := Trim(enc)
    If enc=
        return url
    formatInteger := A_FormatInteger
    SetFormat, IntegerFast, H
    VarSetCapacity(buff, StrPut(url, enc))
    Loop % StrPut(url, &buff, enc) - 1
    {
        byte := NumGet(buff, A_Index-1, "UChar")
        encoded .= byte > 127 or byte < 33 ? "%" SubStr(byte, 3) : Chr(byte)
    }
    SetFormat, IntegerFast, %formatInteger%
    return encoded
}

UrlDownloadToString(url, headers := "")
{
    static whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", url, true)

    if (headers != "")
    {
        for key, value in headers
        {
            whr.SetRequestHeader(key, value)
        }
    }

    whr.Send()
    whr.WaitForResponse()
    return whr.ResponseText
}
