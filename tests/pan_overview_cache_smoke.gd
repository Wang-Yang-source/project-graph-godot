extends SceneTree

class MeasuredOverview extends "res://src/group_overview.gd":
	var summary_updates := 0

	func _update_summary(group: TextNode, panel: Panel) -> void:
		summary_updates += 1
		super._update_summary(group, panel)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 6:
		await process_frame

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-hex="):
			path = argument.trim_prefix("--fixture-hex=").hex_decode().get_string_from_utf8()
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("Pass --fixture-hex= followed by an existing UTF-8 hexadecimal document path")
		quit(2)
		return
	var hash_before := FileAccess.get_sha256(path)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	stage.get_node("GroupOverview").set_script(MeasuredOverview)
	view.add_child(stage)
	check(await stage.load_from_file(path), "Fixture loads")
	var bounds := Rect2()
	var first := true
	for object in stage.stage_objects():
		if object is Entity:
			bounds = object.aabb if first else bounds.merge(object.aabb)
			first = false
	stage.camera.position = bounds.get_center()
	stage.camera.target_position = stage.camera.position
	stage.camera.zoom = Vector2.ONE * .035
	stage.camera.target_zoom = stage.camera.zoom
	await settle()
	var overview = stage.group_overview
	check(not overview._summaries.is_empty(), "Fixture exercises previews")
	var membership: Dictionary = overview._active.duplicate()
	var updates: int = overview.summary_updates
	for frame in 20:
		stage.camera.position += Vector2(1, 1)
		stage.camera.target_position = stage.camera.position
		await process_frame
	check(overview.summary_updates - updates < overview._summaries.size(), "Pure pan only initializes newly visible summaries")
	check(overview._active == membership, "Pure pan preserves membership")
	stage.camera.position += Vector2(1000000, 1000000)
	stage.camera.target_position = stage.camera.position
	await settle()
	for panel in overview._summaries.values():
		check(not panel.visible, "Offscreen summaries are culled")
	stage.camera.position = bounds.get_center()
	stage.camera.target_position = stage.camera.position
	await settle()
	var visible := false
	for panel in overview._summaries.values():
		visible = visible or panel.visible
	check(visible, "Returning to the graph restores summaries")
	check(FileAccess.get_sha256(path) == hash_before, "Fixture stays unchanged")
	view.queue_free()
	await process_frame
	print("PAN_OVERVIEW_CACHE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
