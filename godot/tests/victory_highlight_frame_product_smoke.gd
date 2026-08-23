extends SceneTree

const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const VictoryHighlightFrameCaptureState := preload("res://scripts/core/victory_highlight_frame_capture_state.gd")
const VictoryHighlightFrameRenderer := preload("res://scripts/core/victory_highlight_frame_renderer.gd")
const VictoryHighlightPlaybackState := preload("res://scripts/core/victory_highlight_playback_state.gd")
const VictoryHighlightRecorder := preload("res://scripts/core/victory_highlight_recorder.gd")

var _failures: Array[String] = []
var _rewarm_modules: Dictionary = {}


class TestOwner:
	extends Node
	var victory_highlight_active := false
	var current_stage := 1


class FakeRegistry:
	extends RefCounted
	var values: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = values.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class FakeFrameCapture:
	extends RefCounted
	var capture_calls := 0
	var goal_calls := 0
	var payload_ready := true
	var requested_clip_ids: Array[int] = []

	func capture_visual(_logical_time_sec: float) -> bool:
		capture_calls += 1
		return true

	func request_goal_capture(clip: Dictionary, retained_ids: Array[int]) -> bool:
		goal_calls += 1
		requested_clip_ids = retained_ids.duplicate()
		return int(clip.get("id", -1)) >= 0

	func attach_frame_payloads(clips: Array[Dictionary]) -> bool:
		if not payload_ready:
			return false
		for clip in clips:
			clip["frame_frames"] = [PackedByteArray([1, 2, 3, 4])]
			clip["frame_size"] = Vector2i(1, 1)
			clip["frame_fps"] = VictoryHighlightFrameCaptureState.CAPTURE_FPS
		return true

	func release_match_clips() -> void:
		pass

	func reset() -> void:
		pass


class FakeRewarmFrameCapture:
	extends RefCounted
	var available := false
	var prewarm_calls := 0

	func is_available() -> bool:
		return available

	func prewarm_step(_owner: Object) -> bool:
		prewarm_calls += 1
		if prewarm_calls < 2:
			return false
		available = true
		return true


class FakeRewarmRecorder:
	extends RefCounted
	var attached_capture: Object = null
	var attach_calls := 0

	func set_frame_capture_state(frame_capture: Object) -> void:
		attached_capture = frame_capture
		attach_calls += 1


class FakeCaptureDiagnostics:
	extends RefCounted
	var fallback_reason := "async_capture_error"

	func get_debug_snapshot() -> Dictionary:
		return {"fallback_reason": fallback_reason}


class FakeDrawRenderer:
	extends RefCounted

	func draw(_canvas: CanvasItem, _playback: Object) -> void:
		pass


class FramePlaybackFixture:
	extends RefCounted
	var clip: Dictionary = {}
	var local_time_sec := 0.0

	func get_current_clip() -> Dictionary:
		return clip

	func get_clip_local_time() -> float:
		return local_time_sec


class FakeSelectionRecorder:
	extends RefCounted
	var clips: Array[Dictionary] = []
	var release_calls := 0

	func get_selected_victory_clips() -> Array[Dictionary]:
		return clips

	func release_match_clips() -> void:
		release_calls += 1


class FakePlayback:
	extends RefCounted
	var start_calls := 0

	func is_active() -> bool:
		return false

	func start(_owner: Object, _registry: Object, _clips: Array[Dictionary], _callback: Callable) -> bool:
		start_calls += 1
		return false


class FakeScoreboard:
	extends RefCounted

	func get_player_points() -> int:
		return 7

	func get_boss_points() -> int:
		return 5


