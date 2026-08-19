extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BossAIState := preload("res://scripts/ai/boss_ai_state.gd")

const AWAKEN_FREEZE_SEC := 3.0
const WIND_AURA_HIT_COOLDOWN_SEC := 0.30
const WIND_AURA_RECHARGE_SEC := 10.0
const SUPERSPEED_FREEZE_SEC := 0.35
const SUPERSPEED_DURATION_SEC := 10.0
const ULTIMATE_COOLDOWN_SEC := 50.0

var _failures: Array[String] = []


class FakeScoreState:
	extends RefCounted

	var player_score := 2
	var boss_score := 0

	func score_for(scoring_side: String) -> Dictionary:
		if scoring_side == "player":
			player_score += 1
		else:
			boss_score += 1
		return {
			"player_score": player_score,
			"boss_score": boss_score,
			"match_finished": false,
			"next_player_serves": scoring_side == "boss",
			"win_goal": 5,
		}


class FakeScoreboard:
	extends RefCounted

	var active := true

	func is_active() -> bool:
		return active


class ResetProbe:
	extends RefCounted

	var calls := 0

	func reset_ball() -> void:
		calls += 1


class FlowProbe:
	extends RefCounted

	var calls: Array[String] = []

	func update_weather(_delta: float) -> void:
		calls.append("update_weather")

	func update_mythic_items(_delta: float) -> void:
		calls.append("update_mythic_items")

	func update_player_control(_delta: float) -> void:
		calls.append("update_player_control")

	func update_runtime_perk_resume(_delta: float) -> void:
		calls.append("update_runtime_perk_resume")

	func update_active_items(_delta: float) -> void:
		calls.append("update_active_items")

	func update_boss_ai(_delta: float) -> void:
		calls.append("update_boss_ai")

	func update_ball(_delta: float) -> void:
		calls.append("update_ball")

	func update_lingpet(_delta: float) -> void:
		calls.append("update_lingpet")

	func update_effects(_delta: float) -> void:
		calls.append("update_effects")

	func queue_redraw() -> void:
		calls.append("queue_redraw")


class FakeAudio:
	extends RefCounted

	var aura_block_calls := 0

	func play_stage7_akamu_wind_aura_block() -> void:
		aura_block_calls += 1


