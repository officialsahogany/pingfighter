extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDebugPicker := preload("res://scripts/hud/runtime_perk_debug_picker.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")


class FakeOwner:
	var selected_character_type := "viper"


class CountingCatalog:
	var calls := 0

	func get_debug_perk_entries(_character_type: String = "") -> Array:
		calls += 1
		return [{
			"id": "four_poisons",
			"name": "Four Poisons",
			"max_level": 5,
			"debug_group": "viper",
			"icon_color": Color(0.6, 0.8, 1.0),
		}]


class CountingIconRenderer:
	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeRuntimeState:
	extends RefCounted

	var grant_starts_cinematic := false
	var debug_grant_calls := 0
	var last_perk_id := ""

	func debug_set_perk_level(perk_id: String, _target_level: int, _owner: Object, registry: Object, _catalog: Object) -> bool:
		debug_grant_calls += 1
		last_perk_id = perk_id
		if grant_starts_cinematic and registry != null and registry.has_method("get_instance"):
			var mythic_runtime: Object = registry.get_instance("mythic_item_runtime")
			if mythic_runtime != null:
				mythic_runtime.set("active", true)
		return true


class FakeMythicRuntime:
	extends RefCounted

	var active := false

	func is_acquisition_cinematic_active() -> bool:
		return active


