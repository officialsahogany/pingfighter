extends "res://scripts/hud/character_info_overlay_support.gd"

func is_active() -> bool:
	return active

func open(owner: Object = null, registry: Object = null) -> void:
	_ensure_editorial_bg_texture()
	_ensure_empty_hero_textures()
	_ensure_scene_dressing_textures()
	var pause_state: Dictionary = CharacterInfoOverlayLifecycle.open(self, owner, registry, _skill_cooldown_pause_active, _skill_cooldown_pause_owner, _skill_cooldown_pause_registry)
	_skill_cooldown_pause_active = bool(pause_state.get("active", false))
	_skill_cooldown_pause_owner = pause_state.get("owner", null)
	_skill_cooldown_pause_registry = pause_state.get("registry", null)

func close(from_input: bool = false) -> void:
	# Drop any held item / open discard confirm so it cannot leak into the next open.
	_drag_cancel()
	_cancel_discard_confirm()
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
	return CharacterInfoOverlayHoverGeometry.overlay_hover_signature(mouse_pos, _last_hover_signature, Callable(self, "_hover_signature_contains_mouse"), _last_equipment_rect, Callable(self, "_get_equipment_hover_signature"), _last_skill_rect, _last_skill_slot_start, _last_skill_slot_size, _last_skill_slot_stride, _last_skill_slot_count, _last_active_items_rect, _last_active_slot_start, _last_active_slot_size, _last_active_slot_stride, _last_active_slot_count, _last_passive_inventory_rect, _last_passive_inventory_grid_rect, _last_passive_grid_start, _last_passive_grid_cell_size, _last_passive_grid_stride, _last_passive_grid_columns, _last_passive_grid_item_count, _last_perk_grid_rect, _last_perk_grid_start, _last_perk_grid_cell_size, _last_perk_grid_stride, _last_perk_grid_columns, _last_perk_grid_item_count, _last_lingpet_skill_icon_rects, _last_lingpet_ring_core_rects, _last_lingpet_stat_row_rects, _last_skill_slot_height)

func _hover_signature_contains_mouse(signature: String, mouse_pos: Vector2) -> bool:
	return CharacterInfoOverlayHoverGeometry.overlay_signature_contains_mouse(signature, mouse_pos, _last_passive_inventory_rect, _last_perk_grid_rect, Callable(self, "_equipment_signature_contains_mouse"), _last_skill_slot_start, _last_skill_slot_size, _last_skill_slot_stride, _last_skill_slot_count, _last_active_slot_start, _last_active_slot_size, _last_active_slot_stride, _last_active_slot_count, _last_passive_inventory_grid_rect, _last_passive_grid_start, _last_passive_grid_cell_size, _last_passive_grid_stride, _last_passive_grid_columns, _last_passive_grid_item_count, _last_perk_grid_start, _last_perk_grid_cell_size, _last_perk_grid_stride, _last_perk_grid_columns, _last_perk_grid_item_count, _last_lingpet_skill_icon_rects, _last_lingpet_ring_core_rects, _last_lingpet_stat_row_rects, _last_skill_slot_height)

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

func _resolve_prewarm_view_size(owner: Object, view_size: Vector2) -> Vector2:
	var resolved_view_size: Vector2 = view_size
	if resolved_view_size.x > 0.0 and resolved_view_size.y > 0.0:
		return resolved_view_size
	if owner != null and owner.has_method("get_viewport_rect"):
		var rect_value: Variant = owner.get_viewport_rect()
		if rect_value is Rect2:
			var owner_view_rect: Rect2 = rect_value
			if owner_view_rect.size.x > 0.0 and owner_view_rect.size.y > 0.0:
				resolved_view_size = owner_view_rect.size
	return resolved_view_size


func _ensure_editorial_bg_texture() -> void:
	if _editorial_bg_texture != null:
		return
	_editorial_bg_texture = ProjectResourceLoader.load_texture(
		EDITORIAL_BG_PATH,
		"Character info editorial background texture is missing",
		"Character info editorial background texture failed to load"
	)


