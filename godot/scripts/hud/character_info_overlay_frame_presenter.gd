extends RefCounted

const CharacterInfoOverlayHeaderPresenter := preload("res://scripts/hud/character_info_overlay_header_presenter.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")

# Kept local (not on the state script) — presenters must not preload the overlay
# state script: core inherits it, and a presenter preload creates a resolve cycle.
const EDITORIAL_BG_ALPHA := 0.20
const BACKDROP_DIM_ALPHA := 0.30
const MYSTIC_BACKDROP_ALPHA := 0.90
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func draw_frame(
	target: Object,
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	font: Font,
	panel_rect: Rect2,
	layout_equipment_rect: Rect2,
	layout_skill_rect: Rect2,
	layout_active_items_rect: Rect2,
	layout_perk_rect: Rect2,
	layout_lingpet_rect: Rect2,
	layout_stats_rect: Rect2,
	layout_inventory_rect: Rect2,
	stat_sources: Array,
	hover_data: Dictionary,
	header_subtitle_cache: Dictionary,
	header_status_text_cache: Dictionary,
	header_status_width_cache: Dictionary,
	lingpet_skill_icon_rects: Array[Rect2],
	lingpet_unlock_card_rects: Array,
	lingpet_ring_core_rects: Array[Rect2],
	lingpet_slot_tab_rects: Array,
	lingpet_art_texture_cache: Dictionary,
	lingpet_skill_icon_texture_cache: Dictionary,
	open_animation_duration: float,
	panel_color: Color,
	panel_border: Color,
	text_dim: Color,
	accent_gold: Color,
	base_active_item_slot_count: int,
	lingpet_hatch_required_hits: int,
	section_color: Color,
	section_border: Color,
	overlay_grid_fill: Color,
	stat_buff_color: Color,
	overlay_grid_empty_text: Color,
	accent_blue: Color,
	text_soft: Color,
	overlay_slot_fill: Color,
	fallback_symbol_ring_segments: int,
	ui_text_scale: float
) -> void:
	var perf_logger: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	var alpha: float = clamp(float(target.get("animation_time")) / open_animation_duration, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, BACKDROP_DIM_ALPHA * alpha))

	CharacterInfoOverlayTextureDrawer.draw_main_panel(canvas, panel_rect, panel_color, panel_border, 3.0)
	# The mystic blurred backdrop stays INSIDE the panel so the battle scene
	# remains visible around the character info layout.
	var mystic_backdrop: Variant = target.get("_mystic_backdrop_texture")
	if mystic_backdrop is Texture2D:
		CharacterInfoOverlayTextureDrawer.draw_cover(canvas, mystic_backdrop as Texture2D, panel_rect.grow(-5.0), Color(1.0, 1.0, 1.0, MYSTIC_BACKDROP_ALPHA * alpha))
	var editorial_bg: Variant = target.get("_editorial_bg_texture")
	if editorial_bg is Texture2D:
		CharacterInfoOverlayTextureDrawer.draw_cover(canvas, editorial_bg as Texture2D, panel_rect.grow(-5.0), Color(1.0, 1.0, 1.0, EDITORIAL_BG_ALPHA * alpha))
	PremiumPanelFrame.draw_corner_brackets(canvas, panel_rect.grow(9.0), Color(panel_border.r, panel_border.g, panel_border.b, 0.85 * alpha), 1.0, 0.08, 46.0)
	var runtime_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_state")
	var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var character_runtime: Object = target.get("_character_runtime")
	var character_type: String = CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var class_emblem: Texture2D = null
	var class_emblem_textures: Variant = target.get("_class_emblem_textures")
	if class_emblem_textures is Dictionary:
		var class_emblem_value: Variant = (class_emblem_textures as Dictionary).get(character_type)
		if class_emblem_value is Texture2D:
			class_emblem = class_emblem_value as Texture2D
	target.set("_header_status_width_cache", CharacterInfoOverlayHeaderPresenter.draw_header(canvas, owner, panel_rect, font, registry, runtime_state, runtime_snapshot, character_type, character_runtime, header_subtitle_cache, header_status_text_cache, header_status_width_cache, text_dim, accent_gold, accent_blue, class_emblem, Callable(target, "_text_size"), Callable(target, "_draw_text_xy")))
	_perf_end(perf_logger, "character_info.frame", sample_start)

	var mouse_pos := Vector2.ZERO
	var viewport: Viewport = canvas.get_viewport()
	if viewport != null:
		mouse_pos = viewport.get_mouse_position()
	var active_item_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_runtime")
	var mythic_item_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	var lingpet_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
	var active_item_hud_visuals: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_hud_visuals")
	var runtime_perk_icon_renderer: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_icon_renderer")
	var runtime_perk_catalog: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_catalog")
	var skill_config: Object = CharacterInfoOverlayOwnerState.skill_config(registry, character_type, character_runtime)
	var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var active_item_slot_capacity: int = CharacterInfoOverlayOwnerState.active_item_slot_capacity(runtime_state, mythic_item_runtime, base_active_item_slot_count)
	var active_item_slots: Array = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "active_item_slots", []))
	stat_sources.clear()
	stat_sources.append(runtime_state)
	stat_sources.append(active_item_runtime)
	stat_sources.append(mythic_item_runtime)
	stat_sources.append(lingpet_runtime)
	var empty_ringpet_hero_texture: Texture2D = null
	var empty_ringpet_hero_value: Variant = target.get("_empty_ringpet_hero_texture")
	if empty_ringpet_hero_value is Texture2D:
		empty_ringpet_hero_texture = empty_ringpet_hero_value as Texture2D

	hover_data.clear()
	hover_data = _draw_sections(target, canvas, owner, registry, font, mouse_pos, hover_data, perf_logger, runtime_state, runtime_snapshot, active_item_runtime, mythic_item_runtime, active_item_hud_visuals, runtime_perk_icon_renderer, runtime_perk_catalog, skill_snapshot, character_type, active_item_slot_capacity, active_item_slots, stat_sources, layout_equipment_rect, layout_skill_rect, layout_active_items_rect, layout_perk_rect, layout_lingpet_rect, layout_stats_rect, layout_inventory_rect, lingpet_skill_icon_rects, lingpet_unlock_card_rects, lingpet_ring_core_rects, lingpet_slot_tab_rects, lingpet_art_texture_cache, lingpet_skill_icon_texture_cache, empty_ringpet_hero_texture, lingpet_hatch_required_hits, section_color, section_border, overlay_grid_fill, stat_buff_color, overlay_grid_empty_text, accent_blue, accent_gold, text_soft, overlay_slot_fill, fallback_symbol_ring_segments, ui_text_scale)
	var pendulum: Object = target.get("_pendulum_interior")
	if pendulum != null and pendulum.has_method("is_active") and bool(pendulum.is_active()):
		hover_data.clear()
		sample_start = _perf_begin(perf_logger)
		if pendulum.has_method("draw"):
			pendulum.draw(canvas, font, panel_rect, view_size, mouse_pos)
		_perf_end(perf_logger, "character_info.pendulum_interior", sample_start)
	if not hover_data.is_empty():
		sample_start = _perf_begin(perf_logger)
		target.call("_draw_tooltip", canvas, hover_data, mouse_pos, view_size, font, runtime_perk_icon_renderer)
		_perf_end(perf_logger, "character_info.tooltip", sample_start)


