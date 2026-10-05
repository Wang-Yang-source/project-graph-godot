extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _run() -> void:
	var font := CanvasTextMetrics.canvas_font()
	check(font == TextNode._make_centered_canvas_font(load("res://assets/fonts/PingFang-SC-Regular.ttf")), "Planning and labels share one font")
	var base := font.base_font as FontFile
	check(base != null and base.multichannel_signed_distance_field and base.generate_mipmaps, "Native MSDF/mipmaps retained")
	check(base.msdf_size == 48 and base.msdf_pixel_range == 8 and is_zero_approx(font.variation_embolden), "MSDF profile retained")
	var glyphs := base.get_glyph_list(0, Vector2i(48, 0))
	check(glyphs.size() > 6000, "Common glyphs shipped in resource")
	var count := glyphs.size()
	var editor := TextEdit.new()
	editor.add_theme_font_override("font", font)
	editor.add_theme_constant_override("line_spacing", 3)
	root.add_child(editor)
	for point_size in [12, 24, 40, 100]:
		editor.add_theme_font_size_override("font_size", point_size)
		for text in ["Waya!", "测试文字", "第一行\n第二行", "", "A\tB", "العربية"]:
			editor.text = text
			await process_frame
			var measured := CanvasTextMetrics.measure(text, font, point_size)
			check(measured.y == editor.get_line_height() * maxi(1, text.split("\n").size()), "Native line height matches cache: %s/%s/%s/%s" % [point_size,text,measured.y,editor.get_line_height()])
			check(measured == CanvasTextMetrics.measure(text, font, point_size), "Measurements reused without change")
	check(base.get_glyph_list(0, Vector2i(48, 0)).size() <= count + 30, "Common text does not regenerate font")
	editor.queue_free()
	await process_frame
	print("CANVAS_FONT_CACHE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