class FakeCloneBounceController:
	extends RefCounted

	var calls := 0

	func bounce_auxiliary_boss_paddle(
		paddle_rect: Rect2,
		context: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		calls += 1
		var ball_pos: Vector2 = context.get("ball_pos", Vector2.ZERO)
		ball_pos.y = paddle_rect.end.y + float(context.get("ball_size", 20.0)) * 0.5 + 1.0
		return {"ball_pos": ball_pos, "ball_vel": Vector2(4.0, 12.0)}


class FakeCloneBallIntensity:
	extends RefCounted

	var last_hit_by := "player"
	var contact_calls := 0
	var last_side := ""

	func get_last_hit_by() -> String:
		return last_hit_by

	func register_contact(_actor_id: String, side: String, _tags: Dictionary = {}) -> void:
		contact_calls += 1
		last_side = side
		last_hit_by = side


func _init() -> void:
	_verify_score_gate_and_awakening_completion()
	_verify_awakening_superspeed_unlock_respects_live_pause()
	_verify_wind_aura_substep_guards_and_debounce()
	_verify_awakened_clone_precedes_wind_aura()
	_verify_wind_aura_pause_suppresses_rewards_not_block()
	_verify_wind_aura_depletion_persistence_and_recharge()
	_verify_wind_aura_draw_cache_refreshes_across_frozen_boundaries()
	_verify_independent_free_cloud_and_clone_rolls()
	_verify_superspeed_activation_duration_cooldown_and_hud()
	_verify_superspeed_predictive_ai_and_recovery()
	_verify_common_dash_gauge_transaction_and_superspeed_free_path()
	_verify_superspeed_round_cleanup()

	if _failures.is_empty():
		print("stage7_akamu_slice5_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_score_gate_and_awakening_completion() -> void:
	var state: Object = Stage7AkamuState.new()
	var score_state := FakeScoreState.new()
	# 각성 임계값은 소유 상수에서 파생한다(리터럴 3은 7점제 재보정에서 깨졌다).
	# 이 점수에서 한 점 더 넣으면 정확히 임계값에 도달한다.
	score_state.player_score = Stage7AkamuState.AWAKEN_SCORE_THRESHOLD - 1
	var reset_probe := ResetProbe.new()
	MatchScoreEventController.new().handle_score_event("player", {
		"score_state": score_state,
		"current_stage": 7,
		"stage7_akamu_state": state,
	}, {
		"reset_ball": Callable(reset_probe, "reset_ball"),
	})
	var actor_context: Dictionary = state.get_actor_draw_context()
	_expect(score_state.player_score == Stage7AkamuState.AWAKEN_SCORE_THRESHOLD, "the accepted player score should commit the awaken-threshold point")
	_expect(reset_probe.calls == 1, "the accepted score should reach normal ball reset once")
	_expect(
		bool(actor_context.get("stage7_akamu_awakening_trigger_armed", false)),
		"the accepted awaken-threshold player point should arm Awakening"
	)
	_expect(
		not bool(actor_context.get("stage7_akamu_awakening_intro_pending", true)),
		"score acceptance should arm, not start, the Awakening intro"
	)
	_expect(not state.is_gameplay_freeze_active(), "score acceptance must not spend freeze under the scoreboard")

	var scoreboard := FakeScoreboard.new()
	var frame_flow: Object = BattleFrameFlowController.new()
	var scoreboard_probe := FlowProbe.new()
	frame_flow.update(1.0, _flow_deps(state, scoreboard), _flow_callbacks(scoreboard_probe))
	actor_context = state.get_actor_draw_context()
	_expect(
		scoreboard_probe.calls == ["update_effects"],
		"active scoreboard should retain its existing effects-only gate"
	)
	_expect(not state.is_gameplay_freeze_active(), "a whole scoreboard second must not consume Awakening freeze")
	_expect_close(
		float(actor_context.get("stage7_akamu_gameplay_freeze_remaining", -1.0)),
		0.0,
		"scoreboard gate should leave the full three seconds unstarted"
	)

	scoreboard.active = false
	var live_probe := FlowProbe.new()
	frame_flow.update(1.0 / 60.0, _flow_deps(state, scoreboard), _flow_callbacks(live_probe))
	actor_context = state.get_actor_draw_context()
	_expect(state.is_gameplay_freeze_active(), "the first live frame after scoreboard should start Awakening")
	_expect(
		str(actor_context.get("stage7_akamu_gameplay_freeze_reason", "")) == "awakening",
		"the frame-flow freeze should identify the Awakening owner"
	)
	_expect(
		bool(actor_context.get("stage7_akamu_awakening_intro_pending", false)),
		"the live frame should promote the armed edge to a pending intro"
	)
	_expect_close(
		float(actor_context.get("stage7_akamu_gameplay_freeze_remaining", 0.0)),
		AWAKEN_FREEZE_SEC - 1.0 / 60.0,
		"the live frame should begin from a fresh three-second freeze"
	)
	_expect(
		live_probe.calls == ["queue_redraw"],
		"the Awakening frame should block player, boss, and ball updates"
	)

	_advance_freeze(state, float(actor_context.get("stage7_akamu_gameplay_freeze_remaining", 0.0)))
	var aura: Dictionary = state.debug_get_wind_aura_snapshot()
	_expect(state.debug_is_awakened(), "three completed seconds should commit Awakening")
	_expect(not state.is_gameplay_freeze_active(), "completed Awakening should release gameplay freeze")
	_expect(bool(aura.get("active", false)), "Awakening completion should activate the persistent wind aura")
	_expect(int(aura.get("particle_count", 0)) == 24, "Awakening should initialize exactly 24 aura particles")
	_expect(int(aura.get("burst_particle_count", 0)) == 48, "Awakening should emit exactly 48 burst particles")


func _verify_awakening_superspeed_unlock_respects_live_pause() -> void:
	for pause_key in [
		"lingpet_star_coil_freeze_boss_skill_cd",
		"active_item_boss_skill_cooldown_paused",
	]:
		var state: Object = Stage7AkamuState.new()
		state.debug_set_gauge(250.0)
		state.handle_score_event("player", {"player_score": Stage7AkamuState.AWAKEN_SCORE_THRESHOLD})
		_expect(state.try_begin_pending_awakening(), "%s setup should start Awakening" % pause_key)
		var freeze_context: Dictionary = _base_context()
		freeze_context[pause_key] = true
		var frame_flow: Object = BattleFrameFlowController.new()
		var flow_probe := FlowProbe.new()
		var deps: Dictionary = _flow_deps(state, null, freeze_context)
		var safety_ticks := 0
		while state.is_gameplay_freeze_active() and safety_ticks < 40:
			frame_flow.update(0.1, deps, _flow_callbacks(flow_probe))
			safety_ticks += 1
		var superspeed: Dictionary = state.debug_get_superspeed_snapshot()
		_expect(state.debug_is_awakened(), "%s should not block Awakening completion" % pause_key)
		_expect(
			not bool(superspeed.get("active", true)),
			"%s completion should leave the newly unlocked ultimate inactive" % pause_key
		)
		_expect_close(
			state.debug_get_gauge(),
			250.0,
			"%s should preserve the reserved Superspeed gauge while paused" % pause_key
		)
		_expect_close(
			float(superspeed.get("cooldown_remaining_sec", 0.0)),
			ULTIMATE_COOLDOWN_SEC,
			"%s completion should arm the full unlock cooldown" % pause_key
		)
		state.update(1.0, freeze_context)
		_expect_close(
			float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0)),
			ULTIMATE_COOLDOWN_SEC,
			"%s should keep the unlock cooldown frozen after Awakening" % pause_key
		)
		state.update(0.1, _base_context())
		_expect(
			not bool(state.debug_get_superspeed_snapshot().get("active", false)),
			"releasing %s should resume the 50-second cooldown, not bypass it" % pause_key
		)
		_expect_close(state.debug_get_gauge(), 250.0, "the resumed unlock cooldown should preserve its reserved gauge")
		state.debug_set_superspeed_cooldown_remaining(0.0)
		state.update(0.0, _base_context())
		_expect(bool(state.debug_get_superspeed_snapshot().get("active", false)), "the ultimate should start once the isolated cooldown gate opens")
		_expect_close(state.debug_get_gauge(), 0.0, "the accepted post-cooldown start should deduct exactly 250 gauge")


