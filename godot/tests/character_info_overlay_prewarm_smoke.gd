extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayActiveItemPresenter := preload("res://scripts/hud/character_info_overlay_active_item_presenter.gd")
const CharacterInfoOverlayHoverGeometry := preload("res://scripts/hud/character_info_overlay_hover_geometry.gd")
const CharacterInfoLingpetPrewarmFilter := preload("res://scripts/hud/character_info_lingpet_prewarm_filter.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const CharacterInfoOverlayPassiveItemPresenter := preload("res://scripts/hud/character_info_overlay_passive_item_presenter.gd")
const CharacterInfoOverlayPrewarmPresenter := preload("res://scripts/hud/character_info_overlay_prewarm_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")


class FakePrewarmModule:
	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeActiveItemVisuals:
	var prewarm_count := 0

	func prewarm_catalog_icons() -> void:
		prewarm_count += 1

	func get_icon_texture(_item_data: Dictionary) -> Texture2D:
		return null


class FakeStagedRuntimeIconModule:
	var complete_after := 1
	var step_calls := 0
	var called_after_done := false
	var _done := false

	func prewarm_assets_step() -> bool:
		if _done:
			called_after_done = true
			return true
		step_calls += 1
		if step_calls >= complete_after:
			_done = true
			return true
		return false


class FakeStagedActiveItemVisuals:
	var complete_after := 4
	var step_calls := 0
	var called_after_done := false
	var _done := false

	func prewarm_catalog_icons_step() -> bool:
		if _done:
			called_after_done = true
			return true
		step_calls += 1
		if step_calls >= complete_after:
			_done = true
			return true
		return false


class FakeSkillConfig:
	func get_snapshot() -> Dictionary:
		return {
			"equipped_skills": ["dash_drive"],
			"max_slots": 5,
			"skill_data": {
				"dash_drive": {
					"korean": "대시 드라이브",
					"description": "전방으로 빠르게 파고들어 충돌 피해를 강화합니다.",
				},
			},
		}


class FakePerkCatalog:
	extends RefCounted

	var get_calls := 0
	var data_by_id: Dictionary = {}

	func get_perk_data(skill_id: String) -> Dictionary:
		get_calls += 1
		if data_by_id.has(skill_id):
			var data_value: Variant = data_by_id[skill_id]
			if data_value is Dictionary:
				return (data_value as Dictionary).duplicate(true)
			return {}
		return {
			"name": skill_id,
			"icon_color": Color.WHITE,
			"descriptions": {
				1: "%s Lv.1" % skill_id,
				2: "%s Lv.2" % skill_id,
			},
		}


class FakeEffectiveRuntimeState:
	extends RefCounted

	var get_level_calls := 0
	var effective_levels: Dictionary = {}

	func get_runtime_skill_level(skill_id: String) -> int:
		get_level_calls += 1
		return int(effective_levels.get(skill_id, 0))


class FakeDashState:
	extends RefCounted

	var snapshot_calls := 0

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		return {
			"tokens": 2,
			"max_tokens": 3,
		}


class FakeRegistry:
	var icon_renderer := FakePrewarmModule.new()
	var active_item_visuals := FakeActiveItemVisuals.new()
	var catalog := RuntimePerkCatalog.new()
	var smasher_skill_config := FakeSkillConfig.new()
	var viper_skill_config := FakeSkillConfig.new()
	var commando_skill_config := FakeSkillConfig.new()
	var smasher_dash_state: Object = null

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_icon_renderer":
				return icon_renderer
			"active_item_hud_visuals":
				return active_item_visuals
			"runtime_perk_catalog":
				return catalog
			"smasher_skill_config":
				return smasher_skill_config
			"viper_skill_config":
				return viper_skill_config
			"commando_skill_config":
				return commando_skill_config
			"smasher_dash_state":
				return smasher_dash_state
		return null


class FakeStaggeredSharedIconRegistry:
	var icon_renderer := FakeStagedRuntimeIconModule.new()
	var active_item_visuals := FakeStagedActiveItemVisuals.new()

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_icon_renderer":
				return icon_renderer
			"active_item_hud_visuals":
				return active_item_visuals
		return null


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var lingpet_state := "companion"
	var lingpet_id := "maribo"
	var current_lingpet_id := "maribo"
	var lingpet_slots := ["maribo", "lunabi", ""]
	var lingpet_active_slot_index := 0
	var equipment_slots := {
		"head": {"name": "alpha_helm", "display_name": "Alpha Helm"},
	}
	var active_item_slots := [
		{"name": "ammo_box", "display_name": "Ammo Box"},
	]
	var passive_item_inventory := [
		{"name": "alpha_charm", "display_name": "Alpha Charm"},
	]
	var runtime_perk_levels := {
		"dash_drive": 1,
	}

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


var _registry := FakeRegistry.new()


func _init() -> void:
	var overlay := CharacterInfoOverlay.new()
	var font: Font = ThemeDB.fallback_font
	_expect(font != null, "fallback font should be available for character info prewarm")

	var omitted_filter_art_cache: Dictionary = {}
	CharacterInfoOverlayLingpetTextureLoader.prewarm_art_assets(omitted_filter_art_cache)
	_expect(omitted_filter_art_cache.is_empty(), "omitted lingpet prewarm filter should not mean full-roster panel art loading")
	var omitted_filter_step_cache: Dictionary = {}
	_expect(CharacterInfoOverlayLingpetTextureLoader.prewarm_art_assets_step(omitted_filter_step_cache), "omitted staged lingpet prewarm filter should finish without queuing full-roster panel art")
	_expect(omitted_filter_step_cache.is_empty(), "omitted staged lingpet prewarm filter should not cache full-roster panel art")
	var slot_filter_ids := CharacterInfoLingpetPrewarmFilter.get_slot_prewarm_pet_ids(FakeOwner.new())
	_expect(slot_filter_ids == ["maribo", "lunabi"], "TAB character info prewarm filter should warm equipped lingpet slots without falling back to the full roster")
	var empty_owner := FakeOwner.new()
	empty_owner.lingpet_state = "none"
	empty_owner.lingpet_id = ""
	empty_owner.current_lingpet_id = ""
	empty_owner.lingpet_slots = []
	empty_owner.lingpet_active_slot_index = -1
	_expect(CharacterInfoLingpetPrewarmFilter.get_active_prewarm_pet_ids(empty_owner).is_empty(), "boot character info prewarm filter should return zero lingpets when the owner has not restored slots yet")

	overlay.prewarm_assets(null, null, Callable(), false, Vector2.ZERO, [])
	_expect(_registry.icon_renderer.prewarm_count == 0, "partial character info prewarm should not mark icon assets done")
	_expect(_registry.active_item_visuals.prewarm_count == 0, "partial character info prewarm should not mark active item visuals done")
	_expect(not overlay._runtime_perk_text_prewarmed, "partial character info prewarm should leave runtime perk text pending without a catalog")
	_expect(not overlay._skill_text_prewarmed, "partial character info prewarm should leave skill text pending without skill configs")

	overlay.prewarm_assets(null, _registry, Callable(), true, Vector2.ZERO, [])
	_expect(_registry.icon_renderer.prewarm_count == 1, "character info prewarm should warm perk icon assets")
	_expect(_registry.active_item_visuals.prewarm_count == 1, "character info prewarm should warm active item icons")
	_expect(overlay._runtime_perk_text_prewarmed, "character info prewarm should complete runtime perk text once the catalog is reachable")
	_expect(overlay._skill_text_prewarmed, "character info prewarm should complete skill text once configs are reachable")
	_expect(overlay._text_size_cache.size() > 0, "character info prewarm should populate text size cache")
	_expect(overlay._wrap_text_cache.size() > 0, "character info prewarm should populate wrapped text cache")

	var layout_overlay := CharacterInfoOverlay.new()
	layout_overlay.prewarm_assets(FakeOwner.new(), _registry, Callable(), false, Vector2.ZERO, ["maribo"])
	_expect(layout_overlay._layout_panel_rect.size != Vector2.ZERO, "character info prewarm should prepare the frame layout when a viewport is available")
	_expect(layout_overlay._layout_equipment_rect.size != Vector2.ZERO, "character info should keep the equipment slot panel visible")
	_expect(layout_overlay._layout_skill_rect.size != Vector2.ZERO, "character info should keep the skill slot panel visible")
	_expect(layout_overlay._layout_active_items_rect.size != Vector2.ZERO, "character info should keep the active item panel visible")
	_expect(layout_overlay._layout_inventory_rect.size != Vector2.ZERO, "character info should keep the passive inventory panel visible")
	_expect(layout_overlay._last_perk_grid_rect.size != Vector2.ZERO, "character info prewarm should prepare perk grid bounds")
	_expect(layout_overlay._layout_lingpet_rect.size != Vector2.ZERO, "character info prewarm should prepare the lingpet build panel")
	_expect(layout_overlay._stats_row_cache.size() >= 8, "character info prewarm should prepare the compact live stat rows")
	_expect(layout_overlay._build_lingpet_stats(FakeOwner.new()).size() > 0, "character info prewarm should expose lingpet stat rows")
	var lingpet_content_rect := Rect2(
		layout_overlay._layout_lingpet_rect.position.x + 12.0,
		layout_overlay._layout_lingpet_rect.position.y + 36.0,
		layout_overlay._layout_lingpet_rect.size.x - 24.0,
		layout_overlay._layout_lingpet_rect.size.y - 48.0
	)
	var lingpet_skill_row_h: float = clamp(lingpet_content_rect.size.y * 0.22, 58.0, 78.0)
	var lingpet_art_rect: Rect2 = CharacterInfoOverlayLingpetPresenter.companion_art_rect(lingpet_content_rect, lingpet_skill_row_h)
	_expect(lingpet_art_rect.size.y >= 120.0, "720p lingpet panel should reserve enough height for the Maribo full-body art")
	var maribo_passive_icon_path: String = LingpetCatalog.get_passive_icon_path("maribo", "gauge_gain_bonus")
	_expect(FileAccess.file_exists(maribo_passive_icon_path), "maribo gauge-gain passive icon asset should exist through the catalog")
	_expect(layout_overlay._lingpet_skill_icon_texture_cache.has(maribo_passive_icon_path), "character info prewarm should cache the catalog passive icon")
	var maribo_art_path: String = LingpetCatalog.get_visual_path("maribo", "cutin_art")
	_expect(maribo_art_path != "", "maribo cutin art should be reachable through the catalog")
	_expect(not layout_overlay._lingpet_art_texture_cache.has(maribo_art_path), "TAB-open character info prewarm should not synchronously load lingpet panel art when the staged cache missed")
	_expect(not layout_overlay._lingpet_skill_icon_texture_cache.has(maribo_art_path), "character info prewarm should keep lingpet art out of the skill icon cache")
	var lunabi_panel_art_path: String = CharacterInfoOverlayLingpetTextureLoader.get_panel_art_path("lunabi")
	_expect(lunabi_panel_art_path.ends_with("lunabi_click_live2d_pingpong_98f.png"), "Lunabi character info panel should use the 98-frame panel Live2D sheet path")
	_expect(not layout_overlay._lingpet_art_texture_cache.has(lunabi_panel_art_path), "limited character info prewarm should not cache inactive Lunabi panel Live2D sheet")
	_expect(not layout_overlay._lingpet_skill_icon_texture_cache.has(lunabi_panel_art_path), "character info prewarm should keep Lunabi panel Live2D out of the skill icon cache")
	var nekuring_panel_art_path: String = CharacterInfoOverlayLingpetTextureLoader.get_panel_art_path("nekuring")
	_expect(nekuring_panel_art_path.ends_with("nekuring_click_live2d_pingpong_98f.png"), "Nekuring character info panel should use the 98-frame panel Live2D sheet path")
	var loader_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
	_expect(loader_source.find("FileAccess.file_exists") < 0, "lingpet texture loader should delegate export-safe existence checks to ProjectResourceLoader")

	var limited_overlay := CharacterInfoOverlay.new()
	var limited_registry := FakeRegistry.new()
	var limited_steps := 0
	while not limited_overlay.prewarm_assets_step(FakeOwner.new(), limited_registry, Callable(), false, Vector2.ZERO, ["maribo"]):
		limited_steps += 1
		if limited_steps >= 512:
			_expect(false, "limited lingpet character info prewarm should complete in bounded steps")
			break
	_expect(limited_overlay._lingpet_art_texture_cache.has(maribo_art_path), "limited lingpet prewarm should cache the requested active pet art")
	_expect(not limited_overlay._lingpet_art_texture_cache.has(lunabi_panel_art_path), "limited lingpet prewarm should not cache inactive roster panel Live2D sheets")
	_expect(limited_overlay._lingpet_skill_icon_texture_cache.has(maribo_passive_icon_path), "limited lingpet prewarm should cache the requested active pet skill icons")

	var staged_registry := FakeRegistry.new()
	var staged_overlay := CharacterInfoOverlay.new()
	var staged_steps := 0
	while not staged_overlay.prewarm_assets_step(FakeOwner.new(), staged_registry, Callable(), true, Vector2.ZERO, ["maribo"]):
		staged_steps += 1
		if staged_steps >= 512:
			_expect(false, "character info staged prewarm should complete in bounded steps")
			break
	_expect(staged_steps > 4, "character info staged prewarm should spread work across multiple calls")
	_expect(staged_overlay._shared_icon_assets_prewarmed, "character info staged prewarm should complete shared icon assets before TAB opens")
	_expect(staged_registry.icon_renderer.prewarm_count == 1, "character info staged prewarm should warm runtime perk icons")
	_expect(staged_registry.active_item_visuals.prewarm_count == 1, "character info staged prewarm should warm active item icons")
	_expect(staged_overlay._lingpet_art_texture_cache.has(maribo_art_path), "character info staged prewarm should cache the requested lingpet art")
	_expect(staged_overlay._lingpet_skill_icon_texture_cache.has(maribo_passive_icon_path), "character info staged prewarm should cache lingpet passive icons")
	var slot_overlay := CharacterInfoOverlay.new()
	var slot_steps := 0
	while not slot_overlay.prewarm_lingpet_panel_assets_step(["maribo", "lunabi"]):
		slot_steps += 1
		if slot_steps >= 512:
			_expect(false, "stage-transition slot lingpet panel prewarm should complete in bounded steps")
			break
	_expect(CharacterInfoOverlayLingpetTextureLoader.get_cached_art_texture("maribo", slot_overlay._lingpet_art_texture_cache) != null, "stage-transition slot prewarm should leave active-slot art as a cached TAB hit")
	_expect(CharacterInfoOverlayLingpetTextureLoader.get_cached_art_texture("lunabi", slot_overlay._lingpet_art_texture_cache) != null, "stage-transition slot prewarm should leave inactive-slot panel Live2D as a cached TAB hit")
	var staggered_registry := FakeStaggeredSharedIconRegistry.new()
	var staggered_overlay := CharacterInfoOverlay.new()
	var shared_icon_steps := 0
	while not CharacterInfoOverlayPrewarmPresenter.prewarm_shared_icon_assets_step(staggered_overlay, staggered_registry, Callable()):
		shared_icon_steps += 1
		if shared_icon_steps >= 16:
			_expect(false, "staggered shared icon prewarm should complete without restarting finished sub-steps")
			break
	_expect(staggered_registry.icon_renderer.step_calls == 1, "staged shared icon prewarm should not rerun completed runtime perk icons while active-item icons continue")
	_expect(not staggered_registry.icon_renderer.called_after_done, "staged shared icon prewarm should skip the finished runtime icon renderer")
	_expect(staggered_registry.active_item_visuals.step_calls == 4, "staged shared icon prewarm should keep advancing active-item icons until complete")
	_expect(not staggered_registry.active_item_visuals.called_after_done, "staged shared icon prewarm should stop after active-item icons complete")

	var text_cache_size: int = overlay._text_size_cache.size()
	var wrap_cache_size: int = overlay._wrap_text_cache.size()
	var wrapped_once: Array = overlay._wrap_text_to_width(font, "alpha beta gamma delta", 13, 70.0, 3)
	var wrapped_twice: Array = overlay._wrap_text_to_width(font, "alpha beta gamma delta", 13, 70.0, 3)
	_expect(wrapped_once == wrapped_twice, "cached character info wrapping should preserve wrapped output")
	var japanese_wrapped: Array = overlay._wrap_text_to_width(font, "ダッシュ前の位置へ転移します。素早い後ろ蹴りでコンボルートを開けます。", 13, 120.0, 8)
	_expect(japanese_wrapped.size() > 1, "character info tooltip wrapping should split no-space Japanese text")
	_assert_wrapped_lines_fit(overlay, font, japanese_wrapped, 13, 120.0, "Japanese character info tooltip lines should fit the box")
	var long_word_wrapped: Array = overlay._wrap_text_to_width(font, "SupercalifragilisticexpialidociousSupercalifragilistic", 13, 90.0, 8)
	_expect(long_word_wrapped.size() > 1, "character info tooltip wrapping should split long unbroken words")
	_assert_wrapped_lines_fit(overlay, font, long_word_wrapped, 13, 90.0, "long unbroken character info tooltip words should fit the box")
	var narrow_tooltip_width: float = CharacterInfoOverlayValueUtils.tooltip_width(font, "シャドウバックステップ", "", str(japanese_wrapped[0]), Vector2(360.0, 240.0), Callable(overlay, "_text_size"))
	_expect(narrow_tooltip_width >= 280.0 and narrow_tooltip_width <= 344.0, "character info tooltip width should stay inside the owning view")
	var tooltip_entries: Array = [{"text": "alpha beta gamma delta", "color": Color.WHITE}]
	var entry_lines_once: Array = overlay._build_tooltip_entry_lines(font, tooltip_entries, 13, 70.0, 3)
	var entry_lines_twice: Array = overlay._build_tooltip_entry_lines(font, tooltip_entries, 13, 70.0, 3)
	_expect(entry_lines_once == entry_lines_twice, "cached character info tooltip entry lines should preserve output")
	var roll_entries_once: Array = overlay._build_passive_item_roll_entries({
		"name": "alpha",
		"fixed_options": [{"label": "Flat", "value": 1, "unit": "%"}],
		"roll_options": [{"key": "speed", "label": "Speed", "value": 2.0}],
	})
	var roll_entries_twice: Array = overlay._build_passive_item_roll_entries({
		"name": "alpha",
		"fixed_options": [{"label": "Flat", "value": 1, "unit": "%"}],
		"roll_options": [{"key": "speed", "label": "Speed", "value": 2.0}],
	})
	_expect(roll_entries_once == roll_entries_twice, "cached passive item roll entries should preserve repeated output")
	_expect(str(roll_entries_twice[0].get("text", "")) == "Flat: 1%", "fixed passive item roll entries should not show placeholder question marks")
	_expect(str(roll_entries_twice[1].get("text", "")) == "Speed: 2", "random passive item roll entries should not show placeholder question marks")
	var passive_body_item := {"name": "alpha", "description": "body", "_equipped_slot": "head"}
	var passive_body_once: String = overlay._build_passive_item_body(passive_body_item)
	var passive_body_twice: String = overlay._build_passive_item_body(passive_body_item)
	_expect(passive_body_once == passive_body_twice, "cached passive item tooltip body should preserve repeated output")
	passive_body_item["_equipped_slot"] = "shoes"
	_expect(overlay._build_passive_item_body(passive_body_item) != passive_body_once, "passive item tooltip body cache should rebuild when equipped slot changes")
	_expect(CharacterInfoOverlayValueUtils.get_string_fallback({"desc": "fallback body"}, "description", "desc") == "fallback body", "lazy string fallback should read the secondary key only when needed")
	_expect(is_equal_approx(CharacterInfoOverlayValueUtils.get_number_fallback({"cooldown_ms": 2500}, "cooldown_msec", "cooldown_ms"), 2500.0), "lazy number fallback should read the secondary key only when needed")
	_expect(is_equal_approx(CharacterInfoOverlayPassiveItemPresenter.roll_option_value({"default": 2.0}, {"speed": 3.0}, "speed"), 3.0), "roll option values should prefer live rolled values before option defaults")
	var passive_frame_color_cache := {}
	var passive_frame_color_once: Color = CharacterInfoOverlayPassiveItemPresenter.cached_frame_color({"name": "alpha", "rarity": "legendary"}, passive_frame_color_cache, CharacterInfoOverlay.PASSIVE_FRAME_COLOR_CACHE_LIMIT)
	var passive_frame_color_twice: Color = CharacterInfoOverlayPassiveItemPresenter.cached_frame_color({"name": "alpha", "rarity": "legendary"}, passive_frame_color_cache, CharacterInfoOverlay.PASSIVE_FRAME_COLOR_CACHE_LIMIT)
	_expect(passive_frame_color_once == passive_frame_color_twice, "cached passive inventory frame colors should preserve repeated output")
	var display_item := {"name": "speedboots", "display_name": "Speed Boots", "name_prefix": "Fast", "quality_tier": "high"}
	var display_once: String = overlay._equipment_item_display_name(display_item)
	var display_twice: String = overlay._equipment_item_display_name(display_item)
	_expect(display_once == display_twice, "cached equipment display names should preserve repeated output")
	var quality_once: Color = overlay._get_item_quality_color(display_item, Color.WHITE)
	var quality_twice: Color = overlay._get_item_quality_color(display_item, Color.WHITE)
	_expect(quality_once == quality_twice, "cached item quality colors should preserve repeated output")
	_expect(CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(14.0, 12.0), 10.0, 10.0, 12.0, 18.0, 3) == 0, "linear hover index should resolve the first slot")
	_expect(CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(25.0, 12.0), 10.0, 10.0, 12.0, 18.0, 3) == -1, "linear hover index should reject slot gaps")
	_expect(CharacterInfoOverlayHoverGeometry.get_hovered_grid_index(Vector2(35.0, 35.0), 10.0, 10.0, 12.0, 18.0, 3, 9) == 4, "grid hover index should resolve row and column")
	_expect(CharacterInfoOverlayHoverGeometry.get_hovered_grid_index(Vector2(71.0, 38.0), 10.0, 10.0, 12.0, 18.0, 3, 5) == -1, "grid hover index should reject out-of-range items")
	_expect(overlay._text_size_cache.size() >= text_cache_size, "character info text cache should remain populated")
	_expect(overlay._wrap_text_cache.size() >= wrap_cache_size, "character info wrap cache should remain populated")

	overlay.prewarm_assets(null, _registry, Callable(), true, Vector2.ZERO, [])
	_expect(_registry.icon_renderer.prewarm_count == 1, "character info prewarm should be idempotent for icons")
	_expect(_registry.active_item_visuals.prewarm_count == 1, "character info prewarm should be idempotent for active item visuals")

	_verify_active_item_tooltip_body()
	_verify_acquired_perk_cache_reuses_catalog_rows()
	_verify_passive_inventory_summary_cache_tracks_equipped_state()
	_verify_active_item_label_cache_reuses_catalog_rows()
	_verify_compact_stats_reuse_frame_sources()
	_verify_stats_do_not_read_dash_token_snapshot()

	print("character_info_overlay_prewarm_smoke: ok")
	quit(0)


