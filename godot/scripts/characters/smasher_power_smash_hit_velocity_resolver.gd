extends RefCounted

const PowerSmashHitDirectionResolver := preload("res://scripts/characters/smasher_power_smash_hit_direction_resolver.gd")

const POWER_SMASH_EFFECT_MULT := 1.0
const POWER_SMASH_SPEED_BOOST_RATE := 0.3161088 * POWER_SMASH_EFFECT_MULT
const POWER_SMASH_MIN_BOOST_MULT := 1.0426496 * POWER_SMASH_EFFECT_MULT
# 무콤보 페널티(원본 0.75/0.78)는 2026-06-11 Option C 설계 결정으로 의도적으로
# 1.0 중화 — 무콤보 스매시도 쓸 만하게 유지한다. 새 설계 결정 없이 원본 파리티
# 복원 금지(docs/character_skill_perk_checklist.md §3.2 "recorded design decision").
const POWER_SMASH_NO_COMBO_BOOST_MULT := 1.0
const POWER_SMASH_INITIAL_STRAIGHT_MULT := 1.0 + ((1.197568 - 1.0) * POWER_SMASH_EFFECT_MULT)
const POWER_SMASH_INITIAL_SIDE_MULT := 1.0 + ((1.263424 - 1.0) * POWER_SMASH_EFFECT_MULT)
# 위와 같은 Option C 중화. (참고: 원본 x0.78을 리밸런스된 초기 부스트 1.1976/1.2634에
# 그대로 곱하면 1.0 미만이 되어 버스트가 감속으로 뒤집힌다.)
const POWER_SMASH_NO_COMBO_INITIAL_MULT := 1.0
const POWER_SMASH_COMBO_SPEED_PER_COUNT := 0.01448832 * POWER_SMASH_EFFECT_MULT
const POWER_SMASH_COMBO_SPEED_CAP := 0.065856 * POWER_SMASH_EFFECT_MULT
const POWER_SMASH_MAX_LAUNCH_SPEED_MULT := 2.14032 * POWER_SMASH_EFFECT_MULT
const POWER_SMASH_MAX_COMBO_LAUNCH_SPEED_MULT := 2.403744 * POWER_SMASH_EFFECT_MULT

var direction_resolver: Object = PowerSmashHitDirectionResolver.new()


