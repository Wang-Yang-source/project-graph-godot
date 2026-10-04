extends SceneTree
## Storage regressions only; run explicitly with an isolated user-data directory.
const Store = preload("res://src/storage/project_binary_store.gd")
const Document = preload("res://src/storage/project_document.gd")
const Blob = preload("res://src/storage/project_blob.gd")
var failures: Array[String] = []
var paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func fixture() -> Dictionary:
	return {"objects": [
		{"type": "text_node", "transform": {"position": [12.5, -48.0], "rotation": 0.3, "scale": [1.5, 0.75]},
			"properties": {"id": JSON.from_native("a"), "text": JSON.from_native("中文\n第二行"),
				"fill_color": JSON.from_native(Color(0.2, 0.4, 0.8, 0.3))}},
		{"type": "text_node", "transform": {"position": [500.0, 80.0]},
			"properties": {"id": JSON.from_native("b"), "text": JSON.from_native("B"), "container": {"$ref": "a"}}},
		{"type": "line_edge", "transform": {},
			"properties": {"id": JSON.from_native("edge"), "source": {"$ref": "a"}, "target": {"$ref": "b"},
				"source_uv": [1.0, 0.5], "target_uv": [0.0, 0.5]}}
	]}


func temporary(label: String) -> String:
	var path := "/tmp/pg-v4-" + label + "-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".prg"
	paths.append(path)
	return path


