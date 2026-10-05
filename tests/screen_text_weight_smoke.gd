extends SceneTree
const Readability = preload("res://src/stage/text_readability.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func capture(view: SubViewport) -> Image:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()


func coverage(image: Image) -> float:
	var total := 0.0
	for y in image.get_height():
		for x in image.get_width():
			total += image.get_pixel(x, y).a
	return total


func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(400, 180)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var label := Label.new()
	label.text = "W 中文 English 101\n稳定布局"
	label.position = Vector2(24, 24)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.add_theme_font_override("font", CanvasTextMetrics.canvas_font())
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	view.add_child(label)
	var full_before := await capture(view)
	var font := label.get_theme_font("font")
	var minimum := label.get_minimum_size()
	var bounds := label.size
	var metrics := CanvasTextMetrics.measure(label.text, font, 24)
	Readability.apply(label, 24.0)
	var full_after := await capture(view)
	check(absf(coverage(full_after) - coverage(full_before)) < 0.05, "24px rendering stays unchanged")
	label.scale = Vector2.ONE / 3.0
	var small_before := await capture(view)
	Readability.apply(label, 8.0)
	var small_after := await capture(view)
	var original := coverage(small_before)
	var enhanced := coverage(small_after)
	print("SCREEN_TEXT_COVERAGE: ", original, " -> ", enhanced)
	check(original > 1.0, "Small baseline actually renders")
	check(enhanced > original * 1.03 and enhanced < original * 2.0, "8px text gains limited foreground coverage")
	check(label.get_minimum_size().is_equal_approx(minimum) and label.size.is_equal_approx(bounds), "Zoom compensation preserves Label geometry")
	check(label.get_theme_font("font") == font and CanvasTextMetrics.measure(label.text, font, 24).is_equal_approx(metrics), "Shared font and text metrics stay unchanged")
	var theme_changes := [0]
	label.theme_changed.connect(func(): theme_changes[0] += 1)
	Readability.apply(label, 8.1)
	await process_frame
	check(theme_changes[0] == 0, "Same optical tier does not invalidate shaping")
	label.add_theme_color_override("font_color", Color.TRANSPARENT)
	Readability.apply(label, 8.0)
	var editing := await capture(view)
	check(coverage(editing) < 0.01, "Transparent editing Label has no ghost outline")
	view.queue_free()
	await process_frame
	print("SCREEN_TEXT_WEIGHT: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
