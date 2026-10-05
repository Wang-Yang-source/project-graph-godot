# 关闭确认弹窗统一与本机安装

2026-10-05；用户授权统一样式、运行验证并替换电脑上的安装版本。

## 实际改动

复用已有 Godot Theme、ConfirmationDialog、ColorRect 与 Catppuccin Palette，不新增依赖。弹窗使用不透明 Base（Mocha #1e1e2e / Latte #eff1f5），Surface1 边框；普通按钮用 Surface0，保存按钮保留 Mauve。按钮与输入控件使用 8 像素圆角，弹窗保留 12 像素圆角；确认按钮最小 96×40，间距 12，内容边距 24。

启动必需的确认窗口也调用已有 DialogTheme.apply_controls。一个共享的原生 ColorRect 在独占 AcceptDialog 显示时遮罩画布，关闭或取消时移除；mouse_filter 为 IGNORE，输入与保存/取消/不保存仍由原生窗口处理。重复打开不会创建额外遮罩。

安装检查另外发现欢迎页首次动画读取不存在的 feedback_tween 元数据。当前工作区增加 has_meta 保护，导出的最终程序已包含此保护。该动画实现属于此前未提交的欢迎页改动；保护保持在该工作区修改中，不把整套欢迎页功能混入弹窗提交。

## 自动与视觉验证

confirmation_style_smoke：headless 和 Mobile/Vulkan 图形运行均 exit 0、PASS。覆盖两种配色、不透明表面、边框、按钮配色/尺寸/圆角、全视口遮罩、取消保留文档及关闭状态、第二确认窗口与遮罩复用。已目视检查两种配色截图 /tmp/pg-confirmation-mocha.png 与 /tmp/pg-confirmation-latte.png。开发运行仍有既有窗口锚点警告。

官方 Godot 4.8-dev6 Linux Release 导出，嵌入 PCK；导出时临时去除开发 MCP 自动加载、关闭编辑器插件并排除 addons/tests/docs/开发目录，随后逐字节恢复 project.godot 与 export_presets.cfg。最终导出 exit 0，日志 ERROR 数量 0。最终 Release 图形启动 exit 0、ERROR 数量 0；首次试装发现的六次元数据错误已消除。

实际桌面入口和 ~/.local/bin/project-graph 指向用户安装：/home/waya/.local/lib/project-graph/project-graph。通过同目录临时文件、哈希检查及原子重命名替换该程序，保留入口路径。

最终二进制 SHA-256：2d24fdde47f765375217503c9f8b5e490c6bb8074e4788f96daf8c7d1e89a3f9。

原程序备份：/home/waya/.local/lib/project-graph/project-graph.backup-before-dialog-unification-20261005-011215；原 SHA-256：83b77ccc284b9b68f73528c672b88cb6db08c5bdc2eefa8fe5b65753b2b641e7。没有强制结束用户已打开的程序或改写用户文档。构建来自当前工作区，包含其既有改动，不是仅弹窗补丁的独立发布包。

## 手动验收（待用户执行）

保存当前工作后退出旧实例，从应用菜单重新打开。新建临时草稿并输入文字，再关闭：弹窗应为实心底色，背景轻微变暗，三个按钮圆角与尺寸一致，保存为紫色。取消应保留草稿并撤去遮罩；再次关闭后不保存应丢弃该临时草稿；保存应进入原有保存流程并写入用户选择的位置。切换浅色后重复关闭，检查配色随主题改变。

失败重点：是否仍在使用旧运行实例；背景内容是否透入弹窗；关闭/取消后遮罩是否残留；按钮或保存行为是否异常。完整手动保存/丢弃流程、多 DPI 与多平台尚未替用户验收，不将启动检查描述为全部功能通过。

使用 MCP 类别：脚本读取/创建/修改、编辑器脚本执行、原生导出/构建命令、文件复制/哈希/原子安装。没有直接读写 .tscn，没有使用 Godot Editor computer use，没有修改第三方插件。提交使用 GitButler 技能。
