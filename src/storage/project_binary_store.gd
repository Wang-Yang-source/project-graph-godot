extends RefCounted
## Uncompressed, indexed PRG v4. The only value codec is Godot's native Variant codec.
const Document = preload("res://src/storage/project_document.gd")
const Blob = preload("res://src/storage/project_blob.gd")
const MAGIC := "PGDOC4\r\n"
const VERSION := 4
const HEADER_SIZE := 32
const MAX_MANIFEST := 4 * 1024 * 1024
const MAX_CORE := 128 * 1024 * 1024
const MAX_BLOB := 256 * 1024 * 1024
const MAX_FILE := 4 * 1024 * 1024 * 1024


static func matches(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var matched := file.get_buffer(8) == MAGIC.to_utf8_buffer()
	file.close()
	return matched


static func save(path: String, snapshot: Dictionary, camera: Dictionary,
		created_at: String, preserved: Dictionary, geometry: Dictionary = {}) -> Dictionary:
	var prepared := Document.from_snapshot(snapshot, camera)
	if not prepared.ok:
		return prepared
	if not Document.safe_value(geometry):
		return Document.failure("几何缓存包含运行时对象")
	var document: Dictionary = prepared.document
	var now := Time.get_datetime_string_from_system(true)
	var metadata := {"version": "4.0.0", "created_at": created_at if not created_at.is_empty() else now,
		"modified_at": now, "object_count": document.objects.size()}
	var suffix := Crypto.new().generate_random_bytes(8).hex_encode()
	var temporary := path + "." + suffix + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return Document.failure("无法创建临时项目文件: " + error_string(FileAccess.get_open_error()))
	var header_written := file.store_buffer(_header(0, 0))
	var blocks := {}
	var error := ""
	if header_written:
		error = _write_block(file, blocks, "records", var_to_bytes(document), "variant", MAX_CORE)
	else:
		error = "无法写入项目文件头"
	if error.is_empty() and not geometry.is_empty():
		var cache := geometry.duplicate(true)
		cache["records_sha256"] = blocks.records.sha256
		error = _write_block(file, blocks, "geometry", var_to_bytes(cache), "variant", MAX_CORE)
	if error.is_empty():
		var preview := JSON.stringify(Document.preview_graph(document)).to_utf8_buffer()
		error = _write_block(file, blocks, "preview", preview, "json", MAX_CORE)
	for identifier in prepared.assets:
		if not error.is_empty():
			break
		var value: Variant = prepared.assets[identifier]
		if value is Blob:
			var result: Dictionary = value.read()
			if not result.ok:
				error = result.error
				break
			value = result.data
		if not value is PackedByteArray or Blob.digest(value) != identifier:
			error = "资产内容与 ID 不一致"
			break
		error = _write_block(file, blocks, "asset/" + identifier, value, "raw", MAX_BLOB)
	for name in preserved:
		if not error.is_empty():
			break
		if not str(name).begins_with("legacy/"):
			error = "不支持的保留数据名称"
			break
		var value: Variant = preserved[name]
		if value is Blob:
			var result: Dictionary = value.read()
			if not result.ok:
				error = result.error
				break
			value = result.data
		if not value is PackedByteArray:
			error = "保留数据类型无效"
			break
		error = _write_block(file, blocks, str(name), value, "raw", MAX_BLOB)
	var manifest := {"version": VERSION, "codec": "godot-variant-4", "real_bits": _real_bits(),
		"metadata": metadata, "blocks": blocks}
	var bytes := JSON.stringify(manifest).to_utf8_buffer()
	var manifest_offset := file.get_position()
	if error.is_empty() and (bytes.size() > MAX_MANIFEST or manifest_offset + bytes.size() > MAX_FILE):
		error = "项目目录或文件过大"
	if error.is_empty():
		if not file.store_buffer(bytes):
			error = "无法写入项目目录"
		file.seek(0)
		if not file.store_buffer(_header(bytes.size(), manifest_offset)):
			error = "无法完成项目文件头"
		file.flush()
		if file.get_error() != OK:
			error = "项目写入失败: " + error_string(file.get_error())
	file.close()
	# Closing/flush may not report buffered failures on every backend; reread before replacing.
	if error.is_empty():
		var checked := read_manifest(temporary)
		if not checked.ok:
			error = checked.error
		else:
			var core := _read_block(temporary, checked.manifest.blocks.records, MAX_CORE)
			if not core.ok:
				error = core.error
	if not error.is_empty():
		DirAccess.remove_absolute(temporary)
		return Document.failure(error)
	var replaced := _replace_file(temporary, path)
	if not replaced.ok:
		return replaced
	var preserved_refs := {}
	for name in blocks:
		if str(name).begins_with("legacy/"):
			preserved_refs[name] = Blob.new(path, blocks[name])
	return {"ok": true, "created_at": metadata.created_at, "version": "4.0.0",
		"preserved_entries": preserved_refs}


static func load(path: String) -> Dictionary:
	var opened := read_manifest(path)
	if not opened.ok:
		return opened
	var manifest: Dictionary = opened.manifest
	var blocks: Dictionary = manifest.blocks
	if not blocks.has("records") or blocks.records.kind != "variant":
		return Document.failure("项目缺少二进制记录块")
	var core := _read_block(path, blocks.records, MAX_CORE)
	if not core.ok:
		return core
	var value: Variant = bytes_to_var(core.data)
	if not value is Dictionary:
		return Document.failure("项目记录块无法解码")
	var assets := {}
	var preserved := {}
	for name in blocks:
		if name.begins_with("asset/"):
			if blocks[name].kind != "raw":
				return Document.failure("资产块类型无效")
			assets[name.trim_prefix("asset/")] = Blob.new(path, blocks[name])
		elif name.begins_with("legacy/"):
			if blocks[name].kind != "raw":
				return Document.failure("旧档块类型无效")
			preserved[name] = Blob.new(path, blocks[name])
	var checked := Document.validate(value, assets.keys())
	if not checked.ok:
		return checked
	if manifest.metadata.get("object_count") != value.objects.size():
		return Document.failure("对象数量与目录不一致")
	var graph := Document.to_snapshot(value, assets)
	# Derived geometry may be discarded; failure never invalidates the document.
	if blocks.has("geometry") and blocks.geometry.kind == "variant":
		var cached := _read_block(path, blocks.geometry, MAX_CORE)
		if cached.ok:
			var decoded: Variant = bytes_to_var(cached.data)
			if decoded is Dictionary and Document.safe_value(decoded) and decoded.get("records_sha256") == blocks.records.sha256:
				graph["_open_geometry"] = decoded
	return {"ok": true, "metadata": manifest.metadata, "graph": graph,
		"document": value, "preserved_entries": preserved, "legacy": false, "format": VERSION}


static func read_manifest(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Document.failure("无法打开项目文件")
	var size := file.get_length()
	var header := file.get_buffer(HEADER_SIZE)
	if size < HEADER_SIZE or size > MAX_FILE or header.size() != HEADER_SIZE:
		file.close()
		return Document.failure("项目文件头不完整")
	if header.slice(0, 8) != MAGIC.to_utf8_buffer() or header.decode_u32(8) != VERSION or header.decode_u64(24) != 0:
		file.close()
		return Document.failure("不支持的项目文件头")
	var length := int(header.decode_u32(12))
	var offset := int(header.decode_u64(16))
	if length <= 0 or length > MAX_MANIFEST or offset < HEADER_SIZE or offset != size - length:
		file.close()
		return Document.failure("项目目录范围无效")
	file.seek(offset)
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return Document.failure("项目目录被截断")
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return Document.failure("项目目录不是有效 JSON")
	var manifest: Dictionary = json.data
	if manifest.get("version") != VERSION or manifest.get("codec") != "godot-variant-4" or manifest.get("real_bits") != _real_bits():
		return Document.failure("项目版本或原生数值精度不兼容")
	if not manifest.get("metadata") is Dictionary or not manifest.get("blocks") is Dictionary or manifest.blocks.size() > 200000:
		return Document.failure("项目目录结构无效")
	if manifest.metadata.get("version") != "4.0.0":
		return Document.failure("项目元数据版本不一致")
	var spans := []
	for name in manifest.blocks:
		var entry: Variant = manifest.blocks[name]
		if not entry is Dictionary or not _whole(entry.get("offset")) or not _whole(entry.get("length")):
			return Document.failure("项目数据块目录无效")
		var start := int(entry.offset)
		var count := int(entry.length)
		if start < HEADER_SIZE or count < 0 or count > MAX_BLOB or start > offset - count:
			return Document.failure("项目数据块超出文件范围")
		if entry.get("kind") not in ["variant", "raw", "json"] or not entry.get("sha256") is String or entry.sha256.length() != 64 or not entry.sha256.is_valid_hex_number(false):
			return Document.failure("项目数据块校验信息无效")
		spans.append([start, start + count])
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var end := HEADER_SIZE
	for span in spans:
		if span[0] < end:
			return Document.failure("项目数据块互相重叠")
		end = span[1]
	return {"ok": true, "manifest": manifest}


static func _write_block(file: FileAccess, blocks: Dictionary, name: String,
		bytes: PackedByteArray, kind: String, limit: int) -> String:
	if bytes.size() > limit:
		return "项目数据块过大: " + name
	blocks[name] = {"offset": file.get_position(), "length": bytes.size(), "kind": kind, "sha256": Blob.digest(bytes)}
	var written := file.store_buffer(bytes)
	return "" if written and file.get_error() == OK else "无法写入项目数据块: " + name


static func _read_block(path: String, entry: Dictionary, limit: int) -> Dictionary:
	if int(entry.length) > limit:
		return Document.failure("项目数据块超过读取限制")
	return Blob.new(path, entry).read()


static func _header(length: int, offset: int) -> PackedByteArray:
	var header := MAGIC.to_utf8_buffer()
	header.resize(HEADER_SIZE)
	header.encode_u32(8, VERSION)
	header.encode_u32(12, length)
	header.encode_u64(16, offset)
	header.encode_u64(24, 0)
	return header


static func _real_bits() -> int:
	return 32 if var_to_bytes(Vector2.ZERO).size() == 12 else 64


static func _whole(value: Variant) -> bool:
	return Document.numeric(value) and float(value) == floorf(float(value))


static func _replace_file(temporary: String, path: String) -> Dictionary:
	# Keep the original only during replacement, then remove the rollback file.
	# This does not guarantee recovery after power loss.
	var backup := path + ".previous"
	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		if FileAccess.file_exists(backup):
			var removed := DirAccess.remove_absolute(backup)
			if removed != OK:
				DirAccess.remove_absolute(temporary)
				return Document.failure("无法更新项目恢复副本")
		var moved := DirAccess.rename_absolute(path, backup)
		if moved != OK:
			DirAccess.remove_absolute(temporary)
			return Document.failure("无法保留原项目文件: " + error_string(moved))
	var error := DirAccess.rename_absolute(temporary, path)
	if error != OK:
		if had_previous:
			var restored := DirAccess.rename_absolute(backup, path)
			if restored != OK:
				return Document.failure("替换失败；原文件仍在 " + backup + "，新文件在 " + temporary)
		DirAccess.remove_absolute(temporary)
		return Document.failure("无法替换项目文件: " + error_string(error))
	if had_previous:
		var removed := DirAccess.remove_absolute(backup)
		if removed != OK:
			# The new document is already installed; do not report a failed save.
			push_warning("项目已保存，但无法清理临时恢复副本: " + backup + ": " + error_string(removed))
	return {"ok": true}
