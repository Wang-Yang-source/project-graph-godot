extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 6: await process_frame
func _run() -> void:
	GraphPreferences.set_value("physics", false, false)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	await settle()
	var a := stage.create_text_node("A", Vector2(-300,0), false)
	var b := stage.create_text_node("B", Vector2(300,120), false)
	a.freeze = true
	b.freeze = true
	await settle()
	stage.history.clear()
	var creator := stage.get_node("LineEdgeCreator") as LineEdgeCreator
	creator._start_drag(a,a.position)
	creator._update_preview(b.position)
	creator._finish_drag()
	var edge := stage.connect_entities(a,b)
	check(edge._creation_tween != null and edge._creation_progress < 1.0, "Real connection gesture starts a native Tween")
	var snapshot := StageObjectRegistry.capture(stage)
	var collision := (edge.collision_shape.shape as ConcavePolygonShape2D).segments.duplicate()
	var full := edge.line.global_transform.affine_inverse() * edge._shaft_points
	edge._set_creation_progress(0.25)
	var first_length := edge.line.points.size()
	check(edge.line.points[0].is_equal_approx(full[0]), "Reveal starts at source")
	check(not edge.line.points[edge.line.points.size()-1].is_equal_approx(full[full.size()-1]), "Partial reveal stops before target")
	check(edge.arrow_head.modulate.a == 0.0, "Arrow waits for line arrival")
	edge._set_creation_progress(0.75)
	check(edge.line.points.size() >= first_length, "Reveal grows along the curve")
	check(edge.get_node("Caption").modulate.a > 0.0, "Caption fades in during creation")
	check((edge.collision_shape.shape as ConcavePolygonShape2D).segments == collision, "Presentation animation preserves collision geometry")
	check(StageObjectRegistry.capture(stage) == snapshot, "Animation never enters saved document values")
	var same := stage.connect_entities(a,b,true)
	check(same == edge and edge._creation_progress == 0.75, "Duplicate connection does not replay the animation")
	stage.camera.zoom = Vector2.ONE * 2.0
	stage.camera.target_zoom = stage.camera.zoom
	b.move_without_inertia(Vector2(400,180))
	await settle()
	await create_timer(0.4).timeout
	check(edge._creation_progress == 1.0 and edge._creation_tween == null, "Animation ends and releases its Tween")
	full = edge.line.global_transform.affine_inverse() * edge._shaft_points
	check(edge.line.points == full, "Completion restores exact full geometry after zoom and endpoint movement")
	check(edge.arrow_head.modulate.a == 1.0 and edge.get_node("Caption").modulate.a == 1.0, "Completion restores normal opacity")
	var quiet := stage.connect_entities(b,a)
	await settle()
	check(quiet._creation_tween == null and quiet._creation_progress == 1.0, "Ordinary construction has no load animation")
	var c := stage.create_text_node("C", Vector2(600,0), false)
	var disposable := stage.connect_entities(a,c,true)
	disposable.queue_free()
	await settle()
	check(not is_instance_valid(disposable), "Deleting an animated edge releases its Tween safely")
	stage.queue_free()
	await process_frame
	print("EDGE_CREATION_ANIMATION: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
