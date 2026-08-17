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
	_verify_debug_picker_hover_tooltip_content_and_bounds()
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
	_expect(not renderer.has_icon("instant_treasure_hunt"), "retired Treasure Hunt should have no icon route")
	var first_smasher_source: Dictionary = renderer._get_icon_source("smasher_wheel")
	var second_smasher_source: Dictionary = renderer._get_icon_source("smasher_wheel")
	_expect(first_smasher_source.get("texture", null) == second_smasher_source.get("texture", null), "cached skill icon sources should reuse normalized textures")

	var staged_renderer := RuntimePerkIconRenderer.new()
	var step_count := 0
	var expected_max_chunks := ceili(float(staged_renderer._build_prewarm_asset_jobs().size()) / 5.0)
	while not staged_renderer.prewarm_assets_step(5):
		step_count += 1
	_expect(step_count <= expected_max_chunks, "staged perk icon prewarm should finish within its catalog-derived chunk budget")
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
	var all_entries: Array = catalog.get_debug_perk_entries()
	picker.selected_tab_index = 4
	var entries: Array = picker._get_entries_for_tab(all_entries, picker.selected_tab_index)
	_expect(entries.size() > RuntimePerkDebugPicker.MAX_VISIBLE_CARDS, "mugong tab needs enough entries to exercise pagination")
	var visible: Array = picker._get_visible_entries(entries)
	_expect(visible.size() <= RuntimePerkDebugPicker.MAX_VISIBLE_CARDS, "selected tab should cap per-frame card draw count")
	picker.page_index = 1
	var page_two: Array = picker._get_visible_entries(entries)
	_expect(not page_two.is_empty(), "mugong tab should expose later pages")
	_expect(str(page_two[0].get("id", "")) != str(visible[0].get("id", "")), "tab-local page changes should shift the visible entry window")


