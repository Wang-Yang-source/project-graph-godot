extends RefCounted
## Native PRG v4 records; the snapshot adapter keeps existing history compatible.
const SCHEMA := 1
const MAX_OBJECTS := 100000
const TYPES := ["text_node", "line_edge", "legacy_asset", "pen_stroke", "venn_region"]
const ENTITY_TYPES := ["text_node", "legacy_asset", "pen_stroke"]
const Blob = preload("res://src/storage/project_blob.gd")


static func from_snapshot(snapshot: Dictionary, camera: Dictionary) -> Dictionary:
	if not snapshot.get("objects") is Array:
		return failure("文档缺少对象数组")
	var records := []
	var assets := {}
	for source in snapshot.objects:
		if not source is Dictionary or not source.get("properties") is Dictionary or not source.get("transform", {}) is Dictionary:
			return failure("文档对象结构无效")
		var properties := {}
		var references := {}
		var asset_refs := {}
		for name in source.properties:
			var value: Variant = source.properties[name]
			if value is Blob:
				var loaded: Dictionary = value.read()
				if not loaded.ok:
					return loaded
				value = loaded.data
			if not safe_value(value):
				return failure("对象属性包含运行时对象或无效数值")
			if value is Dictionary and value.has("$ref"):
				if not value["$ref"] is String:
					return failure("引用 ID 必须是字符串")
				references[str(name)] = value["$ref"]
			elif name in ["source_uv", "target_uv", "asset_size"]:
				var point: Variant = vector(value)
				if point == null:
					return failure("对象向量属性无效")
				properties[str(name)] = point
			else:
				properties[str(name)] = value if value is PackedByteArray else JSON.to_native(value)
		var stored_id: Variant = properties.get("id", "")
		if not stored_id is String:
			return failure("对象 ID 必须是字符串")
		var identifier: String = stored_id
		properties.erase("id")
		if str(source.get("type", "")) == "legacy_asset":
			var data: Variant = properties.get("image_bytes", PackedByteArray())
			if not data is PackedByteArray:
				return failure("图片字节类型无效")
			if data.is_empty() and not str(properties.get("image_base64", "")).is_empty():
				data = Marshalls.base64_to_raw(str(properties.image_base64))
				if data.is_empty():
					return failure("旧图片编码无效")
			properties.erase("image_base64")
			properties.erase("image_bytes")
			if not data.is_empty():
				var asset_id := Blob.digest(data)
				assets[asset_id] = data
				asset_refs["image_bytes"] = asset_id
		var transform: Dictionary = source.get("transform", {})
		var position: Variant = vector(transform.get("position", [0.0, 0.0]))
		var scale: Variant = vector(transform.get("scale", [1.0, 1.0]))
		if position == null or scale == null:
			return failure("对象坐标或缩放无效")
		records.append({"id": identifier, "type": str(source.get("type", "")),
			"transform": {"position": position, "rotation": transform.get("rotation", 0.0), "scale": scale},
			"properties": properties, "references": references, "assets": asset_refs})
	var document := {"schema": SCHEMA, "objects": records, "camera": camera.duplicate(true)}
	var checked := validate(document, assets.keys())
	return {"ok": true, "document": document, "assets": assets} if checked.ok else checked


static func validate(document: Dictionary, asset_ids: Array) -> Dictionary:
	if document.get("schema") != SCHEMA or not document.get("objects") is Array or not document.get("camera", {}) is Dictionary:
		return failure("不支持的文档数据结构")
	if document.objects.size() > MAX_OBJECTS or not safe_value(document):
		return failure("文档数据类型、深度或数量无效")
	for key in document:
		if key not in ["schema", "objects", "camera"]:
			return failure("不支持的文档字段: " + str(key))
	var records := {}
	var parents := {}
	for record in document.objects:
		if not record is Dictionary:
			return failure("文档记录必须是对象")
		var identifier: Variant = record.get("id")
		if not identifier is String or identifier.is_empty() or records.has(identifier):
			return failure("文档对象 ID 为空或重复")
		if not TYPES.has(record.get("type")):
			return failure("不支持的对象类型: " + str(record.get("type")))
		for name in ["properties", "references", "assets", "transform"]:
			if not record.get(name) is Dictionary:
				return failure("对象字段结构无效: " + name)
		for key in record:
			if key not in ["id", "type", "transform", "properties", "references", "assets"]:
				return failure("不支持的对象记录字段: " + str(key))
		if record.properties.has("id"):
			return failure("对象 ID 只能定义在记录顶层")
		for name in record.references:
			if record.properties.has(name) or record.assets.has(name):
				return failure("对象属性和引用字段重复")
		for name in record.assets:
			if record.properties.has(name):
				return failure("对象属性和资产字段重复")
		var transform: Dictionary = record.transform
		if not transform.get("position") is Vector2 or not transform.get("scale") is Vector2:
			return failure("对象变换类型无效")
		if not transform.position.is_finite() or not transform.scale.is_finite() or not numeric(transform.get("rotation")):
			return failure("对象变换数值无效")
		for property in record.assets:
			if record.type != "legacy_asset" or property != "image_bytes" or not asset_ids.has(record.assets[property]):
				return failure("对象资产引用无效")
		records[identifier] = record
	for record in document.objects:
		for property in record.references:
			var target: Variant = record.references[property]
			if not target is String or not records.has(target) or not ENTITY_TYPES.has(records[target].type):
				return failure("对象引用缺失或目标类型无效")
			if property == "container":
				parents[record.id] = target
			elif property == "topic_parent":
				if records[target].type != "text_node":
					return failure("主题父节点类型无效")
			elif property not in ["source", "target"]:
				return failure("不支持的对象引用字段: " + str(property))
		if record.type == "line_edge" and (not record.references.has("source") or not record.references.has("target")):
			return failure("连线缺少端点")
		if record.type == "venn_region":
			var members: Variant = record.properties.get("member_ids", PackedStringArray())
			if not members is PackedStringArray and not members is Array:
				return failure("集合成员类型无效")
			for identifier in members:
				if not records.has(identifier) or not ENTITY_TYPES.has(records[identifier].type):
					return failure("集合成员引用无效")
	var finished := {}
	for identifier in parents:
		var chain := {}
		var cursor: String = identifier
		while parents.has(cursor) and not finished.has(cursor):
			if chain.has(cursor):
				return failure("分组包含循环引用")
			chain[cursor] = true
			cursor = parents[cursor]
		for visited in chain:
			finished[visited] = true
	return {"ok": true}


