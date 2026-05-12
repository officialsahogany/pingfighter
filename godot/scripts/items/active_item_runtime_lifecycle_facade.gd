extends RefCounted


func reset(runtime: Object) -> void:
	_reset_member(runtime, "slot_controller")
	_reset_member(runtime, "field_spawn_controller")
	_reset_member(runtime, "throw_controller")
	_reset_member(runtime, "effect_controller")
	_reset_member(runtime, "debug_spawn_menu")
	_reset_member(runtime, "pending_throw_recovery")


func build_starting_slots(runtime: Object) -> Array:
	return runtime.slot_controller.build_starting_slots()


func _reset_member(runtime: Object, member_name: String) -> void:
	if runtime == null:
		return
	var member_value: Variant = runtime.get(member_name)
	if member_value is Object and member_value.has_method("reset"):
		member_value.reset()
