extends RefCounted

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func build_base_result(source: String, damage_units: int) -> Dictionary:
	return {
		"source": source,
		"damage_units": damage_units,
	}


static func get_result_frames(profile: Dictionary, result: Dictionary, frame_key: String) -> float:
	var frames: float = float(profile.get(frame_key, 0.0))
	if result.has(frame_key):
		frames = float(result.get(frame_key, frames))
	return frames


static func get_stun_frames(profile: Dictionary, result: Dictionary) -> float:
	return get_result_frames(profile, result, "stun_frames")


static func get_slow_frames(profile: Dictionary, result: Dictionary) -> float:
	return get_result_frames(profile, result, "slow_frames")


static func get_stun_source(result: Dictionary, default_source: String) -> String:
	return str(result.get("stun_source", default_source))


static func get_slow_source(result: Dictionary, default_source: String) -> String:
	return str(result.get("slow_source", "%s_slow" % default_source))


static func get_slow_multiplier(profile: Dictionary, result: Dictionary) -> float:
	return clamp(float(result.get("slow_multiplier", profile.get("slow_multiplier", 1.0))), 0.0, 1.0)


static func apply_stun_result_fields(
	result: Dictionary,
	stun_frames: float,
	knockback_vel: float,
	knockback_profile: Dictionary
) -> void:
	result["stun_frames"] = stun_frames
	result["knockback_vel"] = knockback_vel
	if knockback_profile.has("knockback_frames"):
		result["knockback_frames"] = float(knockback_profile.get("knockback_frames", 0.0))
	if knockback_profile.has("knockback_decay_per_frame"):
		result["knockback_decay_per_frame"] = float(knockback_profile.get("knockback_decay_per_frame", 1.0))


static func apply_slow_result_fields(result: Dictionary, slow_frames: float, slow_multiplier: float) -> void:
	result["slow_frames"] = slow_frames
	result["slow_multiplier"] = slow_multiplier


static func build_stun_status_data(knockback_vel: float, source: String, result: Dictionary) -> Dictionary:
	var status_data := {
		"knockback_vel": knockback_vel,
		"knockback_active": abs(knockback_vel) > 0.001,
		"source": source,
	}
	if result.has("knockback_frames"):
		status_data["knockback_frames"] = float(result.get("knockback_frames", 0.0))
	if result.has("knockback_decay_per_frame"):
		status_data["knockback_decay_per_frame"] = float(result.get("knockback_decay_per_frame", 1.0))
	return status_data


static func build_slow_status_data(slow_multiplier: float, source: String) -> Dictionary:
	return {
		"multiplier": slow_multiplier,
		"source": source,
	}


static func apply_runtime_status_results(
	result: Dictionary,
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	source: String,
	field_width: float
) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var boss_target: Vector2 = CommandoFirearmOriginGeometry.get_boss_target_pos(context, field_width)
	var stun_frames: float = get_stun_frames(profile, result)
	if stun_frames > 0.0:
		_apply_runtime_stun_result(result, profile, status_effect_state, pos, velocity, boss_target, stun_frames, source)
	elif bool(result.get("knockback_without_stun", false)):
		_apply_runtime_knockback_without_stun(result, profile, deps, pos, velocity, boss_target)
	_apply_runtime_slow_result(result, profile, status_effect_state, source)


static func _apply_runtime_stun_result(
	result: Dictionary,
	profile: Dictionary,
	status_effect_state: Object,
	pos: Vector2,
	velocity: Vector2,
	boss_target: Vector2,
	stun_frames: float,
	source: String
) -> void:
	var knockback_profile: Dictionary = CommandoFirearmHitGeometry.get_result_hit_profile(profile, result)
	var knockback_vel: float = CommandoFirearmHitGeometry.get_hit_knockback_velocity(
		knockback_profile,
		pos,
		velocity,
		boss_target
	)
	var stun_source: String = get_stun_source(result, source)
	apply_stun_result_fields(result, stun_frames, knockback_vel, knockback_profile)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status(
			"boss",
			"stun",
			stun_frames,
			build_stun_status_data(knockback_vel, stun_source, result),
			stun_source
		)
		result["stun_applied"] = true


static func _apply_runtime_knockback_without_stun(
	result: Dictionary,
	profile: Dictionary,
	deps: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	boss_target: Vector2
) -> void:
	var knockback_profile: Dictionary = CommandoFirearmHitGeometry.get_result_hit_profile(profile, result)
	var knockback_vel: float = CommandoFirearmHitGeometry.get_hit_knockback_velocity(
		knockback_profile,
		pos,
		velocity,
		boss_target
	)
	result["knockback_vel"] = knockback_vel
	var ai_state: Object = deps.get("ai_state", null)
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(
			knockback_vel,
			float(result.get("knockback_frames", 18.0)),
			float(result.get("knockback_decay_per_frame", 0.85)),
			true
		)
		result["knockback_applied"] = true


static func _apply_runtime_slow_result(
	result: Dictionary,
	profile: Dictionary,
	status_effect_state: Object,
	source: String
) -> void:
	var slow_frames: float = get_slow_frames(profile, result)
	if slow_frames <= 0.0:
		return
	var slow_source: String = get_slow_source(result, source)
	var slow_multiplier: float = get_slow_multiplier(profile, result)
	apply_slow_result_fields(result, slow_frames, slow_multiplier)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status(
			"boss",
			"slow",
			slow_frames,
			build_slow_status_data(slow_multiplier, slow_source),
			slow_source
		)
		result["slow_applied"] = true
