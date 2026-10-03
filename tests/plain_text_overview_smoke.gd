extends "res://tests/group_overview_smoke.gd"

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
	var branch := make_node("文本节点", Vector2(-700, 0))
	branch.fill_color = Color("#f38ba8")
	var leaf := make_node("按Enter键", Vector2(-500, 300))
	stage.connect_entities(branch, leaf)
	var group := make_node("真实分组", Vector2(700, 0))
	make_node("分组内节点", Vector2(900, 300), group)
	stage.select_ids(PackedStringArray())
	await zoom_to(2.0)
	check(not branch._container_active and group._container_active, "Graph branches remain text nodes; spatial containers are groups")
	var before := JSON.stringify(StageObjectRegistry.capture(stage))
	await zoom_to(.08)
	var overview = stage.group_overview
	for entity in [branch, leaf, group]:
		check(overview._summaries.has(entity.get_instance_id()), "Overview includes the expected title")
		if not overview._summaries.has(entity.get_instance_id()):
			continue
		var panel: Panel = overview._summaries[entity.get_instance_id()]
		var style = preload("res://src/main/continuous_corners.gd").source(panel.get_theme_stylebox("panel"))
		var border := panel.get_node("Border") as Line2D
		if entity._container_active:
			check(style.draw_center and style.bg_color.a > 0 and style.border_width_top > 0, "Actual groups retain their overview frame")
		else:
			check(not style.draw_center and style.bg_color.a == 0 and style.border_width_top == 0 and not border.visible, "Plain text root and next-layer titles have no fill or thumbnail border")
			check(panel.get_node("Title").visible, "Plain text titles remain visible")
	check(JSON.stringify(StageObjectRegistry.capture(stage)) == before, "Presentation does not change saved objects")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pg-plain-text-overview.png")
	await zoom_to(2.0)
	check(overview._summaries.is_empty() and branch.visibility_layer == 1 and leaf.visibility_layer == 1, "Zoom in restores original text rendering")
	app.queue_free()
	await process_frame
	print("PLAIN_TEXT_OVERVIEW: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func zoom_to(value: float) -> void:
	stage.camera.zoom = Vector2.ONE * value
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
