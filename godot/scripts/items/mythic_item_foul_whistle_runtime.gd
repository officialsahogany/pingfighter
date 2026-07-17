extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_FOUL_WHISTLE := "foul_whistle"
const TOTAL_FRAMES := 120.0
const RESET_FRAME := 70.0
const REFEREE_FRAME_COUNT := 4
const REFEREE_FRAME_FRAMES := 6.0


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_FOUL_WHISTLE)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_FOUL_WHISTLE) > 0
	return is_equipped(runtime)


func get_negate_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_FOUL_WHISTLE, "negate_chance_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_FOUL_WHISTLE, "negate_chance_pct"), 0.0, 100.0)


func get_negate_chance(runtime: Object) -> float:
	return get_negate_chance_pct(runtime) / 100.0


func try_trigger(runtime: Object, loss_type: String = "round", audio_source: Variant = null) -> bool:
	if not is_active(runtime) or runtime.foul_whistle_state.animation_active:
		return false
	var chance: float = get_negate_chance(runtime)
	if chance <= 0.0 or randf() >= chance:
		return false
	runtime.foul_whistle_state.start(loss_type)
	runtime.audio_router.play_foul_whistle_audio(runtime, audio_source)
	return true


func consume_reset_ready(runtime: Object) -> bool:
	return runtime.foul_whistle_state.consume_reset_ready()


func is_effect_active(runtime: Object) -> bool:
	return runtime.foul_whistle_state.animation_active


func clear_runtime(runtime: Object) -> void:
	runtime.foul_whistle_state.clear()


func update_runtime(runtime: Object, fps_scale: float) -> void:
	runtime.foul_whistle_state.update(fps_scale, RESET_FRAME, TOTAL_FRAMES)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime.runtime_perk_state_ref if runtime != null else null)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
