extends SceneTree

const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")


class FakeOwner:
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeActiveItemRuntime:
	var open := false

	func toggle_debug_spawn_menu() -> void:
		open = not open

	func close_debug_spawn_menu() -> void:
		open = false

	func is_debug_spawn_menu_open() -> bool:
		return open


class FakeMythicRuntime:
	var open := false
	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1

	func toggle_debug_management_menu() -> void:
		open = not open

	func close_debug_management_menu() -> void:
		open = false

	func is_debug_management_menu_open() -> bool:
		return open


class FakeToggleOverlay:
	var open := false
	var prewarm_count := 0

	func toggle(_owner: Object = null) -> void:
		open = not open

	func close() -> void:
		open = false

	func is_open() -> bool:
		return open

	func prewarm_assets(_catalog: Object = null, _owner: Object = null, _icon_renderer: Object = null) -> void:
		prewarm_count += 1


class FakeBallSpeedOverlay:
	var active := false

	func toggle() -> void:
		active = not active

	func close() -> void:
		active = false

	func is_active() -> bool:
		return active


class FakeCharacterInfo:
	var active := false
	var prewarm_count := 0
	var last_owner: Object
	var last_registry: Object
	var last_module_getter_valid := false
	var last_include_shared_icon_assets := false
	var last_view_size := Vector2.ZERO

	func open() -> void:
		active = true

	func close() -> void:
		active = false

	func is_active() -> bool:
		return active

	func prewarm_assets(
		owner: Object = null,
		registry: Object = null,
		module_getter: Callable = Callable(),
		include_shared_icon_assets: bool = true,
		view_size: Vector2 = Vector2.ZERO
	) -> void:
		prewarm_count += 1
		last_owner = owner
		last_registry = registry
		last_module_getter_valid = module_getter.is_valid()
		last_include_shared_icon_assets = include_shared_icon_assets
		last_view_size = view_size


class FakeRegistry:
	var modal_gate := BattleSceneModalGateController.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var mythic_item_runtime := FakeMythicRuntime.new()
	var perk_picker := FakeToggleOverlay.new()
	var stage_picker := FakeToggleOverlay.new()
	var weather_picker := FakeToggleOverlay.new()
	var lingpet_picker := FakeToggleOverlay.new()
	var ball_speed := FakeBallSpeedOverlay.new()
	var character_info := FakeCharacterInfo.new()

	func get_instance(key: String) -> Object:
		match key:
			"battle_scene_modal_gate_controller":
				return modal_gate
			"active_item_runtime":
				return active_item_runtime
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_debug_picker":
				return perk_picker
			"stage_debug_picker":
				return stage_picker
			"weather_debug_picker":
				return weather_picker
			"lingpet_debug_picker":
				return lingpet_picker
			"ball_speed_debug_overlay":
				return ball_speed
			"character_info_overlay":
				return character_info
		return null


var registry := FakeRegistry.new()


func _init() -> void:
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()

	_expect(not _press(input, owner, KEY_F10), "F10 should be reserved for ExhibitionResetHandler and ignored by battle debug input")
	_expect(_press(input, owner, KEY_F2), "F2 should open item spawn debug")
	_expect(registry.active_item_runtime.open, "item spawn debug should be open")

	_expect(_press(input, owner, KEY_F5), "F5 should switch directly to stage debug")
	_expect(not registry.active_item_runtime.open, "switching to stage debug should close item spawn debug")
	_expect(registry.stage_picker.open, "stage debug should be open after direct switch")

	_expect(_press(input, owner, KEY_F3), "F3 should switch directly to item management debug")
	_expect(not registry.stage_picker.open, "switching to item management should close stage debug")
	_expect(registry.mythic_item_runtime.open, "item management debug should be open")
	_expect(registry.mythic_item_runtime.prewarm_count == 1, "item management debug should prewarm before opening")

	_expect(_press(input, owner, KEY_F4), "F4 should switch directly to perk picker debug")
	_expect(not registry.mythic_item_runtime.open, "switching to perk picker should close item management debug")
	_expect(registry.perk_picker.open, "perk picker debug should be open")
	_expect(registry.perk_picker.prewarm_count == 1, "perk picker debug should prewarm before opening")

	_expect(_press(input, owner, KEY_F9), "F9 should switch directly to ball-speed debug")
	_expect(not registry.perk_picker.open, "switching to ball-speed debug should close perk picker")
	_expect(registry.ball_speed.active, "ball-speed debug should be active")

	_expect(_press(input, owner, KEY_F6), "F6 should switch directly to weather debug")
	_expect(not registry.ball_speed.active, "switching to weather debug should close ball-speed debug")
	_expect(registry.weather_picker.open, "weather debug should be open")

	_expect(_press(input, owner, KEY_F7), "F7 should switch directly to lingpet debug")
	_expect(not registry.weather_picker.open, "switching to lingpet debug should close weather debug")
	_expect(registry.lingpet_picker.open, "lingpet debug should be open")

	_expect(_press(input, owner, KEY_F2), "F2 should switch back from weather debug")
	_expect(not registry.lingpet_picker.open, "switching to item spawn should close lingpet debug")
	_expect(registry.active_item_runtime.open, "item spawn debug should reopen after direct switch")

	_expect(_press(input, owner, KEY_F2), "pressing the already-open debug key should close that debug")
	_expect(not registry.active_item_runtime.open, "same debug key should toggle its screen off")
	_expect(_press(input, owner, KEY_TAB), "TAB should open character info")
	_expect(registry.character_info.active, "TAB should open character info overlay")
	_expect(registry.character_info.prewarm_count == 1, "TAB should prewarm character info before opening")
	_expect(registry.character_info.last_owner == owner, "TAB character info prewarm should receive owner")
	_expect(registry.character_info.last_registry == registry, "TAB character info prewarm should receive registry")
	_expect(registry.character_info.last_module_getter_valid, "TAB character info prewarm should receive module getter")
	_expect(registry.character_info.last_include_shared_icon_assets, "TAB character info prewarm should include shared icon assets")
	_expect(registry.character_info.last_view_size.x > 0.0 and registry.character_info.last_view_size.y > 0.0, "TAB character info prewarm should receive the current view size")
	_expect(owner.redraw_count >= 9, "each debug key switch should queue redraw")
	registry.character_info.close()
	registry.character_info.last_owner = null
	registry.character_info.last_registry = null

	print("debug_menu_direct_switch_smoke: ok")
	quit(0)


func _press(input: Object, owner: Object, keycode: int) -> bool:
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = keycode
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = keycode
	return bool(input.handle_input(event, owner, registry, Callable(self, "_get_module"), {}))


func _get_module(key: String) -> Object:
	return registry.get_instance(key)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
