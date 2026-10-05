extends SceneTree
const Model = preload("res://src/storage/graph_document.gd")
const Codec = preload("res://src/storage/project_document.gd")
const Blob = preload("res://src/storage/project_blob.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func node(identifier: String, references: Dictionary = {}) -> Dictionary:
	return {"id": identifier, "type": "text_node", "properties": {"text": identifier},
		"references": references, "assets": {}, "transform": {"position": Vector2.ZERO,
		"rotation": 0.0, "scale": Vector2.ONE}}

func _run() -> void:
	var model := Model.new()
	var group := node("group")
	var child := node("child", {"container": "group"})
	var distant := node("distant", {"topic_parent": "child"})
	var edge := node("edge", {"source": "child", "target": "distant"})
	edge.type = "line_edge"
	check(model.replace_document({"schema": 1, "camera": {}, "objects": [group, child, distant, edge]}, {}).ok, "Complete model loads without views")
	var one_view: Dictionary = Codec.to_snapshot({"objects": [child], "camera": {}}, {})
	one_view.objects[0].properties.text = JSON.from_native("changed in one view")
	check(model.reconcile_views(one_view, PackedStringArray(["child"])).ok, "Partial view edits reconcile")
	check(model.ids().size() == 4 and model.record("distant") == distant, "Never instantiated records and references survive reconciliation")
	check(model.find_text("changed") == PackedStringArray(["child"]), "Search uses complete model")
	var baseline := model.native_document()
	check(model.reconcile_views({"objects": []}, PackedStringArray()).ok and model.native_document() == baseline, "Recycling views preserves the document")
	check(not model.reconcile_views({"objects": []}, PackedStringArray(["child"])).ok and model.native_document() == baseline, "Invalid partial deletion is atomic")
	check(model.move_subtrees(PackedStringArray(["group"]), Vector2(300, 40)).ok, "Whole container subtree moves without views")
	check(model.record("group").transform.position == Vector2(300, 40) and model.record("child").transform.position == Vector2(300, 40), "Uninstantiated descendants move")
	check(model.record("distant").transform.position == Vector2.ZERO, "Topic references remain separate from containment")
	check(model.remove_ids(PackedStringArray(["group"])).ok, "Container deletion cascades atomically")
	check(model.ids() == PackedStringArray(["distant"]) and model.record("distant").references.is_empty(), "Endpoint edges and orphan topic references are removed")
	model.replace_document({"schema": 1, "camera": {}, "objects": [group, child, distant, edge]}, {})
	check(model.remove_ids(PackedStringArray(["group"]), true).ok and model.ids().size() == 3, "Preserve-content deletion keeps distant members and edges")
	check(not model.record("child").references.has("container"), "Preserved child reparents to surviving owner")
	var data := PackedByteArray([1, 2, 3, 4])
	var asset_id := Blob.digest(data)
	var handle := Blob.new("/tmp/this-document-block-does-not-exist.prg", {"offset": 32, "length": 4, "sha256": asset_id})
	var image := node("image")
	image.type = "legacy_asset"
	image.properties = {"asset_size": Vector2(100, 100)}
	image.assets = {"image_bytes": asset_id}
	model.replace_document({"schema": 1, "camera": {}, "objects": [image]}, {asset_id: handle})
	var copy := Model.new()
	check(copy.replace_snapshot(model.snapshot()).ok and not handle._loaded, "Snapshot adapters preserve lazy image handles without I/O")
	check(copy.native_document() == model.native_document(), "Lazy asset identity survives round trip")
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	root.add_child(stage)
	var a := stage.create_text_node("live", Vector2.ZERO, false)
	var b := stage.create_text_node("offscreen", Vector2(5000, 0), false)
	a.freeze = true
	b.freeze = true
	stage.select_ids(PackedStringArray())
	var hidden_id := b.id
	var path := "/tmp/pg-authority-stage.prg"
	check(stage.save_to_file(path), "Stage saves complete baseline")
	stage.release_document_views(PackedStringArray([hidden_id]))
	await process_frame
	check(stage.stage_objects().size() == 1 and stage.document_model.ids().size() == 2, "Stage can recycle a view without deleting its record")
	check(not stage.is_dirty(), "View lifecycle does not dirty the file")
	check(stage.object_counts() == Vector2i(2, 0), "Counts include uninstantiated records")
	stage.history.begin_transaction()
	a.text = "edited"
	stage.history.commit(false)
	await stage.history.undo()
	check(a.text == "live" and stage.document_model.find_text("offscreen").size() == 1, "Undo restores the model and preserves unseen objects")
	check(stage.stage_objects().size() == 1, "Undo does not instantiate unchanged offscreen records")
	await stage.history.redo()
	check(a.text == "edited", "Redo updates the active view")
	check(stage.save_to_file(path), "Saving partial views succeeds")
	var loaded := ProjectFile.load(path)
	check(loaded.ok and loaded.graph.objects.size() == 2, "Saving partial views retains the entire document")
	stage.select_ids(PackedStringArray([hidden_id]))
	check(stage.selected_objects().size() == 1 and stage.selected_objects()[0].text == "offscreen", "Selecting an unseen record prepares its view")
	check(not stage.is_dirty(), "Materialization leaves saved content clean")
	stage.select_ids(PackedStringArray())
	stage.release_document_views(PackedStringArray([hidden_id]))
	await stage.delete_document_ids(PackedStringArray([hidden_id]), true)
	check(stage.document_model.ids().size() == 1, "Deletion operates on an uninstantiated record")
	await stage.history.undo()
	check(stage.document_model.find_text("offscreen").size() == 1, "Undo restores deleted offscreen content")
	stage.queue_free()
	await process_frame
	for suffix in ["", ".previous"]:
		DirAccess.remove_absolute(path + suffix)
	print("DOCUMENT_AUTHORITY: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
