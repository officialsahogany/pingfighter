extends RefCounted

const StageClearResultSceneFieldApplier := preload("res://scripts/ui/stage_clear_result_scene_field_applier.gd")


static func apply_scene_apply_result(scene: Object, apply_result: Dictionary) -> void:
	if scene == null:
		return
	var field_name_lookup: Dictionary = _get_scene_dictionary(scene, &"_scene_field_name_lookup")
	StageClearResultSceneFieldApplier.apply_from_result(
		scene,
		apply_result,
		field_name_lookup,
		"StageClearResultScene"
	)


static func _get_scene_dictionary(scene: Object, field_name: StringName) -> Dictionary:
	if scene == null:
		return {}
	var value: Variant = scene.get(field_name)
	return value if value is Dictionary else {}
