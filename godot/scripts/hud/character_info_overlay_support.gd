extends "res://scripts/hud/character_info_overlay_state.gd"

const CharacterInfoOverlayDragController := preload("res://scripts/hud/character_info_overlay_drag_controller.gd")

func _drag_handle_left_press(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	return CharacterInfoOverlayDragController.handle_left_press(self, mouse_pos, owner, registry)

func _drag_handle_left_release(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	return CharacterInfoOverlayDragController.handle_left_release(self, mouse_pos, owner, registry)

func _drag_handle_motion(mouse_pos: Vector2) -> void:
	CharacterInfoOverlayDragController.handle_motion(self, mouse_pos)

func _drag_cancel() -> void:
	CharacterInfoOverlayDragController.cancel_drag(self)

func _is_discard_confirm_active() -> bool:
	return CharacterInfoOverlayDragController.is_confirm_active(self)

func _handle_discard_confirm_mouse_button(mouse_pos: Vector2, button_index: int, owner: Object, registry: Object) -> bool:
	return CharacterInfoOverlayDragController.handle_confirm_mouse_button(self, mouse_pos, button_index, owner, registry)

func _cancel_discard_confirm() -> void:
	CharacterInfoOverlayDragController.cancel_confirm(self)

func _draw_drag_overlay(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2, font: Font) -> void:
	CharacterInfoOverlayDragController.draw_overlay(self, canvas, owner, registry, view_size, font, _layout_panel_rect)

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

func _build_stats(owner: Object, registry: Object, runtime_state_override: Object = null, active_item_runtime_override: Object = null, mythic_item_runtime_override: Object = null, character_type_override: String = "", stat_sources_override: Array = [], write_row_cache: bool = true, active_item_slot_capacity_override: int = -1, active_item_slots_override: Variant = null, include_breakdown: bool = true) -> Array:
	return CharacterInfoOverlayStatsPresenter.build_overlay_player_stat_rows(self, owner, registry, _character_runtime, runtime_state_override, active_item_runtime_override, mythic_item_runtime_override, character_type_override, stat_sources_override, write_row_cache, active_item_slot_capacity_override, active_item_slots_override, STAT_ROW_COUNT, _stats_row_cache, _stats_label_cache, _stats_value_cache, _stats_color_cache, _stats_value_width_cache, _stats_value_width_text_cache, _stats_value_width_size_cache, _stats_value_width_font_id_cache, SPECIAL_GAUGE_MAX, PLAYER_BASE_PADDLE_WIDTH, BASE_ACTIVE_ITEM_SLOT_COUNT, STAT_BUFF_COLOR, STAT_DEBUFF_COLOR, include_breakdown)

func _draw_tooltip(canvas: CanvasItem, data: Dictionary, mouse_pos: Vector2, view_size: Vector2, font: Font, perk_icon_renderer: Object = null) -> void:
	CharacterInfoOverlayTooltipPresenter.draw_tooltip(canvas, data, mouse_pos, view_size, font, _empty_tooltip_roll_entries, ACCENT_BLUE, TEXT_SOFT, OVERLAY_TOOLTIP_PANEL_FILL, Callable(self, "_draw_text_xy"), Callable(self, "_wrap_text_to_width"), Callable(CharacterInfoOverlayValueUtils, "tooltip_width").bind(Callable(self, "_text_size")), Callable(self, "_draw_dual_item_tooltip"), Callable(self, "_tooltip_subtitle_color"), Callable(self, "_draw_breakdown_icon").bind(perk_icon_renderer))


# 능력치 툴팁 증감 내역 줄 앞의 원인 아이콘. 퍽/신화(gold_digger·bluetooth_ring·
# angel_blessing·celestial_armor·mystic_dice)는 runtime_perk_icon_renderer가
# 커버하고, 나머지 액티브 아이템은 아이템 텍스처로 폴백한다. 카테고리 전용
# 항목(icon_id 없음)은 그리지 않는다.
const _BREAKDOWN_ITEM_ICON_PATHS := {
	"vitamin_pill": "res://assets/sprites/items/vitamin_pill.png",
	"strange_vial": "res://assets/sprites/items/strange_vial.png",
	"long_boost": "res://assets/sprites/items/long_boost_icon.png",
	"dash_boost": "res://assets/sprites/items/dash_boost.png",
	"milk_bottle": "res://assets/sprites/items/milk_bottle_icon_imagegen_v1.png",
}
var _breakdown_item_icon_cache: Dictionary = {}

func _draw_breakdown_icon(canvas: CanvasItem, icon_id: String, rect: Rect2, perk_icon_renderer: Object) -> bool:
	if canvas == null or icon_id == "":
		return false
	if perk_icon_renderer != null and perk_icon_renderer.has_method("has_icon") and bool(perk_icon_renderer.has_icon(icon_id)):
		return bool(perk_icon_renderer.draw_icon(canvas, icon_id, rect, 1.0, true))
	if _BREAKDOWN_ITEM_ICON_PATHS.has(icon_id):
		var texture: Texture2D = _breakdown_item_icon_cache.get(icon_id, null)
		if texture == null:
			texture = ProjectResourceLoader.load_texture(str(_BREAKDOWN_ITEM_ICON_PATHS[icon_id]))
			if texture != null:
				_breakdown_item_icon_cache[icon_id] = texture
		if texture != null:
			canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 1.0))
			return true
	return false

