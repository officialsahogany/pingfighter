extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const CHARACTER_DEBUG_KEY := KEY_F1
const ITEM_SPAWN_DEBUG_KEY := KEY_F2
const ITEM_MANAGEMENT_DEBUG_KEY := KEY_F3
const PERK_PICKER_DEBUG_KEY := KEY_F4
const STAGE_DEBUG_KEY := KEY_F5
const WEATHER_DEBUG_KEY := KEY_F6
# KEY_F7 is owned by `ExhibitionResetHandler` (autoload) as the booth reset
# hotkey. Do not rebind F7 here -- the autoload handles the event in `_input`
# before unhandled-input reaches this controller.
const RUNTIME_PERK_DEBUG_KEY := KEY_F8
const BALL_SPEED_DEBUG_KEY := KEY_F9
const LINGPET_DEBUG_KEY := KEY_F10
const CHARACTER_INFO_KEY := KEY_TAB
const PAUSE_MENU_KEY := KEY_ESCAPE
const DEBUG_MENU_CHARACTER_PICKER := "character_picker"
const DEBUG_MENU_ITEM_SPAWN := "item_spawn"
const DEBUG_MENU_ITEM_MANAGEMENT := "item_management"
const DEBUG_MENU_PERK_PICKER := "perk_picker"
const DEBUG_MENU_STAGE_PICKER := "stage_picker"
const DEBUG_MENU_WEATHER_PICKER := "weather_picker"
const DEBUG_MENU_BALL_SPEED := "ball_speed"
const DEBUG_MENU_LINGPET_PICKER := "lingpet_picker"
const DEBUG_MENU_KEYS := [
	DEBUG_MENU_CHARACTER_PICKER,
	DEBUG_MENU_ITEM_SPAWN,
	DEBUG_MENU_ITEM_MANAGEMENT,
	DEBUG_MENU_PERK_PICKER,
	DEBUG_MENU_STAGE_PICKER,
	DEBUG_MENU_WEATHER_PICKER,
	DEBUG_MENU_BALL_SPEED,
	DEBUG_MENU_LINGPET_PICKER,
]


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	# Highest priority: the fullscreen lingpet acquisition cut-in. While it is up
	# it swallows all input; once the reveal has finished playing, a click/confirm
	# starts the exit action which then fades out and resumes the paused battle.
	if _is_lingpet_acquire_cutin_active(module_getter):
		var lingpet_runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
		if (
			lingpet_runtime != null
			and lingpet_runtime.has_method("is_acquire_cutin_awaiting_dismiss")
			and bool(lingpet_runtime.is_acquire_cutin_awaiting_dismiss())
			and _is_elixir_confirm_event(event)
		):
			# Click does NOT close instantly -- it starts the spear-raise + water-spray
			# exit action, which then fades out and resumes gameplay on its own.
			if lingpet_runtime.has_method("begin_acquire_cutin_dismiss") and bool(lingpet_runtime.begin_acquire_cutin_dismiss()):
				_queue_redraw(owner)
				_mark_handled(owner)
		return true

	var character_debug_picker: Object = _get_module(module_getter, "character_debug_picker")
	var stage_debug_picker: Object = _get_module(module_getter, "stage_debug_picker")
	var grip_overlay: Object = _get_module(module_getter, "grip_style_selection_overlay")
	if _is_grip_style_selection_active(module_getter):
		if grip_overlay != null and grip_overlay.has_method("handle_input"):
			var handled_grip: bool = bool(grip_overlay.handle_input(event, owner, registry, _get_view_size(owner)))
			if handled_grip:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true
	var skill_tooltip_hint: Object = _get_module(module_getter, "skill_orb_tooltip_tutorial_hint")
	if _is_skill_orb_tooltip_tutorial_active(module_getter):
		if skill_tooltip_hint != null and skill_tooltip_hint.has_method("handle_input"):
			var handled_skill_tutorial: bool = bool(skill_tooltip_hint.handle_input(event, owner, registry, _get_view_size(owner)))
			if handled_skill_tutorial:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true
	if _is_key_pressed(event, CHARACTER_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_CHARACTER_PICKER, owner, module_getter)
		return true
	if _is_key_pressed(event, ITEM_SPAWN_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_ITEM_SPAWN, owner, module_getter)
		return true
	if _is_key_pressed(event, ITEM_MANAGEMENT_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_ITEM_MANAGEMENT, owner, module_getter)
		return true
	if _is_key_pressed(event, PERK_PICKER_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_PERK_PICKER, owner, module_getter)
		return true

	if _is_key_pressed(event, STAGE_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_STAGE_PICKER, owner, module_getter)
		return true
	if _is_key_pressed(event, WEATHER_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_WEATHER_PICKER, owner, module_getter)
		return true
	if _is_key_pressed(event, LINGPET_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_LINGPET_PICKER, owner, module_getter)
		return true
	if _is_character_debug_picker_open(module_getter):
		if character_debug_picker != null and character_debug_picker.has_method("handle_input"):
			var handled_character_debug: bool = bool(character_debug_picker.handle_input(
				event,
				owner,
				registry,
				_get_view_size(owner)
			))
			if handled_character_debug:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true
	var weather_debug_picker: Object = _get_module(module_getter, "weather_debug_picker")
	if _is_weather_debug_picker_open(module_getter):
		if weather_debug_picker != null and weather_debug_picker.has_method("handle_input"):
			var handled_weather_debug: bool = bool(weather_debug_picker.handle_input(
				event,
				owner,
				registry,
				_get_view_size(owner)
			))
			if handled_weather_debug:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true
	if _is_stage_debug_picker_open(module_getter):
		if stage_debug_picker != null and stage_debug_picker.has_method("handle_input"):
			var handled_stage_debug: bool = bool(stage_debug_picker.handle_input(
				event,
				owner,
				registry,
				_get_view_size(owner)
			))
			if handled_stage_debug:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true
	var lingpet_debug_picker: Object = _get_module(module_getter, "lingpet_debug_picker")
	if _is_lingpet_debug_picker_open(module_getter):
		if lingpet_debug_picker != null and lingpet_debug_picker.has_method("handle_input"):
			var handled_lingpet_debug: bool = bool(lingpet_debug_picker.handle_input(
				event,
				owner,
				registry,
				_get_view_size(owner)
			))
			if handled_lingpet_debug:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true

	var _ball_speed_debug: Object = _get_module(module_getter, "ball_speed_debug_overlay")
	if _is_key_pressed(event, BALL_SPEED_DEBUG_KEY):
		_switch_debug_menu(DEBUG_MENU_BALL_SPEED, owner, module_getter)
		return true

	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if _is_mythic_management_menu_open(module_getter):
		if mythic_item_runtime != null and mythic_item_runtime.has_method("handle_debug_management_menu_input"):
			var handled_item_debug: bool = bool(mythic_item_runtime.handle_debug_management_menu_input(
				event,
				owner,
				registry,
				_get_view_size(owner)
			))
			if handled_item_debug:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true

	var perk_debug_picker: Object = _get_module(module_getter, "runtime_perk_debug_picker")
	if _is_perk_debug_picker_open(module_getter):
		if perk_debug_picker != null and perk_debug_picker.has_method("handle_input"):
			var handled_debug: bool = bool(perk_debug_picker.handle_input(
				event,
				owner,
				registry,
				_get_view_size(owner)
			))
			if handled_debug:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true

	var runtime_perk_state: Object = _get_module(module_getter, "runtime_perk_state")
	if _is_runtime_perk_choice_active(module_getter):
		if runtime_perk_state != null and runtime_perk_state.has_method("handle_input"):
			var handled: bool = bool(runtime_perk_state.handle_input(event, owner, registry, _get_view_size(owner)))
			if handled:
				_queue_redraw(owner)
				_mark_handled(owner)
		return true

	var character_info: Object = _get_module(module_getter, "character_info_overlay")
	var pause_menu: Object = _get_module(module_getter, "pause_menu_overlay")
	if _is_pause_menu_active(module_getter):
		if pause_menu != null and pause_menu.has_method("handle_input"):
			var pause_result: Variant = pause_menu.handle_input(event, owner, registry, _get_view_size(owner))
			var handled_pause: bool = _is_pause_result_handled(pause_result)
			if handled_pause:
				_handle_pause_menu_action(_get_pause_result_action(pause_result), owner, registry, module_getter)
				_queue_redraw(owner)
				_mark_handled(owner)
		return true

	if _is_elixir_cinematic_active(module_getter):
		var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
		if _is_elixir_confirm_event(event):
			if active_item_runtime != null and active_item_runtime.has_method("handle_elixir_confirm"):
				if bool(active_item_runtime.handle_elixir_confirm()):
					_queue_redraw(owner)
					_mark_handled(owner)
		return true

	if _is_character_info_active(module_getter):
		if character_info != null and character_info.has_method("handle_input"):
			var handled_info: bool = bool(character_info.handle_input(event, owner, registry, _get_view_size(owner)))
			if handled_info:
				if _should_queue_character_info_input_redraw(character_info):
					_queue_redraw(owner)
				_mark_handled(owner)
		return true

	if _is_key_pressed(event, PAUSE_MENU_KEY) or GamepadInput.is_pause_event(event):
		if pause_menu != null and pause_menu.has_method("open"):
			_close_all_debug_menus(module_getter)
			pause_menu.open()
			_queue_redraw(owner)
			_mark_handled(owner)
		return true

	if _is_key_pressed(event, CHARACTER_INFO_KEY):
		if character_info != null and character_info.has_method("open"):
			_close_overlay_menu("pause_menu_overlay", "close", module_getter)
			_prewarm_character_info(character_info, owner, registry, module_getter)
			_open_character_info(character_info, owner, registry)
			_queue_redraw(owner)
			_mark_handled(owner)
		return true

	if _is_key_pressed(event, RUNTIME_PERK_DEBUG_KEY):
		_call_context(context, "collect_star_point")
		_queue_redraw(owner)
		_mark_handled(owner)
		return true

	return _handle_active_item_debug_input(event, owner, registry, module_getter)


