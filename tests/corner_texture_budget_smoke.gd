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
	for radius in [18.0, 128.0, 512.0]:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("#313244")
		flat.border_color = Color("#cdd6f4")
		flat.set_border_width_all(1)
		var box := Corners.style(flat, radius, true) as StyleBoxTexture
		var pixels := box.texture.get_image()
		check(pixels.get_width() <= 512 and pixels.get_height() <= 512, "Canvas corner textures have a bounded raster size")
		check(pixels.has_mipmaps(), "Canvas corner textures retain mipmaps")
		check(Corners.source(box).corner_radius_top_left == int(radius), "Texture budget preserves logical radius")
		if radius == 18.0:
			check(pixels.get_width() >= int(box.texture.get_width()) * 3, "Normal node corners retain supersampling")
	print("CORNER_TEXTURE_BUDGET: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
