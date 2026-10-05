extends SceneTree
const Corners = preload("res://src/main/continuous_corners.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _edge_brightness(image: Image, x: int, y: int) -> float:
	var brightest := 0.0
	for offset in range(-4, 5):
		var color := image.get_pixel(clampi(x, 0, image.get_width()-1), clampi(y + offset, 0, image.get_height()-1))
		brightest = maxf(brightest, (color.r + color.g + color.b) / 3.0)
	return brightest

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	await process_frame
	var group := stage.create_text_node("Group heading", Vector2(100, 100), false)
	var child := stage.create_text_node("Content inside the group", Vector2(200, 250), false)
	child.container = group
	stage.select_ids(PackedStringArray())
	for frame in 8:
		await process_frame
	var header := Corners.source(group.label.get_theme_stylebox("normal"))
	var panel := Corners.source(group.container_panel.get_theme_stylebox("panel"))
	var inset := float(panel.border_width_top)
	check(header.expand_margin_top == -inset and header.expand_margin_left == -inset and header.expand_margin_right == -inset, "Heading backing must stay inside the container border")
	check(header.content_margin_left == 15 and header.content_margin_top == 10, "Text padding must remain unchanged")
	check(group.label.position == group.container_panel.position, "Heading and group geometry must retain their origin")
	stage.camera.position = group.aabb.get_center()
	stage.camera.target_position = stage.camera.position
	stage.camera.zoom = Vector2.ONE * 1.5
	stage.camera.target_zoom = stage.camera.zoom
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var transform := root.get_final_transform() * group.container_panel.get_global_transform_with_canvas()
	var rect := transform * Rect2(Vector2.ZERO, group.container_panel.size)
	var x := roundi(rect.get_center().x)
	var top := _edge_brightness(image, x, roundi(rect.position.y))
	var bottom := _edge_brightness(image, x, roundi(rect.end.y))
	check(top >= bottom * 0.85, "Top border must retain brightness comparable to bottom border")
	stage.queue_free()
	await process_frame
	print("GROUP_HEADER_BORDER: ", "PASS" if failures.is_empty() else str(failures), " top=", top, " bottom=", bottom)
	quit(0 if failures.is_empty() else 1)
