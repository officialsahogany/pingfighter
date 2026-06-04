extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")

const GAUGE_MAX := 500.0
const STAGE1_BUTTERFLY_GAUGE_GAIN := 200.0


func update(delta: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var now_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	var dash_snapshot: Dictionary = _get_dictionary(context, "dash_snapshot")
	var dash_token_max: int = int(dash_snapshot.get("max_tokens", 1))
	var loop_audio_allowed: bool = _is_loop_audio_allowed(context, deps)
	var effect_deps: Dictionary = deps
	if not loop_audio_allowed:
		effect_deps = deps.duplicate()
		effect_deps["audio"] = null

	var feedback = deps.get("feedback", null)
	if feedback != null:
		feedback.update(delta, dash_token_max)

	var audio = deps.get("audio", null)
	if audio != null:
		audio.update(delta)
		if loop_audio_allowed and audio.has_method("sync_dash_delay"):
			audio.sync_dash_delay(_is_dash_recovery_audio_active(dash_snapshot))
		elif not loop_audio_allowed:
			GameplayLoopAudioCleanup.stop_all(audio)

	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("update"):
		status_effect_state.update(fps_scale, context, effect_deps)

	_merge_active_item_boss_skill_pause(context, deps.get("active_item_runtime", null))

	var stage1_balloon_event = deps.get("stage1_balloon_event", null)
	if stage1_balloon_event != null and stage1_balloon_event.has_method("update"):
		stage1_balloon_event.update(delta, context, effect_deps)

	var dalji_cooldown_state = deps.get("stage1_dalji_boss_skill_cooldown_state", null)
	if dalji_cooldown_state != null and dalji_cooldown_state.has_method("update"):
		var active_item_runtime = deps.get("active_item_runtime", null)
		if active_item_runtime != null and active_item_runtime.has_method("get_boss_ai_context"):
			context.merge(active_item_runtime.get_boss_ai_context(), true)
		dalji_cooldown_state.update(fps_scale, context, effect_deps)

	var stage2_boss_skill_state = deps.get("stage2_boss_skill_state", null)
	if stage2_boss_skill_state != null and stage2_boss_skill_state.has_method("update"):
		_merge_score_context(context, deps.get("score_state", null))
		stage2_boss_skill_state.update(delta, context, effect_deps)

	var stage3_boss_skill_state = deps.get("stage3_boss_skill_state", null)
	var stage3_boss_skill_result: Dictionary = {}
	if stage3_boss_skill_state != null and stage3_boss_skill_state.has_method("update"):
		_merge_score_context(context, deps.get("score_state", null))
		stage3_boss_skill_result = stage3_boss_skill_state.update(delta, context, effect_deps)
		context.merge(stage3_boss_skill_result, true)

	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	var stage5_hongryun_result: Dictionary = {}
	if (
		int(context.get("current_stage", 1)) == 5
		and stage5_hongryun_state != null
		and stage5_hongryun_state.has_method("update")
	):
		_merge_score_context(context, deps.get("score_state", null))
		stage5_hongryun_result = stage5_hongryun_state.update(delta, context, effect_deps)
		context.merge(stage5_hongryun_result, true)

	var stage5_hongryun_fire_machine_event: Object = deps.get("stage5_hongryun_fire_machine_event", null)
	var stage5_hongryun_fire_machine_result: Dictionary = {}
	if (
		int(context.get("current_stage", 1)) == 5
		and stage5_hongryun_fire_machine_event != null
		and stage5_hongryun_fire_machine_event.has_method("update")
	):
		stage5_hongryun_fire_machine_result = stage5_hongryun_fire_machine_event.update(delta, context, effect_deps)
		context.merge(stage5_hongryun_fire_machine_result, true)

	var stage6_tetriser_state: Object = deps.get("stage6_tetriser_state", null)
	var stage6_tetriser_result: Dictionary = {}
	if (
		int(context.get("current_stage", 1)) == 6
		and stage6_tetriser_state != null
		and stage6_tetriser_state.has_method("update")
	):
		stage6_tetriser_result = stage6_tetriser_state.update(delta, context, effect_deps)
		context.merge(stage6_tetriser_result, true)

	var drive_text_timer_frames: float = max(
		0.0,
		float(context.get("drive_text_timer_frames", 0.0)) - fps_scale
	)

	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var power_state = deps.get("power_state", null)
	if power_state != null:
		power_state.update_text_timer(fps_scale)
		power_state.update_effects(
			fps_scale,
			ball_pos,
			bool(context.get("ball_active", false)),
			float(context.get("ball_size", 0.0)),
			context
		)

	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if _needs_effect_update(plasma_state) and plasma_state.has_method("update_effects"):
		plasma_state.update_effects(fps_scale, context, effect_deps)

	var recovery_state: Object = deps.get("smasher_recovery_state", null)
	if _needs_effect_update(recovery_state) and recovery_state.has_method("update_effects"):
		recovery_state.update_effects(fps_scale, context, effect_deps)

	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if _needs_effect_update(cleanse_state) and cleanse_state.has_method("update_effects"):
		cleanse_state.update_effects(fps_scale, context, effect_deps)

	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)
	if _needs_effect_update(warp_gate_state) and warp_gate_state.has_method("update_effects"):
		warp_gate_state.update_effects(fps_scale, context, effect_deps)
	if audio != null and audio.has_method("sync_warp_gate_loop") and warp_gate_state != null and warp_gate_state.has_method("is_active"):
		audio.sync_warp_gate_loop(loop_audio_allowed and bool(warp_gate_state.is_active()))

	var wheel_state: Object = deps.get("smasher_wheel_state", null)
	if _needs_effect_update(wheel_state) and wheel_state.has_method("update_effects"):
		wheel_state.update_effects(fps_scale, context, effect_deps)
	if audio != null and audio.has_method("sync_smasher_wheel_loop") and wheel_state != null and wheel_state.has_method("is_active"):
		audio.sync_smasher_wheel_loop(loop_audio_allowed and bool(wheel_state.is_active()))

	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if _needs_effect_update(magnum_state) and magnum_state.has_method("update_effects"):
		magnum_state.update_effects(fps_scale, now_msec, context)
	if audio != null and audio.has_method("sync_magnum_grip") and magnum_state != null and magnum_state.has_method("is_active"):
		audio.sync_magnum_grip(loop_audio_allowed and bool(magnum_state.is_active()))

	var dash_spirit_state: Object = deps.get("smasher_dash_spirit_state", null)
	if _needs_effect_update(dash_spirit_state) and dash_spirit_state.has_method("update_effects"):
		dash_spirit_state.update_effects(fps_scale)

	var shield_kiting_state: Object = deps.get("smasher_shield_kiting_state", null)
	if _needs_effect_update(shield_kiting_state) and shield_kiting_state.has_method("update_effects"):
		shield_kiting_state.update_effects(fps_scale)

	var blacksmith_thor_shield_state: Object = deps.get("blacksmith_thor_shield_state", null)
	var blacksmith_thor_shield_result: Dictionary = {}
	if _needs_effect_update(blacksmith_thor_shield_state) and blacksmith_thor_shield_state.has_method("update_effects"):
		blacksmith_thor_shield_result = blacksmith_thor_shield_state.update_effects(fps_scale, context, effect_deps)
		if not blacksmith_thor_shield_result.is_empty():
			context.merge(blacksmith_thor_shield_result, true)

	var commando_firearm_runtime: Object = deps.get("commando_firearm_runtime", null)
	var commando_firearm_result: Dictionary = {}
	if _needs_effect_update(commando_firearm_runtime) and commando_firearm_runtime.has_method("update_effects"):
		commando_firearm_result = commando_firearm_runtime.update_effects(fps_scale, now_msec, context, effect_deps)
		if not commando_firearm_result.is_empty():
			context.merge(commando_firearm_result, true)

	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if _needs_effect_update(viper_skill_runtime) and viper_skill_runtime.has_method("update_effects"):
		viper_skill_runtime.update_effects(fps_scale, now_msec, context, effect_deps)
	if (
		audio != null
		and audio.has_method("sync_chaos_spear_blackhole_loop")
		and viper_skill_runtime != null
		and viper_skill_runtime.has_method("is_chaos_blackhole_audio_active")
	):
		audio.sync_chaos_spear_blackhole_loop(loop_audio_allowed and bool(viper_skill_runtime.is_chaos_blackhole_audio_active()))

	var monkey_blessing_delivery_state: Object = deps.get("monkey_blessing_delivery_state", null)
	if _needs_effect_update(monkey_blessing_delivery_state) and monkey_blessing_delivery_state.has_method("update_effects"):
		monkey_blessing_delivery_state.update_effects(delta, context, effect_deps)

	var commando_reload_delivery_state: Object = deps.get("commando_reload_delivery_state", null)
	if _needs_effect_update(commando_reload_delivery_state) and commando_reload_delivery_state.has_method("update_effects"):
		commando_reload_delivery_state.update_effects(delta, context, effect_deps)

	var combo_state = deps.get("combo_state", null)
	if _is_smasher_context(context) and combo_state != null:
		combo_state.update_timers(fps_scale)

	var stage_background = deps.get("stage_background", null)
	if stage_background != null:
		if stage_background.has_method("update"):
			stage_background.update(delta, context, effect_deps)

	var stage2_monkey_banana_result: Dictionary = {}
	var stage2_monkey_banana_event = deps.get("stage2_monkey_banana_event", null)
	if (
		int(context.get("current_stage", 1)) == 2
		and stage2_monkey_banana_event != null
		and stage2_monkey_banana_event.has_method("update")
	):
		stage2_monkey_banana_result = stage2_monkey_banana_event.update(delta, context, effect_deps)
		context.merge(stage2_monkey_banana_result, true)

	var next_special_gauge: float = float(context.get("special_gauge", 0.0))
	if (
		int(context.get("current_stage", 1)) == 1
		and stage_background != null
		and stage_background.has_method("consume_butterfly_gauge_recovery")
		and bool(stage_background.consume_butterfly_gauge_recovery())
	):
		var gauge_max: float = float(context.get("gauge_max", GAUGE_MAX))
		var old_special_gauge: float = next_special_gauge
		next_special_gauge = min(gauge_max, next_special_gauge + STAGE1_BUTTERFLY_GAUGE_GAIN)
		if next_special_gauge > old_special_gauge:
			if feedback != null and feedback.has_method("trigger_gauge_flash"):
				feedback.trigger_gauge_flash()
			if audio != null and audio.has_method("play_item_get"):
				audio.play_item_get()
	if stage2_monkey_banana_result.has("special_gauge"):
		next_special_gauge = float(stage2_monkey_banana_result.get("special_gauge", next_special_gauge))
	var commando_firearm_gauge_gain: float = max(0.0, float(commando_firearm_result.get("commando_firearm_special_gauge_gain", 0.0)))
	if commando_firearm_gauge_gain > 0.0:
		var commando_gauge_max: float = max(1.0, float(context.get("gauge_max", GAUGE_MAX)))
		var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
		if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_gold_digger_gauge_bonus"):
			commando_firearm_gauge_gain = max(0.0, float(mythic_item_runtime.apply_gold_digger_gauge_bonus(commando_firearm_gauge_gain)))
		var old_special_gauge: float = next_special_gauge
		next_special_gauge = min(commando_gauge_max, next_special_gauge + commando_firearm_gauge_gain)
		commando_firearm_result["commando_firearm_special_gauge_gain_applied"] = next_special_gauge - old_special_gauge
		commando_firearm_result["commando_firearm_special_gauge_after"] = next_special_gauge
		if next_special_gauge > old_special_gauge and feedback != null and feedback.has_method("trigger_gauge_flash"):
			feedback.trigger_gauge_flash()

	var orb_hud_state = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		orb_hud_state.sync_gauge_spin(
			max(0, int(round(next_special_gauge))),
			now_msec
		)
		orb_hud_state.sync_dash_token_spin(
			max(0, int(dash_snapshot.get("tokens", 0))),
			now_msec
		)

	_update_actor_animation(delta, context, deps, dash_snapshot)

	var impact_effects = deps.get("impact_effects", null)
	if impact_effects != null:
		impact_effects.update(delta)

	var result := {
		"drive_text_timer_frames": drive_text_timer_frames,
		"special_gauge": next_special_gauge,
	}
	result.merge(stage2_monkey_banana_result, true)
	result.merge(stage3_boss_skill_result, true)
	result.merge(stage5_hongryun_result, true)
	result.merge(stage5_hongryun_fire_machine_result, true)
	result.merge(commando_firearm_result, true)
	result.merge(blacksmith_thor_shield_result, true)
	result["special_gauge"] = next_special_gauge
	return result