func _verify_debug_picker_hover_tooltip_content_and_bounds() -> void:
	var picker := RuntimePerkDebugPicker.new()
	picker.target_level = 3
	var real_entries: Array = RuntimePerkCatalog.new().get_debug_perk_entries("smasher")
	var found_real_chosik := false
	var found_real_vision_mugong := false
	var found_real_mugong := false
	for entry_value in real_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var content: Dictionary = picker._build_hover_tooltip_content(entry, 0)
		if not found_real_vision_mugong and picker._is_vision_mugong_entry(entry):
			found_real_vision_mugong = true
			_expect(str(content.get("kind", "")) == "비전초식", "real F4 vision entries should route to a 비전초식 tooltip")
			_expect(str(content.get("detail", "")) != "상세 설명이 없습니다.", "real F4 vision mugong entries should expose catalog tooltip copy")
		elif not found_real_chosik and (str(entry.get("unlocks_skill", "")) != "" or str(entry.get("id", "")).begins_with("unlock_")):
			found_real_chosik = true
			_expect(str(content.get("kind", "")) == "초식", "real F4 unlock entries should route to a 초식 tooltip")
			_expect(str(content.get("detail", "")) != "상세 설명이 없습니다.", "real F4 chosik entries should expose catalog tooltip copy")
		elif not found_real_mugong and not bool(entry.get("is_instant", false)) and str(entry.get("unlocks_skill", "")) == "" and not str(entry.get("id", "")).begins_with("unlock_"):
			found_real_mugong = true
			_expect(str(content.get("kind", "")) in ["무공", "절세무공"], "real F4 growth entries should route to a mugong tooltip")
			_expect(str(content.get("detail", "")) != "상세 설명이 없습니다.", "real F4 mugong entries should expose catalog tooltip copy")
		if found_real_chosik and found_real_vision_mugong and found_real_mugong:
			break
	_expect(found_real_chosik, "real F4 catalog should provide at least one chosik tooltip entry")
	_expect(found_real_vision_mugong, "real F4 catalog should provide at least one vision mugong tooltip entry")
	_expect(found_real_mugong, "real F4 catalog should provide at least one mugong tooltip entry")

	var mugong_content: Dictionary = picker._build_hover_tooltip_content({
		"id": "common_swiftness",
		"name": "경신보",
		"max_level": 5,
		"debug_group": "common",
		"detail": "몸놀림을 가볍게 하여 이동 속도를 높입니다.",
		"descriptions": {
			1: "이동 속도 6% 증가",
			2: "이동 속도 12% 증가",
			3: "이동 속도 18% 증가",
		},
	}, 1)
	_expect(str(mugong_content.get("kind", "")) == "무공", "ordinary F4 entries should identify their hover tooltip as 무공")
	_expect(str(mugong_content.get("detail", "")).contains("몸놀림"), "mugong hover tooltip should expose the catalog detail")
	_expect(str(mugong_content.get("stats", "")) == "이동 속도 18% 증가", "mugong hover tooltip should use the selected target-level description")
	_expect(str(mugong_content.get("subtitle", "")).contains("적용 3성") and str(mugong_content.get("subtitle", "")).contains("보유 1성"), "mugong hover tooltip should show target and owned ranks")

	var training_content: Dictionary = picker._build_hover_tooltip_content({
		"id": "physique_move_speed",
		"name": "유운보 수련",
		"max_level": 0,
		"is_physique_training": true,
		"debug_group": "training",
		"detail": "무공 슬롯을 차지하지 않는 상시 수련입니다.",
	}, 0)
	_expect(str(training_content.get("kind", "")) == "수련", "training debug entries should use the dedicated 수련 kind")
	_expect(str(training_content.get("subtitle", "")).contains("1회 적용") and not str(training_content.get("subtitle", "")).contains("Lv."), "training debug tooltip should avoid level semantics")

	var chosik_content: Dictionary = picker._build_hover_tooltip_content({
		"id": "smasher_unlock_dash",
		"name": "황역전",
		"max_level": 1,
		"unlocks_skill": "dash",
		"debug_group": "smasher",
		"detail": "방향키를 빠르게 두 번 눌러 돌진하는 황역전을 장착합니다.",
		"descriptions": {1: "황역전 초식 비급"},
	}, 0)
	_expect(str(chosik_content.get("kind", "")) == "초식", "unlock F4 entries should identify their hover tooltip as 초식")
	_expect(str(chosik_content.get("detail", "")).contains("황역전"), "chosik hover tooltip should expose the catalog detail")
	_expect(str(chosik_content.get("stats_heading", "")) == "습득 정보", "chosik hover tooltip should label its unlock metadata")

	var mythic_content: Dictionary = picker._build_hover_tooltip_content({
		"id": "odins_eye",
		"name": "오딘의 눈",
		"max_level": 1,
		"rarity": "mythic",
		"debug_group": "converted_mythic",
		"detail": "절세무공 설명",
		"descriptions": {1: "절세무공 효과"},
	}, 0)
	_expect(str(mythic_content.get("kind", "")) == "절세무공", "mythic F4 entries should keep the approved 절세무공 terminology")

	var font: Font = ThemeDB.fallback_font
	_expect(font != null, "tooltip bounds smoke requires the fallback font")
	if font != null:
		var view_size := Vector2(900.0, 720.0)
		var layout: Dictionary = picker._get_hover_tooltip_layout(font, mugong_content, view_size)
		var tooltip_size: Vector2 = layout.get("size", Vector2.ZERO)
		_expect(tooltip_size.x >= RuntimePerkDebugPicker.TOOLTIP_MIN_WIDTH and tooltip_size.y > 0.0, "hover tooltip layout should produce a readable non-empty size")
		var edge_card := Rect2(840.0, 670.0, 52.0, 42.0)
		var tooltip_rect: Rect2 = picker._get_hover_tooltip_rect(edge_card, tooltip_size, view_size)
		_expect(tooltip_rect.position.x >= RuntimePerkDebugPicker.TOOLTIP_VIEW_MARGIN and tooltip_rect.end.x <= view_size.x - RuntimePerkDebugPicker.TOOLTIP_VIEW_MARGIN + 0.01, "hover tooltip should clamp inside the horizontal viewport bounds")
		_expect(tooltip_rect.position.y >= RuntimePerkDebugPicker.TOOLTIP_VIEW_MARGIN and tooltip_rect.end.y <= view_size.y - RuntimePerkDebugPicker.TOOLTIP_VIEW_MARGIN + 0.01, "hover tooltip should clamp inside the vertical viewport bounds")

	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_debug_picker.gd")
	var draw_body: String = _function_body(source, "func draw(")
	_expect(draw_body.find("_draw_tabs(") >= 0 and draw_body.find("_draw_tabs(") < draw_body.find("_draw_card("), "F4 draw should render the selected tab row before cards")
	_expect(draw_body.find("_draw_hover_tooltip(") > draw_body.find("_draw_card("), "F4 draw should render the hovered tooltip after cards so it stays on top")


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
	picker.selected_tab_index = 5
	picker.toggle()
	runtime_state.grant_starts_cinematic = true
	var mythic_entries: Array = picker._get_entries_for_tab(catalog.entries, picker.selected_tab_index)
	var click := _click_first_debug_card(picker, view_size, mythic_entries)
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
	normal_picker.selected_tab_index = 4
	normal_picker.toggle()
	var mugong_entries: Array = normal_picker._get_entries_for_tab(normal_catalog.entries, normal_picker.selected_tab_index)
	var normal_click := _click_first_debug_card(normal_picker, view_size, mugong_entries)
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


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + 1)
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
