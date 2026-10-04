# 快捷键教程性能测量

本入口针对用户指定的 `/home/waya/Desktop/project/tutorial-shortcut-keys-3.1.prg`，复用已有分组拖动驱动、完整 Main 和 Release 导出入口。测试驱动新增能力不表示生产性能优化已完成。

## 条件与入口

2026-10-05：新增 `--subject-id=`，避免测试硬编码要求文档中存在“伸缩链”；`--zoom=` 默认保留旧基线倍率 0.28488218784332。指定文档预期 609 个对象，大组 ID 为 `qbHLlGF4VNI_n5iLF-Zeu`，小组 ID 为 `8b837e8f-fe28-407f-842d-4de1fe1cd44e`。

`tests/group_drag_benchmark.gd` 继续支持 `--main-window`，用于已有开发构建的短拖动基线。`tests/performance_baseline_runner.gd` 新增同一完整 Main 路径，以及 `--only-drag`、`--duration=`（秒，默认 3）、`--output=`、`--expected-objects=`。源文件复制到进程独立的用户目录临时文件；结束时检查源文件和副本哈希，不保存源文件。

通过 Godot MCP 编辑器脚本构建：

```gdscript
load("res://tests/performance_release_export.gd").build("/tmp/pg-shortcuts-before.x86_64")
```

由 Godot MCP 启动该导出程序，将下列参数放在 `--` 后：

```text
--fixture-hex=<指定文件绝对路径的 UTF-8 十六进制>
--main-window
--subject-id=qbHLlGF4VNI_n5iLF-Zeu
--expected-objects=609
--only-drag
--duration=5
--output=/tmp/pg-shortcuts-before-large.json
```

小组替换 `--subject-id` 和输出文件名。修复前后使用相同输入、倍率、窗口、UI 200%、渲染器与 VSync 关闭条件；记录实际 Release 包哈希和工作区代码状态。不要将测试导出包发布成产品。

## 指标与限制

保留原始逐帧间隔和 median/P95/P99，增加超过 16.67/33.33 ms 的比例、实际采样时长、每显示帧物理步数，以及 `RenderingServer.get_frame_setup_time_cpu()` 和视口 CPU 加帧准备 CPU。原有视口 GPU 总和仍可能包含按需视口的旧读数，不能自动等同准确关键路径。

环境报告增加 `physics_ticks_per_second` 与 `max_fps`。完整 Main 可能按屏幕刷新率设置物理频率，而裸 Stage 默认频率不同；比较前必须检查这些条件，不能只根据每显示帧物理步数判断成本变化。本测量不降低物理频率或画面质量。

拖动开始报告目标是否处于 overview 模式、被 overview 隐藏的实体数、物理会话成员数，并记录采样期间物理会话成员峰值。用于区分展开内容和折叠预览；默认倍率不变，测量折叠场景时显式设置 `--zoom=0.05` 或 `--zoom=0.1`，再加 `--require-overview`，若目标未折叠则失败。活动 overview 的真实输入仅选择对应 summary/title，避免点击被渲染层隐藏的原生 Label；不能仅按肉眼猜测折叠状态。

`press_input_ms` 记录按下事件的 parse/flush 同步耗时；直接处理器入口另记 `direct_press_handler_ms`。保留原有不投掷的测试收尾：先同步调用 `finish_drag(false)`，其耗时记作 `release_finalize_ms`，随后释放事件 parse/flush 记作 `release_input_ms`，两项独立同步调用之和为 `release_callback_total_ms`。`release_input_after_manual_finish=true` 明确说明实际拖动先已结束，不能仅用随后的空释放事件耗时证明正常释放响应。记录历史事务在收尾前、手动结束后和输入释放后的活动状态；这些字段均不含异步物理稳定等待，未把惯性持续时间算成输入回调开销，也未新增等待或改变历史取消流程。新增计时已通过解析检查，尚待主任务下一次正常测量取得数据；正常投掷释放和历史最终提交仍须单独验收。

可选 `--real-input --measure-release` 使用正常释放事件，不提前手动结束拖动。记录真实释放 parse/flush 后，再观察 1 秒 release 阶段的帧 median/P95/P99/峰值，捕捉惯性、碰撞和异步历史提交尖峰；记录窗口结束时历史事务是否仍活动、物理会话成员数和目标拖动状态。release 的同步事件耗时与这一阶段的帧耗时分别报告，窗口中事务仍活动不自动判为失败；有限观察不能证明后续全部稳定或释放完毕。该选项不影响默认旧收尾，尚待主任务最终测量验证。

