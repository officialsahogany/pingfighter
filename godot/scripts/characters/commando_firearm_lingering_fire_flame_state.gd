extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const FLAME_COUNT := 15
const DEFAULT_WIDTH := 150.0
const DEFAULT_HEIGHT := 60.0
const PHASE_STEP := 0.08
const DRIFT_WAVE_SPEED := 0.22
const DRIFT_RISE_SPEED := 0.16
const OFFSET_BOUND_RATIO := 0.48
const DEFAULT_DRIFT_SIZE := 10.0
const SIZE_DECAY_RATE := 0.985
const MIN_DRIFT_SIZE := 3.0
const RING_BASE := 0.26
const RING_RANGE := 0.68
const RING_PATTERN_STEP := 7
const RING_PATTERN_MODULO := 11
const RING_FACTOR_DIVISOR := 10.0
const SIZE_BASE := 8.0
const SIZE_PATTERN_STEP := 5
const SIZE_PATTERN_MODULO := 13
const LIFETIME_BASE := 22.0
const LIFETIME_PATTERN_STEP := 3
const LIFETIME_PATTERN_MODULO := 18
const RESET_SIZE_BASE := 9.0
const RESET_SIZE_PATTERN_STEP := 7
const RESET_SIZE_PATTERN_MODULO := 14
const RESET_LIFETIME_BASE := 24.0
const RESET_LIFETIME_PATTERN_STEP := 5
const RESET_LIFETIME_PATTERN_MODULO := 16
const PHASE_SPACING := 0.67
const MAX_LIFETIME := 40.0
const RESET_RADIUS_X_RATIO := 0.34
const RESET_RADIUS_Y_RATIO := 0.38
const SPAWN_RADIUS_RATIO := 0.5


static func build_flames(effect: Dictionary) -> Array:
	var flames: Array = []
	var effect_size: Vector2 = get_effect_size(effect)
	for i in range(get_flame_count()):
		flames.append(build_flame(i, effect_size.x, effect_size.y))
	return flames


static func get_flame_count() -> int:
	return FLAME_COUNT


static func get_effect_size(effect: Dictionary) -> Vector2:
	return Vector2(
		get_effect_width(effect),
		get_effect_height(effect)
	)


static func get_effect_width(effect: Dictionary) -> float:
	return get_effect_dimension(effect, "width", DEFAULT_WIDTH)


static func get_effect_height(effect: Dictionary) -> float:
	return get_effect_dimension(effect, "height", DEFAULT_HEIGHT)


static func get_effect_dimension(effect: Dictionary, dimension_key: String, default_value: float) -> float:
	return max(1.0, float(effect.get(dimension_key, default_value)))


static func build_flame(flame_index: int, width: float, height: float) -> Dictionary:
	var angle: float = get_flame_angle(flame_index)
	return {
		"offset": get_flame_offset(flame_index, width, height, angle),
		"size": get_flame_size(flame_index),
		"lifetime": get_flame_lifetime(flame_index),
		"max_lifetime": get_flame_max_lifetime(),
		"phase": get_flame_phase(flame_index),
	}


static func get_flame_angle(flame_index: int) -> float:
	return get_flame_cycle_angle(flame_index)


static func get_flame_cycle_angle(angle_index: int) -> float:
	return TAU * float(angle_index) / float(get_flame_count())


static func get_flame_ring(flame_index: int) -> float:
	return RING_BASE + RING_RANGE * get_flame_ring_factor(flame_index)


static func get_flame_ring_factor(flame_index: int) -> float:
	return float(get_flame_ring_pattern_value(flame_index)) / RING_FACTOR_DIVISOR


static func get_flame_ring_pattern_value(flame_index: int) -> int:
	return get_flame_pattern_value(flame_index, RING_PATTERN_STEP, RING_PATTERN_MODULO)


static func get_flame_pattern_value(flame_index: int, pattern_step: int, pattern_modulo: int) -> int:
	return (flame_index * pattern_step) % pattern_modulo


static func get_flame_offset(flame_index: int, width: float, height: float, angle: float) -> Vector2:
	var ring: float = get_flame_ring(flame_index)
	var radius: Vector2 = get_flame_spawn_radius(width, height, ring)
	return get_flame_offset_from_radius(angle, radius)


static func get_flame_spawn_radius(width: float, height: float, ring: float) -> Vector2:
	return Vector2(
		get_flame_spawn_radius_x(width, ring),
		get_flame_spawn_radius_y(height, ring)
	)


static func get_flame_spawn_radius_x(width: float, ring: float) -> float:
	return width * SPAWN_RADIUS_RATIO * ring


static func get_flame_spawn_radius_y(height: float, ring: float) -> float:
	return height * SPAWN_RADIUS_RATIO * ring


static func get_flame_offset_from_radius(angle: float, radius: Vector2) -> Vector2:
	return Vector2(cos(angle) * radius.x, sin(angle) * radius.y)


