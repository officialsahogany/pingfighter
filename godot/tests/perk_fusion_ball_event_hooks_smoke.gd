extends SceneTree

const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")

const OVERLOAD_SPEED_CAP_KEY := "perk_fusion_overload_speed_cap"
const OVERLOAD_SPEED_CAP_FRAMES_KEY := "perk_fusion_overload_speed_cap_frames"

var _failures: Array[String] = []


class FakeMotionStepper:
	extends RefCounted

	var response: Dictionary

	func _init(next_response: Dictionary) -> void:
		response = next_response

	func step(_ball_pos: Vector2, _step_vel: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return response.duplicate(true)


class FakeWallBounceController:
	extends RefCounted

	func process(
		ball_vel: Vector2,
		_impact_boost: float,
		_side: String,
		_impact_pos: Vector2,
		_height: float,
		_deps: Dictionary
	) -> Dictionary:
		return {"ball_vel": Vector2(abs(ball_vel.x), ball_vel.y)}


class FakePaddleBounceController:
	extends RefCounted

	var result: Dictionary

	func _init(next_result: Dictionary) -> void:
		result = next_result

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		_context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary
	) -> Dictionary:
		return result.duplicate(true)


class FakeBallPhysics:
	extends RefCounted

	var dynamic_impact_boost := 1.0

	func _init(next_dynamic_impact_boost: float = 1.0) -> void:
		dynamic_impact_boost = next_dynamic_impact_boost

	func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
		return velocity

	func get_minimum_effective_boost(_velocity: Vector2) -> float:
		return 1.0

	func compute_dynamic_impact_boost(
		_ball_velocity: Vector2,
		_current_speed: float,
		_launch_angle_rad: float
	) -> Dictionary:
		return {
			"boost": dynamic_impact_boost,
			"decay_rate": 0.975,
			"min_boost": 0.70,
		}


class FakeFusionRuntime:
	extends RefCounted

	var overload_multiplier := 1.15
	var overload_consume_count := 0
	var wall_award := 2
	var wall_query_count := 0
	var gold_awards: Array[int] = []
	var skill_use_count := 0
	var round_reset_count := 0

	func consume_perk_fusion_paddle_bounce_speed_multiplier() -> float:
		overload_consume_count += 1
		var result := overload_multiplier
		overload_multiplier = 1.0
		return result

	func award_perk_fusion_wall_bounce_gold(_context: Dictionary = {}, _deps: Dictionary = {}) -> int:
		wall_query_count += 1
		if wall_award > 0:
			gold_awards.append(wall_award)
		return wall_award

	func notify_perk_fusion_skill_used() -> void:
		skill_use_count += 1

	var dash_notify_count := 0

	func notify_perk_fusion_player_dash() -> void:
		dash_notify_count += 1

	func reset_perk_fusion_round_byproducts() -> void:
		round_reset_count += 1
		overload_multiplier = 1.0


class FakeBallOwner:
	extends RefCounted

	var perk_fusion_overload_speed_cap := 35.0
	var perk_fusion_overload_speed_cap_frames := 90.0

	func _get(_property: StringName) -> Variant:
		return null


func _init() -> void:
	_verify_player_paddle_consumes_overload_after_a_real_bounce()
	_verify_canonical_paddle_normalizes_effective_speed_before_overload()
	_verify_overload_opens_effective_rally_cap_until_boss_return()
	_verify_overload_cap_outlanks_ordinary_hard_caps()
	_verify_round_cleanup_resets_overload_arm()
	_verify_boss_or_empty_paddle_result_does_not_consume_overload()
	_verify_paddle_owned_power_and_drive_edges_notify_skill_use_once()
	_verify_confirmed_dash_start_notifies_fusion_dash_hook_once()
	_verify_real_ball_update_ticks_overload_ttl_closed()
	_verify_wall_bounce_routes_fusion_gold_through_runtime_award_flow()

	if _failures.is_empty():
		print("perk_fusion_ball_event_hooks_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_player_paddle_consumes_overload_after_a_real_bounce() -> void:
	var runtime := FakeFusionRuntime.new()
	var scene := _base_scene()
	var processor := BallMotionEventProcessor.new()
	processor.step_motion(
		scene,
		1.0,
		_base_context(),
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(true)),
			"paddle_bounce_controller": FakePaddleBounceController.new({"ball_vel": Vector2(3.0, -4.0)}),
			"runtime_perk_state": runtime,
		},
		{}
	)
	_expect(runtime.overload_consume_count == 1, "successful player paddle bounce should consume overload exactly once")
	_expect(
		_get_vector2(scene, "ball_vel", Vector2.ZERO).is_equal_approx(Vector2(3.45, -4.6)),
		"overload should multiply the committed outgoing player-paddle velocity by 1.15"
	)


