extends RefCounted
## Call only from Godot MCP's editor script. Never changes saved project/presets.
static func build(destination: String) -> Error:
	var entry := Node.new()
	entry.set_script(preload("res://tests/performance_baseline_runner.gd"))
	var scene := PackedScene.new()
	var status := scene.pack(entry)
	entry.free()
	if status != OK:
		return status
	status = ResourceSaver.save(scene, "res://tests/performance_release_entry.res")
	if status != OK:
		return status
	var original = ProjectSettings.get_setting("application/run/main_scene")
	ProjectSettings.set_setting("application/run/main_scene", "res://tests/performance_release_entry.res")
	var platform := EditorExportPlatformLinuxBSD.new()
	var preset := platform.create_preset()
	status = platform.export_project(preset, false, destination)
	ProjectSettings.set_setting("application/run/main_scene", original)
	return status
