extends SceneTree
## Real pointer drag benchmark. Loads a supplied fixture and never saves it.
var failures: Array[String] = []
var app: Control
var stage: Stage
var subject: TextNode
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			path = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
	if path.is_empty():
		push_error("Pass --fixture-hex= with a UTF-8 hexadecimal document path")
		quit(2)
		return
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("ui_scale", 200.0, false)
	GraphPreferences.set_value("physics", true, false)
	root.size = Vector2i(1996,1248)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	app = Control.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var container := SubViewportContainer.new()
	app.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	var view := SubViewport.new()
	view.size = root.size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	stage = load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	for frame in 6:
		await process_frame
	var copied_path := ProjectSettings.globalize_path("user://group_drag_fixture.prg")
	if DirAccess.copy_absolute(path, copied_path) != OK:
		quit(2)
		return
	path = copied_path
	var original_hash := FileAccess.get_sha256(path)
	if not await stage.load_from_file(path):
		quit(2)
		return
	for object in stage.stage_objects():
		if object is TextNode and object.text.contains("伸缩链"):
			subject = object
			break
	if subject == null:
		push_error("Fixture must contain the stretch-chain tutorial group")
		quit(2)
		return
	stage.camera.position = subject.aabb.get_center()
	stage.camera.target_position = stage.camera.position
	stage.camera.zoom = Vector2.ONE * .28488218784332
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(1.0).timeout
	stage.get_viewport().physics_object_picking = false
	print("DRAG_ENV ", JSON.stringify({"version":Engine.get_version_info().string,"objects":stage.stage_objects().size(),"zoom":stage.camera.zoom.x,"size":root.size,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode()}))
	var origin := subject.aabb.get_center()
	var original_position := subject.global_position
	_motion(origin)
	var press := InputEventMouseButton.new()
	press.position = _screen(origin)
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var local_press := press.duplicate() as InputEventMouseButton
	local_press.position = stage.get_canvas_transform() * origin
	subject._on_input_event(stage.get_viewport(), local_press, 0)
	await create_timer(.2).timeout
	if OS.get_cmdline_user_args().has("--disable-overview"):
		stage.group_overview.set_process(false)
	if OS.get_cmdline_user_args().has("--disable-shape-refresh"):
		for object in stage.stage_objects():
			if object is Entity:
				object.geometry_changed.disconnect(object._queue_collision_outline_update)
	if OS.get_cmdline_user_args().has("--disable-contact"):
		stage.get_node("PhysicsSession").set_physics_process(false)
	var samples: Array[float] = []
	var process_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec() - started < 3000000:
		var t := (Time.get_ticks_usec() - started) / 1000000.0
		_motion(origin + Vector2(sin(t * 3.0) * 12.0, cos(t * 3.0) * 8.0) / stage.camera.zoom.x)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		previous = now
	var moved := subject.global_position.distance_to(original_position)
	subject.finish_drag(false)
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	samples.sort()
	process_samples.sort()
	physics_samples.sort()
	print("DRAG_RESULT ", JSON.stringify({"fps":samples.size() * 1000000.0 / (previous-started),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"movement":moved,"process_ms":process_samples[process_samples.size()/2],"physics_ms":physics_samples[physics_samples.size()/2],"file_unchanged":FileAccess.get_sha256(path)==original_hash}))
	stage.history.cancel_transaction()
	if moved < 4.0 or FileAccess.get_sha256(path) != original_hash:
		failures.append("Drag must move the group and preserve the fixture")
	DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame
	print("GROUP_DRAG: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)

func _screen(point: Vector2) -> Vector2:
	var viewport := stage.get_viewport()
	var container := viewport.get_parent() as Control
	return container.get_global_transform_with_canvas() * ((stage.get_canvas_transform() * point) * container.size / Vector2(viewport.size))

func _motion(point: Vector2) -> void:
	root.warp_mouse(_screen(point))
	var motion := InputEventMouseMotion.new()
	motion.position = _screen(point)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