func _verify_wind_aura_substep_guards_and_debounce() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	# Superspeed suppresses the free cloud/clone branches without changing aura
	# collision semantics, keeping this collision-order test isolated.
	state.debug_set_superspeed_active(true)
	state.debug_seed_rng(75001)
	var audio := FakeAudio.new()
	var motion_context: Dictionary = _base_context()
	motion_context.merge({
		"stage7_akamu_state": state,
		"stage7_akamu_audio": audio,
		"boss_collision_cooldown": 0.0,
		"player_collision_cooldown": 0.0,
	}, true)
	var step_result: Dictionary = BallMotionStepper.new().step(
		Vector2(380.0, 180.0),
		Vector2(0.0, -120.0),
		Vector2(0.0, -20.0),
		motion_context
	)
	_expect(
		str(step_result.get("event", "")) == "stage7_wind_aura",
		"the swept substep loop should resolve wind aura before the boss paddle"
	)
	_expect(
		float((step_result.get("ball_pos", Vector2.ZERO) as Vector2).y) > 75.0,
		"wind aura should reflect outside the boss-paddle contact band"
	)
	_expect(
		(step_result.get("ball_vel", Vector2.ZERO) as Vector2).y > 0.0,
		"wind aura should reverse an upward threat toward the player"
	)
	_expect(audio.aura_block_calls == 1, "substep aura reflection should emit one block cue")

	var guard_state: Object = Stage7AkamuState.new()
	guard_state.debug_force_complete_awakening()
	guard_state.debug_set_superspeed_active(true)
	guard_state.debug_set_gauge(450.0)
	guard_state.debug_seed_rng(75002)
	var guard_audio := FakeAudio.new()
	var context: Dictionary = _base_context()
	var boss_center := Vector2(380.0, 45.0)
	var boss_owned: Dictionary = context.duplicate(true)
	boss_owned["last_hit_by"] = "boss"
	_expect(
		guard_state.resolve_wind_aura_collision(boss_center, Vector2(0.0, -20.0), boss_owned).is_empty(),
		"boss-owned balls should pass through Akamu's own aura"
	)
	_expect(
		guard_state.resolve_wind_aura_collision(boss_center, Vector2(0.0, 20.0), context).is_empty(),
		"downward balls should not double-reflect on the aura"
	)
	var waiting_context: Dictionary = context.duplicate(true)
	waiting_context["waiting_for_serve"] = true
	_expect(
		guard_state.resolve_wind_aura_collision(boss_center, Vector2(0.0, -20.0), waiting_context).is_empty(),
		"serve-wait should disable aura collision"
	)

	var hit: Dictionary = guard_state.resolve_wind_aura_collision(
		boss_center,
		Vector2(3.0, -20.0),
		context,
		{"audio": guard_audio}
	)
	_expect(not hit.is_empty(), "a player-owned upward ball inside radius 90 should be blocked")
	_expect_close(
		float((hit.get("ball_vel", Vector2.ZERO) as Vector2).y),
		22.0,
		"aura reflection should multiply vertical speed by 1.1"
	)
	_expect_close(guard_state.debug_get_gauge(), 500.0, "aura block should add 90 gauge and cap at 500")
	_expect(int(guard_state.debug_get_wind_aura_snapshot().get("hit_count", 0)) == 1, "first block should spend one aura hit")
	_expect(
		guard_state.resolve_wind_aura_collision(boss_center, Vector2.ZERO + Vector2.UP * 20.0, context).is_empty(),
		"the same frame should be rejected by the 300ms hit debounce"
	)
	_expect(guard_audio.aura_block_calls == 1, "debounced overlap must not replay the block cue")

	var paused_context: Dictionary = context.duplicate(true)
	paused_context["lingpet_star_coil_freeze_boss_skill_cd"] = true
	_advance_state(guard_state, 0.29, paused_context)
	_expect(
		float(guard_state.debug_get_wind_aura_snapshot().get("hit_cooldown_remaining_sec", 0.0)) > 0.0,
		"aura debounce should remain closed at 290ms"
	)
	_expect(
		guard_state.resolve_wind_aura_collision(boss_center, Vector2(0.0, -20.0), context).is_empty(),
		"aura should still reject a hit before 300ms"
	)
	_advance_state(guard_state, 0.0101, paused_context)
	hit = guard_state.resolve_wind_aura_collision(
		boss_center,
		Vector2(0.0, -20.0),
		context,
		{"audio": guard_audio}
	)
	_expect(not hit.is_empty(), "aura should reopen exactly at 300ms")
	_expect(int(guard_state.debug_get_wind_aura_snapshot().get("hit_count", 0)) == 2, "reopened aura should register the second hit")
	_expect(guard_audio.aura_block_calls == 2, "reopened aura should play one new block cue")


func _verify_awakened_clone_precedes_wind_aura() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	state.debug_spawn_shadow_clones(Vector2(380.0, 45.0), true)
	var context: Dictionary = _base_context()
	_advance_state(state, 0.6, context)
	var bounce := FakeCloneBounceController.new()
	var intensity := FakeCloneBallIntensity.new()
	var start_pos := Vector2(310.0, 180.0)
	var ball_vel := Vector2(0.0, -20.0)
	var step_result: Dictionary = BallMotionStepper.new().step(
		start_pos,
		Vector2(0.0, -120.0),
		ball_vel,
		context.merged({
			"stage7_akamu_state": state,
			"boss_collision_cooldown": 0.0,
			"player_collision_cooldown": 0.0,
		}, true)
	)
	_expect(
		str(step_result.get("event", "")) == "none",
		"an awakened inner clone on the swept path should reserve collision priority before the enclosing aura"
	)
	_expect(
		bool(step_result.get("stage7_akamu_clone_collision_reserved", false)),
		"clone and aura overlap in the same swept substep should stop on the clone reservation edge"
	)
	_expect(
		int(state.debug_get_wind_aura_snapshot().get("hit_count", -1)) == 0,
		"the aura must not spend durability before the post-motion clone owner resolves its reserved hit"
	)
	var scene := {
		"previous_ball_pos": start_pos,
		"ball_pos": step_result.get("ball_pos", start_pos),
		"ball_vel": ball_vel,
	}
	_expect(
		state.resolve_ball_collision(scene, context, {
			"paddle_bounce_controller": bounce,
			"ball_intensity": intensity,
		}),
		"the reserved inner-clone sweep should commit through the existing post-motion clone owner"
	)
	_expect(bounce.calls == 1, "clone-first coexistence should commit exactly one auxiliary reflection")
	_expect(
		intensity.contact_calls == 1 and intensity.last_side == "boss",
		"the winning clone should transfer ball ownership to the boss exactly once"
	)
	_expect((scene.get("ball_vel", Vector2.ZERO) as Vector2).y > 0.0, "the winning clone should reflect the ball toward the player")
	_expect(
		int(state.debug_get_clone_snapshot().get("dying_count", 0)) == 1
		and int(state.debug_get_clone_snapshot().get("live_count", 0)) == 3,
		"clone-first coexistence should consume one clone instead of one aura durability pip"
	)


