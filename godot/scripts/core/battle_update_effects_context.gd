extends RefCounted

const BattleUpdateEffectsDepsBuilder := preload("res://scripts/core/battle_update_effects_deps_builder.gd")
const BattleUpdateEffectsFrameContextBuilder := preload("res://scripts/core/battle_update_effects_frame_context_builder.gd")

var deps_builder: Object = BattleUpdateEffectsDepsBuilder.new()
var frame_context_builder: Object = BattleUpdateEffectsFrameContextBuilder.new()


func build_context(owner: Object, registry: Object) -> Dictionary:
	return frame_context_builder.build_context(owner, registry)


func build_deps(
	registry: Object,
	current_stage: int = 1,
	character_type: String = "",
	stage1_boss_variant: String = "dalji"
) -> Dictionary:
	return deps_builder.build_deps(registry, current_stage, character_type, stage1_boss_variant)
