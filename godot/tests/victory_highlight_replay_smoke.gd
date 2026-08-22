extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const VictoryHighlightActorResolver := preload("res://scripts/core/victory_highlight_actor_resolver.gd")
const VictoryHighlightPlaybackState := preload("res://scripts/core/victory_highlight_playback_state.gd")
const VictoryHighlightRecorder := preload("res://scripts/core/victory_highlight_recorder.gd")
const VictoryHighlightRenderer := preload("res://scripts/core/victory_highlight_renderer.gd")

var _failures: Array[String] = []
var _finish_calls := 0


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


class FakeAudio:
	extends RefCounted
	var transition_calls := 0
	var impact_calls := 0
	var stop_calls := 0

	func play_ui_confirm() -> void:
		transition_calls += 1

	func play_power_smash() -> void:
		impact_calls += 1

	func play_victory_highlight_transition() -> void:
		transition_calls += 1

	func play_victory_highlight_impact() -> void:
		impact_calls += 1

	func stop_stage2_quake_loop() -> void:
		stop_calls += 1


class FakeScoreboard:
	extends RefCounted
	var player_points := 7
	var boss_points := 5
	var start_calls := 0

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return 7

	func get_last_scoring_side() -> String:
		return "player"

	func start(_player: int, _boss: int, _finished: bool, _side: String) -> void:
		start_calls += 1


class FakeScoreState:
	extends RefCounted
	var player_score := 0
	var boss_score := 0

	func force_score(next_player: int, next_boss: int) -> Dictionary:
		player_score = next_player
		boss_score = next_boss
		return {"player_score": player_score, "boss_score": boss_score, "match_finished": true}


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
	var active := false
	var finish_callback := Callable()

	func is_active() -> bool:
		return active

	func start(_owner: Object, _registry: Object, clips: Array[Dictionary], callback: Callable) -> bool:
		start_calls += 1
		finish_callback = callback
		active = not clips.is_empty()
		return active

	func finish_for_tests() -> void:
		active = false
		var callback := finish_callback
		finish_callback = Callable()
		if callback.is_valid():
			callback.call()

	func reset() -> void:
		active = false
		finish_callback = Callable()


class FakeLoot:
	extends RefCounted
	var start_calls := 0
	var start_result := false

	func is_active() -> bool:
		return false

	func start(
		_owner: Object,
		_registry: Object,
		_player_points: int,
		_boss_points: int,
		_finish_callback: Callable
	) -> bool:
		start_calls += 1
		return start_result


class FakeResultScreen:
	extends RefCounted
	var show_calls := 0
	var show_result := false

	func show_from_scoreboard(
		_owner: Object,
		_registry: Object,
		_reset_callback: Callable,
		_exit_callback: Callable
	) -> bool:
		show_calls += 1
		return show_result


class FakeContextBuilder:
	extends RefCounted

	func build_match_flow_deps(
		registry: Object,
		_current_stage: int,
		_perf_logger: Object,
		_perf_prefix: String,
		_include_all: bool,
		_character_type: String
	) -> Dictionary:
		return {"scoreboard_state": registry.get_instance("scoreboard_state")}


class FakeMatchFlow:
	extends RefCounted
	var presentation_key_seen := false

	func update_scoreboard(
		_delta: float,
		_deps: Dictionary,
		callbacks: Dictionary,
		_config: Dictionary
	) -> void:
		presentation_key_seen = callbacks.has("try_start_victory_presentation")
		if presentation_key_seen:
			callbacks["try_start_victory_presentation"].call()