func _ensure_scene_dressing_textures() -> void:
	if _human_hologram_texture == null:
		_human_hologram_texture = ProjectResourceLoader.load_texture(
			HUMAN_HOLOGRAM_PATH,
			"Character info human hologram texture is missing",
			"Character info human hologram texture failed to load"
		)
	if _empty_slot_socket_texture == null:
		_empty_slot_socket_texture = ProjectResourceLoader.load_texture(
			EMPTY_SLOT_SOCKET_PATH,
			"Character info empty slot socket texture is missing",
			"Character info empty slot socket texture failed to load"
		)
		CharacterInfoOverlayTextureDrawer.set_empty_slot_socket_texture(_empty_slot_socket_texture)
	if _mystic_backdrop_texture == null:
		_mystic_backdrop_texture = ProjectResourceLoader.load_texture(
			MYSTIC_BACKDROP_PATH,
			"Character info mystic backdrop texture is missing",
			"Character info mystic backdrop texture failed to load"
		)
	if _class_emblem_textures.size() < CLASS_EMBLEM_PATHS.size():
		for class_id in CLASS_EMBLEM_PATHS:
			if _class_emblem_textures.get(class_id) is Texture2D:
				continue
			var emblem_texture: Texture2D = ProjectResourceLoader.load_texture(
				str(CLASS_EMBLEM_PATHS[class_id]),
				"Character info class emblem texture is missing",
				"Character info class emblem texture failed to load"
			)
			if emblem_texture != null:
				_class_emblem_textures[class_id] = emblem_texture


func _ensure_empty_hero_textures() -> void:
	if _empty_perk_hero_texture == null:
		_empty_perk_hero_texture = ProjectResourceLoader.load_texture(
			EMPTY_HERO_PERK_CRYSTAL_PATH,
			"Character info empty perk hero texture is missing",
			"Character info empty perk hero texture failed to load"
		)
	if _empty_ringpet_hero_texture == null:
		_empty_ringpet_hero_texture = ProjectResourceLoader.load_texture(
			EMPTY_HERO_RINGPET_EGG_PATH,
			"Character info empty ringpet hero texture is missing",
			"Character info empty ringpet hero texture failed to load"
		)
	if _empty_passive_hero_texture == null:
		_empty_passive_hero_texture = ProjectResourceLoader.load_texture(
			EMPTY_HERO_PASSIVE_CLUSTER_PATH,
			"Character info empty passive hero texture is missing",
			"Character info empty passive hero texture failed to load"
		)


