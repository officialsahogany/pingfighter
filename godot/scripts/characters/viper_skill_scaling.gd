extends RefCounted

const KICK_PREP_SPEED_START := 9.0
const KICK_PREP_SPEED_FULL := 24.0
const KICK_PREP_SPEED_MIN_MULT := 0.78
const KICK_PREP_DANGER_START_FRAMES := 78.0
const KICK_PREP_DANGER_FULL_FRAMES := 24.0
const KICK_PREP_DANGER_MIN_MULT := 0.55
const KICK_PREP_DOWNWARD_SPEED_START := 7.0
const KICK_PREP_DOWNWARD_SPEED_FULL := 20.0


func get_four_poisons_prep_reduction_pct(
	four_poisons_level: int,
	values: Array,
	cap: int,
	per_extra_level: int
) -> int:
	return get_four_poisons_scaled_pct(four_poisons_level, values, cap, per_extra_level)


func get_four_poisons_scaled_pct(four_poisons_level: int, values: Array, cap: int, per_extra_level: int) -> int:
	if four_poisons_level <= 0:
		return 0
	if four_poisons_level < values.size():
		return int(values[four_poisons_level])
	var last_index: int = values.size() - 1
	var base_pct: int = int(values[last_index])
	var extra: int = four_poisons_level - last_index
	return min(cap, base_pct + extra * per_extra_level)


func get_four_poisons_additive_cooldown_seconds(
	skill_name: String,
	skill_config: Object,
	fallback_base_seconds: float,
	four_poisons_level: int,
	cooldown_values: Array,
	cooldown_cap: int,
	cooldown_per_extra_level: int,
	nerve_strike_name: String,
	dive_strike_name: String,
	chaos_spear_name: String,
	dual_glitch_name: String
) -> float:
	var configured_seconds: float = fallback_base_seconds
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		configured_seconds = float(skill_config.get_cooldown_seconds(skill_name))
	if configured_seconds <= 0.0:
		configured_seconds = fallback_base_seconds
	var base_seconds: float = fallback_base_seconds
	match skill_name:
		nerve_strike_name:
			base_seconds = 40.0
		dive_strike_name:
			base_seconds = 70.0
		chaos_spear_name:
			base_seconds = 30.0
		dual_glitch_name:
			base_seconds = 40.0
	var configured_reduction: float = clamp(1.0 - configured_seconds / max(0.001, base_seconds), 0.0, 0.95)
	var cooldown_reduction_pct: int = get_four_poisons_scaled_pct(
		four_poisons_level,
		cooldown_values,
		cooldown_cap,
		cooldown_per_extra_level
	)
	var four_poisons_reduction: float = float(cooldown_reduction_pct) / 100.0
	var total_reduction: float = clamp(configured_reduction + four_poisons_reduction, 0.0, 0.95)
	return max(0.0, base_seconds * (1.0 - total_reduction))


func get_dual_glitch_clone_hp(four_poisons_level: int, values: Array, cap: int) -> int:
	var safe_four_poisons_level: int = max(0, four_poisons_level)
	var clamped_four_poisons_level: int = min(values.size() - 1, safe_four_poisons_level)
	var clone_hp: int = int(values[clamped_four_poisons_level])
	if safe_four_poisons_level > 5:
		clone_hp += min(2, max(0, int(floor(float(safe_four_poisons_level - 4) / 2.0))))
	return min(cap, clone_hp)


func get_blade_skill_cost(base_cost: float, blade_amp_level: int, skill_name: String, blade_rush_name: String, dark_blade_name: String) -> float:
	if skill_name == blade_rush_name or skill_name == dark_blade_name:
		if base_cost <= 0.0:
			base_cost = 150.0 if skill_name == dark_blade_name else 200.0
		return max(100.0, base_cost - float(min(max(0, blade_amp_level) * 10, 100)))
	return base_cost


func get_blade_amp_followup_chance_pct(blade_amp_level: int) -> int:
	var safe_level: int = max(0, blade_amp_level)
	if safe_level < 3:
		return 0
	return min(100, (safe_level - 2) * 10)