class CountingPlayback:
	extends RefCounted
	var update_calls := 0

	func is_active() -> bool:
		return true

	func update(_delta: float) -> void:
		update_calls += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_and_owner_schema()
	_test_localization_lockstep()
	_test_fail_closed_actor_contracts()
	_test_uniform_content_transform()
	var fixture := _make_actor_fixture()
	var actor_context: Dictionary = fixture["actor_context"]
	var texture: Texture2D = fixture["texture"]
	_test_final_actor_context_capture(actor_context)
	_test_rate_invariance_and_time_eviction(actor_context)
	_test_selection_stream_merge_and_hold(actor_context)
	_test_goal_lookback_anchor_and_early_oldest(actor_context)
	_test_selected_clip_pose_coverage()
	_test_release(actor_context, texture)
	_test_host_skip_f9_and_reset()
	_test_two_victory_intercepts_and_fallback()
	_test_frame_gate()
	actor_context.clear()
	fixture.clear()
	texture = null
	if _failures.is_empty():
		print("victory_highlight_replay_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		printerr("victory_highlight_replay_smoke: %s" % failure)
	quit(1)


func _test_catalog_and_owner_schema() -> void:
	var catalog := GameplayCoreModuleCatalog.new()
	for key in [
		"victory_highlight_recorder",
		"victory_highlight_actor_resolver",
		"victory_highlight_playback_state",
		"victory_highlight_renderer",
	]:
		_expect(not catalog.get_spec(key).is_empty(), "catalog must register %s" % key)
	_expect(BattleSceneState.DEFAULT_VALUES.has("victory_highlight_active"), "owner schema must declare victory_highlight_active")
	_expect(VictoryHighlightRenderer.new() != null, "renderer script must compile")
	_expect(VictoryHighlightActorResolver != null, "actor resolver script must compile")


func _test_localization_lockstep() -> void:
	var keys := [
		"victory_highlight_title",
		"victory_highlight_finisher",
		"victory_highlight_long_rally",
		"victory_highlight_clutch",
		"victory_highlight_skip_hint",
	]
	var expected_skip_hints := {
		LanguageSettingsData.LANGUAGE_KOREAN: "길게 눌러 건너뛰기",
		LanguageSettingsData.LANGUAGE_ENGLISH: "Hold to skip",
		LanguageSettingsData.LANGUAGE_CHINESE: "长按跳过",
		LanguageSettingsData.LANGUAGE_JAPANESE: "長押しでスキップ",
		LanguageSettingsData.LANGUAGE_SPANISH: "Mantén pulsado para omitir",
		LanguageSettingsData.LANGUAGE_PORTUGUESE_BRAZIL: "Segure para pular",
		LanguageSettingsData.LANGUAGE_RUSSIAN: "Удерживайте, чтобы пропустить",
	}
	for language in [
		LanguageSettingsData.LANGUAGE_KOREAN,
		LanguageSettingsData.LANGUAGE_ENGLISH,
		LanguageSettingsData.LANGUAGE_CHINESE,
		LanguageSettingsData.LANGUAGE_JAPANESE,
		LanguageSettingsData.LANGUAGE_SPANISH,
		LanguageSettingsData.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettingsData.LANGUAGE_RUSSIAN,
	]:
		var table: Dictionary = LanguageSettingsData.TEXT.get(language, {})
		for key in keys:
			_expect(table.has(key) and not str(table.get(key, "")).is_empty(), "highlight copy key %s must stay in 7-language lockstep (%s)" % [key, language])
		_expect(str(table.get("victory_highlight_skip_hint", "")) == str(expected_skip_hints.get(language, "")), "hold-skip hint must use the approved copy in %s" % language)
	var korean_hint := str((LanguageSettingsData.TEXT.get(LanguageSettingsData.LANGUAGE_KOREAN, {}) as Dictionary).get("victory_highlight_skip_hint", ""))
	_expect(not korean_hint.contains("—"), "Korean hold-skip copy must not contain an em dash")


func _test_fail_closed_actor_contracts() -> void:
	var foreign_texture := _make_test_texture(Vector2i(64, 32), Color(0.2, 0.5, 1.0, 1.0))
	var slot: Dictionary = {}

	var non_walk_4x2 := _resolver_actor_context()
	non_walk_4x2["boss_dash_active"] = true
	non_walk_4x2["boss_dash_sheet"] = foreign_texture
	non_walk_4x2["boss_dash_frame"] = 3
	VictoryHighlightActorResolver.resolve_into(non_walk_4x2, slot)
	_expect(slot.get("boss_texture", null) == null, "4x2 non-walk boss sheet must fail closed to silhouette without a pose grid contract")
	_expect((slot.get("boss_src", Rect2()) as Rect2).size == Vector2.ZERO, "non-walk silhouette must not retain a guessed 4x4 source cell")
	_expect((slot.get("boss_dest", Rect2()) as Rect2).size.length() > 0.0, "non-walk fail-closed path must retain boss geometry for silhouette rendering")
	_expect(str(slot.get("boss_pose", "")) == "dash", "coverage metadata must identify a shared dash pose")
	_expect(str(slot.get("boss_resolution", "")) == "silhouette_unsupported_pose", "dash without a pose contract must be measured as an unsupported-pose silhouette")

	var missing_walk_sheet := _resolver_actor_context()
	missing_walk_sheet["boss_is_walking"] = true
	missing_walk_sheet["boss_facing"] = 1
	missing_walk_sheet["boss_walk_frame_count"] = 8
	missing_walk_sheet["boss_walk_grid_cols"] = 4
	missing_walk_sheet["boss_sprite_sheet"] = foreign_texture
	VictoryHighlightActorResolver.resolve_into(missing_walk_sheet, slot)
	_expect(slot.get("boss_texture", null) == null, "missing selected walk sheet must not leak through boss_sprite_sheet")
	_expect(str(slot.get("boss_resolution", "")) == "silhouette_missing_texture", "walk with an explicit grid but no owned directional sheet must report missing texture")

	var valid_walk := _resolver_actor_context()
	valid_walk["boss_is_walking"] = true
	valid_walk["boss_facing"] = 1
	valid_walk["boss_walk_right_sheet"] = foreign_texture
	valid_walk["boss_walk_frame_count"] = 8
	valid_walk["boss_walk_grid_cols"] = 4
	VictoryHighlightActorResolver.resolve_into(valid_walk, slot)
	_expect(slot.get("boss_texture", null) == foreign_texture, "walk sheet with explicit frame/grid metadata must remain eligible for real-sheet replay")
	_expect((slot.get("boss_src", Rect2()) as Rect2).size == Vector2(16.0, 16.0), "valid 4x2 walk contract must resolve its real 16x16 cell")
	_expect(str(slot.get("boss_pose", "")) == "walk" and str(slot.get("boss_resolution", "")) == "sheet", "valid walk metadata must report an exact sheet resolution")

	var private_attack_walk := valid_walk.duplicate()
	private_attack_walk["current_stage"] = 7
	private_attack_walk["stage7_akamu_boss_attack_active"] = true
	VictoryHighlightActorResolver.resolve_into(private_attack_walk, slot)
	_expect(slot.get("boss_texture", null) == foreign_texture, "measurement metadata must not change the existing slice-1 walk rendering decision")
	_expect(str(slot.get("boss_pose", "")) == "attack" and str(slot.get("boss_pose_source", "")) == "stage_hint", "Stage 7 public attack state must be measured as an attack hint")
	_expect(str(slot.get("boss_resolution", "")) == "sheet_pose_mismatch", "a walk sheet drawn during a public attack pose must not count as successful sheet coverage")

	var player_without_grid := _resolver_actor_context()
	player_without_grid["commando_weapon_fire_active"] = true
	player_without_grid["commando_weapon_fire_sheet"] = foreign_texture
	VictoryHighlightActorResolver.resolve_into(player_without_grid, slot)
	_expect(slot.get("player_texture", null) == null, "player pose without renderer-facing grid metadata must fail closed to silhouette")
	_expect((slot.get("player_dest", Rect2()) as Rect2).size.length() > 0.0, "player fail-closed path must retain actor geometry for silhouette rendering")

	var commando_flip := _resolver_actor_context()
	commando_flip["commando_weapon_fire_active"] = true
	commando_flip["commando_weapon_fire_sheet"] = foreign_texture
	commando_flip["commando_weapon_fire_frame"] = 0
	commando_flip["commando_weapon_fire_frame_count"] = 8
	commando_flip["commando_weapon_fire_grid_cols"] = 4
	commando_flip["commando_weapon_fire_grid_rows"] = 2
	commando_flip["commando_weapon_fire_flip_h"] = true
	VictoryHighlightActorResolver.resolve_into(commando_flip, slot)
	_expect(slot.get("player_texture", null) == foreign_texture, "commando flip fixture must retain its real sheet when the grid contract is explicit")
	_expect(bool(slot.get("player_flip", false)), "commando weapon-fire fixture must keep the reachable player flip flag")
	_expect((slot.get("player_src", Rect2()) as Rect2).size == Vector2(16.0, 16.0), "commando flip fixture must resolve the contracted 4x2 source cell")

	var stage5_foreign_fallback := _resolver_actor_context()
	stage5_foreign_fallback["current_stage"] = 5
	stage5_foreign_fallback["boss_idle_sheet"] = foreign_texture
	stage5_foreign_fallback["boss_sprite_sheet"] = foreign_texture
	VictoryHighlightActorResolver.resolve_into(stage5_foreign_fallback, slot)
	_expect(slot.get("boss_texture", null) == null, "Stage 5 foreign idle/generic fixture must render a silhouette instead of another stage boss")
	_expect(not bool(slot.get("boss_pose_observable", true)) and str(slot.get("boss_pose", "")) == "idle_or_renderer_internal", "context-free idle/turn timers must stay explicitly ambiguous instead of being guessed as idle")

	foreign_texture = null


func _test_uniform_content_transform() -> void:
	var renderer := VictoryHighlightRenderer.new()
	var transform_debug: Dictionary = renderer.get_content_transform_for_tests()
	var scale: float = float(transform_debug.get("scale", 0.0))
	var content_rect: Rect2 = transform_debug.get("content_rect", Rect2())
	_expect(is_equal_approx(content_rect.position.y, 118.0) and is_equal_approx(content_rect.end.y, 678.0), "content transform must map the 760x750 source to the y=118..678 band")
	_expect(scale > 0.0 and scale < 1.0, "content transform must use one positive downscale")

	var ball := Vector2(380.0, 375.0)
	var player_rect := Rect2(290.0, 612.0, 160.0, 160.0)
	var boss_rect := Rect2(300.0, -10.0, 160.0, 160.0)
	var event_pos := Vector2(610.0, 22.0)
	var mapped_ball: Vector2 = renderer.transform_content_point_for_tests(ball)
	var mapped_player: Rect2 = renderer.transform_content_rect_for_tests(player_rect)
	var mapped_boss: Rect2 = renderer.transform_content_rect_for_tests(boss_rect)
	var mapped_event: Vector2 = renderer.transform_content_point_for_tests(event_pos)
	_expect(
		(mapped_player.get_center() - mapped_ball).is_equal_approx((player_rect.get_center() - ball) * scale)
		and (mapped_boss.get_center() - mapped_ball).is_equal_approx((boss_rect.get_center() - ball) * scale)
		and (mapped_event - mapped_ball).is_equal_approx((event_pos - ball) * scale),
		"ball, player paddle/actor, boss paddle/actor, and event marks must preserve every relative displacement under one affine transform"
	)
	_expect(
		mapped_player.size.is_equal_approx(player_rect.size * scale)
		and mapped_boss.size.is_equal_approx(boss_rect.size * scale),
		"actor extents must use the same scale as positions; per-actor clamps or resizes are forbidden"
	)
	_expect(
		renderer.transform_content_point_for_tests(Vector2.ZERO).is_equal_approx(content_rect.position)
		and renderer.transform_content_point_for_tests(Vector2(760.0, 750.0)).is_equal_approx(content_rect.end),
		"source playfield corners must land on the shared content band without per-element offsets"
	)

	# These are the observed live-QA envelopes from §11.0. They may extend a
	# few source pixels beyond y=0/750, but the one shared transform must still
	# keep visible replay content out of the title/subtitle and skip-copy glyphs.
	var top_event_y: float = renderer.transform_content_point_for_tests(event_pos - Vector2(0.0, 42.0)).y
	var bottom_ball_y: float = renderer.transform_content_point_for_tests(Vector2(380.0, 700.0 + 34.0 * 1.55)).y
	var visible_top: float = minf(mapped_boss.position.y, top_event_y)
	var visible_bottom: float = maxf(mapped_player.end.y, bottom_ball_y)
	_expect(visible_top > 102.0, "replay geometry must stay below the title/subtitle glyph band")
	_expect(visible_bottom < 696.0, "replay geometry must stay above the skip-hint glyph band")
	var hold_gauge: Rect2 = renderer.get_skip_hold_gauge_rect_for_tests()
	var half_fill: Rect2 = renderer.get_skip_hold_fill_rect_for_tests(0.5)
	_expect(hold_gauge.size.y >= 6.0, "hold progress must use a filled bar instead of a thin outline stroke")
	_expect(half_fill.position == hold_gauge.position and is_equal_approx(half_fill.size.x, hold_gauge.size.x * 0.5), "hold progress geometry must fill from 0 to 1 without moving its origin")


func _test_final_actor_context_capture(actor_context: Dictionary) -> void:
	_expect(actor_context.has("player_pos") and actor_context.has("boss_pos"), "real BattleDrawActorContext.build return must carry actor positions")
	var recorder := VictoryHighlightRecorder.new()
	var recorded: bool = recorder.capture_visual(actor_context, _draw_context(Vector2(380.0, 420.0)), 0.0)
	_expect(recorded, "recorder must accept the final BattleDrawActorContext.build return")
	var snapshot: Dictionary = recorder.get_debug_snapshot()
	_expect(int(snapshot.get("visual_count", 0)) == 1, "final actor context must reach the visual ring")


func _test_rate_invariance_and_time_eviction(actor_context: Dictionary) -> void:
	var durations: Array[float] = []
	for rate in [60.0, 72.0, 90.0]:
		var recorder := VictoryHighlightRecorder.new()
		recorder.record_player_hit(Vector2(360.0, 690.0), "", 0.10)
		_capture_range(recorder, actor_context, 0.0, 0.90, rate)
		recorder.record_score_event("player", _score_result(7, 5, true), 4, "player", "", 0.90)
		var clips: Array[Dictionary] = recorder.get_selected_victory_clips()
		_expect(clips.size() == 1, "rate fixture must produce one finisher at %.0f Hz" % rate)
		if not clips.is_empty():
			durations.append(float(clips[0].get("duration_sec", 0.0)))
	if durations.size() == 3:
		_expect(absf(durations[0] - durations[1]) < 0.02 and absf(durations[1] - durations[2]) < 0.02, "60/72/90 Hz capture must preserve wall-clock replay length")

	var evicting := VictoryHighlightRecorder.new()
	_capture_range(evicting, actor_context, 0.0, 2.60, 120.0)
	var times: Array[float] = evicting.get_visual_times_for_tests()
	_expect(not times.is_empty() and times[0] >= 0.59, "ring eviction must use capture time rather than physics/render frame count")
	_expect(times.size() <= VictoryHighlightRecorder.VISUAL_CAPACITY, "time ring must stay inside fixed preallocation")


func _test_selection_stream_merge_and_hold(actor_context: Dictionary) -> void:
	var ordinary := VictoryHighlightRecorder.new()
	_record_goal(ordinary, actor_context, 1.0, 2, true, false, "")
	var ordinary_clips: Array[Dictionary] = ordinary.get_selected_victory_clips()
	_expect(ordinary_clips.size() == 1 and str(ordinary_clips[0].get("label_key", "")) == VictoryHighlightRecorder.LABEL_FINISHER, "ordinary win must select only its final finisher")

	var dramatic := VictoryHighlightRecorder.new()
	_record_goal(dramatic, actor_context, 1.0, 2, false, false, "")
	_record_goal(dramatic, actor_context, 2.2, 10, false, false, "")
	_record_goal(dramatic, actor_context, 3.4, 4, false, true, "skill_finisher")
	_record_goal(dramatic, actor_context, 4.6, 3, true, false, "")
	var selected: Array[Dictionary] = dramatic.get_selected_victory_clips()
	_expect(selected.size() == 3, "long-rally plus clutch victory must select three distinct clips")
	if selected.size() == 3:
		_expect(float(selected[0].get("capture_time_sec", 0.0)) < float(selected[1].get("capture_time_sec", 0.0)) and float(selected[1].get("capture_time_sec", 0.0)) < float(selected[2].get("capture_time_sec", 0.0)), "selected clips must play chronologically")

	var stream_recorder := VictoryHighlightRecorder.new()
	stream_recorder.capture_visual(actor_context, _draw_context(Vector2(300.0, 400.0)), 0.0)
	stream_recorder.record_player_hit(Vector2(300.0, 700.0), "first", 0.10)
	stream_recorder.record_wall_hit(Vector2(5.0, 410.0), 0.11)
	stream_recorder.record_boss_hit(Vector2(330.0, 30.0), "", 0.12)
	stream_recorder.capture_visual(actor_context, _draw_context(Vector2(380.0, 100.0)), 0.30)
	stream_recorder.record_score_event("player", _score_result(7, 5, true), 7, "player", "first", 0.30)
	var merged: Array[Dictionary] = stream_recorder.get_selected_victory_clips()
	_expect(not merged.is_empty() and (merged[0].get("events", []) as Array).size() >= 4, "multiple physics events between visual frames must survive clip promotion")
	if not merged.is_empty():
		var samples: Array = merged[0].get("samples", [])
		var last_sample: Dictionary = samples[-1]
		_expect(is_equal_approx(float(last_sample.get("t_sec", 0.0)), float(merged[0].get("goal_t_sec", 0.0)) + VictoryHighlightRecorder.GOAL_HOLD_SEC), "clip must synthesize the +0.5s goal hold without future live samples")


func _test_goal_lookback_anchor_and_early_oldest(actor_context: Dictionary) -> void:
	var full_lookback := VictoryHighlightRecorder.new()
	_capture_range(full_lookback, actor_context, 0.0, 1.50, 72.0)
	full_lookback.record_player_hit(Vector2(370.0, 700.0), "late_hit", 1.40)
	full_lookback.record_score_event("player", _score_result(7, 5, true), 7, "player", "late_hit", 1.50)
	var full_clips: Array[Dictionary] = full_lookback.get_selected_victory_clips()
	_expect(full_clips.size() == 1, "full-lookback fixture must promote one finisher")
	if full_clips.size() == 1:
		var clip: Dictionary = full_clips[0]
		var samples: Array = clip.get("samples", [])
		_expect(not samples.is_empty() and is_zero_approx(float((samples[0] as Dictionary).get("t_sec", -1.0))), "goal lookback must begin 1.5 seconds before the goal instead of at the late player hit")
		_expect(is_equal_approx(float(clip.get("goal_t_sec", -1.0)), VictoryHighlightRecorder.MAX_ACTION_SEC), "full ring history must preserve exactly 1.5 seconds of real action")
		_expect(is_equal_approx(float(clip.get("duration_sec", -1.0)), VictoryHighlightRecorder.MAX_CLIP_SEC), "full lookback plus synthetic goal hold must total exactly 2.0 seconds")
		_expect(is_equal_approx(float(clip.get("last_player_hit_t_sec", -1.0)), 1.40), "last player hit must remain metadata without controlling the clip start anchor")
		var found_player_hit := false
		for event_value in clip.get("events", []):
			if event_value is Dictionary and int((event_value as Dictionary).get("kind", 0)) == VictoryHighlightRecorder.EVENT_PLAYER_HIT:
				found_player_hit = true
				break
		_expect(found_player_hit, "last player hit must remain an in-clip event marker after anchor decoupling")

	var early_goal := VictoryHighlightRecorder.new()
	_capture_range(early_goal, actor_context, 0.20, 0.60, 72.0)
	early_goal.record_player_hit(Vector2(370.0, 700.0), "early_hit", 0.55)
	early_goal.record_score_event("player", _score_result(7, 5, true), 3, "player", "early_hit", 0.60)
	var early_clips: Array[Dictionary] = early_goal.get_selected_victory_clips()
	_expect(early_clips.size() == 1, "an early goal with less than 1.5 seconds of ring history must still promote")
	if early_clips.size() == 1:
		var clip: Dictionary = early_clips[0]
		var samples: Array = clip.get("samples", [])
		_expect(not samples.is_empty() and is_zero_approx(float((samples[0] as Dictionary).get("t_sec", -1.0))), "short-history goal must start at the ring oldest sample")
		_expect(is_equal_approx(float(clip.get("goal_t_sec", -1.0)), 0.40), "short-history goal must preserve only the available real-action span")
		_expect(is_equal_approx(float(clip.get("duration_sec", -1.0)), 0.90), "short-history goal must append the exact 0.5-second synthetic hold")


func _test_selected_clip_pose_coverage() -> void:
	var recorder := VictoryHighlightRecorder.new()
	var pre_clip_idle := _resolver_actor_context()
	pre_clip_idle["current_stage"] = 5
	_capture_range(recorder, pre_clip_idle, 0.0, 0.60, 10.0)

	var clip_attack := pre_clip_idle.duplicate()
	clip_attack["boss_hit_active"] = true
	recorder.record_player_hit(Vector2(370.0, 700.0), "", 1.0)
	_capture_range(recorder, clip_attack, 0.80, 1.50, 10.0)
	recorder.record_score_event("player", _score_result(7, 5, true), 5, "player", "", 1.50)
	var selected: Array[Dictionary] = recorder.get_selected_victory_clips()
	var report: Dictionary = recorder.get_selected_pose_coverage_report()
	_expect(selected.size() == 1 and int(report.get("selected_clip_count", 0)) == 1, "pose coverage must aggregate only the selected finisher clip")
	if not selected.is_empty():
		_expect(is_equal_approx(float(report.get("weighted_sec", 0.0)), float(selected[0].get("duration_sec", -1.0))), "pose coverage weights must span the selected clip duration, including the synthetic goal hold")
	_expect(is_equal_approx(float(report.get("silhouette_ratio", 0.0)), 1.0), "attack-only selected clip must report full silhouette coverage while attack grids are unsupported")
	_expect(float(report.get("ambiguous_ratio", 0.0)) > 0.0, "goal-relative lookback must retain the earlier ambiguous idle/internal action context")
	var buckets: Array = report.get("buckets", [])
	_expect(buckets.size() == 2, "selected-clip pose coverage must include both early context and the goal attack pose")
	var found_ambiguous := false
	var found_attack := false
	for bucket_value in buckets:
		if not (bucket_value is Dictionary):
			continue
		var bucket: Dictionary = bucket_value as Dictionary
		if int(bucket.get("stage_id", 0)) != 5:
			continue
		if str(bucket.get("pose", "")) == "idle_or_renderer_internal":
			found_ambiguous = true
		elif str(bucket.get("pose", "")) == "attack":
			found_attack = str(bucket.get("resolution", "")) == "silhouette_unsupported_pose"
	_expect(found_ambiguous, "coverage buckets must preserve the earlier ambiguous renderer-internal context")
	_expect(found_attack, "coverage buckets must preserve the observed unsupported attack pose and failure reason")


func _test_release(actor_context: Dictionary, texture: Texture2D) -> void:
	var recorder := VictoryHighlightRecorder.new()
	var resolved := actor_context.duplicate()
	resolved["player_idle_sprite_texture"] = texture
	recorder.capture_visual(resolved, _draw_context(Vector2(360.0, 420.0)), 0.0)
	_expect(recorder.has_ring_texture_refs_for_tests(), "fixture must hold a texture reference before release")
	recorder.record_player_hit(Vector2(360.0, 700.0), "", 0.1)
	recorder.record_score_event("player", _score_result(7, 5, true), 2, "player", "", 0.3)
	recorder.release_match_clips()
	var debug: Dictionary = recorder.get_debug_snapshot()
	_expect(int(debug.get("clip_count", -1)) == 0 and not recorder.has_ring_texture_refs_for_tests(), "release must clear promoted clips and all ring texture references")


func _test_host_skip_f9_and_reset() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new()
	var recorder := VictoryHighlightRecorder.new()
	var replay_audio := FakeAudio.new()
	registry.values = {
		"victory_highlight_renderer": VictoryHighlightRenderer.new(),
		"victory_highlight_recorder": recorder,
		"game_audio": replay_audio,
	}
	var playback := VictoryHighlightPlaybackState.new()
	registry.values["victory_highlight_playback_state"] = playback
	var skip_clip := _fixture_clip()
	skip_clip["duration_sec"] = 4.0
	skip_clip["goal_t_sec"] = 3.5
	var skip_clips: Array[Dictionary] = [skip_clip]
	var clips: Array[Dictionary] = [_fixture_clip()]
	_expect(playback.start(owner, registry, skip_clips, Callable(self, "_on_finish")), "playback must start with a valid clipped host")
	_expect(replay_audio.stop_calls == 1 and replay_audio.transition_calls == 1, "replay entry must stop gameplay loops and emit only its dedicated transition cue")
	playback.sync_host_layout({"game_offset": Vector2(91.0, 37.0), "render_scale": 0.8})
	var host: Dictionary = playback.get_host_debug_snapshot()
	_expect(bool(host.get("clip_exists", false)) and bool(host.get("clip_contents", false)), "host must own an active clip_contents Control")
	_expect(host.get("clip_position", Vector2.ONE) == Vector2.ZERO and host.get("clip_size", Vector2.ZERO) == Vector2(760.0, 750.0), "clip rect must cover the full Godot playfield, including x=0..80 and x=680..760")
	_expect(bool(host.get("content_clip_exists", false)) and bool(host.get("content_clip_contents", false)), "host must clip every transformed replay primitive through one shared content Control")
	_expect(host.get("content_clip_position", Vector2.ONE) == Vector2(0.0, 118.0) and host.get("content_clip_size", Vector2.ZERO) == Vector2(760.0, 560.0), "shared content clip must preserve the 118..678 copy-safe band")
	_expect(str(host.get("current_content_mode", "")) == "state_band", "state-only replay must keep the established band presentation mode")
	_expect(not bool(host.get("host_process_enabled", true)), "controller-owned replay host must keep its own process disabled")
	_expect(owner.victory_highlight_active, "playback start must mirror the owner schema flag")

	var early_key := InputEventKey.new()
	early_key.pressed = true
	early_key.keycode = KEY_A
	_expect(not playback.handle_input(early_key) and playback.is_active(), "skip input must be ignored during the 0.15s entry guard")
	var f9 := InputEventKey.new()
	f9.pressed = true
	f9.keycode = KEY_F9
	_expect(not playback.handle_input(f9) and playback.is_active(), "F9 must pass through the replay input layer")
	playback.update(0.16)
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	_expect(playback.handle_input(mouse_down), "post-guard mouse press must begin the shared hold timer")
	playback.update(0.10)
	_expect(playback.is_active() and playback.get_skip_hold_progress() > 0.0, "a short mouse hold must show progress without skipping")
	_expect(playback.handle_input(mouse_up) and playback.is_active(), "a single click release before 0.6s must not skip")
	_expect(is_zero_approx(playback.get_skip_hold_progress()), "early mouse release must reset hold progress")

	_expect(playback.handle_input(early_key), "post-guard key press must begin the shared hold timer")
	playback.update(VictoryHighlightPlaybackState.SKIP_HOLD_SEC - 0.01)
	_expect(playback.is_active() and playback.get_skip_hold_progress() > 0.98, "a 0.59s key hold must remain below the skip threshold")
	var key_up := InputEventKey.new()
	key_up.pressed = false
	key_up.keycode = KEY_A
	_expect(playback.handle_input(key_up) and playback.is_active(), "release below 0.6s must cancel the key hold")
	_expect(is_zero_approx(playback.get_skip_hold_progress()), "early key release must reset hold progress")

	_expect(playback.handle_input(early_key), "second key press must restart hold progress from zero")
	playback.update(VictoryHighlightPlaybackState.SKIP_HOLD_SEC)
	_expect(not playback.is_active(), "a 0.6s key hold must skip the entire presentation")
	_expect(_finish_calls == 1 and not owner.victory_highlight_active, "hold skip must finish once, invoke the continuation callback, and clear the owner flag")
	_expect(not bool(playback.get_host_debug_snapshot().get("host_exists", true)), "normal finish must detach the fx host")

	var boundary_clips: Array[Dictionary] = [_fixture_clip(), _fixture_clip()]
	_expect(playback.start(owner, registry, boundary_clips, Callable()), "playback must restart for cross-clip hold coverage")
	playback.update(1.35)
	_expect(playback.handle_input(early_key), "hold must begin before a clip boundary")
	playback.update(0.10)
	_expect(playback.get_current_clip_index() == 1 and playback.get_skip_hold_progress() > 0.16, "hold progress must continue across clip boundaries on the global playback clock")
	_expect(playback.handle_input(key_up) and is_zero_approx(playback.get_skip_hold_progress()), "cross-clip release must reset the same global hold timer")
	playback.reset()

	_expect(playback.start(owner, registry, clips, Callable()), "playback must be restartable for reset coverage")
	MatchResetController.new().reset_game({
		"victory_highlight_playback_state": playback,
		"victory_highlight_recorder": recorder,
	}, {})
	_expect(not playback.is_active() and not owner.victory_highlight_active, "match reset must stop playback and clear its owner flag")
	_expect(not bool(playback.get_host_debug_snapshot().get("host_exists", true)), "match reset must detach the fx host")

	var crossfade_clips: Array[Dictionary] = [_fixture_clip(), _fixture_clip()]
	_expect(playback.start(owner, registry, crossfade_clips, Callable()), "playback must restart for timing coverage")
	var timing_debug: Dictionary = playback.get_host_debug_snapshot()
	var speed: float = float(timing_debug.get("timeline_speed", 0.0))
	_expect(speed > 0.0 and speed < 1.0 and is_equal_approx((1.6 / speed), VictoryHighlightPlaybackState.MIN_TOTAL_PRESENTATION_SEC), "short selections must be paced to the 2.8s presentation floor")
	playback.update(1.41)
	_expect(playback.get_current_clip_index() == 1 and not playback.get_previous_clip().is_empty(), "clip transition must retain the outgoing clip for crossfade")
	playback.update(0.06)
	_expect(playback.get_content_alpha() > 0.45 and playback.get_content_alpha() < 0.55, "crossfade must use 0.12s wall-clock timing")
	playback.update(0.07)
	_expect(playback.get_previous_clip().is_empty(), "outgoing clip must release after the 0.12s crossfade")
	playback.reset()
	var frame_clip := _fixture_clip()
	frame_clip["frame_frames"] = [PackedByteArray([1, 2, 3, 4])]
	var frame_clips: Array[Dictionary] = [frame_clip]
	_expect(playback.start(owner, registry, frame_clips, Callable()), "frame-backed playback must start through the real playback state")
	_expect(
		is_equal_approx(float(playback.get_host_debug_snapshot().get("timeline_speed", 0.0)), 1.0),
		"any frame-backed playback must preserve its natural capture timeline"
	)
	playback.reset()
	var mixed_clips: Array[Dictionary] = [frame_clip, _fixture_clip()]
	_expect(playback.start(owner, registry, mixed_clips, Callable()), "mixed frame/state playback must start through one shared timeline")
	_expect(
		is_equal_approx(float(playback.get_host_debug_snapshot().get("timeline_speed", 0.0)), 1.0),
		"one frame payload must select natural pacing for the entire mixed playback"
	)
	playback.reset()

	var result_screen := FakeResultScreen.new()
	var score_state := FakeScoreState.new()
	var scoreboard := FakeScoreboard.new()
	registry.values["stage_clear_result_screen"] = result_screen
	registry.values["match_score_state"] = score_state
	registry.values["scoreboard_state"] = scoreboard
	_expect(playback.start(owner, registry, clips, Callable()), "playback must start for F9 route coverage")
	BattleSceneInputController.new().handle_unhandled_input(
		f9,
		owner,
		registry,
		func(key: String) -> Object: return registry.get_instance(key),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"reset_game_after_stage_clear": Callable(),
			"exit_to_menu_after_stage_clear": Callable(),
		}
	)
	_expect(not playback.is_active() and result_screen.show_calls == 1, "F9 must pass through replay, tear it down, and reach the stage-clear result route")
	_expect(score_state.player_score == MatchScoreState.WIN_GOAL and score_state.boss_score == 0 and scoreboard.start_calls == 1, "F9 result route must use the canonical winning score against 0")
	owner.free()


