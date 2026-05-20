extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var _character_runtime: Object = PlayerCharacterRuntime.new()


func pause_skill_cooldowns(owner: Object, registry: Object) -> void:
	var skill_state: Object = _get_active_skill_state(owner, registry)
	if skill_state != null and skill_state.has_method("pause_cooldowns"):
		skill_state.pause_cooldowns(Time.get_ticks_msec())


func resume_skill_cooldowns(owner: Object, registry: Object) -> void:
	var skill_state: Object = _get_active_skill_state(owner, registry)
	if skill_state != null and skill_state.has_method("resume_cooldowns"):
		skill_state.resume_cooldowns(Time.get_ticks_msec())


func queue_tooltip_overlay_redraw(owner: Object, registry: Object) -> void:
	var overlay_host: Object = _get_instance(registry, "skill_orb_tooltip_overlay_host")
	if overlay_host != null and overlay_host.has_method("queue_redraw"):
		overlay_host.queue_redraw(owner, registry)


func hide_tooltip_overlay(registry: Object) -> void:
	var overlay_host: Object = _get_instance(registry, "skill_orb_tooltip_overlay_host")
	if overlay_host != null and overlay_host.has_method("hide"):
		overlay_host.hide()


func _get_active_skill_state(owner: Object, registry: Object) -> Object:
	if registry == null:
		return null
	var character_type: String = _character_runtime.normalize(str(
		BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")
	))
	return _get_instance(registry, _character_runtime.get_skill_state_key(character_type))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
