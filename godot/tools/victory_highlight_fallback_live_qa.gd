extends SceneTree

const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const VictoryHighlightFrameCaptureState := preload("res://scripts/core/victory_highlight_frame_capture_state.gd")
const VictoryHighlightFrameRenderer := preload("res://scripts/core/victory_highlight_frame_renderer.gd")
const VictoryHighlightPlaybackState := preload("res://scripts/core/victory_highlight_playback_state.gd")
const VictoryHighlightRecorder := preload("res://scripts/core/victory_highlight_recorder.gd")
const VictoryHighlightRenderer := preload("res://scripts/core/victory_highlight_renderer.gd")

const OUTPUT_DIR := "res://.godot/codex_captures/victory_highlight_fallback"
const GAME_SIZE := Vector2(760.0, 750.0)
const PREWARM_TIMEOUT_FRAMES := 360
const EXTENDED_MATCH_FRAMES := 360
const REMATCH_FRAMES := 240


class ModuleRegistry:
	extends RefCounted
	var values: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = values.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class LiveBattleOwner:
	extends Node2D
	var victory_highlight_active := false
	var current_stage := 1
	var ball_pos := Vector2(380.0, 375.0)
	var ball_prev := ball_pos
	var frame_index := 0
	var match_label := "extended"

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color("101725"), true)
		for x in range(20, 760, 40):
			draw_line(Vector2(x, 0), Vector2(x, 750), Color(0.12, 0.20, 0.31, 0.5), 1.0)
		for y in range(15, 750, 40):
			draw_line(Vector2(0, y), Vector2(760, y), Color(0.12, 0.20, 0.31, 0.5), 1.0)
		draw_line(Vector2(0, 375), Vector2(760, 375), Color(0.45, 0.65, 0.86, 0.65), 2.0)
		draw_rect(Rect2(292, 676, 176, 26), Color("61b9ff"), true)
		draw_rect(Rect2(292, 48, 176, 26), Color("ff718a"), true)
		draw_circle(ball_pos, 18.0, Color("ffe17b"))
		draw_circle(ball_pos, 11.0, Color("fff8d4"))
		draw_arc(ball_pos, 24.0, 0.0, TAU, 32, Color(1.0, 0.78, 0.24, 0.45), 4.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(28, 42),
			"VICTORY REPLAY QA  |  %s  |  frame %04d" % [match_label, frame_index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			22,
			Color("eaf4ff")
		)


var _owner: LiveBattleOwner = null
var _registry := ModuleRegistry.new()
var _capture := VictoryHighlightFrameCaptureState.new()
var _recorder := VictoryHighlightRecorder.new()
var _playback := VictoryHighlightPlaybackState.new()
var _prewarm := BattleBootResourcePrewarmController.new()
var _match_flow := BattleSceneMatchFlowDriver.new()
var _frame_renderer := VictoryHighlightFrameRenderer.new()
var _base_renderer := VictoryHighlightRenderer.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		await _fail("live QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		await _fail("live QA requires Vulkan")
		return
	DisplayServer.window_set_size(Vector2i(1280, 900))
	_owner = LiveBattleOwner.new()
	_owner.name = "VictoryHighlightFallbackLiveBattle"
	root.add_child(_owner)
	_layout_owner()
	_registry.values = {
		"victory_highlight_frame_capture_state": _capture,
		"victory_highlight_recorder": _recorder,
		"victory_highlight_playback_state": _playback,
		"victory_highlight_frame_renderer": _frame_renderer,
		"victory_highlight_renderer": _base_renderer,
	}
	_recorder.reset()
	await _frames(8)
	if not await _prewarm_frame_lane(false):
		return
	if not await _record_match("extended", EXTENDED_MATCH_FRAMES, true):
		return
	var first_capture := await _start_and_capture_replay("extended_match_replay")
	if first_capture.is_empty():
		return
	_playback.reset()
	await _frames(4)
	_recorder.reset()
	_prewarm.set("stage_runtime_resources_prewarmed_for_stage", _owner.current_stage)
	var released: Dictionary = _capture.get_debug_snapshot()
	if bool(released.get("ready", true)) or int(released.get("owned_rid_count", -1)) != 0:
		await _fail("match release did not close the frame capture owner before rematch")
		return
	if not await _prewarm_frame_lane(true):
		return
	if not await _record_match("same_stage_rematch", REMATCH_FRAMES, false):
		return
	var second_capture := await _start_and_capture_replay("same_stage_rematch_replay")
	if second_capture.is_empty():
		return
	var final_snapshot: Dictionary = _capture.get_debug_snapshot()
	var playback_snapshot: Dictionary = _playback.get_host_debug_snapshot()
	print("[VictoryHighlightFallbackLiveQA] first_capture=%s" % first_capture)
	print("[VictoryHighlightFallbackLiveQA] second_capture=%s" % second_capture)
	print("[VictoryHighlightFallbackLiveQA] capture_snapshot=%s" % JSON.stringify(final_snapshot))
	print("[VictoryHighlightFallbackLiveQA] payload_log=%s" % str(playback_snapshot.get("payload_log", "")))
	print(
		"victory_highlight_fallback_live_qa: ok extended_frame_replay=1 same_stage_frame_replay=1 fallback_replays=0"
	)
	_playback.reset()
	await _shutdown(0)


func _layout_owner() -> void:
	var view_size := root.get_visible_rect().size
	var render_scale := minf(view_size.x / GAME_SIZE.x, view_size.y / GAME_SIZE.y)
	_owner.position = (view_size - GAME_SIZE * render_scale) * 0.5
	_owner.scale = Vector2.ONE * render_scale


func _prewarm_frame_lane(through_stage_gate: bool) -> bool:
	for _frame in range(PREWARM_TIMEOUT_FRAMES):
		var complete := false
		if through_stage_gate:
			complete = bool(_prewarm.prewarm_stage_runtime_resources_step(
				_owner,
				Callable(_registry, "get_instance")
			))
		else:
			complete = bool(_prewarm.prewarm_victory_highlight_frame_lane_step(
				_owner,
				Callable(_registry, "get_instance")
			))
		_owner.queue_redraw()
		await process_frame
		if complete and bool(_capture.is_available()):
			print(
				"[VictoryHighlightFallbackLiveQA] prewarm through_stage_gate=%s snapshot=%s"
				% [str(through_stage_gate), JSON.stringify(_capture.get_debug_snapshot())]
			)
			return true
	await _fail("frame lane prewarm timed out through_stage_gate=%s" % str(through_stage_gate))
	return false


func _record_match(label: String, frame_count: int, deuce_mode: bool) -> bool:
	_owner.match_label = label
	var logical_time := 0.0
	var previous_ball_pos := _owner.ball_pos
	for frame_index in range(frame_count):
		logical_time = float(frame_index) / 60.0
		var phase := float(frame_index % 180) / 180.0
		var ball_pos := Vector2(
			90.0 + 580.0 * phase,
			375.0 + sin(float(frame_index) * 0.08) * 250.0
		)
		_owner.frame_index = frame_index
		_owner.ball_prev = previous_ball_pos
		_owner.ball_pos = ball_pos
		_owner.queue_redraw()
		_recorder.capture_visual(
			_build_actor_context(),
			_build_draw_context(ball_pos, previous_ball_pos),
			logical_time
		)
		previous_ball_pos = ball_pos
		await process_frame
	await _frames(8)
	var before_goal: Dictionary = _capture.get_debug_snapshot()
	if int(before_goal.get("capture_produced_count", 0)) <= 0:
		await _fail("%s produced no real frame captures" % label)
		return false
	_recorder.record_player_hit(Vector2(380.0, 690.0), "", logical_time - 0.5)
	var promoted := bool(_recorder.record_score_event(
		"player",
		{
			"player_score": 8 if deuce_mode else 5,
			"boss_score": 6 if deuce_mode else 0,
			"deuce_mode": deuce_mode,
			"match_finished": true,
		},
		24 if deuce_mode else 8,
		"player",
		"",
		logical_time
	))
	for _frame in range(24):
		_owner.queue_redraw()
		await process_frame
	var clips: Array[Dictionary] = _recorder.get_selected_victory_clips()
	if not promoted or clips.is_empty() or (clips[0].get("frame_frames", []) as Array).is_empty():
		await _fail("%s did not promote a frame-backed victory clip" % label)
		return false
	print(
		"[VictoryHighlightFallbackLiveQA] match=%s produced=%d clip_frames=%d fallback_reason=%s"
		% [
			label,
			int(before_goal.get("capture_produced_count", 0)),
			(clips[0].get("frame_frames", []) as Array).size(),
			str(_capture.get_debug_snapshot().get("fallback_reason", "")),
		]
	)
	return true


func _build_actor_context() -> Dictionary:
	return {
		"player_pos": Vector2(292.0, 652.0),
		"player_paddle_size": Vector2(176.0, 50.0),
		"boss_pos": Vector2(292.0, 48.0),
		"boss_size": Vector2(176.0, 50.0),
	}


func _build_draw_context(ball_pos: Vector2, previous_ball_pos: Vector2) -> Dictionary:
	return {
		"ball_active": true,
		"ball_pos": ball_pos,
		"ball_pos_prev": previous_ball_pos,
		"ball_vel": (ball_pos - previous_ball_pos) * 60.0,
		"ball_render_radius": 18.0,
		"physics_accumulator": 0.0,
		"physics_dt": 1.0 / 60.0,
	}


func _start_and_capture_replay(label: String) -> String:
	var started := bool(_match_flow.call(
		"_try_start_victory_presentation",
		_registry,
		_owner,
		Callable()
	))
	if not started or not bool(_playback.is_active()):
		await _fail("%s did not start through the production victory ladder" % label)
		return ""
	for _frame in range(10):
		_playback.update(1.0 / 60.0)
		_owner.queue_redraw()
		await process_frame
	var playback_snapshot: Dictionary = _playback.get_host_debug_snapshot()
	if (
		str(playback_snapshot.get("renderer_key", "")) != "victory_highlight_frame_renderer"
		or not str(playback_snapshot.get("payload_log", "")).contains("frame")
	):
		await _fail("%s started the state fallback instead of frame replay" % label)
		return ""
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		await _fail("%s capture was empty" % label)
		return ""
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		await _fail("could not create live QA output directory")
		return ""
	var output_path := output_dir.path_join("%s.png" % label)
	if image.save_png(output_path) != OK:
		await _fail("could not save %s" % output_path)
		return ""
	return output_path


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _fail(message: String) -> void:
	print("[VictoryHighlightFallbackLiveQA] FAILURE: %s" % message)
	push_error(message)
	await _shutdown(1)


func _shutdown(exit_code: int) -> void:
	if _playback != null:
		_playback.reset()
	if _recorder != null:
		_recorder.reset()
	if _owner != null and is_instance_valid(_owner):
		_owner.queue_free()
	await _frames(6)
	_registry.values.clear()
	quit(exit_code)
