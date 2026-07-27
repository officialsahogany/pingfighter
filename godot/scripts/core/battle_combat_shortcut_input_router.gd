extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if _handle_skill_orb_tooltip_cycle(event, owner, registry, module_getter):
		return true
	return _handle_commando_weapon_switch(event, owner, registry, module_getter)


func _handle_skill_orb_tooltip_cycle(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if (
		not GamepadInput.is_skill_tooltip_cycle_event(event)
		and not _is_arrow_space_grip_skill_tooltip_event(event, owner)
	):
		return false
	var skill_tooltip_driver: Object = _get_module(
		module_getter,
		"battle_scene_skill_tooltip_driver"
	)
	if skill_tooltip_driver == null or not skill_tooltip_driver.has_method("cycle_gamepad_tooltip"):
		return false
	if not bool(skill_tooltip_driver.cycle_gamepad_tooltip(owner, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_commando_weapon_switch(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var input_reader: Object = _get_module(module_getter, "commando_input_reader")
	if input_reader == null or not input_reader.has_method("handle_weapon_switch_event"):
		return false
	if not bool(input_reader.handle_weapon_switch_event(event, owner, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _is_arrow_space_grip_skill_tooltip_event(event: InputEvent, owner: Object) -> bool:
	if not _is_key_pressed(event, KEY_SHIFT):
		return false
	return _get_owner_grip_style(owner) == "space_arrows"


func _get_owner_grip_style(owner: Object) -> String:
	if owner == null:
		return ""
	for key in ["tutorial_grip_style", "junior_mika_grip_style"]:
		if owner.has_meta(key):
			var normalized: String = _normalize_grip_style(str(owner.get_meta(key, "")))
			if normalized != "":
				return normalized
	return ""


func _normalize_grip_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized == "space_arrows" or normalized == "arrows_space":
		return "space_arrows"
	return normalized


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
