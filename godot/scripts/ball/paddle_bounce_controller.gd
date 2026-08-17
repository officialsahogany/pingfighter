extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceFrameState := preload("res://scripts/ball/paddle_bounce_frame_state.gd")
const PaddleBouncePlayerSkillStep := preload("res://scripts/ball/paddle_bounce_player_skill_step.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const PaddleBouncePostHitStep := preload("res://scripts/ball/paddle_bounce_post_hit_step.gd")
const PaddleBounceSkillFlow := preload("res://scripts/ball/paddle_bounce_skill_flow.gd")
const PaddleBounceVelocityStep := preload("res://scripts/ball/paddle_bounce_velocity_step.gd")

var frame_state: Object = PaddleBounceFrameState.new()
var player_skill_step: Object = PaddleBouncePlayerSkillStep.new()
var post_hit_handler: Object = PaddleBouncePostHitHandler.new()
var post_hit_step: Object = PaddleBouncePostHitStep.new()
var skill_flow: Object = PaddleBounceSkillFlow.new()
var velocity_step: Object = PaddleBounceVelocityStep.new()


func bounce(
	paddle_x: float,
	paddle_w: float,
	is_player: bool,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary = {}
) -> Dictionary:
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if is_player:
		ball_vel = _restore_perk_resume_suppressed_speed(ball_vel, context)
	else:
		ball_vel = _restore_void_phantom_suppressed_speed(ball_vel, deps)
	var pre_hit_speed: float = ball_vel.length()
	var incoming_dx: float = ball_vel.x
	var paddle_center_x: float = paddle_x + paddle_w * 0.5
	var contact_offset_x: float = ball_pos.x - paddle_center_x
	# Negative contact offset means the ball hit left of paddle center;
	# positive / zero means right. Player attack-sheet selection consumes
	# this same sign through `hit_pos`.
	var hit_pos: float = contact_offset_x / (paddle_w * 0.5)
	hit_pos = clamp(hit_pos, -1.0, 1.0)

	var power_state = deps.get("power_state", null)
	var was_power_smashing: bool = power_state != null and (
		power_state.is_parabola_active() or power_state.is_freeze_active()
	)
	var physics = deps.get("ball_physics", null)
	var paddle_bounce_state = deps.get("paddle_bounce_state", null)
	if paddle_bounce_state == null:
		return {}

	var outgoing_direction: float = -1.0 if is_player else 1.0
	var speed: float = float(paddle_bounce_state.get_initial_speed(ball_vel))
	var angle_rad: float = deg_to_rad(hit_pos * float(context.get("max_bounce_angle", 60.0)))
	var frame: Dictionary = frame_state.build(context, physics, ball_vel, pre_hit_speed, angle_rad)
	var power_activated: bool = false
	var drive_activated: bool = false
	if is_player:
		var skill_step_result: Dictionary = player_skill_step.apply(
			skill_flow,
			frame_state,
			speed,
			angle_rad,
			hit_pos,
			float(frame["accel_scale"]),
			ball_pos,
			frame,
			context,
			deps,
			callbacks
		)
		power_activated = bool(skill_step_result.get("power_activated", false))
		drive_activated = bool(skill_step_result.get("drive_activated", false))
		speed = float(skill_step_result.get("speed", speed))
		angle_rad = float(skill_step_result.get("angle_rad", angle_rad))

	var velocity_step_result: Dictionary = velocity_step.apply(
		paddle_bounce_state,
		frame_state,
		ball_vel,
		hit_pos,
		is_player,
		incoming_dx,
		outgoing_direction,
		speed,
		angle_rad,
		drive_activated,
		frame,
		physics,
		deps,
		context
	)
	ball_vel = _get_vector2(velocity_step_result, "ball_vel", ball_vel)

	var post_hit_result: Dictionary = post_hit_step.apply(
		post_hit_handler,
		frame_state,
		is_player,
		ball_pos,
		ball_vel,
		hit_pos,
		paddle_w,
		power_activated,
		was_power_smashing,
		drive_activated,
		frame,
		context,
		deps
	)
	ball_pos = _get_vector2(post_hit_result, "ball_pos", ball_pos)
	ball_vel = _get_vector2(post_hit_result, "ball_vel", ball_vel)
	var player_speed: float = float(post_hit_result.get("player_speed", context.get("player_speed", 0.0)))
	var boss_vel: float = float(post_hit_result.get("boss_vel", context.get("boss_vel", 0.0)))
	var result: Dictionary = frame_state.build_result_snapshot(frame, ball_pos, ball_vel, player_speed, boss_vel)
	if post_hit_result.has("runtime_perk_gold"):
		result["runtime_perk_gold"] = int(post_hit_result.get("runtime_perk_gold", 0))
	# 패들 소유 스킬 활성화 에지(파워스매싱/드라이브)를 결과로 전파한다 —
	# 융합 스킬-사용 훅 등 같은 프레임 소비자가 result에서만 읽는 일회성 에지.
	result["power_activated"] = power_activated
	result["drive_activated"] = drive_activated
	for key in [
		"player_collision_cooldown",
		"boss_collision_cooldown",
		"smasher_wheel_speed_cap",
		"smasher_wheel_hit",
		"rainbow_fur_glove_activated",
		"rainbow_fur_glove_cooldown_reduction_pct",
		"shrapnel_armor_activated",
		"shrapnel_armor_shard_count",
		"shrapnel_armor_gauge_cost",
		"blacksmith_thor_shield_hit",
		"blacksmith_thor_shield_hit_pos",
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_anim_timer",
		"blacksmith_umbrella_retracting",
		"blacksmith_umbrella_anim_direction",
		"blacksmith_umbrella_open_ratio",
		"blacksmith_thor_shield_open_ratio",
		"blacksmith_umbrella_raise_amount",
		"blacksmith_umbrella_shield_open_amount",
		"blacksmith_umbrella_visual_state",
		"blacksmith_umbrella_folded",
		"blacksmith_umbrella_deployed",
		"blacksmith_umbrella_swing_active",
		"blacksmith_umbrella_swing_direction",
		"blacksmith_umbrella_swing_timer",
		"blacksmith_umbrella_gauge",
		"blacksmith_umbrella_gauge_max",
		"blacksmith_umbrella_gauge_gain",
		"blacksmith_umbrella_damage_flash_timer",
		"blacksmith_umbrella_hit_pulse_timer",
		"suppress_paddle_hit_knockback",
		"paddle_hit_pulse_kind",
		"paddle_hit_pulse_intensity",
		"commando_bowling_trap_guard_consumed",
		"commando_bowling_trap_guarded",
		"commando_bowling_trap_guard_hit",
		"commando_bowling_trap_guard_armed",
		"commando_bowling_trap_guard_source",
		"commando_bowling_trap_guard_status_source",
		"commando_bowling_trap_guard_knockback_power",
		"commando_bowling_trap_guard_knockback_vel",
		"commando_bowling_trap_guard_stun_frames",
		"commando_bowling_trap_guard_restore_speed",
		"commando_bowling_trap_guard_consumed_restore_speed",
		"commando_suicide_drone_ball_boost_active",
		"commando_suicide_drone_ball_restore_speed",
		"commando_suicide_drone_ball_boosted_speed",
		"commando_suicide_drone_ball_boost_consumed",
		"commando_suicide_drone_ball_restored_speed",
		"lingpet_wild_roar_ball_boost_active",
		"lingpet_wild_roar_ball_restore_speed",
		"lingpet_wild_roar_ball_boost_consumed",
		"lingpet_wild_roar_ball_restored_speed",
		"boss_status_immune",
		"speed_limit_disabled",
	]:
		if post_hit_result.has(key):
			result[key] = post_hit_result[key]
	if not is_player:
		# 후처리 훅(스테이지7 아카무 등)이 "정상 보스 반사가 확정된 결과"만
		# 소비하도록 하는 표식 — 빈/미확정 결과에는 실리지 않는다.
		result["normal_boss_bounce_committed"] = true
	apply_rally_speed_cap_progression(result, context)
	return result


func apply_rally_speed_cap_progression(result: Dictionary, context: Dictionary) -> void:
	_apply_rally_speed_cap_progression(result, context)


func _apply_rally_speed_cap_progression(result: Dictionary, context: Dictionary) -> void:
	var increase: float = max(0.0, float(context.get("rally_speed_cap_increase_per_hit", 0.5)))
	if increase <= 0.0:
		return
	var bonus_max: float = max(0.0, float(context.get("rally_speed_cap_bonus_max", 10.0)))
	var current_bonus: float = max(0.0, float(context.get("rally_speed_cap_bonus", 0.0)))
	var next_bonus: float = min(current_bonus + increase, bonus_max)
	result["rally_speed_cap_bonus"] = next_bonus
	var applied_increase: float = next_bonus - current_bonus
	if applied_increase <= 0.0:
		return
	_raise_cap(result, context, "max_ball_speed", 26.0, applied_increase)
	_raise_cap(result, context, "impact_boost_max_ball_speed", 26.0, applied_increase)
	if bool(context.get("fire_weather_speed_cap_active", false)):
		_raise_cap(result, context, "fire_weather_max_ball_speed", 35.0, applied_increase)


func _raise_cap(
	result: Dictionary,
	context: Dictionary,
	key: String,
	fallback: float,
	increase: float
) -> void:
	var current_cap: float = float(context.get(key, fallback))
	if current_cap >= INF:
		return
	result[key] = current_cap + increase


func _restore_perk_resume_suppressed_speed(ball_vel: Vector2, context: Dictionary) -> Vector2:
	# 퍽(스타포인트) 선택 모달 복귀 안전장치는 하강 중인 공의 ball_vel "크기"를 매 프레임
	# original*ratio(하한 0.30)로 덮어쓴다(runtime_perk_resume_safety.gd). 그 램프는
	# update_ball보다 먼저 도는데(battle_frame_flow_controller: update_runtime_perk_resume
	# -> update_ball), 기존 해제 조건은 "공이 위로 움직일 때"라 타격 프레임에는 아직
	# 하강 중이다 -> 해제가 한 프레임 늦어 이번 타구의 입력 공속이 눌린 채 확정된다.
	# 그 결과 안전장치가 반응시간이 아니라 페널티가 된다: 천뢰격/벽력타가 눌린 속도로
	# target_speed / original_speed를 시딩해 순항속이 떨어지고(콤보증폭칩 장착 시에는
	# 발사 속도 자체가), 보스 카운터 복원 속도까지 오염된다.
	# 플레이어가 실제로 받아친 순간 안전장치는 목적을 다했으므로, 방향은 그대로 두고
	# 크기만 모달 이전 원속으로 되돌린다(초과 금지 = 램프가 없었을 때와 동일한 입력).
	# 램프 자체의 teardown은 기존 상승-즉시-해제가 다음 프레임에 처리한다.
	var pre_modal_speed: float = _get_vector2(context, "perk_resume_original_ball_vel", Vector2.ZERO).length()
	var current_speed: float = ball_vel.length()
	if current_speed <= 0.001 or pre_modal_speed <= current_speed + 0.001:
		return ball_vel
	return ball_vel * (pre_modal_speed / current_speed)


# 허공환영은 발동 타구의 공속을 -40% 눌러 기만 비행 시간을 벌어준다. 그 창의
# 계약은 "보스가 가드할 때까지"이므로, 보스 반사가 확정되는 이 지점에서 크기만
# 원속으로 되돌린다(방향은 아래 반사 계산이 정한다).
# ⚠️여기서 복원하지 않으면 감속이 랠리 전체로 샌다 — get_initial_speed 가 들어오는
# 크기를 그대로 나가는 속도로 쓰기 때문에(×PADDLE_HIT_BOOST=1.0), 눌린 공을 받아친
# 보스 리턴도 눌린 채 확정되고 이후 랠리가 통째로 느려진다.
# ⚠️아카무 무형화는 controller.bounce 호출 '전'에 걸러지고(_process_paddle),
# 여기 도달한 보스 반사는 normal_boss_bounce_committed 로 확정되므로,
# 이 지점의 소비 = 가드 확정 1회다.
func _restore_void_phantom_suppressed_speed(ball_vel: Vector2, deps: Dictionary) -> Vector2:
	var state: Object = deps.get("smasher_void_phantom_state", null)
	if state == null or not state.has_method("consume_suppressed_launch_speed"):
		return ball_vel
	var original_speed: float = float(state.consume_suppressed_launch_speed())
	if original_speed <= 0.0:
		return ball_vel
	var current_speed: float = ball_vel.length()
	# 초과 금지(max 의미론) — 감속이 없었을 때와 동일한 입력으로만 되돌린다.
	if current_speed <= 0.001 or original_speed <= current_speed + 0.001:
		return ball_vel
	return ball_vel * (original_speed / current_speed)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