func _verify_canonical_paddle_normalizes_effective_speed_before_overload() -> void:
	const ORDINARY_EFFECTIVE_CAP := 30.5
	const IMPACT_BOOST := 1.2
	const OVERLOAD_EFFECTIVE_CAP := ORDINARY_EFFECTIVE_CAP * 1.15
	var runtime := FakeFusionRuntime.new()
	var physics := FakeBallPhysics.new(IMPACT_BOOST)
	var scene := _base_scene()
	scene.merge({
		"ball_pos": Vector2(380.0, 680.0),
		"ball_vel": Vector2(0.0, ORDINARY_EFFECTIVE_CAP / IMPACT_BOOST),
		"ball_impact_boost": IMPACT_BOOST,
	}, true)
	var context := _base_context()
	context.merge({
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_height": 50.0,
		"player_speed": 0.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_vel": 0.0,
		"selected_character_type": "smasher",
		"min_ball_speed": 3.0,
		"max_ball_speed": 30.0,
		"impact_boost_max_ball_speed": 30.0,
		"rally_speed_cap_bonus": 4.0,
		"rally_speed_cap_increase_per_hit": 0.5,
		"rally_speed_cap_bonus_max": 10.0,
		"max_bounce_angle": 60.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
	}, true)
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		context,
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(true)),
			"paddle_bounce_controller": PaddleBounceController.new(),
			"paddle_bounce_state": PaddleBounceState.new(),
			"ball_physics": physics,
			"runtime_perk_state": runtime,
		},
		{}
	)
	var effective_speed: float = (
		_get_vector2(scene, "ball_vel", Vector2.ZERO).length()
		* float(scene.get("ball_impact_boost", 1.0))
	)
	_expect(runtime.overload_consume_count == 1, "canonical paddle and event fallback must not consume overload twice")
	_expect_close(effective_speed, OVERLOAD_EFFECTIVE_CAP, "impact boost should still produce exactly ordinary effective cap * 1.15")
	_expect_close(float(scene.get(OVERLOAD_SPEED_CAP_KEY, 0.0)), OVERLOAD_EFFECTIVE_CAP, "transient cap should be stored in effective-speed space")
	BallFrameMotionController.new().apply_ball_speed_limits(scene, {"ball_physics": physics})
	_expect_close(
		_get_vector2(scene, "ball_vel", Vector2.ZERO).length()
			* float(scene.get("ball_impact_boost", 1.0)),
		OVERLOAD_EFFECTIVE_CAP,
		"same-frame limiter should preserve exact +15% with impact boost"
	)

	# A later player return without a new charge closes any stale excursion left
	# by an auxiliary boss-side reflector instead of treating the cap as a marker.
	scene["ball_vel"] = Vector2(0.0, ORDINARY_EFFECTIVE_CAP / IMPACT_BOOST)
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		context,
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(true)),
			"paddle_bounce_controller": FakePaddleBounceController.new({
				"ball_vel": Vector2(0.0, -ORDINARY_EFFECTIVE_CAP / IMPACT_BOOST),
				"ball_impact_boost": IMPACT_BOOST,
			}),
			"ball_physics": physics,
			"runtime_perk_state": runtime,
		},
		{}
	)
	_expect_close(float(scene.get(OVERLOAD_SPEED_CAP_KEY, -1.0)), 0.0, "uncharged next player return should close a stale overload cap")


