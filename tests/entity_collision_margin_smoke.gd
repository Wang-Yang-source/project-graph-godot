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
func _run() -> void:
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	var a: TextNode = stage.create_text_node("A", Vector2.ZERO, false)
	a.fixed_width = 160
	await frames(8)
	var visual := a.global_transform * a.get_visual_rect()
	check(a.aabb.is_equal_approx(visual), "Editor bounds keep the visible frame")
	var outer := a.get_node_or_null("PhysicsMargin") as CollisionShape2D
	check(outer != null, "Entity owns an invisible native collision frame")
	if outer != null:
		var frame: Rect2 = outer.global_transform * outer.shape.get_rect()
		check(frame.size.is_equal_approx(visual.size + Vector2(2, 2)), "Collision frame adds one unit per side")
		check(a.collision_shape.disabled, "Only the outer frame participates in contacts")
	var b: TextNode = stage.create_text_node("B", Vector2(visual.end.x + 0.5, 0), false)
	b.fixed_width = 160
	await frames(120)
	var gap := b.aabb.position.x - a.aabb.end.x
	check(gap > 1.5, "Visually separated nodes repel before their visible frames touch")
	check(a.aabb.size.is_equal_approx(visual.size), "Repulsion does not enlarge editor bounds")
	a.text = "Changed width"
	a.fixed_width = 240
	await frames(8)
	if outer != null:
		check((outer.shape as RectangleShape2D).size.is_equal_approx(a.get_visual_rect().size + Vector2(2,2)), "Collision frame follows text resize")
	var asset: Entity = load("res://src/stage_object/entity/legacy_asset/legacy_asset.tscn").instantiate()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	asset.image_base64 = Marshalls.raw_to_base64(image.save_png_to_buffer())
	asset.position = Vector2(1000, 1000)
	stage.add_child(asset)
	var pen: PenStroke = load("res://src/stage_object/entity/pen_stroke/pen_stroke.tscn").instantiate()
	pen.position = Vector2(2000, 1000)
	pen.points = PackedVector2Array([Vector2.ZERO, Vector2(100, 100)])
	stage.add_child(pen)
	await frames(8)
	check(asset.has_node("PhysicsMargin") and pen.has_node("PhysicsMargin"), "Asset and pen entities also have collision frames")
	stage.queue_free()
	await process_frame
	print("ENTITY_COLLISION_MARGIN: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