func _verify_wind_aura_pause_suppresses_rewards_not_block() -> void:
	var double_roll_seed: int = _find_double_free_roll_seed()
	_expect(double_roll_seed >= 0, "pause suppression test should have a deterministic double-roll seed")
	if double_roll_seed < 0:
		return
	for pause_key in [
		"lingpet_star_coil_freeze_boss_skill_cd",
		"active_item_boss_skill_cooldown_paused",
	]:
		var state: Object = Stage7AkamuState.new()
		state.debug_force_complete_awakening()
		state.debug_set_gauge(0.0)
		state.debug_seed_rng(double_roll_seed)
		var context: Dictionary = _base_context()
		context[pause_key] = true
		var result: Dictionary = state.resolve_wind_aura_collision(
			Vector2(380.0, 45.0),
			Vector2(0.0, -20.0),
			context
		)
		var aura: Dictionary = state.debug_get_wind_aura_snapshot()
		_expect(not result.is_empty(), "%s pause should preserve physical aura reflection" % pause_key)
		_expect(
			(result.get("ball_vel", Vector2.ZERO) as Vector2).y > 0.0,
			"%s pause should still reverse the ball" % pause_key
		)
		_expect(int(aura.get("hit_count", 0)) == 1, "%s pause should still consume aura durability" % pause_key)
		_expect_close(state.debug_get_gauge(), 0.0, "%s pause should suppress the +90 aura reward" % pause_key)
		_expect(
			not bool(state.debug_get_cloud_snapshot().get("dash_active", false)),
			"%s pause should suppress the free cloud roll" % pause_key
		)
		_expect(
			not bool(state.debug_get_clone_snapshot().get("casting", false))
			and not bool(aura.get("free_clone_queued", false)),
			"%s pause should suppress the free clone roll" % pause_key
		)

	# Seal the motion-step context forwarding too: the physics substep must carry
	# the pause bit into the aura owner rather than only handling direct calls.
	var stepped_state: Object = Stage7AkamuState.new()
	stepped_state.debug_force_complete_awakening()
	stepped_state.debug_seed_rng(double_roll_seed)
	var step_context: Dictionary = _base_context()
	step_context.merge({
		"stage7_akamu_state": stepped_state,
		"lingpet_star_coil_freeze_boss_skill_cd": true,
		"boss_collision_cooldown": 0.0,
		"player_collision_cooldown": 0.0,
	}, true)
	var scene := {
		"ball_pos": Vector2(380.0, 180.0),
		"ball_vel": Vector2(0.0, -20.0),
		"ball_impact_boost": 1.0,
		"boss_collision_cooldown": 0.0,
		"player_collision_cooldown": 0.0,
	}
	BallMotionEventProcessor.new().step_motion(
		scene,
		6.0,
		step_context,
		{
			"motion_stepper": BallMotionStepper.new(),
			"stage7_akamu_state": stepped_state,
		},
		{}
	)
	_expect(
		(scene.get("ball_vel", Vector2.ZERO) as Vector2).y > 0.0,
		"motion-event step-context forwarding should preserve the aura block"
	)
	_expect_close(stepped_state.debug_get_gauge(), 0.0, "motion-event step-context forwarding should suppress aura gauge")
	_expect(
		not bool(stepped_state.debug_get_cloud_snapshot().get("dash_active", false))
		and not bool(stepped_state.debug_get_clone_snapshot().get("casting", false)),
		"motion-event step-context forwarding should suppress both free skill rolls"
	)


func _verify_wind_aura_depletion_persistence_and_recharge() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	state.debug_set_superspeed_active(true)
	state.debug_seed_rng(75003)
	var context: Dictionary = _base_context()
	var boss_center := Vector2(380.0, 45.0)
	for _hit_index in range(5):
		state.debug_clear_wind_aura_hit_cooldown()
		var result: Dictionary = state.resolve_wind_aura_collision(
			boss_center,
			Vector2(0.0, -20.0),
			context
		)
		_expect(not result.is_empty(), "each cleared aura contact should resolve through hit five")
	var aura: Dictionary = state.debug_get_wind_aura_snapshot()
	_expect(int(aura.get("hit_count", 0)) == 5, "the fifth aura block should exhaust all five hits")
	_expect(bool(aura.get("depleted", false)), "the fifth aura block should enter depletion")
	_expect_close(
		float(aura.get("recharge_remaining_sec", 0.0)),
		WIND_AURA_RECHARGE_SEC,
		"depletion should start a full ten-second recharge"
	)
	_expect(int(aura.get("burst_particle_count", 0)) == 32, "depletion should replace the burst with 32 disperse particles")

	state.clear_round_transients()
	aura = state.debug_get_wind_aura_snapshot()
	_expect(state.debug_is_awakened(), "normal round cleanup should preserve Awakening")
	_expect(bool(aura.get("active", false)), "normal round cleanup should preserve the persistent aura")
	_expect(bool(aura.get("depleted", false)), "normal round cleanup should preserve aura depletion")
	_expect(int(aura.get("hit_count", 0)) == 5, "normal round cleanup should preserve the five spent hits")
	_expect_close(
		float(aura.get("recharge_remaining_sec", 0.0)),
		WIND_AURA_RECHARGE_SEC,
		"normal round cleanup should preserve the recharge clock"
	)
	_expect(not bool(state.debug_get_superspeed_snapshot().get("active", true)), "round cleanup should still clear transient Superspeed")

	state.debug_set_gauge(0.0)
	_advance_state(state, 9.99, context)
	aura = state.debug_get_wind_aura_snapshot()
	_expect(bool(aura.get("depleted", false)), "aura should stay depleted just before ten seconds")
	_expect_close(float(aura.get("recharge_remaining_sec", 0.0)), 0.01, "recharge should retain its final 10ms", 0.001)
	state.update(0.0101, context)
	aura = state.debug_get_wind_aura_snapshot()
	_expect(not bool(aura.get("depleted", true)), "aura should reactivate at ten seconds")
	_expect(int(aura.get("hit_count", -1)) == 0, "aura recharge should restore all five hits")
	_expect(int(aura.get("particle_count", 0)) == 24, "aura recharge should rebuild its 24 persistent particles")

	state.reset_for_result()
	aura = state.debug_get_wind_aura_snapshot()
	_expect(not state.debug_is_awakened(), "full result reset should clear Awakening")
	_expect(not bool(aura.get("active", true)), "full result reset should clear the persistent aura")
	_expect(int(aura.get("particle_count", -1)) == 0, "full result reset should clear aura particles")


