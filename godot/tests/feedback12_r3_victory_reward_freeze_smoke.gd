extends SceneTree

# expect-zero-object-leaks
# Feedback12 R3 seal: Tower reward-pick keeps its own board clock alive while
# freezing combat simulation, then thaws on the first frame after the modal.

const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")

const FRAME_DELTA := 1.0 / 60.0
const FIVE_SECOND_TICKS := 300

var _failures: Array[String] = []


class LootCallRecordingState:
	extends RefCounted

	var active := true
	var reward_pick_active := false
	var update_calls := 0

	func is_active() -> bool:
		return active

	func is_reward_pick_active() -> bool:
		return active and reward_pick_active

	func update(_delta: float) -> void:
		update_calls += 1


class CallbackRecorder:
	extends RefCounted

	var calls: Dictionary = {}

	func count(key: String) -> int:
		return int(calls.get(key, 0))

	func make(key: String) -> Callable:
		return Callable(self, "_on_call").bind(key)

	func make_delta(key: String) -> Callable:
		return Callable(self, "_on_call_delta").bind(key)

	func _on_call(key: String) -> void:
		calls[key] = count(key) + 1

	func _on_call_delta(_delta: float, key: String) -> void:
		calls[key] = count(key) + 1


class FakeGameAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_stage3_psychoball_loop() -> void:
		stop_calls += 1


