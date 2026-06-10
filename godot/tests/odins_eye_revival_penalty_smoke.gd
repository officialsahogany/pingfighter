extends SceneTree

const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"gameplay_frame_counter": 1,
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"ball_pos": Vector2(340.0, 760.0),
		"ball_pos_prev": Vector2(340.0, 730.0),
		"ball_vel": Vector2(0.0, 12.0),
		"ball_active": true,
		"boss_max_health": 20,
		"boss_current_health": 7,
		"boss_health_damage_units": 13,
		"boss_defeated_by_health": true,
		"starting_dash_tokens": 3,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func queue_redraw() -> void:
		values["queue_redraw_calls"] = int(values.get("queue_redraw_calls", 0)) + 1


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false
	var player_serves := false
	var reset_wait_calls := 0
	var scoreboard_wait_calls := 0
	var restart_notice_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting_for_serve = true
		reset_wait_calls += 1

	func start_scoreboard_wait() -> void:
		scoreboard_wait_calls += 1

	func start_round_restart_notice() -> void:
		restart_notice_calls += 1

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeScoreboardState:
	extends RefCounted

	var start_args: Array = []
	var sparkle_calls := 0

	func trigger_top_mini_sparkle() -> void:
		sparkle_calls += 1

	func start(
		player_score: int,
		boss_score: int,
		match_finished: bool,
		scoring_side: String,
		win_goal: int = 5
	) -> void:
		start_args = [player_score, boss_score, match_finished, scoring_side, win_goal]


class FakeAudio:
	extends RefCounted

	var round_set_calls := 0
	var stopped: Dictionary = {}

	func stop_dash_delay() -> void:
		stopped["dash"] = true

	func stop_warp_gate_loop() -> void:
		stopped["warp"] = true

	func stop_stage2_quake_loop() -> void:
		stopped["quake"] = true

	func play_round_set() -> void:
		round_set_calls += 1


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0

	func reset_ball(owner: Object, _registry: Object) -> void:
		reset_calls += 1
		owner.set("ball_pos", Vector2(380.0, 375.0))
		owner.set("ball_pos_prev", Vector2(380.0, 375.0))
		owner.set("ball_vel", Vector2.ZERO)
		owner.set("ball_active", false)


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(owner: Object) -> void:
		reset_calls += 1
		owner.set("boss_current_health", owner.get("boss_max_health"))
		owner.set("boss_health_damage_units", 0)
		owner.set("boss_defeated_by_health", false)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_odins_eye_score_loss_flow()
	_verify_penalty_cleared_on_player_victory()

	if _failures.is_empty():
		print("odins_eye_revival_penalty_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_odins_eye_score_loss_flow() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var score_state: Object = MatchScoreState.new()
	var round_state := FakeRoundState.new()
	var scoreboard := FakeScoreboardState.new()
	var audio := FakeAudio.new()
	var ball_driver := FakeBallDriver.new()
	var boss_health := FakeBossHealthFlow.new()
	var match_flow: Object = MatchFlowController.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"match_score_state": score_state,
		"round_flow_state": round_state,
		"scoreboard_state": scoreboard,
		"game_audio": audio,
		"battle_scene_ball_update_driver": ball_driver,
		"battle_scene_boss_health_flow": boss_health,
		"match_flow_controller": match_flow,
	})
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"Odin's Eye should equip for score-flow smoke"
	)

	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": audio,
		"owner": owner,
		"registry": registry,
	}, {})
	_expect(int(score_state.get_snapshot().get("boss_score", -1)) == 0, "first Odin loss should negate boss score immediately")
	_expect(runtime.is_odins_eye_revival_animation_active(), "first Odin loss should start revival animation")
	_expect(runtime.is_odins_eye_penalty_active(), "first Odin loss should enter penalty immediately")
	_expect(not runtime.is_odins_eye_available(), "first Odin loss should consume the current revival cycle")
	_expect(owner.values.get("ball_pos", Vector2.ZERO) == Vector2(-100.0, -100.0), "first Odin loss should hide the ball while revival plays")
	_expect(not bool(owner.values.get("ball_active", true)), "first Odin loss should deactivate the ball while revival plays")
	_expect(not round_state.waiting_for_serve, "revival animation should not expose a serve-wait ball before finalize")
	_expect(audio.round_set_calls == 0, "Odin score cancel should not play normal score audio")

	var item_driver := BattleSceneItemUpdateDriver.new()
	owner.set("gameplay_frame_counter", int(owner.get("gameplay_frame_counter")) + 1)
	item_driver.update_mythic_items(owner, registry, 3.1)
	_expect(ball_driver.reset_calls == 1, "revival finalize should reset the ball")
	_expect(boss_health.reset_calls == 1, "revival finalize should reset boss round health")
	_expect(round_state.waiting_for_serve and round_state.player_serves, "revival finalize should return to player serve wait")
	_expect(runtime.is_odins_eye_penalty_active(), "revival finalize should keep the penalty form active")
	_expect(runtime.has_odins_eye_revival_used(), "revival finalize should preserve used state for the penalty cycle")

	round_state.waiting_for_serve = false
	owner.set("ball_pos", Vector2(340.0, 760.0))
	owner.set("ball_vel", Vector2(0.0, 12.0))
	owner.set("ball_active", true)
	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": audio,
		"owner": owner,
		"registry": registry,
	}, {})
	_expect(int(score_state.get_snapshot().get("boss_score", -1)) == 0, "penalty loss should wait for death finalize before scoring")
	_expect(runtime.is_odins_eye_death_animation_active(), "penalty loss should start Odin death animation")
	_expect(owner.values.get("ball_pos", Vector2.ZERO) == Vector2(-100.0, -100.0), "penalty loss should hide the ball while death plays")
	_expect(scoreboard.start_args.is_empty(), "penalty loss should not start scoreboard before death finalize")

	owner.set("gameplay_frame_counter", int(owner.get("gameplay_frame_counter")) + 1)
	BattleSceneItemUpdateDriver.new().update_mythic_items(owner, registry, 2.6)
	var snapshot: Dictionary = score_state.get_snapshot()
	_expect(int(snapshot.get("boss_score", -1)) == 1, "death finalize should dispatch the real boss score")
	_expect(scoreboard.start_args == [0, 1, false, "boss", 5], "death finalize score should use normal scoreboard flow")
	_expect(scoreboard.sparkle_calls == 1, "death finalize score should trigger scoreboard sparkle")
	_expect(round_state.scoreboard_wait_calls == 1, "death finalize score should enter scoreboard wait")
	_expect(audio.round_set_calls == 1, "death finalize score should play normal score audio")
	_expect(not runtime.is_odins_eye_penalty_active(), "death finalize should clear penalty")
	_expect(not runtime.has_odins_eye_revival_used(), "death finalize should re-arm Odin for a future cycle")
	_expect(runtime.is_odins_eye_available(), "death finalize should make Odin available again while equipped")
	_expect(not bool(owner.values.get("odins_eye_penalty_active", true)), "owner sync should clear Odin penalty after death finalize")
	_expect(not bool(owner.values.get("odins_eye_revival_used", true)), "owner sync should clear Odin used state after death finalize")


