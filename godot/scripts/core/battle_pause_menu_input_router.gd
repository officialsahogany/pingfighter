extends RefCounted

const BattleCharacterInfoInputRouter := preload(
	"res://scripts/core/battle_character_info_input_router.gd"
)
const BattleDebugMenuSwitcher := preload(
	"res://scripts/core/battle_debug_menu_switcher.gd"
)
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const PAUSE_MENU_KEY := KEY_ESCAPE

var _character_info_input_router: Object = BattleCharacterInfoInputRouter.new()
var _debug_menu_switcher: Object = BattleDebugMenuSwitcher.new()


func handle_active_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if not _call_modal_gate_bool(module_getter, "is_pause_menu_active"):
		return false
	var pause_menu := _get_module(module_getter, "pause_menu_overlay")
	if pause_menu != null and pause_menu.has_method("handle_input"):
		var result: Variant = pause_menu.handle_input(
			event,
			owner,
			registry,
			view_size
		)
		if _is_result_handled(result):
			_handle_action(
				_get_result_action(result),
				owner,
				registry,
				module_getter,
				view_size
			)
			_queue_redraw(owner)
			_mark_handled(owner)
	return true


func handle_open_shortcut(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	if not _is_key_pressed(event, PAUSE_MENU_KEY) and not GamepadInput.is_pause_event(event):
		return false
	var pause_menu := _get_module(module_getter, "pause_menu_overlay")
	if pause_menu != null and pause_menu.has_method("open"):
		_debug_menu_switcher.close_all(module_getter)
		pause_menu.open()
		_queue_redraw(owner)
		_mark_handled(owner)
		return true
	return false


func _handle_action(
	action: String,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> void:
	match action:
		"character_info":
			_character_info_input_router.open_from_pause(
				owner,
				registry,
				module_getter,
				view_size
			)
		"continue":
			pass
		"exit_to_main":
			var match_flow_driver := _get_module(
				module_getter,
				"battle_scene_match_flow_driver"
			)
			if match_flow_driver != null and match_flow_driver.has_method(
				"exit_to_main_menu"
			):
				match_flow_driver.exit_to_main_menu(owner)
	if not action.is_empty():
		_queue_redraw(owner)


func _is_result_handled(result: Variant) -> bool:
	if result is Dictionary:
		return bool((result as Dictionary).get("handled", false))
	return bool(result)


func _get_result_action(result: Variant) -> String:
	if result is Dictionary:
		return str((result as Dictionary).get("action", ""))
	return ""


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _call_modal_gate_bool(module_getter: Callable, method_name: String) -> bool:
	var modal_gate := _get_module(
		module_getter,
		"battle_scene_modal_gate_controller"
	)
	if modal_gate == null or not modal_gate.has_method(method_name):
		return false
	return bool(modal_gate.call(method_name, module_getter))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.call("get_viewport")
	if viewport != null:
		viewport.set_input_as_handled()
