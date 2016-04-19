global Arg

Functions:
    @("Help", "帮助信息")
    @("KeyHelp", "置顶的按键帮助信息")
    @("AhkRun", "使用 Ahk 的 Run() 运行 `; command", true)
    @("CmdRun", "使用 cmd 运行 : command", true)
    @("CmdRunOnly", "只使用 cmd 运行，忽略 mintty")
    @("WinRRun", "使用 win + r 运行", true)
    @("Dictionary", "有道词典在线翻译", true)
    @("RunAndDisplay", "使用 cmd 运行，并显示结果", true)
    @("ReloadFiles", "重新加载需要搜索的文件")
    @("Clip", "显示剪切板内容")
    @("Calc", "计算器")
    @("SearchOnBaidu", "使用 Baidu（百度）搜索剪切板或输入内容", true)
    @("SearchOnGoogle", "使用 Google（谷歌）搜索剪切板或输入内容", true)
    @("SearchOnBing", "使用 Bing（必应）搜索剪切板或输入内容", true)
    @("SearchOnTaobao", "使用 Taobao（淘宝）搜索剪切板或输入内容")
    @("SearchOnJingdong", "使用 JD（京东）搜索剪切板或输入内容")
    @("EditConfig", "编辑配置文件")
    @("ClearClipboardFormat", "清除剪切板中文字的格式")
    @("RunClipboard", "使用 ahk 的 Run 运行剪切板内容")
    @("EmptyRecycle", "清空回收站")
    @("Logoff", "注销 登出")
    @("RestartMachine", "重启")
    @("ShutdownMachine", "关机")
    @("SuspendMachine", "挂起 睡眠 待机")
    @("HibernateMachine", "休眠")
    @("TurnMonitorOff", "关闭显示器")
    @("T2S", "将剪切板或输入内容中的繁体转成简体")
    @("S2T", "将剪切板或输入内容中的简体转成繁体")
    @("ShowIp", "显示 IP")
    @("Calendar", "用浏览器打开万年历")
    @("CleanupRank", "清理命令权重中的无效命令")
    @("ArgTest", "参数测试：ArgTest arg1,arg2,...")

    if (IsLabel("ReservedFunctions"))
    {
        GoSub, ReservedFunctions
    }
return

Help:
    DisplayResult(KeyHelpText() . GetAllFunctions())
return

KeyHelp:
    ToolTip, % KeyHelpText()
return

CmdRun:
    RunWithCmd(Arg)
return

CmdRunOnly:
    RunWithCmd(Arg, true)
return

AhkRun:
    Run, %Arg%
return

Clip:
    DisplayResult("剪切板内容长度 " . StrLen(clipboard) . " ：`n`n" . clipboard)
return

EditConfig:
    Run, % g_ConfFile
return

ArgTest:
    Args := StrSplit(Arg, ",")
    result := "共有 " . Args.Length() . " 个参数。`n`n"

    for index, argument in Args
    {
        result .= "第 " . index . " 个参数：" . argument . "`n"
    }

    DisplayResult(result)
return

ShowIp:
    DisplayResult(A_IPAddress1
            . "`r`n" . A_IPAddress2
            . "`r`n" . A_IPAddress3
            . "`r`n" . A_IPAddress4)
return

Dictionary:
    word := Arg == "" ? clipboard : Arg

    url := "http://fanyi.youdao.com/openapi.do?keyfrom=YouDaoCV&key=659600698&"
            . "type=data&doctype=json&version=1.2&q=" UrlEncode(word)

    jsonText := StrReplace(UrlDownloadToString(url), "-phonetic", "_phonetic")

    if (jsonText == "no query")
    {
        DisplayResult("未查到结果")
        return
    }

    parsed := JSON.Load(jsonText)
	result := parsed.query

	if (parsed.basic.uk_phonetic != "" && parsed.basic.us_phonetic != "")
	{
		result .= " UK: [" parsed.basic.uk_phonetic "], US: [" parsed.basic.us_phonetic "]`n"
	}
	else if (parsed.basic.phonetic != "")
	{
		result .= " [" parsed.basic.phonetic "]`n"
	}
    else
    {
        result .= "`n"
    }

	if (parsed.basic.explains.Length() > 0)
	{
		result .= "`n"
		for index, explain in parsed.basic.explains
		{
			result .= "    * " explain "`n"
		}
	}

	if (parsed.web.Length() > 0)
	{
		result .= "`n----`n"

		for i, element in parsed.web
		{
			result .= "`n    * " element.key
			for j, value in element.value
			{
				if (j == 1)
				{
					result .= "`n       "
				}
				else
				{
					result .= "`; "
				}

				result .= value
			}
		}
	}

    DisplayResult(result)
    clipboard := result
return

Calendar:
    Run % "http://www.baidu.com/baidu?wd=%CD%F2%C4%EA%C0%FA"
return

T2S:
    text := Arg == "" ? clipboard : Arg
    clipboard := ""
    clipboard := Kanji_t2s(text)
    ClipWait
    DisplayResult(clipboard)
return

S2T:
    text := Arg == "" ? clipboard : Arg
    clipboard := ""
    clipboard := Kanji_s2t(text)
    ClipWait
    DisplayResult(clipboard)
return

ClearClipboardFormat:
    clipboard := clipboard
return

SearchOnBaidu:
    word := Arg == "" ? clipboard : Arg

    Run, https://www.baidu.com/s?wd=%word%
return

SearchOnGoogle:
    word := UrlEncode(Arg == "" ? clipboard : Arg)

    Run, https://www.google.com.hk/#newwindow=1&safe=strict&q=%word%
return

SearchOnBing:
    word := Arg == "" ? clipboard : Arg

    Run, http://cn.bing.com/search?q=%word%
return

SearchOnTaobao:
    word := Arg == "" ? clipboard : Arg

    Run, https://s.taobao.com/search?q=%word%
return

SearchOnJingdong:
    word := Arg == "" ? clipboard : Arg

    Run, http://search.jd.com/Search?keyword=%word%&enc=utf-8
return

RunClipboard:
    Run, %clipboard%
return

Calc:
    result := Eval(Arg)
    DisplayResult(result)
    clipboard := result
return

RunAndDisplay:
    DisplayResult(RunAndGetOutput(Arg))
return

WinRRun:
    Send, #r
    Sleep, 100
    Send, %Arg%
    Send, {enter}
return

Logoff:
    Shutdown, 0
return

ShutdownMachine:
    Shutdown, 1
return

RestartMachine:
    Shutdown, 2
return

HibernateMachine:
    ; 参数 #1: 使用 1 代替 0 来进行休眠而不是挂起。
	; 参数 #2: 使用 1 代替 0 来立即挂起而不询问每个应用程序以获得许可。
	; 参数 #3: 使用 1 而不是 0 来禁止所有的唤醒事件。
    DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
return

SuspendMachine:
    DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
return

TurnMonitorOff:
	; 关闭显示器:
	SendMessage, 0x112, 0xF170, 2,, Program Manager
	; 0x112 is WM_SYSCOMMAND, 0xF170 is SC_MONITORPOWER.
	; 对上面命令的注释: 使用 -1 代替 2 来打开显示器.
	; 使用 1 代替 2 来激活显示器的节能模式.
return

EmptyRecycle:
    FileRecycleEmpty,
return