func _verify_active_item_tooltip_body() -> void:
	var described_body: String = CharacterInfoOverlayActiveItemPresenter.build_body(
		{"description": "스킬 쿨타임과 대쉬 토큰을 즉시 회복합니다."},
		7000
	)
	_expect(described_body.find("스킬 쿨타임과 대쉬 토큰") >= 0, "active item tooltip body should include catalog description text")
	_expect(described_body.find("쿨타임 7.0초") >= 0, "active item tooltip body should keep the effective cooldown line")
	var fallback_body: String = CharacterInfoOverlayActiveItemPresenter.build_body({}, 7000)
	_expect(fallback_body == "쿨타임 7.0초", "active item tooltip body should keep a cooldown-only fallback")


func _verify_acquired_perk_cache_reuses_catalog_rows() -> void:
	var overlay := CharacterInfoOverlay.new()
	var catalog := FakePerkCatalog.new()
	var levels := {
		"alpha": 1,
		"beta": 2,
	}
	var first: Array = overlay._build_acquired_perks_cached(levels, catalog)
	var second: Array = overlay._build_acquired_perks_cached(levels, catalog)
	_expect(first.size() == 2, "acquired perk cache should build acquired perk entries")
	_expect(second.size() == 2, "acquired perk cache should return acquired perk entries on repeat")
	_expect(catalog.get_calls == 2, "unchanged acquired perk cache should not call the catalog again")

	levels["gamma"] = 1
	var third: Array = overlay._build_acquired_perks_cached(levels, catalog)
	_expect(third.size() == 3, "acquired perk cache should rebuild when levels change")
	_expect(catalog.get_calls == 5, "changed acquired perk cache should rebuild catalog rows")

	var snapshot_overlay := CharacterInfoOverlay.new()
	var snapshot_catalog := FakePerkCatalog.new()
	var runtime_state := FakeEffectiveRuntimeState.new()
	var snapshot_levels := {"alpha": 1}
	runtime_state.effective_levels = {"alpha": 4}
	var snapshot_first: Array = snapshot_overlay._build_acquired_perks_cached(snapshot_levels, snapshot_catalog, runtime_state, {"effective_runtime_skill_levels": {"alpha": 4}})
	_expect(int(snapshot_first[0].get("level", 0)) == 4, "acquired perk cache should use snapshot effective levels")
	_expect(runtime_state.get_level_calls == 0, "snapshot-backed acquired perk cache should not call runtime level methods")
	runtime_state.effective_levels = {"alpha": 7}
	var snapshot_second: Array = snapshot_overlay._build_acquired_perks_cached(snapshot_levels, snapshot_catalog, runtime_state, {"effective_runtime_skill_levels": {"alpha": 7}})
	_expect(int(snapshot_second[0].get("level", 0)) == 7, "acquired perk cache should rebuild when snapshot effective levels change")
	_expect(runtime_state.get_level_calls == 0, "snapshot-backed acquired perk rebuild should still avoid runtime level methods")
	_expect(snapshot_catalog.get_calls == 2, "snapshot effective-level change should rebuild only affected catalog rows")

	var unlock_overlay := CharacterInfoOverlay.new()
	var unlock_catalog := FakePerkCatalog.new()
	unlock_catalog.data_by_id = {
		"soldier_unlock_ak47": {
			"name": "AK-47",
			"icon_color": Color.WHITE,
			"descriptions": {1: "AK-47 해금"},
			"unlocks_skill": "ak47",
		},
		"item_luck": {
			"name": "아이템 행운",
			"icon_color": Color.WHITE,
			"descriptions": {1: "아이템 행운 Lv.1"},
		},
	}
	var unlock_levels := {
		"soldier_unlock_ak47": 1,
		"item_luck": 1,
	}
	var filtered_unlocks: Array = unlock_overlay._build_acquired_perks_cached(unlock_levels, unlock_catalog, null, {}, ["ak47"])
	_expect(filtered_unlocks.size() == 1, "equipped unlock-skill perks should be hidden from the acquired perk grid")
	_expect(str(filtered_unlocks[0].get("id", "")) == "item_luck", "non-unlock acquired perks should remain visible when skill unlocks are hidden")
	var visible_unlocks: Array = unlock_overlay._build_acquired_perks_cached(unlock_levels, unlock_catalog, null, {}, [])
	_expect(visible_unlocks.size() == 2, "unequipped unlock-skill perks should remain visible in the acquired perk grid")

	var source := _character_info_overlay_source()
	var perk_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_perk_presenter.gd")
	var text_width_cache_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_text_width_cache.gd")
	var acquired_cache_hash_body := _function_body(perk_presenter_source, "static func acquired_perk_cache_hash(")
	var acquired_runtime_hash_body := _function_body(perk_presenter_source, "static func acquired_perk_runtime_cache_hash(")
	var build_acquired_body := _function_body(perk_presenter_source, "static func build_acquired_perks(")
	var overlay_acquired_body := _function_body(perk_presenter_source, "static func build_overlay_acquired_perks_cached(")
	var perk_grid_draw_body := _function_body(perk_presenter_source, "static func draw_grid_cells(")
	var overlay_indexed_size_body := _function_body(text_width_cache_source, "static func get_overlay_indexed_size(")
	var overlay_text_size_body := _function_body(text_width_cache_source, "static func get_overlay_text_size(")
	_expect(source.find("parts.sort()") < 0, "acquired perk cache signature should not sort every frame")
	_expect(source.find("var _acquired_perk_cache_hash := 0") >= 0, "acquired perk cache should keep a numeric hash guard")
	_expect(source.find("var _acquired_perk_cache_ready := false") >= 0, "acquired perk cache should guard the initial hash state")
	_expect(source.find("var _acquired_perk_signature_parts: Array[String] = []") < 0, "acquired perk cache should not keep string signature parts")
	_expect(source.find("var _perk_level_text_size_cache_values: Array[Vector2] = []") >= 0, "perk grid level text should keep a typed size cache")
	_expect(overlay_acquired_body.find("var effective_levels: Dictionary = effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)") >= 0, "acquired perk cache should compute snapshot effective levels once")
	_expect(acquired_cache_hash_body.find("has_snapshot_effective_levels") >= 0, "acquired perk cache hash should only use the fast snapshot hash when effective levels are present")
	_expect(acquired_cache_hash_body.find("hash([catalog_id, hash(levels), hash(effective_levels), equipped_skills_hash") >= 0, "snapshot-backed acquired perk cache should use compact dictionary hashes")
	_expect(acquired_cache_hash_body.find("for skill_id_value in levels") < 0, "snapshot-backed acquired perk cache hash should not iterate every perk level")
	_expect(acquired_runtime_hash_body.find("var result: int = hash(catalog_id)") >= 0, "direct acquired perk runtime cache should accumulate a numeric hash")
	_expect(acquired_runtime_hash_body.find("for skill_id_value in levels.keys():") < 0, "direct acquired perk runtime cache should not allocate dictionary key arrays")
	_expect(acquired_runtime_hash_body.find("for skill_id_value in levels:") >= 0, "direct acquired perk runtime cache should iterate levels directly")
	_expect(acquired_runtime_hash_body.find("result = hash([result, skill_id, base_level, effective_level])") >= 0, "direct acquired perk runtime cache should avoid joined string signatures")
	_expect(build_acquired_body.find("for skill_id_value in levels.keys():") < 0, "acquired perk cache rebuild should not allocate dictionary key arrays")
	_expect(build_acquired_body.find("data[\"_level_text\"] = CharacterInfoOverlayFormatter.perk_level_text(data)") >= 0, "acquired perk cache should precompute perk level text")
	_expect(build_acquired_body.find("data[\"_level_color\"] = CharacterInfoOverlayFormatter.perk_level_color(data, accent_gold)") >= 0, "acquired perk cache should precompute perk level color")
	_expect(build_acquired_body.find("var draw_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get(\"icon_color\", accent_blue))") >= 0, "acquired perk cache should compute perk draw color once through value utils")
	_expect(build_acquired_body.find("data[\"_draw_color\"] = draw_color") >= 0, "acquired perk cache should precompute perk draw color")
	_expect(build_acquired_body.find("data[\"_draw_id\"] = skill_id") >= 0, "acquired perk cache should precompute perk draw id")
	_expect(source.find("func _should_hide_equipped_unlock_perk(") < 0, "acquired perk grid should not keep the unused equipped-unlock wrapper")
	_expect(build_acquired_body.find("acquired_perk_data(skill_id, base_level, level, catalog, equipped_skill_lookup, accent_blue)") >= 0, "acquired perk grid should delegate equipped unlock filtering to the presenter")
	_expect(source.find("var _acquired_perk_draw_id_cache: Array[String] = []") >= 0, "acquired perk draw should keep typed id caches")
	_expect(source.find("var _acquired_perk_draw_color_cache: Array[Color] = []") >= 0, "acquired perk draw should keep typed color caches")
	_expect(source.find("var _acquired_perk_hover_title_cache: Array[String] = []") >= 0, "acquired perk draw should keep typed hover title caches")
	_expect(perk_presenter_source.find("hover_title_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, \"name\", \"id\")") >= 0, "acquired perk rebuild should cache hover titles through value utils")
	_expect(perk_presenter_source.find("hover_body_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, \"description\", \"detail\")") >= 0, "acquired perk rebuild should cache hover bodies through value utils")
	_expect(perk_presenter_source.find("static func build_overlay_acquired_perks_cached(") >= 0, "acquired perk rebuild should refresh typed draw arrays")
	_expect(overlay_acquired_body.find("refresh_draw_arrays(acquired,") >= 0, "acquired perk cache rebuild should refresh typed draw arrays after sorting")
	_expect(perk_grid_draw_body.find("var level_text: String = level_text_cache[i]") >= 0, "perk grid draw should reuse cached level text")
	_expect(source.find("func _get_perk_level_text_size(font: Font, text: String, size: int) -> Vector2:") >= 0, "perk grid draw should use a dedicated level text size cache")
	_expect(source.find("var _centered_text_size_cache_values: Array[Vector2] = []") >= 0, "centered text draw should keep a typed size cache")
	_expect(source.find("func _get_centered_text_size(font: Font, text: String, size: int) -> Vector2:") >= 0, "centered text draw should use a dedicated size cache")
	_expect(source.find("var _perk_level_text_size_fast_value := Vector2.ZERO") >= 0, "perk grid level text should keep a one-slot size fast cache")
	_expect(source.find("var _centered_text_size_fast_value := Vector2.ZERO") >= 0, "centered text should keep a one-slot size fast cache")
	_expect(overlay_indexed_size_body.find("return fast_value") >= 0, "perk grid level text should check the fast size cache before scanning arrays")
	_expect(overlay_indexed_size_body.find("return fast_value") >= 0, "centered text should check the fast size cache before scanning arrays")
	_expect(source.find("var _text_size_fast_value := Vector2.ZERO") >= 0, "generic text size cache should keep a one-slot fast value")
	_expect(overlay_text_size_body.find("if text == fast_text and ui_size == fast_ui_size:") >= 0, "generic text size cache should check the one-slot fast path before building string keys")
	_expect(overlay_text_size_body.find("target.set(\"_text_size_fast_value\", measured_size)") >= 0, "generic text size cache should update the fast value after measuring")
	_expect(source.find("func _draw_text_centered(") < 0, "character info should remove the unused Vector2 centered text wrapper")
	_expect(_function_body(source, "func _draw_text_centered_xy(").find("var text_size: Vector2 = _get_centered_text_size(font, visible_text, size)") >= 0, "centered text draw should read cached centered text sizes")
	_expect(_function_body(source, "func _draw_text_centered_xy(").find("var text_size: Vector2 = _text_size(font, text, size)") < 0, "centered text draw should avoid the generic string-key size cache")
	_expect(source.find("func _draw_text_centered_with_size(") < 0, "character info should remove the unused Vector2 measured centered text wrapper")
	_expect(source.find("func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color) -> void:") >= 0, "character info left-aligned text should support scalar baseline coordinates")
	_expect(source.find("func _draw_text(") < 0, "character info should remove the unused Vector2 baseline text wrapper")
	_expect(source.find("_draw_text(canvas, font,") < 0, "character info draw paths should call the scalar baseline helper directly")
	_expect(source.find("func _draw_text_centered_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color) -> void:") >= 0, "character info centered text should support scalar center coordinates")
	_expect(source.find("func _draw_text_centered_with_size_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, text_size: Vector2) -> void:") >= 0, "character info measured centered text should support scalar center coordinates")
	_expect(perk_grid_draw_body.find("var level_text_size: Vector2 = get_level_text_size_callable.call(font, level_text, 9)") >= 0, "perk grid draw should read cached level text sizes")
	_expect(perk_grid_draw_body.find("_draw_text_centered(canvas, font, level_text") < 0, "perk grid draw should not call the generic centered text measurement path for perk levels")
	_expect(perk_grid_draw_body.find("draw_text_centered_with_size_xy_callable.call(canvas, font, level_text") >= 0, "perk grid draw should pass scalar center coordinates for level text")
	_expect(perk_grid_draw_body.find("var perk_id: String = draw_id_cache[i]") >= 0, "perk grid draw should reuse cached perk id")
	_expect(source.find("var _perk_grid_center_x_cache: Array[float] = []") >= 0, "perk grid draw should cache cell centers for level text")
	_expect(perk_grid_draw_body.find("draw_text_centered_with_size_xy_callable.call(canvas, font, level_text, center_x_cache[i], level_y_cache[i], 9, level_color, level_text_size)") >= 0, "perk grid draw should reuse cached level text coordinates")
	_expect(perk_grid_draw_body.find("perk.get(\"_draw_color\"") < 0, "perk grid draw should not read cached colors back through perk dictionaries")
	_expect(perk_grid_draw_body.find("perk.get(\"_level_color\"") < 0, "perk grid draw should not read cached level colors back through perk dictionaries")
	_expect(perk_grid_draw_body.find("var perk: Dictionary = acquired[i]") < 0, "perk grid draw should not open acquired perk dictionaries per visible cell")
	_expect(perk_grid_draw_body.find("_get_string_fallback(perk") < 0, "perk grid hover should read cached title and body text")
	_expect(perk_grid_draw_body.find("hover_title_cache[i]") >= 0, "perk grid hover should read cached title text")
	_expect(source.find("_last_perk_item_rects") < 0, "perk grid hover should not keep an empty rect-map fallback")
	_expect(_function_body(source, "func _get_hover_signature(").find("_get_rect_map_hover_signature(_last_perk_item_rects") < 0, "perk grid hover signature should not scan an empty rect map")
	_expect(_function_body(source, "func _hover_signature_contains_mouse(").find("_rect_map_key_contains_mouse(_last_perk_item_rects") < 0, "perk grid hover reuse should rely on cached grid geometry")