static func get_flame_size(flame_index: int) -> float:
	return SIZE_BASE + float(get_flame_size_offset(flame_index))


static func get_flame_size_offset(flame_index: int) -> int:
	return get_flame_size_pattern_value(flame_index)


static func get_flame_size_pattern_value(flame_index: int) -> int:
	return get_flame_pattern_value(flame_index, SIZE_PATTERN_STEP, SIZE_PATTERN_MODULO)


static func get_flame_lifetime(flame_index: int) -> float:
	return LIFETIME_BASE + float(get_flame_lifetime_offset(flame_index))


static func get_flame_lifetime_offset(flame_index: int) -> int:
	return get_flame_lifetime_pattern_value(flame_index)


static func get_flame_lifetime_pattern_value(flame_index: int) -> int:
	return get_flame_pattern_value(flame_index, LIFETIME_PATTERN_STEP, LIFETIME_PATTERN_MODULO)


static func get_flame_phase(flame_index: int) -> float:
	return float(flame_index) * get_flame_phase_spacing()


static func get_flame_phase_spacing() -> float:
	return PHASE_SPACING


static func get_flame_max_lifetime() -> float:
	return MAX_LIFETIME


static func get_flames_for_frame(effect: Dictionary, fps_scale: float) -> Array:
	var flames: Array = get_flames(effect)
	if should_seed_flames(flames):
		return build_flames(effect)
	return advance_flames(flames, effect, fps_scale)


static func get_flames(effect: Dictionary) -> Array:
	return CommandoFirearmValueUtils.get_array(effect.get("flames", []))


static func should_seed_flames(flames: Array) -> bool:
	return flames.is_empty()


static func advance_flames(flames: Array, effect: Dictionary, fps_scale: float) -> Array:
	var next_flames: Array = []
	var effect_size: Vector2 = get_effect_size(effect)
	for i in range(flames.size()):
		var flame: Dictionary = get_flame_at_index(flames, i)
		next_flames.append(advance_flame(flame, i, effect, fps_scale, effect_size.x, effect_size.y))
	return next_flames


static func get_flame_at_index(flames: Array, flame_index: int) -> Dictionary:
	if flame_index < 0 or flame_index >= flames.size():
		return {}
	return CommandoFirearmValueUtils.get_dict(flames[flame_index])


static func advance_flame(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	fps_scale: float,
	width: float,
	height: float
) -> Dictionary:
	var lifetime: float = get_flame_next_lifetime(flame, fps_scale)
	var phase: float = get_flame_next_phase(flame, fps_scale)
	lifetime = apply_flame_motion(flame, flame_index, effect, lifetime, phase, fps_scale, width, height)
	return apply_flame_frame_values(flame, lifetime, phase)


static func apply_flame_frame_values(flame: Dictionary, lifetime: float, phase: float) -> Dictionary:
	flame["lifetime"] = lifetime
	flame["phase"] = phase
	return flame


static func apply_flame_motion(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	lifetime: float,
	phase: float,
	fps_scale: float,
	width: float,
	height: float
) -> float:
	if should_reset_flame(lifetime):
		return apply_flame_reset_motion(flame, flame_index, effect, width, height)
	return apply_flame_drift_motion(flame, phase, fps_scale, width, height, lifetime)


static func apply_flame_reset_motion(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	width: float,
	height: float
) -> float:
	return reset_flame(flame, flame_index, effect, width, height)


static func apply_flame_drift_motion(
	flame: Dictionary,
	phase: float,
	fps_scale: float,
	width: float,
	height: float,
	lifetime: float
) -> float:
	drift_flame(flame, phase, fps_scale, width, height)
	return lifetime


static func should_reset_flame(lifetime: float) -> bool:
	return lifetime <= 0.0


static func get_flame_next_lifetime(flame: Dictionary, fps_scale: float) -> float:
	return get_flame_current_lifetime(flame) - fps_scale


static func get_flame_next_phase(flame: Dictionary, fps_scale: float) -> float:
	return get_flame_current_phase(flame) + get_flame_phase_step(fps_scale)


static func get_flame_current_lifetime(flame: Dictionary) -> float:
	return float(flame.get("lifetime", 0.0))


static func get_flame_current_phase(flame: Dictionary) -> float:
	return float(flame.get("phase", 0.0))


static func get_flame_phase_step(fps_scale: float) -> float:
	return PHASE_STEP * fps_scale


static func reset_flame(flame: Dictionary, flame_index: int, effect: Dictionary, width: float, height: float) -> float:
	apply_flame_reset_values(flame, flame_index, effect, width, height)
	return get_flame_reset_lifetime(flame_index)


static func apply_flame_reset_values(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	width: float,
	height: float
) -> void:
	flame["offset"] = get_flame_reset_offset(flame_index, effect, width, height)
	flame["size"] = get_flame_reset_size(flame_index)


