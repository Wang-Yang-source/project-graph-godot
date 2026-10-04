class_name TextNode
extends Entity

const Corners = preload("res://src/main/continuous_corners.gd")
const Palette = preload("res://src/main/theme_palette.gd")

# 舞台使用独立的可缩放字体缓存，不修改菜单等界面共享的原字体。
static var _canvas_font: Font

@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var label: Label = %Label
@onready var container_panel: Panel = $ContainerPanel
var _container_rect := Rect2()
var _container_active := false
var _container_layout_key: Array = []
var _fill_layer := 1
var _normal_label_position := Vector2.ZERO
var _normal_edit_position := Vector2.ZERO

var _text_edit: AutoSizeTextEdit
var text_edit: AutoSizeTextEdit:
	get:
		return _ensure_text_editor()
var _edit_menu: PopupMenu

# Theme hierarchy is independent of spatial containers and ordinary edges.
# Legacy nodes have no inferred parent; Enter creates another root topic.
@export var topic_parent: TextNode:
	set(value):
		topic_parent = value
		notify_topology_change()
		notify_persistent_change()

@export var text: String = "":
	set(value):
		text = value
		notify_persistent_change()
		invalidate_geometry()
		if is_node_ready():
			label.text = value
			_queue_collision_update()

@export var font_size := 24:
	set(value):
		font_size = maxi(8, value)
		notify_persistent_change()
		if is_node_ready():
			_apply_appearance()
@export var fixed_width := 0.0:
	set(value):
		fixed_width = maxf(0.0, value)
		notify_persistent_change()
		if is_node_ready():
			_apply_appearance()
@export var fill_color := Color.TRANSPARENT:
	set(value):
		fill_color = value
		notify_persistent_change()
		if is_node_ready():
			_apply_appearance()
@export_storage var border_color := Color("#585b70"):
	set(value):
		border_color = value
		notify_persistent_change()
		if is_node_ready():
			_apply_appearance()
@export_storage var use_theme_border := false:
	set(value):
		use_theme_border = value
		notify_persistent_change()
		if is_node_ready():
			_apply_appearance()

## 旧文件字段仅用于兼容保存；显示颜色始终由实际背景计算。
@export_storage var text_color := Color.TRANSPARENT:
	set(value):
		text_color = value
		notify_persistent_change()
		if is_node_ready():
			_apply_appearance()
var _editing := false
var _edit_minimum_size := Vector2.ZERO
var _edit_origin := Vector2.ZERO
var _appearance_light: Variant = null
var _appearance_container := false
var _small_text := false
var _displayed_background := Color(-1, -1, -1, -1)
var _collision_update_pending := false


func _ready() -> void:
	# Canvas corners reuse native mipmapped textures independently of UI DPI.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	super()
	label.text = text
	# 输入层使用左上角定位，最小尺寸变化不能再从中心推动控件。
	# Clicking selected text should position the caret, not start dragging the selection.
	# 标题尺寸变化时固定左上角，居中交给 Label 的文本对齐。
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.grow_horizontal = Control.GROW_DIRECTION_END
	label.grow_vertical = Control.GROW_DIRECTION_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_normal_label_position = label.position
	_normal_edit_position = label.position
	# 共享固定字形缓存；控件过滤必须实际使用缩小采样的 mipmap。
	if _canvas_font == null:
		_canvas_font = _make_centered_canvas_font(preload("res://assets/fonts/PingFang-SC-Regular.ttf"))
	var display_font: Font = get_meta("prepared_canvas_font", _canvas_font)
	remove_meta("prepared_canvas_font")
	label.add_theme_font_override("font", display_font)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_text_edit = get_node_or_null("%TextEdit") as AutoSizeTextEdit
	if _text_edit != null:
		_configure_text_editor()
	_apply_appearance()
	visibility_changed.connect(_on_visibility_changed)
	label.resized.connect(_queue_collision_update)
	container_panel.resized.connect(_queue_collision_update)
	_queue_collision_update()



