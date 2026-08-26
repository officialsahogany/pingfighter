extends RefCounted

const BattleActiveItemDebugInputRouter := preload(
	"res://scripts/core/battle_active_item_debug_input_router.gd"
)
const BattleCharacterInfoInputRouter := preload(
	"res://scripts/core/battle_character_info_input_router.gd"
)
const BattleDebugMenuInputRouter := preload("res://scripts/core/battle_debug_menu_input_router.gd")
const BattleDebugMenuShortcutRouter := preload(
	"res://scripts/core/battle_debug_menu_shortcut_router.gd"
)
const BattleElixirCinematicInputRouter := preload(
	"res://scripts/core/battle_elixir_cinematic_input_router.gd"
)
const BattleGuidedOverlayInputRouter := preload(
	"res://scripts/core/battle_guided_overlay_input_router.gd"
)
const BattleLingpetPriorityInputRouter := preload(
	"res://scripts/core/battle_lingpet_priority_input_router.gd"
)
const GuardianSpringChosikSwapInputRouter := preload(
	"res://scripts/core/guardian_spring_chosik_swap_input_router.gd"
)
const BattlePauseMenuInputRouter := preload(
	"res://scripts/core/battle_pause_menu_input_router.gd"
)
const BattleRuntimePerkInputRouter := preload(
	"res://scripts/core/battle_runtime_perk_input_router.gd"
)

const CHARACTER_DEBUG_KEY := BattleDebugMenuShortcutRouter.CHARACTER_DEBUG_KEY
const ITEM_SPAWN_DEBUG_KEY := BattleDebugMenuShortcutRouter.ITEM_SPAWN_DEBUG_KEY
const ITEM_MANAGEMENT_DEBUG_KEY := BattleDebugMenuShortcutRouter.ITEM_MANAGEMENT_DEBUG_KEY
const PERK_PICKER_DEBUG_KEY := BattleDebugMenuShortcutRouter.PERK_PICKER_DEBUG_KEY
const STAGE_DEBUG_KEY := BattleDebugMenuShortcutRouter.STAGE_DEBUG_KEY
const WEATHER_DEBUG_KEY := BattleDebugMenuShortcutRouter.WEATHER_DEBUG_KEY
const LINGPET_DEBUG_KEY := BattleDebugMenuShortcutRouter.LINGPET_DEBUG_KEY
const RUNTIME_PERK_DEBUG_KEY := BattleRuntimePerkInputRouter.RUNTIME_PERK_DEBUG_KEY
const BALL_SPEED_DEBUG_KEY := BattleDebugMenuShortcutRouter.BALL_SPEED_DEBUG_KEY
# KEY_F10 is owned by `ExhibitionResetHandler` (autoload) as the booth reset
# hotkey. Do not rebind F10 here -- the autoload handles the event in `_input`
# before unhandled-input reaches this controller.
var _active_item_debug_input_router: Object = BattleActiveItemDebugInputRouter.new()
var _character_info_input_router: Object = BattleCharacterInfoInputRouter.new()
var _debug_menu_input_router: Object = BattleDebugMenuInputRouter.new()
var _debug_menu_shortcut_router: Object = BattleDebugMenuShortcutRouter.new()
var _elixir_cinematic_input_router: Object = BattleElixirCinematicInputRouter.new()
var _guided_overlay_input_router: Object = BattleGuidedOverlayInputRouter.new()
var _guardian_spring_chosik_swap_input_router: Object = (
	GuardianSpringChosikSwapInputRouter.new()
)
var _lingpet_priority_input_router: Object = BattleLingpetPriorityInputRouter.new()
var _pause_menu_input_router: Object = BattlePauseMenuInputRouter.new()
var _runtime_perk_input_router: Object = BattleRuntimePerkInputRouter.new()


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	# These fullscreen lingpet modals outrank every other overlay input route.
	if _lingpet_priority_input_router.handle_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner),
		_guardian_spring_chosik_swap_input_router
	):
		return true

	if _guided_overlay_input_router.handle_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true
	# Preserve the monolith's exact seam: F1-F7 shortcuts, the first four open
	# debug pickers, F9, then mythic/perk debug menus. F9 used to sit between
	# those active-menu groups and must not be hoisted ahead of them.
	if _debug_menu_shortcut_router.handle_primary_shortcut_input(
		event,
		owner,
		module_getter
	):
		return true
	if _debug_menu_input_router.handle_pre_ball_speed_menu_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true
	if _debug_menu_shortcut_router.handle_ball_speed_shortcut_input(
		event,
		owner,
		module_getter
	):
		return true
	if _debug_menu_input_router.handle_post_ball_speed_menu_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true

	if _runtime_perk_input_router.handle_active_choice_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true

	if _pause_menu_input_router.handle_active_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true

	if _elixir_cinematic_input_router.handle_input(
		event,
		owner,
		module_getter
	):
		return true

	if _character_info_input_router.handle_active_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true

	if _pause_menu_input_router.handle_open_shortcut(
		event,
		owner,
		module_getter
	):
		return true

	if _character_info_input_router.handle_open_shortcut(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	):
		return true

	if _runtime_perk_input_router.handle_debug_grant_input(
		event,
		owner,
		context
	):
		return true

	return _active_item_debug_input_router.handle_input(
		event,
		owner,
		registry,
		module_getter,
		_get_view_size(owner)
	)


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2.ZERO
