# 连线背向端口时绕开节点

截图中上方节点的上端口连接下方节点的下端口，两端都背向对方。原来的三次曲线将负向控制距离压到零，结果退化成穿过节点的直线。

复用 Godot 原生 AStar2D 做两个端点矩形外侧的可见图寻路，Geometry2D 检查线段是否穿入端点。只增加必要的端点几何集成，不新增第三方依赖或自写搜索算法。保持保存的 UV 端口，端点背向时先向外离开，再绕行到目标外侧；正常相向连线继续使用现有曲线。预览、已保存线段、箭头和碰撞共用 connection_curve。此路由只避免两个端点，不承诺避开第三个节点；重叠端点可能无外侧通路，保留既有回退。

改动：line_edge.gd 接入 exterior_route.gd 原生路由适配；exterior_connections_smoke 覆盖截图对应的四种相对位置、固定端口和出入方向。Godot 文件通过 mcp__godot_mcp__read_script、modify_script、create_script、execute_editor_script 处理，未处理 tscn 文本。

用户授权自动调试后，新增测试修改前报 156 项穿入/方向错误，修改后通过。proportional_connections_smoke、smooth_connections_smoke、master_connection_ports_smoke 在工作区通过；独立暂存源通过前三项。master_connection_ports_smoke 对独立暂存源使用了未提交的接口，超时，不记为通过。reciprocal_connections_smoke 的共享线段断言在修改前后的工作区均失败，属已有问题，未混入本次修复。Linux release 导出通过。

尚未执行的手动检查：重新启动程序，连接上方节点的上边与下方节点的下边，再移动节点交换相对位置。应保留指定端口，连线绕外侧走，箭头停在边框，文字区域没有穿线。失败时检查预览和保存后是否不一致、拖动后是否又穿入、反向箭头是否偏离。
