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


func apply_power_smash_speed_limit(scene: Dictionary, max_effective_speed: float) -> void:
	_limit_effective_speed(scene, max_effective_speed)


func apply_ball_speed_limits(scene: Dictionary, deps: Dictionary) -> void:
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics == null:
		return
	var velocity: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	if ball_physics.has_method("enforce_minimum_rally_speed"):
		velocity = ball_physics.enforce_minimum_rally_speed(velocity)
	var speed_unlimited: bool = _is_speed_limit_disabled(scene)
	var impact_boost: float = max(1.0, float(scene.get("ball_impact_boost", 1.0)))
	if ball_physics.has_method("get_minimum_effective_boost"):
		impact_boost = max(impact_boost, float(ball_physics.get_minimum_effective_boost(velocity)))
	if not speed_unlimited:
		velocity = _cap_effective_velocity(velocity, impact_boost, _get_effective_speed_cap(scene, impact_boost, deps))
	scene["ball_vel"] = velocity
	scene["ball_impact_boost"] = impact_boost


func _is_speed_limit_disabled(scene: Dictionary) -> bool:
	return (
		bool(scene.get("speed_limit_disabled", false))
		or bool(scene.get("commando_suicide_drone_ball_boost_active", false))
		or bool(scene.get("lingpet_wild_roar_ball_boost_active", false))
		or bool(scene.get("active_item_aipill_ball_boost_active", false))
	)


func _get_effective_speed_cap(scene: Dictionary, impact_boost: float, deps: Dictionary) -> float:
	var speed_cap: float = float(scene.get("max_ball_speed", 26.0))
	if impact_boost > 1.001:
		speed_cap = max(speed_cap, float(scene.get("impact_boost_max_ball_speed", 26.0)))
	var meditation_release_cap: float = float(scene.get("stage4_meditation_release_speed_cap", 0.0))
	if meditation_release_cap > 0.0:
		speed_cap = max(speed_cap, meditation_release_cap)
	speed_cap = max(speed_cap, float(scene.get("smasher_wheel_speed_cap", 0.0)))
	speed_cap = max(speed_cap, float(scene.get("trampoline_launch_speed_cap", 0.0)))
	speed_cap = max(speed_cap, _get_magnum_grip_speed_cap(deps))
	speed_cap = max(speed_cap, _get_viper_blade_speed_cap(deps))
	speed_cap = max(speed_cap, _get_ragnarok_speed_cap(scene, deps))
	if bool(scene.get("fire_weather_speed_cap_active", false)):
		speed_cap = min(speed_cap, float(scene.get("fire_weather_max_ball_speed", 35.0)))
	if meditation_release_cap > 0.0:
		speed_cap = min(speed_cap, meditation_release_cap)
	return speed_cap


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
