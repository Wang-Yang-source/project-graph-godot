# Linux 导出启动

独立 release 程序从启动页后台加载主场景时，出现随机资源 preload 失败（舞台场景、着色器或字体），导致无法进入工作区。改为启动页第一帧绘制后，在主线程调用 Godot 原生 load 加载主场景；保留启动提示和失败反馈。没有新依赖。该初始化加载期间会占用主线程，后续舞台导航流程不变。

通过 Godot MCP 读取/修改 boot.gd，执行 headless release 导出，再独立启动导出程序验证。临时关闭开发插件及 MCPRuntimeProbe，排除测试与临时文件；导出后精确恢复 project.godot 和 export_presets.cfg 原始字节。Godot 与模板均为 4.8.dev6.official.8898c2b3d。

修复前独立启动日志存在 preload 解析错误；修复后独立 GUI 启动退出码 0，无 SCRIPT ERROR/ERROR。UID 改路径及文本脚本导出的定位试验已撤回，保留原生产导出模式。

尚待手动验证：从应用菜单打开 Project Graph，应在启动页后进入工作区，再打开现有文档；失败时检查启动页一直停留、空白窗口、无法新建标签。其他平台及冷启动延迟尚未验证。
