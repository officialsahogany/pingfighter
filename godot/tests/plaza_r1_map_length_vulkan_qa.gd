extends SceneTree

# Live-feel evidence for the R1 1900 -> 2400 plaza-width promotion. This probe
# intentionally walks the production StageClearResultPlazaSceneHandler route:
# Input.action_press("ui_right") -> PlazaScene.update_plaza() ->
# PlazaPlayerController.move_player(). It never warps the player position.
#
# The four captures make the extra route visible:
#   A. production spawn (x=120)
#   B. midpoint of the new spawn-to-exit walk
#   C. the 60 Hz frame where the legacy 1900 map would already have reached
#      its exit zone; the 2400 map must still be on the street
#   D. first production frame inside the new 2400 exit zone

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")

const VIEW_SIZE := Vector2i(1280, 720)
const OUTPUT_DIR := "res://.tmp/plaza_r1_map_length_vulkan"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r1_map_length_vulkan.engine.log"
const FIXED_MAP_SEED := 918273
const LOGICAL_FPS := 60.0
const DELTA := 1.0 / LOGICAL_FPS
const LEGACY_MAP_SIZE := Vector2(1900.0, 750.0)
const LEGACY_EXIT_START_X := 1750.0
const EXPECTED_MAP_SIZE := Vector2(2400.0, 1500.0)
const EXPECTED_EXIT_START_X := 2250.0
const EXPECTED_SPAWN_X := 120.0
const EXPECTED_NEW_ENTRY_FRAME := 533
const EXPECTED_LEGACY_ENTRY_FRAME := 408
const MAX_ROUTE_FRAMES := 700
const EXPECTED_CAPTURE_SLUGS := [
	"a_spawn",
	"b_new_route_midpoint",
	"c_legacy_exit_time_still_walking",
	"d_new_exit_first_entry",
]


class ExitSink:
	extends RefCounted

	var call_count := 0

	func finish() -> void:
		call_count += 1


