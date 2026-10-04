# MSDF 文字缩放

使用 Godot 4.8.dev6 自带 TextServerAdvanced（advanced），不增加渲染库。两份现有字体导入启用 MSDF，范围 8、尺寸 48，并禁用嵌入位图；默认字体也启用 MSDF。TextNode 的共享字体副本启用相同参数，显示标签和编辑框使用同一个字体，连线标题继承源节点字体。

相关检查：pingfang_font_smoke 加入画布、UI 的 MSDF 与 Advanced 服务断言。修改前两项 MSDF 断言失败，修改后退出码 0、PINGFANG_FONT: PASS。无界面输入测试仍产生已有的 IME 不受支持日志，不能据此声称实际输入法已验证。

复用评估：Godot 原生 FontFile、FontVariation、字体导入器和 TextServerAdvanced 已满足需求；无需新增通用文字渲染实现或依赖。MSDF 是引擎缩放文字时使用的字形距离场，不会改善外部截图放大的清晰度。中文首次生成字形仍可能产生额外成本，实际大文档性能尚未验收。

所有 Godot 文件修改、字体重导入、测试和导出均通过 Godot MCP 的编辑器脚本或脚本工具；未直接处理场景文本。构建、安装结果以当次交付说明为准。

手动验证（尚未执行）：退出旧实例，从应用菜单打开新版，在节点输入“文字缩放清晰 Test01”，分别缩放到 100%、200%、400%，再双击编辑并给连线添加文字。放大时字缘应保持清晰，进入编辑后字形和起点应一致。缩回 50% 并切换深浅主题，应没有字形缺失。失败重点检查是否仍运行旧版本、字体是否成功重导入、局部字体覆盖是否关闭 MSDF；同时观察中文大文档首次打开是否卡顿。

参考：[Godot FontFile](https://docs.godotengine.org/en/stable/classes/class_fontfile.html)、[ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)。
