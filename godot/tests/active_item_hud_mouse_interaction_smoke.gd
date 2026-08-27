extends SceneTree

const ActiveItemHudInteractionController := preload("res://scripts/hud/active_item_hud_interaction_controller.gd")
const ActiveItemHudTooltipRenderer := preload("res://scripts/hud/active_item_hud_tooltip_renderer.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = [
		{"name": "gauge_charge", "display_name": "탕약", "description": "기력을 회복합니다."},
		{"name": "dash_boost", "display_name": "축지부", "description": "활주를 강화합니다."},
	]
	var redraw_requests := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1000.0, 900.0))

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeLayout:
	extends RefCounted

	func build_layout(
		_view_size: Vector2,
		_game_offset: Vector2,
		_game_size: Vector2,
		_gameplay_width: float,
		item_count: int,
		_slot_capacity: int
	) -> Dictionary:
		var rects: Array[Rect2] = []
		for index in range(maxi(3, item_count)):
			rects.append(Rect2(100.0 + float(index) * 50.0, 700.0, 42.0, 42.0))
		return {
			"visible": true,
			"slot_rects": rects,
			"actual_item_count": item_count,
		}


class FakeRuntime:
	extends RefCounted

	var used_slots: Array[int] = []

	func use_slot(slot_index: int, _owner: Object, _registry: Object) -> bool:
		used_slots.append(slot_index)
		return true


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(_module_getter: Callable, _battle_initialized: bool, _landing_started: bool) -> bool:
		return false


class FakeModules:
	extends RefCounted

	var layout := FakeLayout.new()
	var runtime := FakeRuntime.new()
	var interaction := ActiveItemHudInteractionController.new()
	var readiness := FakeReadiness.new()

	func get_module(key: String) -> Object:
		match key:
			"active_item_hud_layout":
				return layout
			"active_item_runtime":
				return runtime
			"active_item_hud_interaction":
				return interaction
			"battle_scene_readiness_controller":
				return readiness
		return null


func _init() -> void:
	_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_slot_hit_testing_and_click_use()
	_verify_battle_input_route()
	_verify_tooltip_content()
	_verify_runtime_wiring()
	_restore_settings_snapshot()
	if _failures.is_empty():
		print("active_item_hud_mouse_interaction_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_slot_hit_testing_and_click_use() -> void:
	var owner := FakeOwner.new()
	var modules := FakeModules.new()
	var interaction := ActiveItemHudInteractionController.new()
	var module_getter := Callable(modules, "get_module")
	var layout: Dictionary = modules.layout.build_layout(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 760.0, 2, 3)
	_expect(interaction.resolve_hovered_slot(layout, 2, Vector2(121.0, 721.0)) == 0, "first occupied slot should resolve from the shared HUD rect")
	_expect(interaction.resolve_hovered_slot(layout, 2, Vector2(221.0, 721.0)) == -1, "empty capacity slots must not expose a tooltip or click target")

	var locked_click := _left_click(Vector2(121.0, 721.0))
	_expect(not interaction.handle_input(locked_click, owner, null, module_getter, false), "slot clicks should stay disabled before battle initialization")
	_expect(modules.runtime.used_slots.is_empty(), "a pre-battle click must not use an item")

	var outside_click := _left_click(Vector2(20.0, 20.0))
	_expect(not interaction.handle_input(outside_click, owner, null, module_getter, true), "clicks outside the HUD should pass through")
	_expect(interaction.handle_input(_left_click(Vector2(121.0, 721.0)), owner, null, module_getter, true), "left-clicking an occupied active-item slot should be handled")
	_expect(modules.runtime.used_slots == [0], "the clicked slot index must route through active_item_runtime.use_slot")


func _verify_battle_input_route() -> void:
	var owner := FakeOwner.new()
	var modules := FakeModules.new()
	var input_controller := BattleSceneInputController.new()
	input_controller.handle_unhandled_input(
		_left_click(Vector2(171.0, 721.0)),
		owner,
		null,
		Callable(modules, "get_module"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)
	_expect(modules.runtime.used_slots == [1], "battle input router should activate the exact HUD slot that was clicked")


func _verify_tooltip_content() -> void:
	var tooltip := ActiveItemHudTooltipRenderer.new()
	var ready_data: Dictionary = tooltip.build_tooltip_data(
		{"name": "gauge_charge"},
		{"cooldown_remaining_ratio": 0.0, "throw_lock_remaining_seconds": 0},
		0
	)
	_expect(str(ready_data.get("title", "")) == "탕약", "tooltip should show the localized active-item name")
	_expect(str(ready_data.get("body", "")).find("기력을 220") >= 0, "tooltip should show the active-item description")
	_expect(str(ready_data.get("hint", "")) == "슬롯 1 · 좌클릭으로 사용", "tooltip should explain click activation")
	_expect(str(ready_data.get("status", "")) == "사용 가능", "ready item tooltip should show its readiness")

	var cooldown_data: Dictionary = tooltip.build_tooltip_data(
		{"name": "dash_boost"},
		{"cooldown_remaining_ratio": 0.5, "throw_lock_remaining_seconds": 0},
		1
	)
	_expect(str(cooldown_data.get("status", "")) == "재사용 대기 중", "cooling item tooltip should expose the cooldown state")


func _verify_runtime_wiring() -> void:
	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_hud_module_catalog.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/active_item_hud_renderer.gd")
	_expect(catalog_source.find("active_item_hud_interaction") >= 0, "HUD module catalog should register the interaction owner")
	_expect(input_source.find("_handle_active_item_hud_input") >= 0, "battle input should route desktop mouse events to the active-item HUD")
	_expect(renderer_source.find("_draw_hover_tooltip") >= 0, "active-item HUD renderer should draw the hover tooltip")


func _left_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {"had": had_original, "bytes": original_bytes}


func _restore_settings_snapshot() -> void:
	if bool(_settings_snapshot.get("had", false)):
		var file := FileAccess.open(LanguageSettings.SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_settings_snapshot.get("bytes", PackedByteArray()))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