func _verify_wind_aura_draw_cache_refreshes_across_frozen_boundaries() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening(Vector2(330.0, 25.0), Vector2(100.0, 40.0))
	state.debug_set_superspeed_active(true)
	var displaced_context: Dictionary = _base_context()
	displaced_context["boss_pos"] = Vector2(600.0, 100.0)
	var displaced_center := Vector2(650.0, 120.0)
	_expect(
		not state.resolve_wind_aura_collision(
			displaced_center,
			Vector2(0.0, -20.0),
			displaced_context
		).is_empty(),
		"draw-cache setup should stamp the aura at a transient boss center"
	)
	var aura_draw: Dictionary = state.get_actor_draw_context().get("stage7_akamu_wind_aura", {})
	_expect(
		aura_draw.get("center", Vector2.ZERO) == displaced_center,
		"a resolved aura block should publish the contact-frame boss center"
	)

	state.clear_round_transients()
	aura_draw = state.get_actor_draw_context().get("stage7_akamu_wind_aura", {})
	_expect(bool(aura_draw.get("active", false)), "round cleanup should keep the persistent aura draw payload active")
	_expect(
		aura_draw.get("center", Vector2.ZERO) == Vector2(380.0, 45.0),
		"round cleanup should rebuild aura position after clearing transient position writers"
	)
	_expect(
		not bool(aura_draw.get("superspeed", true)),
		"round cleanup should clear the stale Superspeed aura palette flag"
	)
	_expect_close(
		float(aura_draw.get("ripple_intensity", -1.0)),
		0.0,
		"round cleanup should clear stale aura ripple intensity"
	)

	var elapsed_before: float = float(aura_draw.get("elapsed_sec", -1.0))
	var frozen_context: Dictionary = _base_context()
	frozen_context["boss_pos"] = Vector2(120.0, 55.0)
	frozen_context["ball_active"] = false
	state.update(0.1, frozen_context)
	aura_draw = state.get_actor_draw_context().get("stage7_akamu_wind_aura", {})
	_expect(bool(aura_draw.get("active", false)), "timing freeze should preserve the persistent aura")
	_expect(
		aura_draw.get("center", Vector2.ZERO) == Vector2(170.0, 75.0),
		"timing freeze should resync aura geometry to the live boss position"
	)
	_expect_close(
		float(aura_draw.get("elapsed_sec", -2.0)),
		elapsed_before,
		"timing freeze should not advance the persistent aura animation timer"
	)


func _verify_independent_free_cloud_and_clone_rolls() -> void:
	var seed_value: int = _find_double_free_roll_seed()
	_expect(seed_value >= 0, "a deterministic seed should exercise both independent 30% aura rolls")
	if seed_value < 0:
		return
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	state.debug_set_gauge(0.0)
	state.debug_seed_rng(seed_value)
	var context: Dictionary = _base_context()
	var result: Dictionary = state.resolve_wind_aura_collision(
		Vector2(380.0, 45.0),
		Vector2(0.0, -20.0),
		context
	)
	var cloud: Dictionary = state.debug_get_cloud_snapshot()
	var aura: Dictionary = state.debug_get_wind_aura_snapshot()
	_expect(not result.is_empty(), "double-roll seed should still resolve the aura block")
	_expect(bool(cloud.get("dash_active", false)), "the successful cloud roll should start a free cloud cast")
	_expect(bool(aura.get("free_clone_queued", false)), "the independent clone success should queue behind cloud's position writer")
	_expect_close(state.debug_get_gauge(), 90.0, "free cloud should not spend the aura block's 90 gained gauge")

	_advance_state(state, 0.4001, context)
	_advance_state(state, 0.3161, context)
	_advance_state(state, 0.3161, context)
	# Cloud completion publishes its home release once. The following owner tick
	# clears that edge and commits the already-successful independent clone roll.
	state.update(0.0, context)
	var clone: Dictionary = state.debug_get_clone_snapshot()
	_expect(not bool(state.debug_get_cloud_snapshot().get("dash_active", true)), "cloud should release its writer after 0.4+0.316+0.316s")
	_expect(bool(clone.get("casting", false)), "queued independent clone success should start when cloud releases")
	_expect(bool(clone.get("cast_free", false)), "queued aura clone should retain its free transactional source")
	_expect(
		str(clone.get("cast_source", "")) == "wind_aura_queued",
		"queued aura clone should expose its dedicated source"
	)
	_expect_close(state.debug_get_gauge(), 90.0, "queued free clone should not reserve or deduct gauge")
	_advance_state(state, 0.50, context)
	clone = state.debug_get_clone_snapshot()
	_expect(int(clone.get("live_count", 0)) == 4, "awakened free clone commit should spawn four clones")
	_expect_close(state.debug_get_gauge(), 90.0, "free clone commit should remain gauge-transactional")


