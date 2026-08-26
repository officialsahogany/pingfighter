extends SceneTree

# expect-zero-object-leaks
const BattleLingpetPriorityInputRouter := preload(
	"res://scripts/core/battle_lingpet_priority_input_router.gd"
)
const BattleSceneOverlayInputController := preload(
	"res://scripts/core/battle_scene_overlay_input_controller.gd"
)

const PRE_DECOMPOSITION_OWNER_COMMIT := "55ca58260"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModalGate:
	extends RefCounted

	var acquire_active := false
	var overflow_active := false
	var guardian_enhance_active := false
	var grip_active := false
	var tutorial_active := false
	var character_debug_open := false
	var weather_debug_open := false
	var stage_debug_open := false
	var lingpet_debug_open := false
	var mythic_debug_open := false
	var perk_debug_open := false
	var runtime_perk_active := false
	var pause_active := false
	var elixir_active := false
	var character_info_active := false

	func is_lingpet_acquire_cutin_active(_module_getter: Callable) -> bool:
		return acquire_active

	func is_lingpet_overflow_choice_active(_module_getter: Callable) -> bool:
		return overflow_active

	func is_lingpet_guardian_enhance_cutin_active(_module_getter: Callable) -> bool:
		return guardian_enhance_active

	func is_grip_style_selection_active(_module_getter: Callable) -> bool:
		return grip_active

	func is_skill_orb_tooltip_tutorial_active(_module_getter: Callable) -> bool:
		return tutorial_active

	func is_character_debug_picker_open(_module_getter: Callable) -> bool:
		return character_debug_open

	func is_weather_debug_picker_open(_module_getter: Callable) -> bool:
		return weather_debug_open

	func is_stage_debug_picker_open(_module_getter: Callable) -> bool:
		return stage_debug_open

	func is_lingpet_debug_picker_open(_module_getter: Callable) -> bool:
		return lingpet_debug_open

	func is_mythic_management_menu_open(_module_getter: Callable) -> bool:
		return mythic_debug_open

	func is_perk_debug_picker_open(_module_getter: Callable) -> bool:
		return perk_debug_open

	func is_runtime_perk_choice_active(_module_getter: Callable) -> bool:
		return runtime_perk_active

	func is_pause_menu_active(_module_getter: Callable) -> bool:
		return pause_active

	func is_elixir_cinematic_active(_module_getter: Callable) -> bool:
		return elixir_active

	func is_character_info_active(_module_getter: Callable) -> bool:
		return character_info_active


class FakeInputSurface:
	extends RefCounted

	var handle_count := 0
	var handled_result := false

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		handle_count += 1
		return handled_result


class FakePauseMenu:
	extends RefCounted

	var handle_count := 0

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		handle_count += 1
		return false


class FakeRuntimePerkState:
	extends RefCounted

	var handle_count := 0

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		handle_count += 1
		return false


class FakeLingpetRuntime:
	extends RefCounted

	func is_acquire_cutin_awaiting_dismiss() -> bool:
		return false


class FakeOverflowHost:
	extends RefCounted

	var handle_count := 0

	func handle_input(
		_event: InputEvent,
		_runtime: Object,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		handle_count += 1
		return false


class FakePreOverflowModalRouter:
	extends RefCounted

	var active := false
	var handle_count := 0

	func is_active(_module_getter: Callable) -> bool:
		return active

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_view_size: Vector2
	) -> bool:
		handle_count += 1
		return false


class FakeBallSpeedDebug:
	extends RefCounted

	var toggle_count := 0

	func is_active() -> bool:
		return false

	func toggle() -> void:
		toggle_count += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_cached_instance(key: String) -> Object:
		return _as_object(instances.get(key, null))

	func get_instance(key: String) -> Object:
		return _as_object(instances.get(key, null))

	func _as_object(value: Variant) -> Object:
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


