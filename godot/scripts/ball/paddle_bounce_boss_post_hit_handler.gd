extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")

const BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES := ActiveItemThrowController.DYNAMITE_BOSS_KNOCKBACK_FRAMES
const BOWLING_TRAP_GUARD_KNOCKBACK_DECAY := ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY

# Python parity (pingfighter.py 174199 / BOSS_COLLISION_COOLDOWN_FRAMES = 10):
# every boss paddle hit re-arms the boss collision cooldown so the ball cannot
# re-collide with the boss rect on the very next frames. Without it a
# displaced boss (lingpet puppet grab kiss point sits just above the player
# band) ping-pongs the ball boss<->player every couple of frames.
const BOSS_COLLISION_COOLDOWN_FRAMES := 10.0


func apply(
	ball_pos: Vector2,
	ball_vel: Vector2,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	was_power_smashing: bool,
	context: Dictionary,
	deps: Dictionary,
	event_router: Object
) -> Dictionary:
	var next_ball_pos: Vector2 = _snap_boss_hit_ball_pos(ball_pos, context)
	var next_ball_vel: Vector2 = ball_vel
	var next_spin_strength: float = ball_spin_strength
	var next_drive_speed_increase: float = drive_speed_increase
	var next_drive_hit_boss: bool = drive_hit_boss
	var power_state: Object = deps.get("power_state", null)

	if event_router != null:
		var counter_result: Dictionary = event_router.apply_drive_boss_counter(
			next_ball_vel,
			next_spin_strength,
			next_drive_speed_increase,
			drive_ball_active,
			next_drive_hit_boss,
			deps
		)
		next_ball_vel = _get_vector2(counter_result, "ball_vel", next_ball_vel)
		next_spin_strength = float(counter_result.get("ball_spin_strength", next_spin_strength))
		next_drive_speed_increase = float(counter_result.get("drive_speed_increase", next_drive_speed_increase))
		next_drive_hit_boss = bool(counter_result.get("drive_hit_boss", next_drive_hit_boss))
		if was_power_smashing:
			next_ball_vel = event_router.end_power_smashing_on_boss_counter(next_ball_vel, power_state, deps, next_ball_pos, context)
		event_router.trigger_boss_hit_anim(float(context.get("boss_vel", 0.0)), context, deps)

	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	var whip_result: Dictionary = {}
	if whip_state != null and whip_state.has_method("register_boss_hit"):
		whip_result = whip_state.register_boss_hit(next_ball_vel, context, deps)
		next_ball_vel = _get_vector2(whip_result, "ball_vel", next_ball_vel)

	var fan_wind_state: Object = deps.get("stage1_gaksital_fan_wind_skill_state", null)
	if fan_wind_state != null and fan_wind_state.has_method("try_consume_boss_hit"):
		fan_wind_state.try_consume_boss_hit(context, deps)

	var arrest_rope_state: Object = deps.get("stage1_pododaejang_arrest_rope_skill_state", null)
	if arrest_rope_state != null and arrest_rope_state.has_method("register_boss_hit"):
		arrest_rope_state.register_boss_hit(context, deps)

	var stage2_result: Dictionary = {}
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	if stage2_skill_state != null and stage2_skill_state.has_method("register_boss_hit"):
		stage2_result = stage2_skill_state.register_boss_hit(next_ball_vel, context, deps)
		next_ball_vel = _get_vector2(stage2_result, "ball_vel", next_ball_vel)
		next_spin_strength = float(stage2_result.get("ball_spin_strength", next_spin_strength))

	var stage3_skill_state: Object = deps.get("stage3_boss_skill_state", null)
	if stage3_skill_state != null and stage3_skill_state.has_method("register_boss_hit"):
		stage3_skill_state.register_boss_hit(next_ball_vel, context, deps)

	var stage4_ponk_skill_state: Object = deps.get("stage4_ponk_skill_state", null)
	if stage4_ponk_skill_state != null and stage4_ponk_skill_state.has_method("register_boss_hit"):
		stage4_ponk_skill_state.register_boss_hit(next_ball_vel, context, deps)

	var stage5_hongryun_result: Dictionary = {}
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	if (
		int(context.get("current_stage", 1)) == 5
		and stage5_hongryun_state != null
		and stage5_hongryun_state.has_method("register_boss_paddle_contact")
	):
		var stage5_hongryun_context: Dictionary = context.duplicate()
		stage5_hongryun_context["ball_pos"] = next_ball_pos
		stage5_hongryun_context["ball_vel"] = next_ball_vel
		stage5_hongryun_result = stage5_hongryun_state.register_boss_paddle_contact(
			next_ball_vel,
			deps,
			stage5_hongryun_context
		)

	var boss_vel_override: float = float(context.get("boss_vel", 0.0))
	var speed_limit_disabled_override: Variant = null
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	var phantom_speed_limit_was_disabled := false
	if viper_skill_runtime != null and viper_skill_runtime.has_method("is_phantom_kick_speed_limit_disabled"):
		phantom_speed_limit_was_disabled = bool(viper_skill_runtime.is_phantom_kick_speed_limit_disabled())
	if viper_skill_runtime != null and viper_skill_runtime.has_method("consume_phantom_kick_knockback"):
		var phantom_result: Dictionary = viper_skill_runtime.consume_phantom_kick_knockback(
			next_ball_pos,
			BallContextReader.get_vector2(context, "boss_pos", Vector2.ZERO),
			float(context.get("boss_paddle_width", 100.0)),
			deps
		)
		if phantom_result.has("boss_vel"):
			boss_vel_override = float(phantom_result.get("boss_vel", boss_vel_override))
	var kick_skill_knockback_consumed := false
	if viper_skill_runtime != null and viper_skill_runtime.has_method("consume_kick_skill_knockback"):
		var kick_knockback_result: Dictionary = viper_skill_runtime.consume_kick_skill_knockback(
			next_ball_pos,
			BallContextReader.get_vector2(context, "boss_pos", Vector2.ZERO),
			float(context.get("boss_paddle_width", 100.0)),
			context,
			deps
		)
		if kick_knockback_result.has("boss_vel"):
			boss_vel_override = float(kick_knockback_result.get("boss_vel", boss_vel_override))
		kick_skill_knockback_consumed = bool(kick_knockback_result.get("kick_skill_knockback_consumed", false))
	if viper_skill_runtime != null and viper_skill_runtime.has_method("consume_kick_guard_speed_reduction"):
		var kick_speed_result: Dictionary = viper_skill_runtime.consume_kick_guard_speed_reduction(
			next_ball_vel,
			context,
			deps
		)
		next_ball_vel = _get_vector2(kick_speed_result, "ball_vel", next_ball_vel)

	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("consume_venom_mist_ball_poison"):
		mythic_item_runtime.consume_venom_mist_ball_poison(
			_get_boss_center(context),
			deps
		)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_ragnarok_boss_hit"):
		var ragnarok_result: Dictionary = mythic_item_runtime.apply_ragnarok_boss_hit(
			next_ball_vel,
			context,
			deps
		)
		next_ball_vel = _get_vector2(ragnarok_result, "ball_vel", next_ball_vel)
		if ragnarok_result.has("speed_limit_disabled"):
			speed_limit_disabled_override = bool(ragnarok_result.get("speed_limit_disabled", false))
	if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_poseidon_boss_hit"):
		var poseidon_result: Dictionary = mythic_item_runtime.apply_poseidon_boss_hit(next_ball_vel)
		next_ball_vel = _get_vector2(poseidon_result, "ball_vel", next_ball_vel)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_baal_boots_boss_hit"):
		var baal_boss_result: Dictionary = mythic_item_runtime.apply_baal_boots_boss_hit(
			next_ball_vel,
			context,
			deps
		)
		next_ball_vel = _get_vector2(baal_boss_result, "ball_vel", next_ball_vel)
		if baal_boss_result.has("boss_vel"):
			boss_vel_override = float(baal_boss_result.get("boss_vel", boss_vel_override))
	var horn_strawberry_result: Dictionary = {}
	if mythic_item_runtime != null and mythic_item_runtime.has_method("consume_horn_strawberry_strong_boss_hit"):
		horn_strawberry_result = mythic_item_runtime.consume_horn_strawberry_strong_boss_hit(
			next_ball_pos,
			next_ball_vel,
			context,
			deps
		)
		if horn_strawberry_result.has("boss_vel"):
			boss_vel_override = float(horn_strawberry_result.get("boss_vel", boss_vel_override))

	var bowling_guard_result: Dictionary = _consume_commando_bowling_trap_guard_hit(
		next_ball_pos,
		next_ball_vel,
		context,
		deps
	)
	if not bowling_guard_result.is_empty():
		next_ball_vel = _get_vector2(bowling_guard_result, "ball_vel", next_ball_vel)
		if bowling_guard_result.has("boss_vel"):
			boss_vel_override = float(bowling_guard_result.get("boss_vel", boss_vel_override))

	var suicide_drone_boost_result: Dictionary = _consume_commando_suicide_drone_ball_boost(
		next_ball_vel,
		context
	)
	if not suicide_drone_boost_result.is_empty():
		next_ball_vel = _get_vector2(suicide_drone_boost_result, "ball_vel", next_ball_vel)

	var wild_roar_boost_result: Dictionary = _consume_lingpet_wild_roar_ball_boost(
		next_ball_vel,
		context
	)
	if not wild_roar_boost_result.is_empty():
		next_ball_vel = _get_vector2(wild_roar_boost_result, "ball_vel", next_ball_vel)

	var result := {
		"ball_pos": next_ball_pos,
		"ball_vel": next_ball_vel,
		"ball_spin_strength": next_spin_strength,
		"drive_speed_increase": next_drive_speed_increase,
		"drive_hit_boss": next_drive_hit_boss,
		"boss_vel": boss_vel_override,
		"boss_collision_cooldown": BOSS_COLLISION_COOLDOWN_FRAMES,
	}
	if stage2_result.has("ball_spin_direction"):
		result["ball_spin_direction"] = int(stage2_result.get("ball_spin_direction", 0))
	if kick_skill_knockback_consumed:
		result["kick_skill_knockback_consumed"] = true
	if phantom_speed_limit_was_disabled:
		result["speed_limit_disabled"] = false
	elif speed_limit_disabled_override != null:
		result["speed_limit_disabled"] = bool(speed_limit_disabled_override)
	if viper_skill_runtime != null and viper_skill_runtime.has_method("is_kick_skill_knockback_ball_active"):
		result["viper_knockback_overlay_active"] = bool(viper_skill_runtime.is_kick_skill_knockback_ball_active())
	elif context.has("viper_knockback_overlay_active"):
		result["viper_knockback_overlay_active"] = bool(context.get("viper_knockback_overlay_active", false))
	if whip_result.has("ball_impact_boost"):
		result["ball_impact_boost"] = float(whip_result["ball_impact_boost"])
	if whip_result.has("ball_boost_decay_rate"):
		result["ball_boost_decay_rate"] = float(whip_result["ball_boost_decay_rate"])
	if whip_result.has("ball_min_boost"):
		result["ball_min_boost"] = float(whip_result["ball_min_boost"])
	if not bowling_guard_result.is_empty():
		for key in bowling_guard_result.keys():
			if key != "ball_vel" and key != "boss_vel":
				result[key] = bowling_guard_result[key]
	if not horn_strawberry_result.is_empty():
		for key in horn_strawberry_result.keys():
			if key != "boss_vel":
				result[key] = horn_strawberry_result[key]
	if not suicide_drone_boost_result.is_empty():
		for key in suicide_drone_boost_result.keys():
			if key != "ball_vel":
				result[key] = suicide_drone_boost_result[key]
	if not wild_roar_boost_result.is_empty():
		for key in wild_roar_boost_result.keys():
			if key != "ball_vel":
				result[key] = wild_roar_boost_result[key]
	if not stage5_hongryun_result.is_empty():
		result.merge(stage5_hongryun_result, true)
	return result


