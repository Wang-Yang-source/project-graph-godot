extends SceneTree
## Authorized regression for collapsed whole-group movement.
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
		await create_timer(0.0).timeout
func entity_for_id(stage: Stage, identifier: String) -> Entity:
	for object in stage.stage_objects():
		if object is Entity and object.id == identifier:
			return object
	return null
func click(body: Entity) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = body.get_canvas_transform() * body.global_position
	body._on_input_event(body.get_viewport(), event, 0)
func _run() -> void:
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	stage.camera.zoom = Vector2.ONE
	stage.camera.target_zoom = Vector2.ONE
	var group := stage.create_text_node("Group", Vector2(100, 100), false)
	var child := stage.create_text_node("Inside", Vector2(230, 180), false)
	var other := stage.create_text_node("External", Vector2(1100, 1000), false)
	child.container = group
	await frames(8)
	var child_id := child.id
	child.set_overview_physics_hidden(true)
	var before := child.global_position
	stage.select_ids(PackedStringArray([child.id]))
	click(child)
	child.drag_controlled = true
	child.is_dragging = true
	child._start_throw(Vector2(300, 0))
	check(not child.is_dragging and not child.drag_controlled and not child.is_throwing,
		"Hidden member rejects direct pointer, drag-control and throw starts")
	check(not child.is_processing_input() and not child.is_physics_processing(),
		"Hidden member has no independent input or physics callbacks")
	check(stage.drag_entities().is_empty() and stage.get_node("EntityLayerMover").selection_roots().is_empty(),
		"Hidden-only selection cannot enter keyboard or Alt movement")
	check(not stage.get_node("StageAlignment").available("alignSelectionToGrid"),
		"Selected hidden member cannot execute a keyboard snap")
	stage.select_ids(PackedStringArray([child.id, other.id]))
	check(stage.drag_entities() == [other] and stage.get_node("EntityLayerMover").selection_roots() == [other],
		"Multi-selection moves only visible independent roots")
	child.set_overview_physics_hidden(false)
	stage.history.clear()
	stage.select_ids(PackedStringArray([child.id]))
	click(child)
	check(child.is_dragging and child.drag_controlled,
		"Expansion restores independent pointer dragging")
	child.move_without_inertia(before + Vector2(30, 20))
	child._drag_target = child.global_position
	child.set_overview_physics_hidden(true)
	check(not child.is_dragging and not child.drag_controlled and not child.is_throwing,
		"Folding during an independent drag ends the gesture without inertia")
	check(not child.is_processing_input() and not child.is_physics_processing(),
		"Folding an active drag disables callbacks")
	await frames(8)
	check(stage.history._undo_stack.size() == 1 and not stage.history.is_transaction_active(),
		"Folding commits the existing gesture exactly once")
	await stage.history.undo()
	await frames(8)
	child = entity_for_id(stage, child_id)
	check(child != null and child.global_position.is_equal_approx(before),
		"Undo restores a drag stopped by collapse")
	child.set_overview_physics_hidden(true)
	var offset := child.global_position - group.global_position
	var origin := group.global_position
	var session := stage.get_node("PhysicsSession")
	group._drag_target = origin + Vector2(180, 0)
	group.drag_controlled = true
	await frames(15)
	check(group.global_position.distance_to(origin) > 30,
		"Collapsed group root remains movable")
	check((child.global_position - group.global_position).is_equal_approx(offset),
		"Locked member accepts authoritative whole-group offset synchronization")
	session.end()
	child.set_overview_physics_hidden(false)
	check(stage.drag_entities().has(child) or not stage.selected_ids.has(child.id),
		"Expansion removes the runtime movement lock")
	stage.queue_free()
	await process_frame
	print("HIDDEN_GROUP_MOVEMENT_LOCK: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