var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _route_samples: Dictionary = {}
var _runtime: Dictionary = {}
var _owner: Control = null
var _handler: Object = null
var _scene: Control = null
var _sink := ExitSink.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _require_windowed_vulkan_mobile():
		_write_report()
		_finish()
		return
	if not _prepare_output_directory():
		_write_report()
		_finish()
		return

	_build_owner()
	_handler = StageClearResultPlazaSceneHandler.new()
	if not await _prewarm_production_owner():
		_write_report()
		_finish()
		return

	var spawned := bool(_handler.spawn_scene(
		_owner,
		{
			"current_stage": 1,
			"map_seed": FIXED_MAP_SEED,
			"full_layout_for_test": true,
			"play_arrival_transition": false,
		},
		Callable(_sink, "finish")
	))
	_expect(spawned, "production StageClearResultPlazaSceneHandler must spawn the live route")
	_scene = _owner.get_node_or_null("PlazaScene") as Control
	_expect(_scene != null, "production owner must contain PlazaScene")
	if _scene == null:
		_write_report()
		_finish()
		return

	_handler.update(0.0)
	await RenderingServer.frame_post_draw
	_verify_engine_log_proves_vulkan()
	var initial_status := _get_scene_status()
	var world_size: Vector2 = initial_status.get("world_size", Vector2.ZERO)
	var exit_zone: Rect2 = initial_status.get("exit_zone", Rect2())
	var spawn_pos: Vector2 = initial_status.get("player_pos", Vector2.ZERO)
	var speed_per_second := PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60 * LOGICAL_FPS
	var new_distance := exit_zone.position.x - spawn_pos.x
	var legacy_distance := LEGACY_EXIT_START_X - spawn_pos.x
	var new_camera_span := maxf(0.0, world_size.x - PlazaScene.GAME_SIZE.x)
	var legacy_camera_span := maxf(0.0, LEGACY_MAP_SIZE.x - PlazaScene.GAME_SIZE.x)
	var midpoint_x := spawn_pos.x + new_distance * 0.5

	_expect(world_size.is_equal_approx(EXPECTED_MAP_SIZE), "live R1 route must publish the non-vacuous 2400 x 1500 map contract")
	_expect(is_equal_approx(exit_zone.position.x, EXPECTED_EXIT_START_X), "live R1 exit must begin at x=2250")
	_expect(is_equal_approx(spawn_pos.x, EXPECTED_SPAWN_X), "live production spawn must remain x=120")
	_expect(is_equal_approx(speed_per_second, 240.0), "live controller must retain 4 px/frame at 60 Hz = 240 world px/s")
	_expect(is_equal_approx(new_camera_span, 1640.0), "2400 world target-camera clamp span must be 1640")
	_expect(is_equal_approx(legacy_camera_span, 1140.0), "1900 world target-camera clamp span must have been 1140")

	_runtime.merge({
		"route": "StageClearResultPlazaSceneHandler.update -> PlazaScene.update_plaza -> PlazaPlayerController.move_player",
		"input": "Input.action_press(ui_right)",
		"direct_position_warp_used": false,
		"logical_fps": LOGICAL_FPS,
		"delta_seconds": DELTA,
		"speed_world_per_second": speed_per_second,
		"speed_world_per_frame_60": PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60,
		"spawn_x": spawn_pos.x,
		"new_world_size": [world_size.x, world_size.y],
		"legacy_world_size": [LEGACY_MAP_SIZE.x, LEGACY_MAP_SIZE.y],
		"new_exit_zone": [exit_zone.position.x, exit_zone.position.y, exit_zone.size.x, exit_zone.size.y],
		"legacy_exit_start_x": LEGACY_EXIT_START_X,
		"new_walk_distance": new_distance,
		"legacy_walk_distance": legacy_distance,
		"distance_delta": new_distance - legacy_distance,
		"distance_increase_percent": _percent_increase(legacy_distance, new_distance),
		"new_continuous_walk_seconds": new_distance / speed_per_second,
		"legacy_continuous_walk_seconds": legacy_distance / speed_per_second,
		"continuous_walk_delta_seconds": (new_distance - legacy_distance) / speed_per_second,
		"new_discrete_entry_frame_60hz": ceili(new_distance / PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60),
		"legacy_discrete_entry_frame_60hz": ceili(legacy_distance / PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60),
		"new_discrete_walk_seconds_60hz": ceili(new_distance / PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60) / LOGICAL_FPS,
		"legacy_discrete_walk_seconds_60hz": ceili(legacy_distance / PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60) / LOGICAL_FPS,
		"new_camera_clamp_span": new_camera_span,
		"legacy_camera_clamp_span": legacy_camera_span,
		"camera_span_delta": new_camera_span - legacy_camera_span,
		"camera_span_increase_percent": _percent_increase(legacy_camera_span, new_camera_span),
		"exit_warp_seconds": 1.0,
	}, true)

	_route_samples["spawn"] = _sample_status(0, initial_status)
	await _capture("a_spawn", 0)

	var midpoint_captured := false
	var legacy_time_captured := false
	var entry_frame := -1
	Input.action_press("ui_right", 1.0)
	for frame in range(1, MAX_ROUTE_FRAMES + 1):
		_handler.update(DELTA)
		await process_frame
		var status := _get_scene_status()
		var player_pos: Vector2 = status.get("player_pos", Vector2.ZERO)
		if not midpoint_captured and player_pos.x >= midpoint_x:
			midpoint_captured = true
			_route_samples["new_route_midpoint"] = _sample_status(frame, status)
			await _capture("b_new_route_midpoint", frame)
		if frame == EXPECTED_LEGACY_ENTRY_FRAME:
			legacy_time_captured = true
			_route_samples["legacy_exit_time"] = _sample_status(frame, status)
			_expect(player_pos.x >= LEGACY_EXIT_START_X, "legacy entry frame must reach the old x=1750 exit threshold")
			_expect(not (status.get("exit_zone", Rect2()) as Rect2).has_point(player_pos), "at the old exit time, the 2400 route must still be outside its live exit zone")
			_expect(float(status.get("camera_x", 0.0)) > legacy_camera_span, "live camera must move beyond the entire legacy 1140 clamp span")
			await _capture("c_legacy_exit_time_still_walking", frame)
		if exit_zone.has_point(player_pos):
			entry_frame = frame
			_route_samples["new_exit_first_entry"] = _sample_status(frame, status)
			await _capture("d_new_exit_first_entry", frame)
			break
	Input.action_release("ui_right")

	_expect(midpoint_captured, "live route must cross and capture its new midpoint")
	_expect(legacy_time_captured, "live route must retain the old-exit-time counterfactual capture")
	_expect(entry_frame == EXPECTED_NEW_ENTRY_FRAME, "2400 production route must first enter the exit zone on 60 Hz frame 533, got %d" % entry_frame)
	_expect(entry_frame - EXPECTED_LEGACY_ENTRY_FRAME == 125, "R1 route must add exactly 125 normal-input frames over the legacy route")
	var exit_status := _get_scene_status()
	var exit_camera := float(exit_status.get("camera_x", -1.0))
	_expect(exit_camera > 1639.0 and exit_camera <= 1640.001, "smoothed live camera must settle at the new 1640 clamp by exit entry, got %.3f" % exit_camera)
	_runtime["actual_new_entry_frame_60hz"] = entry_frame
	_runtime["actual_new_walk_seconds_60hz"] = entry_frame / LOGICAL_FPS
	_runtime["actual_extra_frames_vs_legacy"] = entry_frame - EXPECTED_LEGACY_ENTRY_FRAME
	_runtime["actual_walk_increase_percent_60hz"] = _percent_increase(
		EXPECTED_LEGACY_ENTRY_FRAME / LOGICAL_FPS,
		entry_frame / LOGICAL_FPS
	)
	_runtime["actual_camera_x_at_new_exit"] = exit_camera

	# Finish the actual interaction as well. Walking into the zone does not leave
	# the plaza; production requires Enter followed by the one-second warp.
	var enter_event := InputEventKey.new()
	enter_event.keycode = KEY_ENTER
	enter_event.pressed = true
	_handler.handle_input(enter_event)
	var exit_transition_frames := 0
	while _sink.call_count == 0 and exit_transition_frames < 90:
		_handler.update(DELTA)
		exit_transition_frames += 1
		await process_frame
	_expect(_sink.call_count == 1, "actual Enter input plus production warp must invoke the plaza exit callback once")
	_expect(exit_transition_frames == 60, "one-second production exit warp must complete in 60 logical frames, got %d" % exit_transition_frames)
	_runtime["actual_exit_transition_frames_60hz"] = exit_transition_frames
	_runtime["actual_spawn_to_exit_callback_seconds_60hz"] = (entry_frame + exit_transition_frames) / LOGICAL_FPS
	_runtime["legacy_spawn_to_exit_callback_seconds_60hz"] = (EXPECTED_LEGACY_ENTRY_FRAME + exit_transition_frames) / LOGICAL_FPS

	_verify_capture_set()
	_write_report()
	_finish()


