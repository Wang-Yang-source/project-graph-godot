extends SceneTree
## Render the shared canvas font through Label; W has no enclosed counters.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var font = TextNode._make_centered_canvas_font(load("res://assets/fonts/PingFang-SC-Regular.ttf"))
	for zoom in [1.0, 2.0, 4.0]:
		var viewport = SubViewport.new()
		viewport.size = Vector2i(320, 300)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var label = Label.new()
		label.text = "W"
		label.position = Vector2(20, 20)
		label.scale = Vector2(zoom, zoom)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 48)
		label.add_theme_color_override("font_color", Color.WHITE)
		viewport.add_child(label)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image = viewport.get_texture().get_image()
		image.save_png("/tmp/pg-msdf-W-%d.png" % int(zoom))
		var holes = count_enclosed_background(image)
		print("MSDF_W zoom=", zoom, " enclosed_background_pixels=", holes)
		if holes != 0:
			failures.append("W has holes at zoom " + str(zoom))
		var foreground = 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.9:
					foreground += 1
		if foreground < 100:
			failures.append("Glyph did not render at zoom " + str(zoom))
		viewport.queue_free()
		await process_frame
	print("MSDF_GLYPH_INTEGRITY: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
func count_enclosed_background(image: Image) -> int:
	var width = image.get_width()
	var height = image.get_height()
	var seen = PackedByteArray()
	seen.resize(width * height)
	var pending: Array[Vector2i] = []
	for x in width:
		pending.append(Vector2i(x, 0))
		pending.append(Vector2i(x, height - 1))
	for y in height:
		pending.append(Vector2i(0, y))
		pending.append(Vector2i(width - 1, y))
	while not pending.is_empty():
		var p = pending.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= width or p.y >= height:
			continue
		var index = p.y * width + p.x
		if seen[index] or image.get_pixel(p.x, p.y).a >= 0.1:
			continue
		seen[index] = 1
		pending.append(p + Vector2i.LEFT)
		pending.append(p + Vector2i.RIGHT)
		pending.append(p + Vector2i.UP)
		pending.append(p + Vector2i.DOWN)
	var enclosed = 0
	for y in height:
		for x in width:
			if not seen[y * width + x] and image.get_pixel(x, y).a < 0.1:
				enclosed += 1
	return enclosed
