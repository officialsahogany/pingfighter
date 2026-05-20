extends RefCounted

const ActiveItemTimedPaddleEffects := preload("res://scripts/items/active_item_timed_paddle_effects.gd")
const ActiveItemDurationBonus := preload("res://scripts/items/active_item_duration_bonus.gd")

var _timed_effects: Object = ActiveItemTimedPaddleEffects.new()
var _duration_bonus: Object = ActiveItemDurationBonus.new()


func activate_vitamin_pill(
	target: Object,
	registry: Object,
	active: bool,
	player_center: Vector2,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	if active:
		return false

	state_applier.apply_vitamin_pill_state(target, _timed_effects.start_vitamin_pill(
		player_center,
		_duration_bonus.get_multiplier(registry)
	))
	effect_feedback.trigger_registry_feedback(registry, true, false, 0.025, 0.9)
	effect_feedback.play_first_audio(registry, ["play_drink", "play_active_item"])
	return true


func activate_strange_vial(
	target: Object,
	owner: Object,
	registry: Object,
	active: bool,
	player_center: Vector2,
	enlarge: bool,
	state_applier: Object,
	paddle_sync: Object,
	effect_feedback: Object
) -> bool:
	if active:
		state_applier.apply_strange_vial_state(target, _timed_effects.clear_strange_vial())

	state_applier.apply_strange_vial_state(target, _timed_effects.start_strange_vial(
		enlarge,
		player_center,
		_duration_bonus.get_multiplier(registry)
	))
	_sync_owner_state(target, owner, registry, paddle_sync)
	effect_feedback.trigger_registry_feedback(registry, true, false, 0.032, 1.05)
	effect_feedback.play_first_audio(registry, ["play_drink", "play_active_item"])
	return true


func activate_long_boost(
	target: Object,
	owner: Object,
	registry: Object,
	active: bool,
	state_applier: Object,
	paddle_sync: Object,
	effect_feedback: Object
) -> bool:
	if active:
		return false

	state_applier.apply_long_boost_state(target, _timed_effects.start_long_boost(
		_duration_bonus.get_multiplier(registry)
	))
	_sync_owner_state(target, owner, registry, paddle_sync)
	effect_feedback.play_first_audio(registry, ["play_active_item", "play_drink"])
	return true


func _sync_owner_state(
	target: Object,
	owner: Object,
	registry: Object,
	paddle_sync: Object
) -> void:
	var active_item_scale: float = paddle_sync.get_player_paddle_scale(
		float(target.get("long_boost_scale")),
		float(target.get("strange_vial_scale"))
	)
	paddle_sync.sync_owner_state(
		owner,
		active_item_scale,
		_get_instance(registry, "smasher_warp_gate_state"),
		_get_instance(registry, "mythic_item_runtime")
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
