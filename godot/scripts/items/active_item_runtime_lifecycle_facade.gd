extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func reset(runtime: Object) -> void:
	_reset_member(runtime, "slot_controller")
	_reset_member(runtime, "field_spawn_controller")
	_reset_member(runtime, "throw_controller")
	_reset_member(runtime, "effect_controller")
	_reset_member(runtime, "debug_spawn_menu")
	_reset_member(runtime, "pending_throw_recovery")


func reset_for_stage_transition(runtime: Object, owner: Object, registry: Object = null) -> void:
	_reset_member(runtime, "field_spawn_controller")
	_reset_member(runtime, "throw_controller")
	_reset_member(runtime, "effect_controller")
	_sync_owner_paddle_after_effect_reset(runtime, owner, registry)
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


func _sync_owner_paddle_after_effect_reset(runtime: Object, owner: Object, registry: Object) -> void:
	if runtime == null or owner == null:
		return
	var effect_controller_value: Variant = runtime.get("effect_controller")
	if not (effect_controller_value is Object):
		return
	var effect_controller: Object = effect_controller_value
	if not effect_controller.has_method("sync_long_boost_owner_state"):
		return
	effect_controller.sync_long_boost_owner_state(
		owner,
		_get_instance(registry, "smasher_warp_gate_state"),
		_get_instance(registry, "mythic_item_runtime")
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null


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
