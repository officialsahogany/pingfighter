extends "res://scripts/hud/character_info_overlay_support.gd"

func is_active() -> bool:
	return active

func open(owner: Object = null, registry: Object = null) -> void:
	var pause_state: Dictionary = CharacterInfoOverlayLifecycle.open(self, owner, registry, _skill_cooldown_pause_active, _skill_cooldown_pause_owner, _skill_cooldown_pause_registry)
	_skill_cooldown_pause_active = bool(pause_state.get("active", false))
	_skill_cooldown_pause_owner = pause_state.get("owner", null)
	_skill_cooldown_pause_registry = pause_state.get("registry", null)

func close(from_input: bool = false) -> void:
	var pause_state: Dictionary = CharacterInfoOverlayLifecycle.close(self, from_input, _skill_cooldown_pause_active, _skill_cooldown_pause_owner, _skill_cooldown_pause_registry)
	_skill_cooldown_pause_active = bool(pause_state.get("active", false))
	_skill_cooldown_pause_owner = pause_state.get("owner", null)
	_skill_cooldown_pause_registry = pause_state.get("registry", null)

func toggle(owner: Object = null, registry: Object = null) -> void:
	if active:
		close()
	else:
		open(owner, registry)

func update(delta: float) -> bool:
	return CharacterInfoOverlayLifecycle.update(self, delta, OPEN_ANIMATION_DURATION)

func consume_input_redraw_request() -> bool:
	return CharacterInfoOverlayValueUtils.consume_overlay_input_redraw(self, _input_redraw_requested, _redraw_requested)

func _request_redraw(from_input: bool = false) -> void:
	CharacterInfoOverlayValueUtils.request_overlay_redraw(self, from_input)

func _reset_hover_and_request_redraw(from_input: bool = false) -> void:
	CharacterInfoOverlayValueUtils.reset_overlay_hover_and_request_redraw(self, from_input)

func _reset_mouse_hover_tracking() -> void:
	CharacterInfoOverlayValueUtils.reset_overlay_hover_tracking(self)

func _should_redraw_for_mouse_motion(mouse_pos: Vector2) -> bool:
	return CharacterInfoOverlayHoverGeometry.should_redraw_for_mouse_motion(self, mouse_pos, _get_hover_signature(mouse_pos), _last_hover_signature, _has_mouse_redraw_position, _last_mouse_redraw_position, MOUSE_MOTION_REDRAW_DISTANCE_SQ)

func _get_hover_signature(mouse_pos: Vector2) -> String:
	return CharacterInfoOverlayHoverGeometry.overlay_hover_signature(mouse_pos, _last_hover_signature, Callable(self, "_hover_signature_contains_mouse"), _last_equipment_rect, Callable(self, "_get_equipment_hover_signature"), _last_skill_rect, _last_skill_slot_start, _last_skill_slot_size, _last_skill_slot_stride, _last_skill_slot_count, _last_active_items_rect, _last_active_slot_start, _last_active_slot_size, _last_active_slot_stride, _last_active_slot_count, _last_passive_inventory_rect, _last_passive_inventory_grid_rect, _last_passive_grid_start, _last_passive_grid_cell_size, _last_passive_grid_stride, _last_passive_grid_columns, _last_passive_grid_item_count, _last_perk_grid_rect, _last_perk_grid_start, _last_perk_grid_cell_size, _last_perk_grid_stride, _last_perk_grid_columns, _last_perk_grid_item_count, _last_lingpet_skill_icon_rects, _last_lingpet_stat_row_rects)

func _hover_signature_contains_mouse(signature: String, mouse_pos: Vector2) -> bool:
	return CharacterInfoOverlayHoverGeometry.overlay_signature_contains_mouse(signature, mouse_pos, _last_passive_inventory_rect, _last_perk_grid_rect, Callable(self, "_equipment_signature_contains_mouse"), _last_skill_slot_start, _last_skill_slot_size, _last_skill_slot_stride, _last_skill_slot_count, _last_active_slot_start, _last_active_slot_size, _last_active_slot_stride, _last_active_slot_count, _last_passive_inventory_grid_rect, _last_passive_grid_start, _last_passive_grid_cell_size, _last_passive_grid_stride, _last_passive_grid_columns, _last_passive_grid_item_count, _last_perk_grid_start, _last_perk_grid_cell_size, _last_perk_grid_stride, _last_perk_grid_columns, _last_perk_grid_item_count, _last_lingpet_skill_icon_rects, _last_lingpet_stat_row_rects)