func get_marshal_duration_frames(base_frames: float, kick_enhance_level: int, marshal_is_double: bool, double_fast: bool, double_fast_mult: float) -> float:
	var speed_base: float = base_frames / double_fast_mult if (double_fast and marshal_is_double) else base_frames
	return max(1.0, speed_base * get_marshal_prep_duration_mult(kick_enhance_level))


func get_core_flip_duration_frames(base_frames: float, kick_enhance_level: int) -> float:
	return max(1.0, base_frames * get_marshal_prep_duration_mult(kick_enhance_level))


func get_core_flip_wall_prep_duration_frames(base_frames: float, kick_enhance_level: int, config: Dictionary) -> float:
	return max(1.0, get_core_flip_duration_frames(base_frames, kick_enhance_level) * get_kick_prep_ball_dynamic_multiplier(config))


func get_kick_prep_ball_dynamic_multiplier(config: Dictionary) -> float:
	var ball_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var impact_boost: float = max(1.0, float(config.get("ball_impact_boost", 1.0)))
	var effective_vel: Vector2 = ball_vel * impact_boost
	var speed: float = effective_vel.length()
	if speed <= 0.001:
		return 1.0
	var speed_ratio: float = clamp((speed - KICK_PREP_SPEED_START) / max(0.001, KICK_PREP_SPEED_FULL - KICK_PREP_SPEED_START), 0.0, 1.0)
	var speed_mult: float = lerp(1.0, KICK_PREP_SPEED_MIN_MULT, speed_ratio)
	var danger_mult: float = 1.0
	if effective_vel.y > 0.001:
		var ball_pos: Vector2 = _get_vector2(config.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
		var floor_y: float = float(config.get("player_floor_y", float(config.get("height", 750.0)) - float(config.get("paddle_height", 50.0))))
		var frames_to_floor: float = max(0.0, floor_y - ball_pos.y) / max(0.001, effective_vel.y)
		var time_ratio: float = clamp((KICK_PREP_DANGER_START_FRAMES - frames_to_floor) / max(0.001, KICK_PREP_DANGER_START_FRAMES - KICK_PREP_DANGER_FULL_FRAMES), 0.0, 1.0)
		var downward_speed_ratio: float = clamp((effective_vel.y - KICK_PREP_DOWNWARD_SPEED_START) / max(0.001, KICK_PREP_DOWNWARD_SPEED_FULL - KICK_PREP_DOWNWARD_SPEED_START), 0.0, 1.0)
		var danger_ratio: float = max(time_ratio, downward_speed_ratio * 0.75)
		danger_mult = lerp(1.0, KICK_PREP_DANGER_MIN_MULT, danger_ratio)
	return clamp(min(speed_mult, danger_mult), KICK_PREP_DANGER_MIN_MULT, 1.0)


func get_marshal_hit_speed(
	current_speed: float,
	kick_enhance_level: int,
	marshal_is_double: bool,
	speed_mult: float,
	min_speed: float,
	double_speed_mult: float,
	double_min_speed: float
) -> float:
	var speed_bonus: float = 1.0 + float(kick_enhance_level) * 0.04
	var selected_speed_mult: float = double_speed_mult if marshal_is_double else speed_mult
	var selected_min_speed: float = double_min_speed if marshal_is_double else min_speed
	return max(current_speed * selected_speed_mult * speed_bonus, selected_min_speed)


func get_core_flip_hit_speed(
	current_speed: float,
	kick_enhance_level: int,
	speed_mult: float,
	min_speed: float
) -> float:
	var speed_bonus: float = 1.0 + float(kick_enhance_level) * 0.04
	return max(current_speed * speed_mult * speed_bonus, min_speed)


func get_marshal_prep_duration_mult(kick_enhance_level: int) -> float:
	var prep_cut_pct: float = min(float(kick_enhance_level) * 7.0, 90.0)
	return max(0.1, 1.0 - prep_cut_pct / 100.0)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
