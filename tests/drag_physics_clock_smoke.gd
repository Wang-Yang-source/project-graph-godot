extends SceneTree
var failures: Array[String] = []
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
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	var driver: Entity = stage.create_text_node("Driver", Vector2.ZERO, false)
	var passive: Entity = stage.create_text_node("Contact", Vector2(220, 0), false)
	driver.fixed_width = 160
	passive.fixed_width = 160
	await frames(8)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = stage.get_canvas_transform() * driver.global_position
	driver._on_input_event(stage.get_viewport(), press, 0)
	driver.set_physics_process(false)
	var origin := driver.global_position
	for i in 50:
		driver._update_drag_target(origin + Vector2(4.0 * (i + 1), 0))
	check(driver.global_position == origin, "Input queues a target without teleporting the physics body")
	check(not driver.freeze, "Dragged body stays in native dynamic contact simulation")
	var previous := driver.global_position.x
	var passive_origin := passive.global_position.x
	var backward := 0.0
	for i in 90:
		await frames(1)
		backward = maxf(backward, previous - driver.global_position.x)
		previous = driver.global_position.x
	check(backward < 0.5, "A stationary pointer target does not reverse the dragged body at contact")
	check(driver.global_position.x > origin.x + 150.0, "Native integration catches up to the pointer")
	check(passive.global_position.x > passive_origin + 10.0, "Native contact pushes the neighbour")
	driver.finish_drag(false, driver.global_position)
	await frames(20)
	stage.queue_free()
	await process_frame
	print("DRAG_PHYSICS_CLOCK: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
