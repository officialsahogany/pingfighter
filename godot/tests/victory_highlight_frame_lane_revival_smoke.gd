extends SceneTree

const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const VictoryHighlightFrameCaptureState := preload("res://scripts/core/victory_highlight_frame_capture_state.gd")
const VictoryHighlightPlaybackState := preload("res://scripts/core/victory_highlight_playback_state.gd")
const VictoryHighlightRecorder := preload("res://scripts/core/victory_highlight_recorder.gd")

const EXPECTED_GOAL_RETRY_LIMIT := 30

var _failures: Array[String] = []
var _modules: Dictionary = {}


class TestOwner:
	extends Node2D
	var current_stage := 1
	var selected_character_type := "smasher"
	var victory_highlight_active := false

	func request_battle_redraw() -> void:
		queue_redraw()


class FakeRegistry:
	extends RefCounted
	var values: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = values.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class ContinueContextBuilder:
	extends RefCounted
	var recorder: Object = null
	var reset_controller: Object = MatchResetController.new()

	func build_match_flow_deps(
		_registry: Object,
		_current_stage: int,
		_perf_logger: Object,
		_perf_label_prefix: String,
		_include_all_stage_deps: bool,
		_character_type: String
	) -> Dictionary:
		return {
			"match_reset_controller": reset_controller,
			"victory_highlight_recorder": recorder,
		}


class ResetResultApplier:
	extends RefCounted
	var apply_calls := 0

	func apply_reset_result(_owner: Object, _result: Dictionary) -> void:
		apply_calls += 1


class LiveReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


class RevivalPrewarm:
	extends RefCounted
	var capture: Object = null
	var recorder: Object = null
	var calls := 0

	func prewarm_victory_highlight_frame_lane_step(owner: Object, _module_getter: Callable) -> bool:
		calls += 1
		if capture != null and capture.has_method("install_ready_capture_pipeline_for_tests"):
			capture.call("install_ready_capture_pipeline_for_tests", owner)
		if recorder != null and recorder.has_method("set_frame_capture_state"):
			recorder.set_frame_capture_state(capture)
		return capture != null and capture.has_method("is_available") and bool(capture.is_available())


class FakeDrawRenderer:
	extends RefCounted

	func draw(_canvas: CanvasItem, _playback: Object) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_continue_reset_self_heals_and_attaches_goal_frames()
	await _test_queued_goal_retry_driver_and_bounded_recovery()
	await _test_unprewarmed_lane_diagnostic_and_state_fallback()
	if _failures.is_empty():
		print("victory_highlight_frame_lane_revival_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		printerr("victory_highlight_frame_lane_revival_smoke: %s" % failure)
	quit(1)


func _test_continue_reset_self_heals_and_attaches_goal_frames() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var capture := VictoryHighlightFrameCaptureState.new()
	var recorder := VictoryHighlightRecorder.new()
	capture.install_owned_viewport_for_tests(owner)
	recorder.set_frame_capture_state(capture)
	_expect(capture.is_available(), "continue fixture must begin with a live frame lane")

	var context_builder := ContinueContextBuilder.new()
	context_builder.recorder = recorder
	var reset_applier := ResetResultApplier.new()
	var registry := FakeRegistry.new()
	registry.values = {
		"battle_update_context": context_builder,
		"match_flow_controller": MatchFlowController.new(),
		"battle_scene_match_reset_result_applier": reset_applier,
	}
	BattleSceneMatchFlowDriver.new().reset_for_continue(
		owner,
		registry,
		Callable(),
		Callable()
	)
	var released: Dictionary = capture.get_debug_snapshot()
	_expect(
		reset_applier.apply_calls == 1
		and not capture.is_available()
		and int(released.get("owned_rid_count", -1)) == 0,
		"real continue reset must release the recorder-owned frame viewport and ready state"
	)
	await process_frame

	var revival := RevivalPrewarm.new()
	revival.capture = capture
	revival.recorder = recorder
	_modules = {
		"battle_scene_readiness_controller": LiveReadiness.new(),
		"battle_boot_resource_prewarm_controller": revival,
		"victory_highlight_frame_capture_state": capture,
	}
	BattleSceneFrameController.new().process_idle(
		1.0 / 60.0,
		owner,
		registry,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_return_true"),
			"is_stage_landing_intro_started": Callable(self, "_return_true"),
		}
	)
	await process_frame
	_expect(
		revival.calls == 1 and capture.is_available(),
		"live process_idle must drive one frame-lane revival step after continue reset"
	)
	if not capture.is_available():
		_modules.clear()
		owner.queue_free()
		await process_frame
		return

	recorder.set_frame_capture_state(null)
	_record_state_goal_history(recorder, 1.0)
	recorder.set_frame_capture_state(capture)
	var frame := _make_frame()
	for index in range(60):
		capture.store_frame_for_tests(frame, 0.20 + float(index) / 72.0)
	var promoted := recorder.record_score_event(
		"player",
		{
			"player_score": 7,
			"boss_score": 5,
			"deuce_mode": false,
			"match_finished": true,
		},
		12,
		"player",
		"",
		1.0
	)
	if capture.has_method("force_pending_capture_success_for_tests"):
		capture.call("force_pending_capture_success_for_tests", frame)
	else:
		_expect(false, "revived capture lane must expose the pending-goal completion seam")
	var selected: Array[Dictionary] = recorder.get_selected_victory_clips()
	_expect(
		promoted
		and selected.size() == 1
		and not (selected[0].get("frame_frames", []) as Array).is_empty(),
		"the first post-continue player goal must attach real frame-lane payloads"
	)
	recorder.reset()
	_modules.clear()
	owner.queue_free()
	await process_frame


