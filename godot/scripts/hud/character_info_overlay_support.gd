extends "res://scripts/hud/character_info_overlay_state.gd"

func _build_lingpet_stats(owner: Object) -> Array:
	_lingpet_stats_cache = CharacterInfoOverlayLingpetPresenter.build_stats_cached(
		CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), LINGPET_HATCH_REQUIRED_HITS),
		_lingpet_stats_cache,
		ACCENT_GOLD,
		TEXT_SOFT,
		OVERLAY_GRID_EMPTY_TEXT,
		STAT_BUFF_COLOR,
		LINGPET_SPEED_DISPLAY_PX_PER_POINT,
		LINGPET_HATCH_REQUIRED_HITS,
		"링펫 근처로 떨어지는, 플레이어가 막기 어려운 공을 미리 예측해 가드하는 확률입니다. 링펫에서 멀리 떨어진 공은 가드하지 않습니다."
	)
	return CharacterInfoOverlayValueUtils.get_array(_lingpet_stats_cache.get("rows", []))

func _build_stats(owner: Object, registry: Object, runtime_state_override: Object = null, active_item_runtime_override: Object = null, mythic_item_runtime_override: Object = null, character_type_override: String = "", stat_sources_override: Array = [], write_row_cache: bool = true, active_item_slot_capacity_override: int = -1, active_item_slots_override: Variant = null) -> Array:
	return CharacterInfoOverlayStatsPresenter.build_overlay_player_stat_rows(self, owner, registry, _character_runtime, runtime_state_override, active_item_runtime_override, mythic_item_runtime_override, character_type_override, stat_sources_override, write_row_cache, active_item_slot_capacity_override, active_item_slots_override, STAT_ROW_COUNT, _stats_row_cache, _stats_label_cache, _stats_value_cache, _stats_color_cache, _stats_value_width_cache, _stats_value_width_text_cache, _stats_value_width_size_cache, _stats_value_width_font_id_cache, SPECIAL_GAUGE_MAX, PLAYER_BASE_PADDLE_WIDTH, BASE_ACTIVE_ITEM_SLOT_COUNT, STAT_BUFF_COLOR, STAT_DEBUFF_COLOR)

func _draw_tooltip(canvas: CanvasItem, data: Dictionary, mouse_pos: Vector2, view_size: Vector2, font: Font) -> void:
	CharacterInfoOverlayTooltipPresenter.draw_tooltip(canvas, data, mouse_pos, view_size, font, _empty_tooltip_roll_entries, ACCENT_BLUE, TEXT_SOFT, OVERLAY_TOOLTIP_PANEL_FILL, Callable(self, "_draw_text_xy"), Callable(self, "_wrap_text_to_width"), Callable(CharacterInfoOverlayValueUtils, "tooltip_width").bind(Callable(self, "_text_size")), Callable(self, "_draw_dual_item_tooltip"), Callable(self, "_tooltip_subtitle_color"))

func _draw_dual_item_tooltip(canvas: CanvasItem, data: Dictionary, mouse_pos: Vector2, view_size: Vector2, font: Font, color: Color, title: String, subtitle: String, body: String, roll_entries: Array) -> void:
	CharacterInfoOverlayTooltipPresenter.draw_dual_item_tooltip(canvas, data, mouse_pos, view_size, font, color, title, subtitle, body, roll_entries, TEXT_SOFT, ACCENT_GOLD, OVERLAY_TOOLTIP_PANEL_FILL, OVERLAY_TOOLTIP_ROLL_PANEL_FILL, OVERLAY_TOOLTIP_ROLL_BORDER, Callable(self, "_draw_text_xy"), Callable(self, "_wrap_text_to_width"), Callable(self, "_build_tooltip_entry_lines"), Callable(self, "_tooltip_subtitle_color"), _tooltip_entry_line_text_cache, _tooltip_entry_line_color_cache)

func _tooltip_subtitle_color(color: Color) -> Color:
	return CharacterInfoOverlayValueUtils.cached_alpha_color(self, color, _tooltip_subtitle_color_source, _tooltip_subtitle_color_cache, "_tooltip_subtitle_color_source", "_tooltip_subtitle_color_cache", 0.95)

func _set_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, title_color: Variant = null, anchor_rect: Variant = null, roll_options: Variant = null) -> Dictionary:
	return CharacterInfoOverlayValueUtils.set_hover_data(data, title, subtitle, body, color, title_color, anchor_rect, roll_options)