func _verify_penalty_cleared_on_player_victory() -> void:
	# §8 boundary policy: a player rally win while in the Odin penalty form must
	# clear the penalty and re-arm revival. Drives the real controller path
	# (MatchFlowController -> match_score_event_controller) so it seals the
	# wiring, not just the runtime helper.
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var score_state: Object = MatchScoreState.new()
	var round_state := FakeRoundState.new()
	var scoreboard := FakeScoreboardState.new()
	var audio := FakeAudio.new()
	var ball_driver := FakeBallDriver.new()
	var boss_health := FakeBossHealthFlow.new()
	var match_flow: Object = MatchFlowController.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"match_score_state": score_state,
		"round_flow_state": round_state,
		"scoreboard_state": scoreboard,
		"game_audio": audio,
		"battle_scene_ball_update_driver": ball_driver,
		"battle_scene_boss_health_flow": boss_health,
		"match_flow_controller": match_flow,
	})
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"Odin's Eye should equip for player-victory smoke"
	)
	var deps := {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": audio,
		"owner": owner,
		"registry": registry,
	}

	# Lose a point -> revival roll -> penalty form, then finalize the revival.
	match_flow.handle_score_event("boss", deps, {})
	owner.set("gameplay_frame_counter", int(owner.get("gameplay_frame_counter")) + 1)
	BattleSceneItemUpdateDriver.new().update_mythic_items(owner, registry, 3.1)
	_expect(runtime.is_odins_eye_penalty_active(), "setup: revival finalize should keep penalty active")
	_expect(runtime.has_odins_eye_revival_used(), "setup: penalty cycle should mark revival used")

	# Player wins the next rally while in penalty.
	round_state.waiting_for_serve = false
	owner.set("ball_pos", Vector2(340.0, 4.0))
	owner.set("ball_vel", Vector2(0.0, -12.0))
	owner.set("ball_active", true)
	match_flow.handle_score_event("player", deps, {})
	_expect(int(score_state.get_snapshot().get("player_score", -1)) == 1, "player victory should still award the point")
	_expect(not runtime.is_odins_eye_penalty_active(), "player victory in penalty should clear Odin penalty")
	_expect(not runtime.has_odins_eye_revival_used(), "player victory in penalty should re-arm Odin revival")
	_expect(runtime.is_odins_eye_available(), "player victory should make Odin available again while equipped")
	_expect(not bool(owner.values.get("odins_eye_penalty_active", true)), "owner sync should clear Odin penalty after player victory")
	_expect(not bool(owner.values.get("odins_eye_revival_used", true)), "owner sync should clear Odin used state after player victory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
