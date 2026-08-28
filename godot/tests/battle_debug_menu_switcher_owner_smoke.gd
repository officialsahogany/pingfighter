extends SceneTree

const BattleDebugMenuSwitcher := preload(
	"res://scripts/core/battle_debug_menu_switcher.gd"
)
const BattleSceneModalGateController := preload(
	"res://scripts/core/battle_scene_modal_gate_controller.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeToggleOverlay:
	extends RefCounted

	var open := false
	var toggle_count := 0
	var close_count := 0
	var prewarm_count := 0
	var last_toggle_owner: Object = null
	var last_prewarm_catalog: Object = null
	var last_prewarm_owner: Object = null
	var last_prewarm_icon_renderer: Object = null

	func toggle(owner: Object = null) -> void:
		open = not open
		toggle_count += 1
		last_toggle_owner = owner

	func close() -> void:
		open = false
		close_count += 1

	func is_open() -> bool:
		return open

	func prewarm_assets(
		catalog: Object = null,
		owner: Object = null,
		icon_renderer: Object = null
	) -> void:
		prewarm_count += 1
		last_prewarm_catalog = catalog
		last_prewarm_owner = owner
		last_prewarm_icon_renderer = icon_renderer


class FakeSimpleOverlay:
	extends RefCounted

	var active := true
	var close_count := 0

	func close() -> void:
		active = false
		close_count += 1

	func is_active() -> bool:
		return active


class FakeActiveItemRuntime:
	extends RefCounted

	var open := false
	var toggle_count := 0
	var close_count := 0

	func toggle_debug_spawn_menu() -> void:
		open = not open
		toggle_count += 1

	func close_debug_spawn_menu() -> void:
		open = false
		close_count += 1

	func is_debug_spawn_menu_open() -> bool:
		return open


class FakeMythicRuntime:
	extends RefCounted

	var open := false
	var toggle_count := 0
	var close_count := 0
	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1

	func toggle_debug_management_menu() -> void:
		open = not open
		toggle_count += 1

	func close_debug_management_menu() -> void:
		open = false
		close_count += 1

	func is_debug_management_menu_open() -> bool:
		return open


class FakeBallSpeedOverlay:
	extends RefCounted

	var active := false

	func toggle() -> void:
		active = not active

	func close() -> void:
		active = false

	func is_active() -> bool:
		return active


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Variant:
		return modules.get(key, null)


func _init() -> void:
	_verify_direct_switch_and_same_key_close()
	_verify_mythic_and_perk_prewarm_before_open()
	_verify_close_all_debug_menus()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_debug_menu_switcher_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_switch_and_same_key_close() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture.holder
	var owner := FakeOwner.new()
	var active_item: FakeActiveItemRuntime = holder.modules["active_item_runtime"]
	var stage_picker: FakeToggleOverlay = holder.modules["stage_debug_picker"]
	var character_info: FakeSimpleOverlay = holder.modules["character_info_overlay"]
	var pause_menu: FakeSimpleOverlay = holder.modules["pause_menu_overlay"]
	active_item.open = true

	BattleDebugMenuSwitcher.new().switch_menu(
		BattleDebugMenuSwitcher.DEBUG_MENU_STAGE_PICKER,
		owner,
		Callable(holder, "get_module")
	)
	_expect(not active_item.open, "direct switch must close the previously open item menu")
	_expect(stage_picker.open, "direct switch must open the selected stage menu")
	_expect(stage_picker.last_toggle_owner == owner, "owner-aware picker toggle must receive the battle owner")
	_expect(not character_info.active and not pause_menu.active, "debug switch must close normal overlays first")
	_expect(owner.redraw_count == 1, "debug switch must request one redraw")

	BattleDebugMenuSwitcher.new().switch_menu(
		BattleDebugMenuSwitcher.DEBUG_MENU_STAGE_PICKER,
		owner,
		Callable(holder, "get_module")
	)
	_expect(not stage_picker.open, "pressing the already-open debug key must close it without reopening")
	_expect(owner.redraw_count == 2, "same-key close must request one redraw")


func _verify_mythic_and_perk_prewarm_before_open() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture.holder
	var owner := FakeOwner.new()
	var switcher: Object = BattleDebugMenuSwitcher.new()
	var mythic: FakeMythicRuntime = holder.modules["mythic_item_runtime"]
	var perk_picker: FakeToggleOverlay = holder.modules["runtime_perk_debug_picker"]
	var catalog: Object = holder.modules["runtime_perk_catalog"]
	var icon_renderer: Object = holder.modules["runtime_perk_icon_renderer"]

	switcher.switch_menu(
		BattleDebugMenuSwitcher.DEBUG_MENU_ITEM_MANAGEMENT,
		owner,
		Callable(holder, "get_module")
	)
	_expect(mythic.prewarm_count == 1, "mythic management must prewarm before first open")
	_expect(mythic.open, "mythic management must open after prewarm")

	switcher.switch_menu(
		BattleDebugMenuSwitcher.DEBUG_MENU_PERK_PICKER,
		owner,
		Callable(holder, "get_module")
	)
	_expect(not mythic.open, "switching to perk picker must close mythic management")
	_expect(perk_picker.prewarm_count == 1, "perk picker must prewarm before first open")
	_expect(perk_picker.last_prewarm_catalog == catalog, "perk prewarm must receive the runtime catalog")
	_expect(perk_picker.last_prewarm_owner == owner, "perk prewarm must receive the owner")
	_expect(perk_picker.last_prewarm_icon_renderer == icon_renderer, "perk prewarm must receive the icon renderer")
	_expect(perk_picker.open, "perk picker must open after prewarm")


func _verify_close_all_debug_menus() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture.holder
	var active_item: FakeActiveItemRuntime = holder.modules["active_item_runtime"]
	var mythic: FakeMythicRuntime = holder.modules["mythic_item_runtime"]
	var character_picker: FakeToggleOverlay = holder.modules["character_debug_picker"]
	var weather_picker: FakeToggleOverlay = holder.modules["weather_debug_picker"]
	var ball_speed: FakeBallSpeedOverlay = holder.modules["ball_speed_debug_overlay"]
	active_item.open = true
	mythic.open = true
	character_picker.open = true
	weather_picker.open = true
	ball_speed.active = true

	BattleDebugMenuSwitcher.new().close_all(Callable(holder, "get_module"))
	_expect(not active_item.open, "close-all must close item spawn")
	_expect(not mythic.open, "close-all must close item management")
	_expect(not character_picker.open, "close-all must close character picker")
	_expect(not weather_picker.open, "close-all must close weather picker")
	_expect(not ball_speed.active, "close-all must close ball-speed overlay")


func _verify_source_ownership() -> void:
	var switcher_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_debug_menu_switcher.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	var shortcut_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_debug_menu_shortcut_router.gd"
	)
	var pause_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_pause_menu_input_router.gd"
	)
	_expect(switcher_source.contains("DEBUG_MENU_KEYS"), "switcher must own the complete debug menu catalog")
	_expect(switcher_source.contains("prewarm_assets"), "switcher must own debug-menu prewarm policy")
	_expect(switcher_source.contains("close_debug_spawn_menu"), "switcher must own item-menu close policy")
	_expect(shortcut_source.contains("BattleDebugMenuSwitcher.new()"), "shortcut router must compose the debug switcher")
	_expect(shortcut_source.contains("_debug_menu_switcher.switch_menu"), "shortcut router must delegate key-driven switches")
	_expect(input_source.contains("BattleDebugMenuShortcutRouter.new()"), "input controller must compose the shortcut router")
	_expect(pause_source.contains("_debug_menu_switcher.close_all"), "pause router must delegate pause-open cleanup")
	_expect(not input_source.contains("func _switch_debug_menu"), "input controller must not retain switch policy")
	_expect(not input_source.contains("func _open_debug_menu"), "input controller must not retain debug open dispatch")
	_expect(not input_source.contains("for menu_key in DEBUG_MENU_KEYS"), "input controller must not retain close-all iteration")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"character_debug_picker": FakeToggleOverlay.new(),
		"active_item_runtime": FakeActiveItemRuntime.new(),
		"mythic_item_runtime": FakeMythicRuntime.new(),
		"runtime_perk_debug_picker": FakeToggleOverlay.new(),
		"stage_debug_picker": FakeToggleOverlay.new(),
		"weather_debug_picker": FakeToggleOverlay.new(),
		"lingpet_debug_picker": FakeToggleOverlay.new(),
		"ball_speed_debug_overlay": FakeBallSpeedOverlay.new(),
		"character_info_overlay": FakeSimpleOverlay.new(),
		"pause_menu_overlay": FakeSimpleOverlay.new(),
		"runtime_perk_catalog": RefCounted.new(),
		"runtime_perk_icon_renderer": RefCounted.new(),
	}
	return {"holder": holder}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
