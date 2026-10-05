extends SceneTree
const Codec = preload("res://src/storage/project_document.gd")

func _initialize() -> void:
	var failures := []
	for bytes in [PackedByteArray(), PackedByteArray([1, 2, 3, 4])]:
		var snapshot := {"objects": [{"type": "legacy_asset", "properties": {
			"id": JSON.from_native("image"), "image_base64": JSON.from_native(""),
			"image_bytes": bytes, "asset_size": [100.0, 50.0]},
			"transform": {"position": [10.0, 20.0], "rotation": 0.0, "scale": [1.0, 1.0]}}], "camera": {}}
		var encoded := Codec.from_snapshot(snapshot, {})
		if not encoded.ok:
			failures.append("Asset snapshot encodes")
			continue
		var record: Dictionary = encoded.document.objects[0]
		if record.properties.has("image_base64") or record.properties.has("image_bytes"):
			failures.append("Native records must keep image data in asset blocks")
		if Codec.to_snapshot(encoded.document, encoded.assets) != snapshot:
			failures.append("Runtime snapshot must preserve empty compatibility fields and image bytes")
	print("PROJECT_ASSET_SNAPSHOT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
