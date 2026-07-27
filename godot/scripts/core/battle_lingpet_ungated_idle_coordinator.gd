extends RefCounted


func process_ungated(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var runtime := _get_module(module_getter, "lingpet_egg_runtime")
	if runtime == null:
		return false

	# The shell-break commit opens the acquisition cut-in, so it must advance
	# first whenever both states are visible during the same idle frame.
	if _is_active(runtime, "is_hatch_break_active"):
		if runtime.has_method("advance_hatch_break"):
			runtime.call("advance_hatch_break", delta, owner, registry)
		_queue_redraw(owner)
		return true

	# This idle pump is intentionally outside the physics/modal gate. Passing
	# the registry lets the reveal wait for and stream its heavy Live2D sheet.
	if _is_active(runtime, "is_acquire_cutin_active"):
		if runtime.has_method("advance_acquire_cutin"):
			runtime.call("advance_acquire_cutin", delta, registry)
		_queue_redraw(owner)
		return true

	if _is_active(runtime, "is_overflow_choice_active"):
		_queue_redraw(owner)
		return true
	return false


func _is_active(runtime: Object, method_name: String) -> bool:
	return runtime.has_method(method_name) and bool(runtime.call(method_name))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")
