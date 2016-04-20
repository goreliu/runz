GetProcessList()
{
    result := ""
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
        result .= "* | 进程 | " process.Name " | " process.CommandLine "`n"
    Sort, result
    return AlignText(result)
}
