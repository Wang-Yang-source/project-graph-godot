extends Node
## Skip unreadable glyphs without changing Label shaping, bounds or persistent data.
const HIDE_BELOW_PIXELS := 2.0
const SHOW_ABOVE_PIXELS := 3.0
const Readability = preload("res://src/stage/text_readability.gd")

var _stage: Node2D
var _labels := {}
var _dirty := true
var _pending_labels := {}
var _layout_revision := -1
var _thresholds: Array[float] = []
var _scale_interval := -1
var _editor_key: Array = []

func _ready() -> void:
	_stage = get_parent()
	process_priority = 90
	get_tree().node_added.connect(_on_node_added)
	for child in _stage.get_children():
		_collect_labels(child)

func _collect_labels(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_collect_labels(child)

func _on_node_added(node: Node) -> void:
	if not node is Label or _labels.has(node.get_instance_id()):
		return
	var owner := node.get_parent()
	while owner != null and not owner is StageObject:
		if owner == _stage:
			return
		owner = owner.get_parent()
	if owner == null or owner.get_parent() != _stage:
		return
	var identifier := node.get_instance_id()
	_labels[identifier] = {"label": node, "owner": owner,
		"characters": node.visible_characters, "behavior": node.visible_characters_behavior,
		"hidden": false, "size": 0.0, "basis": [],
		"geometry_callback": _owner_geometry_changed.bind(identifier)}
	node.theme_changed.connect(_invalidate_label.bind(identifier))
	node.resized.connect(_invalidate_label.bind(identifier))
	owner.geometry_changed.connect(_labels[identifier].geometry_callback)
	_pending_labels[identifier] = true
	node.tree_exiting.connect(_forget.bind(identifier))
	_dirty = true

func _restore_label(data: Dictionary) -> void:
	if is_instance_valid(data.label) and data.label.is_inside_tree() and is_instance_valid(data.owner) and data.owner.is_inside_tree() and not data.owner.is_queued_for_deletion():
		Readability.apply(data.label, INF)
	if data.hidden and is_instance_valid(data.label):
		data.label.visible_characters = data.characters
		data.label.visible_characters_behavior = data.behavior
		data.hidden = false
	if is_instance_valid(data.owner) and data.owner is TextNode and data.owner.is_inside_tree() and data.label == data.owner.label:
		data.owner.set_text_render_pixels(INF)

func _forget(identifier: int) -> void:
	if _labels.has(identifier):
		var data: Dictionary = _labels[identifier]
		if is_instance_valid(data.owner) and data.owner.geometry_changed.is_connected(data.geometry_callback):
			data.owner.geometry_changed.disconnect(data.geometry_callback)
		_restore_label(data)
	_labels.erase(identifier)
	_pending_labels.erase(identifier)
	_dirty = true

func _invalidate() -> void:
	_dirty = true
	for identifier in _labels:
		_pending_labels[identifier] = true

func _invalidate_label(identifier: int) -> void:
	if _labels.has(identifier):
		_pending_labels[identifier] = true

func _owner_geometry_changed(identifier: int) -> void:
	if not _labels.has(identifier):
		return
	var data: Dictionary = _labels[identifier]
	var pose: Transform2D = data.label.get_global_transform()
	# World translation cannot change a glyph's size. Resizes and theme edits
	# have their own label notifications; only a changed basis needs metrics.
	if data.basis != [pose.x, pose.y]:
		_pending_labels[identifier] = true

func _process(_delta: float) -> void:
	var scale := maxf((_stage.get_viewport().get_final_transform() * _stage.get_global_transform_with_canvas()).get_scale().abs().x, .0001)
	var editors: Array = _stage._editing_objects.keys()
	var interval := _thresholds.bsearch(scale, false)
	if not _dirty and _pending_labels.is_empty() and interval == _scale_interval and editors == _editor_key:
		return
	var rebuild_thresholds := _dirty
	_dirty = false
	var pending := _pending_labels.keys()
	_pending_labels.clear()
	var relative_stage: Transform2D = _stage.global_transform.affine_inverse()
	for identifier in pending:
		if not _labels.has(identifier):
			continue
		var data: Dictionary = _labels[identifier]
		var label: Label = data.label
		var pose := label.get_global_transform()
		data.basis = [pose.x, pose.y]
		var size := label.get_theme_font_size("font_size") * (relative_stage * pose).get_scale().abs().x
		if size != data.size:
			data.size = size
			rebuild_thresholds = true
	if rebuild_thresholds:
		_thresholds.clear()
		for data in _labels.values():
			if data.size <= 0.0:
				continue
			for pixels in Readability.PIXEL_THRESHOLDS:
				_thresholds.append(float(pixels) / data.size)
			if data.owner is TextNode:
				_thresholds.append(5.0 / data.size)
			else:
				_thresholds.append(HIDE_BELOW_PIXELS / data.size)
				_thresholds.append(SHOW_ABOVE_PIXELS / data.size)
		_thresholds.sort()
	var refresh_all := rebuild_thresholds or interval != _scale_interval or editors != _editor_key
	_editor_key = editors
	_layout_revision = _stage.layout_revision
	var identifiers: Array = _labels.keys() if refresh_all else pending
	for identifier in identifiers:
		if not _labels.has(identifier):
			continue
		var data: Dictionary = _labels[identifier]
		var label: Label = data.label
		var pixels: float = data.size * scale
		Readability.apply(label, pixels)
		var owner: StageObject = data.owner
		var editing: bool = owner is TextNode and owner._editing
		if owner is LineEdge:
			editing = owner.get_node("Caption")._editing
		if owner is TextNode and label == owner.label:
			owner.set_text_render_pixels(pixels)
		var threshold: float = 5.0 if owner is TextNode else (SHOW_ABOVE_PIXELS if data.hidden else HIDE_BELOW_PIXELS)
		var hidden: bool = not editing and pixels < threshold
		if hidden == data.hidden:
			continue
		data.hidden = hidden
		if hidden:
			data.characters = label.visible_characters
			data.behavior = label.visible_characters_behavior
			label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
			label.visible_characters = 0
		else:
			label.visible_characters = data.characters
			label.visible_characters_behavior = data.behavior
	_scale_interval = _thresholds.bsearch(scale, false)

func _exit_tree() -> void:
	for data in _labels.values():
		if is_instance_valid(data.owner) and data.owner.geometry_changed.is_connected(data.geometry_callback):
			data.owner.geometry_changed.disconnect(data.geometry_callback)
		_restore_label(data)
