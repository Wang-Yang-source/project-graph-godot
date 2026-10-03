extends "res://tests/plain_text_overview_smoke.gd"

func _run() -> void:
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			fixture = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
	if fixture.is_empty():
		quit(2)
		return
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	root.size = Vector2i(1600, 1000)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.get_node("UIOverlay/Welcome").hide()
	stage = app.tabs.get_current_stage()
	stage.apply_preferences()
	stage.camera.set_process(false)
	check(await stage.load_from_file(fixture), "Fixture loads without saving")
	stage.select_ids(PackedStringArray())
	await settle()
	var before := JSON.stringify(StageObjectRegistry.capture(stage).objects)
	var bounds := Rect2()
	var first := true
	for object in stage.stage_objects():
		if object is Entity:
			bounds = object.aabb if first else bounds.merge(object.aabb)
			first = false
	stage.camera.position = bounds.get_center()
	stage.camera.target_position = stage.camera.position
	var viewport_size := stage.get_viewport_rect().size
	var fit := minf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y) * .9
	var overview = stage.group_overview
	var colored := 0
	for zoom in [fit, fit * 1.5, fit * 3.0]:
		await zoom_to(zoom)
		for identifier in overview._preview_nodes:
			var node: TextNode = overview._preview_nodes[identifier]
			var rect: Rect2 = overview._preview_display_rect(identifier)
			if node._container_active:
				check(rect.is_equal_approx(overview._group_rects[identifier]), "Real group thumbnail retains original frame geometry")
			elif node.fill_color.a > 0.0:
				colored += 1
				check(rect.is_equal_approx(overview._entity_rects[identifier]), "Colored text uses its own bounds, not branch subtree bounds")
				var panel: Panel = overview._summaries[identifier]
				if panel.visible:
					var control: Control = node.label if overview._miniatures.has(identifier) else panel
					var style = preload("res://src/main/continuous_corners.gd").source(control.get_theme_stylebox("normal" if control == node.label else "panel"))
					check(style.bg_color == node.fill_color and style.draw_center, "Text background retains original color and opacity")
			else:
				var panel: Panel = overview._summaries[identifier]
				if panel.visible:
					var control: Control = node.label if overview._miniatures.has(identifier) else panel
					var style = preload("res://src/main/continuous_corners.gd").source(control.get_theme_stylebox("normal" if control == node.label else "panel"))
					check(style.bg_color.a == 0.0, "Unfilled plain titles have no extra body rectangle")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pg-overview-document-" + str(snappedf(zoom, .0001)) + ".png")
	check(colored > 0, "Real document exercises colored text previews")
	check(JSON.stringify(StageObjectRegistry.capture(stage).objects) == before, "Appearance does not alter the document")
	app.queue_free()
	await process_frame
	print("OVERVIEW_DOCUMENT_APPEARANCE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
