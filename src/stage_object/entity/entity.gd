class_name Entity
extends StageObject

# 单父包含关系使用稳定对象引用；所有刚体仍直接挂在舞台下，保持世界坐标。
@export var container: Entity:
	set(value):
		if container == value:
			return
		container = value
		notify_topology_change()
		if is_inside_tree():
			_refresh_container_collisions.call_deferred()
			for child in get_parent().get_children():
				if child is Entity and child.is_inside_container(self):
					child._refresh_container_collisions.call_deferred()
		notify_persistent_change()
		invalidate_geometry()

@export var throw_speed_limit := 1200.0:
	set(value):
		throw_speed_limit = value
		notify_persistent_change()
@export var throw_damping := 7.0:
	set(value):
		throw_damping = value
		notify_persistent_change()

var _physics_outline: CollisionShape2D
var _collision_outline_pending := false

const THROW_SAMPLE_SECONDS := 0.08
static var _native_material: PhysicsMaterial
var _collision_ancestors: Array[Entity] = []

var is_dragging: bool = false:
	set(value):
		is_dragging = value
		set_process_input(value)
		set_physics_process(is_dragging or is_throwing)
var drag_controlled := false:
	set(value):
		drag_controlled = value
		# Keep contacts dynamic; only the physics callback drives the gesture.
		freeze = false
		if value:
			sleeping = false
			if is_inside_tree():
				var session := get_parent().get_node_or_null("PhysicsSession")
				if session != null:
					session.begin([self])
var drag_offset: Vector2 = Vector2.ZERO
var is_throwing := false:
	set(value):
		is_throwing = value
		set_physics_process(is_dragging or is_throwing)
var _position_sync_pending := false
var _position_sync_target := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_moved := false
var _last_drag_update := Vector3.INF
var _drag_target := Vector2.ZERO
var _drag_samples: Array[Dictionary] = []
var _release_pending := false
var _release_velocity := Vector2.ZERO
var _saved_damping := 0.0
var _history: History
var _drag_origins: Dictionary[Entity, Vector2] = {}
var _drag_followers: Dictionary[Entity, bool] = {}


func _ready() -> void:
	set_process_input(is_dragging)
	set_physics_process(is_dragging or is_throwing)
	_history = _find_history()
	# Native bodies own contacts, friction, damping and inertia; controls still pick.
	collision_layer = 1
	collision_mask = 1
	freeze_mode = FREEZE_MODE_KINEMATIC
	freeze = get_parent().get_node_or_null("PhysicsSession") != null
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = throw_damping
	continuous_cd = CCD_MODE_CAST_SHAPE
	if _native_material == null:
		_native_material = PhysicsMaterial.new()
		_native_material.friction = 0.7
		_native_material.bounce = 0.0
	physics_material_override = _native_material
	_refresh_container_collisions.call_deferred()
	geometry_changed.connect(_queue_collision_outline_update)
	_queue_collision_outline_update()


func _queue_collision_outline_update() -> void:
	if _collision_outline_pending:
		return
	_collision_outline_pending = true
	_refresh_collision_outline.call_deferred()


func _refresh_collision_outline() -> void:
	_collision_outline_pending = false
	if not is_inside_tree():
		return
	var bounds := Rect2()
	var initialized := false
	for child in get_children():
		var source := child as CollisionShape2D
		if source == null or source == _physics_outline or source.shape == null:
			continue
		if source.disabled and not source.has_meta("editor_geometry_only"):
			continue
		var rect: Rect2 = source.transform * source.shape.get_rect()
		if rect.size.is_zero_approx():
			continue
		bounds = bounds.merge(rect) if initialized else rect
		initialized = true
		# Keep the original geometry for picking, connections and editor bounds.
		source.set_meta("editor_geometry_only", true)
		source.disabled = true
	if not initialized:
		if _physics_outline != null:
			_physics_outline.disabled = true
		return
	if _physics_outline == null:
		_physics_outline = CollisionShape2D.new()
		_physics_outline.name = "PhysicsOutline"
		_physics_outline.set_meta("physics_outline", true)
		add_child(_physics_outline)
	if has_method("get_visual_outline"):
		var points: PackedVector2Array = Geometry2D.convex_hull(call("get_visual_outline"))
		if points.size() > 1 and points[0].is_equal_approx(points[-1]):
			points.resize(points.size() - 1)
		var polygon := _physics_outline.shape as ConvexPolygonShape2D
		if polygon == null or polygon.points != points:
			polygon = ConvexPolygonShape2D.new()
			polygon.points = points
			_physics_outline.shape = polygon
		_physics_outline.position = Vector2.ZERO
	else:
		var shape := _physics_outline.shape as RectangleShape2D
		if shape == null or shape.size != bounds.size:
			shape = RectangleShape2D.new()
			shape.size = bounds.size
			_physics_outline.shape = shape
		_physics_outline.position = bounds.get_center()
	_physics_outline.disabled = false


