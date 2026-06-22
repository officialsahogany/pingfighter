extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const PLAY_LEFT := 0.0
const PLAY_RIGHT := WIDTH
const BALL_SIZE := 28.6
const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE
const DRIVE_TEXT_DURATION_FRAMES := 30.0
const POWER_SMASH_TEXT_DURATION_FRAMES := 48.0
const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0
const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_PADDLE_HEIGHT := 40.0
const BOSS_HITBOX_HEIGHT := BOSS_PADDLE_HEIGHT

var character_runtime: Object = PlayerCharacterRuntime.new()


func build(owner: Object, shake_offset: Vector2, registry) -> Dictionary:
	var current_msec: int = Time.get_ticks_msec()
	var selected_character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", PlayerCharacterRuntime.SMASHER))
	var player_paddle_width: float = max(1.0, float(_get_owner_value(owner, "player_paddle_width", PADDLE_WIDTH)))
	var player_paddle_height: float = max(1.0, float(_get_owner_value(owner, "player_paddle_height", PADDLE_HEIGHT)))
	var runtime_paddle_base_width: float = max(1.0, float(_get_owner_value(owner, "runtime_paddle_base_width", player_paddle_width)))
	var runtime_player_paddle_scale: float = max(0.1, float(_get_owner_value(owner, "player_paddle_scale", player_paddle_width / PADDLE_WIDTH)))
	var player_paddle_visual_scale_override: float = float(_get_owner_value(owner, "player_paddle_visual_scale_override", -1.0))
	var boss_paddle_width: float = max(1.0, float(_get_owner_value(owner, "boss_paddle_width", BOSS_PADDLE_WIDTH)))
	var boss_hitbox_height: float = max(1.0, float(_get_owner_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT)))
	var player_paddle_scale: float = _resolve_player_visual_paddle_scale(
		runtime_player_paddle_scale,
		player_paddle_visual_scale_override,
		runtime_paddle_base_width
	)
	var layout: Dictionary = _build_game_layout(owner, registry, WIDTH, HEIGHT)
	var dash_snapshot: Dictionary = _get_dash_snapshot(registry)
	var viper_knockback_overlay_active: bool = bool(_get_owner_value(owner, "viper_knockback_overlay_active", false))
	var viper_jetpack_active: bool = false
	var viper_jetpack_airborne: bool = false
	var viper_air_strike_flash_timer: float = 0.0
	if selected_character_type == PlayerCharacterRuntime.VIPER:
		var viper_skill_runtime: Object = registry.get_instance("viper_skill_runtime") if registry != null and registry.has_method("get_instance") else null
		if viper_skill_runtime != null and viper_skill_runtime.has_method("is_kick_skill_knockback_ball_active"):
			viper_knockback_overlay_active = viper_knockback_overlay_active or bool(viper_skill_runtime.is_kick_skill_knockback_ball_active())
		var viper_jetpack_state: Object = registry.get_instance("viper_jetpack_state") if registry != null and registry.has_method("get_instance") else null
		if viper_jetpack_state != null:
			if "active" in viper_jetpack_state:
				viper_jetpack_active = bool(viper_jetpack_state.active)
			if viper_jetpack_state.has_method("is_airborne"):
				viper_jetpack_airborne = bool(viper_jetpack_state.is_airborne(0.1))
			if "air_strike_flash_timer" in viper_jetpack_state:
				viper_air_strike_flash_timer = float(viper_jetpack_state.air_strike_flash_timer)
	var context := {
		"shake_offset": shake_offset,
		"current_msec": current_msec,
		"width": WIDTH,
		"height": HEIGHT,
		"game_offset": _get_layout_vector2(layout, "game_offset", Vector2.ZERO),
		"game_size": _get_layout_vector2(layout, "game_size", Vector2(WIDTH, HEIGHT)),
		"render_scale": max(0.001, float(layout.get("render_scale", 1.0))),
		"selected_character_type": selected_character_type,
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"stage1_boss_variant": str(_get_owner_value(owner, "stage1_boss_variant", "dalji")),
		"weather_type": str(_get_owner_value(owner, "weather_type", "")),
		"weather_active": bool(_get_owner_value(owner, "weather_event_active", false)),
		"weather_event_active": bool(_get_owner_value(owner, "weather_event_active", false)),
		"weather_event_context": _get_owner_dict(owner, "weather_event_context"),
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"dash_snapshot": dash_snapshot,
		"textures": _get_owner_dict(owner, "battle_textures"),
		"player_customization_overlays_enabled": bool(_get_owner_value(owner, "player_customization_overlays_enabled", true)),
		"player_customization_debug_overlay_enabled": bool(_get_owner_value(owner, "player_customization_debug_overlay_enabled", false)),
		"player_customization_overlay_slots": _get_owner_dict(owner, "player_customization_overlay_slots"),
		"player_customization_overlay_textures": _get_owner_dict(owner, "player_customization_overlay_textures"),
		"player_pos": _get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		"player_speed": float(_get_owner_value(owner, "player_speed", 0.0)),
		"player_paddle_size": Vector2(player_paddle_width, player_paddle_height),
		"player_paddle_scale": player_paddle_scale,
		"boss_pos": _get_owner_vector2(owner, "boss_pos", Vector2.ZERO),
		"boss_pos_prev": _get_owner_vector2(owner, "boss_pos_prev", _get_owner_vector2(owner, "boss_pos", Vector2.ZERO)),
		"boss_interp_last_physics_usec": int(_get_owner_value(owner, "boss_interp_last_physics_usec", 0)),
		"boss_render_interpolation_enabled": bool(_get_owner_value(owner, "boss_render_interpolation_enabled", true)),
		"boss_paddle_size": Vector2(boss_paddle_width, boss_hitbox_height),
		"boss_hitbox_height": boss_hitbox_height,
		"boss_max_health": max(0, int(_get_owner_value(owner, "boss_max_health", 0))),
		"boss_current_health": max(0, int(_get_owner_value(owner, "boss_current_health", 0))),
		"boss_health_damage_units": max(0, int(_get_owner_value(owner, "boss_health_damage_units", 0))),
		"boss_last_damage_source": str(_get_owner_value(owner, "boss_last_damage_source", "")),
		"boss_defeated_by_health": bool(_get_owner_value(owner, "boss_defeated_by_health", false)),
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_pos_prev": _get_owner_vector2(owner, "ball_pos_prev", _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)),
		"ball_interp_reset_requested": bool(_get_owner_value(owner, "ball_interp_reset_requested", false)),
		"ball_interp_last_physics_usec": int(_get_owner_value(owner, "ball_interp_last_physics_usec", 0)),
		"ball_render_interpolation_enabled": bool(_get_owner_value(owner, "ball_render_interpolation_enabled", true)),
		"ball_vel": _get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		"stage3_kuromi_ball_hidden": bool(_get_owner_value(owner, "stage3_kuromi_ball_hidden", false)),
		"ball_size": BALL_SIZE,
		"ball_visual_type": str(_get_owner_value(owner, "ball_visual_type", "energy")),
		"bomb_ball_loaded": bool(_get_owner_value(owner, "bomb_ball_loaded", false)),
		"poisoned_ball_overlay_active": bool(_get_owner_value(owner, "poisoned_ball_overlay_active", false)),
		"blacksmith_umbrella_open": bool(_get_owner_value(owner, "blacksmith_umbrella_open", false)),
		"blacksmith_umbrella_anim_timer": float(_get_owner_value(owner, "blacksmith_umbrella_anim_timer", 0.0)),
		"blacksmith_umbrella_retracting": bool(_get_owner_value(owner, "blacksmith_umbrella_retracting", false)),
		"blacksmith_umbrella_anim_direction": int(_get_owner_value(owner, "blacksmith_umbrella_anim_direction", 1)),
		"blacksmith_umbrella_open_ratio": clamp(float(_get_owner_value(owner, "blacksmith_umbrella_open_ratio", 0.0)), 0.0, 1.0),
		"blacksmith_thor_shield_open_ratio": clamp(float(_get_owner_value(owner, "blacksmith_thor_shield_open_ratio", 0.0)), 0.0, 1.0),
		"blacksmith_umbrella_raise_amount": clamp(float(_get_owner_value(owner, "blacksmith_umbrella_raise_amount", 0.0)), 0.0, 1.0),
		"blacksmith_umbrella_shield_open_amount": clamp(float(_get_owner_value(owner, "blacksmith_umbrella_shield_open_amount", 0.0)), 0.0, 1.0),
		"blacksmith_umbrella_visual_state": str(_get_owner_value(owner, "blacksmith_umbrella_visual_state", "closed")),
		"blacksmith_umbrella_folded": bool(_get_owner_value(owner, "blacksmith_umbrella_folded", true)),
		"blacksmith_umbrella_deployed": bool(_get_owner_value(owner, "blacksmith_umbrella_deployed", false)),
		"blacksmith_umbrella_swing_active": bool(_get_owner_value(owner, "blacksmith_umbrella_swing_active", false)),
		"blacksmith_umbrella_swing_direction": int(_get_owner_value(owner, "blacksmith_umbrella_swing_direction", 0)),
		"blacksmith_umbrella_swing_timer": float(_get_owner_value(owner, "blacksmith_umbrella_swing_timer", 0.0)),
		"blacksmith_umbrella_gauge": int(_get_owner_value(owner, "blacksmith_umbrella_gauge", 5)),
		"blacksmith_umbrella_gauge_max": int(_get_owner_value(owner, "blacksmith_umbrella_gauge_max", 5)),
		"blacksmith_umbrella_gauge_gain": float(_get_owner_value(owner, "blacksmith_umbrella_gauge_gain", 60.0)),
		"blacksmith_umbrella_damage_flash_timer": float(_get_owner_value(owner, "blacksmith_umbrella_damage_flash_timer", 0.0)),
		"blacksmith_umbrella_hit_pulse_timer": float(_get_owner_value(owner, "blacksmith_umbrella_hit_pulse_timer", 0.0)),
		"viper_knockback_overlay_active": viper_knockback_overlay_active,
		"viper_jetpack_active": viper_jetpack_active,
		"viper_jetpack_airborne": viper_jetpack_airborne,
		"viper_air_strike_flash_timer": viper_air_strike_flash_timer,
		"boost_charging_active": bool(dash_snapshot.get("boost_charging_active", _get_owner_value(owner, "boost_charging_active", false))),
		"drive_ball_active": bool(_get_owner_value(owner, "drive_ball_active", false)),
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
		"player_paddle_width": player_paddle_width,
		"boss_paddle_width": boss_paddle_width,
		"ball_render_radius": BALL_RENDER_RADIUS,
		"special_gauge": float(_get_owner_value(owner, "special_gauge", 0.0)),
		"drive_text_timer_frames": float(_get_owner_value(owner, "drive_text_timer_frames", 0.0)),
		"drive_text_duration_frames": DRIVE_TEXT_DURATION_FRAMES,
		"power_smash_text_duration_frames": POWER_SMASH_TEXT_DURATION_FRAMES,
	}
	_merge_blacksmith_thor_shield_state_context(context, selected_character_type, registry)
	return context


