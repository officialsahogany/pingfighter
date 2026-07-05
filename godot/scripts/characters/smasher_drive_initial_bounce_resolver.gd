extends RefCounted

const DRIVE_EFFECT_MULT: float = 0.8
const DRIVE_MAX_LAUNCH_SPEED_MULT: float = 2.30 * DRIVE_EFFECT_MULT
const DRIVE_NO_COMBO_SPEED_MULT: float = 0.975
const DRIVE_NO_COMBO_BASE_SPIN: float = 0.155 * DRIVE_EFFECT_MULT
const DRIVE_NO_COMBO_SPEED_SPIN_COEFF: float = 0.009 * DRIVE_EFFECT_MULT
const DRIVE_NO_COMBO_SPIN_CAP: float = 0.39 * DRIVE_EFFECT_MULT
const DRIVE_BASE_ANGLE_RAD: float = PI / 8.0
const DRIVE_POSITION_FACTOR_SCALE: float = 0.30
const SMASHER_DRIVE_COMBO_SPEED_MULT: float = 1.0 + ((1.00576 - 1.0) * DRIVE_EFFECT_MULT)
const SMASHER_DRIVE_COMBO_SPIN_PER_COMBO: float = 0.06 * DRIVE_EFFECT_MULT
const SMASHER_DRIVE_COMBO_SPIN_CAP: float = 0.36 * DRIVE_EFFECT_MULT
const SMASHER_DRIVE_COMBO_SPEED_PER_COMBO: float = 0.00576 * DRIVE_EFFECT_MULT
const SMASHER_DRIVE_COMBO_SPEED_CAP: float = 0.03456 * DRIVE_EFFECT_MULT
const SMASHER_DRIVE_COMBO_SPIN_CAP_PER_COMBO: float = 0.04 * DRIVE_EFFECT_MULT
const SMASHER_DRIVE_COMBO_SPIN_CAP_BONUS_MAX: float = 0.24 * DRIVE_EFFECT_MULT
const SMASHER_DRIVE_COMBO_PARTICLE_PER_COMBO: int = 3


func apply(
	speed: float,
	hit_pos: float,
	drive_direction: int,
	combo_count: int,
	accel_scale: float,
	ball_physics: Object,
	combo_min_count: int,
	text_duration_frames: float,
	combo_amp_speed: float = 0.0,
	combo_amp_curve: float = 0.0
) -> Dictionary:
	var combo_active: bool = combo_count >= combo_min_count
	var drive_speed_mult: float = DRIVE_NO_COMBO_SPEED_MULT
	var drive_speed_bypass_bonus: float = 0.0
	var drive_base_spin: float = DRIVE_NO_COMBO_BASE_SPIN
	var drive_speed_spin_coeff: float = DRIVE_NO_COMBO_SPEED_SPIN_COEFF
	var drive_spin_cap: float = DRIVE_NO_COMBO_SPIN_CAP
	var drive_particle_count: int = 4
	if combo_active:
		drive_speed_mult = SMASHER_DRIVE_COMBO_SPEED_MULT
		# 콤보증폭칩: 공속 콤보 항(rate+cap)만 증폭. base 배율(SMASHER_DRIVE_COMBO_SPEED_MULT)은 비증폭.
		drive_speed_bypass_bonus = min(
			float(combo_count) * SMASHER_DRIVE_COMBO_SPEED_PER_COMBO * (1.0 + combo_amp_speed),
			SMASHER_DRIVE_COMBO_SPEED_CAP * (1.0 + combo_amp_speed)
		)
		drive_base_spin = 0.22 * DRIVE_EFFECT_MULT
		drive_speed_spin_coeff = 0.012 * DRIVE_EFFECT_MULT
		# 콤보증폭칩: 커브 상한 콤보 항(rate+max)만 증폭. base 0.52*MULT는 비증폭.
		drive_spin_cap = 0.52 * DRIVE_EFFECT_MULT + min(
			float(combo_count) * SMASHER_DRIVE_COMBO_SPIN_CAP_PER_COMBO * (1.0 + combo_amp_curve),
			SMASHER_DRIVE_COMBO_SPIN_CAP_BONUS_MAX * (1.0 + combo_amp_curve)
		)
		drive_particle_count = 8 + combo_count * SMASHER_DRIVE_COMBO_PARTICLE_PER_COMBO

	var original_speed: float = speed
	speed *= _apply_dampened_multiplier(ball_physics, speed, drive_speed_mult)
	if drive_speed_bypass_bonus > 0.0:
		speed *= 1.0 + drive_speed_bypass_bonus
	var speed_increase: float = speed - original_speed

	var drive_base_angle_mag: float = DRIVE_BASE_ANGLE_RAD
	var drive_position_factor_scale: float = DRIVE_POSITION_FACTOR_SCALE
	if combo_active:
		var combo_steepness: float = clamp((float(combo_count) - 2.0) / 4.0, 0.0, 1.0)
		drive_base_angle_mag = PI / 16.0 - (PI / 16.0 - PI / 180.0) * combo_steepness
		drive_position_factor_scale = 0.15 - (0.15 - 0.01) * combo_steepness
	var angle_rad: float = (
		drive_base_angle_mag if drive_direction == -1 else -drive_base_angle_mag
	) + hit_pos * drive_position_factor_scale

	var drive_combo_spin_bonus: float = 0.0
	if combo_active:
		# 콤보증폭칩: 커브(스핀) 콤보 항(rate+cap)만 증폭.
		drive_combo_spin_bonus = min(
			float(combo_count) * SMASHER_DRIVE_COMBO_SPIN_PER_COMBO * (1.0 + combo_amp_curve),
			SMASHER_DRIVE_COMBO_SPIN_CAP * (1.0 + combo_amp_curve)
		)
	var spin_strength: float = min(
		drive_spin_cap,
		drive_base_spin + speed * drive_speed_spin_coeff + drive_combo_spin_bonus
	)

	var drive_base_multiplier: float = _apply_dampened_multiplier(
		ball_physics,
		speed,
		randf_range(
			1.0 + 0.0144 * DRIVE_EFFECT_MULT * accel_scale,
			1.0 + 0.0504 * DRIVE_EFFECT_MULT * accel_scale
		)
	)
	var drive_base_additional_speed: float = speed * (drive_base_multiplier - 1.0)
	speed *= drive_base_multiplier
	speed_increase += drive_base_additional_speed
	var max_drive_speed: float = max(original_speed, 0.1) * DRIVE_MAX_LAUNCH_SPEED_MULT
	if speed > max_drive_speed:
		speed = max_drive_speed
		speed_increase = max(0.0, speed - original_speed)

	return {
		"speed": speed,
		"angle_rad": angle_rad,
		"spin_strength": spin_strength,
		"spin_direction": drive_direction,
		"speed_increase": speed_increase,
		"particle_count": drive_particle_count,
		"text_timer_frames": text_duration_frames * (2.0 if combo_active else 1.0),
		"consume_combo": combo_active,
	}


func _apply_dampened_multiplier(ball_physics: Object, current_speed: float, raw_multiplier: float) -> float:
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		return float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	return raw_multiplier
