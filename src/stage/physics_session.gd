extends Node
## Native broadphase activates contacts only during a gesture or throw.
## Idle presentation does not make overlapping document records move by itself.
const CONTACT_MARGIN := 8.0
const LOOKAHEAD_SECONDS := 0.05
const STABLE_FRAMES := 3
var target_root: Node2D
var _members := {}
var _group_followers: Dictionary = {}
var _follower_rids: Array[RID] = []
var _group_topology_revision := -1
var _stable := 0
var active := false
var _shape := RectangleShape2D.new()

func _ready() -> void:
	target_root = get_parent()
	process_physics_priority = 100
	set_physics_process(false)

func begin(drivers: Array) -> void:
	for body in drivers:
		if body is Entity and is_instance_valid(body) and body.get_parent() == target_root and not body._overview_physics_hidden and not is_instance_valid(body._rigid_follow_owner):
			_members[body] = true
			_register_group_followers(body)
			body.freeze = false
			body.sleeping = false
	if _members.is_empty():
		return
	active = true
	_stable = 0
	set_physics_process(true)

# Descendant ownership lasts through inertia and ends with the transaction's
# physics session. Hidden bodies are outside the space; expanded followers stay
# kinematic but never run independent integration or contact discovery.
func _register_group_followers(driver: Entity) -> void:
	for object in target_root.get_children():
		var child := object as Entity
		if child == null or child == driver or not child.is_inside_container(driver):
			continue
		if _group_followers.has(child) and child._rigid_follow_owner == driver:
			continue
		child.stop_throw()
		child._rigid_follow_owner = driver
		child.drag_controlled = false
		child.freeze = true
		child.sleeping = true
		_group_followers[child] = child.global_position - driver.global_position
		_members.erase(child)
		if not _follower_rids.has(child.get_rid()):
			_follower_rids.append(child.get_rid())

func sync_group_followers(physics_only := false) -> void:
	var check_containment: bool = not target_root is Stage or _group_topology_revision != target_root.topology_revision
	for child in _group_followers.keys():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			_group_followers.erase(child)
			continue
		var driver: Entity = child._rigid_follow_owner
		if not is_instance_valid(driver) or driver.is_queued_for_deletion() or (check_containment and not child.is_inside_container(driver)):
			child._rigid_follow_owner = null
			child.freeze = true
			_group_followers.erase(child)
			continue
		# Collapsed descendants have no native contacts. Publish their poses once
		# before render/layout rather than repeating work for catch-up steps.
		if physics_only and child._overview_physics_hidden:
			continue
		child._set_group_follow_position(driver.global_position + _group_followers[child])
	if target_root is Stage:
		_group_topology_revision = target_root.topology_revision

func _activate_contacts() -> void:
	var space := target_root.get_world_2d().direct_space_state
	var queue := _members.keys()
	var excluded: Array[RID] = _follower_rids.duplicate()
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
			if candidate._overview_physics_hidden or is_instance_valid(candidate._rigid_follow_owner):
				continue
			if _members.has(candidate):
				continue
			# Enclosing frames are collision-exempt from their descendants.
			if body.is_inside_container(candidate) or candidate.is_inside_container(body):
				continue
			_members[candidate] = true
			_register_group_followers(candidate)
			excluded.append_array(_follower_rids.filter(func(rid): return not excluded.has(rid)))
			candidate.freeze = false
			candidate.sleeping = false
			queue.append(candidate)
		if hits.size() == 256:
			# Query this body again with the newly activated bodies excluded.
			queue.append(body)

func _physics_process(_delta: float) -> void:
	sync_group_followers(true)
	for body in _members.keys():
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != target_root or body._overview_physics_hidden or is_instance_valid(body._rigid_follow_owner):
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
	sync_group_followers()
	for child in _group_followers:
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child._rigid_follow_owner = null
			child.drag_controlled = false
			child.stop_throw()
			child.freeze = true
			child.sleeping = true
	_group_followers.clear()
	_follower_rids.clear()
	_group_topology_revision = -1
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