func _verify_overload_opens_effective_rally_cap_until_boss_return() -> void:
	# The player bounce itself advances the rally cap by 0.5. Overload must use
	# that committed effective cap (base 26 + prior bonus 4 + this hit 0.5), not
	# the base league cap, and must survive the same frame's final clamp.
	const BASE_CAP := 26.0
	const PRIOR_RALLY_BONUS := 4.0
	const RALLY_INCREMENT := 0.5
	const EFFECTIVE_CAP := BASE_CAP + PRIOR_RALLY_BONUS + RALLY_INCREMENT
	const OVERLOAD_MULTIPLIER := 1.15
	const BOOSTED_CAP := EFFECTIVE_CAP * OVERLOAD_MULTIPLIER

	var runtime := FakeFusionRuntime.new()
	var scene := _base_scene()
	scene["max_ball_speed"] = BASE_CAP + PRIOR_RALLY_BONUS
	scene["impact_boost_max_ball_speed"] = BASE_CAP + PRIOR_RALLY_BONUS
	scene["rally_speed_cap_bonus"] = PRIOR_RALLY_BONUS
	var context := _base_context()
	context["max_ball_speed"] = BASE_CAP + PRIOR_RALLY_BONUS
	context["impact_boost_max_ball_speed"] = BASE_CAP + PRIOR_RALLY_BONUS
	context["rally_speed_cap_bonus"] = PRIOR_RALLY_BONUS
	context["rally_speed_cap_increase_per_hit"] = RALLY_INCREMENT
	context["rally_speed_cap_bonus_max"] = 10.0

	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		context,
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(true)),
			"paddle_bounce_controller": FakePaddleBounceController.new({
				"ball_vel": Vector2(0.0, -EFFECTIVE_CAP),
				"rally_speed_cap_bonus": PRIOR_RALLY_BONUS + RALLY_INCREMENT,
				"max_ball_speed": EFFECTIVE_CAP,
				"impact_boost_max_ball_speed": EFFECTIVE_CAP,
			}),
			"runtime_perk_state": runtime,
		},
		{}
	)
	_expect(runtime.overload_consume_count == 1, "at-cap player bounce should consume overload once")
	_expect_close(
		float(scene.get(OVERLOAD_SPEED_CAP_KEY, 0.0)),
		BOOSTED_CAP,
		"overload should open a transient cap from the committed rally-adjusted cap"
	)
	_expect(float(scene.get(OVERLOAD_SPEED_CAP_FRAMES_KEY, 0.0)) > 0.0, "overload cap should arm a bounded failsafe TTL")

	# This is the real post-motion clamp that currently swallows the multiplier.
	# The overload cap must keep the same-frame effective speed at cap * 1.15.
	BallFrameMotionController.new().apply_ball_speed_limits(
		scene,
		{"ball_physics": FakeBallPhysics.new()}
	)
	_expect_close(
		_get_vector2(scene, "ball_vel", Vector2.ZERO).length(),
		BOOSTED_CAP,
		"same-frame clamp should preserve overload speed at effective cap * 1.15"
	)

	# Overload is a one-rally excursion. Exercise the same event processor that
	# owns the real boss-paddle result, then run the update controller's final
	# same-tick clamp after that owner clears the transient cap.
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		context,
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(false)),
			"paddle_bounce_controller": FakePaddleBounceController.new({
				"ball_vel": Vector2(0.0, BOOSTED_CAP),
			}),
			"runtime_perk_state": runtime,
		},
		{}
	)
	BallFrameMotionController.new().apply_ball_speed_limits(
		scene,
		{"ball_physics": FakeBallPhysics.new()}
	)
	_expect_close(
		float(scene.get(OVERLOAD_SPEED_CAP_KEY, -1.0)),
		0.0,
		"boss return should clear the overload cap key"
	)
	_expect_close(float(scene.get(OVERLOAD_SPEED_CAP_FRAMES_KEY, -1.0)), 0.0, "boss return should clear the overload cap TTL")
	_expect_close(
		_get_vector2(scene, "ball_vel", Vector2.ZERO).length(),
		EFFECTIVE_CAP,
		"boss return should restore ball speed to the effective rally cap"
	)

	var round_reset: Dictionary = BallRoundState.new().build_common_snapshot()
	_expect_close(
		float(round_reset.get(OVERLOAD_SPEED_CAP_KEY, -1.0)),
		0.0,
		"round reset should clear the overload cap even before a boss return"
	)
	_expect_close(float(round_reset.get(OVERLOAD_SPEED_CAP_FRAMES_KEY, -1.0)), 0.0, "round reset should clear the overload cap TTL")

	for score_event in ["player_scored", "boss_scored"]:
		var score_scene := _base_scene()
		score_scene[OVERLOAD_SPEED_CAP_KEY] = BOOSTED_CAP
		score_scene[OVERLOAD_SPEED_CAP_FRAMES_KEY] = 90.0
		BallMotionEventProcessor.new().step_motion(
			score_scene,
			1.0,
			context,
			{"motion_stepper": FakeMotionStepper.new({"event": score_event})},
			{}
		)
		_expect_close(float(score_scene.get(OVERLOAD_SPEED_CAP_KEY, -1.0)), 0.0, "%s should clear the overload cap" % score_event)
		_expect_close(float(score_scene.get(OVERLOAD_SPEED_CAP_FRAMES_KEY, -1.0)), 0.0, "%s should clear the overload cap TTL" % score_event)

	_expect(
		BattleSceneState.DEFAULT_VALUES.has(OVERLOAD_SPEED_CAP_KEY)
			and BattleSceneState.DEFAULT_VALUES.has(OVERLOAD_SPEED_CAP_FRAMES_KEY),
		"overload cap keys must be declared in the battle owner schema"
	)
	var owner_snapshot: Dictionary = BallUpdateOwnerSnapshot.new().build(FakeBallOwner.new())
	_expect_close(float(owner_snapshot.get(OVERLOAD_SPEED_CAP_KEY, 0.0)), 35.0, "owner snapshot should preserve the overload cap across frames")
	_expect_close(float(owner_snapshot.get(OVERLOAD_SPEED_CAP_FRAMES_KEY, 0.0)), 90.0, "owner snapshot should preserve the overload TTL across frames")
	var scene_snapshot: Dictionary = BallUpdateController.new()._build_scene_snapshot(owner_snapshot)
	_expect_close(float(scene_snapshot.get(OVERLOAD_SPEED_CAP_KEY, 0.0)), 35.0, "scene snapshot whitelist should preserve the overload cap")

	var ttl_scene: Dictionary = {
		"ball_vel": Vector2(0.0, BOOSTED_CAP),
		"ball_impact_boost": 1.0,
		"max_ball_speed": EFFECTIVE_CAP,
	}
	ttl_scene[OVERLOAD_SPEED_CAP_KEY] = BOOSTED_CAP
	ttl_scene[OVERLOAD_SPEED_CAP_FRAMES_KEY] = 1.0
	var motion := BallFrameMotionController.new()
	motion.update_perk_fusion_overload_speed_cap(ttl_scene, 1.0)
	motion.apply_ball_speed_limits(ttl_scene, {"ball_physics": FakeBallPhysics.new()})
	_expect_close(float(ttl_scene.get(OVERLOAD_SPEED_CAP_KEY, -1.0)), 0.0, "failsafe TTL should close a leaked overload cap")
	_expect_close(_get_vector2(ttl_scene, "ball_vel", Vector2.ZERO).length(), EFFECTIVE_CAP, "TTL expiry should restore the effective cap")

	var aipill_scene: Dictionary = {
		"ball_vel": Vector2(0.0, BOOSTED_CAP + 10.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": EFFECTIVE_CAP,
		"active_item_aipill_ball_boost_active": true,
	}
	aipill_scene[OVERLOAD_SPEED_CAP_KEY] = BOOSTED_CAP
	motion.apply_ball_speed_limits(aipill_scene, {"ball_physics": FakeBallPhysics.new()})
	_expect_close(
		_get_vector2(aipill_scene, "ball_vel", Vector2.ZERO).length(),
		BOOSTED_CAP + 10.0,
		"AI pill unlimited policy should remain dominant when overload cap also exists"
	)


func _verify_overload_cap_outlanks_ordinary_hard_caps() -> void:
	const OPEN_CAP := 40.25
	var motion := BallFrameMotionController.new()
	for policy in [
		{"fire_weather_speed_cap_active": true, "fire_weather_max_ball_speed": 35.0},
		{"stage4_meditation_release_speed_cap": 30.0},
	]:
		var scene := {
			"ball_vel": Vector2(0.0, OPEN_CAP),
			"ball_impact_boost": 1.0,
			"max_ball_speed": 35.0,
			OVERLOAD_SPEED_CAP_KEY: OPEN_CAP,
		}
		scene.merge(policy, true)
		motion.apply_ball_speed_limits(scene, {"ball_physics": FakeBallPhysics.new()})
		_expect_close(_get_vector2(scene, "ball_vel", Vector2.ZERO).length(), OPEN_CAP, "overload should penetrate ordinary fire/meditation caps")

	var power_scene := {
		"ball_vel": Vector2(0.0, OPEN_CAP),
		"ball_impact_boost": 1.0,
		OVERLOAD_SPEED_CAP_KEY: OPEN_CAP,
	}
	var power_cap: float = BallUpdateController.new()._get_power_smash_effective_speed_cap(
		power_scene,
		{
			"power_smash_max_ball_speed": 35.0,
			"fire_weather_speed_cap_active": true,
			"fire_weather_max_ball_speed": 35.0,
		},
		{}
	)
	motion.apply_power_smash_speed_limit(power_scene, power_cap)
	_expect_close(_get_vector2(power_scene, "ball_vel", Vector2.ZERO).length(), OPEN_CAP, "overload should penetrate the Power Smash cap path")


func _verify_round_cleanup_resets_overload_arm() -> void:
	var runtime := FakeFusionRuntime.new()
	BallRoundActorCleanup.new().reset_actor_round_state({"runtime_perk_state": runtime})
	_expect(runtime.round_reset_count == 1, "generic round reset should clear the armed overload hold")
	_expect_close(runtime.overload_multiplier, 1.0, "generic round reset should prevent overload from crossing rounds")


func _verify_boss_or_empty_paddle_result_does_not_consume_overload() -> void:
	var boss_runtime := FakeFusionRuntime.new()
	BallMotionEventProcessor.new().step_motion(
		_base_scene(),
		1.0,
		_base_context(),
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(false)),
			"paddle_bounce_controller": FakePaddleBounceController.new({"ball_vel": Vector2(3.0, 4.0)}),
			"runtime_perk_state": boss_runtime,
		},
		{}
	)
	_expect(boss_runtime.overload_consume_count == 0, "boss paddle bounce must not consume player overload")

	var empty_runtime := FakeFusionRuntime.new()
	BallMotionEventProcessor.new().step_motion(
		_base_scene(),
		1.0,
		_base_context(),
		{
			"motion_stepper": FakeMotionStepper.new(_paddle_event(true)),
			"paddle_bounce_controller": FakePaddleBounceController.new({}),
			"runtime_perk_state": empty_runtime,
		},
		{}
	)
	_expect(empty_runtime.overload_consume_count == 0, "rejected/empty player paddle result must preserve overload")