func _verify_passive_inventory_summary_cache_tracks_equipped_state() -> void:
	var draw_cache_overlay := CharacterInfoOverlay.new()
	var draw_cache_items: Array = [
		{"name": "alpha", "rarity": "passive"},
		{"name": "beta", "rarity": "legendary", "equipped": true},
	]
	var draw_cache_first: Dictionary = draw_cache_overlay._prepare_passive_inventory_draw_cache(draw_cache_items)
	var draw_cache_first_hash: int = draw_cache_overlay._passive_inventory_draw_cache_items_hash
	var draw_cache_second: Dictionary = draw_cache_overlay._prepare_passive_inventory_draw_cache(draw_cache_items)
	_expect(draw_cache_first == draw_cache_second, "passive inventory draw cache should preserve the prepared summary on repeat")
	_expect(draw_cache_overlay._passive_inventory_draw_cache_items_hash == draw_cache_first_hash, "passive inventory draw cache should store the post-prepare item hash for immediate reuse")
	var icon_hash_items: Array = [
		{"name": "alpha", "icon_path": "res://alpha.png"},
		{"name": "beta", "icon_sheet_path": "res://beta_sheet.png"},
	]
	var icon_hash_first: int = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_icon_hash(icon_hash_items)
	var icon_hash_item: Dictionary = icon_hash_items[0]
	icon_hash_item["_draw_color"] = Color.RED
	var icon_hash_second: int = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_icon_hash(icon_hash_items)
	_expect(icon_hash_first == icon_hash_second, "passive inventory icon prewarm hash should ignore draw-cache fields")
	icon_hash_item["icon_path"] = "res://alpha_v2.png"
	var icon_hash_third: int = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_icon_hash(icon_hash_items)
	_expect(icon_hash_third != icon_hash_first, "passive inventory icon prewarm hash should change when icon identity changes")
	var source := _character_info_overlay_source()
	var passive_item_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_passive_item_presenter.gd")
	var passive_inventory_drawer_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_passive_inventory_drawer.gd")
	var passive_overlay_prepare_body := _function_body(passive_item_presenter_source, "static func prepare_overlay_inventory_draw_cache(")
	var passive_summary_body := _function_body(passive_item_presenter_source, "static func set_inventory_summary(")
	var passive_draw_arrays_body := _function_body(passive_item_presenter_source, "static func prepare_inventory_draw_arrays(")
	var passive_inventory_draw_body := _function_body(passive_inventory_drawer_source, "static func draw_inventory_cells(")
	_expect(source.find("_passive_inventory_summary_count") >= 0, "passive inventory summary should cache by visible count")
	_expect(source.find("_passive_inventory_summary_equipped") >= 0, "passive inventory summary should cache by equipped count")
	_expect(source.find("\"count_text\": \"보유 0 / 장착 0\"") >= 0, "passive inventory summary should keep reusable header count text")
	_expect(source.find("func _get_passive_inventory_count_text_width(font: Font, count_text: String, size: int) -> float:") >= 0, "passive inventory header count text width should use a cache helper")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("var count_text: String = str(summary.get(\"count_text\", \"\"))") >= 0, "passive inventory draw should read cached count text")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("_text_size(font, count_text, 11)") < 0, "passive inventory draw should not measure count text directly every frame")
	_expect(source.find("_get_passive_inventory_summary_state(inventory_items)") < 0, "passive inventory summary should avoid per-frame string signatures")
	_expect(passive_summary_body.find("% [item_count, equipped_count]") < 0, "passive inventory summary count text should avoid format arrays")
	_expect(source.find("var _passive_inventory_item_cache: Array[Dictionary] = []") >= 0, "passive inventory draw should keep typed item dictionary caches")
	_expect(source.find("var _passive_inventory_draw_cache_items_hash := 0") >= 0, "passive inventory draw cache should keep the item hash as a scalar")
	_expect(source.find("func _passive_inventory_draw_cache_matches(") < 0, "passive inventory draw cache should not keep a separate one-line match wrapper")
	_expect(passive_overlay_prepare_body.find("var items_hash: int = hash(inventory_items)") >= 0, "passive inventory prep should hash the item array once")
	_expect(passive_overlay_prepare_body.find("items_hash == current_items_hash and item_count == current_item_count") >= 0, "passive inventory prep should reuse cached draw metadata when items are unchanged")
	_expect(passive_overlay_prepare_body.find("target.set(\"_passive_inventory_draw_cache_items_hash\", hash(inventory_items))") >= 0, "passive inventory prep should store the post-prepare item hash")
	_expect(source.find("func _passive_inventory_draw_cache_signature_for_items(") < 0, "passive inventory draw cache should not keep a string-signature helper")
	_expect(source.find("var _passive_inventory_icon_prewarm_items_hash := 0") >= 0, "passive inventory icon prewarm should keep an item hash scalar")
	_expect(source.find("var _passive_inventory_icon_prewarm_item_count := -1") >= 0, "passive inventory icon prewarm should keep an item-count scalar")
	_expect(source.find("func _get_passive_inventory_icon_hash(") < 0, "passive inventory icon prewarm should not keep the overlay hash wrapper")
	_expect(source.find("func _get_passive_inventory_icon_signature(") < 0, "passive inventory icon prewarm should not build joined string signatures")
	_expect(_function_body(passive_item_presenter_source, "static func prewarm_overlay_inventory_assets(").find("var items_hash: int = passive_inventory_icon_hash(inventory_items)") >= 0, "passive inventory icon prewarm should hash icon identity once")
	_expect(passive_overlay_prepare_body.find("return summary") >= 0, "passive inventory prep should return the cached summary on a signature hit")
	_expect(source.find("var _passive_inventory_draw_color_cache: Array[Color] = []") >= 0, "passive inventory draw should keep typed item color caches")
	_expect(passive_overlay_prepare_body.find("CharacterInfoOverlayValueUtils.resize_arrays([item_cache, draw_color_cache, border_color_cache, active_border_color_cache, equipped_cache], item_count)") >= 0, "passive inventory draw cache should resize typed arrays together")
	_expect(passive_draw_arrays_body.find("_passive_inventory_item_cache[i] = item_data") >= 0, "passive inventory prep should cache item dictionaries by item index")
	_expect(passive_draw_arrays_body.find("_passive_inventory_draw_color_cache[i] = color") >= 0, "passive inventory prep should cache draw colors by item index")
	_expect(passive_draw_arrays_body.find("_passive_inventory_equipped_cache[i] = equipped") >= 0, "passive inventory prep should cache equipped flags by item index")
	_expect(passive_inventory_draw_body.find("var item_data: Dictionary = item_cache[i]") >= 0, "passive inventory draw should read cached item dictionaries")
	_expect(passive_inventory_draw_body.find("var color: Color = draw_color_cache[i]") >= 0, "passive inventory draw should read typed draw colors")
	_expect(passive_inventory_draw_body.find("var equipped: bool = equipped_cache[i]") >= 0, "passive inventory draw should read typed equipped flags")
	_expect(passive_inventory_draw_body.find("_get_dict(inventory_items[i])") < 0, "passive inventory draw should not normalize visible item dictionaries per cell")
	_expect(passive_inventory_draw_body.find("item_data.get(\"_draw_color\"") < 0, "passive inventory draw should not read cached colors back through item dictionaries")
	_expect(passive_inventory_draw_body.find("item_data.get(\"_draw_active_border_color\"") < 0, "passive inventory draw should not resolve border colors through item dictionaries")
	_expect(source.find("_last_passive_inventory_item_rects") < 0, "passive inventory hover should not keep an empty rect-map fallback")
	_expect(_function_body(source, "func _get_hover_signature(").find("_get_rect_map_hover_signature(_last_passive_inventory_item_rects") < 0, "passive inventory hover signature should not scan an empty rect map")
	_expect(_function_body(source, "func _hover_signature_contains_mouse(").find("_rect_map_key_contains_mouse(_last_passive_inventory_item_rects") < 0, "passive inventory hover reuse should rely on cached grid geometry")
	_expect(_function_body(source, "func _try_handle_passive_inventory_context_click(").find("_find_hovered_rect_key(_last_passive_inventory_item_rects") < 0, "passive inventory context click should rely on cached grid index math")


