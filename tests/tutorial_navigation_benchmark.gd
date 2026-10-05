extends SceneTree
## Read-only navigation benchmark for an existing document. Never saves the fixture.
var app: Control
var stage: Stage

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := ""
	var label := "baseline"
	var detail := false
	var fit := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			fixture = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
		if argument == "--fit":
			fit = true
		if argument == "--detail":
			detail = true
		if argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
	if fixture.is_empty():
		push_error("Pass --fixture-hex= followed by the UTF-8 hexadecimal document path")
		quit(2)
		return
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("ui_scale", 200.0, false)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	root.size = Vector2i(1800, 1100)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX if "--mailbox" in OS.get_cmdline_user_args() else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 10:
		await process_frame
	app.get_node("UIOverlay/Welcome").hide()
	stage = app.tabs.get_current_stage()
	if not await stage.load_from_file(fixture):
		quit(2)
		return
	await create_timer(3.0).timeout
	var center := stage.camera.position
	var initial_zoom := 2.0 if detail else stage.camera.zoom.x
	if fit:
		var bounds := Rect2()
		var first := true
		for object in stage.stage_objects():
			if object is Entity:
				bounds = object.aabb if first else bounds.merge(object.aabb)
				first = false
		center = bounds.get_center()
		stage.camera.position = center
		stage.camera.target_position = center
		var available := stage.get_viewport_rect().size - Vector2(80, 80)
		initial_zoom = clampf(minf(available.x / bounds.size.x, available.y / bounds.size.y), stage.camera.min_zoom, stage.camera.max_zoom)
	stage.camera.zoom = Vector2.ONE * initial_zoom
	stage.camera.target_zoom = stage.camera.zoom
	print("TUTORIAL_ENV ", JSON.stringify({"label":label,"objects":stage.stage_objects().size(),"zoom":initial_zoom,"size":root.size,"rendering":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"physics_hz":Engine.physics_ticks_per_second,"vsync":DisplayServer.window_get_vsync_mode()}))
	for i in 50:
		await process_frame
	await process_frame
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("/tmp/project-graph-tutorial-" + label + ".png")
	for phase in ["idle", "pan", "zoom"]:
		var intervals: Array[float] = []
		var draw_calls: Array[float] = []
		var started := Time.get_ticks_usec()
		var previous := started
		while Time.get_ticks_usec() - started < 3000000:
			var t := float(Time.get_ticks_usec() - started) / 1000000.0
			if phase == "pan":
				stage.camera.target_position = center + Vector2(sin(t * 2.0) * 150.0, cos(t * 2.0) * 80.0)
			elif phase == "zoom":
				stage.camera.target_zoom = Vector2.ONE * initial_zoom * (1.0 + 0.25 * sin(t * 2.0))
			await process_frame
			var now := Time.get_ticks_usec()
			intervals.append((now - previous) / 1000.0)
			previous = now
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
		intervals.sort()
		print("TUTORIAL_RESULT ", JSON.stringify({"label":label,"phase":phase,"fps":intervals.size()/elapsed,"p95_ms":intervals[int(intervals.size()*0.95)],"draw_calls":_mean(draw_calls)}))
	_profile_updates()
	app.queue_free()
	await process_frame
	quit()

func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1.0)

func _profile_updates() -> void:
	var totals := {"view":0, "overview":0, "edges":0, "captions":0, "layout":0}
	var objects := stage.stage_objects()
	for index in 20:
		stage.camera.position += Vector2(1, 0)
		stage.camera.zoom *= 1.003
		var start := Time.get_ticks_usec()
		stage._process(0.0)
		totals.view += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		stage.group_overview.refresh()
		totals.overview += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for object in objects:
			if object is LineEdge and object.is_processing():
				object._process(0.0)
		totals.edges += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for object in objects:
			if object is LineEdge and object.get_node("Caption").is_processing():
				object.get_node("Caption")._process(0.0)
		totals.captions += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		stage.get_node("EntityLayerMover").refresh_layout()
		totals.layout += Time.get_ticks_usec() - start
	for key in totals:
		totals[key] = float(totals[key]) / 20000.0
	print("TUTORIAL_PROFILE ", JSON.stringify(totals))