func _update_actor_animation(
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	dash_snapshot: Dictionary
) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	animation_state.update(delta, {
		"player_speed": float(context.get("player_speed", 0.0)),
		"dash_active": dash_snapshot.get("active", false),
		"player_has_sprite": bool(context.get("player_has_sprite", false)),
		"player_has_idle_sprite": bool(context.get("player_has_idle_sprite", false)),
		"player_sprite_frame_count": int(context.get("player_sprite_frame_count", 6)),
		"player_sprite_animation_speed": float(context.get("player_sprite_animation_speed", 0.10)),
		"player_has_hit_sprite": bool(context.get("player_has_attack_sheet", false)),
		"player_hit_frame_count": int(context.get("player_hit_frame_count", 4)),
		"player_hit_linear_frames": bool(context.get("player_hit_linear_frames", false)),
		"player_hit_anim_duration": float(context.get("player_hit_anim_duration", 0.36)),
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"ball_active": bool(context.get("ball_active", false)),
		"ball_impact_boost": float(context.get("ball_impact_boost", 1.0)),
		"ball_size": float(context.get("ball_size", 0.0)),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_paddle_size": _get_vector2(context, "player_paddle_size", Vector2.ZERO),
		"player_collision_cooldown": float(context.get("player_collision_cooldown", 0.0)),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_vel": float(context.get("boss_vel", 0.0)),
		"boss_has_sprite": bool(context.get("boss_has_sprite", false)),
		"boss_sprite_frame_count": int(context.get("boss_sprite_frame_count", 8)),
		"boss_sprite_animation_speed": float(context.get("boss_sprite_animation_speed", 0.10)),
		"boss_has_hit_sprite": bool(context.get("boss_has_hit_sprite", false)),
		"boss_hit_frame_count": int(context.get("boss_hit_frame_count", 8)),
		"boss_hit_frame_speed": float(context.get("boss_hit_frame_speed", 0.075)),
		"boss_collision_cooldown": float(context.get("boss_collision_cooldown", 0.0)),
		"boss_paddle_width": float(context.get("boss_paddle_width", 100.0)),
		"boss_hitbox_height": float(context.get("boss_hitbox_height", 40.0)),
	})


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _merge_score_context(context: Dictionary, score_state: Object) -> void:
	if score_state == null or not score_state.has_method("get_snapshot"):
		return
	var score_snapshot: Dictionary = score_state.get_snapshot()
	context["player_score"] = int(score_snapshot.get("player_score", 0))
	context["boss_score"] = int(score_snapshot.get("boss_score", 0))
	if score_state.has_method("is_player_in_danger"):
		context["player_in_danger"] = bool(score_state.is_player_in_danger())


