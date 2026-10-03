extends Line2D
## View-only fallback for a Control border thinner than one viewport pixel.
## The normal style continues to own its fill, margins and world geometry.

const Corners = preload("res://src/main/continuous_corners.gd")
const MIN_GROUP_SCREEN_RADIUS := 10.0

@export var style_name: StringName = &"normal"
@onready var _control: Control = get_parent() as Control
var _refresh_key: Array = []
var _event_driven := false
var _stage: Node2D
var _view_bounds := Rect2()
var _view_cache_valid := false
var _in_view := false
var _view_bucket := -2147483648
var _zoom_step_offset := 0.0
var _bucket_offset := 0.0
var _basis_key := Transform2D.IDENTITY
var _outline_key: Array = []
var _outline := PackedVector2Array()
var _group_style: StyleBox
var _group_mask: StyleBoxEmpty
var _group_fill: Polygon2D


func _ready() -> void:
	width = 1.0
	get_viewport().size_changed.connect(_queue_refresh)
	# Overview masks are restored at priority 50; refresh after that transition.
	process_priority = 51
	_control.resized.connect(_queue_refresh)
	_control.theme_changed.connect(_queue_refresh)
	_control.visibility_changed.connect(_queue_refresh)
	var ancestor: Node = _control
	while ancestor != null:
		if ancestor.has_signal("geometry_changed"):
			ancestor.connect("geometry_changed", _queue_refresh)
			_bucket_offset = float(posmod(str(ancestor.get("id")).hash(), 16)) / 16.0
		if ancestor.has_signal("view_changed"):
			ancestor.connect("view_changed", _on_view_changed)
			_stage = ancestor as Node2D
			_event_driven = true
			break
		ancestor = ancestor.get_parent()


func _queue_refresh(_world_rect: Rect2 = Rect2(), _zoom_steps: float = 0.0) -> void:
	_view_cache_valid = false
	set_process(true)


func _on_view_changed(world_rect: Rect2, zoom_steps: float) -> void:
	if not _view_cache_valid:
		set_process(true)
		return
	var was_in_view := _in_view
	_in_view = world_rect.intersects(_view_bounds, true)
	# Panning moves the canvas, not the baked border. Wake only on entry or
	# when its existing per-octave sampling bucket changes.
	if _in_view and (not was_in_view or floori(zoom_steps + _zoom_step_offset) != _view_bucket):
		set_process(true)