func _handle_active_item_debug_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	if active_item_runtime == null:
		return false

	if active_item_runtime.has_method("handle_debug_spawn_menu_input"):
		var handled_spawn_input: bool = bool(active_item_runtime.handle_debug_spawn_menu_input(
			event,
			_get_view_size(owner),
			owner,
			registry
		))
		if handled_spawn_input:
			_queue_redraw(owner)
			_mark_handled(owner)
		return handled_spawn_input

	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not active_item_runtime.has_method("handle_debug_spawn_menu_click"):
		return false
	var handled_spawn_click: bool = bool(active_item_runtime.handle_debug_spawn_menu_click(
		mouse_event.position,
		_get_view_size(owner),
		owner,
		registry
	))
	if handled_spawn_click:
		_queue_redraw(owner)
		_mark_handled(owner)
	return handled_spawn_click


func _switch_debug_menu(menu_key: String, owner: Object, module_getter: Callable) -> void:
	var was_open: bool = _is_debug_menu_open(menu_key, module_getter)
	_close_overlay_menu("character_info_overlay", "close", module_getter)
	_close_overlay_menu("pause_menu_overlay", "close", module_getter)
	_close_all_debug_menus(module_getter)
	if not was_open:
		_open_debug_menu(menu_key, owner, module_getter)
	_queue_redraw(owner)
	_mark_handled(owner)


