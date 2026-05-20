extends RefCounted

const BattleUpdateBossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BattleUpdatePlayerControlDepsBuilder := preload("res://scripts/core/battle_update_player_control_deps_builder.gd")

var player_control_deps_builder: Object = BattleUpdatePlayerControlDepsBuilder.new()
var boss_ai_context_builder: Object = BattleUpdateBossAiContextBuilder.new()

func build_player_control_config(character_type: String = "smasher") -> Dictionary:
	return player_control_deps_builder.build_config(character_type)


func build_player_control_deps(registry: Object, character_type: String = "smasher") -> Dictionary:
	return player_control_deps_builder.build_deps(registry, character_type)


func build_boss_ai_context(owner: Object, registry: Object) -> Dictionary:
	return boss_ai_context_builder.build_context(owner, registry)
