extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneUpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")

var _callbacks: Object = BattleSceneUpdateCallbacks.new()


func update(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var flow_controller: Object = _get_instance(registry, "battle_frame_flow_controller")
	if flow_controller == null:
		return

	_callbacks.bind(owner, registry)
	flow_controller.update(delta, {
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"power_state": _get_instance(registry, "smasher_power_smash_state"),
		"round_state": _get_instance(registry, "round_flow_state"),
		"serve_flow_controller": _get_instance(registry, "serve_flow_controller"),
		"serve_context": _build_serve_context(owner),
	}, _callbacks.build_frame_callbacks(owner))
	_callbacks.clear()


func reset_ball(owner: Object, registry: Object) -> void:
	_callbacks.reset_ball(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _build_serve_context(owner: Object) -> Dictionary:
	return {
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
	}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