func _draw_dual_item_tooltip(canvas: CanvasItem, data: Dictionary, mouse_pos: Vector2, view_size: Vector2, font: Font, color: Color, title: String, subtitle: String, body: String, roll_entries: Array) -> void:
	CharacterInfoOverlayTooltipPresenter.draw_dual_item_tooltip(canvas, data, mouse_pos, view_size, font, color, title, subtitle, body, roll_entries, TEXT_SOFT, ACCENT_GOLD, OVERLAY_TOOLTIP_PANEL_FILL, OVERLAY_TOOLTIP_ROLL_PANEL_FILL, OVERLAY_TOOLTIP_ROLL_BORDER, Callable(self, "_draw_text_xy"), Callable(self, "_wrap_text_to_width"), Callable(self, "_build_tooltip_entry_lines"), Callable(self, "_tooltip_subtitle_color"), _tooltip_entry_line_text_cache, _tooltip_entry_line_color_cache)

func _tooltip_subtitle_color(color: Color) -> Color:
	return CharacterInfoOverlayValueUtils.cached_alpha_color(self, color, _tooltip_subtitle_color_source, _tooltip_subtitle_color_cache, "_tooltip_subtitle_color_source", "_tooltip_subtitle_color_cache", 0.95)

func _set_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, title_color: Variant = null, anchor_rect: Variant = null, roll_options: Variant = null, right_header: String = "") -> Dictionary:
	return CharacterInfoOverlayValueUtils.set_hover_data(data, title, subtitle, body, color, title_color, anchor_rect, roll_options, right_header)

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

# Normalized (0..1) regions of the hologram texture per equipment slot key.
# Hovering a slot redraws its region over itself — the texture's own alpha
# masks the brightening to the figure, so the body part pops with no box edge.
const EQUIPMENT_HOLOGRAM_REGIONS := {
	"head": Rect2(0.32, 0.06, 0.36, 0.17),
	"top": Rect2(0.26, 0.23, 0.48, 0.22),
	"left_arm": Rect2(0.08, 0.24, 0.28, 0.38),
	"right_arm": Rect2(0.64, 0.24, 0.28, 0.38),
	"belt": Rect2(0.28, 0.43, 0.44, 0.13),
	"belt2": Rect2(0.26, 0.25, 0.48, 0.24),
	"knee": Rect2(0.26, 0.56, 0.48, 0.20),
	"shoes": Rect2(0.26, 0.76, 0.48, 0.15),
}


