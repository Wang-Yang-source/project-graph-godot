extends Node2D

## View-only overview with camera and screen-size gates tuned for earlier titles.
## Show root and immediate child titles with aggregated links; omit deeper detail.
@export_range(0.01, 1.0) var camera_scale_threshold := 0.45
@export_range(0.01, 1.0) var viewport_size_ratio := 0.15

const Corners = preload("res://src/main/continuous_corners.gd")
const Palette = preload("res://src/main/theme_palette.gd")
const TITLE_FONT_SIZE := 100
# Physical screen pixels: switch hierarchy before ordinary text becomes unreadable.
const DETAIL_TITLE_PIXELS := 12.0
const MAX_SUMMARY_TITLE_PIXELS := 24.0
static var _summary_font: FontFile

@onready var _template: Panel = $SummaryTemplate
var _active: Dictionary = {}
var _hidden: Dictionary = {}
var _suppressed: Dictionary = {}
var _summaries: Dictionary = {}
var _refresh_key: Array = []
var _view_rect_key: Array = []
var _layout_revision := -1
var _objects: Array = []
var _groups: Array = []
var _levels: Dictionary = {}
var _blocked: Dictionary = {}
var _group_rects: Dictionary = {}
var _entity_rects: Dictionary = {}
var _display_rect_cache: Dictionary = {}
var _frame_scale := 1.0
var _gate_key: Array = []
var _gate_input_key: Array = []
var _zoom_gates: Array[float] = []
var _membership_key: Array = []
var _cover_groups: Dictionary = {}
var _structure_key: Array = []
var _entities := {}
var _preview_parents := {}
var _preview_children := {}
var _preview_nodes := {}
var _preview_roots := {}
var _group_gates := {}
var _preview_links := {}
var _link_render_key: Array = []
var _link_geometry_context: Array = []
var _links_layer: Node2D
var _panel_pool := {}
var _overlap_key: Array = []
var _overlap_hidden: Array[Panel] = []
# Real frames keep native geometry; overview replaces glyphs only.
var _miniatures := {}
var _native_previews := {}
var _native_preview_key: Array = []


func _ready() -> void:
	# Layout, camera and edge geometry run first. Never affect physics visibility.
	process_priority = 50


func _process(_delta: float) -> void:
	refresh()


func is_hidden(object: StageObject) -> bool:
	# Covered details are omitted and cannot be picked through the overview.
	return _hidden.has(object.get_instance_id())


func is_active(group: TextNode) -> bool:
	return _active.has(group.get_instance_id())


func outline_for(group: TextNode) -> PackedVector2Array:
	var panel := _summaries.get(group.get_instance_id()) as Panel
	if panel == null:
		return group.get_visual_outline()
	var style := Corners.source(panel.get_theme_stylebox("panel"))
	var points := Corners.outline(Rect2(Vector2.ZERO, panel.size), float(style.corner_radius_top_left))
	for index in points.size():
		points[index] = group.to_local(panel.get_global_transform() * points[index])
	return points


func covers_point(world_point: Vector2) -> bool:
	for key in _active:
		if not _hidden.has(key) and is_instance_valid(_active[key]) and (_group_rects.get(key, _active[key].aabb) as Rect2).has_point(world_point):
			return true
	return false


func invalidate() -> void:
	_refresh_key.clear()
	_layout_revision = -1


