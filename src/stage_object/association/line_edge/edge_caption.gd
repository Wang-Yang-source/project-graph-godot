extends Node2D

const Corners = preload("res://src/main/continuous_corners.gd")
const Palette = preload("res://src/main/theme_palette.gd")

@onready var edge: LineEdge = get_parent()
@onready var label: Label = $Label
var _editor: AutoSizeTextEdit
var editor: AutoSizeTextEdit:
	get:
		return _ensure_editor()
var _editing := false
var _last_light: Variant = null
var _last_stroke := Color(-1, -1, -1, -1)
var _last_background := Color(-1, -1, -1, -1)
var _hovered := false
var _centering := false
var _layout_dirty := true
var _refresh_key: Array = []


func _ready() -> void:
	process_priority = 3
	edge.geometry_changed.connect(_queue_refresh)
	edge.style_changed.connect(_queue_refresh)
	if edge.get_parent() is Stage:
		edge.get_parent().caption_peers_changed.connect(_queue_refresh)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.gui_input.connect(_label_input)
	label.mouse_entered.connect(_set_hovered.bind(true))
	label.mouse_exited.connect(_set_hovered.bind(false))
	label.resized.connect(_on_label_resized)
	visibility_changed.connect(_visibility_changed)
	_editor = get_node_or_null("Editor") as AutoSizeTextEdit
	if _editor != null:
		_configure_editor()
	_update_style()
	_refresh_text()



func _ensure_editor() -> AutoSizeTextEdit:
	if _editor != null:
		return _editor
	_editor = load("res://src/stage_object/association/line_edge/caption_editor.res").instantiate() as AutoSizeTextEdit
	_editor.name = "Editor"
	_editor.enable_auto_size = false
	_editor.add_theme_font_override("font", label.get_theme_font("font"))
	_editor.add_theme_font_size_override("font_size", label.get_theme_font_size("font_size"))
	add_child(_editor)
	_configure_editor()
	_last_light = null
	_update_style()
	return _editor



func _configure_editor() -> void:
	_editor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_editor.gui_input.connect(_editor_input)
	_editor.focus_exited.connect(finish_edit)
	_editor.commit_requested.connect(finish_edit)
	_editor.cancel_requested.connect(finish_edit.bind(false))
	_editor.enable_auto_size = false
	_editor.select_from_padding = true
	_editor.drag_and_drop_selection_enabled = false
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_editor.add_theme_constant_override("wrap_offset", 0)
	_editor.custom_minimum_size = Vector2.ZERO
	_editor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_editor.grow_horizontal = Control.GROW_DIRECTION_END
	_editor.grow_vertical = Control.GROW_DIRECTION_END
	_editor.text_changed.connect(_refresh_text)
	_editor.caret_changed.connect(_refresh_text, CONNECT_DEFERRED)
	_editor.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(edge.source) or not is_instance_valid(edge.target):
		finish_edit(false)
		set_process(false)
		return
	if not _editing and edge.visibility_layer == 0:
		set_process(false)
		return
	if not _editing and edge.text.is_empty() and not label.visible:
		set_process(false)
		return
	var refresh_key := [edge.geometry_version, edge.text, edge.line.default_color,
		edge.get_parent().get_meta("caption_peer_revision", 0), edge.visibility_layer,
		edge.source.get_instance_id(), edge.target.get_instance_id(), _layout_dirty]
	if not _editing and refresh_key == _refresh_key:
		set_process(false)
		return
	_refresh_key = refresh_key
	_update_style()
	_refresh_text()
	var center := edge.caption_position(edge.caption_fraction())
	if position != center:
		position = center
	_center_controls()
	set_process(_editing)


func _refresh_text() -> void:
	if not _editing and _editor != null and _editor.text != edge.text:
		_editor.text = edge.text
	var displayed_text := editor.text if _editing else edge.text
	if label.text != displayed_text:
		_layout_dirty = true
		label.text = displayed_text
		label.reset_size()
	label.visible = _editing or not edge.text.is_empty()
	_center_controls()


func _on_label_resized() -> void:
	_layout_dirty = true
	_center_controls()


func _center_controls() -> void:
	if _centering:
		return
	if not _layout_dirty and not _editing:
		edge.update_caption_collision(label.size, position, label.visible)
		return
	_centering = true
	# TextEdit owns shaping, caret and IME widths; Label's minimum omits the
	# caret reserve and preedit, so it cannot size the editing surface alone.
	var content_size := label.get_minimum_size()
	if _editor != null:
		content_size = content_size.max(_editor.get_minimum_size())
	var metrics := _editor.measure_unwrapped(_editor.text, true) if _editing else CanvasTextMetrics.measure(label.text, label.get_theme_font("font"), label.get_theme_font_size("font_size"), label.get_theme_constant("line_spacing"))
	var margins := label.get_theme_stylebox("normal").get_minimum_size()
	content_size.x = maxf(content_size.x, metrics.x + margins.x + 10.0)
	content_size.y = maxf(content_size.y, ceilf(metrics.y + margins.y + 4.0))
	label.size = content_size
	label.position = -content_size * 0.5
	if _editor != null:
		_editor.size = content_size
	if _editor != null:
		_editor.position = label.position
	if _editor != null:
		_editor.align_with_label(label, editor.text, true)
	# TextEdit may scroll when a caret event precedes the deferred size update.
	# Once the complete line fits, discard that obsolete horizontal offset.
	if _editor != null:
		_editor.scroll_horizontal = 0
	if _editor != null:
		_editor.scroll_vertical = 0
	edge.update_caption_collision(label.size, position, label.visible)
	_layout_dirty = false
	_centering = false

