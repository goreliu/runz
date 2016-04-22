; RunZ:Misc
; 实用工具

Misc:
    @("Dictionary", "有道词典在线翻译", true)
    @("Calc", "计算器")
    @("SearchOnBaidu", "使用 Baidu（百度）搜索剪切板或输入内容", true)
    @("SearchOnGoogle", "使用 Google（谷歌）搜索剪切板或输入内容", true)
    @("SearchOnBing", "使用 Bing（必应）搜索剪切板或输入内容", true)
    @("SearchOnTaobao", "使用 Taobao（淘宝）搜索剪切板或输入内容")
    @("SearchOnJingdong", "使用 JD（京东）搜索剪切板或输入内容")
    @("ShowIp", "显示 IP")
    @("Calendar", "用浏览器打开万年历")
    @("CurrencyRate", "汇率 使用示例： hl JPY EUR 2")
    @("CNY2USD", "汇率 人民币兑换美元")
    @("USD2CNY", "汇率 美元兑换人民币")
    @("UrlEncode", "URL 编码")
return

CNY2USD:
    DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
    DisplayResult(QueryCurrencyRate("CNY", "USD", Arg))
return

USD2CNY:
    DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
    DisplayResult(QueryCurrencyRate("USD", "CNY", Arg))
return

CurrencyRate:
    args := StrSplit(Arg, " ")
    if (args.Length() != 3)
    {
        DisplayResult("使用示例：`n    CurrencyRate USD CNY 2")
        return
    }

    DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
    DisplayResult(QueryCurrencyRate(args[1], args[2], args[3]))
return

QueryCurrencyRate(fromCurrency, toCurrency, amount)
{
    headers := Object()
    headers["apikey"] := "c9098c96599be340bbd9551e2b061f63"

    jsonText := UrlDownloadToString("http://apis.baidu.com/apistore/currencyservice/currency?"
        . "fromCurrency=" fromCurrency "&toCurrency=" toCurrency "&amount=" amount, headers)
    parsed := JSON.Load(jsonText)

    if (parsed.errNum != 0 && parsed.errMsg != "success")
    {
        return "查询失败，错误信息：`n`n" jsonText
    }

    result := fromCurrency " 兑换 " toCurrency " 当前汇率：`n`n" parsed.retData.currency "`n`n`n"
    result .= amount " " fromCurrency " = " parsed.retData.convertedamount " " toCurrency "`n"

    return result
}

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

Calc:
    result := Eval(Arg)
    DisplayResult(result)
    clipboard := result
    TurnOnRealtimeExec()
return

UrlEncode:
    text := Arg == "" ? clipboard : Arg
    clipboard := UrlEncode(text)
    DisplayResult(clipboard)
return


#include %A_ScriptDir%\Lib\Eval.ahk
#include %A_ScriptDir%\Lib\JSON.ahk
