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
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1000, 800)
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	await process_frame
	var group := stage.create_text_node("键盘快捷键", Vector2.ZERO, false)
	group.freeze = true
	for light in [false, true]:
		group._container_active = false
		group._apply_appearance(true, light)
		group.set_loading_container_rect(Rect2(-400, -300, 800, 600))
		var style := Corners.source(group.label.get_theme_stylebox("normal"))
		check(style.border_width_top == 0 and style.border_width_bottom == 0 and style.bg_color.a == 0, "Loaded group title has no extra text box")
		check(Corners.source(group.container_panel.get_theme_stylebox("panel")).border_width_top == 1, "Container retains its own outline")
		check(group.label.text == "键盘快捷键", "Title text survives loading style transition")
		for frame in 4:
			await process_frame
	view.queue_free()
	await process_frame
	print("LOADING_TITLE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
