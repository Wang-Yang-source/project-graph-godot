# 连线曲率

移除贝塞尔控制柄固定 96 世界单位的上限，分别按照两个端点法线方向上的距离计算控制柄。长连线弯曲随间距延展，反向连接保持相同曲线形状。继续复用 Godot Curve2D 原生自适应细分、Line2D 和 Polygon2D，没有新增依赖，也没有修改持久化格式。

使用 Godot MCP 脚本读取、创建、修改、编辑器脚本执行工具。proportional_connections_smoke 修改前失败（63 项比例断言），修改后通过；smooth_connections_smoke、navigation_cache_smoke、edge_caption_smoke、edit_text_alignment_smoke 均通过。已生成并检查实际节点图渲染，覆盖 shift、ctrl、alt 组合关系、不同端点方向及箭头。

手动验证（尚未执行）：启动修改后的项目，打开快捷键示例图，拖动节点拉长、缩短及改变连接方向，再缩放。应看到曲线平顺延展、近距离无回钩、箭头贴合节点轮廓、文字标签跟随曲线；若失败，重点检查急弯、反向回折、箭头进入节点内部或标签偏离。
