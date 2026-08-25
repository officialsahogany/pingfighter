extends RefCounted

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


func switch_menu(menu_key: String, owner: Object, module_getter: Callable) -> void:
	var was_open := _is_debug_menu_open(menu_key, module_getter)
	_close_overlay_menu("character_info_overlay", "close", module_getter)
	_close_overlay_menu("pause_menu_overlay", "close", module_getter)
	close_all(module_getter)
	if not was_open:
		_open_debug_menu(menu_key, owner, module_getter)
	_queue_redraw(owner)
	_mark_handled(owner)


func close_all(module_getter: Callable) -> void:
	for menu_key in DEBUG_MENU_KEYS:
		_close_debug_menu(str(menu_key), module_getter)


func _is_debug_menu_open(menu_key: String, module_getter: Callable) -> bool:
	match menu_key:
		DEBUG_MENU_CHARACTER_PICKER:
			return _call_modal_gate_bool(module_getter, "is_character_debug_picker_open")
		DEBUG_MENU_ITEM_SPAWN:
			return _call_modal_gate_bool(module_getter, "is_active_item_debug_spawn_menu_open")
		DEBUG_MENU_ITEM_MANAGEMENT:
			return _call_modal_gate_bool(module_getter, "is_mythic_management_menu_open")
		DEBUG_MENU_PERK_PICKER:
			return _call_modal_gate_bool(module_getter, "is_perk_debug_picker_open")
		DEBUG_MENU_STAGE_PICKER:
			return _call_modal_gate_bool(module_getter, "is_stage_debug_picker_open")
		DEBUG_MENU_WEATHER_PICKER:
			return _call_modal_gate_bool(module_getter, "is_weather_debug_picker_open")
		DEBUG_MENU_BALL_SPEED:
			return _is_ball_speed_debug_active(module_getter)
		DEBUG_MENU_LINGPET_PICKER:
			return _call_modal_gate_bool(module_getter, "is_lingpet_debug_picker_open")
	return false


func _open_debug_menu(menu_key: String, owner: Object, module_getter: Callable) -> void:
	match menu_key:
		DEBUG_MENU_CHARACTER_PICKER:
			var character_debug_picker := _get_module(module_getter, "character_debug_picker")
			if character_debug_picker != null and character_debug_picker.has_method("toggle"):
				character_debug_picker.call("toggle", owner)
		DEBUG_MENU_ITEM_SPAWN:
			var active_item_runtime := _get_module(module_getter, "active_item_runtime")
			if active_item_runtime != null and active_item_runtime.has_method("toggle_debug_spawn_menu"):
				active_item_runtime.call("toggle_debug_spawn_menu")
		DEBUG_MENU_ITEM_MANAGEMENT:
			var mythic_item_runtime := _get_module(module_getter, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("toggle_debug_management_menu"):
				_prewarm_mythic_management_menu(mythic_item_runtime)
				mythic_item_runtime.call("toggle_debug_management_menu")
		DEBUG_MENU_PERK_PICKER:
			var perk_debug_picker := _get_module(module_getter, "runtime_perk_debug_picker")
			if perk_debug_picker != null and perk_debug_picker.has_method("toggle"):
				_prewarm_perk_debug_picker(perk_debug_picker, owner, module_getter)
				perk_debug_picker.call("toggle")
		DEBUG_MENU_STAGE_PICKER:
			var stage_debug_picker := _get_module(module_getter, "stage_debug_picker")
			if stage_debug_picker != null and stage_debug_picker.has_method("toggle"):
				stage_debug_picker.call("toggle", owner)
		DEBUG_MENU_WEATHER_PICKER:
			var weather_debug_picker := _get_module(module_getter, "weather_debug_picker")
			if weather_debug_picker != null and weather_debug_picker.has_method("toggle"):
				weather_debug_picker.call("toggle", owner)
		DEBUG_MENU_BALL_SPEED:
			var ball_speed_debug := _get_module(module_getter, "ball_speed_debug_overlay")
			if ball_speed_debug != null and ball_speed_debug.has_method("toggle"):
				ball_speed_debug.call("toggle")
		DEBUG_MENU_LINGPET_PICKER:
			var lingpet_debug_picker := _get_module(module_getter, "lingpet_debug_picker")
			if lingpet_debug_picker != null and lingpet_debug_picker.has_method("toggle"):
				lingpet_debug_picker.call("toggle", owner)


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
	var active_item_runtime := _get_module(module_getter, "active_item_runtime")
	if active_item_runtime == null:
		return
	if active_item_runtime.has_method("close_debug_spawn_menu"):
		active_item_runtime.call("close_debug_spawn_menu")
	elif (
		_call_modal_gate_bool(module_getter, "is_active_item_debug_spawn_menu_open")
		and active_item_runtime.has_method("toggle_debug_spawn_menu")
	):
		active_item_runtime.call("toggle_debug_spawn_menu")


func _close_mythic_management_debug_menu(module_getter: Callable) -> void:
	var mythic_item_runtime := _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return
	if mythic_item_runtime.has_method("close_debug_management_menu"):
		mythic_item_runtime.call("close_debug_management_menu")
	elif (
		_call_modal_gate_bool(module_getter, "is_mythic_management_menu_open")
		and mythic_item_runtime.has_method("toggle_debug_management_menu")
	):
		mythic_item_runtime.call("toggle_debug_management_menu")


func _close_ball_speed_debug(module_getter: Callable) -> void:
	var ball_speed_debug := _get_module(module_getter, "ball_speed_debug_overlay")
	if ball_speed_debug == null:
		return
	if ball_speed_debug.has_method("close"):
		ball_speed_debug.call("close")
	elif _is_ball_speed_debug_active(module_getter) and ball_speed_debug.has_method("toggle"):
		ball_speed_debug.call("toggle")


func _prewarm_perk_debug_picker(
	perk_debug_picker: Object,
	owner: Object,
	module_getter: Callable
) -> void:
	var icon_renderer := _get_module(module_getter, "runtime_perk_icon_renderer")
	if perk_debug_picker != null and perk_debug_picker.has_method("prewarm_assets"):
		perk_debug_picker.call(
			"prewarm_assets",
			_get_module(module_getter, "runtime_perk_catalog"),
			owner,
			icon_renderer
		)
	elif icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.call("prewarm_assets")


func _prewarm_mythic_management_menu(mythic_item_runtime: Object) -> void:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_assets"):
		mythic_item_runtime.call("prewarm_assets")


func _is_ball_speed_debug_active(module_getter: Callable) -> bool:
	var ball_speed_debug := _get_module(module_getter, "ball_speed_debug_overlay")
	return (
		ball_speed_debug != null
		and ball_speed_debug.has_method("is_active")
		and bool(ball_speed_debug.call("is_active"))
	)


func _call_modal_gate_bool(
	module_getter: Callable,
	method_name: String,
	fallback: bool = false
) -> bool:
	var modal_gate := _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate == null or not modal_gate.has_method(method_name):
		return fallback
	return bool(modal_gate.call(method_name, module_getter))


func _close_overlay_menu(
	module_key: String,
	close_method: String,
	module_getter: Callable
) -> void:
	var module := _get_module(module_getter, module_key)
	if module != null and module.has_method(close_method):
		module.call(close_method)


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
