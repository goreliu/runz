; http://ahk8.com/archive/index.php/thread-1927.html
UnicodeDecode(text)
{
    return text
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
