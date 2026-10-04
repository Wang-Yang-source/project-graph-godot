extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	var node: TextNode = stage.create_text_node("Thin outline", Vector2.ZERO, false)
	await process_frame
	await process_frame
	stage.select_object(node)
	for zoom in [0.5, 1.0, 2.0, 8.0]:
		stage.camera.set_process(false)
		stage.camera.zoom = Vector2.ONE * zoom
		stage.camera.force_update_scroll()
		stage._refresh_selection_outlines()
		var line: Line2D = stage._selection_lines[node.id]
		var width := line.width * line.get_global_transform_with_canvas().x.length()
		if absf(width - 1.0) > 0.01:
			failures.append("Selection remains one screen pixel at zoom " + str(zoom))
		var expected := node.get_visual_outline()
		if line.points.size() != expected.size():
			failures.append("Selection follows visible outline without expansion")
	print("THIN_NODE_OUTLINE: ", "PASS" if failures.is_empty() else failures)
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
