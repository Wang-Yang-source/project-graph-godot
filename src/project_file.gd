class_name ProjectFile

const LegacyImporter = preload("res://src/legacy_project_importer.gd")

const BinaryStore = preload("res://src/storage/project_binary_store.gd")
const Blob = preload("res://src/storage/project_blob.gd")
const FORMAT_VERSION := "4.0.0"
const METADATA_PATH := "metadata.json"
const STAGE_PATH := "stage.json"


static func save(path: String, snapshot: Dictionary, camera_state: Dictionary, previous_created_at: String = "", preserved_entries: Dictionary = {}, geometry: Dictionary = {}) -> Dictionary:
	return BinaryStore.save(path, snapshot, camera_state, previous_created_at, preserved_entries, geometry)


static func load(path: String) -> Dictionary:
	if BinaryStore.matches(path):
		return BinaryStore.load(path)
	return _load_zip(path)


static func prepare_graph_assets(graph: Dictionary) -> Dictionary:
	# Current eager stage needs every image; do raw I/O in the worker before replacement.
	for record in graph.get("objects", []):
		if not record is Dictionary or not record.get("properties") is Dictionary:
			return _failure("文档对象结构无效")
		for name in record.properties:
			var value: Variant = record.properties[name]
			if value is Blob:
				var loaded: Dictionary = value.read()
				if not loaded.ok:
					return loaded
				record.properties[name] = loaded.data
	return {"ok": true}


static func _load_zip(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var error := reader.open(path)
	if error != OK:
		return _failure("无法打开项目文件或文件不是有效的 ZIP: %s" % error_string(error))
	if not reader.file_exists(STAGE_PATH) and reader.file_exists("stage.msgpack"):
		var result: Dictionary = LegacyImporter.new().load_archive(reader)
		reader.close()
		return result
	if not reader.file_exists(METADATA_PATH) or not reader.file_exists(STAGE_PATH):
		reader.close()
		return _failure("项目文件必须包含 metadata.json 和 stage.json")

	var metadata_result := _read_json(reader, METADATA_PATH)
	var graph_result := _read_json(reader, STAGE_PATH)
	var preserved_entries := {}
	for name in reader.get_files():
		if name.begins_with("legacy/") and not name.ends_with("/"):
			preserved_entries[name] = Blob.new(path, {"archive_entry": name})
	reader.close()
	if not metadata_result.ok:
		return metadata_result
	if not graph_result.ok:
		return graph_result
	var metadata: Dictionary = metadata_result.data
	var graph: Dictionary = graph_result.data
	var version := str(metadata.get("version", ""))
	if not _is_supported_version(version):
		return _failure("不支持的项目文件版本: %s" % version)
	if not graph.get("objects") is Array:
		return _failure("stage.json 缺少 objects 数组")
	return {"ok": true, "metadata": metadata, "graph": graph, "preserved_entries": preserved_entries, "legacy": false}


static func _read_json(reader: ZIPReader, archive_path: String) -> Dictionary:
	var text := reader.read_file(archive_path).get_string_from_utf8()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		return _failure("%s 不是有效 JSON: %s" % [archive_path, json.get_error_message()])
	if not json.data is Dictionary:
		return _failure("%s 的根值必须是对象" % archive_path)
	return {"ok": true, "data": json.data}


static func _is_supported_version(version: String) -> bool:
	var parts := version.split(".")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	return int(parts[0]) == 3


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
