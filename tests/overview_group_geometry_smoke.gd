extends "res://tests/plain_text_overview_smoke.gd"

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	root.size = Vector2i(1280, 800)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.get_node("UIOverlay/Welcome").hide()
	stage = app.tabs.get_current_stage()
	stage.apply_preferences()
	stage.camera.set_process(false)
	var outer := make_node("选择操作", Vector2.ZERO)
	var wide := make_node("宽分组", Vector2(-400, 0), outer)
	make_node("向左框选", Vector2(-2000, -100), wide)
	make_node("完全覆盖框选", Vector2(1200, 100), wide)
	var tall := make_node("高分组", Vector2(2000, 0), outer)
	make_node("上", Vector2(2000, -1200), tall)
	make_node("下", Vector2(2200, 1200), tall)
	stage.select_ids(PackedStringArray())
	await zoom_to(2.0)
	var before := JSON.stringify(StageObjectRegistry.capture(stage))
	var overview = stage.group_overview
	for zoom in [.08, .04, .12]:
		await zoom_to(zoom)
		for entity in [outer, wide, tall]:
			var identifier: int = entity.get_instance_id()
			check(overview._summaries.has(identifier), "Root and immediate group previews exist")
			if not overview._summaries.has(identifier):
				continue
			var original: Rect2 = overview._group_rects[identifier]
			var display: Rect2 = overview._preview_display_rect(identifier)
			check(display.is_equal_approx(original), "Preview preserves original group bounds and center at every zoom")
			var panel: Panel = overview._summaries[identifier]
			if panel.visible:
				var rendered := panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
				check(rendered.is_equal_approx(original), "Native panel uses the same world frame without independent width or height caps")
				var corners = preload("res://src/main/continuous_corners.gd")
				var native_style = corners.source(entity.container_panel.get_theme_stylebox("panel"))
				var preview_style = corners.source(panel.get_theme_stylebox("panel"))
				var relative: Transform2D = stage.global_transform.affine_inverse() * entity.container_panel.get_global_transform()
				var expected_radius := roundi(native_style.corner_radius_top_left * relative.get_scale().abs().x / panel.scale.x)
				check(preview_style.corner_radius_top_left == expected_radius, "Rounded corners scale from the native group shape")
				check(preview_style.bg_color == entity.display_fill_color(), "Group background preserves native color and opacity")
	check(JSON.stringify(StageObjectRegistry.capture(stage)) == before, "Preview geometry does not change saved layout")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pg-overview-group-geometry.png")
	await zoom_to(2.0)
	check(overview._summaries.is_empty(), "Zoom in restores original groups")
	app.queue_free()
	await process_frame
	print("OVERVIEW_GROUP_GEOMETRY: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