func _ensure_text_editor() -> AutoSizeTextEdit:
	if _text_edit != null:
		return _text_edit
	_text_edit = load("res://src/stage_object/entity/text_node/text_editor.res").instantiate() as AutoSizeTextEdit
	_text_edit.name = "TextEdit"
	_text_edit.enable_auto_size = false
	_text_edit.add_theme_font_override("font", label.get_theme_font("font"))
	_text_edit.add_theme_font_size_override("font_size", font_size)
	add_child(_text_edit)
	_text_edit.owner = self
	_text_edit.unique_name_in_owner = true
	_configure_text_editor()
	_appearance_light = null
	_apply_appearance(false)
	return _text_edit



func _configure_text_editor() -> void:
	_text_edit.drag_and_drop_selection_enabled = false
	_text_edit.select_from_padding = true
	_text_edit.add_theme_constant_override("wrap_offset", 0)
	_text_edit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_text_edit.grow_horizontal = Control.GROW_DIRECTION_END
	_text_edit.grow_vertical = Control.GROW_DIRECTION_END
	_text_edit.add_theme_font_override("font", label.get_theme_font("font"))
	_text_edit.add_theme_font_size_override("font_size", font_size)
	_text_edit.add_theme_constant_override("line_spacing", label.get_theme_constant("line_spacing"))
	_text_edit.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_text_edit.set_context_menu_enabled(false)
	_text_edit.focus_exited.connect(_on_edit_focus_exited)
	_text_edit.commit_requested.connect(exit_edit_mode)
	_text_edit.cancel_requested.connect(exit_edit_mode.bind(false))
	_text_edit.text_changed.connect(_refresh_edit_layout)
	_text_edit.content_metrics_changed.connect(_refresh_edit_layout)
	_text_edit.caret_changed.connect(_restore_edit_scroll, CONNECT_DEFERRED)
	_text_edit.text_set.connect(_refresh_edit_layout)
	_text_edit.resized.connect(_queue_collision_update)
	if not _text_edit.gui_input.is_connected(_on_text_edit_gui_input):
		_text_edit.gui_input.connect(_on_text_edit_gui_input)
	_text_edit.hide()

func _configure_edit_menu(theme_light: Variant = null) -> void:
	# 禁用 Godot 内置 TextEdit 长菜单，改用项目自己的短菜单，避免右侧滚动条和过宽条目。
	text_edit.set_context_menu_enabled(false)
	if _edit_menu == null:
		_edit_menu = PopupMenu.new()
		_edit_menu.name = "EditMenu"
		text_edit.add_child(_edit_menu)
		_edit_menu.id_pressed.connect(_on_edit_menu_pressed)
	var menu := _edit_menu
	_compact_edit_menu(menu)
	# 文本菜单独立使用工作区的圆角卡片样式，避免继承系统直角灰色菜单。
	var light: bool = _display_theme_is_light() if theme_light == null else bool(theme_light)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Palette.color(light, "surface.raised")
	panel.border_color = Palette.color(light, "border.default")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 6.0
	panel.content_margin_right = 6.0
	panel.content_margin_top = 5.0
	panel.content_margin_bottom = 5.0
	panel.shadow_color = Color(0, 0, 0, 0.18 if light else 0.34)
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0, 3)
	menu.add_theme_stylebox_override("panel", Corners.style(panel, Corners.PANEL))

	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.color(light, "surface.selected")
	hover.set_corner_radius_all(7)
	hover.content_margin_left = 4.0
	hover.content_margin_right = 4.0
	menu.add_theme_stylebox_override("hover", Corners.style(hover, Corners.CONTROL))
	menu.add_theme_stylebox_override("pressed", Corners.style(hover, Corners.CONTROL))

	var separator := StyleBoxFlat.new()
	separator.bg_color = Palette.color(light, "border.subtle")
	separator.content_margin_top = 1.0
	separator.content_margin_bottom = 1.0
	menu.add_theme_stylebox_override("separator", separator)

	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_accelerator_color"]:
		menu.add_theme_color_override(key, Palette.color(light, "text.primary"))
	menu.add_theme_color_override("font_disabled_color", Palette.color(light, "text.disabled"))
	menu.add_theme_font_size_override("font_size", 15)
	menu.add_theme_constant_override("item_vertical_padding", 1)
	menu.add_theme_constant_override("item_start_padding", 6)
	menu.add_theme_constant_override("item_end_padding", 6)
	menu.add_theme_constant_override("h_separation", 4)