func prewarm_assets(
	owner: Object = null,
	registry: Object = null,
	module_getter: Callable = Callable(),
	include_shared_icon_assets: bool = true,
	view_size: Vector2 = Vector2.ZERO,
	lingpet_prewarm_pet_ids: Variant = null
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	_ensure_editorial_bg_texture()
	_ensure_empty_hero_textures()
	_ensure_scene_dressing_textures()
	var resolved_view_size: Vector2 = _resolve_prewarm_view_size(owner, view_size)
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
	CharacterInfoOverlayPrewarmPresenter.prewarm_shared_assets_and_text(self, font, owner, registry, module_getter, include_shared_icon_assets, _lingpet_art_texture_cache, _lingpet_skill_icon_texture_cache, _shared_icon_assets_prewarmed, _static_text_prewarmed, _active_item_text_prewarmed, _runtime_perk_text_prewarmed, _skill_text_prewarmed, lingpet_prewarm_pet_ids)
	_prewarm_pendulum_interior(owner, registry)
	# 융합 재료쌍 아이콘 스테이지드 프리웜: TAB 오픈 시점(배틀 입력 컨트롤러·
	# 플라자 호스트 공통 경유) 소유 — 퍽 그리드 draw는 조회 전용이라 여기서
	# 합성해 둬야 첫 표시 프레임 히치가 없다.
	var fusion_icon_renderer: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_icon_renderer")
	var fusion_runtime_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_state")
	if fusion_icon_renderer != null and fusion_icon_renderer.has_method("prewarm_fusion_pair_icons_for_state"):
		fusion_icon_renderer.prewarm_fusion_pair_icons_for_state(fusion_runtime_state)

func prewarm_assets_step(
	owner: Object = null,
	registry: Object = null,
	module_getter: Callable = Callable(),
	include_shared_icon_assets: bool = true,
	view_size: Vector2 = Vector2.ZERO,
	lingpet_prewarm_pet_ids: Variant = null,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> bool:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		_prewarm_assets_step_index = 0
		_reset_text_prewarm_step_state()
		return true
	var resolved_view_size: Vector2 = _resolve_prewarm_view_size(owner, view_size)
	var step_start: int = _perf_begin(perf_logger)
	_ensure_editorial_bg_texture()
	_ensure_empty_hero_textures()
	_ensure_scene_dressing_textures()
	_perf_end_with_prefix(perf_logger, perf_label_prefix, "shell_textures", step_start)
	match _prewarm_assets_step_index:
		0:
			step_start = _perf_begin(perf_logger)
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
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "layout", step_start)
		1:
			step_start = _perf_begin(perf_logger)
			CharacterInfoOverlayPrewarmPresenter.prewarm_draw_caches(self, font, owner, registry, module_getter, BASE_ACTIVE_ITEM_SLOT_COUNT)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "draw_caches", step_start)
		2:
			step_start = _perf_begin(perf_logger)
			var art_done: bool = CharacterInfoOverlayLingpetTextureLoader.prewarm_art_assets_step(_lingpet_art_texture_cache, lingpet_prewarm_pet_ids)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "lingpet_art", step_start)
			if not art_done:
				return false
		3:
			step_start = _perf_begin(perf_logger)
			var skill_icons_done: bool = CharacterInfoOverlayLingpetTextureLoader.prewarm_skill_icon_assets_step(_lingpet_skill_icon_texture_cache, lingpet_prewarm_pet_ids)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "lingpet_skill_icons", step_start)
			if not skill_icons_done:
				return false
		4:
			if include_shared_icon_assets and not _shared_icon_assets_prewarmed:
				step_start = _perf_begin(perf_logger)
				var shared_icons_done: bool = CharacterInfoOverlayPrewarmPresenter.prewarm_shared_icon_assets_step(self, registry, module_getter)
				_perf_end_with_prefix(perf_logger, perf_label_prefix, "shared_icons", step_start)
				if not shared_icons_done:
					return false
				_shared_icon_assets_prewarmed = true
		5:
			step_start = _perf_begin(perf_logger)
			_prewarm_visible_item_icons(owner, registry, module_getter)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "visible_item_icons", step_start)
		6:
			step_start = _perf_begin(perf_logger)
			_prewarm_passive_inventory_assets(owner, registry, module_getter)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "passive_inventory_icons", step_start)
		7:
			if _prewarm_text_step_index < CharacterInfoOverlayPrewarmPresenter.TEXT_PREWARM_STEP_COUNT:
				step_start = _perf_begin(perf_logger)
				var text_step_done := CharacterInfoOverlayPrewarmPresenter.prewarm_text_caches_step(
					self,
					font,
					owner,
					registry,
					module_getter,
					_static_text_prewarmed,
					_active_item_text_prewarmed,
					_runtime_perk_text_prewarmed,
					_skill_text_prewarmed,
					_prewarm_text_step_index
				)
				_perf_end_with_prefix(perf_logger, perf_label_prefix, _character_info_text_prewarm_label(_prewarm_text_step_index), step_start)
				if text_step_done:
					_prewarm_text_step_index += 1
				return false
			_prewarm_assets_step_index = 0
			_reset_text_prewarm_step_state()
			return true
		_:
			_prewarm_assets_step_index = 0
			_reset_text_prewarm_step_state()
			return true
	_prewarm_assets_step_index += 1
	return false

