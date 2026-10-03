extends Node
## Skip unreadable glyphs without changing Label shaping, bounds or persistent data.
const HIDE_BELOW_PIXELS := 2.0
const SHOW_ABOVE_PIXELS := 3.0

var _stage: Node2D
var _labels := {}
var _dirty := true
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
		"hidden": false, "size": 0.0}
	node.theme_changed.connect(_invalidate)
	node.resized.connect(_invalidate)
	node.tree_exiting.connect(_forget.bind(identifier))
	_dirty = true

func _restore_label(data: Dictionary) -> void:
	if data.hidden and is_instance_valid(data.label):
		data.label.visible_characters = data.characters
		data.label.visible_characters_behavior = data.behavior
		data.hidden = false

func _forget(identifier: int) -> void:
	if _labels.has(identifier):
		_restore_label(_labels[identifier])
	_labels.erase(identifier)
	_dirty = true

func _invalidate() -> void:
	_dirty = true

func _process(_delta: float) -> void:
	var scale := maxf((_stage.get_viewport().get_final_transform() * _stage.get_global_transform_with_canvas()).get_scale().abs().x, .0001)
	var revision: int = _stage.layout_revision
	var editors: Array = _stage._editing_objects.keys()
	var interval := _thresholds.bsearch(scale)
	if not _dirty and revision == _layout_revision and interval == _scale_interval and editors == _editor_key:
		return
	var refresh_metrics := _dirty or revision != _layout_revision
	_dirty = false
	_layout_revision = revision
	_editor_key = editors
	if refresh_metrics:
		_thresholds.clear()
	for data in _labels.values():
		var label: Label = data.label
		if refresh_metrics:
			var relative := _stage.global_transform.affine_inverse() * label.get_global_transform()
			data.size = label.get_theme_font_size("font_size") * relative.get_scale().abs().x
			if data.size > 0.0:
				_thresholds.append(HIDE_BELOW_PIXELS / data.size)
				_thresholds.append(SHOW_ABOVE_PIXELS / data.size)
		var pixels: float = data.size * scale
		var owner: StageObject = data.owner
		var editing: bool = owner is TextNode and owner._editing
		if owner is LineEdge:
			editing = owner.get_node("Caption")._editing
		var hidden: bool = not editing and (pixels < SHOW_ABOVE_PIXELS if data.hidden else pixels < HIDE_BELOW_PIXELS)
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
	if refresh_metrics:
		_thresholds.sort()
	_scale_interval = _thresholds.bsearch(scale)

func _exit_tree() -> void:
	for data in _labels.values():
		_restore_label(data)
