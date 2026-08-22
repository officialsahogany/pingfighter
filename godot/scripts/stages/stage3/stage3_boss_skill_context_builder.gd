extends RefCounted

# Read-only Stage 3 actor and diagnostic context projection.
#
# Focused owners decide whether their arrays are borrowed or copied. This
# builder preserves that contract, the established merge precedence, and the
# exact diagnostic fields without allocating an owner list in the draw path.

var _prism_burst_state: Object
var _kuromi_awakening_state: Object
var _tear_shower_state: Object
var _curse_chest_state: Object
var _psychoball_state: Object
var _tail_whip_state: Object
var _kuromi_eating_state: Object
var _starpoint_state: Object


func _init(
	prism_burst_state: Object,
	kuromi_awakening_state: Object,
	tear_shower_state: Object,
	curse_chest_state: Object,
	psychoball_state: Object,
	tail_whip_state: Object,
	kuromi_eating_state: Object,
	starpoint_state: Object
) -> void:
	_prism_burst_state = prism_burst_state
	_kuromi_awakening_state = kuromi_awakening_state
	_tear_shower_state = tear_shower_state
	_curse_chest_state = curse_chest_state
	_psychoball_state = psychoball_state
	_tail_whip_state = tail_whip_state
	_kuromi_eating_state = kuromi_eating_state
	_starpoint_state = starpoint_state


func build_actor_draw_context(
	boss_special_gauge: float,
	boss_special_ready: bool,
	boss_red_intensity: float,
	copy_arrays: bool = false
) -> Dictionary:
	var context := {
		"stage3_boss_special_gauge": boss_special_gauge,
		"stage3_boss_special_ready": boss_special_ready,
		"stage3_boss_red_ratio": clamp(boss_red_intensity / 220.0, 0.0, 1.0),
	}
	context.merge(_prism_burst_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_kuromi_awakening_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_tear_shower_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_curse_chest_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_psychoball_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_tail_whip_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_kuromi_eating_state.get_actor_draw_context(copy_arrays), true)
	context.merge(_starpoint_state.get_actor_draw_context(copy_arrays), true)
	return context


func build_snapshot(
	status: String,
	boss_special_gauge: float,
	boss_special_ready: bool,
	boss_red_intensity: float
) -> Dictionary:
	var snapshot := build_actor_draw_context(
		boss_special_gauge,
		boss_special_ready,
		boss_red_intensity,
		true
	)
	snapshot["status"] = status
	snapshot["boss_special_gauge"] = boss_special_gauge
	snapshot["boss_special_ready"] = boss_special_ready
	snapshot["psycho_cooldown"] = float(_psychoball_state.psycho_cooldown)
	snapshot["psychoball_hitstop_timer"] = float(_psychoball_state.psychoball_hitstop_timer)
	snapshot["tears_cooldown"] = float(_tear_shower_state.tears_cooldown)
	snapshot["curse_cooldown"] = float(_curse_chest_state.curse_cooldown)
	snapshot["tail_cooldown"] = float(_tail_whip_state.tail_whip_cooldown)
	return snapshot
