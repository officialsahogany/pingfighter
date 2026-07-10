extends RefCounted


func get_dowsing_pendulum_context(runtime: Object, constants: Dictionary) -> Dictionary:
	var attraction_range: float = runtime.get_dowsing_pendulum_range()
	if attraction_range <= 0.0:
		return {
			"active": false,
		}
	return {
		"active": true,
		"range": attraction_range,
		"force": float(constants.get("dowsing_pendulum_attraction_force", 3.5)),
		"min_distance": float(constants.get("dowsing_pendulum_min_distance", 30.0)),
		"max_speed": float(constants.get("dowsing_pendulum_max_speed", 8.0)),
	}


func get_sensor_context(runtime: Object) -> Dictionary:
	return {
		"equipped": runtime.is_sensor_equipped(),
		"enabled": runtime.sensor_enabled,
		"ready": runtime.is_sensor_auto_dash_ready(),
		"cooldown_seconds": runtime.get_sensor_cooldown_seconds(),
		"cooldown_remaining_seconds": runtime.get_sensor_cooldown_remaining_seconds(),
		"cooldown_progress": runtime.get_sensor_cooldown_progress(),
		"auto_dash_effect_active": runtime.sensor_auto_dash_effect_timer_frames > 0.0,
		"last_dash_direction": runtime.sensor_last_dash_direction,
	}


func get_hermes_shoes_context(runtime: Object) -> Dictionary:
	return runtime.hermes_shoes_state.get_context(
		runtime.is_hermes_shoes_equipped(),
		runtime.is_hermes_shoes_active(),
		runtime.get_hermes_shoes_speed_bonus_pct(),
		runtime.get_hermes_shoes_speed_multiplier()
	)


func get_celestial_armor_context(runtime: Object) -> Dictionary:
	return runtime.celestial_armor_state.get_context(
		runtime.is_celestial_armor_equipped(),
		runtime.is_celestial_armor_active(),
		runtime.get_celestial_armor_trigger_chance_pct(),
		runtime.get_celestial_armor_gauge_cost()
	)


func get_baal_boots_context(runtime: Object) -> Dictionary:
	var context: Dictionary = runtime.baal_boots_weather_state.get_context(
		runtime.is_baal_boots_equipped(),
		runtime.is_baal_boots_active(),
		runtime.get_baal_boots_gauge_recovery()
	)
	context.merge(runtime.baal_boots_combat_state.get_context(), true)
	return context


func get_venom_mist_context(runtime: Object, constants: Dictionary) -> Dictionary:
	return {
		"equipped": runtime.is_venom_mist_gauntlet_equipped(),
		"active": runtime.is_venom_mist_gauntlet_active(),
		"count": runtime.get_venom_mist_gauntlet_count(),
		"trigger_chance_pct": runtime.get_venom_mist_trigger_chance_pct(),
		"duration_sec": runtime.get_venom_mist_duration_sec(),
		"ball_poisoned": runtime.venom_mist_ball_poisoned,
		"field_active": runtime.venom_mist_field_active,
		"field_center": runtime.venom_mist_center,
		"field_radius": float(constants.get("venom_mist_radius", 120.0)),
		"field_timer_frames": runtime.venom_mist_timer_frames,
		"boss_in_field": runtime.venom_mist_boss_in_field,
		"boss_slow_multiplier": runtime.get_venom_mist_boss_slow_multiplier(),
	}


func get_commando_arm_context(runtime: Object) -> Dictionary:
	return {
		"equipped": runtime.is_commando_arm_equipped(),
		"active": runtime.is_commando_arm_active(),
		"count": runtime.get_commando_arm_count(),
		"throw_speed_pct": runtime.get_commando_arm_throw_speed_pct(),
		"explosion_range_pct": runtime.get_commando_arm_explosion_range_pct(),
		"smoke_duration_pct": runtime.get_commando_arm_smoke_duration_pct(),
		"prep_reduction_pct": runtime.get_commando_arm_prep_reduction_pct(),
		"prep_multiplier": runtime.get_commando_arm_prep_multiplier(),
		"generic_throw_speed_multiplier": runtime.get_commando_arm_throw_speed_multiplier(false),
		"boomerang_throw_speed_multiplier": runtime.get_commando_arm_throw_speed_multiplier(true),
		"range_multiplier": runtime.get_commando_arm_range_multiplier(),
		"smoke_duration_multiplier": runtime.get_commando_arm_smoke_duration_multiplier(),
	}


func get_rainbow_fur_glove_context(runtime: Object) -> Dictionary:
	return {
		"equipped": runtime.is_rainbow_fur_glove_equipped(),
		"active": runtime.is_rainbow_fur_glove_active(),
		"trigger_chance_pct": runtime.get_rainbow_fur_glove_trigger_chance_pct(),
		"cooldown_reduction_pct": runtime.get_rainbow_fur_glove_cooldown_reduction_pct(),
		"effect_active": runtime.rainbow_fur_glove_aura_timer_frames > 0.0 or not runtime.rainbow_fur_glove_particles.is_empty(),
		"aura_timer_frames": runtime.rainbow_fur_glove_aura_timer_frames,
		"last_reduction_pct": runtime.rainbow_fur_glove_last_reduction_pct,
	}