func _verify_superspeed_activation_duration_cooldown_and_hud() -> void:
	var forced_state: Object = Stage7AkamuState.new()
	forced_state.debug_force_complete_awakening()
	forced_state.debug_set_superspeed_cooldown_remaining(0.0)
	forced_state.debug_set_gauge(249.0)
	_expect(
		not forced_state.debug_start_superspeed(_base_context()),
		"forced Superspeed should reject gauge below 250 without spending it"
	)
	_expect_close(forced_state.debug_get_gauge(), 249.0, "failed forced Superspeed should preserve gauge")
	forced_state.debug_set_gauge(250.0)
	_expect(forced_state.debug_start_superspeed(_base_context()), "forced Superspeed should start at exactly 250 gauge")
	_expect_close(forced_state.debug_get_gauge(), 0.0, "forced Superspeed should deduct exactly 250 gauge")

	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	state.debug_set_superspeed_cooldown_remaining(0.0)
	state.debug_set_gauge(250.0)
	var context: Dictionary = _base_context()
	state.update(0.0, context)
	var snapshot: Dictionary = state.debug_get_superspeed_snapshot()
	var actor_context: Dictionary = state.get_actor_draw_context()
	_expect(bool(snapshot.get("active", false)), "eligible awakened state should auto-start Superspeed")
	_expect_close(state.debug_get_gauge(), 0.0, "automatic Superspeed should deduct 250 gauge")
	_expect_close(float(snapshot.get("remaining_sec", 0.0)), SUPERSPEED_DURATION_SEC, "Superspeed should start with ten seconds")
	_expect_close(
		float(actor_context.get("stage7_akamu_gameplay_freeze_remaining", 0.0)),
		SUPERSPEED_FREEZE_SEC,
		"Superspeed should start its 350ms activation freeze"
	)
	_expect(
		str(actor_context.get("stage7_akamu_gameplay_freeze_reason", "")) == "superspeed",
		"Superspeed activation freeze should expose its owner"
	)

	var card: Dictionary = _find_skill(
		state.get_hud_context().get("stage7_boss_skill_hud_skills", []),
		"stage7_superspeed"
	)
	_expect(bool(card.get("implemented", false)), "Superspeed HUD card should leave placeholder mode")
	_expect(bool(card.get("active", false)) and str(card.get("status", "")) == "active", "active Superspeed should own active card styling")
	_expect_close(float(card.get("cost", 0.0)), 250.0, "Superspeed HUD should expose its real cost")
	_expect_close(float(card.get("duration_total", 0.0)), 10.0, "Superspeed HUD should expose its real duration")
	_expect_close(float(card.get("cooldown_total", 0.0)), ULTIMATE_COOLDOWN_SEC, "Superspeed HUD should expose its real cooldown")

	_advance_freeze(state, SUPERSPEED_FREEZE_SEC)
	snapshot = state.debug_get_superspeed_snapshot()
	_expect(not state.is_gameplay_freeze_active(), "350ms should release Superspeed activation freeze")
	_expect_close(
		float(snapshot.get("remaining_sec", 0.0)),
		SUPERSPEED_DURATION_SEC - SUPERSPEED_FREEZE_SEC,
		"the activation freeze should count inside the ten-second duration"
	)

	state.handle_boss_paddle_hit({"ball_pos": Vector2(380.0, 80.0)}, context)
	_expect_close(state.debug_get_gauge(), 20.0, "boss paddle hits during Superspeed should gain only 20 gauge")
	state.notify_superspeed_dash_started(
		Vector2(330.0, 25.0),
		Vector2(100.0, 40.0),
		1,
		710.0,
		11.0
	)
	snapshot = state.debug_get_superspeed_snapshot()
	_expect(int(snapshot.get("afterimage_count", 0)) == 5, "each Superspeed dash should spawn five delayed afterimages")
	_advance_state(state, 4.0, context)
	snapshot = state.debug_get_superspeed_snapshot()
	_expect(int(snapshot.get("dark_particle_count", 0)) > 0, "active Superspeed should continuously emit dark particles")
	_expect(int(snapshot.get("dark_particle_count", 0)) <= 200, "Superspeed dark particles should respect the 200 cap")
	_expect(int(snapshot.get("trail_count", 0)) > 0, "active Superspeed should emit movement trails")
	_expect(int(snapshot.get("trail_count", 0)) <= 30, "Superspeed movement trails should respect the 30 cap")

	var remaining: float = float(snapshot.get("remaining_sec", 0.0))
	_advance_state(state, maxf(0.0, remaining - 0.001), context)
	_expect(bool(state.debug_get_superspeed_snapshot().get("active", false)), "Superspeed should remain active until just before ten seconds")
	state.update(0.0011, context)
	snapshot = state.debug_get_superspeed_snapshot()
	_expect(not bool(snapshot.get("active", true)), "Superspeed should end naturally at ten seconds including freeze")
	_expect_close(
		float(snapshot.get("cooldown_remaining_sec", 0.0)),
		ULTIMATE_COOLDOWN_SEC,
		"natural Superspeed expiry should arm a fresh 50-second cooldown"
	)

	var paused_context: Dictionary = context.duplicate(true)
	paused_context["lingpet_star_coil_freeze_boss_skill_cd"] = true
	var cooldown_before: float = float(snapshot.get("cooldown_remaining_sec", 0.0))
	_advance_state(state, 1.0, paused_context)
	_expect_close(
		float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0)),
		cooldown_before,
		"boss-skill cooldown pause should stop Superspeed recharge"
	)
	state.update(0.1, context)
	_expect_close(
		float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0)),
		cooldown_before - 0.1,
		"Superspeed cooldown should resume after the pause"
	)
	var cooldown_remaining: float = float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0))
	_advance_state(state, maxf(0.0, cooldown_remaining - 0.001), context)
	_expect(
		float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0)) > 0.0,
		"Superspeed cooldown should remain closed immediately before 50 active seconds"
	)
	state.update(0.0011, context)
	_expect_close(
		float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", -1.0)),
		0.0,
		"Superspeed cooldown should reopen after 50 unpaused seconds"
	)