class FakeLoot:
	extends RefCounted
	var start_calls := 0

	func is_active() -> bool:
		return false

	func start(_owner: Object, _registry: Object, _player: int, _boss: int, _finish: Callable) -> bool:
		start_calls += 1
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_registration()
	_test_resolution_and_memory_contract()
	_test_overlay_fade_contract()
	_test_render_rate_capture_schedule()
	_test_uniformity_metrics_negative_leg()
	_test_goal_hold_metrics_negative_leg()
	_test_shadow_lane_and_goal_promotion()
	_test_partial_frame_payload_attachment()
	_test_same_stage_frame_lane_rewarm()
	_test_real_playback_renderer_selection()
	_test_actual_frame_clip_promotion()
	_test_frame_failure_state_replay_to_loot()
	_test_empty_lane_falls_through_to_loot()
	_test_forced_capture_failures()
	_test_owned_resource_cleanup()
	if _failures.is_empty():
		print("victory_highlight_frame_product_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		printerr("victory_highlight_frame_product_smoke: %s" % failure)
	quit(1)


func _test_catalog_registration() -> void:
	var catalog := GameplayCoreModuleCatalog.new()
	for key in ["victory_highlight_frame_capture_state", "victory_highlight_frame_renderer"]:
		_expect(not catalog.get_spec(key).is_empty(), "gameplay module catalog must register %s" % key)


func _test_resolution_and_memory_contract() -> void:
	_expect(
		VictoryHighlightFrameCaptureState.CAPTURE_SIZE == Vector2i(760, 750),
		"product capture must use the 760x750 logical art resolution"
	)
	_expect(
		VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT == 2_280_000,
		"one 760x750 RGBA frame must be exactly 2,280,000 bytes"
	)
	_expect(
		VictoryHighlightFrameCaptureState.MAX_CAPTURE_HZ == 72.0
		and VictoryHighlightFrameCaptureState.CAPTURE_FPS == VictoryHighlightFrameCaptureState.MAX_CAPTURE_HZ,
		"capture and timestamp playback rate must share the 72Hz product authority"
	)
	_expect(
		VictoryHighlightFrameCaptureState.RING_SLOT_COUNT == 144,
		"the two-second product ring must derive to 144 slots at 72Hz"
	)
	_expect(
		VictoryHighlightFrameCaptureState.MAX_ACTION_SEC == 1.50
		and VictoryHighlightFrameCaptureState.GOAL_HOLD_SEC == 0.50
		and VictoryHighlightFrameCaptureState.MAX_CLIP_SEC == 2.0,
		"product timing authority must split 1.5 seconds of action from a 0.5-second synthetic goal hold"
	)
	_expect(
		VictoryHighlightFrameCaptureState.MAX_CLIP_FRAME_COUNT == 108,
		"the 1.5-second action window must derive with floor(1.5 * 72) = 108 stored frames"
	)
	_expect(
		VictoryHighlightFrameCaptureState.LOGICAL_MAX_FRAME_COUNT == 468,
		"the bounded 144-slot ring plus three 108-frame clips must total 468 logical frames"
	)
	_expect(
		VictoryHighlightFrameCaptureState.LOGICAL_MAX_BYTE_COUNT == 1_067_040_000,
		"the 760x750 72Hz logical memory contract must be exactly 1,067,040,000 bytes"
	)
	_expect(
		VictoryHighlightFrameRenderer.CAPTURE_SIZE == VictoryHighlightFrameCaptureState.CAPTURE_SIZE
		and VictoryHighlightFrameRenderer.CAPTURE_BYTE_COUNT == VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT,
		"playback ImageTexture dimensions must stay locked to the capture owner"
	)


func _test_overlay_fade_contract() -> void:
	var renderer := VictoryHighlightFrameRenderer.new()
	_expect(
		is_equal_approx(renderer.get_title_alpha_for_tests(0.0), 1.0)
		and is_equal_approx(renderer.get_title_alpha_for_tests(0.80), 1.0),
		"frame title must remain fully visible through the 0.8-second hold"
	)
	_expect(
		is_equal_approx(renderer.get_title_alpha_for_tests(0.925), 0.5)
		and is_zero_approx(renderer.get_title_alpha_for_tests(1.05))
		and is_zero_approx(renderer.get_title_alpha_for_tests(3.0)),
		"frame title must fade for 0.25 seconds and never reappear later on the global playback clock"
	)
	_expect(
		is_equal_approx(renderer.get_subtitle_alpha_for_tests(0.0), 1.0)
		and is_equal_approx(renderer.get_subtitle_alpha_for_tests(0.60), 1.0),
		"frame subtitle must remain fully visible for 0.6 seconds after each clip transition"
	)
	_expect(
		is_equal_approx(renderer.get_subtitle_alpha_for_tests(0.70), 0.5)
		and is_zero_approx(renderer.get_subtitle_alpha_for_tests(0.80)),
		"frame subtitle must fade to zero over the following 0.2 seconds"
	)
	var frame_renderer := VictoryHighlightFrameRenderer.new()
	_expect(
		frame_renderer.get_frame_content_rect_for_tests() == Rect2(Vector2.ZERO, Vector2(760.0, 750.0)),
		"frame replay destination must be the exact full 760x750 game canvas"
	)
	var scrims: Array[Rect2] = frame_renderer.get_overlay_scrim_rects_for_tests()
	_expect(
		scrims.size() == 2
		and scrims[0].get_area() + scrims[1].get_area() < 760.0 * 750.0 * 0.25,
		"frame copy readability must use two local scrims instead of a fullscreen dark veil"
	)


func _test_render_rate_capture_schedule() -> void:
	var stable_capture := VictoryHighlightFrameCaptureState.new()
	var stable_due := 0
	for index in range(144):
		if stable_capture.consume_capture_schedule_for_tests(float(index) / 72.0):
			stable_due += 1
	_expect(stable_due == 144, "Stable 72Hz input must make every render frame capture-due")
	var high_refresh_capture := VictoryHighlightFrameCaptureState.new()
	var high_refresh_due := 0
	for index in range(180):
		if high_refresh_capture.consume_capture_schedule_for_tests(float(index) / 90.0):
			high_refresh_due += 1
	_expect(high_refresh_due == 144, "90Hz input must be evenly capped to 72 capture requests over two seconds")


func _test_uniformity_metrics_negative_leg() -> void:
	var bytes := PackedByteArray()
	bytes.resize(VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT)
	var frames: Array[PackedByteArray] = [bytes, bytes, bytes]
	var clip := {
		"id": 72,
		"frame_frames": frames,
		"frame_fps": VictoryHighlightFrameCaptureState.CAPTURE_FPS,
		"frame_size": VictoryHighlightFrameCaptureState.CAPTURE_SIZE,
		"frame_data_format": RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	}
	var renderer := VictoryHighlightFrameRenderer.new()
	var clips: Array[Dictionary] = [clip]
	_expect(renderer.configure_for_clips(clips), "uniformity counterproof renderer must configure")
	var fixture := FramePlaybackFixture.new()
	fixture.clip = clip
	fixture.local_time_sec = 0.25 / VictoryHighlightFrameCaptureState.CAPTURE_FPS
	_expect(renderer.prepare_playback_frame(fixture), "uniformity counterproof first frame must upload")
	_expect(renderer.prepare_playback_frame(fixture), "uniformity counterproof repeated frame must remain drawable")
	fixture.local_time_sec = 2.25 / VictoryHighlightFrameCaptureState.CAPTURE_FPS
	_expect(renderer.prepare_playback_frame(fixture), "uniformity counterproof skipped frame must upload")
	var metrics: Dictionary = renderer.get_upload_metrics()
	_expect(int(metrics.get("repeated_frame_count", 0)) == 1, "uniformity seal must turn RED for one repeated display frame")
	_expect(int(metrics.get("skipped_frame_count", 0)) == 1, "uniformity seal must turn RED for one skipped capture frame")


func _test_goal_hold_metrics_negative_leg() -> void:
	var bytes := PackedByteArray()
	bytes.resize(VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT)
	var clip := {
		"id": 73,
		"duration_sec": VictoryHighlightFrameCaptureState.GOAL_HOLD_SEC,
		"goal_t_sec": 0.0,
		"frame_frames": [bytes],
		"frame_fps": VictoryHighlightFrameCaptureState.CAPTURE_FPS,
		"frame_size": VictoryHighlightFrameCaptureState.CAPTURE_SIZE,
		"frame_data_format": RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	}
	var renderer := VictoryHighlightFrameRenderer.new()
	var clips: Array[Dictionary] = [clip]
	_expect(renderer.configure_for_clips(clips), "goal-hold counterproof renderer must configure")
	var fixture := FramePlaybackFixture.new()
	fixture.clip = clip
	fixture.local_time_sec = 0.0
	_expect(renderer.prepare_playback_frame(fixture), "goal hold must display its final action frame")
	fixture.local_time_sec = VictoryHighlightFrameCaptureState.GOAL_HOLD_SEC - (1.0 / VictoryHighlightFrameCaptureState.CAPTURE_FPS)
	_expect(renderer.prepare_playback_frame(fixture), "goal hold must keep displaying through its final render tick")
	var metrics: Dictionary = renderer.get_upload_metrics()
	_expect(int(metrics.get("goal_hold_display_count", 0)) == 2, "goal-hold fixture must classify both display requests as hold time")
	_expect(int(metrics.get("goal_hold_advance_count", -1)) == 0, "goal hold must never advance the stored capture frame")
	_expect(int(metrics.get("repeated_frame_count", -1)) == 0, "synthetic hold must not pollute the real-action 1:1 repeat metric")


func _test_shadow_lane_and_goal_promotion() -> void:
	var recorder := VictoryHighlightRecorder.new()
	var frame_capture := FakeFrameCapture.new()
	recorder.set_frame_capture_state(frame_capture)
	_record_goal(recorder, 1.0, 2, false, false, "clutch_first")
	_record_goal(recorder, 2.0, 9, false, false, "")
	_record_goal(recorder, 3.0, 6, false, false, "clutch_tie")
	_record_goal(recorder, 4.0, 12, false, false, "")
	_record_goal(recorder, 5.0, 3, true, true, "frame_finisher")
	var promoted: Array[Dictionary] = recorder.get_promoted_clips_for_tests()
	_expect(promoted.size() == 5, "frame lane must not suppress shadow-state promotion for any player goal")
	_expect(frame_capture.goal_calls == 5 and frame_capture.capture_calls > 0, "every player goal must request a frame clip while continuous capture stays active")
	_expect(frame_capture.requested_clip_ids.size() <= 3, "online frame candidates must stay bounded to three retained clip ids")
	var selected: Array[Dictionary] = recorder.get_selected_victory_clips()
	var selected_ids: Array[int] = []
	for clip in selected:
		selected_ids.append(int(clip.get("id", -1)))
	selected_ids.sort()
	var retained_ids := frame_capture.requested_clip_ids.duplicate()
	retained_ids.sort()
	_expect(selected_ids == retained_ids, "online three-clip retention must exactly match final finisher/long-rally/clutch selection")
	_expect(not selected.is_empty() and not (selected[0].get("frame_frames", []) as Array).is_empty(), "healthy frame lane must attach frames to selected state clips")
	frame_capture.payload_ready = false
	selected = recorder.get_selected_victory_clips()
	_expect(not selected.is_empty() and (selected[0].get("samples", []) as Array).size() > 0, "runtime frame failure must leave complete state clips available")


func _test_partial_frame_payload_attachment() -> void:
	var capture := VictoryHighlightFrameCaptureState.new()
	capture.install_frame_clip_for_tests(1, [PackedByteArray([1, 2, 3, 4])])
	var clips: Array[Dictionary] = [
		{"id": 1, "samples": [{"t_sec": 0.0}]},
		{"id": 2, "samples": [{"t_sec": 0.0}]},
	]
	_expect(capture.attach_frame_payloads(clips), "one healthy frame candidate must keep mixed playback eligible")
	_expect(
		not (clips[0].get("frame_frames", []) as Array).is_empty()
		and (clips[1].get("frame_frames", []) as Array).is_empty(),
		"partial frame availability must attach per clip while preserving the missing clip's state lane"
	)
	capture.reset()


func _test_real_playback_renderer_selection() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new()
	registry.values = {
		"victory_highlight_frame_renderer": FakeDrawRenderer.new(),
		"victory_highlight_renderer": FakeDrawRenderer.new(),
		"victory_highlight_recorder": FakeSelectionRecorder.new(),
		"victory_highlight_frame_capture_state": FakeCaptureDiagnostics.new(),
	}
	var playback := VictoryHighlightPlaybackState.new()
	var state_clip := _fixture_clip()
	var frame_clip := state_clip.duplicate(true)
	frame_clip["frame_frames"] = [PackedByteArray([1, 2, 3, 4])]
	var frame_clips: Array[Dictionary] = [frame_clip]
	_expect(playback.start(owner, registry, frame_clips, Callable()), "real playback start must accept frame-backed clips")
	_expect(str(playback.get_host_debug_snapshot().get("renderer_key", "")) == "victory_highlight_frame_renderer", "frame-backed clips must choose the frame renderer at the single start lookup")
	var frame_host: Dictionary = playback.get_host_debug_snapshot()
	_expect(
		str(frame_host.get("payload_log", "")).contains("clip_payloads=0:1:frame")
		and str(frame_host.get("payload_log", "")).contains("last_fallback_reason=async_capture_error"),
		"playback start must expose per-clip payload presence and the last frame fallback reason"
	)
	_expect(
		str(frame_host.get("current_content_mode", "")) == "frame_full_canvas"
		and frame_host.get("frame_content_position", Vector2.ONE) == Vector2.ZERO
		and frame_host.get("frame_content_size", Vector2.ZERO) == Vector2(760.0, 750.0),
		"frame playback host must expose one full-canvas content bridge"
	)
	playback.reset()
	var state_clips: Array[Dictionary] = [state_clip]
	_expect(playback.start(owner, registry, state_clips, Callable()), "real playback start must accept state-only fallback clips")
	_expect(str(playback.get_host_debug_snapshot().get("renderer_key", "")) == "victory_highlight_renderer", "state-only clips must choose the established state renderer")
	_expect(str(playback.get_host_debug_snapshot().get("current_content_mode", "")) == "state_band", "pure state fallback must retain the established content-band mode")
	playback.reset()
	var mixed_clips: Array[Dictionary] = [frame_clip, state_clip]
	_expect(playback.start(owner, registry, mixed_clips, Callable()), "mixed frame/state playback must start")
	_expect(
		str(playback.get_host_debug_snapshot().get("renderer_key", "")) == "victory_highlight_frame_renderer"
		and str(playback.get_host_debug_snapshot().get("current_content_mode", "")) == "frame_full_canvas",
		"one frame payload must select the hybrid renderer and begin in full-canvas mode"
	)
	playback.update(float(frame_clip.get("duration_sec", 0.80)))
	_expect(
		playback.get_current_clip_index() == 1
		and str(playback.get_host_debug_snapshot().get("current_content_mode", "")) == "state_band",
		"mixed playback must switch to the existing state-band mode on a state clip"
	)
	playback.reset()
	owner.free()


func _test_same_stage_frame_lane_rewarm() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var capture := FakeRewarmFrameCapture.new()
	var recorder := FakeRewarmRecorder.new()
	_rewarm_modules = {
		"victory_highlight_frame_capture_state": capture,
		"victory_highlight_recorder": recorder,
	}
	var controller := BattleBootResourcePrewarmController.new()
	controller.stage_runtime_resources_prewarmed_for_stage = owner.current_stage
	var first_complete := controller.prewarm_stage_runtime_resources_step(
		owner,
		Callable(self, "_get_rewarm_module")
	)
	_expect(
		not first_complete
		and capture.prewarm_calls == 1
		and recorder.attached_capture == capture,
		"same-stage match entry must reattach and resume an unavailable frame lane before declaring prewarm complete"
	)
	var second_complete := controller.prewarm_stage_runtime_resources_step(
		owner,
		Callable(self, "_get_rewarm_module")
	)
	_expect(
		second_complete
		and capture.prewarm_calls == 2
		and capture.available
		and recorder.attach_calls >= 2,
		"same-stage frame-lane rewarm must finish through the production staged prewarm API"
	)
	_rewarm_modules.clear()
	owner.free()


func _test_empty_lane_falls_through_to_loot() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new()
	var recorder := FakeSelectionRecorder.new()
	var loot := FakeLoot.new()
	registry.values = {
		"scoreboard_state": FakeScoreboard.new(),
		"victory_highlight_recorder": recorder,
		"victory_highlight_playback_state": FakePlayback.new(),
		"victory_loot_phase_state": loot,
	}
	var driver := BattleSceneMatchFlowDriver.new()
	driver.apply_scoreboard_update_result(
		ScoreboardState.UPDATE_RESET_GAME,
		registry,
		owner,
		Callable(),
		Callable()
	)
	_expect(recorder.release_calls == 1 and loot.start_calls == 1, "when both lanes are empty the victory ladder must release replay data and continue to loot")
	owner.free()


func _test_frame_failure_state_replay_to_loot() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var recorder := VictoryHighlightRecorder.new()
	var unavailable_frame_lane := FakeFrameCapture.new()
	unavailable_frame_lane.payload_ready = false
	recorder.set_frame_capture_state(unavailable_frame_lane)
	_record_goal(recorder, 1.0, 5, true, false, "")
	var playback := VictoryHighlightPlaybackState.new()
	var loot := FakeLoot.new()
	var registry := FakeRegistry.new()
	registry.values = {
		"scoreboard_state": FakeScoreboard.new(),
		"victory_highlight_recorder": recorder,
		"victory_highlight_playback_state": playback,
		"victory_highlight_renderer": FakeDrawRenderer.new(),
		"victory_loot_phase_state": loot,
	}
	var driver := BattleSceneMatchFlowDriver.new()
	driver.apply_scoreboard_update_result(
		ScoreboardState.UPDATE_RESET_GAME,
		registry,
		owner,
		Callable(),
		Callable()
	)
	_expect(playback.is_active(), "frame startup/runtime failure must still start the shadow-state replay")
	_expect(str(playback.get_host_debug_snapshot().get("renderer_key", "")) == "victory_highlight_renderer", "failed frame lane must choose the state renderer")
	playback.update(4.0)
	_expect(not playback.is_active(), "state fallback replay must complete its normalized timeline")
	_expect(loot.start_calls == 1, "state fallback completion must continue to loot without softlock")
	owner.free()


func _test_actual_frame_clip_promotion() -> void:
	var capture := VictoryHighlightFrameCaptureState.new()
	var bytes := PackedByteArray()
	bytes.resize(VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT)
	for index in range(VictoryHighlightFrameCaptureState.RING_SLOT_COUNT):
		capture.store_frame_for_tests(bytes, float(index) / VictoryHighlightFrameCaptureState.CAPTURE_FPS)
	capture.promote_goal_for_tests({
		"clip_id": 7,
		"goal_sec": 1.96,
		"goal_t_sec": VictoryHighlightFrameCaptureState.MAX_ACTION_SEC,
		"duration_sec": VictoryHighlightFrameCaptureState.MAX_CLIP_SEC,
	}, [7])
	var selected: Array[Dictionary] = [{"id": 7}]
	_expect(capture.attach_frame_payloads(selected), "actual CPU-ring owner must attach a promoted frame clip")
	_expect(
		(selected[0].get("frame_frames", []) as Array).size() == VictoryHighlightFrameCaptureState.MAX_CLIP_FRAME_COUNT,
		"maximum promoted frame clip must contain exactly floor(1.5 * 72) real-action frames"
	)
	var early_capture := VictoryHighlightFrameCaptureState.new()
	for index in range(30):
		early_capture.store_frame_for_tests(
			bytes,
			0.20 + float(index) / VictoryHighlightFrameCaptureState.CAPTURE_FPS
		)
	early_capture.promote_goal_for_tests({
		"clip_id": 70,
		"goal_sec": 0.60,
		"goal_t_sec": 0.40,
		"duration_sec": 0.90,
	}, [70])
	var early_selected: Array[Dictionary] = [{"id": 70}]
	_expect(early_capture.attach_frame_payloads(early_selected), "short ring history must still attach a non-empty frame clip")
	_expect(
		(early_selected[0].get("frame_frames", []) as Array).size()
		== int(floor(0.40 * VictoryHighlightFrameCaptureState.CAPTURE_FPS)),
		"early-goal frame clip must store only the action frames available from ring oldest"
	)
	early_capture.reset()
	for clip_id in [8, 9, 10, 11]:
		capture.promote_goal_for_tests({
			"clip_id": clip_id,
			"goal_sec": 1.96,
			"goal_t_sec": 0.75,
			"duration_sec": 1.0,
		}, [8, 9, 10, 11])
	_expect(
		int(capture.get_debug_snapshot().get("frame_clip_count", 0)) == VictoryHighlightFrameCaptureState.MAX_RETAINED_CLIP_COUNT,
		"capture owner must fail closed at three retained clips even when a caller supplies four ids"
	)
	capture.reset()


func _test_owned_resource_cleanup() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var capture := VictoryHighlightFrameCaptureState.new()
	capture.install_owned_viewport_for_tests(owner)
	capture.install_frame_clip_for_tests(1, [PackedByteArray([1, 2, 3, 4])])
	_expect(int(capture.get_debug_snapshot().get("owned_rid_count", 0)) == 1, "cleanup fixture must own a real SubViewport RID before reset")
	capture.reset()
	var released: Dictionary = capture.get_debug_snapshot()
	_expect(int(released.get("owned_rid_count", -1)) == 0 and int(released.get("frame_clip_count", -1)) == 0, "match reset must release every owned frame RID and clip reference")
	owner.free()


func _test_forced_capture_failures() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var startup := VictoryHighlightFrameCaptureState.new()
	startup.force_startup_failure_for_tests(true)
	_expect(startup.prewarm_step(owner), "forced startup failure must terminate prewarm instead of stalling the loading gate")
	var startup_debug: Dictionary = startup.get_debug_snapshot()
	_expect(bool(startup_debug.get("failed", false)) and int(startup_debug.get("owned_rid_count", -1)) == 0, "forced startup failure must fail closed with zero owned RIDs")
	var runtime := VictoryHighlightFrameCaptureState.new()
	runtime.install_owned_viewport_for_tests(owner)
	runtime.install_frame_clip_for_tests(1, [PackedByteArray([1, 2, 3, 4])])
	runtime.force_runtime_failure_for_tests()
	var runtime_debug: Dictionary = runtime.get_debug_snapshot()
	_expect(bool(runtime_debug.get("failed", false)) and int(runtime_debug.get("owned_rid_count", -1)) == 0, "forced runtime failure must discard frame resources for state fallback")
	_expect(int(runtime_debug.get("frame_clip_count", -1)) == 1, "forced runtime failure must preserve already-promoted frame clips")
	owner.free()


func _get_rewarm_module(key: String) -> Object:
	var value: Variant = _rewarm_modules.get(key, null)
	return value as Object if typeof(value) == TYPE_OBJECT else null


func _record_goal(
	recorder: Object,
	goal_sec: float,
	rally_count: int,
	is_final: bool,
	deuce_mode: bool,
	skill_tag: String
) -> void:
	recorder.record_player_hit(Vector2(370.0, 700.0), skill_tag, goal_sec - 0.70)
	for index in range(59):
		var time_sec := goal_sec - 0.80 + float(index) / 72.0
		var ball_pos := Vector2(260.0 + float(index) * 2.0, 610.0 - float(index) * 8.0)
		recorder.capture_visual(_actor_context(), {
			"ball_active": true,
			"ball_pos": ball_pos,
			"ball_pos_prev": ball_pos,
			"ball_vel": Vector2(180.0, -240.0),
			"ball_render_radius": 18.0,
		}, time_sec)
	recorder.record_score_event("player", {
		"player_score": 7 if is_final else 4,
		"boss_score": 5 if is_final else 3,
		"deuce_mode": deuce_mode,
		"match_finished": is_final,
	}, rally_count, "player", skill_tag, goal_sec)


func _actor_context() -> Dictionary:
	return {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"player_pos": Vector2(300.0, 690.0),
		"player_paddle_size": Vector2(160.0, 35.0),
		"boss_pos": Vector2(300.0, 25.0),
		"boss_paddle_size": Vector2(160.0, 35.0),
	}


func _fixture_clip() -> Dictionary:
	return {
		"id": 1,
		"duration_sec": 0.80,
		"goal_t_sec": 0.55,
		"samples": [{"t_sec": 0.0, "ball_pos": Vector2(320.0, 500.0)}],
		"events": [],
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
