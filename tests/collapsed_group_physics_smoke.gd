extends SceneTree
## Run only through the authorized Godot MCP regression runner.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		# SceneTree.process_frame precedes node callbacks. Observe the published
		# group pose after the render/layout pass, just as the viewport does.
		await create_timer(0.0).timeout

func entity_for_id(stage: Stage, identifier: String) -> Entity:
	for object in stage.stage_objects():
		if object is Entity and object.id == identifier:
			return object
	return null

func _run() -> void:
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var group := stage.create_text_node("Whole group", Vector2(100, 100), false)
	var a := stage.create_text_node("A", Vector2(220, 170), false)
	var nested := stage.create_text_node("Nested", Vector2(380, 180), false)
	var b := stage.create_text_node("B", Vector2(500, 260), false)
	a.container = group
	nested.container = group
	b.container = nested
	await frames(10)
	var session := stage.get_node("PhysicsSession")
	var followers: Array[Entity] = [a, nested, b]
	var offsets := {}
	for child in followers:
		offsets[child.id] = child.global_position - group.global_position
		child.set_overview_physics_hidden(true)
		check(not PhysicsServer2D.body_get_space(child.get_rid()).is_valid(), "Collapsed descendant leaves native space")
	check(PhysicsServer2D.body_get_space(group.get_rid()) == group.get_world_2d().space, "Whole group root remains physical")
	var group_id := group.id
	var start := group.global_position
	stage.history.begin_transaction()
	group._drag_target = start + Vector2(240, 0)
	group.drag_controlled = true
	await frames(20)
	check(group.global_position.distance_to(start) > 50.0, "Native group driver moves")
	check(session._members.size() == 1, "Only group root discovers contacts")
	check(session._group_followers.size() == followers.size(), "Nested descendants have one driver")
	for child in followers:
		check((child.global_position - group.global_position).is_equal_approx(offsets[child.id]), "Dragged descendant keeps group offset")
		check(child.freeze and not child.drag_controlled, "Hidden descendant does not integrate independently")
		child.set_overview_physics_hidden(false)
		check(PhysicsServer2D.body_get_space(child.get_rid()) == child.get_world_2d().space, "Expansion restores native space")
	await frames(6)
	for child in followers:
		check((child.global_position - group.global_position).is_equal_approx(offsets[child.id]), "Expansion cannot replay stale native position")
	group.drag_controlled = false
	group._start_throw(Vector2(150, 0))
	await frames(12)
	for child in followers:
		check((child.global_position - group.global_position).is_equal_approx(offsets[child.id]), "Released group retains rigid offsets during inertia")
	session.end()
	var final := group.global_position
	for child in followers:
		check(child._rigid_follow_owner == null and child.freeze, "Session settles and clears temporary ownership")
	stage.history.commit(false)
	await frames(4)
	await stage.history.undo()
	await frames(8)
	var restored := entity_for_id(stage, group_id)
	check(restored != null and restored.global_position.is_equal_approx(start), "Undo restores native group position")
	await stage.history.redo()
	await frames(8)
	restored = entity_for_id(stage, group_id)
	check(restored != null and restored.global_position.is_equal_approx(final), "Redo restores released group position")
	# A standalone external obstacle still participates in the native session.
	var obstacle := stage.create_text_node("External", Vector2(restored.aabb.end.x + 4, restored.aabb.get_center().y), false)
	await frames(6)
	session.begin([restored])
	await frames(1)
	check(session._members.has(obstacle), "External collision/contact activation remains enabled")
	var obstacle_origin := obstacle.global_position
	restored._drag_target = restored.global_position + Vector2(200, 0)
	restored.drag_controlled = true
	await frames(24)
	check(obstacle.global_position.distance_to(obstacle_origin) > 1.0, "Whole group keeps native external collision and avoidance")
	for child_id in offsets:
		var member := entity_for_id(stage, child_id)
		check(member != null and (member.global_position - restored.global_position).is_equal_approx(offsets[child_id]), "Redo and external contacts preserve internal offsets")
	# Switching to Alt cancels all temporary physics ownership first.
	restored._drag_origins[restored] = restored.global_position
	restored.is_dragging = true
	restored.pause_drag_for_layer_move()
	check(not session.active and session._group_followers.is_empty(), "Alt gesture clears native group session")
	session.end()
	stage.queue_free()
	await process_frame
	print("COLLAPSED_GROUP_PHYSICS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
