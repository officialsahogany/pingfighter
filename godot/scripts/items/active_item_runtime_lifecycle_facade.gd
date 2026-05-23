extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func reset(runtime: Object) -> void:
	_reset_member(runtime, "slot_controller")
	_reset_member(runtime, "field_spawn_controller")
	_reset_member(runtime, "throw_controller")
	_reset_member(runtime, "effect_controller")
	_reset_member(runtime, "debug_spawn_menu")
	_reset_member(runtime, "pending_throw_recovery")


func reset_for_stage_transition(runtime: Object, owner: Object, _registry: Object = null) -> void:
	_reset_member(runtime, "field_spawn_controller")
	_reset_member(runtime, "throw_controller")
	_reset_member(runtime, "effect_controller")
	_reset_member(runtime, "debug_spawn_menu")
	_reset_member(runtime, "pending_throw_recovery")
	_reset_stage_transition_slot_state(runtime, owner)


func build_starting_slots(runtime: Object) -> Array:
	return runtime.slot_controller.build_starting_slots()


func _reset_member(runtime: Object, member_name: String) -> void:
	if runtime == null:
		return
	var member_value: Variant = runtime.get(member_name)
	if member_value is Object and member_value.has_method("reset"):
		member_value.reset()


func _reset_stage_transition_slot_state(runtime: Object, owner: Object) -> void:
	if runtime == null:
		return
	var slot_controller_value: Variant = runtime.get("slot_controller")
	if not (slot_controller_value is Object):
		return
	var slot_controller: Object = slot_controller_value
	if slot_controller.has_method("reset"):
		slot_controller.reset()
	if owner == null or not slot_controller.has_method("reset_cooldowns_for_stage_transition"):
		return
	var current_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var cleaned_slots: Array = slot_controller.reset_cooldowns_for_stage_transition(current_slots)
	owner.set("active_item_slots", cleaned_slots)