func refresh() -> void:
	var stage: Stage = get_parent()
	_frame_scale = maxf((get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().x, .01)
	if stage.is_loading and stage.has_meta("loading_overview_revision"):
		for identifier in _summaries:
			if _active.has(identifier):
				_update_summary(_active[identifier], _summaries[identifier])
		return
	var camera: Camera2D = stage.camera
	var viewport_size := get_viewport_rect().size
	var key := [stage.layout_revision, stage.document_revision, camera.zoom, viewport_size,
		get_viewport().get_final_transform(), camera_scale_threshold, viewport_size_ratio, stage._applied_theme_light]
	if key == _refresh_key:
		_refresh_pan_visibility(stage)
		return
	_refresh_key = key
	var changed := _layout_revision != stage.layout_revision
	if changed:
		_layout_revision = stage.layout_revision
		_objects = stage.stage_objects()
		var structure := []
		for object in _objects:
			if object is Entity:
				structure.append([object.get_instance_id(),
					object.container.get_instance_id() if is_instance_valid(object.container) else 0,
					object.topic_parent.get_instance_id() if object is TextNode and is_instance_valid(object.topic_parent) else 0,
					object._editing if object is TextNode else false, object.is_visible_in_tree()])
			elif object is LineEdge:
				structure.append([object.get_instance_id(),
					object.source.get_instance_id() if is_instance_valid(object.source) else 0,
					object.target.get_instance_id() if is_instance_valid(object.target) else 0,
					object.get_node("Caption")._editing])
		if structure != _structure_key:
			_structure_key = structure
			_build_preview_tree()
			_membership_key.clear()
		_refresh_preview_rects()
	var display_scale := snappedf(_frame_scale / maxf(camera.zoom.x, .0001), .0001)
	var gate_input_key := [stage.layout_revision, stage.document_revision, viewport_size, display_scale, camera_scale_threshold, viewport_size_ratio]
	if gate_input_key != _gate_input_key:
		_gate_input_key = gate_input_key
		var sizes := []
		for group in _groups:
			sizes.append([group.get_instance_id(), _group_rects[group.get_instance_id()].size, group.font_size, group.text.strip_edges().is_empty()])
		var gate_key := [sizes, stage.layout_revision, stage.document_revision, viewport_size, display_scale, camera_scale_threshold, viewport_size_ratio]
		if gate_key != _gate_key:
			_gate_key = gate_key
			_zoom_gates.clear()
			_group_gates.clear()
			var side := maxf(viewport_size.x, viewport_size.y)
			for group in _groups:
				var identifier: int = group.get_instance_id()
				var level: int = _levels.get(identifier, 0)
				var rect: Rect2 = _group_rects[identifier]
				var limit: float = camera_scale_threshold * camera.REFERENCE_ZOOM
				var size_gate := side * minf(.75, viewport_size_ratio + .20 * level) / maxf(rect.size.x, rect.size.y)
				# A large frame must not delay its preview until the header is unreadable.
				var font_size := INF
				for child in _preview_children.get(identifier, []):
					var entity: Entity = _entities[child]
					if entity is TextNode and not entity.text.strip_edges().is_empty():
						var relative: Transform2D = stage.global_transform.affine_inverse() * entity.label.get_global_transform()
						var world_font: float = entity.label.get_theme_font_size("font_size") * relative.get_scale().abs().x
						font_size = minf(font_size, maxf(world_font, .0001))
				# Large frames must also collapse when their immediate child text is tiny.
				var text_gate := DETAIL_TITLE_PIXELS / (font_size * display_scale)
				var gate := maxf(minf(limit, size_gate), text_gate)
				_group_gates[identifier] = gate
				_zoom_gates.append(gate)
			_zoom_gates.sort()
	var membership_zoom := camera.zoom.x + .00001
	var membership := [_gate_key, _zoom_gates.bsearch(membership_zoom)]
	if membership != _membership_key:
		_membership_key = membership
		var previous := _active.duplicate()
		_active.clear()
		for group in _groups:
			var identifier: int = group.get_instance_id()
			if not group.text.strip_edges().is_empty() and not _blocked.has(identifier) and membership_zoom < float(_group_gates[identifier]):
				_active[identifier] = group
		for group in _groups:
			var identifier: int = group.get_instance_id()
			if not group.text.strip_edges().is_empty() and not _blocked.has(identifier) and not _active_ancestors(group).is_empty():
				_active[identifier] = group
		if previous != _active or _preview_nodes.is_empty() or changed:
			_refresh_membership()
	elif changed:
		_link_render_key.clear()
	for identifier in _summaries:
		_update_summary(_preview_nodes[identifier], _summaries[identifier])
	_update_native_previews()
	_avoid_title_overlaps()
	_update_preview_links()
	_view_rect_key = [stage.world_view_rect]


func _refresh_pan_visibility(stage: Stage) -> void:
	# Translation changes culling, but preserves world geometry and title layout.
	var key := [stage.world_view_rect]
	if key == _view_rect_key:
		return
	_view_rect_key = key
	for identifier in _summaries:
		var panel: Panel = _summaries[identifier]
		var rect: Rect2 = panel.get_meta("view_rect", Rect2())
		panel.visible = bool(panel.get_meta("view_readable", false)) and stage.world_view_rect.intersects(rect, true)
		if panel.visible and panel.get_meta("presentation_pending", true):
			_update_summary(_preview_nodes[identifier], panel)
	_update_native_previews()
	_avoid_title_overlaps()
	_update_preview_links()


func _build_preview_tree() -> void:
	for identifier in _panel_pool.keys():
		var valid := false
		for object in _objects:
			if object.get_instance_id() == identifier:
				valid = true
				break
		if not valid:
			_panel_pool[identifier].queue_free()
			_panel_pool.erase(identifier)
	_entities.clear()
	_preview_parents.clear()
	_preview_children.clear()
	_groups.clear()
	_blocked.clear()
	var incoming := {}
	var spatial_parents := {}
	for object in _objects:
		if object is Entity and object.is_visible_in_tree():
			_entities[object.get_instance_id()] = object
		elif object is LineEdge and object.source is TextNode and object.target is TextNode:
			var identifier: int = object.target.get_instance_id()
			if not incoming.has(identifier):
				incoming[identifier] = []
			if not incoming[identifier].has(object.source):
				incoming[identifier].append(object.source)
	for identifier in _entities:
		var object: Entity = _entities[identifier]
		var parent: Entity = object.container
		if is_instance_valid(parent):
			spatial_parents[identifier] = parent.get_instance_id()
		if object is TextNode and not object._container_active:
			# Logical branch depth refines a flat spatial group for display only.
			# Explicit nested frames remain direct children of their real frame.
			if is_instance_valid(object.topic_parent) and object.topic_parent.container == object.container:
				parent = object.topic_parent
			else:
				var candidates: Array = incoming.get(identifier, [])
				if candidates.size() == 1 and candidates[0].container == object.container:
					parent = candidates[0]
		if is_instance_valid(parent) and _entities.has(parent.get_instance_id()):
			_preview_parents[identifier] = parent.get_instance_id()
	var cyclic := {}
	for identifier in _preview_parents:
		var chain := []
		var current: int = identifier
		while _preview_parents.has(current):
			var index := chain.find(current)
			if index >= 0:
				for entry in chain.slice(index):
					cyclic[entry] = true
				break
			chain.append(current)
			current = _preview_parents[current]
	for identifier in cyclic:
		_preview_parents.erase(identifier)
		if spatial_parents.has(identifier):
			_preview_parents[identifier] = spatial_parents[identifier]
	for identifier in _preview_parents:
		var parent: int = _preview_parents[identifier]
		if not _preview_children.has(parent):
			_preview_children[parent] = []
		_preview_children[parent].append(identifier)
	for identifier in _preview_children:
		if _entities[identifier] is TextNode:
			_groups.append(_entities[identifier])
	_levels = _group_levels(_objects)
	for object in _objects:
		if object is TextNode and object._editing:
			_block_ancestors(object, _blocked)
		elif object is LineEdge and object.get_node("Caption")._editing:
			if is_instance_valid(object.source):
				_block_ancestors(object.source, _blocked)
			if is_instance_valid(object.target):
				_block_ancestors(object.target, _blocked)
	_cache_cover_groups()


func _refresh_preview_rects() -> void:
	_group_rects.clear()
	_entity_rects.clear()
	_display_rect_cache.clear()
	for identifier in _entities:
		var rect: Rect2 = _entities[identifier].aabb
		_entity_rects[identifier] = rect
		_group_rects[identifier] = rect
	var groups := _groups.duplicate()
	groups.sort_custom(func(a: TextNode, b: TextNode) -> bool:
		return int(_levels.get(a.get_instance_id(), 0)) < int(_levels.get(b.get_instance_id(), 0)))
	for group in groups:
		var identifier: int = group.get_instance_id()
		if group._container_active:
			continue
		var bounds: Rect2 = _group_rects[identifier]
		for child in _preview_children.get(identifier, []):
			bounds = bounds.merge(_group_rects[child])
		_group_rects[identifier] = bounds.grow(12.0)


func _refresh_membership() -> void:
	_display_rect_cache.clear()
	_hidden.clear()
	for identifier in _cover_groups:
		for ancestor in _cover_groups[identifier]:
			if _active.has(ancestor):
				_hidden[identifier] = true
				break
	_miniatures.clear()
	for object in _objects:
		var identifier: int = object.get_instance_id()
		for ancestor in _cover_groups.get(identifier, []):
			if _active.has(ancestor) and _active[ancestor]._container_active:
				_miniatures[identifier] = true
				break
		if object is TextNode and object._container_active and _active.has(identifier):
			_miniatures[identifier] = true
	var wanted := _hidden.duplicate()
	for identifier in _active:
		wanted[identifier] = true
	for identifier in _suppressed.keys():
		if not wanted.has(identifier):
			_restore(identifier)
	for object in _objects:
		var identifier: int = object.get_instance_id()
		if not wanted.has(identifier):
			continue
		if not _suppressed.has(identifier):
			var items: Array[Dictionary] = []
			_suppress_canvas(object, items)
			_suppressed[identifier] = {"object":object, "items":items, "pickable":object.input_pickable}
			for item in items:
				if item.has("layer"):
					item.node.visibility_layer = 0
		object.input_pickable = not _hidden.has(identifier) and bool(_suppressed[identifier].pickable)
	_preview_nodes.clear()
	_preview_roots.clear()
	for identifier in _active:
		if not _hidden.has(identifier):
			_preview_roots[identifier] = true
			_preview_nodes[identifier] = _active[identifier]
			for child in _preview_children.get(identifier, []):
				if _entities[child] is TextNode and not _entities[child].text.strip_edges().is_empty():
					_preview_nodes[child] = _entities[child]
	for identifier in _summaries.keys():
		if not _preview_nodes.has(identifier):
			_summaries[identifier].hide()
			_panel_pool[identifier] = _summaries[identifier]
			_summaries.erase(identifier)
	for identifier in _preview_nodes:
		var panel := _summaries.get(identifier) as Panel
		if panel == null and _panel_pool.has(identifier):
			panel = _panel_pool[identifier]
			_panel_pool.erase(identifier)
			_summaries[identifier] = panel
		if panel == null:
			panel = _template.duplicate() as Panel
			panel.name = "Summary_" + _preview_nodes[identifier].id
			add_child(panel)
			panel.gui_input.connect(_on_summary_input.bind(_preview_nodes[identifier]))
			panel.get_node("Title").gui_input.connect(_on_summary_input.bind(_preview_nodes[identifier]))
			_summaries[identifier] = panel
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if _preview_roots.has(identifier) else Control.MOUSE_FILTER_IGNORE
		panel.get_node("Title").mouse_filter = Control.MOUSE_FILTER_STOP if _preview_roots.has(identifier) else Control.MOUSE_FILTER_IGNORE
	_rebuild_preview_links()
	_link_geometry_context.clear()
	_link_render_key.clear()


func _representative(identifier: int) -> int:
	var path := [identifier]
	var current := identifier
	while _preview_parents.has(current):
		current = _preview_parents[current]
		path.append(current)
	for index in range(path.size() - 1, -1, -1):
		if _preview_roots.has(path[index]):
			return path[index - 1] if index > 0 else path[index]
	return identifier


func _rebuild_preview_links() -> void:
	if _links_layer == null:
		_links_layer = Node2D.new()
		_links_layer.name = "PreviewLinks"
		_links_layer.z_index = 67
		add_child(_links_layer)
	var wanted := {}
	for object in _objects:
		if not object is LineEdge or _miniatures.has(object.get_instance_id()) or not _hidden.has(object.get_instance_id()) or not is_instance_valid(object.source) or not is_instance_valid(object.target):
			continue
		var from := _representative(object.source.get_instance_id())
		var to := _representative(object.target.get_instance_id())
		if from == to or not _preview_nodes.has(from) or not _preview_nodes.has(to):
			continue
		var identifier := str([from, to, object.show_arrow, object.display_stroke_color()])
		if not wanted.has(identifier):
			wanted[identifier] = {"edge":object, "source":from, "target":to}
	for identifier in _preview_links.keys():
		if not wanted.has(identifier):
			var node: Node = _preview_links[identifier].node
			_links_layer.remove_child(node)
			node.queue_free()
			_preview_links.erase(identifier)
	for identifier in wanted:
		if not _preview_links.has(identifier):
			var node := Node2D.new()
			var line := Line2D.new()
			line.name = "Line"
			line.antialiased = true
			line.texture = preload("res://assets/line_antialiasing.res")
			line.texture_mode = Line2D.LINE_TEXTURE_TILE
			line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			node.add_child(line)
			var head := Polygon2D.new()
			head.name = "Head"
			head.antialiased = true
			node.add_child(head)
			_links_layer.add_child(node)
			_preview_links[identifier] = wanted[identifier]
			_preview_links[identifier].node = node
		else:
			_preview_links[identifier].edge = wanted[identifier].edge


func _update_native_previews() -> void:
	var stage: Stage = get_parent()
	var roots := []
	for identifier in _preview_roots:
		if _miniatures.has(identifier):
			roots.append(identifier)
	var key := [_layout_revision, stage.document_revision, roots]
	if key != _native_preview_key:
		_native_preview_key = key
		for identifier in _native_previews:
			if is_instance_valid(_native_previews[identifier].view):
				_native_previews[identifier].view.queue_free()
			_native_previews[identifier].image.queue_free()
		_native_previews.clear()
		for identifier in roots:
			var rect: Rect2 = _group_rects[identifier]
			var factor := 512.0 / maxf(rect.size.x, rect.size.y)
			var view := SubViewport.new()
			view.name = "NativeGroupCache"
			view.disable_3d = true
			view.world_2d = World2D.new()
			view.transparent_bg = true
			view.size = Vector2i((rect.size * factor).ceil()).max(Vector2i.ONE)
			view.render_target_update_mode = SubViewport.UPDATE_ONCE
			add_child(view)
			for object in _objects:
				var object_id: int = object.get_instance_id()
				if object_id != identifier and not _cover_groups.get(object_id, []).has(identifier):
					continue
				if object is TextNode:
					var control: Control = object.container_panel if object._container_active else object.label
					var body := Panel.new()
					body.mouse_filter = Control.MOUSE_FILTER_IGNORE
					body.set_anchors_preset(Control.PRESET_TOP_LEFT)
					body.size = control.size
					var native_style := Corners.source(control.get_theme_stylebox("panel" if object._container_active else "normal"))
					if native_style != null:
						var style := native_style.duplicate() as StyleBoxFlat
						style.set_border_width_all(maxi(style.border_width_top, ceili(2.0 / factor)))
						body.add_theme_stylebox_override("panel", style)
					view.add_child(body)
					body.position = control.global_position
					body.rotation = control.get_global_transform().get_rotation()
					body.scale = control.get_global_transform().get_scale()
					body.z_index = 0 if object._container_active else 2
				elif object is LineEdge:
					var line := Line2D.new()
					var from := LineEdge.connection_rect(object.source, object.target)
					var to := LineEdge.connection_rect(object.target, object.source)
					var anchors := LineEdge.connection_uvs(from, to)
					var head_length := LineEdge.arrow_length(from, to, anchors, object.stroke_width) if object.show_arrow else 0.0
					line.points = LineEdge.connection_curve(from, to, anchors, object.curve_segments, head_length, true)
					line.default_color = object.display_stroke_color()
					line.width = maxf(object.stroke_width, 2.0 / factor)
					line.antialiased = true
					line.z_index = 1
					view.add_child(line)
					if object.show_arrow:
						var head := Polygon2D.new()
						head.position = LineEdge.anchor(to, anchors[1])
						head.rotation = (-anchors[3]).angle()
						head.polygon = PackedVector2Array([Vector2.ZERO, Vector2(-head_length, -head_length * .4), Vector2(-head_length, head_length * .4)])
						head.color = line.default_color
						head.z_index = 1
						view.add_child(head)
			view.canvas_transform = Transform2D(0.0, Vector2.ONE * factor, 0.0, -rect.position * factor)
			var image := Sprite2D.new()
			image.texture = view.get_texture()
			image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			image.position = to_local(rect.get_center())
			image.scale = rect.size / Vector2(view.size)
			image.z_index = 66
			add_child(image)
			_native_previews[identifier] = {"view":view, "image":image, "rect":rect}
			_freeze_preview_texture.call_deferred(_native_previews[identifier])
	for data in _native_previews.values():
		data.image.visible = stage.world_view_rect.intersects(data.rect, true)


func _freeze_preview_texture(data: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(data.view) or not is_instance_valid(data.image):
		return
	var pixels: Image = data.view.get_texture().get_image()
	pixels.generate_mipmaps()
	data.image.texture = ImageTexture.create_from_image(pixels)
	var alpha_material := CanvasItemMaterial.new()
	alpha_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	data.image.material = alpha_material
	data.image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	data.view.queue_free()


func _preview_display_rect(identifier: int) -> Rect2:
	var object: TextNode = _preview_nodes[identifier]
	# Preserve saved geometry. Enlarging each tiny node to a fixed screen size
	# moves its visible boundary into neighbours while the graph stays still.
	if not object._container_active:
		return _entity_rects[identifier] if _entity_rects.has(identifier) else object.aabb
	return _group_rects[identifier] if _group_rects.has(identifier) else object.aabb


func _preview_endpoint_rect(identifier: int) -> Rect2:
	return _preview_display_rect(identifier)


func _update_preview_links() -> void:
	var scale := _frame_scale
	var bucket := floori(log(scale) / log(2.0) * 16.0)
	var stage: Stage = get_parent()
	var key := [_layout_revision, stage.document_revision, bucket, stage.world_view_rect]
	if key == _link_render_key:
		return
	_link_render_key = key
	var geometry_context := [_layout_revision, stage.document_revision, scale]
	var refresh_geometry := geometry_context != _link_geometry_context
	_link_geometry_context = geometry_context
	var pixel_scale := pow(2.0, bucket / 16.0)
	for data in _preview_links.values():
		var node: Node2D = data.node
		if refresh_geometry or not data.has("geometry_key"):
			var from := _preview_endpoint_rect(data.source)
			var to := _preview_endpoint_rect(data.target)
			var geometry_key := [from, to]
			# World curves survive camera changes. Only native stroke/head sizes change.
			if data.get("geometry_key", []) != geometry_key:
				data.geometry_key = geometry_key
				var anchors := LineEdge.connection_uvs(from, to)
				data.points = LineEdge.connection_curve(from, to, anchors, 24, 0.0, true)
				data.tip = LineEdge.anchor(to, anchors[1])
				data.direction = -anchors[3] if anchors.size() > 3 else (Vector2(.5,.5) - anchors[1]).normalized()
				var bounds := Rect2(data.points[0], Vector2.ZERO)
				for point in data.points:
					bounds = bounds.expand(point)
				data.bounds = bounds.grow(16.0)
				var line: Line2D = node.get_node("Line")
				line.points = node.get_global_transform().affine_inverse() * data.points
		node.visible = stage.world_view_rect.intersects(data.bounds, true) and _summaries[data.source].visible and _summaries[data.target].visible
		if not node.visible:
			continue
		var line: Line2D = node.get_node("Line")
		var width := 3.0 / pixel_scale
		if not is_equal_approx(line.width, width):
			line.width = width
		var color: Color = data.edge.display_stroke_color()
		if line.default_color != color:
			line.default_color = color
		var head: Polygon2D = node.get_node("Head")
		head.visible = data.edge.show_arrow
		head.color = line.default_color
		head.global_position = data.tip
		head.global_rotation = data.direction.angle()
		var length := 8.0 / pixel_scale
		if data.get("render_bucket", -2147483648) != bucket:
			data.render_bucket = bucket
			head.polygon = PackedVector2Array([Vector2.ZERO, Vector2(-length,-length*.4), Vector2(-length,length*.4)])


func _group_levels(_objects: Array) -> Dictionary:
	var levels := {}
	for identifier in _preview_children:
		var current: int = identifier
		var level := 0
		levels[current] = maxi(int(levels.get(current, 0)), level)
		while _preview_parents.has(current):
			current = _preview_parents[current]
			level += 1
			levels[current] = maxi(int(levels.get(current, 0)), level)
	return levels


func _block_ancestors(entity: Entity, blocked: Dictionary) -> void:
	var current := entity.get_instance_id()
	blocked[current] = true
	while _preview_parents.has(current):
		current = _preview_parents[current]
		blocked[current] = true


func _active_ancestors(entity: Entity) -> Array:
	var ancestors := []
	var current := entity.get_instance_id()
	while _preview_parents.has(current):
		current = _preview_parents[current]
		if _active.has(current):
			ancestors.append(current)
	return ancestors


func _suppress_canvas(node: Node, items: Array[Dictionary], root := true) -> void:
	# Native culling checks every CanvasItem ancestor. One root layer hides the
	# entire subtree; only top-level items need their own layer changed.
	var state := {"node":node}
	if node is CanvasItem and (root or node.top_level):
		state.layer = node.visibility_layer
	if node is Control:
		state.mouse_filter = node.mouse_filter
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.size() > 1:
		items.append(state)
	for child in node.get_children():
		_suppress_canvas(child, items, not node is CanvasItem)


func _restore(key: int) -> void:
	var state: Dictionary = _suppressed[key]
	for item in state.items:
		if not is_instance_valid(item.node):
			continue
		if item.has("layer"):
			item.node.visibility_layer = item.layer
		if item.has("mouse_filter"):
			item.node.mouse_filter = item.mouse_filter
	if is_instance_valid(state.object):
		state.object.input_pickable = state.pickable
	if is_instance_valid(state.object) and state.object is LineEdge:
		state.object._queue_refresh()
		state.object.get_node("Caption")._queue_refresh()
	_suppressed.erase(key)


func _exit_tree() -> void:
	for key in _suppressed.keys():
		_restore(key)


func _update_summary(group: TextNode, panel: Panel) -> void:
	var stage: Stage = get_parent()
	var revision: int = stage.get_meta("loading_overview_revision", stage.layout_revision)
	var identifier := group.get_instance_id()
	var root := _preview_roots.has(identifier) or (stage.is_loading and _active.has(identifier))
	var rect: Rect2 = _preview_display_rect(identifier) if _preview_nodes.has(identifier) else (_group_rects[identifier] if _group_rects.has(identifier) else group.aabb)
	var scale := _frame_scale
	var screen_size := rect.size * scale
	var covered := group._container_active
	# Below legible size, omit tiny frames as well as text to reduce overlap.
	var readable := maxf(screen_size.x, screen_size.y) >= 20.0 if covered else screen_size.x >= 28.0 and screen_size.y >= 18.0
	panel.set_meta("view_rect", rect)
	panel.set_meta("view_readable", readable)
	panel.set_meta("presentation_pending", true)
	if not readable or not stage.world_view_rect.intersects(rect, true):
		panel.hide()
		return
	panel.show()
	panel.set_meta("presentation_pending", false)
	var offset := float(posmod(group.id.hash(), 16)) / 16.0
	var pixel_scale := pow(2.0, (floorf(log(scale) / log(2.0) * 16.0 + offset) - offset) / 16.0)
	var presentation_key := [revision, stage.document_revision, pixel_scale, rect, root, covered, stage._applied_theme_light]
	if panel.get_meta("presentation_key", []) == presentation_key:
		return
	panel.set_meta("presentation_key", presentation_key)
	var light := group._display_theme_is_light()
	var canvas_color := Palette.color(light, "surface.canvas")
	var fill := group.fill_color
	var background := group.display_fill_color() if covered else fill
	if not covered and fill.a == 0 and group.font_size * pixel_scale < 5.0:
		background = Color((Palette.LATTE if light else Palette.MOCHA)["surface2"], .2)
	var border_color := group.display_border_color()
	var text_background := fill if fill.a == 1.0 else canvas_color
	var brightness := .2126 * text_background.r + .7152 * text_background.g + .0722 * text_background.b
	var foreground := Color.BLACK if brightness > 128.0 / 255.0 else Color.WHITE
	var text := group.text
	var content_key := [text, foreground]
	var key := [revision, pixel_scale, rect, root, covered, _miniatures.has(identifier), content_key, background, border_color, group.font_size]
	if panel.get_meta("summary_key", []) == key:
		return
	panel.set_meta("summary_key", key)
	panel.position = to_local(rect.position)
	panel.scale = Vector2.ONE / pixel_scale
	panel.size = rect.size * pixel_scale
	panel.z_index = 66 if root else 68
	var title: Label = panel.get_node("Title")
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title.z_index = 4 if root else 0
	title.clip_text = false
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _summary_font == null:
		_summary_font = TextNode._make_canvas_font(preload("res://assets/fonts/PingFang-SC-Regular.ttf")) as FontFile
	if panel.get_meta("summary_content", []) != content_key:
		title.text = text
		title.add_theme_font_override("font", _summary_font)
		title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
		title.add_theme_color_override("font_color", foreground)
		panel.set_meta("summary_content", content_key)
	# Native Label metrics include explicit line breaks and the font's ascent.
	var measured := title.get_minimum_size()
	var sampling_ceiling := pixel_scale * pow(2.0, 1.0 / 16.0)
	var title_area := Rect2(Vector2.ZERO, panel.size)
	if covered:
		var header := (group.label.get_global_transform() * Rect2(Vector2.ZERO, group.label.size)).intersection(rect)
		title_area = Rect2((header.position - rect.position) * pixel_scale, header.size * pixel_scale)
		# Give the group heading a readable strip, never the whole group body.
		title_area.size.y = minf(panel.size.y * .2,
			maxf(title_area.size.y, DETAIL_TITLE_PIXELS * pixel_scale / sampling_ceiling))
	var fit := minf(title_area.size.x / maxf(measured.x, .0001),
		title_area.size.y / maxf(measured.y, .0001)) * .9
	var desired := float(group.font_size) * pixel_scale
	if covered:
		desired = maxf(desired, DETAIL_TITLE_PIXELS * pixel_scale / sampling_ceiling)
	desired = minf(desired, minf(fit * TITLE_FONT_SIZE, MAX_SUMMARY_TITLE_PIXELS * pixel_scale / sampling_ceiling))
	var factor := maxf(desired, 0.0) / TITLE_FONT_SIZE
	title.visible = not text.strip_edges().is_empty() and desired * scale / pixel_scale >= 5.0
	title.size = measured
	title.scale = Vector2.ONE * factor
	title.position = title_area.position + (title_area.size - measured * factor) * .5
	# The direct next-layer preview stays above the parent to preserve requested
	# readability, while every covered title uses the master fitting formula.
	var native_control: Control = group.container_panel if covered else group.label
	var native_style := Corners.source(native_control.get_theme_stylebox("panel" if covered else "normal"))
	var native_transform := stage.global_transform.affine_inverse() * native_control.get_global_transform()
	var radius := float(native_style.corner_radius_top_left) * native_transform.get_scale().abs().x * pixel_scale if native_style != null else 0.0
	var framed := group._container_active
	var style_key := [background, border_color, radius, framed, covered, root, _miniatures.has(identifier)]
	if panel.get_meta("style_key", []) != style_key:
		var style := StyleBoxFlat.new()
		style.bg_color = background if framed else fill
		style.draw_center = framed or fill.a > 0.0
		style.border_color = border_color
		style.set_border_width_all(1 if framed and covered else 0)
		panel.add_theme_stylebox_override("panel", Corners.style(style, radius, true, true))
		panel.set_meta("style_key", style_key)
	if _miniatures.has(identifier):
		# The geometry cache draws this body once; this panel supplies only text.
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var border := panel.get_node_or_null("Border") as Line2D
	if border == null:
		border = Line2D.new()
		border.name = "Border"
		border.antialiased = true
		border.texture = preload("res://assets/line_antialiasing.res")
		border.texture_mode = Line2D.LINE_TEXTURE_TILE
		border.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		border.closed = true
		panel.add_child(border)
	border.visible = framed and not covered
	border.scale = Vector2.ONE * pixel_scale
	border.default_color = border_color
	# Native texture includes a one-pixel AA fringe on either side.
	border.width = (2.0 if covered else 2.0 * pixel_scale) / pixel_scale + 2.0 / pixel_scale
	var border_key := [rect.size, framed, radius / pixel_scale]
	if border.visible and border.get_meta("geometry_key", []) != border_key:
		border.points = Corners.outline(Rect2(Vector2.ZERO, rect.size), radius / pixel_scale)
		border.set_meta("geometry_key", border_key)


func _avoid_title_overlaps() -> void:
	var key := []
	for identifier in _summaries:
		var panel: Panel = _summaries[identifier]
		key.append([identifier, panel.visible, panel.get_meta("summary_key", [])])
	if key == _overlap_key:
		for panel in _overlap_hidden:
			if is_instance_valid(panel): panel.hide()
		return
	_overlap_key = key
	_overlap_hidden.clear()
	var occupied: Array[Rect2] = []
	for identifier in _preview_roots:
		var panel := _summaries.get(identifier) as Panel
		if panel == null or not panel.visible: continue
		var title: Label = panel.get_node("Title")
		if title.visible:
			occupied.append(title.get_global_transform() * Rect2(Vector2.ZERO, title.size))
	for identifier in _summaries:
		if _preview_roots.has(identifier): continue
		var panel: Panel = _summaries[identifier]
		if not panel.visible: continue
		var title: Label = panel.get_node("Title")
		if not title.visible:
			continue
		# Only drawn glyphs compete for space; a frame or invisible Control is
		# not an occupied title. Keep background geometry and input intact.
		var rect := title.get_global_transform() * Rect2(Vector2.ZERO, title.size)
		var overlaps := false
		for used in occupied:
			if rect.intersects(used):
				overlaps = true
				break
		if overlaps:
			panel.hide()
			_overlap_hidden.append(panel)
		else:
			occupied.append(rect)

func _on_summary_input(event: InputEvent, group: TextNode) -> void:
	if not is_instance_valid(group) or is_hidden(group):
		return
	group._on_label_gui_input(event)
	# A double click opens the normal editor at its original, stable position.
	if group._editing:
		refresh()


func _cache_cover_groups() -> void:
	_cover_groups.clear()
	for identifier in _entities:
		var ancestors := []
		var current: int = identifier
		while _preview_parents.has(current):
			current = _preview_parents[current]
			ancestors.append(current)
		_cover_groups[identifier] = ancestors
	for object in _objects:
		if not object is LineEdge or not is_instance_valid(object.source) or not is_instance_valid(object.target):
			continue
		var from: Array = _cover_groups.get(object.source.get_instance_id(), []).duplicate()
		var to: Array = _cover_groups.get(object.target.get_instance_id(), []).duplicate()
		from.append(object.source.get_instance_id())
		to.append(object.target.get_instance_id())
		_cover_groups[object.get_instance_id()] = from.filter(func(key): return to.has(key))


## Full group bounds/topology are installed first; suppress arriving detail before draw.
func register_loading_object(object: StageObject) -> void:
	var covered := false
	if object is Entity:
		var current: Entity = object.container
		while is_instance_valid(current):
			if _active.has(current.get_instance_id()):
				covered = true
				break
			current = current.container
	elif object is LineEdge and is_instance_valid(object.source) and is_instance_valid(object.target):
		for key in _active:
			var group: Entity = _active[key]
			var from_inside: bool = object.source == group or object.source.is_inside_container(group)
			var to_inside: bool = object.target == group or object.target.is_inside_container(group)
			if from_inside and to_inside:
				covered = true
				break
	if not covered:
		return
	var key := object.get_instance_id()
	_hidden[key] = true
	if _suppressed.has(key):
		return
	var items: Array[Dictionary] = []
	_suppress_canvas(object, items)
	_suppressed[key] = {"object": object, "items": items, "pickable": object.input_pickable}
	for item in items:
		if item.has("layer"):
			item.node.visibility_layer = 0
	object.input_pickable = false