func _show_edit_menu(local_position: Vector2) -> void:
	if _edit_menu == null:
		_configure_edit_menu()
	_compact_edit_menu(_edit_menu)
	_edit_menu.size = Vector2i.ZERO
	_edit_menu.max_size = Vector2i(220, 1000)
	_edit_menu.position = Vector2i(text_edit.get_screen_position() + local_position)
	_edit_menu.popup()


func _on_edit_menu_pressed(id: int) -> void:
	text_edit.menu_option(id)


func _compact_edit_menu(menu: PopupMenu) -> void:
	# Godot 默认文本菜单包含书写方向、控制字符等长条目；编辑节点只保留常用项。
	menu.clear()
	var has_selection := text_edit.has_selection()
	menu.add_item("剪切", TextEdit.MENU_CUT)
	menu.set_item_disabled(menu.item_count - 1, not has_selection)
	menu.add_item("复制", TextEdit.MENU_COPY)
	menu.set_item_disabled(menu.item_count - 1, not has_selection)
	menu.add_item("粘贴", TextEdit.MENU_PASTE)
	menu.add_separator()
	menu.add_item("全选", TextEdit.MENU_SELECT_ALL)
	menu.add_item("清空", TextEdit.MENU_CLEAR)
	menu.set_item_disabled(menu.item_count - 1, text_edit.text.is_empty())
	if text_edit.has_undo() or text_edit.has_redo():
		menu.add_separator()
		menu.add_item("撤销", TextEdit.MENU_UNDO)
		menu.set_item_disabled(menu.item_count - 1, not text_edit.has_undo())
		menu.add_item("重做", TextEdit.MENU_REDO)
		menu.set_item_disabled(menu.item_count - 1, not text_edit.has_redo())


func _on_label_gui_input(event: InputEvent) -> void:
	if event is InputEventWithModifiers and event.alt_pressed:
		return
	# 进入编辑模式
	if label.visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			enter_edit_mode()
			text_edit.select_all.call_deferred()
			get_viewport().set_input_as_handled()
			return

	super._on_input_event(get_viewport(), event, 0)


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_edit_menu(event.position)
		text_edit.accept_event()
		return
	text_edit.handle_canvas_input(event)


func _input(event: InputEvent) -> void:
	super._input(event)
	if not _editing or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 使用控件局部坐标，兼容相机平移、缩放和子视口。
		if not Rect2(Vector2.ZERO, text_edit.size).has_point(text_edit.get_global_transform_with_canvas().affine_inverse() * event.position):
			exit_edit_mode()


func enter_edit_mode() -> void:
	if _editing:
		return
	_ensure_text_editor()
	finish_drag()
	var stage := get_parent()
	if stage.has_method("select_ids"):
		stage.call("select_ids", PackedStringArray([id]))
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_edit_minimum_size = label.size
	_edit_origin = label.position
	_editing = true
	if stage.has_method("set_editor_active"):
		stage.call("set_editor_active", self, true)
	_appearance_light = null
	# 编辑控件只作为输入层，复用标签的原始矩形，避免切换时改变刚体碰撞中心。
	text_edit.enable_auto_size = false
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	text_edit.min_width = label.size.x
	text_edit.max_width = maxf(text_edit.min_width, fixed_width if fixed_width > 0.0 else 600.0)
	text_edit.min_height = label.size.y
	text_edit.position = label.position
	text_edit.size = label.size
	text_edit.custom_minimum_size = label.size
	text_edit.text = text
	text_edit.clear_undo_history()
	_apply_appearance(false)
	text_edit.position = label.position
	_align_edit_text()
	# Keep the input overlay on the existing background until the edit is committed.
	text_edit.size = label.size
	# 背景与碰撞始终由 Label 保持；输入层只绘制文字、光标和选区。
	label.show()
	text_edit.z_index = 1
	text_edit.show()
	text_edit.grab_focus()
	text_edit.deselect()
	text_edit.set_caret_line(text_edit.get_line_count() - 1)
	text_edit.set_caret_column(text_edit.get_line(text_edit.get_caret_line()).length())
	_queue_collision_update()


