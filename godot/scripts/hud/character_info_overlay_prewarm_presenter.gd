extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayHeaderPresenter := preload("res://scripts/hud/character_info_overlay_header_presenter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayPassiveItemPresenter := preload("res://scripts/hud/character_info_overlay_passive_item_presenter.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayStaticData := preload("res://scripts/hud/character_info_overlay_static_data.gd")
const CharacterInfoOverlayTextWidthCache := preload("res://scripts/hud/character_info_overlay_text_width_cache.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")

const TEXT_PREWARM_STEP_COUNT := 4
const ACTIVE_ITEM_TEXT_PREWARM_BATCH_SIZE := 6
const RUNTIME_PERK_TEXT_PREWARM_BATCH_SIZE := 8
const SKILL_TEXT_PREWARM_BATCH_SIZE := 3


static func prewarm_layout_caches(
	target: Object,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	resolved_view_size: Vector2,
	base_accessory_slot_count: int,
	accent_blue: Color,
	base_active_item_slot_count: int,
	passive_inventory_column_target: float
) -> void:
	if resolved_view_size.x <= 0.0 or resolved_view_size.y <= 0.0:
		return
	target.call("_update_frame_layout", resolved_view_size)
	_prewarm_equipment(target, owner, base_accessory_slot_count)
	_prewarm_skills(target, owner, registry, module_getter, accent_blue)
	_prewarm_active_items(target, owner, registry, module_getter, base_active_item_slot_count)
	_prewarm_passive_inventory(target, owner, registry, module_getter, passive_inventory_column_target)
	_prewarm_perks(target, owner, registry, module_getter)


static func prewarm_draw_caches(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, base_active_item_slot_count: int) -> void:
	if font == null:
		return
	_prewarm_header_text(target, font, owner, registry, module_getter)
	_prewarm_centered_text(target, font)
	_prewarm_inventory_count_text(target, font, owner, registry, module_getter)
	prewarm_stats_layout(target, font, owner, registry, module_getter, base_active_item_slot_count)


static func prewarm_shared_assets_and_text(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, include_shared_icon_assets: bool, lingpet_art_texture_cache: Dictionary, lingpet_skill_icon_texture_cache: Dictionary, shared_icon_assets_prewarmed: bool, static_text_prewarmed: bool, active_item_text_prewarmed: bool, runtime_perk_text_prewarmed: bool, skill_text_prewarmed: bool, lingpet_prewarm_pet_ids: Variant = null) -> void:
	CharacterInfoOverlayLingpetTextureLoader.prewarm_cached_art_assets(lingpet_art_texture_cache, lingpet_prewarm_pet_ids)
	CharacterInfoOverlayLingpetTextureLoader.prewarm_skill_icon_assets(lingpet_skill_icon_texture_cache, lingpet_prewarm_pet_ids)
	if include_shared_icon_assets and not shared_icon_assets_prewarmed:
		target.set("_shared_icon_assets_prewarmed", _prewarm_shared_icon_assets(registry, module_getter))
	target.call("_prewarm_visible_item_icons", owner, registry, module_getter)
	target.call("_prewarm_passive_inventory_assets", owner, registry, module_getter)
	_prewarm_static_text(target, font, owner, static_text_prewarmed)
	_prewarm_active_item_text_full(target, font, active_item_text_prewarmed)
	_prewarm_runtime_perk_text_full(target, font, owner, registry, module_getter, runtime_perk_text_prewarmed)
	_prewarm_skill_text_full(target, font, owner, registry, module_getter, skill_text_prewarmed)


static func prewarm_shared_icon_assets_step(target: Object, registry: Object, module_getter: Callable) -> bool:
	var icon_done := bool(target.get("_prewarm_shared_runtime_icon_assets_done")) if target != null else true
	if not icon_done:
		var icon_renderer: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_icon_renderer")
		if icon_renderer != null and icon_renderer.has_method("prewarm_assets_step"):
			icon_done = bool(icon_renderer.prewarm_assets_step())
		elif icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
			icon_renderer.prewarm_assets()
			icon_done = true
		else:
			icon_done = true
		target.set("_prewarm_shared_runtime_icon_assets_done", icon_done)
	var visuals_done := bool(target.get("_prewarm_shared_active_item_icons_done")) if target != null else true
	if not visuals_done:
		var visuals: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "active_item_hud_visuals")
		if visuals != null and visuals.has_method("prewarm_catalog_icons_step"):
			visuals_done = bool(visuals.prewarm_catalog_icons_step())
		elif visuals != null and visuals.has_method("prewarm_catalog_icons"):
			visuals.prewarm_catalog_icons()
			visuals_done = true
		else:
			visuals_done = true
		target.set("_prewarm_shared_active_item_icons_done", visuals_done)
	if icon_done and visuals_done and target != null:
		target.set("_prewarm_shared_runtime_icon_assets_done", false)
		target.set("_prewarm_shared_active_item_icons_done", false)
	return icon_done and visuals_done