func _test_queued_goal_retry_driver_and_bounded_recovery() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var transient := VictoryHighlightFrameCaptureState.new()
	if not transient.has_method("install_ready_capture_pipeline_for_tests"):
		_expect(false, "capture state must expose a ready pipeline fixture for queued-goal recovery")
		owner.queue_free()
		await process_frame
		return
	transient.call("install_ready_capture_pipeline_for_tests", owner)
	var frame := _make_frame()
	for index in range(60):
		transient.store_frame_for_tests(frame, 0.20 + float(index) / 72.0)
	if not transient.has_method("force_queued_goal_viewport_degeneracy_for_tests"):
		_expect(false, "capture state must expose queued-goal viewport retry injection")
		transient.reset()
		owner.queue_free()
		await process_frame
		return
	transient.call("force_queued_goal_viewport_degeneracy_for_tests", 1)
	var descriptor := _goal_descriptor(41)
	transient.request_goal_capture(descriptor, [41])
	var queued: Dictionary = transient.get_debug_snapshot()
	_expect(
		bool(queued.get("queued_goal", false))
		and not bool(queued.get("pending_capture", true))
		and int(queued.get("viewport_retry_count", 0)) == 1,
		"a transient viewport degeneration must leave the final goal queued without failure"
	)
	transient.call("_on_frame_post_draw")
	var rearmed: Dictionary = transient.get_debug_snapshot()
	_expect(
		not bool(rearmed.get("queued_goal", true))
		and bool(rearmed.get("pending_capture", false)),
		"frame_post_draw must re-arm an idle queued goal after the viewport repairs"
	)
	if transient.has_method("force_pending_capture_success_for_tests"):
		transient.call("force_pending_capture_success_for_tests", frame)
	else:
		_expect(false, "queued goal retry must expose deterministic async completion")
	var selected: Array[Dictionary] = [{"id": 41}]
	_expect(
		transient.attach_frame_payloads(selected)
		and not (selected[0].get("frame_frames", []) as Array).is_empty(),
		"a repaired queued goal must terminate as exactly one promoted frame clip"
	)
	transient.reset()
	await process_frame

	var bounded := VictoryHighlightFrameCaptureState.new()
	bounded.call("install_ready_capture_pipeline_for_tests", owner)
	for index in range(60):
		bounded.store_frame_for_tests(frame, 0.20 + float(index) / 72.0)
	bounded.call("force_queued_goal_viewport_degeneracy_for_tests", EXPECTED_GOAL_RETRY_LIMIT)
	bounded.request_goal_capture(_goal_descriptor(42), [42])
	for _step in range(EXPECTED_GOAL_RETRY_LIMIT - 1):
		bounded.call("_on_frame_post_draw")
	var exhausted: Dictionary = bounded.get_debug_snapshot()
	var recovered: Array[Dictionary] = [{"id": 42}]
	_expect(
		int(exhausted.get("queued_goal_retry_limit", -1)) == EXPECTED_GOAL_RETRY_LIMIT
		and int(exhausted.get("viewport_retry_count", -1)) == EXPECTED_GOAL_RETRY_LIMIT
		and not bool(exhausted.get("queued_goal", true))
		and not bool(exhausted.get("pending_capture", true))
		and int(exhausted.get("frame_clip_count", 0)) == 1
		and bounded.attach_frame_payloads(recovered),
		"a permanently degenerate final goal must recover from the ring at the bounded retry limit"
	)
	bounded.reset()
	owner.queue_free()
	await process_frame


