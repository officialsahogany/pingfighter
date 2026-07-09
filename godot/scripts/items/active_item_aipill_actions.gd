extends RefCounted

const ActiveItemAipillBehavior := preload("res://scripts/items/active_item_aipill_behavior.gd")
const ActiveItemAipillRuntime := preload("res://scripts/items/active_item_aipill_runtime.gd")

var _behavior: Object = ActiveItemAipillBehavior.new()
var _runtime: Object = ActiveItemAipillRuntime.new()


func activate(target: Object, registry: Object, state_applier: Object, effect_feedback: Object) -> bool:
	state_applier.apply_aipill_state(target, _runtime.start_state())
	effect_feedback.trigger_registry_feedback(registry, true, false, 0.035, 1.1)
	effect_feedback.play_first_audio(registry, ["play_active_item"])
	return true


func apply_player_control(active: bool, player_pos: Vector2, config: Dictionary, delta: float) -> Dictionary:
	return _behavior.apply_player_control(active, player_pos, config, delta)


func apply_guard_drain(
	target: Object,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary,
	active: bool,
	phase: float,
	state_applier: Object,
	effect_feedback: Object
) -> float:
	var result: Dictionary = _behavior.build_guard_drain_result(
		active,
		special_gauge,
		context,
		_get_neural_helmet_gauge_reduction(deps, context)
	)
	if bool(result.get("flash", false)):
		state_applier.apply_aipill_state(target, _runtime.flash_state(active, phase))
	if bool(result.get("feedback", false)):
		effect_feedback.trigger_feedback_state(deps.get("feedback", null), true, false, 0.025, 0.9)
	if bool(result.get("clear_aipill", false)):
		state_applier.apply_aipill_state(target, _runtime.clear_state())
	return float(result.get("special_gauge", special_gauge))


func apply_ball_hit_speed_boost(active: bool, ball_vel: Vector2) -> Dictionary:
	return _behavior.build_ball_hit_speed_boost_result(active, ball_vel)


func _get_neural_helmet_gauge_reduction(deps: Dictionary, context: Dictionary) -> float:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_neural_helmet_aipill_gauge_reduction"):
		return max(0.0, float(mythic_item_runtime.get_neural_helmet_aipill_gauge_reduction()))
	if context.has("neural_helmet_aipill_gauge_reduction"):
		return max(0.0, float(context.get("neural_helmet_aipill_gauge_reduction", 0.0)))
	return 0.0
