extends SceneTree

const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BossAiTurnInertiaResolver := preload("res://scripts/ai/boss_ai_turn_inertia_resolver.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

var _failures: Array[String] = []


class ScoreStateStub:
	extends RefCounted

	var score_calls := 0
	var next_match_finished := false

	func score_for(scoring_side: String) -> Dictionary:
		score_calls += 1
		return {
			"player_score": 1 if scoring_side == "player" else 0,
			"boss_score": 1 if scoring_side == "boss" else 0,
			"next_player_serves": scoring_side == "boss",
			"match_finished": next_match_finished,
		}


class RuntimePerkStateStub:
	extends RefCounted

	var queue_calls := 0
	var round_reset_calls := 0
	var finished_queue_calls := 0
	var pending: Dictionary = {}

	func queue_perk_fusion_player_point_lost(match_finished: bool = false) -> Dictionary:
		if match_finished:
			# 종결 득점 계약: 기회를 만들지 않고 pending도 폐기한다.
			finished_queue_calls += 1
			pending.clear()
			return {}
		queue_calls += 1
		pending = {
			"static_field": {
				"boss_slow_multiplier": BossSlowTiers.WEAK,
				"duration_sec": 4.0,
			},
			"restore_dash_tokens": true,
		}
		return pending.duplicate(true)

	func reset_perk_fusion_round_byproducts() -> void:
		round_reset_calls += 1

	func consume_pending_perk_fusion_point_loss_effects() -> Dictionary:
		var result: Dictionary = pending.duplicate(true)
		pending.clear()
		return result


class OwnerStub:
	extends RefCounted

	var perk_fusion_overload_speed_cap := 35.075
	var perk_fusion_overload_speed_cap_frames := 120.0


class StatusEffectStateStub:
	extends RefCounted

	var applications: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary, source: String) -> Dictionary:
		applications.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}


class DashStateStub:
	extends RefCounted

	var refill_calls := 0

	func refill_tokens() -> void:
		refill_calls += 1

	func get_snapshot() -> Dictionary:
		return {"tokens": 3, "max_tokens": 3}


class OrbHudStateStub:
	extends RefCounted

	var reset_values: Array[int] = []

	func reset_dash_tokens(current_charges: int) -> void:
		reset_values.append(current_charges)


class GameAudioStub:
	extends RefCounted

	var mini_spark_calls := 0

	func play_mini_spark() -> void:
		mini_spark_calls += 1


