extends SceneTree
const Corners = preload("res://src/main/continuous_corners.gd")
const Palette = preload("res://src/main/theme_palette.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 8: await process_frame
func _run() -> void:
	GraphPreferences.set_value("physics",false,false)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var a := stage.create_text_node("Source",Vector2(-250,0),false)
	var b := stage.create_text_node("Target",Vector2(250,0),false)
	a.freeze = true
	b.freeze = true
	var edge := stage.connect_entities(a,b)
	edge.text = "说明"
	edge.stroke_color = Color.YELLOW
	await settle()
	var caption = edge.get_node("Caption")
	for light in [false,true]:
		stage.apply_theme(light)
		edge.refresh_for_physics()
		await settle()
		var background: Color = Palette.color(light,"surface.canvas")
		var box := Corners.source(caption.label.get_theme_stylebox("normal"))
		check(box.bg_color.is_equal_approx(background), "Annotation background blends into the canvas")
		check(box.border_width_left == 0, "Annotation has no capsule outline")
		check(caption.label.get_theme_color("font_color").is_equal_approx(Palette.neutral_text_color(background)), "Annotation text adapts to canvas contrast")
		var width: float = caption.editor.measure_unwrapped(edge.text).x
		check(caption.label.size.x <= width + 32, "Annotation removes oversized capsule padding")
		var size: Vector2 = caption.label.size
		caption._set_hovered(true)
		await settle()
		check(caption.label.size == size, "Hover feedback does not move the annotation")
		caption._set_hovered(false)
		await settle()
		if not light:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pg-floating-caption.png")
	var group := stage.create_text_node("Group",Vector2.ZERO,false)
	a.container = group
	b.container = group
	group.fill_color = Color.WHITE
	stage.get_node("EntityLayerMover").refresh_layout()
	edge.refresh_for_physics()
	await settle()
	var group_background := Corners.source(caption.label.get_theme_stylebox("normal")).bg_color
	check(group_background.is_equal_approx(Palette.color(true,"surface.canvas").blend(group.display_fill_color())), "Annotation mask follows its container fill")
	check(caption.label.get_theme_color("font_color").r < 0.5, "White container uses contrasting dark annotation text")
	stage.queue_free()
	await process_frame
	print("FLOATING_CAPTION: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
