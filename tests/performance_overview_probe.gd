extends "res://src/group_overview.gd"
## Actual callbacks and completed native viewport captures; timings are inclusive.
var perf_totals := {}
var perf_preview_samples: Array = []
var perf_measured_views := {}

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	perf_totals["_process"] = perf_totals.get("_process", 0) + Time.get_ticks_usec() - started

func refresh(force := false) -> void:
	var started := Time.get_ticks_usec()
	super.refresh(force)
	perf_totals["refresh"] = perf_totals.get("refresh", 0) + Time.get_ticks_usec() - started

func _update_native_previews() -> void:
	var started := Time.get_ticks_usec()
	super._update_native_previews()
	for data in _native_previews.values():
		if is_instance_valid(data.view):
			var identifier: int = data.view.get_instance_id()
			if not perf_measured_views.has(identifier):
				perf_measured_views[identifier] = true
				RenderingServer.viewport_set_measure_render_time(data.view.get_viewport_rid(), true)
	perf_totals["_update_native_previews"] = perf_totals.get("_update_native_previews", 0) + Time.get_ticks_usec() - started

func _update_preview_links() -> void:
	var started := Time.get_ticks_usec()
	super._update_preview_links()
	perf_totals["_update_preview_links"] = perf_totals.get("_update_preview_links", 0) + Time.get_ticks_usec() - started

func _complete_preview_capture(pixels: Image, data: Dictionary) -> void:
	if is_instance_valid(data.view):
		var viewport: SubViewport = data.view
		perf_preview_samples.append({"cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()), "gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()), "size": str(viewport.size)})
	super._complete_preview_capture(pixels, data)
