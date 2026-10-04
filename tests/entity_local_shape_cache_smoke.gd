extends SceneTree
## Run only through the authorized Godot MCP regression runner.
class OutlineProbe:
	extends TextNode
	var outline_reads := 0

	func get_visual_outline() -> PackedVector2Array:
		outline_reads += 1
		return super.get_visual_outline()


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func hits(node: TextNode, local_point: Vector2) -> bool:
	var outline := node.get_node("PhysicsOutline") as CollisionShape2D
	var probe := CircleShape2D.new()
	probe.radius = 0.05
	return outline.shape.collide(
		outline.global_transform, probe, Transform2D(0.0, node.to_global(local_point)))


func _run() -> void:
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var node := StageObjectRegistry.get_scene("text_node").instantiate() as TextNode
	node.set_script(OutlineProbe)
	node.text = "Local hull"
	stage.add_child(node)
	stage.apply_object_preferences(node)
	await frames(8)
	var outline := node.get_node("PhysicsOutline") as CollisionShape2D
	var shape := outline.shape
	var reads: int = node.get("outline_reads")
	for step in 12:
		node.position += Vector2(12.5, -7.25)
		node._refresh_collision_outline()
	check(node.get("outline_reads") == reads, "Pure translation does not reconstruct the local outline")
	check(outline.shape == shape, "Translation keeps the native collision resource")
	check(hits(node, node.get_visual_rect().get_center()), "Translated center remains hittable")
	var rect := node.get_visual_rect()
	check(not hits(node, rect.position + Vector2(0.5, 0.5)), "Rounded empty corner remains empty")
	node.rotation = 0.3
	node.scale = Vector2(1.2, 0.9)
	node._refresh_collision_outline()
	check(node.get("outline_reads") == reads, "World basis changes reuse unchanged local hull")
	check(hits(node, rect.get_center()), "Native collision follows the world basis")
	node.fixed_width = node.get_visual_rect().size.x + 90.0
	await frames(6)
	node._refresh_collision_outline()
	check(node.get("outline_reads") > reads, "Resizing rebuilds the local hull")
	check(outline.shape.get_rect().size.is_equal_approx(node.get_visual_rect().size), "Resized hull matches the visual size")
	reads = node.get("outline_reads")
	var style := StyleBoxFlat.new()
	node.label.add_theme_stylebox_override("normal", style)
	node._refresh_collision_outline()
	check(node.get("outline_reads") > reads, "Same-size corner changes invalidate the hull")
	check(hits(node, node.get_visual_rect().position + Vector2(0.5, 0.5)), "Square corner is hittable after radius change")
	reads = node.get("outline_reads")
	outline.shape = RectangleShape2D.new()
	node._refresh_collision_outline()
	check(node.get("outline_reads") > reads, "Replacing the native shape cannot reuse stale cache")
	check(outline.shape is ConvexPolygonShape2D, "Native hull recovers after shape replacement")
	stage.queue_free()
	await process_frame
	print("ENTITY_LOCAL_SHAPE_CACHE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
