extends RefCounted

const BattleUpdateEffectsCharacterDepsBuilder := preload("res://scripts/core/battle_update_effects_character_deps_builder.gd")
const BattleUpdateEffectsCoreDepsBuilder := preload("res://scripts/core/battle_update_effects_core_deps_builder.gd")
const BattleUpdateStageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_stage_runtime_deps_builder.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_deps_builder: Object = BattleUpdateEffectsCharacterDepsBuilder.new()
var core_deps_builder: Object = BattleUpdateEffectsCoreDepsBuilder.new()
var stage_runtime_deps_builder: Object = BattleUpdateStageRuntimeDepsBuilder.new()
var _character_runtime: Object = PlayerCharacterRuntime.new()

var _cached_registry: Object = null
var _cached_stage: int = -1
var _cached_character_type := ""
var _cached_deps: Dictionary = {}
var _has_cached_deps: bool = false


func build_deps(registry: Object, current_stage: int = 1, character_type: String = "") -> Dictionary:
	var trimmed_character_type: String = character_type.strip_edges()
	var cache_character_type: String = "" if trimmed_character_type == "" else _character_runtime.normalize(trimmed_character_type)
	if (
		_has_cached_deps
		and registry == _cached_registry
		and current_stage == _cached_stage
		and cache_character_type == _cached_character_type
	):
		return _cached_deps.duplicate()

	var deps: Dictionary = core_deps_builder.build_deps(registry)
	deps.merge(character_deps_builder.build_deps(registry, character_type), true)
	deps.merge(stage_runtime_deps_builder.build_deps(registry, current_stage, false), true)
	_cached_registry = registry
	_cached_stage = current_stage
	_cached_character_type = cache_character_type
	_cached_deps = deps
	_has_cached_deps = true
	return _cached_deps.duplicate()
