; RunZ:QRCode
; 生成二维码

QRCode:
    if (!FileExist(A_ScriptDir "\Lib\Reserved\quricol" A_PtrSize * 8 ".dll"))
    {
        return
    }

    @("GenerateQR", "生成二维码")
return

GenerateQR:
    word := Arg == "" ? clipboard : Arg
    if (word == "")
    {
        DisplayResult(AlignText("* | 错误 | 剪切板内无文本数据"))
        return
    }

    DisplayResult(AlignText("* | 内容 | 二维码内容长度 | " StrLen(word) "`n"
        . "* | 内容 | 二维码内容 | 见下方`n`n" word))

    QRfile := GenerateQR(SubStr(word, 1, 1000))

    /*
    少占用 300 - 400 K 内存，先不引入 Gdip.ahk
    GdipToken := Gdip_Startup()

    bitmap := Gdip_CreateBitmapFromFile(QRfile)
    imageWidth := Gdip_GetImageWidth(bitmap)
    Gdip_DisposeImage(bitmap)
    Gdip_Shutdown(GdipToken)

    windowWidth := imageWidth

    if (windowWidth >= 300)
    {
        windowWidth := 300
    }
    */

    windowWidth := 300

    Gui, QR:Destroy
    Gui, QR:Add, Picture, x0 y0 w%windowWidth% h-1 gQRSaveAs, % file := QRfile
    Gui, QR:Show, % "w" windowWidth " h" windowWidth
return

QRSaveAs:
    Fileselectfile, selectedFile, s16, 二维码.png, 另存为, PNG图片(*.png)
    if (selectedFile == "")
    {
        return
    }

    if (!RegExMatch(selectedFile,"i)\.png"))
    {
        selectedFile .= ".png"
    }

    FileMove, %file%, %selectedFile%, 1
    GUI, QR:Destroy
return

QrGuiEscape:
QrGuiClose:
    FileDelete, %file%
    GUI, QR:Destroy
return

GenerateQR(string, file = "")
{
    if (file == "")
    {
        file := A_Temp "\RunZ.QR.png"
    }

    hModule := DllCall(A_ScriptDir "\Lib\Reserved\quricol" A_PtrSize * 8 ".dll\GeneratePNG"
        , "str", file, "str", string, "int", 4, "int", 12, "int", 0)
    DllCall("FreeLibrary", "Ptr", hModule)
    return file
}

;#include %A_ScriptDir%\Lib\Gdip.ahk
