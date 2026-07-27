extends SceneTree

const LingpetCompanionDefenseState := preload(
	"res://scripts/lingpet/lingpet_companion_defense_state.gd"
)
const LingpetCompanionMotionState := preload(
	"res://scripts/lingpet/lingpet_companion_motion_state.gd"
)

class BattleOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(500.0, 400.0)
	var ball_vel := Vector2(0.0, 4.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var player_pos := Vector2(80.0, 650.0)
	var player_paddle_width := 155.0


class MotionHost:
	extends RefCounted

	var pos := Vector2(400.0, 650.0)
	var patrol_lane_y := 650.0
	var patrol_min_x := 42.0
	var patrol_max_x := 718.0
	var patrol_dir := -1.0
	var patrol_pause := 0.75
	var patrol_speed := 120.0
	var patrol_seed := 5


var _failures: Array[String] = []


func _init() -> void:
	_verify_local_predictive_guard_state()
	_verify_motion_state_compatibility_surface()
	_verify_motion_state_delegates_ownership()

	if _failures.is_empty():
		print("lingpet_companion_defense_state_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_local_predictive_guard_state() -> void:
	var state: Object = LingpetCompanionDefenseState.new()
	var owner := BattleOwner.new()
	var motion := MotionHost.new()
	var handled := bool(state.try_update(0.05, owner, motion, 1.0, 120.0, 80.0))

	_expect(handled, "a nearby player-unblockable descending ball should start the guard")
	_expect(state.defense_intercept_active, "successful guard roll should arm the intercept")
	_expect(absf(float(state.defense_intercept_target_x) - 500.0) <= 0.01, "guard should anchor to predicted landing X")
	_expect(motion.pos.x > 400.0, "armed guard should move toward the local landing point")
	_expect(motion.patrol_dir > 0.0, "guard motion should face the actual travel direction")
	_expect(motion.patrol_pause == 0.0, "arming defense should release any patrol pause")
	_expect(state.defense_intercept_step_speed > 0.0, "moving guard should expose real per-frame step speed")

	state.advance_guard_aura(0.15)
	_expect(is_equal_approx(float(state.defense_guard_aura_ratio), 1.0), "guard aura should reach full strength after its authored ramp")
	state.clear_intercept()
	_expect(not state.defense_intercept_active, "clear should release the intercept")
	_expect(is_zero_approx(float(state.defense_intercept_step_speed)), "clear should zero the real movement-speed channel")
	_expect(is_zero_approx(float(state.defense_guard_aura_ratio)), "clear should remove the guard aura")

	state.reset()
	var player_blockable_owner := BattleOwner.new()
	player_blockable_owner.ball_pos.x = 150.0
	var player_blockable_motion := MotionHost.new()
	player_blockable_motion.pos.x = 150.0
	var seed_before_blockable := player_blockable_motion.patrol_seed
	_expect(
		not bool(state.try_update(0.05, player_blockable_owner, player_blockable_motion, 1.0, 120.0, 80.0)),
		"a ball the player can block should stay outside companion-defense scope"
	)
	_expect(not state.defense_intercept_active, "player-blockable ball should not arm defense")
	_expect(
		player_blockable_motion.patrol_seed == seed_before_blockable,
		"player-blockable ball should not consume the defense roll"
	)

	state.reset()
	var far_owner := BattleOwner.new()
	far_owner.ball_pos.x = 700.0
	var far_motion := MotionHost.new()
	far_motion.pos.x = 300.0
	_expect(
		not bool(state.try_update(0.05, far_owner, far_motion, 0.30, 120.0, 80.0)),
		"a predicted landing outside the defense-rate-scaled local zone should not arm"
	)
	_expect(not state.defense_intercept_active, "far ball should not turn the companion into a field-wide goalkeeper")


func _verify_motion_state_compatibility_surface() -> void:
	var motion: Object = LingpetCompanionMotionState.new()
	motion.defense_decision_timer = 0.75
	motion.defense_intercept_active = true
	motion.defense_intercept_target_x = 321.0
	motion.defense_intercept_step_speed = 88.0
	motion.defense_guard_aura_ratio = 0.5

	_expect(is_equal_approx(float(motion.defense_decision_timer), 0.75), "legacy decision-timer property should remain writable")
	_expect(bool(motion.defense_intercept_active), "legacy intercept-active property should remain writable")
	_expect(is_equal_approx(float(motion.defense_intercept_target_x), 321.0), "legacy target property should remain writable")
	_expect(is_equal_approx(float(motion.defense_intercept_step_speed), 88.0), "legacy step-speed property should remain writable")
	_expect(is_equal_approx(float(motion.defense_guard_aura_ratio), 0.5), "legacy aura property should remain writable")
	motion.clear_defense_intercept()
	_expect(not bool(motion.defense_intercept_active), "legacy clear method should delegate to the focused state")


func _verify_motion_state_delegates_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_motion_state.gd")
	var defense_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_defense_state.gd")
	_expect(
		source.find("LingpetCompanionDefenseState") >= 0,
		"companion motion should compose the focused defense state"
	)
	_expect(
		source.find("var defense_decision_timer :=") < 0,
		"companion motion should not retain raw defense timer storage"
	)
	_expect(
		source.find("func _try_update_defense_intercept") < 0,
		"companion motion should not retain defense prediction/runtime logic"
	)
	_expect(
		source.find("func _advance_defense_intercept") < 0,
		"companion motion should not retain defense chase integration"
	)
	_expect(
		source.find("static func get_defense_guard_speed") >= 0,
		"companion motion should keep the public static guard-speed facade"
	)
	_expect(
		defense_source.find("return {") < 0
			and defense_source.find("Callable(") < 0
			and defense_source.find("Array[") < 0,
		"the patrol defense hot path should not allocate result containers or lambdas"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
