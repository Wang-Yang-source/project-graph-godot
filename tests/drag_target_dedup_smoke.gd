extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var node := Entity.new()
	check(node._needs_drag_target_update(Vector2(100, 200)), "First pointer target must be applied")
	check(not node._needs_drag_target_update(Vector2(100, 200)), "Stationary pointer must skip repeated group updates")
	check(node._needs_drag_target_update(Vector2(101, 200)), "Pointer movement must be applied")
	check(node._needs_drag_target_update(Vector2(101, 200), 0), "Axis lock must update snapping even at a stationary pointer")
	check(not node._needs_drag_target_update(Vector2(101, 200), 0), "Repeated locked-axis target must be skipped")
	check(node._needs_drag_target_update(Vector2(101, 200)), "Releasing axis lock must refresh alignment")
	node._last_drag_update = Vector3.INF
	check(node._needs_drag_target_update(Vector2(101, 200)), "A new gesture at the same location must update")
	node.free()
	print("DRAG_TARGET_DEDUP: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
