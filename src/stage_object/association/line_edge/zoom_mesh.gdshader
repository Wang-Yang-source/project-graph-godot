shader_type canvas_item;
render_mode unshaded;
uniform float stroke_width = 2.0;
uniform float envelope_width = 102.0;
uniform float pixel_scale = 1.0;
varying float edge_distance;
varying float half_width;
varying vec4 stroke_color;
void vertex() {
	bool positive = UV.x > 50.0;
	vec2 offset = UV - vec2(positive ? 100.0 : 0.0, 0.0);
	float scale = max(length((CANVAS_MATRIX * MODEL_MATRIX)[0].xy), 0.000001);
	float width = ceil((max(1.0, stroke_width * scale / pixel_scale) + 1.0) * 4.0) * 0.25 * pixel_scale;
	VERTEX += offset * (width / scale - envelope_width) * 0.5;
	half_width = width * 0.5;
	edge_distance = (positive ? 1.0 : -1.0) * half_width;
	stroke_color = COLOR;
}
void fragment() {
	float coverage = clamp((half_width - abs(edge_distance)) / pixel_scale, 0.0, 1.0);
	COLOR = stroke_color * vec4(1.0, 1.0, 1.0, coverage);
}
