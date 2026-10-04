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


func set_zoom(stage: Stage, pixels: float) -> void:
	stage.camera.set_process(false)
	stage.camera.zoom = Vector2.ONE * pixels / 24.0
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()


func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var node := stage.create_text_node("中文 W English 101", Vector2.ZERO, false)
	await settle()
	var before := StageObjectRegistry.capture(stage)
	var bounds := node.get_visual_rect()
	await set_zoom(stage, 8.0)
	check(node.label.get_theme_constant("outline_size") > 0, "Real TextDetail strengthens small stage text")
	var small_alpha := node.label.get_theme_color("font_outline_color").a
	await set_zoom(stage, 12.0)
	check(node.label.get_theme_color("font_outline_color").a < small_alpha, "Zooming in gradually reduces compensation")
	await set_zoom(stage, 24.0)
	check(node.label.get_theme_constant("outline_size") == 0, "Normal stage text uses the original weight")
	await set_zoom(stage, 8.0)
	node.enter_edit_mode()
	await settle()
	check(node.label.get_theme_constant("outline_size") == 0, "Entering edit mode leaves no display outline")
	stage.finish_text_editing()
	await settle()
	check(node.label.get_theme_constant("outline_size") > 0, "Leaving edit mode restores small text compensation")
	check(node.get_visual_rect() == bounds, "Zoom and editing keep node geometry stable")
	check(StageObjectRegistry.capture(stage) == before, "Optical weight never changes serialized document data")
	stage.queue_free()
	await settle()
	view.queue_free()
	await process_frame
	print("OPTICAL_TEXT_INTEGRATION: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