func _is_debug_menu_open(menu_key: String, module_getter: Callable) -> bool:
	match menu_key:
		DEBUG_MENU_CHARACTER_PICKER:
			return _is_character_debug_picker_open(module_getter)
		DEBUG_MENU_ITEM_SPAWN:
			return _is_active_item_debug_spawn_menu_open(module_getter)
		DEBUG_MENU_ITEM_MANAGEMENT:
			return _is_mythic_management_menu_open(module_getter)
		DEBUG_MENU_PERK_PICKER:
			return _is_perk_debug_picker_open(module_getter)
		DEBUG_MENU_STAGE_PICKER:
			return _is_stage_debug_picker_open(module_getter)
		DEBUG_MENU_WEATHER_PICKER:
			return _is_weather_debug_picker_open(module_getter)
		DEBUG_MENU_BALL_SPEED:
			return _is_ball_speed_debug_active(module_getter)
		DEBUG_MENU_LINGPET_PICKER:
			return _is_lingpet_debug_picker_open(module_getter)
	return false


func _open_debug_menu(menu_key: String, owner: Object, module_getter: Callable) -> void:
	match menu_key:
		DEBUG_MENU_CHARACTER_PICKER:
			var character_debug_picker: Object = _get_module(module_getter, "character_debug_picker")
			if character_debug_picker != null and character_debug_picker.has_method("toggle"):
				character_debug_picker.toggle(owner)
		DEBUG_MENU_ITEM_SPAWN:
			var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
			if active_item_runtime != null and active_item_runtime.has_method("toggle_debug_spawn_menu"):
				active_item_runtime.toggle_debug_spawn_menu()
		DEBUG_MENU_ITEM_MANAGEMENT:
			var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("toggle_debug_management_menu"):
				_prewarm_mythic_management_menu(mythic_item_runtime)
				mythic_item_runtime.toggle_debug_management_menu()
		DEBUG_MENU_PERK_PICKER:
			var perk_debug_picker: Object = _get_module(module_getter, "runtime_perk_debug_picker")
			if perk_debug_picker != null and perk_debug_picker.has_method("toggle"):
				_prewarm_perk_debug_picker(perk_debug_picker, owner, module_getter)
				perk_debug_picker.toggle()
		DEBUG_MENU_STAGE_PICKER:
			var stage_debug_picker: Object = _get_module(module_getter, "stage_debug_picker")
			if stage_debug_picker != null and stage_debug_picker.has_method("toggle"):
				stage_debug_picker.toggle(owner)
		DEBUG_MENU_WEATHER_PICKER:
			var weather_debug_picker: Object = _get_module(module_getter, "weather_debug_picker")
			if weather_debug_picker != null and weather_debug_picker.has_method("toggle"):
				weather_debug_picker.toggle(owner)
		DEBUG_MENU_BALL_SPEED:
			var ball_speed_debug: Object = _get_module(module_getter, "ball_speed_debug_overlay")
			if ball_speed_debug != null and ball_speed_debug.has_method("toggle"):
				ball_speed_debug.toggle()
		DEBUG_MENU_LINGPET_PICKER:
			var lingpet_debug_picker: Object = _get_module(module_getter, "lingpet_debug_picker")
			if lingpet_debug_picker != null and lingpet_debug_picker.has_method("toggle"):
				lingpet_debug_picker.toggle(owner)


