extends RefCounted

const DefeatContinueVisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")

const EVENT_NONE := 0
const EVENT_CONSUME_REQUEST := 1
const EVENT_SHATTER_SFX := 2
const EVENT_CONTINUE_RESET := 4

enum Phase {
	PRESENT,
	CONSUMING,
}

var phase: int = Phase.PRESENT
var confirm_elapsed: float = 0.0
var post_consume_remaining_gems: int = 0

var _consume_event_fired: bool = false
var _shatter_sfx_fired: bool = false
var _continue_reset_fired: bool = false
var _reset_fired_this_step: bool = false


func reset(current_remaining_gems: int = 0) -> void:
	phase = Phase.PRESENT
	confirm_elapsed = 0.0
	post_consume_remaining_gems = maxi(0, current_remaining_gems - 1)
	_consume_event_fired = false
	_shatter_sfx_fired = false
	_continue_reset_fired = false
	_reset_fired_this_step = false


func begin_consuming() -> int:
	if phase != Phase.PRESENT or _consume_event_fired:
		return EVENT_NONE
	phase = Phase.CONSUMING
	confirm_elapsed = 0.0
	_consume_event_fired = true
	return EVENT_CONSUME_REQUEST


func set_post_consume_remaining(value: int, max_gems: int) -> void:
	post_consume_remaining_gems = clampi(value, 0, maxi(0, max_gems))


func advance(delta: float) -> int:
	_reset_fired_this_step = false
	if not is_consuming():
		return EVENT_NONE
	confirm_elapsed += maxf(0.0, delta)
	var events := EVENT_NONE
	if not _shatter_sfx_fired and has_shatter_started():
		_shatter_sfx_fired = true
		events |= EVENT_SHATTER_SFX
	if not _continue_reset_fired and confirm_elapsed >= DefeatContinueVisualProjection.CONFIRM_RESET_TIME_SEC:
		_continue_reset_fired = true
		_reset_fired_this_step = true
		confirm_elapsed = DefeatContinueVisualProjection.CONFIRM_RESET_TIME_SEC
		events |= EVENT_CONTINUE_RESET
	return events


func is_present() -> bool:
	return phase == Phase.PRESENT


func is_consuming() -> bool:
	return phase == Phase.CONSUMING


func has_reset_fired() -> bool:
	return _continue_reset_fired


func should_update_revival() -> bool:
	return _continue_reset_fired and not _reset_fired_this_step


func should_close(revival_active: bool) -> bool:
	return (
		_continue_reset_fired
		and not _reset_fired_this_step
		and confirm_elapsed >= DefeatContinueVisualProjection.CONFIRM_FADEBACK_END_SEC
		and not revival_active
	)


func get_visual_remaining_gems(current_remaining_gems: int) -> int:
	return DefeatContinueVisualProjection.get_visual_remaining_gems(
		is_consuming(),
		has_shatter_started(),
		current_remaining_gems,
		post_consume_remaining_gems
	)


func get_breaking_gem_index(max_gems: int, current_remaining_gems: int) -> int:
	return DefeatContinueVisualProjection.get_breaking_gem_index(
		is_consuming(),
		_continue_reset_fired,
		max_gems,
		current_remaining_gems
	)


func has_shatter_started() -> bool:
	return DefeatContinueVisualProjection.has_shatter_started(is_consuming(), confirm_elapsed)


func has_shatter_completed() -> bool:
	return DefeatContinueVisualProjection.has_shatter_completed(is_consuming(), confirm_elapsed)


func is_shatter_window_active() -> bool:
	return DefeatContinueVisualProjection.is_shatter_window_active(is_consuming(), confirm_elapsed)


func get_shatter_progress() -> float:
	return DefeatContinueVisualProjection.get_shatter_progress(is_consuming(), confirm_elapsed)


func get_confirm_shake_offset(index: int, breaking_index: int) -> Vector2:
	return DefeatContinueVisualProjection.get_confirm_shake_offset(
		is_consuming(),
		confirm_elapsed,
		index,
		breaking_index
	)


func get_pre_shatter_charge() -> float:
	return DefeatContinueVisualProjection.get_pre_shatter_charge(is_consuming(), confirm_elapsed)


func get_pre_shatter_crack() -> float:
	return DefeatContinueVisualProjection.get_pre_shatter_crack(is_consuming(), confirm_elapsed)


func get_impact_flash_alpha() -> float:
	return DefeatContinueVisualProjection.get_impact_flash_alpha(is_consuming(), confirm_elapsed)


func get_impact_ring_progress() -> float:
	return DefeatContinueVisualProjection.get_impact_ring_progress(is_consuming(), confirm_elapsed)


func get_impact_ring_alpha() -> float:
	return DefeatContinueVisualProjection.get_impact_ring_alpha(is_consuming(), confirm_elapsed)


func get_light_beam_alpha() -> float:
	return DefeatContinueVisualProjection.get_light_beam_alpha(is_consuming(), confirm_elapsed)


func get_chroma_split_strength() -> float:
	return DefeatContinueVisualProjection.get_chroma_split_strength(is_consuming(), confirm_elapsed)


func get_impact_shake_offset() -> Vector2:
	return DefeatContinueVisualProjection.get_impact_shake_offset(is_consuming(), confirm_elapsed)


func get_whiteout_alpha() -> float:
	return DefeatContinueVisualProjection.get_whiteout_alpha(is_consuming(), confirm_elapsed)