func _get_equipment_hover_signature(mouse_pos: Vector2) -> String:
	var slot_index: int = _find_hovered_equipment_slot_index(mouse_pos)
	return CharacterInfoOverlayHoverGeometry.equipment_hover_signature(mouse_pos, slot_index, _equipment_slot_keys, _has_indexed_equipment_hover_layout(), _last_equipment_slot_rects)

func _equipment_signature_contains_mouse(key_text: String, mouse_pos: Vector2) -> bool:
	return CharacterInfoOverlayHoverGeometry.equipment_signature_contains_mouse(key_text, mouse_pos, _equipment_slot_index_cache, _equipment_slot_rect_list_cache, _has_indexed_equipment_hover_layout(), _last_equipment_slot_rects)

func _has_indexed_equipment_hover_layout() -> bool:
	return _equipment_hover_uses_indexed_layout and not _equipment_slot_keys.is_empty() and _equipment_slot_rect_list_cache.size() == _equipment_slot_keys.size()

func _set_passive_grid_hover_layout(start: Vector2, cell_size: float, stride: float, columns: int, item_count: int) -> void:
	CharacterInfoOverlayHoverGeometry.set_grid_hover_layout(self, start, cell_size, stride, columns, item_count, "_last_passive_grid_start", "_last_passive_grid_cell_size", "_last_passive_grid_stride", "_last_passive_grid_columns", "_last_passive_grid_item_count")

func _set_perk_grid_hover_layout(start: Vector2, cell_size: float, stride: float, columns: int, item_count: int) -> void:
	CharacterInfoOverlayHoverGeometry.set_grid_hover_layout(self, start, cell_size, stride, columns, item_count, "_last_perk_grid_start", "_last_perk_grid_cell_size", "_last_perk_grid_stride", "_last_perk_grid_columns", "_last_perk_grid_item_count")

func _set_skill_slot_hover_layout(start: Vector2, slot_size: float, stride: float, slot_count: int) -> void:
	CharacterInfoOverlayHoverGeometry.set_linear_hover_layout(self, start, slot_size, stride, slot_count, "_last_skill_slot_start", "_last_skill_slot_size", "_last_skill_slot_stride", "_last_skill_slot_count")

func _update_skill_slot_layout(rect: Rect2, slot_size: float, max_slots: int) -> void:
	CharacterInfoOverlaySkillSlotPresenter.update_overlay_layout(self, rect, slot_size, max_slots, _skill_slot_layout_rect, _skill_slot_layout_count, _skill_slot_layout_slot_size, _skill_slot_rect_cache, _skill_slot_icon_rect_cache, _skill_slot_fallback_rect_cache, _skill_slot_center_cache, _skill_slot_center_x_cache)

func _refresh_skill_slot_draw_cache(equipped: Array, skill_data: Dictionary, fallback_skill_color: Color) -> void:
	CharacterInfoOverlaySkillSlotPresenter.refresh_overlay_draw_cache(self, equipped, skill_data, fallback_skill_color, OVERLAY_SLOT_FILL, _skill_slot_draw_cache_equipped_hash, _skill_slot_draw_cache_skill_data_hash, _skill_slot_draw_cache_fallback_color, _skill_slot_id_cache, _skill_slot_data_cache, _skill_slot_label_cache, _skill_slot_color_cache, _skill_slot_fill_color_cache, _skill_slot_border_color_cache, Callable(CharacterInfoOverlayFormatter, "short_skill_name"))

func _set_active_slot_hover_layout(start: Vector2, slot_size: float, stride: float, slot_count: int) -> void:
	CharacterInfoOverlayHoverGeometry.set_linear_hover_layout(self, start, slot_size, stride, slot_count, "_last_active_slot_start", "_last_active_slot_size", "_last_active_slot_stride", "_last_active_slot_count")

