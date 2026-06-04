extends RefCounted


func reset_round_wait(deps: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if round_state != null:
		round_state.reset_round_wait()


func reset_actor_round_state(deps: Dictionary) -> void:
	var ai_state = deps.get("ai_state", null)
	if ai_state != null:
		ai_state.reset()

	var animation_state = deps.get("animation_state", null)
	if animation_state != null:
		animation_state.reset()

	var movement_state = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("reset"):
		movement_state.reset()

	var dash_state = deps.get("dash_state", null)
	if dash_state != null:
		dash_state.reset_round()

	var active_item_runtime = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("reset_round"):
		active_item_runtime.reset_round()

	var viper_skill_runtime = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime != null and viper_skill_runtime.has_method("reset_round"):
		viper_skill_runtime.reset_round(deps)

	var viper_jetpack_state = deps.get("viper_jetpack_state", null)
	if viper_jetpack_state != null and viper_jetpack_state.has_method("reset_round"):
		viper_jetpack_state.reset_round(deps)

	var commando_firearm_runtime = deps.get("commando_firearm_runtime", null)
	if commando_firearm_runtime != null and commando_firearm_runtime.has_method("reset_round"):
		commando_firearm_runtime.reset_round(deps)

	var commando_supply_drop_state = deps.get("commando_supply_drop_state", null)
	if commando_supply_drop_state != null and commando_supply_drop_state.has_method("reset_round"):
		commando_supply_drop_state.reset_round(deps)

	var commando_weapon_controller = deps.get("commando_weapon_controller", null)
	if commando_weapon_controller != null and commando_weapon_controller.has_method("reset_round"):
		commando_weapon_controller.reset_round()

	var blacksmith_shield_state = deps.get("blacksmith_thor_shield_state", null)
	if blacksmith_shield_state != null and blacksmith_shield_state.has_method("reset_round"):
		blacksmith_shield_state.reset_round(deps)

	var lingpet_runtime = deps.get("lingpet_egg_runtime", null)
	if lingpet_runtime != null and lingpet_runtime.has_method("reset_round"):
		lingpet_runtime.reset_round(deps)

	var feedback = deps.get("feedback", null)
	if feedback != null:
		var dash_token_max: int = _get_dash_token_max(dash_state)
		feedback.reset_round(dash_token_max)

	var whip_state = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("reset_round"):
		whip_state.reset_round()

	var spinning_top_state = deps.get("stage1_dalji_spinning_top_skill_state", null)
	if spinning_top_state != null and spinning_top_state.has_method("reset_round"):
		spinning_top_state.reset_round()

	var dalji_cooldown_state = deps.get("stage1_dalji_boss_skill_cooldown_state", null)
	if dalji_cooldown_state != null and dalji_cooldown_state.has_method("reset_round"):
		dalji_cooldown_state.reset_round()

	var stage2_boss_skill_state = deps.get("stage2_boss_skill_state", null)
	if stage2_boss_skill_state != null and stage2_boss_skill_state.has_method("reset_round"):
		stage2_boss_skill_state.reset_round()

	var stage2_background = deps.get("stage2_pillar_background", null)
	if stage2_background != null and stage2_background.has_method("reset_round"):
		stage2_background.reset_round(deps)

	var stage3_boss_skill_state = deps.get("stage3_boss_skill_state", null)
	if stage3_boss_skill_state != null and stage3_boss_skill_state.has_method("reset_round"):
		stage3_boss_skill_state.reset_round()

	var stage4_ponk_skill_state = deps.get("stage4_ponk_skill_state", null)
	if stage4_ponk_skill_state != null and stage4_ponk_skill_state.has_method("reset_round"):
		stage4_ponk_skill_state.reset_round(deps)

	var stage5_hongryun_state = deps.get("stage5_hongryun_state", null)
	if stage5_hongryun_state != null and stage5_hongryun_state.has_method("reset_round"):
		stage5_hongryun_state.reset_round()

	var stage5_hongryun_actor_renderer = deps.get("stage5_hongryun_actor_renderer", null)
	_reset_stage5_hongryun_round_fx(stage5_hongryun_actor_renderer)

	if stage2_background != null and stage2_background.has_method("start_boss_rage_animation"):
		stage2_background.start_boss_rage_animation(deps)

	var audio = deps.get("audio", null)
	if audio != null and audio.has_method("stop_stage2_quake_loop"):
		audio.stop_stage2_quake_loop()
	if audio != null and audio.has_method("stop_stage3_psychoball_loop"):
		audio.stop_stage3_psychoball_loop()
	if audio != null and audio.has_method("stop_stage5_hongryun_charge"):
		audio.stop_stage5_hongryun_charge()
	if audio != null and audio.has_method("stop_commando_supply_radio_loop"):
		audio.stop_commando_supply_radio_loop()
	if audio != null and audio.has_method("stop_commando_supply_aircraft_loop"):
		audio.stop_commando_supply_aircraft_loop()


func _get_dash_token_max(dash_state) -> int:
	if dash_state == null:
		return 1
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	return int(dash_snapshot.get("max_tokens", 1))


func _reset_stage5_hongryun_round_fx(actor_renderer: Object) -> void:
	if actor_renderer == null:
		return
	if actor_renderer.has_method("reset_round_fx"):
		actor_renderer.reset_round_fx()
	elif actor_renderer.has_method("reset"):
		actor_renderer.reset()
