extends SceneTree
## Reuse only immutable snapshots synchronized to the Stage document revision.
class CountingHistory extends "res://src/history.gd":
	var capture_count := 0
	func _capture_snapshot() -> Dictionary:
		capture_count += 1
		return super._capture_snapshot()

class GenericRoot extends Node2D:
	var value := 1
	func document_snapshot() -> Dictionary:
		return {"value": value}
	func restore_document_snapshot(snapshot: Dictionary) -> void:
		value = int(snapshot.value)

var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 4:
		await process_frame

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	stage.get_node("History").set_script(CountingHistory)
	root.add_child(stage)
	await settle()
	var history: CountingHistory = stage.history as CountingHistory
	var node: TextNode = stage.create_text_node("baseline", Vector2.ZERO, false)
	await settle()
	history.clear()
	history.capture_count = 0
	history.begin_transaction()
	history.begin_transaction()
	check(history.capture_count == 0, "Unchanged Stage starts and repeats a transaction without capture")
	check(history._transaction_snapshot == history._current_snapshot, "Reused transaction contains the synchronized baseline")
	history.commit(false)
	check(history.capture_count == 1 and history._undo_stack.is_empty(), "No-op commit captures once without an undo entry")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "No-op commit refreshes the reusable baseline")
	await history.cancel_transaction()
	await settle()

	var revision: int = stage.document_revision
	node.invalidate_geometry(false)
	check(stage.document_revision == revision, "Geometry-only invalidation does not change persistent revision")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Geometry-only invalidation preserves snapshot reuse")
	history.commit(false)

	node.text = "outside transaction"
	check(stage.document_revision > revision, "External persistent setter changes document revision")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 1, "External edit forces a fresh transaction capture")
	node.text = "inside transaction"
	history.commit(false)
	check(history._undo_stack.size() == 1, "Persistent edit is one history entry")
	await history.undo()
	await settle()
	check(node.text == "outside transaction", "Undo preserves the edit made before the transaction")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Undo marks the restored revision synchronized")
	await history.cancel_transaction()
	await settle()
	await history.redo()
	await settle()
	check(node.text == "inside transaction", "Redo restores the transaction edit")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Redo marks the restored revision synchronized")
	node.text = "cancelled"
	await history.cancel_transaction()
	await settle()
	check(node.text == "inside transaction", "Cancellation restores the reused immutable baseline")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Cancellation marks its restored revision synchronized")
	history.commit(false)

	var stale: Dictionary = stage.document_snapshot()
	stale.objects[0].properties.text = JSON.from_native("stale supplied snapshot")
	history.clear(stale)
	stale.objects[0].properties.text = JSON.from_native("caller mutated snapshot")
	check(history._current_snapshot.objects[0].properties.text == JSON.from_native("stale supplied snapshot"), "Clear owns caller-supplied values")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 1, "An arbitrary supplied clear snapshot is never revision-trusted")
	history.commit(false)
	check(history._current_snapshot.objects[0].properties.text == JSON.from_native("inside transaction"), "No-op after external baseline replaces old current snapshot")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Fresh no-op baseline can be reused")
	await history.cancel_transaction()
	await settle()

	var fresh: Dictionary = stage.document_snapshot()
	history.clear(fresh, stage.document_revision)
	fresh.objects[0].properties.text = JSON.from_native("caller mutation")
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Explicit fresh load revision enables reuse")
	check(history._transaction_snapshot.objects[0].properties.text == JSON.from_native("inside transaction"), "Trusted clear does not alias caller values")
	history.commit(false)
	history.clear(stage.document_snapshot(), stage.document_revision + 1)
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 1, "A mismatching supplied revision forces capture")
	history.commit(false)

	var path := "/tmp/pg-history-revision-%d.prg" % OS.get_process_id()
	check(ProjectFile.save(path, stage.document_snapshot(), {}).ok, "Local load fixture saves")
	check(await stage.load_from_file(path), "Local fixture reloads")
	await settle()
	history.capture_count = 0
	history.begin_transaction()
	check(history.capture_count == 0, "Complete load passes its fresh revision to History")
	history.commit(false)
	DirAccess.remove_absolute(path)

	var generic := GenericRoot.new()
	var generic_history := CountingHistory.new()
	generic.add_child(generic_history)
	root.add_child(generic)
	generic_history.capture_count = 0
	generic_history.begin_transaction()
	check(generic_history.capture_count == 1, "Generic targets always capture")
	generic_history.commit(false)
	generic_history.capture_count = 0
	generic_history.begin_transaction()
	check(generic_history.capture_count == 1, "Generic targets never adopt a Stage revision")
	generic_history.commit(false)
	generic.queue_free()
	stage.queue_free()
	await process_frame
	print("HISTORY_REVISION_REUSE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