完整 Main 使用原有生产脚本，避免在节点已 ready 后替换脚本破坏状态；此路径的 `callback_timings_available=false`、预览捕获计数为 -1，表示未采集。裸 Stage 继续使用原有探针并报告捕获完成次数，捕获 GPU 为零仍表示缺少有效计时。父子回调耗时是 inclusive，不得重复相加。未把约每秒更新的 `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS` 当作逐帧 CPU 时间。

默认拖动沿用旧驱动：输入事件移动指针，直接调用对象处理器开始拖动。可加 `--real-input`，只通过正常输入事件开始拖动；这条路径若未实际移动目标则基准失败，不会回退为直接处理器调用。两种入口必须分开标记，不能混合比较。画面命中和实际跟手仍需用户验收。

首个完整 Main Release 的真实输入尝试未成功：目标位移为 0，结果 `valid=false`，所测约 7.45 ms 的中位帧时间不能作为拖动基线。定位到容器中心可能属于嵌套成员，以及旧指针转换遗漏原生像素 SubViewport 的 final transform。驱动现复用既有 `hidpi_stage_smoke` 的完整转换，并在正常输入按下前寻找目标自身的可见 Label 或 summary 控件，要求 GUI hover 指向该控件；按下后检查目标已选中且 `is_dragging=true`，采样期间每帧继续检查。必要时把相机移到目标标题以保证它在视野内；输出输入控件路径、世界/屏幕位置与选中状态。未确认正确拖动前不得把静止结果列入性能比较。

后续开发构建发现合成事件与真实 OS 指针不一致：`Viewport.warp_mouse` 接收视口逻辑坐标，会自行应用屏幕变换，而事件位置使用窗口物理像素。旧驱动把物理像素直接用于 warp，在 200% UI 下再次放大，物理帧读取真实鼠标时产生上千单位的异常位移；即使目标已选中且保持拖动，也不能作为固定短轨迹的有效基线。现已对 warp 参数先应用根视口 final transform 的逆变换；采样前及过程中检查真实世界指针对应的屏幕位置与期望位置，误差超过 2 个物理像素即失败。输出 `pointer_check` 和 `pointer_error_max_px`，此前异常位移样本排除。

## 验证

测试驱动改动通过 MCP 脚本修改类别完成；未直接读写场景文件、未改生产脚本或第三方插件。两个驱动通过 MCP `Script.reload()` 解析检查，返回 `OK`。2026-10-05 对指定 609 对象文档执行一次独占的完整 Main 开发构建 2 秒指针诊断：目标 ID、正常 GUI 命中、持续拖动、对象/连线及源文件哈希校验通过，位移 28.92 世界单位，最大物理指针误差 1.026 px，未放宽 2 px 阈值。发送时的屏幕位置与帧采样时的实际屏幕位置单独记录，避免相机变化使旧世界目标比较失真；加 `--pointer-trace` 可记录最多 32 帧的诊断信息，常规测量只保留指针误差校验。

该次共有 11 帧，median 199.52 ms、P95 299.22 ms，每显示帧物理步数 median 为 8，已有视口 GPU 总和 median 0.82 ms、视口 CPU 加帧准备 median 0.90 ms。它仅验证驱动并说明持续更新仍有严重瓶颈，样本不足以作为稳定分位数或优化前后收益。前一次出现 1174 px 指针误差的 2 秒样本保留 `valid=false`，独占诊断中未复现，不能凭猜测改为通过。完整 Main Release 配对结果、长采样性能验收及下列用户视觉验收尚未完成。

手动打开指定文件，全图平移并从全图放大到文字可读，再拖动上述大组和小组。预期成员、边框、连线、箭头同步移动，释放后稳定，一次拖动能一次撤销，原文档内容保持原样；再修改组内文字并缩小、撤销/重做和关闭标签。失败时重点检查目标误命中、200% UI 坐标偏移、周期整图序列化、缓存未失效、释放后的物理补帧以及预览资源未释放。

默认验收目标为完整 Main、正常质量的预热平移/缩放/拖动 P95 ≤16.67 ms、P99 ≤25 ms，超过 33.33 ms 的帧占比 ≤0.5%；首次大范围缩放单列，不与热缓存混合。120 Hz 为独立后续目标，不能以无上限平均 FPS 宣称已满足。上述目标尚未验收。