const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")


class FakeDashState:
	extends RefCounted

	var allow_start := true

	func start(
		_direction: float,
		_is_half: bool,
		_runtime_perk_state: Object,
		_registry: Object,
		_consume_token: bool = true,
		_sensor: bool = false
	) -> bool:
		return allow_start


# 코덱스 P2: TTL은 helper 정의만으로는 죽어 있다 — 실 BallUpdateController
# .update()가 매 물리 프레임 틱해야, 보스 반사/득점 없는 랠리에서도 열린
# 캡이 90프레임을 넘겨 살 수 없다(스킵 프레임 포함 실경로 봉인).
func _verify_real_ball_update_ticks_overload_ttl_closed() -> void:
	var controller := BallUpdateController.new()
	var context := {
		"ball_active": true,
		"skip_ball_motion_step": true,
		"ball_pos": Vector2(380.0, 300.0),
		"ball_vel": Vector2.ZERO,
		"perk_fusion_overload_speed_cap": 35.0,
		"perk_fusion_overload_speed_cap_frames": 2.0,
	}
	var first: Dictionary = controller.update(1.0 / 60.0, context, {}, {})
	var first_snapshot: Dictionary = first.get("snapshot", {}) as Dictionary
	_expect(
		is_equal_approx(float(first_snapshot.get("perk_fusion_overload_speed_cap_frames", -1.0)), 1.0),
		"the real ball update should tick the overload TTL by exactly one frame"
	)
	_expect(float(first_snapshot.get("perk_fusion_overload_speed_cap", 0.0)) > 0.0, "a still-live TTL must keep the transient cap open")
	context.merge(first_snapshot, true)
	var second: Dictionary = controller.update(1.0 / 60.0, context, {}, {})
	var second_snapshot: Dictionary = second.get("snapshot", {}) as Dictionary
	_expect(
		is_equal_approx(float(second_snapshot.get("perk_fusion_overload_speed_cap", -1.0)), 0.0)
			and is_equal_approx(float(second_snapshot.get("perk_fusion_overload_speed_cap_frames", -1.0)), 0.0),
		"the real ball update must close the cap when the TTL expires"
	)