func _verify_active_item_label_cache_reuses_catalog_rows() -> void:
	var source := _character_info_overlay_source()
	var value_utils_source := _character_info_value_utils_contract_source()
	var label_cache_body := _function_body(value_utils_source, "static func refresh_active_item_label_cache(")
	_expect(source.find("_refresh_active_item_label_cache(slots)") >= 0, "active item draw should refresh cached label rows once")
	_expect(source.find("func _refresh_active_item_label_cache(slots: Array) -> void:") >= 0, "active item label cache helper should remain wired")
	_expect(value_utils_source.find("static func refresh_active_item_label_cache(") >= 0, "active item label cache should resize arrays without clearing stable rows")
	_expect(source.find("func _active_item_label_cache_matches(slots: Array) -> bool:") < 0, "active item label cache should not keep the unused pre-scan wrapper")
	_expect(source.find("_get_active_item_label_signature") < 0, "active item label cache should avoid per-frame joined signatures")
	_expect(source.find("_active_item_label_cache_names: Array[String]") >= 0, "active item label cache should track item names in an indexed array")
	_expect(source.find("_active_item_label_cache_raw_display_names: Array[String]") >= 0, "active item label cache should track raw display names in an indexed array")
	_expect(source.find("_active_item_display_name_cache: Array[String]") >= 0, "active item label cache should store display labels in an indexed array")
	_expect(source.find("_active_item_trimmed_label_cache: Array[String]") >= 0, "active item label cache should store trimmed labels in an indexed array")
	_expect(source.find("Callable(CharacterInfoOverlayFormatter, \"trim_label\")") >= 0, "active item label cache should pass the shared formatter")
	_expect(label_cache_body.find("trimmed_label_cache[i] = str(trim_label_callable.call(display_name, 10))") >= 0, "active item label cache should precompute trimmed labels through the shared formatter")
	_expect(source.find("func _trim_label(") < 0, "active item label cache should not keep the overlay trim wrapper")
	_expect(label_cache_body.find("_active_item_label_cache_matches(slots)") < 0, "active item refresh should not pre-scan slots before updating changed rows")
	_expect(label_cache_body.find("continue") >= 0, "active item refresh should skip unchanged cached rows")


