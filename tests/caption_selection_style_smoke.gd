extends SceneTree
const Corners = preload("res://src/main/continuous_corners.gd")
var failures: Array[String] = []
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
	var app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var stage: Stage = app.tabs.get_current_stage()
	var a := stage.create_text_node("起点", Vector2(-200,-100), false)
	var b := stage.create_text_node("终点", Vector2(200,100), false)
	a.freeze = true
	b.freeze = true
	var edge := stage.connect_entities(a,b)
	edge.use_theme_color = false
	edge.text = "3次"
	var caption = edge.get_node("Caption")
	for light in [false,true]:
		app._apply_preferences("theme", "latte" if light else "mocha")
		for color in [Color("#ffcc00"), Color("#203060")]:
			edge.stroke_color = color
			await settle()
			var background := Corners.source(caption.label.get_theme_stylebox("normal")).bg_color
			caption.begin_edit()
			caption.editor.select_all()
			await settle()
			var selection: Color = caption.editor.get_theme_color("selection_color")
			var foreground: Color = caption.editor.get_theme_color("font_color")
			check(selection.a > 0 and selection.a <= 0.25, "Selection gently overlays the caption color instead of an opaque dark block")
			check(caption.editor.get_theme_color("font_selected_color") == foreground, "Selected text retains caption contrast")
			check(Corners.source(caption.label.get_theme_stylebox("normal")).bg_color.a == 1.0, "Editing keeps an opaque line mask with subtle focus feedback")
			check(caption.editor.has_selection(), "Fixture exercises selected caption text")
			if not light and color == Color("#ffcc00") and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/pg-caption-selection-%s.png" % OS.get_environment("PG_CAPTION_PHASE"))
			caption.editor.text = "取消草稿"
			caption.editor.text_changed.emit()
			caption.editor.cancel_requested.emit()
			await settle()
			check(edge.text == "3次" and not caption.editor.visible, "Cancel restores original caption")
	caption.begin_edit()
	caption.editor.text = "4次"
	caption.editor.text_changed.emit()
	caption.editor.commit_requested.emit()
	await settle()
	check(edge.text == "4次" and not caption.editor.visible, "Commit restores display with the updated caption")
	app.queue_free()
	await process_frame
	print("CAPTION_SELECTION_STYLE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