# 대시 훅(과부하 무장): 확정된 대시 시작만 융합 대시 훅을 정확 1회
# 통지하고, 시작이 거부된 대시는 통지하지 않는다.
func _verify_confirmed_dash_start_notifies_fusion_dash_hook_once() -> void:
	var runtime := FakeFusionRuntime.new()
	var dash_state := FakeDashState.new()
	var controller := SmasherPlayerDashController.new()
	var started: Dictionary = controller.try_start_sensor_dash(
		1.0,
		Vector2(300.0, 700.0),
		{},
		{"dash_state": dash_state, "runtime_perk_state": runtime}
	)
	_expect(bool(started.get("started", false)), "confirmed sensor dash fixture should start")
	_expect(runtime.dash_notify_count == 1, "a confirmed dash start should notify the fusion dash hook exactly once")
	dash_state.allow_start = false
	controller.try_start_sensor_dash(
		1.0,
		Vector2(300.0, 700.0),
		{},
		{"dash_state": dash_state, "runtime_perk_state": runtime}
	)
	_expect(runtime.dash_notify_count == 1, "a rejected dash start must not notify the fusion dash hook")


func _verify_paddle_owned_power_and_drive_edges_notify_skill_use_once() -> void:
	for activation_key in ["power_activated", "drive_activated"]:
		var runtime := FakeFusionRuntime.new()
		BallMotionEventProcessor.new().step_motion(
			_base_scene(),
			1.0,
			_base_context(),
			{
				"motion_stepper": FakeMotionStepper.new(_paddle_event(true)),
				"paddle_bounce_controller": FakePaddleBounceController.new({
					"ball_vel": Vector2(3.0, -4.0),
					activation_key: true,
				}),
				"runtime_perk_state": runtime,
			},
			{}
		)
		_expect(runtime.skill_use_count == 1, "%s should notify the fusion skill-use hook exactly once" % activation_key)
	var controller_source := FileAccess.get_file_as_string("res://scripts/ball/paddle_bounce_controller.gd")
	_expect(controller_source.find("result[\"power_activated\"]") >= 0, "paddle controller should preserve the Power Smashing activation edge")
	_expect(controller_source.find("result[\"drive_activated\"]") >= 0, "paddle controller should preserve the Drive activation edge")