func _verify_compact_stats_reuse_frame_sources() -> void:
	var source := _character_info_overlay_source()
	var hover_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_hover_geometry.gd")
	var frame_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	var layout_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_layout.gd")
	var lingpet_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var stats_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_stats_presenter.gd")
	var header_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_header_presenter.gd")
	var prewarm_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_prewarm_presenter.gd")
	var loader_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
	var texture_drawer_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_texture_drawer.gd")
	var equipment_drawer_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_equipment_drawer.gd")
	var active_item_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_active_item_presenter.gd")
	var skill_slot_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_skill_slot_presenter.gd")
	var tooltip_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
	var passive_item_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_passive_item_presenter.gd")
	var passive_inventory_drawer_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_passive_inventory_drawer.gd")
	var owner_state_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_owner_state.gd")
	var prewarm_filter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_lingpet_prewarm_filter.gd")
	var battle_overlay_input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	var plaza_overlay_host_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_character_info_overlay_host.gd")
	var value_utils_source := _character_info_value_utils_contract_source()
	var perk_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_perk_presenter.gd")
	var skill_layout_body := _function_body(value_utils_source, "static func refresh_skill_slot_layout_arrays(")
	var active_layout_body := _function_body(value_utils_source, "static func refresh_active_slot_layout_arrays(")
	var tooltip_anchor_body := _function_body(value_utils_source, "static func tooltip_anchor_rect(")
	var fallback_symbol_body := _function_body(value_utils_source, "static func fallback_symbol_letter(")
	var fallback_symbol_draw_body := _function_body(texture_drawer_source, "static func draw_fallback_symbol(")
	var equipment_draw_slots_body := _function_body(equipment_drawer_source, "static func draw_slots(")
	var active_slot_draw_body := _function_body(active_item_presenter_source, "static func draw_slots(")
	var skill_slot_draw_body := _function_body(skill_slot_presenter_source, "static func draw_slots(")
	var skill_overlay_cache_body := _function_body(skill_slot_presenter_source, "static func refresh_overlay_draw_cache(")
	var active_overlay_cache_body := _function_body(active_item_presenter_source, "static func refresh_overlay_draw_cache(")
	var hover_data_body := _function_body(value_utils_source, "static func set_hover_data(")
	var wrap_text_body := _function_body(value_utils_source, "static func wrap_text_to_width_cached(")
	var tooltip_draw_body := _function_body(tooltip_presenter_source, "static func draw_tooltip(")
	var dual_tooltip_draw_body := _function_body(tooltip_presenter_source, "static func draw_dual_item_tooltip(")
	var skill_cache_body := _function_body(value_utils_source, "static func refresh_skill_slot_draw_cache(")
	var tooltip_entry_body := _function_body(value_utils_source, "static func refresh_tooltip_entry_lines(")
	var build_acquired_body := _function_body(perk_presenter_source, "static func build_acquired_perks(")
	var perk_grid_draw_body := _function_body(perk_presenter_source, "static func draw_grid_cells(")
	var passive_roll_body := _function_body(passive_item_presenter_source, "static func build_cached_roll_entries(")
	var stats_build_body := _function_body(stats_presenter_source, "static func build_player_stat_rows(")
	var stats_apply_body := _function_body(stats_presenter_source, "static func refresh_player_stat_cache(")
	_expect(
		frame_presenter_source.find("var active_item_slot_capacity: int = CharacterInfoOverlayOwnerState.active_item_slot_capacity(runtime_state, mythic_item_runtime, base_active_item_slot_count)") >= 0,
		"character info active-item panel should reuse active item slot capacity sources"
	)
	_expect(
		frame_presenter_source.find("var active_item_hud_visuals: Object = CharacterInfoOverlayOwnerState.get_instance(registry, \"active_item_hud_visuals\")") >= 0,
		"character info draw should fetch active item HUD visuals once per frame"
	)
	_expect(
		frame_presenter_source.find("var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method(\"get_snapshot\") else {}") >= 0,
		"character info draw should fetch runtime perk snapshot once per frame"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("if not snapshot.has(\"pending_skill_choices\"):") < 0,
		"character info header should no longer read pending choices (top-right status line removed for the trash can)"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("if not snapshot.has(\"gold_from_perks\"):") < 0,
		"character info header should no longer read perk gold (top-right status line removed for the trash can)"
	)
	_expect(
		frame_presenter_source.find("var runtime_perk_icon_renderer: Object = CharacterInfoOverlayOwnerState.get_instance(registry, \"runtime_perk_icon_renderer\")") >= 0,
		"character info draw should fetch runtime perk icon renderer once per frame"
	)
	_expect(
		frame_presenter_source.find("var runtime_perk_catalog: Object = CharacterInfoOverlayOwnerState.get_instance(registry, \"runtime_perk_catalog\")") >= 0,
		"character info draw should fetch runtime perk catalog once per frame"
	)
	_expect(
		frame_presenter_source.find("var viewport: Viewport = canvas.get_viewport()") >= 0,
		"character info draw should resolve the viewport once when reading the mouse position"
	)
	_expect(
		_function_body(source, "func draw(").find("var dash_snapshot: Dictionary = _get_smasher_dash_snapshot(registry, character_type)") < 0,
		"character info draw should not fetch dash-token snapshots for the compact stat panel"
	)
	_expect(
		source.find("func _get_smasher_dash_snapshot(") < 0,
		"character info should remove the unused smasher dash snapshot helper"
	)
	_expect(
		frame_presenter_source.find("var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method(\"get_snapshot\") else {}") >= 0,
		"character info draw should fetch skill snapshot once per frame"
	)
	_expect(
		frame_presenter_source.find("CharacterInfoOverlayHeaderPresenter.draw_header(canvas, owner, panel_rect, font, registry, runtime_state, runtime_snapshot, character_type") >= 0,
		"character info header should reuse the frame-level runtime perk state, snapshot, and character type"
	)
	_expect(
		header_presenter_source.find("static func cached_status_width(font: Font, status: String, size: int, cache: Dictionary, text_size_callable: Callable) -> Dictionary:") >= 0,
		"character info header presenter should cache the status text width"
	)
	_expect(
		source.find("var _header_subtitle_cache: Dictionary = {}") >= 0,
		"character info header should keep stable subtitle cache state"
	)
	_expect(
		header_presenter_source.find("static func cached_subtitle(display_name: String, character_type: String, cache: Dictionary) -> String:") >= 0,
		"character info header presenter should own subtitle cache helper"
	)
	_expect(
		header_presenter_source.find("static func cached_status_text(pending: int, gold: int, cache: Dictionary) -> String:") >= 0,
		"character info header presenter should own status text cache helper"
	)
	_expect(
		_function_body(source, "func prewarm_assets(").find("CharacterInfoOverlayPrewarmPresenter.prewarm_draw_caches(self, font, owner, registry, module_getter, BASE_ACTIVE_ITEM_SLOT_COUNT)") >= 0,
		"character info prewarm should prepare first-draw caches after layout"
	)
	_expect(
		_function_body(prewarm_presenter_source, "static func prewarm_shared_assets_and_text(").find("CharacterInfoOverlayLingpetTextureLoader.prewarm_cached_art_assets(lingpet_art_texture_cache, lingpet_prewarm_pet_ids)") >= 0,
		"TAB-open character info prewarm should peek cached lingpet art instead of synchronously loading panel sheets"
	)
	_expect(
		_function_body(source, "func prewarm_assets_step(").find("CharacterInfoOverlayLingpetTextureLoader.prewarm_art_assets_step(_lingpet_art_texture_cache, lingpet_prewarm_pet_ids)") >= 0
			and _function_body(source, "func prewarm_assets_step(").find("CharacterInfoOverlayPrewarmPresenter.prewarm_shared_icon_assets_step(self, registry, module_getter)") >= 0,
		"character info staged prewarm should move lingpet art and shared icons out of the first TAB input frame"
	)
	_expect(
		_function_body(source, "func prewarm_lingpet_panel_assets_step(").find("CharacterInfoOverlayLingpetTextureLoader.prewarm_art_assets_step(_lingpet_art_texture_cache, lingpet_prewarm_pet_ids)") >= 0
			and _function_body(source, "func prewarm_lingpet_panel_assets_step(").find("CharacterInfoOverlayLingpetTextureLoader.prewarm_skill_icon_assets_step(_lingpet_skill_icon_texture_cache, lingpet_prewarm_pet_ids)") >= 0,
		"character info should expose a lingpet-only staged prewarm path for stage-transition owner sync"
	)
	_expect(
		prewarm_presenter_source.find("static func prewarm_stats_layout(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, base_active_item_slot_count: int) -> void:") >= 0,
		"character info prewarm should include a stats layout cache helper"
	)
	_expect(
		prewarm_presenter_source.find("static func prewarm_shared_icon_assets_step(target: Object, registry: Object, module_getter: Callable) -> bool:") >= 0,
		"character info prewarm presenter should expose staged shared icon warming"
	)
	_expect(
		_function_body(loader_source, "static func _prewarm_texture_path_threaded_step(").find("ProjectResourceLoader.prewarm_texture_threaded_step(") >= 0
			and _function_body(loader_source, "static func prewarm_art_assets_step(").find("_build_panel_art_prewarm_paths(pet_ids)") >= 0,
		"character info lingpet panel art staged prewarm should use threaded imported texture loading"
	)
	_expect(
		_function_body(loader_source, "static func _get_cached_texture_path(").find("ProjectResourceLoader.get_cached_texture(path)") >= 0
			and _function_body(lingpet_presenter_source, "static func draw_companion_panel(").find("CharacterInfoOverlayLingpetTextureLoader.get_cached_art_texture") >= 0
			and _function_body(lingpet_presenter_source, "static func draw_companion_panel(").find("CharacterInfoOverlayLingpetTextureLoader.get_cached_static_art_texture") >= 0
			and _function_body(lingpet_presenter_source, "static func draw_companion_panel(").find("CharacterInfoOverlayLingpetTextureLoader.get_art_texture") < 0,
		"character info TAB draw should use cached-only panel art with a static-art fallback instead of blocking on in-flight streams"
	)
	_expect(
		_function_body(loader_source, "static func _resolve_prewarm_pet_ids(").find("return []") >= 0
			and loader_source.find("const PREWARM_ALL_PETS") >= 0,
		"character info lingpet texture loader should require an explicit roster token instead of treating null as full-roster prewarm"
	)
	_expect(
		prewarm_filter_source.find("static func get_active_prewarm_pet_ids(") >= 0
			and prewarm_filter_source.find("load_snapshot") < 0
			and prewarm_filter_source.find("_append_from_save_snapshot") < 0,
		"character info lingpet prewarm filter should be owner-only; boot with empty owner intentionally warms zero lingpet panel art"
	)
	_expect(
		battle_overlay_input_source.find("CharacterInfoLingpetPrewarmFilter.get_slot_prewarm_pet_ids(owner, registry, module_getter)") >= 0
			and battle_overlay_input_source.find("prewarm_assets(owner, registry, module_getter, true, _get_view_size(owner), lingpet_prewarm_pet_ids)") >= 0,
		"battle TAB character info open should pass an equipped-slot lingpet filter instead of synchronously prewarming the full roster"
	)
	_expect(
		plaza_overlay_host_source.find("CharacterInfoLingpetPrewarmFilter.get_slot_prewarm_pet_ids(_owner, _registry, _module_getter)") >= 0
			and plaza_overlay_host_source.find("prewarm_assets(_owner, _registry, _module_getter, true, view_size, lingpet_prewarm_pet_ids)") >= 0,
		"plaza TAB character info open should pass an equipped-slot lingpet filter instead of synchronously prewarming the full roster"
	)
	_expect(
		_function_body(prewarm_presenter_source, "static func prewarm_stats_layout(").find("target.call(\"_text_size\", font, str(row.get(\"value\", \"\")), 13)") >= 0,
		"character info stats prewarm should populate compact stat text caches"
	)
	_expect(
		source.find("func _prewarm_visible_item_icons(owner: Object, registry: Object, module_getter: Callable) -> void:") >= 0,
		"character info prewarm should warm visible equipment and inventory icons"
	)
	_expect(
		_function_body(header_presenter_source, "static func cached_subtitle(").find("% [display_name") < 0,
		"character info header subtitle should avoid format arrays after cache misses"
	)
	_expect(
		_function_body(header_presenter_source, "static func cached_status_text(").find("% [pending, gold]") < 0,
		"character info header status should avoid format arrays after cache misses"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("var title_x: float = panel_rect.position.x + 28.0 + emblem_offset") >= 0,
		"character info header should use scalar title coordinates with class-emblem offset"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("title_pos") < 0,
		"character info header should avoid a temporary title Vector2"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("var subtitle_text: String = cached_subtitle(display_name, character_type, subtitle_cache)") >= 0,
		"character info header should read subtitle text from cache"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("cached_status_text(") < 0,
		"character info header should no longer compose the top-right status text (replaced by the trash can)"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("var status_width") < 0,
		"character info header should no longer measure status text width (status line removed)"
	)
	_expect(
		_function_body(header_presenter_source, "static func draw_header(").find("_text_size(font, status, 14)") < 0,
		"character info header should not measure status text directly every frame"
	)
	_expect(
		source.find("_update_frame_layout(view_size)") >= 0,
		"character info draw should reuse cached layout rects while the view size is stable"
	)
	_expect(
		layout_source.find("if current_panel_rect.size != Vector2.ZERO and current_view_size.is_equal_approx(view_size):") >= 0,
		"character info layout cache should be keyed by view size"
	)
	_expect(
		layout_source.find("target.set(\"_layout_equipment_rect\", section_rect(left_rect, 0.0, 0.58))") >= 0,
		"character info layout should keep the equipment panel rect alive beside the lingpet layout"
	)
	_expect(
		layout_source.find("target.set(\"_layout_inventory_rect\", Rect2(") >= 0,
		"character info layout should keep the passive inventory panel rect alive"
	)
	_expect(
		layout_source.find("var left_rect := Rect2(") >= 0 and layout_source.find("var right_rect := Rect2(") >= 0,
		"character info layout should build explicit player and lingpet columns"
	)
	_expect(
		layout_source.find("return Rect2(column_rect.position.x, y, column_rect.size.x, max(64.0, height))") >= 0,
		"character info section rects should use scalar Rect2 construction"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_perk_grid\", canvas, owner, registry, layout_perk_rect, font, mouse_pos, hover_data, runtime_state, runtime_perk_icon_renderer, runtime_snapshot, runtime_perk_catalog, CharacterInfoOverlayValueUtils.get_array(skill_snapshot.get(\"equipped_skills\", [])))") >= 0,
		"character info perk grid should reuse the frame-level runtime perk state, icon renderer, snapshot, and catalog"
	)
	_expect(
		source.find("var catalog: Object = catalog_override") >= 0,
		"character info perk grid should accept the frame-level runtime perk catalog"
	)
	_expect(
		source.find("var acquired: Array = _build_acquired_perks_cached(levels, catalog, effective_runtime_state, snapshot, equipped_skills_for_filter)") >= 0,
		"character info perk grid should pass the frame-level snapshot into acquired perk cache"
	)
	_expect(
		_function_body(source, "func _draw_perk_grid(").find("var grid_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)") >= 0,
		"character info perk grid should build its grid rect without temporary Vector2 allocations"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_skill_slots\", canvas, owner, registry, skill_rect, font, mouse_pos, hover_data, character_type, skill_snapshot, runtime_perk_icon_renderer)") >= 0,
		"character info skill slots should reuse the frame-level skill snapshot and icon renderer"
	)
	_expect(
		source.find("var hovered_skill_slot := -1") >= 0,
		"character info skill slots should resolve hovered slot once"
	)
	_expect(
		source.find("hovered_skill_slot = CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(mouse_pos, _last_skill_slot_start.x, _last_skill_slot_start.y, _last_skill_slot_size, _last_skill_slot_stride, max_slots)") >= 0,
		"character info skill hover should use cached linear slot math"
	)
	_expect(
		source.find("_last_skill_slot_rects") < 0,
		"character info skill hover should not keep an empty rect-map fallback"
	)
	_expect(
		_function_body(source, "func _get_hover_signature(").find("_get_rect_map_hover_signature(_last_skill_slot_rects") < 0,
		"character info skill hover signature should not scan an empty rect map"
	)
	_expect(
		_function_body(source, "func _hover_signature_contains_mouse(").find("_rect_map_key_contains_mouse(_last_skill_slot_rects") < 0,
		"character info skill hover reuse should rely on cached linear slot geometry"
	)
	_expect(
		skill_slot_draw_body.find("var hovered_empty: bool = i == hovered_skill_slot") >= 0,
		"character info empty skill slot detail should reuse the hovered slot"
	)
	_expect(
		source.find("var skill_slot_extent := Vector2(slot_size, slot_size)") < 0,
		"character info skill slots should not keep a slot extent vector for Rect2 construction"
	)
	_expect(
		source.find("var _skill_slot_rect_cache: Array[Rect2] = []") >= 0,
		"character info skill slots should cache slot rects by layout"
	)
	_expect(
		source.find("var _skill_slot_icon_rect_cache: Array[Rect2] = []") >= 0,
		"character info skill slots should cache icon rects by layout"
	)
	_expect(
		source.find("var _skill_slot_fallback_rect_cache: Array[Rect2] = []") >= 0,
		"character info skill slots should cache fallback rects by layout"
	)
	_expect(
		source.find("var _skill_slot_center_cache: Array[Vector2] = []") >= 0,
		"character info skill slots should cache empty-slot centers by layout"
	)
	_expect(
		source.find("func _update_skill_slot_layout(rect: Rect2, slot_size: float, max_slots: int) -> void:") >= 0,
		"character info skill slots should update layout geometry through a helper"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("_update_skill_slot_layout(rect, slot_size, max_slots)") >= 0,
		"character info skill draw should refresh slot layout once before iteration"
	)
	_expect(
		skill_layout_body.find("var slot_x: float = start_x + float(i) * skill_slot_step") >= 0,
		"character info skill slot x should be computed only when the layout changes"
	)
	_expect(
		skill_slot_draw_body.find("var slot_x: float = start_x + float(i) * skill_slot_step") < 0,
		"character info skill presenter draw loop should not recompute slot x every frame"
	)
	_expect(
		skill_slot_draw_body.find("var slot_rect: Rect2 = slot_rect_cache[i]") >= 0,
		"character info skill presenter should read cached slot rects in the draw loop"
	)
	_expect(
		skill_slot_draw_body.find("var slot_rect := Rect2(slot_x, slot_y, slot_size, slot_size)") < 0,
		"character info skill presenter should avoid Rect2 construction inside the draw loop"
	)
	_expect(
		source.find("var fallback_skill_color: Color = CharacterInfoOverlayFormatter.skill_fallback_color(character_type, ACCENT_BLUE)") >= 0,
		"character info skill slots should reuse the character fallback color"
	)
	_expect(
		skill_slot_draw_body.find("var skill_icon_rect := Rect2(slot_x + 5.0, slot_y + 5.0, slot_size - 10.0, slot_size - 10.0)") < 0,
		"character info skill presenter should not rebuild icon rects inside the draw loop"
	)
	_expect(
		skill_slot_draw_body.find("icon_renderer.draw_icon(canvas, skill_id, icon_rect_cache[i], 1.0, true)") >= 0,
		"character info skill presenter should reuse cached icon rects"
	)
	_expect(
		skill_slot_draw_body.find("var fallback_rect := Rect2(slot_x + 9.0, slot_y + 9.0, slot_size - 18.0, slot_size - 18.0)") < 0,
		"character info skill presenter fallback rects should not be rebuilt inside the draw loop"
	)
	_expect(
		skill_slot_draw_body.find("CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, fallback_rect_cache[i], color, skill_id") >= 0,
		"character info skill presenter fallback symbols should reuse cached fallback rects"
	)
	_expect(
		skill_slot_draw_body.find("slot_rect.grow(") < 0,
		"character info skill presenter should not allocate grown rects per visible slot"
	)
	_expect(
		source.find("var can_draw_skill_icon: bool = icon_renderer != null and icon_renderer.has_method(\"draw_icon\")") >= 0,
		"character info skill slots should check icon renderer capability once before slot iteration"
	)
	_expect(
		skill_slot_draw_body.find("if not can_draw_skill_icon or not bool(icon_renderer.draw_icon(canvas, skill_id, icon_rect_cache[i], 1.0, true)):") >= 0,
		"character info skill presenter loop should reuse the cached icon renderer capability"
	)
	_expect(
		skill_slot_draw_body.find("var has_skill_slot: bool = i < equipped_count") >= 0,
		"character info filled skill slots should skip the empty-slot base draw path"
	)
	_expect(
		source.find("const OVERLAY_SLOT_FILL := Color(12.0 / 255.0, 17.0 / 255.0, 29.0 / 255.0, 0.96)") >= 0,
		"character info slot draws should reuse a shared slot fill constant"
	)
	_expect(
		source.find("const OVERLAY_SLOT_BORDER := Color(80.0 / 255.0, 100.0 / 255.0, 140.0 / 255.0, 0.72)") >= 0,
		"character info slot draws should reuse a shared slot border constant"
	)
	_expect(
		source.find("const OVERLAY_SKILL_EMPTY_HOVER_FILL := Color(80.0 / 255.0, 90.0 / 255.0, 110.0 / 255.0, 0.35)") >= 0,
		"character info empty skill hover fill should be a shared constant"
	)
	_expect(
		skill_slot_draw_body.find("CharacterInfoOverlayTextureDrawer.draw_empty_slot_socket(canvas, slot_rect, slot_fill, slot_border)") >= 0,
		"character info skill presenter should route empty slots through the shared empty-slot socket helper"
	)
	_expect(
		texture_drawer_source.find("static func draw_slot_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:") >= 0,
		"character info texture drawer should expose the shared slot panel helper"
	)
	_expect(
		skill_cache_body.find("slot_fill_color.r * 0.88 + color.r * 0.12") >= 0,
		"character info filled skill slot tint should reuse the fixed slot fill constant"
	)
	_expect(
		skill_slot_draw_body.find("canvas.draw_circle(center_cache[i], slot_size * 0.22, empty_hover_fill)") >= 0,
		"character info skill presenter empty-slot hover detail should reuse cached center and fixed hover color"
	)
	_expect(
		skill_slot_draw_body.find("draw_text_centered_xy_callable.call(canvas, font, label, center_x_cache[i], label_y, 10, text_dim)") >= 0,
		"character info skill presenter labels should reuse cached center x and label y"
	)
	_expect(
		skill_layout_body.find("\"label_y\": slot_y + slot_size - 11.0") >= 0,
		"character info skill labels should stay inside the skill slot bottom edge"
	)
	_expect(
		skill_layout_body.find("slot_size - 20.0") >= 0,
		"character info skill icons should reserve lower in-slot space for the label glyph"
	)
	_expect(
		skill_layout_body.find("\"label_y\": slot_y + slot_size +") < 0,
		"character info skill labels should not be positioned below the slot box"
	)
	_expect(
		_function_body(lingpet_presenter_source, "static func _draw_skill_symbol(").find("maribo_resonance_boost") >= 0,
		"character info lingpet passive fallback symbol should recognize Maribo's catalog passive id"
	)
	_expect(
		source.find("var _skill_slot_fill_color_cache: Array[Color] = []") >= 0,
		"character info filled skill slots should cache tinted fill colors"
	)
	_expect(
		source.find("func _refresh_skill_slot_draw_cache(equipped: Array, skill_data: Dictionary, fallback_skill_color: Color) -> void:") >= 0,
		"character info skill slots should refresh draw colors through a cache helper"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("_refresh_skill_slot_draw_cache(equipped, skill_data, fallback_skill_color)") >= 0,
		"character info skill slots should refresh draw caches before slot iteration"
	)
	_expect(
		skill_cache_body.find("slot_fill_color.r * 0.88 + color.r * 0.12") >= 0,
		"character info filled skill slot tint should reuse the fixed slot fill constant"
	)
	_expect(
		skill_slot_draw_body.find("var skill_slot_fill := Color(") < 0,
		"character info skill presenter draw loop should not rebuild tinted fill colors"
	)
	_expect(
		skill_slot_draw_body.find("CharacterInfoOverlayTextureDrawer.draw_slot_panel(canvas, slot_rect, fill_color_cache[i], border_color_cache[i], 2.0)") >= 0,
		"character info skill presenter should draw cached tinted fills through the shared slot panel helper"
	)
	_expect(
		texture_drawer_source.find("PremiumPanelFrame.KIND_SLOT") >= 0,
		"character info texture drawer should route slot borders to the premium frame slot kind"
	)
	_expect(
		skill_slot_draw_body.find("var skill_id: String = id_cache[i]") >= 0,
		"character info skill presenter should reuse cached skill ids"
	)
	_expect(
		skill_slot_draw_body.find("var data: Dictionary = data_cache[i]") >= 0,
		"character info skill presenter should reuse cached skill data"
	)
	_expect(
		skill_slot_draw_body.find("var color: Color = color_cache[i]") >= 0,
		"character info skill presenter should reuse cached skill colors"
	)
	_expect(
		skill_slot_draw_body.find("Color(color.r, color.g, color.b, 0.72)") < 0,
		"character info skill presenter draw loop should not rebuild border colors"
	)
	_expect(
		source.find("var _skill_slot_draw_cache_equipped_hash := 0") >= 0,
		"character info skill slot draw cache should keep the equipped hash as a scalar"
	)
	_expect(
		source.find("var _skill_slot_label_cache: Array[String] = []") >= 0,
		"character info skill slot labels should be cached with draw data"
	)
	_expect(
		skill_cache_body.find("label_cache[i] = str(short_skill_name_callable.call(data, skill_id))") >= 0,
		"character info skill slot cache should precompute trimmed labels"
	)
	_expect(
		skill_slot_draw_body.find("var label: String = label_cache[i]") >= 0,
		"character info skill presenter draw loop should read cached labels"
	)
	_expect(
		skill_slot_draw_body.find("CharacterInfoOverlayFormatter.short_skill_name(data, skill_id)") < 0,
		"character info skill presenter draw loop should not trim labels per visible slot"
	)
	_expect(
		source.find("func _skill_slot_draw_cache_matches(") < 0,
		"character info skill slot cache should not keep a separate one-line match wrapper"
	)
	_expect(
		skill_overlay_cache_body.find("for value in equipped:") < 0,
		"character info skill slot cache should not build signatures through per-skill string loops"
	)
	_expect(
		skill_overlay_cache_body.find("var equipped_hash: int = hash(equipped)") >= 0,
		"character info skill slot cache should include the equipped skill array hash"
	)
	_expect(
		skill_overlay_cache_body.find("equipped_hash == current_equipped_hash and skill_data_hash == current_skill_data_hash") >= 0,
		"character info skill slot cache should avoid formatting string signatures on stable frames"
	)
	_expect(
		source.find("func _make_skill_slot_draw_cache_signature(") < 0,
		"character info skill slot cache should not keep a string-signature helper"
	)
	_expect(
		source.find("func _get_hovered_linear_slot_index(") < 0,
		"character info should not keep the overlay linear hover index wrapper"
	)
	_expect(
		source.find("func _format_int_pair(") < 0,
		"character info stat pair labels should use the shared formatter directly"
	)
	_expect(
		source.find("func _apply_stat_chain(") < 0 and (source.find("Callable(CharacterInfoOverlayOwnerState, \"apply_stat_chain\")") >= 0 or active_item_presenter_source.find("Callable(CharacterInfoOverlayOwnerState, \"apply_stat_chain\")") >= 0 or stats_presenter_source.find("Callable(CharacterInfoOverlayOwnerState, \"apply_stat_chain\")") >= 0),
		"character info stat math should call the owner-state stat-chain helper directly"
	)
	_expect(
		source.find("func _call_numeric_multiplier(") < 0 and stats_presenter_source.find("Callable(CharacterInfoOverlayOwnerState, \"call_numeric_multiplier\")") >= 0,
		"character info stat multipliers should call the owner-state multiplier helper directly"
	)
	_expect(
		source.find("func _sort_perks(") < 0 and perk_presenter_source.find("static func sort_perks(") >= 0 and build_acquired_body.find("return sort_perks(a, b)") >= 0,
		"character info acquired perk sorting should call the perk presenter directly"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_active_items\", canvas, owner, registry, active_items_rect, font, mouse_pos, hover_data, active_item_slot_capacity, active_item_hud_visuals, stat_sources, active_item_slots)") >= 0,
		"character info active-item panel should receive the cached slot capacity and active slots"
	)
	_expect(
		source.find("\"%d / %d\" % [active_slots.size(), active_item_slot_capacity]") < 0,
		"character info active-item panel should avoid per-frame format arrays for slot capacity"
	)
	_expect(
		source.find("var _frame_stat_sources: Array = []") >= 0,
		"character info overlay should keep a reusable frame-level stat source array"
	)
	_expect(
		frame_presenter_source.find("stat_sources.clear()") >= 0,
		"character info draw should reuse the frame-level stat source array"
	)
	_expect(
		source.find("_layout_inventory_rect, _frame_stat_sources, _frame_hover_data") >= 0,
		"character info draw should pass the reused frame-level stat sources"
	)
	_expect(
		frame_presenter_source.find("stat_sources.append(lingpet_runtime)") >= 0,
		"character info draw should include lingpet stat bonuses in the reused frame-level stat sources"
	)
	_expect(
		frame_presenter_source.find("var active_item_slots: Array = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, \"active_item_slots\", []))") >= 0,
		"character info draw should fetch active item slots once per frame"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_active_items\", canvas, owner, registry, active_items_rect, font, mouse_pos, hover_data, active_item_slot_capacity, active_item_hud_visuals, stat_sources, active_item_slots)") >= 0,
		"character info active item draw should reuse the frame-level slot capacity, stat sources, and active slots"
	)
	_expect(
		source.find("var hovered_active_slot := -1") >= 0,
		"character info active item slots should resolve hovered slot once"
	)
	_expect(
		source.find("hovered_active_slot = CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(mouse_pos, _last_active_slot_start.x, _last_active_slot_start.y, _last_active_slot_size, _last_active_slot_stride, max_slots)") >= 0,
		"character info active item hover should use cached linear slot math"
	)
	_expect(
		source.find("_last_active_item_slot_rects") < 0,
		"character info active item hover should not keep an empty rect-map fallback"
	)
	_expect(
		_function_body(source, "func _get_hover_signature(").find("_get_rect_map_hover_signature(_last_active_item_slot_rects") < 0,
		"character info active item hover signature should not scan an empty rect map"
	)
	_expect(
		_function_body(source, "func _hover_signature_contains_mouse(").find("_rect_map_key_contains_mouse(_last_active_item_slot_rects") < 0,
		"character info active item hover reuse should rely on cached linear slot geometry"
	)
	_expect(
		active_slot_draw_body.find("var empty_slot_hovered: bool = i == hovered_active_slot") >= 0,
		"character info active item presenter empty-slot marker should reuse the hovered slot"
	)
	_expect(
		source.find("var active_slot_extent := Vector2(slot_size, slot_size)") < 0,
		"character info active item slots should not keep a slot extent vector for Rect2 construction"
	)
	_expect(
		source.find("var _active_slot_rect_cache: Array[Rect2] = []") >= 0,
		"character info active item slots should cache slot rects by layout"
	)
	_expect(
		source.find("var _active_slot_fallback_rect_cache: Array[Rect2] = []") >= 0,
		"character info active item slots should cache fallback rects by layout"
	)
	_expect(
		source.find("var _active_slot_center_x_cache: Array[float] = []") >= 0,
		"character info active item slots should cache slot center x values by layout"
	)
	_expect(
		source.find("var _active_slot_has_item_cache: Array[bool] = []") >= 0,
		"character info active item slots should cache occupied slot flags for drawing"
	)
	_expect(
		source.find("var _active_slot_item_cache: Array[Dictionary] = []") >= 0,
		"character info active item slots should cache item dictionaries for drawing"
	)
	_expect(
		source.find("var _active_slot_fallback_color_cache: Array[Color] = []") >= 0,
		"character info active item slots should cache fallback colors for drawing"
	)
	_expect(
		source.find("func _update_active_slot_layout(rect: Rect2, slot_size: float, gap: float, max_slots: int) -> void:") >= 0,
		"character info active item slots should update layout geometry through a helper"
	)
	_expect(
		source.find("func _refresh_active_slot_draw_cache(slots: Array, max_slots: int, visuals: Object, should_cache_colors: bool) -> void:") >= 0,
		"character info active item slots should refresh draw data through a helper"
	)
	_expect(
		source.find("func _active_slot_draw_cache_matches(") < 0,
		"character info active item slot cache should not keep a separate one-line match wrapper"
	)
	_expect(
		active_overlay_cache_body.find("_active_slot_draw_signature_parts.clear()") < 0,
		"character info active item cache should not build signatures through reusable string append loops"
	)
	_expect(
		active_overlay_cache_body.find("var slots_hash: int = hash(slots)") >= 0,
		"character info active item cache should include the active slot array hash"
	)
	_expect(
		active_overlay_cache_body.find("slots_hash == current_slots_hash and max_slots == current_max_slots") >= 0,
		"character info active item cache should avoid formatting string signatures on stable frames"
	)
	_expect(
		source.find("var _active_slot_draw_cache_slots_hash := 0") >= 0,
		"character info active item cache should store the slot hash as a scalar"
	)
	_expect(
		source.find("func _make_active_slot_draw_cache_signature(") < 0,
		"character info active item cache should not keep a string-signature helper"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("_update_active_slot_layout(rect, slot_size, gap, max_slots)") >= 0,
		"character info active item draw should refresh slot layout once before iteration"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("_refresh_active_slot_draw_cache(slots, max_slots, visuals, not can_draw_active_item_icon)") >= 0,
		"character info active item draw should refresh slot draw cache once before iteration"
	)
	_expect(
		active_layout_body.find("var slot_x: float = active_slot_start_x + float(i) * active_slot_step") >= 0,
		"character info active item slot x should be computed only when the layout changes"
	)
	_expect(
		active_slot_draw_body.find("var slot_x: float = active_slot_start_x + float(i) * active_slot_step") < 0,
		"character info active item presenter draw loop should not recompute slot x every frame"
	)
	_expect(
		active_slot_draw_body.find("var slot_rect: Rect2 = slot_rect_cache[i]") >= 0,
		"character info active item presenter should read cached slot rects in the draw loop"
	)
	_expect(
		active_slot_draw_body.find("var slot_rect := Rect2(slot_x, y, slot_size, slot_size)") < 0,
		"character info active item presenter should avoid Rect2 construction inside the draw loop"
	)
	_expect(
		source.find("const OVERLAY_ACTIVE_EMPTY_TEXT := Color(95.0 / 255.0, 100.0 / 255.0, 120.0 / 255.0)") >= 0,
		"character info empty active item marker color should be a shared constant"
	)
	_expect(
		active_slot_draw_body.find("draw_text_centered_xy_callable.call(canvas, font, \"-\", center_x_cache[i], empty_marker_y, 20, empty_text_color)") >= 0,
		"character info active item presenter empty marker should reuse cached center and marker y"
	)
	_expect(
		active_slot_draw_body.find("var fallback_rect := Rect2(slot_x + 10.0, y + 10.0, slot_size - 20.0, slot_size - 20.0)") < 0,
		"character info active item presenter fallback rects should not be rebuilt inside the draw loop"
	)
	_expect(
		active_slot_draw_body.find("CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, fallback_rect_cache[i], active_item_color, str(item_data.get(\"name\", \"\"))") >= 0,
		"character info active item presenter fallback symbols should reuse cached fallback rects"
	)
	_expect(
		active_slot_draw_body.find("slot_rect.grow(") < 0,
		"character info active item presenter should not allocate grown rects per visible slot"
	)
	_expect(
		source.find("var can_draw_active_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method(\"draw_icon\")") >= 0,
		"character info active item slots should check icon renderer capability once before slot iteration"
	)
	_expect(
		active_slot_draw_body.find("if can_draw_active_item_icon:") >= 0,
		"character info active item presenter loop should reuse the cached icon renderer capability"
	)
	_expect(
		active_slot_draw_body.find("var has_active_slot: bool = slot_has_item_cache[i]") >= 0,
		"character info active item presenter should read cached slot presence in the draw loop"
	)
	_expect(
		active_slot_draw_body.find("slots[i] is Dictionary") < 0,
		"character info active item presenter draw loop should not repeat slot dictionary checks"
	)
	_expect(
		active_slot_draw_body.find("var item_data: Dictionary = slot_item_cache[i]") >= 0,
		"character info active item presenter should read cached item data in the draw loop"
	)
	_expect(
		active_slot_draw_body.find("var active_item_color: Color = fallback_color_cache[i]") >= 0,
		"character info active item presenter should read cached fallback colors in the draw loop"
	)
	_expect(
		active_slot_draw_body.find("var has_active_item_color: bool = has_fallback_color_cache[i]") >= 0,
		"character info active item presenter hover should know whether fallback color is already cached"
	)
	_expect(
		active_slot_draw_body.find("var active_item_hovered: bool = i == hovered_active_slot") >= 0,
		"character info active item presenter hover should reuse the hovered slot"
	)
	_expect(
		active_slot_draw_body.find("var active_slot_center_x: float = slot_x + slot_size * 0.5") < 0,
		"character info active item presenter labels should not recompute slot center x in the draw loop"
	)
	_expect(
		active_slot_draw_body.find("draw_text_centered_xy_callable.call(canvas, font, trimmed_label, center_x_cache[i], label_y, 10, text_dim)") >= 0,
		"character info active item presenter labels should reuse cached center x and label y"
	)
	_expect(
		active_slot_draw_body.find("var trimmed_label: String = trimmed_label_cache[i]") >= 0,
		"character info active item presenter labels should read precomputed trimmed labels directly by index"
	)
	_expect(
		active_slot_draw_body.find("var display_name: String = display_name_cache[i]") >= 0,
		"character info active item presenter labels should read precomputed display names directly by index"
	)
	_expect(
		active_slot_draw_body.find("i < trimmed_label_cache.size()") < 0,
		"character info active item presenter should not bounds-check stable label caches per filled slot"
	)
	_expect(
		active_slot_draw_body.find("_trim_label(display_name, 10)") < 0,
		"character info active item presenter should not trim labels after the label cache refresh"
	)
	_expect(
		active_slot_draw_body.find("if not has_active_item_color:") >= 0,
		"character info active item presenter hover should reuse fallback item color when available"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_passive_inventory\", canvas, owner, registry, inventory_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)") >= 0,
		"character info passive inventory draw should reuse frame-level active item HUD visuals, mythic runtime, and runtime perk state"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_equipment_slots\", canvas, owner, registry, equipment_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)") >= 0,
		"character info equipment draw should reuse frame-level mythic runtime and runtime perk state for roll tooltips"
	)
	_expect(
		_function_body(source, "func _draw_equipment_slots(").find("var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 34.0, rect.size.x - 24.0, rect.size.y - 42.0)") >= 0,
		"character info equipment draw should build its content rect without temporary Vector2 allocations"
	)
	_expect(
		frame_presenter_source.find("hover_data = target.call(\"_draw_stats_panel\", canvas, owner, registry, layout_stats_rect, font, runtime_state, active_item_runtime, mythic_item_runtime, character_type, stat_sources, mouse_pos, hover_data, active_item_slot_capacity, active_item_slots)") >= 0,
		"character info stats draw should reuse frame-level runtime sources, compact stat sources, active-item slots, capacity, and hover state"
	)
	_expect(
		stats_build_body.find("var stat_sources: Array = stat_sources_override if not stat_sources_override.is_empty() else [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]") >= 0,
		"character info stats presenter should reuse frame-level stat sources when provided"
	)
	_expect(
		source.find("write_row_cache: bool = true") >= 0,
		"character info stats builder should keep direct-call row dictionaries optional"
	)
	_expect(
		_function_body(source, "func _draw_stats_panel(").find("stat_sources_override,\n\t\tfalse") >= 0,
		"character info stats draw should skip row dictionary writes"
	)
	_expect(
		source.find("_write_simple_stat_row(9, \"대시 토큰\"") < 0,
		"character info stats should omit dash token summaries"
	)
	_expect(
		source.find("_write_simple_stat_row(10, \"장착 스킬\"") < 0,
		"character info stats should omit equipped skill summaries"
	)
	_expect(
		source.find("var _stats_row_count := 0") >= 0,
		"character info stats panel should keep the reusable stats row count"
	)
	_expect(
		source.find("var row_count: int = _stats_row_count") >= 0,
		"character info player stats draw should reuse the cached stats row count"
	)
	_expect(
		_function_body(source, "func _draw_stats_panel(").find("var stats: Array = _build_stats(") < 0,
		"character info stats panel should not allocate a returned stats array binding during draw"
	)
	_expect(
		_function_body(stats_presenter_source, "static func draw_lingpet_stat_rows(").find("tooltip_body") >= 0,
		"lingpet stat rows should support focused hover tooltip bodies from the stats presenter"
	)
	_expect(
		source.find("미리 예측해 가드") >= 0,
		"Maribo defense-rate stat should explain its local predictive-guard behavior"
	)
	_expect(
		stats_presenter_source.find("target.set(\"_stats_row_count\", row_count)") >= 0,
		"character info stats builder should refresh the reusable stats row count"
	)
	_expect(
		source.find("func _update_stats_layout(") < 0 and source.find("_stats_layout_") < 0,
		"character info stats panel should remove the unused legacy layout cache"
	)
	_expect(
		stats_presenter_source.find("refresh_player_stat_cache(rows, row_count") >= 0,
		"character info stats builder should reuse stat row dictionaries"
	)
	_expect(
		source.find("row.clear()") < 0,
		"character info stats row writers should overwrite cached rows without clearing dictionaries each frame"
	)
	_expect(
		stats_apply_body.find("if write_row_cache:") >= 0,
		"character info stat cache applier should skip row dictionaries during draw"
	)
	_expect(
		stats_apply_body.find("row.erase(\"base\")") >= 0,
		"character info stat cache applier should clear stale delta metadata from simple rows"
	)
	_expect(
		source.find("var _stats_label_cache: Array[String] = []") >= 0,
		"character info stats draw should keep a typed label cache"
	)
	_expect(
		source.find("var _stats_value_cache: Array[String] = []") >= 0,
		"character info stats draw should keep a typed value cache"
	)
	_expect(
		source.find("var _stats_color_cache: Array[Color] = []") >= 0,
		"character info stats draw should keep a typed color cache"
	)
	_expect(
		source.find("var _stats_value_width_cache: Array[float] = []") >= 0,
		"character info stats draw should cache value widths"
	)
	_expect(
		source.find("var _stats_value_width_text_cache: Array[String] = []") >= 0,
		"character info stats value width cache should track value text"
	)
	_expect(
		stats_presenter_source.find("static func _get_cached_value_width(font: Font, index: int, value_text: String, size: int") >= 0,
		"character info stats draw should use a presenter-owned value width cache helper"
	)
	_expect(
		source.find("var stat: Dictionary = _get_dict(stat_value)") < 0,
		"character info stats draw should not unpack row dictionaries during the draw loop"
	)
	_expect(
		stats_presenter_source.find("_draw_text_xy(canvas, font, str(label_cache[i]), label_draw_x, baseline_y, row_size, text_dim, ui_text_scale)") >= 0,
		"character info stats draw should read labels from typed scalar caches after icon offset"
	)
	_expect(
		stats_presenter_source.find("_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color, ui_text_scale)") >= 0,
		"character info stats values should draw through the scalar baseline helper"
	)
	_expect(
		_function_body(source, "func _draw_stats_panel(").find("var baseline: Vector2 = _stats_layout_positions[i]") < 0,
		"character info stats draw should not unpack Vector2 baselines"
	)
	_expect(
		_function_body(source, "func _draw_stats_panel(").find("_text_size(font, value_text, _stats_layout_row_size)") < 0,
		"character info stats draw should not recalculate value text sizes every frame"
	)
	_expect(
		stats_presenter_source.find("var value_width: float = _get_cached_value_width(font, i, value_text, row_size") >= 0,
		"character info stats draw should read value widths from cache"
	)
	_expect(
		stats_presenter_source.find("var item_cooldown_seconds: float = float(CharacterInfoOverlayOwnerState.active_item_cooldown_from_base(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC, stat_sources, Callable(CharacterInfoOverlayOwnerState, \"apply_stat_chain\"))) / 1000.0") >= 0,
		"character info stats should compute default active-item cooldown through the shared scalar base path"
	)
	_expect(
		source.find("{\"cooldown_msec\": ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC}") < 0,
		"character info stats should not allocate a default cooldown dictionary per draw"
	)
	_expect(
		source.find("func _get_effective_active_item_cooldown_from_base(") < 0,
		"character info should not keep the overlay active-item cooldown wrapper"
	)
	_expect(
		source.find("func _stats_row_font_size(") < 0,
		"character info stats row size should not keep a one-line overlay wrapper"
	)
	_expect(
		source.find("func _stat_delta_color(") < 0,
		"character info stats delta color should not keep a one-line overlay wrapper"
	)
	_expect(
		stats_presenter_source.find("stat_delta_color(base_value, current_value, higher_is_better, buff_color, debuff_color)") >= 0,
		"character info stats delta rows should compute color once inside the shared presenter"
	)
	_expect(
		stats_apply_body.find("var row: Dictionary = row_cache[i]") >= 0,
		"character info stats row lookup should reuse indexed row dictionaries without resizing per row"
	)
	_expect(
		_function_body(stats_presenter_source, "static func build_overlay_player_stat_rows(").find("return row_cache") >= 0,
		"character info stats builder should return the reusable stat row cache"
	)
	_expect(
		source.find("panel_rect = panel_rect.grow") < 0,
		"character info opening frames should keep the panel layout stable so layout caches can be reused"
	)
	_expect(
		source.find("canvas.draw_line(rect.position + Vector2(12.0, 3.0)") < 0,
		"character info panels should skip decorative glint lines in the overlay draw budget"
	)
	_expect(
		stats_presenter_source.find("var value_right_x: float = rect.end.x - 2.0") >= 0,
		"character info stats panel should use a stable scalar value-right edge during row draw"
	)
	_expect(
		stats_presenter_source.find("simple_stat_row(\"액티브 아이템 슬롯\", CharacterInfoOverlayFormatter.format_int_pair(active_item_slot_count, active_item_slot_capacity), active_item_slot_color)") >= 0,
		"character info stats should show active item slot count and capacity"
	)
	_expect(
		source.find("_passive_item_roll_entries_cache_item_hash") >= 0,
		"character info passive item roll entries should keep a numeric item hash cache guard"
	)
	_expect(
		passive_roll_body.find("item_hash == cache_item_hash") >= 0,
		"character info passive item roll entries should hit the cache before rebuilding string signatures"
	)
	_expect(
		passive_roll_body.find("_passive_item_roll_entries_signature(") < 0,
		"character info passive item roll entries should avoid the old roll signature builder on hover draws"
	)
	_expect(
		source.find("_passive_item_roll_entries_cache_signature") < 0,
		"character info passive item roll entries should not keep an unused string cache signature"
	)
	_expect(
		passive_roll_body.find("var fixed_options: Array = CharacterInfoOverlayValueUtils.get_array(item_data.get(\"fixed_options\", []))") >= 0,
		"character info passive item roll entries should reuse fixed options"
	)
	_expect(
		source.find("var _empty_tooltip_roll_entries: Array = []") >= 0,
		"character info tooltips should keep a reusable empty roll-entry array"
	)
	_expect(
		tooltip_draw_body.find("var roll_entries: Array = CharacterInfoOverlayValueUtils.get_array(data.get(\"roll_options\")) if data.has(\"roll_options\") else CharacterInfoOverlayValueUtils.get_array(data.get(\"options\")) if data.has(\"options\") else empty_roll_entries") >= 0,
		"character info tooltip roll entries should read roll options only when present"
	)
	_expect(
		source.find("func _get_tooltip_roll_entries(") < 0,
		"character info tooltips should not keep the overlay roll-entry wrapper"
	)
	_expect(
		tooltip_draw_body.find("data.has(\"options\")") >= 0,
		"character info tooltip roll entries should read fallback options only when present"
	)
	_expect(
		_function_body(source, "func _draw_tooltip(").find("_empty_tooltip_roll_entries") >= 0,
		"character info tooltip roll entries should avoid allocating an empty array for ordinary hovers"
	)
	_expect(
		source.find("const OVERLAY_TOOLTIP_PANEL_FILL := Color(12.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.97)") >= 0,
		"character info tooltip panel fill should be cached as a constant"
	)
	_expect(
		source.find("const OVERLAY_TOOLTIP_ROLL_PANEL_FILL := Color(18.0 / 255.0, 22.0 / 255.0, 40.0 / 255.0, 0.97)") >= 0,
		"character info roll tooltip panel fill should be cached as a constant"
	)
	_expect(
		source.find("const OVERLAY_TOOLTIP_ROLL_BORDER := Color(1.0, 140.0 / 255.0, 70.0 / 255.0)") >= 0,
		"character info roll tooltip border should be cached as a constant"
	)
	_expect(
		source.find("const UI_FONT_SIZE_CACHE_LIMIT := 64") >= 0,
		"character info text draws should cap the reusable UI font-size cache"
	)
	_expect(
		source.find("var _ui_font_size_cache: Array[int] = []") >= 0,
		"character info text draws should keep a typed UI font-size cache"
	)
	_expect(
		_function_body(source, "func _ui_font_size(").find("while _ui_font_size_cache.size() <= size:") >= 0,
		"character info UI font-size conversion should reuse cached small sizes"
	)
	_expect(
		_function_body(source, "func _ui_font_size(").find("size >= UI_FONT_SIZE_CACHE_LIMIT") >= 0,
		"character info UI font-size cache should keep large sizes on the direct path"
	)
	_expect(
		_function_body(source, "func _draw_text_centered_with_size_xy(").find("center - Vector2(") < 0,
		"character info centered text draw should avoid an intermediate Vector2 subtraction"
	)
	_expect(
		_function_body(source, "func _draw_text_centered_with_size_xy(").find("Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34)") >= 0,
		"character info centered text draw should build the baseline directly from scalars"
	)
	_expect(
		source.find("const FALLBACK_SYMBOL_RING_SEGMENTS := 8") >= 0,
		"character info fallback symbols should keep the tightened ring segment budget"
	)
	_expect(
		fallback_symbol_draw_body.find("center + Vector2(0.0, 3.0)") < 0,
		"character info fallback symbols should avoid a temporary centered-text offset vector"
	)
	_expect(
		fallback_symbol_draw_body.find("draw_text_centered_xy_callable.call(canvas, ThemeDB.fallback_font, letter, center.x, center.y + 3.0") >= 0,
		"character info fallback symbols should draw text through the scalar center helper"
	)
	_expect(
		source.find("const FALLBACK_SYMBOL_LETTER_CACHE_LIMIT := 256") >= 0,
		"character info fallback symbols should cap the reusable letter cache"
	)
	_expect(
		source.find("var _fallback_symbol_letter_cache: Dictionary = {}") >= 0,
		"character info fallback symbols should keep a reusable letter cache"
	)
	_expect(
		fallback_symbol_draw_body.find("var letter: String = CharacterInfoOverlayValueUtils.fallback_symbol_letter(id_text, letter_cache, letter_cache_limit)") >= 0,
		"character info fallback symbol draw should use the cached letter helper"
	)
	_expect(
		fallback_symbol_draw_body.find("substr(0, 1).to_upper()") < 0,
		"character info fallback symbol draw should not rebuild uppercase letters per draw"
	)
	_expect(
		fallback_symbol_body.find("id_text.substr(0, 1).to_upper()") >= 0,
		"character info fallback symbol letter helper should own the uppercase conversion"
	)
	_expect(
		tooltip_draw_body.find("var rect := Rect2(pos_x, pos_y, width, height)") >= 0,
		"character info tooltip rect should avoid temporary Vector2 position/size values"
	)
	_expect(
		source.find("var _tooltip_subtitle_color_source := Color.TRANSPARENT") >= 0,
		"character info tooltip subtitle colors should be cache guarded"
	)
	_expect(
		source.find("func _tooltip_subtitle_color(color: Color) -> Color:") >= 0,
		"character info tooltip subtitle colors should use a cache helper"
	)
	_expect(
		tooltip_draw_body.find("var text_x: float = pos_x + 14.0") >= 0,
		"character info tooltip text should reuse a scalar baseline x"
	)
	_expect(
		tooltip_draw_body.find("rect.position.x + 14.0") < 0,
		"character info tooltip text should avoid repeated rect position lookups"
	)
	_expect(
		tooltip_draw_body.find("var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)") >= 0,
		"character info tooltip subtitle should reuse cached subtitle color"
	)
	_expect(
		source.find("func _draw_character_card(") < 0,
		"character info should remove the unused legacy character card helper"
	)
	_expect(
		source.find("func _draw_meter(") < 0,
		"character info should remove the unused legacy meter helper"
	)
	_expect(
		dual_tooltip_draw_body.find("var desc_rect := Rect2(pos_x, pos_y, desc_width, desc_height)") >= 0,
		"character info dual tooltip description rect should avoid temporary Vector2 position/size values"
	)
	_expect(
		dual_tooltip_draw_body.find("var roll_rect := Rect2(pos_x + desc_width + gap, pos_y, roll_width, roll_height)") >= 0,
		"character info dual tooltip roll rect should avoid temporary position and size Vector2 values"
	)
	_expect(
		dual_tooltip_draw_body.find("var desc_text_x: float = pos_x + 14.0") >= 0,
		"character info dual tooltip description text should reuse a scalar baseline x"
	)
	_expect(
		dual_tooltip_draw_body.find("var roll_text_x: float = pos_x + desc_width + gap + 12.0") >= 0,
		"character info dual tooltip roll text should reuse a scalar baseline x"
	)
	_expect(
		dual_tooltip_draw_body.find("desc_rect.position.x + 14.0") < 0,
		"character info dual tooltip description text should avoid repeated rect position lookups"
	)
	_expect(
		dual_tooltip_draw_body.find("roll_rect.position.x + 12.0") < 0,
		"character info dual tooltip roll text should avoid repeated rect position lookups"
	)
	_expect(
		dual_tooltip_draw_body.find("var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)") >= 0,
		"character info dual tooltip subtitle should reuse cached subtitle color"
	)
	_expect(
		tooltip_draw_body.find("Color(color.r, color.g, color.b, 0.95)") < 0,
		"character info tooltip draw should not rebuild subtitle colors directly"
	)
	_expect(
		dual_tooltip_draw_body.find("Color(color.r, color.g, color.b, 0.95)") < 0,
		"character info dual tooltip draw should not rebuild subtitle colors directly"
	)
	_expect(
		source.find("mouse_pos + Vector2(16.0, 14.0)") < 0,
		"character info tooltip placement should avoid a temporary mouse-offset Vector2"
	)
	_expect(
		tooltip_anchor_body.find("return Rect2(mouse_pos.x, mouse_pos.y, 0.0, 0.0)") >= 0,
		"character info tooltip fallback anchor should use scalar Rect2 construction"
	)
	_expect(
		tooltip_anchor_body.find("Rect2(mouse_pos, Vector2.ZERO)") < 0,
		"character info tooltip fallback anchor should avoid temporary Vector2 size values"
	)
	_expect(
		source.find("var pos := Vector2(anchor_rect.position.x + 10.0") < 0,
		"character info dual tooltip placement should avoid a temporary anchor-position Vector2"
	)
	_expect(
		source.find("Rect2(pos, Vector2(width, height))") < 0,
		"character info tooltip rect should not rebuild through Vector2 size helpers"
	)
	_expect(
		source.find("Rect2(pos, Vector2(desc_width, desc_height))") < 0,
		"character info dual tooltip description rect should not rebuild through Vector2 size helpers"
	)
	_expect(
		source.find("var roll_border := Color(1.0, 140.0 / 255.0, 70.0 / 255.0)") < 0,
		"character info dual tooltip should reuse the cached roll border"
	)
	_expect(
		passive_item_presenter_source.find("roll_option_value(option, rolls, key)") >= 0,
		"character info passive item roll entries should avoid eager value/default fallback evaluation"
	)
	_expect(
		active_item_presenter_source.find("CharacterInfoOverlayValueUtils.get_number_fallback(item_data, \"cooldown_msec\", \"cooldown_ms\")") >= 0,
		"character info active item cooldowns should avoid eager cooldown fallback evaluation"
	)
	_expect(
		source.find("func _build_stat_entry(") < 0,
		"character info stats should not keep the old per-row allocation helper"
	)
	_expect(
		passive_roll_body.find("if fixed_options.is_empty() and option_source.is_empty():") >= 0,
		"character info passive item roll entries should skip empty roll tooltips before runtime lookup"
	)
	_expect(
		passive_roll_body.find("var polish_multiplier: float = CharacterInfoOverlayOwnerState.passive_item_roll_polish_multiplier(registry, runtime_state)") >= 0,
		"character info passive item roll entries should use the frame-level runtime state in the numeric cache guard"
	)
	_expect(
		source.find("func _get_passive_item_roll_polish_multiplier(") < 0,
		"character info passive item roll cache should use the owner-state polish helper directly"
	)
	_expect(
		_function_body(owner_state_source, "static func passive_item_roll_polish_multiplier(").find("if runtime_state == null:\n\t\truntime_state = get_instance(registry, \"runtime_perk_state\")") >= 0,
		"character info passive item roll cache should only fall back to registry lookup for direct calls"
	)
	_expect(
		source.find("var _tooltip_entry_lines_cache_entries_hash := 0") >= 0,
		"character info tooltip entry lines should keep a numeric entries hash guard"
	)
	_expect(
		tooltip_entry_body.find("var entries_hash: int = hash(entries)") >= 0,
		"character info tooltip entry lines should hash entries before cache lookup"
	)
	_expect(
		tooltip_entry_body.find("entries_hash == current_entries_hash") >= 0,
		"character info tooltip entry line cache should hit without rebuilding string signatures"
	)
	_expect(
		tooltip_entry_body.find("text_cache.size() == line_cache.size()") >= 0,
		"character info tooltip entry line cache guard should validate text cache size"
	)
	_expect(
		tooltip_entry_body.find("color_cache.size() == line_cache.size()") >= 0,
		"character info tooltip entry line cache guard should validate color cache size"
	)
	_expect(
		source.find("var _tooltip_entry_line_dict_cache: Array = []") >= 0,
		"character info tooltip entry line dictionaries should use an indexed cache"
	)
	_expect(
		source.find("var _tooltip_entry_line_text_cache: Array[String] = []") >= 0,
		"character info tooltip entry line text should use a typed indexed cache"
	)
	_expect(
		source.find("var _tooltip_entry_line_color_cache: Array[Color] = []") >= 0,
		"character info tooltip entry line colors should use a typed indexed cache"
	)
	_expect(
		source.find("_tooltip_entry_lines_cache_signature") < 0,
		"character info tooltip entry lines should not keep an unused string cache signature"
	)
	_expect(
		source.find("var _tooltip_entry_signature_parts: Array[String] = []") < 0,
		"character info tooltip entry lines should not keep unused string signature parts"
	)
	_expect(
		source.find("var _passive_item_roll_source_signature_parts: Array[String] = []") < 0,
		"character info passive roll entries should not keep unused string signature parts"
	)
	_expect(
		source.find("func _passive_item_roll_source_signature(") < 0,
		"character info passive roll entries should not keep an unused roll source signature helper"
	)
	_expect(
		source.find("func _passive_item_roll_entries_signature(") < 0,
		"character info passive roll entries should not keep an unused roll signature helper"
	)
	_expect(
		passive_roll_body.find("str(fixed_options)") < 0,
		"character info passive roll draw path should not stringify fixed option arrays wholesale"
	)
	_expect(
		passive_roll_body.find("str(option_source)") < 0,
		"character info passive roll draw path should not stringify roll option arrays wholesale"
	)
	_expect(
		source.find("var _frame_hover_data: Dictionary = {}") >= 0,
		"character info draw should keep a reusable frame hover dictionary"
	)
	_expect(
		frame_presenter_source.find("hover_data.clear()") >= 0,
		"character info draw should reuse the frame hover dictionary instead of allocating an empty dictionary"
	)
	_expect(
		source.find("func _set_hover_data(") >= 0,
		"character info hover data should use a shared fill helper"
	)
	_expect(
		hover_data_body.find("data.clear()") >= 0,
		"character info hover data helper should refill the reusable dictionary"
	)
	_expect(
		source.find("hover_data = {") < 0,
		"character info hover paths should avoid per-hover dictionary literals"
	)
	_expect(
		equipment_draw_slots_body.find("hover_data = set_hover_data_callable.call(") >= 0,
		"character info equipped-item hover should reuse the frame hover dictionary"
	)
	_expect(
		source.find("func _draw_equipment_slots_grid(") < 0,
		"character info should remove the unused fallback equipment grid helper"
	)
	_expect(
		_function_body(passive_inventory_drawer_source, "static func draw_inventory_cells(").find("hover_data = set_hover_data_callable.call(") >= 0,
		"character info passive inventory presenter hover should reuse the frame hover dictionary"
	)
	_expect(
		perk_grid_draw_body.find("hover_data = set_hover_data_callable.call(") >= 0,
		"character info perk presenter hover should reuse the frame hover dictionary"
	)
	_expect(
		skill_slot_draw_body.find("hover_data = set_hover_data_callable.call(") >= 0,
		"character info skill presenter hover should reuse the frame hover dictionary"
	)
	_expect(
		active_slot_draw_body.find("hover_data = set_hover_data_callable.call(") >= 0,
		"character info active item presenter hover should reuse the frame hover dictionary"
	)
	_expect(
		active_slot_draw_body.find("\"슬롯 %d\"") >= 0,
		"character info active item tooltip should show a readable Korean slot label"
	)
	_expect(
		source.find("var _last_lingpet_skill_icon_rects: Array[Rect2] = []") >= 0,
		"lingpet skill icon hover rects should be cached for redraw tracking"
	)
	_expect(
		source.find("var _last_lingpet_stat_row_rects: Array[Rect2] = []") >= 0,
		"lingpet stat row hover rects should be cached for redraw tracking"
	)
	_expect(
		_function_body(hover_source, "static func overlay_hover_signature(").find("get_rect_list_hover_signature(lingpet_skill_rects, mouse_pos, \"lingpet_skill\")") >= 0,
		"lingpet skill icons should participate in mouse-motion hover redraws"
	)
	_expect(
		_function_body(hover_source, "static func overlay_hover_signature(").find("get_rect_list_hover_signature(lingpet_stat_rects, mouse_pos, \"lingpet_stat\")") >= 0,
		"lingpet stat rows should participate in mouse-motion hover redraws"
	)
	_expect(
		_function_body(lingpet_presenter_source, "static func draw_skill_icon(").find("_fill_hover_data(hover_data") >= 0,
		"lingpet skill hover should reuse the frame hover dictionary through the presenter"
	)
	_expect(
		source.find("return _tooltip_entry_lines_cache.duplicate(true)") < 0,
		"character info tooltip entry cache should avoid per-hover deep copies"
	)
	_expect(
		tooltip_entry_body.find("line_cache.clear()") >= 0,
		"character info tooltip entry builder should reuse the cached result array"
	)
	_expect(
		tooltip_entry_body.find("text_cache.clear()") >= 0,
		"character info tooltip entry builder should clear cached line text before refill"
	)
	_expect(
		tooltip_entry_body.find("color_cache.clear()") >= 0,
		"character info tooltip entry builder should clear cached line colors before refill"
	)
	_expect(
		tooltip_entry_body.find("var result: Array = line_cache") >= 0,
		"character info tooltip entry builder should reuse the cached result array"
	)
	_expect(
		tooltip_entry_body.find("result.append({\"text\"") < 0,
		"character info tooltip entry builder should avoid per-line dictionary literals"
	)
	_expect(
		tooltip_entry_body.find("text_cache.append(line_text)") >= 0,
		"character info tooltip entry builder should fill cached line text"
	)
	_expect(
		tooltip_entry_body.find("color_cache.append(color)") >= 0,
		"character info tooltip entry builder should fill cached line colors"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("_tooltip_entry_line_text_cache") >= 0 and dual_tooltip_draw_body.find("tooltip_entry_line_text_cache[i]") >= 0,
		"character info roll tooltip draw should read cached line text"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("_tooltip_entry_line_color_cache") >= 0 and dual_tooltip_draw_body.find("tooltip_entry_line_color_cache[i]") >= 0,
		"character info roll tooltip draw should read cached line colors"
	)
	_expect(
		dual_tooltip_draw_body.find("var entry_dict: Dictionary = _get_dict(entry)") < 0,
		"character info roll tooltip draw should not unpack line dictionaries"
	)
	_expect(
		value_utils_source.find("static func tooltip_entry_line_dict(line_dict_cache: Array, index: int) -> Dictionary:") >= 0,
		"character info tooltip entry builder should reuse line dictionaries by index"
	)
	_expect(
		_function_body(value_utils_source, "static func tooltip_entry_line_dict(").find("data.clear()") >= 0,
		"character info tooltip entry line cache should clear dictionaries before refill"
	)
	_expect(
		source.find("return _passive_item_roll_entries_cache.duplicate(true)") < 0,
		"character info passive roll cache should avoid per-hover deep copies"
	)
	_expect(
		source.find("var _passive_item_roll_entry_dict_cache: Array = []") >= 0,
		"character info passive roll entries should keep an indexed dictionary cache"
	)
	_expect(
		passive_roll_body.find("roll_entries_cache.clear()\n\tvar result: Array = roll_entries_cache") >= 0,
		"character info passive roll entry builder should reuse the cached result array"
	)
	_expect(
		passive_roll_body.find("result.append({") < 0,
		"character info passive roll entry builder should avoid per-entry dictionary literals"
	)
	_expect(
		passive_item_presenter_source.find("static func roll_entry_dict(roll_entry_dict_cache: Array, index: int) -> Dictionary:") >= 0,
		"character info passive roll entries should reuse dictionaries by index"
	)
	_expect(
		_function_body(passive_item_presenter_source, "static func roll_entry_dict(").find("data.clear()") >= 0,
		"character info passive roll entry cache should clear dictionaries before refill"
	)
	_expect(
		source.find("return (cached_lines as Array).duplicate()") < 0,
		"character info wrapped text cache should avoid per-hover array copies"
	)
	_expect(
		source.find("var _wrap_text_fast_lines: Array = []") >= 0,
		"character info wrapped text should keep a one-slot fast cache"
	)
	_expect(
		wrap_text_body.find("_wrapped_text_state(fast_lines") >= 0,
		"character info wrapped text should hit the fast cache before building string keys"
	)
	_expect(
		value_utils_source.find("static func store_wrapped_text_lines(cache_key: String, text: String, size_key: int, max_width_key: int, max_lines: int, lines: Array, cache: Dictionary, cache_limit: int) -> Dictionary:") >= 0,
		"character info wrapped text should update dictionary and fast caches through one helper"
	)
	_expect(
		wrap_text_body.find(".slice(") < 0,
		"character info wrapped text should trim cached lines in-place instead of allocating slices"
	)
	_expect(
		wrap_text_body.find("while lines.size() > max_lines:") >= 0,
		"character info wrapped text should clamp cached line arrays without slice allocations"
	)
	_expect(
		tooltip_entry_body.find("_tooltip_entry_lines_signature(entries, size, max_width, max_lines)") < 0,
		"character info tooltip entry lines should avoid the old string signature builder on hover draws"
	)
	_expect(
		source.find("func _tooltip_entry_lines_signature(") < 0,
		"character info tooltip entry lines should not keep an unused string signature helper"
	)
	_expect(
		source.find("PackedStringArray()") < 0,
		"character info tooltip entry cache should avoid allocating PackedStringArray per hover"
	)