static func prewarm_text_caches_step(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, static_text_prewarmed: bool, active_item_text_prewarmed: bool, runtime_perk_text_prewarmed: bool, skill_text_prewarmed: bool, step_index: int) -> bool:
	match step_index:
		0:
			_prewarm_static_text(target, font, owner, static_text_prewarmed)
			return true
		1:
			return _prewarm_active_item_text(target, font, active_item_text_prewarmed)
		2:
			return _prewarm_runtime_perk_text(target, font, owner, registry, module_getter, runtime_perk_text_prewarmed)
		3:
			return _prewarm_skill_text(target, font, owner, registry, module_getter, skill_text_prewarmed)
	return true


static func _prewarm_shared_icon_assets(registry: Object, module_getter: Callable) -> bool:
	var shared_assets_warmed := false
	var icon_renderer: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_icon_renderer")
	if icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.prewarm_assets()
		shared_assets_warmed = true
	var visuals: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("prewarm_catalog_icons"):
		visuals.prewarm_catalog_icons()
		shared_assets_warmed = true
	return shared_assets_warmed


static func _prewarm_static_text(target: Object, font: Font, owner: Object, static_text_prewarmed: bool) -> void:
	if static_text_prewarmed:
		return
	target.set("_static_text_prewarmed", true)
	target.call("_ensure_equipment_slot_metadata_cache")
	CharacterInfoOverlayTextWidthCache.prewarm_static_text(font, owner, target.get("_equipment_slot_keys"), target.get("_equipment_slot_labels"), Callable(target, "_text_size"))


static func _prewarm_active_item_text(target: Object, font: Font, active_item_text_prewarmed: bool) -> bool:
	if active_item_text_prewarmed:
		return true
	var entries: Array = target.get("_active_item_text_prewarm_entries")
	if entries.is_empty() and int(target.get("_active_item_text_prewarm_cursor")) <= 0:
		entries = CharacterInfoOverlayValueUtils.build_active_item_text_prewarm_entries(
			target.get("_active_item_catalog"),
			ActiveItemCatalog.FIELD_SPAWN_ORDER,
			CharacterInfoOverlayStaticData.EXTRA_ACTIVE_ITEM_PREWARM_NAMES
		)
		target.set("_active_item_text_prewarm_entries", entries)
	var cursor: int = int(target.get("_active_item_text_prewarm_cursor"))
	var next_cursor := CharacterInfoOverlayValueUtils.prewarm_active_item_text_entries_step(font, entries, cursor, ACTIVE_ITEM_TEXT_PREWARM_BATCH_SIZE, Callable(target, "_text_size"), Callable(CharacterInfoOverlayFormatter, "trim_label"), Callable(target, "_wrap_text_to_width"))
	if next_cursor >= entries.size():
		target.set("_active_item_text_prewarmed", true)
		target.set("_active_item_text_prewarm_cursor", 0)
		target.set("_active_item_text_prewarm_entries", [])
		return true
	target.set("_active_item_text_prewarm_cursor", next_cursor)
	return false


static func _prewarm_active_item_text_full(target: Object, font: Font, active_item_text_prewarmed: bool) -> void:
	if active_item_text_prewarmed:
		return
	target.set("_active_item_text_prewarmed", true)
	CharacterInfoOverlayValueUtils.prewarm_active_item_text(font, target.get("_active_item_catalog"), ActiveItemCatalog.FIELD_SPAWN_ORDER, CharacterInfoOverlayStaticData.EXTRA_ACTIVE_ITEM_PREWARM_NAMES, Callable(target, "_text_size"), Callable(CharacterInfoOverlayFormatter, "trim_label"), Callable(target, "_wrap_text_to_width"))


