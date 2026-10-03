# 连线缩放网格按需构建

原来静止相机下移动节点也会为隐藏的缩放网格生成顶点、索引和 ArrayMesh。现在只在缩放动画实际使用该网格时构建；平移和拖动仍及时更新原有 Line2D、箭头、碰撞及连线文字，下一次缩放使用最新端点几何。沿用现有 Godot MeshInstance2D/ArrayMesh，没有新增依赖或改变画面质量。

通过 Godot MCP 的脚本读取、修改、创建及编辑器脚本执行工具完成。独立提交只改变网格构建条件，保留工作区其他连线功能修改。

同一 975 对象教程快照、Godot 4.8 dev6、Intel Iris Xe、Vulkan Mobile、关闭 VSync、1996×1248、UI 200%，3 秒真实指针拖动：目标去重后为 17.07 FPS / P95 64.68 ms；再按需构建网格为 21.13 FPS / P95 51.94 ms。相对未优化的复测 9.93 FPS / P95 110.46 ms，帧率约翻倍，P95 降低约 53%。仍未达到 60 FPS，不能描述为全软件已无卡顿。

全图导航复测（1920×1200，其他条件一致）：优化前后静止 432/434 FPS、平移 281/286 FPS、缩放 160/151 FPS。缩放差异约 5%，不据此宣称缩放收益。查看了优化后全图截图。

已通过 `lazy_zoom_mesh_smoke.gd`，覆盖首次缩放、静止移动时不重建隐藏网格、下次缩放更新几何、缩放完成恢复 Line2D。`navigation_cache_smoke.gd`、带真实快照的 `tutorial_navigation_cache_smoke.gd`、鼠标及位置布局回归通过。

Linux release 导出命令退出码为 0，生成了 `/tmp/project-graph-performance.x86_64`，但有 MCP 端口冲突和退出资源警告。release 测量进程报告缺少 `res://addons/godot_mcp/runtime/mcp_runtime_probe.gd` autoload 并超时，未取得 release 性能数据，未改动第三方插件。环境未提供 gdformat；已执行 Godot 解析与运行检查，没有完成外部格式工具检查。

手动复查：打开教程，拖动有连线的分组，随后连续滚轮放大、缩小、停止，再移动端点并再次缩放。预期曲线和箭头连续、缩放结束不闪烁、不留下旧位置连线。失败时检查第一次缩放突跳、箭头消失、移动后缩放显示旧几何。尚未由用户执行这些步骤，首次缩放与 release 的尾延迟尚未单独测量。