func _verify_superspeed_predictive_ai_and_recovery() -> void:
	var clamp_state: Object = Stage7AkamuState.new()
	clamp_state.debug_force_complete_awakening()
	clamp_state.debug_set_gauge(123.0)
	clamp_state.debug_set_superspeed_active(true)
	var clamp_context: Dictionary = _superspeed_ai_context(clamp_state, 999.0)
	var clamp_ai: Object = BossAIState.new()
	var boss_pos := Vector2(330.0, 25.0)
	var result: Dictionary = clamp_ai.update(0.0, boss_pos, 0.0, clamp_context)
	var snapshot: Dictionary = clamp_state.debug_get_superspeed_snapshot()
	_expect(bool(snapshot.get("dash_active", false)), "Superspeed AI should immediately start a predictive dash")
	_expect_close(float(snapshot.get("dash_target_center_x", 0.0)), 710.0, "predicted target should clamp to the right boss-center bound")
	_expect(int(snapshot.get("dash_direction", 0)) == 1, "right-clamped prediction should dash right")
	_expect_close(absf(float(result.get("boss_vel", 0.0))), 40.0, "Superspeed dash should expose its 40px/frame peak speed")
	_expect(result.get("boss_pos", Vector2.ZERO) == boss_pos, "zero-delta prediction should not move before its physics tick")
	_expect(int(snapshot.get("afterimage_count", 0)) == 5, "predictive dash start should notify the VFX owner once")
	_expect_close(
		clamp_state.debug_get_gauge(),
		123.0,
		"Superspeed's dedicated predictive dash branch should remain free"
	)

	var recovery_state: Object = Stage7AkamuState.new()
	recovery_state.debug_force_complete_awakening()
	recovery_state.debug_set_superspeed_active(true)
	var recovery_context: Dictionary = _superspeed_ai_context(recovery_state, 430.0)
	var recovery_ai: Object = BossAIState.new()
	var first: Dictionary = recovery_ai.update(1.0 / 60.0, boss_pos, 0.0, recovery_context)
	_expect(
		(first.get("boss_pos", boss_pos) as Vector2).x > boss_pos.x,
		"first Superspeed physics tick should move toward the predicted ball x"
	)
	# 원본 파리티(pingfighter.py:178296-178306): 짧은 인터셉트가 목표에 도달해도
	# 대시를 즉시 종료하지 않고 타이머가 끝날 때까지 목표에 머문다. 조기 종료는
	# 재대시를 앞당겨 극정호신 템포를 원본보다 빠르게 만든다(2026-07-11 라이브 QA).
	var second: Dictionary = recovery_ai.update(
		1.0 / 60.0,
		first.get("boss_pos", boss_pos) as Vector2,
		float(first.get("boss_vel", 0.0)),
		recovery_context
	)
	_expect(
		bool(recovery_state.debug_get_superspeed_snapshot().get("dash_active", false)),
		"reaching the target must HOLD the dash (tempo parity), not early-finish"
	)
	# 목표에 도달한 뒤 잔여 프레임 동안 정지 유지(속도 0, 위치 고정).
	var hold_pos: Vector2 = second.get("boss_pos", boss_pos) as Vector2
	for _hold_frame in range(3):
		var hold_tick: Dictionary = recovery_ai.update(1.0 / 60.0, hold_pos, 0.0, recovery_context)
		_expect(
			bool(recovery_state.debug_get_superspeed_snapshot().get("dash_active", false)),
			"superspeed dash holds at the target until its duration timer elapses"
		)
		_expect(
			absf((hold_tick.get("boss_pos", hold_pos) as Vector2).x - hold_pos.x) < 0.5
			and is_zero_approx(float(hold_tick.get("boss_vel", 1.0))),
			"held boss should stay put at the target with zero velocity"
		)
		hold_pos = hold_tick.get("boss_pos", hold_pos)
	# 새 목표를 준 뒤 타이머 만료까지 진행 -> 종료 -> 1틱 회복 -> 재대시 재개.
	recovery_context["ball_pos"] = Vector2(700.0, 300.0)
	var finish_pos: Vector2 = hold_pos
	var did_finish := false
	for _finish_frame in range(8):
		var finish_tick: Dictionary = recovery_ai.update(1.0 / 60.0, finish_pos, 0.0, recovery_context)
		finish_pos = finish_tick.get("boss_pos", finish_pos)
		if not bool(recovery_state.debug_get_superspeed_snapshot().get("dash_active", true)):
			did_finish = true
			break
	_expect(did_finish, "superspeed dash should finish once its full duration timer elapses")
	var resume_pos: Vector2 = finish_pos
	var did_resume := false
	for _resume_frame in range(4):
		var resume_tick: Dictionary = recovery_ai.update(1.0 / 60.0, resume_pos, 0.0, recovery_context)
		if (resume_tick.get("boss_pos", resume_pos) as Vector2).x > resume_pos.x + 0.01:
			did_resume = true
			break
		resume_pos = resume_tick.get("boss_pos", resume_pos)
	_expect(did_resume, "Superspeed should resume predictive dashing after the recovery window")

	var order_probe := FlowProbe.new()
	BattleFrameFlowController.new().update(
		1.0 / 60.0,
		_flow_deps(recovery_state, null),
		_flow_callbacks(order_probe)
	)
	_expect(
		order_probe.calls.find("update_boss_ai") >= 0
		and order_probe.calls.find("update_ball") > order_probe.calls.find("update_boss_ai"),
		"battle frame flow should advance Superspeed boss AI before ball physics"
	)


func _verify_common_dash_gauge_transaction_and_superspeed_free_path() -> void:
	var missing_owner_ai: Object = BossAIState.new()
	missing_owner_ai.update(
		1.0 / 60.0,
		Vector2(330.0, 25.0),
		0.0,
		_common_dash_context(null)
	)
	_expect(
		not bool(missing_owner_ai.get("boss_dash_active")),
		"ordinary Stage 7 dash should fail closed when its gauge owner is missing"
	)

	var underfunded_state: Object = Stage7AkamuState.new()
	underfunded_state.debug_set_gauge(49.0)
	var underfunded_ai: Object = BossAIState.new()
	underfunded_ai.update(
		1.0 / 60.0,
		Vector2(330.0, 25.0),
		0.0,
		_common_dash_context(underfunded_state)
	)
	_expect(
		not bool(underfunded_ai.get("boss_dash_active")),
		"ordinary Stage 7 dash should reject 49 gauge after geometry acceptance"
	)
	_expect_close(
		underfunded_state.debug_get_gauge(),
		49.0,
		"failed ordinary dash transaction should preserve all gauge"
	)

	var funded_state: Object = Stage7AkamuState.new()
	funded_state.debug_set_gauge(50.0)
	var funded_ai: Object = BossAIState.new()
	funded_ai.update(
		1.0 / 60.0,
		Vector2(330.0, 25.0),
		0.0,
		_common_dash_context(funded_state)
	)
	_expect(
		bool(funded_ai.get("boss_dash_active")),
		"ordinary Stage 7 dash should start when geometry and exact 50 gauge both commit"
	)
	_expect_close(
		funded_state.debug_get_gauge(),
		0.0,
		"ordinary Stage 7 dash should deduct its 50 gauge only after acceptance"
	)


