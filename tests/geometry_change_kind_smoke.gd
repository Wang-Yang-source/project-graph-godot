extends SceneTree

class Host extends Node2D:
	var is_loading := false
	var document_changes := 0
	var geometry_changes := 0
	var topology_changes := 0
	func mark_document_changed() -> void:
		document_changes += 1
	func mark_geometry_changed(_object: StageObject) -> void:
		geometry_changes += 1
	func mark_topology_changed() -> void:
		topology_changes += 1

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var host := Host.new()
	root.add_child(host)
	var object := StageObject.new()
	host.add_child(object)
	await process_frame
	var shape_before := object.shape_version
	var geometry_before := object.geometry_version
	var persistent_before := host.document_changes
	object.position += Vector2(25, -10)
	object._notification(Node2D.NOTIFICATION_TRANSFORM_CHANGED)
	check(object.geometry_version > geometry_before, "Translation invalidates world geometry")
	check(object.shape_version == shape_before, "Translation preserves local shape")
	check(host.document_changes > persistent_before, "Translation remains persistent")
	object.rotation = 0.25
	object._notification(Node2D.NOTIFICATION_TRANSFORM_CHANGED)
	check(object.shape_version > shape_before, "Rotation invalidates local shape consumers")
	shape_before = object.shape_version
	object.invalidate_geometry()
	check(object.shape_version == shape_before + 1, "Existing no-argument invalidation stays conservative")
	object.notify_topology_change()
	check(host.topology_changes == 1, "Topology notification reaches the stage")
	host.queue_free()
	await process_frame
	print("GEOMETRY_CHANGE_KIND: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
