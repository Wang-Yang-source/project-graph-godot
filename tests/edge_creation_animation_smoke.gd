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
	var a_id := a.id
	var snapshot := StageObjectRegistry.capture(stage)
	var creator := stage.get_node("LineEdgeCreator") as LineEdgeCreator
	creator.set_process(false)
	creator._start_drag(a,a.position)
	creator._update_preview(a.position + Vector2(2,0))
	check(not creator._preview_line.visible and creator._preview_tween == null, "A click does not flash an animated preview")
	creator._update_preview(b.position)
	check(creator._preview_tween != null, "Dragging animates the preview before a saved edge exists")
	check(StageObjectRegistry.capture(stage) == snapshot, "Preview does not change persistent objects")
	creator._set_preview_progress(0.25)
	var tip: Vector2 = creator._preview_line.points[creator._preview_line.points.size()-1]
	check(tip.distance_to(creator.to_local(b.position)) > 50, "Preview grows from the source instead of appearing as a complete connection")
	creator._set_preview_progress(1.0)
	check(creator._preview_line.points[creator._preview_line.points.size()-1].is_equal_approx(creator.to_local(b.position)), "Provisional tip follows cursor rather than a final target port")
	var next := b.position + Vector2(15,5)
	creator._update_preview(next)
	check(creator._preview_line.points[creator._preview_line.points.size()-1].is_equal_approx(creator.to_local(next)), "Mouse movement continuously updates the preview")
	check(creator._target == b and creator._target_edge_highlight.visible, "Target remains identifiable during provisional drawing")
	creator.cancel_drag()
	check(creator._preview_tween == null and creator._preview_line.points.is_empty() and not creator._preview_line.visible, "Cancel clears the Tween and transient geometry")
	check(StageObjectRegistry.capture(stage) == snapshot and not stage.history.can_undo(), "Cancel adds no document or history changes")
	creator._start_drag(a,a.position)
	creator._update_preview(b.position)
	await create_timer(0.25).timeout
	check(creator._preview_tween == null and creator._preview_progress == 1.0, "Preview animation finishes while still dragging")
	creator._finish_drag()
	while stage.history._pending_commit:
		await physics_frame
		await process_frame
	await settle()
	var edge := stage.connect_entities(a,b)
	check(edge.line.points == edge.line.global_transform.affine_inverse() * edge._shaft_points, "Release immediately displays the completed connection")
	check(creator._preview_tween == null and not creator._preview_line.visible, "Release removes preview feedback")
	check(stage.history._undo_stack.size() == 1, "Connection remains one undo step")
	await stage.history.undo()
	await settle()
	check(StageObjectRegistry.capture(stage) == snapshot, "Undo removes only the created connection")
	for object in stage.stage_objects():
		if object.id == a_id: a = object
	creator._start_drag(a,a.position)
	creator._update_preview(Vector2(600,600))
	creator._finish_drag()
	await settle()
	check(StageObjectRegistry.capture(stage) == snapshot, "Releasing over empty space creates no edge")
	stage.queue_free()
	await process_frame
	print("EDGE_PREVIEW_ANIMATION: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
