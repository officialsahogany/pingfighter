extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
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


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
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

	overlay.prewarm_assets(null, null, Callable(), false)
	_expect(_registry.icon_renderer.prewarm_count == 0, "partial character info prewarm should not mark icon assets done")
	_expect(_registry.active_item_visuals.prewarm_count == 0, "partial character info prewarm should not mark active item visuals done")
	_expect(not overlay._runtime_perk_text_prewarmed, "partial character info prewarm should leave runtime perk text pending without a catalog")
	_expect(not overlay._skill_text_prewarmed, "partial character info prewarm should leave skill text pending without skill configs")

	overlay.prewarm_assets(null, _registry)
	_expect(_registry.icon_renderer.prewarm_count == 1, "character info prewarm should warm perk icon assets")
	_expect(_registry.active_item_visuals.prewarm_count == 1, "character info prewarm should warm active item icons")
	_expect(overlay._runtime_perk_text_prewarmed, "character info prewarm should complete runtime perk text once the catalog is reachable")
	_expect(overlay._skill_text_prewarmed, "character info prewarm should complete skill text once configs are reachable")
	_expect(overlay._text_size_cache.size() > 0, "character info prewarm should populate text size cache")
	_expect(overlay._wrap_text_cache.size() > 0, "character info prewarm should populate wrapped text cache")

	var layout_overlay := CharacterInfoOverlay.new()
	layout_overlay.prewarm_assets(FakeOwner.new(), _registry, Callable(), false)
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
	var lingpet_art_rect: Rect2 = layout_overlay._get_lingpet_companion_art_rect(lingpet_content_rect, lingpet_skill_row_h)
	_expect(lingpet_art_rect.size.y >= 120.0, "720p lingpet panel should reserve enough height for the Maribo full-body art")
	_expect(FileAccess.file_exists(CharacterInfoOverlay.MARIBO_RESONANCE_BOOST_ICON_PATH), "maribo resonance boost passive icon asset should exist")
	_expect(layout_overlay._lingpet_skill_icon_texture_cache.has(CharacterInfoOverlay.MARIBO_RESONANCE_BOOST_ICON_PATH), "character info prewarm should cache the resonance boost passive icon")

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
	var narrow_tooltip_width: float = overlay._get_tooltip_width(font, "シャドウバックステップ", "", str(japanese_wrapped[0]), Vector2(360.0, 240.0))
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
	_expect(overlay._get_string_fallback({"desc": "fallback body"}, "description", "desc") == "fallback body", "lazy string fallback should read the secondary key only when needed")
	_expect(overlay._get_array_fallback({"options": [1, 2]}, "roll_options", "options").size() == 2, "lazy array fallback should read the secondary key only when needed")
	_expect(is_equal_approx(overlay._get_number_fallback({"cooldown_ms": 2500}, "cooldown_msec", "cooldown_ms"), 2500.0), "lazy number fallback should read the secondary key only when needed")
	_expect(is_equal_approx(overlay._get_roll_option_value({"default": 2.0}, {"speed": 3.0}, "speed"), 3.0), "roll option values should prefer live rolled values before option defaults")
	var passive_frame_color_once: Color = overlay._passive_item_frame_color({"name": "alpha", "rarity": "legendary"})
	var passive_frame_color_twice: Color = overlay._passive_item_frame_color({"name": "alpha", "rarity": "legendary"})
	_expect(passive_frame_color_once == passive_frame_color_twice, "cached passive inventory frame colors should preserve repeated output")
	var display_item := {"name": "speedboots", "display_name": "Speed Boots", "name_prefix": "Fast", "quality_tier": "high"}
	var display_once: String = overlay._equipment_item_display_name(display_item)
	var display_twice: String = overlay._equipment_item_display_name(display_item)
	_expect(display_once == display_twice, "cached equipment display names should preserve repeated output")
	var quality_once: Color = overlay._get_item_quality_color(display_item, Color.WHITE)
	var quality_twice: Color = overlay._get_item_quality_color(display_item, Color.WHITE)
	_expect(quality_once == quality_twice, "cached item quality colors should preserve repeated output")
	_expect(overlay._get_hovered_linear_slot_index(Vector2(14.0, 12.0), 10.0, 10.0, 12.0, 18.0, 3) == 0, "linear hover index should resolve the first slot")
	_expect(overlay._get_hovered_linear_slot_index(Vector2(25.0, 12.0), 10.0, 10.0, 12.0, 18.0, 3) == -1, "linear hover index should reject slot gaps")
	_expect(overlay._get_hovered_grid_index(Vector2(35.0, 35.0), 10.0, 10.0, 12.0, 18.0, 3, 9) == 4, "grid hover index should resolve row and column")
	_expect(overlay._get_hovered_grid_index(Vector2(71.0, 38.0), 10.0, 10.0, 12.0, 18.0, 3, 5) == -1, "grid hover index should reject out-of-range items")
	_expect(overlay._text_size_cache.size() >= text_cache_size, "character info text cache should remain populated")
	_expect(overlay._wrap_text_cache.size() >= wrap_cache_size, "character info wrap cache should remain populated")

	overlay.prewarm_assets(null, _registry)
	_expect(_registry.icon_renderer.prewarm_count == 1, "character info prewarm should be idempotent for icons")
	_expect(_registry.active_item_visuals.prewarm_count == 1, "character info prewarm should be idempotent for active item visuals")

	_verify_acquired_perk_cache_reuses_catalog_rows()
	_verify_passive_inventory_summary_cache_tracks_equipped_state()
	_verify_active_item_label_cache_reuses_catalog_rows()
	_verify_compact_stats_reuse_frame_sources()
	_verify_stats_do_not_read_dash_token_snapshot()

	print("character_info_overlay_prewarm_smoke: ok")
	quit(0)


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

	var source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd")
	_expect(source.find("parts.sort()") < 0, "acquired perk cache signature should not sort every frame")
	_expect(source.find("var _acquired_perk_cache_hash := 0") >= 0, "acquired perk cache should keep a numeric hash guard")
	_expect(source.find("var _acquired_perk_cache_ready := false") >= 0, "acquired perk cache should guard the initial hash state")
	_expect(source.find("var _acquired_perk_signature_parts: Array[String] = []") < 0, "acquired perk cache should not keep string signature parts")
	_expect(source.find("var _perk_level_text_size_cache_values: Array[Vector2] = []") >= 0, "perk grid level text should keep a typed size cache")
	_expect(source.find("var effective_levels: Dictionary = _get_effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)") >= 0, "acquired perk cache should compute snapshot effective levels once")
	_expect(_function_body(source, "func _get_acquired_perk_cache_hash(").find("has_snapshot_effective_levels") >= 0, "acquired perk cache hash should only use the fast snapshot hash when effective levels are present")
	_expect(_function_body(source, "func _get_acquired_perk_cache_hash(").find("return hash([catalog_id, hash(levels), hash(effective_levels), equipped_skills_hash])") >= 0, "snapshot-backed acquired perk cache should use compact dictionary hashes")
	_expect(_function_body(source, "func _get_acquired_perk_cache_hash(").find("for skill_id_value in levels") < 0, "snapshot-backed acquired perk cache hash should not iterate every perk level")
	_expect(_function_body(source, "func _get_acquired_perk_runtime_cache_hash(").find("var result: int = hash(catalog_id)") >= 0, "direct acquired perk runtime cache should accumulate a numeric hash")
	_expect(_function_body(source, "func _get_acquired_perk_runtime_cache_hash(").find("for skill_id_value in levels.keys():") < 0, "direct acquired perk runtime cache should not allocate dictionary key arrays")
	_expect(_function_body(source, "func _get_acquired_perk_runtime_cache_hash(").find("for skill_id_value in levels:") >= 0, "direct acquired perk runtime cache should iterate levels directly")
	_expect(_function_body(source, "func _get_acquired_perk_runtime_cache_hash(").find("result = hash([result, skill_id, base_level, effective_level])") >= 0, "direct acquired perk runtime cache should avoid joined string signatures")
	_expect(_function_body(source, "func _build_acquired_perks(").find("for skill_id_value in levels.keys():") < 0, "acquired perk cache rebuild should not allocate dictionary key arrays")
	_expect(source.find("data[\"_level_text\"] = _perk_level_text(data)") >= 0, "acquired perk cache should precompute perk level text")
	_expect(source.find("data[\"_level_color\"] = _perk_level_color(data)") >= 0, "acquired perk cache should precompute perk level color")
	_expect(source.find("var draw_color: Color = _get_color(data.get(\"icon_color\", ACCENT_BLUE))") >= 0, "acquired perk cache should compute perk draw color once")
	_expect(source.find("data[\"_draw_color\"] = draw_color") >= 0, "acquired perk cache should precompute perk draw color")
	_expect(source.find("data[\"_draw_id\"] = skill_id") >= 0, "acquired perk cache should precompute perk draw id")
	_expect(source.find("func _should_hide_equipped_unlock_perk(perk_data: Dictionary, equipped_skill_lookup: Dictionary) -> bool:") >= 0, "acquired perk grid should hide equipped active-skill unlock duplicates")
	_expect(source.find("var _acquired_perk_draw_id_cache: Array[String] = []") >= 0, "acquired perk draw should keep typed id caches")
	_expect(source.find("var _acquired_perk_draw_color_cache: Array[Color] = []") >= 0, "acquired perk draw should keep typed color caches")
	_expect(source.find("var _acquired_perk_hover_title_cache: Array[String] = []") >= 0, "acquired perk draw should keep typed hover title caches")
	_expect(source.find("_acquired_perk_hover_title_cache[i] = _get_string_fallback(perk, \"name\", \"id\")") >= 0, "acquired perk rebuild should cache hover titles")
	_expect(source.find("_acquired_perk_hover_body_cache[i] = _get_string_fallback(perk, \"description\", \"detail\")") >= 0, "acquired perk rebuild should cache hover bodies")
	_expect(source.find("func _refresh_acquired_perk_draw_arrays(acquired: Array) -> void:") >= 0, "acquired perk rebuild should refresh typed draw arrays")
	_expect(source.find("_refresh_acquired_perk_draw_arrays(result)") >= 0, "acquired perk cache rebuild should refresh typed draw arrays after sorting")
	_expect(source.find("var level_text: String = _acquired_perk_level_text_cache[i]") >= 0, "perk grid draw should reuse cached level text")
	_expect(source.find("func _get_perk_level_text_size(font: Font, text: String, size: int) -> Vector2:") >= 0, "perk grid draw should use a dedicated level text size cache")
	_expect(source.find("var _centered_text_size_cache_values: Array[Vector2] = []") >= 0, "centered text draw should keep a typed size cache")
	_expect(source.find("func _get_centered_text_size(font: Font, text: String, size: int) -> Vector2:") >= 0, "centered text draw should use a dedicated size cache")
	_expect(source.find("var _perk_level_text_size_fast_value := Vector2.ZERO") >= 0, "perk grid level text should keep a one-slot size fast cache")
	_expect(source.find("var _centered_text_size_fast_value := Vector2.ZERO") >= 0, "centered text should keep a one-slot size fast cache")
	_expect(_function_body(source, "func _get_perk_level_text_size(").find("return _perk_level_text_size_fast_value") >= 0, "perk grid level text should check the fast size cache before scanning arrays")
	_expect(_function_body(source, "func _get_centered_text_size(").find("return _centered_text_size_fast_value") >= 0, "centered text should check the fast size cache before scanning arrays")
	_expect(source.find("var _text_size_fast_value := Vector2.ZERO") >= 0, "generic text size cache should keep a one-slot fast value")
	_expect(_function_body(source, "func _text_size(").find("if text == _text_size_fast_text and ui_size == _text_size_fast_ui_size:") >= 0, "generic text size cache should check the one-slot fast path before building string keys")
	_expect(_function_body(source, "func _text_size(").find("_text_size_fast_value = measured_size") >= 0, "generic text size cache should update the fast value after measuring")
	_expect(_function_body(source, "func _draw_text_centered(").find("_draw_text_centered_xy(canvas, font, text, center.x, center.y, size, color)") >= 0, "centered text draw should delegate to the scalar center helper")
	_expect(_function_body(source, "func _draw_text_centered_xy(").find("var text_size: Vector2 = _get_centered_text_size(font, visible_text, size)") >= 0, "centered text draw should read cached centered text sizes")
	_expect(_function_body(source, "func _draw_text_centered_xy(").find("var text_size: Vector2 = _text_size(font, text, size)") < 0, "centered text draw should avoid the generic string-key size cache")
	_expect(source.find("func _draw_text_centered_with_size(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color, text_size: Vector2) -> void:") >= 0, "character info centered text should support already-measured text")
	_expect(source.find("func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color) -> void:") >= 0, "character info left-aligned text should support scalar baseline coordinates")
	_expect(_function_body(source, "func _draw_text(").find("_draw_text_xy(canvas, font, text, baseline.x, baseline.y, size, color)") >= 0, "character info legacy text helper should delegate to the scalar baseline helper")
	_expect(source.find("_draw_text(canvas, font,") < 0, "character info draw paths should call the scalar baseline helper directly")
	_expect(source.find("func _draw_text_centered_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color) -> void:") >= 0, "character info centered text should support scalar center coordinates")
	_expect(source.find("func _draw_text_centered_with_size_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, text_size: Vector2) -> void:") >= 0, "character info measured centered text should support scalar center coordinates")
	_expect(_function_body(source, "func _draw_perk_grid(").find("var level_text_size: Vector2 = _get_perk_level_text_size(font, level_text, 9)") >= 0, "perk grid draw should read cached level text sizes")
	_expect(_function_body(source, "func _draw_perk_grid(").find("_draw_text_centered(canvas, font, level_text") < 0, "perk grid draw should not call the generic centered text measurement path for perk levels")
	_expect(_function_body(source, "func _draw_perk_grid(").find("_draw_text_centered_with_size_xy(canvas, font, level_text") >= 0, "perk grid draw should pass scalar center coordinates for level text")
	_expect(source.find("var perk_id: String = _acquired_perk_draw_id_cache[i]") >= 0, "perk grid draw should reuse cached perk id")
	_expect(source.find("var _perk_grid_center_x_cache: Array[float] = []") >= 0, "perk grid draw should cache cell centers for level text")
	_expect(_function_body(source, "func _draw_perk_grid(").find("_draw_text_centered_with_size_xy(canvas, font, level_text, _perk_grid_center_x_cache[i], _perk_grid_level_y_cache[i], 9, level_color, level_text_size)") >= 0, "perk grid draw should reuse cached level text coordinates")
	_expect(_function_body(source, "func _draw_perk_grid(").find("perk.get(\"_draw_color\"") < 0, "perk grid draw should not read cached colors back through perk dictionaries")
	_expect(_function_body(source, "func _draw_perk_grid(").find("perk.get(\"_level_color\"") < 0, "perk grid draw should not read cached level colors back through perk dictionaries")
	_expect(_function_body(source, "func _draw_perk_grid(").find("var perk: Dictionary = acquired[i]") < 0, "perk grid draw should not open acquired perk dictionaries per visible cell")
	_expect(_function_body(source, "func _draw_perk_grid(").find("_get_string_fallback(perk") < 0, "perk grid hover should read cached title and body text")
	_expect(_function_body(source, "func _draw_perk_grid(").find("_acquired_perk_hover_title_cache[i]") >= 0, "perk grid hover should read cached title text")
	_expect(source.find("_last_perk_item_rects") < 0, "perk grid hover should not keep an empty rect-map fallback")
	_expect(_function_body(source, "func _get_hover_signature(").find("_get_rect_map_hover_signature(_last_perk_item_rects") < 0, "perk grid hover signature should not scan an empty rect map")
	_expect(_function_body(source, "func _hover_signature_contains_mouse(").find("_rect_map_key_contains_mouse(_last_perk_item_rects") < 0, "perk grid hover reuse should rely on cached grid geometry")


