extends RefCounted

const BattleUpdateActorContext := preload("res://scripts/core/battle_update_actor_context.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var actor_context: Object = BattleUpdateActorContext.new()
var effects_context: Object = BattleUpdateEffectsContext.new()
var match_flow_context: Object = BattleUpdateMatchFlowContext.new()


func build_player_control_config(character_type: String = PlayerCharacterRuntime.SMASHER) -> Dictionary:
	return actor_context.build_player_control_config(character_type)


func build_player_control_deps(registry: Object, character_type: String = PlayerCharacterRuntime.SMASHER) -> Dictionary:
	return actor_context.build_player_control_deps(registry, character_type)


func build_boss_ai_context(owner: Object, registry: Object) -> Dictionary:
	return actor_context.build_boss_ai_context(owner, registry)


func build_effects_context(owner: Object, registry: Object) -> Dictionary:
	return effects_context.build_context(owner, registry)


func build_effects_deps(registry: Object, current_stage: int = 1, character_type: String = "") -> Dictionary:
	return effects_context.build_deps(registry, current_stage, character_type)


func build_match_flow_deps(
	registry: Object,
	current_stage: int = 1,
	perf_logger: Object = null,
	perf_label_prefix: String = "",
	include_all_stage_deps: bool = true,
	character_type: String = ""
) -> Dictionary:
	return match_flow_context.build_deps(
		registry,
		current_stage,
		perf_logger,
		perf_label_prefix,
		include_all_stage_deps,
		character_type
	)