func _build_owner() -> void:
	_owner = Control.new()
	_owner.name = "StageClearResultProductionOwner"
	_owner.position = Vector2.ZERO
	_owner.size = Vector2(VIEW_SIZE)
	root.add_child(_owner)
	var underlay := ColorRect.new()
	underlay.name = "ResultStackUnderlay"
	underlay.position = Vector2.ZERO
	underlay.size = Vector2(VIEW_SIZE)
	underlay.color = Color(0.018, 0.022, 0.038, 1.0)
	underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owner.add_child(underlay)


func _prewarm_production_owner() -> bool:
	ProjectResourceLoader.clear_caches()
	PlazaScene.reset_prewarm_assets_for_test()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	var cache_only_ready := bool(_handler.ensure_assets_ready(1, _owner))
	_expect(not cache_only_ready, "cache-only preload must remain insufficient before live GPU prewarm")
	var guard := 0
	while not BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete() and guard < 16:
		BattlePsoPrewarmer.run_hwangyeok_gpu_prewarm_step(_owner)
		await RenderingServer.frame_post_draw
		guard += 1
	var ready := bool(_handler.ensure_assets_ready(1, _owner))
	_expect(ready, "production owner must complete retained Hwangyeok GPU prewarm")
	var status := BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status()
	_expect(int(status.get("drawn_layer_count", 0)) == 21, "live prewarm must draw all 21 building layers")
	_expect(int(status.get("post_draw_flush_count", 0)) >= 2, "live prewarm must cross two frame_post_draw flushes")
	return ready


func _sample_status(frame: int, status: Dictionary) -> Dictionary:
	var player_pos: Vector2 = status.get("player_pos", Vector2.ZERO)
	var exit_zone: Rect2 = status.get("exit_zone", Rect2())
	return {
		"frame_60hz": frame,
		"logical_seconds": frame / LOGICAL_FPS,
		"player_pos": [player_pos.x, player_pos.y],
		"camera_x": float(status.get("camera_x", 0.0)),
		"inside_live_exit_zone": exit_zone.has_point(player_pos),
	}


