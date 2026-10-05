extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func hits(node: Entity, point: Vector2) -> bool:
	var physical := node.get_node_or_null("PhysicsOutline") as CollisionShape2D
	if physical == null:
		physical = node.get_node_or_null("PhysicsMargin") as CollisionShape2D
	if physical == null or physical.shape == null:
		return false
	var probe := CircleShape2D.new()
	probe.radius = 0.05
	return physical.shape.collide(physical.global_transform,probe,Transform2D(0.0,node.to_global(point)))

func _run() -> void:
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	var node: TextNode = stage.create_text_node("Rounded collision", Vector2.ZERO, false)
	await frames(8)
	var physical := node.get_node_or_null("PhysicsOutline") as CollisionShape2D
	check(physical != null and physical.shape is ConvexPolygonShape2D, "Native polygon matches the rounded node")
	var rect := node.get_visual_rect()
	check(not hits(node, rect.position + Vector2(0.5,0.5)), "Empty visible corner is also empty in native collision")
	check(hits(node, rect.get_center()), "Visible center keeps native collision")
	check(not hits(node, Vector2(rect.position.x - 0.5,rect.get_center().y)), "No invisible outer padding remains")
	check(node.aabb.is_equal_approx(node.global_transform * rect), "Editor bounds still match visible bounds")
	stage.select_object(node)
	stage._refresh_selection_outlines()
	check(stage.selected_ids.has(node.id), "Selection still works")
	check(not stage._selection_lines.has(node.id), "No translucent selection frame is drawn")
	node.fixed_width = 260
	await frames(8)
	if physical != null and physical.shape is ConvexPolygonShape2D:
		check(physical.shape.get_rect().size.is_equal_approx(node.get_visual_rect().size), "Rounded collision follows resizing")
	check(not hits(node,node.get_visual_rect().position + Vector2(0.5,0.5)), "Resized corner stays empty")
	stage.queue_free()
	await process_frame
	print("ROUNDED_ENTITY_COLLISION: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