func _verify_wall_bounce_routes_fusion_gold_through_runtime_award_flow() -> void:
	var runtime := FakeFusionRuntime.new()
	var scene := _base_scene()
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		_base_context(),
		{
			"motion_stepper": FakeMotionStepper.new({
				"event": "wall",
				"side": "left",
				"ball_pos": Vector2(14.0, 300.0),
				"impact_pos": Vector2(14.0, 300.0),
			}),
			"wall_bounce_controller": FakeWallBounceController.new(),
			"runtime_perk_state": runtime,
		},
		{}
	)
	_expect(runtime.wall_query_count == 1, "each resolved wall bounce should query golden trajectory exactly once")
	_expect(runtime.gold_awards == [2], "positive golden trajectory award should use the canonical capped runtime transaction")

	runtime.wall_award = 0
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		_base_context(),
		{
			"motion_stepper": FakeMotionStepper.new({
				"event": "wall",
				"side": "right",
				"ball_pos": Vector2(746.0, 300.0),
				"impact_pos": Vector2(746.0, 300.0),
			}),
			"wall_bounce_controller": FakeWallBounceController.new(),
			"runtime_perk_state": runtime,
		},
		{}
	)
	_expect(runtime.wall_query_count == 2, "zero-award wall bounce should still advance the byproduct runtime cap/query state")
	_expect(runtime.gold_awards == [2], "zero golden trajectory award must not store gold")


func _paddle_event(is_player: bool) -> Dictionary:
	return {
		"event": "player_paddle" if is_player else "boss_paddle",
		"is_player": is_player,
		"paddle_x": 300.0,
		"paddle_w": 155.0,
		"ball_pos": Vector2(380.0, 650.0 if is_player else 100.0),
	}


func _base_scene() -> Dictionary:
	return {
		"ball_pos": Vector2(380.0, 350.0),
		"ball_vel": Vector2(-3.0, -4.0),
		"ball_impact_boost": 1.0,
	}


func _base_context() -> Dictionary:
	return {
		"width": 760.0,
		"height": 750.0,
		"ball_size": 28.6,
		"paddle_width": 155.0,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(
		is_equal_approx(actual, expected),
		"%s (actual=%s, expected=%s)" % [message, actual, expected]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
