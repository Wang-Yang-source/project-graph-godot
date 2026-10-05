extends Node

# Exercise native template loading, references, bounds and edited save roundtrips.
func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var tree = get_tree()
	GraphPreferences.set_value("physics", false, false)
	GraphPreferences.set_value("theme", "mocha", false)
	var view = SubViewport.new()
	view.size = Vector2i(1600, 2100)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(view)
	var stage = load("res://src/stage/stage.tscn").instantiate()
	view.add_child(stage)
	var failures: Array[String] = []
	var report: Array = []
	for slug in ["literature-review", "argument-writing", "knowledge-review", "problem-analysis"]:
		var path: String = "res://docs/examples/mind-maps/" + slug + ".prg"
		print("CHECK loading ", slug)
		var loaded: bool = await stage.load_from_file(path)
		if not loaded:
			failures.append(slug + ": load failed")
			continue
		for object in stage.stage_objects():
			if object is Entity: object.freeze = true
		stage.camera.target_position = Vector2(-30, 10)
		stage.camera.position = stage.camera.target_position
		stage.camera.target_zoom = Vector2.ONE * 0.86
		stage.camera.zoom = stage.camera.target_zoom
		for frame in 20: await tree.process_frame
		var objects: Array = stage.stage_objects()
		if objects.size() != 37: failures.append(slug + ": object count")
		var ids: Dictionary = {}
		var nodes: Array = []
		var edges: Array = []
		for object in objects:
			if ids.has(object.id): failures.append(slug + ": duplicate ID")
			ids[object.id] = object
			if object is TextNode: nodes.append(object)
			if object is LineEdge: edges.append(object)
		if nodes.size() != 21 or edges.size() != 16: failures.append(slug + ": type count")
		for edge in edges:
			if not is_instance_valid(edge.source) or not is_instance_valid(edge.target): failures.append(slug + ": dangling edge")
		for node in nodes:
			if node.id.begins_with("branch-") and not is_instance_valid(node.topic_parent): failures.append(slug + ": missing topic parent")
		for a in nodes.size():
			for b in range(a+1, nodes.size()):
				if nodes[a].aabb.intersects(nodes[b].aabb): failures.append(slug + ": overlap " + nodes[a].id + " / " + nodes[b].id)
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("/tmp/pg-template-" + slug + ".png")
		print("CHECK rendered ", slug)
		var leaf = ids["branch-0-0"]
		leaf.text += "\n验证编辑"
		leaf.position += Vector2(35, 10)
		for frame in 8: await tree.process_frame
		print("CHECK edited ", slug)
		var edited: Dictionary = StageObjectRegistry.capture(stage)
		var saved: bool = stage.save_to_file("/tmp/pg-template-roundtrip-" + slug + ".prg")
		if not saved: failures.append(slug + ": save failed")
		print("CHECK saved ", slug, " ", saved)
		var restored: bool = await stage.load_from_file("/tmp/pg-template-roundtrip-" + slug + ".prg")
		if not restored: failures.append(slug + ": reload failed")
		for object in stage.stage_objects():
			if object is Entity: object.freeze = true
		for frame in 8: await tree.process_frame
		if StageObjectRegistry.capture(stage) != edited: failures.append(slug + ": roundtrip data mismatch")
		print("CHECK restored ", slug)
		report.append({"template": slug, "nodes": nodes.size(), "edges": edges.size(), "render": "/tmp/pg-template-" + slug + ".png", "saved": saved, "reloaded": restored})
	view.queue_free()
	await tree.process_frame
	var result := {"report": report, "failures": failures}
	var result_file = FileAccess.open("/tmp/pg-mind-map-validation.json", FileAccess.WRITE)
	result_file.store_string(JSON.stringify(result, "\t"))
	result_file.close()
	print("MIND_MAP_TEMPLATES: ", result)
	get_tree().quit(0 if failures.is_empty() else 1)
