# MSDF 文字缩放

使用 Godot 4.8.dev6 自带 TextServerAdvanced（advanced），不增加渲染库。两份现有字体导入启用 MSDF，范围 8、尺寸 48，并禁用嵌入位图；默认字体也启用 MSDF。TextNode 的共享字体副本启用相同参数，显示标签和编辑框使用同一个字体，连线标题继承源节点字体。

相关检查：pingfang_font_smoke 加入画布、UI 的 MSDF 与 Advanced 服务断言。修改前两项 MSDF 断言失败，修改后退出码 0、PINGFANG_FONT: PASS。无界面输入测试仍产生已有的 IME 不受支持日志，不能据此声称实际输入法已验证。

复用评估：Godot 原生 FontFile、FontVariation、字体导入器和 TextServerAdvanced 已满足需求；无需新增通用文字渲染实现或依赖。MSDF 是引擎缩放文字时使用的字形距离场，不会改善外部截图放大的清晰度。中文首次生成字形仍可能产生额外成本，实际大文档性能尚未验收。

所有 Godot 文件修改、字体重导入、测试和导出均通过 Godot MCP 的编辑器脚本或脚本工具；未直接处理场景文本。构建、安装结果以当次交付说明为准。

手动验证（尚未执行）：退出旧实例，从应用菜单打开新版，在节点输入“文字缩放清晰 Test01”，分别缩放到 100%、200%、400%，再双击编辑并给连线添加文字。放大时字缘应保持清晰，进入编辑后字形和起点应一致。缩回 50% 并切换深浅主题，应没有字形缺失。失败重点检查是否仍运行旧版本、字体是否成功重导入、局部字体覆盖是否关闭 MSDF；同时观察中文大文档首次打开是否卡顿。

参考：[Godot FontFile](https://docs.godotengine.org/en/stable/classes/class_fontfile.html)、[ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)。

## 模拟加粗导致字形孔洞

用户提供的 Waya 截图已通过原生 Label 渲染复现：同一苹方字体的 MSDF 配合 `FontVariation.variation_embolden=0.45` 时，W 和“体”的笔画出现孔洞；不加粗的 MSDF 字形正常。移除这层模拟加粗，保留字体家族、Advanced 服务、MSDF 和编辑框共享字体。字重恢复字体原始 Regular，比之前略细。

新增 `msdf_glyph_integrity_smoke.gd`，通过 SubViewport 与 Label 实际渲染共享画布字体，检查没有闭合字腔的 W。使用 Xvfb、Compatibility 与 Mesa llvmpipe；修改前在 100%、200%、400% 分别发现 30、115、470 个孔洞背景像素，修改后均为 0，且有足够的前景像素，防止未渲染的空图误判通过。`pingfang_font_smoke` 同样在 Xvfb 下通过，日志没有脚本或 IME 错误。没有启动 Godot Editor 或操作真实桌面窗口。

检查命令（通过 Godot MCP 执行，需符合仓库授权规则）：

```sh
xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tests/msdf_glyph_integrity_smoke.gd
```

手动验收仍未执行：退出旧实例后重开，在节点和连线标题输入“Waya! 字体”，放大到 200%、400%，切换深浅背景并进入编辑。W 的三个尖角及“体”的笔画交接应完整，没有背景色孔洞，文字仍使用 MSDF。失败重点检查旧实例或旧系统安装、局部模拟加粗是否仍开启，以及实际 GPU 后端差异。
