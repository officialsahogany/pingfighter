extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func update_effects(owner: Object, registry: Object, delta: float) -> void:
	var controller: Object = _get_instance(registry, "battle_effects_update_controller")
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if owner == null or controller == null or context_builder == null:
		return

	var result: Dictionary = controller.update(
		delta,
		context_builder.build_effects_context(owner, registry),
		context_builder.build_effects_deps(registry)
	)
	owner.set("drive_text_timer_frames", float(result.get(
		"drive_text_timer_frames",
		_get_owner_value(owner, "drive_text_timer_frames", 0.0)
	)))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
