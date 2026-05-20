extends RefCounted

const BattleUpdateStageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_stage_runtime_deps_builder.gd")

var stage_runtime_deps_builder: Object = BattleUpdateStageRuntimeDepsBuilder.new()


func build_deps(registry: Object, current_stage: int = 1) -> Dictionary:
	return stage_runtime_deps_builder.build_deps(registry, current_stage, true)