func _build_tooltip_entry_lines(font: Font, entries: Array, size: int, max_width: float, max_lines: int) -> Array:
	return CharacterInfoOverlayValueUtils.build_overlay_tooltip_entry_lines(self, font, entries, size, max_width, max_lines, _tooltip_entry_lines_cache_entries_hash, _tooltip_entry_lines_cache_size, _tooltip_entry_lines_cache_width, _tooltip_entry_lines_cache_max_lines, _tooltip_entry_lines_cache, _tooltip_entry_line_dict_cache, _tooltip_entry_line_text_cache, _tooltip_entry_line_color_cache, Callable(self, "_wrap_text_to_width"), ACCENT_GOLD)

func _update_perk_scrollbar_layout(grid_rect: Rect2, max_scroll: float) -> void:
	CharacterInfoOverlayValueUtils.update_scrollbar_rects(self, "_perk_scrollbar_track_rect", "_perk_scrollbar_thumb_rect", grid_rect, _last_perk_content_height, perk_scroll, max_scroll)

func _update_equipment_slot_layout(content_rect: Rect2, slot_size: float) -> void:
	CharacterInfoOverlayEquipmentGeometry.update_overlay_slot_layout(self, content_rect, slot_size, _equipment_layout_content_rect, _equipment_layout_slot_size, Callable(self, "_ensure_equipment_slot_metadata_cache"), _equipment_slot_keys, _equipment_slot_rect_cache, _equipment_slot_rect_list_cache, _equipment_slot_icon_rect_cache, _equipment_slot_fallback_rect_cache, _equipment_slot_placeholder_rect_cache, _equipment_slot_locked_line_a_start_cache, _equipment_slot_locked_line_a_end_cache, _equipment_slot_locked_line_b_start_cache, _equipment_slot_locked_line_b_end_cache, _equipment_slot_center_x_cache, _equipment_slot_center_y_cache, _equipment_slot_label_y_cache)

func _ensure_equipment_slot_metadata_cache() -> void:
	CharacterInfoOverlayEquipmentDrawer.ensure_slot_metadata_cache(EQUIPMENT_SLOT_DEFINITIONS, _equipment_slot_keys, _equipment_slot_labels, _equipment_slot_compact_labels, _equipment_slot_bases, _equipment_slot_accessory_numbers, _equipment_slot_empty_colors, _equipment_slot_empty_border_colors, _equipment_slot_index_cache, EQUIPMENT_COLOR_HEAD, EQUIPMENT_COLOR_TOP, EQUIPMENT_COLOR_ARM, EQUIPMENT_COLOR_BELT, EQUIPMENT_COLOR_BACK, EQUIPMENT_COLOR_KNEE, EQUIPMENT_COLOR_SHOES, EQUIPMENT_COLOR_ACCESSORY)

func _refresh_equipment_slot_visible_label_cache(use_compact: bool) -> void:
	_ensure_equipment_slot_metadata_cache()
	_equipment_slot_visible_label_cache_compact = CharacterInfoOverlayEquipmentDrawer.refresh_visible_label_cache(_equipment_slot_keys, _equipment_slot_labels, _equipment_slot_compact_labels, _equipment_slot_visible_label_cache, use_compact, _equipment_slot_visible_label_cache_compact)

func _refresh_equipment_slot_frame_cache(slot_state: Dictionary, accessory_slot_count: int) -> void:
	CharacterInfoOverlayEquipmentDrawer.refresh_overlay_slot_frame_cache(self, slot_state, accessory_slot_count, Callable(self, "_ensure_equipment_slot_metadata_cache"), Callable(self, "_ensure_equipment_slot_frame_cache_size"), _equipment_slot_keys, _equipment_slot_accessory_numbers, _empty_equipment_item, _equipment_slot_item_cache, _equipment_slot_has_item_cache, _equipment_slot_enabled_cache, _equipment_slot_label_color_cache, _equipment_slot_base_color_cache, _equipment_slot_border_color_cache, _equipment_slot_fill_color_cache, _equipment_slot_border_width_cache, _equipment_slot_locked_line_color_cache, _equipment_slot_empty_colors, _equipment_slot_empty_border_colors, _equipment_slot_frame_cache_slot_state_hash, _equipment_slot_frame_cache_accessory_slot_count, _equipment_slot_frame_cache_slot_count, TEXT_SOFT, EQUIPMENT_LABEL_DISABLED, EQUIPMENT_COLOR_DISABLED, EQUIPMENT_COLOR_FILLED, EQUIPMENT_SLOT_BORDER_DISABLED, EQUIPMENT_SLOT_BORDER_FILLED, EQUIPMENT_SLOT_FILL_ENABLED, EQUIPMENT_SLOT_FILL_DISABLED)