func _update_active_slot_layout(rect: Rect2, slot_size: float, gap: float, max_slots: int) -> void:
	CharacterInfoOverlayActiveItemPresenter.update_overlay_slot_layout(self, rect, slot_size, gap, max_slots, _active_slot_layout_rect, _active_slot_layout_count, _active_slot_layout_slot_size, _active_slot_layout_gap, _active_slot_rect_cache, _active_slot_fallback_rect_cache, _active_slot_center_x_cache)

func _refresh_active_slot_draw_cache(slots: Array, max_slots: int, visuals: Object, should_cache_colors: bool) -> void:
	CharacterInfoOverlayActiveItemPresenter.refresh_overlay_draw_cache(self, slots, max_slots, visuals, should_cache_colors, _active_slot_draw_cache_slots_hash, _active_slot_draw_cache_max_slots, _active_slot_draw_cache_visuals_id, _active_slot_draw_cache_should_cache_colors, _active_slot_has_item_cache, _active_slot_item_cache, _active_slot_fallback_color_cache, _active_slot_has_fallback_color_cache, Callable(CharacterInfoOverlayFormatter, "item_color"))

func _update_passive_inventory_grid_layout(grid_rect: Rect2, cell_size: float, stride: float, columns: int, item_count: int, scroll: float) -> void:
	CharacterInfoOverlayPassiveItemPresenter.update_overlay_grid_layout(self, grid_rect, cell_size, stride, columns, item_count, scroll, _passive_grid_layout_rect, _passive_grid_layout_scroll, _passive_grid_layout_columns, _passive_grid_layout_cell_size, _passive_grid_layout_stride, _passive_grid_layout_item_count, _passive_grid_cell_rect_cache, _passive_grid_icon_rect_cache, _passive_grid_fallback_rect_cache, _passive_grid_badge_rect_cache, _passive_grid_badge_center_x_cache, _passive_grid_badge_center_y_cache, _passive_grid_visible_index_cache)

func _update_perk_grid_layout(grid_rect: Rect2, cell_size: float, stride: float, columns: int, item_count: int, scroll: float) -> void:
	CharacterInfoOverlayPerkPresenter.update_overlay_grid_layout(self, grid_rect, cell_size, stride, columns, item_count, scroll, _perk_grid_layout_rect, _perk_grid_layout_scroll, _perk_grid_layout_columns, _perk_grid_layout_cell_size, _perk_grid_layout_stride, _perk_grid_layout_item_count, _perk_grid_cell_rect_cache, _perk_grid_icon_rect_cache, _perk_grid_center_x_cache, _perk_grid_level_y_cache, _perk_grid_visible_index_cache)

func _find_hovered_equipment_slot_index(mouse_pos: Vector2) -> int:
	return CharacterInfoOverlayHoverGeometry.find_hovered_rect_index(_equipment_slot_rect_list_cache, mouse_pos)

func _get_equipment_slot_key_at_mouse(mouse_pos: Vector2) -> String:
	var slot_index: int = _find_hovered_equipment_slot_index(mouse_pos)
	return CharacterInfoOverlayEquipmentDrawer.slot_key_at_index_or_mouse(mouse_pos, slot_index, _equipment_slot_keys, _has_indexed_equipment_hover_layout(), _last_equipment_slot_rects)

func prewarm_assets(owner: Object = null, registry: Object = null, module_getter: Callable = Callable(), include_shared_icon_assets: bool = true, view_size: Vector2 = Vector2.ZERO) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var resolved_view_size: Vector2 = view_size
	if resolved_view_size.x <= 0.0 or resolved_view_size.y <= 0.0:
		if owner != null and owner.has_method("get_viewport_rect"):
			var rect_value: Variant = owner.get_viewport_rect()
			if rect_value is Rect2:
				var owner_view_rect: Rect2 = rect_value
				if owner_view_rect.size.x > 0.0 and owner_view_rect.size.y > 0.0:
					resolved_view_size = owner_view_rect.size
	CharacterInfoOverlayPrewarmPresenter.prewarm_layout_caches(
		self,
		owner,
		registry,
		module_getter,
		resolved_view_size,
		BASE_ACCESSORY_SLOT_COUNT,
		ACCENT_BLUE,
		BASE_ACTIVE_ITEM_SLOT_COUNT,
		PASSIVE_INVENTORY_COLUMN_TARGET
	)
	CharacterInfoOverlayPrewarmPresenter.prewarm_draw_caches(self, font, owner, registry, module_getter, BASE_ACTIVE_ITEM_SLOT_COUNT)
	CharacterInfoOverlayPrewarmPresenter.prewarm_shared_assets_and_text(self, font, owner, registry, module_getter, include_shared_icon_assets, _lingpet_art_texture_cache, _lingpet_skill_icon_texture_cache, _shared_icon_assets_prewarmed, _static_text_prewarmed, _active_item_text_prewarmed, _runtime_perk_text_prewarmed, _skill_text_prewarmed)

