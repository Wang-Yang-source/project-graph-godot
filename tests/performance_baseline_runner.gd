extends Node
@onready var root: Window = get_tree().root
@onready var process_frame: Signal = get_tree().process_frame
## Real pointer drag benchmark. Loads a supplied fixture and never saves it.
var failures: Array[String] = []
var app: Control
var stage: Stage
var subject: TextNode
var load_done := false
var load_ok := false
var report := {}
var view: SubViewport
var measured_views: Array[Viewport] = []
func _ready() -> void:
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
	root.transparent = not OS.get_cmdline_user_args().has("--opaque")
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
	view = SubViewport.new()
	view.size = root.size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	container.add_child(view)
	stage = load("res://src/stage/stage.tscn").instantiate() as Stage
	stage.set_script(preload("res://tests/performance_stage_probe.gd"))
	stage.get_node("EntityLayerMover").set_script(preload("res://tests/performance_layer_probe.gd"))
	stage.get_node("GroupOverview").set_script(preload("res://tests/performance_overview_probe.gd"))
	view.add_child(stage)
	for frame in 6:
		await process_frame
	var copied_path := ProjectSettings.globalize_path("user://performance_fixture.prg")
	if DirAccess.copy_absolute(path, copied_path) != OK:
		quit(2)
		return
	path = copied_path
	var original_hash := FileAccess.get_sha256(path)
	var load_started := Time.get_ticks_usec()
	var previous_load := load_started
	var phases := {}
	_begin_load(path)
	while not load_done and Time.get_ticks_usec() - load_started < 60000000:
		var phase := -1
		for node in root.get_children():
			if node.get_script() != null and node.get_script().resource_path == "res://src/project_loader.gd":
				phase = int(node.get("_phase"))
		await process_frame
		var now := Time.get_ticks_usec()
		phases[str(phase)] = phases.get(str(phase), 0.0) + (now - previous_load) / 1000.0
		previous_load = now
	report["loading"] = {"total_ms": (Time.get_ticks_usec() - load_started) / 1000.0, "phase_wall_ms": phases}
	if not load_ok:
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
	report["opening_view"] = {"zoom": stage.camera.zoom.x, "center": str(stage.camera.global_position)}
	await _measure("fit_idle")
	await _measure("fit_zoom")
	stage.camera.position = subject.aabb.get_center()
	stage.camera.target_position = stage.camera.position
	stage.camera.zoom = Vector2.ONE * .28488218784332
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(1.0).timeout
	stage.get_viewport().physics_object_picking = false
	report["fixture_sha256"] = original_hash
	report["environment"] = {"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "window": str(root.size), "viewport": str(view.size), "transparent": root.transparent, "objects": stage.stage_objects().size(), "zoom": stage.camera.zoom.x, "vsync": DisplayServer.window_get_vsync_mode(), "debug_build": OS.is_debug_build(), "load_average": _load_average(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	await _measure("idle")
	await _measure("zoom")
	stage.camera.zoom = Vector2.ONE * .28488218784332
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(.5).timeout
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
	await _measure("drag", origin)
	var moved := subject.global_position.distance_to(original_position)
	subject.finish_drag(false)
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	report["movement"] = moved
	report["file_unchanged"] = FileAccess.get_sha256(path) == original_hash
	stage.history.cancel_transaction()
	if moved < 4.0 or FileAccess.get_sha256(path) != original_hash:
		failures.append("Drag must move the group and preserve the fixture")
	if OS.get_cmdline_user_args().has("--ablation"):
		stage.process_mode = Node.PROCESS_MODE_DISABLED
		await _measure("callbacks_disabled")
		view.canvas_cull_mask = 0
		await _measure("canvas_hidden")
	var decoded_started := Time.get_ticks_usec()
	var decoded := ProjectFile.load(path)
	report["standalone_decode_ms"] = (Time.get_ticks_usec() - decoded_started) / 1000.0
	if not decoded.ok or decoded.graph.get("objects", []).size() != stage.stage_objects().size():
		failures.append("Loaded object count must match decoded document")
	for object in stage.stage_objects():
		if object is LineEdge and (not is_instance_valid(object.source) or not is_instance_valid(object.target)):
			failures.append("Every loaded edge must resolve its endpoints")
	report["valid"] = failures.is_empty()
	print("PERFORMANCE_BASELINE ", JSON.stringify(report))
	FileAccess.open("/tmp/pg-performance-baseline.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame
	print("PERFORMANCE_BASELINE: ", "PASS" if failures.is_empty() else str(failures))
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

func _begin_load(path: String) -> void:
	load_ok = await stage.load_from_file(path)
	load_done = true

func _measure(phase: String, origin := Vector2.ZERO) -> void:
	var samples := {"frame": [], "render_cpu": [], "render_gpu": [], "all_viewports_render_cpu": [], "all_viewports_render_gpu": [], "draw_calls": []}
	var probes := {"stage": stage, "layer": stage.get_node("EntityLayerMover"), "overview": stage.group_overview}
	for probe in probes.values():
		probe.perf_totals.clear()
	stage.group_overview.perf_preview_samples.clear()
	measured_views.clear()
	_collect_views(root)
	var started := Time.get_ticks_usec()
	var previous := started
	var base_zoom: Vector2 = stage.camera.target_zoom
	while Time.get_ticks_usec() - started < 3000000:
		var t := (Time.get_ticks_usec() - started) / 1000000.0
		if phase == "drag":
			_motion(origin + Vector2(sin(t * 3.0) * 12.0, cos(t * 3.0) * 8.0) / base_zoom.x)
		elif phase.ends_with("zoom"):
			stage.camera.target_zoom = base_zoom * (1.0 + .25 * sin(t * 2.0))
		await process_frame
		var now := Time.get_ticks_usec()
		samples.frame.append((now - previous) / 1000.0)
		samples.render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()))
		samples.render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var cpu := 0.0
		var gpu := 0.0
		for viewport in measured_views:
			if is_instance_valid(viewport):
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
		samples.all_viewports_render_cpu.append(cpu)
		samples.all_viewports_render_gpu.append(gpu)
		previous = now
	var result := {"viewports": measured_views.size(), "rss_kib": _rss(), "frames": samples.frame.size(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	for metric in samples:
		var values: Array = samples[metric]
		values.sort()
		result[metric] = {"median": values[values.size()/2], "p95": values[mini(int(values.size() * .95), values.size()-1)], "p99": values[mini(int(values.size() * .99), values.size()-1)]}
	result["callback_cpu_mean_ms_per_frame"] = {}
	for name in probes:
		var totals: Dictionary = probes[name].perf_totals
		for method in totals:
			result.callback_cpu_mean_ms_per_frame[name + "." + method] = float(totals[method]) / samples.frame.size() / 1000.0
	result["native_preview_render_samples"] = stage.group_overview.perf_preview_samples.duplicate(true)
	report[phase] = result
	print("PERFORMANCE_PHASE ", phase, " ", JSON.stringify(result))

func _collect_views(node: Node) -> void:
	if node is Viewport:
		measured_views.append(node)
		RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(), true)
	for child in node.get_children():
		_collect_views(child)

func _rss() -> int:
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status == null:
		return -1
	while not status.eof_reached():
		var line := status.get_line()
		if line.begins_with("VmRSS:"):
			return int(line.trim_prefix("VmRSS:").strip_edges().split(" ", false)[0])
	return -1

func _load_average() -> String:
	var status := FileAccess.open("/proc/loadavg", FileAccess.READ)
	return status.get_line().strip_edges() if status != null else "unavailable"

func quit(code: int) -> void:
	get_tree().quit(code)

func create_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds)
