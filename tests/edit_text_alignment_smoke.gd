extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 6: await process_frame
func ink_center(view: SubViewport, label: Label, foreground: Color) -> Vector2:
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	var transform := view.get_final_transform() * label.get_global_transform_with_canvas()
	var crop := (transform * Rect2(Vector2(12,8), label.size - Vector2(32,16))).intersection(Rect2(Vector2.ZERO,Vector2(view.size)))
	var sum := Vector2.ZERO
	var count := 0
	for y in range(ceili(crop.position.y), floori(crop.end.y)):
		for x in range(ceili(crop.position.x), floori(crop.end.x)):
			var color := pixels.get_pixel(x,y)
			if color.a > 0.8 and Vector3(color.r,color.g,color.b).distance_to(Vector3(foreground.r,foreground.g,foreground.b)) < 0.12:
				sum += Vector2(x,y)
				count += 1
	check(count > 10, "Visible glyph fixture contains enough ink")
	return sum / maxi(count,1)
func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200,800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	stage.get_node("CanvasLayer/Grid").hide()
	await settle()
	var a := stage.create_text_node("编辑 English 3次", Vector2(-200,0), false)
	var b := stage.create_text_node("终点", Vector2(200,0), false)
	a.freeze = true
	b.freeze = true
	a.fill_color = Color.WHITE
	a.text_color = Color.BLACK
	var edge := stage.connect_entities(a,b)
	edge.text = "3次 English"
	edge.stroke_color = Color.WHITE
	edge.use_theme_color = false
	var caption = edge.get_node("Caption")
	stage.select_ids(PackedStringArray())
	for object in [a,edge]:
		var label: Label = a.label if object == a else caption.label
		var editor: TextEdit = a.text_edit if object == a else caption.editor
		var foreground := label.get_theme_color("font_color")
		for zoom_value in [1.0,2.0]:
			stage.camera.target_zoom = Vector2.ONE * zoom_value
			stage.camera.zoom = stage.camera.target_zoom
			stage.camera.position = object.position if object == a else caption.global_position
			stage.camera.target_position = stage.camera.position
			await settle()
			var before := await ink_center(view,label,foreground)
			object.enter_edit_mode()
			editor.add_theme_color_override("caret_color", Color.TRANSPARENT)
			await settle()
			var during := await ink_center(view,label,foreground)
			print("EDIT_ALIGNMENT: ", {"object":object.get_class(),"zoom":zoom_value,"before":before,"during":during,"shift":during-before,"label":label.get_character_bounds(0),"editor":editor.get_rect_at_line_column(0,0)})
			check(before.distance_to(during) <= 0.6, "Entering editing keeps glyphs in place")
			object.exit_edit_mode(false)
			await settle()
			var after := await ink_center(view,label,foreground)
			check(before.distance_to(after) <= 0.6, "Cancel editing preserves glyph position")
	view.queue_free()
	await process_frame
	print("EDIT_TEXT_ALIGNMENT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
