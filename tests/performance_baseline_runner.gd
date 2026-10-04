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
var main_window := false
var real_input := false
var sample_seconds := 3.0
var benchmark_zoom := .28488218784332
var subject_id := ""
var expected_objects := -1
var output_path := "/tmp/pg-performance-baseline.json"
var probes := {}
var _last_motion_screen := Vector2.ZERO
var _last_motion_actual_screen := Vector2.ZERO
var _last_motion_camera := Vector2.ZERO
var pointer_trace_enabled := false
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			path = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
		elif argument.begins_with("--subject-id="):
			subject_id = argument.trim_prefix("--subject-id=")
		elif argument.begins_with("--expected-objects="):
			expected_objects = argument.trim_prefix("--expected-objects=").to_int()
		elif argument.begins_with("--zoom="):
			benchmark_zoom = maxf(argument.trim_prefix("--zoom=").to_float(), .001)
		elif argument.begins_with("--duration="):
			sample_seconds = clampf(argument.trim_prefix("--duration=").to_float(), .2, 60.0)
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	main_window = OS.get_cmdline_user_args().has("--main-window")
	real_input = OS.get_cmdline_user_args().has("--real-input")
	pointer_trace_enabled = OS.get_cmdline_user_args().has("--pointer-trace")
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
	if main_window:
		app = load("res://src/main/main.tscn").instantiate() as Control
		root.add_child(app)
		stage = app.tabs.get_current_stage()
		view = stage.get_viewport() as SubViewport
	else:
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
		container.add_child(view)
		stage = load("res://src/stage/stage.tscn").instantiate() as Stage
		stage.set_script(preload("res://tests/performance_stage_probe.gd"))
		stage.get_node("EntityLayerMover").set_script(preload("res://tests/performance_layer_probe.gd"))
		stage.get_node("GroupOverview").set_script(preload("res://tests/performance_overview_probe.gd"))
		view.add_child(stage)
		probes = {"stage": stage, "layer": stage.get_node("EntityLayerMover"), "overview": stage.group_overview}
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	for frame in 6:
		await process_frame
	if main_window:
		app.get_node("UIOverlay/Welcome").hide()
	var source_path := path
	var source_hash := FileAccess.get_sha256(source_path)
	var copied_path := ProjectSettings.globalize_path("user://performance_fixture_%d.prg" % OS.get_process_id())
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
	if expected_objects >= 0 and stage.stage_objects().size() != expected_objects:
		push_error("Loaded object count differs from --expected-objects")
		DirAccess.remove_absolute(path)
		quit(2)
		return
	for object in stage.stage_objects():
		if object is TextNode and ((not subject_id.is_empty() and object.id == subject_id) or (subject_id.is_empty() and object.text.contains("伸缩链"))):
			subject = object
			break
	if subject == null:
		push_error("Fixture must contain the requested TextNode ID, or legacy stretch-chain group")
		quit(2)
		return
	report["opening_view"] = {"zoom": stage.camera.zoom.x, "center": str(stage.camera.global_position)}
	if not OS.get_cmdline_user_args().has("--only-drag"):
		await _measure("fit_idle")
		await _measure("fit_zoom")
	stage.camera.position = subject.aabb.get_center()
	stage.camera.target_position = stage.camera.position
	stage.camera.zoom = Vector2.ONE * benchmark_zoom
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(1.0).timeout
	stage.get_viewport().physics_object_picking = real_input
	report["fixture_sha256"] = original_hash
	report["environment"] = {"main_window": main_window, "real_input": real_input, "subject_id": subject.id, "sample_seconds": sample_seconds, "engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "window": str(root.size), "viewport": str(view.size), "transparent": root.transparent, "objects": stage.stage_objects().size(), "zoom": stage.camera.zoom.x, "vsync": DisplayServer.window_get_vsync_mode(), "debug_build": OS.is_debug_build(), "load_average": _load_average(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	if not OS.get_cmdline_user_args().has("--only-drag"):
		await _measure("idle")
		await _measure("zoom")
	stage.camera.zoom = Vector2.ONE * benchmark_zoom
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(.5).timeout
	print("DRAG_ENV ", JSON.stringify({"version":Engine.get_version_info().string,"objects":stage.stage_objects().size(),"zoom":stage.camera.zoom.x,"size":root.size,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode()}))
	var origin := subject.aabb.get_center()
	if real_input:
		origin = await _pick_drag_origin()
		if origin == Vector2.INF:
			push_error("No visible input control belonging to requested subject")
			DirAccess.remove_absolute(path)
			quit(2)
			return
	var original_position := subject.global_position
	_motion(origin)
	var press := InputEventMouseButton.new()
	press.position = _screen(origin)
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var press_input_started: int = Time.get_ticks_usec()
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	report["press_input_ms"] = (Time.get_ticks_usec() - press_input_started) / 1000.0
	report["press_history_transaction_active"] = stage.history.is_transaction_active()
	if not real_input:
		var local_press := press.duplicate() as InputEventMouseButton
		local_press.position = stage.get_canvas_transform() * origin
		var direct_press_started: int = Time.get_ticks_usec()
		subject._on_input_event(stage.get_viewport(), local_press, 0)
		report["direct_press_handler_ms"] = (Time.get_ticks_usec() - direct_press_started) / 1000.0
	await get_tree().physics_frame
	await process_frame
	await create_timer(.2).timeout
	var actual_pointer_world: Vector2 = subject.get_global_mouse_position()
	var initial_pointer_error_px: float = _screen(actual_pointer_world).distance_to(_screen(origin))
	report["pointer_check"] = {"expected_world": str(origin), "actual_world": str(actual_pointer_world), "screen_error_px": initial_pointer_error_px}
	if initial_pointer_error_px > 2.0:
		failures.append("Actual OS pointer must agree with generated input within two physical pixels")
	var overview_hidden_entity_count := 0
	for object in stage.stage_objects():
		if object is Entity and stage.group_overview.is_hidden(object):
			overview_hidden_entity_count += 1
	report.environment["subject_overview_active"] = stage.group_overview.is_active(subject)
	if OS.get_cmdline_user_args().has("--require-overview") and not report.environment.subject_overview_active:
		failures.append("Requested subject must be collapsed in overview mode")
	report.environment["overview_hidden_entity_count"] = overview_hidden_entity_count
	report["drag_start"] = {"subject_dragging": subject.is_dragging, "subject_selected": stage.selected_ids.has(subject.id), "selected_ids": stage.selected_ids, "origin_world": str(origin), "origin_screen": str(_screen(origin)), "picking": stage.get_viewport().physics_object_picking, "physics_session_members": _physics_session_members()}
	if not subject.is_dragging or not stage.selected_ids.has(subject.id):
		failures.append("Requested subject must be selected and dragging after pointer press")
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
	report["release_history_transaction_active_before"] = stage.history.is_transaction_active()
	var normal_release: bool = real_input and OS.get_cmdline_user_args().has("--measure-release")
	var release_finalize_started: int = Time.get_ticks_usec()
	if not normal_release:
		subject.finish_drag(false)
	report["release_finalize_ms"] = (Time.get_ticks_usec() - release_finalize_started) / 1000.0
	report["release_history_transaction_active_after_finalize"] = stage.history.is_transaction_active()
	report["release_physics_session_members_after_finalize"] = _physics_session_members()
	press.pressed = false
	if normal_release:
		press.position = root.get_final_transform() * root.get_mouse_position()
		press.global_position = press.position
	var release_input_started: int = Time.get_ticks_usec()
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	report["release_input_ms"] = (Time.get_ticks_usec() - release_input_started) / 1000.0
	report["release_input_after_manual_finish"] = not normal_release
	report["release_callback_total_ms"] = float(report.release_finalize_ms) + float(report.release_input_ms)
	report["release_history_transaction_active_after_input"] = stage.history.is_transaction_active()
	if normal_release:
		var drag_sample_seconds: float = sample_seconds
		sample_seconds = 1.0
		await _measure("release")
		sample_seconds = drag_sample_seconds
		report["release_history_transaction_active_after_window"] = stage.history.is_transaction_active()
		report["release_physics_session_members_after_window"] = _physics_session_members()
		report["release_subject_dragging_after_window"] = subject.is_dragging
		if subject.is_dragging:
			failures.append("Normal release must finish the requested drag")
	report["movement"] = moved
	report["file_unchanged"] = FileAccess.get_sha256(path) == original_hash and FileAccess.get_sha256(source_path) == source_hash
	stage.history.cancel_transaction()
	if moved < 4.0 or not report.file_unchanged:
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
	FileAccess.open(output_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame
	print("PERFORMANCE_BASELINE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)

func _screen(point: Vector2) -> Vector2:
	var viewport := stage.get_viewport()
	var container := viewport.get_parent() as Control
	return root.get_final_transform() * container.get_global_transform_with_canvas() * viewport.get_final_transform() * stage.get_canvas_transform() * point

func _motion(point: Vector2) -> void:
	_last_motion_screen = _screen(point)
	_last_motion_camera = stage.camera.global_position
	root.warp_mouse(root.get_final_transform().affine_inverse() * _last_motion_screen)
	_last_motion_actual_screen = root.get_final_transform() * root.get_mouse_position()
	var motion := InputEventMouseMotion.new()
	motion.position = _last_motion_screen
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()

func _begin_load(path: String) -> void:
	load_ok = await stage.load_from_file(path)
	load_done = true

func _measure(phase: String, origin := Vector2.ZERO) -> void:
	var samples := {"frame": [], "render_cpu": [], "render_gpu": [], "frame_setup_cpu": [], "render_cpu_with_setup": [], "all_viewports_render_cpu": [], "all_viewports_render_gpu": [], "draw_calls": [], "physics_steps": []}
	for probe in probes.values():
		probe.perf_totals.clear()
	if not probes.is_empty():
		stage.group_overview.perf_preview_samples.clear()
	measured_views.clear()
	_collect_views(root)
	var started := Time.get_ticks_usec()
	var previous := started
	var previous_physics := Engine.get_physics_frames()
	var active_drag_frames := 0
	var pointer_error_max_px := 0.0
	var expected_pointer: Vector2 = origin
	var pointer_trace: Array[Dictionary] = []
	var physics_session_members_start: int = _physics_session_members()
	var physics_session_members_peak: int = physics_session_members_start
	var base_zoom: Vector2 = stage.camera.target_zoom
	while Time.get_ticks_usec() - started < sample_seconds * 1000000.0:
		var t := (Time.get_ticks_usec() - started) / 1000000.0
		if phase == "drag":
			expected_pointer = origin + Vector2(sin(t * 3.0) * 12.0, cos(t * 3.0) * 8.0) / base_zoom.x
			_motion(expected_pointer)
		elif phase.ends_with("zoom"):
			stage.camera.target_zoom = base_zoom * (1.0 + .25 * sin(t * 2.0))
		await process_frame
		var now := Time.get_ticks_usec()
		if phase == "drag":
			physics_session_members_peak = maxi(physics_session_members_peak, _physics_session_members())
			var actual_pointer: Vector2 = subject.get_global_mouse_position()
			var actual_screen: Vector2 = root.get_final_transform() * root.get_mouse_position()
			var physical_error: float = actual_screen.distance_to(_last_motion_screen)
			pointer_error_max_px = maxf(pointer_error_max_px, physical_error)
			if pointer_trace_enabled and pointer_trace.size() < 32:
				pointer_trace.append({"frame": samples.frame.size(), "sent_screen": str(_last_motion_screen), "actual_after_warp": str(_last_motion_actual_screen), "actual_before_frame": str(actual_screen), "mapped_world_screen": str(_screen(actual_pointer)), "actual_world": str(actual_pointer), "expected_world": str(expected_pointer), "screen_error_px": physical_error, "os_screen": str(DisplayServer.mouse_get_position()), "window_position": str(DisplayServer.window_get_position()), "camera_sent": str(_last_motion_camera), "camera_now": str(stage.camera.global_position), "focus": root.has_focus()})
		if phase == "drag" and subject.is_dragging and stage.selected_ids.has(subject.id):
			active_drag_frames += 1
		samples.frame.append((now - previous) / 1000.0)
		var physics_frame := Engine.get_physics_frames()
		samples.physics_steps.append(physics_frame - previous_physics)
		previous_physics = physics_frame
		samples.render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()))
		samples.render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var cpu := 0.0
		var gpu := 0.0
		for viewport in measured_views:
			if is_instance_valid(viewport):
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
		var setup_cpu := RenderingServer.get_frame_setup_time_cpu()
		samples.frame_setup_cpu.append(setup_cpu)
		samples.render_cpu_with_setup.append(cpu + setup_cpu)
		samples.all_viewports_render_cpu.append(cpu)
		samples.all_viewports_render_gpu.append(gpu)
		previous = now
	var result := {"viewports": measured_views.size(), "rss_kib": _rss(), "frames": samples.frame.size(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var raw_frames: Array = samples.frame.duplicate()
	var missed_budget := 0
	var long_frames := 0
	for frame_ms in raw_frames:
		if frame_ms > 16.666667:
			missed_budget += 1
		if frame_ms > 33.333334:
			long_frames += 1
	result["frame_ms"] = raw_frames
	result["over_16_67_ms_ratio"] = float(missed_budget) / raw_frames.size()
	result["over_33_33_ms_ratio"] = float(long_frames) / raw_frames.size()
	result["duration_ms"] = (previous - started) / 1000.0
	if phase == "drag":
		result["physics_session_members_start"] = physics_session_members_start
		result["physics_session_members_peak"] = physics_session_members_peak
		result["pointer_error_max_px"] = pointer_error_max_px
		result["pointer_trace"] = pointer_trace
		if pointer_error_max_px > 2.0:
			failures.append("Actual OS pointer must follow the generated trajectory within two physical pixels")
		result["subject_dragging_frame_ratio"] = float(active_drag_frames) / raw_frames.size()
		if active_drag_frames != raw_frames.size():
			failures.append("Requested subject must remain dragging throughout measurement")
	for metric in samples:
		var values: Array = samples[metric]
		values.sort()
		result[metric] = {"median": values[values.size()/2], "p95": values[mini(int(values.size() * .95), values.size()-1)], "p99": values[mini(int(values.size() * .99), values.size()-1)], "max": values[values.size()-1]}
	result["callback_cpu_mean_ms_per_frame"] = {}
	for name in probes:
		var totals: Dictionary = probes[name].perf_totals
		for method in totals:
			result.callback_cpu_mean_ms_per_frame[name + "." + method] = float(totals[method]) / samples.frame.size() / 1000.0
	result["callback_timings_available"] = not probes.is_empty()
	result["native_preview_render_samples"] = stage.group_overview.perf_preview_samples.duplicate(true) if not probes.is_empty() else []
	result["native_preview_capture_count"] = result.native_preview_render_samples.size() if not probes.is_empty() else -1
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

# Use the same physical-pixel transform as hidpi_stage_smoke. A group body's
# center may be a child or covered preview, so prove GUI ownership before press.
func _pick_drag_origin() -> Vector2:
	for attempt in 2:
		var controls: Array[Control] = []
		if not stage.group_overview.is_active(subject):
			controls.append(subject.label)
		var summaries: Dictionary = stage.group_overview._summaries
		var panel := summaries.get(subject.get_instance_id()) as Control
		if is_instance_valid(panel):
			var title := panel.get_node_or_null("Title") as Control
			if is_instance_valid(title):
				controls.append(title)
			controls.append(panel)
		for control in controls:
			if not is_instance_valid(control) or not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			for fraction in [Vector2(.5, .5), Vector2(.2, .5), Vector2(.8, .5), Vector2(.5, .05)]:
				var viewport_point: Vector2 = control.get_global_transform_with_canvas() * (control.size * fraction)
				var world_point: Vector2 = stage.get_canvas_transform().affine_inverse() * viewport_point
				var screen_point: Vector2 = _screen(world_point)
				if not Rect2(Vector2.ZERO, Vector2(root.size)).grow(-8.0).has_point(screen_point):
					continue
				_motion(world_point)
				await process_frame
				await process_frame
				var hovered: Control = stage.get_viewport().gui_get_hovered_control()
				if hovered == control:
					report["drag_input_control"] = str(control.get_path())
					return world_point
		# The original body's center may leave its header outside the viewport.
		var header_world: Vector2 = subject.label.get_global_transform() * (subject.label.size * .5)
		stage.camera.position = header_world
		stage.camera.target_position = header_world
		await process_frame
		await process_frame
	return Vector2.INF

func _physics_session_members() -> int:
	var session: Node = stage.get_node_or_null("PhysicsSession")
	if session == null:
		return -1
	var members: Variant = session.get("_members")
	return members.size() if members is Dictionary else -1