func _snap_boss_hit_ball_pos(ball_pos: Vector2, context: Dictionary) -> Vector2:
	# Anchor to the LIVE boss paddle top, not the static `boss_y` constant: a
	# boss-scripting skill (lingpet puppet grab) can hold the boss mid-field,
	# and the static anchor teleported the ball back to the top on contact.
	var boss_top: float = BallContextReader.get_vector2(
		context,
		"boss_pos",
		Vector2(0.0, float(context.get("boss_y", ball_pos.y)))
	).y
	ball_pos.y = (
		boss_top
		+ float(context.get("boss_hitbox_height", 0.0))
		+ float(context.get("ball_size", 0.0))
	)
	return ball_pos


func _get_boss_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = BallContextReader.get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_size: Vector2 = BallContextReader.get_vector2(context, "boss_paddle_size", Vector2.ZERO)
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _consume_commando_bowling_trap_guard_hit(
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var commando_firearm_runtime: Object = deps.get("commando_firearm_runtime", null)
	if commando_firearm_runtime != null and commando_firearm_runtime.has_method("consume_bowling_trap_boss_guard"):
		var runtime_result: Dictionary = commando_firearm_runtime.consume_bowling_trap_boss_guard(
			ball_vel,
			context,
			deps
		)
		if not runtime_result.is_empty():
			return runtime_result

	if not bool(context.get("commando_bowling_trap_guard_armed", false)):
		return {}
	if _is_boss_status_immune(context, deps):
		return _build_bowling_guard_clear_result(ball_vel, 0.0, false, true)
	var knockback_power: float = max(0.0, float(context.get("commando_bowling_trap_guard_knockback_power", 0.0)))
	var stun_frames: float = max(0.0, float(context.get("commando_bowling_trap_guard_stun_frames", 0.0)))
	if knockback_power <= 0.0 and stun_frames <= 0.0:
		return _build_bowling_guard_clear_result(ball_vel)
	var knockback_vel: float = _get_bowling_guard_knockback_velocity(ball_pos, ball_vel, context, knockback_power)
	var status_state: Object = deps.get("status_effect_state", null)
	var applied_status := false
	if status_state != null and status_state.has_method("apply_status") and stun_frames > 0.0:
		status_state.apply_status(
			"boss",
			"stun",
			stun_frames,
			{
				"knockback_vel": knockback_vel,
				"knockback_active": abs(knockback_vel) > 0.001,
				"knockback_frames": BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
				"knockback_decay_per_frame": BOWLING_TRAP_GUARD_KNOCKBACK_DECAY,
				"knockback_stop_threshold": 0.3,
				"suppress_stun_stars": false,
			},
			str(context.get("commando_bowling_trap_guard_source", "commando_bowling_trap_guard"))
		)
		applied_status = true
	var ai_state: Object = deps.get("ai_state", null)
	if not applied_status and ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(
			knockback_vel,
			min(stun_frames, BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES),
			BOWLING_TRAP_GUARD_KNOCKBACK_DECAY,
			true
		)
	return _build_bowling_guard_clear_result(
		_get_bowling_guard_restored_ball_velocity(ball_vel, context),
		knockback_vel,
		true
	)


func _get_bowling_guard_knockback_velocity(
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	knockback_power: float
) -> float:
	var boss_pos: Vector2 = BallContextReader.get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_width: float = max(1.0, float(context.get("boss_paddle_width", 100.0)))
	var boss_center_x: float = boss_pos.x + boss_width * 0.5
	var direction: float = 1.0 if ball_pos.x >= boss_center_x else -1.0
	if abs(ball_pos.x - boss_center_x) <= 0.01 and abs(ball_vel.x) > 0.01:
		direction = sign(ball_vel.x)
	return direction * knockback_power


func _get_bowling_guard_restored_ball_velocity(ball_vel: Vector2, context: Dictionary) -> Vector2:
	var restore_speed: float = max(0.0, float(context.get("commando_bowling_trap_guard_restore_speed", 0.0)))
	if restore_speed <= 0.0 or ball_vel.length() <= 0.0:
		return ball_vel
	return ball_vel.normalized() * restore_speed


func _build_bowling_guard_clear_result(
	ball_vel: Vector2,
	boss_vel: float = 0.0,
	hit: bool = false,
	immune: bool = false
) -> Dictionary:
	var result := {
		"ball_vel": ball_vel,
		"commando_bowling_trap_guard_consumed": true,
		"commando_bowling_trap_guarded": hit,
		"commando_bowling_trap_guard_hit": hit,
		"boss_status_immune": immune,
		"commando_bowling_trap_guard_armed": false,
		"commando_bowling_trap_guard_source": "",
		"commando_bowling_trap_guard_knockback_power": 0.0,
		"commando_bowling_trap_guard_stun_frames": 0.0,
		"commando_bowling_trap_guard_restore_speed": 0.0,
	}
	if hit:
		result["boss_vel"] = boss_vel
	return result


func _consume_commando_suicide_drone_ball_boost(ball_vel: Vector2, context: Dictionary) -> Dictionary:
	if not bool(context.get("commando_suicide_drone_ball_boost_active", false)):
		return {}
	var restore_speed: float = max(0.0, float(context.get("commando_suicide_drone_ball_restore_speed", 0.0)))
	var next_ball_vel: Vector2 = ball_vel
	if restore_speed > 0.0 and ball_vel.length() > 0.001:
		next_ball_vel = ball_vel.normalized() * restore_speed
	return {
		"ball_vel": next_ball_vel,
		"commando_suicide_drone_ball_boost_active": false,
		"commando_suicide_drone_ball_restore_speed": 0.0,
		"commando_suicide_drone_ball_boosted_speed": 0.0,
		"commando_suicide_drone_ball_boost_consumed": true,
		"commando_suicide_drone_ball_restored_speed": restore_speed,
		"commando_suicide_drone_speed_limit_disabled": false,
		"speed_limit_disabled": false,
	}


func _consume_lingpet_wild_roar_ball_boost(ball_vel: Vector2, context: Dictionary) -> Dictionary:
	if not bool(context.get("lingpet_wild_roar_ball_boost_active", false)):
		return {}
	var restore_speed: float = max(0.0, float(context.get("lingpet_wild_roar_ball_restore_speed", 0.0)))
	var next_ball_vel: Vector2 = ball_vel
	if restore_speed > 0.0 and ball_vel.length() > 0.001:
		next_ball_vel = ball_vel.normalized() * restore_speed
	return {
		"ball_vel": next_ball_vel,
		"lingpet_wild_roar_ball_boost_active": false,
		"lingpet_wild_roar_ball_restore_speed": 0.0,
		"lingpet_wild_roar_ball_boost_consumed": true,
		"lingpet_wild_roar_ball_restored_speed": restore_speed,
		"lingpet_wild_roar_speed_limit_disabled": false,
		"speed_limit_disabled": false,
	}


func _is_boss_status_immune(context: Dictionary, deps: Dictionary) -> bool:
	if int(context.get("current_stage", 0)) == 2:
		if (
			bool(context.get("stage2_speed_defense_status_immunity_active", false))
			or bool(context.get("stage2_speed_defense_active", false))
		):
			return true
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	)
