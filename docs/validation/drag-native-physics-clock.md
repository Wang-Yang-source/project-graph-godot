# 拖动与碰撞使用同一物理时钟

## 改动与依据

本地缓存的上游 `origin/godot` 为 `0f09b4f98`（2026-09-13）。其 Entity 使用速度追赶鼠标，StageObject 直接继承 RigidBody2D。本次复用这一思路及 Godot 自带的 PhysicsDirectBodyState2D；不新增依赖或碰撞求解器。远程 fetch 与 GitHub API 连接超时，未确认该缓存是否为线上最新提交。

旧实现冻结刚体，在鼠标输入回调中直接写 global_position。一物理帧内的连续输入能直接跳过接触区域。现在输入只更新目标，_integrate_forces 在原生物理时钟中设置追赶速度。追赶系数按 timestep 限制，并复用 throw_speed_limit 防止突然跳远的指针产生过高撞击速度。拖动时保持动态碰撞，释放后保留原有惯性与历史事务。分组跟随和布局移动的显式位置变更在下一次原生积分同步，避免旧物理状态覆盖新位置。

Godot 官方依据：https://docs.godotengine.org/en/latest/classes/class_rigidbody2d.html 。Godot 文件仅通过 read_script、modify_script、create_script 和 execute_editor_script 等 `mcp__godot_mcp__` 工具处理；场景通过 PackedScene 原生打包，无 tscn 文本操作。

## 自动验证（用户已授权）

- drag_physics_clock_smoke：修改前失败（输入直接跳位、冻结模拟、连续输入错过碰撞）；修改后通过。覆盖一帧 50 个目标更新、原生追赶、接触推开邻居、静止目标下的位置反向跳动小于 0.5 世界单位。
- native_entity_physics_smoke：惯性、碰撞、阻尼、分组拖动与惯性、一次撤销/重做通过。
- drag_target_dedup_smoke、container_connection_scope_smoke：通过。
- 独立暂存的 Entity 源码运行上述两个物理测试通过，原有未提交代码恢复后保留。
- Linux release 导出成功；使用相同 release 模板导出的临时验证入口报告 DRAG_PHYSICS_CLOCK: PASS，退出码 0。
- 生产 release 在 Xvfb/OpenGL Compatibility 下启动并退出成功。Xvfb 报输入法及 V-Sync 不支持警告，无脚本错误；未据此声称实体桌面的视觉体验已完全验证。

## 用户手动验证（尚未执行）

关闭并重新从应用菜单启动 Project Graph，创建两个文本块，分别慢拖、快速拖动一个块撞向另一个，再停住鼠标。应看到节点连续追赶、邻居被推开、接触后逐渐稳定；甩动释放保留惯性，撤销一次恢复整个操作。再拖动包含多个节点的分组，检查子节点保持相对位置。

如果失败，重点记录：是否只有撞上时抖动，是否停住鼠标后仍来回跳、是否分组子节点反复跳回、是否仅高缩放或高刷新率下出现。真实桌面、高刷新率以及大量节点接触仍须上述手动验证。
