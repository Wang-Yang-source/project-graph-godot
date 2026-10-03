extends SceneTree
const Corners = preload("res://src/main/continuous_corners.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1000, 800)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var parent := Node2D.new()
	parent.position = Vector2(100, 100)
	view.add_child(parent)
	var panel := Panel.new()
	panel.name = "ContainerPanel"
	panel.size = Vector2(1000, 700)
	parent.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.9, 0.7)
	style.border_color = Color.WHITE
	style.set_border_width_all(1)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", Corners.style(style, 24, true, true))
	var border := Line2D.new()
	border.set_script(load("res://src/minimum_screen_border.gd"))
	border.style_name = &"panel"
	border.width = 1
	border.closed = true
	border.antialiased = true
	panel.add_child(border)
	await process_frame
	var changes := [0]
	panel.theme_changed.connect(func(): changes[0] += 1)
	var textures_before := Corners._textures.size()
	var minimum := panel.get_minimum_size()
	for step in 120:
		parent.scale = Vector2.ONE * exp(lerpf(log(0.02), log(1.1), step / 119.0))
		await process_frame
		check(panel.size == Vector2(1000,700) and panel.get_minimum_size() == minimum, "Navigation preserves control layout")
	check(Corners._textures.size() == textures_before, "Zoom does not rasterize additional corner textures")
	check(changes[0] <= 3, "Zoom does not repeatedly invalidate control themes")
	parent.scale = Vector2.ONE * 0.4
	await process_frame
	var adapted := panel.get_theme_stylebox("panel")
	for jitter in [0.400001, 0.400003, 0.400007]:
		parent.scale = Vector2.ONE * jitter
		await process_frame
		check(panel.get_theme_stylebox("panel") == adapted, "Sub-bucket zoom retains the same style resource")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var pixels := view.get_texture().get_image()
		pixels.save_png("/tmp/pg-group-border-navigation.png")
		check(pixels.get_pixel(300,240).a > 0.65, "Adaptive rounded group retains its fill")
	var before_cull: Array = border._refresh_key.duplicate()
	parent.position = Vector2(10000, 10000)
	parent.scale = Vector2.ONE * 0.1
	await process_frame
	check(border._refresh_key == before_cull, "Offscreen zoom defers rounded geometry")
	parent.position = Vector2(100, 100)
	await process_frame
	check(border._refresh_key != before_cull, "Returning onscreen refreshes deferred geometry")
	var changed := style.duplicate() as StyleBoxFlat
	changed.bg_color = Color(0.8, 0.3, 0.1, 0.7)
	panel.add_theme_stylebox_override("panel", Corners.style(changed, 24, true, true))
	await process_frame
	check(border._group_fill.color == changed.bg_color, "Theme edits refresh the native group fill")
	parent.scale = Vector2.ONE * 1.1
	await process_frame
	check(Corners.source(panel.get_theme_stylebox("panel")).border_width_top == 1, "Normal zoom restores original style")
	view.queue_free()
	await process_frame
	print("GROUP_BORDER_NAVIGATION: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
