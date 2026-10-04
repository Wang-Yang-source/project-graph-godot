extends SceneTree

class CountedStage extends Stage:
	var snapshot_calls := 0
	func document_snapshot() -> Dictionary:
		snapshot_calls += 1
		return super.document_snapshot()

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame in 8:
		await physics_frame
		await process_frame

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	stage.set_script(CountedStage)
	root.add_child(stage)
	var node := stage.create_text_node("Dirty polling", Vector2.ZERO, false)
	node.freeze = true
	await settle()
	stage.document_snapshot()
	stage._saved_document = stage.document_model.native_document().duplicate(true)
	stage._dirty_revision = -1
	check(not stage.is_dirty(), "Saved baseline is clean")
	check(stage.object_counts() == Vector2i(1, 0), "Initial complete membership is counted")
	stage.history.begin_transaction()
	stage.snapshot_calls = 0
	node.global_position = Vector2(40, 20)
	for poll in 10:
		check(stage.is_dirty(), "Changed gesture displays the unsaved marker")
		check(stage.object_counts() == Vector2i(1, 0), "Movement preserves counts without capture")
	check(stage.snapshot_calls == 0, "Dirty polling does not capture the document during a gesture")
	await stage.history.cancel_transaction()
	await settle()
	stage.snapshot_calls = 0
	check(not stage.is_dirty(), "Cancel restores the precise clean state")
	check(stage.snapshot_calls == 1, "After cancellation the pending revision receives an exact comparison")
	for object in stage.stage_objects():
		if object is TextNode:
			node = object
			break
	stage.history.begin_transaction()
	node.global_position = Vector2(60, 30)
	check(stage.is_dirty(), "New gesture becomes dirty")
	stage.history.commit(false)
	check(stage.is_dirty(), "Committed movement remains dirty")
	stage.history.undo()
	await settle()
	check(not stage.is_dirty(), "Undo returns to the saved baseline")
	var second := stage.create_text_node("Added", Vector2(400, 0), false)
	check(stage.object_counts() == Vector2i(2, 0), "Creation changes membership count")
	var edge := stage.connect_entities(node, second)
	check(stage.object_counts() == Vector2i(2, 1), "New edge is counted")
	stage.snapshot_calls = 0
	stage.document_snapshot()
	var held_id := second.id
	stage.release_document_views(PackedStringArray([edge.id, held_id]))
	await process_frame
	check(stage.object_counts() == Vector2i(2, 1), "Recycled views remain complete document members")
	stage.materialize_document_ids(PackedStringArray([held_id]))
	check(stage.object_counts() == Vector2i(2, 1), "Materialization does not duplicate membership")
	stage.snapshot_calls = 0
	for poll in 10:
		check(stage.object_counts() == Vector2i(2, 1), "Repeated membership query is stable")
	check(stage.snapshot_calls == 0, "Membership reads do not serialize document")
	await stage.delete_document_ids(PackedStringArray([held_id]))
	await settle()
	check(stage.object_counts() == Vector2i(1, 0), "Cascade deletion updates complete counts")
	stage.history.undo()
	await settle()
	check(stage.object_counts() == Vector2i(2, 1), "Undo restores complete counts")
	stage.queue_free()
	await process_frame
	print("UI_READ_POLL: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