func _verify_passive_inventory_summary_cache_tracks_equipped_state() -> void:
	var overlay := CharacterInfoOverlay.new()
	var items: Array = [
		{"name": "alpha"},
		{"name": "beta", "equipped": true},
		{"name": "gamma", "_equipped_slot": "head"},
	]
	var first: Dictionary = overlay._get_passive_inventory_summary(items)
	var second: Dictionary = overlay._get_passive_inventory_summary(items)
	_expect(int(first.get("count", 0)) == 3, "passive inventory summary should count inventory items")
	_expect(int(first.get("equipped", 0)) == 2, "passive inventory summary should count equipped items")
	_expect(first == second, "unchanged passive inventory summary should be reusable")

	var alpha: Dictionary = items[0]
	alpha["equipped"] = true
	var third: Dictionary = overlay._get_passive_inventory_summary(items)
	_expect(int(third.get("equipped", 0)) == 3, "passive inventory summary should rebuild when equipped state changes")
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
	var icon_hash_overlay := CharacterInfoOverlay.new()
	var icon_hash_items: Array = [
		{"name": "alpha", "icon_path": "res://alpha.png"},
		{"name": "beta", "icon_sheet_path": "res://beta_sheet.png"},
	]
	var icon_hash_first: int = icon_hash_overlay._get_passive_inventory_icon_hash(icon_hash_items)
	var icon_hash_item: Dictionary = icon_hash_items[0]
	icon_hash_item["_draw_color"] = Color.RED
	var icon_hash_second: int = icon_hash_overlay._get_passive_inventory_icon_hash(icon_hash_items)
	_expect(icon_hash_first == icon_hash_second, "passive inventory icon prewarm hash should ignore draw-cache fields")
	icon_hash_item["icon_path"] = "res://alpha_v2.png"
	var icon_hash_third: int = icon_hash_overlay._get_passive_inventory_icon_hash(icon_hash_items)
	_expect(icon_hash_third != icon_hash_first, "passive inventory icon prewarm hash should change when icon identity changes")
	var source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd")
	_expect(source.find("_passive_inventory_summary_count") >= 0, "passive inventory summary should cache by visible count")
	_expect(source.find("_passive_inventory_summary_equipped") >= 0, "passive inventory summary should cache by equipped count")
	_expect(source.find("\"count_text\": \"보유 0 / 장착 0\"") >= 0, "passive inventory summary should keep reusable header count text")
	_expect(source.find("func _get_passive_inventory_count_text_width(font: Font, count_text: String, size: int) -> float:") >= 0, "passive inventory header count text width should use a cache helper")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("var count_text: String = str(summary.get(\"count_text\", \"\"))") >= 0, "passive inventory draw should read cached count text")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("_text_size(font, count_text, 11)") < 0, "passive inventory draw should not measure count text directly every frame")
	_expect(source.find("_get_passive_inventory_summary_state(inventory_items)") < 0, "passive inventory summary should avoid per-frame string signatures")
	_expect(_function_body(source, "func _set_passive_inventory_summary(").find("% [item_count, equipped_count]") < 0, "passive inventory summary count text should avoid format arrays")
	_expect(source.find("var _passive_inventory_item_cache: Array[Dictionary] = []") >= 0, "passive inventory draw should keep typed item dictionary caches")
	_expect(source.find("var _passive_inventory_draw_cache_items_hash := 0") >= 0, "passive inventory draw cache should keep the item hash as a scalar")
	_expect(source.find("func _passive_inventory_draw_cache_matches(items_hash: int, item_count: int) -> bool:") >= 0, "passive inventory draw cache should compare scalar cache keys")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("var items_hash: int = hash(inventory_items)") >= 0, "passive inventory prep should hash the item array once")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("if _passive_inventory_draw_cache_matches(items_hash, item_count):") >= 0, "passive inventory prep should reuse cached draw metadata when items are unchanged")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("_passive_inventory_draw_cache_items_hash = hash(inventory_items)") >= 0, "passive inventory prep should store the post-prepare item hash")
	_expect(source.find("func _passive_inventory_draw_cache_signature_for_items(") < 0, "passive inventory draw cache should not keep a string-signature helper")
	_expect(source.find("var _passive_inventory_icon_prewarm_items_hash := 0") >= 0, "passive inventory icon prewarm should keep an item hash scalar")
	_expect(source.find("var _passive_inventory_icon_prewarm_item_count := -1") >= 0, "passive inventory icon prewarm should keep an item-count scalar")
	_expect(source.find("func _get_passive_inventory_icon_hash(inventory_items: Array) -> int:") >= 0, "passive inventory icon prewarm should use a compact hash helper")
	_expect(source.find("func _get_passive_inventory_icon_signature(") < 0, "passive inventory icon prewarm should not build joined string signatures")
	_expect(_function_body(source, "func _prewarm_passive_inventory_assets(").find("var items_hash: int = _get_passive_inventory_icon_hash(inventory_items)") >= 0, "passive inventory icon prewarm should hash icon identity once")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("return _passive_inventory_summary") >= 0, "passive inventory prep should return the cached summary on a signature hit")
	_expect(source.find("var _passive_inventory_draw_color_cache: Array[Color] = []") >= 0, "passive inventory draw should keep typed item color caches")
	_expect(source.find("func _ensure_passive_inventory_draw_cache_size(item_count: int) -> void:") >= 0, "passive inventory draw cache should resize typed arrays together")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("_passive_inventory_item_cache[i] = item_data") >= 0, "passive inventory prep should cache item dictionaries by item index")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("_passive_inventory_draw_color_cache[i] = color") >= 0, "passive inventory prep should cache draw colors by item index")
	_expect(_function_body(source, "func _prepare_passive_inventory_draw_cache(").find("_passive_inventory_equipped_cache[i] = equipped") >= 0, "passive inventory prep should cache equipped flags by item index")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("var item_data: Dictionary = _passive_inventory_item_cache[i]") >= 0, "passive inventory draw should read cached item dictionaries")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("var color: Color = _passive_inventory_draw_color_cache[i]") >= 0, "passive inventory draw should read typed draw colors")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("var equipped: bool = _passive_inventory_equipped_cache[i]") >= 0, "passive inventory draw should read typed equipped flags")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("_get_dict(inventory_items[i])") < 0, "passive inventory draw should not normalize visible item dictionaries per cell")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("item_data.get(\"_draw_color\"") < 0, "passive inventory draw should not read cached colors back through item dictionaries")
	_expect(_function_body(source, "func _draw_passive_inventory(").find("item_data.get(\"_draw_active_border_color\"") < 0, "passive inventory draw should not resolve border colors through item dictionaries")
	_expect(source.find("_last_passive_inventory_item_rects") < 0, "passive inventory hover should not keep an empty rect-map fallback")
	_expect(_function_body(source, "func _get_hover_signature(").find("_get_rect_map_hover_signature(_last_passive_inventory_item_rects") < 0, "passive inventory hover signature should not scan an empty rect map")
	_expect(_function_body(source, "func _hover_signature_contains_mouse(").find("_rect_map_key_contains_mouse(_last_passive_inventory_item_rects") < 0, "passive inventory hover reuse should rely on cached grid geometry")
	_expect(_function_body(source, "func _try_handle_passive_inventory_context_click(").find("_find_hovered_rect_key(_last_passive_inventory_item_rects") < 0, "passive inventory context click should rely on cached grid index math")


