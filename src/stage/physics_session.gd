extends Node
## Native broadphase activates contacts only during a gesture or throw.
## Idle presentation does not make overlapping document records move by itself.
const CONTACT_MARGIN := 8.0
const LOOKAHEAD_SECONDS := 0.05
const STABLE_FRAMES := 3
var target_root: Node2D
var _members := {}
var _stable := 0
var active := false
var _shape := RectangleShape2D.new()

func _ready() -> void:
	target_root = get_parent()
	process_physics_priority = 100
	set_physics_process(false)

func begin(drivers: Array) -> void:
	for body in drivers:
		if body is Entity and is_instance_valid(body) and body.get_parent() == target_root:
			_members[body] = true
			body.freeze = false
			body.sleeping = false
	if _members.is_empty():
		return
	active = true
	_stable = 0
	set_physics_process(true)

func _activate_contacts() -> void:
	var space := target_root.get_world_2d().direct_space_state
	var queue := _members.keys()
	var excluded: Array[RID] = []
	for body in queue:
		if is_instance_valid(body):
			excluded.append(body.get_rid())
	var cursor := 0
	while cursor < queue.size():
		var body: Entity = queue[cursor]
		cursor += 1
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var bounds := body.aabb.grow(CONTACT_MARGIN)
		var predicted := bounds
		predicted.position += body.linear_velocity * LOOKAHEAD_SECONDS
		bounds = bounds.merge(predicted)
		_shape.size = bounds.size.max(Vector2.ONE)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = _shape
		query.transform = Transform2D(0.0, bounds.get_center())
		query.collision_mask = 1
		query.exclude = excluded
		var hits := space.intersect_shape(query, 256)
		for hit in hits:
			var candidate: Variant = hit.collider
			if candidate is CollisionObject2D and not excluded.has(candidate.get_rid()):
				excluded.append(candidate.get_rid())
			if not candidate is Entity or not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or candidate.get_parent() != target_root:
				continue
			if _members.has(candidate):
				continue
			# Enclosing frames are collision-exempt from their descendants.
			if body.is_inside_container(candidate) or candidate.is_inside_container(body):
				continue
			_members[candidate] = true
			candidate.freeze = false
			candidate.sleeping = false
			queue.append(candidate)
		if hits.size() == 256:
			# Query this body again with the newly activated bodies excluded.
			queue.append(body)

func _physics_process(_delta: float) -> void:
	for body in _members.keys():
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != target_root:
			_members.erase(body)
	if _members.is_empty():
		end()
		return
	_activate_contacts()
	var moving := false
	for body in _members:
		if body.drag_controlled or body.is_dragging or body.is_throwing or body.linear_velocity.length_squared() > 4.0 or absf(body.angular_velocity) > 0.05:
			moving = true
			break
	_stable = 0 if moving else _stable + 1
	if _stable >= STABLE_FRAMES:
		end()

func end() -> void:
	for body in _members:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.stop_throw()
			body.freeze = true
			body.sleeping = true
	_members.clear()
	active = false
	_stable = 0
	set_physics_process(false)

func _exit_tree() -> void:
	end()
