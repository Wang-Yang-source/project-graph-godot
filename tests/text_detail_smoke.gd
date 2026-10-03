extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 6:
		await process_frame
func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var node := stage.create_text_node("Readable text", Vector2.ZERO, false)
	node.freeze = true
	stage.select_ids(PackedStringArray())
	stage.camera.zoom = Vector2.ONE
	stage.camera.target_zoom = stage.camera.zoom
	await settle()
	var captured := JSON.stringify(StageObjectRegistry.capture(stage).objects)
	var bounds := node.label.size
	var characters := node.label.visible_characters
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	await settle()
	check(node.label.visible_characters == 0, "Subpixel glyphs are omitted")
	check(node.label.visible and node.label.size == bounds, "Glyph culling preserves Control visibility and bounds")
	check(JSON.stringify(StageObjectRegistry.capture(stage).objects) == captured, "Glyph culling preserves persistent data")
	node._editing = true
	stage.set_editor_active(node, true)
	await settle()
	check(node.label.visible_characters == characters, "Editing restores glyphs without moving the camera")
	node._editing = false
	stage.set_editor_active(node, false)
	await settle()
	check(node.label.visible_characters == 0, "Finishing editing reapplies the threshold")
	stage.camera.zoom = Vector2.ONE
	stage.camera.target_zoom = stage.camera.zoom
	await settle()
	check(node.label.visible_characters == characters, "Zooming in restores glyphs")
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	await settle()
	stage.remove_child(node)
	check(node.label.visible_characters == characters, "Removing a hidden label restores its prior draw state")
	node.queue_free()
	var late := stage.create_text_node("Later", Vector2(200, 0), false)
	late.freeze = true
	await settle()
	check(late.label.visible_characters == 0, "New stage objects join the detail cache")
	stage.get_node("TextDetail").queue_free()
	await settle()
	check(late.label.visible_characters == -1, "Removing the detail manager restores live labels")
	view.queue_free()
	await process_frame
	print("TEXT_DETAIL: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