class FakeCatalog:
	extends RefCounted

	var entries: Array = []

	func _init(initial_entries: Array) -> void:
		entries = initial_entries

	func get_debug_perk_entries(_character_type: String = "") -> Array:
		return entries


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(initial_instances: Dictionary) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_icon_renderer_prewarm()
	_verify_debug_picker_prewarm()
	_verify_debug_picker_uses_paged_draw_budget()
	_verify_debug_picker_closes_for_mythic_cinematic_grant()

	if _failures.is_empty():
		print("runtime_perk_debug_picker_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_icon_renderer_prewarm() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	_expect(renderer.has_method("prewarm_assets"), "runtime perk icon renderer should expose boot prewarm")
	_expect(renderer.has_method("prewarm_assets_step"), "runtime perk icon renderer should expose staged boot prewarm")
	renderer.prewarm_assets()
	_expect(renderer._texture_cache.size() >= RuntimePerkIconRenderer.PERK_ICON_PATHS.size(), "perk icon prewarm should populate static perk texture cache")
	_expect(renderer._sheet_cache.size() >= RuntimePerkIconRenderer.PERK_SHEET_PATHS.size(), "perk icon prewarm should populate animated sheet cache")
	_expect(renderer._static_source_cache.has("four_poisons"), "prewarm should cache static perk icon sources for repeat choice draws")
	_expect(renderer._static_source_cache.has("smasher_wheel"), "prewarm should cache normalized active skill icon sources")
	_expect(renderer._static_source_cache.has("unlock_smasher_wheel"), "prewarm should cache unlock alias icon sources")
	_expect(not renderer._sheet_region_cache.is_empty(), "prewarm should cache animated sheet region metadata")
	_expect(renderer.has_icon("four_poisons"), "prewarmed renderer should keep Viper perk PNG available")
	_expect(renderer.has_icon("instant_treasure_hunt"), "prewarmed renderer should keep instant perk sheet available")
	var first_smasher_source: Dictionary = renderer._get_icon_source("smasher_wheel")
	var second_smasher_source: Dictionary = renderer._get_icon_source("smasher_wheel")
	_expect(first_smasher_source.get("texture", null) == second_smasher_source.get("texture", null), "cached skill icon sources should reuse normalized textures")

	var staged_renderer := RuntimePerkIconRenderer.new()
	var step_count := 0
	while not staged_renderer.prewarm_assets_step(5):
		step_count += 1
		_expect(step_count < 64, "staged perk icon prewarm should finish in a bounded number of chunks")
	_expect(step_count > 0, "staged perk icon prewarm should split texture work across chunks")
	_expect(staged_renderer._texture_cache.size() >= RuntimePerkIconRenderer.PERK_ICON_PATHS.size(), "staged perk icon prewarm should populate static texture cache")
	_expect(staged_renderer._static_source_cache.has("unlock_smasher_wheel"), "staged perk icon prewarm should cache unlock alias icon sources")


func _verify_debug_picker_prewarm() -> void:
	var catalog := RuntimePerkCatalog.new()
	var renderer := RuntimePerkIconRenderer.new()
	var picker := RuntimePerkDebugPicker.new()
	var owner := FakeOwner.new()
	picker.prewarm_assets(catalog, owner, renderer)
	_expect(renderer._texture_cache.size() >= RuntimePerkIconRenderer.PERK_ICON_PATHS.size(), "debug picker prewarm should delegate to icon renderer")
	_expect(picker._text_prewarmed, "debug picker prewarm should warm card text metrics")
	_expect(not picker._cached_entries.is_empty(), "debug picker prewarm should cache debug entries before first draw")

	var counting_catalog := CountingCatalog.new()
	var counting_renderer := CountingIconRenderer.new()
	var counting_picker := RuntimePerkDebugPicker.new()
	counting_picker.prewarm_assets(counting_catalog, owner, counting_renderer)
	_expect(counting_catalog.calls == 1, "debug picker prewarm should build entries once")
	counting_picker._get_cached_entries(counting_catalog, owner)
	_expect(counting_catalog.calls == 1, "first draw should reuse prewarmed debug entries")
	counting_picker.prewarm_assets(counting_catalog, owner, counting_renderer)
	_expect(counting_catalog.calls == 1, "repeated prewarm for the same character should keep cached entries")
	_expect(counting_renderer.prewarm_count == 1, "repeated picker prewarm should not rerun icon prewarm")


func _verify_debug_picker_uses_paged_draw_budget() -> void:
	var catalog := RuntimePerkCatalog.new()
	var picker := RuntimePerkDebugPicker.new()
	var entries: Array = catalog.get_debug_perk_entries()
	_expect(entries.size() > RuntimePerkDebugPicker.MAX_VISIBLE_CARDS, "debug picker smoke needs enough perks to exercise pagination")
	var visible: Array = picker._get_visible_entries(entries)
	_expect(visible.size() <= RuntimePerkDebugPicker.MAX_VISIBLE_CARDS, "debug picker should cap per-frame card draw count")
	picker.page_index = 1
	var page_two: Array = picker._get_visible_entries(entries)
	_expect(not page_two.is_empty(), "debug picker should expose later pages")
	_expect(str(page_two[0].get("id", "")) != str(visible[0].get("id", "")), "debug picker page changes should shift the visible entry window")


func _verify_debug_picker_closes_for_mythic_cinematic_grant() -> void:
	var view_size := Vector2(1280.0, 720.0)
	var owner := FakeOwner.new()
	var mythic_runtime := FakeMythicRuntime.new()
	var runtime_state := FakeRuntimeState.new()
	var catalog := FakeCatalog.new([{
		"id": "odins_eye",
		"name": "Odin's Eye",
		"max_level": 1,
		"rarity": "mythic",
		"debug_group": "converted_mythic",
	}])
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"runtime_perk_state": runtime_state,
		"mythic_item_runtime": mythic_runtime,
	})
	var picker := RuntimePerkDebugPicker.new()
	picker.toggle()
	runtime_state.grant_starts_cinematic = true
	var click := _click_first_debug_card(picker, view_size, catalog.entries)
	_expect(picker.handle_input(click, owner, registry, view_size), "debug picker should handle mythic card clicks")
	_expect(runtime_state.debug_grant_calls == 1, "debug picker should apply the clicked mythic debug grant")
	_expect(mythic_runtime.active, "mythic debug grant fixture should start the acquisition cinematic")
	_expect(not picker.is_open(), "debug picker should close after a grant starts the mythic acquisition cinematic")

	var normal_state := FakeRuntimeState.new()
	var normal_runtime := FakeMythicRuntime.new()
	var normal_catalog := FakeCatalog.new([{
		"id": "common_bulk_up",
		"name": "Bulk Up",
		"max_level": 5,
		"debug_group": "common",
	}])
	var normal_registry := FakeRegistry.new({
		"runtime_perk_catalog": normal_catalog,
		"runtime_perk_state": normal_state,
		"mythic_item_runtime": normal_runtime,
	})
	var normal_picker := RuntimePerkDebugPicker.new()
	normal_picker.toggle()
	var normal_click := _click_first_debug_card(normal_picker, view_size, normal_catalog.entries)
	_expect(normal_picker.handle_input(normal_click, owner, normal_registry, view_size), "debug picker should handle ordinary card clicks")
	_expect(normal_state.debug_grant_calls == 1, "debug picker should apply ordinary debug grants")
	_expect(normal_picker.is_open(), "debug picker should stay open for ordinary non-cinematic debug grants")


func _click_first_debug_card(picker: Object, view_size: Vector2, entries: Array) -> InputEventMouseButton:
	var visible_entries: Array = picker._get_visible_entries(entries)
	var panel_rect: Rect2 = picker._get_panel_rect(view_size, visible_entries.size())
	var layout: Dictionary = picker._build_grid_layout(panel_rect, visible_entries.size())
	var card_rect: Rect2 = picker._get_card_rect(0, panel_rect, layout)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = card_rect.get_center()
	return event


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