class RegistryStub:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_score_commit_queues_once_and_new_round_applies_once()
	_verify_static_field_preserves_four_seconds_of_live_rally_slow()
	_verify_match_finishing_score_carries_no_pending_into_next_stage()
	_verify_real_reset_ball_applies_pending_after_ball_cleanup()
	if _failures.is_empty():
		print("perk_fusion_round_boundary_integration_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_score_commit_queues_once_and_new_round_applies_once() -> void:
	var score_state := ScoreStateStub.new()
	var runtime_state := RuntimePerkStateStub.new()
	var owner := OwnerStub.new()
	var score_controller := MatchScoreEventController.new()
	score_controller.handle_score_event("boss", {
		"score_state": score_state,
		"runtime_perk_state": runtime_state,
		"owner": owner,
	}, {})
	_expect(score_state.score_calls == 1, "accepted boss score should commit before fusion point-loss handling")
	_expect(runtime_state.queue_calls == 1, "accepted player point loss should create exactly one byproduct opportunity")
	_expect(runtime_state.round_reset_calls == 1, "accepted score should clear fusion round transients once")
	_expect(is_zero_approx(owner.perk_fusion_overload_speed_cap), "accepted boss score should close the overload cap")
	_expect(is_zero_approx(owner.perk_fusion_overload_speed_cap_frames), "accepted boss score should close the overload cap TTL")
	owner.perk_fusion_overload_speed_cap = 35.075
	owner.perk_fusion_overload_speed_cap_frames = 120.0
	score_controller.handle_score_event("player", {
		"score_state": score_state,
		"runtime_perk_state": runtime_state,
		"owner": owner,
	}, {})
	_expect(runtime_state.queue_calls == 1, "player-scored rounds must not roll point-loss byproducts")
	_expect(runtime_state.round_reset_calls == 2, "both accepted score sides should clear the old round transients")
	_expect(is_zero_approx(owner.perk_fusion_overload_speed_cap), "accepted player score should close the overload cap")
	_expect(is_zero_approx(owner.perk_fusion_overload_speed_cap_frames), "accepted player score should close the overload cap TTL")

	var status_state := StatusEffectStateStub.new()
	var dash_state := DashStateStub.new()
	var orb_hud_state := OrbHudStateStub.new()
	var game_audio := GameAudioStub.new()
	var registry := RegistryStub.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"status_effect_state": status_state,
		"smasher_dash_state": dash_state,
		"orb_hud_state": orb_hud_state,
		"game_audio": game_audio,
	}
	var event_driver := BattleSceneMatchEventDriver.new()
	event_driver._apply_pending_perk_fusion_round_start(registry)
	_expect(status_state.applications.size() == 1, "queued static field should apply after old-round status cleanup")
	if status_state.applications.size() == 1:
		var application: Dictionary = status_state.applications[0]
		_expect(str(application.get("target", "")) == "boss" and str(application.get("status_id", "")) == "slow", "static field should target the boss slow channel")
		_expect(is_equal_approx(float(application.get("duration_frames", 0.0)), 240.0), "four-second static field should enter the 60-fps status owner as 240 frames")
		var data: Dictionary = application.get("data", {}) as Dictionary
		_expect(is_equal_approx(float(data.get("multiplier", 0.0)), BossSlowTiers.WEAK), "static field should use the shared WEAK slow multiplier")
		_expect(bool(data.get("pause_while_ball_inactive", false)), "static field should preserve its timer until the ball is served")
	_expect(game_audio.mini_spark_calls == 1, "static field should play one electric activation cue")
	_expect(dash_state.refill_calls == 1, "successful recycle protocol should refill the full dash token state")
	_expect(orb_hud_state.reset_values == [3], "recycle protocol should synchronize the HUD to the refilled token count")
	event_driver._apply_pending_perk_fusion_round_start(registry)
	_expect(status_state.applications.size() == 1 and dash_state.refill_calls == 1, "pending point-loss effects must be consumed exactly once")
	_expect(game_audio.mini_spark_calls == 1, "consumed static field should not replay its activation cue")


func _verify_static_field_preserves_four_seconds_of_live_rally_slow() -> void:
	var status_state := StatusEffectState.new()
	status_state.apply_status("boss", "slow", 240.0, {
		"multiplier": BossSlowTiers.WEAK,
		"pause_while_ball_inactive": true,
	}, StatusEffectState.SOURCE_PERK_FUSION_STATIC_FIELD)
	var effects_controller := BattleEffectsUpdateController.new()
	# Worst-case boss serve delay can exceed the entire old four-second timer.
	effects_controller.update(5.0, _effects_context(false, true), {
		"status_effect_state": status_state,
	})
	var waiting_source: Dictionary = status_state.get_status_source(
		"boss",
		"slow",
		StatusEffectState.SOURCE_PERK_FUSION_STATIC_FIELD
	)
	_expect(
		is_equal_approx(float(waiting_source.get("remaining_frames", 0.0)), 240.0),
		"five seconds of serve waiting must not consume static field"
	)
	var boss_context: Dictionary = status_state.get_boss_ai_context()
	_expect(
		is_equal_approx(
			BossAiTurnInertiaResolver.get_movement_slow_multiplier(boss_context),
			BossSlowTiers.WEAK
		),
		"live boss AI movement should receive the static-field weak slow multiplier"
	)
	effects_controller.update(239.0 / 60.0, _effects_context(true, false), {
		"status_effect_state": status_state,
	})
	_expect(status_state.has_status("boss", "slow"), "static field should remain for the first 239 live-rally frames")
	effects_controller.update(1.0 / 60.0, _effects_context(true, false), {
		"status_effect_state": status_state,
	})
	_expect(not status_state.has_status("boss", "slow"), "static field should expire after exactly 240 live-rally frames")


