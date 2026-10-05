extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	await process_frame
	var group := stage.create_text_node("清晰的预览标题", Vector2.ZERO, false)
	for point in [Vector2(-400,-300), Vector2(400,300)]:
		var child := stage.create_text_node("子节点", point, false)
		child.freeze = true
		child.container = group
	group.freeze = true
	stage.camera.target_zoom = Vector2.ONE * 0.04
	stage.camera.zoom = stage.camera.target_zoom
	stage.select_ids(PackedStringArray())
	for frame in 12: await process_frame
	var panel: Panel = stage.group_overview._summaries.get(group.get_instance_id())
	if panel == null or not panel.visible:
		push_error("Visible tiny overview fixture is required")
		failed = true
	else:
		var title: Label = panel.get_node("Title")
		if title.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			push_error("Minified overview title must sample glyph mipmaps")
			failed = true
		if not title.get_theme_font("font").generate_mipmaps:
			push_error("Overview glyph cache must retain mipmaps")
			failed = true
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("/tmp/pg-overview-sampling.png")
	view.queue_free()
	await process_frame
	print("OVERVIEW_SAMPLING: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