static func to_snapshot(document: Dictionary, assets: Dictionary) -> Dictionary:
	var objects := []
	for record in document.objects:
		var properties := {"id": JSON.from_native(record.id)}
		if record.type == "legacy_asset":
			# Runtime compatibility fields stay out of native records and asset blocks.
			properties["image_base64"] = JSON.from_native("")
			properties["image_bytes"] = PackedByteArray()
		for name in record.properties:
			var value: Variant = record.properties[name]
			if value is Vector2:
				properties[name] = [value.x, value.y]
			else:
				properties[name] = value if value is PackedByteArray else JSON.from_native(value)
		for name in record.references:
			properties[name] = {"$ref": record.references[name]}
		for name in record.assets:
			if assets.has(record.assets[name]):
				properties[name] = assets[record.assets[name]]
			else:
				properties["preview_attachment"] = record.assets[name]
		var transform: Dictionary = record.transform
		objects.append({"type": record.type, "properties": properties,
			"transform": {"position": [transform.position.x, transform.position.y],
				"rotation": transform.rotation, "scale": [transform.scale.x, transform.scale.y]}})
	return {"objects": objects, "camera": document.camera.duplicate(true)}


static func preview_graph(document: Dictionary) -> Dictionary:
	# Bounded display projection; original text/geometry remains in records.
	var projection := {"schema": SCHEMA, "camera": {}, "objects": []}
	var names := ["text", "font_size", "fixed_width", "fill_color", "text_color",
		"border_color", "use_theme_border", "stroke_color", "stroke_width", "show_arrow",
		"use_theme_color", "source_uv", "target_uv", "asset_size", "image_format", "points"]
	for record in document.objects:
		if projection.objects.size() >= 5000:
			break
		var properties := {}
		for name in names:
			if not record.properties.has(name):
				continue
			var value: Variant = record.properties[name]
			if name == "text":
				value = str(value).left(512)
			elif name == "points" and value is PackedVector2Array:
				value = value.slice(0, 2000)
			properties[name] = value
		projection.objects.append({"id": record.id, "type": record.type,
			"transform": record.transform, "properties": properties,
			"references": record.references, "assets": record.assets})
	var graph := to_snapshot(projection, {})
	for index in graph.objects.size():
		var record: Dictionary = projection.objects[index]
		if record.type == "legacy_asset":
			var projected: Dictionary = graph.objects[index]
			projected.type = "text_node"
			var size: Vector2 = record.properties.get("asset_size", Vector2(100, 100))
			var position: Vector2 = record.transform.position
			projected.properties["preview_rect"] = [position.x, position.y, size.x, size.y]
			projected.properties["text"] = ""
			projected.properties["font_size"] = 24
	return graph


static func vector(value: Variant) -> Variant:
	if value is Vector2:
		return value if value.is_finite() else null
	if value is Array and value.size() == 2 and numeric(value[0]) and numeric(value[1]):
		return Vector2(float(value[0]), float(value[1]))
	return null


static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func safe_value(value: Variant, depth: int = 0) -> bool:
	if depth > 64 or value is Object or value is Callable or value is Signal or value is RID:
		return false
	if value is Dictionary:
		for key in value:
			if not key is String and not key is StringName:
				return false
			if not safe_value(value[key], depth + 1):
				return false
	elif value is Array:
		for item in value:
			if not safe_value(item, depth + 1):
				return false
	elif value is float:
		return is_finite(value)
	return true


static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
