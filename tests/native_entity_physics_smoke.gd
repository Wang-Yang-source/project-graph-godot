extends SceneTree
var failures: Array[String] = []
var stage: Stage
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _run() -> void:
	GraphPreferences.set_value("left_mode", 0, false)
	stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	var a = stage.create_text_node("Driver", Vector2.ZERO, false)
	var b = stage.create_text_node("Passive", Vector2(220, 0), false)
	a.fixed_width = 160
	b.fixed_width = 160
	await frames(8)
	check(PhysicsServer2D.body_get_space(a.get_rid()).is_valid(), "Entity is registered in a native physics space")
	check(not a.freeze and a.collision_layer != 0 and a.collision_mask != 0, "Entity collision and simulation are enabled")
	check(a.physics_material_override != null and a.physics_material_override.friction > 0.0, "Contact uses native friction")
	var b_origin = b.global_position
	a._start_throw(Vector2(900, 0))
	await frames(60)
	check(a.global_position.x > 5.0, "Native inertia advances the released node")
	check(b.global_position.x > b_origin.x + 5.0, "A real native contact pushes the passive node")
	check(a.linear_velocity.length() < 50.0, "Native damping slows released motion")
	a.stop_throw()
	b.stop_throw()
	a.move_without_inertia(Vector2(0, 400))
	b.move_without_inertia(Vector2(300, 400))
	await frames(8)
	stage.history.clear()
	var before = StageObjectRegistry.capture(stage)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = stage.get_canvas_transform() * a.global_position
	a._on_input_event(stage.get_viewport(), press, 0)
	a.set_physics_process(false)
	check(a.freeze and a.freeze_mode == RigidBody2D.FREEZE_MODE_KINEMATIC, "Pointer driver uses native kinematic freeze mode")
	var passive_origin = b.global_position
	for i in 45:
		a._update_drag_target(Vector2(5.0 * (i + 1), 400))
		await frames(1)
	check(b.global_position.x > passive_origin.x + 5.0, "Dragging pushes a neighbour through Godot collision response")
	a.finish_drag(false, a.global_position)
	for i in 120:
		if not stage.history._pending_commit:
			break
		await frames(1)
	check(not a.freeze, "Release restores dynamic simulation")
	check(stage.history._undo_stack.size() == 1, "Drag and contact settle into one undo entry")
	var after = StageObjectRegistry.capture(stage)
	await stage.history.undo()
	await frames(8)
	check(StageObjectRegistry.capture(stage) == before, "Undo restores both driver and passive node")
	await stage.history.redo()
	await frames(8)
	check(StageObjectRegistry.capture(stage) == after, "Redo restores the settled collision result")
	var group = stage.create_text_node("Group", Vector2(0, 1000), false)
	var child = stage.create_text_node("Child", Vector2(40, 1100), false)
	child.container = group
	await frames(20)
	check(child.get_collision_exceptions().has(group), "Contained child ignores its own enclosing body")
	var relative = child.global_position - group.global_position
	await frames(40)
	check((child.global_position - group.global_position).distance_to(relative) < 0.5, "Containing geometry does not eject its own child")
	press.position = stage.get_canvas_transform() * group.global_position
	group._on_input_event(stage.get_viewport(), press, 0)
	group.set_physics_process(false)
	var group_origin = group.global_position
	for i in 10:
		group._update_drag_target(group_origin + Vector2(10.0 * (i + 1), 0))
		await frames(1)
	group.finish_drag(false, group.global_position)
	await frames(20)
	check((child.global_position - group.global_position).distance_to(relative) < 0.5, "Group dragging preserves the child's relative placement")
	var throw_origin = group.global_position
	group._start_throw(Vector2(400, 0))
	await frames(20)
	check(group.global_position.x > throw_origin.x + 1.0, "Groups also use native inertia")
	check((child.global_position - group.global_position).distance_to(relative) < 0.5, "Group inertia carries its descendants without a second throw")
	group.stop_throw()
	var flick = stage.create_text_node("Flick", Vector2(1500, -1000), false)
	await frames(8)
	press.position = stage.get_canvas_transform() * flick.global_position
	flick._on_input_event(stage.get_viewport(), press, 0)
	flick.set_physics_process(false)
	await frames(2)
	flick._update_drag_target(Vector2(1540, -1000))
	await frames(1)
	flick.finish_drag(true, Vector2(1550, -1000))
	check(flick.is_throwing and flick.linear_velocity.x > 0.0, "Pointer release transfers sampled velocity to the native body")
	var released_position = flick.global_position
	await frames(10)
	check(flick.global_position.x > released_position.x + 1.0, "Released pointer gesture retains visible inertia")
	stage.queue_free()
	await process_frame
	print("NATIVE_ENTITY_PHYSICS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
