extends SceneTree

var failures: Array[String] = []
var done := false
var loaded := false


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _load(stage: Stage, path: String) -> void:
	loaded = await stage.load_from_file(path)
	done = true


func _run() -> void:
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("physics", false, false)
	var app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	for frame in 5:
		await process_frame
	var stage: Stage = app.tabs.get_current_stage()
	var objects := []
	for index in 260:
		objects.append({"type": "text_node", "transform": {"position": [index * 180.0, 0.0]},
			"properties": {"id": JSON.from_native("large-node-%d" % index),
				"text": JSON.from_native("主题 %d" % index)}})
		if index > 0:
			objects.append({"type": "line_edge", "transform": {"position": [0.0, 0.0]},
				"properties": {"id": JSON.from_native("large-edge-%d" % index),
					"source": {"$ref": "large-node-%d" % (index - 1)},
					"target": {"$ref": "large-node-%d" % index}}})
	var path := "/tmp/pg-large-loading-smoke.prg"
	check(ProjectFile.save(path, {"objects": objects}, {"position": [0.0, 0.0], "zoom": 0.5}).ok, "Fixture saves")
	var hash_before := FileAccess.get_sha256(path)
	_load(stage, path)
	var partial_frames := 0
	var unnecessary_animation := false
	var frames := 0
	while not done and frames < 2000:
		await process_frame
		frames += 1
		var current := stage.stage_objects()
		if current.is_empty() or current.size() == objects.size():
			continue
		partial_frames += 1
		for object in current:
			if object is TextNode:
				unnecessary_animation = unnecessary_animation or not is_equal_approx(object.modulate.a, 1.0)
			elif object is LineEdge:
				unnecessary_animation = unnecessary_animation or object.line.material != null
	check(done and loaded, "Large graph completes")
	check(partial_frames > 1, "Large graph still yields and displays partial batches")
	check(not unnecessary_animation, "Large graph batches show directly without per-object animation")
	check(stage.stage_objects().size() == objects.size(), "Every node and edge survives")
	check(not stage.is_dirty(), "Initial large snapshot is clean")
	check(FileAccess.get_sha256(path) == hash_before, "Loading never changes the input file")
	var by_id := {}
	for object in stage.stage_objects():
		by_id[object.id] = object
	for index in range(1, 260):
		var edge: LineEdge = by_id.get("large-edge-%d" % index)
		check(edge != null and edge.source == by_id.get("large-node-%d" % (index - 1))
			and edge.target == by_id.get("large-node-%d" % index), "Cross-object references survive")
	var node: TextNode = by_id["large-node-0"]
	stage.history.begin_transaction()
	node.text = "edited"
	stage.history._finish_commit()
	await stage.history.undo()
	check(not stage.is_loading and stage.stage_objects().size() == objects.size(), "Undo restores the whole loaded graph")
	for object in stage.stage_objects():
		if object.id == "large-node-0":
			check(object.text == "主题 0", "Undo restores the loaded text")
	DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame
	print("LARGE_LOADING: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
