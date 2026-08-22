extends RefCounted

## Owns synchronous cross-owner handoffs only. Producer state/timing stays in
## Tail Whip and Kuromi eating; this coordinator preserves consumer order.

var _prism_burst_state: Object
var _starpoint_state: Object
var _kuromi_eating_state: Object


func _init(prism_burst_state: Object, starpoint_state: Object, kuromi_eating_state: Object) -> void:
	_prism_burst_state = prism_burst_state
	_starpoint_state = starpoint_state
	_kuromi_eating_state = kuromi_eating_state


func apply_tail_hit_event(tail_hit_event: Dictionary, deps: Dictionary, context: Dictionary) -> bool:
	if tail_hit_event.is_empty():
		return false
	var ball_pos: Vector2 = _as_vector2(tail_hit_event.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	_prism_burst_state.spawn(ball_pos, true)
	_create_ball_impact_effect(ball_pos, deps)
	_starpoint_state.spawn_tail_drop(ball_pos, deps, context)
	_play_audio(deps, "play_stage3_tail")
	return true


func consume_kuromi_prism_request() -> bool:
	var prism_burst_pos: Variant = _kuromi_eating_state.consume_prism_burst_request()
	if not prism_burst_pos is Vector2:
		return false
	_prism_burst_state.spawn(prism_burst_pos)
	return true


func _create_ball_impact_effect(pos: Vector2, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 1.0, 1.0)


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