static func get_flame_reset_angle(flame_index: int, effect: Dictionary) -> float:
	return get_flame_cycle_angle(get_flame_reset_angle_index(flame_index, effect))


static func get_flame_reset_angle_index(flame_index: int, effect: Dictionary) -> int:
	return flame_index + get_effect_id(effect)


static func get_effect_id(effect: Dictionary) -> int:
	return int(effect.get("id", 0))


static func get_flame_reset_offset(flame_index: int, effect: Dictionary, width: float, height: float) -> Vector2:
	var angle: float = get_flame_reset_angle(flame_index, effect)
	var radius: Vector2 = get_flame_reset_radius(width, height)
	return get_flame_offset_from_radius(angle, radius)


static func get_flame_reset_radius(width: float, height: float) -> Vector2:
	return Vector2(
		get_flame_reset_radius_x(width),
		get_flame_reset_radius_y(height)
	)


static func get_flame_reset_radius_x(width: float) -> float:
	return width * RESET_RADIUS_X_RATIO


static func get_flame_reset_radius_y(height: float) -> float:
	return height * RESET_RADIUS_Y_RATIO


static func get_flame_reset_size(flame_index: int) -> float:
	return RESET_SIZE_BASE + float(get_flame_reset_size_offset(flame_index))


static func get_flame_reset_size_offset(flame_index: int) -> int:
	return get_flame_reset_size_pattern_value(flame_index)


static func get_flame_reset_size_pattern_value(flame_index: int) -> int:
	return get_flame_pattern_value(flame_index, RESET_SIZE_PATTERN_STEP, RESET_SIZE_PATTERN_MODULO)


static func get_flame_reset_lifetime(flame_index: int) -> float:
	return RESET_LIFETIME_BASE + float(get_flame_reset_lifetime_offset(flame_index))


static func get_flame_reset_lifetime_offset(flame_index: int) -> int:
	return get_flame_reset_lifetime_pattern_value(flame_index)


static func get_flame_reset_lifetime_pattern_value(flame_index: int) -> int:
	return get_flame_pattern_value(flame_index, RESET_LIFETIME_PATTERN_STEP, RESET_LIFETIME_PATTERN_MODULO)


static func drift_flame(flame: Dictionary, phase: float, fps_scale: float, width: float, height: float) -> void:
	flame["offset"] = get_flame_drift_offset(flame, phase, fps_scale, width, height)
	flame["size"] = get_flame_drift_size(flame, fps_scale)


static func get_flame_drift_offset(flame: Dictionary, phase: float, fps_scale: float, width: float, height: float) -> Vector2:
	var offset: Vector2 = get_flame_unclamped_drift_offset(flame, phase, fps_scale)
	return clamp_flame_offset(offset, width, height)


static func get_flame_current_offset(flame: Dictionary) -> Vector2:
	return CommandoFirearmValueUtils.get_vector2(flame.get("offset", Vector2.ZERO), Vector2.ZERO)


static func get_flame_unclamped_drift_offset(flame: Dictionary, phase: float, fps_scale: float) -> Vector2:
	return get_flame_current_offset(flame) + get_flame_drift_step(phase, fps_scale)


static func get_flame_drift_step(phase: float, fps_scale: float) -> Vector2:
	return Vector2(
		get_flame_drift_wave_offset(phase, fps_scale),
		get_flame_drift_rise_offset(fps_scale)
	)


static func get_flame_drift_wave_offset(phase: float, fps_scale: float) -> float:
	return sin(phase) * DRIFT_WAVE_SPEED * fps_scale


static func get_flame_drift_rise_offset(fps_scale: float) -> float:
	return -DRIFT_RISE_SPEED * fps_scale


static func clamp_flame_offset(offset: Vector2, width: float, height: float) -> Vector2:
	var x_bound: float = get_flame_offset_bound(width)
	var y_bound: float = get_flame_offset_bound(height)
	return Vector2(
		clamp(offset.x, -x_bound, x_bound),
		clamp(offset.y, -y_bound, y_bound)
	)


static func get_flame_offset_bound(length: float) -> float:
	return length * OFFSET_BOUND_RATIO


static func get_flame_drift_size(flame: Dictionary, fps_scale: float) -> float:
	return clamp_flame_drift_size(get_flame_unclamped_drift_size(flame, fps_scale))


static func get_flame_current_size(flame: Dictionary) -> float:
	return float(flame.get("size", DEFAULT_DRIFT_SIZE))


static func get_flame_unclamped_drift_size(flame: Dictionary, fps_scale: float) -> float:
	return get_flame_current_size(flame) * get_flame_size_decay(fps_scale)


static func get_flame_size_decay(fps_scale: float) -> float:
	return pow(SIZE_DECAY_RATE, fps_scale)


static func clamp_flame_drift_size(size: float) -> float:
	return max(MIN_DRIFT_SIZE, size)
