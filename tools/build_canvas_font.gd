extends SceneTree
## Native pre-rendered MSDF cache. Character manifest is stable across documents.
func _initialize() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fonts/canvas-characters.json"))
	var original: FontFile = load("res://assets/fonts/PingFang-SC-Regular.ttf")
	var font := original.duplicate() as FontFile
	font.multichannel_signed_distance_field = true
	font.msdf_pixel_range = 8
	font.msdf_size = 48
	font.generate_mipmaps = true
	var started := Time.get_ticks_usec()
	for value in manifest:
		var codepoint := int(value)
		if font.has_char(codepoint):
			font.render_range(0, Vector2i(48, 0), codepoint, codepoint)
	var error := ResourceSaver.save(font, "res://assets/fonts/canvas-msdf.res", ResourceSaver.FLAG_COMPRESS)
	FileAccess.open("/tmp/pg-canvas-font-build.json", FileAccess.WRITE).store_string(JSON.stringify({
		"error":error,"characters":manifest.size(),"duration_ms":(Time.get_ticks_usec()-started)/1000.0,
		"resource_bytes":FileAccess.get_file_as_bytes("res://assets/fonts/canvas-msdf.res").size()}))
	quit(0 if error == OK else 1)
