# 预览图片异步捕获

在独立分组缓存修复基础上，将 Vulkan/Mobile 的预览图片捕获改为 Godot 4.8 dev6 原生 RenderingDevice.texture_get_data_async；使用 RenderingServer.call_on_render_thread 提交，WorkerThreadPool 生成独立 Image 的 mipmap，主线程安装 ImageTexture。画面仍由 SubViewport 和原有节点生成，未使用低层绘制 API。Compatibility 或不支持的像素格式回退到原生图片读取，mipmap 仍在工作线程生成。

复用引擎能力，无新增第三方依赖。核对了实际二进制方法及 dev6 官方 [RenderingDevice](https://raw.githubusercontent.com/godotengine/godot/8898c2b3d/doc/classes/RenderingDevice.xml) / [RenderingServer](https://raw.githubusercontent.com/godotengine/godot/8898c2b3d/doc/classes/RenderingServer.xml) 文档；没有自写 GPU 复制或 mipmap 算法。实测 viewport 为 RGBA8，进入原生异步读取路径。

被新预览替换的捕获会标记取消，等待已提交的读取完成后释放 viewport，不安装过期图片。读取失败时保留已渲染的 viewport 图片，避免空白预览；生命周期测试也覆盖该失败路径。页面退出时节点树释放场景资源，回调检查目标有效性。Godot MCP 的脚本读写、创建与编辑器脚本执行完成实现、图形测试和测量。

同一 975 对象教程快照、Godot 4.8 dev6、Intel Iris Xe、Vulkan Mobile、1920×1200、UI 200%、VSync 关闭；连续缩放采样 3 秒，倍率 ±25%：

| 初始倍率 | 原始 FPS / 最差帧 ms | 独立缓存后 | 再异步捕获后 |
| --- | --- | --- | --- |
| 0.08 | 154 / 319 | 213 / 78 | 212 / 36 |
| 0.15 | 144 / 557 | 244 / 138 | 246 / 52 |
| 0.30 | 234 / 204 | 257 / 203 | 252 / 110 |

全图连续缩放复测从 156 提升到 196 FPS；平移为 278/277 FPS。最终永久基准在 0.15 倍复测为 220 FPS、最差帧 58.1 ms、P95 5.42 ms、P99 31.24 ms，说明测量有波动。主要减少跨预览档位的停顿，P95 没有明显改善；P99 在 0.15 倍从约 7.7 增至 23.6–31.2 ms，多次较短更新取代少数长停顿，仍有继续优化的空间。这里仅报告调试进程，尚未取得 release 数据。

`async_preview_capture_smoke.gd` 在 Mobile 和 Compatibility 图形进程通过，验证颜色、透明像素、尺寸、mipmap、完成回调线程与超时。`async_preview_lifecycle_smoke.gd` 在两个渲染器均验证取消进行中的捕获后 viewport 释放。独立缓存、真实教程导航缓存及缩放网格回归通过。检查了优化后截图。`tutorial_zoom_benchmark.gd` 保留倍率参数、P95/P99/最差帧，输入通过十六进制路径传入，使用隔离偏好且不保存文档。

尚未执行：用户手动复查、其他硬件及 Windows/macOS/Web 性能、release 性能和外部 gdformat（环境未安装）。上一轮 release 测量被既有 MCP autoload 资源缺失阻断。

手动验证：打开教程，连续缩放跨过分组预览阈值，再快速切换标签页或关闭文档；预期预览连续、颜色透明度一致、停顿明显减少。编辑组内文字后再缩小，缩略图应显示新内容。失败时重点检查旧图片覆盖新内容、闪白、透明度改变、关闭页面后的错误日志或内存持续增长。
