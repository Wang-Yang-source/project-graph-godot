# 连续节点避让

原问题：拖动 A 推开 B 时，局部物理查询只围绕 A，B 接触的 C 没有加入求解，导致 B、C 留下重叠。

现在使用 Godot 原生 PhysicsShapeQueryParameters2D 查询，配合数组队列和字典去重，沿同容器内的近邻接触递归扩展。查询覆盖每个参与节点的下一步移动范围；涉及标签端点时继续查询端点邻居。每个节点每个物理步只查询一次。保持原有阻尼弹簧、局部距离预算和完整操作事务，不沿图的连线拓扑启动远处布局；没有新增依赖。

使用 Godot MCP 脚本读取、创建、修改和编辑器脚本执行工具。

已执行：chain_contact_smoke 修改前失败，修改后通过，覆盖 A→B→C→D 连续挤压、最终两两分离、远处节点固定、单步撤销与重做。另通过 local_drag_physics_smoke、overlap_clearance_smoke、physics_scope_smoke、property_local_physics_smoke、spring_contact_smoke。

尚未执行的手动验证：开启物理，将 A、B、C 排成一列，拖动 A 挤压 B 并继续向 C 推进，再松手；B 与 C 应一起弹性让位并最终分开，远处节点不应移动。增加 D 后再试，并撤销、重做。若失败，重点检查第二、第三层邻居持续重叠、退回时节点突然停止或跨容器移动。