func _on_edit_focus_exited() -> void:
	# The root viewport temporarily releases focus before forwarding a canvas click.
	_finish_edit_after_focus_transfer.call_deferred()


func _finish_edit_after_focus_transfer() -> void:
	if _editing and not text_edit.has_focus():
		exit_edit_mode()


func exit_edit_mode(commit_changes: bool = true) -> void:
	if not _editing:
		return
	# 先结束状态，避免隐藏控件触发 focus_exited 时重复提交。
	_editing = false
	if get_parent().has_method("set_editor_active"):
		get_parent().call("set_editor_active", self, false)
	# apply_ime 会更改 text，必须在快照和隐藏控件之前完成。
	if commit_changes:
		text_edit.apply_ime()
	else:
		text_edit.cancel_ime()
	var changed := commit_changes and text != text_edit.text
	if changed and _history != null:
		_history.begin_transaction()
		var solver := get_parent().get_node_or_null("NodeRepulsion")
		if solver != null:
			solver.begin_local_edit([self])
	if changed:
		text = text_edit.text
	text_edit.release_focus()
	text_edit.hide()
	label.text = text
	label.show()
	_apply_appearance()
	text_edit.enable_auto_size = true
	_queue_collision_update()
	if changed and _history != null:
		_history.commit()


func _on_visibility_changed() -> void:
	if is_node_ready() and not is_visible_in_tree():
		exit_edit_mode()


func _queue_collision_update() -> void:
	if _collision_update_pending:
		return
	_collision_update_pending = true
	_update_collision_shape.call_deferred()


func _update_collision_shape() -> void:
	_collision_update_pending = false
	_refresh_corner_styles()
	var bounds := get_visual_rect()
	var center := bounds.get_center()
	var current_shape := collision_shape.shape as RectangleShape2D
	if current_shape != null and current_shape.size == bounds.size and collision_shape.position == center:
		return
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	collision_shape.shape = shape
	collision_shape.position = center
	invalidate_geometry()


func display_border_color() -> Color:
	var light: bool = Palette.is_light(str(GraphPreferences.value("theme"))) if _appearance_light == null else bool(_appearance_light)
	return Palette.neutral_edge_color(display_background_color(light))


func display_background_color(light: bool) -> Color:
	var background := Palette.color(light, "surface.canvas")
	var chain: Array[Entity] = []
	var current: Entity = self
	while is_instance_valid(current) and not chain.has(current):
		chain.append(current)
		current = current.container
	chain.reverse()
	for node in chain:
		if node is TextNode:
			background = background.blend(node.display_fill_color())
	return background