func _capture(slug: String, frame: int) -> void:
	if _scene == null:
		_failures.append("capture %s requested without PlazaScene" % slug)
		return
	_scene.queue_redraw()
	var host := _scene.get_node_or_null("PlazaMapWorldHost") as Control
	if host != null:
		host.queue_redraw()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("capture %s returned an empty window image" % slug)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(slug + ".png"))
	var error := image.save_png(output_path)
	_expect(error == OK, "capture %s must save successfully (error %d)" % [slug, error])
	if error != OK:
		return
	_captures.append({
		"slug": slug,
		"frame_60hz": frame,
		"path": output_path,
		"size": [image.get_width(), image.get_height()],
		"sha256": FileAccess.get_sha256(output_path),
	})
	print("plaza_r1_map_length_vulkan_qa: evidence %s" % output_path)


func _require_windowed_vulkan_mobile() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	var requested_driver := _get_user_arg_value("--plaza-rendering-driver=").to_lower()
	_expect(not display_name.contains("headless"), "map-length QA requires a real windowed display server")
	_expect(rendering_method == "mobile", "map-length QA requires rendering method mobile, got %s" % rendering_method)
	_expect(requested_driver == "vulkan", "map-length QA requires --plaza-rendering-driver=vulkan after --")
	_runtime["display_server"] = display_name
	_runtime["rendering_method"] = rendering_method
	_runtime["rendering_driver"] = requested_driver
	_runtime["video_adapter"] = RenderingServer.get_video_adapter_name()
	_runtime["video_adapter_api_version"] = RenderingServer.get_video_adapter_api_version()
	return _failures.is_empty()


func _verify_engine_log_proves_vulkan() -> void:
	var engine_log := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	var has_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	_runtime["engine_log_path"] = ProjectSettings.globalize_path(ENGINE_LOG_PATH)
	_runtime["engine_log_has_vulkan_mobile_banner"] = has_banner
	_expect(has_banner, "engine log must prove Vulkan Forward Mobile")


func _prepare_output_directory() -> bool:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_failures.append("failed to create evidence directory %s (error %d)" % [output_dir, mkdir_error])
		return false
	for slug in EXPECTED_CAPTURE_SLUGS:
		var path := output_dir.path_join(str(slug) + ".png")
		if FileAccess.file_exists(path):
			var remove_error := DirAccess.remove_absolute(path)
			if remove_error != OK:
				_failures.append("failed to remove stale evidence %s (error %d)" % [path, remove_error])
				return false
	var report_path := output_dir.path_join("metrics.json")
	if FileAccess.file_exists(report_path):
		var remove_report_error := DirAccess.remove_absolute(report_path)
		if remove_report_error != OK:
			_failures.append("failed to remove stale metrics %s (error %d)" % [report_path, remove_report_error])
			return false
	return true


func _verify_capture_set() -> void:
	var slugs := {}
	for capture in _captures:
		var slug := str(capture.get("slug", ""))
		slugs[slug] = true
		var size_value: Variant = capture.get("size", [])
		var capture_size: Array = size_value as Array if size_value is Array else []
		_expect(capture_size == [VIEW_SIZE.x, VIEW_SIZE.y], "%s must be an exact 1280 x 720 capture" % slug)
		_expect(str(capture.get("sha256", "")).length() == 64, "%s must retain a SHA-256 evidence hash" % slug)
	_expect(slugs.size() == EXPECTED_CAPTURE_SLUGS.size(), "map-length QA must retain four unique captures")
	for slug in EXPECTED_CAPTURE_SLUGS:
		_expect(slugs.has(slug), "map-length QA is missing capture %s" % slug)


func _write_report() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
	var report := {
		"schema": "plaza_r1_map_length_live_vulkan_v1",
		"pass": _failures.is_empty(),
		"view_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"map_seed": FIXED_MAP_SEED,
		"runtime": _runtime,
		"route_samples": _route_samples,
		"captures": _captures,
		"failures": _failures,
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to open map-length metrics %s" % output_path)
		return
	file.store_string(JSON.stringify(report, "\t", false))
	file.close()
	print("plaza_r1_map_length_vulkan_qa: metrics %s" % output_path)


func _get_scene_status() -> Dictionary:
	if _scene == null:
		return {}
	var value: Variant = _scene.call("get_status")
	return value as Dictionary if value is Dictionary else {}


func _get_user_arg_value(prefix: String) -> String:
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _percent_increase(old_value: float, new_value: float) -> float:
	return (new_value - old_value) / old_value * 100.0 if old_value > 0.0 else 0.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	Input.action_release("ui_right")
	if _handler != null:
		_handler.free_scene()
	if _owner != null and is_instance_valid(_owner):
		_owner.queue_free()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("plaza_r1_map_length_vulkan_qa: ok")
		print("plaza_r1_map_length_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
