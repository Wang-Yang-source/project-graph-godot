extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 10: await process_frame
func _run() -> void:
	GraphPreferences.set_value("physics",true,false)
	GraphPreferences.set_value("effects",false,false)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	stage.group_overview.camera_scale_threshold = 0.001
	var outer := stage.create_text_node("Outer",Vector2(0,-200),false)
	var group := stage.create_text_node("Group",Vector2.ZERO,false)
	var a := stage.create_text_node("Test01",Vector2(0,150),false)
	var b := stage.create_text_node("Target",Vector2(400,150),false)
	group.container = outer
	a.container = group
	b.container = group
	var edge := stage.connect_entities(a,b)
	edge.text = "Dependency"
	await settle()
	stage.get_node("EntityLayerMover").refresh_layout()
	stage.history.clear()
	var before := StageObjectRegistry.capture(stage)
	var positions := {a.id:a.position,b.id:b.position,outer.id:outer.position}
	var a_id := a.id
	var b_id := b.id
	var group_id := group.id
	var outer_id := outer.id
	var edge_id := edge.id
	var slicer := stage.get_node("StageObjectSlicer") as StageObjectSlicer
	slicer.set_process(false)
	var rect := group.aabb
	slicer._slice_start = Vector2(rect.end.x+5,a.position.y)
	slicer._is_slicing = true
	slicer._update_slice_endpoint(a.position)
	check(slicer._slice_targets.has(group), "Fixture cuts the group border")
	check(not slicer._slice_targets.has(a) and not slicer._slice_targets.has(b) and not slicer._slice_targets.has(edge), "Opening the wrapper protects directly crossed content")
	slicer._finish_slice()
	while stage.history._pending_commit:
		await physics_frame
		await process_frame
	await settle()
	var live := {}
	for object in stage.stage_objects(): live[object.id] = object
	check(not live.has(group_id), "Cut removes only the group wrapper")
	check(live.has(a_id) and live.has(b_id) and live.has(edge_id), "Cut preserves members and their connection")
	if live.has(a_id) and live.has(b_id) and live.has(outer_id):
		check(live[a_id].text == "Test01" and live[b_id].text == "Target", "Member content stays unchanged")
		check(live[a_id].container == live[outer_id] and live[b_id].container == live[outer_id], "Members are promoted to the enclosing group")
		for id in positions: check(live[id].position.is_equal_approx(positions[id]), "Cut does not move contents")
	if live.has(edge_id): check(live[edge_id].text == "Dependency", "Relationship annotation stays unchanged")
	check(stage.history._undo_stack.size() == 1, "Ungroup is one undo step")
	var after := StageObjectRegistry.capture(stage)
	await stage.history.undo()
	await settle()
	check(StageObjectRegistry.capture(stage) == before, "Undo restores the original group and content")
	await stage.history.redo()
	await settle()
	check(StageObjectRegistry.capture(stage) == after, "Redo restores ungrouped content")
	stage.queue_free()
	await process_frame
	print("SLICE_UNGROUP: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