func _apply_appearance(update_layout: bool = true, theme_light: Variant = null) -> void:
	var light: bool = _display_theme_is_light() if theme_light == null else bool(theme_light)
	var background := display_background_color(light)
	if not update_layout and _appearance_light == light and _appearance_container == _container_active and _displayed_background.is_equal_approx(background):
		return
	_appearance_light = light
	_appearance_container = _container_active
	invalidate_geometry()
	_displayed_background = background
	if _edit_menu != null:
		_configure_edit_menu(light)
	label.begin_bulk_theme_override()
	if _text_edit != null:
		_text_edit.begin_bulk_theme_override()
	var foreground := display_text_color(light)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 0) if _editing else foreground)
	if update_layout:
		label.add_theme_font_size_override("font_size", font_size)
		if _text_edit != null:
			_text_edit.add_theme_font_size_override("font_size", font_size)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = fixed_width
		_fit_label_text_height()
		label.size = Vector2(fixed_width, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = display_fill_color()
	style.border_color = Palette.color(light, "border.focus") if _editing else display_border_color()
	# Match master: ordinary nodes and expanded groups use a two-world-pixel border.
	style.set_border_width_all(2)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	container_panel.add_theme_stylebox_override("panel", Corners.style(style, Corners.fitted_radius(container_panel.size, Corners.PANEL), true, true))
	if _container_active:
		style.bg_color = Color.TRANSPARENT
		# The heading shares the panel origin. Keep its backing inside the
		# existing border instead of painting over the top edge and corners.
		var heading_inset := float(style.border_width_top)
		style.expand_margin_left = -heading_inset
		style.expand_margin_top = -heading_inset
		style.expand_margin_right = -heading_inset
		style.set_border_width_all(0)
	label.add_theme_stylebox_override("normal", Corners.style(style, Corners.fitted_radius(label.size, Corners.PANEL), true, true))
	if _text_edit != null:
		_text_edit.add_theme_color_override("font_color", foreground)
	if _text_edit != null:
		_text_edit.add_theme_color_override("caret_color", foreground)
	if _text_edit != null:
		_text_edit.add_theme_color_override("selection_color", Palette.color(light, "surface.selected"))
	var edit_style := style.duplicate() as StyleBoxFlat
	# 输入框可为光标与输入法扩展，但不接管节点的背景与轮廓。
	edit_style.bg_color = Color.TRANSPARENT
	edit_style.border_color = Color.TRANSPARENT
	edit_style.set_border_width_all(0)
	if _text_edit != null:
		_text_edit.add_theme_stylebox_override("normal", edit_style)
	if _text_edit != null:
		_text_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	label.end_bulk_theme_override()
	if _text_edit != null:
		_text_edit.end_bulk_theme_override()
	if _editing:
		_align_edit_text()
	if update_layout:
		label.reset_size()
		# 样式、文字和字体刷新不能把分组标题缩回普通文本块宽度。
		# 保持与创建、加载和拖动时相同的顶部居中布局。
		if _container_active and _container_rect.has_area():
			label.position = _container_rect.position
			label.size = Vector2(_container_rect.size.x, label.get_minimum_size().y)
			if _text_edit != null:
				_text_edit.position = label.position
		_queue_collision_update()
	_refresh_corner_styles()


# Resizing text or a group changes geometry even when its colors stay unchanged.
# Updating only the style radius preserves content margins and avoids relayout.

func _refresh_corner_styles() -> void:
	_refresh_control_corners(label, "normal")
	_refresh_control_corners(container_panel, "panel")


func _refresh_control_corners(control: Control, key: StringName) -> void:
	var original := Corners.source(control.get_theme_stylebox(key))
	if original == null:
		return
	var radius := Corners.fitted_radius(control.size, Corners.PANEL)
	if original.corner_radius_top_left == int(radius):
		return
	control.add_theme_stylebox_override(key, Corners.style(original, radius, true, true))


func get_visual_outline_key() -> Array:
	var control: Control = container_panel if _container_active else label
	var key: StringName = &"panel" if _container_active else &"normal"
	var original := Corners.source(control.get_theme_stylebox(key))
	var radius := float(original.corner_radius_top_left) if original != null else 0.0
	return [get_visual_rect(), radius]


func get_visual_outline() -> PackedVector2Array:
	var control: Control = container_panel if _container_active else label
	var key: StringName = &"panel" if _container_active else &"normal"
	var original := Corners.source(control.get_theme_stylebox(key))
	var radius := float(original.corner_radius_top_left) if original != null else 0.0
	return Corners.outline(get_visual_rect(), radius)


static func _make_centered_canvas_font(original: Font) -> FontVariation:
	if original.resource_path == "res://assets/fonts/PingFang-SC-Regular.ttf":
		return CanvasTextMetrics.canvas_font()
	var bold := FontVariation.new()
	bold.base_font = _make_canvas_font(original)
	# Synthetic emboldening creates overlapping contours and holes in MSDF glyphs.
	bold.variation_embolden = 0.0
	return bold


static func _make_canvas_font(original: Font) -> Font:
	if original is FontVariation:
		var variation := original.duplicate() as FontVariation
		if original.base_font != null:
			variation.base_font = _make_canvas_font(original.base_font)
		return variation
	if original is FontFile:
		var scalable := original.duplicate() as FontFile
		# Share MSDF glyphs across zoom levels; keep label and editor geometry identical.
		scalable.multichannel_signed_distance_field = true
		scalable.msdf_pixel_range = 8
		scalable.msdf_size = 48
		scalable.generate_mipmaps = true
		return scalable
	return original


# 包含状态由子对象引用推导，不更换对象身份，因此连线和属性仍指向原节点。
func _container_layout_inputs(members: Array[Entity]) -> Array:
	var basis := Transform2D(global_transform.x, global_transform.y, Vector2.ZERO)
	var header := [basis, label.get_minimum_size(), fixed_width, fill_color,
		border_color, use_theme_border, text, font_size, _editing, _small_text,
		_display_theme_is_light()]
	var inverse := global_transform.affine_inverse()
	var entries := []
	for member in members:
		var local_shape: Array = []
		var appearance: Array = []
		if member is TextNode:
			local_shape = member.get_visual_outline_key()
			appearance = [member.fill_color, member._fill_layer, member.border_color,
				member.use_theme_border, member.text, member.font_size, member._small_text]
		else:
			for child in member.get_children():
				var collision := child as CollisionShape2D
				if collision == null or collision.shape == null or collision.has_meta("physics_outline"):
					continue
				if collision.disabled and not collision.has_meta("editor_geometry_only"):
					continue
				local_shape.append([collision.transform, collision.shape.get_rect()])
		entries.append([member.get_instance_id(), member.shape_version,
			inverse * member.global_transform, local_shape, appearance])
	return [header, entries]


func _same_container_layout_inputs(candidate: Array) -> bool:
	if _container_layout_key.size() != 2 or candidate[0] != _container_layout_key[0]:
		return false
	var before: Array = _container_layout_key[1]
	var after: Array = candidate[1]
	if before.size() != after.size():
		return false
	var pixels_per_unit := maxf((get_viewport().get_final_transform() * get_global_transform_with_canvas()).x.length(), 0.001)
	var positional_tolerance := minf(0.001, 0.05 / pixels_per_unit)
	for index in after.size():
		var a: Array = before[index]
		var b: Array = after[index]
		if a[0] != b[0] or a[1] != b[1] or a[3] != b[3] or a[4] != b[4]:
			return false
		var old_pose: Transform2D = a[2]
		var new_pose: Transform2D = b[2]
		if old_pose.x != new_pose.x or old_pose.y != new_pose.y:
			return false
		# Float32 world-coordinate subtraction can jitter after common motion.
		# Keep the tolerance bounded in local units and retain the old key so
		# real sub-tolerance movement accumulates until it invalidates.
		if old_pose.origin.distance_squared_to(new_pose.origin) > positional_tolerance * positional_tolerance:
			return false
	return true


func update_container_layout(members: Array[Entity]) -> void:
	var layout_key := _container_layout_inputs(members)
	if _same_container_layout_inputs(layout_key):
		return
	_container_layout_key = layout_key
	_update_fill_layer(members)
	_apply_appearance(false)
	var active := not members.is_empty()
	if active != _container_active:
		_container_active = active
		container_panel.visible = active
		if not active:
			# 最后一个成员移出后，普通方块留在原容器标题处。
			move_without_inertia(to_global(_container_rect.position - _normal_label_position))
			label.position = _normal_label_position
			if _text_edit != null:
				_text_edit.position = _normal_edit_position
			label.size = Vector2(fixed_width, 0.0)
		_apply_appearance()
	if not active:
		# Label/property signals already queue collision updates when needed.
		return
	var bounds := Rect2()
	var initialized := false
	for member in members:
		var world_rect := member.aabb
		for corner in [world_rect.position, Vector2(world_rect.end.x, world_rect.position.y), world_rect.end, Vector2(world_rect.position.x, world_rect.end.y)]:
			var point := to_local(corner)
			if not initialized:
				bounds = Rect2(point, Vector2.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	var header_height := label.get_minimum_size().y
	bounds = bounds.grow(30.0)
	bounds.position.y -= header_height
	bounds.size.y += header_height
	bounds.size.x = maxf(bounds.size.x, maxf(label.get_minimum_size().x, fixed_width))
	var title_size := Vector2(bounds.size.x, header_height)
	if bounds == _container_rect and container_panel.position == bounds.position and container_panel.size == bounds.size and label.position == bounds.position and label.size == title_size:
		return
	_container_rect = bounds
	container_panel.position = bounds.position
	container_panel.size = bounds.size
	label.position = bounds.position
	label.size = Vector2(bounds.size.x, header_height)
	if _text_edit != null:
		_text_edit.position = label.position
	_update_collision_shape()

func get_visual_rect() -> Rect2:
	if _container_active:
		return _container_rect
	# 编辑态不改变可见方块的几何矩形，避免 RigidBody2D 因输入层尺寸变化而位移。
	return Rect2(label.position, label.size)


func _fit_label_text_height() -> void:
	var metrics := CanvasTextMetrics.measure(label.text, label.get_theme_font("font"), font_size, label.get_theme_constant("line_spacing"))
	label.custom_minimum_size = Vector2(maxf(fixed_width, metrics.x + 62.0), metrics.y + 20.0)

func _refresh_edit_layout() -> void:
	if not _editing:
		return
	label.text = text_edit.text
	_fit_label_text_height()
	label.reset_size()
	var metrics := text_edit.measure_unwrapped(text_edit.text, true)
	label.size = label.size.max(_edit_minimum_size).max(Vector2(metrics.x + 62.0, metrics.y + 20.0))
	label.position = _edit_origin
	_align_edit_text()
	text_edit.custom_minimum_size = label.size
	text_edit.size = label.size
	text_edit.position = label.position
	_restore_edit_scroll()
	_queue_collision_update()


func _restore_edit_scroll() -> void:
	if _editing:
		text_edit.scroll_horizontal = 0
		text_edit.scroll_vertical = 0


func _align_edit_text() -> void:
	text_edit.align_with_label(label, text_edit.text, true)


# Display-only opacity for containers; ordinary nodes preserve the chosen alpha.
# Master substitutes a faint border-colored fill only when transparent text is tiny.
func display_fill_color() -> Color:
	if not _container_active:
		if fill_color.a == 0.0 and _small_text:
			return Color(display_border_color(), 0.2)
		return fill_color
	var result := fill_color
	result.a *= pow(0.78, _fill_layer - 1)
	return result


func display_text_color(light: bool) -> Color:
	# Theme text replaces master's canvas inverse; opaque fills still need contrast.
	if fill_color.a == 1.0:
		return Palette.neutral_text_color(display_background_color(light))
	return Palette.color(light, "canvas.node.text")


func set_text_render_pixels(pixels: float) -> void:
	var small := pixels < 5.0
	if small == _small_text:
		return
	_small_text = small
	_apply_appearance(false)

func _update_fill_layer(members: Array[Entity]) -> void:
	var level := 1
	for member in members:
		if member is TextNode and Color(member.fill_color, 1.0).is_equal_approx(Color(fill_color, 1.0)):
			level = maxi(level, member._fill_layer + 1)
	if level == _fill_layer:
		return
	_fill_layer = level
	_apply_appearance()


func _display_theme_is_light() -> bool:
	var stage := get_parent() as Stage
	if stage != null and stage._applied_theme_light >= 0:
		return stage._applied_theme_light == 1
	return Palette.is_light(str(GraphPreferences.value("theme")))


## Stable full-document bounds during progressive restoration.
func set_loading_container_rect(world_rect: Rect2) -> void:
	_container_layout_key.clear()
	_container_active = true
	_container_rect = global_transform.affine_inverse() * world_rect
	container_panel.position = _container_rect.position
	container_panel.size = _container_rect.size
	container_panel.show()
	label.position = _container_rect.position
	label.size = Vector2(_container_rect.size.x, label.get_minimum_size().y)
	_apply_appearance(false)
	_update_collision_shape()