func prewarm_lingpet_panel_assets_step(
	lingpet_prewarm_pet_ids: Variant = null,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> bool:
	var step_start: int = 0
	match _lingpet_panel_prewarm_step_index:
		0:
			step_start = _perf_begin(perf_logger)
			var art_done: bool = CharacterInfoOverlayLingpetTextureLoader.prewarm_art_assets_step(_lingpet_art_texture_cache, lingpet_prewarm_pet_ids)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "lingpet_art", step_start)
			if not art_done:
				return false
			_lingpet_panel_prewarm_step_index = 1
			return false
		1:
			step_start = _perf_begin(perf_logger)
			var skill_icons_done: bool = CharacterInfoOverlayLingpetTextureLoader.prewarm_skill_icon_assets_step(_lingpet_skill_icon_texture_cache, lingpet_prewarm_pet_ids)
			_perf_end_with_prefix(perf_logger, perf_label_prefix, "lingpet_skill_icons", step_start)
			if not skill_icons_done:
				return false
			_lingpet_panel_prewarm_step_index = 0
			return true
		_:
			_lingpet_panel_prewarm_step_index = 0
			return true


func _character_info_text_prewarm_label(step_index: int) -> String:
	match step_index:
		0:
			return "text.static"
		1:
			return "text.active_item"
		2:
			return "text.runtime_perk"
		3:
			return "text.skill"
	return "text.%d" % step_index


func _reset_text_prewarm_step_state() -> void:
	_prewarm_text_step_index = 0
	_active_item_text_prewarm_cursor = 0
	_active_item_text_prewarm_entries.clear()
	_runtime_perk_text_prewarm_cursor = 0
	_runtime_perk_text_prewarm_entries.clear()
	_skill_text_prewarm_cursor = 0
	_skill_text_prewarm_entries.clear()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end_with_prefix(perf_logger: Object, label_prefix: String, label_suffix: String, start_usec: int) -> void:
	if label_prefix == "":
		return
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample("%s.%s" % [label_prefix, label_suffix], start_usec)

func handle_input(event: InputEvent, owner: Object, registry: Object, _view_size: Vector2) -> bool:
	return CharacterInfoOverlayInputHandler.handle_input(self, event, owner, registry)

func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	_update_frame_layout(view_size)
	CharacterInfoOverlayFramePresenter.draw_frame(self, canvas, owner, registry, view_size, font, _layout_panel_rect, _layout_equipment_rect, _layout_skill_rect, _layout_active_items_rect, _layout_perk_rect, _layout_lingpet_rect, _layout_stats_rect, _layout_inventory_rect, _frame_stat_sources, _frame_hover_data, _header_subtitle_cache, _header_status_text_cache, _header_status_width_cache, _last_lingpet_skill_icon_rects, _last_lingpet_unlock_card_rects, _last_lingpet_ring_core_rects, _last_lingpet_slot_tab_rects, _lingpet_art_texture_cache, _lingpet_skill_icon_texture_cache, OPEN_ANIMATION_DURATION, PANEL_COLOR, PANEL_BORDER, TEXT_DIM, ACCENT_GOLD, BASE_ACTIVE_ITEM_SLOT_COUNT, LINGPET_HATCH_REQUIRED_HITS, SECTION_COLOR, SECTION_BORDER, OVERLAY_GRID_FILL, STAT_BUFF_COLOR, OVERLAY_GRID_EMPTY_TEXT, ACCENT_BLUE, TEXT_SOFT, OVERLAY_SLOT_FILL, FALLBACK_SYMBOL_RING_SEGMENTS, UI_TEXT_SCALE)
	# Drag preview / trash zone / discard-confirm modal draw on top of the frame.
	_draw_drag_overlay(canvas, owner, registry, view_size, font)

