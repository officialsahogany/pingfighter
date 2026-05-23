extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const MatchScoreboardFlowController := preload("res://scripts/core/match_scoreboard_flow_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemPandoraLegacyRuntime := preload("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
const MythicItemPandoraSelectionRenderer := preload("res://scripts/items/mythic_item_pandora_selection_renderer.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var selected_character_type := "smasher"
	var accessory_slot_count := 2
	var pandora_legacy_equipped := false
	var pandora_legacy_active := false
	var pandora_legacy_pending := false
	var pandora_legacy_selection_active := false
	var pandora_legacy_selection_items: Array = []
	var pandora_legacy_selected_index := 0
	var redraw_calls := 0

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeRegistry:
	var mythic_item_runtime: Object
	var active_item_runtime: Object

	func _init(mythic_runtime: Object, active_runtime: Object = null) -> void:
		mythic_item_runtime = mythic_runtime
		active_item_runtime = active_runtime

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"active_item_runtime":
				return active_item_runtime
		return null


class FakeScoreboard:
	var result := 1

	func update_scoreboard(_delta: float) -> int:
		return result


class FakeRoundState:
	var prepare_calls := 0

	func prepare_serve_after_scoreboard() -> void:
		prepare_calls += 1


class FakeModuleGetter:
	var mythic_item_runtime: Object
	var modal_gate: Object = BattleSceneModalGateController.new()

	func _init(runtime: Object) -> void:
		mythic_item_runtime = runtime

	func get_module(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"battle_scene_modal_gate_controller":
				return modal_gate
		return null


class CallbackSink:
	var reset_calls := 0

	func reset_ball() -> void:
		reset_calls += 1


func _init() -> void:
	_verify_pandora_runtime_owns_selection_constants()

	var catalog: Object = MythicItemCatalog.new()
	_verify_selection_renderer_loads_icons_through_project_loader(catalog)
	var item_data: Dictionary = catalog.build_item_by_name("pandora_legacy")
	_expect(not item_data.is_empty(), "Pandora Legacy should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "판도라의 유산", "Pandora Legacy should use Korean display text")
	_expect(str(item_data.get("slot", "")) == "back", "Pandora Legacy should use the back slot")
	_expect(str(item_data.get("type", "")) == "mythic", "Pandora Legacy should be a mythic item")
	_expect_close(float(item_data.get("chance", 0.0)), 0.00008, "Pandora Legacy field chance should match Python")
	_expect(catalog.get_roll_options("pandora_legacy").size() == 2, "Pandora Legacy should expose two roll options")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "pandora_legacy"), "Pandora Legacy should be in the field spawn pool")
	_expect(_array_has_item(catalog.get_debug_items(), "pandora_legacy"), "Pandora Legacy should be in the debug item list")
	_expect_icon_asset(item_data)

	var runtime: Object = MythicItemRuntime.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, active_runtime)
	_expect(
		runtime.acquire_item("pandora_legacy", owner, registry, {"trigger_chance": 100.0, "selection_quality": 100.0}, true, false) >= 0,
		"Pandora Legacy should acquire and auto-equip"
	)
	_expect(owner.pandora_legacy_equipped, "Pandora Legacy should sync equipped state")
	_expect(owner.pandora_legacy_active, "Pandora Legacy should sync active state")
	_expect_close(runtime.get_pandora_legacy_trigger_chance(), 100.0, "trigger override should be consumed by runtime")
	_expect_close(runtime.get_pandora_legacy_selection_quality(), 100.0, "selection quality override should be consumed by runtime")

	var choices: Array = runtime.generate_pandora_legacy_selection_choices(owner, registry)
	_expect(choices.size() == 3, "Pandora Legacy should generate three choices")
	_expect(_choices_are_unique(choices), "Pandora choices should be unique")
	_expect(not _array_has_item(choices, "pandora_legacy"), "Pandora Legacy should not offer itself")

	_expect(runtime.try_queue_pandora_legacy_round_win({"owner": owner, "registry": registry}), "100 percent trigger should queue a selection")
	_expect(runtime.has_pending_pandora_legacy_selection(), "queued Pandora selection should be pending")
	var scoreboard := FakeScoreboard.new()
	var round_state := FakeRoundState.new()
	var callbacks := CallbackSink.new()
	MatchScoreboardFlowController.new().update_scoreboard(
		0.0,
		{
			"scoreboard_state": scoreboard,
			"round_state": round_state,
			"mythic_item_runtime": runtime,
			"owner": owner,
			"registry": registry,
		},
		{"reset_ball": Callable(callbacks, "reset_ball")},
		{"update_start_serve": 1}
	)
	_expect(callbacks.reset_calls == 1, "scoreboard flow should still reset the ball before Pandora selection")
	_expect(round_state.prepare_calls == 1, "scoreboard flow should prepare the next serve")
	_expect(runtime.is_pandora_legacy_selection_active(), "pending Pandora selection should open after scoreboard")
	_expect(runtime.should_pause_game(), "open Pandora selection should pause gameplay")
	var timer_before: float = float(runtime.get_snapshot().get("pandora_legacy_selection_timer_frames", 0.0))
	var module_getter := FakeModuleGetter.new(runtime)
	_expect(
		BattleSceneOverlayFrameController.new().process_idle(
			1.0 / 60.0,
			owner,
			registry,
			Callable(module_getter, "get_module")
		),
		"active Pandora selection should be handled by the overlay frame"
	)
	var timer_after: float = float(runtime.get_snapshot().get("pandora_legacy_selection_timer_frames", 0.0))
	_expect(timer_after > timer_before, "Pandora selection fade timer should advance while gameplay is paused")

	var active_owner := FakeOwner.new()
	var active_registry := FakeRegistry.new(MythicItemRuntime.new(), ActiveItemRuntime.new())
	active_owner.active_item_slots = [{"name": "soap"}, {"name": "flare"}, {"name": "wall"}]
	var active_runtime_for_selection: Object = active_registry.mythic_item_runtime
	_expect(active_runtime_for_selection.start_pandora_legacy_selection([
		{"name": "banana", "pandora_source": "active"},
		{"name": "boomerang", "pandora_source": "active"},
		{"name": "stopwatch", "pandora_source": "active"},
	], active_owner, active_registry), "manual active-choice selection should open")
	_expect(active_runtime_for_selection.confirm_pandora_legacy_selection(0, active_owner, active_registry), "active Pandora choice should grant")
	_expect(active_owner.active_item_slots.size() == 4, "active Pandora choice should overflow into the active slot list")
	_expect(str(active_owner.active_item_slots.back().get("name", "")) == "banana", "active Pandora choice should grant the selected item")

	var passive_runtime: Object = MythicItemRuntime.new()
	var passive_owner := FakeOwner.new()
	var passive_registry := FakeRegistry.new(passive_runtime, ActiveItemRuntime.new())
	_expect(passive_runtime.start_pandora_legacy_selection([
		{"name": "speedboots", "pandora_source": "passive"},
		{"name": "sensor", "pandora_source": "passive"},
		{"name": "ragnarok_hammer", "pandora_source": "mythic"},
	], passive_owner, passive_registry), "manual passive-choice selection should open")
	_expect(passive_runtime.confirm_pandora_legacy_selection(0, passive_owner, passive_registry), "passive Pandora choice should grant")
	_expect(_inventory_has_item(passive_runtime, "speedboots"), "passive Pandora choice should enter passive inventory")

	print("pandora_legacy_port_smoke: ok")
	quit(0)


func _verify_pandora_runtime_owns_selection_constants() -> void:
	_expect(MythicItemPandoraLegacyRuntime.CARD_COUNT == 3, "Pandora runtime should own the selection card count")
	_expect(
		str(MythicItemPandoraLegacyRuntime.ACTIVE_ITEM_KOREAN_NAMES.get("banana", "")) == "바나나",
		"Pandora runtime should own active-item Korean names"
	)
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	_expect(runtime_source.find("PANDORA_ACTIVE_ITEM_KOREAN_NAMES") < 0, "mythic runtime should not keep Pandora active-item names inline")
	_expect(runtime_source.find("PANDORA_SELECTION_CARD_COUNT") < 0, "mythic runtime should not keep Pandora card-count constants inline")
	_expect(runtime_source.find("_get_pandora_card_index_at") < 0, "mythic runtime should not keep Pandora card-index bridge methods inline")
	_expect(runtime_source.find("_clear_pandora_legacy_runtime") < 0, "mythic runtime should not keep Pandora clear bridge methods inline")


func _verify_selection_renderer_loads_icons_through_project_loader(catalog: Object) -> void:
	ProjectResourceLoader.clear_caches()
	var renderer: Object = MythicItemPandoraSelectionRenderer.new()
	var item_data: Dictionary = catalog.build_item_by_name("sensor")
	var icon_path: String = str(item_data.get("icon_path", ""))
	var cache: Dictionary = {}
	var texture: Texture2D = renderer.get_choice_icon_texture(item_data, cache)
	_expect(texture != null, "Pandora selection renderer should load passive icons")
	_expect(cache.has(icon_path), "Pandora selection renderer should keep its local icon cache")
	_expect(ProjectResourceLoader.get_cached_texture(icon_path) != null, "Pandora selection renderer should route icon loads through ProjectResourceLoader")


func _expect_icon_asset(item_data: Dictionary) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "Pandora Legacy icon should load")
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "Pandora Legacy icon should use the 32px source")
	_expect(str(item_data.get("icon_sheet_path", "")) != "", "Pandora Legacy should expose an animated icon sheet")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "Pandora Legacy should expose 32 smooth icon frames")
	_expect(int(item_data.get("icon_frame_msec", 0)) == 33, "Pandora Legacy icon should use the shared mythic frame cadence")
	_expect(bool(item_data.get("icon_fill_slot", false)), "Pandora Legacy animated icon should fill the mythic slot box")
	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null and sheet.get_size() == Vector2(1024.0, 32.0), "Pandora Legacy icon sheet should load as 32 smooth 32px frames")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _choices_are_unique(items: Array) -> bool:
	var names: Dictionary = {}
	for item_value in items:
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "" or names.has(item_name):
			return false
		names[item_name] = true
	return true


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if abs(actual - expected) <= tolerance:
		return
	push_error("%s (actual=%s expected=%s)" % [message, actual, expected])
	quit(1)
