# 节点隐形碰撞外框

每个 Entity 通过原生 CollisionShape2D / RectangleShape2D 加入名为 PhysicsMargin 的临时子节点，覆盖已有碰撞几何的本地包围框，再向外扩展每侧 12 个世界单位。两个节点可见边框之间约留 24 单位的间距；这是原生接触带来的排斥感，不是远距离力场。文本块、图片资产、笔画与分组共用 Entity 集成，无新增依赖或自写碰撞算法。

复用 Godot 原生形状节点与 Rect2.grow。原有形状保留供编辑工具和连线使用，标记为 editor_geometry_only 并停止参与物理接触；外框标记为 physics_margin，StageObject.aabb 忽略它，避免选择框、连线、分组边界跟着膨胀。只有外框参与接触，避免叠加两个碰撞形状。几何变更后通过合并的延迟更新调整外框，不在物理查询刷新过程中修改形状。包含关系的祖先碰撞例外继续生效。

实际改动：Entity 创建并维护外框；StageObject 区分物理外框和编辑几何；新增 entity_collision_margin_smoke 回归。使用 mcp__godot_mcp__read_script、modify_script、create_script、execute_editor_script；未读写任何 tscn 文本。

用户已授权自动调试。新增测试在修改前失败，修改后通过：外框节点、每侧边距、原始编辑边界、未贴边节点自动分离、文字变宽同步、资产与笔画支持。drag_physics_clock_smoke、native_entity_physics_smoke、container_connection_scope_smoke 通过；独立暂存的 Entity 与 StageObject 运行外框及原生物理测试通过。Linux release 导出成功；相同 release 模板的临时验证入口报告 ENTITY_COLLISION_MARGIN: PASS；生产程序 Xvfb/OpenGL 启动退出成功，只有环境输入法与 V-Sync 警告，无脚本错误。

手动验证尚未执行：关闭旧程序，从应用菜单重新打开，拖动一个文本块靠近另一个。可见边框尚未贴住时，应已推动邻居，松手后保留空隙并稳定。修改文字宽度再撞一次，外框应同步变化；拖动分组检查内部节点不被挤出，撤销一次应恢复整次操作。失败时重点检查：是否贴边后才碰撞、空隙是否持续跳动、连线端点是否错误移到外框、分组内部是否被推出。
