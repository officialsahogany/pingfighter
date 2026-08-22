extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")


func update_power_freeze(delta: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var controller: Object = deps.get("power_motion_controller", null)
	if controller == null:
		return
	var result: Dictionary = controller.update_freeze(
		delta,
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		{
			"freeze_duration": float(context.get("power_smash_freeze_duration", 0.0)),
			"ball_size": float(context.get("ball_size", 28.6)),
			"player_has_hit_sprite": bool(context.get("player_has_hit_sprite", false)),
			"player_hit_anim_duration": float(context.get("player_hit_anim_duration", 0.40)),
		},
		deps
	)
	scene.merge(result, true)


func cap_ball_speed(scene: Dictionary, deps: Dictionary) -> void:
	apply_ball_speed_limits(scene, deps)


# Ticks the trampoline launch overspeed window. Runs before the frame's first
# clamp: while the TTL holds, the opened cap survives apply_ball_speed_limits;
# once it expires the cap clears and the normal cap reins the ball back in.
func update_trampoline_launch_cap(scene: Dictionary, fps_scale: float) -> void:
	if float(scene.get("trampoline_launch_speed_cap", 0.0)) <= 0.0:
		return
	var frames: float = float(scene.get("trampoline_launch_speed_cap_frames", 0.0)) - fps_scale
	if frames > 0.0:
		scene["trampoline_launch_speed_cap_frames"] = frames
		return
	scene["trampoline_launch_speed_cap_frames"] = 0.0
	scene["trampoline_launch_speed_cap"] = 0.0


func update_dalji_vision_ball_modifiers(
	scene: Dictionary,
	fps_scale: float,
	deps: Dictionary
) -> void:
	var state: Object = deps.get("dalji_vision_chosik_state", null)
	if state == null:
		return
	if state.has_method("advance_ball_motion_modifiers"):
		state.advance_ball_motion_modifiers(fps_scale)
	if bool(scene.get("skip_ball_motion_step", false)):
		return
	if state.has_method("apply_wallward_curve"):
		var velocity := _get_vector2(scene, "ball_vel", Vector2.ZERO)
		scene["ball_vel"] = state.apply_wallward_curve(velocity, fps_scale)


func apply_power_smash_speed_limit(scene: Dictionary, max_effective_speed: float) -> void:
	_limit_effective_speed(scene, max_effective_speed)


func apply_ball_speed_limits(scene: Dictionary, deps: Dictionary) -> void:
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics == null:
		return
	var velocity: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var minimum_suspended: bool = _is_minimum_rally_speed_suspended(deps)
	if not minimum_suspended and ball_physics.has_method("enforce_minimum_rally_speed"):
		velocity = ball_physics.enforce_minimum_rally_speed(velocity)
	var speed_unlimited: bool = _is_speed_limit_disabled(scene)
	var impact_boost: float = max(1.0, float(scene.get("ball_impact_boost", 1.0)))
	if not minimum_suspended and ball_physics.has_method("get_minimum_effective_boost"):
		impact_boost = max(impact_boost, float(ball_physics.get_minimum_effective_boost(velocity)))
	if not speed_unlimited:
		velocity = _cap_effective_velocity(velocity, impact_boost, _get_effective_speed_cap(scene, impact_boost, deps))
	scene["ball_vel"] = velocity
	scene["ball_impact_boost"] = impact_boost


# 허공환영 기만 비행 창에서만 랠리 최저속 '하한'을 중지한다(캡을 여는
# _is_speed_limit_disabled 의 대칭 레버).
# ⚠️하한은 이중으로 걸린다: ball_vel 자체를 최저속으로 클램프하고, 그 뒤
# get_minimum_effective_boost 가 impact_boost 를 최저속/현재속으로 다시 올려
# 실효 이동거리까지 되돌린다. 한쪽만 풀면 감속이 조용히 먹힌다.
# 스테이지1 기준 최저속 ≈9.68px/frame 이라, 이 게이트가 없으면 저속 랠리에서
# -40%가 -19% 수준으로 줄어 표시값과 체감이 갈린다.
# 창은 보스 가드 반사에서 소비되므로(peek 이 0 을 돌려주는 즉시) 하한도 함께 복귀한다.
func _is_minimum_rally_speed_suspended(deps: Dictionary) -> bool:
	var state: Object = deps.get("smasher_void_phantom_state", null)
	if state == null or not state.has_method("peek_suppressed_launch_speed"):
		return false
	return float(state.peek_suppressed_launch_speed()) > 0.0


func _is_speed_limit_disabled(scene: Dictionary) -> bool:
	return (
		bool(scene.get("speed_limit_disabled", false))
		or bool(scene.get("commando_suicide_drone_ball_boost_active", false))
		or bool(scene.get("lingpet_wild_roar_ball_boost_active", false))
		or bool(scene.get("active_item_aipill_ball_boost_active", false))
		or bool(scene.get("lingpet_mokrin_ball_boost_active", false))
	)


func _get_effective_speed_cap(scene: Dictionary, impact_boost: float, deps: Dictionary) -> float:
	var speed_cap: float = float(scene.get("max_ball_speed", 26.0))
	if impact_boost > 1.001:
		speed_cap = max(speed_cap, float(scene.get("impact_boost_max_ball_speed", 26.0)))
	var meditation_release_cap: float = float(scene.get("stage4_meditation_release_speed_cap", 0.0))
	if meditation_release_cap > 0.0:
		speed_cap = max(speed_cap, meditation_release_cap)
	speed_cap = max(speed_cap, float(scene.get("smasher_wheel_speed_cap", 0.0)))
	speed_cap = max(speed_cap, _get_smasher_overdrive_speed_cap(deps))
	speed_cap = max(speed_cap, float(scene.get("trampoline_launch_speed_cap", 0.0)))
	speed_cap = max(speed_cap, _get_magnum_grip_speed_cap(deps))
	speed_cap = max(speed_cap, _get_viper_blade_speed_cap(deps))
	speed_cap = max(speed_cap, _get_ragnarok_speed_cap(scene, deps))
	if bool(scene.get("fire_weather_speed_cap_active", false)):
		speed_cap = min(speed_cap, float(scene.get("fire_weather_max_ball_speed", 35.0)))
	if meditation_release_cap > 0.0:
		speed_cap = min(speed_cap, meditation_release_cap)
	# 벽력추진(legacy overload key) 일시 캡: 보스 가드 전까지 유효속도 초과 허용 — 일반 하드캡
	# (화염 기상·명상 해방)보다 상위다. 신령환류 무제한 정책은 이 함수에
	# 오기 전에 클램프 자체를 끈다(우세 유지).
	var overload_cap: float = float(scene.get("perk_fusion_overload_speed_cap", 0.0))
	if overload_cap > 0.0:
		speed_cap = max(speed_cap, overload_cap)
	# 연환팽이의 명시적 +50% -> 벽 반사 +30% 궤적은 일반/기상 캡에서
	# 즉시 잘리지 않도록 짧은 전용 캡 창으로 보존한다.
	speed_cap = max(speed_cap, _get_dalji_vision_speed_cap(deps) * maxf(1.0, impact_boost))
	return speed_cap


func _get_dalji_vision_speed_cap(deps: Dictionary) -> float:
	var state: Object = deps.get("dalji_vision_chosik_state", null)
	if state == null or not state.has_method("get_boosted_ball_speed_cap"):
		return 0.0
	return maxf(0.0, float(state.get_boosted_ball_speed_cap()))


# 벽력추진 호환 캡 failsafe TTL(프레임): 보스 가드/득점/라운드 리셋이 정상
# 마감하지만, 소유 이벤트가 유실된 leak도 바운디드로 닫는다.
func update_perk_fusion_overload_speed_cap(scene: Dictionary, fps_scale: float) -> void:
	var remaining: float = float(scene.get("perk_fusion_overload_speed_cap_frames", 0.0))
	if remaining <= 0.0:
		return
	remaining -= maxf(0.0, fps_scale)
	if remaining <= 0.0:
		scene["perk_fusion_overload_speed_cap"] = 0.0
		scene["perk_fusion_overload_speed_cap_frames"] = 0.0
		return
	scene["perk_fusion_overload_speed_cap_frames"] = remaining


func _cap_effective_velocity(velocity: Vector2, impact_boost: float, max_effective_speed: float) -> Vector2:
	if max_effective_speed <= 0.0:
		return velocity
	var speed: float = velocity.length()
	if speed <= 0.0:
		return velocity
	var safe_boost: float = max(0.001, impact_boost)
	var effective_speed: float = speed * safe_boost
	if effective_speed <= max_effective_speed:
		return velocity
	return velocity.normalized() * (max_effective_speed / safe_boost)


func _limit_effective_speed(scene: Dictionary, max_effective_speed: float) -> void:
	var velocity: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var speed: float = velocity.length()
	if speed <= 0.0:
		return
	var impact_boost: float = max(0.001, float(scene.get("ball_impact_boost", 1.0)))
	var effective_speed: float = speed * impact_boost
	if effective_speed <= max_effective_speed:
		return
	scene["ball_vel"] = velocity.normalized() * (max_effective_speed / impact_boost)


func update_serve_collision_cooldowns(scene: Dictionary, fps_scale: float) -> void:
	scene["player_collision_cooldown"] = max(
		0.0,
		float(scene.get("player_collision_cooldown", 0.0)) - fps_scale
	)
	scene["boss_collision_cooldown"] = max(
		0.0,
		float(scene.get("boss_collision_cooldown", 0.0)) - fps_scale
	)


func apply_impact_decay(scene: Dictionary, fps_scale: float, deps: Dictionary) -> void:
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics == null:
		return
	scene["ball_impact_boost"] = ball_physics.apply_impact_decay(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		float(scene.get("ball_impact_boost", 1.0)),
		float(scene.get("ball_min_boost", 0.70)),
		float(scene.get("ball_boost_decay_rate", 0.975)),
		fps_scale
	)


func apply_ball_spin(scene: Dictionary, fps_scale: float, deps: Dictionary) -> void:
	var ball_spin_state: Object = deps.get("ball_spin_state", null)
	if ball_spin_state == null:
		return
	var result: Dictionary = ball_spin_state.apply_spin(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		float(scene.get("ball_spin_strength", 0.0)),
		int(scene.get("ball_spin_direction", 0)),
		fps_scale,
		bool(scene.get("drive_ball_active", false))
	)
	scene.merge(result, true)


func apply_power_motion(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var controller: Object = deps.get("power_motion_controller", null)
	if controller == null:
		return
	var result: Dictionary = controller.apply_motion(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		fps_scale,
		{
			"scene": scene,
			"gravity_effect": float(context.get("power_smash_gravity_effect", 0.0)),
			"boost_duration": float(context.get("power_smash_boost_duration", 0.0)),
			"current_msec": int(context.get("current_msec", Time.get_ticks_msec())),
			"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		},
		deps
	)
	scene.merge(result, true)


func apply_viper_chaos_spear(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "viper":
		return
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null:
		return
	if viper_skill_runtime.has_method("needs_ball_motion_update") and not bool(viper_skill_runtime.needs_ball_motion_update()):
		return
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	if viper_skill_runtime.has_method("apply_shadow_step_ball_motion"):
		_apply_viper_motion_result(
			scene,
			viper_skill_runtime.apply_shadow_step_ball_motion(fps_scale, scene, motion_context, deps)
		)
		motion_context.merge(scene, true)
	if viper_skill_runtime.has_method("apply_blade_rush_ball_motion"):
		_apply_viper_motion_result(
			scene,
			viper_skill_runtime.apply_blade_rush_ball_motion(fps_scale, scene, motion_context, deps)
		)
		motion_context.merge(scene, true)
	if viper_skill_runtime.has_method("apply_emp_strike_ball_motion"):
		_apply_viper_motion_result(
			scene,
			viper_skill_runtime.apply_emp_strike_ball_motion(fps_scale, scene, motion_context, deps)
		)
		motion_context.merge(scene, true)
	if not viper_skill_runtime.has_method("apply_chaos_spear_ball_motion"):
		return
	var result: Dictionary = viper_skill_runtime.apply_chaos_spear_ball_motion(fps_scale, scene, motion_context, deps)
	_apply_viper_motion_result(scene, result)


# 바이퍼 연습모드(테스트리그 튜토리얼)의 정지공 소유형 홀드. 바이퍼 스킬 모션 패스
# 직후·skip 단축 평가 전에 호출해야 한다: 홀드 중에도 쉐도우 웨이브/홀로그램이 공을
# 때릴 수 있고, 히트 프레임에는 연습모드가 라이브 래치를 관찰해 같은 프레임에 skip 을
# 내려(발사 속도 보존) 공이 즉시 날아간다. docs/viper_practice_mode_slice_plan.md S2.
func apply_viper_practice_hold(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "viper":
		return
	var practice: Object = deps.get("viper_practice_mode", null)
	if practice == null or not practice.has_method("apply_ball_hold_motion"):
		return
	if practice.has_method("is_active") and not bool(practice.is_active()):
		return
	_apply_viper_motion_result(
		scene,
		practice.apply_ball_hold_motion(scene, deps.get("viper_skill_runtime", null))
	)


# 허공환영 발동 직후 1초 차지는 같은 owned-ball skip 계약을 쓴다. 위치·속도·
# skip을 scene snapshot에 함께 써야 원래 속도나 과거 skip 값이 되살아나지 않는다.
func apply_smasher_void_phantom_charge(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary
) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var state: Object = deps.get("smasher_void_phantom_state", null)
	if state == null or not state.has_method("apply_charge_ball_motion"):
		return
	if state.has_method("is_charging") and not bool(state.is_charging()):
		return
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	var charge_scale: float = 0.0 if _is_active_item_time_frozen(deps) else fps_scale
	_apply_viper_motion_result(
		scene,
		state.apply_charge_ball_motion(charge_scale, motion_context, deps)
	)


func _apply_viper_motion_result(scene: Dictionary, result: Dictionary) -> void:
	if result.has("ball_pos"):
		scene["ball_pos"] = _get_vector2(result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("skip_ball_motion_step"):
		scene["skip_ball_motion_step"] = bool(result.get("skip_ball_motion_step", false))
	if result.has("player_collision_cooldown"):
		scene["player_collision_cooldown"] = float(result.get("player_collision_cooldown", scene.get("player_collision_cooldown", 0.0)))
	if result.has("ball_impact_boost"):
		scene["ball_impact_boost"] = float(result.get("ball_impact_boost", scene.get("ball_impact_boost", 1.0)))
	if result.has("runtime_perk_gold"):
		scene["runtime_perk_gold"] = int(result.get("runtime_perk_gold", 0))
	if result.has("skill_gold_award"):
		scene["skill_gold_award"] = int(result.get("skill_gold_award", 0))


func apply_stage1_dalji_whip(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state == null or not whip_state.has_method("update_ball_motion"):
		return
	var power_state: Object = deps.get("power_state", null)
	var power_motion_locked: bool = false
	if power_state != null:
		power_motion_locked = bool(power_state.is_freeze_active()) or bool(power_state.is_parabola_active())
	var result: Dictionary = whip_state.update_ball_motion(
		fps_scale,
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		context,
		power_motion_locked
	)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("ball_impact_boost"):
		scene["ball_impact_boost"] = float(result["ball_impact_boost"])
	if result.has("ball_boost_decay_rate"):
		scene["ball_boost_decay_rate"] = float(result["ball_boost_decay_rate"])
	if result.has("ball_min_boost"):
		scene["ball_min_boost"] = float(result["ball_min_boost"])
	if bool(result.get("stage1_dalji_whip_controls_speed", false)):
		scene["stage1_dalji_whip_controls_speed"] = true


func apply_stage1_dalji_spinning_top(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var spinning_top_state: Object = deps.get("stage1_dalji_spinning_top_skill_state", null)
	if spinning_top_state == null or not spinning_top_state.has_method("update_and_collide"):
		return
	var result: Dictionary = spinning_top_state.update_and_collide(fps_scale, scene, context, deps)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("ball_impact_boost"):
		scene["ball_impact_boost"] = float(result["ball_impact_boost"])
	if result.has("ball_boost_decay_rate"):
		scene["ball_boost_decay_rate"] = float(result["ball_boost_decay_rate"])
	if result.has("ball_min_boost"):
		scene["ball_min_boost"] = float(result["ball_min_boost"])


func apply_stage1_gaksital_fan_throw(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var fan_throw_state: Object = deps.get("stage1_gaksital_fan_throw_skill_state", null)
	if fan_throw_state == null or not fan_throw_state.has_method("update_and_collide"):
		return
	var result: Dictionary = fan_throw_state.update_and_collide(fps_scale, scene, context, deps)
	if bool(result.get("stage1_gaksital_fan_throw_hit", false)):
		scene["stage1_gaksital_fan_throw_hit"] = true
	if bool(result.get("stage1_gaksital_fan_throw_smoke_blocked", false)):
		scene["stage1_gaksital_fan_throw_smoke_blocked"] = true
	if result.has("stage1_gaksital_fan_throw_player_knockback_vel"):
		scene["stage1_gaksital_fan_throw_player_knockback_vel"] = float(result.get("stage1_gaksital_fan_throw_player_knockback_vel", 0.0))


func apply_stage1_gaksital_fan_wind(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var fan_wind_state: Object = deps.get("stage1_gaksital_fan_wind_skill_state", null)
	if fan_wind_state == null or not fan_wind_state.has_method("update_and_collide"):
		return
	var result: Dictionary = fan_wind_state.update_and_collide(fps_scale, scene, context, deps)
	if result.has("ball_pos"):
		scene["ball_pos"] = _get_vector2(result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("skip_ball_motion_step"):
		scene["skip_ball_motion_step"] = bool(result.get("skip_ball_motion_step", false))
	if result.has("stage1_gaksital_fan_wind_captured"):
		scene["stage1_gaksital_fan_wind_captured"] = bool(result.get("stage1_gaksital_fan_wind_captured", false))
	if bool(result.get("stage1_gaksital_fan_wind_released", false)):
		scene["stage1_gaksital_fan_wind_released"] = true
	if bool(result.get("stage1_gaksital_fan_wind_expired_release", false)):
		scene["stage1_gaksital_fan_wind_expired_release"] = true


func apply_stage1_pododaejang_patrol_guards(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary
) -> void:
	var patrol_guards_state: Object = deps.get("stage1_pododaejang_patrol_guards_skill_state", null)
	if patrol_guards_state == null or not patrol_guards_state.has_method("update_and_collide"):
		return
	var result: Dictionary = patrol_guards_state.update_and_collide(fps_scale, scene, context, deps)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if bool(result.get("stage1_pododaejang_patrol_guard_hit", false)):
		scene["stage1_pododaejang_patrol_guard_hit"] = true


func apply_magnum_grip(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if magnum_state == null or not magnum_state.has_method("apply_ball_motion"):
		return
	var power_state: Object = deps.get("power_state", null)
	var power_motion_locked: bool = false
	if power_state != null:
		power_motion_locked = bool(power_state.is_freeze_active()) or bool(power_state.is_parabola_active())
	if magnum_state.has_method("is_active") and not bool(magnum_state.is_active()):
		return
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	var result: Dictionary = magnum_state.apply_ball_motion(
		fps_scale,
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		motion_context,
		power_motion_locked
	)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))


func apply_dash_spirit_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var dash_spirit_state: Object = deps.get("smasher_dash_spirit_state", null)
	if dash_spirit_state == null or not dash_spirit_state.has_method("resolve_ball_collision"):
		return
	var result: Dictionary = dash_spirit_state.resolve_ball_collision(scene, context, deps)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))


func apply_smasher_wheel_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var wheel_state: Object = deps.get("smasher_wheel_state", null)
	if wheel_state == null or not wheel_state.has_method("resolve_ball_collision"):
		return
	var wheel_context: Dictionary = context.duplicate()
	wheel_context.merge(scene, true)
	var result: Dictionary = wheel_state.resolve_ball_collision(scene, wheel_context, deps)
	if result.is_empty():
		return
	for key in result.keys():
		scene[str(key)] = result[key]


# 풍운천선무 회선반동 조향. 벽력유성과 같은 "프레임별 속도 조향" 계약이라
# step_motion 앞에서 돌고, 공을 소유하지 않는다(skip_ball_motion_step 미사용).
# ⚠️가장 싼 판별 게이트(is_rebound_active)를 컨텍스트 조립 위로 끌어올린다 —
# 회선은 라운드당 최대 한 번인데 이 함수는 매 프레임 불린다.
func apply_smasher_wheel_rebound(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var wheel_state: Object = deps.get("smasher_wheel_state", null)
	if wheel_state == null or not wheel_state.has_method("apply_rebound_ball_motion"):
		return
	if not wheel_state.has_method("is_rebound_active") or not bool(wheel_state.is_rebound_active()):
		return
	var result: Dictionary = wheel_state.apply_rebound_ball_motion(
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		fps_scale,
		{
			"ball_impact_boost": float(scene.get("ball_impact_boost", 1.0)),
			"width": float(context.get("width", 760.0)),
			"height": float(context.get("height", 750.0)),
		}
	)
	if result.is_empty():
		return
	scene.merge(result, true)


func apply_smasher_overdrive(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary
) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var state: Object = deps.get("smasher_overdrive_state", null)
	if state == null or not state.has_method("apply_ball_motion"):
		return
	# 급전 타이밍은 "보스 라인까지 남은 비행 프레임"으로 판정하므로 보스 지오메트리가
	# 필요하다. context 는 step_motion 이 쓰는 것과 같은 frame_context 라
	# boss_pos / boss_paddle_size / hitbox_padding / ball_size 를 모두 들고 있다.
	var motion_context: Dictionary = {
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0)),
		"hitbox_padding": float(context.get("hitbox_padding", 5.0)),
		"ball_size": float(context.get("ball_size", 28.6)),
		"width": float(context.get("width", 760.0)),
		"ball_pos": _get_vector2(scene, "ball_pos", Vector2.ZERO),
		# 유성 예고는 꺾임 지점을 앞당겨 적분한다 — 실전 변위가
		# ball_vel * boost * fps_scale 이므로 틱 스케일이 없으면 타점이 어긋난다.
		"fps_scale": fps_scale,
	}
	var result: Dictionary = state.apply_ball_motion(
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		max(0.001, float(scene.get("ball_impact_boost", 1.0))),
		motion_context
	)
	if not result.is_empty():
		scene.merge(result, true)


func apply_shield_kiting_collision(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var shield_kiting_state: Object = deps.get("smasher_shield_kiting_state", null)
	if shield_kiting_state == null or not shield_kiting_state.has_method("update_and_collide"):
		return
	var result: Dictionary = shield_kiting_state.update_and_collide(fps_scale, scene, context, deps)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("runtime_perk_gold"):
		scene["runtime_perk_gold"] = int(result.get("runtime_perk_gold", 0))


func apply_laurel_leaf_shield_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var laurel_leaf_shield_state: Object = deps.get("laurel_leaf_shield_state", null)
	if laurel_leaf_shield_state == null or not laurel_leaf_shield_state.has_method("resolve_ball_collision"):
		return
	var result: Dictionary = laurel_leaf_shield_state.resolve_ball_collision(scene, context, deps)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))


func apply_active_item_magnet_field(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null or not active_item_runtime.has_method("apply_magnet_field_ball_pull"):
		return
	if active_item_runtime.has_method("is_magnet_field_active") and not bool(active_item_runtime.is_magnet_field_active()):
		return

	var last_hit_by := ""
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null and ball_intensity.has_method("get_last_hit_by"):
		last_hit_by = str(ball_intensity.get_last_hit_by())
	if last_hit_by != "boss":
		return

	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	motion_context["last_hit_by"] = last_hit_by
	var result: Dictionary = active_item_runtime.apply_magnet_field_ball_pull(fps_scale, motion_context)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))


func apply_smasher_void_phantom_decoys(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var state: Object = deps.get("smasher_void_phantom_state", null)
	if state == null or not state.has_method("apply_ball_path_tick"):
		return
	if state.has_method("is_active") and not bool(state.is_active()):
		return
	# 스톱워치 시간정지 중에는 환영도 멈춘다(구 홀로그램 계약 유지) — 실제 공이
	# 멈춰 있는데 환영만 날아가면 기만이 곧바로 들통난다.
	if _is_active_item_time_frozen(deps):
		return
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	state.apply_ball_path_tick(fps_scale, motion_context, deps)


func _is_active_item_time_frozen(deps: Dictionary) -> bool:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null:
		return false
	var effect_controller: Variant = active_item_runtime.get("effect_controller")
	if typeof(effect_controller) != TYPE_OBJECT or not is_instance_valid(effect_controller):
		return false
	var controller: Object = effect_controller
	return controller.has_method("is_time_frozen") and bool(controller.is_time_frozen())


func apply_poseidon_trident(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("apply_poseidon_wave_to_ball"):
		return
	if mythic_item_runtime.has_method("is_poseidon_ball_motion_active") and not bool(mythic_item_runtime.is_poseidon_ball_motion_active()):
		return
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	var result: Dictionary = mythic_item_runtime.apply_poseidon_wave_to_ball(scene, fps_scale, motion_context, deps)
	if result.has("ball_pos"):
		scene["ball_pos"] = _get_vector2(result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("skip_ball_motion_step"):
		scene["skip_ball_motion_step"] = bool(result.get("skip_ball_motion_step", false))
	if result.has("ball_impact_boost"):
		scene["ball_impact_boost"] = max(
			float(scene.get("ball_impact_boost", 1.0)),
			float(result.get("ball_impact_boost", scene.get("ball_impact_boost", 1.0)))
		)


func apply_weather_motion(scene: Dictionary, fps_scale: float, deps: Dictionary) -> void:
	var weather: Object = deps.get("weather_event_state", null)
	if weather != null and weather.has_method("apply_ball_weather_motion"):
		weather.apply_ball_weather_motion(scene, fps_scale)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _get_magnum_grip_speed_cap(deps: Dictionary) -> float:
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if magnum_state == null:
		return 0.0
	var cap := 0.0
	if magnum_state.has_method("get_release_hit_speed_cap"):
		cap = max(cap, float(magnum_state.get_release_hit_speed_cap()))
	if magnum_state.has_method("get_pending_release_hit_speed_cap"):
		cap = max(cap, float(magnum_state.get_pending_release_hit_speed_cap()))
	return cap


func _get_smasher_overdrive_speed_cap(deps: Dictionary) -> float:
	var state: Object = deps.get("smasher_overdrive_state", null)
	if state == null or not state.has_method("get_speed_cap"):
		return 0.0
	return float(state.get_speed_cap())


func _get_viper_blade_speed_cap(deps: Dictionary) -> float:
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("get_blade_hit_speed_cap"):
		return 0.0
	return float(viper_skill_runtime.get_blade_hit_speed_cap())


func _get_ragnarok_speed_cap(scene: Dictionary, deps: Dictionary) -> float:
	# Ragnarok Hammer raises the current league cap by a fixed +6 while its
	# charged stun ball is in flight (it no longer disables the cap entirely).
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("get_ragnarok_speed_cap_bonus"):
		return 0.0
	var bonus: float = float(mythic_item_runtime.get_ragnarok_speed_cap_bonus())
	if bonus <= 0.0:
		return 0.0
	return float(scene.get("max_ball_speed", 26.0)) + bonus
