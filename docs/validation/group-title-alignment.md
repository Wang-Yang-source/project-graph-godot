# 分组标题默认居中

分组标题使用 Godot 原生 Label 文本居中和 Control 左上角锚点；尺寸增长固定左上角，样式刷新后恢复完整分组标题宽度。没有新增依赖。

通过 Godot MCP 的脚本读取、创建、修改和编辑器脚本执行工具操作；测试运行于独立 Godot 4.8.dev6 进程，没有使用 computer use 或直接处理场景文件。

自动验证：新增 group_title_alignment_smoke，覆盖创建、样式刷新、修改文字、字号和固定宽度、明暗主题、取消编辑、加载边界与移动。修复前失败，修复后 headless 与 X11/Compatibility 均通过；实际渲染截图 /tmp/pg-group-title-centered.png 已检查。edit_text_alignment_smoke（X11）、text_edit_geometry_smoke（headless 与 X11）、slice_ungroup_smoke（headless）通过。

现有 imported_containment_smoke 在 headless 和 X11 下均因“Dragged group uses its preview”失败；去掉本次标题修复后同样失败。分组携带成员移动、边界、撤销和重做断言没有报告失败。该预览问题不属于本次标题修复。

尚未执行的真实设备手动验证：新建或打开分组，修改标题后拖动。应从一开始就在顶部水平居中，拖动前后位置不跳变；失败时重点检查加载、编辑退出和主题切换后标题是否缩回左上角。
