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
	var top := make_node("多重连线", Vector2.ZERO)
	top.font_size = 100
	var child := make_node("1", Vector2(-1200, 0), top)
	child.font_size = 32
	var peer := make_node("2", Vector2(1200, 0), top)
	peer.font_size = 32
	var deep := make_node("25", Vector2(-1200, 200), child)
	var other := make_node("27", Vector2(-1000, 0), child)
	stage.connect_entities(deep, other)
	stage.select_ids(PackedStringArray())
	await zoom_to(2.0)
	var before := JSON.stringify(StageObjectRegistry.capture(stage))
	var overview = stage.group_overview
	# Isolate the readability rule from existing earlier screen-footprint gates.
	overview.camera_scale_threshold = .01
	overview.viewport_size_ratio = .01
	overview.invalidate()
	var relative := stage.global_transform.affine_inverse() * child.label.get_global_transform()
	var font_world := child.label.get_theme_font_size("font_size") * relative.get_scale().abs().x
	var display_scale: float = overview._frame_scale / stage.camera.zoom.x
	stage.camera.position = Vector2.ZERO
	stage.camera.target_position = Vector2.ZERO
	await zoom_to(13.0 / (font_world * display_scale))
	check(not overview.is_active(top), "Readable child titles retain their normal layer")
	await zoom_to(11.0 / (font_world * display_scale))
	check(overview.is_active(top), "Huge frames switch as immediate child fonts fall below 12 screen pixels")
	check(overview._summaries.has(child.get_instance_id()) and overview._summaries.has(peer.get_instance_id()), "The next layer has title previews")
	for entity in [child, peer]:
		var panel: Panel = overview._summaries[entity.get_instance_id()]
		check(panel.visible and panel.get_node("Title").visible, "Immediate child titles remain visible")
	check(not overview._summaries.has(deep.get_instance_id()), "Deeper labels are omitted")
	check(child.visibility_layer == 0 and deep.visibility_layer == 0 and other.visibility_layer == 0, "Preview titles replace all original descendant rendering")
	for identifier in overview._summaries:
		var panel: Panel = overview._summaries[identifier]
		var title: Label = panel.get_node("Title")
		var pixels := title.get_theme_font_size("font_size") * (root.get_final_transform() * title.get_global_transform_with_canvas()).get_scale().abs().x
		check(pixels <= 24.01, "Summary titles never become giant digits over inner nodes")
	check(JSON.stringify(StageObjectRegistry.capture(stage)) == before, "Hierarchy switching preserves the document")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pg-hierarchy-readability.png")
	await zoom_to(2.0)
	check(not overview.is_active(top) and child.visibility_layer == 1 and deep.visibility_layer == 1, "Zooming in restores the original layer")
	app.queue_free()
	await process_frame
	print("HIERARCHY_READABILITY: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
