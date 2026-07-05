extends RefCounted

const StageClearResultStatusBuilder := preload("res://scripts/ui/stage_clear_result_status_builder.gd")


static func get_interaction_status(scene: Object, dalji_dialogue: String) -> Dictionary:
	return StageClearResultStatusBuilder.build_scene_interaction_status(scene, dalji_dialogue)