func _draw_equipment_anatomy_silhouette(canvas: CanvasItem, content_rect: Rect2, slot_size: float, show_detail: bool = false, hovered_slot_index: int = -1) -> void:
	if _human_hologram_texture != null:
		# Slice C: distinct holographic human figure replaces the faint
		# procedural silhouette (which stays as the load-failure fallback).
		var texture_size: Vector2 = _human_hologram_texture.get_size()
		if texture_size.x <= 0.0 or texture_size.y <= 0.0:
			return
		var fit_rect := content_rect.grow(-4.0)
		var fit_scale: float = min(fit_rect.size.x / texture_size.x, fit_rect.size.y / texture_size.y)
		var dest := Rect2(fit_rect.get_center() - texture_size * fit_scale * 0.5, texture_size * fit_scale)
		canvas.draw_texture_rect(_human_hologram_texture, dest, false, Color(1.0, 1.0, 1.0, 0.92))
		_draw_equipment_hologram_part_highlight(canvas, dest, texture_size, hovered_slot_index)
		return
	_update_equipment_silhouette_geometry(content_rect, slot_size)
	CharacterInfoOverlayEquipmentGeometry.draw_silhouette(canvas, slot_size, show_detail, _equipment_silhouette_head_center, _equipment_silhouette_neck_rect, _equipment_silhouette_torso_poly, _equipment_silhouette_body_x, _equipment_silhouette_shoulder_y, _equipment_silhouette_waist_y, _equipment_silhouette_hip_y, _equipment_silhouette_waist_w, _equipment_silhouette_left_arm_poly, _equipment_silhouette_right_arm_poly, _equipment_silhouette_left_leg_poly, _equipment_silhouette_right_leg_poly, EQUIPMENT_SILHOUETTE_HEAD, EQUIPMENT_SILHOUETTE_NECK, EQUIPMENT_SILHOUETTE_BASE, EQUIPMENT_SILHOUETTE_DEEP_DETAIL, EQUIPMENT_SILHOUETTE_BASE_DETAIL, EQUIPMENT_SILHOUETTE_LINE, EQUIPMENT_BODY_RING_SEGMENTS, EQUIPMENT_BODY_ARC_SEGMENTS)

func _draw_equipment_hologram_part_highlight(canvas: CanvasItem, dest: Rect2, texture_size: Vector2, hovered_slot_index: int) -> void:
	if hovered_slot_index < 0 or hovered_slot_index >= _equipment_slot_keys.size():
		return
	var region_value: Variant = EQUIPMENT_HOLOGRAM_REGIONS.get(_equipment_slot_keys[hovered_slot_index])
	if not (region_value is Rect2):
		return
	var region: Rect2 = region_value
	var src := Rect2(region.position * texture_size, region.size * texture_size)
	var dst := Rect2(dest.position + region.position * dest.size, region.size * dest.size)
	canvas.draw_texture_rect_region(_human_hologram_texture, dst, src, Color(1.0, 1.0, 1.0, 0.9))
	canvas.draw_texture_rect_region(_human_hologram_texture, dst, src, Color(0.72, 0.95, 1.0, 0.55))


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

func _prewarm_pendulum_interior(owner: Object, registry: Object) -> void:
	if _pendulum_interior == null or not _pendulum_interior.has_method("prewarm_for_snapshot"):
		return
	var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), LINGPET_HATCH_REQUIRED_HITS)
	if CharacterInfoOverlayPendulumInterior.can_open_snapshot(snapshot):
		_pendulum_interior.prewarm_for_snapshot(snapshot, registry)

func _get_passive_inventory_count_text_width(font: Font, count_text: String, size: int) -> float:
	return CharacterInfoOverlayTextWidthCache.get_overlay_single_width(self, "_passive_inventory_count_text_width_cache", font, count_text, size, Callable(self, "_text_size"), _passive_inventory_count_text_width_cache)

func _refresh_active_item_label_cache(slots: Array) -> void:
	CharacterInfoOverlayValueUtils.refresh_active_item_label_cache(slots, _active_item_catalog, _active_item_label_cache_names, _active_item_label_cache_raw_display_names, _active_item_display_name_cache, _active_item_trimmed_label_cache, Callable(CharacterInfoOverlayFormatter, "trim_label"))

func _build_acquired_perks_cached(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, equipped_skills_for_filter: Array = []) -> Array:
	return CharacterInfoOverlayPerkPresenter.build_overlay_acquired_perks_cached(self, levels, catalog, runtime_state, runtime_snapshot_override, equipped_skills_for_filter, _acquired_perk_cache_hash, _acquired_perk_cache_ready, _acquired_perk_cache, _acquired_perk_draw_id_cache, _acquired_perk_draw_color_cache, _acquired_perk_border_color_cache, _acquired_perk_hover_border_color_cache, _acquired_perk_level_text_cache, _acquired_perk_level_color_cache, _acquired_perk_hover_title_cache, _acquired_perk_hover_body_cache, _acquired_perk_hover_detail_cache, ACCENT_BLUE, ACCENT_GOLD)

