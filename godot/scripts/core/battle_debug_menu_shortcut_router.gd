extends RefCounted

const BattleDebugMenuSwitcher := preload(
	"res://scripts/core/battle_debug_menu_switcher.gd"
)

const CHARACTER_DEBUG_KEY := KEY_F1
const ITEM_SPAWN_DEBUG_KEY := KEY_F2
const ITEM_MANAGEMENT_DEBUG_KEY := KEY_F3
const PERK_PICKER_DEBUG_KEY := KEY_F4
const STAGE_DEBUG_KEY := KEY_F5
const WEATHER_DEBUG_KEY := KEY_F6
const LINGPET_DEBUG_KEY := KEY_F7
const BALL_SPEED_DEBUG_KEY := KEY_F9

var _debug_menu_switcher: Object = BattleDebugMenuSwitcher.new()


func handle_input(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	var menu_key := _get_menu_key(event)
	if menu_key.is_empty():
		return false
	_debug_menu_switcher.switch_menu(menu_key, owner, module_getter)
	return true


func _get_menu_key(event: InputEvent) -> String:
	if not (event is InputEventKey):
		return ""
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return ""
	var menu_key := _get_menu_key_for_keycode(key_event.keycode)
	if menu_key.is_empty():
		menu_key = _get_menu_key_for_keycode(key_event.physical_keycode)
	return menu_key


func _get_menu_key_for_keycode(keycode: int) -> String:
	match keycode:
		CHARACTER_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_CHARACTER_PICKER
		ITEM_SPAWN_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_ITEM_SPAWN
		ITEM_MANAGEMENT_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_ITEM_MANAGEMENT
		PERK_PICKER_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_PERK_PICKER
		STAGE_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_STAGE_PICKER
		WEATHER_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_WEATHER_PICKER
		LINGPET_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_LINGPET_PICKER
		BALL_SPEED_DEBUG_KEY:
			return BattleDebugMenuSwitcher.DEBUG_MENU_BALL_SPEED
	return ""