func apply(
	power_state: Object,
	ball_velocity: Vector2,
	ball_position: Vector2,
	player_position: Vector2,
	paddle_width: float,
	base_speed: float,
	ball_physics: Object,
	combo_min_count: int,
	launch_speed_multiplier: float = 1.0,
	smash_speed_amp: float = 0.0
) -> Vector2:
	if power_state == null:
		return ball_velocity

	var ball_current_speed: float = ball_velocity.length()
	power_state.set_original_speed(ball_current_speed)

	var speed_dampen_factor: float = _get_speed_dampen_factor(ball_physics, ball_current_speed)
	var min_boost: float = base_speed * POWER_SMASH_MIN_BOOST_MULT
	var actual_boost: float = max(ball_current_speed * POWER_SMASH_SPEED_BOOST_RATE * speed_dampen_factor, min_boost)
	var combo_consumed: int = int(power_state.get_combo_consumed())
	var combo_boosted: bool = combo_consumed >= combo_min_count
	if combo_consumed < combo_min_count:
		actual_boost *= POWER_SMASH_NO_COMBO_BOOST_MULT

	var new_speed: float = ball_current_speed + actual_boost
	if ball_current_speed > 0.0:
		ball_velocity *= new_speed / ball_current_speed
	else:
		ball_velocity = Vector2(base_speed * 0.8, -base_speed * 0.8)

	var direction: int = int(power_state.get_direction())
	if direction == -1 or direction == 1:
		ball_velocity = direction_resolver.apply_side_direction(ball_velocity, direction, base_speed, ball_physics)
	else:
		ball_velocity = direction_resolver.apply_straight_direction(
			ball_velocity,
			ball_position,
			player_position,
			paddle_width,
			base_speed,
			ball_physics
		)

	if ball_velocity.y > 0.0:
		ball_velocity.y = -abs(ball_velocity.y)

	var safe_launch_speed_multiplier: float = max(0.01, launch_speed_multiplier)
	if not is_equal_approx(safe_launch_speed_multiplier, 1.0):
		ball_velocity *= safe_launch_speed_multiplier

	# 콤보 속도 항(2026-08-05 콤보 상향 설계 결정, 체크리스트 §3.2 개정): set_target_speed
	# 보다 먼저 곱해 발사 버스트뿐 아니라 순항(target)에도 반영한다. 무콤보 쪽 중화
	# (Option C)는 그대로. 콤보증폭칩 amp는 이 항을 (1+amp)로 증폭(base 부스트 비증폭).
	var combo_base_bonus: float = 0.0
	if combo_boosted:
		combo_base_bonus = min(
			float(combo_consumed) * POWER_SMASH_COMBO_SPEED_PER_COUNT,
			POWER_SMASH_COMBO_SPEED_CAP
		)
		ball_velocity *= 1.0 + combo_base_bonus * (1.0 + smash_speed_amp)

	var final_speed: float = ball_velocity.length()
	power_state.set_target_speed(final_speed)
	var initial_boost_multiplier: float = POWER_SMASH_INITIAL_STRAIGHT_MULT if direction == 0 else POWER_SMASH_INITIAL_SIDE_MULT
	if combo_consumed < combo_min_count:
		initial_boost_multiplier *= POWER_SMASH_NO_COMBO_INITIAL_MULT

	if final_speed > 0.0:
		var boost_ratio: float = _apply_dampened_multiplier(ball_physics, final_speed, initial_boost_multiplier)
		ball_velocity *= boost_ratio
		ball_velocity = _clamp_launch_speed(
			ball_velocity,
			base_speed,
			combo_boosted,
			safe_launch_speed_multiplier,
			smash_speed_amp,
			combo_base_bonus
		)
		power_state.start_initial_boost(ball_velocity.length())

	return ball_velocity


func _get_speed_dampen_factor(ball_physics: Object, current_speed: float) -> float:
	if ball_physics != null and ball_physics.has_method("get_speed_dampen_factor"):
		return float(ball_physics.get_speed_dampen_factor(current_speed))
	return 1.0


func _apply_dampened_multiplier(ball_physics: Object, current_speed: float, raw_multiplier: float) -> float:
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		return float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	return raw_multiplier


func _clamp_launch_speed(
	ball_velocity: Vector2,
	base_speed: float,
	combo_boosted: bool,
	max_speed_multiplier: float = 1.0,
	smash_speed_amp: float = 0.0,
	combo_base_bonus: float = 0.0
) -> Vector2:
	var current_speed: float = ball_velocity.length()
	if current_speed <= 0.0:
		return ball_velocity
	var max_mult: float = POWER_SMASH_MAX_COMBO_LAUNCH_SPEED_MULT if combo_boosted else POWER_SMASH_MAX_LAUNCH_SPEED_MULT
	# 콤보 발사 천장 완화 두 축(각각 없으면 캡 포화가 해당 축을 통째로 마스킹한다 —
	# 실측: BALL_BASE_SPEED에서 Lv0==Lv5==18.389이던 칩 회귀와 동일 메커니즘):
	#  (1+base bonus) = 2026-08-05 콤보 상향 결정(순항 반영분의 버스트 헤드룸),
	#  (1+amp) = 콤보증폭칩. 전역 공속 캡이 상한을 별도 보장, 무콤보 발사 캡은 비증폭.
	if combo_boosted and combo_base_bonus > 0.0:
		max_mult *= 1.0 + combo_base_bonus
	if combo_boosted and smash_speed_amp > 0.0:
		max_mult *= 1.0 + smash_speed_amp
	var max_speed: float = max(base_speed, 0.1) * max_mult * max(1.0, max_speed_multiplier)
	if current_speed <= max_speed:
		return ball_velocity
	return ball_velocity.normalized() * max_speed
