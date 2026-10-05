extends SceneTree
const Delta = preload("res://src/storage/snapshot_delta.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func record(identifier: String, text: String) -> Dictionary:
	return {"type":"text_node","transform":{"position":[0.0,0.0]},"properties":{"id":JSON.from_native(identifier),"text":JSON.from_native(text)}}
func _run() -> void:
	var before := {"objects":[],"metadata":{"name":"before"}}
	for i in 1000:
		before.objects.append(record(str(i), "unchanged"))
	var after := before.duplicate(true)
	after.objects[400].properties.text = JSON.from_native("edited")
	var delta := Delta.between(before, after)
	check(delta.ok and delta.changes.size() == 1, "One changed record retained for 1000-object document")
	check(not delta.has("before") and not delta.has("after"), "History entry does not retain complete snapshots")
	check(Delta.apply(after, delta, false).snapshot == before, "Undo restores full content")
	check(Delta.apply(before, delta, true).snapshot == after, "Redo restores full content")
	var modified := after.duplicate(true)
	modified.objects[400].properties.text = JSON.from_native("another editor")
	check(not Delta.apply(modified, delta, false).ok, "Conflicting baseline rejected")
	var changed := before.duplicate(true)
	changed.objects.remove_at(30)
	changed.objects.insert(12, record("new", "created"))
	changed.objects.reverse()
	changed.metadata.name = "after"
	var topology := Delta.between(before, changed)
	check(topology.changes.size() == 2, "Creation and removal retained without unrelated records")
	check(Delta.apply(changed, topology, false).snapshot == before, "Deletion undo restores exact order and metadata")
	check(Delta.apply(before, topology, true).snapshot == changed, "Reorder and creation redo")
	var invalid := before.duplicate(true)
	invalid.objects[1].properties.id = invalid.objects[0].properties.id
	check(not Delta.between(before, invalid).ok, "Duplicate identities reject compact history")
	var saved_change: Dictionary = delta.changes[0].after.duplicate(true)
	after.objects[400].properties.text = JSON.from_native("external mutation")
	check(delta.changes[0].after == saved_change, "Changed records own their history values")
	print("HISTORY_DELTA: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