func _verify_superspeed_round_cleanup() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	state.debug_set_superspeed_cooldown_remaining(0.0)
	state.debug_set_gauge(250.0)
	_expect(state.debug_start_superspeed(_base_context()), "round-cleanup precondition should start Superspeed")
	state.notify_superspeed_dash_started(Vector2(330.0, 25.0), Vector2(100.0, 40.0), 1, 710.0, 11.0)
	var superspeed_cooldown_before: float = float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", -1.0))
	state.clear_round_transients()
	var snapshot: Dictionary = state.debug_get_superspeed_snapshot()
	var aura: Dictionary = state.debug_get_wind_aura_snapshot()
	_expect(not bool(snapshot.get("active", true)), "round cleanup should cancel active Superspeed")
	_expect_close(float(snapshot.get("remaining_sec", -1.0)), 0.0, "round cleanup should clear Superspeed duration")
	# 원본 파리티(2026-07-12): 스킬 쿨타임은 라운드 경계를 넘어 유지된다(리셋 아님).
	_expect_close(
		float(snapshot.get("cooldown_remaining_sec", -1.0)),
		superspeed_cooldown_before,
		"Superspeed cooldown must PERSIST across the round boundary (not reset)"
	)
	_expect(int(snapshot.get("afterimage_count", -1)) == 0, "round cleanup should clear Superspeed afterimages")
	_expect(int(snapshot.get("dark_particle_count", -1)) == 0, "round cleanup should clear Superspeed particles")
	_expect(int(snapshot.get("trail_count", -1)) == 0, "round cleanup should clear Superspeed trails")
	_expect(state.debug_is_awakened() and bool(aura.get("active", false)), "round cleanup should preserve Awakening and wind aura")


func _find_double_free_roll_seed() -> int:
	var context: Dictionary = _base_context()
	for seed_value in range(1, 4097):
		var state: Object = Stage7AkamuState.new()
		state.debug_force_complete_awakening()
		state.debug_seed_rng(seed_value)
		state.resolve_wind_aura_collision(
			Vector2(380.0, 45.0),
			Vector2(0.0, -20.0),
			context
		)
		if (
			bool(state.debug_get_cloud_snapshot().get("dash_active", false))
			and bool(state.debug_get_wind_aura_snapshot().get("free_clone_queued", false))
		):
			return seed_value
	return -1


func _superspeed_ai_context(state: Object, ball_x: float) -> Dictionary:
	var context: Dictionary = _base_context()
	context.merge({
		"ball_pos": Vector2(ball_x, 300.0),
		"ball_vel": Vector2.ZERO,
		"play_left": 0.0,
		"play_right": 760.0,
	}, true)
	context.merge(state.get_boss_ai_context(), true)
	return context


func _common_dash_context(state_owner: Object) -> Dictionary:
	var context: Dictionary = _base_context()
	context.merge({
		"ball_pos": Vector2(700.0, 100.0),
		"ball_vel": Vector2(0.0, -20.0),
		"ball_impact_boost": 1.0,
		"boss_max_speed": 6.0,
		"boss_dash_enabled": true,
		"boss_dash_trigger_chance": 1.0,
		"boss_dash_max_distance": 316.8,
		"play_left": 0.0,
		"play_right": 760.0,
	}, true)
	if state_owner != null:
		context.merge(state_owner.get_boss_ai_context(), true)
	return context


func _flow_deps(
	state: Object,
	scoreboard: Object,
	freeze_context: Dictionary = {}
) -> Dictionary:
	return {
		"current_stage": 7,
		"stage7_akamu_state": state,
		"stage7_akamu_freeze_context": freeze_context,
		"scoreboard_state": scoreboard,
		"skill_orb_tooltip_active": false,
		"power_state": null,
		"round_state": null,
		"mythic_item_runtime": null,
	}


func _flow_callbacks(probe: FlowProbe) -> Dictionary:
	return {
		"update_weather": Callable(probe, "update_weather"),
		"update_mythic_items": Callable(probe, "update_mythic_items"),
		"update_player_control": Callable(probe, "update_player_control"),
		"update_runtime_perk_resume": Callable(probe, "update_runtime_perk_resume"),
		"update_active_items": Callable(probe, "update_active_items"),
		"update_boss_ai": Callable(probe, "update_boss_ai"),
		"update_ball": Callable(probe, "update_ball"),
		"update_lingpet": Callable(probe, "update_lingpet"),
		"update_effects": Callable(probe, "update_effects"),
		"queue_redraw": Callable(probe, "queue_redraw"),
	}


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 300.0),
		"ball_vel": Vector2(0.0, -20.0),
		"ball_size": 20.0,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"hitbox_padding": 5.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"last_hit_by": "player",
	}


func _advance_state(
	state: Object,
	duration_sec: float,
	context: Dictionary,
	deps: Dictionary = {}
) -> void:
	var remaining: float = maxf(0.0, duration_sec)
	while remaining > 0.000001:
		var step: float = minf(0.1, remaining)
		state.update(step, context, deps)
		remaining -= step


func _advance_freeze(state: Object, duration_sec: float) -> void:
	var remaining: float = maxf(0.0, duration_sec)
	while remaining > 0.000001:
		var step: float = minf(0.1, remaining)
		state.advance_gameplay_freeze(step)
		remaining -= step


func _find_skill(value: Variant, skill_id: String) -> Dictionary:
	if not (value is Array):
		return {}
	for entry_value in value:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == skill_id:
			return entry_value
	return {}


func _expect_close(
	actual: float,
	expected: float,
	message: String,
	tolerance: float = 0.0001
) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.5f, got %.5f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
