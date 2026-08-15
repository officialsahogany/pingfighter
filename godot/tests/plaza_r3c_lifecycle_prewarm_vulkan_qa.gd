extends SceneTree

# Windowed-only R3-C cold-entry seal. Unlike the focused smoke, this script
# never invokes the post-draw callback directly: readiness must cross two real
# RenderingServer.frame_post_draw emissions from the hidden SubViewport.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaR3LifecyclePrewarmCandidate := preload("res://scripts/plaza/plaza_r3_lifecycle_prewarm_candidate.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const SAFE_INSETS := {"left": 72.0, "top": 72.0, "right": 360.0, "bottom": 120.0}
const MINIMAP_RECT := Rect2(1690.0, 80.0, 250.0, 174.0)
const OUTPUT_ROOT := "res://.tmp/plaza_r3c_lifecycle_prewarm_vulkan"
const MAX_PREWARM_FRAMES := 12_000
const PIXEL_SAMPLE_STRIDE := 4
const MIN_FIRST_VISIBLE_CHANGED_SAMPLES := 1_000
const EXPECTED_COMPLETED_LEGS := 4
const MIN_ASSERTIONS_BY_LEG := {
	"real_gpu_cold_prewarm": 22,
	"first_visible_frame": 14,
	"owner_cadence": 603,
	"warm_reentry_and_evidence": 18,
}

var _failures: Array[String] = []
var _assertion_count := 0
var _legs_completed := 0
var _leg_assertion_counts: Dictionary = {}
var _seed := 0
var _run_index := 0
var _output_dir := ""
var _engine_log_path := ""
var _window_metrics: Dictionary = {}
var _cold_status: Dictionary = {}
var _warm_status: Dictionary = {}
var _cadence_metrics: Dictionary = {}
var _capture_record: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_seed = int(_get_user_arg_value("--plaza-r3c-seed="))
	_run_index = int(_get_user_arg_value("--plaza-r3c-run="))
	_engine_log_path = _get_user_arg_value("--plaza-r3c-engine-log-path=")
	_output_dir = OUTPUT_ROOT.path_join("seed_%02d_run_%d" % [_seed, _run_index])
	print("plaza_r3c_lifecycle_prewarm_vulkan_qa: CANDIDATE-ONLY seed=%d run=%d" % [_seed, _run_index])
	if not _prepare_output_directory() or not await _require_windowed_vulkan():
		_finish()
		return
	ProjectResourceLoader.clear_caches()
	PlazaAssetLoader.reset_for_test()
	var lifecycle := PlazaR3LifecyclePrewarmCandidate.new()
	lifecycle.name = "PlazaR3CWindowedLifecycle"
	root.add_child(lifecycle)
	await _verify_real_gpu_cold_prewarm(lifecycle)
	var ready_status := lifecycle.call("get_debug_status") as Dictionary
	if not bool(ready_status.get("ready", false)):
		if is_instance_valid(lifecycle):
			lifecycle.free()
		_finish()
		return
	await _verify_first_visible_frame(lifecycle)
	_verify_owner_cadence(lifecycle)
	await _verify_warm_reentry_and_evidence(lifecycle)
	if is_instance_valid(lifecycle):
		lifecycle.call("reset_all_for_test")
	await process_frame
	if is_instance_valid(lifecycle):
		lifecycle.queue_free()
		lifecycle = null
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	PlazaAssetLoader.reset_for_test()
	ProjectResourceLoader.clear_caches()
	# Let rendering/resource deletion queues advance; a blocking sleep does not
	# flush GPU RID retirement and therefore is not a valid leak barrier.
	for _dispose_frame in range(120):
		await process_frame
	await RenderingServer.frame_post_draw
	_finish()