func _ensure_equipment_slot_frame_cache_size(slot_count: int) -> void:
	CharacterInfoOverlayValueUtils.resize_arrays_if_needed([_equipment_slot_item_cache, _equipment_slot_has_item_cache, _equipment_slot_enabled_cache, _equipment_slot_label_color_cache, _equipment_slot_base_color_cache, _equipment_slot_border_color_cache, _equipment_slot_fill_color_cache, _equipment_slot_border_width_cache, _equipment_slot_locked_line_color_cache], slot_count)

func _update_equipment_silhouette_geometry(content_rect: Rect2, slot_size: float) -> void:
	CharacterInfoOverlayEquipmentGeometry.update_overlay_silhouette(self, content_rect, slot_size, _equipment_silhouette_content_rect, _equipment_silhouette_slot_size, _equipment_silhouette_torso_poly)

func _draw_equipment_anatomy_silhouette(canvas: CanvasItem, content_rect: Rect2, slot_size: float, show_detail: bool = false) -> void:
	_update_equipment_silhouette_geometry(content_rect, slot_size)
	CharacterInfoOverlayEquipmentGeometry.draw_silhouette(canvas, slot_size, show_detail, _equipment_silhouette_head_center, _equipment_silhouette_neck_rect, _equipment_silhouette_torso_poly, _equipment_silhouette_body_x, _equipment_silhouette_shoulder_y, _equipment_silhouette_waist_y, _equipment_silhouette_hip_y, _equipment_silhouette_waist_w, _equipment_silhouette_left_arm_poly, _equipment_silhouette_right_arm_poly, _equipment_silhouette_left_leg_poly, _equipment_silhouette_right_leg_poly, EQUIPMENT_SILHOUETTE_HEAD, EQUIPMENT_SILHOUETTE_NECK, EQUIPMENT_SILHOUETTE_BASE, EQUIPMENT_SILHOUETTE_DEEP_DETAIL, EQUIPMENT_SILHOUETTE_BASE_DETAIL, EQUIPMENT_SILHOUETTE_LINE, EQUIPMENT_BODY_RING_SEGMENTS, EQUIPMENT_BODY_ARC_SEGMENTS)

func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color) -> void:
	if text == "":
		return
	# draw_string과 픽셀 동일한 셰이핑 캐시 경로 (Font 내부 64-LRU 순환 축출 회피).
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(baseline_x, baseline_y), LanguageSettings.translate_text(text), _ui_font_size(size), color)

func _draw_text_centered_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color) -> void:
	if text == "":
		return
	var visible_text := LanguageSettings.translate_text(text)
	var text_size: Vector2 = _get_centered_text_size(font, visible_text, size)
	_draw_text_centered_with_size_xy(canvas, font, visible_text, center_x, center_y, size, color, text_size)

func _draw_text_centered_with_size_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, text_size: Vector2) -> void:
	if text == "":
		return
	var visible_text := LanguageSettings.translate_text(text)
	if visible_text != text:
		text_size = _get_centered_text_size(font, visible_text, size)
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34), visible_text, _ui_font_size(size), color)

func _ui_font_size(size: int) -> int:
	if size < 0 or size >= UI_FONT_SIZE_CACHE_LIMIT:
		return max(1, int(round(float(size) * UI_TEXT_SCALE)))
	while _ui_font_size_cache.size() <= size:
		var source_size: int = _ui_font_size_cache.size()
		_ui_font_size_cache.append(max(1, int(round(float(source_size) * UI_TEXT_SCALE))))
	return _ui_font_size_cache[size]

func _text_size(font: Font, text: String, size: int) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	var ui_size: int = _ui_font_size(size)
	return CharacterInfoOverlayTextWidthCache.get_overlay_text_size(self, font, text, ui_size, _text_size_fast_text, _text_size_fast_ui_size, _text_size_fast_value, _text_size_cache, TEXT_SIZE_CACHE_LIMIT)

