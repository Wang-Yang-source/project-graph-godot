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
	stage.set_process(false)
	var group := stage.create_text_node("group", Vector2.ZERO, false)
	var child := stage.create_text_node("hidden child", Vector2(200, 200), false)
	var other := stage.create_text_node("outside", Vector2(5000, 0), false)
	child.container = group
	var edge := stage.connect_entities(group, child)
	var ids := PackedStringArray([group.id, child.id, other.id, edge.id])
	var group_id := group.id
	var child_id := child.id
	stage.document_snapshot()
	var expected_components := WorkspaceActions.graph_components(stage)
	var expected_text := {}
	for format in ["markdown", "tree", "network", "mermaid"]:
		expected_text[format] = WorkspaceActions.export_text(stage, format, false)
	stage.release_document_views(ids)
	await process_frame
	check(stage.stage_objects().is_empty(), "Fixture has no instantiated views")
	for format in expected_text:
		check(WorkspaceActions.export_text(stage, format, false) == expected_text[format], "Complete " + format + " export survives view recycling")
	check(WorkspaceActions.graph_components(stage) == expected_components, "Outline components survive view recycling")
	stage.select_ids(PackedStringArray([group_id]))
	WorkspaceActions.copy_selection(stage)
	check(WorkspaceActions.clipboard.objects.size() == 3, "Copy includes hidden container child and internal edge, excludes outside node")
	check(WorkspaceActions.clipboard_text == "group", "Clipboard text retains explicit selection semantics")
	check(stage.stage_objects().is_empty(), "Copy, outline and text exports create no views")
	var copy_ids := PackedStringArray()
	for object in WorkspaceActions.clipboard.objects:
		copy_ids.append(str(JSON.to_native(object.properties.id)))
	check(copy_ids.has(child_id), "Hidden child is copied")
	WorkspaceActions.paste(stage)
	check(stage.selected_ids.size() == 3, "Paste creates the complete copied selection")
	var pasted_edge: LineEdge
	for object in stage.stage_objects():
		if object is LineEdge:
			pasted_edge = object
	check(pasted_edge != null and pasted_edge.source.id != group_id and pasted_edge.target.id != child_id, "Paste remaps internal endpoint references")
	check(stage.document_snapshot().objects.size() == 7, "Paste preserves original hidden document")
	await stage.history.undo()
	check(stage.document_snapshot().objects.size() == 4, "Undo removes copied records without dropping original hidden records")
	var deep := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(deep)
	deep.set_process(false)
	var records := []
	for index in range(1100):
		records.append({"id": "n%d" % index, "type": "text_node", "properties": {"text": "topic%d" % index}, "references": {}, "assets": {}, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}})
		if index > 0:
			records.append({"id": "e%d" % index, "type": "line_edge", "properties": {}, "references": {"source": "n%d" % (index - 1), "target": "n%d" % index}, "assets": {}, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}})
	check(deep.document_model.replace_document({"schema": 1, "camera": {}, "objects": records}, {}).ok, "Deep map fixture is valid")
	var deep_text := WorkspaceActions.export_text(deep, "markdown", false)
	check(deep_text.count("\n") == 1099 and deep_text.ends_with("topic1099"), "Deep export avoids recursion limits")
	var components := WorkspaceActions.graph_components(deep)
	check(components.size() == 1 and components[0].ids.size() == 1100 and components[0].edges == 1099, "Deep outline keeps complete connectivity")
	check(deep.stage_objects().is_empty(), "Deep export and outline never instantiate nodes")
	deep.queue_free()
	stage.queue_free()
	await process_frame
	print("DOCUMENT_ACTIONS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