func _update_style() -> void:
	var stage := edge.get_parent() as Stage
	var light: bool = stage._applied_theme_light == 1 if stage != null and stage._applied_theme_light >= 0 else Palette.is_light(str(GraphPreferences.value("theme")))
	var stroke := edge.display_stroke_color()
	var background := edge._stroke_background(light)
	if _last_light == light and _last_stroke == stroke and _last_background == background:
		return
	_layout_dirty = true
	_last_light = light
	_last_stroke = stroke
	_last_background = background
	var normal := StyleBoxFlat.new()
	normal.bg_color = background.lerp(Palette.color(light, "accent.primary"), 0.08 if _editing else 0.04) if _editing or _hovered else background
	normal.border_color = Color.TRANSPARENT
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	label.add_theme_stylebox_override("normal", Corners.style(normal, Corners.CONTROL, true))
	var input_style := normal.duplicate() as StyleBoxFlat
	input_style.bg_color = Color.TRANSPARENT
	input_style.border_color = Color.TRANSPARENT
	input_style.set_border_width_all(0)
	input_style.content_margin_right -= 2.0
	if _editor != null:
		_editor.add_theme_stylebox_override("normal", input_style)
	if _editor != null:
		_editor.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var foreground := Palette.neutral_text_color(background)
	label.add_theme_color_override("font_color", Color.TRANSPARENT if _editing else foreground)
	if _editor != null:
		_editor.add_theme_color_override("font_color", foreground)
	if _editor != null:
		_editor.add_theme_constant_override("line_spacing", label.get_theme_constant("line_spacing"))
	if _editor != null:
		_editor.add_theme_color_override("caret_color", foreground)
	if _editor != null:
		_editor.add_theme_color_override("selection_color", Color(foreground, 0.18))
	if _editor != null:
		_editor.add_theme_color_override("font_selected_color", foreground)
	if is_instance_valid(edge.source) and edge.source is TextNode:
		var font: Font = edge.source.label.get_theme_font("font")
		label.add_theme_font_override("font", font)
		if _editor != null:
			_editor.add_theme_font_override("font", font)

func _set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	_last_light = null
	_queue_refresh()


func begin_edit() -> void:
	if _editing or not is_instance_valid(edge.source) or not is_instance_valid(edge.target):
		return
	var stage := edge.get_parent() as Stage
	if stage == null or stage.history._busy:
		return
	_ensure_editor()
	stage.finish_text_editing()
	stage.finish_interaction()
	stage.select_ids(PackedStringArray([edge.id]))
	_editing = true
	stage.set_editor_active(edge, true)
	set_process(true)
	_refresh_key.clear()
	stage.group_overview.invalidate()
	_last_light = null
	_update_style()
	editor.text = edge.text
	editor.clear_undo_history()
	editor.show()
	editor.text_changed.emit()
	_refresh_text()
	_center_controls()
	editor.grab_focus()
	editor.deselect()
	editor.set_caret_line(editor.get_line_count() - 1)
	editor.set_caret_column(editor.get_line(editor.get_caret_line()).length())


func finish_edit(commit_changes := true) -> void:
	if not _editing:
		return
	_editing = false
	_refresh_key.clear()
	var parent_stage := edge.get_parent() as Stage
	if parent_stage != null:
		parent_stage.set_editor_active(edge, false)
		parent_stage.group_overview.invalidate()
	_last_light = null
	_update_style()
	if commit_changes:
		editor.apply_ime()
	else:
		editor.cancel_ime()
	var stage := edge.get_parent() as Stage
	var changed := commit_changes and edge.text != editor.text
	if changed and stage != null:
		stage.history.begin_transaction()
		stage.get_node("NodeRepulsion").begin_local_edit([edge.source, edge.target], false)
		edge.text = editor.text
	editor.release_focus()
	editor.hide()
	_refresh_text()
	if changed and stage != null:
		stage.history.commit()
		stage.document_changed.emit()


func is_dirty() -> bool:
	return _editing and editor.text != edge.text


func _label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not event.alt_pressed:
		var stage := edge.get_parent() as Stage
		if stage != null:
			stage.select_object_from_click(edge, event)
			if event.double_click:
				begin_edit()
				editor.select_all.call_deferred()
		label.accept_event()


func _editor_input(event: InputEvent) -> void:
	editor.handle_canvas_input(event)


func _input(event: InputEvent) -> void:
	if _editing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not Rect2(Vector2.ZERO, editor.size).has_point(editor.get_local_mouse_position()):
			finish_edit()


func _visibility_changed() -> void:
	if is_node_ready() and not is_visible_in_tree():
		finish_edit()


func _queue_refresh() -> void:
	_refresh_key.clear()
	set_process(true)
