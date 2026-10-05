extends RefCounted
## Optical compensation only: native outlines leave shaping and document geometry intact.
const PIXEL_THRESHOLDS := [6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0]
const CACHE_VERSION := "optical-text-v1"


static func apply(label: Label, pixels: float) -> void:
	var bucket := clampi(ceili((18.0 - pixels) / 2.0), 0, 7) if is_finite(pixels) else 0
	var foreground := label.get_theme_color("font_color")
	var font_size := label.get_theme_font_size("font_size")
	# The shared MSDF range is 8; native outlines must remain at most half that.
	var width := clampi(ceili(float(font_size) / 8.0), 1, 4)
	var size := width if bucket > 0 and foreground.a > 0.0 else 0
	var outline := foreground if size > 0 else Color.TRANSPARENT
	outline.a *= float(bucket) * 0.1 * minf(float(font_size) / (8.0 * width), 1.0)
	var key := [size, outline]
	if label.get_meta("optical_text_key", []) == key:
		return
	label.set_meta("optical_text_key", key)
	label.begin_bulk_theme_override()
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", outline)
	label.end_bulk_theme_override()
