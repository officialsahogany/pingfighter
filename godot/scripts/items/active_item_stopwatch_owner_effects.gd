extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemStopwatchRecovery := preload("res://scripts/items/active_item_stopwatch_recovery.gd")

var _recovery: Object = ActiveItemStopwatchRecovery.new()


func apply_update_actions(owner: Object, state: Dictionary, fallback_original_ball_vel: Vector2) -> void:
	if owner == null:
		return
	if bool(state.get("freeze_ball", false)):
		owner.set("ball_vel", Vector2.ZERO)
	if bool(state.get("apply_recovery_velocity", false)):
		_apply_recovery_velocity_for_timer(
			owner,
			_get_vector2(state, "recovery_original_ball_vel", fallback_original_ball_vel),
			float(state.get("recovery_timer_for_velocity", 0.0))
		)
	if bool(state.get("reset_collision_cooldowns", false)):
		reset_collision_cooldowns(owner)
	if bool(state.get("apply_final_recovery_velocity", false)):
		_apply_recovery_velocity_for_timer(
			owner,
			_get_vector2(state, "recovery_original_ball_vel", fallback_original_ball_vel),
			0.0
		)


func apply_recovery_velocity(owner: Object, original_ball_vel: Vector2, speed_ratio: float) -> void:
	if owner == null:
		return
	var current_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	var result: Dictionary = _recovery.build_recovery_velocity_result(original_ball_vel, current_vel, speed_ratio)
	if not bool(result.get("has_velocity", false)):
		return
	owner.set("ball_vel", _get_vector2(result, "ball_vel", Vector2.ZERO))


func reset_collision_cooldowns(owner: Object) -> void:
	if owner == null:
		return
	owner.set("player_collision_cooldown", 0.0)
	owner.set("boss_collision_cooldown", 0.0)


func get_recovery_speed_ratio(recovery_timer_frames: float) -> float:
	return _recovery.get_recovery_speed_ratio(recovery_timer_frames)


func force_recovery_velocity_upward(active: bool, original_ball_vel: Vector2, min_upward_speed: float = 7.65) -> Vector2:
	if not active:
		return original_ball_vel
	var forced_vel: Vector2 = original_ball_vel
	if abs(forced_vel.y) <= 0.01:
		forced_vel.y = -abs(min_upward_speed)
	else:
		forced_vel.y = -abs(forced_vel.y)
	return forced_vel


func _apply_recovery_velocity_for_timer(owner: Object, original_ball_vel: Vector2, recovery_timer_frames: float) -> void:
	apply_recovery_velocity(owner, original_ball_vel, get_recovery_speed_ratio(recovery_timer_frames))


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