func _test_two_victory_intercepts_and_fallback() -> void:
	var owner := TestOwner.new()
	root.add_child(owner)
	var fixture_clips: Array[Dictionary] = [_fixture_clip()]
	var direct_registry := _make_driver_registry(fixture_clips)
	var direct_playback: FakePlayback = direct_registry.get_instance("victory_highlight_playback_state")
	var reset_count := {"value": 0}
	var direct_driver := BattleSceneMatchFlowDriver.new()
	direct_driver.apply_scoreboard_update_result(
		ScoreboardState.UPDATE_RESET_GAME,
		direct_registry,
		owner,
		func() -> void: reset_count["value"] += 1,
		Callable()
	)
	_expect(direct_playback.start_calls == 1, "regular scoreboard ladder must intercept victory with presentation")
	direct_playback.reset()

	var fallback_registry := _make_driver_registry(fixture_clips)
	var fake_match_flow := FakeMatchFlow.new()
	fallback_registry.values["match_flow_controller"] = fake_match_flow
	fallback_registry.values["battle_update_context"] = FakeContextBuilder.new()
	var fallback_playback: FakePlayback = fallback_registry.get_instance("victory_highlight_playback_state")
	BattleSceneMatchFlowDriver.new().update_scoreboard(
		fallback_registry,
		0.1,
		Callable(),
		Callable(),
		owner
	)
	_expect(fake_match_flow.presentation_key_seen and fallback_playback.start_calls == 1, "fallback scoreboard ladder must independently intercept victory with the renamed callback")
	fallback_playback.reset()

	var softlock_registry := _make_driver_registry(fixture_clips)
	var softlock_playback: FakePlayback = softlock_registry.get_instance("victory_highlight_playback_state")
	var softlock_loot := FakeLoot.new()
	var softlock_result := FakeResultScreen.new()
	softlock_registry.values["victory_loot_phase_state"] = softlock_loot
	softlock_registry.values["stage_clear_result_screen"] = softlock_result
	var softlock_reset := {"value": 0}
	var softlock_driver := BattleSceneMatchFlowDriver.new()
	softlock_driver.apply_scoreboard_update_result(
		ScoreboardState.UPDATE_RESET_GAME,
		softlock_registry,
		owner,
		func() -> void: softlock_reset["value"] += 1,
		Callable()
	)
	softlock_playback.finish_for_tests()
	_expect(softlock_loot.start_calls == 1 and softlock_result.show_calls == 1 and int(softlock_reset["value"]) == 1, "highlight finish must fall through loot failure, result failure, then reset without softlock")
	owner.free()