func _process(_delta: float) -> void:
	if _event_driven:
		set_process(false)
	if _stage != null:
		_view_bounds = _control.get_global_transform() * Rect2(Vector2.ZERO, _control.size)
		var scale_transform := get_viewport().get_final_transform() * _control.get_global_transform_with_canvas()
		var scale_value := maxf(minf(scale_transform.x.length(), scale_transform.y.length()), .01)
		var stage_scale := maxf(_stage.get_global_transform_with_canvas().get_scale().x, .01)
		_zoom_step_offset = log(scale_value / stage_scale) / log(2.0) * 16.0 + _bucket_offset
		_view_bucket = floori(log(scale_value) / log(2.0) * 16.0 + _bucket_offset)
		_in_view = (_stage.get("world_view_rect") as Rect2).grow(64.0 / stage_scale).intersects(_view_bounds, true)
		_view_cache_valid = true
	var ancestor: CanvasItem = _control
	while ancestor != null:
		if ancestor.visibility_layer & get_viewport().canvas_cull_mask == 0:
			return
		ancestor = null if ancestor.top_level else ancestor.get_parent() as CanvasItem
	if not _control.is_visible_in_tree() or visibility_layer == 0:
		return
	var render_transform := get_viewport().get_final_transform()
	var canvas := render_transform * _control.get_global_transform_with_canvas()
	# Defer offscreen style and outline work until the camera returns.
	if not (canvas * Rect2(Vector2.ZERO, _control.size)).intersects((render_transform * get_viewport_rect()).grow(2.0), true):
		return
	var current := _control.get_theme_stylebox(style_name)
	# Theme/appearance edits may replace the display-only mask.
	if _group_mask != null and current != _group_mask:
		_group_style = null
		_group_mask = null
	var original := Corners.source(_group_style if _group_style != null else current)
	if original == null:
		hide()
		return
	var border_width := float(original.border_width_left)
	# Full basis inversion keeps the border aligned even on rotated/scaled nodes.
	var basis := Transform2D(canvas.x, canvas.y, Vector2.ZERO)
	if is_zero_approx(basis.determinant()):
		hide()
		return
	var actual_scale := minf(canvas.x.length(), canvas.y.length())
	# Keep real group corners legible even before overview titles activate.
	var corner_bucket := floori(log(actual_scale) / log(2.0) * 16.0 + _bucket_offset)
	var corner_scale := pow(2.0, (corner_bucket - _bucket_offset) / 16.0)
	var radius := float(original.corner_radius_top_left)
	if _control.name == &"ContainerPanel":
		radius = Corners.fitted_radius(_control.size,
			maxf(Corners.PANEL, MIN_GROUP_SCREEN_RADIUS / corner_scale), border_width)
		_sync_group_fill(current, original, border_width * actual_scale < 1.0)
	visible = border_width > 0.0 and original.border_color.a > 0.0 and border_width * actual_scale < 1.0
	if not visible:
		return
	# Round down: between buckets the core grows slightly, never below one pixel.
	var bucket := floori(log(actual_scale) / log(2.0) * 16.0 + _bucket_offset)
	var sampled_scale := pow(2.0, (bucket - _bucket_offset) / 16.0)
	var normalized_basis := Transform2D(canvas.x / actual_scale, canvas.y / actual_scale, Vector2.ZERO)
	var ratio := sampled_scale / actual_scale
	basis.x *= ratio
	basis.y *= ratio
	var key := [bucket, _control.size, radius, border_width, original.border_color]
	if key == _refresh_key and normalized_basis.is_equal_approx(_basis_key):
		return
	_refresh_key = key
	_basis_key = normalized_basis
	transform = basis.affine_inverse()
	default_color = original.border_color
	var outline_key := [_control.size, radius, border_width]
	if outline_key != _outline_key:
		_outline_key = outline_key
		_outline = Corners.outline(Rect2(Vector2.ZERO, _control.size).grow(-border_width * 0.5), maxf(0.0, radius - border_width * 0.5))
	# Native packed-array transformation avoids a GDScript loop per corner point.
	points = basis * _outline
	if _group_fill != null:
		_group_fill.polygon = points


func _sync_group_fill(current: StyleBox, original: StyleBoxFlat, adaptive: bool) -> void:
	# Reuse native geometry instead of rasterizing SVGs and invalidating the
	# Control theme at every zoom bucket. This mask preserves content margins.
	if not adaptive:
		if _group_style != null:
			_control.add_theme_stylebox_override(style_name, _group_style)
			_group_style = null
			_group_mask = null
		if _group_fill != null:
			_group_fill.hide()
		return
	if _group_mask == null:
		_group_style = current
		_group_mask = StyleBoxEmpty.new()
		_group_mask.set_meta(Corners.SOURCE_META, original)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_group_mask.set_content_margin(side, current.get_content_margin(side))
		_control.add_theme_stylebox_override(style_name, _group_mask)
	if _group_fill == null:
		_group_fill = Polygon2D.new()
		_group_fill.name = "RoundedFill"
		_group_fill.antialiased = true
		_group_fill.show_behind_parent = true
		add_child(_group_fill)
	_group_fill.color = original.bg_color
	_group_fill.visible = original.draw_center and original.bg_color.a > 0.0


func _exit_tree() -> void:
	if _group_style != null and is_instance_valid(_control):
		_control.add_theme_stylebox_override(style_name, _group_style)