func _uses_native_physics() -> bool:
	return true


func _refresh_container_collisions() -> void:
	# Enclosing panels must not eject their own descendants.
	for ancestor in _collision_ancestors:
		if is_instance_valid(ancestor):
			remove_collision_exception_with(ancestor)
	_collision_ancestors.clear()
	var ancestor := container
	while is_instance_valid(ancestor) and not _collision_ancestors.has(ancestor):
		add_collision_exception_with(ancestor)
		_collision_ancestors.append(ancestor)
		ancestor = ancestor.container


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.alt_pressed:
			return
		if event.pressed:
			if int(GraphPreferences.value("left_mode")) != 0:
				return
			# 通过父节点的选择接口交互，避免 Entity 反向依赖引用其子类的 Stage。
			var stage: Node = get_parent()
			if stage != null and not (stage.has_method("select_object_from_click") and stage.has_method("selected_objects")):
				stage = null
			if stage != null:
				stage.call("select_object_from_click", self, event)
			get_viewport().set_input_as_handled()
			if stage != null and not (stage.get("selected_ids") as PackedStringArray).has(id):
				return
			if _history != null:
				_history.begin_transaction()
			is_dragging = true
			_drag_moved = false
			_last_drag_update = Vector3.INF
			_drag_origin = global_position
			drag_offset = get_canvas_transform().affine_inverse() * event.position - global_position
			_drag_samples.clear()
			_sample_pointer(global_position)
			_drag_origins.clear()
			if stage != null:
				for object in stage.call("drag_entities"):
					if object is Entity:
						_drag_origins[object] = object.global_position
			if _drag_origins.is_empty():
				_drag_origins[self] = global_position
			_drag_followers.clear()
			if stage != null:
				var roots := _drag_origins.keys()
				for child in stage.get_children():
					var candidate := child as Entity
					if candidate == null or _drag_origins.has(candidate):
						continue
					for root in roots:
						if candidate.is_inside_container(root):
							_drag_origins[candidate] = candidate.global_position
							_drag_followers[candidate] = true
							break
			for object in _drag_origins:
				object.stop_throw()
				object.drag_controlled = true
				object._drag_target = object.global_position
				object.linear_velocity = Vector2.ZERO
				object.angular_velocity = 0.0
				object.sleeping = false
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0
			if stage != null:
				var solver := stage.get_node_or_null("NodeRepulsion")
				if solver != null:
					solver.begin_local_edit(_drag_origins.keys().filter(func(object): return not _drag_followers.has(object)))
		else:
			finish_drag(true, get_canvas_transform().affine_inverse() * event.position)
		return

	if event is InputEventMouseMotion and is_dragging:
		_update_drag_target(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventWithModifiers and event.alt_pressed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_drag(true, get_canvas_transform().affine_inverse() * event.position)
	elif event is InputEventMouseMotion and is_dragging:
		_update_drag_target(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func finish_drag(allow_throw := false, world_pointer := Vector2.INF) -> void:
	if not is_dragging:
		return
	_update_drag_target(world_pointer)
	var velocity := _pointer_velocity() if _drag_moved and allow_throw else Vector2.ZERO
	is_dragging = false
	for object in _drag_origins:
		if is_instance_valid(object):
			object.drag_controlled = false
			object._release_pending = false
			# Descendants follow their parent after release; do not add a second throw.
			object._release_velocity = Vector2.ZERO if _drag_followers.has(object) else velocity
			object._start_throw(object._release_velocity)
	_drag_origins.clear()
	_drag_followers.clear()
	_drag_samples.clear()
	if _history != null:
		_history.commit()


func _physics_process(_delta: float) -> void:
	if is_throwing and linear_velocity.length_squared() < 4.0:
		stop_throw()
	if is_dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not is_visible_in_tree():
			finish_drag()
		elif not Input.is_key_pressed(KEY_ALT):
			_update_drag_target()


func _update_drag_target(world_pointer := Vector2.INF) -> void:
	var pointer: Vector2 = get_global_mouse_position() if world_pointer == Vector2.INF else world_pointer
	var target_position := pointer - drag_offset
	_sample_pointer(target_position)
	if not _drag_moved:
		var screen_delta := get_global_transform_with_canvas().basis_xform(target_position - _drag_origin)
		if screen_delta.length() < 4.0:
			return
		_drag_moved = true
	if GraphPreferences.value("snap"):
		target_position = target_position.snapped(Vector2(64, 64))
	if not _needs_drag_target_update(target_position):
		return
	var displacement: Vector2 = target_position - _drag_origin
	for object in _drag_origins:
		if is_instance_valid(object):
			object._drag_target = _drag_origins[object] + displacement
			object.sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _position_sync_pending:
		var pose := state.transform
		pose.origin = _position_sync_target
		state.transform = pose
		state.linear_velocity = Vector2.ZERO
		_position_sync_pending = false
	if drag_controlled:
		# Upstream's velocity-following gesture, applied on the native physics clock.
		# Bound the gain by the timestep so a slow frame cannot overshoot the target.
		var gain := minf(20.0, 1.0 / maxf(state.step, 0.001))
		state.linear_velocity = ((_drag_target - state.transform.origin) * gain).limit_length(throw_speed_limit)
		state.angular_velocity = 0.0
	super._integrate_forces(state)


# Input events and physics catch-up may report the same target repeatedly.
# Keep sampling pointer history, but avoid waking/moving every group member.
func _needs_drag_target_update(target_position: Vector2, axis := -1) -> bool:
	var key := Vector3(target_position.x, target_position.y, float(axis))
	if key == _last_drag_update:
		return false
	_last_drag_update = key
	return true


func _sample_pointer(world_position := Vector2.INF) -> void:
	var now := float(Time.get_ticks_usec()) / 1000000.0
	_drag_samples.append({"time": now, "position": get_global_mouse_position() if world_position == Vector2.INF else world_position})
	while _drag_samples.size() > 2 and float(_drag_samples[1].time) < now - THROW_SAMPLE_SECONDS:
		_drag_samples.pop_front()
	while _drag_samples.size() > 64:
		_drag_samples.pop_front()


func _pointer_velocity() -> Vector2:
	if _drag_samples.size() < 2:
		return Vector2.ZERO
	var last: Dictionary = _drag_samples.back()
	var first: Dictionary = _drag_samples.front()
	var elapsed := float(last.time) - float(first.time)
	if elapsed < 0.008:
		return Vector2.ZERO
	var velocity: Vector2 = (last.position - first.position) / elapsed
	return (velocity * 0.55).limit_length(throw_speed_limit) if velocity.length() >= 25.0 else Vector2.ZERO


func _start_throw(velocity: Vector2) -> void:
	is_throwing = not velocity.is_zero_approx()
	if is_throwing:
		freeze = false
		var session := get_parent().get_node_or_null("PhysicsSession")
		if session != null:
			session.begin([self])
		_saved_damping = linear_damp
		linear_damp = throw_damping
	linear_velocity = velocity
	sleeping = false


func stop_throw() -> void:
	if is_throwing:
		linear_damp = _saved_damping
	is_throwing = false
	_release_pending = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _find_history() -> History:
	var node: Node = self
	while node != null:
		var history := node.get_node_or_null("History") as History
		if history != null:
			return history
		node = node.get_parent()
	return null


func is_inside_container(ancestor: Entity) -> bool:
	var cursor := container
	var visited: Array[Entity] = []
	while is_instance_valid(cursor) and not visited.has(cursor):
		if cursor == ancestor:
			return true
		visited.append(cursor)
		cursor = cursor.container
	return false


func container_depth() -> int:
	var cursor := container
	var visited: Array[Entity] = []
	while is_instance_valid(cursor) and not visited.has(cursor):
		visited.append(cursor)
		cursor = cursor.container
	return visited.size()


func pause_drag_for_layer_move() -> void:
	if not is_dragging:
		return
	is_dragging = false
	for object in _drag_origins:
		if is_instance_valid(object):
			object.drag_controlled = false
			object.stop_throw()
	_drag_origins.clear()
	_drag_samples.clear()


func move_without_inertia(world_position: Vector2) -> void:
	stop_throw()
	global_position = world_position
	_position_sync_target = world_position
	_position_sync_pending = true
	sleeping = false
