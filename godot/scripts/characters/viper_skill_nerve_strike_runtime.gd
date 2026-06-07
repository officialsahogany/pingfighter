extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func start_strike(runtime: Object, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "nerve_strike"))
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var next_gauge: float = max(0.0, special_gauge - runtime._get_skill_cost_with_fallback(skill_config, skill_name, float(constants.get("gauge_cost", 90.0))))
	runtime.runtime_action_router.trigger_viper_runtime_cooldown(skill_name, now_msec, skill_config, deps, runtime._get_four_poisons_additive_cooldown_seconds(skill_name, skill_config, deps, float(constants.get("cooldown_base", 40.0))), runtime.visibility_query)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime.runtime_action_router.trigger_feedback(deps, 0.12, 4.2)
	runtime.runtime_action_router.interrupt_viper_jetpack_thrust(deps)
	runtime.audio_router.stop_blade_spin_sound(runtime, deps)
	runtime._reset_blade_motion_only(deps)
	runtime.nerve_strike_cast_id += 1
	runtime.nerve_strike_active = true
	runtime.nerve_strike_phase = 0
	runtime.nerve_strike_phase_frames = 0.0
	runtime.nerve_strike_start_pos = player_pos
	runtime.nerve_strike_pos = player_pos
	runtime.nerve_strike_dash_target_pos = ViperSkillGeometry.nerve_strike_target_pos(config, float(constants.get("target_y_offset", 0.0)))
	runtime.nerve_strike_return_start_pos = Vector2.ZERO
	runtime.nerve_strike_return_target_pos = Vector2.ZERO
	runtime.nerve_strike_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.nerve_strike_floor_y = ViperSkillGeometry.player_floor_y(config)
	runtime.nerve_strike_hit_confirmed = false
	runtime.nerve_strike_combo_used = true
	runtime.nerve_strike_freeze_active = false
	runtime.nerve_strike_slash_triggered = false
	runtime.nerve_strike_slash_vfx_frames = 0.0
	runtime.nerve_strike_slash_center = ViperSkillGeometry.nerve_strike_target_center(config, float(constants.get("target_y_offset", 0.0)))
	runtime.audio_router.play_nerve_strike_moving_sound(deps)
	_spawn_replicated_clone_slashes(runtime, config, deps, constants)
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": runtime.nerve_strike_pos, "player_speed": 0.0, "special_gauge": next_gauge}