func get_adversity_armor_context(runtime: Object) -> Dictionary:
	return {
		"equipped": runtime.is_adversity_armor_equipped(),
		"active": runtime.is_adversity_armor_active(),
		"trigger_chance_pct": runtime.get_adversity_armor_trigger_chance_pct(),
		"invincible_duration_sec": runtime.get_adversity_armor_invincible_duration_sec(),
		"serve_speed_bonus_pct": runtime.get_adversity_armor_serve_speed_bonus_pct(),
		"pending_invincible": runtime.adversity_armor_pending_invincible,
		"serve_speed_boost_pending": runtime.adversity_armor_serve_speed_boost_pending,
		"invincible": runtime.is_adversity_armor_invincible(),
		"timer_frames": runtime.adversity_armor_invincible_timer_frames,
		"total_timer_frames": runtime.adversity_armor_invincible_total_frames,
		"timer_ratio": runtime.adversity_armor_runtime.get_timer_ratio(runtime),
		"barrier_y": runtime.adversity_armor_runtime.get_barrier_y(),
		"flash_timer_frames": runtime.adversity_armor_flash_timer_frames,
		"flash_frames": 30.0,
		"phase": runtime.adversity_armor_phase,
		"last_trigger_roll_pct": runtime.adversity_armor_last_trigger_roll_pct,
		"last_triggered": runtime.adversity_armor_last_triggered,
		"last_reflect_center": runtime.adversity_armor_last_reflect_center,
	}


func get_shrapnel_armor_context(runtime: Object) -> Dictionary:
	return {
		"equipped": runtime.is_shrapnel_armor_equipped(),
		"active": runtime.is_shrapnel_armor_active(),
		"trigger_chance_pct": runtime.get_shrapnel_armor_trigger_chance_pct(),
		"shard_count": runtime.get_shrapnel_armor_shard_count(),
		"knockback_level": runtime.get_shrapnel_armor_knockback_level(),
		"gauge_cost": runtime.get_shrapnel_armor_gauge_cost(),
		"effect_active": runtime.shrapnel_armor_runtime.is_effect_active(runtime),
		"boss_stun_active": runtime.shrapnel_armor_boss_stun_timer_frames > 0.0,
		"boss_knockback_active": runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0 and abs(runtime.shrapnel_armor_boss_knockback_vel) > 0.0,
		"boss_knockback_vel": runtime.shrapnel_armor_boss_knockback_vel,
		"last_proc_shard_count": runtime.shrapnel_armor_last_proc_shard_count,
		"last_gauge_cost": runtime.shrapnel_armor_last_gauge_cost,
	}


func get_sacred_laurel_context(runtime: Object) -> Dictionary:
	var leaf_bonus: int = runtime.get_sacred_laurel_leaf_bonus()
	return {
		"active": leaf_bonus > 0,
		"leaf_bonus": leaf_bonus,
	}


func get_transcendent_crown_context(runtime: Object) -> Dictionary:
	var skill_bonus: int = runtime.get_transcendent_crown_skill_bonus()
	return {
		"active": skill_bonus > 0,
		"skill_bonus": skill_bonus,
	}


func get_poseidon_context(runtime: Object, _constants: Dictionary) -> Dictionary:
	return {
		"equipped": runtime.poseidon_runtime.is_equipped(runtime),
		"cooldown": runtime.get_poseidon_cooldown(),
		"cooldown_remaining": max(0.0, runtime.poseidon_effect_cooldown_frames / 60.0),
		"gauge_cost": runtime.get_poseidon_gauge_cost(),
		"vortex_size": runtime.get_poseidon_vortex_size(),
		"vortex_active": runtime.poseidon_vortex_active,
		"capture_active": runtime.poseidon_capture_active,
		"capture_progress": clamp(runtime.poseidon_capture_timer_frames / max(1.0, runtime.poseidon_capture_duration_frames), 0.0, 1.0) if runtime.poseidon_capture_active else 0.0,
		"water_trail_active": runtime.poseidon_water_trail_active,
	}


func get_boss_ai_context(runtime: Object, constants: Dictionary) -> Dictionary:
	var baal_rain_slow_multiplier: float = float(constants.get("baal_rain_slow_multiplier", 0.70))
	var context := {
		"ragnarok_hammer_boss_stun_active": runtime.ragnarok_boss_stun_timer_frames > 0.0,
		"ragnarok_hammer_boss_knockback_active": runtime.ragnarok_boss_knockback_timer_frames > 0.0 and abs(runtime.ragnarok_boss_knockback_vel) > 0.0,
		"ragnarok_hammer_boss_knockback_vel": runtime.ragnarok_boss_knockback_vel,
		"ragnarok_hammer_electric_stun_drift_vel": runtime.ragnarok_boss_electric_drift_vel,
		"venom_mist_boss_slow_active": runtime.venom_mist_field_active and runtime.venom_mist_boss_in_field,
		"venom_mist_boss_slow_multiplier": runtime.get_venom_mist_boss_slow_multiplier(),
		"shrapnel_armor_boss_stun_active": runtime.shrapnel_armor_boss_stun_timer_frames > 0.0,
		"shrapnel_armor_boss_knockback_active": runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0 and abs(runtime.shrapnel_armor_boss_knockback_vel) > 0.0,
		"shrapnel_armor_boss_knockback_vel": runtime.shrapnel_armor_boss_knockback_vel,
	}
	runtime.baal_boots_combat_state.merge_boss_ai_context(context, baal_rain_slow_multiplier)
	return context