func _run() -> void:
	var graph := fixture()
	var path := temporary("roundtrip")
	var original := graph.duplicate(true)
	var legacy := {"legacy/original.bin": PackedByteArray([1, 2, 3, 4])}
	var geometry := {"layout_version": 1, "font_fingerprint": "fixture", "rects": {"a": Rect2(1, 2, 3, 4)}}
	var saved := ProjectFile.save(path, graph, {"position": [12.0, 40.0], "zoom": 0.5}, "", legacy, geometry)
	check(saved.ok and Store.matches(path), "Default saves are native v4, not ZIP")
	check(graph == original, "Saving never mutates caller records")
	var loaded := ProjectFile.load(path)
	check(loaded.ok, "Native document opens")
	if loaded.ok:
		check(loaded.metadata.version == "4.0.0" and loaded.document.objects.size() == 3, "Version and full record count survive")
		var first: Dictionary = loaded.document.objects[0]
		check(first.id == "a" and first.properties.text == "中文\n第二行", "Native strings and stable ID survive")
		check(first.properties.fill_color == Color(0.2, 0.4, 0.8, 0.3), "Color remains native")
		check(first.transform.position == Vector2(12.5, -48) and first.transform.scale == Vector2(1.5, 0.75), "Full transform survives")
		check(loaded.document.objects[2].references == {"source": "a", "target": "b"}, "References are separate stable IDs")
		check(loaded.graph.objects[2].properties.source_uv == [1.0, 0.5], "Vector properties retain scene adapter semantics")
		check(loaded.graph.get("_open_geometry", {}).get("rects") == geometry.rects, "Geometry cache survives")
		check(loaded.preserved_entries["legacy/original.bin"] is Blob, "Legacy payload stays lazy")
		var content: Dictionary = loaded.preserved_entries["legacy/original.bin"].read()
		check(content.ok and content.data == legacy["legacy/original.bin"], "Lazy payload is byte-identical")
		var old_hash := FileAccess.get_sha256(path)
		check(ProjectFile.save(path, graph, {}, loaded.metadata.created_at, loaded.preserved_entries).ok, "Same-path save copies lazy payload before replacing its source")
		check(FileAccess.get_sha256(path + ".previous") == old_hash, "Previous valid document is retained")
		var again := ProjectFile.load(path)
		if again.ok:
			check(again.preserved_entries["legacy/original.bin"].read().data == legacy["legacy/original.bin"], "Payload offsets are rebased after saving")
		else:
			check(false, "Replacement remains readable")
	_test_assets()
	_test_legacy_json(graph)
	_test_rejection(graph, path)
	for item in paths:
		DirAccess.remove_absolute(item)
		if FileAccess.file_exists(item + ".previous"):
			DirAccess.remove_absolute(item + ".previous")
	print("PROJECT_V4_STORAGE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)


func _test_assets() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var data := image.save_png_to_buffer()
	var graph := {"objects": []}
	for identifier in ["image-a", "image-b"]:
		graph.objects.append({"type": "legacy_asset", "transform": {},
			"properties": {"id": JSON.from_native(identifier), "image_base64": JSON.from_native(Marshalls.raw_to_base64(data)),
				"image_format": JSON.from_native("png"), "asset_size": [100.0, 80.0]}})
	var path := temporary("assets")
	check(ProjectFile.save(path, graph, {}).ok, "Legacy Base64 imports into v4 asset blocks")
	var loaded := ProjectFile.load(path)
	if not loaded.ok:
		check(false, "Image document opens")
		return
	var manifest := Store.read_manifest(path)
	var asset_count := 0
	for name in manifest.manifest.blocks:
		if name.begins_with("asset/"):
			asset_count += 1
	check(asset_count == 1, "Identical image data is deduplicated")
	check(not loaded.document.objects[0].properties.has("image_base64"), "No Base64 in native record properties")
	check(loaded.graph.objects[0].properties.image_bytes is Blob, "Opening the store does not read image bytes")
	check(ProjectFile.prepare_graph_assets(loaded.graph).ok, "Worker-side preparation resolves image data")
	check(loaded.graph.objects[0].properties.image_bytes == data, "Raw asset bytes round-trip")
	var records: Array[Dictionary] = []
	var object := StageObjectRegistry.instantiate_record(loaded.graph.objects[0], records)
	check(object is LegacyAsset and object.image_bytes == data, "Asset records restore through the shared registry")
	if object != null:
		object.free()


func _test_legacy_json(graph: Dictionary) -> void:
	var path := temporary("legacy")
	var archive := ZIPPacker.new()
	check(archive.open(path) == OK, "Old ZIP fixture opens")
	archive.start_file("metadata.json")
	archive.write_file(JSON.stringify({"version": "3.0.0"}).to_utf8_buffer())
	archive.close_file()
	archive.start_file("stage.json")
	archive.write_file(JSON.stringify(graph).to_utf8_buffer())
	archive.close_file()
	archive.close()
	var before := FileAccess.get_sha256(path)
	var loaded := ProjectFile.load(path)
	check(loaded.ok and loaded.graph.objects.size() == 3, "v3 remains readable")
	check(FileAccess.get_sha256(path) == before and not Store.matches(path), "Opening never migrates the source file")


func _test_rejection(graph: Dictionary, valid_path: String) -> void:
	var duplicate := graph.duplicate(true)
	duplicate.objects[1].properties.id = duplicate.objects[0].properties.id
	var path := temporary("invalid")
	check(not ProjectFile.save(path, duplicate, {}).ok and not FileAccess.file_exists(path), "Duplicate IDs fail before creating a file")
	var invalid := graph.duplicate(true)
	invalid.objects[2].properties.target = {"$ref": "missing"}
	check(not ProjectFile.save(path, invalid, {}).ok, "Dangling references are rejected")
	invalid = graph.duplicate(true)
	invalid.objects[0].properties.container = {"$ref": "b"}
	check(not ProjectFile.save(path, invalid, {}).ok, "Container cycles are rejected")
	var bytes := FileAccess.get_file_as_bytes(valid_path)
	var truncated := temporary("truncated")
	var file := FileAccess.open(truncated, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() - 3))
	file.close()
	check(not ProjectFile.load(truncated).ok, "Truncated directory fails")
	var corrupted := temporary("checksum")
	bytes[32] = bytes[32] ^ 1
	file = FileAccess.open(corrupted, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	check(not ProjectFile.load(corrupted).ok, "Damaged core block fails its checksum before decoding")
	var runtime := fixture()
	var resource := RefCounted.new()
	runtime.objects[0].properties["unsafe"] = resource
	check(not ProjectFile.save(path, runtime, {}).ok, "Runtime objects are rejected before native encoding")
	var native := {"schema": 1, "camera": {}, "objects": []}
	native["unsafe"] = resource
	check(not Document.safe_value(native), "Objects cannot enter the native document codec")
