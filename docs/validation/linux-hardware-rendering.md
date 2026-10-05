# Linux 硬件渲染与 Mailbox

通过 Godot 原生项目设置的 `linuxbsd` 平台覆盖，在 Linux 默认选择 Mobile 渲染器和 Vulkan 驱动，窗口使用 Mailbox 垂直同步模式。保留其他平台现有渲染器选择，以及已有的 OpenGL 回退配置；不改变颜色、字体、采样、透明度、抗锯齿或窗口比例。引擎已支持这些能力，无需新增社区库或驱动依赖。

Mailbox 在垂直消隐时呈现最近完成的图像，同时继续渲染后续图像，因此可以解除显示器刷新率对渲染帧率的限制且避免撕裂。实际显示帧率仍受显示器刷新率限制，渲染吞吐量由图内容、CPU/GPU 和后台负载决定。OpenGL 回退时 Mailbox 按 Godot 契约退回普通垂直同步，不保证无限渲染帧率。

本机独立进程实际启动报告 Vulkan 1.4、Mobile、Intel Iris Xe，并报告 VSync 模式 3；该配置不是只修改了未生效的设置。教程完整图开发运行约为静止 193、平移 114、缩放 75 FPS。测量边界及 CPU 缓存优化见 [教程导航性能](tutorial-navigation-performance.md)。

通过真实教程缓存、最低边框像素覆盖、原生舞台分辨率/点击、画布采样、导航缓存五项回归。Godot 项目设置及临时导出配置通过 MCP 编辑器脚本处理；脚本与测试通过 MCP 读写、创建和执行。没有启用 Godot 官方标注存在崩溃风险的独立渲染线程选项。

手动验证（待执行）：重启新版安装的程序，打开教程操作，保持当前界面比例，持续平移和缩放，再调整窗口大小、编辑节点和撤销。应保留字体、圆角、透明层次和准确点击，帧率比旧版完整视野提高，画面不出现撕裂。若渲染器仍为 OpenGL，重点检查 Vulkan 驱动及是否运行旧安装；若驱动回退或后台负载高，帧率可能低于测量值。Wayland 原生会话、其他 GPU/平台及多显示器移动尚需人工验证。

来源：[Godot 渲染器](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)、[DisplayServer 的 Mailbox 契约](https://docs.godotengine.org/en/latest/classes/class_displayserver.html#enum-displayserver-vsyncmode)、[ProjectSettings 渲染线程限制](https://docs.godotengine.org/en/latest/classes/class_projectsettings.html#class-projectsettings-property-rendering-driver-threads-thread-model)。
