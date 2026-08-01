extends RefCounted

const STAGE1_CHAMPION_BOSS_SPEED_MULT: float = 1.5
const BOSS_ACCEL: float = 0.798 * STAGE1_CHAMPION_BOSS_SPEED_MULT
const BOSS_DECEL: float = 0.798 * STAGE1_CHAMPION_BOSS_SPEED_MULT
const BOSS_MAX_SPEED: float = 6.3175 * STAGE1_CHAMPION_BOSS_SPEED_MULT
const TURN_SLIDE_BRAKE_MULT: float = 0.48
const TURN_APPROACH_SLIDE_BRAKE_MULT: float = 0.82
const TURN_RELEASE_ACCEL_MULT: float = 0.18
const TURN_RELEASE_MIN_RATIO: float = 0.03
# 도착 정착 데드존의 하한(px). 실제 데드존은 '정지 상태에서 한 프레임 가속했을
# 때의 변위'(accel × fps_scale²)로, 이 값은 accel≈0 같은 퇴화 케이스 보호용이다.
const SETTLE_DEADZONE_MIN_PX: float = 0.05


# 리졸버 출력 뒤에 붙는 이동 후처리(채찍 제한 + 각종 감속 배율)의 단일 정본.
# ⚠️실경로(boss_ai_state._update_motion)와 예측의 도달 가능성 시뮬레이션이 **같은
# 함수**를 써야 한다. 시뮬레이션만 후처리를 빼먹으면 감속 디버프가 걸린 보스를
# "충분히 비켜난다"고 오판한다(거미지뢰 감속 스윕에서 45건 중 37건 재현).
static func apply_movement_post_processing(boss_vel: float, context: Dictionary) -> float:
	if bool(context.get("stage1_dalji_whip_active", false)):
		boss_vel = clamp(boss_vel, -1.5, 1.5) * 0.3
	return boss_vel * get_movement_slow_multiplier(context)


static func is_soap_slip_active(context: Dictionary) -> bool:
	return bool(context.get("active_item_soap_slip_active", false))


# 비누 미끄러짐: AI 의도로 직행하지 않고 관성 위치/속도에 blend 비율만 섞는다.
# ⚠️실경로의 **마지막** 이동 후처리다 — 도달 시뮬레이션이 이걸 빼면 미끄러지는
# 보스를 "제때 비켜난다"고 오판한다(극한 y=600 v20 기본 배율에서 armed 후 차단).
# 반환값은 (pos_x, vel) 쌍이다.
static func apply_soap_slip_blend(
	original_pos_x: float,
	original_vel: float,
	ai_pos_x: float,
	ai_vel: float,
	context: Dictionary,
	fps_scale: float,
	play_left: float,
	play_right: float,
	boss_paddle_width: float
) -> Vector2:
	var blend: float = clamp(float(context.get("active_item_soap_slip_blend", 0.18)), 0.0, 1.0)
	var friction: float = clamp(float(context.get("active_item_soap_slip_friction", 0.985)), 0.0, 1.0)
	var momentum_x: float = original_pos_x + original_vel * fps_scale
	var next_vel: float = (original_vel + (ai_vel - original_vel) * blend) * friction
	var next_pos_x: float = momentum_x + (ai_pos_x - momentum_x) * blend
	if next_pos_x < play_left:
		next_pos_x = play_left
		next_vel = abs(next_vel) * 0.3
	elif next_pos_x > play_right - boss_paddle_width:
		next_pos_x = play_right - boss_paddle_width
		next_vel = -abs(next_vel) * 0.3
	return Vector2(next_pos_x, next_vel)


const POWER_SMASH_BOSS_REACT_PER_COMBO: float = 0.05
const POWER_SMASH_BOSS_REACT_CAP: float = 0.30


# 반응 배율의 단일 정본. 도달 가능성 시뮬레이션도 같은 값을 써야 실경로와 어긋나지
# 않는다(파워스매싱 집중 중이면 보스가 더 빨리 반응한다).
static func get_power_smash_reaction_multiplier(context: Dictionary) -> float:
	if not bool(context.get("power_smashing_parabola_active", false)):
		return 1.0
	var combo_consumed: int = int(context.get("power_smashing_combo_consumed", 0))
	if combo_consumed < 2:
		return 1.0
	return 1.0 + min(float(combo_consumed) * POWER_SMASH_BOSS_REACT_PER_COMBO, POWER_SMASH_BOSS_REACT_CAP)


