extends SceneTree
const Instance = preload("res://src/main/single_instance.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func wait_until(condition: Callable, timeout_ms: int = 7000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _run() -> void:
	create_timer(25.0).timeout.connect(func(): quit(1))
	var owner := Instance.new()
	root.add_child(owner)
	owner.start(PackedStringArray())
	check(not owner.secondary and owner._server.is_listening(), "Owner binds only loopback")
	var results: Array[bool] = []
	var second := Instance.new()
	root.add_child(second)
	second.forwarding_finished.connect(func(ok): results.append(ok))
	var paths := PackedStringArray(["/tmp/中文 空格.prg", "/tmp/second.prg"])
	second.start(paths)
	await wait_until(func(): return not results.is_empty())
	check(results == [true], "Transfer is acknowledged")
	check(owner.pending.size() == 1 and owner.pending[0] == paths, "UTF-8 paths retain packet boundaries")
	second.free()
	await wait_until(func(): return owner._clients.is_empty())
	check(owner._clients.is_empty(), "Completed connection is disposed")
	var rejected := StreamPeerTCP.new()
	rejected.connect_to_host("127.0.0.1", owner._port)
	await wait_until(func():
		rejected.poll()
		return rejected.get_status() == StreamPeerTCP.STATUS_CONNECTED
	)
	var packets := PacketPeerStream.new()
	packets.stream_peer = rejected
	packets.put_packet(JSON.stringify({"token": "wrong", "paths": Array(paths)}).to_utf8_buffer())
	await wait_until(func():
		rejected.poll()
		return packets.get_available_packet_count() > 0
	)
	check(packets.get_available_packet_count() > 0 and packets.get_packet().get_string_from_utf8() == "rejected", "Invalid owner token is rejected")
	check(owner.pending.size() == 1, "Rejected request does not open documents")
	rejected.disconnect_from_host()
	var interrupted := StreamPeerTCP.new()
	interrupted.connect_to_host("127.0.0.1", owner._port)
	await wait_until(func():
		interrupted.poll()
		return interrupted.get_status() == StreamPeerTCP.STATUS_CONNECTED
	)
	interrupted.disconnect_from_host()
	await wait_until(func(): return owner._clients.is_empty())
	check(owner._clients.is_empty(), "Disconnect before request cleans up")
	var silent := StreamPeerTCP.new()
	silent.connect_to_host("127.0.0.1", owner._port)
	await wait_until(func():
		silent.poll()
		return silent.get_status() == StreamPeerTCP.STATUS_CONNECTED and owner._clients.size() == 1
	)
	await wait_until(func(): return owner._clients.is_empty())
	check(owner._clients.is_empty(), "Incomplete request expires")
	silent.disconnect_from_host()
	var port: int = owner._port
	var endpoint: String = owner._endpoint
	owner.free()
	check(not FileAccess.file_exists(endpoint), "Owner disposal removes endpoint")
	var stalled := TCPServer.new()
	check(stalled.listen(port, "127.0.0.1") == OK, "Port is reusable after disposal")
	var file := FileAccess.open(endpoint, FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": "stalled-test"}))
	file.close()
	results.clear()
	var client := Instance.new()
	root.add_child(client)
	client.forwarding_finished.connect(func(ok): results.append(ok))
	client.start(paths)
	await wait_until(func(): return stalled.is_connection_available())
	var idle := stalled.take_connection()
	await wait_until(func(): return not results.is_empty())
	check(results == [false], "Unresponsive owner times out without claiming success")
	check(client._client.is_empty() and not client.is_processing(), "Timed-out client closes transport")
	client.free()
	idle.disconnect_from_host()
	stalled.stop()
	DirAccess.remove_absolute(endpoint)
	print("SINGLE_INSTANCE_TRANSPORT_SMOKE ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
