# 安装版菜单图标源文件

main.gd 使用 FileAccess 读取 SVG 源码，再替换主题色并生成 DPITexture。普通 texture 导入只导出转换纹理，安装包中缺少原文，导致顶部菜单图标为空。

实际改动：src/main/icons/lucide 下 81 个 SVG 的 .import 改用 Godot 原生 Keep File；四个平台导出预设显式包含此目录 SVG。其他图标目录和现有 DPITexture 着色逻辑未修改。通过 Godot ResourceLoader 依赖索引未发现资源直接使用此目录的纹理。复用 ConfigFile、Keep File 和既有图标加载代码，无新依赖。

验证：用 Godot 4.8.dev6 加载原用户安装二进制的 PCK 并调用 main.gd 的 _menu_icon，得到空纹理，探针退出码 1。重新导出 release 后，同一探针得到有效图标并退出 0。release 独立 headless 启动退出 0。相关文件 git diff --check 通过。导出后还确认 Keep File 导入未被自动扫描改回 texture。未安装外部 gdformat，未执行该工具检查。

工具类别：Godot MCP 编辑器脚本读取和写入导入/导出配置、资源依赖读取、脚本与导出包检查、导出构建。没有直接读写 .tscn，没有操作 Godot Editor 的 computer use。

参考：[FileAccess 官方说明](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html)、[4.8.dev6 导出器](https://github.com/godotengine/godot/blob/8898c2b3d/editor/export/editor_export_platform.cpp)。导出器的 keep 分支保留原文件，普通纹理分支只保存导入产物，单加 include_filter 不足以改变导入行为。

手动验证（尚未执行）：退出已有实例，从应用入口重新启动，左上角文件等菜单应有图标；切换深浅主题与 100%/200% 缩放，图标应完整并适配颜色。失败时重点检查是否仍运行旧进程、启动入口指向哪个二进制、导出包是否保留 SVG 原文。其余平台已更新预设，尚未构建验证。
