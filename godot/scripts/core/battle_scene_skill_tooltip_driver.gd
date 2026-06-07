extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var _character_runtime: Object = PlayerCharacterRuntime.new()


func pause_skill_cooldowns(owner: Object, registry: Object) -> void:
	var skill_state: Object = _get_active_skill_state(owner, registry)
	if skill_state != null and skill_state.has_method("pause_cooldowns"):
		skill_state.pause_cooldowns(Time.get_ticks_msec())
	_pause_active_item_cooldowns(owner, registry)


func resume_skill_cooldowns(owner: Object, registry: Object) -> void:
	var skill_state: Object = _get_active_skill_state(owner, registry)
	if skill_state != null and skill_state.has_method("resume_cooldowns"):
		skill_state.resume_cooldowns(Time.get_ticks_msec())
	_resume_active_item_cooldowns(owner, registry)


func queue_tooltip_overlay_redraw(owner: Object, registry: Object) -> void:
	var overlay_host: Object = _get_instance(registry, "skill_orb_tooltip_overlay_host")
	if overlay_host != null and overlay_host.has_method("queue_redraw"):
		overlay_host.queue_redraw(owner, registry)


func cycle_gamepad_tooltip(owner: Object, registry: Object) -> bool:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("cycle_gamepad_tooltip"):
		return false
	var result: Dictionary = hover_state.cycle_gamepad_tooltip(owner, registry)
	if not bool(result.get("handled", false)):
		return false
	if bool(result.get("active", false)):
		queue_tooltip_overlay_redraw(owner, registry)
	else:
		hide_tooltip_overlay(registry)
	return true


func hide_tooltip_overlay(registry: Object) -> void:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state != null and hover_state.has_method("clear_gamepad_tooltip_selection"):
		hover_state.clear_gamepad_tooltip_selection()
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


func _pause_active_item_cooldowns(owner: Object, registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("pause_cooldowns"):
		active_item_runtime.pause_cooldowns(owner, registry)


func _resume_active_item_cooldowns(owner: Object, registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("resume_cooldowns"):
		active_item_runtime.resume_cooldowns(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