func handle_input(event: InputEvent, owner: Object, registry: Object, _view_size: Vector2) -> bool:
	return CharacterInfoOverlayInputHandler.handle_input(self, event, owner, registry)

func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	_update_frame_layout(view_size)
	CharacterInfoOverlayFramePresenter.draw_frame(self, canvas, owner, registry, view_size, font, _layout_panel_rect, _layout_equipment_rect, _layout_skill_rect, _layout_active_items_rect, _layout_perk_rect, _layout_lingpet_rect, _layout_stats_rect, _layout_inventory_rect, _frame_stat_sources, _frame_hover_data, _header_subtitle_cache, _header_status_text_cache, _header_status_width_cache, _last_lingpet_skill_icon_rects, _lingpet_art_texture_cache, _lingpet_skill_icon_texture_cache, OPEN_ANIMATION_DURATION, PANEL_COLOR, PANEL_BORDER, TEXT_DIM, ACCENT_GOLD, BASE_ACTIVE_ITEM_SLOT_COUNT, LINGPET_HATCH_REQUIRED_HITS, SECTION_COLOR, SECTION_BORDER, OVERLAY_GRID_FILL, STAT_BUFF_COLOR, OVERLAY_GRID_EMPTY_TEXT, ACCENT_BLUE, TEXT_SOFT, OVERLAY_SLOT_FILL, FALLBACK_SYMBOL_RING_SEGMENTS, UI_TEXT_SCALE)

func _update_frame_layout(view_size: Vector2) -> void:
	CharacterInfoOverlayLayout.update_frame_layout(self, view_size, _layout_view_size, _layout_panel_rect)

func _draw_equipment_slots(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, active_item_hud_visuals: Object = null, mythic_item_runtime: Object = null, runtime_state: Object = null) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "장비 슬롯", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	_last_equipment_rect = rect
	var slot_state: Dictionary = CharacterInfoOverlayOwnerState.equipment_state_from_owner(owner)
	var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 34.0, rect.size.x - 24.0, rect.size.y - 42.0)
	var slot_size: float = clamp(min(content_rect.size.x * 0.18, content_rect.size.y * 0.145), 34.0, 55.0)
	_update_equipment_slot_layout(content_rect, slot_size)
	_last_equipment_slot_rects = _equipment_slot_rect_cache
	_equipment_hover_uses_indexed_layout = true
	var visuals: Object = active_item_hud_visuals if active_item_hud_visuals != null else CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_hud_visuals")
	var can_draw_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var mouse_in_equipment_rect: bool = rect.has_point(mouse_pos)
	var accessory_slot_count: int = CharacterInfoOverlayOwnerState.accessory_slot_count_from_owner(owner, BASE_ACCESSORY_SLOT_COUNT)
	var hovered_slot_index := -1
	if mouse_in_equipment_rect:
		hovered_slot_index = _find_hovered_equipment_slot_index(mouse_pos)

	_draw_equipment_anatomy_silhouette(canvas, content_rect, slot_size, hovered_slot_index >= 0)
	_ensure_equipment_slot_metadata_cache()
	var equipment_label_size: int = 10 if slot_size >= 40.0 else 8
	var use_compact_equipment_labels: bool = slot_size < 42.0
	_refresh_equipment_slot_visible_label_cache(use_compact_equipment_labels)
	_refresh_equipment_slot_frame_cache(slot_state, accessory_slot_count)
	hover_data = CharacterInfoOverlayEquipmentDrawer.draw_overlay_slots(
		canvas,
		font,
		hover_data,
		self,
		content_rect,
		equipment_label_size,
		hovered_slot_index,
		_active_item_icon_renderer,
		can_draw_item_icon,
		visuals,
		registry,
		mythic_item_runtime,
		runtime_state,
		_fallback_symbol_letter_cache,
		FALLBACK_SYMBOL_LETTER_CACHE_LIMIT,
		FALLBACK_SYMBOL_RING_SEGMENTS,
		EQUIPMENT_SLOT_BORDER_FILLED,
		EQUIPMENT_EMPTY_RING_SEGMENTS,
		EQUIPMENT_PLACEHOLDER_ARC_SEGMENTS,
		EQUIPMENT_ACCESSORY_RING_SEGMENTS,
		Callable(self, "_draw_text_centered_xy"),
		Callable(self, "_equipment_item_display_name"),
		Callable(self, "_get_item_quality_color"),
		Callable(self, "_build_passive_item_roll_entries"),
		Callable(self, "_set_hover_data")
	)
	return hover_data

