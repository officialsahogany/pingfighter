extends RefCounted

const BattleUpdateMatchItemRuntimeDepsBuilder := preload("res://scripts/core/battle_update_match_item_runtime_deps_builder.gd")
const BattleUpdateMatchPlayerSkillDepsBuilder := preload("res://scripts/core/battle_update_match_player_skill_deps_builder.gd")
const BattleUpdateMatchStageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_match_stage_runtime_deps_builder.gd")
const BattleUpdateMatchStateDepsBuilder := preload("res://scripts/core/battle_update_match_state_deps_builder.gd")

var item_runtime_deps_builder: Object = BattleUpdateMatchItemRuntimeDepsBuilder.new()
var player_skill_deps_builder: Object = BattleUpdateMatchPlayerSkillDepsBuilder.new()
var stage_runtime_deps_builder: Object = BattleUpdateMatchStageRuntimeDepsBuilder.new()
var match_state_deps_builder: Object = BattleUpdateMatchStateDepsBuilder.new()


func build_match_state_deps(registry: Object) -> Dictionary:
	return match_state_deps_builder.build_deps(registry)


func build_item_runtime_deps(registry: Object) -> Dictionary:
	return item_runtime_deps_builder.build_deps(registry)


func build_player_skill_runtime_deps(registry: Object) -> Dictionary:
	return player_skill_deps_builder.build_deps(registry)


func build_stage_runtime_deps(
	registry: Object,
	current_stage: int = 1,
	include_all_stages: bool = true
) -> Dictionary:
	return stage_runtime_deps_builder.build_deps(registry, current_stage, include_all_stages)