func _close_all_debug_menus(module_getter: Callable) -> void:
	for menu_key in DEBUG_MENU_KEYS:
		_close_debug_menu(str(menu_key), module_getter)


func _close_debug_menu(menu_key: String, module_getter: Callable) -> void:
	match menu_key:
		DEBUG_MENU_CHARACTER_PICKER:
			_close_overlay_menu("character_debug_picker", "close", module_getter)
		DEBUG_MENU_ITEM_SPAWN:
			_close_active_item_debug_menu(module_getter)
		DEBUG_MENU_ITEM_MANAGEMENT:
			_close_mythic_management_debug_menu(module_getter)
		DEBUG_MENU_PERK_PICKER:
			_close_overlay_menu("runtime_perk_debug_picker", "close", module_getter)
		DEBUG_MENU_STAGE_PICKER:
			_close_overlay_menu("stage_debug_picker", "close", module_getter)
		DEBUG_MENU_WEATHER_PICKER:
			_close_overlay_menu("weather_debug_picker", "close", module_getter)
		DEBUG_MENU_BALL_SPEED:
			_close_ball_speed_debug(module_getter)
		DEBUG_MENU_LINGPET_PICKER:
			_close_overlay_menu("lingpet_debug_picker", "close", module_getter)


func _close_active_item_debug_menu(module_getter: Callable) -> void:
	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	if active_item_runtime == null:
		return
	if active_item_runtime.has_method("close_debug_spawn_menu"):
		active_item_runtime.close_debug_spawn_menu()
	elif _is_active_item_debug_spawn_menu_open(module_getter) and active_item_runtime.has_method("toggle_debug_spawn_menu"):
		active_item_runtime.toggle_debug_spawn_menu()


func _close_mythic_management_debug_menu(module_getter: Callable) -> void:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return
	if mythic_item_runtime.has_method("close_debug_management_menu"):
		mythic_item_runtime.close_debug_management_menu()
	elif _is_mythic_management_menu_open(module_getter) and mythic_item_runtime.has_method("toggle_debug_management_menu"):
		mythic_item_runtime.toggle_debug_management_menu()


func _prewarm_perk_debug_picker(perk_debug_picker: Object, owner: Object, module_getter: Callable) -> void:
	var icon_renderer: Object = _get_module(module_getter, "runtime_perk_icon_renderer")
	if perk_debug_picker != null and perk_debug_picker.has_method("prewarm_assets"):
		perk_debug_picker.prewarm_assets(
			_get_module(module_getter, "runtime_perk_catalog"),
			owner,
			icon_renderer
		)
	elif icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.prewarm_assets()


func _prewarm_mythic_management_menu(mythic_item_runtime: Object) -> void:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_assets"):
		mythic_item_runtime.prewarm_assets()


func _prewarm_character_info(character_info: Object, owner: Object, registry: Object, module_getter: Callable) -> void:
	if character_info != null and character_info.has_method("prewarm_assets"):
		character_info.prewarm_assets(owner, registry, module_getter, true, _get_view_size(owner))