func _update_frame_layout(view_size: Vector2) -> void:
	CharacterInfoOverlayLayout.update_frame_layout(self, view_size, _layout_view_size, _layout_panel_rect)

func _draw_equipment_slots(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, active_item_hud_visuals: Object = null, mythic_item_runtime: Object = null, runtime_state: Object = null) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 13.0, "sword", SECTION_GLYPH_COLOR)
	_draw_text_xy(canvas, font, "장비 슬롯", rect.position.x + 36.0, rect.position.y + 24.0, 13, TEXT_SOFT)

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

	_draw_equipment_anatomy_silhouette(canvas, content_rect, slot_size, hovered_slot_index >= 0, hovered_slot_index)
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
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 12.0, "star", SECTION_GLYPH_COLOR)
	_draw_text_xy(canvas, font, "장착 스킬", rect.position.x + 36.0, rect.position.y + 24.0, 13, TEXT_SOFT)

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

	# Skill cards: slot_size is the orb-well size; the card adds side pads plus the
	# name/badge rows (SKILL_CARD_* in CharacterInfoOverlayLayoutUtils). Keep this
	# formula identical to _prewarm_skills in the prewarm presenter (two-path trap).
	var card_width_limit: float = (rect.size.x - 24.0 - float(max_slots - 1) * 12.0) / float(max_slots)
	var slot_width_limit: float = card_width_limit - 24.0
	var slot_height_limit: float = rect.size.y - 118.0
	var slot_size: float = min(96.0, max(40.0, min(slot_width_limit, slot_height_limit)))
	_update_skill_slot_layout(rect, slot_size, max_slots)
	var fallback_skill_color: Color = CharacterInfoOverlayFormatter.skill_fallback_color(character_type, ACCENT_BLUE)
	_refresh_skill_slot_draw_cache(equipped, skill_data, fallback_skill_color)
	var hovered_skill_slot := -1
	if mouse_in_skill_rect:
		hovered_skill_slot = CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(mouse_pos, _last_skill_slot_start.x, _last_skill_slot_start.y, _last_skill_slot_size, _last_skill_slot_stride, max_slots, _last_skill_slot_height)
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
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 13.0, "flask", SECTION_GLYPH_COLOR)
	_draw_text_xy(canvas, font, "액티브 아이템", rect.position.x + 36.0, rect.position.y + 24.0, 13, TEXT_SOFT)

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


func _draw_empty_state_hero(canvas: CanvasItem, texture: Texture2D, grid_rect: Rect2, y_offset: float, size_scale: float, min_size: float, max_size: float, fallback_radius: float) -> void:
	var hero_size: float = clampf(minf(grid_rect.size.x, grid_rect.size.y) * size_scale, min_size, max_size)
	var center := Vector2(grid_rect.get_center().x, grid_rect.get_center().y + y_offset)
	if texture != null:
		var hero_rect := Rect2(center - Vector2(hero_size, hero_size) * 0.5, Vector2(hero_size, hero_size))
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, hero_rect, Color(1.0, 1.0, 1.0, 0.90))
		return
	CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(canvas, center, fallback_radius, Color(OVERLAY_GRID_EMPTY_TEXT.r, OVERLAY_GRID_EMPTY_TEXT.g, OVERLAY_GRID_EMPTY_TEXT.b, 0.75))


