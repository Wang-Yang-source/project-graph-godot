extends SceneTree
## Editor runtime adapter; the same Node runner can be packed as a release scene.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var runner := Node.new()
	runner.set_script(preload("res://tests/performance_baseline_runner.gd"))
	root.add_child(runner)
