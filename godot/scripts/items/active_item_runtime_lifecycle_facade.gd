extends RefCounted


func reset(runtime: Object) -> void:
	runtime.slot_controller.reset()
	runtime.field_spawn_controller.reset()
	runtime.throw_controller.reset()
	runtime.effect_controller.reset()
	runtime.debug_spawn_menu.reset()
	runtime.pending_throw_recovery.reset()


func build_starting_slots(runtime: Object) -> Array:
	return runtime.slot_controller.build_starting_slots()
