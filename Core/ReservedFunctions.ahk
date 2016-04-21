global Arg

; 这里可能会调用一些不包含在源码包里的第三方库
ReservedFunctions:
    if (!FileExist(A_ScriptDir "\Lib\Reserved"))
    {
        return
    }

    @("GenerateQR", "生成二维码")
return

; GenerateQR begin

GenerateQR:
    word := Arg == "" ? clipboard : Arg
    QRfile := GenerateQR(SubStr(word, 1, 1000))

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

    DllCall(A_ScriptDir "\Lib\Reserved\quricol32.dll\GeneratePNG"
        , "str", file, "str", string, "int", 4, "int", 6, "int", 0)
    return file
}

; GenerateQR end
