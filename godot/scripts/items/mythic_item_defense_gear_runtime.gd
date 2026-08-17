extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SPIKEBOOTS := "spikeboots"
const ITEM_BULLETPROOF_HAT := "bulletproof_hat"
const ITEM_SPIKED_HELMET := "spiked_helmet"


func is_spikeboots_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_SPIKEBOOTS)


func get_spikeboots_dash_afterdelay_reduction_pct(runtime: Object) -> float:
	if not runtime.equipped_items.has(ITEM_SPIKEBOOTS):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SPIKEBOOTS, "dash_afterdelay_pct"), 0.0, 95.0)


func get_spikeboots_dash_cooldown_reduction_pct(runtime: Object) -> float:
	if not runtime.equipped_items.has(ITEM_SPIKEBOOTS):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SPIKEBOOTS, "dash_cooldown_pct"), 0.0, 95.0)


func get_dash_recovery_frames(runtime: Object, base_frames: float) -> float:
	var reduction_pct: float = get_spikeboots_dash_afterdelay_reduction_pct(runtime)
	return max(1.0, float(base_frames) * max(0.0, 1.0 - reduction_pct / 100.0))


func get_dash_recharge_frames(runtime: Object, base_frames: float) -> float:
	var reduction_pct: float = get_spikeboots_dash_cooldown_reduction_pct(runtime)
	return max(1.0, float(base_frames) * max(0.0, 1.0 - reduction_pct / 100.0))


func is_bulletproof_hat_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_BULLETPROOF_HAT)


func get_bulletproof_hat_stun_resist_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return get_player_posture_correction_pct(runtime)
	if not runtime.equipped_items.has(ITEM_BULLETPROOF_HAT):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_BULLETPROOF_HAT, "stun_resist_pct"), 0.0, 100.0)


func get_player_stun_resist_pct(runtime: Object) -> float:
	return get_bulletproof_hat_stun_resist_pct(runtime)


func get_player_stun_duration_seconds(runtime: Object, base_seconds: float) -> float:
	var resist_scale: float = max(0.0, 1.0 - get_player_stun_resist_pct(runtime) / 100.0)
	return max(0.0, float(base_seconds) * resist_scale)


func is_spiked_helmet_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_SPIKED_HELMET)


func get_spiked_helmet_knockback_resist_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return get_player_posture_correction_pct(runtime)
	if not runtime.equipped_items.has(ITEM_SPIKED_HELMET):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SPIKED_HELMET, "knockback_resist_pct"), 0.0, 100.0)


func get_player_knockback_resist_pct(runtime: Object) -> float:
	return get_spiked_helmet_knockback_resist_pct(runtime)


func get_player_knockback_resist_scale(runtime: Object) -> float:
	return max(0.0, 1.0 - get_player_knockback_resist_pct(runtime) / 100.0)


func get_player_posture_correction_pct(runtime: Object) -> float:
	if not PerkConversionFlags.is_enabled():
		return 0.0
	return _get_converted_perk_value(runtime, ITEM_BULLETPROOF_HAT, "posture_correction_pct")


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var runtime_state: Object = runtime.runtime_perk_state_ref if runtime != null else null
	if runtime_state != null and runtime_state.has_method("get_converted_perk_option_value"):
		return float(runtime_state.get_converted_perk_option_value(perk_id, key))
	var level := 0
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		level = max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime_state)