static func _prewarm_runtime_perk_text(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, runtime_perk_text_prewarmed: bool) -> bool:
	if runtime_perk_text_prewarmed:
		return true
	var perk_catalog: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_catalog")
	var perk_runtime_state: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_state")
	var character_runtime: Object = target.get("_character_runtime")
	if perk_catalog == null:
		return true
	var entries: Array = target.get("_runtime_perk_text_prewarm_entries")
	if entries.is_empty() and int(target.get("_runtime_perk_text_prewarm_cursor")) <= 0:
		entries = CharacterInfoOverlayPerkPresenter.build_runtime_perk_text_prewarm_entries(
			perk_catalog,
			CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime),
			perk_runtime_state
		)
		target.set("_runtime_perk_text_prewarm_entries", entries)
	var cursor: int = int(target.get("_runtime_perk_text_prewarm_cursor"))
	var next_cursor := CharacterInfoOverlayPerkPresenter.prewarm_runtime_perk_text_entries_step(font, entries, cursor, RUNTIME_PERK_TEXT_PREWARM_BATCH_SIZE, Callable(target, "_text_size"), Callable(CharacterInfoOverlayFormatter, "trim_label"), Callable(target, "_wrap_text_to_width"))
	if next_cursor >= entries.size():
		target.set("_runtime_perk_text_prewarmed", true)
		target.set("_runtime_perk_text_prewarm_cursor", 0)
		target.set("_runtime_perk_text_prewarm_entries", [])
		return true
	target.set("_runtime_perk_text_prewarm_cursor", next_cursor)
	return false


static func _prewarm_runtime_perk_text_full(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, runtime_perk_text_prewarmed: bool) -> void:
	if runtime_perk_text_prewarmed:
		return
	var perk_catalog: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_catalog")
	var perk_runtime_state: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_state")
	var character_runtime: Object = target.get("_character_runtime")
	target.set(
		"_runtime_perk_text_prewarmed",
		CharacterInfoOverlayPerkPresenter.prewarm_runtime_perk_text(font, perk_catalog, CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime), perk_runtime_state, Callable(target, "_text_size"), Callable(CharacterInfoOverlayFormatter, "trim_label"), Callable(target, "_wrap_text_to_width"))
	)


static func _prewarm_skill_text(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, skill_text_prewarmed: bool) -> bool:
	if skill_text_prewarmed:
		return true
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var entries: Array = target.get("_skill_text_prewarm_entries")
	if entries.is_empty() and int(target.get("_skill_text_prewarm_cursor")) <= 0:
		entries = CharacterInfoOverlayValueUtils.build_skill_text_prewarm_entries(
			character_runtime,
			registry,
			module_getter,
			Callable(CharacterInfoOverlayOwnerState, "prewarm_instance")
		)
		target.set("_skill_text_prewarm_entries", entries)
	var cursor: int = int(target.get("_skill_text_prewarm_cursor"))
	var next_cursor := CharacterInfoOverlayValueUtils.prewarm_skill_text_entries_step(font, entries, cursor, SKILL_TEXT_PREWARM_BATCH_SIZE, Callable(target, "_text_size"), Callable(CharacterInfoOverlayFormatter, "trim_label"), Callable(target, "_wrap_text_to_width"))
	if next_cursor >= entries.size():
		target.call("_text_size", font, CharacterInfoOverlayFormatter.character_type_label(character_type), 14)
		if not entries.is_empty():
			target.set("_skill_text_prewarmed", true)
		target.set("_skill_text_prewarm_cursor", 0)
		target.set("_skill_text_prewarm_entries", [])
		return true
	target.set("_skill_text_prewarm_cursor", next_cursor)
	return false


static func _prewarm_skill_text_full(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, skill_text_prewarmed: bool) -> void:
	if skill_text_prewarmed:
		return
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	target.set(
		"_skill_text_prewarmed",
		CharacterInfoOverlayValueUtils.prewarm_skill_text(font, character_runtime, CharacterInfoOverlayFormatter.character_type_label(character_type), registry, module_getter, Callable(CharacterInfoOverlayOwnerState, "prewarm_instance"), Callable(target, "_text_size"), Callable(CharacterInfoOverlayFormatter, "trim_label"), Callable(target, "_wrap_text_to_width"))
	)


