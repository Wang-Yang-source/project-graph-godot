extends SceneTree
## Local migration runner. Originals are copied before any replacement.
const Document = preload("res://src/storage/project_document.gd")
var app
var stage: Stage
var reports: Array = []
var failures: Array[String] = []
var backup_folder := ""
var result_path := "/tmp/pg-v4-migration-result.json"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error(message)
	return ok

func timed_load(path: String) -> Dictionary:
	var hash_before := FileAccess.get_sha256(path)
	var started := Time.get_ticks_usec()
	var ok := await stage.load_from_file(path)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	var loaded := ProjectFile.load(path)
	var valid: bool = ok and loaded.ok and not stage.is_loading and not stage.history._busy and not stage.is_dirty()
	valid = valid and stage.stage_objects().size() == loaded.get("graph", {}).get("objects", []).size()
	for object in stage.stage_objects():
		if object is LineEdge:
			valid = valid and is_instance_valid(object.source) and is_instance_valid(object.target)
	valid = valid and FileAccess.get_sha256(path) == hash_before
	check(valid, "Load invariants: " + path)
	return {"ms":elapsed, "valid":valid, "objects":stage.stage_objects().size()}

func write_report() -> void:
	var report := {"backup_folder":backup_folder, "documents":reports, "failures":failures,
		"display":DisplayServer.get_name(), "renderer":RenderingServer.get_current_rendering_method(),
		"engine":Engine.get_version_info().string, "complete":false}
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("physics", false, false)
	root.size = Vector2i(1280, 800)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	for i in 10:
		await process_frame
	stage = app.tabs.get_current_stage()
	var folder := OS.get_environment("PG_MIGRATE_FOLDER")
	if folder.is_empty():
		push_error("Set PG_MIGRATE_FOLDER explicitly; migration replaces files and preserves originals")
		quit(2)
		return
	backup_folder = folder.path_join("prg-original-backup-" + str(Time.get_unix_time_from_system()).replace(".", "-"))
	if not check(DirAccess.make_dir_recursive_absolute(backup_folder) == OK, "Create backup directory"):
		quit(1)
		return
	var candidates: Array = []
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with(".prg"):
			continue
		var path: String = folder.path_join(name)
		var loaded := ProjectFile.load(path)
		if not check(loaded.ok, "Read source " + name):
			continue
		if int(loaded.get("format", 3)) == 4:
			continue
		var backup: String = backup_folder.path_join(name)
		if not check(DirAccess.copy_absolute(path, backup) == OK and FileAccess.get_sha256(path) == FileAccess.get_sha256(backup), "Copy exact original " + name):
			continue
		candidates.append({"path":path, "backup":backup})
	for candidate in candidates:
		var path: String = candidate.path
		var source := ProjectFile.load(path)
		var expected := Document.from_snapshot(source.graph, source.graph.get("camera", {}))
		if not check(expected.ok, "Normalize source " + path):
			continue
		var report := {"file":path, "original":candidate.backup, "original_sha256":FileAccess.get_sha256(path)}
		reports.append(report)
		report["old_load"] = await timed_load(path)
		if not report.old_load.valid:
			write_report()
			continue
		var rects := {}
		for object in stage.stage_objects():
			if not object is LineEdge:
				rects[object.id] = object.aabb
		var geometry := {"layout_version":1, "font_fingerprint":CanvasTextMetrics.fingerprint(), "rects":rects}
		var saved := ProjectFile.save(path, source.graph, source.graph.get("camera", {}), str(source.metadata.get("created_at", "")), source.get("preserved_entries", {}), geometry)
		if not check(saved.ok, "Migrate " + path + ": " + str(saved.get("error", ""))):
			write_report()
			continue
		var migrated := ProjectFile.load(path)
		var identical: bool = migrated.ok and migrated.get("format") == 4 and migrated.document == expected.document
		identical = identical and FileAccess.get_sha256(candidate.backup) == report.original_sha256
		identical = identical and FileAccess.get_sha256(path + ".previous") == report.original_sha256
		for identifier in expected.assets:
			if not migrated.ok or not migrated.document.objects is Array:
				identical = false
				break
			var block_name: String = "asset/" + identifier
			var directory = ProjectFile.BinaryStore.read_manifest(path)
			if not directory.ok or not directory.manifest.blocks.has(block_name):
				identical = false
				break
			var actual = ProjectFile.Blob.new(path, directory.manifest.blocks[block_name]).read()
			identical = identical and actual.ok and actual.data == expected.assets[identifier]
		for name in source.get("preserved_entries", {}):
			var original: Variant = source.preserved_entries[name]
			if original is ProjectFile.Blob:
				# Handles refer to the pre-migration offsets, now available in the backup.
				original = ProjectFile.Blob.new(candidate.backup, {"archive_entry":name}).read().data
			var actual = migrated.preserved_entries[name].read()
			identical = identical and actual.ok and actual.data == original
		report["content_identical"] = check(identical, "Native document/assets/legacy equality " + path)
		report["v4_sha256"] = FileAccess.get_sha256(path)
		report["v4_loads"] = []
		for repeat in 3:
			report.v4_loads.append(await timed_load(path))
		print("MIGRATED: ", JSON.stringify(report))
		write_report()
	write_report()
	var file := FileAccess.open(result_path, FileAccess.READ)
	var final_report: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	final_report.complete = true
	FileAccess.open(result_path, FileAccess.WRITE).store_string(JSON.stringify(final_report, "\t"))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
