extends RefCounted

const BattleUpdateStageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_stage_runtime_deps_builder.gd")

var stage_runtime_deps_builder: Object = BattleUpdateStageRuntimeDepsBuilder.new()


func build_deps(registry: Object, current_stage: int = 1, include_all_stages: bool = true) -> Dictionary:
	var deps: Dictionary = stage_runtime_deps_builder.build_deps(registry, current_stage, include_all_stages)
	if include_all_stages or current_stage == 5:
		deps["stage5_hongryun_actor_renderer"] = _get_instance(registry, "stage5_hongryun_actor_renderer")
	return deps


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
