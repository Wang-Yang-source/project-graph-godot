extends SceneTree
var failures: Array[String] = []
var children: Array[int] = []
var app
var fixture_two := "/tmp/pg-open-tabs-" + str(OS.get_process_id()) + " second.prg"
var fixture := "/tmp/pg-open-tabs-" + str(OS.get_process_id()) + " 中文.prg"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		for pid in children:
			if OS.is_process_running(pid):
				OS.kill(pid)
		push_error("Single-instance test watchdog expired")
		quit(1)
	)
	GraphPreferences._loaded = true
	GraphPreferences.set_value("physics", false, false)
	check(ProjectFile.save(fixture, {"objects": []}, {"position": [0, 0], "zoom": 1.0}).ok, "Fixture saves")
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	for frame in 30:
		await process_frame
	var initial: Stage = app.tabs.get_current_stage()
	initial.create_text_node("unsaved work", Vector2.ZERO)
	var count: int = app.tabs.get_tab_count()
	await launch(PackedStringArray([fixture]))
	check(app.tabs.get_tab_count() == count + 1, "External launch opens a tab in the existing window")
	check(app.tabs.get_current_stage().current_file_path == fixture, "New document becomes current")
	check(is_instance_valid(initial) and initial.stage_objects().size() == 1, "Unsaved original tab is preserved")
	await launch(PackedStringArray([fixture]))
	check(app.tabs.get_tab_count() == count + 1, "Reopening document reuses existing tab")
	check(ProjectFile.save(fixture_two, {"objects": []}, {"position": [0, 0], "zoom": 1.0}).ok, "Second fixture saves")
	await launch(PackedStringArray([fixture, fixture_two]))
	check(app.tabs.get_tab_count() == count + 2, "Multi-file launch creates only missing tabs")
	check(app.tabs.get_current_stage().current_file_path == fixture_two, "Last requested document becomes current")
	var endpoint: String = app._document_instance._endpoint
	app.free()
	for frame in 5:
		await process_frame
	check(not FileAccess.file_exists(endpoint), "Closing owner removes discovery endpoint")
	var boot = load("res://src/boot/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	var deadline := Time.get_ticks_msec() + 10000
	while current_scene == boot and Time.get_ticks_msec() < deadline:
		await process_frame
	app = current_scene
	check(app != boot, "Normal boot creates a replacement owner after close")
	if app != boot:
		await launch(PackedStringArray([fixture]))
		check(app.tabs.get_tab_count() == 1, "Replacement owner opens into its initial blank tab workspace")
		check(app.tabs.get_current_stage().current_file_path == fixture, "Replacement owner receives file")
	if app != boot and not OS.get_environment("PG_TEST_DESKTOP").is_empty():
		var output: Array = []
		var entry := OS.get_environment("PG_TEST_DESKTOP")
		check(OS.execute("gio", PackedStringArray(["launch", entry, fixture_two]), output, true) == 0, "Registered desktop launcher starts")
		var launch_deadline := Time.get_ticks_msec() + 10000
		while app.tabs.get_current_stage().current_file_path != fixture_two and Time.get_ticks_msec() < launch_deadline:
			await process_frame
		check(app.tabs.get_tab_count() == 2 and app.tabs.get_current_stage().current_file_path == fixture_two, "File-manager desktop entry opens another tab in the existing workspace")
		for frame in 60:
			await process_frame
	app.free()
	DirAccess.remove_absolute(fixture_two)
	DirAccess.remove_absolute(fixture)
	print("SINGLE_INSTANCE_OPEN_SMOKE ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func launch(paths: PackedStringArray) -> void:
	var executable := OS.get_environment("PG_TEST_BINARY")
	var args := PackedStringArray(["--display-driver", "x11", "--rendering-method", "gl_compatibility"])
	if executable.is_empty():
		executable = OS.get_executable_path()
		args.append_array(PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]))
	args.append("--")
	args.append_array(paths)
	var pid := OS.create_process(executable, args)
	children.append(pid)
	check(pid > 0, "Second process starts")
	var deadline := Time.get_ticks_msec() + 10000
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not OS.is_process_running(pid), "Second process forwards files and exits instead of leaving another window")
	if OS.is_process_running(pid):
		OS.kill(pid)
	for frame in 20:
		await process_frame
