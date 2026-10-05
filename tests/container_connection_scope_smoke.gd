extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _run() -> void:
	GraphPreferences.set_value("physics",false,false)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var group := stage.create_text_node("Group",Vector2.ZERO,false)
	var other_group := stage.create_text_node("Other group",Vector2(800,0),false)
	var a := stage.create_text_node("A",Vector2(0,150),false)
	var b := stage.create_text_node("B",Vector2(240,150),false)
	var outside := stage.create_text_node("Outside",Vector2(800,500),false)
	a.container = group
	b.container = group
	for frame in 10: await process_frame
	stage.history.clear()
	for pair in [[a,outside],[outside,a],[a,other_group],[a,group]]:
		check(stage.connect_entities(pair[0],pair[1]) == null, "Internal nodes cannot connect across their group boundary")
	check(stage.connect_entities(a,b) != null, "Same-group members can connect")
	check(stage.connect_entities(group,other_group) != null, "Group wrappers can connect on their shared outer layer")
	var creator := stage.get_node("LineEdgeCreator") as LineEdgeCreator
	creator.set_process(false)
	var before := StageObjectRegistry.capture(stage)
	creator._start_drag(a,a.position)
	creator._update_preview(outside.position)
	check(creator._target == null and not creator._target_edge_highlight.visible, "Forbidden outside target is never highlighted as connectable")
	creator._finish_drag()
	for frame in 6: await process_frame
	check(StageObjectRegistry.capture(stage) == before, "Invalid gesture creates no edge")
	check(not stage.history.can_undo(), "Rejected cross-group gesture adds no undo entry")
	stage.queue_free()
	await process_frame
	print("CONTAINER_CONNECTION_SCOPE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
