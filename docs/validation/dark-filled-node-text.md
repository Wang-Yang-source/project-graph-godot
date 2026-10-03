# 深色主题浅色填充文字回归

日期：2026-10-04。

原因：工作区在 TextNode 和连线标题中增加了深色主题固定前景色分支，使用 #cdd6f4，绕过实际背景对比度计算。填充同色时文字与背景融为一体。

实际改动：移除这两处工作区分支，恢复 HEAD 已有的 Palette.neutral_text_color(background)。节点标签、编辑文字、光标及 LaTeX 共用计算结果。复用既有调色板和 Godot Color，无新增依赖。测试增加截图中的 #cdd6f4 填充，并断言实际显示文字的对比度至少为 4.5:1。由于修正后的两处前景色表达式与 HEAD 相同，本次原子提交只新增回归测试与此记录，其他已有工作区改动不纳入提交。

工具：Godot MCP 脚本读取、修改及编辑器脚本执行；场景使用现有测试中的 PackedScene API，未读取场景文本。

用户授权后验证：原工作区 node_neutral_text_smoke 退出 1，深色主题文字、编辑器及 LaTeX 前景色断言失败。修正后该测试 headless 通过；新增填充及对比度断言后 X11/Compatibility 通过，截图 /tmp/pg-neutral-node-text-false.png 已目视检查，浅色填充显示深灰文字。text_contrast_smoke、caption_selection_style_smoke headless 通过。

额外检查：edit_text_alignment_smoke 在 headless 等待绘制而停住，已终止独立测试进程；X11 下节点编辑对齐通过，连线标题取消编辑位置断言失败，此项未标记通过，未扩大本次颜色修复范围。

尚未执行：原用户文档的真实交互检查、导出构建及其他平台。

手动验证：重新运行项目并打开原文档，查看浅色填充节点，再双击编辑并退出，切换明暗主题。应看到清晰的文字和光标；若仍为空白，重点检查编辑与退出时文字是否恢复，以及填充或上层容器改变后前景色是否同步更新。
