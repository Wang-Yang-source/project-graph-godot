extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var app: Node = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	for frame in 15:
		await process_frame
	GraphPreferences.set_value("physics", false, false)
	GraphPreferences.set_value("effects", false, false)
	var stage: Stage = app.tabs.get_current_stage()
	stage.apply_preferences()
	stage.group_overview.camera_scale_threshold = .001
	var group := stage.create_text_node("Group", Vector2.ZERO, false)
	var first := stage.create_text_node("First", Vector2(0, 150), false)
	var second := stage.create_text_node("Second", Vector2(400, 150), false)
	first.container = group
	second.container = group
	var edge := stage.connect_entities(first, second)
	for frame in 10:
		await process_frame
	var group_id := group.id
	var first_id := first.id
	var second_id := second.id
	var edge_id := edge.id
	var slicer: StageObjectSlicer = stage.get_node("StageObjectSlicer")
	slicer.set_process(false)
	var center := first.aabb.get_center()
	var start := Vector2(center.x, first.aabb.position.y - 15)
	var end := Vector2(center.x, first.aabb.end.y + 15)
	check(not slicer._is_point_on_stage_object(start), "Expanded group whitespace permits starting a cut")
	check(slicer._is_point_on_stage_object(group.label.global_position + group.label.size / 2), "Group title remains an interaction target")
	check(slicer._segment_intersects_collision_box(group.to_global(group.get_visual_rect().position - Vector2(15, 0)), group.label.global_position + group.label.size / 2, group), "Crossing the group title still targets the group")
	stage.history.clear()
	var before := StageObjectRegistry.capture(stage)
	slicer._slice_start = start
	slicer._is_slicing = true
	slicer._update_slice_endpoint(end)
	check(slicer._slice_targets.has(first), "Cut finds the member")
	check(not slicer._slice_targets.has(group), "Interior cut does not target the containing group")
	check(not slicer._slice_targets.has(second), "Cut avoids the sibling")
	slicer._finish_slice()
	for frame in 10:
		await process_frame
	check(stage.history._undo_stack.size() == 1, "Deletion has one history entry")
	var ids := PackedStringArray()
	for object in stage.stage_objects():
		ids.append(object.id)
	check(ids.has(group_id) and ids.has(second_id), "Group and sibling survive")
	check(not ids.has(first_id) and not ids.has(edge_id), "Member and its connected edge are deleted")
	var after := StageObjectRegistry.capture(stage)
	await stage.history.undo()
	for frame in 10:
		await process_frame
	check(StageObjectRegistry.capture(stage) == before, "Undo restores member, containment and edge")
	await stage.history.redo()
	for frame in 10:
		await process_frame
	check(StageObjectRegistry.capture(stage) == after, "Redo restores deletion")
	app.queue_free()
	await process_frame
	print("SLICE_GROUP: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