func _build_game_layout(owner: Object, registry, width: float, height: float) -> Dictionary:
	var view_size := Vector2(width, height)
	if owner != null and owner.has_method("get_viewport_rect"):
		view_size = owner.get_viewport_rect().size
	var layout_module: Object = registry.get_instance("battle_view_layout") if registry != null and registry.has_method("get_instance") else null
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_offset": Vector2.ZERO,
		"game_size": Vector2(width, height),
		"render_scale": 1.0,
	}


func _resolve_player_visual_paddle_scale(runtime_scale: float, visual_override: float, runtime_base_width: float) -> float:
	var safe_runtime_scale: float = maxf(0.1, runtime_scale)
	if visual_override <= 0.0:
		return safe_runtime_scale
	var base_scale: float = maxf(0.1, runtime_base_width / PADDLE_WIDTH)
	var dynamic_effect_scale: float = safe_runtime_scale / base_scale
	return maxf(0.1, visual_override * dynamic_effect_scale)


func _get_layout_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dash_snapshot(registry) -> Dictionary:
	var dash_state: Object = registry.get_instance("smasher_dash_state") if registry != null and registry.has_method("get_instance") else null
	if dash_state != null:
		return dash_state.get_snapshot()
	return _get_empty_dash_snapshot()


func _get_empty_dash_snapshot() -> Dictionary:
	return {
		"tokens": 0,
		"max_tokens": 1,
		"active": false,
		"direction": 0.0,
		"is_half": false,
		"recovering": false,
		"stun_timer": 0.0,
		"recovery_total_frames": 0.0,
		"recovery_progress": 1.0,
		"available_timer": 0.0,
		"charge_timer": 0.0,
		"recharge_frames": 300.0,
		"boost_charging_pending_dash_refund": false,
		"boost_charging_active": false,
		"boost_charging_timer": 0.0,
		"boost_charging_effect_timer": 0.0,
		"boost_charging_effect_duration": 12.0,
		"boost_charging_token_index": -1,
	}


func _merge_blacksmith_thor_shield_state_context(context: Dictionary, character_type: String, registry) -> void:
	if character_type != PlayerCharacterRuntime.BLACKSMITH:
		return
	var shield_state: Object = registry.get_instance("blacksmith_thor_shield_state") if registry != null and registry.has_method("get_instance") else null
	if shield_state == null or not shield_state.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = shield_state.get_snapshot()
	for key in snapshot.keys():
		var key_name := str(key)
		if key_name.begins_with("blacksmith_umbrella") or key_name == "blacksmith_thor_shield_open_ratio":
			context[key_name] = snapshot[key]


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)


func _get_owner_dict(owner: Object, key: String) -> Dictionary:
	return BattleSceneOwnerReader.get_dictionary(owner, key)