func _init() -> void:
	_verify_production_wiring_and_canonical_order()
	_verify_pause_beats_character_info()
	_verify_debug_menu_beats_perk_picker()
	_verify_lingpet_priority_beats_guided_overlay()
	_verify_f9_remains_after_open_picker_input()
	_verify_missing_shortcut_targets_fall_through()
	_verify_pre_overflow_insertion_swallow_contract()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_overlay_input_priority_preservation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_production_wiring_and_canonical_order() -> void:
	var shell_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_shell.gd"
	)
	var scene_input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	var overlay_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	var lingpet_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_lingpet_priority_input_router.gd"
	)
	var guided_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_guided_overlay_input_router.gd"
	)
	var debug_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_debug_menu_input_router.gd"
	)
	var catalog_source := FileAccess.get_file_as_string(
		"res://scripts/resources/gameplay_core_module_catalog.gd"
	)

	_expect_tokens_in_order(
		overlay_source,
		[
			"_lingpet_priority_input_router.handle_input(",
			"_guided_overlay_input_router.handle_input(",
			"_debug_menu_shortcut_router.handle_primary_shortcut_input(",
			"_debug_menu_input_router.handle_pre_ball_speed_menu_input(",
			"_debug_menu_shortcut_router.handle_ball_speed_shortcut_input(",
			"_debug_menu_input_router.handle_post_ball_speed_menu_input(",
			"_runtime_perk_input_router.handle_active_choice_input(",
			"_pause_menu_input_router.handle_active_input(",
			"_elixir_cinematic_input_router.handle_input(",
			"_character_info_input_router.handle_active_input(",
			"_pause_menu_input_router.handle_open_shortcut(",
			"_character_info_input_router.handle_open_shortcut(",
			"_runtime_perk_input_router.handle_debug_grant_input(",
			"_active_item_debug_input_router.handle_input(",
		],
		"post-decomposition facade must preserve the full %s route order" % PRE_DECOMPOSITION_OWNER_COMMIT
	)
	_expect_tokens_in_order(
		lingpet_source,
		[
			"is_lingpet_acquire_cutin_active",
			"_handle_pre_overflow_modal_input(",
			"is_lingpet_overflow_choice_active",
			"is_lingpet_guardian_enhance_cutin_active",
		],
		"Lingpet route must keep acquisition, the X1 seam, overflow, and enhancement order"
	)
	_expect_tokens_in_order(
		guided_source,
		["is_grip_style_selection_active", "is_skill_orb_tooltip_tutorial_active"],
		"guided overlay router must preserve grip-before-tooltip order"
	)
	_expect_tokens_in_order(
		debug_source,
		[
			"is_character_debug_picker_open",
			"is_weather_debug_picker_open",
			"is_stage_debug_picker_open",
			"is_lingpet_debug_picker_open",
			"is_mythic_management_menu_open",
			"is_perk_debug_picker_open",
		],
		"debug router must preserve the original active-menu order around F9"
	)
	_expect(
		shell_source.contains("input_controller.handle_unhandled_input("),
		"battle_scene_shell must enter the production scene input controller"
	)
	_expect(
		scene_input_source.contains("overlay_input.handle_input("),
		"scene input controller must dispatch into the overlay facade"
	)
	_expect(
		catalog_source.contains(
			'"path": "res://scripts/core/battle_scene_overlay_input_controller.gd"'
		),
		"module catalog must instantiate the production overlay facade"
	)
	for router_path in [
		"battle_active_item_debug_input_router.gd",
		"battle_character_info_input_router.gd",
		"battle_debug_menu_input_router.gd",
		"battle_elixir_cinematic_input_router.gd",
		"battle_guided_overlay_input_router.gd",
		"battle_pause_menu_input_router.gd",
	]:
		_expect(
			overlay_source.contains(router_path),
			"production facade must preload %s" % router_path
		)


func _verify_pause_beats_character_info() -> void:
	var registry := _base_registry()
	var gate: FakeModalGate = registry.instances["battle_scene_modal_gate_controller"]
	var pause := FakePauseMenu.new()
	var character_info := FakeInputSurface.new()
	gate.pause_active = true
	gate.character_info_active = true
	registry.instances["pause_menu_overlay"] = pause
	registry.instances["character_info_overlay"] = character_info
	var consumed := _route_overlay(InputEventMouseMotion.new(), registry)
	_expect(consumed, "simultaneous pause and character info must consume input")
	_expect(pause.handle_count == 1, "pause must receive simultaneous modal input first")
	_expect(character_info.handle_count == 0, "character info must not see pause-owned input")