static func update_strike(runtime: Object, delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	runtime.nerve_strike_phase_frames += fps_scale
	var result: Dictionary = {"handled": true, "activated": false, "skill_name": str(constants.get("skill_name", "nerve_strike")), "player_pos": player_pos, "player_speed": 0.0, "special_gauge": special_gauge}
	match runtime.nerve_strike_phase:
		0:
			_update_dash_phase(runtime, result, config, deps, constants)
		1:
			_update_slash_phase(runtime, config, deps, constants)
		2:
			_update_return_phase(runtime, result, deps, constants)
		_:
			reset_runtime(runtime, false)
	if runtime.nerve_strike_active:
		result["player_pos"] = runtime.nerve_strike_pos
	return result


static func enter_return_phase(runtime: Object, config: Dictionary, deps: Dictionary) -> void:
	runtime.nerve_strike_phase = 2
	runtime.nerve_strike_phase_frames = 0.0
	# Python parity (pingfighter.py: "프리즈는 착지 완료까지 유지 — Phase 2 끝에서 해제"):
	# the hit cutscene freeze (ball + boss + stage hazards) is held THROUGH the
	# return flight and is only released when Viper finishes landing, via
	# reset_runtime() at the end of _update_return_phase(). Do NOT clear
	# nerve_strike_freeze_active here — clearing it on return-phase entry lets the
	# ball/boss resume ~15 frames (~0.25s) early while Viper is still flying back.
	# Misses never set the freeze (start_strike() leaves it false), so leaving it
	# untouched is correct for the miss path too.
	runtime.nerve_strike_return_start_pos = runtime.nerve_strike_pos
	runtime.nerve_strike_return_target_pos = ViperSkillGeometry.nerve_strike_return_target_pos(config)
	runtime.audio_router.play_nerve_strike_moving_sound(deps)


static func reset_runtime(runtime: Object, clear_clones: bool = false) -> void:
	runtime.nerve_strike_active = false
	runtime.nerve_strike_phase = 0
	runtime.nerve_strike_phase_frames = 0.0
	runtime.nerve_strike_start_pos = Vector2.ZERO
	runtime.nerve_strike_pos = Vector2.ZERO
	runtime.nerve_strike_dash_target_pos = Vector2.ZERO
	runtime.nerve_strike_return_start_pos = Vector2.ZERO
	runtime.nerve_strike_return_target_pos = Vector2.ZERO
	runtime.nerve_strike_paddle_size = Vector2(155.0, 50.0)
	runtime.nerve_strike_floor_y = 700.0
	runtime.nerve_strike_hit_confirmed = false
	runtime.nerve_strike_freeze_active = false
	runtime.nerve_strike_slash_triggered = false
	runtime.nerve_strike_slash_vfx_frames = 0.0
	runtime.nerve_strike_slash_center = Vector2.ZERO
	if clear_clones:
		runtime.nerve_strike_combo_used = false
		runtime.nerve_strike_miss_text_timer = 0.0
		runtime.nerve_strike_miss_text_pos = Vector2.ZERO
		runtime.nerve_strike_clone_slashes.clear()


static func apply_confusion(runtime: Object, deps: Dictionary, constants: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null:
		var registry: Object = deps.get("registry", null)
		if registry != null and registry.has_method("get_instance"):
			status_effect_state = registry.get_instance("status_effect_state")
	if status_effect_state == null or not status_effect_state.has_method("apply_status"):
		return
	var venom_confusion_values: Array = constants.get("venom_confusion_values", [])
	var venom_confusion_pct: int = runtime._get_four_poisons_scaled_pct(deps, venom_confusion_values, int(constants.get("venom_confusion_cap", 150)), int(constants.get("venom_confusion_per_extra", 10)))
	var confusion_multiplier: float = 1.0 + float(venom_confusion_pct) / 100.0
	status_effect_state.apply_status("boss", "confusion", round(float(constants.get("confusion_frames", 150.0)) * confusion_multiplier), {"cleansable": true}, "viper_nerve_strike")


static func get_boss_center(config: Dictionary) -> Vector2:
	return ViperSkillGeometry.nerve_strike_boss_center(config)


static func spawn_slash_feedback(runtime: Object, center: Vector2, deps: Dictionary) -> void:
	runtime.runtime_action_router.trigger_feedback(deps, 0.16, 5.0)
	runtime._spawn_fallback_hit_impact(center, Vector2(0.0, 24.0), deps, Color(0.72, 0.12, 0.95, 1.0), 1.4, 0.95, 1.10)


static func _spawn_replicated_clone_slashes(runtime: Object, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	if not runtime._is_dual_glitch_clone_replication_active(deps):
		return
	var nerve_replica_origins: Array = runtime.visibility_query.get_dual_glitch_replication_origins(runtime._get_dual_glitch_clone_rect_entries(true, false))
	if nerve_replica_origins.is_empty():
		return
	var nerve_replica_boss_center: Vector2 = get_boss_center(config)
	for nerve_origin_value in nerve_replica_origins:
		if not (nerve_origin_value is Dictionary):
			continue
		var nerve_origin: Dictionary = nerve_origin_value
		var nerve_replica_side: int = int(nerve_origin.get("side", 0))
		if nerve_replica_side == 0:
			continue
		var nerve_replica_delay_mult: float = 1.0 if nerve_replica_side < 0 else 2.0
		var nerve_replica_start := Vector2(float(nerve_origin.get("x", nerve_replica_boss_center.x)), float(nerve_origin.get("y", nerve_replica_boss_center.y)))
		runtime.nerve_strike_clone_slashes.append({"cast_id": runtime.nerve_strike_cast_id, "side": nerve_replica_side, "state": "pending", "delay_frames": float(constants.get("dual_glitch_nerve_stagger_frames", 12.0)) * nerve_replica_delay_mult, "timer": 0.0, "origin": nerve_replica_start, "pos": nerve_replica_start, "target": nerve_replica_boss_center, "hit_applied": false})


static func _update_dash_phase(runtime: Object, result: Dictionary, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	var dash_motion: Dictionary = ViperSkillGeometry.nerve_strike_dash_motion(runtime.nerve_strike_start_pos, runtime.nerve_strike_dash_target_pos, ViperSkillGeometry.nerve_strike_target_pos(config, float(constants.get("target_y_offset", 0.0))), runtime.nerve_strike_phase_frames, float(constants.get("dash_frames", 30.0)), float(constants.get("tracking_end_ratio", 0.80)), float(constants.get("tracking_strength", 0.12)))
	var dash_progress: float = float(dash_motion.get("progress", 0.0))
	runtime.nerve_strike_dash_target_pos = _get_vector2(dash_motion.get("target_pos", runtime.nerve_strike_dash_target_pos), runtime.nerve_strike_dash_target_pos)
	runtime.nerve_strike_pos = _get_vector2(dash_motion.get("pos", runtime.nerve_strike_pos), runtime.nerve_strike_pos)
	if dash_progress >= 1.0:
		var nerve_strike_player_center: Vector2 = runtime.nerve_strike_pos + runtime.nerve_strike_paddle_size * 0.5
		runtime.nerve_strike_hit_confirmed = ViperSkillGeometry.nerve_strike_hits_target(nerve_strike_player_center, get_boss_center(config), float(constants.get("hit_radius", 120.0)))
		runtime.nerve_strike_phase = 1
		runtime.nerve_strike_phase_frames = 0.0
		runtime.nerve_strike_slash_triggered = false
		runtime.nerve_strike_slash_center = get_boss_center(config)
		if runtime.nerve_strike_hit_confirmed:
			_apply_dash_hit(runtime, result, deps, constants)
		else:
			runtime.nerve_strike_miss_text_timer = float(constants.get("miss_text_frames", 60.0))
			runtime.nerve_strike_miss_text_pos = ViperSkillGeometry.nerve_strike_miss_text_pos(ViperSkillGeometry.nerve_strike_target_center(config, float(constants.get("target_y_offset", 0.0))), -20.0)
			enter_return_phase(runtime, config, deps)


static func _apply_dash_hit(runtime: Object, result: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.nerve_strike_freeze_active = true
	runtime.audio_router.play_phantom_show_sound(deps)
	runtime.runtime_action_router.trigger_feedback(deps, 0.18, 5.2)
	var mythic_item_runtime: Object = runtime.visibility_query.get_mythic_item_runtime(deps)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_spawn_venom_mist_at_boss"):
		mythic_item_runtime.try_spawn_venom_mist_at_boss(runtime.nerve_strike_slash_center, deps, false)
	result.merge(runtime.runtime_action_router.award_skill_gold(deps, int(constants.get("hit_gold", 60))), true)


static func _update_slash_phase(runtime: Object, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	var slash_duration: float = float(constants.get("slash_hit_frames", 138.0)) if runtime.nerve_strike_hit_confirmed else float(constants.get("slash_miss_frames", 18.0))
	var slash_progress: float = ViperSkillGeometry.nerve_strike_phase_progress(runtime.nerve_strike_phase_frames, slash_duration)
	runtime.nerve_strike_pos = runtime.nerve_strike_dash_target_pos
	if ViperSkillGeometry.nerve_strike_should_trigger_slash(runtime.nerve_strike_hit_confirmed, runtime.nerve_strike_slash_triggered, slash_progress, float(constants.get("slash_trigger_ratio", 0.45))):
		runtime.nerve_strike_slash_triggered = true
		runtime.nerve_strike_slash_vfx_frames = float(constants.get("slash_vfx_frames", 30.0))
		runtime.nerve_strike_slash_center = get_boss_center(config)
		runtime.trigger_venom_edge_strike()
		runtime.audio_router.play_nerve_strike_attack_sound(deps)
		spawn_slash_feedback(runtime, runtime.nerve_strike_slash_center, deps)
	if slash_progress >= 1.0:
		if runtime.nerve_strike_hit_confirmed:
			apply_confusion(runtime, deps, constants)
		enter_return_phase(runtime, config, deps)


static func _update_return_phase(runtime: Object, result: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	var return_frames: float = float(constants.get("return_hit_frames", 15.0)) if runtime.nerve_strike_hit_confirmed else float(constants.get("return_miss_frames", 9.0))
	var return_motion: Dictionary = ViperSkillGeometry.nerve_strike_return_motion(runtime.nerve_strike_return_start_pos, runtime.nerve_strike_return_target_pos, runtime.nerve_strike_phase_frames, return_frames)
	var return_progress: float = float(return_motion.get("progress", 0.0))
	runtime.nerve_strike_pos = _get_vector2(return_motion.get("pos", runtime.nerve_strike_pos), runtime.nerve_strike_pos)
	if return_progress >= 1.0:
		runtime.nerve_strike_pos = runtime.nerve_strike_return_target_pos
		var nerve_strike_final_pos: Vector2 = runtime.nerve_strike_pos
		runtime.runtime_action_router.force_viper_jetpack_land(deps)
		reset_runtime(runtime, false)
		result["player_pos"] = nerve_strike_final_pos


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