func _draw_passive_inventory(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary, active_item_hud_visuals: Object = null, mythic_item_runtime: Object = null, runtime_state: Object = null) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	_last_passive_inventory_rect = rect

	var inventory_items: Array = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_items(owner, registry, mythic_item_runtime)
	var summary: Dictionary = _prepare_passive_inventory_draw_cache(inventory_items)
	var title := "패시브 보관함"
	var count_text: String = str(summary.get("count_text", ""))
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 12.0, "chest", SECTION_GLYPH_COLOR)
	_draw_text_xy(canvas, font, title, rect.position.x + 36.0, rect.position.y + 24.0, 13, TEXT_SOFT)
	var count_width: float = _get_passive_inventory_count_text_width(font, count_text, 11)
	_draw_text_xy(canvas, font, count_text, rect.end.x - count_width - 12.0, rect.position.y + 23.0, 11, TEXT_DIM)

	var grid_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	_last_passive_inventory_grid_rect = grid_rect
	var mouse_in_passive_grid_rect: bool = grid_rect.has_point(mouse_pos)
	canvas.draw_rect(grid_rect, OVERLAY_GRID_FILL)
	if inventory_items.is_empty():
		_set_passive_grid_hover_layout(Vector2.ZERO, 0.0, 0.0, 0, 0)
		_last_passive_inventory_content_height = grid_rect.size.y
		_draw_empty_state_hero(canvas, _empty_passive_hero_texture, grid_rect, -55.0, 0.72, 76.0, 118.0, 6.0)
		_draw_text_centered_xy(canvas, font, "NO PASSIVE ITEMS OBTAINED", grid_rect.position.x + grid_rect.size.x * 0.5, grid_rect.position.y + grid_rect.size.y * 0.5 - 6.0, 15, Color(ACCENT_BLUE.r, ACCENT_BLUE.g, ACCENT_BLUE.b, 0.85))
		if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_ENGLISH:
			_draw_text_centered_xy(canvas, font, "패시브 아이템 없음", grid_rect.position.x + grid_rect.size.x * 0.5, grid_rect.position.y + grid_rect.size.y * 0.5 + 16.0, 13, OVERLAY_GRID_EMPTY_TEXT)
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
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 12.0, "hex", SECTION_GLYPH_COLOR)
	_draw_text_xy(canvas, font, "퍽", rect.position.x + 36.0, rect.position.y + 24.0, 13, TEXT_SOFT)

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
	var slot_limit := 6
	if catalog != null and catalog.has_method("get_perk_slot_status"):
		# 융합 슬롯 환급 반영: registry를 slot context로 관통.
		var slot_status: Dictionary = CharacterInfoOverlayValueUtils.get_dict(catalog.get_perk_slot_status(levels, registry))
		var slot_count: int = int(slot_status.get("count", 0))
		slot_limit = int(slot_status.get("limit", slot_limit))
		if slot_limit > 0:
			var slot_text := "슬롯 %d/%d" % [slot_count, slot_limit]
			var slot_width: float = _text_size(font, slot_text, 11).x
			var slot_color := Color(170.0 / 255.0, 225.0 / 255.0, 1.0, 0.90)
			if slot_count >= slot_limit:
				slot_color = Color(1.0, 190.0 / 255.0, 90.0 / 255.0, 0.95)
			_draw_text_xy(canvas, font, slot_text, rect.end.x - slot_width - 14.0, rect.position.y + 23.0, 11, slot_color)
	var acquired: Array = _build_acquired_perks_cached(levels, catalog, effective_runtime_state, snapshot, equipped_skills_for_filter)

	var grid_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	var mouse_in_perk_grid_rect: bool = grid_rect.has_point(mouse_pos)
	_last_perk_grid_rect = grid_rect
	canvas.draw_rect(grid_rect, OVERLAY_GRID_FILL)
	var gap := 8.0
	var display_slot_count: int = max(6, slot_limit)
	var display_entries: Array = _build_perk_display_entries_cached(acquired, display_slot_count, _get_run_ring_core_tier_for_grid(registry))
	# Recompute animation liveness from the just-refreshed display draw ids so the
	# lifecycle update loop knows whether it must keep redrawing for an animated perk.
	_perk_grid_has_animated_icon = _perk_grid_contains_animated_icon(icon_renderer, can_draw_perk_icon)
	if display_entries.is_empty():
		_set_perk_grid_hover_layout(Vector2.ZERO, 0.0, 0.0, 0, 0)
		_draw_empty_state_hero(canvas, _empty_perk_hero_texture, grid_rect, -74.0, 0.52, 76.0, 132.0, 6.0)
		_draw_text_centered_xy(canvas, font, "NO PERKS OBTAINED", grid_rect.position.x + grid_rect.size.x * 0.5, grid_rect.position.y + grid_rect.size.y * 0.5 - 6.0, 15, Color(ACCENT_BLUE.r, ACCENT_BLUE.g, ACCENT_BLUE.b, 0.85))
		if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_ENGLISH:
			_draw_text_centered_xy(canvas, font, LanguageSettings.translate_text("획득한 퍽 없음"), grid_rect.position.x + grid_rect.size.x * 0.5, grid_rect.position.y + grid_rect.size.y * 0.5 + 16.0, 14, OVERLAY_GRID_EMPTY_TEXT)
		_last_perk_content_height = grid_rect.size.y
		return hover_data

	# Wide redesign (mockup v2 2026-07-08): prefer a single centered row of hex slots
	# across the widened panel; wrap back to the legacy 4-column grid only when the
	# section is too narrow for readable single-row cells.
	var entry_count: int = display_entries.size()
	var single_row_cell: float = (grid_rect.size.x - float(max(0, entry_count - 1)) * gap) / float(max(1, entry_count))
	var columns: int = entry_count if single_row_cell >= 44.0 else 4
	var rows: int = int(ceil(float(entry_count) / float(columns)))
	var cell_width_limit: float = floor((grid_rect.size.x - float(columns - 1) * gap) / float(columns))
	var cell_height_limit: float = floor((grid_rect.size.y - float(max(0, rows - 1)) * gap) / float(max(1, rows)))
	# Cells scale up to fill the section (width/height limits govern); the cap only
	# stops comically large hexes on very large windows.
	var cell_size: float = min(110.0, max(28.0, min(cell_width_limit, cell_height_limit)))
	_last_perk_content_height = float(rows) * (cell_size + gap) - gap
	var max_perk_scroll: float = max(0.0, _last_perk_content_height - _last_perk_grid_rect.size.y)
	perk_scroll = clamp(perk_scroll, 0.0, max_perk_scroll)
	var stride: float = cell_size + gap
	# Center the hex block inside the section while it fits (no scroll); a scrolling
	# grid keeps the legacy top-left origin so the scroll math stays untouched.
	var layout_rect := grid_rect
	if max_perk_scroll <= 0.0:
		var used_w: float = float(columns) * stride - gap
		layout_rect.position.x += max(0.0, (grid_rect.size.x - used_w) * 0.5)
		layout_rect.position.y += max(0.0, (grid_rect.size.y - _last_perk_content_height) * 0.5)
	_update_perk_grid_layout(layout_rect, cell_size, stride, columns, entry_count, perk_scroll)
	var hovered_perk_index := -1
	if mouse_in_perk_grid_rect:
		hovered_perk_index = CharacterInfoOverlayHoverGeometry.get_hovered_grid_index(mouse_pos, _last_perk_grid_start.x, _last_perk_grid_start.y, _last_perk_grid_cell_size, _last_perk_grid_stride, columns, display_entries.size())
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