func _verify_stats_do_not_read_dash_token_snapshot() -> void:
	var overlay := CharacterInfoOverlay.new()
	var registry := FakeRegistry.new()
	var dash_state := FakeDashState.new()
	var owner := FakeOwner.new()
	registry.smasher_dash_state = dash_state

	owner.selected_character_type = "viper"
	overlay._build_stats(owner, registry)
	_expect(dash_state.snapshot_calls == 0, "non-smasher character info stats should not read smasher dash state")

	owner.selected_character_type = "smasher"
	overlay._build_stats(owner, registry)
	_expect(dash_state.snapshot_calls == 0, "compact character info stats should not read dash-token state")


func _character_info_overlay_source() -> String:
	return FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_state.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_core.gd")


func _character_info_value_utils_contract_source() -> String:
	return FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_layout_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_text_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_slot_cache_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_misc_value_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_prewarm_text_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_value_utils.gd")


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + signature.length())
	var next_static_func: int = source.find("\nstatic func ", start + signature.length())
	var next_boundary := next_func
	if next_boundary < 0 or (next_static_func >= 0 and next_static_func < next_boundary):
		next_boundary = next_static_func
	if next_boundary < 0:
		return source.substr(start)
	return source.substr(start, next_boundary - start)


func _assert_wrapped_lines_fit(overlay: Object, font: Font, lines: Array, size: int, max_width: float, message: String) -> void:
	for line_value in lines:
		var line: String = str(line_value)
		var width: float = overlay._text_size(font, line, size).x
		_expect(width <= max_width + 0.5, "%s: '%s' was %.2fpx wide for %.2fpx" % [message, line, width, max_width])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