static func get_movement_slow_multiplier(context: Dictionary) -> float:
	var multiplier := 1.0
	if bool(context.get("active_item_spider_mine_slow_active", false)):
		multiplier *= clamp(float(context.get("active_item_spider_mine_slow_factor", 0.4)), 0.05, 1.0)
	if bool(context.get("smasher_plasma_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("smasher_plasma_boss_slow_multiplier", 1.0)), 0.05, 1.0)
	if bool(context.get("venom_mist_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("venom_mist_boss_slow_multiplier", 0.3)), 0.05, 1.0)
	if bool(context.get("baal_boots_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("baal_boots_boss_slow_multiplier", 0.7)), 0.05, 1.0)
	if bool(context.get("lingpet_star_coil_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("lingpet_star_coil_boss_slow_multiplier", 0.4)), 0.05, 1.0)
	if bool(context.get("lingpet_dwarf_magic_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("lingpet_dwarf_magic_boss_slow_multiplier", 0.55)), 0.05, 1.0)
	# Molotov fire already owns hard movement obstruction through the post-AI
	# barrier in boss_ai_state. Keep its lingering fire slow as a standalone
	# smooth-return feel, but do not stack it on top of dedicated boss-slow debuffs.
	if is_equal_approx(multiplier, 1.0) and bool(context.get("active_item_molotov_slow_active", false)):
		multiplier *= clamp(float(context.get("active_item_molotov_slow_factor", 1.0)), 0.05, 1.0)
	return clamp(multiplier, 0.05, 1.0)


func update_velocity(
	future_x: float,
	boss_center: float,
	boss_vel: float,
	fps_scale: float,
	ball_approaching_boss: bool,
	reaction_multiplier: float = 1.0,
	decel_multiplier: float = 1.0,
	movement_context: Dictionary = {}
) -> float:
	var base_accel: float = max(0.0, float(movement_context.get("boss_movement_accel", BOSS_ACCEL)))
	var base_decel: float = max(0.0, float(movement_context.get("boss_movement_decel", BOSS_DECEL)))
	var base_max_speed: float = max(0.0, float(movement_context.get("boss_movement_max_speed", BOSS_MAX_SPEED)))
	var accel: float = base_accel * max(0.0, reaction_multiplier)
	var max_speed: float = base_max_speed * max(0.0, reaction_multiplier)
	var decel: float = base_decel * max(0.0, decel_multiplier)
	# 한 프레임 가속으로 만들어지는 변위보다 목표 오차가 작으면 '도착'으로 본다.
	# 아래 _get_target_direction 주석의 한계 순환을 끊는 유일한 지점이다.
	var settle_deadzone: float = max(SETTLE_DEADZONE_MIN_PX, accel * fps_scale * fps_scale)
	var target_dir: int = _get_target_direction(future_x, boss_center, settle_deadzone)
	var reversing: bool = _is_reversing(target_dir, boss_vel)
	if reversing:
		return _sanitize_velocity(
			_brake_through_reversal(target_dir, boss_vel, fps_scale, ball_approaching_boss, accel, decel),
			max_speed
		)

	if target_dir < 0:
		boss_vel = _approach_target(future_x, boss_center, boss_vel, fps_scale, accel, decel, max_speed, true)
	elif target_dir > 0:
		boss_vel = _approach_target(future_x, boss_center, boss_vel, fps_scale, accel, decel, max_speed, false)
	else:
		boss_vel = _decelerate_to_stop(boss_vel, fps_scale, decel)

	return _sanitize_velocity(boss_vel, max_speed)


# Accelerate toward the target, but start braking once the boss is within its own
# stopping distance so it SETTLES on the predicted x instead of blowing past it.
# Without this predictive brake the resolver only ever decelerates AFTER overshoot
# (via _brake_through_reversal), and the weak reversal brake (< 1.0 mult) leaves a
# sustained limit-cycle oscillation after any large displacement (banana slip /
# knockback slam to a wall). Braking distance is the standard v^2/(2*decel) stop
# distance; fps_scale cancels out of that integral so it is not a factor here.
func _approach_target(
	future_x: float,
	boss_center: float,
	boss_vel: float,
	fps_scale: float,
	accel: float,
	decel: float,
	max_speed: float,
	going_left: bool
) -> float:
	var distance_to_target: float = abs(future_x - boss_center)
	var braking_distance: float = (boss_vel * boss_vel) / (2.0 * max(0.001, decel))
	if braking_distance >= distance_to_target:
		return _decelerate_to_stop(boss_vel, fps_scale, decel)
	if going_left:
		return _accelerate_left(boss_vel, fps_scale, accel, max_speed)
	return _accelerate_right(boss_vel, fps_scale, accel, max_speed)


func _brake_through_reversal(
	target_dir: int,
	boss_vel: float,
	fps_scale: float,
	ball_approaching_boss: bool,
	accel: float,
	decel: float
) -> float:
	var slide_brake_mult: float = TURN_APPROACH_SLIDE_BRAKE_MULT if ball_approaching_boss else TURN_SLIDE_BRAKE_MULT
	var brake_step: float = decel * slide_brake_mult * fps_scale
	var current_speed: float = abs(boss_vel)
	if current_speed > brake_step:
		return move_toward(boss_vel, 0.0, brake_step)

	var remaining_brake: float = brake_step - current_speed
	var release_ratio: float = clamp(remaining_brake / max(0.001, brake_step), TURN_RELEASE_MIN_RATIO, 1.0)
	var release_speed: float = accel * TURN_RELEASE_ACCEL_MULT * release_ratio * fps_scale
	return float(target_dir) * release_speed


func _sanitize_velocity(boss_vel: float, max_speed: float) -> float:
	boss_vel = clamp(boss_vel, -max_speed, max_speed)
	if abs(boss_vel) < 0.001:
		return 0.0
	return boss_vel


func _accelerate_left(boss_vel: float, fps_scale: float, accel: float, max_speed: float) -> float:
	if boss_vel <= -max_speed:
		return boss_vel
	return max(-max_speed, boss_vel - accel * fps_scale)


func _accelerate_right(boss_vel: float, fps_scale: float, accel: float, max_speed: float) -> float:
	if boss_vel >= max_speed:
		return boss_vel
	return min(max_speed, boss_vel + accel * fps_scale)


func _decelerate_to_stop(boss_vel: float, fps_scale: float, decel: float) -> float:
	return move_toward(boss_vel, 0.0, decel * fps_scale)


# ⚠️데드존 없이 부호만 보면 보스는 목표를 사이에 두고
# [가속 → 오버슛 → 역전제동 → 재가속]을 매 프레임 반복하는 한계 순환에 빠져
# 제자리에서 떨린다(실측 peak-to-peak 1.83px, 목표 오차 0.05px에서도 동일).
# 예측 브레이크(_approach_target)는 '큰 변위'의 오버슛만 잡는다 — 남은 오차가
# 한 스텝 변위보다 작으면 정지 상태의 브레이크 거리(v²/2decel)가 0이라 언제나
# 가속 분기로 들어가기 때문이다.
# 평소엔 공이 금방 도착해 순환이 짧게 끝나지만, 허공환영처럼 공이 느리게
# 올라와 보스가 목표에 오래 주차돼 있으면 그대로 눈에 보인다.
# 데드존 크기는 공(28.6px)·보스 패들(100px)·미스 임계(69.3px) 대비 작아
# 방어 정확도에 미치는 영향은 실질적으로 무시 가능한 범위다.
func _get_target_direction(future_x: float, boss_center: float, settle_deadzone: float = 0.0) -> int:
	var distance: float = future_x - boss_center
	if absf(distance) <= settle_deadzone:
		return 0
	if distance < 0.0:
		return -1
	if distance > 0.0:
		return 1
	return 0


func _is_reversing(target_dir: int, boss_vel: float) -> bool:
	return (target_dir < 0 and boss_vel > 0.0) or (target_dir > 0 and boss_vel < 0.0)