func _verify_real_gpu_cold_prewarm(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var config := _build_config()
	_expect(bool(lifecycle.call("begin_prewarm", config)), "cold request must be accepted")
	_expect(await _drive_real_prewarm(lifecycle), "real Vulkan cold prewarm must complete")
	_cold_status = lifecycle.call("get_debug_status") as Dictionary
	var readiness := lifecycle.call("get_readiness_snapshot") as Dictionary
	var plan := lifecycle.call("get_environment_plan_snapshot_for_test") as Dictionary
	var expected_resource := _derive_expected_resource_paths(plan, config)
	var expected_gpu := _derive_expected_gpu_paths(plan, config)
	var validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(readiness, expected_resource, expected_gpu)
	_expect(bool(_cold_status.get("ready", false)), "cold lifecycle must report ready")
	_expect(str(_cold_status.get("phase", "")) == "ready", "cold lifecycle must stop at ready")
	_expect(bool(validation.get("valid", false)), "independent warm-set validation must pass: %s" % validation)
	_expect(int(readiness.get("catalog_key_count", 0)) == 25, "environment catalog must contain exact 25 keys")
	_expect((readiness.get("building_texture_paths", []) as Array).size() == 21, "building prewarm must contain 21 layers")
	_expect((readiness.get("actor_texture_paths", []) as Array).size() == 4, "player and guardian warm set must contain four textures")
	_expect((readiness.get("expected_resource_paths", []) as Array).size() == expected_resource.size(), "resource warm set must exactly match independent derivation")
	_expect((readiness.get("expected_gpu_paths", []) as Array).size() == expected_gpu.size(), "GPU warm set must exactly match independent derivation")
	_expect((readiness.get("submitted_gpu_paths", []) as Array).size() == expected_gpu.size(), "all visible textures must be submitted")
	_expect(int(readiness.get("gpu_in_bounds_path_count", 0)) == expected_gpu.size(), "every GPU submission must be in bounds")
	_expect(int(readiness.get("gpu_post_draw_flush_count", 0)) == 2, "real GPU readiness must cross exactly two post-draw flushes")
	_expect(not bool(readiness.get("gpu_reused", true)), "fresh process cold run must not reuse a GPU warm seal")
	_expect(bool(readiness.get("node_pipeline_warmed", false)), "actual R3 node pipeline must be built before visibility")
	_expect(bool(readiness.get("minimap_pipeline_warmed", false)), "actual minimap pipeline must be built before visibility")
	_expect(int(readiness.get("duplicate_step_count", -1)) == 0, "prewarm steps must complete exactly once")
	_expect(int(_cold_status.get("compile_count", 0)) == 1, "cold key must compile once")
	_expect(int(_cold_status.get("texture_request_count", 0)) > 0, "fresh process must issue threaded texture requests")
	_expect(int(_cold_status.get("cold_warning_count", -1)) == 0, "no [PrewarmColdInstantiate] warning may fire")
	_expect(int(_cold_status.get("cold_prewarm_usec", -1)) > 0, "cold prewarm duration must be recorded")
	_expect(int(_cold_status.get("scene_owned_node_count", 0)) > 0, "hidden runtime must own a non-empty scene tree")
	_expect(int(_cold_status.get("scene_texture_id_count", 0)) > 0, "hidden runtime must retain real texture identities")
	_expect(int(_cold_status.get("scene_audio_player_count", -1)) == 0, "hidden R3 exterior must allocate no detached audio players")
	_complete_leg("real_gpu_cold_prewarm", assertion_start)


func _verify_first_visible_frame(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var before := lifecycle.call("get_debug_status") as Dictionary
	var whole_started_usec := Time.get_ticks_usec()
	_expect(bool(lifecycle.call("activate_exterior")), "prebuilt runtime must activate")
	await RenderingServer.frame_post_draw
	var whole_frame_usec := Time.get_ticks_usec() - whole_started_usec
	var after := lifecycle.call("get_debug_status") as Dictionary
	var first_visible_texture := root.get_texture()
	var first_visible_image := first_visible_texture.get_image()
	_expect(first_visible_image != null and not first_visible_image.is_empty(), "cold first-visible capture must exist")
	var changed_samples := _count_samples_away_from_color(first_visible_image, RenderingServer.get_default_clear_color(), PIXEL_SAMPLE_STRIDE)
	_window_metrics["first_visible_changed_sample_pixels"] = changed_samples
	_window_metrics["first_visible_pixel_sample_stride"] = PIXEL_SAMPLE_STRIDE
	_expect(changed_samples >= MIN_FIRST_VISIBLE_CHANGED_SAMPLES, "cold activation must expose non-empty R3 exterior pixels: %d < %d" % [changed_samples, MIN_FIRST_VISIBLE_CHANGED_SAMPLES])
	if first_visible_image != null and not first_visible_image.is_empty():
		var capture_path := _output_dir.path_join("first_visible.png")
		var save_error := first_visible_image.save_png(ProjectSettings.globalize_path(capture_path))
		_expect(save_error == OK, "cold first-visible evidence PNG must save")
		if save_error == OK:
			_capture_record = {
				"path": capture_path,
				"sha256": FileAccess.get_sha256(capture_path),
				"size": [first_visible_image.get_width(), first_visible_image.get_height()],
				"changed_sample_pixels": changed_samples,
			}
	_window_metrics["whole_first_visible_frame_usec"] = whole_frame_usec
	_window_metrics["r3_first_visible_activation_usec"] = int(after.get("first_visible_activation_usec", -1))
	_expect(int(after.get("first_visible_activation_usec", 99_999)) <= 2_000, "first-visible R3 work must remain within 2ms")
	_expect(whole_frame_usec > 0, "whole first-visible frame duration must be recorded separately")
	_expect(int(after.get("texture_request_count", -1)) == int(before.get("texture_request_count", -2)), "activation must issue zero texture requests")
	_expect(int(after.get("compile_count", -1)) == int(before.get("compile_count", -2)), "activation must compile zero authoritative records")
	_expect(int(after.get("runtime_build_count", -1)) == int(before.get("runtime_build_count", -2)), "activation must build zero node pipelines")
	_expect(int(after.get("scene_owned_node_count", -1)) == int(before.get("scene_owned_node_count", -2)), "activation must allocate zero scene nodes")
	_expect(int(after.get("scene_material_rid_count", -1)) == int(before.get("scene_material_rid_count", -2)), "activation must allocate zero material RIDs")
	_expect(int(after.get("scene_texture_id_count", -1)) == int(before.get("scene_texture_id_count", -2)), "activation must change zero texture identities")
	_expect(int(after.get("cached_resource_texture_path_count", -1)) == int(before.get("cached_resource_texture_path_count", -2)), "activation must grow no resource cache")
	_expect(bool(after.get("active", false)) and bool(after.get("visible", false)), "first visible frame must expose the active runtime")
	_expect((after.get("lifecycle_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(VIEW_SIZE)), "visible lifecycle owner must retain the exact unclipped render extent")
	_expect(int(after.get("activation_count", 0)) == 1, "cold activation must occur exactly once")
	_expect(int(after.get("cold_warning_count", -1)) == 0, "first visible frame must retain zero cold-instantiation warnings")
	_expect(str(after.get("layout_fingerprint", "")).length() == 64, "visible frame must retain the compiled layout fingerprint")
	first_visible_image = null
	first_visible_texture = null
	_complete_leg("first_visible_frame", assertion_start)


func _verify_owner_cadence(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	for tick_index in range(720):
		var phase := tick_index % 240
		var direction := Vector2.RIGHT if phase < 60 else Vector2.DOWN if phase < 120 else Vector2.LEFT if phase < 180 else Vector2.UP
		var result := lifecycle.call("tick_exterior", direction, 1.0 / 60.0, tick_index * 17) as Dictionary
		_expect(bool(result.get("valid", false)), "real owner tick %d must remain valid" % tick_index)
	var runtime := lifecycle.call("get_runtime_for_test") as Control
	_cadence_metrics = runtime.call("get_owner_cadence_metrics") as Dictionary
	_expect(int(_cadence_metrics.get("sample_count", 0)) == 600, "real owner cadence must retain 600 steady samples")
	_expect(float(_cadence_metrics.get("p95_usec", 99_999.0)) < 2_000.0, "real owner cadence p95 must remain below 2ms: %s" % _cadence_metrics)
	_expect(bool(_cadence_metrics.get("within_limit", false)), "real owner cadence must publish a GREEN fixed-limit result")
	_complete_leg("owner_cadence", assertion_start)


func _verify_warm_reentry_and_evidence(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var cold_layout_fingerprint := str(_cold_status.get("layout_fingerprint", ""))
	var cold_plan_fingerprint := str(_cold_status.get("environment_plan_fingerprint", ""))
	var cold_compile_count := int(_cold_status.get("compile_count", 0))
	var cold_request_count := int(_cold_status.get("texture_request_count", 0))
	lifecycle.call("teardown_scene")
	_expect(bool(lifecycle.call("begin_prewarm", _build_config())), "same-key warm request must be accepted")
	_expect(await _drive_real_prewarm(lifecycle), "same-key warm prewarm must complete")
	_warm_status = lifecycle.call("get_debug_status") as Dictionary
	_expect(bool(_warm_status.get("ready", false)), "warm reentry must report ready")
	_expect(int(_warm_status.get("compile_count", 0)) == cold_compile_count, "warm reentry must not recompile")
	_expect(int(_warm_status.get("texture_request_count", 0)) == cold_request_count, "warm reentry must issue zero new texture requests")
	_expect(int(_warm_status.get("cache_hit_count", 0)) >= 1, "warm reentry must hit the compiled cache")
	_expect(str(_warm_status.get("layout_fingerprint", "")) == cold_layout_fingerprint, "warm reentry must preserve layout fingerprint")
	_expect(str(_warm_status.get("environment_plan_fingerprint", "")) == cold_plan_fingerprint, "warm reentry must preserve plan fingerprint")
	_expect(int(_warm_status.get("warm_prewarm_usec", -1)) > 0, "warm entry duration must be recorded")
	_expect(int(_warm_status.get("warm_prewarm_usec", 9_999_999)) <= int(_warm_status.get("cold_prewarm_usec", -1)), "warm entry must not be slower than cold entry")
	_expect(bool((_warm_status.get("readiness", {}) as Dictionary).get("gpu_reused", false)), "same-key warm reentry must reuse the exact GPU texture identity seal")
	_expect(int(_warm_status.get("cold_warning_count", -1)) == 0, "cold-instantiation warning count must remain zero after warm reentry")
	_expect(bool(lifecycle.call("activate_exterior")), "warm runtime must activate")
	await RenderingServer.frame_post_draw
	var warm_runtime := lifecycle.call("get_runtime_for_test") as Control
	_expect(warm_runtime != null and is_instance_valid(warm_runtime), "warm activation must retain the rebuilt R3 runtime")
	var warm_runtime_status := warm_runtime.call("get_debug_status") as Dictionary if warm_runtime != null and is_instance_valid(warm_runtime) else {}
	_expect(bool(warm_runtime_status.get("active", false)) and bool(warm_runtime_status.get("visible", false)), "warm activation must expose the rebuilt R3 runtime")
	_expect(_capture_record.get("size", []) == [VIEW_SIZE.x, VIEW_SIZE.y], "evidence capture must be exact 2020x1246")
	var engine_log := FileAccess.get_file_as_string(_engine_log_path)
	var has_vulkan_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	_window_metrics["engine_log_has_vulkan_mobile_banner"] = has_vulkan_banner
	_expect(has_vulkan_banner, "engine log must contain the real Vulkan Forward Mobile banner")
	_expect(_failures.is_empty(), "windowed lifecycle evidence must remain failure-free before report")
	_complete_leg("warm_reentry_and_evidence", assertion_start)


func _drive_real_prewarm(lifecycle: Control) -> bool:
	for _frame_index in range(MAX_PREWARM_FRAMES):
		if bool(lifecycle.call("advance_prewarm_step")):
			return true
		var status := lifecycle.call("get_debug_status") as Dictionary
		if str(status.get("phase", "")) == "rejected":
			_expect(false, "windowed prewarm rejected: %s" % status.get("rejection_reason", ""))
			return false
		await process_frame
	_expect(false, "windowed prewarm exceeded %d frames" % MAX_PREWARM_FRAMES)
	return false


func _build_config() -> Dictionary:
	return {
		"stage_id": 1,
		"map_seed": _seed,
		"render_size": Vector2(VIEW_SIZE),
		"safe_insets": SAFE_INSETS,
		"minimap_rect": MINIMAP_RECT,
		"camera_zoom": 1.35,
		"selected_character_type": "smasher",
		"guardian_enabled": true,
		"guardian_id": "onimaru",
		"guardian_locomotion_style": "ground",
		"initial_player_position_policy": "first_portal",
	}


func _derive_expected_resource_paths(plan: Dictionary, config: Dictionary) -> Array[String]:
	var paths := _derive_expected_gpu_paths(plan, config)
	for path_map in [
		PlazaAssetLoader.get_interior_npc_texture_paths_for_test(),
		PlazaAssetLoader.get_interior_room_texture_paths_for_test(),
		PlazaAssetLoader.get_interior_object_texture_paths_for_test(),
	]:
		for path_value in (path_map as Dictionary).values():
			_append_unique(paths, str(path_value))
	paths.sort()
	return paths


func _derive_expected_gpu_paths(plan: Dictionary, config: Dictionary) -> Array[String]:
	var paths := PlazaAssetLoader.get_hwangyeok_building_prewarm_texture_paths()
	var player_paths := PlazaAssetLoader.get_player_texture_paths_for_test(config.get("selected_character_type", "smasher"))
	for key in ["idle", "walk_left", "walk_right"]:
		_append_unique(paths, str(player_paths.get(key, "")))
	_append_unique(paths, LingpetCatalog.get_visual_path(str(config.get("guardian_id", "onimaru")), "companion_walk"))
	var ground := plan.get("ground_draw", {}) as Dictionary
	_append_unique(paths, str(ground.get("texture_path", "")))
	for key in ["road_draws", "plot_pad_draws", "decor_draws"]:
		for record in _dictionary_array(plan.get(key, [])):
			_append_unique(paths, str(record.get("texture_path", "")))
	paths.sort()
	return paths


func _prepare_output_directory() -> bool:
	if _seed not in [4, 12] or _run_index < 1 or _run_index > 3:
		_failures.append("seed/run contract invalid")
		return false
	var absolute := ProjectSettings.globalize_path(_output_dir)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		_failures.append("failed to create output directory")
		return false
	for filename in DirAccess.get_files_at(absolute):
		if DirAccess.remove_absolute(absolute.path_join(str(filename))) != OK:
			_failures.append("failed to remove stale evidence: %s" % filename)
	return _failures.is_empty()


func _require_windowed_vulkan() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	var driver_name := _get_user_arg_value("--plaza-r3c-rendering-driver=").to_lower()
	if display_name.contains("headless"):
		_failures.append("R3-C cold QA requires a windowed display server")
	if rendering_method != "mobile":
		_failures.append("R3-C cold QA requires rendering method mobile, got %s" % rendering_method)
	if driver_name != "vulkan":
		_failures.append("R3-C cold QA requires the explicit Vulkan sentinel")
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = VIEW_SIZE
	await process_frame
	await process_frame
	_window_metrics = {
		"display_server": display_name,
		"rendering_method": rendering_method,
		"rendering_driver": driver_name,
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"requested_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"live_window_size": [root.size.x, root.size.y],
	}
	_expect(root.size == VIEW_SIZE, "live window must be exact 2020x1246")
	return _failures.is_empty()


func _write_report() -> void:
	var report := {
		"schema": "plaza_r3c_lifecycle_prewarm_vulkan_qa_v1",
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"candidate_only": true,
		"production_connected": false,
		"map_seed": _seed,
		"run_index": _run_index,
		"window": _window_metrics,
		"cold_status": _cold_status,
		"warm_status": _warm_status,
		"owner_cadence": _cadence_metrics,
		"capture": _capture_record,
		"completed_legs": _legs_completed,
		"assertion_count": _assertion_count,
		"leg_assertion_counts": _leg_assertion_counts,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(_output_dir.path_join("metrics.json")), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _append_unique(paths: Array[String], path: String) -> void:
	if path != "" and not paths.has(path):
		paths.append(path)


func _count_samples_away_from_color(image: Image, baseline: Color, stride: int) -> int:
	if image == null or image.is_empty():
		return 0
	if stride <= 0:
		return 0
	var changed := 0
	for y in range(0, image.get_height(), stride):
		for x in range(0, image.get_width(), stride):
			var pixel := image.get_pixel(x, y)
			if (
				absf(pixel.r - baseline.r) > 1.0 / 255.0
				or absf(pixel.g - baseline.g) > 1.0 / 255.0
				or absf(pixel.b - baseline.b) > 1.0 / 255.0
				or absf(pixel.a - baseline.a) > 1.0 / 255.0
			):
				changed += 1
	return changed


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value as Array:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _get_user_arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _complete_leg(leg_name: String, assertion_start: int) -> void:
	if _leg_assertion_counts.has(leg_name):
		_failures.append("GRT-040 duplicate completed verification leg: %s" % leg_name)
		return
	_leg_assertion_counts[leg_name] = _assertion_count - assertion_start
	_legs_completed += 1


func _expect(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _legs_completed != EXPECTED_COMPLETED_LEGS:
		_failures.append("GRT-040 completion gate: expected %d completed verification legs, got %d" % [EXPECTED_COMPLETED_LEGS, _legs_completed])
	for leg_name in MIN_ASSERTIONS_BY_LEG.keys():
		var actual := int(_leg_assertion_counts.get(leg_name, 0))
		var required := int(MIN_ASSERTIONS_BY_LEG.get(leg_name, 1))
		if actual < required:
			_failures.append("GRT-040 completion gate: leg %s executed %d assertions, expected at least %d" % [leg_name, actual, required])
	if _assertion_count <= 0:
		_failures.append("GRT-040 completion gate: assertion count must be positive")
	_write_report()
	if _failures.is_empty():
		print("plaza_r3c_lifecycle_prewarm_vulkan_qa: ok seed=%d run=%d legs=%d assertions=%d" % [_seed, _run_index, _legs_completed, _assertion_count])
		print("plaza_r3c_lifecycle_prewarm_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(_output_dir))
		_schedule_quit(0)
		return
	for failure in _failures:
		push_error(failure)
	_schedule_quit(1)


func _schedule_quit(exit_code: int) -> void:
	# Queue native SceneTree quit directly so _finish() and async _run() return
	# before ObjectDB cleanup. The real-frame disposal drain already completed.
	call_deferred("quit", exit_code)
