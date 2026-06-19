extends SceneTree

const DefeatGemShatterFxHost := preload("res://scripts/effects/defeat_gem_shatter_fx_host.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_pipeline_status()
	await _verify_host_sync_and_cleanup()
	_verify_source_contracts()

	if _failures.is_empty():
		print("defeat_gem_shatter_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pipeline_status() -> void:
	DefeatGemShatterFxHost.prewarm_assets()
	var status := DefeatGemShatterFxHost.build_pipeline_status()
	_expect(WritheEmber.has_preset("chance_gem_shatter_cyan"), "WritheEmber should expose the cyan chance-gem shatter preset")
	_expect(bool(status.get("preset_ready", false)), "shatter host prewarm should build against a real preset")
	_expect(bool(status.get("quad_texture_ready", false)), "shatter host prewarm should create the masked WritheEmber input texture")
	_expect(bool(status.get("spark_texture_ready", false)), "shatter host prewarm should create the cyan sparkle texture")
	_expect(bool(status.get("burst_texture_ready", false)), "shatter host prewarm should create the cyan burst texture")
	_expect(int(status.get("spark_amount", 0)) == 40, "shatter host should keep the bounded 40-spark particle budget")
	_expect(int(status.get("fixed_fps", 0)) == 30, "shatter host particles should run at fixed_fps 30")
	_expect(int(status.get("z_index", 0)) >= 40, "shatter host should render above the immediate-draw overlay")


func _verify_host_sync_and_cleanup() -> void:
	var host := DefeatGemShatterFxHost.new()
	get_root().add_child(host)
	await process_frame
	var initial_status := host.get_debug_status()
	_expect(not bool(initial_status.get("active", true)), "fresh shatter host should start inactive")
	_expect(not bool(initial_status.get("z_as_relative", true)), "shatter host should use absolute z ordering")
	_expect(int(initial_status.get("z_index", 0)) >= 40, "shatter host should sit above cutin-style overlay layers")
	_expect(bool(initial_status.get("local_coords", false)), "shatter sparks should stay local to the gem center")

	host.sync_state({
		"view_size": Vector2(1280.0, 720.0),
		"gem_center": Vector2(640.0, 540.0),
		"progress": 0.22,
		"elapsed": 0.44,
		"quality_scale": 1.0,
	}, true)
	var active_status := host.get_debug_status()
	_expect(bool(active_status.get("active", false)), "active shatter sync should make the host visible")
	_expect(bool(active_status.get("burst_visible", false)), "active shatter sync should show the masked burst layer")
	_expect(bool(active_status.get("particles_emitting", false)), "active sustain sync should emit cyan spark particles")
	_expect(int(active_status.get("particle_amount", 0)) == 40, "active host should keep its 40-particle cap")
	_expect(int(active_status.get("particle_fixed_fps", 0)) == 30, "active host should keep fixed_fps 30")
	_expect(_vector_close(active_status.get("position", Vector2.ZERO), Vector2(640.0, 540.0)), "host should position itself at the screen-space gem center")
	_expect(_vector_close(active_status.get("scale", Vector2.ZERO), Vector2.ONE), "720p sync should keep host scale at 1.0")
	_expect(float(active_status.get("intensity", 0.0)) > 0.1, "active sustain sync should drive nonzero WritheEmber intensity")

	host.sync_state({
		"view_size": Vector2(1280.0, 720.0),
		"gem_center": Vector2(640.0, 540.0),
		"progress": 0.90,
		"elapsed": 1.80,
		"quality_scale": 1.0,
	}, true)
	var collapse_status := host.get_debug_status()
	_expect(bool(collapse_status.get("active", false)), "collapse sync should stay visible until the handoff reaches the broken gem")
	_expect(float(collapse_status.get("intensity", 1.0)) < float(active_status.get("intensity", 0.0)), "collapse sync should reduce intensity instead of hard-popping")

	host.sync_state({
		"view_size": Vector2(1280.0, 720.0),
		"gem_center": Vector2(640.0, 540.0),
		"progress": 1.0,
		"elapsed": 2.0,
		"quality_scale": 1.0,
	}, true)
	_expect(not bool(host.get_debug_status().get("active", true)), "progress 1.0 should deactivate the host cleanly")

	host.sync_state({
		"view_size": Vector2(1280.0, 720.0),
		"gem_center": Vector2(640.0, 540.0),
		"progress": 0.35,
		"elapsed": 0.70,
		"quality_scale": 1.0,
	}, true)
	_expect(bool(host.get_debug_status().get("active", false)), "host should reactivate for timeout cleanup coverage")
	host.force_timeout_for_test()
	_expect(not bool(host.get_debug_status().get("active", true)), "host should self-timeout if the screen stops syncing it")

	host.sync_state({
		"view_size": Vector2(1280.0, 720.0),
		"gem_center": Vector2(640.0, 540.0),
		"progress": 0.35,
		"elapsed": 0.70,
		"quality_scale": 0.1,
	}, true)
	_expect(not bool(host.get_debug_status().get("active", true)), "low quality gate should disable the optional energy host")
	host.queue_free()


func _verify_source_contracts() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/effects/defeat_gem_shatter_fx_host.gd")
	var sync_body := _function_body(source, "func sync_state")
	_expect(source.find("game_offset") < 0 and source.find("render_scale") < 0, "shatter host should stay in screen-space coordinates")
	_expect(source.find("draw_set_transform") < 0, "shatter host should not reset canvas transforms")
	_expect(source.find("ResourceLoader.load") < 0 and source.find("Image.load_from_file") < 0, "shatter host should not synchronously load files")
	_expect(sync_body.find("_build_children") < 0, "sync_state should not create nodes or materials on the hot path")
	_expect(sync_body.find("ImageTexture.create_from_image") < 0, "sync_state should not create textures on the hot path")
	_expect(source.find("image.fill(Color.WHITE)") < 0 and source.find("image.set_pixel") >= 0, "WritheEmber input texture should be alpha-masked, not a visible square quad")
	_expect(source.find("_smoothstep") >= 0, "WritheEmber input mask should keep a feathered radial edge")
	_expect(source.find("ACTIVE_SYNC_GRACE_MSEC") >= 0 and source.find("set_active(false)") >= 0, "shatter host should own a single cleanup and self-timeout path")
	_expect(source.find("local_coords = true") >= 0, "spark particles should remain centered on the gem")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _vector_close(value: Variant, expected: Vector2) -> bool:
	if not (value is Vector2):
		return false
	return (value as Vector2).distance_to(expected) <= 0.01


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
