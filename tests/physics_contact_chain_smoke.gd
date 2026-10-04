extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var members: Array[TextNode] = []
	for index in 4:
		members.append(stage.create_text_node(str(index), Vector2(0, index * 80), false))
	var far := stage.create_text_node("unrelated", Vector2(5000, 0), false)
	stage.select_ids(PackedStringArray())
	for frame in 8:
		await physics_frame
	var before := StageObjectRegistry.capture(stage)
	stage.history.begin_transaction()
	members[0].drag_controlled = true
	members[0]._drag_target = Vector2(0, 200)
	for frame in 240:
		await physics_frame
	for index in range(1, 4):
		check(members[index].position.y > index * 80 + 1, "Native contacts must propagate through the complete chain")
	check(far.position == Vector2(5000, 0) and far.freeze, "Contact propagation must not activate unrelated records")
	members[0].drag_controlled = false
	stage.history.commit(false)
	var after := StageObjectRegistry.capture(stage)
	check(stage.history._undo_stack.size() == 1, "Propagated movement is one history transaction")
	await stage.history.undo()
	check(StageObjectRegistry.capture(stage) == before, "Undo restores every propagated contact")
	await stage.history.redo()
	check(StageObjectRegistry.capture(stage) == after, "Redo restores every propagated contact")
	stage.queue_free()
	await process_frame
	print("PHYSICS_CONTACT_CHAIN: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
