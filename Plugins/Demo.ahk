; RunZ:Demo
; 插件示例
;
; 第一行为固定格式 ; RunZ:插件名
; 插件名需要和文件名一致
; 第二行为固定格式 ; 插件描述
; 插件需要使用 UTF-8 BOM 编码
;
; 该插件默认不启用，在配置文件可启用该插件

; 该标签名要和首行的插件名一致
Demo:
    ; 第一个参数为标签名
    ; 第二个为搜索项，即该功能的表述，内容随意
    ; 第三个参数为 true 时，当搜索无结果也会显示，默认为 false
    ; 第四个参数为绑定的全局热键，默认无
    @("Demo1", "插件实例1")
    @("Demo2", "插件实例2")
    @("Demo3", "插件实例3")
return


; 和 @ 函数的第一个参数对应
Demo1:
    ; 在指定目录启动软件
    Run, notepad, c:
return

Demo2:
    ; DisplayResult(text) 内置函数用来在列表框展示文本
    DisplayResult("我是插件")
return

Demo3:
    ; Arg 为用户输入的参数
    DisplayResult("我的参数：" Arg)
return
