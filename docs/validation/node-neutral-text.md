# 文本块自动灰阶文字

实际改动：TextNode 始终用 Palette.neutral_text_color(display_background_color(light)) 计算文字、编辑器、光标和 LaTeX 的灰阶颜色。背景包含画布、上层容器及自身填充的透明叠加。旧 text_color 字段仅供兼容存储，不再显示为可配置文字色，也不参与渲染。复用已有 Godot Color 与调色板计算，不新增依赖。

缩略图程序同样忽略旧文字颜色，按对应背景生成中性文字；已有 Python 测试改为验证浅/深主题及透明、白、黑背景上的旧红色文字与自动颜色结果一致。欢迎页开发运行优先调用仓库缩略图程序，缓存版本升级，避免旧彩色缩略图残留；此欢迎页接入依赖此前未提交的欢迎页重构，暂留工作区。

工具：Godot 文件通过 MCP 脚本读取、创建、修改及编辑器脚本执行工具处理；普通 Python 文件使用文本补丁工具。

验证：node_neutral_text_smoke 修复前失败，修复后 headless 与 X11/Compatibility 通过，覆盖显式旧蓝色/红色、旧透明度、不同填充、嵌套半透明背景、主题切换、编辑与取消，文档快照保持不变。text_contrast_smoke、edit_text_alignment_smoke、group_title_alignment_smoke、welcome_theme_preview_smoke 通过；Python 缩略图 12 项测试通过。实际截图 /tmp/pg-neutral-node-text-true.png 已检查。

尚未执行的真实设备手动验证：重启并打开截图中的旧模板，切换明暗主题，再改变文本块填充并进入编辑。文字应只有黑、白、灰，随实际背景改变明度；失败时重点检查旧文件文字色、半透明上层容器、编辑态和旧缩略图缓存。
