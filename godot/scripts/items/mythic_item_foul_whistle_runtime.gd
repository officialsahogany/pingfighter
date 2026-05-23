extends RefCounted

const ITEM_FOUL_WHISTLE := "foul_whistle"
const TOTAL_FRAMES := 120.0
const RESET_FRAME := 70.0
const REFEREE_FRAME_COUNT := 4
const REFEREE_FRAME_FRAMES := 6.0


func is_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_FOUL_WHISTLE)


func is_active(runtime: Object) -> bool:
	return is_equipped(runtime)


func get_negate_chance_pct(runtime: Object) -> float:
	if not is_equipped(runtime):
		return 0.0
	return clamp(runtime._get_equipped_roll_sum(ITEM_FOUL_WHISTLE, "negate_chance_pct"), 0.0, 100.0)


func get_negate_chance(runtime: Object) -> float:
	return get_negate_chance_pct(runtime) / 100.0


func try_trigger(runtime: Object, loss_type: String = "round", audio_source: Variant = null) -> bool:
	if not is_equipped(runtime) or runtime.foul_whistle_state.animation_active:
		return false
	var chance: float = get_negate_chance(runtime)
	if chance <= 0.0 or randf() >= chance:
		return false
	runtime.foul_whistle_state.start(loss_type)
	runtime._play_foul_whistle_audio(audio_source)
	return true


func consume_reset_ready(runtime: Object) -> bool:
	return runtime.foul_whistle_state.consume_reset_ready()


func is_effect_active(runtime: Object) -> bool:
	return runtime.foul_whistle_state.animation_active


func clear_runtime(runtime: Object) -> void:
	runtime.foul_whistle_state.clear()


func update_runtime(runtime: Object, fps_scale: float) -> void:
	runtime.foul_whistle_state.update(fps_scale, RESET_FRAME, TOTAL_FRAMES)