func _draw_skill_slots(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, character_type_override: String = "", skill_snapshot_override: Dictionary = {}, icon_renderer_override: Object = null) -> Dictionary:
	_last_skill_rect = rect
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "장착 스킬", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var character_type: String = character_type_override if character_type_override != "" else CharacterInfoOverlayOwnerState.character_type_from_owner(owner, _character_runtime)
	var snapshot: Dictionary = skill_snapshot_override
	if snapshot.is_empty():
		var skill_config: Object = CharacterInfoOverlayOwnerState.skill_config(registry, character_type, _character_runtime)
		snapshot = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var equipped: Array = CharacterInfoOverlayValueUtils.get_array(snapshot.get("equipped_skills", []))
	var max_slots: int = max(1, int(snapshot.get("max_slots", 5)))
	var skill_data: Dictionary = CharacterInfoOverlayValueUtils.get_dict(snapshot.get("skill_data", {}))
	var icon_renderer: Object = icon_renderer_override if icon_renderer_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_icon_renderer")
	var can_draw_skill_icon: bool = icon_renderer != null and icon_renderer.has_method("draw_icon")
	var mouse_in_skill_rect: bool = rect.has_point(mouse_pos)

	var slot_width_limit: float = (rect.size.x - 24.0 - float(max_slots - 1) * 8.0) / float(max_slots)
	var slot_height_limit: float = rect.size.y - 60.0
	var slot_size: float = min(60.0, max(36.0, min(slot_width_limit, slot_height_limit)))
	_update_skill_slot_layout(rect, slot_size, max_slots)
	var fallback_skill_color: Color = CharacterInfoOverlayFormatter.skill_fallback_color(character_type, ACCENT_BLUE)
	_refresh_skill_slot_draw_cache(equipped, skill_data, fallback_skill_color)
	var hovered_skill_slot := -1
	if mouse_in_skill_rect:
		hovered_skill_slot = CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(mouse_pos, _last_skill_slot_start.x, _last_skill_slot_start.y, _last_skill_slot_size, _last_skill_slot_stride, max_slots)
	return CharacterInfoOverlaySkillSlotPresenter.draw_overlay_slots(
		canvas,
		font,
		hover_data,
		self,
		max_slots,
		equipped.size(),
		hovered_skill_slot,
		slot_size,
		icon_renderer,
		can_draw_skill_icon,
		_skill_slot_label_y,
		_fallback_symbol_letter_cache,
		FALLBACK_SYMBOL_LETTER_CACHE_LIMIT,
		FALLBACK_SYMBOL_RING_SEGMENTS,
		OVERLAY_SLOT_FILL,
		OVERLAY_SLOT_BORDER,
		OVERLAY_SKILL_EMPTY_HOVER_FILL,
		TEXT_DIM,
		Callable(self, "_draw_text_centered_xy"),
		Callable(self, "_set_hover_data")
	)

