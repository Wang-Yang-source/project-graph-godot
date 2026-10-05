extends SceneTree
var failures: Array[String] = []
var app
var stage: Stage

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 8:
		await process_frame
		await physics_frame

func _run() -> void:
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("physics", false, false)
	GraphPreferences.set_value("ui_scale", 200.0, false)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	stage = app.tabs.get_current_stage()
	var tab: Control = app.tabs.get_tab_control(app.tabs.current_tab)
	var view: SubViewport = stage.get_viewport()
	var screen_scale := (root.get_final_transform() * tab.get_global_transform_with_canvas()).get_scale().abs()
	print("HIDPI_METRICS: ", {"root_size": root.size, "root_factor": root.content_scale_factor, "root_final": root.get_final_transform(), "tab_size": tab.size, "tab_screen": tab.get_screen_transform(), "view_size": view.size, "view_final": view.get_final_transform()})
	var expected := Vector2i((tab.size * screen_scale).ceil())
	check(view.size.x >= expected.x and view.size.y >= expected.y, "Stage renders at screen pixel resolution under UI scaling")
	check(view.get_visible_rect().size.is_equal_approx(tab.size.round()), "High DPI preserves logical viewport dimensions")
	var a := stage.create_text_node("中文清晰度 English 123", Vector2(-160, -70), false)
	var b := stage.create_text_node("文字与斜线", Vector2(160, 70), false)
	a.freeze = true
	b.freeze = true
	var edge := stage.connect_entities(a, b)
	edge.text = "连线标签"
	stage.camera.target_position = Vector2.ZERO
	stage.camera.target_zoom = Vector2.ONE
	stage.camera.position = Vector2.ZERO
	stage.camera.zoom = Vector2.ONE
	stage.select_ids(PackedStringArray())
	await settle()
	var size_before := view.size
	var positions := [a.position, b.position]
	for zoom_value in [0.25, 1.0, 3.0]:
		stage.camera.target_zoom = Vector2.ONE * zoom_value
		stage.camera.zoom = stage.camera.target_zoom
		await settle()
		check(view.size == size_before, "Camera zoom does not reallocate viewport")
		check(a.position == positions[0] and b.position == positions[1], "Sampling changes preserve world positions")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pg-hidpi-%s-%s.png" % [OS.get_environment("PG_HIDPI_PHASE"), zoom_value])
	stage.camera.target_zoom = Vector2.ONE
	stage.camera.zoom = Vector2.ONE
	await settle()
	var received: Array[Vector2] = []
	a.label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			received.append(event.position))
	var logical_point := a.label.size * 0.5
	var canvas: Control = view.get_parent()
	var physical_point := root.get_final_transform() * canvas.get_global_transform_with_canvas() * view.get_final_transform() * a.label.get_global_transform_with_canvas() * logical_point
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = physical_point
	click.global_position = physical_point
	root.push_input(click)
	await settle()
	check(not received.is_empty() and received[0].distance_to(logical_point) < 1.0, "Native canvas input hits rendered label without DPI offset")
	click.pressed = false
	root.push_input(click)
	check(stage.camera.grid_material.get_shader_parameter("render_scale").is_equal_approx(view.get_final_transform().get_scale()), "Grid uses the same physical pixel scale as objects")
	GraphPreferences.set_value("ui_scale", 125.0, false)
	app._apply_preferences()
	await settle()
	tab = app.tabs.get_tab_control(app.tabs.current_tab)
	screen_scale = (root.get_final_transform() * tab.get_global_transform_with_canvas()).get_scale().abs()
	expected = Vector2i((tab.size * screen_scale).ceil())
	check(view.size.x >= expected.x and view.size.y >= expected.y, "Fractional UI scale retains screen pixel resolution")
	check(view.get_visible_rect().size.is_equal_approx(tab.size.round()), "Fractional scaling preserves viewport coordinates")
	var extra: Stage = app.tabs.new_tab("DPI close regression")
	await settle()
	app.tabs.close_container(extra.get_parent().get_parent())
	await settle()
	check(app.tabs.get_tab_count() == 1 and app.tabs.get_current_stage() == stage, "Closing native canvas resolves its owning tab")
	app.queue_free()
	await process_frame
	print("HIDPI_STAGE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
