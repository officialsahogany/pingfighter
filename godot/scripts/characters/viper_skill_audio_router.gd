extends RefCounted


func play_chaos_windup_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_chaos_spear_windup"):
		audio.play_chaos_spear_windup()


func stop_chaos_windup_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_chaos_spear_windup"):
		audio.stop_chaos_spear_windup()


func play_chaos_flying_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_chaos_spear_flying"):
		audio.play_chaos_spear_flying()


func stop_chaos_flying_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_chaos_spear_flying"):
		audio.stop_chaos_spear_flying()


func play_chaos_impact_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_chaos_spear_impact"):
		audio.play_chaos_spear_impact()


func stop_chaos_impact_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_chaos_spear_impact"):
		audio.stop_chaos_spear_impact()


func play_chaos_blackhole_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_chaos_spear_blackhole_loop"):
		audio.play_chaos_spear_blackhole_loop()


func stop_chaos_blackhole_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_chaos_spear_blackhole_loop"):
		audio.stop_chaos_spear_blackhole_loop()


func stop_chaos_phase_sounds(deps: Dictionary) -> void:
	stop_chaos_windup_sound(deps)
	stop_chaos_flying_sound(deps)
	stop_chaos_impact_sound(deps)


func stop_all_chaos_spear_sounds(deps: Dictionary) -> void:
	stop_chaos_phase_sounds(deps)
	stop_chaos_blackhole_sound(deps)


func play_core_flip_spin_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_blade_spin"):
		audio.play_viper_blade_spin()


func play_core_flip_kick_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_hwarang_kick"):
		audio.play_viper_hwarang_kick()
	elif audio.has_method("play_viper_marshal_kick"):
		audio.play_viper_marshal_kick()
	elif audio.has_method("play_viper_backstep"):
		audio.play_viper_backstep()


func play_shadow_step_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_backstep"):
		audio.play_viper_backstep()
	elif audio.has_method("play_dash_start"):
		audio.play_dash_start(true)
	if audio.has_method("stop_dash_delay"):
		audio.stop_dash_delay()


func play_shadow_kick_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_shadow_kick"):
		audio.play_viper_shadow_kick()


func play_marshal_backstep_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_backstep"):
		audio.play_viper_backstep()
	elif audio.has_method("play_dash_start"):
		audio.play_dash_start(true)


func play_marshal_charge_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_marshal_kick"):
		audio.play_viper_marshal_kick()
	elif audio.has_method("play_viper_shadow_kick"):
		audio.play_viper_shadow_kick()


func play_phantom_show_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_phantom_show"):
		audio.play_viper_phantom_show()


func play_phantom_hit_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_phantom_kick_hit"):
		audio.play_viper_phantom_kick_hit()


func play_ignition_aura_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_ignition_aura"):
		audio.play_viper_ignition_aura()
	elif audio.has_method("play_viper_dive_strike"):
		audio.play_viper_dive_strike()
	elif audio.has_method("play_viper_marshal_kick"):
		audio.play_viper_marshal_kick()


func play_dive_prep_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_dive_prep"):
		audio.play_viper_dive_prep()


func play_dive_strike_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_dive_strike"):
		audio.play_viper_dive_strike()


func play_nerve_strike_moving_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_venom_moving"):
		audio.play_viper_venom_moving()


func play_nerve_strike_attack_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_venom_attack"):
		audio.play_viper_venom_attack()


func play_blade_fire_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_blade"):
		audio.play_viper_blade()


func stop_blade_spin_sound(runtime: Object, deps: Dictionary = {}) -> void:
	if not runtime.blade_spin_sound_active:
		return
	var audio: Object = deps.get("audio", null)
	if audio == null:
		audio = runtime.blade_spin_audio
	if audio != null and is_instance_valid(audio) and audio.has_method("stop_viper_blade_spin"):
		audio.stop_viper_blade_spin()
	runtime.blade_spin_sound_active = false
	runtime.blade_spin_audio = null


func play_kick_guard_knockback_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_viper_kick_guard_knockback"):
		audio.play_viper_kick_guard_knockback()
	elif audio.has_method("play_stage2_speed_defense_hit"):
		audio.play_stage2_speed_defense_hit()


func play_dual_glitch_windup_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_dual_glitch_windup"):
		audio.play_viper_dual_glitch_windup()


func stop_dual_glitch_windup_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_viper_dual_glitch_windup"):
		audio.stop_viper_dual_glitch_windup()


func play_dual_glitch_split_sound(deps: Dictionary) -> void:
	# 분신이 갈라져 분리되는 순간: windup(dualglitch1) 정지 후 split(dualglitch2) 1회 재생.
	stop_dual_glitch_windup_sound(deps)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_dual_glitch_split"):
		audio.play_viper_dual_glitch_split()
