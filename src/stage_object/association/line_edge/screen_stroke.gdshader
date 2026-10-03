shader_type canvas_item;
render_mode unshaded;

uniform float stroke_ratio = 0.02;
uniform float pixel_scale = 1.0;
varying vec4 stroke_color;

void vertex() {
	stroke_color = COLOR;
}

void fragment() {
	float uv_per_pixel = max(length(vec2(dFdx(UV.y), dFdy(UV.y))), 0.000001);
	float mesh_pixels = 1.0 / uv_per_pixel;
	float logical_stroke = max(1.0, stroke_ratio * mesh_pixels / pixel_scale);
	float expanded_width = ceil((logical_stroke + 1.0) * 4.0) * 0.25 * pixel_scale;
	float distance_pixels = abs(UV.y - 0.5) * mesh_pixels;
	float coverage = clamp((expanded_width * 0.5 - distance_pixels) / pixel_scale, 0.0, 1.0);
	COLOR = stroke_color * vec4(1.0, 1.0, 1.0, coverage);
}
