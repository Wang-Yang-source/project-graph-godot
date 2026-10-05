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
	stage.camera.position = Vector2.ZERO
	stage.camera.target_position = Vector2.ZERO
	var frame := make_node("手动调整树形布局", Vector2.ZERO)
	var branch := make_node("18", Vector2(-500, 0), frame)
	branch.font_size = 100
	var child := make_node("19", Vector2(-300, 100), frame)
	var leaf := make_node("21", Vector2(-200, 200), frame)
	stage.connect_entities(branch, child)
	stage.connect_entities(child, leaf)
	var chain := make_node("２００１", Vector2(500, 0), frame)
	chain.font_size = 100
	var chain_child := make_node("２００２", Vector2(500, 200), frame)
	stage.connect_entities(chain, chain_child)
	stage.select_ids(PackedStringArray())
	await zoom_to(2.0)
	var before := JSON.stringify(StageObjectRegistry.capture(stage))
	var overview = stage.group_overview
	overview.camera_scale_threshold = 1.0
	overview.viewport_size_ratio = 1.0
	overview.invalidate()
	for zoom in [.08, .04, .08]:
		await zoom_to(zoom)
		check(overview._preview_nodes.has(frame.get_instance_id()) and overview._preview_nodes.has(branch.get_instance_id()) and overview._preview_nodes.has(chain.get_instance_id()), "Flat spatial frame previews its immediate graph roots")
		check(not overview._preview_nodes.has(child.get_instance_id()) and not overview._preview_nodes.has(leaf.get_instance_id()) and not overview._preview_nodes.has(chain_child.get_instance_id()), "Deeper graph numbers are never promoted into random peer titles")
		check(child.container == frame and leaf.container == frame, "Preview graph depth leaves spatial membership intact")
		if overview._summaries.has(chain.get_instance_id()):
			var panel: Panel = overview._summaries[chain.get_instance_id()]
			if panel.visible:
				check(panel.get_node("Title").text == "２００１", "Full-width source digits are retained exactly")
	check(JSON.stringify(StageObjectRegistry.capture(stage)) == before, "Repeated zoom does not change serialized relationships")

	for entity in [frame, branch, child, leaf, chain, chain_child]:
		check(entity.visibility_layer == 0, "Original bodies are suppressed while the native texture supplies their geometry")
	for object in stage.stage_objects():
		if object is LineEdge:
			check(object.visibility_layer == 0, "Original edge rendering is suppressed while its geometry is cached")
	check(overview._native_previews.has(frame.get_instance_id()), "Real frame has a faithful native geometry cache")
	var cached = overview._native_previews[frame.get_instance_id()].image.texture
	await zoom_to(.04)
	check(overview._native_previews[frame.get_instance_id()].image.texture == cached, "Zoom reuses the geometry cache")
	stage.camera.position = Vector2(1000000, 1000000)
	stage.camera.target_position = stage.camera.position
	stage.camera.force_update_scroll()
	await settle()
	check(not overview._native_previews[frame.get_instance_id()].image.visible, "Panning culls the native image")
	stage.camera.position = Vector2.ZERO
	stage.camera.target_position = Vector2.ZERO
	stage.camera.force_update_scroll()
	await settle()
	check(overview._native_previews[frame.get_instance_id()].image.visible and overview._native_previews[frame.get_instance_id()].image.texture == cached, "Panning back restores the same cached texture")
	check(overview._preview_links.is_empty(), "Native edges are not duplicated by aggregated links")
	await zoom_to(.2)
	check(overview._native_previews.has(frame.get_instance_id()), "Large screen overview remains cached")
	if overview._native_previews.has(frame.get_instance_id()):
		var large_texture: Texture2D = overview._native_previews[frame.get_instance_id()].image.texture
		check(maxi(large_texture.get_width(), large_texture.get_height()) > 512, "Large previews increase cache resolution instead of enlarging a 512-pixel image")
		await zoom_to(.08)
		check(overview._native_previews[frame.get_instance_id()].image.texture == large_texture, "Zooming back retains the sharper cache")
	await zoom_to(2.0)
	for entity in [frame, branch, child, leaf, chain, chain_child]:
		check(entity.label.visible_characters == -1 and not overview.is_hidden(entity), "Zoom in restores original glyphs and picking")

	# Native frames may overlap while their actual title glyphs do not.
	overview.set_process(false)
	for panel in overview._summaries.values():
		panel.hide()
	overview._summaries.clear()
	overview._preview_roots.clear()
	overview._overlap_key.clear()
	var panels: Array[Panel] = []
	for index in 3:
		var panel := Panel.new()
		panel.size = Vector2(1000, 1000)
		var title := Label.new()
		title.name = "Title"
		title.text = ["Root", "Left", "Right"][index]
		title.position = Vector2(20 + index * 200, 20)
		title.size = Vector2(80, 40)
		panel.add_child(title)
		overview.add_child(panel)
		overview._summaries[panel.get_instance_id()] = panel
		panels.append(panel)
	overview._preview_roots[panels[0].get_instance_id()] = true
	overview._avoid_title_overlaps()
	check(panels[1].visible and panels[2].visible, "Large frame rectangles do not hide non-overlapping title glyphs")
	app.queue_free()
	await process_frame
	print("OVERVIEW_TREE_LAYERS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