func _test_unprewarmed_lane_diagnostic_and_state_fallback() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var capture := VictoryHighlightFrameCaptureState.new()
	var recorder := VictoryHighlightRecorder.new()
	recorder.set_frame_capture_state(capture)
	_record_state_goal_history(recorder, 1.0)
	var promoted := recorder.record_score_event(
		"player",
		{
			"player_score": 7,
			"boss_score": 3,
			"deuce_mode": false,
			"match_finished": true,
		},
		8,
		"player",
		"",
		1.0
	)
	var clips: Array[Dictionary] = recorder.get_selected_victory_clips()
	var snapshot: Dictionary = capture.get_debug_snapshot()
	_expect(
		promoted
		and clips.size() == 1
		and (clips[0].get("frame_frames", []) as Array).is_empty()
		and str(snapshot.get("fallback_reason", "")) == "frame_lane_not_prewarmed",
		"an unprewarmed zero-attachment lane must preserve the state clip and record its exact fallback reason"
	)
	var registry := FakeRegistry.new()
	registry.values = {
		"victory_highlight_recorder": recorder,
		"victory_highlight_frame_capture_state": capture,
		"victory_highlight_frame_renderer": FakeDrawRenderer.new(),
		"victory_highlight_renderer": FakeDrawRenderer.new(),
	}
	var playback := VictoryHighlightPlaybackState.new()
	var started := playback.start(owner, registry, clips, Callable())
	var playback_snapshot: Dictionary = playback.get_host_debug_snapshot()
	_expect(
		started
		and str(playback_snapshot.get("renderer_key", "")) == "victory_highlight_renderer"
		and str(playback_snapshot.get("payload_log", "")).contains("last_fallback_reason=frame_lane_not_prewarmed"),
		"driver-disabled counterproof must choose the state replay renderer with actionable diagnostics"
	)
	playback.reset()
	recorder.reset()
	owner.queue_free()
	await process_frame


func _record_state_goal_history(recorder: Object, goal_sec: float) -> void:
	recorder.record_player_hit(Vector2(370.0, 690.0), "", goal_sec - 0.55)
	for index in range(60):
		var sample_sec := goal_sec - 0.80 + float(index) / 72.0
		var ball_pos := Vector2(250.0 + float(index) * 3.0, 620.0 - float(index) * 7.0)
		recorder.capture_visual(
			{
				"current_stage": 1,
				"selected_character_type": "smasher",
				"player_pos": Vector2(300.0, 690.0),
				"player_paddle_size": Vector2(160.0, 35.0),
				"boss_pos": Vector2(300.0, 25.0),
				"boss_paddle_size": Vector2(160.0, 35.0),
			},
			{
				"ball_active": true,
				"ball_pos": ball_pos,
				"ball_pos_prev": ball_pos,
				"ball_vel": Vector2(180.0, -240.0),
				"ball_render_radius": 18.0,
			},
			sample_sec
		)


func _goal_descriptor(clip_id: int) -> Dictionary:
	return {
		"id": clip_id,
		"capture_time_sec": 1.0,
		"goal_t_sec": 0.75,
		"duration_sec": 1.25,
		"is_final": true,
	}


func _make_frame() -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT)
	return frame


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	return value as Object if typeof(value) == TYPE_OBJECT else null


func _return_true() -> bool:
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
