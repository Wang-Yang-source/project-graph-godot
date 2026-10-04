extends RefCounted
## Runtime-only handle. File paths are never part of persisted document records.
var _path: String
var _entry: Dictionary
var _data := PackedByteArray()
var _loaded := false


func _init(path: String = "", entry: Dictionary = {}) -> void:
	_path = path
	_entry = entry.duplicate(true)


func read() -> Dictionary:
	if _loaded:
		return {"ok": true, "data": _data}
	if _entry.has("archive_entry"):
		var archive := ZIPReader.new()
		var error := archive.open(_path)
		if error != OK or not archive.file_exists(str(_entry.archive_entry)):
			archive.close()
			return {"ok": false, "error": "无法读取保留的旧档内容"}
		_data = archive.read_file(str(_entry.archive_entry))
		archive.close()
	else:
		var file := FileAccess.open(_path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "无法读取项目数据块"}
		var offset := int(_entry.get("offset", -1))
		var length := int(_entry.get("length", -1))
		if offset < 32 or length < 0 or length > 268435456 or offset > file.get_length() - length:
			file.close()
			return {"ok": false, "error": "项目数据块范围无效"}
		file.seek(offset)
		_data = file.get_buffer(length)
		file.close()
		if _data.size() != length or digest(_data) != str(_entry.get("sha256", "")):
			_data = PackedByteArray()
			return {"ok": false, "error": "项目数据块不完整或校验失败"}
	_loaded = true
	return {"ok": true, "data": _data}


static func digest(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