func _get_perk_level_text_size(font: Font, text: String, size: int) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	return CharacterInfoOverlayTextWidthCache.get_overlay_indexed_size(self, font, text, size, _perk_level_text_size_fast_text, _perk_level_text_size_fast_size, _perk_level_text_size_fast_font_id, _perk_level_text_size_fast_value, "_perk_level_text_size_fast_text", "_perk_level_text_size_fast_size", "_perk_level_text_size_fast_font_id", "_perk_level_text_size_fast_value", _perk_level_text_size_cache_texts, _perk_level_text_size_cache_sizes, _perk_level_text_size_cache_font_ids, _perk_level_text_size_cache_values, Callable(self, "_text_size"))

func _get_centered_text_size(font: Font, text: String, size: int) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	return CharacterInfoOverlayTextWidthCache.get_overlay_indexed_size(self, font, text, size, _centered_text_size_fast_text, _centered_text_size_fast_size, _centered_text_size_fast_font_id, _centered_text_size_fast_value, "_centered_text_size_fast_text", "_centered_text_size_fast_size", "_centered_text_size_fast_font_id", "_centered_text_size_fast_value", _centered_text_size_cache_texts, _centered_text_size_cache_sizes, _centered_text_size_cache_font_ids, _centered_text_size_cache_values, Callable(self, "_text_size"), CENTERED_TEXT_SIZE_CACHE_LIMIT)

func _prewarm_visible_item_icons(owner: Object, registry: Object, module_getter: Callable) -> void:
	_ensure_equipment_slot_metadata_cache()
	CharacterInfoOverlayPassiveItemPresenter.prewarm_overlay_visible_item_icons(owner, registry, module_getter, _equipment_slot_keys, _empty_equipment_item, _active_item_icon_renderer)

func _prewarm_passive_inventory_assets(owner: Object, registry: Object, module_getter: Callable) -> void:
	CharacterInfoOverlayPassiveItemPresenter.prewarm_overlay_inventory_assets(self, owner, registry, module_getter, _passive_inventory_icon_prewarm_items_hash, _passive_inventory_icon_prewarm_item_count, _active_item_icon_renderer)

func _get_passive_inventory_count_text_width(font: Font, count_text: String, size: int) -> float:
	return CharacterInfoOverlayTextWidthCache.get_overlay_single_width(self, "_passive_inventory_count_text_width_cache", font, count_text, size, Callable(self, "_text_size"), _passive_inventory_count_text_width_cache)

func _refresh_active_item_label_cache(slots: Array) -> void:
	CharacterInfoOverlayValueUtils.refresh_active_item_label_cache(slots, _active_item_catalog, _active_item_label_cache_names, _active_item_label_cache_raw_display_names, _active_item_display_name_cache, _active_item_trimmed_label_cache, Callable(CharacterInfoOverlayFormatter, "trim_label"))

func _build_acquired_perks_cached(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, equipped_skills_for_filter: Array = []) -> Array:
	return CharacterInfoOverlayPerkPresenter.build_overlay_acquired_perks_cached(self, levels, catalog, runtime_state, runtime_snapshot_override, equipped_skills_for_filter, _acquired_perk_cache_hash, _acquired_perk_cache_ready, _acquired_perk_cache, _acquired_perk_draw_id_cache, _acquired_perk_draw_color_cache, _acquired_perk_border_color_cache, _acquired_perk_hover_border_color_cache, _acquired_perk_level_text_cache, _acquired_perk_level_color_cache, _acquired_perk_hover_title_cache, _acquired_perk_hover_body_cache, ACCENT_BLUE, ACCENT_GOLD)

func _build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels_override: Dictionary = {}, equipped_skills_for_filter: Array = []) -> Array:
	var result: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels_override, equipped_skills_for_filter, ACCENT_BLUE, ACCENT_GOLD)
	CharacterInfoOverlayPerkPresenter.refresh_draw_arrays(result, _acquired_perk_draw_id_cache, _acquired_perk_draw_color_cache, _acquired_perk_border_color_cache, _acquired_perk_hover_border_color_cache, _acquired_perk_level_text_cache, _acquired_perk_level_color_cache, _acquired_perk_hover_title_cache, _acquired_perk_hover_body_cache, ACCENT_BLUE, Callable(CharacterInfoOverlayFormatter, "perk_level_text"), Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(ACCENT_GOLD))
	return result

