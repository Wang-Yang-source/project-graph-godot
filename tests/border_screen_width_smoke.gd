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
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1000, 800)
	view.size_2d_override = Vector2i(500, 400)
	view.size_2d_override_stretch = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	stage.get_node("CanvasLayer/Grid").hide()
	var node := stage.create_text_node("", Vector2.ZERO, false)
	node.freeze = true
	node.label.custom_minimum_size = Vector2(600,400)
	node.label.size = node.label.custom_minimum_size
	stage.select_ids(PackedStringArray())
	var border: Line2D = node.label.get_node("MinimumBorder")
	for zoom_value in [0.02, 0.125, 0.25, 0.49]:
		stage.camera.target_zoom = Vector2.ONE * zoom_value
		stage.camera.zoom = stage.camera.target_zoom
		stage.camera.position = node.label.position + (view.get_visible_rect().size * 0.5 - Vector2(40,40)) / zoom_value
		stage.camera.target_position = stage.camera.position
		for frame in 4: await process_frame
		var transform := view.get_final_transform() * border.get_global_transform_with_canvas()
		var core := border.width * minf(transform.x.length(), transform.y.length())
		check(core >= 0.99 and core <= 1.06, "Fallback border stays one physical pixel at zoom %s, got %s" % [zoom_value,core])
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image := view.get_texture().get_image()
			var x := 80 + roundi(node.label.size.x * zoom_value)
			var covered := 0
			for y in range(74, 87):
				if image.get_pixel(x,y).a > 0.1: covered += 1
			check(covered <= 3, "Thin border has no broad blurry band at zoom %s, got %s rows" % [zoom_value,covered])
			if zoom_value == 0.25: image.save_png("/tmp/pg-thin-screen-border.png")
	view.queue_free()
	await process_frame
	print("BORDER_SCREEN_WIDTH: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
