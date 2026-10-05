extends SceneTree
var failures: Array[String] = []
var completed := false
var ok := false
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _load(stage: Stage, path: String) -> void:
	ok = await stage.load_from_file(path)
	completed = true
func _run() -> void:
	var records := []
	for i in 80:
		records.append({"type":"text_node","transform":{"position":[float(i % 10) * 280,float(i / 10) * 180],"rotation":0.0,"scale":[1.0,1.0]},
			"properties":{"id":JSON.from_native("node-%s" % i),"text":JSON.from_native("主题 %s" % i)}})
		if i > 0:
			records.append({"type":"line_edge","transform":{"position":[0.0,0.0]},"properties":{
				"id":JSON.from_native("edge-%s" % i),"source":{"$ref":"node-%s" % (i-1)},"target":{"$ref":"node-%s" % i}}})
	var path := "/tmp/pg-load-transaction.prg"
	check(ProjectFile.save(path, {"objects":records}, {}).ok, "Fixture saves")
	var hash := FileAccess.get_sha256(path)
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	_load(stage,path)
	while not completed:
		await process_frame
		var objects := stage.stage_objects()
		if objects.size() < records.size():
			for object in objects:
				if object is Entity:
					check(object.freeze and object.collision_mask == 0, "Partial graph cannot simulate physics")
				check(not object.visible, "Partial graph remains behind load cover")
	check(ok and not stage.is_loading and not stage.history._busy, "Load unlocks editor")
	check(stage.stage_objects().size() == records.size(), "All persistent objects restored")
	check(not stage.is_dirty(), "Load creates clean history baseline")
	var by_id := {}
	for object in stage.stage_objects():
		by_id[object.id] = object
		check(object.process_mode != Node.PROCESS_MODE_DISABLED, "Object callbacks restored")
		if object is Entity:
			check(object.freeze and object.collision_mask == 1 and object._uses_native_physics(), "Native physics is available while idle views stay frozen")
			check(object._text_edit == null, "Load does not create text editors")
	for i in 80:
		check(by_id["node-%s" % i].position.is_equal_approx(Vector2(float(i % 10)*280,float(i / 10)*180)), "Saved world position retained")
	for i in range(1,80):
		var edge: LineEdge = by_id["edge-%s" % i]
		check(edge.source == by_id["node-%s" % (i-1)] and edge.target == by_id["node-%s" % i], "Reference resolution is complete")
	stage.history.begin_transaction()
	by_id["node-0"].text = "编辑"
	stage.history._finish_commit()
	await stage.history.undo()
	check(by_id["node-0"].text == "主题 0", "First edit can be undone")
	check(FileAccess.get_sha256(path) == hash, "Opening never rewrites source")
	DirAccess.remove_absolute(path)
	stage.queue_free()
	await process_frame
	print("DOCUMENT_LOAD_TRANSACTION: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