func _draw_active_items(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, max_slots: int = -1, active_item_hud_visuals: Object = null, stat_sources: Array = [], active_slots_override: Variant = null) -> Dictionary:
	_last_active_items_rect = rect
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "액티브 아이템", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var slots: Array = active_slots_override if active_slots_override is Array else CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "active_item_slots", []))
	_refresh_active_item_label_cache(slots)
	var visuals: Object = active_item_hud_visuals if active_item_hud_visuals != null else CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_hud_visuals")
	var can_draw_active_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var mouse_in_active_items_rect: bool = rect.has_point(mouse_pos)
	if max_slots < 1:
		max_slots = CharacterInfoOverlayOwnerState.active_item_slot_capacity_from_registry(registry, BASE_ACTIVE_ITEM_SLOT_COUNT)
	var slot_width_limit: float = (rect.size.x - 34.0) / float(max_slots)
	var slot_height_limit: float = rect.size.y - 64.0
	var min_slot_size: float = 24.0 if max_slots > 5 else 40.0
	var slot_size: float = min(68.0, max(min_slot_size, min(slot_width_limit, slot_height_limit)))
	var gap: float = max(4.0, (rect.size.x - slot_size * float(max_slots)) / float(max_slots + 1))
	_update_active_slot_layout(rect, slot_size, gap, max_slots)
	_refresh_active_slot_draw_cache(slots, max_slots, visuals, not can_draw_active_item_icon)
	var hovered_active_slot := -1
	if mouse_in_active_items_rect:
		hovered_active_slot = CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(mouse_pos, _last_active_slot_start.x, _last_active_slot_start.y, _last_active_slot_size, _last_active_slot_stride, max_slots)
	return CharacterInfoOverlayActiveItemPresenter.draw_overlay_slots(
		canvas,
		font,
		hover_data,
		self,
		max_slots,
		hovered_active_slot,
		_active_item_icon_renderer,
		can_draw_active_item_icon,
		visuals,
		stat_sources,
		registry,
		_active_slot_empty_marker_y,
		_active_slot_label_y,
		_fallback_symbol_letter_cache,
		FALLBACK_SYMBOL_LETTER_CACHE_LIMIT,
		FALLBACK_SYMBOL_RING_SEGMENTS,
		OVERLAY_SLOT_FILL,
		OVERLAY_SLOT_BORDER,
		OVERLAY_ACTIVE_EMPTY_TEXT,
		TEXT_DIM,
		Callable(self, "_draw_text_centered_xy"),
		Callable(self, "_set_hover_data")
	)