class RewardPickCombatProbe:
	extends RefCounted

	var stage3_state := Stage3BossSkillState.new()
	var ball_pos := Vector2(390.0, 375.0)
	var ball_vel := Vector2(10.0, 0.0)
	var ball_update_ticks := 0
	var effect_update_ticks := 0

	func _init() -> void:
		stage3_state.force_kuromi_awake()
		stage3_state.set("kuromi_eating_cooldown", 10.0)
		stage3_state.set("tail_whip_active", true)
		stage3_state.set("tail_whip_timer", 0.5)
		stage3_state.set("tail_whip_target", ball_pos)
		stage3_state.set("tail_has_target", true)

	func update_ball(delta: float) -> void:
		ball_update_ticks += 1
		ball_pos += ball_vel * delta

	func update_effects(delta: float) -> void:
		effect_update_ticks += 1
		var result: Dictionary = stage3_state.update(delta, {
			"current_stage": 3,
			"ball_active": true,
			"waiting_for_serve": false,
			"ball_pos": ball_pos,
			"ball_vel": ball_vel,
			"boss_pos": Vector2(320.0, 25.0),
			"boss_paddle_size": Vector2(110.0, 18.0),
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"player_score": 2,
		}, {})
		var next_ball_pos: Variant = result.get("ball_pos", null)
		if next_ball_pos is Vector2:
			ball_pos = next_ball_pos
		var next_ball_vel: Variant = result.get("ball_vel", null)
		if next_ball_vel is Vector2:
			ball_vel = next_ball_vel

	func get_soul_count() -> int:
		var drops: Array = stage3_state.get_snapshot().get("stage3_starpoint_drops", [])
		return drops.size()

	func get_first_soul_source() -> String:
		var drops: Array = stage3_state.get_snapshot().get("stage3_starpoint_drops", [])
		if drops.is_empty() or not (drops[0] is Dictionary):
			return ""
		return str((drops[0] as Dictionary).get("source_type", ""))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_generic_loot_contract()
	_verify_reward_pick_freeze_and_thaw()
	_verify_reward_pick_predicate_bypass_counterproof()
	if _failures.is_empty():
		print("feedback12_r3_victory_reward_freeze_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_generic_loot_contract() -> void:
	var controller := BattleFrameFlowController.new()
	var loot := LootCallRecordingState.new()
	var recorder := CallbackRecorder.new()
	var callbacks := {
		"update_player_control": recorder.make_delta("update_player_control"),
		"update_active_items": recorder.make_delta("update_active_items"),
		"update_ball": recorder.make_delta("update_ball"),
		"update_boss_ai": recorder.make_delta("update_boss_ai"),
		"update_lingpet": recorder.make_delta("update_lingpet"),
		"update_effects": recorder.make_delta("update_effects"),
		"queue_redraw": recorder.make("queue_redraw"),
	}
	controller.update(FRAME_DELTA, {"victory_loot_phase_state": loot}, callbacks)
	_expect(loot.update_calls == 1, "ordinary loot must keep its own update alive")
	_expect(recorder.count("update_player_control") == 1, "ordinary loot must keep player pickup control alive")
	_expect(recorder.count("update_active_items") == 1, "ordinary loot must keep active-item pickup objects alive")
	_expect(recorder.count("update_effects") == 1, "ordinary loot must keep presentation effects alive")
	_expect(recorder.count("update_ball") == 0, "ordinary loot must retain its existing ball freeze")
	_expect(recorder.count("update_boss_ai") == 0, "ordinary loot must retain its existing boss-AI freeze")
	_expect(recorder.count("update_lingpet") == 0, "ordinary loot must retain its existing companion pause")


func _verify_reward_pick_freeze_and_thaw() -> void:
	var controller := BattleFrameFlowController.new()
	var loot := LootCallRecordingState.new()
	loot.reward_pick_active = true
	var recorder := CallbackRecorder.new()
	var probe := RewardPickCombatProbe.new()
	var game_audio := FakeGameAudio.new()
	var deps := {
		"victory_loot_phase_state": loot,
		"game_audio": game_audio,
	}
	var callbacks := {
		"update_weather": recorder.make_delta("update_weather"),
		"update_mythic_items": recorder.make_delta("update_mythic_items"),
		"update_player_control": recorder.make_delta("update_player_control"),
		"update_active_items": recorder.make_delta("update_active_items"),
		"update_ball": Callable(probe, "update_ball"),
		"update_boss_ai": recorder.make_delta("update_boss_ai"),
		"update_lingpet": recorder.make_delta("update_lingpet"),
		"update_effects": Callable(probe, "update_effects"),
		"queue_redraw": recorder.make("queue_redraw"),
	}
	var frozen_ball_pos: Vector2 = probe.ball_pos
	var frozen_ball_vel: Vector2 = probe.ball_vel
	var frozen_soul_count: int = probe.get_soul_count()
	for _tick in range(FIVE_SECOND_TICKS):
		controller.update(FRAME_DELTA, deps, callbacks)
	_expect(loot.update_calls == FIVE_SECOND_TICKS, "reward-pick board must advance for all 300 frozen ticks")
	_expect(recorder.count("queue_redraw") == FIVE_SECOND_TICKS, "reward-pick board must redraw for all 300 frozen ticks")
	_expect(recorder.count("update_weather") == 0, "reward-pick freeze must not advance weather simulation")
	_expect(recorder.count("update_mythic_items") == 0, "reward-pick freeze must not advance mythic item simulation")
	_expect(recorder.count("update_player_control") == 0, "reward-pick freeze must block player control")
	_expect(recorder.count("update_active_items") == 0, "reward-pick freeze must block active-item objects")
	_expect(recorder.count("update_boss_ai") == 0, "reward-pick freeze must block boss AI")
	_expect(recorder.count("update_lingpet") == 0, "reward-pick freeze must block companion simulation")
	_expect(probe.ball_update_ticks == 0, "reward-pick freeze must block authoritative ball ticks")
	_expect(probe.effect_update_ticks == 0, "reward-pick freeze must block the full effects lane")
	_expect(probe.ball_pos == frozen_ball_pos, "reward-pick freeze must hold ball position for five seconds")
	_expect(probe.ball_vel == frozen_ball_vel, "reward-pick freeze must prevent a hidden Kuromi tail redirect")
	_expect(probe.get_soul_count() == frozen_soul_count, "reward-pick freeze must hold the Muhon count for five seconds")
	_expect(game_audio.stop_calls == 1, "reward-pick entry must stop registered gameplay loops exactly once")

	var thaw_ball_pos: Vector2 = probe.ball_pos
	var thaw_effect_ticks: int = probe.effect_update_ticks
	var thaw_soul_count: int = probe.get_soul_count()
	loot.active = false
	controller.update(FRAME_DELTA, deps, callbacks)
	_expect(probe.ball_update_ticks == 1, "reward-pick exit must thaw the ball on the next frame")
	_expect(probe.effect_update_ticks == thaw_effect_ticks + 1, "reward-pick exit must thaw effects on the next frame")
	_expect(probe.ball_pos != thaw_ball_pos, "reward-pick exit must resume ball movement")
	_expect(probe.get_soul_count() > thaw_soul_count, "reward-pick exit must resume the armed Stage 3 tail/Muhon path")


func _verify_reward_pick_predicate_bypass_counterproof() -> void:
	var controller := BattleFrameFlowController.new()
	var loot := LootCallRecordingState.new()
	loot.reward_pick_active = false
	var probe := RewardPickCombatProbe.new()
	controller.update(FRAME_DELTA, {"victory_loot_phase_state": loot}, {
		"update_effects": Callable(probe, "update_effects"),
	})
	_expect(probe.effect_update_ticks == 1, "reward-pick predicate bypass counterproof must reach the effects lane")
	_expect(probe.ball_vel != Vector2(10.0, 0.0), "reward-pick predicate bypass counterproof must reproduce the Kuromi tail redirect")
	_expect(probe.get_soul_count() == 1, "reward-pick predicate bypass counterproof must create one Muhon")
	_expect(probe.get_first_soul_source() == "menhera_tail", "reward-pick predicate bypass counterproof must use the real tail source")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