func get_actor_draw_context(runtime: Object, constants: Dictionary) -> Dictionary:
	if not has_actor_draw_context(runtime):
		return {}
	var ragnarok_boss_stun_frame_msec: int = int(constants.get("ragnarok_boss_stun_frame_msec", 100))
	var stun_active: bool = runtime.ragnarok_boss_stun_timer_frames > 0.0
	var shrapnel_stun_active: bool = runtime.shrapnel_armor_boss_stun_timer_frames > 0.0
	var soul_burst_visible: bool = runtime.soul_burst_dash_active or runtime.soul_burst_effect_timer_frames > 0.0
	var context := {}
	if stun_active or runtime.ragnarok_boss_knockback_timer_frames > 0.0:
		context["ragnarok_hammer_boss_stun_active"] = stun_active
		context["ragnarok_hammer_electric_stun_active"] = stun_active
		context["ragnarok_hammer_boss_knockback_active"] = runtime.ragnarok_boss_knockback_timer_frames > 0.0
	if shrapnel_stun_active or runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0:
		context["shrapnel_armor_boss_stun_active"] = shrapnel_stun_active
		context["shrapnel_armor_boss_knockback_active"] = runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0
	if shrapnel_stun_active:
		context["active_item_boss_stun_active"] = true
		@warning_ignore("integer_division")
		context["active_item_boss_stun_frame"] = int(Time.get_ticks_msec() / ragnarok_boss_stun_frame_msec) % 8
	if stun_active:
		context["active_item_boss_stun_active"] = true
		@warning_ignore("integer_division")
		context["active_item_boss_stun_frame"] = int(Time.get_ticks_msec() / ragnarok_boss_stun_frame_msec) % 8
		context["active_item_boss_stun_stars_suppressed"] = true
	if soul_burst_visible:
		context["soul_burst_dash_active"] = runtime.soul_burst_dash_active
		context["soul_burst_effect_active"] = runtime.soul_burst_effect_timer_frames > 0.0
		context["player_color"] = Color(110.0 / 255.0, 45.0 / 255.0, 185.0 / 255.0)
		context["player_color_light"] = Color(210.0 / 255.0, 160.0 / 255.0, 1.0)
	if runtime.is_horn_strawberry_transformed() or runtime.is_horn_strawberry_event_playing():
		# Python parity: the transform/detransform EVENTS also hide the normal
		# paddle and drive the snapshot-rise, so the actor renderer needs the
		# horn context during the events too, not only once transformed.
		context["horn_strawberry_transformed"] = runtime.is_horn_strawberry_transformed()
		context["horn_strawberry_event_playing"] = runtime.is_horn_strawberry_event_playing()
		context["horn_strawberry_context"] = runtime.get_horn_strawberry_context()
	return context


func has_actor_draw_context(runtime: Object) -> bool:
	return (
		runtime.soul_burst_dash_active
		or runtime.soul_burst_effect_timer_frames > 0.0
		or runtime.ragnarok_boss_stun_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_stun_timer_frames > 0.0
		or runtime.ragnarok_boss_knockback_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0
		or runtime.is_horn_strawberry_transformed()
		or runtime.is_horn_strawberry_event_playing()
	)


func get_ball_draw_context(runtime: Object) -> Dictionary:
	if not has_ball_draw_context(runtime):
		return {}
	var context := {}
	if runtime.ragnarok_stun_ball_active:
		context["ragnarok_hammer_ball_active"] = true
		context["ragnarok_hammer_ball_elapsed"] = runtime.ragnarok_runtime.get_ball_elapsed(runtime)
	if _is_poseidon_ball_draw_active(runtime):
		context["poseidon_trident_ball_active"] = true
	if runtime.venom_mist_ball_poisoned:
		context["poisoned_ball_overlay_active"] = true
	runtime.baal_boots_combat_state.merge_ball_draw_context(context)
	return context


func has_ball_draw_context(runtime: Object) -> bool:
	return (
		runtime.ragnarok_stun_ball_active
		or _is_poseidon_ball_draw_active(runtime)
		or runtime.venom_mist_ball_poisoned
		or _is_baal_boots_ball_mark_active(runtime)
	)


func _is_poseidon_ball_draw_active(runtime: Object) -> bool:
	return runtime.poseidon_capture_active or runtime.poseidon_water_trail_active or runtime.poseidon_vortex_affected


func _is_baal_boots_ball_mark_active(runtime: Object) -> bool:
	return runtime.baal_boots_combat_state.ball_mark_timer_frames > 0.0 and runtime.baal_boots_combat_state.ball_mark_type != ""
