# 原生避让查询的包含关系排除

PhysicsSession 复用 Godot 的 `PhysicsShapeQueryParameters2D.exclude`：每个 driver 的祖先 RID 只加入该 driver 的局部查询排除，已有固定后代仍在会话共享排除表中。祖先不会被写入共享列表，所以它仍可作为另一外部 driver 的合法障碍。祖先遍历为 O(depth)，无需新库、通用查询缓存或碰撞近似。

拓扑 revision 变化时重建固定后代 RID 排除并清除可选的原有接触区域缓存。原生 hull 真正准备或改变（资源、局部变换、启用状态）时，全部静止 driver 可重新发现新障碍；世界共同平移及形状缓存命中不会清缓存。该通知保留原有可选缓存的正确性，提交不引入该缓存本身。未调整物理频率、CCD、CONTACT_MARGIN 或碰撞精度。

自动回归：`res://tests/contact_query_exclusions_smoke.gd`。覆盖局部祖先排除、同一祖先对另一 driver 的外部碰撞、创建障碍、解除包含后的 RID 清理与真实原生查询命中、形状变化通知及共同平移不通知。测试在 physics callback 记录真实 native hit，使用明确进入查询区域的重叠 fixture，并给包含布局与原生碰撞数个 physics ticks 收敛；仅 AABB 间距 4 个世界单位并不保证曲线轮廓命中。实际测试文本节点为 contact_monitor=false、max_contacts_reported=0、KINEMATIC freeze_mode，原生凸包100点；这些诊断不证明性能已达60FPS。

Godot 源码与测试经 MCP script 读写、resource reload、异步 headless child 验证；原子提交前做 diffcheck。手动验证尚待用户执行：

1. 打开测试 PRG，展开分组，拖动内部元素；外框不得因自身后代的接触查询而被激活推走。
2. 同时选择该内部元素及一个外部元素，向同一外框靠近；外部元素与外框仍须正常避让，不能因另一个 driver 的祖先排除而穿过。
3. 拖动外组过程中，在其外边界附近新增对象或解除一个内部对象的包含关系，再拖向该对象；新外部对象应参与碰撞，原固定后代不能永久留在排除列表。

失败时检查外框被自身子节点推出、对其他 driver 漏碰撞、新对象无响应、解除包含后仍无碰撞，或共同平移持续触发形状通知。新增对象应实际进入曲线轮廓/查询区域，避免仅凭 AABB 接近判断碰撞失败。
