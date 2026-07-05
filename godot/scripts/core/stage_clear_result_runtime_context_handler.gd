extends RefCounted

const StageClearResultRuntimeContextData := preload("res://scripts/core/stage_clear_result_runtime_context_data.gd")


func get_score_snapshot(registry: Object) -> Dictionary:
	return StageClearResultRuntimeContextData.get_score_snapshot(registry)


func get_current_stage(owner: Object) -> int:
	return StageClearResultRuntimeContextData.get_current_stage(owner)


func get_selected_character_type(owner: Object) -> String:
	return StageClearResultRuntimeContextData.get_selected_character_type(owner)


func get_result_victory_character_type(owner: Object) -> String:
	return StageClearResultRuntimeContextData.get_result_victory_character_type(owner)


func get_instance(registry: Object, key: String) -> Object:
	return StageClearResultRuntimeContextData.get_instance(registry, key)


func reset_stage_for_result(registry: Object, stage_id: int) -> void:
	StageClearResultRuntimeContextData.reset_stage_for_result(registry, stage_id)


func reset_stage4_for_result(registry: Object, stage_id: int) -> void:
	StageClearResultRuntimeContextData.reset_stage4_for_result(registry, stage_id)


func reset_stage5_for_result(registry: Object, stage_id: int) -> void:
	StageClearResultRuntimeContextData.reset_stage5_for_result(registry, stage_id)


func reset_stage6_for_result(registry: Object, stage_id: int) -> void:
	StageClearResultRuntimeContextData.reset_stage6_for_result(registry, stage_id)