func _verify_active_item_label_cache_reuses_catalog_rows() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd")
	_expect(source.find("_refresh_active_item_label_cache(slots)") >= 0, "active item draw should refresh cached label rows once")
	_expect(source.find("func _refresh_active_item_label_cache(slots: Array) -> void:") >= 0, "active item label cache helper should remain wired")
	_expect(source.find("func _ensure_active_item_label_cache_size(slot_count: int) -> void:") >= 0, "active item label cache should resize arrays without clearing stable rows")
	_expect(source.find("func _active_item_label_cache_matches(slots: Array) -> bool:") >= 0, "active item label cache should compare slots without string signatures")
	_expect(source.find("_get_active_item_label_signature") < 0, "active item label cache should avoid per-frame joined signatures")
	_expect(source.find("_active_item_label_cache_names: Array[String]") >= 0, "active item label cache should track item names in an indexed array")
	_expect(source.find("_active_item_label_cache_raw_display_names: Array[String]") >= 0, "active item label cache should track raw display names in an indexed array")
	_expect(source.find("_active_item_display_name_cache: Array[String]") >= 0, "active item label cache should store display labels in an indexed array")
	_expect(source.find("_active_item_trimmed_label_cache: Array[String]") >= 0, "active item label cache should store trimmed labels in an indexed array")
	_expect(source.find("_active_item_trimmed_label_cache[i] = _trim_label(display_name, 10)") >= 0, "active item label cache should precompute trimmed labels")
	_expect(_function_body(source, "func _refresh_active_item_label_cache(").find("_active_item_label_cache_matches(slots)") < 0, "active item refresh should not pre-scan slots before updating changed rows")
	_expect(_function_body(source, "func _refresh_active_item_label_cache(").find("continue") >= 0, "active item refresh should skip unchanged cached rows")


