extends SceneTree
var failures: Array[String] = []
var done := false

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 8:
		await process_frame

func _undo(history: History) -> void:
	await history.undo()
	done = true

func _run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			path = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
	if path.is_empty():
		quit(2)
		return
	var hash_before := FileAccess.get_sha256(path)
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	GraphPreferences.set_value("welcome", false, false)
	var app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var stage: Stage = app.tabs.get_current_stage()
	check(await stage.load_from_file(path), "Fixture loads")
	await settle()
	var before := StageObjectRegistry.capture(stage)
	var instances := {}
	var node: TextNode
	for object in stage.stage_objects():
		instances[object.id] = object
		if node == null and object is TextNode:
			node = object
	var id := node.id
	var original := node.text
	stage.history.begin_transaction()
	node.text = original + " UNDO PROBE"
	stage.history.commit(false)
	await settle()
	var started := Time.get_ticks_usec()
	var previous := started
	var intervals: Array[float] = []
	_undo(stage.history)
	while not done:
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	await settle()
	var preserved := 0
	for object in stage.stage_objects():
		if object == instances[object.id]:
			preserved += 1
		if object.id == id:
			check(object.text == original, "Undo restores text")
	check(preserved == instances.size(), "Property undo preserves existing objects")
	check(StageObjectRegistry.capture(stage) == before, "Undo restores the full snapshot")
	check(not stage.history._busy and stage.history.can_redo(), "Undo unlocks and enables redo")
	print("UNDO_BENCHMARK: ", JSON.stringify({"objects": instances.size(), "undo_ms": elapsed,
		"max_frame_ms": intervals.max() if not intervals.is_empty() else 0.0, "preserved": preserved}))
	await stage.history.redo()
	await settle()
	for object in stage.stage_objects():
		if object.id == id:
			check(object.text == original + " UNDO PROBE", "Redo restores edit")

	# Creation plus rebinding an existing edge must be one reversible transaction.
	var source: TextNode
	var edge: LineEdge
	for object in stage.stage_objects():
		if object.id == id:
			source = object
		if edge == null and object is LineEdge:
			edge = object
	var edit_snapshot := StageObjectRegistry.capture(stage)
	stage.history.begin_transaction()
	var child := stage.create_text_node("Undo topology probe", source.position + Vector2(300, 100), false)
	child.topic_parent = source
	var child_id := child.id
	edge.target = child
	stage.history.commit(false)
	await settle()
	var created_snapshot := StageObjectRegistry.capture(stage)
	await stage.history.undo()
	await settle()
	check(StageObjectRegistry.capture(stage) == edit_snapshot, "Creation undo restores object order and references")
	await stage.history.redo()
	await settle()
	check(StageObjectRegistry.capture(stage) == created_snapshot, "Creation redo restores references to recreated nodes")
	var recreated: TextNode
	for object in stage.stage_objects():
		if object.id == child_id:
			recreated = object
	check(recreated != null and recreated.topic_parent == source, "Recreated topic parent resolves to the existing node")
	check(edge.target == recreated, "Preserved edge points to recreated node")
	stage.delete_objects([recreated])
	await settle()
	stage.history._finish_commit()
	var deleted_snapshot := StageObjectRegistry.capture(stage)
	await stage.history.undo()
	await settle()
	check(StageObjectRegistry.capture(stage) == created_snapshot, "Deletion undo restores removed nodes and edges")
	await stage.history.redo()
	await settle()
	check(StageObjectRegistry.capture(stage) == deleted_snapshot, "Deletion redo removes the same objects")
	var stable := StageObjectRegistry.capture(stage)
	var stack_size := stage.history._undo_stack.size()
	stage.history.begin_transaction()
	source.text += " CANCEL"
	await stage.history.cancel_transaction()
	await settle()
	check(StageObjectRegistry.capture(stage) == stable, "Cancellation restores the live edit")
	check(stage.history._undo_stack.size() == stack_size, "Cancellation does not consume history")
	check(FileAccess.get_sha256(path) == hash_before, "Source file stays unchanged")
	app.queue_free()
	await process_frame
	print("UNDO_INCREMENTAL: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