# True when any padded perk-grid cell renders an animated (sheet-backed) icon.
# Scans the already-built display draw ids (empty slots are ""), so it is O(slots)
# and only touched on the ~9x/sec animation redraws it enables.
func _perk_grid_contains_animated_icon(icon_renderer: Object, can_draw_perk_icon: bool) -> bool:
	if not can_draw_perk_icon or icon_renderer == null or not icon_renderer.has_method("has_animated_icon"):
		return false
	for id_value in _acquired_perk_draw_id_cache:
		var perk_id: String = str(id_value)
		if perk_id != "" and bool(icon_renderer.has_animated_icon(perk_id)):
			return true
	return false

func _draw_stats_panel(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font, runtime_state_override: Object = null, active_item_runtime_override: Object = null, mythic_item_runtime_override: Object = null, character_type_override: String = "", stat_sources_override: Array = [], mouse_pos: Vector2 = Vector2.INF, hover_data: Dictionary = {}, active_item_slot_capacity_override: int = -1, active_item_slots_override: Variant = null) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(rect.position.x + 24.0, rect.position.y + 18.0), 12.0, "chart", SECTION_GLYPH_COLOR)
	_draw_text_xy(canvas, font, "능력치", rect.position.x + 36.0, rect.position.y + 24.0, 13, TEXT_SOFT)
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
		active_item_slots_override,
		rect.has_point(mouse_pos)
	)
	var row_count: int = _stats_row_count
	if _layout_lingpet_stats_rect.size != Vector2.ZERO:
		# Redesign (mockup v2 2026-07-08): lingpet stats live in their own right-column
		# box (_draw_lingpet_stats_panel, drawn BEFORE this panel so its drawer clears
		# the shared hover-rect list first) -- this panel renders player rows only.
		var inner_rect := Rect2(rect.position.x + 12.0, rect.position.y + 38.0, rect.size.x - 24.0, rect.size.y - 50.0)
		return CharacterInfoOverlayStatsPresenter.draw_cached_player_stat_rows(canvas, font, "플레이어 능력치", inner_rect, row_count, _stats_label_cache, _stats_value_cache, _stats_color_cache, _stats_value_width_cache, _stats_value_width_text_cache, _stats_value_width_size_cache, _stats_value_width_font_id_cache, ACCENT_BLUE, TEXT_DIM, OVERLAY_GRID_EMPTY_TEXT, UI_TEXT_SCALE, mouse_pos, hover_data, _last_lingpet_stat_row_rects)
	var lingpet_rows: Array = _build_lingpet_stats(owner)
	return CharacterInfoOverlayStatsPresenter.draw_stat_sections(canvas, font, rect, row_count, _stats_label_cache, _stats_value_cache, _stats_color_cache, _stats_value_width_cache, _stats_value_width_text_cache, _stats_value_width_size_cache, _stats_value_width_font_id_cache, lingpet_rows, mouse_pos, hover_data, _last_lingpet_stat_row_rects, ACCENT_BLUE, TEXT_DIM, OVERLAY_GRID_EMPTY_TEXT, UI_TEXT_SCALE)