func _draw_passive_inventory(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, active_item_hud_visuals: Object = null, mythic_item_runtime: Object = null, runtime_state: Object = null) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_last_passive_inventory_rect = rect

	var inventory_items: Array = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_items(owner, registry, mythic_item_runtime)
	var summary: Dictionary = _prepare_passive_inventory_draw_cache(inventory_items)
	var title := "패시브 보관함"
	var count_text: String = str(summary.get("count_text", ""))
	_draw_text_xy(canvas, font, title, rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)
	var count_width: float = _get_passive_inventory_count_text_width(font, count_text, 11)
	_draw_text_xy(canvas, font, count_text, rect.end.x - count_width - 12.0, rect.position.y + 23.0, 11, TEXT_DIM)

	var grid_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	_last_passive_inventory_grid_rect = grid_rect
	var mouse_in_passive_grid_rect: bool = grid_rect.has_point(mouse_pos)
	canvas.draw_rect(grid_rect, OVERLAY_GRID_FILL)
	if inventory_items.is_empty():
		_set_passive_grid_hover_layout(Vector2.ZERO, 0.0, 0.0, 0, 0)
		_last_passive_inventory_content_height = grid_rect.size.y
		_draw_text_centered_xy(canvas, font, "패시브 아이템 없음", grid_rect.position.x + grid_rect.size.x * 0.5, grid_rect.position.y + grid_rect.size.y * 0.5 + 4.0, 13, OVERLAY_GRID_EMPTY_TEXT)
		return hover_data

	var gap := 8.0
	var columns: int = max(4, int(floor((grid_rect.size.x + gap) / PASSIVE_INVENTORY_COLUMN_TARGET)))
	var cell_size: float = min(50.0, floor((grid_rect.size.x - float(columns - 1) * gap) / float(columns)))
	cell_size = max(36.0, cell_size)
	var rows: int = int(ceil(float(inventory_items.size()) / float(columns)))
	_last_passive_inventory_content_height = float(rows) * (cell_size + gap) - gap
	var max_scroll: float = max(0.0, _last_passive_inventory_content_height - _last_passive_inventory_rect.size.y + 48.0)
	passive_inventory_scroll = clamp(passive_inventory_scroll, 0.0, max_scroll)
	var visuals: Object = active_item_hud_visuals if active_item_hud_visuals != null else CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_hud_visuals")
	var can_draw_passive_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var stride: float = cell_size + gap
	_update_passive_inventory_grid_layout(grid_rect, cell_size, stride, columns, inventory_items.size(), passive_inventory_scroll)
	var hovered_passive_index := -1
	if mouse_in_passive_grid_rect:
		hovered_passive_index = CharacterInfoOverlayHoverGeometry.get_hovered_grid_index(mouse_pos, _last_passive_grid_start.x, _last_passive_grid_start.y, _last_passive_grid_cell_size, _last_passive_grid_stride, columns, inventory_items.size())
	hover_data = CharacterInfoOverlayPassiveInventoryDrawer.draw_overlay_inventory_cells(
		canvas,
		font,
		hover_data,
		self,
		hovered_passive_index,
		_active_item_icon_renderer,
		can_draw_passive_item_icon,
		visuals,
		registry,
		mythic_item_runtime,
		runtime_state,
		_fallback_symbol_letter_cache,
		FALLBACK_SYMBOL_LETTER_CACHE_LIMIT,
		FALLBACK_SYMBOL_RING_SEGMENTS,
		OVERLAY_GRID_CELL_FILL,
		OVERLAY_EQUIPPED_BADGE_FILL,
		Callable(self, "_draw_text_centered_xy"),
		Callable(self, "_equipment_item_display_name"),
		Callable(self, "_build_passive_item_body"),
		Callable(self, "_get_item_quality_color"),
		Callable(self, "_build_passive_item_roll_entries"),
		Callable(self, "_set_hover_data")
	)
	if max_scroll > 0.0:
		_update_passive_inventory_scrollbar_layout(grid_rect, max_scroll)
		CharacterInfoOverlayTextureDrawer.draw_scrollbar(canvas, _passive_scrollbar_track_rect, _passive_scrollbar_thumb_rect, OVERLAY_SCROLLBAR_TRACK, OVERLAY_PASSIVE_SCROLLBAR_THUMB)
	return hover_data

