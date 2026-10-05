extends SceneTree

var failures: Array[String] = []
var app

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 12:
		await process_frame
		await physics_frame

func _run() -> void:
	GraphPreferences.set_value("welcome", true, false)
	GraphPreferences.set_value("classroom", false, false)
	GraphPreferences.set_value("ui_scale", 100.0, false)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var welcome: Control = app.get_node("UIOverlay/Welcome")
	check(welcome.visible, "Welcome shown at startup")
	check(not app.tabs.is_visible_in_tree(), "Welcome and stage must not be visible together")
	check(not app.get_node("UIOverlay/Status").visible, "Canvas status hidden on welcome")
	var header: Control = app.get_node("VBoxContainer/Header")
	check(welcome.get_global_rect().position.y >= header.get_global_rect().end.y, "Welcome stays below header")
	var original_stage: Stage = app.tabs.get_current_stage()
	var node := original_stage.create_text_node("Existing document", Vector2.ZERO, false)
	original_stage.select_ids(PackedStringArray([node.id]))
	var count := original_stage.stage_objects().size()
	var click := InputEventMouseButton.new()
	click.position = Vector2(4, 590)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	if DisplayServer.get_name() != "headless":
		root.push_input(click, true)
		click.pressed = false
		root.push_input(click, true)
	await settle()
	check(original_stage.stage_objects().size() == count, "Welcome margins do not forward double clicks to stage")
	var remove := InputEventKey.new()
	remove.keycode = KEY_DELETE
	remove.pressed = true
	if DisplayServer.get_name() != "headless":
		app._input(remove)
	await settle()
	check(original_stage.stage_objects().size() == count, "Welcome blocks canvas delete shortcut")
	GraphPreferences.set_value("quick", true, false)
	app._apply_preferences()
	for dock in app.get_node("DockAutoHide")._docks:
		check(not dock.enabled, "Preference refresh keeps canvas docks disabled")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	if DisplayServer.get_name() != "headless":
		app._input(escape)
	else:
		welcome.hide()
	await settle()
	check(not welcome.visible and app.tabs.visible, "Escape restores stage")
	check(app.tabs.get_current_stage() == original_stage, "Returning preserves document")
	check(app.get_node("UIOverlay/Status").visible, "Returning restores status")
	app._run("welcome")
	await settle()
	check(welcome.visible and not app.tabs.visible, "Home hides existing stage")
	app.tabs.new_tab()
	await settle()
	check(not app.tabs.visible, "Adding a tab while welcome is visible keeps stage hidden")
	app._run("newDraft")
	await settle()
	check(not welcome.visible and app.tabs.visible, "New draft returns to stage")
	check(app.tabs.get_current_stage().stage_objects().is_empty(), "New draft is empty")
	app._run("welcome")
	await settle()
	if OS.get_cmdline_user_args().has("--visual"):
		for light in [false, true]:
			GraphPreferences.set_value("theme", "light" if light else "mocha", false)
			app._apply_preferences()
			for window_size in [Vector2i(1152, 648), Vector2i(800, 600)]:
				root.mode = Window.MODE_WINDOWED
				app.set_anchors_preset(Control.PRESET_TOP_LEFT)
				app.size = Vector2(window_size)
				app.position = Vector2.ZERO
				await settle()
				check(app.size.is_equal_approx(Vector2(window_size)), "Requested logical layout size")
				check(welcome.get_global_rect().position.y >= header.get_global_rect().end.y, "Resized welcome stays below header")
				check(welcome.get_global_rect().end.y <= app.size.y, "Welcome fits window height")
				await RenderingServer.frame_post_draw
				await process_frame
				await RenderingServer.frame_post_draw
				print("WELCOME_VISUAL: ", {"theme": GraphPreferences.value("theme"), "size": app.size, "rect": welcome.get_global_rect()})
				root.get_texture().get_image().save_png("/tmp/pg-welcome-%s-%d.png" % ["light" if light else "dark", window_size.x])
	welcome.hide()
	await settle()
	check(not welcome.visible and app.tabs.visible, "Hiding welcome restores stage")
	GraphPreferences.set_value("classroom", true, false)
	app._run("welcome")
	welcome.hide()
	check(not app.get_node("UIOverlay/Status").visible, "Returning respects classroom preference")

	app.queue_free()
	await process_frame
	print("WELCOME_STAGE: " + ("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