func _test_frame_gate() -> void:
	var playback := CountingPlayback.new()
	var calls := {"ball": 0, "boss": 0, "player": 0, "redraw": 0}
	BattleFrameFlowController.new().update(0.1, {
		"victory_highlight_playback_state": playback,
	}, {
		"update_ball": func(_delta: float) -> void: calls["ball"] += 1,
		"update_boss_ai": func(_delta: float) -> void: calls["boss"] += 1,
		"update_player_control": func(_delta: float) -> void: calls["player"] += 1,
		"queue_redraw": func() -> void: calls["redraw"] += 1,
	})
	_expect(playback.update_calls == 1 and int(calls["redraw"]) == 1, "highlight frame branch must advance only replay and redraw")
	_expect(int(calls["ball"]) == 0 and int(calls["boss"]) == 0 and int(calls["player"]) == 0, "highlight frame branch must freeze ball, boss AI, and player control")


func _make_actor_fixture() -> Dictionary:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var context := {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"player_pos": Vector2(300.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_paddle_scale": 1.0,
		"boss_pos": Vector2(330.0, 20.0),
		"boss_pos_prev": Vector2(330.0, 20.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"textures": {},
	}
	return {
		"actor_context": BattleDrawActorContext.new().build(context, {}),
		"texture": texture,
	}


func _resolver_actor_context() -> Dictionary:
	return {
		"current_stage": 1,
		"player_pos": Vector2(300.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_paddle_scale": 1.0,
		"player_idle_draw_size": Vector2(160.0, 160.0),
		"player_speed": 0.0,
		"boss_pos": Vector2(330.0, 20.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"boss_sprite_draw_size": Vector2(160.0, 160.0),
		"boss_visual_center_y_offset": 25.0,
	}


func _make_test_texture(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _draw_context(ball_pos: Vector2) -> Dictionary:
	return {
		"ball_active": true,
		"ball_pos": ball_pos,
		"ball_pos_prev": ball_pos,
		"ball_vel": Vector2(180.0, -240.0),
		"ball_render_radius": 18.0,
	}


func _capture_range(recorder: Object, actor_context: Dictionary, start_sec: float, end_sec: float, rate: float) -> void:
	var steps: int = ceili((end_sec - start_sec) * rate)
	for index in range(steps + 1):
		var time_sec: float = minf(end_sec, start_sec + float(index) / rate)
		var ball_pos := Vector2(250.0 + time_sec * 80.0, 600.0 - time_sec * 500.0)
		recorder.capture_visual(actor_context, _draw_context(ball_pos), time_sec)


func _record_goal(
	recorder: Object,
	actor_context: Dictionary,
	goal_sec: float,
	rally_count: int,
	is_final: bool,
	deuce_mode: bool,
	skill_tag: String
) -> void:
	recorder.record_player_hit(Vector2(370.0, 700.0), skill_tag, goal_sec - 0.70)
	_capture_range(recorder, actor_context, goal_sec - 0.80, goal_sec, 72.0)
	recorder.record_score_event(
		"player",
		_score_result(7 if is_final else 4, 5 if is_final else 3, is_final, deuce_mode),
		rally_count,
		"player",
		skill_tag,
		goal_sec
	)


func _score_result(player_score: int, boss_score: int, match_finished: bool, deuce_mode: bool = false) -> Dictionary:
	return {
		"player_score": player_score,
		"boss_score": boss_score,
		"deuce_mode": deuce_mode,
		"match_finished": match_finished,
	}


func _fixture_clip() -> Dictionary:
	return {
		"label_key": VictoryHighlightRecorder.LABEL_FINISHER,
		"duration_sec": 0.80,
		"goal_t_sec": 0.55,
		"samples": [
			{"t_sec": 0.0, "ball_pos": Vector2(320.0, 500.0), "ball_radius": 18.0, "player_dest": Rect2(290.0, 620.0, 160.0, 120.0), "boss_dest": Rect2(300.0, 20.0, 160.0, 160.0)},
			{"t_sec": 0.55, "ball_pos": Vector2(380.0, 20.0), "ball_radius": 18.0, "player_dest": Rect2(290.0, 620.0, 160.0, 120.0), "boss_dest": Rect2(300.0, 20.0, 160.0, 160.0)},
		],
		"events": [{"t_sec": 0.55, "kind": VictoryHighlightRecorder.EVENT_GOAL, "pos": Vector2(380.0, 20.0)}],
	}


func _make_driver_registry(clips: Array[Dictionary]) -> FakeRegistry:
	var registry := FakeRegistry.new()
	var recorder := FakeSelectionRecorder.new()
	recorder.clips = clips
	registry.values = {
		"scoreboard_state": FakeScoreboard.new(),
		"victory_highlight_recorder": recorder,
		"victory_highlight_playback_state": FakePlayback.new(),
		"victory_loot_phase_state": FakeLoot.new(),
		"stage_clear_result_screen": FakeResultScreen.new(),
		"game_audio": FakeAudio.new(),
	}
	return registry


func _on_finish() -> void:
	_finish_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