static func prewarm_stats_layout(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable, base_active_item_slot_count: int) -> void:
	var layout_stats_rect: Rect2 = target.get("_layout_stats_rect")
	if layout_stats_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_state")
	var active_item_runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "active_item_runtime")
	var mythic_item_runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var lingpet_runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "lingpet_egg_runtime")
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var stat_sources: Array = [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]
	var active_item_slot_capacity: int = CharacterInfoOverlayOwnerState.active_item_slot_capacity(runtime_state, mythic_item_runtime, base_active_item_slot_count)
	var active_item_slots: Array = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "active_item_slots", []))
	var player_rows: Array = target.call("_build_stats", owner, registry, runtime_state, active_item_runtime, mythic_item_runtime, character_type, stat_sources, true, active_item_slot_capacity, active_item_slots)
	var lingpet_rows: Array = target.call("_build_lingpet_stats", owner)
	for rows in [player_rows, lingpet_rows]:
		for row_value in rows:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			target.call("_text_size", font, str(row.get("label", "")), 13)
			target.call("_text_size", font, str(row.get("value", "")), 13)


static func _prewarm_header_text(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:
	var layout_panel_rect: Rect2 = target.get("_layout_panel_rect")
	if layout_panel_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_state")
	var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var subtitle_cache: Dictionary = target.get("_header_subtitle_cache")
	var display_name: String = CharacterInfoOverlayOwnerState.character_display_name_from_owner(owner, character_type)
	target.call("_text_size", font, CharacterInfoOverlayHeaderPresenter.cached_subtitle(display_name, character_type, subtitle_cache), 14)
	var pending: int = int(runtime_snapshot.get("pending_skill_choices")) if runtime_snapshot.has("pending_skill_choices") else int(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_perk_pending_choices", 0))
	var gold: int = int(runtime_snapshot.get("gold_from_perks")) if runtime_snapshot.has("gold_from_perks") else int(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_perk_gold", 0))
	var status_text_cache: Dictionary = target.get("_header_status_text_cache")
	var status_width_cache: Dictionary = target.get("_header_status_width_cache")
	target.set(
		"_header_status_width_cache",
		CharacterInfoOverlayHeaderPresenter.cached_status_width(
			font,
			CharacterInfoOverlayHeaderPresenter.cached_status_text(pending, gold, status_text_cache),
			14,
			status_width_cache,
			Callable(target, "_text_size")
		)
	)


static func _prewarm_centered_text(target: Object, font: Font) -> void:
	var equipment_label_size := 8 if float(target.get("_equipment_layout_slot_size")) > 0.0 and float(target.get("_equipment_layout_slot_size")) < 40.0 else 10
	var equipment_labels: Array = target.get("_equipment_slot_visible_label_cache")
	for label in equipment_labels:
		target.call("_get_centered_text_size", font, str(label), equipment_label_size)
	var skill_labels: Array = target.get("_skill_slot_label_cache")
	for label in skill_labels:
		target.call("_get_centered_text_size", font, str(label), 10)
	var active_item_labels: Array = target.get("_active_item_trimmed_label_cache")
	for label in active_item_labels:
		target.call("_get_centered_text_size", font, str(label), 10)
	var perk_level_texts: Array = target.get("_acquired_perk_level_text_cache")
	for level_text in perk_level_texts:
		target.call("_get_perk_level_text_size", font, str(level_text), 9)


static func _prewarm_inventory_count_text(target: Object, font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:
	var layout_inventory_rect: Rect2 = target.get("_layout_inventory_rect")
	if layout_inventory_rect.size == Vector2.ZERO:
		return
	var mythic_item_runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var inventory_items: Array = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_items(owner, registry, mythic_item_runtime)
	var summary: Dictionary = target.call("_prepare_passive_inventory_draw_cache", inventory_items)
	target.call("_get_passive_inventory_count_text_width", font, str(summary.get("count_text", "")), 11)


static func _prewarm_equipment(target: Object, owner: Object, base_accessory_slot_count: int) -> void:
	var layout_equipment_rect: Rect2 = target.get("_layout_equipment_rect")
	if layout_equipment_rect.size == Vector2.ZERO:
		return
	var equipment_content_rect := Rect2(layout_equipment_rect.position.x + 12.0, layout_equipment_rect.position.y + 34.0, layout_equipment_rect.size.x - 24.0, layout_equipment_rect.size.y - 42.0)
	var equipment_slot_size: float = clamp(min(equipment_content_rect.size.x * 0.18, equipment_content_rect.size.y * 0.145), 34.0, 55.0)
	target.call("_update_equipment_slot_layout", equipment_content_rect, equipment_slot_size)
	target.set("_last_equipment_slot_rects", target.get("_equipment_slot_rect_cache"))
	target.set("_equipment_hover_uses_indexed_layout", true)
	target.call("_ensure_equipment_slot_metadata_cache")
	target.call("_refresh_equipment_slot_visible_label_cache", equipment_slot_size < 42.0)
	target.call(
		"_refresh_equipment_slot_frame_cache",
		CharacterInfoOverlayOwnerState.equipment_state_from_owner(owner),
		CharacterInfoOverlayOwnerState.accessory_slot_count_from_owner(owner, base_accessory_slot_count)
	)


static func _prewarm_skills(target: Object, owner: Object, registry: Object, module_getter: Callable, accent_blue: Color) -> void:
	var layout_skill_rect: Rect2 = target.get("_layout_skill_rect")
	if layout_skill_rect.size == Vector2.ZERO:
		return
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var skill_config: Object = CharacterInfoOverlayOwnerState.prewarm_skill_config(registry, module_getter, character_type, character_runtime)
	var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var max_slots: int = max(1, int(skill_snapshot.get("max_slots", 5)))
	# Skill cards: keep this sizing formula identical to _draw_skill_slots in
	# character_info_overlay_core.gd (two-path trap).
	var card_width_limit: float = (layout_skill_rect.size.x - 24.0 - float(max_slots - 1) * 12.0) / float(max_slots)
	var slot_width_limit: float = card_width_limit - 24.0
	var slot_height_limit: float = layout_skill_rect.size.y - 118.0
	var slot_size: float = min(96.0, max(40.0, min(slot_width_limit, slot_height_limit)))
	target.call("_update_skill_slot_layout", layout_skill_rect, slot_size, max_slots)
	target.call(
		"_refresh_skill_slot_draw_cache",
		CharacterInfoOverlayValueUtils.get_array(skill_snapshot.get("equipped_skills", [])),
		CharacterInfoOverlayValueUtils.get_dict(skill_snapshot.get("skill_data", {})),
		CharacterInfoOverlayFormatter.skill_fallback_color(character_type, accent_blue)
	)


static func _prewarm_active_items(target: Object, owner: Object, registry: Object, module_getter: Callable, base_active_item_slot_count: int) -> void:
	var layout_active_items_rect: Rect2 = target.get("_layout_active_items_rect")
	if layout_active_items_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_state")
	var mythic_item_runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var max_slots: int = CharacterInfoOverlayOwnerState.active_item_slot_capacity(runtime_state, mythic_item_runtime, base_active_item_slot_count)
	var slot_width_limit: float = (layout_active_items_rect.size.x - 34.0) / float(max_slots)
	var slot_height_limit: float = layout_active_items_rect.size.y - 64.0
	var min_slot_size: float = 24.0 if max_slots > 5 else 40.0
	var slot_size: float = min(68.0, max(min_slot_size, min(slot_width_limit, slot_height_limit)))
	var gap: float = max(4.0, (layout_active_items_rect.size.x - slot_size * float(max_slots)) / float(max_slots + 1))
	var active_slots: Array = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "active_item_slots", []))
	var visuals: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "active_item_hud_visuals")
	var icon_renderer: Object = target.get("_active_item_icon_renderer")
	var can_draw_icon: bool = icon_renderer != null and icon_renderer.has_method("draw_icon")
	target.call("_refresh_active_item_label_cache", active_slots)
	target.call("_update_active_slot_layout", layout_active_items_rect, slot_size, gap, max_slots)
	target.call("_refresh_active_slot_draw_cache", active_slots, max_slots, visuals, not can_draw_icon)


static func _prewarm_passive_inventory(target: Object, owner: Object, registry: Object, module_getter: Callable, column_target: float) -> void:
	var layout_inventory_rect: Rect2 = target.get("_layout_inventory_rect")
	if layout_inventory_rect.size == Vector2.ZERO:
		return
	var mythic_item_runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var inventory_items: Array = CharacterInfoOverlayPassiveItemPresenter.passive_inventory_items(owner, registry, mythic_item_runtime)
	target.call("_prepare_passive_inventory_draw_cache", inventory_items)
	target.set("_last_passive_inventory_rect", layout_inventory_rect)
	var grid_rect := Rect2(layout_inventory_rect.position.x + 12.0, layout_inventory_rect.position.y + 36.0, layout_inventory_rect.size.x - 24.0, layout_inventory_rect.size.y - 48.0)
	target.set("_last_passive_inventory_grid_rect", grid_rect)
	if inventory_items.is_empty():
		target.call("_set_passive_grid_hover_layout", Vector2.ZERO, 0.0, 0.0, 0, 0)
		target.set("_last_passive_inventory_content_height", grid_rect.size.y)
		target.call("_update_passive_inventory_scrollbar_layout", grid_rect, 0.0)
		return
	var gap := 8.0
	var columns: int = max(4, int(floor((grid_rect.size.x + gap) / column_target)))
	var cell_size: float = min(50.0, floor((grid_rect.size.x - float(columns - 1) * gap) / float(columns)))
	cell_size = max(36.0, cell_size)
	var rows: int = int(ceil(float(inventory_items.size()) / float(columns)))
	var content_height: float = float(rows) * (cell_size + gap) - gap
	target.set("_last_passive_inventory_content_height", content_height)
	var max_scroll: float = max(0.0, content_height - layout_inventory_rect.size.y + 48.0)
	var scroll: float = clamp(float(target.get("passive_inventory_scroll")), 0.0, max_scroll)
	target.set("passive_inventory_scroll", scroll)
	var stride: float = cell_size + gap
	target.call("_update_passive_inventory_grid_layout", grid_rect, cell_size, stride, columns, inventory_items.size(), scroll)
	target.call("_update_passive_inventory_scrollbar_layout", grid_rect, max_scroll)


static func _prewarm_perks(target: Object, owner: Object, registry: Object, module_getter: Callable) -> void:
	var layout_perk_rect: Rect2 = target.get("_layout_perk_rect")
	if layout_perk_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_state")
	var catalog: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "runtime_perk_catalog")
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var skill_config: Object = CharacterInfoOverlayOwnerState.prewarm_skill_config(registry, module_getter, character_type, character_runtime)
	var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var equipped_skills: Array = CharacterInfoOverlayValueUtils.get_array(skill_snapshot.get("equipped_skills", []))
	var snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var levels: Dictionary = CharacterInfoOverlayValueUtils.get_dict(snapshot.get("runtime_skill_levels", {}))
	if levels.is_empty() and not snapshot.has("runtime_skill_levels"):
		levels = CharacterInfoOverlayValueUtils.get_dict(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_perk_levels", {}))
	var acquired_perks: Array = target.call("_build_acquired_perks_cached", levels, catalog, runtime_state, snapshot, equipped_skills)
	var grid_rect := Rect2(layout_perk_rect.position.x + 12.0, layout_perk_rect.position.y + 36.0, layout_perk_rect.size.x - 24.0, layout_perk_rect.size.y - 48.0)
	target.set("_last_perk_grid_rect", grid_rect)
	if acquired_perks.is_empty():
		target.call("_set_perk_grid_hover_layout", Vector2.ZERO, 0.0, 0.0, 0, 0)
		target.set("_last_perk_content_height", grid_rect.size.y)
		target.call("_update_perk_scrollbar_layout", grid_rect, 0.0)
		return
	var columns: int = max(3, int(floor((grid_rect.size.x + 8.0) / 58.0)))
	var cell_size: float = min(52.0, floor((grid_rect.size.x - float(columns - 1) * 8.0) / float(columns)))
	var gap := 8.0
	var rows: int = int(ceil(float(acquired_perks.size()) / float(columns)))
	var content_height: float = float(rows) * (cell_size + gap) - gap
	target.set("_last_perk_content_height", content_height)
	var max_scroll: float = max(0.0, content_height - grid_rect.size.y)
	var scroll: float = clamp(float(target.get("perk_scroll")), 0.0, max_scroll)
	target.set("perk_scroll", scroll)
	var stride: float = cell_size + gap
	target.call("_update_perk_grid_layout", grid_rect, cell_size, stride, columns, acquired_perks.size(), scroll)
	target.call("_update_perk_scrollbar_layout", grid_rect, max_scroll)
