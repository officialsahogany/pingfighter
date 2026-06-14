extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const PaddleBouncePlayerPostHitHandler := preload("res://scripts/ball/paddle_bounce_player_post_hit_handler.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")

var boss_post_hit_handler: Object = PaddleBounceBossPostHitHandler.new()
var event_router: Object = PaddleBounceEventRouter.new()
var player_post_hit_handler: Object = PaddleBouncePlayerPostHitHandler.new()
var power_hit_handler: Object = PaddleBouncePowerHitHandler.new()


func apply(
	is_player: bool,
	ball_pos: Vector2,
	ball_vel: Vector2,
	hit_pos: float,
	paddle_w: float,
	power_activated: bool,
	was_power_smashing: bool,
	drive_activated: bool,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var perf_logger: Object = deps.get("perf_logger", null)
	var total_start: int = _perf_begin(perf_logger)
	var power_state: Object = deps.get("power_state", null)
	var physics: Object = deps.get("ball_physics", null)
	var power_hit_start: int = _perf_begin(perf_logger)
	ball_vel = power_hit_handler.apply(
		ball_pos,
		ball_vel,
		paddle_w,
		power_activated,
		power_state,
		physics,
		context
	)
	_perf_end(perf_logger, "paddle_bounce.post_hit.power_hit", power_hit_start)

	var player_speed: float = float(context.get("player_speed", 0.0))
	var boss_vel: float = float(context.get("boss_vel", 0.0))
	var whip_result: Dictionary = {}
	var wheel_result: Dictionary = {}
	var boss_result: Dictionary = {}
	var rainbow_glove_result: Dictionary = {}
	var shrapnel_armor_result: Dictionary = {}
	var blacksmith_shield_result: Dictionary = {}
	var runtime_perk_gold: int = -1
	var clear_smasher_wheel_speed_cap := false
	var speed_limit_disabled_override: Variant = null
	if is_player:
		var gauge_before_player_hit: float = special_gauge
		var player_start: int = _perf_begin(perf_logger)
		var player_result: Dictionary = player_post_hit_handler.apply(
			ball_pos,
			hit_pos,
			power_activated,
			drive_activated,
			special_gauge,
			context,
			deps,
			event_router
		)
		_perf_end(perf_logger, "paddle_bounce.post_hit.player", player_start)
		ball_pos = _get_vector2(player_result, "ball_pos", ball_pos)
		if power_state != null and power_state.has_method("trigger_ghost_possession_fly_back"):
			power_state.trigger_ghost_possession_fly_back(ball_pos)
		special_gauge = float(player_result.get("special_gauge", special_gauge))
		context["special_gauge"] = special_gauge
		player_speed = float(player_result.get("player_speed", player_speed))
		boss_vel = float(player_result.get("boss_vel", boss_vel))
		if bool(context.get("blacksmith_thor_shield_hit", false)):
			var blacksmith_shield_state: Object = deps.get("blacksmith_thor_shield_state", null)
			if blacksmith_shield_state != null and blacksmith_shield_state.has_method("notify_ball_hit"):
				var shield_context: Dictionary = context.duplicate()
				shield_context["ball_pos"] = ball_pos
				shield_context["blacksmith_umbrella_gauge_gain"] = float(context.get(
					"blacksmith_thor_shield_gauge_gain",
					context.get("blacksmith_umbrella_gauge_gain", 60.0)
				))
				blacksmith_shield_result = blacksmith_shield_state.notify_ball_hit(
					ball_pos,
					ball_vel,
					gauge_before_player_hit,
					special_gauge,
					shield_context,
					deps
				)
				if not blacksmith_shield_result.is_empty():
					special_gauge = float(blacksmith_shield_result.get("special_gauge", special_gauge))
					context["special_gauge"] = special_gauge
					if bool(blacksmith_shield_result.get("suppress_paddle_hit_knockback", false)):
						context["suppress_paddle_hit_knockback"] = true
					for pulse_key in ["paddle_hit_pulse_kind", "paddle_hit_pulse_intensity"]:
						if blacksmith_shield_result.has(pulse_key):
							context[pulse_key] = blacksmith_shield_result[pulse_key]
		var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
		if whip_state != null and whip_state.has_method("register_player_hit"):
			whip_result = whip_state.register_player_hit(ball_vel, context)
			ball_vel = _get_vector2(whip_result, "ball_vel", ball_vel)
		var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
		if cleanse_state != null and cleanse_state.has_method("apply_counter_speed_bonus"):
			ball_vel = cleanse_state.apply_counter_speed_bonus(ball_vel)
		var wheel_state: Object = deps.get("smasher_wheel_state", null)
		if (
			str(context.get("selected_character_type", "smasher")) == "smasher"
			and wheel_state != null
			and wheel_state.has_method("consume_ball_hit")
		):
			var wheel_context: Dictionary = context.duplicate()
			wheel_context["ball_pos"] = ball_pos
			wheel_result = wheel_state.consume_ball_hit(ball_pos, ball_vel, wheel_context, deps)
			if bool(wheel_result.get("smasher_wheel_hit", false)):
				ball_pos = _get_vector2(wheel_result, "ball_pos", ball_pos)
				ball_vel = _get_vector2(wheel_result, "ball_vel", ball_vel)
				ball_spin_strength = float(wheel_result.get("ball_spin_strength", ball_spin_strength))
				drive_speed_increase = float(wheel_result.get("drive_speed_increase", drive_speed_increase))
				drive_hit_boss = bool(wheel_result.get("drive_hit_boss", drive_hit_boss))
				runtime_perk_gold = int(wheel_result.get("runtime_perk_gold", runtime_perk_gold))
		var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
		var dual_glitch_clone_hit: bool = bool(context.get("viper_dual_glitch_clone_hit", false))
		if (
			dual_glitch_clone_hit
			and viper_skill_runtime != null
			and viper_skill_runtime.has_method("apply_dual_glitch_clone_ball_hit")
		):
			viper_skill_runtime.apply_dual_glitch_clone_ball_hit(context, deps)
		if (
			not dual_glitch_clone_hit
			and viper_skill_runtime != null
			and viper_skill_runtime.has_method("register_player_ball_contact")
		):
			viper_skill_runtime.register_player_ball_contact(deps, context)
		if (
			not dual_glitch_clone_hit
			and str(context.get("selected_character_type", "smasher")) == "viper"
			and viper_skill_runtime != null
			and viper_skill_runtime.has_method("apply_shadow_step_paddle_hit")
		):
			var shadow_context: Dictionary = context.duplicate()
			shadow_context["ball_pos"] = ball_pos
			var shadow_result: Dictionary = viper_skill_runtime.apply_shadow_step_paddle_hit(
				ball_vel,
				shadow_context,
				deps
			)
			if bool(shadow_result.get("hit", false)):
				ball_vel = _get_vector2(shadow_result, "ball_vel", ball_vel)
				if bool(shadow_result.get("suppress_base_gauge", false)):
					special_gauge = gauge_before_player_hit
					context["special_gauge"] = special_gauge
				if shadow_result.has("runtime_perk_gold"):
					runtime_perk_gold = int(shadow_result.get("runtime_perk_gold", 0))
		if was_power_smashing and not power_activated:
			_end_power_smashing_on_player_return(power_state, event_router)
		var viper_jetpack_state: Object = deps.get("viper_jetpack_state", null)
		if (
			not dual_glitch_clone_hit
			and str(context.get("selected_character_type", "smasher")) == "viper"
			and viper_jetpack_state != null
			and viper_jetpack_state.has_method("apply_air_strike_post_hit")
		):
			var jetpack_context: Dictionary = context.duplicate()
			jetpack_context["ball_pos"] = ball_pos
			var air_strike_start: int = _perf_begin(perf_logger)
			var jetpack_result: Dictionary = viper_jetpack_state.apply_air_strike_post_hit(
				ball_vel,
				gauge_before_player_hit,
				special_gauge,
				jetpack_context,
				deps
			)
			_perf_end(perf_logger, "paddle_bounce.post_hit.air_strike", air_strike_start)
			ball_vel = _get_vector2(jetpack_result, "ball_vel", ball_vel)
			special_gauge = float(jetpack_result.get("special_gauge", special_gauge))
			context["special_gauge"] = special_gauge
			for pulse_key in ["paddle_hit_pulse_kind", "paddle_hit_pulse_intensity"]:
				if jetpack_result.has(pulse_key):
					context[pulse_key] = jetpack_result[pulse_key]
			if jetpack_result.has("runtime_perk_gold"):
				runtime_perk_gold = int(jetpack_result.get("runtime_perk_gold", 0))
		var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
		if mythic_item_runtime != null and mythic_item_runtime.has_method("try_apply_ragnarok_player_hit"):
			var ragnarok_result: Dictionary = mythic_item_runtime.try_apply_ragnarok_player_hit(
				ball_vel,
				special_gauge,
				context,
				deps
			)
			ball_vel = _get_vector2(ragnarok_result, "ball_vel", ball_vel)
			special_gauge = float(ragnarok_result.get("special_gauge", special_gauge))
			context["special_gauge"] = special_gauge
			if ragnarok_result.has("speed_limit_disabled"):
				speed_limit_disabled_override = bool(ragnarok_result.get("speed_limit_disabled", false))
		if mythic_item_runtime != null and mythic_item_runtime.has_method("try_apply_knee_pads_player_hit"):
			var knee_pads_result: Dictionary = mythic_item_runtime.try_apply_knee_pads_player_hit(
				ball_pos,
				special_gauge,
				context,
				deps
			)
			special_gauge = float(knee_pads_result.get("special_gauge", special_gauge))
			context["special_gauge"] = special_gauge
		if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_baal_boots_player_hit"):
			var baal_player_result: Dictionary = mythic_item_runtime.apply_baal_boots_player_hit(
				ball_pos,
				ball_vel,
				context,
				deps
			)
			ball_vel = _get_vector2(baal_player_result, "ball_vel", ball_vel)
		if mythic_item_runtime != null and mythic_item_runtime.has_method("try_proc_shrapnel_armor_player_hit"):
			shrapnel_armor_result = mythic_item_runtime.try_proc_shrapnel_armor_player_hit(
				ball_pos,
				context,
				deps
			)
			if shrapnel_armor_result.has("special_gauge"):
				special_gauge = float(shrapnel_armor_result.get("special_gauge", special_gauge))
				context["special_gauge"] = special_gauge
		if mythic_item_runtime != null and mythic_item_runtime.has_method("try_proc_rainbow_fur_glove_player_hit"):
			rainbow_glove_result = mythic_item_runtime.try_proc_rainbow_fur_glove_player_hit(
				ball_pos,
				context,
				deps
			)
	else:
		clear_smasher_wheel_speed_cap = true
		var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
		if magnum_state != null and magnum_state.has_method("clear_release_hit_speed_cap"):
			magnum_state.clear_release_hit_speed_cap()
		var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
		if viper_skill_runtime != null and viper_skill_runtime.has_method("clear_blade_hit_speed_cap"):
			viper_skill_runtime.clear_blade_hit_speed_cap()
		var boss_start: int = _perf_begin(perf_logger)
		boss_result = boss_post_hit_handler.apply(
			ball_pos,
			ball_vel,
			ball_spin_strength,
			drive_speed_increase,
			drive_ball_active,
			drive_hit_boss,
			was_power_smashing,
			context,
			deps,
			event_router
		)
		_perf_end(perf_logger, "paddle_bounce.post_hit.boss", boss_start)
		ball_pos = _get_vector2(boss_result, "ball_pos", ball_pos)
		ball_vel = _get_vector2(boss_result, "ball_vel", ball_vel)
		ball_spin_strength = float(boss_result.get("ball_spin_strength", ball_spin_strength))
		drive_speed_increase = float(boss_result.get("drive_speed_increase", drive_speed_increase))
		drive_hit_boss = bool(boss_result.get("drive_hit_boss", drive_hit_boss))
		boss_vel = float(boss_result.get("boss_vel", boss_vel))
		# Ghost-smashing possession: the boss has returned Mika's ghost ball, but
		# she should remain hidden until that returned ball reaches the player
		# paddle. The player branch triggers the fly-back on the actual counter.
		if power_state != null and power_state.has_method("is_ghost_possession_active") and power_state.is_ghost_possession_active():
			if power_state.has_method("notify_ghost_possession_boss_returned"):
				power_state.notify_ghost_possession_boss_returned()
		if bool(boss_result.get("commando_bowling_trap_guard_hit", false)):
			context["suppress_paddle_hit_knockback"] = true
		if bool(boss_result.get("kick_skill_knockback_consumed", false)):
			context["suppress_paddle_hit_knockback"] = true
		if bool(boss_result.get("suppress_paddle_hit_knockback", false)):
			context["suppress_paddle_hit_knockback"] = true
		special_gauge = float(context.get("special_gauge", special_gauge))

	var fire_weather_hit_active := _is_fire_weather_active(deps)
	if fire_weather_hit_active:
		context["suppress_paddle_hit_knockback"] = true
	var rally_start: int = _perf_begin(perf_logger)
	var rally_result: Dictionary = event_router.register_rally_feedback(
		ball_pos,
		ball_vel,
		is_player,
		power_activated,
		deps,
		context,
		special_gauge,
		drive_activated
	)
	_perf_end(perf_logger, "paddle_bounce.post_hit.rally_feedback", rally_start)
	special_gauge = float(rally_result.get("special_gauge", special_gauge))
	context["special_gauge"] = special_gauge
	var fire_hit_result: Dictionary = _apply_fire_weather_paddle_hit_knockback(
		fire_weather_hit_active,
		is_player,
		ball_pos,
		context,
		deps
	)
	if fire_hit_result.has("boss_vel"):
		boss_vel = float(fire_hit_result.get("boss_vel", boss_vel))
	var result := {
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_spin_strength": ball_spin_strength,
		"drive_speed_increase": drive_speed_increase,
		"drive_hit_boss": drive_hit_boss,
		"special_gauge": special_gauge,
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}
	if whip_result.has("ball_impact_boost"):
		result["ball_impact_boost"] = float(whip_result["ball_impact_boost"])
	if whip_result.has("ball_boost_decay_rate"):
		result["ball_boost_decay_rate"] = float(whip_result["ball_boost_decay_rate"])
	if whip_result.has("ball_min_boost"):
		result["ball_min_boost"] = float(whip_result["ball_min_boost"])
	if not wheel_result.is_empty():
		for key in [
			"ball_spin_direction",
			"drive_ball_active",
			"player_collision_cooldown",
			"smasher_wheel_speed_cap",
			"smasher_wheel_hit",
		]:
			if wheel_result.has(key):
				result[key] = wheel_result[key]
	if clear_smasher_wheel_speed_cap:
		result["smasher_wheel_speed_cap"] = 0.0
	if boss_result.has("viper_knockback_overlay_active"):
		result["viper_knockback_overlay_active"] = bool(boss_result.get("viper_knockback_overlay_active", false))
	if boss_result.has("speed_limit_disabled"):
		result["speed_limit_disabled"] = bool(boss_result.get("speed_limit_disabled", false))
	elif speed_limit_disabled_override != null:
		result["speed_limit_disabled"] = bool(speed_limit_disabled_override)
	if not boss_result.is_empty():
		for key in [
			"boss_collision_cooldown",
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
			"horn_strawberry_horn_charge_hit",
			"horn_strawberry_horn_charge_consumed",
			"horn_strawberry_bomb_hit",
			"horn_strawberry_bomb_consumed",
			"suppress_paddle_hit_knockback",
			"boss_status_immune",
		]:
			if boss_result.has(key):
				result[key] = boss_result[key]
	if runtime_perk_gold >= 0:
		result["runtime_perk_gold"] = runtime_perk_gold
	if bool(rainbow_glove_result.get("activated", false)):
		result["rainbow_fur_glove_activated"] = true
		result["rainbow_fur_glove_cooldown_reduction_pct"] = float(rainbow_glove_result.get("cooldown_reduction_pct", 0.0))
	if bool(shrapnel_armor_result.get("activated", false)):
		result["shrapnel_armor_activated"] = true
		result["shrapnel_armor_shard_count"] = int(shrapnel_armor_result.get("shard_count", 0))
		result["shrapnel_armor_gauge_cost"] = float(shrapnel_armor_result.get("gauge_cost", 0.0))
	if not blacksmith_shield_result.is_empty():
		for key in [
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
		]:
			if blacksmith_shield_result.has(key):
				result[key] = blacksmith_shield_result[key]
	if not fire_hit_result.is_empty():
		result["fire_weather_hit_knockback"] = true
		if fire_hit_result.has("player_fire_knockback_vel"):
			result["player_fire_knockback_vel"] = float(fire_hit_result.get("player_fire_knockback_vel", 0.0))
		if fire_hit_result.has("boss_fire_knockback_vel"):
			result["boss_fire_knockback_vel"] = float(fire_hit_result.get("boss_fire_knockback_vel", 0.0))
	_perf_end(perf_logger, "paddle_bounce.post_hit.total", total_start)
	return result


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _is_fire_weather_active(deps: Dictionary) -> bool:
	var weather = deps.get("weather_event_state", null)
	return weather != null and weather.has_method("is_fire_active") and bool(weather.is_fire_active())


func _apply_fire_weather_paddle_hit_knockback(
	fire_weather_hit_active: bool,
	is_player: bool,
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not fire_weather_hit_active:
		return {}
	var weather = deps.get("weather_event_state", null)
	if weather == null or not weather.has_method("apply_fire_paddle_hit_knockback"):
		return {}
	return weather.apply_fire_paddle_hit_knockback(is_player, ball_pos, context, deps)


@warning_ignore("shadowed_variable")
func _end_power_smashing_on_player_return(power_state: Object, event_router: Object) -> void:
	if power_state == null:
		return
	if event_router != null and event_router.has_method("end_power_smashing_on_player_return"):
		event_router.end_power_smashing_on_player_return(power_state)
	elif _is_basic_power_smash_parabola_active(power_state) and power_state.has_method("reset"):
		power_state.reset(false)


func _is_basic_power_smash_parabola_active(power_state: Object) -> bool:
	if not power_state.has_method("is_parabola_active") or not bool(power_state.is_parabola_active()):
		return false
	if power_state.has_method("is_ghost_shot_motion_active") and bool(power_state.is_ghost_shot_motion_active()):
		return false
	return true
