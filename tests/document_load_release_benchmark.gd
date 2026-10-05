extends Node
## Release entry point; PG_LOAD_DOCUMENT is read only, never saved.
var done := false
var succeeded := false
@onready var root: Window = get_tree().root

func _ready() -> void:
	call_deferred("_run")

func _load_document(stage: Stage, path: String) -> void:
	succeeded = await stage.load_from_file(path)
	done = true

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("welcome", false, false)
	root.size = Vector2i(1280, 800)
	var path := OS.get_environment("PG_LOAD_DOCUMENT")
	if path.is_empty():
		push_error("PG_LOAD_DOCUMENT must identify a read-only fixture")
		get_tree().quit(2)
		return
	var hash_before := FileAccess.get_sha256(path)
	var app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	for i in 10:
		await get_tree().process_frame
	var stage: Stage = app.tabs.get_current_stage()
	var started := Time.get_ticks_usec()
	var previous := started
	var phases := {}
	var intervals: Array[float] = []
	var max_ms := float(OS.get_environment("PG_MAX_LOAD_MS")) if not OS.get_environment("PG_MAX_LOAD_MS").is_empty() else 0.0
	_load_document(stage, path)
	while not done and Time.get_ticks_usec() - started < 60000000:
		var phase := -1
		for child in root.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://src/project_loader.gd":
				phase = int(child.get("_phase"))
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var interval := (now - previous) / 1000.0
		intervals.append(interval)
		phases[str(phase)] = phases.get(str(phase), 0.0) + interval
		previous = now
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var total_ms := (Time.get_ticks_usec() - started) / 1000.0
	var objects := stage.stage_objects()
	var valid := done and succeeded and not stage.is_loading and not stage.history._busy and not stage.is_dirty()
	for object in objects:
		if object is LineEdge:
			valid = valid and is_instance_valid(object.source) and is_instance_valid(object.target)
	var loaded := ProjectFile.load(path)
	valid = valid and loaded.ok and objects.size() == loaded.graph.get("objects", []).size()
	valid = valid and FileAccess.get_sha256(path) == hash_before
	intervals.sort()
	var report := JSON.stringify({"file":path.get_file(),"objects":objects.size(),"total_ms":total_ms,
		"p95_frame_ms":intervals[int(intervals.size() * .95)] if not intervals.is_empty() else 0,
		"max_frame_ms":intervals.back() if not intervals.is_empty() else 0,"phases_ms":phases,
		"native_nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),"valid":valid,
		"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()})
	FileAccess.open("/tmp/pg-load-release-result.json",FileAccess.WRITE).store_string(report)
	print("LOAD_RELEASE: ",report)
	var screenshot := OS.get_environment("PG_LOAD_SCREENSHOT")
	if not screenshot.is_empty() and DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(screenshot)
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if valid and (max_ms <= 0 or total_ms <= max_ms) else 1)
