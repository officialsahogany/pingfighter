extends RefCounted

const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var deps_groups: Object = BattleUpdateMatchFlowDepsGroups.new()


func build_deps(registry: Object, current_stage: int = 1) -> Dictionary:
	var deps := {}
	deps.merge(deps_groups.build_match_state_deps(registry), true)
	deps.merge(deps_groups.build_item_runtime_deps(registry), true)
	deps.merge(deps_groups.build_player_skill_runtime_deps(registry), true)
	deps.merge(deps_groups.build_stage_runtime_deps(registry, current_stage), true)
	return deps