# Right-column lingpet stats box (mockup v2 2026-07-08). Must draw BEFORE the player
# stats panel: draw_lingpet_stat_rows CLEARS the shared hover-rect list and the player
# rows then append into it (the same protocol draw_stat_sections relied on).
func _draw_lingpet_stats_panel(canvas: CanvasItem, owner: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary) -> Dictionary:
	CharacterInfoOverlayTextureDrawer.draw_section_chrome(canvas, rect, SECTION_COLOR, SECTION_BORDER, ACCENT_BLUE)
	var inner_rect := Rect2(rect.position.x + 12.0, rect.position.y + 10.0, rect.size.x - 24.0, rect.size.y - 22.0)
	return CharacterInfoOverlayStatsPresenter.draw_lingpet_stat_rows(canvas, font, "링펫 능력치", _build_lingpet_stats(owner), inner_rect, mouse_pos, hover_data, _last_lingpet_stat_row_rects, ACCENT_BLUE, TEXT_DIM, OVERLAY_GRID_EMPTY_TEXT, UI_TEXT_SCALE)

	# 소스별 증감 내역(breakdown)은 툴팁 전용이라 마우스가 이 패널 위에 있을
	# 때만 계산한다 — 링펫 동반 시 패널이 상시 redraw되므로 hover 게이팅으로
	# build-then-discard 비용을 막는다 (2026-07-11 리뷰 P2).