func _effects_context(ball_active: bool, waiting_for_serve: bool) -> Dictionary:
	return {
		"current_stage": 1,
		"current_msec": 1000,
		"selected_character_type": "smasher",
		"ball_active": ball_active,
		"waiting_for_serve": waiting_for_serve,
		"dash_snapshot": {},
		"ball_pos": Vector2(380.0, 360.0),
		"player_pos": Vector2(300.0, 680.0),
		"boss_pos": Vector2(330.0, 25.0),
	}


# 종결 득점(match_finished) 이월 차단: 마지막 보스 득점은 부산물 기회를
# 만들지 않고, 스테이지 전환 뒤 다음 라운드 시작 적용이 0이어야 한다.
func _verify_match_finishing_score_carries_no_pending_into_next_stage() -> void:
	var score_state := ScoreStateStub.new()
	score_state.next_match_finished = true
	var runtime_state := RuntimePerkStateStub.new()
	var owner := OwnerStub.new()
	MatchScoreEventController.new().handle_score_event("boss", {
		"score_state": score_state,
		"runtime_perk_state": runtime_state,
		"owner": owner,
	}, {})
	_expect(runtime_state.queue_calls == 0, "match-finishing boss score must not create a byproduct opportunity")
	_expect(runtime_state.finished_queue_calls == 1, "match-finishing boss score should route through the finished-guard path")
	_expect(runtime_state.pending.is_empty(), "match-finishing score must leave no pending point-loss effects")
	var status_state := StatusEffectStateStub.new()
	var dash_state := DashStateStub.new()
	var registry := RegistryStub.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"status_effect_state": status_state,
		"smasher_dash_state": dash_state,
		"orb_hud_state": OrbHudStateStub.new(),
	}
	BattleSceneMatchEventDriver.new()._apply_pending_perk_fusion_round_start(registry)
	_expect(status_state.applications.is_empty() and dash_state.refill_calls == 0, "next-stage round start must apply zero carried-over effects")


class BallDriverStub:
	extends RefCounted

	var sequence: Array
	var reset_calls := 0

	func _init(shared_sequence: Array) -> void:
		sequence = shared_sequence

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1
		sequence.append("ball_reset")


class SequencedStatusStub:
	extends RefCounted

	var sequence: Array
	var applications := 0

	func _init(shared_sequence: Array) -> void:
		sequence = shared_sequence

	func apply_status(_target: String, _status_id: String, _duration_frames: float, _data: Dictionary, _source: String) -> Dictionary:
		applications += 1
		sequence.append("status_apply")
		return {}


# 실 _reset_ball() 배선 관통(코덱스 보강 #4): helper 직접 호출이 아니라
# 실제 라운드 시작 경로가 ball_driver.reset_ball → pending 적용 순서로
# 정확히 1회 소비하는지 봉인한다(호출부 누락 회귀 차단).
func _verify_real_reset_ball_applies_pending_after_ball_cleanup() -> void:
	var runtime_state := RuntimePerkStateStub.new()
	runtime_state.queue_perk_fusion_player_point_lost()
	var sequence: Array = []
	var ball_driver := BallDriverStub.new(sequence)
	var status_state := SequencedStatusStub.new(sequence)
	var dash_state := DashStateStub.new()
	var registry := RegistryStub.new()
	registry.instances = {
		"battle_scene_ball_update_driver": ball_driver,
		"runtime_perk_state": runtime_state,
		"status_effect_state": status_state,
		"smasher_dash_state": dash_state,
		"orb_hud_state": OrbHudStateStub.new(),
	}
	var event_driver := BattleSceneMatchEventDriver.new()
	event_driver._reset_ball(null, registry)
	_expect(ball_driver.reset_calls == 1, "real round start should reset the ball exactly once")
	_expect(status_state.applications == 1 and dash_state.refill_calls == 1, "real round start should apply the pending effects exactly once")
	_expect(sequence == ["ball_reset", "status_apply"], "pending effects must apply after the old-round ball/status cleanup")
	event_driver._reset_ball(null, registry)
	_expect(status_state.applications == 1 and dash_state.refill_calls == 1, "a second real round start must not re-apply consumed pending effects")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