func _is_dash_recovery_audio_active(dash_snapshot: Dictionary) -> bool:
	return (
		bool(dash_snapshot.get("recovering", false))
		or (
			not bool(dash_snapshot.get("active", false))
			and float(dash_snapshot.get("stun_timer", 0.0)) > 0.0
		)
	)


func _needs_effect_update(state: Object) -> bool:
	if state == null:
		return false
	if state.has_method("needs_effect_update"):
		return bool(state.needs_effect_update())
	if state.has_method("has_visible_effects"):
		return bool(state.has_visible_effects())
	return true


func _is_loop_audio_allowed(context: Dictionary, deps: Dictionary) -> bool:
	var scoreboard_state: Object = deps.get("scoreboard_state", null)
	if scoreboard_state != null and scoreboard_state.has_method("is_active") and bool(scoreboard_state.is_active()):
		return false
	if bool(context.get("waiting_for_serve", false)):
		return false
	return bool(context.get("ball_active", false))


func _is_smasher_context(context: Dictionary) -> bool:
	return str(context.get("selected_character_type", "smasher")).strip_edges().to_lower() == "smasher"


func _merge_active_item_boss_skill_pause(context: Dictionary, active_item_runtime: Object) -> void:
	if active_item_runtime == null or not active_item_runtime.has_method("get_boss_ai_context"):
		return
	var boss_context: Dictionary = active_item_runtime.get_boss_ai_context()
	for key in ["active_item_tear_gas_cooldown_pause_active", "active_item_boss_skill_cooldown_paused"]:
		if boss_context.has(key):
			context[key] = boss_context[key]


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