func _wrap_text_to_width(font: Font, text: String, size: int, max_width: float, max_lines: int) -> Array:
	if text == "" or max_lines <= 0:
		return []
	var size_key: int = _ui_font_size(size)
	return CharacterInfoOverlayValueUtils.build_overlay_wrapped_text(self, font, text, size, size_key, max_width, max_lines, _wrap_text_cache, _wrap_text_fast_text, _wrap_text_fast_size, _wrap_text_fast_width, _wrap_text_fast_max_lines, _wrap_text_fast_lines, Callable(self, "_text_size"), WRAP_TEXT_CACHE_LIMIT)

func _try_handle_passive_inventory_context_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	return CharacterInfoOverlayPassiveItemPresenter.try_handle_inventory_context_click(mouse_pos, owner, registry, _last_passive_inventory_grid_rect, _last_passive_grid_start, _last_passive_grid_cell_size, _last_passive_grid_stride, _last_passive_grid_columns, _last_passive_grid_item_count)

func _try_handle_equipment_context_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	return CharacterInfoOverlayEquipmentDrawer.try_handle_context_click(mouse_pos, owner, registry, _last_equipment_rect, Callable(self, "_get_equipment_slot_key_at_mouse"))

func _try_handle_lingpet_unlock_pick_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	for raw_entry in _last_lingpet_unlock_card_rects:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var rect_value: Variant = entry.get("rect", Rect2())
		if not (rect_value is Rect2):
			continue
		var rect: Rect2 = rect_value
		if not rect.has_point(mouse_pos):
			continue
		var runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
		if runtime == null or not runtime.has_method("commit_unlock_pick"):
			return false
		return bool(runtime.commit_unlock_pick(str(entry.get("pet_id", "")), str(entry.get("choice_key", "")), str(entry.get("candidate_id", "")), owner, registry))
	return false

func _prepare_passive_inventory_draw_cache(inventory_items: Array) -> Dictionary:
	return CharacterInfoOverlayPassiveItemPresenter.prepare_overlay_inventory_draw_cache(self, inventory_items, _passive_inventory_draw_cache_items_hash, _passive_inventory_draw_cache_item_count, _passive_inventory_item_cache, _passive_inventory_draw_color_cache, _passive_inventory_border_color_cache, _passive_inventory_active_border_color_cache, _passive_inventory_equipped_cache, _passive_inventory_summary, _passive_inventory_summary_count, _passive_inventory_summary_equipped, Callable(CharacterInfoOverlayPassiveItemPresenter, "cached_frame_color").bind(_passive_item_frame_color_cache, PASSIVE_FRAME_COLOR_CACHE_LIMIT))

func _build_passive_item_body(item_data: Dictionary) -> String:
	return CharacterInfoOverlayPassiveItemPresenter.build_cached_body(self, item_data, _passive_item_body_cache_hash, _passive_item_body_cache_ready, _passive_item_body_cache)

func _build_passive_item_roll_entries(item_data: Dictionary, registry: Object = null, mythic_item_runtime: Object = null, runtime_state: Object = null) -> Array:
	return CharacterInfoOverlayPassiveItemPresenter.build_overlay_roll_entries(self, item_data, registry, mythic_item_runtime, runtime_state, STAT_BUFF_COLOR, ACCENT_GOLD, _passive_item_roll_entries_cache_item_hash, _passive_item_roll_entries_cache_runtime_id, _passive_item_roll_entries_cache_polish_multiplier, _passive_item_roll_entries_cache, _passive_item_roll_entry_dict_cache)

func _update_passive_inventory_scrollbar_layout(grid_rect: Rect2, max_scroll: float) -> void:
	CharacterInfoOverlayValueUtils.update_scrollbar_rects(self, "_passive_scrollbar_track_rect", "_passive_scrollbar_thumb_rect", grid_rect, _last_passive_inventory_content_height, passive_inventory_scroll, max_scroll)

func _equipment_item_display_name(item_data: Dictionary) -> String:
	return CharacterInfoOverlayPassiveItemPresenter.cached_equipment_display_name(self, item_data, _equipment_item_display_name_cache_hash, _equipment_item_display_name_cache_ready, _equipment_item_display_name_cache)

func _get_item_quality_color(item_data: Dictionary, fallback: Color = Color.WHITE) -> Color:
	return CharacterInfoOverlayPassiveItemPresenter.cached_item_quality_color(self, item_data, fallback, _item_quality_color_cache_hash, _item_quality_color_cache_ready, _item_quality_color_cache)
