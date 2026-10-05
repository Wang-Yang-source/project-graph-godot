extends SceneTree
## Exercise navigation caches against a real graph without saving user data.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 6:
		await physics_frame
		await process_frame

func _run() -> void:
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			fixture = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
	if fixture.is_empty():
		push_error("A UTF-8 hexadecimal fixture path is required")
		quit(2)
		return
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	check(await stage.load_from_file(fixture), "Fixture loads")
	await settle()
	var before: Array = StageObjectRegistry.capture(stage).objects
	var bounds := Rect2()
	var first := true
	for object in stage.stage_objects():
		if object is Entity:
			bounds = object.aabb if first else bounds.merge(object.aabb)
			first = false
	stage.camera.position = bounds.get_center()
	stage.camera.target_position = stage.camera.position
	var overview = stage.group_overview
	var observed := false
	for zoom_value in [.02, .035, .06, .125, .25, .5, 1.0, 2.0]:
		stage.camera.zoom = Vector2.ONE * zoom_value
		stage.camera.target_zoom = stage.camera.zoom
		await settle()
		for identifier in overview._entities:
			check(overview._entity_rects[identifier].is_equal_approx(overview._entities[identifier].aabb), "Cached entity bounds match geometry")
		for identifier in overview._preview_nodes:
			observed = true
			var rect: Rect2 = overview._preview_display_rect(identifier)
			check(rect == overview._preview_display_rect(identifier), "Repeated preview lookup is stable")
		var active: Dictionary = overview._active.duplicate()
		var display_rects := {}
		for identifier in overview._preview_nodes:
			display_rects[identifier] = overview._preview_display_rect(identifier)
		stage.camera.position += Vector2(1, 1)
		stage.camera.target_position = stage.camera.position
		await settle()
		check(overview._active == active, "Panning does not change preview membership")
		for identifier in display_rects:
			check(display_rects[identifier] == overview._preview_display_rect(identifier), "Panning preserves preview world geometry")
	check(observed, "Fixture exercises real previews")
	# Property changes must invalidate the cached presentation.
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	await settle()
	for identifier in overview._preview_nodes:
		var node: TextNode = overview._preview_nodes[identifier]
		var panel: Panel = overview._summaries[identifier]
		if not panel.visible:
			continue
		var text := node.text
		node.text = text + " CACHE"
		await settle()
		check(panel.get_node("Title").text == node.text.replace("\n", " "), "Renaming updates cached preview title")
		node.text = text
		await settle()
		break
	GraphPreferences.set_value("theme", "latte", false)
	stage.apply_preferences()
	await settle()
	for identifier in overview._summaries:
		var panel: Panel = overview._summaries[identifier]
		if panel.visible:
			var presentation: Array = panel.get_meta("presentation_key", [])
			check(not presentation.is_empty() and presentation[-1] == stage._applied_theme_light, "Theme changes invalidate presentation")
	check(JSON.stringify(before) == JSON.stringify(StageObjectRegistry.capture(stage).objects), "Navigation and cancelled property probes preserve saved objects")
	view.queue_free()
	await process_frame
	print("TUTORIAL_NAVIGATION_CACHE: " + ("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
