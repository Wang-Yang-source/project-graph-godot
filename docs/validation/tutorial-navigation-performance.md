# 教程操作导航性能

只读测量 `/home/waya/Desktop/project/教程操作.prg`，615 个节点、388 条连线，保留当前 200% 界面缩放、字体、透明度、圆角和抗锯齿。

## 源码改动与复用

预览缓存复用 Godot Dictionary、Rect2 和既有文档/布局版本号：只在几何变化时获取碰撞包围盒；同档位复用预览矩形；同一帧共享物理显示比例；纯平移复用文字、颜色、样式和预览连接几何；预览成员、布局、属性、主题或采样档位变化时失效。保持原有显示阈值和标题避让规则。

边框调度缓存另见 [边框导航更新缓存](border-navigation-cache.md)。未增加第三方依赖，没有降低采样质量，也未冻结实际编辑物理行为。

## 测量入口

`tests/tutorial_navigation_benchmark.gd` 使用只读文档加载和单独的内存偏好设置，分别测量静止、平移、连续缩放三秒，输出实际帧间隔平均 FPS 与 p95；`--fit` 取完整图视野，`--detail` 使用相机实际倍率 2.0，`--mailbox` 使用 Mailbox，默认取消垂直同步以测吞吐量。

路径通过 `--fixture-hex=` 传递 UTF-8 十六进制编码，避免主界面误把测试参数当作待打开的 PRG 文件。通过 Godot MCP 编辑器脚本使用 `OS.create_process` 启动测试；例如生成参数：`"--fixture-hex=" + path.to_utf8_buffer().hex_encode()`。测量不会保存文档、最近文件或个人偏好设置。

## 开发运行对照

2026-10-03，本机 i9-13900H / Intel Iris Xe，Godot 4.8.dev6，X11，1920×1200，UI 200%，完整图相机倍率约 0.03534。其他编辑器及应用保持运行，因此数值不是单独占用机器的性能上限。

| 实现 | 静止 FPS | 平移 FPS | 缩放 FPS | 平移 p95 ms | 缩放 p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 修改前 OpenGL，取消垂直同步 | 185 | 76 | 57 | 17.36 | 27.10 |
| 预览与边框缓存，OpenGL，取消垂直同步 | 184 | 107 | 73 | 10.48 | 20.98 |
| 相同缓存，Vulkan Mobile / Mailbox | 193 | 114 | 75 | 10.65 | 19.77 |

Vulkan 另一次测量为平移 112、缩放 78 FPS，存在运行负载差异。显示器实际呈现仍受刷新率限制，不能将这些数值解释为每帧均达到 120 FPS。取消同步和 Mailbox 运行的静止截图一致性检查：超过 10/255 的像素差约 0.0031%，平均通道差约 0.0009/255；文字、填充、结构和圆角没有明显变化。跨 GPU/平台视觉未验证。

## 回归

用户已授权运行测量和回归。Godot 文件通过 MCP 脚本读写、创建和编辑器脚本工具处理；未直接读取或写入场景文本。

通过：`tutorial_navigation_cache_smoke`（真实文档的预览包围盒、重复查找、平移、重命名、主题更新和持久对象不变）、`minimum_screen_border_smoke`、`hidpi_stage_smoke`、`canvas_sampling_smoke`、`navigation_cache_smoke`。前四个旧预览测试在优化前已因既有连接范围或预览假设失败，未为了让其通过而改变现有交互与视觉。

手动验证（待执行）：重新启动更新后的程序，打开该教程，保持 UI 200%，缩小到完整图并连续平移、缩放；调试信息中的 FPS 应提高，字体、圆角和透明层次应保持现状。放大后点击、拖拽、编辑文字并撤销；对象命中与历史行为应正常。再切换深浅主题并调整窗口大小，检查预览内容及时更新。若仍低帧率，重点检查是否运行旧版、GPU 驱动是否使用软件渲染、完整图中的对象规模与后台负载；若有旧标题、错色、缺边或端点偏移，检查缓存失效。

复用依据：[Godot GPU 优化](https://docs.godotengine.org/en/latest/tutorials/performance/gpu_optimization.html)、[CPU 优化](https://docs.godotengine.org/en/latest/tutorials/performance/cpu_optimization.html)。
