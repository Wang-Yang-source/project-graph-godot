# 可见圆角与原生碰撞一致

用户最终要求取消额外透明外框。已移除碰撞扩张边距，以及 Entity 的紫色半透明选择外圈；对象仍保留选择状态、拖动与事务历史。

Entity 通过原生 CollisionShape2D 子节点 PhysicsOutline 承载物理轮廓。具有 get_visual_outline 的文本节点与分组，复用实际可见轮廓，交给 Geometry2D.convex_hull 及 ConvexPolygonShape2D；其余矩形资产沿用实际矩形边界。原来的矩形编辑几何仍保留，但标记 editor_geometry_only，不参加物理接触。StageObject.aabb 排除 physics_outline，因此连线、编辑边界没有膨胀。轮廓在文字、分组尺寸变化后合并延迟更新。无新增依赖、自写碰撞或物理求解器。

Godot 文件全部通过 mcp__godot_mcp__read_script、modify_script、create_script、execute_editor_script 处理；没有 tscn 文本操作。修改 Entity、StageObject、Stage，以及对应测试；已删除要求额外边距和选择外圈的过时测试。

用户已授权自动调试。rounded_entity_collision_smoke 使用 Godot Shape2D.collide 与小圆探针检查原生形状：修改前五项失败，修改后通过。验证圆角空白不碰撞、中心碰撞、没有隐形边距、选择不产生外圈、尺寸变化同步。独立暂存源与工作区均通过此测试及 native_entity_physics_smoke；drag_physics_clock_smoke 与 exterior_connections_smoke 通过。Linux release 导出成功，相同 release 模板临时入口输出 ROUNDED_ENTITY_COLLISION: PASS，退出码 0。生产程序 Xvfb/OpenGL 启动成功，无脚本错误。

最初使用空间点查询的测试在 SceneTree 的帧信号中遇到物理空间访问时机错误，未作为有效证据；已改为 Shape2D.collide 后重新取得修改前失败、修改后通过的结果。官方方法依据：https://docs.godotengine.org/en/latest/classes/class_shape2d.html 。

尚未执行的手动验证：重新从应用菜单启动程序，选中文本块，应没有紫色半透明外圈；从对角方向拖动两个文本块靠近，应沿真实圆角接触，不再按矩形空白顶角挤开。修改文字尺寸、拖动分组再检查一次；撤销应恢复整次操作。若失败，重点检查圆角空白是否仍顶住、外圈是否仍显示、改变尺寸后是否出现旧碰撞边界。截图中的穿线另见 exterior-connection-routing.md。
