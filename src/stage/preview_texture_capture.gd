extends RefCounted
## Native readback plus off-thread mipmap generation. No scene access off thread.

static func capture(view: SubViewport, completed: Callable) -> void:
	var texture := view.get_texture()
	var size := view.size
	RenderingServer.call_on_render_thread(_request.bind(texture, size, completed))


static func _request(texture: Texture2D, size: Vector2i, completed: Callable) -> void:
	if not completed.is_valid():
		return
	var device := RenderingServer.get_rendering_device()
	if device == null:
		_prepare(texture.get_image(), completed)
		return
	var rid := RenderingServer.texture_get_rd_texture(texture.get_rid())
	if not rid.is_valid() or not device.texture_is_valid(rid):
		_prepare(texture.get_image(), completed)
		return
	var format := device.texture_get_format(rid)
	if format.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM and format.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB:
		_prepare(texture.get_image(), completed)
		return
	var callback := func(bytes: PackedByteArray) -> void:
		var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
		_prepare(image, completed)
	var result := device.texture_get_data_async(rid, 0, callback)
	if result != OK:
		_prepare(texture.get_image(), completed)


static func _prepare(image: Image, completed: Callable) -> void:
	if image == null or image.is_empty():
		if completed.is_valid():
			completed.call_deferred(image)
		return
	WorkerThreadPool.add_task(func() -> void:
		image.generate_mipmaps()
		if completed.is_valid():
			completed.call_deferred(image)
	, false, "Group preview mipmaps")