static func _draw_sections(target: Object, canvas: CanvasItem, owner: Object, registry: Object, font: Font, mouse_pos: Vector2, hover_data: Dictionary, perf_logger: Object, runtime_state: Object, runtime_snapshot: Dictionary, active_item_runtime: Object, mythic_item_runtime: Object, active_item_hud_visuals: Object, runtime_perk_icon_renderer: Object, runtime_perk_catalog: Object, skill_snapshot: Dictionary, character_type: String, active_item_slot_capacity: int, active_item_slots: Array, stat_sources: Array, layout_equipment_rect: Rect2, layout_skill_rect: Rect2, layout_active_items_rect: Rect2, layout_perk_rect: Rect2, layout_lingpet_rect: Rect2, layout_stats_rect: Rect2, layout_inventory_rect: Rect2, lingpet_skill_icon_rects: Array[Rect2], lingpet_unlock_card_rects: Array, lingpet_ring_core_rects: Array[Rect2], lingpet_slot_tab_rects: Array, lingpet_art_texture_cache: Dictionary, lingpet_skill_icon_texture_cache: Dictionary, empty_ringpet_hero_texture: Texture2D, lingpet_hatch_required_hits: int, section_color: Color, section_border: Color, overlay_grid_fill: Color, stat_buff_color: Color, overlay_grid_empty_text: Color, accent_blue: Color, accent_gold: Color, text_soft: Color, overlay_slot_fill: Color, fallback_symbol_ring_segments: int, ui_text_scale: float) -> Dictionary:
	var sample_start: int
	var equipment_rect: Rect2 = layout_equipment_rect
	if equipment_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = target.call("_draw_equipment_slots", canvas, owner, registry, equipment_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)
		_perf_end(perf_logger, "character_info.equipment", sample_start)

	var skill_rect: Rect2 = layout_skill_rect
	if skill_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = target.call("_draw_skill_slots", canvas, owner, registry, skill_rect, font, mouse_pos, hover_data, character_type, skill_snapshot, runtime_perk_icon_renderer)
		_perf_end(perf_logger, "character_info.skills", sample_start)

	var active_items_rect: Rect2 = layout_active_items_rect
	if active_items_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = target.call("_draw_active_items", canvas, owner, registry, active_items_rect, font, mouse_pos, hover_data, active_item_slot_capacity, active_item_hud_visuals, stat_sources, active_item_slots)
		_perf_end(perf_logger, "character_info.active_items", sample_start)
	else:
		target.set("_last_active_items_rect", Rect2())
		target.set("_last_active_slot_count", 0)
		target.set("_last_active_slot_size", 0.0)
		target.set("_last_active_slot_stride", 0.0)

	sample_start = _perf_begin(perf_logger)
	hover_data = target.call("_draw_perk_grid", canvas, owner, registry, layout_perk_rect, font, mouse_pos, hover_data, runtime_state, runtime_perk_icon_renderer, runtime_snapshot, runtime_perk_catalog, CharacterInfoOverlayValueUtils.get_array(skill_snapshot.get("equipped_skills", [])))
	_perf_end(perf_logger, "character_info.perks", sample_start)

	sample_start = _perf_begin(perf_logger)
	var lingpet_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), lingpet_hatch_required_hits)
	var lingpet_unlock_options: Array = []
	var lingpet_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime != null and lingpet_runtime.has_method("get_snapshot"):
		var lingpet_runtime_snapshot_value: Variant = lingpet_runtime.get_snapshot()
		if lingpet_runtime_snapshot_value is Dictionary:
			CharacterInfoOverlayLingpetPresenter.merge_runtime_satiety_snapshot(lingpet_snapshot, lingpet_runtime_snapshot_value as Dictionary)
	if lingpet_runtime != null and lingpet_runtime.has_method("get_unlock_choice_options"):
		lingpet_unlock_options = lingpet_runtime.get_unlock_choice_options(str(lingpet_snapshot.get("pet_id", "")), registry)
	var lingpet_panel_live2d_active: bool = CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(lingpet_snapshot)
	target.set("_lingpet_panel_live2d_redraw_active", lingpet_panel_live2d_active)
	hover_data = CharacterInfoOverlayLingpetPresenter.draw_panel(canvas, font, layout_lingpet_rect, lingpet_snapshot, mouse_pos, hover_data, lingpet_skill_icon_rects, lingpet_unlock_options, lingpet_unlock_card_rects, lingpet_ring_core_rects, lingpet_slot_tab_rects, lingpet_art_texture_cache, lingpet_skill_icon_texture_cache, empty_ringpet_hero_texture, section_color, section_border, overlay_grid_fill, stat_buff_color, overlay_grid_empty_text, accent_blue, accent_gold, text_soft, overlay_slot_fill, fallback_symbol_ring_segments, ui_text_scale, Callable(target, "_wrap_text_to_width"), lingpet_hatch_required_hits, float(target.get("lingpet_panel_live2d_time")))
	_perf_end(perf_logger, "character_info.lingpet", sample_start)

	# Lingpet stats box (right column). Drawn BEFORE the player stats panel because its
	# drawer clears the shared hover-rect list that the player rows then append into.
	var lingpet_stats_rect_value: Variant = target.get("_layout_lingpet_stats_rect")
	if lingpet_stats_rect_value is Rect2 and (lingpet_stats_rect_value as Rect2).size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = target.call("_draw_lingpet_stats_panel", canvas, owner, lingpet_stats_rect_value, font, mouse_pos, hover_data)
		_perf_end(perf_logger, "character_info.lingpet_stats", sample_start)

	sample_start = _perf_begin(perf_logger)
	hover_data = target.call("_draw_stats_panel", canvas, owner, registry, layout_stats_rect, font, runtime_state, active_item_runtime, mythic_item_runtime, character_type, stat_sources, mouse_pos, hover_data, active_item_slot_capacity, active_item_slots)
	_perf_end(perf_logger, "character_info.stats", sample_start)

	var inventory_rect: Rect2 = layout_inventory_rect
	if inventory_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = target.call("_draw_passive_inventory", canvas, owner, registry, inventory_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)
		_perf_end(perf_logger, "character_info.passive_inventory", sample_start)
	return hover_data


static func _perf_begin(perf_logger: Object) -> int:
	return int(perf_logger.begin_sample()) if perf_logger != null and perf_logger.has_method("begin_sample") else 0


static func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