func _verify_debug_menu_beats_perk_picker() -> void:
	var registry := _base_registry()
	var gate: FakeModalGate = registry.instances["battle_scene_modal_gate_controller"]
	var character_picker := FakeInputSurface.new()
	var perk_picker := FakeInputSurface.new()
	gate.character_debug_open = true
	gate.perk_debug_open = true
	registry.instances["character_debug_picker"] = character_picker
	registry.instances["runtime_perk_debug_picker"] = perk_picker
	var consumed := _route_overlay(InputEventMouseMotion.new(), registry)
	_expect(consumed, "simultaneous debug menus must consume input")
	_expect(character_picker.handle_count == 1, "character debug menu must outrank perk picker")
	_expect(perk_picker.handle_count == 0, "perk picker must not see earlier debug-menu input")


func _verify_lingpet_priority_beats_guided_overlay() -> void:
	var registry := _base_registry()
	var gate: FakeModalGate = registry.instances["battle_scene_modal_gate_controller"]
	var grip := FakeInputSurface.new()
	gate.acquire_active = true
	gate.grip_active = true
	registry.instances["lingpet_egg_runtime"] = FakeLingpetRuntime.new()
	registry.instances["grip_style_selection_overlay"] = grip
	var consumed := _route_overlay(InputEventMouseMotion.new(), registry)
	_expect(consumed, "simultaneous Lingpet and guided overlays must consume input")
	_expect(grip.handle_count == 0, "Lingpet acquisition must outrank guided overlay input")


func _verify_f9_remains_after_open_picker_input() -> void:
	var registry := _base_registry()
	var gate: FakeModalGate = registry.instances["battle_scene_modal_gate_controller"]
	var character_picker := FakeInputSurface.new()
	var ball_speed := FakeBallSpeedDebug.new()
	gate.character_debug_open = true
	registry.instances["character_debug_picker"] = character_picker
	registry.instances["ball_speed_debug_overlay"] = ball_speed
	var consumed := _route_overlay(_key_press(KEY_F9), registry)
	_expect(consumed, "an open debug picker must swallow F9")
	_expect(character_picker.handle_count == 1, "open picker must receive F9 before the ball-speed shortcut")
	_expect(ball_speed.toggle_count == 0, "F9 must not jump ahead of an open pre-F9 picker")


func _verify_missing_shortcut_targets_fall_through() -> void:
	var registry := _base_registry()
	_expect(
		not _route_overlay(_key_press(KEY_TAB), registry),
		"TAB must fall through when character-info target is unavailable"
	)
	_expect(
		not _route_overlay(_key_press(KEY_ESCAPE), registry),
		"Escape must fall through when pause target is unavailable"
	)


func _verify_pre_overflow_insertion_swallow_contract() -> void:
	var registry := _base_registry()
	var gate: FakeModalGate = registry.instances["battle_scene_modal_gate_controller"]
	var overflow_host := FakeOverflowHost.new()
	var inserted_router := FakePreOverflowModalRouter.new()
	registry.instances["lingpet_egg_runtime"] = FakeLingpetRuntime.new()
	registry.instances["lingpet_overflow_choice_overlay_host"] = overflow_host
	gate.overflow_active = true
	inserted_router.active = true
	var consumed := BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventMouseMotion.new(),
		FakeOwner.new(),
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0),
		inserted_router
	)
	_expect(consumed, "active pre-overflow modal must swallow locally unhandled input")
	_expect(inserted_router.handle_count == 1, "active inserted modal must receive input once")
	_expect(overflow_host.handle_count == 0, "inserted modal must outrank overflow")

	gate.acquire_active = true
	BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventMouseMotion.new(),
		FakeOwner.new(),
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0),
		inserted_router
	)
	_expect(inserted_router.handle_count == 1, "acquisition must outrank the inserted modal")

	gate.acquire_active = false
	inserted_router.active = false
	BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventMouseMotion.new(),
		FakeOwner.new(),
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0),
		inserted_router
	)
	_expect(overflow_host.handle_count == 1, "inactive inserted modal must yield to overflow")


func _base_registry() -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances["battle_scene_modal_gate_controller"] = FakeModalGate.new()
	return registry


func _route_overlay(event: InputEvent, registry: FakeRegistry) -> bool:
	return bool(BattleSceneOverlayInputController.new().handle_input(
		event,
		FakeOwner.new(),
		registry,
		Callable(registry, "get_instance"),
		{}
	))


func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _expect_tokens_in_order(source: String, tokens: Array, message: String) -> void:
	var cursor := -1
	for token_value in tokens:
		var token := str(token_value)
		var next_index := source.find(token, cursor + 1)
		if next_index < 0:
			_failures.append("%s; missing/out-of-order token: %s" % [message, token])
			return
		cursor = next_index


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