# Padded slot-grid display entries (acquired perks + empty hex cells up to the slot
# budget). build_overlay_acquired_perks_cached returns the SAME cached Array instance
# until its hash-keyed rebuild, so instance identity + the slot budget is an exact
# change key -- gating here keeps the per-draw path free of dictionary allocation and
# keeps the typed draw arrays refreshed only when the padded entries actually change.
#
# ⚠️ The run ring-core tier must NOT be injected here. Ring core is slot-FREE in the
# landed contract (`RuntimePerkCatalog.is_slot_consuming_perk` exempts it twice and
# `count_owned_slot_perks` cannot even see it -- the tier lives in LingpetAffinityState,
# not `runtime_skill_levels`), so tier cells appended into this budget list drew past
# the "슬롯 N/M" header the same function reports (6 perks + tier 2 = 8 cells under
# 6/6) and cannibalised empty slots below the limit. The tier already has its own
# dedicated slot + cap tooltip in the 수호령 panel of this same overlay.
func _build_perk_display_entries_cached(acquired: Array, display_slot_count: int) -> Array:
	if is_same(acquired, _perk_display_entries_source) and display_slot_count == _perk_display_entries_slot_count:
		return _perk_display_entries_cache
	_perk_display_entries_source = acquired
	_perk_display_entries_slot_count = display_slot_count
	_perk_display_entries_cache = CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(acquired, display_slot_count)
	CharacterInfoOverlayPerkPresenter.refresh_draw_arrays(_perk_display_entries_cache, _acquired_perk_draw_id_cache, _acquired_perk_draw_color_cache, _acquired_perk_border_color_cache, _acquired_perk_hover_border_color_cache, _acquired_perk_level_text_cache, _acquired_perk_level_color_cache, _acquired_perk_hover_title_cache, _acquired_perk_hover_body_cache, _acquired_perk_hover_detail_cache, ACCENT_BLUE, Callable(CharacterInfoOverlayFormatter, "perk_level_text"), Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(ACCENT_GOLD))
	return _perk_display_entries_cache


func _build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels_override: Dictionary = {}, equipped_skills_for_filter: Array = []) -> Array:
	var result: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels_override, equipped_skills_for_filter, ACCENT_BLUE, ACCENT_GOLD)
	CharacterInfoOverlayPerkPresenter.refresh_draw_arrays(result, _acquired_perk_draw_id_cache, _acquired_perk_draw_color_cache, _acquired_perk_border_color_cache, _acquired_perk_hover_border_color_cache, _acquired_perk_level_text_cache, _acquired_perk_level_color_cache, _acquired_perk_hover_title_cache, _acquired_perk_hover_body_cache, _acquired_perk_hover_detail_cache, ACCENT_BLUE, Callable(CharacterInfoOverlayFormatter, "perk_level_text"), Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(ACCENT_GOLD))
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

func _try_handle_lingpet_slot_tab_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	for raw_entry in _last_lingpet_slot_tab_rects:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var rect_value: Variant = entry.get("rect", Rect2())
		if not (rect_value is Rect2):
			continue
		if not (rect_value as Rect2).has_point(mouse_pos):
			continue
		var runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
		if runtime == null or not runtime.has_method("switch_lingpet_slot"):
			return false
		# switch_lingpet_slot is a no-op (returns false) for an empty slot and a
		# benign re-select for the already-active slot; only a real switch returns
		# true and consumes the click / triggers the panel redraw.
		return bool(runtime.switch_lingpet_slot(int(entry.get("slot_index", -1)), owner, registry))
	return false

func _is_pendulum_interior_active() -> bool:
	return _pendulum_interior != null and _pendulum_interior.has_method("is_active") and bool(_pendulum_interior.is_active())

func _close_pendulum_interior() -> void:
	if _pendulum_interior != null and _pendulum_interior.has_method("reset"):
		_pendulum_interior.reset()
	call("_reset_hover_and_request_redraw", true)

func _try_handle_lingpet_pendulum_open_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	for rect in _last_lingpet_ring_core_rects:
		if not rect.has_point(mouse_pos):
			continue
		var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), LINGPET_HATCH_REQUIRED_HITS)
		if not CharacterInfoOverlayPendulumInterior.can_open_snapshot(snapshot):
			return false
		if _pendulum_interior == null or not _pendulum_interior.has_method("open"):
			return false
		return bool(_pendulum_interior.open(snapshot, owner, registry))
	return false

func _handle_pendulum_mouse_button(mouse_pos: Vector2, button_index: int) -> bool:
	if not _is_pendulum_interior_active():
		return false
	if _pendulum_interior == null or not _pendulum_interior.has_method("handle_mouse_button"):
		return true
	var action: StringName = _pendulum_interior.handle_mouse_button(mouse_pos, button_index)
	if action != &"":
		call("_reset_hover_and_request_redraw", true)
	return true

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
