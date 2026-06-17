extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleUpdateDashSnapshotBuilder := preload("res://scripts/core/battle_update_dash_snapshot_builder.gd")
const BattleUpdateEffectsOwnerContextBuilder := preload("res://scripts/core/battle_update_effects_owner_context_builder.gd")
const BattleUpdateEffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var dash_snapshot_builder: Object = BattleUpdateDashSnapshotBuilder.new()
var owner_context_builder: Object = BattleUpdateEffectsOwnerContextBuilder.new()
var sprite_context_builder: Object = BattleUpdateEffectsSpriteContextBuilder.new()


func build_context(owner: Object, registry: Object) -> Dictionary:
	var sprite_context: Dictionary = sprite_context_builder.build_context(
		BattleSceneOwnerReader.get_dictionary(owner, "battle_textures"),
		BattleSceneOwnerReader.get_value(owner, "selected_character_type", PlayerCharacterRuntime.SMASHER)
	)
	var character_type: String = str(sprite_context.get("selected_character_type", PlayerCharacterRuntime.SMASHER))
	var context: Dictionary = owner_context_builder.build_context(
		owner,
		registry,
		character_type,
		dash_snapshot_builder.build_snapshot(registry)
	)
	context.merge(sprite_context, true)
	return context