func _open_character_info(character_info: Object, owner: Object, registry: Object) -> void:
	if character_info == null or not character_info.has_method("open"):
		return
	if _method_accepts_argument_count(character_info, "open", 2):
		character_info.open(owner, registry)
	else:
		character_info.open()


func _should_queue_character_info_input_redraw(character_info: Object) -> bool:
	if character_info != null and character_info.has_method("consume_input_redraw_request"):
		return bool(character_info.consume_input_redraw_request())
	return true


func _close_ball_speed_debug(module_getter: Callable) -> void:
	var ball_speed_debug: Object = _get_module(module_getter, "ball_speed_debug_overlay")
	if ball_speed_debug == null:
		return
	if ball_speed_debug.has_method("close"):
		ball_speed_debug.close()
	elif _is_ball_speed_debug_active(module_getter) and ball_speed_debug.has_method("toggle"):
		ball_speed_debug.toggle()


func _close_overlay_menu(module_key: String, close_method: String, module_getter: Callable) -> void:
	var module: Object = _get_module(module_getter, module_key)
	if module != null and module.has_method(close_method):
		module.call(close_method)


func _debug_cycle_weather_event(owner: Object, registry: Object, module_getter: Callable) -> Dictionary:
	var weather_driver: Object = _get_module(module_getter, "battle_scene_weather_update_driver")
	if weather_driver == null or not weather_driver.has_method("debug_cycle_weather_event"):
		return {"handled": false}
	var result: Variant = weather_driver.debug_cycle_weather_event(owner, registry)
	if result is Dictionary:
		return result
	return {"handled": true}


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_runtime_perk_choice_active")


func _is_character_debug_picker_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_character_debug_picker_open")


func _is_perk_debug_picker_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_perk_debug_picker_open")


func _is_mythic_management_menu_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_mythic_management_menu_open")


func _is_stage_debug_picker_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_stage_debug_picker_open")


func _is_weather_debug_picker_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_weather_debug_picker_open")


func _is_lingpet_debug_picker_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_lingpet_debug_picker_open")


func _is_character_info_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_character_info_active")


func _is_pause_menu_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_pause_menu_active")


func _is_grip_style_selection_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_grip_style_selection_active")


func _is_skill_orb_tooltip_tutorial_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_skill_orb_tooltip_tutorial_active")


func _is_elixir_cinematic_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_elixir_cinematic_active")


func _is_lingpet_acquire_cutin_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_lingpet_acquire_cutin_active")


func _is_elixir_confirm_event(event: InputEvent) -> bool:
	if GamepadInput.is_confirm_event(event):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return false
		return key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.physical_keycode == KEY_ENTER
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return false


func _is_active_item_debug_spawn_menu_open(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_active_item_debug_spawn_menu_open")


func _is_ball_speed_debug_active(module_getter: Callable) -> bool:
	var ball_speed_debug: Object = _get_module(module_getter, "ball_speed_debug_overlay")
	return ball_speed_debug != null and ball_speed_debug.has_method("is_active") and bool(ball_speed_debug.is_active())


func _call_modal_gate_bool(module_getter: Callable, method_name: String, fallback: bool = false) -> bool:
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate == null or not modal_gate.has_method(method_name):
		return fallback
	return bool(modal_gate.call(method_name, module_getter))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call_context(context: Dictionary, key: String) -> void:
	var callback_value: Variant = context.get(key, Callable())
	if typeof(callback_value) == TYPE_CALLABLE:
		var callback: Callable = callback_value
		if callback.is_valid():
			callback.call()


func _handle_pause_menu_action(action: String, owner: Object, registry: Object, module_getter: Callable) -> void:
	match action:
		"character_info":
			var character_info: Object = _get_module(module_getter, "character_info_overlay")
			if character_info != null and character_info.has_method("open"):
				_prewarm_character_info(character_info, owner, registry, module_getter)
				_open_character_info(character_info, owner, registry)
		"continue":
			pass
	if not action.is_empty():
		_queue_redraw(owner)


func _is_pause_result_handled(result: Variant) -> bool:
	if result is Dictionary:
		return bool((result as Dictionary).get("handled", false))
	return bool(result)


func _get_pause_result_action(result: Variant) -> String:
	if result is Dictionary:
		return str((result as Dictionary).get("action", ""))
	return ""


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2.ZERO


func _method_accepts_argument_count(target: Object, method_name: String, argument_count: int) -> bool:
	if target == null:
		return false
	for method_value in target.get_method_list():
		var method_info: Dictionary = method_value if method_value is Dictionary else {}
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() >= argument_count
	return false
