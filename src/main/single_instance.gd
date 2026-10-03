extends Node
## Reuse Godot's loopback TCP and PacketPeerStream framing; no external IPC dependency.
signal open_requested(paths: PackedStringArray)
signal forwarding_finished(ok: bool)

const TIMEOUT_MS := 5000
const MAX_CLIENTS := 16
var secondary := false
var pending: Array[PackedStringArray] = []
var _server := TCPServer.new()
var _clients: Array[Dictionary] = []
var _client: Dictionary = {}
var _token := ""
var _endpoint := "user://open-instance.json"
var _port := 0
var _paths := PackedStringArray()
var _deadline := 0
var _sent := false

static func document_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument.get_extension().to_lower() == "prg":
			var path := ProjectSettings.globalize_path(argument)
			if not path.is_absolute_path():
				path = OS.get_environment("PWD").path_join(path)
			paths.append(path.simplify_path())
	return paths

func start(paths: PackedStringArray) -> void:
	_paths = paths
	# Isolate desktop sessions and users without a global application port.
	var scope := OS.get_user_data_dir() + OS.get_environment("DISPLAY") + OS.get_environment("WAYLAND_DISPLAY")
	_port = 42000 + (scope.hash() & 0x7fffffff) % 10000
	_endpoint = "user://open-instance-" + scope.sha256_text().left(16) + ".json"
	if _server.listen(_port, "127.0.0.1") == OK:
		_token = Crypto.new().generate_random_bytes(32).hex_encode()
		var file := FileAccess.open(_endpoint, FileAccess.WRITE)
		if file == null:
			_server.stop()
			push_error("Cannot publish document-open endpoint")
			return
		file.store_string(JSON.stringify({"token": _token}))
		file.close()
		if OS.has_feature("Linux") or OS.has_feature("macOS"):
			FileAccess.set_unix_permissions(_endpoint, 384)
	else:
		secondary = true
		_deadline = Time.get_ticks_msec() + TIMEOUT_MS
		var tcp := StreamPeerTCP.new()
		tcp.connect_to_host("127.0.0.1", _port)
		_client = _connection(tcp)

func _connection(tcp: StreamPeerTCP) -> Dictionary:
	var packets := PacketPeerStream.new()
	packets.stream_peer = tcp
	packets.input_buffer_max_size = 1048576
	packets.output_buffer_max_size = 1048576
	return {"tcp": tcp, "packets": packets, "deadline": Time.get_ticks_msec() + TIMEOUT_MS}

func _process(_delta: float) -> void:
	if secondary:
		_poll_forward()
		return
	while _server.is_connection_available():
		var tcp := _server.take_connection()
		if _clients.size() >= MAX_CLIENTS:
			tcp.disconnect_from_host()
		else:
			_clients.append(_connection(tcp))
	for index in range(_clients.size() - 1, -1, -1):
		var connection := _clients[index]
		var tcp: StreamPeerTCP = connection.tcp
		var packets: PacketPeerStream = connection.packets
		tcp.poll()
		if packets.get_available_packet_count() > 0:
			var request: Variant = JSON.parse_string(packets.get_packet().get_string_from_utf8())
			if request is Dictionary and request.get("token", "") == _token and request.get("paths") is Array:
				var paths := PackedStringArray()
				for path in request.paths:
					if path is String and path.is_absolute_path() and path.get_extension().to_lower() == "prg":
						paths.append(path)
				pending.append(paths)
				open_requested.emit(paths)
				packets.put_packet("accepted".to_utf8_buffer())
			else:
				packets.put_packet("rejected".to_utf8_buffer())
			# Acknowledgement is queued before closing the socket.
			connection.deadline = Time.get_ticks_msec() + 100
		if tcp.get_status() in [StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR] or Time.get_ticks_msec() > int(connection.deadline):
			tcp.disconnect_from_host()
			_clients.remove_at(index)

func _poll_forward() -> void:
	if _client.is_empty():
		return
	var tcp: StreamPeerTCP = _client.tcp
	var packets: PacketPeerStream = _client.packets
	tcp.poll()
	if not _sent and tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED and FileAccess.file_exists(_endpoint):
		var endpoint: Variant = JSON.parse_string(FileAccess.get_file_as_string(_endpoint))
		if endpoint is Dictionary and endpoint.get("token", "") != "":
			_sent = packets.put_packet(JSON.stringify({"token": endpoint.token, "paths": Array(_paths)}).to_utf8_buffer()) == OK
	if packets.get_available_packet_count() > 0:
		_finish_forward(packets.get_packet().get_string_from_utf8() == "accepted")
	elif Time.get_ticks_msec() > _deadline or tcp.get_status() in [StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR]:
		_finish_forward(false)

func _finish_forward(ok: bool) -> void:
	_client.tcp.disconnect_from_host()
	_client.clear()
	set_process(false)
	forwarding_finished.emit(ok)

func _exit_tree() -> void:
	for connection in _clients:
		connection.tcp.disconnect_from_host()
	_clients.clear()
	if not _client.is_empty():
		_client.tcp.disconnect_from_host()
		_client.clear()
	if _server.is_listening():
		_server.stop()
		DirAccess.remove_absolute(_endpoint)