func _draw_perk_grid(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, runtime_state: Object = null, icon_renderer_override: Object = null, runtime_snapshot_override: Variant = null, catalog_override: Object = null, equipped_skills_for_filter: Array = []) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "퍽", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var effective_runtime_state: Object = runtime_state if runtime_state != null else CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_state")
	var catalog: Object = catalog_override
	if catalog == null:
		catalog = CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_catalog")
	var icon_renderer: Object = icon_renderer_override if icon_renderer_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_icon_renderer")
	var can_draw_perk_icon: bool = icon_renderer != null and icon_renderer.has_method("draw_icon")
	var snapshot: Dictionary = runtime_snapshot_override if runtime_snapshot_override is Dictionary else {}
	if not (runtime_snapshot_override is Dictionary) and effective_runtime_state != null and effective_runtime_state.has_method("get_snapshot"):
		snapshot = effective_runtime_state.get_snapshot()
	var levels: Dictionary = CharacterInfoOverlayValueUtils.get_dict(snapshot.get("runtime_skill_levels", {}))
	if levels.is_empty() and not snapshot.has("runtime_skill_levels"):
		levels = CharacterInfoOverlayValueUtils.get_dict(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_perk_levels", {}))
	var acquired: Array = _build_acquired_perks_cached(levels, catalog, effective_runtime_state, snapshot, equipped_skills_for_filter)

	var grid_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	var mouse_in_perk_grid_rect: bool = grid_rect.has_point(mouse_pos)
	_last_perk_grid_rect = grid_rect
	canvas.draw_rect(grid_rect, OVERLAY_GRID_FILL)
	if acquired.is_empty():
		_set_perk_grid_hover_layout(Vector2.ZERO, 0.0, 0.0, 0, 0)
		_draw_text_centered_xy(canvas, font, LanguageSettings.translate_text("획득한 퍽 없음"), grid_rect.position.x + grid_rect.size.x * 0.5, grid_rect.position.y + grid_rect.size.y * 0.5 + 4.0, 14, OVERLAY_GRID_EMPTY_TEXT)
		_last_perk_content_height = grid_rect.size.y
		return hover_data

	var columns: int = max(3, int(floor((grid_rect.size.x + 8.0) / 58.0)))
	var cell_size: float = min(52.0, floor((grid_rect.size.x - float(columns - 1) * 8.0) / float(columns)))
	var gap := 8.0
	var rows: int = int(ceil(float(acquired.size()) / float(columns)))
	_last_perk_content_height = float(rows) * (cell_size + gap) - gap
	var max_perk_scroll: float = max(0.0, _last_perk_content_height - _last_perk_grid_rect.size.y)
	perk_scroll = clamp(perk_scroll, 0.0, max_perk_scroll)
	var stride: float = cell_size + gap
	_update_perk_grid_layout(grid_rect, cell_size, stride, columns, acquired.size(), perk_scroll)
	var hovered_perk_index := -1
	if mouse_in_perk_grid_rect:
		hovered_perk_index = CharacterInfoOverlayHoverGeometry.get_hovered_grid_index(mouse_pos, _last_perk_grid_start.x, _last_perk_grid_start.y, _last_perk_grid_cell_size, _last_perk_grid_stride, columns, acquired.size())
	hover_data = CharacterInfoOverlayPerkPresenter.draw_overlay_grid_cells(
		canvas,
		font,
		hover_data,
		self,
		hovered_perk_index,
		icon_renderer,
		can_draw_perk_icon,
		_fallback_symbol_letter_cache,
		FALLBACK_SYMBOL_LETTER_CACHE_LIMIT,
		FALLBACK_SYMBOL_RING_SEGMENTS,
		OVERLAY_GRID_CELL_FILL,
		Callable(self, "_get_perk_level_text_size"),
		Callable(self, "_draw_text_centered_with_size_xy"),
		Callable(self, "_draw_text_centered_xy"),
		Callable(self, "_set_hover_data")
	)
	if max_perk_scroll > 0.0:
		_update_perk_scrollbar_layout(grid_rect, max_perk_scroll)
		CharacterInfoOverlayTextureDrawer.draw_scrollbar(canvas, _perk_scrollbar_track_rect, _perk_scrollbar_thumb_rect, OVERLAY_SCROLLBAR_TRACK, OVERLAY_PERK_SCROLLBAR_THUMB)
	return hover_data

func _draw_stats_panel(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, runtime_state_override: Object = null, active_item_runtime_override: Object = null, mythic_item_runtime_override: Object = null, character_type_override: String = "", stat_sources_override: Array = [], mouse_pos: Vector2 = Vector2.INF, hover_data: Dictionary = {}, active_item_slot_capacity_override: int = -1, active_item_slots_override: Variant = null) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "능력치", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)
	_build_stats(
		owner,
		registry,
		runtime_state_override,
		active_item_runtime_override,
		mythic_item_runtime_override,
		character_type_override,
		stat_sources_override,
		false,
		active_item_slot_capacity_override,
		active_item_slots_override
	)
	var lingpet_rows: Array = _build_lingpet_stats(owner)
	var row_count: int = _stats_row_count
	return CharacterInfoOverlayStatsPresenter.draw_stat_sections(canvas, font, rect, row_count, _stats_label_cache, _stats_value_cache, _stats_color_cache, _stats_value_width_cache, _stats_value_width_text_cache, _stats_value_width_size_cache, _stats_value_width_font_id_cache, lingpet_rows, mouse_pos, hover_data, _last_lingpet_stat_row_rects, ACCENT_BLUE, TEXT_DIM, OVERLAY_GRID_EMPTY_TEXT, UI_TEXT_SCALE)