func _verify_compact_stats_reuse_frame_sources() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd")
	_expect(
		source.find("var active_item_slot_capacity: int = _get_active_item_slot_capacity_for_sources(runtime_state, mythic_item_runtime)") >= 0,
		"character info active-item panel should reuse active item slot capacity sources"
	)
	_expect(
		source.find("var active_item_hud_visuals: Object = _get_instance(registry, \"active_item_hud_visuals\")") >= 0,
		"character info draw should fetch active item HUD visuals once per frame"
	)
	_expect(
		source.find("var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method(\"get_snapshot\") else {}") >= 0,
		"character info draw should fetch runtime perk snapshot once per frame"
	)
	_expect(
		source.find("if not snapshot.has(\"pending_skill_choices\"):") >= 0,
		"character info header should only read owner pending choices when the snapshot lacks the value"
	)
	_expect(
		source.find("if not snapshot.has(\"gold_from_perks\"):") >= 0,
		"character info header should only read owner perk gold when the snapshot lacks the value"
	)
	_expect(
		source.find("var runtime_perk_icon_renderer: Object = _get_instance(registry, \"runtime_perk_icon_renderer\")") >= 0,
		"character info draw should fetch runtime perk icon renderer once per frame"
	)
	_expect(
		source.find("var runtime_perk_catalog: Object = _get_instance(registry, \"runtime_perk_catalog\")") >= 0,
		"character info draw should fetch runtime perk catalog once per frame"
	)
	_expect(
		source.find("var viewport: Viewport = canvas.get_viewport()") >= 0,
		"character info draw should resolve the viewport once when reading the mouse position"
	)
	_expect(
		_function_body(source, "func draw(").find("var dash_snapshot: Dictionary = _get_smasher_dash_snapshot(registry, character_type)") < 0,
		"character info draw should not fetch dash-token snapshots for the compact stat panel"
	)
	_expect(
		source.find("func _get_smasher_dash_snapshot(registry: Object, character_type: String) -> Dictionary:") >= 0,
		"character info draw should use a gated smasher dash snapshot helper"
	)
	_expect(
		_function_body(source, "func _get_smasher_dash_snapshot(").find("if character_type != \"smasher\":\n\t\treturn {}") >= 0,
		"character info dash snapshot helper should skip non-smasher characters"
	)
	_expect(
		source.find("var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method(\"get_snapshot\") else {}") >= 0,
		"character info draw should fetch skill snapshot once per frame"
	)
	_expect(
		source.find("_draw_header(canvas, owner, panel_rect, font, registry, runtime_state, runtime_snapshot, character_type)") >= 0,
		"character info header should reuse the frame-level runtime perk state, snapshot, and character type"
	)
	_expect(
		source.find("func _get_header_status_width(font: Font, status_text: String, size: int) -> float:") >= 0,
		"character info header should cache the status text width"
	)
	_expect(
		source.find("var _header_subtitle_text := \"\"") >= 0,
		"character info header should cache stable subtitle text"
	)
	_expect(
		source.find("func _get_header_subtitle(display_name: String, character_type: String) -> String:") >= 0,
		"character info header should use a subtitle cache helper"
	)
	_expect(
		source.find("func _get_header_status_text(pending: int, gold: int) -> String:") >= 0,
		"character info header should use a status text cache helper"
	)
	_expect(
		_function_body(source, "func prewarm_assets(").find("_prewarm_draw_caches(font, owner, registry, module_getter)") >= 0,
		"character info prewarm should prepare first-draw caches after layout"
	)
	_expect(
		source.find("func _prewarm_stats_layout(font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:") >= 0,
		"character info prewarm should include a stats layout cache helper"
	)
	_expect(
		_function_body(source, "func _prewarm_stats_layout(").find("_text_size(font, str(row.get(\"value\", \"\")), 13)") >= 0,
		"character info stats prewarm should populate compact stat text caches"
	)
	_expect(
		source.find("func _prewarm_visible_item_icons(owner: Object, registry: Object, module_getter: Callable) -> void:") >= 0,
		"character info prewarm should warm visible equipment and inventory icons"
	)
	_expect(
		_function_body(source, "func _get_header_subtitle(").find("% [display_name") < 0,
		"character info header subtitle should avoid format arrays after cache misses"
	)
	_expect(
		_function_body(source, "func _get_header_status_text(").find("% [pending, gold]") < 0,
		"character info header status should avoid format arrays after cache misses"
	)
	_expect(
		_function_body(source, "func _draw_header(").find("var title_x: float = panel_rect.position.x + 26.0") >= 0,
		"character info header should use scalar title coordinates"
	)
	_expect(
		_function_body(source, "func _draw_header(").find("title_pos") < 0,
		"character info header should avoid a temporary title Vector2"
	)
	_expect(
		_function_body(source, "func _draw_header(").find("var subtitle: String = _get_header_subtitle(display_name, character_type)") >= 0,
		"character info header should read subtitle text from cache"
	)
	_expect(
		_function_body(source, "func _draw_header(").find("var status: String = _get_header_status_text(pending, gold)") >= 0,
		"character info header should read status text from cache"
	)
	_expect(
		_function_body(source, "func _draw_header(").find("var status_width: float = _get_header_status_width(font, status, 14)") >= 0,
		"character info header should read cached status text width"
	)
	_expect(
		_function_body(source, "func _draw_header(").find("_text_size(font, status, 14)") < 0,
		"character info header should not measure status text directly every frame"
	)
	_expect(
		source.find("_update_frame_layout(view_size)") >= 0,
		"character info draw should reuse cached layout rects while the view size is stable"
	)
	_expect(
		source.find("if _layout_panel_rect.size != Vector2.ZERO and _layout_view_size.is_equal_approx(view_size):") >= 0,
		"character info layout cache should be keyed by view size"
	)
	_expect(
		source.find("_layout_equipment_rect = _section_rect(left_rect, 0.0, 0.58)") >= 0,
		"character info layout should keep the equipment panel rect alive beside the lingpet layout"
	)
	_expect(
		source.find("_layout_inventory_rect = Rect2(") >= 0,
		"character info layout should keep the passive inventory panel rect alive"
	)
	_expect(
		source.find("var left_rect := Rect2(") >= 0 and source.find("var right_rect := Rect2(") >= 0,
		"character info layout should build explicit player and lingpet columns"
	)
	_expect(
		source.find("return Rect2(column_rect.position.x, y, column_rect.size.x, max(64.0, height))") >= 0,
		"character info section rects should use scalar Rect2 construction"
	)
	_expect(
		source.find("hover_data = _draw_perk_grid(canvas, owner, registry, _layout_perk_rect, font, mouse_pos, hover_data, runtime_state, runtime_perk_icon_renderer, runtime_snapshot, runtime_perk_catalog, _get_array(skill_snapshot.get(\"equipped_skills\", [])))") >= 0,
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
		source.find("hover_data = _draw_skill_slots(canvas, owner, registry, _layout_skill_rect, font, mouse_pos, hover_data, character_type, skill_snapshot, runtime_perk_icon_renderer)") >= 0,
		"character info skill slots should reuse the frame-level skill snapshot and icon renderer"
	)
	_expect(
		source.find("var hovered_skill_slot := -1") >= 0,
		"character info skill slots should resolve hovered slot once"
	)
	_expect(
		source.find("hovered_skill_slot = _get_hovered_linear_slot_index(mouse_pos, _last_skill_slot_start.x, _last_skill_slot_start.y, _last_skill_slot_size, _last_skill_slot_stride, max_slots)") >= 0,
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
		source.find("var hovered_empty: bool = i == hovered_skill_slot") >= 0,
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
		_function_body(source, "func _update_skill_slot_layout(").find("var slot_x: float = start_x + float(i) * skill_slot_step") >= 0,
		"character info skill slot x should be computed only when the layout changes"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var slot_x: float = start_x + float(i) * skill_slot_step") < 0,
		"character info skill draw loop should not recompute slot x every frame"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var slot_rect: Rect2 = _skill_slot_rect_cache[i]") >= 0,
		"character info skill slots should read cached slot rects in the draw loop"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var slot_rect := Rect2(slot_x, slot_y, slot_size, slot_size)") < 0,
		"character info skill slots should avoid Rect2 construction inside the draw loop"
	)
	_expect(
		source.find("var fallback_skill_color: Color = _skill_fallback_color(character_type)") >= 0,
		"character info skill slots should reuse the character fallback color"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var skill_icon_rect := Rect2(slot_x + 5.0, slot_y + 5.0, slot_size - 10.0, slot_size - 10.0)") < 0,
		"character info skill slots should not rebuild icon rects inside the draw loop"
	)
	_expect(
		source.find("icon_renderer.draw_icon(canvas, skill_id, _skill_slot_icon_rect_cache[i], 1.0, true)") >= 0,
		"character info skill icons should reuse cached icon rects"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var fallback_rect := Rect2(slot_x + 9.0, slot_y + 9.0, slot_size - 18.0, slot_size - 18.0)") < 0,
		"character info skill fallback rects should not be rebuilt inside the draw loop"
	)
	_expect(
		source.find("_draw_fallback_symbol(canvas, _skill_slot_fallback_rect_cache[i], color, skill_id)") >= 0,
		"character info skill fallback symbols should reuse cached fallback rects"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("slot_rect.grow(") < 0,
		"character info skill slots should not allocate grown rects per visible slot"
	)
	_expect(
		source.find("var can_draw_skill_icon: bool = icon_renderer != null and icon_renderer.has_method(\"draw_icon\")") >= 0,
		"character info skill slots should check icon renderer capability once before slot iteration"
	)
	_expect(
		source.find("if not can_draw_skill_icon or not bool(icon_renderer.draw_icon(canvas, skill_id, _skill_slot_icon_rect_cache[i], 1.0, true)):") >= 0,
		"character info skill slot loop should reuse the cached icon renderer capability"
	)
	_expect(
		source.find("var has_skill_slot: bool = i < equipped.size()") >= 0,
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
		source.find("canvas.draw_rect(slot_rect, OVERLAY_SLOT_FILL)") >= 0,
		"character info skill slots should reuse the fixed slot fill constant"
	)
	_expect(
		source.find("canvas.draw_rect(slot_rect, OVERLAY_SLOT_BORDER, false, 1.5)") >= 0,
		"character info skill slots should reuse the fixed slot border constant"
	)
	_expect(
		source.find("OVERLAY_SLOT_FILL.r * 0.88 + color.r * 0.12") >= 0,
		"character info filled skill slot tint should reuse the fixed slot fill constant"
	)
	_expect(
		source.find("canvas.draw_circle(_skill_slot_center_cache[i], slot_size * 0.22, OVERLAY_SKILL_EMPTY_HOVER_FILL)") >= 0,
		"character info empty skill hover detail should reuse cached center and fixed hover color"
	)
	_expect(
		source.find("_draw_text_centered_xy(canvas, font, label, _skill_slot_center_x_cache[i], _skill_slot_label_y, 10, TEXT_DIM)") >= 0,
		"character info skill labels should reuse cached center x and label y"
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
		source.find("OVERLAY_SLOT_FILL.r * 0.88 + color.r * 0.12") >= 0,
		"character info filled skill slot tint should reuse the fixed slot fill constant"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var skill_slot_fill := Color(") < 0,
		"character info skill slot draw loop should not rebuild tinted fill colors"
	)
	_expect(
		source.find("canvas.draw_rect(slot_rect, _skill_slot_fill_color_cache[i])") >= 0,
		"character info filled skill slots should draw cached tinted fills"
	)
	_expect(
		source.find("canvas.draw_rect(slot_rect, _skill_slot_border_color_cache[i], false, 2.0)") >= 0,
		"character info filled skill slots should draw cached border colors"
	)
	_expect(
		source.find("var skill_id: String = _skill_slot_id_cache[i]") >= 0,
		"character info filled skill slots should reuse cached skill ids"
	)
	_expect(
		source.find("var data: Dictionary = _skill_slot_data_cache[i]") >= 0,
		"character info filled skill slots should reuse cached skill data"
	)
	_expect(
		source.find("var color: Color = _skill_slot_color_cache[i]") >= 0,
		"character info filled skill slots should reuse cached skill colors"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("Color(color.r, color.g, color.b, 0.72)") < 0,
		"character info skill slot draw loop should not rebuild border colors"
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
		_function_body(source, "func _refresh_skill_slot_draw_cache(").find("_skill_slot_label_cache[i] = _short_skill_name(data, skill_id)") >= 0,
		"character info skill slot cache should precompute trimmed labels"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("var label: String = _skill_slot_label_cache[i]") >= 0,
		"character info skill slot draw loop should read cached labels"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("_short_skill_name(data, skill_id)") < 0,
		"character info skill slot draw loop should not trim labels per visible slot"
	)
	_expect(
		source.find("func _skill_slot_draw_cache_matches(equipped_hash: int, skill_data_hash: int, fallback_skill_color: Color, equipped_count: int) -> bool:") >= 0,
		"character info skill slot cache should compare scalar cache keys without a string signature"
	)
	_expect(
		_function_body(source, "func _refresh_skill_slot_draw_cache(").find("for value in equipped:") < 0,
		"character info skill slot cache should not build signatures through per-skill string loops"
	)
	_expect(
		_function_body(source, "func _refresh_skill_slot_draw_cache(").find("var equipped_hash: int = hash(equipped)") >= 0,
		"character info skill slot cache should include the equipped skill array hash"
	)
	_expect(
		_function_body(source, "func _refresh_skill_slot_draw_cache(").find("_skill_slot_draw_cache_matches(equipped_hash, skill_data_hash, fallback_skill_color, equipped.size())") >= 0,
		"character info skill slot cache should avoid formatting string signatures on stable frames"
	)
	_expect(
		source.find("func _make_skill_slot_draw_cache_signature(") < 0,
		"character info skill slot cache should not keep a string-signature helper"
	)
	_expect(
		source.find("func _get_hovered_linear_slot_index(") >= 0,
		"character info linear slot hover helper should remain wired"
	)
	_expect(
		source.find("func _format_int_pair(current: int, maximum: int) -> String:") >= 0,
		"character info stat pair labels should use a scalar helper instead of format arrays"
	)
	_expect(
		source.find("hover_data = _draw_active_items(canvas, owner, registry, _layout_active_items_rect, font, mouse_pos, hover_data, active_item_slot_capacity, active_item_hud_visuals, stat_sources, active_item_slots)") >= 0,
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
		source.find("_frame_stat_sources.clear()") >= 0,
		"character info draw should reuse the frame-level stat source array"
	)
	_expect(
		source.find("var stat_sources: Array = _frame_stat_sources") >= 0,
		"character info draw should pass the reused frame-level stat sources"
	)
	_expect(
		source.find("_frame_stat_sources.append(lingpet_runtime)") >= 0,
		"character info draw should include lingpet stat bonuses in the reused frame-level stat sources"
	)
	_expect(
		source.find("var active_item_slots: Array = _get_array(_safe_owner_get(owner, \"active_item_slots\", []))") >= 0,
		"character info draw should fetch active item slots once per frame"
	)
	_expect(
		source.find("hover_data = _draw_active_items(canvas, owner, registry, _layout_active_items_rect, font, mouse_pos, hover_data, active_item_slot_capacity, active_item_hud_visuals, stat_sources, active_item_slots)") >= 0,
		"character info active item draw should reuse the frame-level slot capacity, stat sources, and active slots"
	)
	_expect(
		source.find("var hovered_active_slot := -1") >= 0,
		"character info active item slots should resolve hovered slot once"
	)
	_expect(
		source.find("hovered_active_slot = _get_hovered_linear_slot_index(mouse_pos, _last_active_slot_start.x, _last_active_slot_start.y, _last_active_slot_size, _last_active_slot_stride, max_slots)") >= 0,
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
		source.find("var empty_slot_hovered: bool = i == hovered_active_slot") >= 0,
		"character info empty active item slot marker should reuse the hovered slot"
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
		source.find("func _active_slot_draw_cache_matches(slots_hash: int, max_slots: int, visuals_id: int, should_cache_colors: bool) -> bool:") >= 0,
		"character info active item slot cache should compare scalar cache keys without a string signature"
	)
	_expect(
		_function_body(source, "func _refresh_active_slot_draw_cache(").find("_active_slot_draw_signature_parts.clear()") < 0,
		"character info active item cache should not build signatures through reusable string append loops"
	)
	_expect(
		_function_body(source, "func _refresh_active_slot_draw_cache(").find("var slots_hash: int = hash(slots)") >= 0,
		"character info active item cache should include the active slot array hash"
	)
	_expect(
		_function_body(source, "func _refresh_active_slot_draw_cache(").find("_active_slot_draw_cache_matches(slots_hash, max_slots, visuals_id, should_cache_colors)") >= 0,
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
		_function_body(source, "func _update_active_slot_layout(").find("var slot_x: float = active_slot_start_x + float(i) * active_slot_step") >= 0,
		"character info active item slot x should be computed only when the layout changes"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("var slot_x: float = active_slot_start_x + float(i) * active_slot_step") < 0,
		"character info active item draw loop should not recompute slot x every frame"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("var slot_rect: Rect2 = _active_slot_rect_cache[i]") >= 0,
		"character info active item slots should read cached slot rects in the draw loop"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("var slot_rect := Rect2(slot_x, y, slot_size, slot_size)") < 0,
		"character info active item slots should avoid Rect2 construction inside the draw loop"
	)
	_expect(
		source.find("const OVERLAY_ACTIVE_EMPTY_TEXT := Color(95.0 / 255.0, 100.0 / 255.0, 120.0 / 255.0)") >= 0,
		"character info empty active item marker color should be a shared constant"
	)
	_expect(
		source.find("_draw_text_centered_xy(canvas, font, \"-\", _active_slot_center_x_cache[i], _active_slot_empty_marker_y, 20, OVERLAY_ACTIVE_EMPTY_TEXT)") >= 0,
		"character info active item empty marker should reuse cached center and marker y"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("var fallback_rect := Rect2(slot_x + 10.0, y + 10.0, slot_size - 20.0, slot_size - 20.0)") < 0,
		"character info active item fallback rects should not be rebuilt inside the draw loop"
	)
	_expect(
		source.find("_draw_fallback_symbol(canvas, _active_slot_fallback_rect_cache[i], active_item_color, str(item_data.get(\"name\", \"\")))") >= 0,
		"character info active item fallback symbols should reuse cached fallback rects"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("slot_rect.grow(") < 0,
		"character info active item slots should not allocate grown rects per visible slot"
	)
	_expect(
		source.find("var can_draw_active_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method(\"draw_icon\")") >= 0,
		"character info active item slots should check icon renderer capability once before slot iteration"
	)
	_expect(
		source.find("if can_draw_active_item_icon:") >= 0,
		"character info active item slot loop should reuse the cached icon renderer capability"
	)
	_expect(
		source.find("var has_active_slot: bool = _active_slot_has_item_cache[i]") >= 0,
		"character info active item slots should read cached slot presence in the draw loop"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("slots[i] is Dictionary") < 0,
		"character info active item draw loop should not repeat slot dictionary checks"
	)
	_expect(
		source.find("var item_data: Dictionary = _active_slot_item_cache[i]") >= 0,
		"character info active item slots should read cached item data in the draw loop"
	)
	_expect(
		source.find("var active_item_color: Color = _active_slot_fallback_color_cache[i]") >= 0,
		"character info active item slots should read cached fallback colors in the draw loop"
	)
	_expect(
		source.find("var has_active_item_color: bool = _active_slot_has_fallback_color_cache[i]") >= 0,
		"character info active item hover should know whether fallback color is already cached"
	)
	_expect(
		source.find("var active_item_hovered: bool = i == hovered_active_slot") >= 0,
		"character info active item hover should reuse the hovered slot"
	)
	_expect(
		source.find("var active_slot_center_x: float = slot_x + slot_size * 0.5") < 0,
		"character info active item labels should not recompute slot center x in the draw loop"
	)
	_expect(
		source.find("_draw_text_centered_xy(canvas, font, trimmed_label, _active_slot_center_x_cache[i], _active_slot_label_y, 10, TEXT_DIM)") >= 0,
		"character info active item labels should reuse cached center x and label y"
	)
	_expect(
		source.find("var trimmed_label: String = _active_item_trimmed_label_cache[i]") >= 0,
		"character info active item labels should read precomputed trimmed labels directly by index"
	)
	_expect(
		source.find("var display_name: String = _active_item_display_name_cache[i]") >= 0,
		"character info active item labels should read precomputed display names directly by index"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("i < _active_item_trimmed_label_cache.size()") < 0,
		"character info active item draw should not bounds-check stable label caches per filled slot"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("_trim_label(display_name, 10)") < 0,
		"character info active item draw should not trim labels after the label cache refresh"
	)
	_expect(
		source.find("if not has_active_item_color:") >= 0,
		"character info active item hover should reuse fallback item color when available"
	)
	_expect(
		source.find("hover_data = _draw_passive_inventory(canvas, owner, registry, _layout_inventory_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)") >= 0,
		"character info passive inventory draw should reuse frame-level active item HUD visuals, mythic runtime, and runtime perk state"
	)
	_expect(
		source.find("hover_data = _draw_equipment_slots(canvas, owner, registry, _layout_equipment_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)") >= 0,
		"character info equipment draw should reuse frame-level mythic runtime and runtime perk state for roll tooltips"
	)
	_expect(
		_function_body(source, "func _draw_equipment_slots(").find("var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 34.0, rect.size.x - 24.0, rect.size.y - 42.0)") >= 0,
		"character info equipment draw should build its content rect without temporary Vector2 allocations"
	)
	_expect(
		source.find("hover_data = _draw_stats_panel(canvas, owner, registry, _layout_stats_rect, font, runtime_state, active_item_runtime, mythic_item_runtime, character_type, stat_sources, mouse_pos, hover_data, active_item_slot_capacity, active_item_slots)") >= 0,
		"character info stats draw should reuse frame-level runtime sources, compact stat sources, active-item slots, capacity, and hover state"
	)
	_expect(
		source.find("var stat_sources: Array = stat_sources_override if not stat_sources_override.is_empty() else [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]") >= 0,
		"character info stats builder should reuse frame-level stat sources when provided"
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
		_function_body(source, "func _draw_stat_rows(").find("tooltip_body") >= 0,
		"lingpet stat rows should support focused hover tooltip bodies"
	)
	_expect(
		source.find("공을 적극적으로 막으러 이동할 확률입니다") >= 0,
		"Maribo defense-rate stat should explain its intercept behavior"
	)
	_expect(
		source.find("_stats_row_count = STAT_ROW_COUNT") >= 0,
		"character info stats builder should refresh the reusable stats row count"
	)
	_expect(
		source.find("func _update_stats_layout(rect: Rect2, stats_count: int) -> void:") >= 0,
		"character info stats panel should cache stable row layout geometry"
	)
	_expect(
		source.find("if stats_count == _stats_layout_count and _stats_layout_rect.is_equal_approx(rect):") >= 0,
		"character info stats layout cache should be keyed by stat count and rect"
	)
	_expect(
		source.find("var _stats_layout_label_x: Array[float] = []") >= 0,
		"character info stats layout should cache label x values in a typed array"
	)
	_expect(
		source.find("var _stats_layout_baseline_y: Array[float] = []") >= 0,
		"character info stats layout should cache baseline y values in a typed array"
	)
	_expect(
		source.find("_stats_layout_label_x.append(x)") >= 0,
		"character info stats layout should cache row label x values"
	)
	_expect(
		source.find("_stats_layout_baseline_y.append(y)") >= 0,
		"character info stats layout should cache row baseline y values"
	)
	_expect(
		source.find("_stats_layout_value_right_x.append(x + column_w)") >= 0,
		"character info stats layout should cache value right edges"
	)
	_expect(
		source.find("_ensure_stats_row_cache(STAT_ROW_COUNT)") >= 0,
		"character info stats builder should reuse stat row dictionaries"
	)
	_expect(
		source.find("row.clear()") < 0,
		"character info stats row writers should overwrite cached rows without clearing dictionaries each frame"
	)
	_expect(
		_function_body(source, "func _write_simple_stat_row(").find("if write_row_cache:") >= 0,
		"character info simple stat writer should skip row dictionaries during draw"
	)
	_expect(
		_function_body(source, "func _write_delta_stat_row(").find("if write_row_cache:") >= 0,
		"character info delta stat writer should skip row dictionaries during draw"
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
		source.find("func _get_stats_value_width(font: Font, index: int, value_text: String, size: int) -> float:") >= 0,
		"character info stats draw should use a value width cache helper"
	)
	_expect(
		source.find("var stat: Dictionary = _get_dict(stat_value)") < 0,
		"character info stats draw should not unpack row dictionaries during the draw loop"
	)
	_expect(
		source.find("_draw_text_xy(canvas, font, _stats_label_cache[i], label_x, baseline_y, row_size, TEXT_DIM)") >= 0,
		"character info stats draw should read labels from typed scalar caches"
	)
	_expect(
		source.find("_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color)") >= 0,
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
		source.find("var value_width: float = _get_stats_value_width(font, i, value_text, row_size)") >= 0,
		"character info stats draw should read value widths from cache"
	)
	_expect(
		source.find("var item_cooldown_seconds: float = float(_get_effective_default_active_item_cooldown_msec(registry, stat_sources)) / 1000.0") >= 0,
		"character info stats should compute default active-item cooldown without allocating a temporary item dictionary"
	)
	_expect(
		source.find("{\"cooldown_msec\": ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC}") < 0,
		"character info stats should not allocate a default cooldown dictionary per draw"
	)
	_expect(
		source.find("func _get_effective_active_item_cooldown_from_base(base_cooldown_msec: int, registry: Object, stat_sources: Array = []) -> int:") >= 0,
		"character info active-item cooldown helpers should share the scalar base path"
	)
	_expect(
		source.find("var color: Color = _stat_delta_color(base_value, current_value, higher_is_better)") >= 0,
		"character info stats delta writer should compute color once for row and draw caches"
	)
	_expect(
		source.find("_ensure_stats_row_index(index)") >= 0,
		"character info stats row lookup should avoid shrinking the reusable cache per row"
	)
	_expect(
		source.find("return _stats_row_cache") >= 0,
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
		source.find("var column_stride: float = column_w + column_gap") >= 0,
		"character info stats layout should reuse the column stride while rebuilding row positions"
	)
	_expect(
		source.find("var value_right_x: float = rect.end.x - 2.0") >= 0,
		"character info stats panel should use a stable scalar value-right edge during row draw"
	)
	_expect(
		source.find("_write_simple_stat_row(8, \"액티브 아이템 슬롯\", _format_int_pair(active_item_slot_count, active_item_slot_capacity), active_item_slot_color, write_row_cache)") >= 0,
		"character info stats should show active item slot count and capacity"
	)
	_expect(
		source.find("_passive_item_roll_entries_cache_item_hash") >= 0,
		"character info passive item roll entries should keep a numeric item hash cache guard"
	)
	_expect(
		_function_body(source, "func _build_passive_item_roll_entries(").find("item_hash == _passive_item_roll_entries_cache_item_hash") >= 0,
		"character info passive item roll entries should hit the cache before rebuilding string signatures"
	)
	_expect(
		_function_body(source, "func _build_passive_item_roll_entries(").find("_passive_item_roll_entries_signature(") < 0,
		"character info passive item roll entries should avoid the old roll signature builder on hover draws"
	)
	_expect(
		source.find("_passive_item_roll_entries_cache_signature") < 0,
		"character info passive item roll entries should not keep an unused string cache signature"
	)
	_expect(
		source.find("var fixed_options: Array = _get_array(item_data.get(\"fixed_options\", []))") >= 0,
		"character info passive item roll entries should reuse fixed options"
	)
	_expect(
		source.find("var _empty_tooltip_roll_entries: Array = []") >= 0,
		"character info tooltips should keep a reusable empty roll-entry array"
	)
	_expect(
		source.find("var roll_entries: Array = _get_tooltip_roll_entries(data)") >= 0,
		"character info tooltips should use the tooltip-specific roll-entry fast path"
	)
	_expect(
		_function_body(source, "func _get_tooltip_roll_entries(").find("if data.has(\"roll_options\")") >= 0,
		"character info tooltip roll entries should read roll options only when present"
	)
	_expect(
		_function_body(source, "func _get_tooltip_roll_entries(").find("if data.has(\"options\")") >= 0,
		"character info tooltip roll entries should read fallback options only when present"
	)
	_expect(
		_function_body(source, "func _get_tooltip_roll_entries(").find("return _empty_tooltip_roll_entries") >= 0,
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
		_function_body(source, "func _draw_fallback_symbol(").find("center + Vector2(0.0, 3.0)") < 0,
		"character info fallback symbols should avoid a temporary centered-text offset vector"
	)
	_expect(
		_function_body(source, "func _draw_fallback_symbol(").find("_draw_text_centered_xy(canvas, ThemeDB.fallback_font, letter, center.x, center.y + 3.0") >= 0,
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
		_function_body(source, "func _draw_fallback_symbol(").find("var letter: String = _fallback_symbol_letter(id_text)") >= 0,
		"character info fallback symbol draw should use the cached letter helper"
	)
	_expect(
		_function_body(source, "func _draw_fallback_symbol(").find("substr(0, 1).to_upper()") < 0,
		"character info fallback symbol draw should not rebuild uppercase letters per draw"
	)
	_expect(
		_function_body(source, "func _fallback_symbol_letter(").find("id_text.substr(0, 1).to_upper()") >= 0,
		"character info fallback symbol letter helper should own the uppercase conversion"
	)
	_expect(
		source.find("var rect := Rect2(pos_x, pos_y, width, height)") >= 0,
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
		_function_body(source, "func _draw_tooltip(").find("var text_x: float = pos_x + 14.0") >= 0,
		"character info tooltip text should reuse a scalar baseline x"
	)
	_expect(
		_function_body(source, "func _draw_tooltip(").find("rect.position.x + 14.0") < 0,
		"character info tooltip text should avoid repeated rect position lookups"
	)
	_expect(
		_function_body(source, "func _draw_tooltip(").find("var subtitle_color: Color = _tooltip_subtitle_color(color)") >= 0,
		"character info tooltip subtitle should reuse cached subtitle color"
	)
	_expect(
		_function_body(source, "func _draw_character_card(").find("var bar_rect := Rect2(rect.position.x + 22.0, rect.end.y - 64.0, rect.size.x - 44.0, 12.0)") >= 0,
		"character info character-card meter rect should avoid temporary Vector2 values"
	)
	_expect(
		_function_body(source, "func _draw_character_card(").find("Rect2(center.x - radius * 0.52, center.y - radius * 0.22, radius * 1.04, radius * 0.44)") >= 0,
		"character info character-card body rect should use scalar Rect2 construction"
	)
	_expect(
		_function_body(source, "func _draw_meter(").find("var fill_rect := Rect2(rect.position.x, rect.position.y, rect.size.x * clamp(ratio, 0.0, 1.0), rect.size.y)") >= 0,
		"character info meter fill rect should avoid temporary Vector2 values"
	)
	_expect(
		_function_body(source, "func _draw_meter(").find("_draw_text_xy(canvas, font, label, rect.position.x, rect.position.y - 8.0") >= 0,
		"character info meter labels should draw through the scalar baseline helper"
	)
	_expect(
		source.find("var desc_rect := Rect2(pos_x, pos_y, desc_width, desc_height)") >= 0,
		"character info dual tooltip description rect should avoid temporary Vector2 position/size values"
	)
	_expect(
		source.find("var roll_rect := Rect2(pos_x + desc_width + gap, pos_y, roll_width, roll_height)") >= 0,
		"character info dual tooltip roll rect should avoid temporary position and size Vector2 values"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("var desc_text_x: float = pos_x + 14.0") >= 0,
		"character info dual tooltip description text should reuse a scalar baseline x"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("var roll_text_x: float = pos_x + desc_width + gap + 12.0") >= 0,
		"character info dual tooltip roll text should reuse a scalar baseline x"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("desc_rect.position.x + 14.0") < 0,
		"character info dual tooltip description text should avoid repeated rect position lookups"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("roll_rect.position.x + 12.0") < 0,
		"character info dual tooltip roll text should avoid repeated rect position lookups"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("var subtitle_color: Color = _tooltip_subtitle_color(color)") >= 0,
		"character info dual tooltip subtitle should reuse cached subtitle color"
	)
	_expect(
		_function_body(source, "func _draw_tooltip(").find("Color(color.r, color.g, color.b, 0.95)") < 0,
		"character info tooltip draw should not rebuild subtitle colors directly"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("Color(color.r, color.g, color.b, 0.95)") < 0,
		"character info dual tooltip draw should not rebuild subtitle colors directly"
	)
	_expect(
		source.find("mouse_pos + Vector2(16.0, 14.0)") < 0,
		"character info tooltip placement should avoid a temporary mouse-offset Vector2"
	)
	_expect(
		_function_body(source, "func _get_tooltip_anchor_rect(").find("return Rect2(mouse_pos.x, mouse_pos.y, 0.0, 0.0)") >= 0,
		"character info tooltip fallback anchor should use scalar Rect2 construction"
	)
	_expect(
		_function_body(source, "func _get_tooltip_anchor_rect(").find("Rect2(mouse_pos, Vector2.ZERO)") < 0,
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
		source.find("_get_roll_option_value(option, rolls, key)") >= 0,
		"character info passive item roll entries should avoid eager value/default fallback evaluation"
	)
	_expect(
		source.find("_get_number_fallback(item_data, \"cooldown_msec\", \"cooldown_ms\")") >= 0,
		"character info active item cooldowns should avoid eager cooldown fallback evaluation"
	)
	_expect(
		source.find("func _build_stat_entry(") < 0,
		"character info stats should not keep the old per-row allocation helper"
	)
	_expect(
		source.find("if fixed_options.is_empty() and option_source.is_empty():") >= 0,
		"character info passive item roll entries should skip empty roll tooltips before runtime lookup"
	)
	_expect(
		source.find("var polish_multiplier: float = _get_passive_item_roll_polish_multiplier(registry, runtime_state)") >= 0,
		"character info passive item roll entries should use the frame-level runtime state in the numeric cache guard"
	)
	_expect(
		source.find("func _get_passive_item_roll_polish_multiplier(registry: Object, runtime_state_override: Object) -> float:") >= 0,
		"character info passive item roll cache should keep polish multiplier lookup in a helper"
	)
	_expect(
		_function_body(source, "func _get_passive_item_roll_polish_multiplier(").find("if runtime_state == null:\n\t\truntime_state = _get_instance(registry, \"runtime_perk_state\")") >= 0,
		"character info passive item roll cache should only fall back to registry lookup for direct calls"
	)
	_expect(
		source.find("var _tooltip_entry_lines_cache_entries_hash := 0") >= 0,
		"character info tooltip entry lines should keep a numeric entries hash guard"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("var entries_hash: int = hash(entries)") >= 0,
		"character info tooltip entry lines should hash entries before cache lookup"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("entries_hash == _tooltip_entry_lines_cache_entries_hash") >= 0,
		"character info tooltip entry line cache should hit without rebuilding string signatures"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_line_text_cache.size() == _tooltip_entry_lines_cache.size()") >= 0,
		"character info tooltip entry line cache guard should validate text cache size"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_line_color_cache.size() == _tooltip_entry_lines_cache.size()") >= 0,
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
		_function_body(source, "func _build_passive_item_roll_entries(").find("str(fixed_options)") < 0,
		"character info passive roll draw path should not stringify fixed option arrays wholesale"
	)
	_expect(
		_function_body(source, "func _build_passive_item_roll_entries(").find("str(option_source)") < 0,
		"character info passive roll draw path should not stringify roll option arrays wholesale"
	)
	_expect(
		source.find("var _frame_hover_data: Dictionary = {}") >= 0,
		"character info draw should keep a reusable frame hover dictionary"
	)
	_expect(
		source.find("_frame_hover_data.clear()\n\tvar hover_data: Dictionary = _frame_hover_data") >= 0,
		"character info draw should reuse the frame hover dictionary instead of allocating an empty dictionary"
	)
	_expect(
		source.find("func _set_hover_data(") >= 0,
		"character info hover data should use a shared fill helper"
	)
	_expect(
		_function_body(source, "func _set_hover_data(").find("data.clear()") >= 0,
		"character info hover data helper should refill the reusable dictionary"
	)
	_expect(
		source.find("hover_data = {") < 0,
		"character info hover paths should avoid per-hover dictionary literals"
	)
	_expect(
		_function_body(source, "func _draw_equipment_slots(").find("hover_data = _set_hover_data(") >= 0,
		"character info equipped-item hover should reuse the frame hover dictionary"
	)
	_expect(
		_function_body(source, "func _draw_equipment_slots_grid(").find("hover_data = _set_hover_data(") >= 0,
		"character info equipment grid item hover should reuse the frame hover dictionary"
	)
	_expect(
		_function_body(source, "func _draw_passive_inventory(").find("hover_data = _set_hover_data(") >= 0,
		"character info passive inventory hover should reuse the frame hover dictionary"
	)
	_expect(
		_function_body(source, "func _draw_perk_grid(").find("hover_data = _set_hover_data(") >= 0,
		"character info perk hover should reuse the frame hover dictionary"
	)
	_expect(
		_function_body(source, "func _draw_skill_slots(").find("hover_data = _set_hover_data(") >= 0,
		"character info skill hover should reuse the frame hover dictionary"
	)
	_expect(
		_function_body(source, "func _draw_active_items(").find("hover_data = _set_hover_data(") >= 0,
		"character info active item hover should reuse the frame hover dictionary"
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
		_function_body(source, "func _get_hover_signature(").find("_get_lingpet_skill_hover_signature(mouse_pos)") >= 0,
		"lingpet skill icons should participate in mouse-motion hover redraws"
	)
	_expect(
		_function_body(source, "func _get_hover_signature(").find("_get_lingpet_stat_hover_signature(mouse_pos)") >= 0,
		"lingpet stat rows should participate in mouse-motion hover redraws"
	)
	_expect(
		_function_body(source, "func _draw_lingpet_skill_icon(").find("hover_data = _set_hover_data(") >= 0,
		"lingpet skill hover should reuse the frame hover dictionary"
	)
	_expect(
		source.find("return _tooltip_entry_lines_cache.duplicate(true)") < 0,
		"character info tooltip entry cache should avoid per-hover deep copies"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_lines_cache.clear()") >= 0,
		"character info tooltip entry builder should reuse the cached result array"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_line_text_cache.clear()") >= 0,
		"character info tooltip entry builder should clear cached line text before refill"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_line_color_cache.clear()") >= 0,
		"character info tooltip entry builder should clear cached line colors before refill"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("var result: Array = _tooltip_entry_lines_cache") >= 0,
		"character info tooltip entry builder should reuse the cached result array"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("result.append({\"text\"") < 0,
		"character info tooltip entry builder should avoid per-line dictionary literals"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_line_text_cache.append(line_text)") >= 0,
		"character info tooltip entry builder should fill cached line text"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_line_color_cache.append(color)") >= 0,
		"character info tooltip entry builder should fill cached line colors"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("_tooltip_entry_line_text_cache[i]") >= 0,
		"character info roll tooltip draw should read cached line text"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("_tooltip_entry_line_color_cache[i]") >= 0,
		"character info roll tooltip draw should read cached line colors"
	)
	_expect(
		_function_body(source, "func _draw_dual_item_tooltip(").find("var entry_dict: Dictionary = _get_dict(entry)") < 0,
		"character info roll tooltip draw should not unpack line dictionaries"
	)
	_expect(
		source.find("func _get_tooltip_entry_line_dict(index: int) -> Dictionary:") >= 0,
		"character info tooltip entry builder should reuse line dictionaries by index"
	)
	_expect(
		_function_body(source, "func _get_tooltip_entry_line_dict(").find("data.clear()") >= 0,
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
		_function_body(source, "func _build_passive_item_roll_entries(").find("_passive_item_roll_entries_cache.clear()\n\tvar result: Array = _passive_item_roll_entries_cache") >= 0,
		"character info passive roll entry builder should reuse the cached result array"
	)
	_expect(
		_function_body(source, "func _build_passive_item_roll_entries(").find("result.append({") < 0,
		"character info passive roll entry builder should avoid per-entry dictionary literals"
	)
	_expect(
		source.find("func _get_passive_item_roll_entry_dict(index: int) -> Dictionary:") >= 0,
		"character info passive roll entries should reuse dictionaries by index"
	)
	_expect(
		_function_body(source, "func _get_passive_item_roll_entry_dict(").find("data.clear()") >= 0,
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
		_function_body(source, "func _wrap_text_to_width(").find("return _wrap_text_fast_lines") >= 0,
		"character info wrapped text should hit the fast cache before building string keys"
	)
	_expect(
		source.find("func _store_wrapped_text_lines(cache_key: String, text: String, size_key: int, max_width_key: int, max_lines: int, lines: Array) -> Array:") >= 0,
		"character info wrapped text should update dictionary and fast caches through one helper"
	)
	_expect(
		_function_body(source, "func _wrap_text_to_width(").find(".slice(") < 0,
		"character info wrapped text should trim cached lines in-place instead of allocating slices"
	)
	_expect(
		_function_body(source, "func _wrap_text_to_width(").find("while lines.size() > max_lines:") >= 0,
		"character info wrapped text should clamp cached line arrays without slice allocations"
	)
	_expect(
		_function_body(source, "func _build_tooltip_entry_lines(").find("_tooltip_entry_lines_signature(entries, size, max_width, max_lines)") < 0,
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


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


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
