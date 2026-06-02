extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemHudSlotIconRenderer := preload("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")
const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherDashSpiritState := preload("res://scripts/characters/smasher_dash_spirit_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LINGPET_SPEED_DISPLAY_PX_PER_POINT := 60.0

const SPECIAL_GAUGE_MAX := 500.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PANEL_COLOR := Color(18.0 / 255.0, 22.0 / 255.0, 38.0 / 255.0, 0.96)
const PANEL_BORDER := Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 0.86)
const SECTION_COLOR := Color(24.0 / 255.0, 30.0 / 255.0, 50.0 / 255.0, 0.92)
const SECTION_BORDER := Color(78.0 / 255.0, 112.0 / 255.0, 165.0 / 255.0, 0.76)
const TEXT_DIM := Color(178.0 / 255.0, 188.0 / 255.0, 210.0 / 255.0)
const TEXT_SOFT := Color(210.0 / 255.0, 220.0 / 255.0, 235.0 / 255.0)
const ACCENT_BLUE := Color(0.0, 205.0 / 255.0, 1.0)
const ACCENT_GOLD := Color(1.0, 215.0 / 255.0, 85.0 / 255.0)
const STAT_BUFF_COLOR := Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0)
const STAT_DEBUFF_COLOR := Color(1.0, 95.0 / 255.0, 95.0 / 255.0)
const OVERLAY_GRID_FILL := Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.55)
const OVERLAY_GRID_CELL_FILL := Color(20.0 / 255.0, 25.0 / 255.0, 38.0 / 255.0, 0.96)
const OVERLAY_GRID_EMPTY_TEXT := Color(125.0 / 255.0, 132.0 / 255.0, 150.0 / 255.0)
const OVERLAY_SLOT_FILL := Color(12.0 / 255.0, 17.0 / 255.0, 29.0 / 255.0, 0.96)
const OVERLAY_SLOT_BORDER := Color(80.0 / 255.0, 100.0 / 255.0, 140.0 / 255.0, 0.72)
const OVERLAY_SKILL_EMPTY_HOVER_FILL := Color(80.0 / 255.0, 90.0 / 255.0, 110.0 / 255.0, 0.35)
const OVERLAY_ACTIVE_EMPTY_TEXT := Color(95.0 / 255.0, 100.0 / 255.0, 120.0 / 255.0)
const OVERLAY_SCROLLBAR_TRACK := Color(0.0, 0.0, 0.0, 0.35)
const OVERLAY_PERK_SCROLLBAR_THUMB := Color(120.0 / 255.0, 170.0 / 255.0, 1.0, 0.72)
const OVERLAY_PASSIVE_SCROLLBAR_THUMB := Color(120.0 / 255.0, 220.0 / 255.0, 170.0 / 255.0, 0.72)
const OVERLAY_EQUIPPED_BADGE_FILL := Color(70.0 / 255.0, 160.0 / 255.0, 1.0, 0.92)
const OVERLAY_TOOLTIP_PANEL_FILL := Color(12.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.97)
const OVERLAY_TOOLTIP_ROLL_PANEL_FILL := Color(18.0 / 255.0, 22.0 / 255.0, 40.0 / 255.0, 0.97)
const OVERLAY_TOOLTIP_ROLL_BORDER := Color(1.0, 140.0 / 255.0, 70.0 / 255.0)
const EQUIPMENT_SILHOUETTE_BASE := Color(32.0 / 255.0, 43.0 / 255.0, 72.0 / 255.0, 0.46)
const EQUIPMENT_SILHOUETTE_HEAD := Color(20.0 / 255.0, 27.0 / 255.0, 48.0 / 255.0, 0.56)
const EQUIPMENT_SILHOUETTE_NECK := Color(20.0 / 255.0, 27.0 / 255.0, 48.0 / 255.0, 0.44)
const EQUIPMENT_SILHOUETTE_DEEP_DETAIL := Color(20.0 / 255.0, 27.0 / 255.0, 48.0 / 255.0, 0.42)
const EQUIPMENT_SILHOUETTE_BASE_DETAIL := Color(32.0 / 255.0, 43.0 / 255.0, 72.0 / 255.0, 0.42)
const EQUIPMENT_SILHOUETTE_LINE := Color(105.0 / 255.0, 134.0 / 255.0, 205.0 / 255.0, 0.18)
const EQUIPMENT_SLOT_FILL_ENABLED := Color(13.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.92)
const EQUIPMENT_SLOT_FILL_DISABLED := Color(13.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.42)
const EQUIPMENT_SLOT_BORDER_DISABLED := Color(85.0 / 255.0, 91.0 / 255.0, 112.0 / 255.0, 0.30)
const EQUIPMENT_SLOT_BORDER_FILLED := Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0, 0.92)
const EQUIPMENT_LABEL_DISABLED := Color(120.0 / 255.0, 126.0 / 255.0, 142.0 / 255.0)
const EQUIPMENT_COLOR_DISABLED := Color(85.0 / 255.0, 91.0 / 255.0, 112.0 / 255.0)
const EQUIPMENT_COLOR_FILLED := Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0)
const EQUIPMENT_COLOR_HEAD := Color(120.0 / 255.0, 190.0 / 255.0, 1.0)
const EQUIPMENT_COLOR_TOP := Color(1.0, 160.0 / 255.0, 95.0 / 255.0)
const EQUIPMENT_COLOR_ARM := Color(185.0 / 255.0, 145.0 / 255.0, 1.0)
const EQUIPMENT_COLOR_BELT := Color(1.0, 215.0 / 255.0, 100.0 / 255.0)
const EQUIPMENT_COLOR_BACK := Color(125.0 / 255.0, 220.0 / 255.0, 1.0)
const EQUIPMENT_COLOR_KNEE := Color(120.0 / 255.0, 1.0, 205.0 / 255.0)
const EQUIPMENT_COLOR_SHOES := Color(115.0 / 255.0, 230.0 / 255.0, 150.0 / 255.0)
const EQUIPMENT_COLOR_ACCESSORY := Color(220.0 / 255.0, 175.0 / 255.0, 1.0)
const BASE_ACCESSORY_SLOT_COUNT := 2
const BASE_ACTIVE_ITEM_SLOT_COUNT := 3
const UI_TEXT_SCALE := 1.12
const OPEN_ANIMATION_DURATION := 0.14
const MOUSE_MOTION_REDRAW_DISTANCE := 32.0
const MOUSE_MOTION_REDRAW_DISTANCE_SQ := MOUSE_MOTION_REDRAW_DISTANCE * MOUSE_MOTION_REDRAW_DISTANCE
const UI_FONT_SIZE_CACHE_LIMIT := 64
const FALLBACK_SYMBOL_LETTER_CACHE_LIMIT := 256
const TEXT_SIZE_CACHE_LIMIT := 2048
const CENTERED_TEXT_SIZE_CACHE_LIMIT := 256
const WRAP_TEXT_CACHE_LIMIT := 1024
const PASSIVE_FRAME_COLOR_CACHE_LIMIT := 128
const PASSIVE_INVENTORY_COLUMN_TARGET := 84.0
const STAT_ROW_COUNT := 9
const LINGPET_HATCH_REQUIRED_HITS := 2
const CHARACTER_CARD_GLOW_LAYERS := 1
const CHARACTER_CARD_RING_SEGMENTS := 12
const FALLBACK_SYMBOL_RING_SEGMENTS := 8
const EQUIPMENT_BODY_RING_SEGMENTS := 4
const EQUIPMENT_BODY_ARC_SEGMENTS := 3
const EQUIPMENT_EMPTY_RING_SEGMENTS := 3
const EQUIPMENT_PLACEHOLDER_ARC_SEGMENTS := 3
const EQUIPMENT_ACCESSORY_RING_SEGMENTS := 3
const EXTRA_ACTIVE_ITEM_PREWARM_NAMES := [
	"ammo_box",
	"doping_potion",
	"elixir_of_mastery",
]
const EQUIPMENT_SLOT_DEFINITIONS := [
	{"key": "head", "label": "머리", "base": "head"},
	{"key": "top", "label": "상의", "base": "top"},
	{"key": "left_arm", "label": "왼팔", "base": "arm"},
	{"key": "right_arm", "label": "오른팔", "base": "arm"},
	{"key": "belt", "label": "벨트", "base": "belt"},
	{"key": "belt2", "label": "등", "base": "back"},
	{"key": "knee", "label": "무릎", "base": "knee"},
	{"key": "shoes", "label": "신발", "base": "shoes"},
	{"key": "accessory1", "label": "장신구 1", "base": "accessory"},
	{"key": "accessory2", "label": "장신구 2", "base": "accessory"},
	{"key": "accessory3", "label": "장신구 3", "base": "accessory"},
	{"key": "accessory4", "label": "장신구 4", "base": "accessory"},
]

var active := false
var animation_time := 0.0
var perk_scroll := 0.0
var passive_inventory_scroll := 0.0
var _last_perk_grid_rect := Rect2()
var _last_perk_content_height := 0.0
var _last_passive_inventory_rect := Rect2()
var _last_passive_inventory_grid_rect := Rect2()
var _last_passive_inventory_content_height := 0.0
var _last_equipment_rect := Rect2()
var _last_skill_rect := Rect2()
var _last_active_items_rect := Rect2()
var _last_lingpet_skill_icon_rects: Array[Rect2] = []
var _last_lingpet_stat_row_rects: Array[Rect2] = []
var _last_equipment_slot_rects: Dictionary = {}
var _equipment_hover_uses_indexed_layout := false
var _equipment_layout_content_rect := Rect2()
var _equipment_layout_slot_size := -1.0
var _equipment_slot_rect_cache: Dictionary = {}
var _equipment_slot_rect_list_cache: Array[Rect2] = []
var _equipment_slot_icon_rect_cache: Array[Rect2] = []
var _equipment_slot_fallback_rect_cache: Array[Rect2] = []
var _equipment_slot_placeholder_rect_cache: Array[Rect2] = []
var _equipment_slot_locked_line_a_start_cache: Array[Vector2] = []
var _equipment_slot_locked_line_a_end_cache: Array[Vector2] = []
var _equipment_slot_locked_line_b_start_cache: Array[Vector2] = []
var _equipment_slot_locked_line_b_end_cache: Array[Vector2] = []
var _equipment_slot_center_x_cache: Array[float] = []
var _equipment_slot_center_y_cache: Array[float] = []
var _equipment_slot_label_y_cache: Array[float] = []
var _equipment_slot_index_cache: Dictionary = {}
var _equipment_slot_keys: Array[String] = []
var _equipment_slot_labels: Array[String] = []
var _equipment_slot_compact_labels: Array[String] = []
var _equipment_slot_visible_label_cache: Array[String] = []
var _equipment_slot_visible_label_cache_compact := false
var _equipment_slot_bases: Array[String] = []
var _equipment_slot_accessory_numbers: Array[int] = []
var _equipment_slot_empty_colors: Array[Color] = []
var _equipment_slot_empty_border_colors: Array[Color] = []
var _equipment_slot_item_cache: Array[Dictionary] = []
var _equipment_slot_has_item_cache: Array[bool] = []
var _equipment_slot_enabled_cache: Array[bool] = []
var _equipment_slot_label_color_cache: Array[Color] = []
var _equipment_slot_base_color_cache: Array[Color] = []
var _equipment_slot_border_color_cache: Array[Color] = []
var _equipment_slot_fill_color_cache: Array[Color] = []
var _equipment_slot_border_width_cache: Array[float] = []
var _equipment_slot_locked_line_color_cache: Array[Color] = []
var _equipment_slot_frame_cache_slot_state_hash := 0
var _equipment_slot_frame_cache_accessory_slot_count := -1
var _equipment_slot_frame_cache_slot_count := -1
var _empty_equipment_item: Dictionary = {}
var _equipment_silhouette_content_rect := Rect2()
var _equipment_silhouette_slot_size := -1.0
var _equipment_silhouette_body_x := 0.0
var _equipment_silhouette_bottom_y := 0.0
var _equipment_silhouette_head_center := Vector2.ZERO
var _equipment_silhouette_neck_rect := Rect2()
var _equipment_silhouette_shoulder_y := 0.0
var _equipment_silhouette_waist_y := 0.0
var _equipment_silhouette_hip_y := 0.0
var _equipment_silhouette_shoulder_w := 0.0
var _equipment_silhouette_waist_w := 0.0
var _equipment_silhouette_torso_poly := PackedVector2Array()
var _equipment_silhouette_left_arm_poly := PackedVector2Array()
var _equipment_silhouette_right_arm_poly := PackedVector2Array()
var _equipment_silhouette_left_leg_poly := PackedVector2Array()
var _equipment_silhouette_right_leg_poly := PackedVector2Array()
var _active_item_catalog: Object = ActiveItemCatalog.new()
var _active_item_icon_renderer: Object = ActiveItemHudSlotIconRenderer.new()
var _character_runtime: Object = PlayerCharacterRuntime.new()
var _lingpet_art_texture_cache: Dictionary = {}
var _lingpet_skill_icon_texture_cache: Dictionary = {}
var _lingpet_stats_cache_hash := 0
var _lingpet_stats_cache_ready := false
var _lingpet_stats_cache: Array = []
var _shared_icon_assets_prewarmed := false
var _static_text_prewarmed := false
var _active_item_text_prewarmed := false
var _runtime_perk_text_prewarmed := false
var _skill_text_prewarmed := false
var _passive_inventory_icon_prewarm_items_hash := 0
var _passive_inventory_icon_prewarm_item_count := -1
var _passive_inventory_draw_cache_items_hash := 0
var _passive_inventory_draw_cache_item_count := -1
var _passive_inventory_summary_count := -1
var _passive_inventory_summary_equipped := -1
var _passive_inventory_summary: Dictionary = {"count": 0, "equipped": 0, "count_text": "보유 0 / 장착 0"}
var _header_subtitle_character_type := ""
var _header_subtitle_display_name := ""
var _header_subtitle_text := ""
var _header_status_pending := -1
var _header_status_gold := -1
var _header_status_language := ""
var _header_status_text := ""
var _header_status_width_text := ""
var _header_status_width_size := 0
var _header_status_width_font_id := 0
var _header_status_width := 0.0
var _passive_inventory_count_text_width := 0.0
var _passive_inventory_count_text_width_text := ""
var _passive_inventory_count_text_width_size := 0
var _passive_inventory_count_text_width_font_id := 0
var _passive_item_frame_color_cache: Dictionary = {}
var _passive_item_body_cache_hash := 0
var _passive_item_body_cache_ready := false
var _passive_item_body_cache := ""
var _passive_item_roll_entries_cache_item_hash := 0
var _passive_item_roll_entries_cache_runtime_id := 0
var _passive_item_roll_entries_cache_polish_multiplier := -1.0
var _passive_item_roll_entries_cache: Array = []
var _passive_item_roll_entry_dict_cache: Array = []
var _equipment_item_display_name_cache_hash := 0
var _equipment_item_display_name_cache_ready := false
var _equipment_item_display_name_cache := ""
var _item_quality_color_cache_hash := 0
var _item_quality_color_cache_ready := false
var _item_quality_color_cache := Color.WHITE
var _tooltip_subtitle_color_source := Color.TRANSPARENT
var _tooltip_subtitle_color_cache := Color.WHITE
var _tooltip_entry_lines_cache_entries_hash := 0
var _tooltip_entry_lines_cache_size := 0
var _tooltip_entry_lines_cache_width := 0
var _tooltip_entry_lines_cache_max_lines := 0
var _tooltip_entry_lines_cache: Array = []
var _tooltip_entry_line_dict_cache: Array = []
var _tooltip_entry_line_text_cache: Array[String] = []
var _tooltip_entry_line_color_cache: Array[Color] = []
var _empty_tooltip_roll_entries: Array = []
var _ui_font_size_cache: Array[int] = []
var _fallback_symbol_letter_cache: Dictionary = {}
var _text_size_cache: Dictionary = {}
var _text_size_fast_text := ""
var _text_size_fast_ui_size := 0
var _text_size_fast_value := Vector2.ZERO
var _wrap_text_cache: Dictionary = {}
var _wrap_text_fast_text := ""
var _wrap_text_fast_size := 0
var _wrap_text_fast_width := 0
var _wrap_text_fast_max_lines := 0
var _wrap_text_fast_lines: Array = []
var _acquired_perk_cache_hash := 0
var _acquired_perk_cache_ready := false
var _acquired_perk_cache: Array = []
var _acquired_perk_draw_id_cache: Array[String] = []
var _acquired_perk_draw_color_cache: Array[Color] = []
var _acquired_perk_border_color_cache: Array[Color] = []
var _acquired_perk_hover_border_color_cache: Array[Color] = []
var _acquired_perk_level_text_cache: Array[String] = []
var _acquired_perk_level_color_cache: Array[Color] = []
var _acquired_perk_hover_title_cache: Array[String] = []
var _acquired_perk_hover_body_cache: Array[String] = []
var _perk_level_text_size_cache_texts: Array[String] = []
var _perk_level_text_size_cache_sizes: Array[int] = []
var _perk_level_text_size_cache_font_ids: Array[int] = []
var _perk_level_text_size_cache_values: Array[Vector2] = []
var _perk_level_text_size_fast_text := ""
var _perk_level_text_size_fast_size := 0
var _perk_level_text_size_fast_font_id := 0
var _perk_level_text_size_fast_value := Vector2.ZERO
var _centered_text_size_cache_texts: Array[String] = []
var _centered_text_size_cache_sizes: Array[int] = []
var _centered_text_size_cache_font_ids: Array[int] = []
var _centered_text_size_cache_values: Array[Vector2] = []
var _centered_text_size_fast_text := ""
var _centered_text_size_fast_size := 0
var _centered_text_size_fast_font_id := 0
var _centered_text_size_fast_value := Vector2.ZERO
var _skill_slot_layout_rect := Rect2()
var _skill_slot_layout_count := -1
var _skill_slot_layout_slot_size := -1.0
var _skill_slot_rect_cache: Array[Rect2] = []
var _skill_slot_icon_rect_cache: Array[Rect2] = []
var _skill_slot_fallback_rect_cache: Array[Rect2] = []
var _skill_slot_center_cache: Array[Vector2] = []
var _skill_slot_center_x_cache: Array[float] = []
var _skill_slot_label_y := 0.0
var _skill_slot_draw_cache_equipped_hash := 0
var _skill_slot_draw_cache_skill_data_hash := 0
var _skill_slot_draw_cache_fallback_color := Color.TRANSPARENT
var _skill_slot_id_cache: Array[String] = []
var _skill_slot_data_cache: Array[Dictionary] = []
var _skill_slot_label_cache: Array[String] = []
var _skill_slot_color_cache: Array[Color] = []
var _skill_slot_fill_color_cache: Array[Color] = []
var _skill_slot_border_color_cache: Array[Color] = []
var _active_item_label_cache_names: Array[String] = []
var _active_item_label_cache_raw_display_names: Array[String] = []
var _active_item_display_name_cache: Array[String] = []
var _active_item_trimmed_label_cache: Array[String] = []
var _active_slot_draw_cache_slots_hash := 0
var _active_slot_draw_cache_max_slots := -1
var _active_slot_draw_cache_visuals_id := -1
var _active_slot_draw_cache_should_cache_colors := false
var _active_slot_has_item_cache: Array[bool] = []
var _active_slot_item_cache: Array[Dictionary] = []
var _active_slot_fallback_color_cache: Array[Color] = []
var _active_slot_has_fallback_color_cache: Array[bool] = []
var _active_slot_layout_rect := Rect2()
var _active_slot_layout_count := -1
var _active_slot_layout_slot_size := -1.0
var _active_slot_layout_gap := -1.0
var _active_slot_rect_cache: Array[Rect2] = []
var _active_slot_fallback_rect_cache: Array[Rect2] = []
var _active_slot_center_x_cache: Array[float] = []
var _active_slot_empty_marker_y := 0.0
var _active_slot_label_y := 0.0
var _passive_grid_layout_rect := Rect2()
var _passive_grid_layout_scroll := -1.0
var _passive_grid_layout_columns := -1
var _passive_grid_layout_cell_size := -1.0
var _passive_grid_layout_stride := -1.0
var _passive_grid_layout_item_count := -1
var _passive_grid_visible_first_row := 0
var _passive_grid_visible_last_row := -1
var _passive_grid_visible_index_cache: Array[int] = []
var _passive_grid_cell_rect_cache: Array[Rect2] = []
var _passive_grid_icon_rect_cache: Array[Rect2] = []
var _passive_grid_fallback_rect_cache: Array[Rect2] = []
var _passive_grid_badge_rect_cache: Array[Rect2] = []
var _passive_grid_badge_center_x_cache: Array[float] = []
var _passive_grid_badge_center_y_cache: Array[float] = []
var _passive_inventory_item_cache: Array[Dictionary] = []
var _passive_inventory_draw_color_cache: Array[Color] = []
var _passive_inventory_border_color_cache: Array[Color] = []
var _passive_inventory_active_border_color_cache: Array[Color] = []
var _passive_inventory_equipped_cache: Array[bool] = []
var _passive_scrollbar_layout_rect := Rect2()
var _passive_scrollbar_layout_max_scroll := -1.0
var _passive_scrollbar_layout_content_height := -1.0
var _passive_scrollbar_layout_scroll := -1.0
var _passive_scrollbar_track_rect := Rect2()
var _passive_scrollbar_thumb_rect := Rect2()
var _perk_grid_layout_rect := Rect2()
var _perk_grid_layout_scroll := -1.0
var _perk_grid_layout_columns := -1
var _perk_grid_layout_cell_size := -1.0
var _perk_grid_layout_stride := -1.0
var _perk_grid_layout_item_count := -1
var _perk_grid_visible_first_row := 0
var _perk_grid_visible_last_row := -1
var _perk_grid_visible_index_cache: Array[int] = []
var _perk_grid_cell_rect_cache: Array[Rect2] = []
var _perk_grid_icon_rect_cache: Array[Rect2] = []
var _perk_grid_center_x_cache: Array[float] = []
var _perk_grid_level_y_cache: Array[float] = []
var _perk_scrollbar_layout_rect := Rect2()
var _perk_scrollbar_layout_max_scroll := -1.0
var _perk_scrollbar_layout_content_height := -1.0
var _perk_scrollbar_layout_scroll := -1.0
var _perk_scrollbar_track_rect := Rect2()
var _perk_scrollbar_thumb_rect := Rect2()
var _stats_row_cache: Array = []
var _stats_row_count := 0
var _stats_label_cache: Array[String] = []
var _stats_value_cache: Array[String] = []
var _stats_color_cache: Array[Color] = []
var _stats_value_width_cache: Array[float] = []
var _stats_value_width_text_cache: Array[String] = []
var _stats_value_width_size_cache: Array[int] = []
var _stats_value_width_font_id_cache: Array[int] = []
var _stats_layout_rect := Rect2()
var _stats_layout_count := -1
var _stats_layout_label_x: Array[float] = []
var _stats_layout_baseline_y: Array[float] = []
var _stats_layout_value_right_x: Array[float] = []
var _stats_layout_row_size := 13
var _stats_layout_visible_count := 0
var _frame_stat_sources: Array = []
var _frame_hover_data: Dictionary = {}
var _layout_view_size := Vector2(-1.0, -1.0)
var _layout_panel_rect := Rect2()
var _layout_equipment_rect := Rect2()
var _layout_skill_rect := Rect2()
var _layout_active_items_rect := Rect2()
var _layout_perk_rect := Rect2()
var _layout_lingpet_rect := Rect2()
var _layout_stats_rect := Rect2()
var _layout_inventory_rect := Rect2()
var _last_passive_grid_start := Vector2.ZERO
var _last_passive_grid_cell_size := 0.0
var _last_passive_grid_stride := 0.0
var _last_passive_grid_columns := 0
var _last_passive_grid_item_count := 0
var _last_perk_grid_start := Vector2.ZERO
var _last_perk_grid_cell_size := 0.0
var _last_perk_grid_stride := 0.0
var _last_perk_grid_columns := 0
var _last_perk_grid_item_count := 0
var _last_skill_slot_start := Vector2.ZERO
var _last_skill_slot_size := 0.0
var _last_skill_slot_stride := 0.0
var _last_skill_slot_count := 0
var _last_active_slot_start := Vector2.ZERO
var _last_active_slot_size := 0.0
var _last_active_slot_stride := 0.0
var _last_active_slot_count := 0
var _redraw_requested := false
var _input_redraw_requested := false
var _last_hover_signature := ""
var _last_mouse_redraw_position := Vector2.ZERO
var _has_mouse_redraw_position := false
var _skill_cooldown_pause_active := false
var _skill_cooldown_pause_owner: Object = null
var _skill_cooldown_pause_registry: Object = null


func is_active() -> bool:
	return active


func open(owner: Object = null, registry: Object = null) -> void:
	active = true
	animation_time = 0.0
	perk_scroll = 0.0
	passive_inventory_scroll = 0.0
	_pause_skill_cooldowns_for_overlay(owner, registry)
	_reset_mouse_hover_tracking()
	_request_redraw()


func close(from_input: bool = false) -> void:
	_resume_skill_cooldowns_for_overlay()
	active = false
	_reset_mouse_hover_tracking()
	_request_redraw(from_input)


func toggle(owner: Object = null, registry: Object = null) -> void:
	if active:
		close()
	else:
		open(owner, registry)


func update(delta: float) -> bool:
	if not active:
		return false
	var was_animating: bool = animation_time < OPEN_ANIMATION_DURATION
	animation_time = min(OPEN_ANIMATION_DURATION, animation_time + delta)
	if was_animating:
		if animation_time >= OPEN_ANIMATION_DURATION:
			_redraw_requested = false
		return true
	if _redraw_requested:
		_redraw_requested = false
		return true
	return false


func consume_input_redraw_request() -> bool:
	var requested: bool = _input_redraw_requested
	_input_redraw_requested = false
	if requested:
		_redraw_requested = false
	return requested


func _request_redraw(from_input: bool = false) -> void:
	_redraw_requested = true
	if from_input:
		_input_redraw_requested = true


func _reset_mouse_hover_tracking() -> void:
	_last_hover_signature = ""
	_has_mouse_redraw_position = false
	_last_mouse_redraw_position = Vector2.ZERO


func _pause_skill_cooldowns_for_overlay(owner: Object, registry: Object) -> void:
	if _skill_cooldown_pause_active or owner == null or registry == null:
		return
	var skill_tooltip_driver: Object = _get_instance(registry, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver == null or not skill_tooltip_driver.has_method("pause_skill_cooldowns"):
		return
	skill_tooltip_driver.pause_skill_cooldowns(owner, registry)
	_skill_cooldown_pause_active = true
	_skill_cooldown_pause_owner = owner
	_skill_cooldown_pause_registry = registry


func _resume_skill_cooldowns_for_overlay() -> void:
	if not _skill_cooldown_pause_active:
		return
	var registry: Object = _skill_cooldown_pause_registry
	var owner: Object = _skill_cooldown_pause_owner
	_skill_cooldown_pause_active = false
	_skill_cooldown_pause_owner = null
	_skill_cooldown_pause_registry = null
	var skill_tooltip_driver: Object = _get_instance(registry, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("resume_skill_cooldowns"):
		skill_tooltip_driver.resume_skill_cooldowns(owner, registry)


func _should_redraw_for_mouse_motion(mouse_pos: Vector2) -> bool:
	var hover_signature: String = _get_hover_signature(mouse_pos)
	var previous_hover_signature: String = _last_hover_signature
	if hover_signature != _last_hover_signature:
		_last_hover_signature = hover_signature
		_last_mouse_redraw_position = mouse_pos
		_has_mouse_redraw_position = true
		return _hover_signature_has_visual(previous_hover_signature) or _hover_signature_has_visual(hover_signature)
	if not _hover_signature_has_visual(hover_signature):
		_last_mouse_redraw_position = mouse_pos
		_has_mouse_redraw_position = true
		return false
	if not _has_mouse_redraw_position:
		_last_mouse_redraw_position = mouse_pos
		_has_mouse_redraw_position = true
		return true
	if mouse_pos.distance_squared_to(_last_mouse_redraw_position) >= MOUSE_MOTION_REDRAW_DISTANCE_SQ:
		_last_mouse_redraw_position = mouse_pos
		return true
	return false


func _hover_signature_has_visual(signature: String) -> bool:
	return signature.find(":") >= 0


func _get_hover_signature(mouse_pos: Vector2) -> String:
	if _hover_signature_has_visual(_last_hover_signature) and _hover_signature_contains_mouse(_last_hover_signature, mouse_pos):
		return _last_hover_signature
	if _last_equipment_rect.has_point(mouse_pos):
		var equipment_signature: String = _get_equipment_hover_signature(mouse_pos)
		if equipment_signature != "":
			return equipment_signature
	if _last_skill_rect.has_point(mouse_pos):
		var skill_signature: String = _get_cached_linear_hover_signature(
			mouse_pos,
			_last_skill_slot_start,
			_last_skill_slot_size,
			_last_skill_slot_stride,
			_last_skill_slot_count,
			"skill"
		)
		if skill_signature != "":
			return skill_signature
	if _last_active_items_rect.has_point(mouse_pos):
		var active_item_signature: String = _get_cached_linear_hover_signature(
			mouse_pos,
			_last_active_slot_start,
			_last_active_slot_size,
			_last_active_slot_stride,
			_last_active_slot_count,
			"active_item"
		)
		if active_item_signature != "":
			return active_item_signature
	if _last_passive_inventory_rect.has_point(mouse_pos):
		var passive_signature: String = _get_cached_grid_hover_signature(
			mouse_pos,
			_last_passive_inventory_grid_rect,
			_last_passive_grid_start,
			_last_passive_grid_cell_size,
			_last_passive_grid_stride,
			_last_passive_grid_columns,
			_last_passive_grid_item_count,
			"passive_item"
		)
		if passive_signature != "":
			return passive_signature
		return "passive_inventory"
	if _last_perk_grid_rect.has_point(mouse_pos):
		var perk_signature: String = _get_cached_grid_hover_signature(
			mouse_pos,
			_last_perk_grid_rect,
			_last_perk_grid_start,
			_last_perk_grid_cell_size,
			_last_perk_grid_stride,
			_last_perk_grid_columns,
			_last_perk_grid_item_count,
			"perk"
		)
		if perk_signature != "":
			return perk_signature
		return "perk_grid"
	var lingpet_skill_signature: String = _get_lingpet_skill_hover_signature(mouse_pos)
	if lingpet_skill_signature != "":
		return lingpet_skill_signature
	var lingpet_stat_signature: String = _get_lingpet_stat_hover_signature(mouse_pos)
	if lingpet_stat_signature != "":
		return lingpet_stat_signature
	return ""


func _hover_signature_contains_mouse(signature: String, mouse_pos: Vector2) -> bool:
	if signature == "passive_inventory":
		return _last_passive_inventory_rect.has_point(mouse_pos)
	if signature == "perk_grid":
		return _last_perk_grid_rect.has_point(mouse_pos)
	var delimiter: int = signature.find(":")
	if delimiter < 0:
		return false
	var prefix: String = signature.substr(0, delimiter)
	var key_text: String = signature.substr(delimiter + 1)
	match prefix:
		"equipment":
			return _equipment_signature_contains_mouse(key_text, mouse_pos)
		"skill":
			return _cached_linear_signature_contains_mouse(
				key_text,
				mouse_pos,
				_last_skill_slot_start,
				_last_skill_slot_size,
				_last_skill_slot_stride,
				_last_skill_slot_count
			)
		"active_item":
			return _cached_linear_signature_contains_mouse(
				key_text,
				mouse_pos,
				_last_active_slot_start,
				_last_active_slot_size,
				_last_active_slot_stride,
				_last_active_slot_count
			)
		"passive_item":
			return _cached_grid_signature_contains_mouse(
				key_text,
				mouse_pos,
				_last_passive_inventory_grid_rect,
				_last_passive_grid_start,
				_last_passive_grid_cell_size,
				_last_passive_grid_stride,
				_last_passive_grid_columns,
				_last_passive_grid_item_count
			)
		"perk":
			return _cached_grid_signature_contains_mouse(
				key_text,
				mouse_pos,
				_last_perk_grid_rect,
				_last_perk_grid_start,
				_last_perk_grid_cell_size,
				_last_perk_grid_stride,
				_last_perk_grid_columns,
				_last_perk_grid_item_count
			)
		"lingpet_skill":
			return _lingpet_skill_signature_contains_mouse(key_text, mouse_pos)
		"lingpet_stat":
			return _lingpet_stat_signature_contains_mouse(key_text, mouse_pos)
	return false


func _get_lingpet_skill_hover_signature(mouse_pos: Vector2) -> String:
	for i in range(_last_lingpet_skill_icon_rects.size()):
		if _last_lingpet_skill_icon_rects[i].has_point(mouse_pos):
			return "lingpet_skill:%d" % i
	return ""


func _lingpet_skill_signature_contains_mouse(key_text: String, mouse_pos: Vector2) -> bool:
	if not key_text.is_valid_int():
		return false
	var index: int = int(key_text)
	if index < 0 or index >= _last_lingpet_skill_icon_rects.size():
		return false
	return _last_lingpet_skill_icon_rects[index].has_point(mouse_pos)


func _get_lingpet_stat_hover_signature(mouse_pos: Vector2) -> String:
	for i in range(_last_lingpet_stat_row_rects.size()):
		if _last_lingpet_stat_row_rects[i].has_point(mouse_pos):
			return "lingpet_stat:%d" % i
	return ""


func _lingpet_stat_signature_contains_mouse(key_text: String, mouse_pos: Vector2) -> bool:
	if not key_text.is_valid_int():
		return false
	var index: int = int(key_text)
	if index < 0 or index >= _last_lingpet_stat_row_rects.size():
		return false
	return _last_lingpet_stat_row_rects[index].has_point(mouse_pos)


func _get_equipment_hover_signature(mouse_pos: Vector2) -> String:
	var slot_index: int = _find_hovered_equipment_slot_index(mouse_pos)
	if slot_index >= 0:
		var key_text := str(slot_index)
		if slot_index < _equipment_slot_keys.size():
			key_text = _equipment_slot_keys[slot_index]
		return "equipment:%s" % key_text
	if _has_indexed_equipment_hover_layout():
		return ""
	return _get_rect_map_hover_signature(_last_equipment_slot_rects, mouse_pos, "equipment")


func _equipment_signature_contains_mouse(key_text: String, mouse_pos: Vector2) -> bool:
	var slot_index := -1
	if key_text.is_valid_int():
		slot_index = int(key_text)
	else:
		slot_index = int(_equipment_slot_index_cache.get(key_text, -1))
	if slot_index >= 0 and slot_index < _equipment_slot_rect_list_cache.size():
		return _equipment_slot_rect_list_cache[slot_index].has_point(mouse_pos)
	if _has_indexed_equipment_hover_layout():
		return false
	return _rect_map_key_contains_mouse(_last_equipment_slot_rects, key_text, mouse_pos)


func _has_indexed_equipment_hover_layout() -> bool:
	return (
		_equipment_hover_uses_indexed_layout
		and not _equipment_slot_keys.is_empty()
		and _equipment_slot_rect_list_cache.size() == _equipment_slot_keys.size()
	)


func _rect_map_key_contains_mouse(rects: Dictionary, key_text: String, mouse_pos: Vector2) -> bool:
	var rect_value: Variant = rects.get(key_text, null)
	if rect_value == null and key_text.is_valid_int():
		rect_value = rects.get(int(key_text), null)
	if not (rect_value is Rect2):
		return false
	var rect: Rect2 = rect_value
	return rect.has_point(mouse_pos)


func _get_rect_map_hover_signature(rects: Dictionary, mouse_pos: Vector2, prefix: String) -> String:
	for key_value in rects:
		var rect_value: Variant = rects[key_value]
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.has_point(mouse_pos):
				return prefix + ":" + str(key_value)
	return ""


func _set_passive_grid_hover_layout(start: Vector2, cell_size: float, stride: float, columns: int, item_count: int) -> void:
	_last_passive_grid_start = start
	_last_passive_grid_cell_size = cell_size
	_last_passive_grid_stride = stride
	_last_passive_grid_columns = columns
	_last_passive_grid_item_count = item_count


func _set_perk_grid_hover_layout(start: Vector2, cell_size: float, stride: float, columns: int, item_count: int) -> void:
	_last_perk_grid_start = start
	_last_perk_grid_cell_size = cell_size
	_last_perk_grid_stride = stride
	_last_perk_grid_columns = columns
	_last_perk_grid_item_count = item_count


func _set_skill_slot_hover_layout(start: Vector2, slot_size: float, stride: float, slot_count: int) -> void:
	_last_skill_slot_start = start
	_last_skill_slot_size = slot_size
	_last_skill_slot_stride = stride
	_last_skill_slot_count = slot_count


func _update_skill_slot_layout(rect: Rect2, slot_size: float, max_slots: int) -> void:
	if (
		rect == _skill_slot_layout_rect
		and max_slots == _skill_slot_layout_count
		and is_equal_approx(slot_size, _skill_slot_layout_slot_size)
	):
		return
	_skill_slot_layout_rect = rect
	_skill_slot_layout_count = max_slots
	_skill_slot_layout_slot_size = slot_size
	_skill_slot_rect_cache.resize(max_slots)
	_skill_slot_icon_rect_cache.resize(max_slots)
	_skill_slot_fallback_rect_cache.resize(max_slots)
	_skill_slot_center_cache.resize(max_slots)
	_skill_slot_center_x_cache.resize(max_slots)
	var skill_slot_step: float = slot_size + 8.0
	var start_x: float = rect.position.x + (rect.size.x - (slot_size * float(max_slots) + 8.0 * float(max_slots - 1))) * 0.5
	var slot_y: float = rect.position.y + 42.0
	_skill_slot_label_y = slot_y + slot_size + 15.0
	_set_skill_slot_hover_layout(Vector2(start_x, slot_y), slot_size, skill_slot_step, max_slots)
	for i in range(max_slots):
		var slot_x: float = start_x + float(i) * skill_slot_step
		_skill_slot_rect_cache[i] = Rect2(slot_x, slot_y, slot_size, slot_size)
		_skill_slot_icon_rect_cache[i] = Rect2(slot_x + 5.0, slot_y + 5.0, slot_size - 10.0, slot_size - 10.0)
		_skill_slot_fallback_rect_cache[i] = Rect2(slot_x + 9.0, slot_y + 9.0, slot_size - 18.0, slot_size - 18.0)
		_skill_slot_center_x_cache[i] = slot_x + slot_size * 0.5
		_skill_slot_center_cache[i] = Vector2(_skill_slot_center_x_cache[i], slot_y + slot_size * 0.5)


func _refresh_skill_slot_draw_cache(equipped: Array, skill_data: Dictionary, fallback_skill_color: Color) -> void:
	var equipped_hash: int = hash(equipped)
	var skill_data_hash: int = hash(skill_data)
	if _skill_slot_draw_cache_matches(equipped_hash, skill_data_hash, fallback_skill_color, equipped.size()):
		return
	_skill_slot_draw_cache_equipped_hash = equipped_hash
	_skill_slot_draw_cache_skill_data_hash = skill_data_hash
	_skill_slot_draw_cache_fallback_color = fallback_skill_color
	_skill_slot_id_cache.resize(equipped.size())
	_skill_slot_data_cache.resize(equipped.size())
	_skill_slot_label_cache.resize(equipped.size())
	_skill_slot_color_cache.resize(equipped.size())
	_skill_slot_fill_color_cache.resize(equipped.size())
	_skill_slot_border_color_cache.resize(equipped.size())
	for i in range(equipped.size()):
		var skill_id: String = str(equipped[i])
		var data: Dictionary = _get_dict(skill_data.get(skill_id, {}))
		var color: Color = _get_color(data.get("color", fallback_skill_color))
		_skill_slot_id_cache[i] = skill_id
		_skill_slot_data_cache[i] = data
		_skill_slot_label_cache[i] = _short_skill_name(data, skill_id)
		_skill_slot_color_cache[i] = color
		_skill_slot_fill_color_cache[i] = Color(
			OVERLAY_SLOT_FILL.r * 0.88 + color.r * 0.12,
			OVERLAY_SLOT_FILL.g * 0.88 + color.g * 0.12,
			OVERLAY_SLOT_FILL.b * 0.88 + color.b * 0.12,
			OVERLAY_SLOT_FILL.a
		)
		_skill_slot_border_color_cache[i] = Color(color.r, color.g, color.b, 0.72)


func _skill_slot_draw_cache_matches(equipped_hash: int, skill_data_hash: int, fallback_skill_color: Color, equipped_count: int) -> bool:
	return (
		equipped_hash == _skill_slot_draw_cache_equipped_hash
		and skill_data_hash == _skill_slot_draw_cache_skill_data_hash
		and fallback_skill_color == _skill_slot_draw_cache_fallback_color
		and _skill_slot_id_cache.size() == equipped_count
	)


func _set_active_slot_hover_layout(start: Vector2, slot_size: float, stride: float, slot_count: int) -> void:
	_last_active_slot_start = start
	_last_active_slot_size = slot_size
	_last_active_slot_stride = stride
	_last_active_slot_count = slot_count


func _update_active_slot_layout(rect: Rect2, slot_size: float, gap: float, max_slots: int) -> void:
	if (
		rect == _active_slot_layout_rect
		and max_slots == _active_slot_layout_count
		and is_equal_approx(slot_size, _active_slot_layout_slot_size)
		and is_equal_approx(gap, _active_slot_layout_gap)
	):
		return
	_active_slot_layout_rect = rect
	_active_slot_layout_count = max_slots
	_active_slot_layout_slot_size = slot_size
	_active_slot_layout_gap = gap
	_active_slot_rect_cache.resize(max_slots)
	_active_slot_fallback_rect_cache.resize(max_slots)
	_active_slot_center_x_cache.resize(max_slots)
	var y: float = rect.position.y + 44.0
	var active_slot_start_x: float = rect.position.x + gap
	var active_slot_step: float = slot_size + gap
	_active_slot_empty_marker_y = y + slot_size * 0.5 + 5.0
	_active_slot_label_y = y + slot_size + 16.0
	_set_active_slot_hover_layout(Vector2(active_slot_start_x, y), slot_size, active_slot_step, max_slots)
	for i in range(max_slots):
		var slot_x: float = active_slot_start_x + float(i) * active_slot_step
		_active_slot_rect_cache[i] = Rect2(slot_x, y, slot_size, slot_size)
		_active_slot_fallback_rect_cache[i] = Rect2(slot_x + 10.0, y + 10.0, slot_size - 20.0, slot_size - 20.0)
		_active_slot_center_x_cache[i] = slot_x + slot_size * 0.5


func _refresh_active_slot_draw_cache(slots: Array, max_slots: int, visuals: Object, should_cache_colors: bool) -> void:
	var slots_hash: int = hash(slots)
	var visuals_id: int = visuals.get_instance_id() if visuals != null else 0
	if _active_slot_draw_cache_matches(slots_hash, max_slots, visuals_id, should_cache_colors):
		return
	_active_slot_draw_cache_slots_hash = slots_hash
	_active_slot_draw_cache_max_slots = max_slots
	_active_slot_draw_cache_visuals_id = visuals_id
	_active_slot_draw_cache_should_cache_colors = should_cache_colors
	_active_slot_has_item_cache.resize(max_slots)
	_active_slot_item_cache.resize(max_slots)
	_active_slot_fallback_color_cache.resize(max_slots)
	_active_slot_has_fallback_color_cache.resize(max_slots)
	for i in range(max_slots):
		if i < slots.size() and slots[i] is Dictionary:
			var item_data: Dictionary = slots[i]
			_active_slot_has_item_cache[i] = true
			_active_slot_item_cache[i] = item_data
			if should_cache_colors:
				_active_slot_fallback_color_cache[i] = _get_item_color(item_data, visuals)
				_active_slot_has_fallback_color_cache[i] = true
			else:
				_active_slot_fallback_color_cache[i] = Color.WHITE
				_active_slot_has_fallback_color_cache[i] = false
		else:
			_active_slot_has_item_cache[i] = false
			_active_slot_item_cache[i] = {}
			_active_slot_fallback_color_cache[i] = Color.WHITE
			_active_slot_has_fallback_color_cache[i] = false


func _active_slot_draw_cache_matches(slots_hash: int, max_slots: int, visuals_id: int, should_cache_colors: bool) -> bool:
	return (
		slots_hash == _active_slot_draw_cache_slots_hash
		and max_slots == _active_slot_draw_cache_max_slots
		and visuals_id == _active_slot_draw_cache_visuals_id
		and should_cache_colors == _active_slot_draw_cache_should_cache_colors
		and _active_slot_has_item_cache.size() == max_slots
	)


func _update_passive_inventory_grid_layout(
	grid_rect: Rect2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int,
	scroll: float
) -> void:
	if (
		grid_rect == _passive_grid_layout_rect
		and item_count == _passive_grid_layout_item_count
		and columns == _passive_grid_layout_columns
		and is_equal_approx(cell_size, _passive_grid_layout_cell_size)
		and is_equal_approx(stride, _passive_grid_layout_stride)
		and is_equal_approx(scroll, _passive_grid_layout_scroll)
	):
		return
	_passive_grid_layout_rect = grid_rect
	_passive_grid_layout_item_count = item_count
	_passive_grid_layout_columns = columns
	_passive_grid_layout_cell_size = cell_size
	_passive_grid_layout_stride = stride
	_passive_grid_layout_scroll = scroll
	_passive_grid_cell_rect_cache.resize(item_count)
	_passive_grid_icon_rect_cache.resize(item_count)
	_passive_grid_fallback_rect_cache.resize(item_count)
	_passive_grid_badge_rect_cache.resize(item_count)
	_passive_grid_badge_center_x_cache.resize(item_count)
	_passive_grid_badge_center_y_cache.resize(item_count)
	var rows: int = int(ceil(float(item_count) / float(columns)))
	_passive_grid_visible_first_row = max(0, int(ceil(scroll / stride)))
	_passive_grid_visible_last_row = min(rows - 1, int(floor((scroll + grid_rect.size.y - cell_size) / stride)))
	_passive_grid_visible_index_cache.clear()
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - (cell_size * float(columns) + (stride - cell_size) * float(columns - 1))) * 0.5
	var start_y: float = grid_rect.position.y - scroll
	_set_passive_grid_hover_layout(Vector2(start_x, start_y), cell_size, stride, columns, item_count)
	for row in range(_passive_grid_visible_first_row, _passive_grid_visible_last_row + 1):
		var row_y: float = start_y + float(row) * stride
		if row_y < grid_rect.position.y or row_y + cell_size > grid_rect.end.y:
			continue
		for col in range(columns):
			var i: int = row * columns + col
			if i >= item_count:
				break
			var cell_x: float = start_x + float(col) * stride
			_passive_grid_cell_rect_cache[i] = Rect2(cell_x, row_y, cell_size, cell_size)
			_passive_grid_icon_rect_cache[i] = Rect2(cell_x + 5.0, row_y + 5.0, cell_size - 10.0, cell_size - 10.0)
			_passive_grid_fallback_rect_cache[i] = Rect2(cell_x + 9.0, row_y + 9.0, cell_size - 18.0, cell_size - 18.0)
			_passive_grid_badge_rect_cache[i] = Rect2(cell_x + cell_size - 18.0, row_y + cell_size - 14.0, 16.0, 12.0)
			_passive_grid_badge_center_x_cache[i] = cell_x + cell_size - 10.0
			_passive_grid_badge_center_y_cache[i] = row_y + cell_size - 6.0
			_passive_grid_visible_index_cache.append(i)


func _update_perk_grid_layout(
	grid_rect: Rect2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int,
	scroll: float
) -> void:
	if (
		grid_rect == _perk_grid_layout_rect
		and item_count == _perk_grid_layout_item_count
		and columns == _perk_grid_layout_columns
		and is_equal_approx(cell_size, _perk_grid_layout_cell_size)
		and is_equal_approx(stride, _perk_grid_layout_stride)
		and is_equal_approx(scroll, _perk_grid_layout_scroll)
	):
		return
	_perk_grid_layout_rect = grid_rect
	_perk_grid_layout_item_count = item_count
	_perk_grid_layout_columns = columns
	_perk_grid_layout_cell_size = cell_size
	_perk_grid_layout_stride = stride
	_perk_grid_layout_scroll = scroll
	_perk_grid_cell_rect_cache.resize(item_count)
	_perk_grid_icon_rect_cache.resize(item_count)
	_perk_grid_center_x_cache.resize(item_count)
	_perk_grid_level_y_cache.resize(item_count)
	var rows: int = int(ceil(float(item_count) / float(columns)))
	_perk_grid_visible_first_row = max(0, int(ceil((scroll - cell_size) / stride)))
	_perk_grid_visible_last_row = min(rows - 1, int(floor((scroll + grid_rect.size.y) / stride)))
	_perk_grid_visible_index_cache.clear()
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - (cell_size * float(columns) + (stride - cell_size) * float(columns - 1))) * 0.5
	var start_y: float = grid_rect.position.y - scroll
	var perk_icon_w: float = cell_size - 10.0
	var perk_icon_h: float = cell_size - 17.0
	_set_perk_grid_hover_layout(Vector2(start_x, start_y), cell_size, stride, columns, item_count)
	for row in range(_perk_grid_visible_first_row, _perk_grid_visible_last_row + 1):
		var row_y: float = start_y + float(row) * stride
		if row_y + cell_size < grid_rect.position.y or row_y > grid_rect.end.y:
			continue
		for col in range(columns):
			var i: int = row * columns + col
			if i >= item_count:
				break
			var cell_x: float = start_x + float(col) * stride
			_perk_grid_cell_rect_cache[i] = Rect2(cell_x, row_y, cell_size, cell_size)
			_perk_grid_icon_rect_cache[i] = Rect2(cell_x + 5.0, row_y + 4.0, perk_icon_w, perk_icon_h)
			_perk_grid_center_x_cache[i] = cell_x + cell_size * 0.5
			_perk_grid_level_y_cache[i] = row_y + cell_size - 4.0
			_perk_grid_visible_index_cache.append(i)


func _get_cached_grid_hover_signature(
	mouse_pos: Vector2,
	grid_rect: Rect2,
	start: Vector2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int,
	prefix: String
) -> String:
	var index: int = _get_cached_grid_hover_index(mouse_pos, grid_rect, start, cell_size, stride, columns, item_count)
	if index < 0:
		return ""
	return prefix + ":" + str(index)


func _cached_grid_signature_contains_mouse(
	key_text: String,
	mouse_pos: Vector2,
	grid_rect: Rect2,
	start: Vector2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int
) -> bool:
	if not key_text.is_valid_int():
		return false
	var index: int = _get_cached_grid_hover_index(mouse_pos, grid_rect, start, cell_size, stride, columns, item_count)
	return index >= 0 and index == int(key_text)


func _get_cached_grid_hover_index(
	mouse_pos: Vector2,
	grid_rect: Rect2,
	start: Vector2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int
) -> int:
	if not grid_rect.has_point(mouse_pos):
		return -1
	return _get_hovered_grid_index(mouse_pos, start.x, start.y, cell_size, stride, columns, item_count)


func _get_cached_linear_hover_signature(
	mouse_pos: Vector2,
	start: Vector2,
	slot_size: float,
	stride: float,
	slot_count: int,
	prefix: String
) -> String:
	var index: int = _get_cached_linear_hover_index(mouse_pos, start, slot_size, stride, slot_count)
	if index < 0:
		return ""
	return prefix + ":" + str(index)


func _cached_linear_signature_contains_mouse(
	key_text: String,
	mouse_pos: Vector2,
	start: Vector2,
	slot_size: float,
	stride: float,
	slot_count: int
) -> bool:
	if not key_text.is_valid_int():
		return false
	var index: int = _get_cached_linear_hover_index(mouse_pos, start, slot_size, stride, slot_count)
	return index >= 0 and index == int(key_text)


func _get_cached_linear_hover_index(
	mouse_pos: Vector2,
	start: Vector2,
	slot_size: float,
	stride: float,
	slot_count: int
) -> int:
	return _get_hovered_linear_slot_index(mouse_pos, start.x, start.y, slot_size, stride, slot_count)


func _find_hovered_rect_key(rects: Dictionary, mouse_pos: Vector2) -> Variant:
	for key_value in rects:
		var rect_value: Variant = rects[key_value]
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.has_point(mouse_pos):
				return key_value
	return null


func _find_hovered_equipment_slot_index(mouse_pos: Vector2) -> int:
	for i in range(_equipment_slot_rect_list_cache.size()):
		if _equipment_slot_rect_list_cache[i].has_point(mouse_pos):
			return i
	return -1


func _get_equipment_slot_key_at_mouse(mouse_pos: Vector2) -> String:
	var slot_index: int = _find_hovered_equipment_slot_index(mouse_pos)
	if slot_index >= 0 and slot_index < _equipment_slot_keys.size():
		return _equipment_slot_keys[slot_index]
	if _has_indexed_equipment_hover_layout():
		return ""
	var slot_key_value: Variant = _find_hovered_rect_key(_last_equipment_slot_rects, mouse_pos)
	if slot_key_value == null:
		return ""
	return str(slot_key_value)


func _get_hovered_linear_slot_index(
	mouse_pos: Vector2,
	start_x: float,
	start_y: float,
	slot_size: float,
	stride: float,
	slot_count: int
) -> int:
	if slot_count < 1 or slot_size <= 0.0 or stride <= 0.0:
		return -1
	if mouse_pos.y < start_y or mouse_pos.y >= start_y + slot_size:
		return -1
	var slot_index: int = int(floor((mouse_pos.x - start_x) / stride))
	if slot_index < 0 or slot_index >= slot_count:
		return -1
	var slot_x: float = start_x + float(slot_index) * stride
	if mouse_pos.x < slot_x or mouse_pos.x >= slot_x + slot_size:
		return -1
	return slot_index


func _get_hovered_grid_index(
	mouse_pos: Vector2,
	start_x: float,
	start_y: float,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int
) -> int:
	if columns < 1 or item_count < 1:
		return -1
	var col: int = int(floor((mouse_pos.x - start_x) / stride))
	var row: int = int(floor((mouse_pos.y - start_y) / stride))
	if col < 0 or col >= columns or row < 0:
		return -1
	var cell_x: float = start_x + float(col) * stride
	var cell_y: float = start_y + float(row) * stride
	if mouse_pos.x < cell_x or mouse_pos.x >= cell_x + cell_size:
		return -1
	if mouse_pos.y < cell_y or mouse_pos.y >= cell_y + cell_size:
		return -1
	var index: int = row * columns + col
	if index < 0 or index >= item_count:
		return -1
	return index


func prewarm_assets(
	owner: Object = null,
	registry: Object = null,
	module_getter: Callable = Callable(),
	include_shared_icon_assets: bool = true,
	view_size: Vector2 = Vector2.ZERO
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	_prewarm_layout_caches(owner, registry, module_getter, view_size)
	_prewarm_draw_caches(font, owner, registry, module_getter)
	_prewarm_lingpet_skill_icon_assets()
	if include_shared_icon_assets and not _shared_icon_assets_prewarmed:
		_shared_icon_assets_prewarmed = _prewarm_shared_icon_assets(registry, module_getter)
	_prewarm_visible_item_icons(owner, registry, module_getter)
	_prewarm_passive_inventory_assets(owner, registry, module_getter)
	if not _static_text_prewarmed:
		_static_text_prewarmed = true
		_prewarm_static_text(font, owner)
	if not _active_item_text_prewarmed:
		_active_item_text_prewarmed = true
		_prewarm_active_item_text(font)
	if not _runtime_perk_text_prewarmed:
		_runtime_perk_text_prewarmed = _prewarm_runtime_perk_text(font, owner, registry, module_getter)
	if not _skill_text_prewarmed:
		_skill_text_prewarmed = _prewarm_skill_text(font, owner, registry, module_getter)


func _prewarm_layout_caches(owner: Object, registry: Object, module_getter: Callable, view_size: Vector2 = Vector2.ZERO) -> void:
	var resolved_view_size: Vector2 = _resolve_prewarm_view_size(owner, view_size)
	if resolved_view_size.x <= 0.0 or resolved_view_size.y <= 0.0:
		return
	_update_frame_layout(resolved_view_size)
	_prewarm_equipment_layout(owner)
	_prewarm_skill_layout(owner, registry, module_getter)
	_prewarm_active_item_layout(owner, registry, module_getter)
	_prewarm_passive_inventory_layout(owner, registry, module_getter)
	_prewarm_perk_grid_layout(owner, registry, module_getter)


func _prewarm_draw_caches(font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:
	if font == null:
		return
	_prewarm_header_text_cache(font, owner, registry, module_getter)
	_prewarm_equipment_text_cache(font)
	_prewarm_skill_slot_text_cache(font)
	_prewarm_active_slot_text_cache(font)
	_prewarm_perk_grid_text_cache(font)
	_prewarm_passive_inventory_text_cache(font, owner, registry, module_getter)
	_prewarm_stats_layout(font, owner, registry, module_getter)


func _prewarm_header_text_cache(font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_panel_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_state")
	var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var character_type: String = _get_character_type(owner)
	var display_name: String = _get_character_display_name(owner, character_type)
	var subtitle: String = _get_header_subtitle(display_name, character_type)
	_text_size(font, subtitle, 14)
	var pending: int = int(runtime_snapshot.get("pending_skill_choices", 0))
	if not runtime_snapshot.has("pending_skill_choices"):
		pending = int(_safe_owner_get(owner, "runtime_perk_pending_choices", 0))
	var gold: int = int(runtime_snapshot.get("gold_from_perks", 0))
	if not runtime_snapshot.has("gold_from_perks"):
		gold = int(_safe_owner_get(owner, "runtime_perk_gold", 0))
	var status: String = _get_header_status_text(pending, gold)
	_get_header_status_width(font, status, 14)


func _prewarm_equipment_text_cache(font: Font) -> void:
	if _equipment_slot_visible_label_cache.is_empty():
		return
	var equipment_label_size := 10
	if _equipment_layout_slot_size > 0.0 and _equipment_layout_slot_size < 40.0:
		equipment_label_size = 8
	for label in _equipment_slot_visible_label_cache:
		_get_centered_text_size(font, str(label), equipment_label_size)


func _prewarm_skill_slot_text_cache(font: Font) -> void:
	for label in _skill_slot_label_cache:
		_get_centered_text_size(font, str(label), 10)


func _prewarm_active_slot_text_cache(font: Font) -> void:
	for label in _active_item_trimmed_label_cache:
		_get_centered_text_size(font, str(label), 10)


func _prewarm_perk_grid_text_cache(font: Font) -> void:
	for level_text in _acquired_perk_level_text_cache:
		_get_perk_level_text_size(font, str(level_text), 9)


func _prewarm_passive_inventory_text_cache(font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_inventory_rect.size == Vector2.ZERO:
		return
	var mythic_item_runtime: Object = _get_prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var inventory_items: Array = _get_passive_inventory_items(owner, registry, mythic_item_runtime)
	var summary: Dictionary = _prepare_passive_inventory_draw_cache(inventory_items)
	var count_text: String = str(summary.get("count_text", ""))
	_get_passive_inventory_count_text_width(font, count_text, 11)


func _prewarm_stats_layout(font: Font, owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_stats_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_state")
	var active_item_runtime: Object = _get_prewarm_instance(registry, module_getter, "active_item_runtime")
	var mythic_item_runtime: Object = _get_prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var lingpet_runtime: Object = _get_prewarm_instance(registry, module_getter, "lingpet_egg_runtime")
	var character_type: String = _get_character_type(owner)
	var stat_sources: Array = [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]
	var active_item_slot_capacity: int = _get_active_item_slot_capacity_for_sources(runtime_state, mythic_item_runtime)
	var active_item_slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	var player_rows: Array = _build_stats(
		owner,
		registry,
		runtime_state,
		active_item_runtime,
		mythic_item_runtime,
		character_type,
		stat_sources,
		true,
		active_item_slot_capacity,
		active_item_slots
	)
	var lingpet_rows: Array = _build_lingpet_stats(owner)
	for rows in [player_rows, lingpet_rows]:
		for row_value in rows:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			_text_size(font, str(row.get("label", "")), 13)
			_text_size(font, str(row.get("value", "")), 13)


func _resolve_prewarm_view_size(owner: Object, requested_view_size: Vector2 = Vector2.ZERO) -> Vector2:
	if requested_view_size.x > 0.0 and requested_view_size.y > 0.0:
		return requested_view_size
	if owner != null and owner.has_method("get_viewport_rect"):
		var rect_value: Variant = owner.get_viewport_rect()
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				return rect.size
	return Vector2.ZERO


func _prewarm_equipment_layout(owner: Object) -> void:
	if _layout_equipment_rect.size == Vector2.ZERO:
		return
	var content_rect := Rect2(_layout_equipment_rect.position.x + 12.0, _layout_equipment_rect.position.y + 34.0, _layout_equipment_rect.size.x - 24.0, _layout_equipment_rect.size.y - 42.0)
	var slot_size: float = clamp(min(content_rect.size.x * 0.18, content_rect.size.y * 0.145), 34.0, 55.0)
	_update_equipment_slot_layout(content_rect, slot_size)
	_last_equipment_slot_rects = _equipment_slot_rect_cache
	_equipment_hover_uses_indexed_layout = true
	_ensure_equipment_slot_metadata_cache()
	_refresh_equipment_slot_visible_label_cache(slot_size < 42.0)
	_refresh_equipment_slot_frame_cache(_get_equipment_state(owner), _get_accessory_slot_count(owner))


func _prewarm_skill_layout(owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_skill_rect.size == Vector2.ZERO:
		return
	var character_type: String = _get_character_type(owner)
	var skill_config: Object = _get_prewarm_skill_config(registry, module_getter, character_type)
	var snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var max_slots: int = max(1, int(snapshot.get("max_slots", 5)))
	var slot_width_limit: float = (_layout_skill_rect.size.x - 24.0 - float(max_slots - 1) * 8.0) / float(max_slots)
	var slot_height_limit: float = _layout_skill_rect.size.y - 60.0
	var slot_size: float = min(60.0, max(36.0, min(slot_width_limit, slot_height_limit)))
	_update_skill_slot_layout(_layout_skill_rect, slot_size, max_slots)
	_refresh_skill_slot_draw_cache(_get_array(snapshot.get("equipped_skills", [])), _get_dict(snapshot.get("skill_data", {})), _skill_fallback_color(character_type))


func _prewarm_active_item_layout(owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_active_items_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_state")
	var mythic_item_runtime: Object = _get_prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var max_slots: int = _get_active_item_slot_capacity_for_sources(runtime_state, mythic_item_runtime)
	var slot_width_limit: float = (_layout_active_items_rect.size.x - 34.0) / float(max_slots)
	var slot_height_limit: float = _layout_active_items_rect.size.y - 64.0
	var min_slot_size: float = 24.0 if max_slots > 5 else 40.0
	var slot_size: float = min(68.0, max(min_slot_size, min(slot_width_limit, slot_height_limit)))
	var gap: float = max(4.0, (_layout_active_items_rect.size.x - slot_size * float(max_slots)) / float(max_slots + 1))
	var active_slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	var visuals: Object = _get_prewarm_instance(registry, module_getter, "active_item_hud_visuals")
	var can_draw_active_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	_refresh_active_item_label_cache(active_slots)
	_update_active_slot_layout(_layout_active_items_rect, slot_size, gap, max_slots)
	_refresh_active_slot_draw_cache(active_slots, max_slots, visuals, not can_draw_active_item_icon)


func _prewarm_passive_inventory_layout(owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_inventory_rect.size == Vector2.ZERO:
		return
	var mythic_item_runtime: Object = _get_prewarm_instance(registry, module_getter, "mythic_item_runtime")
	var inventory_items: Array = _get_passive_inventory_items(owner, registry, mythic_item_runtime)
	_prepare_passive_inventory_draw_cache(inventory_items)
	_last_passive_inventory_rect = _layout_inventory_rect
	var grid_rect := Rect2(_layout_inventory_rect.position.x + 12.0, _layout_inventory_rect.position.y + 36.0, _layout_inventory_rect.size.x - 24.0, _layout_inventory_rect.size.y - 48.0)
	_last_passive_inventory_grid_rect = grid_rect
	if inventory_items.is_empty():
		_set_passive_grid_hover_layout(Vector2.ZERO, 0.0, 0.0, 0, 0)
		_last_passive_inventory_content_height = grid_rect.size.y
		_update_passive_inventory_scrollbar_layout(grid_rect, 0.0)
		return
	var gap := 8.0
	var columns: int = max(4, int(floor((grid_rect.size.x + gap) / PASSIVE_INVENTORY_COLUMN_TARGET)))
	var cell_size: float = min(50.0, floor((grid_rect.size.x - float(columns - 1) * gap) / float(columns)))
	cell_size = max(36.0, cell_size)
	var rows: int = int(ceil(float(inventory_items.size()) / float(columns)))
	_last_passive_inventory_content_height = float(rows) * (cell_size + gap) - gap
	var max_scroll: float = _get_max_passive_inventory_scroll()
	passive_inventory_scroll = clamp(passive_inventory_scroll, 0.0, max_scroll)
	var stride: float = cell_size + gap
	_update_passive_inventory_grid_layout(grid_rect, cell_size, stride, columns, inventory_items.size(), passive_inventory_scroll)
	_update_passive_inventory_scrollbar_layout(grid_rect, max_scroll)


func _prewarm_perk_grid_layout(owner: Object, registry: Object, module_getter: Callable) -> void:
	if _layout_perk_rect.size == Vector2.ZERO:
		return
	var runtime_state: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_state")
	var catalog: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_catalog")
	var character_type: String = _get_character_type(owner)
	var skill_config: Object = _get_prewarm_skill_config(registry, module_getter, character_type)
	var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var equipped_skills: Array = _get_array(skill_snapshot.get("equipped_skills", []))
	var snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	if levels.is_empty() and not snapshot.has("runtime_skill_levels"):
		levels = _get_dict(_safe_owner_get(owner, "runtime_perk_levels", {}))
	var acquired: Array = _build_acquired_perks_cached(levels, catalog, runtime_state, snapshot, equipped_skills)
	var grid_rect := Rect2(_layout_perk_rect.position.x + 12.0, _layout_perk_rect.position.y + 36.0, _layout_perk_rect.size.x - 24.0, _layout_perk_rect.size.y - 48.0)
	_last_perk_grid_rect = grid_rect
	if acquired.is_empty():
		_set_perk_grid_hover_layout(Vector2.ZERO, 0.0, 0.0, 0, 0)
		_last_perk_content_height = grid_rect.size.y
		_update_perk_scrollbar_layout(grid_rect, 0.0)
		return
	var columns: int = max(3, int(floor((grid_rect.size.x + 8.0) / 58.0)))
	var cell_size: float = min(52.0, floor((grid_rect.size.x - float(columns - 1) * 8.0) / float(columns)))
	var gap := 8.0
	var rows: int = int(ceil(float(acquired.size()) / float(columns)))
	_last_perk_content_height = float(rows) * (cell_size + gap) - gap
	var max_perk_scroll: float = _get_max_perk_scroll()
	perk_scroll = clamp(perk_scroll, 0.0, max_perk_scroll)
	var stride: float = cell_size + gap
	_update_perk_grid_layout(grid_rect, cell_size, stride, columns, acquired.size(), perk_scroll)
	_update_perk_scrollbar_layout(grid_rect, max_perk_scroll)


func _get_prewarm_skill_config(registry: Object, module_getter: Callable, character_type: String) -> Object:
	var skill_config: Object = _get_skill_config(registry, character_type)
	if skill_config != null:
		return skill_config
	var key := "smasher_skill_config"
	if _character_runtime != null and _character_runtime.has_method("get_skill_config_key"):
		key = str(_character_runtime.get_skill_config_key(character_type))
	elif character_type == "viper":
		key = "viper_skill_config"
	elif character_type == "soldier":
		key = "commando_skill_config"
	return _get_prewarm_instance(registry, module_getter, key)


func handle_input(event: InputEvent, owner: Object, registry: Object, _view_size: Vector2) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if _should_redraw_for_mouse_motion(motion_event.position):
			_request_redraw(true)
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
			close(true)
			return true
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
			close(true)
			return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and _last_passive_inventory_rect.has_point(mouse_event.position):
			var inventory_changed := false
			var inventory_max_scroll: float = _get_max_passive_inventory_scroll()
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var previous_scroll_up: float = passive_inventory_scroll
				passive_inventory_scroll = clamp(passive_inventory_scroll - 48.0, 0.0, inventory_max_scroll)
				inventory_changed = not is_equal_approx(passive_inventory_scroll, previous_scroll_up)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var previous_scroll_down: float = passive_inventory_scroll
				passive_inventory_scroll = clamp(passive_inventory_scroll + 48.0, 0.0, inventory_max_scroll)
				inventory_changed = not is_equal_approx(passive_inventory_scroll, previous_scroll_down)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				inventory_changed = _try_handle_passive_inventory_context_click(mouse_event.position, owner, registry)
			if inventory_changed:
				_reset_mouse_hover_tracking()
				_request_redraw(true)
			return true
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if _try_handle_equipment_context_click(mouse_event.position, owner, registry):
				_reset_mouse_hover_tracking()
				_request_redraw(true)
				return true
		if mouse_event.pressed and _last_perk_grid_rect.has_point(mouse_event.position):
			var perk_changed := false
			var max_scroll: float = _get_max_perk_scroll()
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var previous_perk_scroll_up: float = perk_scroll
				perk_scroll = clamp(perk_scroll - 48.0, 0.0, max_scroll)
				perk_changed = not is_equal_approx(perk_scroll, previous_perk_scroll_up)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var previous_perk_scroll_down: float = perk_scroll
				perk_scroll = clamp(perk_scroll + 48.0, 0.0, max_scroll)
				perk_changed = not is_equal_approx(perk_scroll, previous_perk_scroll_down)
			if perk_changed:
				_reset_mouse_hover_tracking()
				_request_redraw(true)
		return true
	return true


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	var alpha: float = clamp(animation_time / OPEN_ANIMATION_DURATION, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.58 * alpha))

	_update_frame_layout(view_size)
	var panel_rect: Rect2 = _layout_panel_rect
	_draw_panel(canvas, panel_rect, PANEL_COLOR, PANEL_BORDER, 3.0)
	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var character_type: String = _get_character_type(owner)
	_draw_header(canvas, owner, panel_rect, font, registry, runtime_state, runtime_snapshot, character_type)
	_perf_end(perf_logger, "character_info.frame", sample_start)

	var mouse_pos := Vector2.ZERO
	var viewport: Viewport = canvas.get_viewport()
	if viewport != null:
		mouse_pos = viewport.get_mouse_position()
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	var lingpet_runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	var active_item_hud_visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	var runtime_perk_icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")
	var runtime_perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var skill_config: Object = _get_skill_config(registry, character_type)
	var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var active_item_slot_capacity: int = _get_active_item_slot_capacity_for_sources(runtime_state, mythic_item_runtime)
	var active_item_slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	_frame_stat_sources.clear()
	_frame_stat_sources.append(runtime_state)
	_frame_stat_sources.append(active_item_runtime)
	_frame_stat_sources.append(mythic_item_runtime)
	_frame_stat_sources.append(lingpet_runtime)
	var stat_sources: Array = _frame_stat_sources

	_frame_hover_data.clear()
	var hover_data: Dictionary = _frame_hover_data
	if _layout_equipment_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = _draw_equipment_slots(canvas, owner, registry, _layout_equipment_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)
		_perf_end(perf_logger, "character_info.equipment", sample_start)

	if _layout_skill_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = _draw_skill_slots(canvas, owner, registry, _layout_skill_rect, font, mouse_pos, hover_data, character_type, skill_snapshot, runtime_perk_icon_renderer)
		_perf_end(perf_logger, "character_info.skills", sample_start)

	if _layout_active_items_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = _draw_active_items(canvas, owner, registry, _layout_active_items_rect, font, mouse_pos, hover_data, active_item_slot_capacity, active_item_hud_visuals, stat_sources, active_item_slots)
		_perf_end(perf_logger, "character_info.active_items", sample_start)

	sample_start = _perf_begin(perf_logger)
	hover_data = _draw_perk_grid(canvas, owner, registry, _layout_perk_rect, font, mouse_pos, hover_data, runtime_state, runtime_perk_icon_renderer, runtime_snapshot, runtime_perk_catalog, _get_array(skill_snapshot.get("equipped_skills", [])))
	_perf_end(perf_logger, "character_info.perks", sample_start)

	sample_start = _perf_begin(perf_logger)
	hover_data = _draw_lingpet_panel(canvas, owner, _layout_lingpet_rect, font, mouse_pos, hover_data)
	_perf_end(perf_logger, "character_info.lingpet", sample_start)

	sample_start = _perf_begin(perf_logger)
	hover_data = _draw_stats_panel(canvas, owner, registry, _layout_stats_rect, font, runtime_state, active_item_runtime, mythic_item_runtime, character_type, stat_sources, mouse_pos, hover_data, active_item_slot_capacity, active_item_slots)
	_perf_end(perf_logger, "character_info.stats", sample_start)

	if _layout_inventory_rect.size != Vector2.ZERO:
		sample_start = _perf_begin(perf_logger)
		hover_data = _draw_passive_inventory(canvas, owner, registry, _layout_inventory_rect, font, mouse_pos, hover_data, active_item_hud_visuals, mythic_item_runtime, runtime_state)
		_perf_end(perf_logger, "character_info.passive_inventory", sample_start)

	if not hover_data.is_empty():
		sample_start = _perf_begin(perf_logger)
		_draw_tooltip(canvas, hover_data, mouse_pos, view_size, font)
		_perf_end(perf_logger, "character_info.tooltip", sample_start)


func _update_frame_layout(view_size: Vector2) -> void:
	if _layout_panel_rect.size != Vector2.ZERO and _layout_view_size.is_equal_approx(view_size):
		return
	_layout_view_size = view_size
	var panel_size := Vector2(
		min(1280.0, max(520.0, view_size.x - 8.0)),
		min(980.0, max(440.0, view_size.y - 4.0))
	)
	_layout_panel_rect = Rect2((view_size - panel_size) * 0.5, panel_size)
	var inner_margin := 18.0
	var content_top := _layout_panel_rect.position.y + 66.0
	var content_bottom := _layout_panel_rect.end.y - 12.0
	var content_height: float = max(300.0, content_bottom - content_top)
	var column_gap := 18.0
	var inventory_height: float = clamp(content_height * 0.18, 86.0, 150.0)
	if content_height < 520.0:
		inventory_height = 82.0
	var main_bottom: float = content_bottom - inventory_height - 10.0
	var main_height: float = max(230.0, main_bottom - content_top)
	var left_w: float = min(470.0, (_layout_panel_rect.size.x - inner_margin * 2.0 - column_gap) * 0.45)
	var right_w: float = _layout_panel_rect.size.x - inner_margin * 2.0 - column_gap - left_w
	var left_rect := Rect2(_layout_panel_rect.position.x + inner_margin, content_top, left_w, main_height)
	var right_rect := Rect2(left_rect.end.x + column_gap, content_top, right_w, main_height)
	_layout_inventory_rect = Rect2(
		_layout_panel_rect.position.x + inner_margin,
		main_bottom + 14.0,
		_layout_panel_rect.size.x - inner_margin * 2.0,
		max(90.0, content_bottom - main_bottom - 14.0)
	)
	_layout_equipment_rect = _section_rect(left_rect, 0.0, 0.58)
	_layout_skill_rect = _section_rect(left_rect, 0.60, 0.19)
	_layout_active_items_rect = _section_rect(left_rect, 0.80, 0.20)
	var right_top_rect := _section_rect(right_rect, 0.0, 0.58)
	var right_top_gap := 12.0
	if right_top_rect.size.x >= 560.0:
		var lingpet_w: float = clamp(right_top_rect.size.x * 0.34, 230.0, 320.0)
		_layout_perk_rect = Rect2(right_top_rect.position, Vector2(right_top_rect.size.x - lingpet_w - right_top_gap, right_top_rect.size.y))
		_layout_lingpet_rect = Rect2(_layout_perk_rect.end.x + right_top_gap, right_top_rect.position.y, lingpet_w, right_top_rect.size.y)
	else:
		var perk_h: float = max(64.0, right_top_rect.size.y * 0.54 - right_top_gap * 0.5)
		_layout_perk_rect = Rect2(right_top_rect.position, Vector2(right_top_rect.size.x, perk_h))
		_layout_lingpet_rect = Rect2(right_top_rect.position.x, _layout_perk_rect.end.y + right_top_gap, right_top_rect.size.x, max(64.0, right_top_rect.end.y - _layout_perk_rect.end.y - right_top_gap))
	_layout_stats_rect = _section_rect(right_rect, 0.60, 0.40)


func _section_rect(column_rect: Rect2, start_ratio: float, height_ratio: float) -> Rect2:
	var gap := 10.0
	var y: float = column_rect.position.y + column_rect.size.y * start_ratio
	var height: float = column_rect.size.y * height_ratio - gap
	return Rect2(column_rect.position.x, y, column_rect.size.x, max(64.0, height))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _draw_header(
	canvas: CanvasItem,
	owner: Object,
	panel_rect: Rect2,
	font: Font,
	registry: Object,
	runtime_state: Object = null,
	runtime_snapshot_override: Variant = null,
	character_type_override: String = ""
) -> void:
	var title_x: float = panel_rect.position.x + 26.0
	var title_y: float = panel_rect.position.y + 42.0
	_draw_text_xy(canvas, font, "캐릭터 정보", title_x, title_y, 28, Color.WHITE)
	var character_type: String = character_type_override
	if character_type == "":
		character_type = _get_character_type(owner)
	var display_name: String = _get_character_display_name(owner, character_type)
	var subtitle: String = _get_header_subtitle(display_name, character_type)
	_draw_text_xy(canvas, font, subtitle, title_x, title_y + 24.0, 14, TEXT_DIM)

	var effective_runtime_state: Object = runtime_state
	if effective_runtime_state == null:
		effective_runtime_state = _get_instance(registry, "runtime_perk_state")
	var snapshot: Dictionary = {}
	if runtime_snapshot_override is Dictionary:
		snapshot = runtime_snapshot_override
	elif effective_runtime_state != null and effective_runtime_state.has_method("get_snapshot"):
		snapshot = effective_runtime_state.get_snapshot()
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	if not snapshot.has("pending_skill_choices"):
		pending = int(_safe_owner_get(owner, "runtime_perk_pending_choices", 0))
	var gold: int = int(snapshot.get("gold_from_perks", 0))
	if not snapshot.has("gold_from_perks"):
		gold = int(_safe_owner_get(owner, "runtime_perk_gold", 0))
	var status: String = _get_header_status_text(pending, gold)
	var status_width: float = _get_header_status_width(font, status, 14)
	_draw_text_xy(canvas, font, status, panel_rect.end.x - status_width - 26.0, title_y + 16.0, 14, ACCENT_GOLD)


func _draw_character_card(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font) -> void:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "상태", rect.position.x + 14.0, rect.position.y + 26.0, 14, ACCENT_BLUE)

	var character_type: String = _get_character_type(owner)
	var character_color: Color = _character_color(character_type)
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.34)
	var radius: float = min(rect.size.x, rect.size.y) * 0.18
	for glow in range(CHARACTER_CARD_GLOW_LAYERS, 0, -1):
		canvas.draw_circle(center, radius + float(glow) * 5.0, Color(character_color.r, character_color.g, character_color.b, 0.035 * float(glow)))
	canvas.draw_circle(center, radius, Color(character_color.r, character_color.g, character_color.b, 0.22))
	canvas.draw_arc(center, radius, -PI * 0.15, TAU - PI * 0.15, CHARACTER_CARD_RING_SEGMENTS, character_color, 3.0)
	canvas.draw_rect(Rect2(center.x - radius * 0.52, center.y - radius * 0.22, radius * 1.04, radius * 0.44), Color(character_color.r, character_color.g, character_color.b, 0.82))
	canvas.draw_line(center + Vector2(-radius * 0.62, radius * 0.40), center + Vector2(radius * 0.62, radius * 0.40), Color.WHITE, 2.0)

	var name := _get_character_display_name(owner, character_type)
	var card_center_x: float = rect.position.x + rect.size.x * 0.5
	_draw_text_centered_xy(canvas, font, name, card_center_x, center.y + radius + 40.0, 20, Color.WHITE)
	var stage := int(_safe_owner_get(owner, "current_stage", 1))
	_draw_text_centered_xy(canvas, font, LanguageSettings.format_stage_label(stage), card_center_x, center.y + radius + 62.0, 13, TEXT_DIM)

	var gauge: float = float(_safe_owner_get(owner, "special_gauge", 0.0))
	var bar_rect := Rect2(rect.position.x + 22.0, rect.end.y - 64.0, rect.size.x - 44.0, 12.0)
	_draw_meter(canvas, bar_rect, gauge / SPECIAL_GAUGE_MAX, Color(70.0 / 255.0, 160.0 / 255.0, 1.0), "게이지 " + _format_int_pair(int(gauge), int(SPECIAL_GAUGE_MAX)), font)

	var dash_snapshot: Dictionary = _get_smasher_dash_snapshot(registry, character_type)
	var tokens: int = int(dash_snapshot.get("tokens", 0))
	var max_tokens: int = max(1, int(dash_snapshot.get("max_tokens", 1)))
	var token_text := "대시 토큰 " + _format_int_pair(tokens, max_tokens)
	_draw_text_xy(canvas, font, token_text, rect.position.x + 22.0, rect.end.y - 22.0, 13, TEXT_SOFT)


func _draw_equipment_slots(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	active_item_hud_visuals: Object = null,
	mythic_item_runtime: Object = null,
	runtime_state: Object = null
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "장비 슬롯", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	_last_equipment_rect = rect
	var slot_state: Dictionary = _get_equipment_state(owner)
	var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 34.0, rect.size.x - 24.0, rect.size.y - 42.0)
	var slot_size: float = clamp(min(content_rect.size.x * 0.18, content_rect.size.y * 0.145), 34.0, 55.0)
	_update_equipment_slot_layout(content_rect, slot_size)
	_last_equipment_slot_rects = _equipment_slot_rect_cache
	_equipment_hover_uses_indexed_layout = true
	var visuals: Object = active_item_hud_visuals
	if visuals == null:
		visuals = _get_instance(registry, "active_item_hud_visuals")
	var can_draw_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var mouse_in_equipment_rect: bool = rect.has_point(mouse_pos)
	var accessory_slot_count: int = _get_accessory_slot_count(owner)
	var hovered_slot_index := -1
	if mouse_in_equipment_rect:
		hovered_slot_index = _find_hovered_equipment_slot_index(mouse_pos)

	_draw_equipment_anatomy_silhouette(canvas, content_rect, slot_size, hovered_slot_index >= 0)
	_ensure_equipment_slot_metadata_cache()
	var equipment_label_size: int = 10 if slot_size >= 40.0 else 8
	var use_compact_equipment_labels: bool = slot_size < 42.0
	_refresh_equipment_slot_visible_label_cache(use_compact_equipment_labels)
	_refresh_equipment_slot_frame_cache(slot_state, accessory_slot_count)
	for i in range(_equipment_slot_keys.size()):
		var key := ""
		var slot_rect: Rect2 = _equipment_slot_rect_list_cache[i]
		var slot_center_x: float = _equipment_slot_center_x_cache[i]
		var slot_center_y: float = _equipment_slot_center_y_cache[i]
		var enabled: bool = _equipment_slot_enabled_cache[i]
		var item_data: Dictionary = _equipment_slot_item_cache[i]
		var has_item: bool = _equipment_slot_has_item_cache[i]
		var hovered: bool = i == hovered_slot_index
		var base_color: Color = _equipment_slot_base_color_cache[i]
		var border_color: Color = _equipment_slot_border_color_cache[i]
		var border_width: float = _equipment_slot_border_width_cache[i]
		if hovered and enabled and not has_item:
			border_color = EQUIPMENT_SLOT_BORDER_FILLED
			border_width = 2.0
		if hovered:
			key = _equipment_slot_keys[i]
			_draw_equipment_connector(canvas, content_rect, key, slot_center_x, slot_center_y, base_color, enabled)
		_draw_equipment_slot_frame(canvas, slot_rect, _equipment_slot_fill_color_cache[i], base_color, border_color, border_width, enabled, has_item, hovered)
		if has_item:
			if can_draw_item_icon:
				_active_item_icon_renderer.draw_icon(canvas, _equipment_slot_icon_rect_cache[i], item_data, 1.0, visuals)
			else:
				if key == "":
					key = _equipment_slot_keys[i]
				_draw_fallback_symbol(canvas, _equipment_slot_fallback_rect_cache[i], base_color, str(item_data.get("name", key)))
		elif hovered:
			var base: String = _equipment_slot_bases[i]
			_draw_equipment_placeholder(canvas, _equipment_slot_placeholder_rect_cache[i], base, base_color, enabled)
		if not enabled:
			_draw_locked_slot(canvas, i)
		var visible_label: String = _equipment_slot_visible_label_cache[i]
		_draw_text_centered_xy(canvas, font, visible_label, slot_center_x, _equipment_slot_label_y_cache[i], equipment_label_size, _equipment_slot_label_color_cache[i])
		if hovered:
			if has_item:
				var display_name: String = _equipment_item_display_name(item_data)
				hover_data = _set_hover_data(
					hover_data,
					display_name,
					_item_part_subtitle(key),
					_get_string_fallback(item_data, "description", "desc"),
					base_color,
					_get_item_quality_color(item_data, Color.WHITE),
					slot_rect,
					_build_passive_item_roll_entries(item_data, registry, mythic_item_runtime, runtime_state)
				)
			else:
				var label: String = _equipment_slot_labels[i]
				hover_data = _set_hover_data(
					hover_data,
					label,
					"미장착" if enabled else "잠김",
					"패시브 장비가 연결되면 이 슬롯에 표시됩니다.",
					base_color
				)
	return hover_data


func _draw_equipment_slots_grid(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	active_item_hud_visuals: Object = null,
	mythic_item_runtime: Object = null,
	runtime_state: Object = null
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "장비 슬롯", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	_last_equipment_rect = rect
	_last_equipment_slot_rects.clear()
	_equipment_hover_uses_indexed_layout = false
	var slot_state: Dictionary = _get_equipment_state(owner)
	var columns := 4
	var gap := 7.0
	var grid_rect := Rect2(rect.position.x + 12.0, rect.position.y + 38.0, rect.size.x - 24.0, rect.size.y - 48.0)
	var cell_w: float = floor((grid_rect.size.x - gap * float(columns - 1)) / float(columns))
	var cell_h: float = floor((grid_rect.size.y - gap * 2.0) / 3.0)
	var cell_size: float = max(26.0, min(cell_w, cell_h))
	var total_w: float = cell_size * float(columns) + gap * float(columns - 1)
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - total_w) * 0.5
	var start_y: float = grid_rect.position.y + max(0.0, (grid_rect.size.y - (cell_size * 3.0 + gap * 2.0)) * 0.5)

	var visuals: Object = active_item_hud_visuals
	if visuals == null:
		visuals = _get_instance(registry, "active_item_hud_visuals")
	var can_draw_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var mouse_in_equipment_rect: bool = rect.has_point(mouse_pos)
	var accessory_slot_count: int = _get_accessory_slot_count(owner)
	_ensure_equipment_slot_metadata_cache()
	for i in range(_equipment_slot_keys.size()):
		var key: String = _equipment_slot_keys[i]
		var label: String = _equipment_slot_labels[i]
		var base: String = _equipment_slot_bases[i]
		var accessory_number: int = _equipment_slot_accessory_numbers[i]
		var empty_color: Color = _equipment_slot_empty_colors[i]
		@warning_ignore("integer_division")
		var row: int = int(i / columns)
		var col: int = i % columns
		var slot_rect := Rect2(Vector2(start_x + float(col) * (cell_size + gap), start_y + float(row) * (cell_size + gap)), Vector2(cell_size, cell_size))
		_last_equipment_slot_rects[key] = slot_rect
		var enabled: bool = accessory_number <= 0 or accessory_number <= accessory_slot_count
		var item_data: Dictionary = _get_equipment_item(slot_state, key)
		var has_item: bool = not item_data.is_empty()
		var base_color: Color = EQUIPMENT_COLOR_DISABLED if not enabled else EQUIPMENT_COLOR_FILLED if has_item else empty_color
		var bg_alpha: float = 0.94 if enabled else 0.48
		canvas.draw_rect(slot_rect, Color(13.0 / 255.0, 17.0 / 255.0, 29.0 / 255.0, bg_alpha))
		canvas.draw_rect(slot_rect, Color(base_color.r, base_color.g, base_color.b, 0.82 if has_item else 0.55), false, 1.6 if enabled else 1.0)
		if has_item:
			if can_draw_item_icon:
				_active_item_icon_renderer.draw_icon(canvas, slot_rect.grow(-5.0), item_data, 1.0, visuals)
			else:
				_draw_fallback_symbol(canvas, slot_rect.grow(-9.0), base_color, str(item_data.get("name", key)))
		else:
			_draw_equipment_placeholder(canvas, slot_rect.grow(-8.0), base, base_color, enabled)
		if not enabled:
			_draw_locked_slot_rect(canvas, slot_rect, base_color)
		var label_size: int = 9 if cell_size >= 38.0 else 8
		var visible_label: String = label if cell_size >= 42.0 else _equipment_slot_compact_labels[i]
		var slot_center_x: float = slot_rect.position.x + slot_rect.size.x * 0.5
		_draw_text_centered_xy(canvas, font, visible_label, slot_center_x, slot_rect.end.y - 4.0, label_size, TEXT_SOFT if enabled else EQUIPMENT_LABEL_DISABLED)
		if mouse_in_equipment_rect and slot_rect.has_point(mouse_pos):
			if has_item:
				var display_name: String = _equipment_item_display_name(item_data)
				hover_data = _set_hover_data(
					hover_data,
					display_name,
					_item_part_subtitle(key),
					_get_string_fallback(item_data, "description", "desc"),
					base_color,
					_get_item_quality_color(item_data, Color.WHITE),
					slot_rect,
					_build_passive_item_roll_entries(item_data, registry, mythic_item_runtime, runtime_state)
				)
			else:
				hover_data = _set_hover_data(
					hover_data,
					label,
					"미장착" if enabled else "잠김",
					"패시브 장비가 연결되면 이 슬롯에 표시됩니다.",
					base_color
				)
	return hover_data


func _draw_skill_slots(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	character_type_override: String = "",
	skill_snapshot_override: Dictionary = {},
	icon_renderer_override: Object = null
) -> Dictionary:
	_last_skill_rect = rect
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "장착 스킬", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var character_type: String = character_type_override
	if character_type == "":
		character_type = _get_character_type(owner)
	var snapshot: Dictionary = skill_snapshot_override
	if snapshot.is_empty():
		var skill_config: Object = _get_skill_config(registry, character_type)
		snapshot = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var equipped: Array = _get_array(snapshot.get("equipped_skills", []))
	var max_slots: int = max(1, int(snapshot.get("max_slots", 5)))
	var skill_data: Dictionary = _get_dict(snapshot.get("skill_data", {}))
	var icon_renderer: Object = icon_renderer_override
	if icon_renderer == null:
		icon_renderer = _get_instance(registry, "runtime_perk_icon_renderer")
	var can_draw_skill_icon: bool = icon_renderer != null and icon_renderer.has_method("draw_icon")
	var mouse_in_skill_rect: bool = rect.has_point(mouse_pos)

	var slot_width_limit: float = (rect.size.x - 24.0 - float(max_slots - 1) * 8.0) / float(max_slots)
	var slot_height_limit: float = rect.size.y - 60.0
	var slot_size: float = min(60.0, max(36.0, min(slot_width_limit, slot_height_limit)))
	_update_skill_slot_layout(rect, slot_size, max_slots)
	var fallback_skill_color: Color = _skill_fallback_color(character_type)
	_refresh_skill_slot_draw_cache(equipped, skill_data, fallback_skill_color)
	var hovered_skill_slot := -1
	if mouse_in_skill_rect:
		hovered_skill_slot = _get_hovered_linear_slot_index(mouse_pos, _last_skill_slot_start.x, _last_skill_slot_start.y, _last_skill_slot_size, _last_skill_slot_stride, max_slots)
	for i in range(max_slots):
		var slot_rect: Rect2 = _skill_slot_rect_cache[i]
		var has_skill_slot: bool = i < equipped.size()
		if not has_skill_slot:
			canvas.draw_rect(slot_rect, OVERLAY_SLOT_FILL)
			canvas.draw_rect(slot_rect, OVERLAY_SLOT_BORDER, false, 1.5)
			var hovered_empty: bool = i == hovered_skill_slot
			if hovered_empty:
				canvas.draw_circle(_skill_slot_center_cache[i], slot_size * 0.22, OVERLAY_SKILL_EMPTY_HOVER_FILL)
			continue
		var skill_id: String = _skill_slot_id_cache[i]
		var data: Dictionary = _skill_slot_data_cache[i]
		var color: Color = _skill_slot_color_cache[i]
		canvas.draw_rect(slot_rect, _skill_slot_fill_color_cache[i])
		canvas.draw_rect(slot_rect, _skill_slot_border_color_cache[i], false, 2.0)
		if not can_draw_skill_icon or not bool(icon_renderer.draw_icon(canvas, skill_id, _skill_slot_icon_rect_cache[i], 1.0, true)):
			_draw_fallback_symbol(canvas, _skill_slot_fallback_rect_cache[i], color, skill_id)
		var label: String = _skill_slot_label_cache[i]
		_draw_text_centered_xy(canvas, font, label, _skill_slot_center_x_cache[i], _skill_slot_label_y, 10, TEXT_DIM)
		if i == hovered_skill_slot:
			hover_data = _set_hover_data(
				hover_data,
				str(data.get("korean", skill_id)),
				"비용 %d  쿨타임 %.0f초" % [int(float(data.get("cost", 0.0))), float(data.get("cooldown", 0.0))],
				str(data.get("description", "")),
				color
			)
	return hover_data


func _draw_active_items(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	max_slots: int = -1,
	active_item_hud_visuals: Object = null,
	stat_sources: Array = [],
	active_slots_override: Variant = null
) -> Dictionary:
	_last_active_items_rect = rect
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "액티브 아이템", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var slots: Array = []
	if active_slots_override is Array:
		slots = active_slots_override
	else:
		slots = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	_refresh_active_item_label_cache(slots)
	var visuals: Object = active_item_hud_visuals
	if visuals == null:
		visuals = _get_instance(registry, "active_item_hud_visuals")
	var can_draw_active_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var mouse_in_active_items_rect: bool = rect.has_point(mouse_pos)
	if max_slots < 1:
		max_slots = _get_active_item_slot_capacity(registry)
	var slot_width_limit: float = (rect.size.x - 34.0) / float(max_slots)
	var slot_height_limit: float = rect.size.y - 64.0
	var min_slot_size: float = 24.0 if max_slots > 5 else 40.0
	var slot_size: float = min(68.0, max(min_slot_size, min(slot_width_limit, slot_height_limit)))
	var gap: float = max(4.0, (rect.size.x - slot_size * float(max_slots)) / float(max_slots + 1))
	_update_active_slot_layout(rect, slot_size, gap, max_slots)
	_refresh_active_slot_draw_cache(slots, max_slots, visuals, not can_draw_active_item_icon)
	var hovered_active_slot := -1
	if mouse_in_active_items_rect:
		hovered_active_slot = _get_hovered_linear_slot_index(mouse_pos, _last_active_slot_start.x, _last_active_slot_start.y, _last_active_slot_size, _last_active_slot_stride, max_slots)
	for i in range(max_slots):
		var slot_rect: Rect2 = _active_slot_rect_cache[i]
		canvas.draw_rect(slot_rect, OVERLAY_SLOT_FILL)
		canvas.draw_rect(slot_rect, OVERLAY_SLOT_BORDER, false, 1.5)
		var has_active_slot: bool = _active_slot_has_item_cache[i]
		if not has_active_slot:
			var empty_slot_hovered: bool = i == hovered_active_slot
			if empty_slot_hovered:
				_draw_text_centered_xy(canvas, font, "-", _active_slot_center_x_cache[i], _active_slot_empty_marker_y, 20, OVERLAY_ACTIVE_EMPTY_TEXT)
			continue
		var item_data: Dictionary = _active_slot_item_cache[i]
		var active_item_hovered: bool = i == hovered_active_slot
		var active_item_color: Color = _active_slot_fallback_color_cache[i]
		var has_active_item_color: bool = _active_slot_has_fallback_color_cache[i]
		if can_draw_active_item_icon:
			_active_item_icon_renderer.draw_icon(canvas, slot_rect, item_data, 1.0, visuals)
		else:
			_draw_fallback_symbol(canvas, _active_slot_fallback_rect_cache[i], active_item_color, str(item_data.get("name", "")))
		var display_name: String = _active_item_display_name_cache[i]
		var trimmed_label: String = _active_item_trimmed_label_cache[i]
		_draw_text_centered_xy(canvas, font, trimmed_label, _active_slot_center_x_cache[i], _active_slot_label_y, 10, TEXT_DIM)
		if active_item_hovered:
			if not has_active_item_color:
				active_item_color = _get_item_color(item_data, visuals)
			hover_data = _set_hover_data(
				hover_data,
				display_name,
				"슬롯 %d" % (i + 1),
				"쿨타임 %.1f초" % (float(_get_effective_active_item_cooldown_msec(item_data, registry, stat_sources)) / 1000.0),
				active_item_color
			)
	return hover_data


func _draw_passive_inventory(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	active_item_hud_visuals: Object = null,
	mythic_item_runtime: Object = null,
	runtime_state: Object = null
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_last_passive_inventory_rect = rect

	var inventory_items: Array = _get_passive_inventory_items(owner, registry, mythic_item_runtime)
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
	var max_scroll: float = _get_max_passive_inventory_scroll()
	passive_inventory_scroll = clamp(passive_inventory_scroll, 0.0, max_scroll)
	var visuals: Object = active_item_hud_visuals
	if visuals == null:
		visuals = _get_instance(registry, "active_item_hud_visuals")
	var can_draw_passive_item_icon: bool = _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon")
	var stride: float = cell_size + gap
	_update_passive_inventory_grid_layout(grid_rect, cell_size, stride, columns, inventory_items.size(), passive_inventory_scroll)
	var hovered_passive_index := -1
	if mouse_in_passive_grid_rect:
		hovered_passive_index = _get_hovered_grid_index(mouse_pos, _last_passive_grid_start.x, _last_passive_grid_start.y, _last_passive_grid_cell_size, _last_passive_grid_stride, columns, inventory_items.size())

	for i in _passive_grid_visible_index_cache:
		var cell_rect: Rect2 = _passive_grid_cell_rect_cache[i]
		var item_data: Dictionary = _passive_inventory_item_cache[i]
		if item_data.is_empty():
			continue
		var color: Color = _passive_inventory_draw_color_cache[i]
		var hovered: bool = i == hovered_passive_index
		var equipped: bool = _passive_inventory_equipped_cache[i]
		var border_color: Color = _passive_inventory_border_color_cache[i]
		if hovered or equipped:
			border_color = _passive_inventory_active_border_color_cache[i]
		canvas.draw_rect(cell_rect, OVERLAY_GRID_CELL_FILL)
		canvas.draw_rect(cell_rect, border_color, false, 2.0 if hovered or equipped else 1.0)
		if can_draw_passive_item_icon:
			_active_item_icon_renderer.draw_icon(canvas, _passive_grid_icon_rect_cache[i], item_data, 1.0, visuals)
		else:
			_draw_fallback_symbol(canvas, _passive_grid_fallback_rect_cache[i], color, str(item_data.get("name", "")))
		if equipped:
			_draw_equipped_badge(canvas, _passive_grid_badge_rect_cache[i], _passive_grid_badge_center_x_cache[i], _passive_grid_badge_center_y_cache[i], font)
		if hovered:
			var slot_key: String = _get_item_slot_key(item_data)
			hover_data = _set_hover_data(
				hover_data,
				_equipment_item_display_name(item_data),
				_item_part_subtitle(slot_key),
				_build_passive_item_body(item_data),
				color,
				_get_item_quality_color(item_data, Color.WHITE),
				cell_rect,
				_build_passive_item_roll_entries(item_data, registry, mythic_item_runtime, runtime_state)
			)
	if max_scroll > 0.0:
		_draw_passive_inventory_scrollbar(canvas, grid_rect, max_scroll)
	return hover_data


func _draw_perk_grid(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	runtime_state: Object = null,
	icon_renderer_override: Object = null,
	runtime_snapshot_override: Variant = null,
	catalog_override: Object = null,
	equipped_skills_for_filter: Array = []
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "퍽", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var effective_runtime_state: Object = runtime_state
	if effective_runtime_state == null:
		effective_runtime_state = _get_instance(registry, "runtime_perk_state")
	var catalog: Object = catalog_override
	if catalog == null:
		catalog = _get_instance(registry, "runtime_perk_catalog")
	var icon_renderer: Object = icon_renderer_override
	if icon_renderer == null:
		icon_renderer = _get_instance(registry, "runtime_perk_icon_renderer")
	var can_draw_perk_icon: bool = icon_renderer != null and icon_renderer.has_method("draw_icon")
	var snapshot: Dictionary = {}
	if runtime_snapshot_override is Dictionary:
		snapshot = runtime_snapshot_override
	elif effective_runtime_state != null and effective_runtime_state.has_method("get_snapshot"):
		snapshot = effective_runtime_state.get_snapshot()
	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	if levels.is_empty() and not snapshot.has("runtime_skill_levels"):
		levels = _get_dict(_safe_owner_get(owner, "runtime_perk_levels", {}))
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
	var max_perk_scroll: float = _get_max_perk_scroll()
	perk_scroll = clamp(perk_scroll, 0.0, max_perk_scroll)
	var stride: float = cell_size + gap
	_update_perk_grid_layout(grid_rect, cell_size, stride, columns, acquired.size(), perk_scroll)
	var hovered_perk_index := -1
	if mouse_in_perk_grid_rect:
		hovered_perk_index = _get_hovered_grid_index(mouse_pos, _last_perk_grid_start.x, _last_perk_grid_start.y, _last_perk_grid_cell_size, _last_perk_grid_stride, columns, acquired.size())

	for i in _perk_grid_visible_index_cache:
		var cell_rect: Rect2 = _perk_grid_cell_rect_cache[i]
		var color: Color = _acquired_perk_draw_color_cache[i]
		var hovered: bool = i == hovered_perk_index
		var border_color: Color = _acquired_perk_border_color_cache[i]
		if hovered:
			border_color = _acquired_perk_hover_border_color_cache[i]
		canvas.draw_rect(cell_rect, OVERLAY_GRID_CELL_FILL)
		canvas.draw_rect(cell_rect, border_color, false, 2.0 if hovered else 1.0)
		var perk_id: String = _acquired_perk_draw_id_cache[i]
		if not can_draw_perk_icon or not bool(icon_renderer.draw_icon(canvas, perk_id, _perk_grid_icon_rect_cache[i], 1.0, true)):
			_draw_fallback_symbol(canvas, _perk_grid_icon_rect_cache[i], color, perk_id)
		var level_text: String = _acquired_perk_level_text_cache[i]
		var level_color: Color = _acquired_perk_level_color_cache[i]
		var level_text_size: Vector2 = _get_perk_level_text_size(font, level_text, 9)
		_draw_text_centered_with_size_xy(canvas, font, level_text, _perk_grid_center_x_cache[i], _perk_grid_level_y_cache[i], 9, level_color, level_text_size)
		if hovered:
			hover_data = _set_hover_data(
				hover_data,
				_acquired_perk_hover_title_cache[i],
				level_text,
				_acquired_perk_hover_body_cache[i],
				color
			)
	if max_perk_scroll > 0.0:
		_draw_scrollbar(canvas, grid_rect, max_perk_scroll)
	return hover_data


func _draw_lingpet_panel(canvas: CanvasItem, owner: Object, rect: Rect2, font: Font, mouse_pos: Vector2, hover_data: Dictionary) -> Dictionary:
	_last_lingpet_skill_icon_rects.clear()
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text_xy(canvas, font, "링펫", rect.position.x + 12.0, rect.position.y + 24.0, 13, ACCENT_BLUE)

	var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	canvas.draw_rect(content_rect, OVERLAY_GRID_FILL)
	var snapshot: Dictionary = _get_lingpet_panel_snapshot(owner)
	var state: String = str(snapshot.get("state", "none"))
	if state == "companion":
		return _draw_lingpet_companion_panel(canvas, content_rect, font, snapshot, mouse_pos, hover_data)

	var hits: int = int(snapshot.get("hatch_hits", 0))
	var required_hits: int = max(1, int(snapshot.get("required_hits", LINGPET_HATCH_REQUIRED_HITS)))
	var progress: float = clamp(float(hits) / float(required_hits), 0.0, 1.0)
	var compact: bool = content_rect.size.x < 260.0 or content_rect.size.y < 145.0
	var icon_size: float = clamp(min(content_rect.size.x * (0.36 if not compact else 0.28), content_rect.size.y * 0.54), 38.0, 82.0)
	var icon_rect: Rect2
	var text_x: float
	var text_y: float
	var text_w: float
	if compact:
		icon_rect = Rect2(content_rect.position.x + 10.0, content_rect.position.y + 10.0, icon_size, icon_size)
		text_x = icon_rect.end.x + 10.0
		text_y = content_rect.position.y + 23.0
		text_w = max(96.0, content_rect.end.x - text_x - 10.0)
	else:
		icon_rect = Rect2(content_rect.position.x + 16.0, content_rect.position.y + content_rect.size.y * 0.5 - icon_size * 0.5, icon_size, icon_size)
		text_x = icon_rect.end.x + 18.0
		text_y = content_rect.position.y + 36.0
		text_w = max(120.0, content_rect.end.x - text_x - 12.0)
	_draw_lingpet_egg_icon(canvas, icon_rect, state, progress)

	var title: String = str(snapshot.get("title", "링펫 알 없음"))
	var subtitle: String = str(snapshot.get("subtitle", "미획득"))
	var body: String = str(snapshot.get("body", ""))
	_draw_text_xy(canvas, font, title, text_x, text_y, 15, Color.WHITE)
	_draw_text_xy(canvas, font, subtitle, text_x, text_y + 24.0, 12, ACCENT_GOLD if state == "egg" else TEXT_SOFT)
	_draw_lingpet_wrapped_text(canvas, font, body, text_x, text_y + 48.0, text_w, 4)
	if state == "egg":
		var meter_rect := Rect2(text_x, min(content_rect.end.y - 24.0, text_y + 94.0), text_w, 8.0)
		_draw_lingpet_progress_bar(canvas, meter_rect, progress)
	return hover_data


func _draw_lingpet_companion_panel(
	canvas: CanvasItem,
	content_rect: Rect2,
	font: Font,
	snapshot: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary
) -> Dictionary:
	var title: String = str(snapshot.get("title", "링펫"))
	var subtitle: String = str(snapshot.get("subtitle", "동행 중"))
	var skill_specs: Array = _get_lingpet_skill_specs(snapshot)
	var skill_row_h: float = clamp(content_rect.size.y * 0.22, 58.0, 78.0)
	var title_y: float = content_rect.position.y + 26.0
	_draw_text_centered_xy(canvas, font, title, content_rect.get_center().x, title_y, 18, Color.WHITE)
	_draw_text_centered_xy(canvas, font, subtitle, content_rect.get_center().x, title_y + 23.0, 12, STAT_BUFF_COLOR)

	var art_rect: Rect2 = _get_lingpet_companion_art_rect(content_rect, skill_row_h)
	canvas.draw_rect(art_rect, Color(7.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 0.34))
	_draw_lingpet_art(canvas, art_rect, str(snapshot.get("pet_id", "")))

	var icon_count: int = max(1, skill_specs.size())
	var icon_gap: float = 9.0
	var icon_size: float = clamp((content_rect.size.x - 24.0 - icon_gap * float(icon_count - 1)) / float(icon_count), 38.0, 58.0)
	var icon_total_w: float = icon_size * float(icon_count) + icon_gap * float(icon_count - 1)
	var icon_x: float = content_rect.get_center().x - icon_total_w * 0.5
	var icon_y: float = content_rect.end.y - skill_row_h + (skill_row_h - icon_size) * 0.48
	for i in range(skill_specs.size()):
		var icon_rect := Rect2(icon_x + float(i) * (icon_size + icon_gap), icon_y, icon_size, icon_size)
		_last_lingpet_skill_icon_rects.append(icon_rect)
		var spec: Dictionary = skill_specs[i]
		hover_data = _draw_lingpet_skill_icon(canvas, font, icon_rect, spec, mouse_pos, hover_data)
	return hover_data


func _get_lingpet_companion_art_rect(content_rect: Rect2, skill_row_h: float) -> Rect2:
	return Rect2(
		content_rect.position.x + 10.0,
		content_rect.position.y + 44.0,
		content_rect.size.x - 20.0,
		max(82.0, content_rect.size.y - skill_row_h - 54.0)
	)


func _draw_lingpet_art(canvas: CanvasItem, rect: Rect2, pet_id: String = "") -> void:
	var glow_center := rect.get_center()
	var glow_radius: float = min(rect.size.x, rect.size.y) * 0.42
	for i in range(4, 0, -1):
		canvas.draw_circle(glow_center, glow_radius + float(i) * 11.0, Color(0.0, 205.0 / 255.0, 1.0, 0.018 * float(i)))
	var art_texture: Texture2D = _get_lingpet_art_texture(pet_id)
	if art_texture != null:
		_draw_texture_contained(canvas, art_texture, rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.96))
		return
	_draw_lingpet_egg_icon(canvas, Rect2(rect.get_center() - Vector2(44.0, 44.0), Vector2(88.0, 88.0)), "companion", 1.0)


func _get_lingpet_art_texture(pet_id: String) -> Texture2D:
	var path := ""
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if LingpetCatalog.has_pet(normalized_pet_id):
		path = LingpetCatalog.get_visual_path(normalized_pet_id, "cutin_art")
	if path == "":
		path = LingpetCatalog.get_visual_path(LingpetCatalog.get_default_pet_id(), "cutin_art")
	if path == "" or not FileAccess.file_exists(path):
		return null
	if _lingpet_art_texture_cache.has(path):
		var cached_texture: Variant = _lingpet_art_texture_cache[path]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
		_lingpet_art_texture_cache.erase(path)
	var texture := ProjectResourceLoader.load_texture(
		path,
		"Missing lingpet art texture at %s",
		"Failed to load lingpet art texture at %s"
	)
	if texture != null:
		_lingpet_art_texture_cache[path] = texture
		return texture
	return null


func _draw_lingpet_skill_icon(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	spec: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary
) -> Dictionary:
	var color: Color = _get_color(spec.get("color", ACCENT_BLUE))
	var hovered: bool = rect.has_point(mouse_pos)
	var border_color: Color = Color(color.r, color.g, color.b, 1.0 if hovered else 0.72)
	canvas.draw_rect(rect, OVERLAY_SLOT_FILL)
	canvas.draw_rect(rect, border_color, false, 2.0 if hovered else 1.0)
	var inner := rect.grow(-4.0)
	if bool(spec.get("use_card", false)):
		var card_texture: Texture2D = _get_lingpet_skill_icon_texture(str(spec.get("card_texture_path", "")))
		if card_texture != null:
			_draw_texture_cover(canvas, card_texture, inner, Color(1.0, 1.0, 1.0, 0.94))
		else:
			_draw_lingpet_skill_symbol(canvas, font, inner, str(spec.get("id", "")), color)
	else:
		var texture: Texture2D = _get_lingpet_skill_icon_texture(str(spec.get("icon_texture_id", "")))
		if texture != null:
			_draw_texture_contained(canvas, texture, inner, Color(1.0, 1.0, 1.0, 0.96))
		else:
			_draw_lingpet_skill_symbol(canvas, font, inner, str(spec.get("id", "")), color)
	var badge: String = str(spec.get("badge", ""))
	if badge != "":
		var badge_rect := Rect2(rect.end.x - 22.0, rect.position.y + 3.0, 19.0, 14.0)
		canvas.draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.58))
		canvas.draw_rect(badge_rect, Color(color.r, color.g, color.b, 0.88), false, 1.0)
		_draw_text_centered_xy(canvas, font, badge, badge_rect.get_center().x, badge_rect.position.y + 11.0, 8, Color.WHITE)
	if hovered:
		hover_data = _set_hover_data(
			hover_data,
			str(spec.get("title", "")),
			str(spec.get("subtitle", "")),
			str(spec.get("body", "")),
			color,
			null,
			rect
		)
	return hover_data


func _get_lingpet_skill_icon_texture(texture_id: String) -> Texture2D:
	var path: String = _get_lingpet_skill_icon_texture_path(texture_id)
	if path == "":
		return null
	if _lingpet_skill_icon_texture_cache.has(path):
		var cached_texture: Variant = _lingpet_skill_icon_texture_cache[path]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
		_lingpet_skill_icon_texture_cache.erase(path)
	var texture := ProjectResourceLoader.load_texture(
		path,
		"Missing lingpet skill icon at %s",
		"Failed to load lingpet skill icon at %s"
	)
	if texture != null:
		_lingpet_skill_icon_texture_cache[path] = texture
	return texture


func _get_lingpet_skill_icon_texture_path(texture_id: String) -> String:
	if texture_id.begins_with("res://"):
		return texture_id
	return ""


func _prewarm_lingpet_skill_icon_assets() -> void:
	for pet_id in LingpetCatalog.get_pet_ids():
		var skill: Dictionary = LingpetCatalog.get_active_skill(pet_id)
		if bool(skill.get("enabled", true)):
			_touch_texture(_get_lingpet_skill_icon_texture(str(skill.get("icon_texture_path", ""))))
			_touch_texture(_get_lingpet_skill_icon_texture(str(skill.get("card_texture_path", ""))))
		_touch_texture(_get_lingpet_skill_icon_texture(LingpetCatalog.get_passive_icon_path(pet_id, "gauge_gain_bonus")))


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


func _draw_lingpet_skill_symbol(canvas: CanvasItem, font: Font, rect: Rect2, id: String, color: Color) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.36
	canvas.draw_circle(center, radius + 7.0, Color(color.r, color.g, color.b, 0.12))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.26))
	canvas.draw_arc(center, radius, 0.0, TAU, FALLBACK_SYMBOL_RING_SEGMENTS, color, 2.0)
	match id:
		"resonance_boost":
			for i in range(3):
				var arc_radius: float = radius * (0.55 + float(i) * 0.18)
				canvas.draw_arc(center, arc_radius, -0.2 + float(i) * 0.42, PI + float(i) * 0.34, FALLBACK_SYMBOL_RING_SEGMENTS, Color(1.0, 1.0, 1.0, 0.36), 1.2)
			canvas.draw_circle(center, radius * 0.22, Color(1.0, 1.0, 1.0, 0.86))
			_draw_text_centered_xy(canvas, font, "+", center.x, center.y + radius * 0.18, int(radius * 0.95), Color.WHITE)
		_:
			_draw_fallback_symbol(canvas, rect, color, id)


func _draw_texture_contained(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale: float = min(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var dest_size: Vector2 = source_size * scale
	var dest := Rect2(rect.get_center() - dest_size * 0.5, dest_size)
	canvas.draw_texture_rect(texture, dest, false, modulate)


func _draw_texture_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source := Rect2(Vector2.ZERO, source_size)
	var target_ratio: float = rect.size.x / rect.size.y
	var source_ratio: float = source_size.x / source_size.y
	if source_ratio > target_ratio:
		source.size.x = source_size.y * target_ratio
		source.position.x = (source_size.x - source.size.x) * 0.5
	else:
		source.size.y = source_size.x / target_ratio
		source.position.y = (source_size.y - source.size.y) * 0.5
	canvas.draw_texture_rect_region(texture, rect, source, modulate, false, true)


func _get_lingpet_panel_snapshot(owner: Object) -> Dictionary:
	var lingpet_id: String = str(_safe_owner_get(owner, "lingpet_id", ""))
	if lingpet_id == "":
		lingpet_id = str(_safe_owner_get(owner, "active_lingpet_id", ""))
	if lingpet_id == "":
		lingpet_id = str(_safe_owner_get(owner, "current_lingpet_id", ""))
	var state: String = str(_safe_owner_get(owner, "lingpet_state", "")).to_lower()
	if state == "":
		state = str(_safe_owner_get(owner, "ringpet_state", "")).to_lower()
	var hits: int = int(_safe_owner_get(owner, "lingpet_hatch_hits", _safe_owner_get(owner, "ringpet_hatch_hits", 0)))
	var required_hits: int = max(1, int(_safe_owner_get(owner, "lingpet_hatch_required_hits", _safe_owner_get(owner, "ringpet_hatch_required_hits", LINGPET_HATCH_REQUIRED_HITS))))
	if state == "":
		if lingpet_id != "":
			state = "companion"
		elif hits > 0:
			state = "egg"
		else:
			state = "none"
	var display_name: String = _get_lingpet_display_name(lingpet_id)
	match state:
		"egg", "hatching", "알":
			return {
				"state": "egg",
				"title": "링펫 알",
				"subtitle": "공 충돌 " + _format_int_pair(hits, required_hits),
				"body": "공에 맞을 때마다 금이 가고, 가득 차면 링펫이 깨어납니다.",
				"hatch_hits": hits,
				"required_hits": required_hits,
			}
		"companion", "active", "owned", "동행":
			var catalog_skill := LingpetCatalog.get_active_skill(lingpet_id)
			var catalog_skill_enabled := bool(catalog_skill.get("enabled", true))
			var catalog_skill_id := str(catalog_skill.get("id", "")) if catalog_skill_enabled else ""
			var catalog_skill_name := str(catalog_skill.get("name", "")) if catalog_skill_enabled else ""
			var catalog_skill_description := str(catalog_skill.get("description", "")) if catalog_skill_enabled else ""
			var catalog_skill_card_path := str(catalog_skill.get("card_texture_path", "")) if catalog_skill_enabled else ""
			var catalog_skill_icon_path := str(catalog_skill.get("icon_texture_path", "")) if catalog_skill_enabled else ""
			var catalog_skill_cooldown := float(catalog_skill.get("cooldown", 0.0)) if catalog_skill_enabled else 0.0
			return {
				"state": "companion",
				"pet_id": lingpet_id,
				"title": display_name,
				"subtitle": "동행 중",
				"body": str(_safe_owner_get(owner, "lingpet_effect_text", "링펫 효과는 다음 단계에서 연결됩니다.")),
				"gauge_gain_bonus_pct": float(_safe_owner_get(owner, "lingpet_gauge_gain_bonus_pct", _safe_owner_get(owner, "ringpet_gauge_gain_bonus_pct", LingpetCatalog.get_stat(lingpet_id, "gauge_gain_bonus_pct", 0.0)))),
				"gauge_gain_bonus_icon_path": str(_safe_owner_get(owner, "lingpet_gauge_gain_bonus_icon_path", LingpetCatalog.get_passive_icon_path(lingpet_id, "gauge_gain_bonus"))),
				"companion_hit_gauge_gain": float(_safe_owner_get(owner, "lingpet_companion_hit_gauge_gain", _safe_owner_get(owner, "ringpet_companion_hit_gauge_gain", LingpetCatalog.get_stat(lingpet_id, "hit_gauge_gain", 40.0)))),
				"companion_skill_id": str(_safe_owner_get(owner, "lingpet_skill_id", _safe_owner_get(owner, "ringpet_skill_id", catalog_skill_id))),
				"companion_skill_name": str(_safe_owner_get(owner, "lingpet_skill_name", _safe_owner_get(owner, "ringpet_skill_name", catalog_skill_name))),
				"companion_skill_description": str(_safe_owner_get(owner, "lingpet_skill_description", _safe_owner_get(owner, "ringpet_skill_description", catalog_skill_description))),
				"companion_skill_card_path": str(_safe_owner_get(owner, "lingpet_skill_card_path", _safe_owner_get(owner, "ringpet_skill_card_path", catalog_skill_card_path))),
				"companion_skill_icon_path": str(_safe_owner_get(owner, "lingpet_skill_icon_path", _safe_owner_get(owner, "ringpet_skill_icon_path", catalog_skill_icon_path))),
				"companion_skill_cooldown_duration": float(_safe_owner_get(owner, "lingpet_skill_cooldown_duration", _safe_owner_get(owner, "ringpet_skill_cooldown_duration", catalog_skill_cooldown))),
				"companion_patrol_speed_default": float(_safe_owner_get(owner, "lingpet_companion_patrol_speed_default", _safe_owner_get(owner, "ringpet_companion_patrol_speed_default", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_default", 120.0)))),
				"companion_patrol_speed_min": float(_safe_owner_get(owner, "lingpet_companion_patrol_speed_min", _safe_owner_get(owner, "ringpet_companion_patrol_speed_min", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_min", 70.0)))),
				"companion_patrol_speed_max": float(_safe_owner_get(owner, "lingpet_companion_patrol_speed_max", _safe_owner_get(owner, "ringpet_companion_patrol_speed_max", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_max", 135.0)))),
				"companion_catch_width": float(_safe_owner_get(owner, "lingpet_companion_catch_width", _safe_owner_get(owner, "ringpet_companion_catch_width", LingpetCatalog.get_stat(lingpet_id, "catch_width", 100.0)))),
				"companion_catch_height": float(_safe_owner_get(owner, "lingpet_companion_catch_height", _safe_owner_get(owner, "ringpet_companion_catch_height", LingpetCatalog.get_stat(lingpet_id, "catch_height", 44.0)))),
				"companion_defense_rate": float(_safe_owner_get(owner, "lingpet_companion_defense_rate", _safe_owner_get(owner, "ringpet_companion_defense_rate", LingpetCatalog.get_stat(lingpet_id, "defense_rate", 0.0)))),
				"hatch_hits": required_hits,
				"required_hits": required_hits,
			}
		_:
			return {
				"state": "none",
				"title": "링펫 알 없음",
				"subtitle": "미획득",
				"body": "주니어리그에서 미카로 플레이하면 첫 링펫 알이 나타납니다.",
				"hatch_hits": 0,
				"required_hits": required_hits,
			}


func _get_lingpet_display_name(lingpet_id: String) -> String:
	if LingpetCatalog.has_pet(lingpet_id):
		return LingpetCatalog.get_display_name(lingpet_id)
	match lingpet_id:
		"maribo":
			return "마리보"
		"":
			return "링펫"
		_:
			return lingpet_id


func _get_lingpet_skill_specs(snapshot: Dictionary) -> Array:
	var specs: Array = []
	var skill_id: String = str(snapshot.get("companion_skill_id", "")).strip_edges()
	if skill_id != "":
		var skill_name: String = str(snapshot.get("companion_skill_name", "")).strip_edges()
		if skill_name == "":
			skill_name = "액티브 스킬"
		var active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration", 0.0))
		var skill_description: String = str(snapshot.get("companion_skill_description", "")).strip_edges()
		if skill_description == "":
			skill_description = "링펫이 전투 중 자동으로 사용하는 액티브 스킬입니다."
		var icon_texture_id := str(snapshot.get("companion_skill_icon_path", "")).strip_edges()
		specs.append({
			"id": skill_id,
			"title": skill_name,
			"subtitle": "액티브 · 쿨타임 " + _format_seconds_text(active_cooldown),
			"body": skill_description,
			"color": Color(80.0 / 255.0, 220.0 / 255.0, 1.0),
			"badge": "A",
			"use_card": icon_texture_id == "",
			"icon_texture_id": icon_texture_id,
			"card_texture_path": str(snapshot.get("companion_skill_card_path", "")),
		})
	var gauge_bonus_pct: float = float(snapshot.get("gauge_gain_bonus_pct", 0.0))
	if gauge_bonus_pct > 0.0:
		specs.append({
			"id": "resonance_boost",
			"title": "공명 증폭",
			"subtitle": "패시브 · 받아치기 +" + _format_percent_text(gauge_bonus_pct),
			"body": "플레이어가 공을 받아칠 때 게이지 획득량이 증가합니다.",
			"color": STAT_BUFF_COLOR,
			"badge": "P",
			"icon_texture_id": str(snapshot.get("gauge_gain_bonus_icon_path", "")),
		})
	return specs


func _draw_lingpet_egg_icon(canvas: CanvasItem, rect: Rect2, state: String, progress: float) -> void:
	var center := rect.get_center()
	var rx: float = rect.size.x * 0.34
	var ry: float = rect.size.y * 0.43
	var egg_color := Color(1.0, 170.0 / 255.0, 218.0 / 255.0, 0.28)
	var ring_color := Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.82)
	if state == "companion":
		egg_color = Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0, 0.24)
		ring_color = STAT_BUFF_COLOR
	for i in range(5, 0, -1):
		canvas.draw_circle(center, max(rx, ry) + float(i) * 3.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.018 * float(i)))
	canvas.draw_colored_polygon(_lingpet_ellipse_points(center, rx, ry), egg_color)
	canvas.draw_arc(center, max(rx, ry) * 0.84, 0.0, TAU, FALLBACK_SYMBOL_RING_SEGMENTS, ring_color, 2.0)
	canvas.draw_circle(center + Vector2(-rx * 0.24, -ry * 0.22), max(2.0, rx * 0.09), Color(1.0, 1.0, 1.0, 0.58))
	if state == "egg" and progress > 0.0:
		var crack_color := Color(1.0, 245.0 / 255.0, 170.0 / 255.0, 0.88)
		var crack_bottom: float = center.y - ry * 0.2 + ry * 0.95 * progress
		canvas.draw_polyline(PackedVector2Array([
			center + Vector2(-rx * 0.08, -ry * 0.62),
			center + Vector2(rx * 0.10, -ry * 0.30),
			center + Vector2(-rx * 0.02, -ry * 0.06),
			Vector2(center.x + rx * 0.18, crack_bottom),
		]), crack_color, 1.8)
	elif state == "none":
		_draw_locked_slot_rect(canvas, rect.grow(-8.0), OVERLAY_GRID_EMPTY_TEXT)
	else:
		_draw_text_centered_xy(canvas, ThemeDB.fallback_font, "M", center.x, center.y + 4.0, int(rect.size.x * 0.30), Color.WHITE)


func _lingpet_ellipse_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(18):
		var angle: float = TAU * float(i) / 18.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _draw_lingpet_progress_bar(canvas: CanvasItem, rect: Rect2, progress: float) -> void:
	canvas.draw_rect(rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(progress, 0.0, 1.0), rect.size.y)), Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.82))
	canvas.draw_rect(rect, Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.85), false, 1.0)


func _draw_lingpet_wrapped_text(canvas: CanvasItem, font: Font, text: String, x: float, y: float, max_width: float, max_lines: int) -> void:
	var lines: Array = _wrap_text_to_width(font, LanguageSettings.translate_text(text), 11, max_width, max_lines)
	for i in range(lines.size()):
		_draw_text_xy(canvas, font, str(lines[i]), x, y + float(i) * 18.0, 11, OVERLAY_GRID_EMPTY_TEXT)


func _draw_stats_panel(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	runtime_state_override: Object = null,
	active_item_runtime_override: Object = null,
	mythic_item_runtime_override: Object = null,
	character_type_override: String = "",
	stat_sources_override: Array = [],
	mouse_pos: Vector2 = Vector2.INF,
	hover_data: Dictionary = {},
	active_item_slot_capacity_override: int = -1,
	active_item_slots_override: Variant = null
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
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
	var inner_rect := Rect2(rect.position.x + 12.0, rect.position.y + 38.0, rect.size.x - 24.0, rect.size.y - 50.0)
	var column_gap := 18.0
	var player_rect: Rect2
	var lingpet_rect: Rect2
	if inner_rect.size.x >= 620.0:
		var column_w: float = (inner_rect.size.x - column_gap) * 0.5
		player_rect = Rect2(inner_rect.position, Vector2(column_w, inner_rect.size.y))
		lingpet_rect = Rect2(player_rect.end.x + column_gap, inner_rect.position.y, column_w, inner_rect.size.y)
		var divider_x: float = player_rect.end.x + column_gap * 0.5
		canvas.draw_line(Vector2(divider_x, inner_rect.position.y + 2.0), Vector2(divider_x, inner_rect.end.y - 2.0), Color(78.0 / 255.0, 112.0 / 255.0, 165.0 / 255.0, 0.34), 1.0)
	else:
		var row_gap := 10.0
		var row_h: float = (inner_rect.size.y - row_gap) * 0.5
		player_rect = Rect2(inner_rect.position, Vector2(inner_rect.size.x, row_h))
		lingpet_rect = Rect2(inner_rect.position.x, player_rect.end.y + row_gap, inner_rect.size.x, row_h)
	_draw_cached_player_stat_rows(canvas, font, "플레이어 능력치", player_rect)
	hover_data = _draw_stat_rows(canvas, font, "링펫 능력치", lingpet_rows, lingpet_rect, mouse_pos, hover_data)
	return hover_data


func _draw_cached_player_stat_rows(canvas: CanvasItem, font: Font, title: String, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.34))
	_draw_text_xy(canvas, font, title, rect.position.x + 2.0, rect.position.y + 20.0, 12, ACCENT_BLUE)
	var row_count: int = _stats_row_count
	if row_count <= 0:
		_draw_text_centered_xy(canvas, font, "표시할 능력치 없음", rect.get_center().x, rect.get_center().y + 4.0, 12, OVERLAY_GRID_EMPTY_TEXT)
		return
	var start_y: float = rect.position.y + 46.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(26.0, available_h / float(max(1, row_count)))
	var row_size := 13
	if line_gap < 20.0:
		row_size = 12
	if line_gap < 18.0:
		row_size = 11
	line_gap = max(16.0, line_gap)
	var label_x: float = rect.position.x + 2.0
	var value_right_x: float = rect.end.x - 2.0
	for i in range(row_count):
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		_draw_text_xy(canvas, font, _stats_label_cache[i], label_x, baseline_y, row_size, TEXT_DIM)
		var value_text: String = _stats_value_cache[i]
		var value_color: Color = _stats_color_cache[i]
		var value_width: float = _get_stats_value_width(font, i, value_text, row_size)
		_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color)


func _draw_stat_rows(
	canvas: CanvasItem,
	font: Font,
	title: String,
	rows: Array,
	rect: Rect2,
	mouse_pos: Vector2 = Vector2.INF,
	hover_data: Dictionary = {}
) -> Dictionary:
	canvas.draw_rect(rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.34))
	_draw_text_xy(canvas, font, title, rect.position.x + 2.0, rect.position.y + 20.0, 12, ACCENT_BLUE)
	_last_lingpet_stat_row_rects.clear()
	var row_count: int = rows.size()
	if row_count <= 0:
		_draw_text_centered_xy(canvas, font, "표시할 능력치 없음", rect.get_center().x, rect.get_center().y + 4.0, 12, OVERLAY_GRID_EMPTY_TEXT)
		return hover_data
	var start_y: float = rect.position.y + 46.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(26.0, available_h / float(max(1, row_count)))
	var row_size := 13
	if line_gap < 20.0:
		row_size = 12
	if line_gap < 18.0:
		row_size = 11
	line_gap = max(16.0, line_gap)
	var label_x: float = rect.position.x + 2.0
	var value_right_x: float = rect.end.x - 2.0
	for i in range(row_count):
		var row_value: Variant = rows[i]
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		var row_rect := Rect2(rect.position.x, baseline_y - float(row_size) - 5.0, rect.size.x, line_gap)
		_last_lingpet_stat_row_rects.append(row_rect)
		var label: String = str(row.get("label", ""))
		var value_text: String = str(row.get("value", ""))
		var value_color: Color = _get_color(row.get("color", Color.WHITE))
		_draw_text_xy(canvas, font, label, label_x, baseline_y, row_size, TEXT_DIM)
		var value_width: float = _text_size(font, value_text, row_size).x
		_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color)
		var tooltip_body: String = str(row.get("tooltip_body", ""))
		if tooltip_body != "":
			if row_rect.has_point(mouse_pos):
				hover_data = _set_hover_data(
					hover_data,
					str(row.get("tooltip_title", label)),
					str(row.get("tooltip_subtitle", value_text)),
					tooltip_body,
					value_color,
					null,
					row_rect
				)
	return hover_data


func _build_lingpet_stats(owner: Object) -> Array:
	var snapshot: Dictionary = _get_lingpet_panel_snapshot(owner)
	var cache_hash: int = _get_lingpet_stats_cache_hash(snapshot)
	if _lingpet_stats_cache_ready and cache_hash == _lingpet_stats_cache_hash:
		return _lingpet_stats_cache
	var state: String = str(snapshot.get("state", "none"))
	if state == "egg":
		var hits: int = int(snapshot.get("hatch_hits", 0))
		var required_hits: int = max(1, int(snapshot.get("required_hits", LINGPET_HATCH_REQUIRED_HITS)))
		return _cache_lingpet_stats_rows(cache_hash, [
			_make_display_stat_row("상태", "알", ACCENT_GOLD),
			_make_display_stat_row("부화 진행", _format_int_pair(hits, required_hits), TEXT_SOFT),
		])
	if state != "companion":
		return _cache_lingpet_stats_rows(cache_hash, [
			_make_display_stat_row("상태", "미획득", OVERLAY_GRID_EMPTY_TEXT),
		])
	var speed_default: float = float(snapshot.get("companion_patrol_speed_default", 120.0))
	var speed_min: float = float(snapshot.get("companion_patrol_speed_min", 70.0))
	var speed_max: float = float(snapshot.get("companion_patrol_speed_max", 135.0))
	var catch_width: float = float(snapshot.get("companion_catch_width", 100.0))
	var catch_height: float = float(snapshot.get("companion_catch_height", 44.0))
	var hit_gain: float = float(snapshot.get("companion_hit_gauge_gain", 40.0))
	var skill_id: String = str(snapshot.get("companion_skill_id", "")).strip_edges()
	var skill_name: String = str(snapshot.get("companion_skill_name", "")).strip_edges()
	if skill_name == "":
		skill_name = "액티브 스킬"
	var active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration", 40.0))
	var defense_rate: float = float(snapshot.get("companion_defense_rate", 0.0))
	var speed_display: float = speed_default / LINGPET_SPEED_DISPLAY_PX_PER_POINT
	var rows := [
		_make_display_stat_row("이동 속도", "%.2f" % speed_display, Color.WHITE, "마리보가 플레이어 진영에서 독자적으로 순찰할 때 쓰는 기본 이동 속도입니다. 실제 순찰은 %s~%spx/s 사이에서 자연스럽게 변동됩니다." % [_format_plain_number(speed_min), _format_plain_number(speed_max)]),
		_make_display_stat_row("몸집크기", "%sx%spx" % [_format_plain_number(catch_width), _format_plain_number(catch_height)], Color.WHITE, "마리보가 공을 튕겨낼 때 쓰는 실제 판정 범위입니다."),
		_make_display_stat_row("게이지 획득량", "%spt" % _format_plain_number(hit_gain), STAT_BUFF_COLOR, "링펫이 공을 직접 튕겼을 때 얻는 공통 기본 게이지 획득량입니다."),
		_make_display_stat_row("방어율", _format_percent_text(defense_rate * 100.0), STAT_BUFF_COLOR, "공을 적극적으로 막으러 이동할 확률입니다. 높을수록 수비 행동을 더 자주 시도합니다."),
	]
	if skill_id != "":
		rows.insert(3, _make_display_stat_row("액티브 쿨타임", _format_seconds_text(active_cooldown), Color.WHITE, "%s을(를) 다시 사용할 수 있게 되는 시간입니다." % skill_name))
	return _cache_lingpet_stats_rows(cache_hash, rows)


func _cache_lingpet_stats_rows(cache_hash: int, rows: Array) -> Array:
	_lingpet_stats_cache_hash = cache_hash
	_lingpet_stats_cache = rows.duplicate(true)
	_lingpet_stats_cache_ready = true
	return _lingpet_stats_cache


func _get_lingpet_stats_cache_hash(snapshot: Dictionary) -> int:
	var state: String = str(snapshot.get("state", "none"))
	if state == "egg":
		return hash([
			LanguageSettings.get_language(),
			state,
			int(snapshot.get("hatch_hits", 0)),
			int(snapshot.get("required_hits", LINGPET_HATCH_REQUIRED_HITS)),
		])
	if state != "companion":
		return hash([LanguageSettings.get_language(), state])
	return hash([
		LanguageSettings.get_language(),
		state,
		float(snapshot.get("companion_patrol_speed_default", 120.0)),
		float(snapshot.get("companion_patrol_speed_min", 70.0)),
		float(snapshot.get("companion_patrol_speed_max", 135.0)),
		float(snapshot.get("companion_catch_width", 100.0)),
		float(snapshot.get("companion_catch_height", 44.0)),
		float(snapshot.get("companion_hit_gauge_gain", 40.0)),
		str(snapshot.get("companion_skill_id", "")).strip_edges(),
		str(snapshot.get("companion_skill_name", "")).strip_edges(),
		float(snapshot.get("companion_skill_cooldown_duration", 40.0)),
		float(snapshot.get("companion_defense_rate", 0.0)),
	])


func _make_display_stat_row(label: String, value_text: String, color: Color, tooltip_body: String = "") -> Dictionary:
	var row := {
		"label": LanguageSettings.translate_text(label),
		"value": LanguageSettings.translate_text(value_text),
		"color": color,
	}
	if tooltip_body != "":
		row["tooltip_title"] = LanguageSettings.translate_text(label)
		row["tooltip_subtitle"] = LanguageSettings.translate_text(value_text)
		row["tooltip_body"] = LanguageSettings.translate_text(tooltip_body)
	return row


func _update_stats_layout(rect: Rect2, stats_count: int) -> void:
	if stats_count == _stats_layout_count and _stats_layout_rect.is_equal_approx(rect):
		return
	_stats_layout_rect = rect
	_stats_layout_count = stats_count
	_stats_layout_label_x.clear()
	_stats_layout_baseline_y.clear()
	_stats_layout_value_right_x.clear()
	_stats_layout_visible_count = 0
	var start_y: float = rect.position.y + 48.0
	var columns: int = 2 if rect.size.x >= 430.0 and stats_count > 10 else 1
	var rows_per_column: int = max(1, int(ceil(float(stats_count) / float(columns))))
	var row_size := 13
	var available_h: float = max(1.0, rect.end.y - start_y - 10.0)
	var line_gap := 26.0
	if rows_per_column > 0:
		line_gap = min(line_gap, available_h / float(rows_per_column))
	if line_gap < 20.0:
		row_size = 12
	if line_gap < 18.0:
		row_size = 11
	line_gap = max(16.0, line_gap)
	var content_x: float = rect.position.x + 14.0
	var content_w: float = rect.size.x - 28.0
	var column_gap := 20.0 if columns > 1 else 0.0
	var column_w: float = (content_w - column_gap * float(columns - 1)) / float(columns)
	var column_stride: float = column_w + column_gap
	_stats_layout_row_size = row_size
	for i in range(stats_count):
		@warning_ignore("integer_division")
		var column: int = int(i / rows_per_column)
		var row: int = i % rows_per_column
		var x: float = content_x + float(column) * column_stride
		var y: float = start_y + float(row) * line_gap
		if y > rect.end.y - 12.0:
			break
		_stats_layout_label_x.append(x)
		_stats_layout_baseline_y.append(y)
		_stats_layout_value_right_x.append(x + column_w)
	_stats_layout_visible_count = _stats_layout_baseline_y.size()


func _build_stats(
	owner: Object,
	registry: Object,
	runtime_state_override: Object = null,
	active_item_runtime_override: Object = null,
	mythic_item_runtime_override: Object = null,
	character_type_override: String = "",
	stat_sources_override: Array = [],
	write_row_cache: bool = true,
	active_item_slot_capacity_override: int = -1,
	active_item_slots_override: Variant = null
) -> Array:
	var character_type: String = character_type_override
	if character_type == "":
		character_type = _get_character_type(owner)
	var runtime_state: Object = runtime_state_override
	if runtime_state == null:
		runtime_state = _get_instance(registry, "runtime_perk_state")
	var active_item_runtime: Object = active_item_runtime_override
	if active_item_runtime == null:
		active_item_runtime = _get_instance(registry, "active_item_runtime")
	var mythic_item_runtime: Object = mythic_item_runtime_override
	if mythic_item_runtime == null:
		mythic_item_runtime = _get_instance(registry, "mythic_item_runtime")
	var lingpet_runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	var stat_sources: Array = stat_sources_override if not stat_sources_override.is_empty() else [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]
	var smasher_recovery_state: Object = _get_instance(registry, "smasher_recovery_state") if character_type == "smasher" else null
	var combo_key: String = _character_runtime.get_combo_state_key(character_type) if _character_runtime != null else ""
	var combo_state: Object = _get_instance(registry, combo_key) if combo_key != "" else null
	var base_max_gauge: float = SPECIAL_GAUGE_MAX
	var base_move_speed: float = _get_base_move_speed(character_type)
	var base_paddle_width: float = PLAYER_BASE_PADDLE_WIDTH
	var base_gauge_gain: float = BallUpdateStaticConfig.GAUGE_CHARGE_PER_HIT
	var base_dash_distance: float = (
		SmasherDashState.DASH_BASE_DURATION_FRAMES
		* SmasherDashSpiritState.DASH_FRAME_SPEED
		* SmasherDashSpiritState.DASH_DISTANCE_SCALE
	)
	var base_dash_recovery_seconds: float = _frames_to_seconds(SmasherDashState.DASH_BASE_RECOVERY_FRAMES)
	var base_dash_cooldown_seconds: float = _frames_to_seconds(SmasherDashState.DASH_BASE_RECHARGE_FRAMES)
	var base_item_cooldown_seconds: float = float(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC) / 1000.0
	var max_gauge: float = _get_effective_max_gauge(owner, stat_sources)
	var move_speed: float = _get_effective_move_speed(character_type, runtime_state, smasher_recovery_state, active_item_runtime, mythic_item_runtime)
	var paddle_width: float = _get_effective_player_paddle_width(owner, runtime_state, active_item_runtime, mythic_item_runtime)
	var gauge_gain: float = _get_effective_gauge_gain_per_hit(character_type, combo_state, stat_sources)
	var dash_distance: float = _get_effective_dash_distance(stat_sources)
	var dash_recovery_seconds: float = _frames_to_seconds(_get_effective_dash_recovery_frames(stat_sources))
	var dash_cooldown_seconds: float = _frames_to_seconds(_get_effective_dash_recharge_frames(stat_sources))
	var item_cooldown_seconds: float = float(_get_effective_default_active_item_cooldown_msec(registry, stat_sources)) / 1000.0
	var active_item_slot_capacity: int = active_item_slot_capacity_override
	if active_item_slot_capacity < 1:
		active_item_slot_capacity = _get_active_item_slot_capacity_for_sources(runtime_state, mythic_item_runtime)
	var active_item_slot_count: int = _get_active_item_slot_count(owner, active_item_slots_override)
	var active_item_slot_color: Color = _stat_delta_color(
		float(BASE_ACTIVE_ITEM_SLOT_COUNT),
		float(active_item_slot_capacity),
		true
	)

	_ensure_stats_row_cache(STAT_ROW_COUNT)
	_write_delta_stat_row(0, "이동 속도", "%.2f" % move_speed, base_move_speed, move_speed, true, write_row_cache)
	_write_delta_stat_row(1, "몸집크기", "%.0fpx" % paddle_width, base_paddle_width, paddle_width, true, write_row_cache)
	_write_delta_stat_row(2, LanguageSettings.translate_text("게이지 획득량"), "%dpt" % int(round(gauge_gain)), base_gauge_gain, gauge_gain, true, write_row_cache)
	_write_delta_stat_row(3, "최대 게이지", "%dpt" % int(round(max_gauge)), base_max_gauge, max_gauge, true, write_row_cache)
	_write_delta_stat_row(4, "대시 거리", "%dpx" % int(round(dash_distance)), base_dash_distance, dash_distance, true, write_row_cache)
	_write_delta_stat_row(5, "대시 후딜시간", "%.2f초" % dash_recovery_seconds, base_dash_recovery_seconds, dash_recovery_seconds, false, write_row_cache)
	_write_delta_stat_row(6, "대시쿨타임", "%.2f초" % dash_cooldown_seconds, base_dash_cooldown_seconds, dash_cooldown_seconds, false, write_row_cache)
	_write_delta_stat_row(7, "아이템쿨타임", "%.2f초" % item_cooldown_seconds, base_item_cooldown_seconds, item_cooldown_seconds, false, write_row_cache)
	_write_simple_stat_row(8, "액티브 아이템 슬롯", _format_int_pair(active_item_slot_count, active_item_slot_capacity), active_item_slot_color, write_row_cache)
	_stats_row_count = STAT_ROW_COUNT
	return _stats_row_cache


func _ensure_stats_row_cache(row_count: int) -> void:
	while _stats_row_cache.size() < row_count:
		_stats_row_cache.append({})
		_stats_label_cache.append("")
		_stats_value_cache.append("")
		_stats_color_cache.append(Color.WHITE)
		_stats_value_width_cache.append(0.0)
		_stats_value_width_text_cache.append("")
		_stats_value_width_size_cache.append(0)
		_stats_value_width_font_id_cache.append(0)
	while _stats_row_cache.size() > row_count:
		_stats_row_cache.pop_back()
		_stats_label_cache.pop_back()
		_stats_value_cache.pop_back()
		_stats_color_cache.pop_back()
		_stats_value_width_cache.pop_back()
		_stats_value_width_text_cache.pop_back()
		_stats_value_width_size_cache.pop_back()
		_stats_value_width_font_id_cache.pop_back()


func _ensure_stats_row_index(index: int) -> void:
	while _stats_row_cache.size() <= index:
		_stats_row_cache.append({})
		_stats_label_cache.append("")
		_stats_value_cache.append("")
		_stats_color_cache.append(Color.WHITE)
		_stats_value_width_cache.append(0.0)
		_stats_value_width_text_cache.append("")
		_stats_value_width_size_cache.append(0)
		_stats_value_width_font_id_cache.append(0)


func _get_stats_value_width(font: Font, index: int, value_text: String, size: int) -> float:
	_ensure_stats_row_index(index)
	var font_id := 0
	if font != null:
		font_id = int(font.get_instance_id())
	if (
		_stats_value_width_text_cache[index] == value_text
		and _stats_value_width_size_cache[index] == size
		and _stats_value_width_font_id_cache[index] == font_id
	):
		return _stats_value_width_cache[index]
	var value_width: float = _text_size(font, value_text, size).x
	_stats_value_width_text_cache[index] = value_text
	_stats_value_width_size_cache[index] = size
	_stats_value_width_font_id_cache[index] = font_id
	_stats_value_width_cache[index] = value_width
	return value_width


func _write_simple_stat_row(index: int, label: String, value_text: String, color: Color, write_row_cache: bool = true) -> void:
	label = LanguageSettings.translate_text(label)
	value_text = LanguageSettings.translate_text(value_text)
	if write_row_cache:
		var row: Dictionary = _get_stats_row(index)
		row["label"] = label
		row["value"] = value_text
		row["color"] = color
	_stats_label_cache[index] = label
	_stats_value_cache[index] = value_text
	_stats_color_cache[index] = color


func _write_delta_stat_row(
	index: int,
	label: String,
	value_text: String,
	base_value: float,
	current_value: float,
	higher_is_better: bool = true,
	write_row_cache: bool = true
) -> void:
	label = LanguageSettings.translate_text(label)
	value_text = LanguageSettings.translate_text(value_text)
	var color: Color = _stat_delta_color(base_value, current_value, higher_is_better)
	if write_row_cache:
		var row: Dictionary = _get_stats_row(index)
		row["label"] = label
		row["value"] = value_text
		row["base"] = base_value
		row["current"] = current_value
		row["higher_is_better"] = higher_is_better
		row["color"] = color
	_stats_label_cache[index] = label
	_stats_value_cache[index] = value_text
	_stats_color_cache[index] = color


func _get_stats_row(index: int) -> Dictionary:
	_ensure_stats_row_index(index)
	return _stats_row_cache[index]


func _get_runtime_perk_gold(owner: Object, runtime_snapshot: Dictionary) -> int:
	if runtime_snapshot.has("gold_from_perks"):
		return int(runtime_snapshot.get("gold_from_perks", 0))
	return int(_safe_owner_get(owner, "runtime_perk_gold", 0))


func _stat_delta_color(base_value: float, current_value: float, higher_is_better: bool = true) -> Color:
	var delta: float = current_value - base_value
	if abs(delta) <= 0.001:
		return Color.WHITE
	var improved: bool = delta > 0.0 if higher_is_better else delta < 0.0
	return STAT_BUFF_COLOR if improved else STAT_DEBUFF_COLOR


func _get_max_gauge(owner: Object) -> float:
	return max(1.0, float(_safe_owner_get(owner, "special_gauge_max", SPECIAL_GAUGE_MAX)))


func _get_effective_max_gauge(owner: Object, stat_sources: Array) -> float:
	return max(1.0, _apply_stat_chain(_get_max_gauge(owner), stat_sources, "get_special_gauge_max"))


func _get_effective_move_speed(
	character_type: String,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object
) -> float:
	return _get_base_move_speed(character_type) * _get_effective_move_speed_multiplier(
		character_type,
		runtime_state,
		smasher_recovery_state,
		active_item_runtime,
		mythic_item_runtime
	)


func _get_base_move_speed(character_type: String) -> float:
	var config: Dictionary = _character_runtime.get_base_movement_config(character_type) if _character_runtime != null else {}
	return max(
		float(config.get("paddle_speed", 0.0)),
		float(config.get("paddle_max_speed", 0.0))
	)


func _get_effective_move_speed_multiplier(
	character_type: String,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object
) -> float:
	var multiplier: float = 1.0
	multiplier *= _call_numeric_multiplier(runtime_state, "get_player_speed_multiplier")
	if character_type == "smasher":
		multiplier *= _call_numeric_multiplier(smasher_recovery_state, "get_player_speed_multiplier")
	multiplier *= _call_numeric_multiplier(active_item_runtime, "get_player_speed_multiplier")
	multiplier *= _call_numeric_multiplier(mythic_item_runtime, "get_player_speed_multiplier")
	return max(0.0, multiplier)


func _get_effective_player_paddle_width(owner: Object, runtime_state: Object, active_item_runtime: Object, mythic_item_runtime: Object) -> float:
	var owner_width: float = float(_safe_owner_get(owner, "player_paddle_width", 0.0))
	var runtime_scale: float = _get_runtime_paddle_scale(owner, runtime_state)
	var mythic_item_scale: float = _call_numeric_multiplier(mythic_item_runtime, "get_player_paddle_scale")
	var base_width: float = PLAYER_BASE_PADDLE_WIDTH * runtime_scale * mythic_item_scale
	var active_item_scale: float = _call_numeric_multiplier(active_item_runtime, "get_player_paddle_scale")
	var calculated_width: float = base_width
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_width"):
		calculated_width = max(1.0, float(active_item_runtime.get_player_paddle_width(base_width)))
	if abs(runtime_scale - 1.0) > 0.001 or abs(mythic_item_scale - 1.0) > 0.001 or abs(active_item_scale - 1.0) > 0.001:
		return calculated_width
	return max(1.0, owner_width if owner_width > 0.0 else calculated_width)


func _get_runtime_paddle_scale(owner: Object, runtime_state: Object) -> float:
	if runtime_state != null and runtime_state.has_method("get_player_paddle_size_multiplier"):
		return max(0.1, float(runtime_state.get_player_paddle_size_multiplier()))
	return max(0.1, float(_safe_owner_get(owner, "runtime_paddle_scale", 1.0)))


func _get_effective_gauge_gain_per_hit(_character_type: String, combo_state: Object, stat_sources: Array) -> float:
	var gauge_gain: float = BallUpdateStaticConfig.GAUGE_CHARGE_PER_HIT
	if combo_state != null and combo_state.has_method("get_gauge_gain"):
		gauge_gain = float(combo_state.get_gauge_gain(gauge_gain))
	return max(0.0, _apply_stat_chain(gauge_gain, stat_sources, "get_gauge_gain_per_hit"))


func _get_effective_dash_distance(stat_sources: Array) -> float:
	var duration_frames: float = _get_effective_dash_duration_frames(stat_sources)
	return max(1.0, duration_frames * SmasherDashSpiritState.DASH_FRAME_SPEED * SmasherDashSpiritState.DASH_DISTANCE_SCALE)


func _get_effective_dash_duration_frames(stat_sources: Array) -> float:
	return max(1.0, _apply_stat_chain(
		SmasherDashState.DASH_BASE_DURATION_FRAMES,
		stat_sources,
		"get_dash_duration_frames"
	))


func _get_effective_dash_recovery_frames(stat_sources: Array) -> float:
	return max(1.0, _apply_stat_chain(
		SmasherDashState.DASH_BASE_RECOVERY_FRAMES,
		stat_sources,
		"get_dash_recovery_frames"
	))


func _get_effective_dash_recharge_frames(stat_sources: Array) -> float:
	return max(1.0, _apply_stat_chain(
		SmasherDashState.DASH_BASE_RECHARGE_FRAMES,
		stat_sources,
		"get_dash_recharge_frames"
	))


func _frames_to_seconds(frames: float) -> float:
	return max(0.0, float(frames)) / 60.0


func _draw_tooltip(canvas: CanvasItem, data: Dictionary, mouse_pos: Vector2, view_size: Vector2, font: Font) -> void:
	var color: Color = _get_color(data.get("color", ACCENT_BLUE))
	var title: String = str(data.get("title", ""))
	var title_color: Color = _get_color(data.get("title_color", Color.WHITE))
	var subtitle: String = str(data.get("subtitle", ""))
	var body: String = str(data.get("body", ""))
	var roll_entries: Array = _get_tooltip_roll_entries(data)
	if not roll_entries.is_empty() and body != "":
		_draw_dual_item_tooltip(canvas, data, mouse_pos, view_size, font, color, title, subtitle, body, roll_entries)
		return
	var width: float = _get_tooltip_width(font, title, subtitle, body, view_size)
	var text_width: float = width - 28.0
	var title_lines: Array = _wrap_text_to_width(font, title, 15, text_width, 2)
	var subtitle_lines: Array = _wrap_text_to_width(font, subtitle, 12, text_width, 2)
	var line_height := 20.0
	var max_tooltip_height: float = max(80.0, view_size.y - 16.0)
	var fixed_height: float = 38.0 + float(title_lines.size() + subtitle_lines.size()) * line_height
	var body_line_limit: int = max(1, int(floor((max_tooltip_height - fixed_height) / line_height)))
	var body_lines: Array = _wrap_text_to_width(font, body, 13, text_width, body_line_limit)
	var height: float = fixed_height + float(body_lines.size()) * line_height
	var anchor_rect: Rect2 = _get_tooltip_anchor_rect(data, mouse_pos)
	var pos_x: float = anchor_rect.position.x + 10.0
	var pos_y: float = anchor_rect.end.y + 12.0
	if pos_x + width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - width
	if pos_y + height > view_size.y - 8.0:
		pos_y = anchor_rect.position.y - height - 12.0
	pos_x = clamp(pos_x, 8.0, max(8.0, view_size.x - width - 8.0))
	pos_y = clamp(pos_y, 8.0, max(8.0, view_size.y - height - 8.0))
	var rect := Rect2(pos_x, pos_y, width, height)
	_draw_panel(canvas, rect, OVERLAY_TOOLTIP_PANEL_FILL, color, 2.0)
	var text_x: float = pos_x + 14.0
	var y := pos_y + 24.0
	for line in title_lines:
		_draw_text_xy(canvas, font, str(line), text_x, y, 15, title_color)
		y += line_height
	if not subtitle_lines.is_empty():
		var subtitle_color: Color = _tooltip_subtitle_color(color)
		for line in subtitle_lines:
			_draw_text_xy(canvas, font, str(line), text_x, y, 12, subtitle_color)
			y += line_height
	for line in body_lines:
		_draw_text_xy(canvas, font, str(line), text_x, y, 13, TEXT_SOFT)
		y += line_height


func _get_tooltip_width(font: Font, title: String, subtitle: String, body: String, view_size: Vector2) -> float:
	var max_width: float = min(520.0, max(240.0, view_size.x - 16.0))
	var min_width: float = min(280.0, max_width)
	var width: float = min_width
	if title != "":
		width = max(width, min(max_width, _text_size(font, title, 15).x + 28.0))
	if subtitle != "":
		width = max(width, min(max_width, _text_size(font, subtitle, 12).x + 28.0))
	for paragraph_value in body.split("\n"):
		var paragraph: String = str(paragraph_value).strip_edges()
		if paragraph == "":
			continue
		width = max(width, min(max_width, _text_size(font, paragraph, 13).x + 28.0))
	return clamp(width, min_width, max_width)


func _draw_dual_item_tooltip(
	canvas: CanvasItem,
	data: Dictionary,
	mouse_pos: Vector2,
	view_size: Vector2,
	font: Font,
	color: Color,
	title: String,
	subtitle: String,
	body: String,
	roll_entries: Array
) -> void:
	var gap := 10.0
	var desc_width: float = min(270.0, max(205.0, view_size.x * 0.52))
	var roll_width: float = min(210.0, max(154.0, view_size.x - desc_width - gap - 26.0))
	if desc_width + gap + roll_width > view_size.x - 16.0:
		var available: float = max(300.0, view_size.x - 16.0 - gap)
		desc_width = max(178.0, available * 0.58)
		roll_width = max(132.0, available - desc_width)
	var body_lines: Array = _wrap_text_to_width(font, body, 13, desc_width - 28.0, 8)
	var roll_lines: Array = _build_tooltip_entry_lines(font, roll_entries, 13, roll_width - 24.0, 8)
	var title_color: Color = _get_color(data.get("title_color", Color.WHITE))
	var line_height := 20.0
	var desc_height: float = 58.0 + float(body_lines.size()) * line_height
	if subtitle != "":
		desc_height += line_height
	var roll_height: float = 42.0 + float(roll_lines.size()) * line_height
	var total_width: float = desc_width + gap + roll_width
	var total_height: float = max(desc_height, roll_height)
	var anchor_rect: Rect2 = _get_tooltip_anchor_rect(data, mouse_pos)
	var pos_x: float = anchor_rect.position.x + 10.0
	var pos_y: float = anchor_rect.position.y - total_height - 12.0
	if pos_y < 8.0:
		pos_y = anchor_rect.end.y + 12.0
	if pos_x + total_width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - total_width
	pos_x = clamp(pos_x, 8.0, max(8.0, view_size.x - total_width - 8.0))
	pos_y = clamp(pos_y, 8.0, max(8.0, view_size.y - total_height - 8.0))

	var desc_rect := Rect2(pos_x, pos_y, desc_width, desc_height)
	var roll_rect := Rect2(pos_x + desc_width + gap, pos_y, roll_width, roll_height)
	_draw_panel(canvas, desc_rect, OVERLAY_TOOLTIP_PANEL_FILL, color, 2.0)
	var desc_text_x: float = pos_x + 14.0
	_draw_text_xy(canvas, font, title, desc_text_x, pos_y + 24.0, 15, title_color)
	var desc_y := pos_y + 44.0
	if subtitle != "":
		var subtitle_color: Color = _tooltip_subtitle_color(color)
		_draw_text_xy(canvas, font, subtitle, desc_text_x, desc_y, 12, subtitle_color)
		desc_y += line_height
	for line in body_lines:
		_draw_text_xy(canvas, font, str(line), desc_text_x, desc_y, 13, TEXT_SOFT)
		desc_y += line_height

	_draw_panel(canvas, roll_rect, OVERLAY_TOOLTIP_ROLL_PANEL_FILL, OVERLAY_TOOLTIP_ROLL_BORDER, 2.0)
	var roll_text_x: float = pos_x + desc_width + gap + 12.0
	_draw_text_xy(canvas, font, "롤 옵션", roll_text_x, pos_y + 24.0, 13, ACCENT_GOLD)
	var roll_y := pos_y + 44.0
	for i in range(roll_lines.size()):
		_draw_text_xy(
			canvas,
			font,
			_tooltip_entry_line_text_cache[i],
			roll_text_x,
			roll_y,
			13,
			_tooltip_entry_line_color_cache[i]
		)
		roll_y += line_height


func _get_tooltip_anchor_rect(data: Dictionary, mouse_pos: Vector2) -> Rect2:
	var anchor_value: Variant = data.get("anchor_rect", null)
	if anchor_value is Rect2:
		return anchor_value
	return Rect2(mouse_pos.x, mouse_pos.y, 0.0, 0.0)


func _tooltip_subtitle_color(color: Color) -> Color:
	if color == _tooltip_subtitle_color_source:
		return _tooltip_subtitle_color_cache
	_tooltip_subtitle_color_source = color
	_tooltip_subtitle_color_cache = Color(color.r, color.g, color.b, 0.95)
	return _tooltip_subtitle_color_cache


func _set_hover_data(
	data: Dictionary,
	title: String,
	subtitle: String,
	body: String,
	color: Color,
	title_color: Variant = null,
	anchor_rect: Variant = null,
	roll_options: Variant = null
) -> Dictionary:
	data.clear()
	data["title"] = title
	data["subtitle"] = subtitle
	data["body"] = body
	data["color"] = color
	if title_color is Color:
		data["title_color"] = title_color
	if anchor_rect is Rect2:
		data["anchor_rect"] = anchor_rect
	if roll_options is Array:
		var roll_array: Array = roll_options
		if not roll_array.is_empty():
			data["roll_options"] = roll_array
	return data


func _build_tooltip_entry_lines(font: Font, entries: Array, size: int, max_width: float, max_lines: int) -> Array:
	if entries.is_empty() or max_lines <= 0:
		return []
	var max_width_key: int = int(round(max_width))
	var entries_hash: int = hash(entries)
	if (
		entries_hash == _tooltip_entry_lines_cache_entries_hash
		and size == _tooltip_entry_lines_cache_size
		and max_width_key == _tooltip_entry_lines_cache_width
		and max_lines == _tooltip_entry_lines_cache_max_lines
		and _tooltip_entry_line_text_cache.size() == _tooltip_entry_lines_cache.size()
		and _tooltip_entry_line_color_cache.size() == _tooltip_entry_lines_cache.size()
	):
		return _tooltip_entry_lines_cache
	_tooltip_entry_lines_cache.clear()
	_tooltip_entry_line_text_cache.clear()
	_tooltip_entry_line_color_cache.clear()
	var result: Array = _tooltip_entry_lines_cache
	for entry_value in entries:
		if result.size() >= max_lines:
			break
		var entry: Dictionary = _get_dict(entry_value)
		var text: String = str(entry.get("text", entry_value))
		if text == "":
			continue
		var color: Color = _get_color(entry.get("color", ACCENT_GOLD))
		var wrapped: Array = _wrap_text_to_width(font, text, size, max_width, max(1, max_lines - result.size()))
		for line in wrapped:
			var line_text: String = str(line)
			var line_entry: Dictionary = _get_tooltip_entry_line_dict(result.size())
			line_entry["text"] = line_text
			line_entry["color"] = color
			_tooltip_entry_line_text_cache.append(line_text)
			_tooltip_entry_line_color_cache.append(color)
			result.append(line_entry)
			if result.size() >= max_lines:
				break
	_tooltip_entry_lines_cache_entries_hash = entries_hash
	_tooltip_entry_lines_cache_size = size
	_tooltip_entry_lines_cache_width = max_width_key
	_tooltip_entry_lines_cache_max_lines = max_lines
	return result


func _get_tooltip_entry_line_dict(index: int) -> Dictionary:
	while _tooltip_entry_line_dict_cache.size() <= index:
		_tooltip_entry_line_dict_cache.append({})
	var data: Dictionary = _tooltip_entry_line_dict_cache[index]
	data.clear()
	return data


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, border_width)


func _draw_meter(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color, label: String, font: Font) -> void:
	canvas.draw_rect(rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
	var fill_rect := Rect2(rect.position.x, rect.position.y, rect.size.x * clamp(ratio, 0.0, 1.0), rect.size.y)
	canvas.draw_rect(fill_rect, Color(color.r, color.g, color.b, 0.82))
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.85), false, 1.0)
	_draw_text_xy(canvas, font, label, rect.position.x, rect.position.y - 8.0, 12, TEXT_DIM)


func _update_perk_scrollbar_layout(grid_rect: Rect2, max_scroll: float) -> void:
	if (
		grid_rect == _perk_scrollbar_layout_rect
		and is_equal_approx(max_scroll, _perk_scrollbar_layout_max_scroll)
		and is_equal_approx(_last_perk_content_height, _perk_scrollbar_layout_content_height)
		and is_equal_approx(perk_scroll, _perk_scrollbar_layout_scroll)
	):
		return
	_perk_scrollbar_layout_rect = grid_rect
	_perk_scrollbar_layout_max_scroll = max_scroll
	_perk_scrollbar_layout_content_height = _last_perk_content_height
	_perk_scrollbar_layout_scroll = perk_scroll
	if max_scroll <= 0.0:
		_perk_scrollbar_track_rect = Rect2()
		_perk_scrollbar_thumb_rect = Rect2()
		return
	_perk_scrollbar_track_rect = Rect2(grid_rect.end.x - 6.0, grid_rect.position.y + 4.0, 4.0, grid_rect.size.y - 8.0)
	var thumb_h: float = max(22.0, _perk_scrollbar_track_rect.size.y * (grid_rect.size.y / max(grid_rect.size.y, _last_perk_content_height)))
	var thumb_y: float = _perk_scrollbar_track_rect.position.y + (_perk_scrollbar_track_rect.size.y - thumb_h) * (perk_scroll / max_scroll)
	_perk_scrollbar_thumb_rect = Rect2(_perk_scrollbar_track_rect.position.x, thumb_y, _perk_scrollbar_track_rect.size.x, thumb_h)


func _draw_scrollbar(canvas: CanvasItem, grid_rect: Rect2, max_scroll: float) -> void:
	_update_perk_scrollbar_layout(grid_rect, max_scroll)
	canvas.draw_rect(_perk_scrollbar_track_rect, OVERLAY_SCROLLBAR_TRACK)
	canvas.draw_rect(_perk_scrollbar_thumb_rect, OVERLAY_PERK_SCROLLBAR_THUMB)


func _draw_fallback_symbol(canvas: CanvasItem, rect: Rect2, color: Color, id_text: String) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.38
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, FALLBACK_SYMBOL_RING_SEGMENTS, color, 2.0)
	var letter: String = _fallback_symbol_letter(id_text)
	_draw_text_centered_xy(canvas, ThemeDB.fallback_font, letter, center.x, center.y + 3.0, int(radius * 1.2), Color.WHITE)


func _fallback_symbol_letter(id_text: String) -> String:
	if id_text == "":
		return "?"
	if _fallback_symbol_letter_cache.has(id_text):
		var cached_letter: Variant = _fallback_symbol_letter_cache[id_text]
		if cached_letter is String:
			return cached_letter
	var letter := id_text.substr(0, 1).to_upper()
	if _fallback_symbol_letter_cache.size() >= FALLBACK_SYMBOL_LETTER_CACHE_LIMIT:
		_fallback_symbol_letter_cache.clear()
	_fallback_symbol_letter_cache[id_text] = letter
	return letter


func _get_anatomy_slot_positions(content_rect: Rect2, slot_size: float) -> Dictionary:
	var body_x: float = content_rect.position.x + content_rect.size.x * 0.45
	var right_column_x: float = content_rect.end.x - slot_size * 0.54
	var side_span: float = min(content_rect.size.x * 0.31, slot_size * 2.55)
	var head_y: float = content_rect.position.y + content_rect.size.y * 0.13
	var shoulder_y: float = content_rect.position.y + content_rect.size.y * 0.35
	var chest_y: float = content_rect.position.y + content_rect.size.y * 0.40
	var waist_y: float = content_rect.position.y + content_rect.size.y * 0.58
	var hip_y: float = content_rect.position.y + content_rect.size.y * 0.68
	var foot_y: float = content_rect.position.y + content_rect.size.y * 0.88
	var accessory_gap: float = min(slot_size * 1.58, content_rect.size.y * 0.21)
	return {
		"head": Vector2(body_x, head_y),
		"left_arm": Vector2(body_x - side_span, shoulder_y),
		"right_arm": Vector2(body_x + side_span, shoulder_y),
		"top": Vector2(body_x, chest_y),
		"belt": Vector2(body_x, waist_y),
		"belt2": Vector2(body_x - side_span * 0.86, hip_y),
		"knee": Vector2(body_x - side_span * 0.48, content_rect.position.y + content_rect.size.y * 0.74),
		"shoes": Vector2(body_x + side_span * 0.58, foot_y),
		"accessory1": Vector2(right_column_x, head_y),
		"accessory2": Vector2(right_column_x, head_y + accessory_gap),
		"accessory3": Vector2(right_column_x, head_y + accessory_gap * 2.0),
		"accessory4": Vector2(right_column_x, head_y + accessory_gap * 3.0),
	}


func _update_equipment_slot_layout(content_rect: Rect2, slot_size: float) -> void:
	if not _equipment_slot_rect_cache.is_empty() and _equipment_layout_content_rect.is_equal_approx(content_rect) and is_equal_approx(_equipment_layout_slot_size, slot_size):
		return
	_ensure_equipment_slot_metadata_cache()
	_equipment_layout_content_rect = content_rect
	_equipment_layout_slot_size = slot_size
	_equipment_slot_rect_cache.clear()
	var slot_count: int = _equipment_slot_keys.size()
	_ensure_equipment_slot_layout_cache_size(slot_count)
	var slot_positions: Dictionary = _get_anatomy_slot_positions(content_rect, slot_size)
	var fallback_center := content_rect.get_center()
	var slot_extent := Vector2(slot_size, slot_size)
	var label_size: int = 10 if slot_size >= 40.0 else 8
	for i in range(slot_count):
		var key: String = _equipment_slot_keys[i]
		var center_value: Variant = slot_positions.get(key, fallback_center)
		var slot_center: Vector2 = center_value if center_value is Vector2 else fallback_center
		var slot_rect := Rect2(slot_center - slot_extent * 0.5, slot_extent)
		var slot_x: float = slot_rect.position.x
		var slot_y: float = slot_rect.position.y
		var slot_w: float = slot_rect.size.x
		var slot_h: float = slot_rect.size.y
		_equipment_slot_rect_cache[key] = slot_rect
		_equipment_slot_rect_list_cache[i] = slot_rect
		_equipment_slot_icon_rect_cache[i] = Rect2(slot_x + 5.0, slot_y + 5.0, slot_w - 10.0, slot_h - 10.0)
		_equipment_slot_fallback_rect_cache[i] = Rect2(slot_x + 8.0, slot_y + 8.0, slot_w - 16.0, slot_h - 16.0)
		_equipment_slot_placeholder_rect_cache[i] = Rect2(slot_x + 7.0, slot_y + 7.0, slot_w - 14.0, slot_h - 14.0)
		_equipment_slot_locked_line_a_start_cache[i] = Vector2(slot_x + 9.0, slot_y + 9.0)
		_equipment_slot_locked_line_a_end_cache[i] = Vector2(slot_x + slot_w - 9.0, slot_y + slot_h - 9.0)
		_equipment_slot_locked_line_b_start_cache[i] = Vector2(slot_x + slot_w - 9.0, slot_y + 9.0)
		_equipment_slot_locked_line_b_end_cache[i] = Vector2(slot_x + 9.0, slot_y + slot_h - 9.0)
		_equipment_slot_center_x_cache[i] = slot_x + slot_w * 0.5
		_equipment_slot_center_y_cache[i] = slot_y + slot_h * 0.5
		_equipment_slot_label_y_cache[i] = min(slot_y + slot_h + float(label_size) + 6.0, content_rect.end.y - 2.0)


func _ensure_equipment_slot_layout_cache_size(slot_count: int) -> void:
	if (
		_equipment_slot_rect_list_cache.size() == slot_count
		and _equipment_slot_icon_rect_cache.size() == slot_count
		and _equipment_slot_fallback_rect_cache.size() == slot_count
		and _equipment_slot_placeholder_rect_cache.size() == slot_count
		and _equipment_slot_locked_line_a_start_cache.size() == slot_count
		and _equipment_slot_locked_line_a_end_cache.size() == slot_count
		and _equipment_slot_locked_line_b_start_cache.size() == slot_count
		and _equipment_slot_locked_line_b_end_cache.size() == slot_count
		and _equipment_slot_center_x_cache.size() == slot_count
		and _equipment_slot_center_y_cache.size() == slot_count
		and _equipment_slot_label_y_cache.size() == slot_count
	):
		return
	_equipment_slot_rect_list_cache.resize(slot_count)
	_equipment_slot_icon_rect_cache.resize(slot_count)
	_equipment_slot_fallback_rect_cache.resize(slot_count)
	_equipment_slot_placeholder_rect_cache.resize(slot_count)
	_equipment_slot_locked_line_a_start_cache.resize(slot_count)
	_equipment_slot_locked_line_a_end_cache.resize(slot_count)
	_equipment_slot_locked_line_b_start_cache.resize(slot_count)
	_equipment_slot_locked_line_b_end_cache.resize(slot_count)
	_equipment_slot_center_x_cache.resize(slot_count)
	_equipment_slot_center_y_cache.resize(slot_count)
	_equipment_slot_label_y_cache.resize(slot_count)


func _ensure_equipment_slot_metadata_cache() -> void:
	if _equipment_slot_keys.size() == EQUIPMENT_SLOT_DEFINITIONS.size():
		return
	_equipment_slot_keys.clear()
	_equipment_slot_labels.clear()
	_equipment_slot_compact_labels.clear()
	_equipment_slot_bases.clear()
	_equipment_slot_accessory_numbers.clear()
	_equipment_slot_empty_colors.clear()
	_equipment_slot_empty_border_colors.clear()
	_equipment_slot_index_cache.clear()
	for definition_value in EQUIPMENT_SLOT_DEFINITIONS:
		var definition: Dictionary = _get_dict(definition_value)
		var key: String = str(definition.get("key", ""))
		var label: String = str(definition.get("label", key))
		var base: String = str(definition.get("base", key))
		var empty_color: Color = _equipment_empty_color_for_base(base)
		var accessory_number: int = _equipment_slot_accessory_number(key)
		_equipment_slot_index_cache[key] = _equipment_slot_keys.size()
		_equipment_slot_keys.append(key)
		_equipment_slot_labels.append(label)
		_equipment_slot_compact_labels.append(_equipment_slot_label(label, key, 0.0))
		_equipment_slot_bases.append(base)
		_equipment_slot_accessory_numbers.append(accessory_number)
		_equipment_slot_empty_colors.append(empty_color)
		_equipment_slot_empty_border_colors.append(Color(empty_color.r, empty_color.g, empty_color.b, 0.58))


func _refresh_equipment_slot_visible_label_cache(use_compact: bool) -> void:
	_ensure_equipment_slot_metadata_cache()
	var slot_count: int = _equipment_slot_keys.size()
	if _equipment_slot_visible_label_cache.size() == slot_count and _equipment_slot_visible_label_cache_compact == use_compact:
		return
	_equipment_slot_visible_label_cache_compact = use_compact
	if _equipment_slot_visible_label_cache.size() != slot_count:
		_equipment_slot_visible_label_cache.resize(slot_count)
	var source_labels: Array[String] = _equipment_slot_compact_labels if use_compact else _equipment_slot_labels
	for i in range(slot_count):
		_equipment_slot_visible_label_cache[i] = source_labels[i]


func _refresh_equipment_slot_frame_cache(slot_state: Dictionary, accessory_slot_count: int) -> void:
	_ensure_equipment_slot_metadata_cache()
	var slot_count: int = _equipment_slot_keys.size()
	_ensure_equipment_slot_frame_cache_size(slot_count)
	var slot_state_hash: int = hash(slot_state)
	if _equipment_slot_frame_cache_matches(slot_state_hash, accessory_slot_count, slot_count):
		return
	_equipment_slot_frame_cache_slot_state_hash = slot_state_hash
	_equipment_slot_frame_cache_accessory_slot_count = accessory_slot_count
	_equipment_slot_frame_cache_slot_count = slot_count
	for i in range(slot_count):
		var item_data: Dictionary = _get_equipment_item_or_empty(slot_state, _equipment_slot_keys[i])
		var accessory_number: int = _equipment_slot_accessory_numbers[i]
		var enabled: bool = accessory_number <= 0 or accessory_number <= accessory_slot_count
		_equipment_slot_item_cache[i] = item_data
		_equipment_slot_has_item_cache[i] = not item_data.is_empty()
		_equipment_slot_enabled_cache[i] = enabled
		_equipment_slot_label_color_cache[i] = TEXT_SOFT if enabled else EQUIPMENT_LABEL_DISABLED
		_equipment_slot_base_color_cache[i] = EQUIPMENT_COLOR_DISABLED if not enabled else EQUIPMENT_COLOR_FILLED if _equipment_slot_has_item_cache[i] else _equipment_slot_empty_colors[i]
		_equipment_slot_border_color_cache[i] = EQUIPMENT_SLOT_BORDER_DISABLED if not enabled else EQUIPMENT_SLOT_BORDER_FILLED if _equipment_slot_has_item_cache[i] else _equipment_slot_empty_border_colors[i]
		_equipment_slot_fill_color_cache[i] = EQUIPMENT_SLOT_FILL_ENABLED if enabled else EQUIPMENT_SLOT_FILL_DISABLED
		_equipment_slot_border_width_cache[i] = 2.0 if _equipment_slot_has_item_cache[i] else 1.4
		var base_color: Color = _equipment_slot_base_color_cache[i]
		_equipment_slot_locked_line_color_cache[i] = Color(base_color.r, base_color.g, base_color.b, 0.32)


func _ensure_equipment_slot_frame_cache_size(slot_count: int) -> void:
	if (
		_equipment_slot_item_cache.size() == slot_count
		and _equipment_slot_has_item_cache.size() == slot_count
		and _equipment_slot_enabled_cache.size() == slot_count
		and _equipment_slot_label_color_cache.size() == slot_count
		and _equipment_slot_base_color_cache.size() == slot_count
		and _equipment_slot_border_color_cache.size() == slot_count
		and _equipment_slot_fill_color_cache.size() == slot_count
		and _equipment_slot_border_width_cache.size() == slot_count
		and _equipment_slot_locked_line_color_cache.size() == slot_count
	):
		return
	_equipment_slot_item_cache.resize(slot_count)
	_equipment_slot_has_item_cache.resize(slot_count)
	_equipment_slot_enabled_cache.resize(slot_count)
	_equipment_slot_label_color_cache.resize(slot_count)
	_equipment_slot_base_color_cache.resize(slot_count)
	_equipment_slot_border_color_cache.resize(slot_count)
	_equipment_slot_fill_color_cache.resize(slot_count)
	_equipment_slot_border_width_cache.resize(slot_count)
	_equipment_slot_locked_line_color_cache.resize(slot_count)


func _equipment_slot_frame_cache_matches(slot_state_hash: int, accessory_slot_count: int, slot_count: int) -> bool:
	return (
		slot_state_hash == _equipment_slot_frame_cache_slot_state_hash
		and accessory_slot_count == _equipment_slot_frame_cache_accessory_slot_count
		and slot_count == _equipment_slot_frame_cache_slot_count
	)


func _update_equipment_silhouette_geometry(content_rect: Rect2, slot_size: float) -> void:
	if _equipment_silhouette_torso_poly.size() > 0 and _equipment_silhouette_content_rect.is_equal_approx(content_rect) and is_equal_approx(_equipment_silhouette_slot_size, slot_size):
		return
	_equipment_silhouette_content_rect = content_rect
	_equipment_silhouette_slot_size = slot_size
	_equipment_silhouette_body_x = content_rect.position.x + content_rect.size.x * 0.45
	var top_y: float = content_rect.position.y + content_rect.size.y * 0.09
	_equipment_silhouette_bottom_y = content_rect.end.y - slot_size * 0.30
	var height: float = max(1.0, _equipment_silhouette_bottom_y - top_y)
	_equipment_silhouette_head_center = Vector2(_equipment_silhouette_body_x, top_y + height * 0.08)
	_equipment_silhouette_neck_rect = Rect2(_equipment_silhouette_head_center + Vector2(-slot_size * 0.16, slot_size * 0.42), Vector2(slot_size * 0.32, slot_size * 0.36))
	_equipment_silhouette_shoulder_y = top_y + height * 0.23
	_equipment_silhouette_waist_y = top_y + height * 0.58
	_equipment_silhouette_hip_y = top_y + height * 0.70
	_equipment_silhouette_shoulder_w = min(content_rect.size.x * 0.43, slot_size * 3.75)
	_equipment_silhouette_waist_w = min(content_rect.size.x * 0.25, slot_size * 2.25)
	var hip_w: float = min(content_rect.size.x * 0.31, slot_size * 2.70)
	_equipment_silhouette_torso_poly = PackedVector2Array([
		Vector2(_equipment_silhouette_body_x - _equipment_silhouette_shoulder_w * 0.5, _equipment_silhouette_shoulder_y),
		Vector2(_equipment_silhouette_body_x + _equipment_silhouette_shoulder_w * 0.5, _equipment_silhouette_shoulder_y),
		Vector2(_equipment_silhouette_body_x + _equipment_silhouette_waist_w * 0.5, _equipment_silhouette_waist_y),
		Vector2(_equipment_silhouette_body_x + hip_w * 0.5, _equipment_silhouette_hip_y),
		Vector2(_equipment_silhouette_body_x - hip_w * 0.5, _equipment_silhouette_hip_y),
		Vector2(_equipment_silhouette_body_x - _equipment_silhouette_waist_w * 0.5, _equipment_silhouette_waist_y),
	])
	_equipment_silhouette_left_arm_poly = PackedVector2Array([
		Vector2(_equipment_silhouette_body_x - _equipment_silhouette_shoulder_w * 0.52, _equipment_silhouette_shoulder_y + slot_size * 0.16),
		Vector2(_equipment_silhouette_body_x - _equipment_silhouette_shoulder_w * 0.92, _equipment_silhouette_shoulder_y + slot_size * 0.56),
		Vector2(_equipment_silhouette_body_x - _equipment_silhouette_shoulder_w * 0.92, _equipment_silhouette_shoulder_y + slot_size * 1.02),
		Vector2(_equipment_silhouette_body_x - _equipment_silhouette_shoulder_w * 0.52, _equipment_silhouette_shoulder_y + slot_size * 0.70),
	])
	_equipment_silhouette_right_arm_poly = PackedVector2Array([
		Vector2(_equipment_silhouette_body_x + _equipment_silhouette_shoulder_w * 0.52, _equipment_silhouette_shoulder_y + slot_size * 0.16),
		Vector2(_equipment_silhouette_body_x + _equipment_silhouette_shoulder_w * 0.92, _equipment_silhouette_shoulder_y + slot_size * 0.56),
		Vector2(_equipment_silhouette_body_x + _equipment_silhouette_shoulder_w * 0.92, _equipment_silhouette_shoulder_y + slot_size * 1.02),
		Vector2(_equipment_silhouette_body_x + _equipment_silhouette_shoulder_w * 0.52, _equipment_silhouette_shoulder_y + slot_size * 0.70),
	])
	_equipment_silhouette_left_leg_poly = PackedVector2Array([
		Vector2(_equipment_silhouette_body_x - hip_w * 0.30, _equipment_silhouette_hip_y),
		Vector2(_equipment_silhouette_body_x - hip_w * 0.02, _equipment_silhouette_hip_y),
		Vector2(_equipment_silhouette_body_x - hip_w * 0.10, _equipment_silhouette_bottom_y - slot_size * 0.18),
		Vector2(_equipment_silhouette_body_x - hip_w * 0.52, _equipment_silhouette_bottom_y - slot_size * 0.08),
	])
	_equipment_silhouette_right_leg_poly = PackedVector2Array([
		Vector2(_equipment_silhouette_body_x + hip_w * 0.02, _equipment_silhouette_hip_y),
		Vector2(_equipment_silhouette_body_x + hip_w * 0.30, _equipment_silhouette_hip_y),
		Vector2(_equipment_silhouette_body_x + hip_w * 0.52, _equipment_silhouette_bottom_y - slot_size * 0.08),
		Vector2(_equipment_silhouette_body_x + hip_w * 0.10, _equipment_silhouette_bottom_y - slot_size * 0.18),
	])


func _draw_equipment_anatomy_silhouette(canvas: CanvasItem, content_rect: Rect2, slot_size: float, show_detail: bool = false) -> void:
	_update_equipment_silhouette_geometry(content_rect, slot_size)

	canvas.draw_circle(_equipment_silhouette_head_center, slot_size * 0.43, EQUIPMENT_SILHOUETTE_HEAD)
	canvas.draw_rect(_equipment_silhouette_neck_rect, EQUIPMENT_SILHOUETTE_NECK)
	canvas.draw_colored_polygon(_equipment_silhouette_torso_poly, EQUIPMENT_SILHOUETTE_BASE)
	if show_detail:
		canvas.draw_colored_polygon(_equipment_silhouette_left_arm_poly, EQUIPMENT_SILHOUETTE_DEEP_DETAIL)
		canvas.draw_colored_polygon(_equipment_silhouette_right_arm_poly, EQUIPMENT_SILHOUETTE_DEEP_DETAIL)
		canvas.draw_colored_polygon(_equipment_silhouette_left_leg_poly, EQUIPMENT_SILHOUETTE_BASE_DETAIL)
		canvas.draw_colored_polygon(_equipment_silhouette_right_leg_poly, EQUIPMENT_SILHOUETTE_BASE_DETAIL)
		canvas.draw_arc(_equipment_silhouette_head_center, slot_size * 0.43, 0.0, TAU, EQUIPMENT_BODY_RING_SEGMENTS, EQUIPMENT_SILHOUETTE_LINE, 1.0)
		canvas.draw_line(Vector2(_equipment_silhouette_body_x, _equipment_silhouette_shoulder_y + slot_size * 0.08), Vector2(_equipment_silhouette_body_x, _equipment_silhouette_hip_y + slot_size * 0.14), EQUIPMENT_SILHOUETTE_LINE, 1.0)
		canvas.draw_arc(Vector2(_equipment_silhouette_body_x, _equipment_silhouette_shoulder_y + slot_size * 0.64), slot_size * 0.72, PI * 0.10, PI * 0.90, EQUIPMENT_BODY_ARC_SEGMENTS, EQUIPMENT_SILHOUETTE_LINE, 1.0)
		canvas.draw_arc(Vector2(_equipment_silhouette_body_x, _equipment_silhouette_shoulder_y + slot_size * 0.64), slot_size * 0.72, PI * 1.10, PI * 1.90, EQUIPMENT_BODY_ARC_SEGMENTS, EQUIPMENT_SILHOUETTE_LINE, 1.0)
		canvas.draw_line(Vector2(_equipment_silhouette_body_x - _equipment_silhouette_waist_w * 0.45, _equipment_silhouette_waist_y), Vector2(_equipment_silhouette_body_x + _equipment_silhouette_waist_w * 0.45, _equipment_silhouette_waist_y), EQUIPMENT_SILHOUETTE_LINE, 1.0)


func _draw_equipment_connector(canvas: CanvasItem, content_rect: Rect2, key: String, slot_center_x: float, slot_center_y: float, color: Color, enabled: bool) -> void:
	var body_x: float = content_rect.position.x + content_rect.size.x * 0.45
	var target_x: float = body_x
	var target_y: float = content_rect.position.y + content_rect.size.y * 0.50
	var alpha: float = 0.18 if enabled else 0.07
	match key:
		"head":
			target_y = content_rect.position.y + content_rect.size.y * 0.17
		"top":
			target_y = content_rect.position.y + content_rect.size.y * 0.38
		"left_arm":
			target_x = body_x - content_rect.size.x * 0.21
			target_y = content_rect.position.y + content_rect.size.y * 0.36
		"right_arm":
			target_x = body_x + content_rect.size.x * 0.21
			target_y = content_rect.position.y + content_rect.size.y * 0.36
		"belt", "belt2":
			target_y = content_rect.position.y + content_rect.size.y * 0.58
		"knee":
			target_x = body_x - content_rect.size.x * 0.08
			target_y = content_rect.position.y + content_rect.size.y * 0.73
		"shoes":
			target_x = body_x + content_rect.size.x * 0.12
			target_y = content_rect.position.y + content_rect.size.y * 0.84
		_:
			target_x = body_x + content_rect.size.x * 0.25
			target_y = slot_center_y
	var delta_x: float = slot_center_x - target_x
	var delta_y: float = slot_center_y - target_y
	if delta_x * delta_x + delta_y * delta_y > 144.0:
		canvas.draw_line(Vector2(target_x, target_y), Vector2(slot_center_x, slot_center_y), Color(color.r, color.g, color.b, alpha), 1.0)


func _draw_equipment_slot_frame(canvas: CanvasItem, slot_rect: Rect2, fill_color: Color, color: Color, border_color: Color, border_width: float, enabled: bool, has_item: bool, hovered: bool) -> void:
	canvas.draw_rect(slot_rect, fill_color)
	canvas.draw_rect(slot_rect, border_color, false, border_width)
	if not hovered:
		return
	var corner: float = min(slot_rect.size.x, slot_rect.size.y) * 0.24
	var corner_color := Color(color.r, color.g, color.b, min(1.0, border_color.a + 0.14))
	var corner_weight := 1.6
	canvas.draw_line(slot_rect.position, slot_rect.position + Vector2(corner, 0.0), corner_color, corner_weight)
	canvas.draw_line(Vector2(slot_rect.end.x, slot_rect.position.y), Vector2(slot_rect.end.x - corner, slot_rect.position.y), corner_color, corner_weight)
	canvas.draw_line(Vector2(slot_rect.position.x, slot_rect.end.y), Vector2(slot_rect.position.x + corner, slot_rect.end.y), corner_color, corner_weight)
	canvas.draw_line(slot_rect.end, slot_rect.end - Vector2(corner, 0.0), corner_color, corner_weight)
	canvas.draw_line(slot_rect.position, slot_rect.position + Vector2(0.0, corner), corner_color, corner_weight)
	canvas.draw_line(Vector2(slot_rect.end.x, slot_rect.position.y), Vector2(slot_rect.end.x, slot_rect.position.y + corner), corner_color, corner_weight)
	canvas.draw_line(Vector2(slot_rect.position.x, slot_rect.end.y), Vector2(slot_rect.position.x, slot_rect.end.y - corner), corner_color, corner_weight)
	canvas.draw_line(slot_rect.end, slot_rect.end - Vector2(0.0, corner), corner_color, corner_weight)
	if not has_item and enabled:
		var empty_center := slot_rect.get_center()
		canvas.draw_circle(empty_center, slot_rect.size.x * 0.28, Color(color.r, color.g, color.b, 0.09 if enabled else 0.04))
		canvas.draw_arc(empty_center, slot_rect.size.x * 0.28, 0.0, TAU, EQUIPMENT_EMPTY_RING_SEGMENTS, Color(color.r, color.g, color.b, 0.32 if enabled else 0.14), 1.0)


func _draw_equipment_placeholder(canvas: CanvasItem, rect: Rect2, base: String, color: Color, enabled: bool) -> void:
	var alpha: float = 0.42 if enabled else 0.20
	var center := rect.get_center()
	var stroke := Color(color.r, color.g, color.b, alpha)
	match base:
		"head":
			canvas.draw_arc(center + Vector2(0.0, 2.0), rect.size.x * 0.25, PI, TAU, EQUIPMENT_PLACEHOLDER_ARC_SEGMENTS, stroke, 1.6)
			canvas.draw_line(center + Vector2(-rect.size.x * 0.25, 2.0), center + Vector2(rect.size.x * 0.25, 2.0), stroke, 1.6)
		"top":
			var body := Rect2(center - Vector2(rect.size.x * 0.22, rect.size.y * 0.18), Vector2(rect.size.x * 0.44, rect.size.y * 0.38))
			canvas.draw_rect(body, Color(color.r, color.g, color.b, alpha * 0.28))
			canvas.draw_rect(body, stroke, false, 1.5)
			canvas.draw_line(body.position, body.position + Vector2(-rect.size.x * 0.12, rect.size.y * 0.16), stroke, 1.5)
			canvas.draw_line(Vector2(body.end.x, body.position.y), body.position + Vector2(body.size.x + rect.size.x * 0.12, rect.size.y * 0.16), stroke, 1.5)
		"arm":
			canvas.draw_line(center + Vector2(-rect.size.x * 0.20, -rect.size.y * 0.18), center + Vector2(rect.size.x * 0.18, rect.size.y * 0.18), stroke, 2.0)
			canvas.draw_circle(center + Vector2(rect.size.x * 0.21, rect.size.y * 0.20), rect.size.x * 0.08, stroke)
		"belt":
			var belt := Rect2(center - Vector2(rect.size.x * 0.28, rect.size.y * 0.06), Vector2(rect.size.x * 0.56, rect.size.y * 0.12))
			canvas.draw_rect(belt, Color(color.r, color.g, color.b, alpha * 0.32))
			canvas.draw_rect(belt, stroke, false, 1.4)
			canvas.draw_rect(Rect2(center - Vector2(rect.size.x * 0.07, rect.size.y * 0.08), Vector2(rect.size.x * 0.14, rect.size.y * 0.16)), stroke, false, 1.2)
		"back":
			var pack := Rect2(center - Vector2(rect.size.x * 0.18, rect.size.y * 0.24), Vector2(rect.size.x * 0.36, rect.size.y * 0.48))
			canvas.draw_rect(pack, Color(color.r, color.g, color.b, alpha * 0.26))
			canvas.draw_rect(pack, stroke, false, 1.5)
			canvas.draw_line(pack.position + Vector2(pack.size.x * 0.5, 0.0), pack.end - Vector2(pack.size.x * 0.5, 0.0), stroke, 1.0)
		"knee":
			canvas.draw_arc(center, rect.size.x * 0.22, -PI * 0.15, PI * 1.15, EQUIPMENT_PLACEHOLDER_ARC_SEGMENTS, stroke, 1.8)
			canvas.draw_line(center + Vector2(-rect.size.x * 0.22, rect.size.y * 0.08), center + Vector2(rect.size.x * 0.20, rect.size.y * 0.12), stroke, 1.6)
		"shoes":
			var sole := Rect2(center - Vector2(rect.size.x * 0.28, rect.size.y * 0.02), Vector2(rect.size.x * 0.56, rect.size.y * 0.14))
			canvas.draw_rect(sole, Color(color.r, color.g, color.b, alpha * 0.28))
			canvas.draw_rect(sole, stroke, false, 1.4)
			canvas.draw_line(sole.position + Vector2(rect.size.x * 0.10, 0.0), center + Vector2(-rect.size.x * 0.05, -rect.size.y * 0.18), stroke, 1.4)
		_:
			canvas.draw_circle(center, rect.size.x * 0.22, Color(color.r, color.g, color.b, alpha * 0.24))
			canvas.draw_arc(center, rect.size.x * 0.22, 0.0, TAU, EQUIPMENT_ACCESSORY_RING_SEGMENTS, stroke, 1.5)


func _draw_locked_slot(canvas: CanvasItem, slot_index: int) -> void:
	var line_color: Color = _equipment_slot_locked_line_color_cache[slot_index]
	canvas.draw_line(_equipment_slot_locked_line_a_start_cache[slot_index], _equipment_slot_locked_line_a_end_cache[slot_index], line_color, 1.4)
	canvas.draw_line(_equipment_slot_locked_line_b_start_cache[slot_index], _equipment_slot_locked_line_b_end_cache[slot_index], line_color, 1.4)


func _draw_locked_slot_rect(canvas: CanvasItem, slot_rect: Rect2, color: Color) -> void:
	var line_color := Color(color.r, color.g, color.b, 0.32)
	canvas.draw_line(slot_rect.position + Vector2(9.0, 9.0), slot_rect.end - Vector2(9.0, 9.0), line_color, 1.4)
	canvas.draw_line(Vector2(slot_rect.end.x - 9.0, slot_rect.position.y + 9.0), Vector2(slot_rect.position.x + 9.0, slot_rect.end.y - 9.0), line_color, 1.4)


func _draw_text(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, size: int, color: Color) -> void:
	_draw_text_xy(canvas, font, text, baseline.x, baseline.y, size, color)


func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color) -> void:
	if text == "":
		return
	var visible_text := LanguageSettings.translate_text(text)
	canvas.draw_string(font, Vector2(baseline_x, baseline_y), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _ui_font_size(size), color)


func _draw_text_centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color) -> void:
	_draw_text_centered_xy(canvas, font, text, center.x, center.y, size, color)


func _draw_text_centered_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color) -> void:
	if text == "":
		return
	var visible_text := LanguageSettings.translate_text(text)
	var text_size: Vector2 = _get_centered_text_size(font, visible_text, size)
	_draw_text_centered_with_size_xy(canvas, font, visible_text, center_x, center_y, size, color, text_size)


func _draw_text_centered_with_size(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color, text_size: Vector2) -> void:
	_draw_text_centered_with_size_xy(canvas, font, text, center.x, center.y, size, color, text_size)


func _draw_text_centered_with_size_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, text_size: Vector2) -> void:
	if text == "":
		return
	var visible_text := LanguageSettings.translate_text(text)
	if visible_text != text:
		text_size = _get_centered_text_size(font, visible_text, size)
	canvas.draw_string(font, Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _ui_font_size(size), color)


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
	if text == _text_size_fast_text and ui_size == _text_size_fast_ui_size:
		return _text_size_fast_value
	var cache_key := "%d:%s" % [ui_size, text]
	if _text_size_cache.has(cache_key):
		var cached_size: Variant = _text_size_cache[cache_key]
		if cached_size is Vector2:
			_text_size_fast_text = text
			_text_size_fast_ui_size = ui_size
			_text_size_fast_value = cached_size
			return cached_size
		_text_size_cache.erase(cache_key)
	var measured_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ui_size)
	if _text_size_cache.size() >= TEXT_SIZE_CACHE_LIMIT:
		_text_size_cache.clear()
	_text_size_cache[cache_key] = measured_size
	_text_size_fast_text = text
	_text_size_fast_ui_size = ui_size
	_text_size_fast_value = measured_size
	return measured_size


func _get_perk_level_text_size(font: Font, text: String, size: int) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	var font_id: int = font.get_instance_id()
	if (
		text == _perk_level_text_size_fast_text
		and size == _perk_level_text_size_fast_size
		and font_id == _perk_level_text_size_fast_font_id
	):
		return _perk_level_text_size_fast_value
	for i in range(_perk_level_text_size_cache_texts.size()):
		if (
			_perk_level_text_size_cache_texts[i] == text
			and _perk_level_text_size_cache_sizes[i] == size
			and _perk_level_text_size_cache_font_ids[i] == font_id
		):
			_perk_level_text_size_fast_text = text
			_perk_level_text_size_fast_size = size
			_perk_level_text_size_fast_font_id = font_id
			_perk_level_text_size_fast_value = _perk_level_text_size_cache_values[i]
			return _perk_level_text_size_cache_values[i]
	var text_size: Vector2 = _text_size(font, text, size)
	_perk_level_text_size_cache_texts.append(text)
	_perk_level_text_size_cache_sizes.append(size)
	_perk_level_text_size_cache_font_ids.append(font_id)
	_perk_level_text_size_cache_values.append(text_size)
	_perk_level_text_size_fast_text = text
	_perk_level_text_size_fast_size = size
	_perk_level_text_size_fast_font_id = font_id
	_perk_level_text_size_fast_value = text_size
	return text_size


func _get_centered_text_size(font: Font, text: String, size: int) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	var font_id: int = font.get_instance_id()
	if (
		text == _centered_text_size_fast_text
		and size == _centered_text_size_fast_size
		and font_id == _centered_text_size_fast_font_id
	):
		return _centered_text_size_fast_value
	for i in range(_centered_text_size_cache_texts.size()):
		if (
			_centered_text_size_cache_texts[i] == text
			and _centered_text_size_cache_sizes[i] == size
			and _centered_text_size_cache_font_ids[i] == font_id
		):
			_centered_text_size_fast_text = text
			_centered_text_size_fast_size = size
			_centered_text_size_fast_font_id = font_id
			_centered_text_size_fast_value = _centered_text_size_cache_values[i]
			return _centered_text_size_cache_values[i]
	var text_size: Vector2 = _text_size(font, text, size)
	if _centered_text_size_cache_texts.size() >= CENTERED_TEXT_SIZE_CACHE_LIMIT:
		_centered_text_size_cache_texts.clear()
		_centered_text_size_cache_sizes.clear()
		_centered_text_size_cache_font_ids.clear()
		_centered_text_size_cache_values.clear()
	_centered_text_size_cache_texts.append(text)
	_centered_text_size_cache_sizes.append(size)
	_centered_text_size_cache_font_ids.append(font_id)
	_centered_text_size_cache_values.append(text_size)
	_centered_text_size_fast_text = text
	_centered_text_size_fast_size = size
	_centered_text_size_fast_font_id = font_id
	_centered_text_size_fast_value = text_size
	return text_size


func _prewarm_shared_icon_assets(registry: Object, module_getter: Callable) -> bool:
	var warmed := false
	var icon_renderer: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_icon_renderer")
	if icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.prewarm_assets()
		warmed = true
	var visuals: Object = _get_prewarm_instance(registry, module_getter, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("prewarm_catalog_icons"):
		visuals.prewarm_catalog_icons()
		warmed = true
	return warmed


func _prewarm_visible_item_icons(owner: Object, registry: Object, module_getter: Callable) -> void:
	var items: Array = []
	var slot_state: Dictionary = _get_equipment_state(owner)
	_ensure_equipment_slot_metadata_cache()
	for slot_key in _equipment_slot_keys:
		var item_data: Dictionary = _get_equipment_item(slot_state, str(slot_key))
		if not item_data.is_empty():
			items.append(item_data)
	var active_slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	for active_value in active_slots:
		if active_value is Dictionary:
			items.append(active_value)
	var mythic_item_runtime: Object = _get_prewarm_instance(registry, module_getter, "mythic_item_runtime")
	items.append_array(_get_passive_inventory_items(owner, registry, mythic_item_runtime))
	if items.is_empty():
		return
	var visuals: Object = _get_prewarm_instance(registry, module_getter, "active_item_hud_visuals")
	if _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("prewarm_item_icons"):
		_active_item_icon_renderer.prewarm_item_icons(items, visuals)
		return
	if visuals == null or not visuals.has_method("get_icon_texture"):
		return
	for item_value in items:
		var item_data: Dictionary = _get_dict(item_value)
		if item_data.is_empty():
			continue
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			var texture_2d: Texture2D = texture as Texture2D
			texture_2d.get_size()


func _prewarm_passive_inventory_assets(owner: Object, registry: Object, module_getter: Callable) -> void:
	var inventory_items: Array = _get_passive_inventory_items(owner, registry)
	if inventory_items.is_empty():
		var runtime: Object = _get_prewarm_instance(registry, module_getter, "mythic_item_runtime")
		if runtime != null:
			inventory_items = _get_array(runtime.get("inventory_items"))
			if inventory_items.is_empty() and runtime.has_method("get_snapshot"):
				var snapshot: Dictionary = _get_dict(runtime.get_snapshot())
				inventory_items = _get_array(snapshot.get("inventory_items", []))
	var item_count: int = inventory_items.size()
	var items_hash: int = _get_passive_inventory_icon_hash(inventory_items)
	if (
		items_hash == _passive_inventory_icon_prewarm_items_hash
		and item_count == _passive_inventory_icon_prewarm_item_count
	):
		return
	_passive_inventory_icon_prewarm_items_hash = items_hash
	_passive_inventory_icon_prewarm_item_count = item_count
	if inventory_items.is_empty():
		return
	var visuals: Object = _get_prewarm_instance(registry, module_getter, "active_item_hud_visuals")
	if _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("prewarm_item_icons"):
		_active_item_icon_renderer.prewarm_item_icons(inventory_items, visuals)
		return
	if visuals == null or not visuals.has_method("get_icon_texture"):
		return
	for item_value in inventory_items:
		var item_data: Dictionary = _get_dict(item_value)
		if item_data.is_empty():
			continue
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			var texture_2d: Texture2D = texture as Texture2D
			texture_2d.get_size()


func _get_passive_inventory_icon_hash(inventory_items: Array) -> int:
	var result: int = inventory_items.size()
	for item_value in inventory_items:
		var item_data: Dictionary = _get_dict(item_value)
		if item_data.is_empty():
			continue
		result = hash([
			result,
			item_data.get("name", ""),
			item_data.get("icon_path", ""),
			item_data.get("icon_sheet_path", ""),
		])
	return result


func _get_passive_inventory_summary(inventory_items: Array) -> Dictionary:
	var equipped_count := 0
	for item_value in inventory_items:
		var item_data: Dictionary = _get_dict(item_value)
		var equipped: bool = bool(item_data.get("_draw_equipped", false))
		if not item_data.has("_draw_equipped"):
			equipped = bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != ""
		if equipped:
			equipped_count += 1
	return _set_passive_inventory_summary(inventory_items.size(), equipped_count)


func _set_passive_inventory_summary(item_count: int, equipped_count: int) -> Dictionary:
	if item_count == _passive_inventory_summary_count and equipped_count == _passive_inventory_summary_equipped:
		return _passive_inventory_summary
	_passive_inventory_summary_count = item_count
	_passive_inventory_summary_equipped = equipped_count
	_passive_inventory_summary["count"] = item_count
	_passive_inventory_summary["equipped"] = equipped_count
	_passive_inventory_summary["count_text"] = "보유 " + str(item_count) + " / 장착 " + str(equipped_count)
	return _passive_inventory_summary


func _get_passive_inventory_count_text_width(font: Font, count_text: String, size: int) -> float:
	var font_id: int = font.get_instance_id() if font != null else 0
	if (
		_passive_inventory_count_text_width_text == count_text
		and _passive_inventory_count_text_width_size == size
		and _passive_inventory_count_text_width_font_id == font_id
	):
		return _passive_inventory_count_text_width
	var width: float = _text_size(font, count_text, size).x
	_passive_inventory_count_text_width_text = count_text
	_passive_inventory_count_text_width_size = size
	_passive_inventory_count_text_width_font_id = font_id
	_passive_inventory_count_text_width = width
	return width


func _get_header_status_width(font: Font, status_text: String, size: int) -> float:
	var font_id: int = font.get_instance_id() if font != null else 0
	if (
		_header_status_width_text == status_text
		and _header_status_width_size == size
		and _header_status_width_font_id == font_id
	):
		return _header_status_width
	var width: float = _text_size(font, status_text, size).x
	_header_status_width_text = status_text
	_header_status_width_size = size
	_header_status_width_font_id = font_id
	_header_status_width = width
	return width


func _get_header_subtitle(display_name: String, character_type: String) -> String:
	if (
		display_name == _header_subtitle_display_name
		and character_type == _header_subtitle_character_type
	):
		return _header_subtitle_text
	_header_subtitle_display_name = display_name
	_header_subtitle_character_type = character_type
	_header_subtitle_text = display_name + "  /  " + _character_type_label(character_type)
	return _header_subtitle_text


func _get_header_status_text(pending: int, gold: int) -> String:
	var language := LanguageSettings.get_language()
	if pending == _header_status_pending and gold == _header_status_gold and language == _header_status_language:
		return _header_status_text
	_header_status_pending = pending
	_header_status_gold = gold
	_header_status_language = language
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		_header_status_text = "Choices Waiting " + str(pending) + "   Perk Gold " + str(gold)
	elif language == LanguageSettings.LANGUAGE_SPANISH:
		_header_status_text = "Opciones en espera " + str(pending) + "   Oro de perks " + str(gold)
	elif language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		_header_status_text = "Escolhas pendentes " + str(pending) + "   Ouro de perks " + str(gold)
	elif language == LanguageSettings.LANGUAGE_RUSSIAN:
		_header_status_text = "Ожидает выбор " + str(pending) + "   Золото перков " + str(gold)
	elif language == LanguageSettings.LANGUAGE_CHINESE:
		_header_status_text = "待选择 " + str(pending) + "   升级金币 " + str(gold)
	elif language == LanguageSettings.LANGUAGE_JAPANESE:
		_header_status_text = "選択待ち " + str(pending) + "   パークゴールド " + str(gold)
	else:
		_header_status_text = "선택 대기 " + str(pending) + "   퍽 골드 " + str(gold)
	return _header_status_text


func _refresh_active_item_label_cache(slots: Array) -> void:
	var slot_count := slots.size()
	_ensure_active_item_label_cache_size(slot_count)
	for i in range(slot_count):
		var item_name := ""
		var raw_display_name := ""
		if slots[i] is Dictionary:
			var item_data: Dictionary = slots[i]
			item_name = str(item_data.get("name", ""))
			raw_display_name = str(item_data.get("display_name", ""))
		if _active_item_label_cache_names[i] == item_name and _active_item_label_cache_raw_display_names[i] == raw_display_name:
			continue
		var display_name: String = raw_display_name
		if display_name == "" and _active_item_catalog != null and _active_item_catalog.has_method("get_display_name"):
			display_name = str(_active_item_catalog.get_display_name(item_name))
		if display_name == "":
			display_name = item_name
		_active_item_label_cache_names[i] = item_name
		_active_item_label_cache_raw_display_names[i] = raw_display_name
		_active_item_display_name_cache[i] = display_name
		_active_item_trimmed_label_cache[i] = _trim_label(display_name, 10)


func _ensure_active_item_label_cache_size(slot_count: int) -> void:
	if _active_item_label_cache_names.size() == slot_count:
		return
	_active_item_label_cache_names.resize(slot_count)
	_active_item_label_cache_raw_display_names.resize(slot_count)
	_active_item_display_name_cache.resize(slot_count)
	_active_item_trimmed_label_cache.resize(slot_count)


func _active_item_label_cache_matches(slots: Array) -> bool:
	if slots.size() != _active_item_label_cache_names.size():
		return false
	for i in range(slots.size()):
		var item_name := ""
		var raw_display_name := ""
		if slots[i] is Dictionary:
			var item_data: Dictionary = slots[i]
			item_name = str(item_data.get("name", ""))
			raw_display_name = str(item_data.get("display_name", ""))
		if _active_item_label_cache_names[i] != item_name or _active_item_label_cache_raw_display_names[i] != raw_display_name:
			return false
	return true


func _prewarm_static_text(font: Font, owner: Object) -> void:
	for text in ["퍽", "Lv.1", "Lv.2", "Lv.3", "Lv.4", "Lv.5", "0 / 2", "0 / 3", "0 / 5", "-", "E"]:
		for size in [8, 9, 10, 11, 12, 13, 14, 15]:
			_text_size(font, str(text), int(size))
	_ensure_equipment_slot_metadata_cache()
	for i in range(_equipment_slot_keys.size()):
		var key: String = _equipment_slot_keys[i]
		var label: String = _equipment_slot_labels[i]
		_text_size(font, label, 10)
		_text_size(font, label, 13)
		_text_size(font, _slot_display_label(key), 12)
	for character_type in ["smasher", "viper", "soldier"]:
		_text_size(font, _character_type_label(str(character_type)), 14)
		_text_size(font, _get_character_display_name(owner, str(character_type)), 20)


func _prewarm_active_item_text(font: Font) -> void:
	var item_names: Array = []
	item_names.append_array(ActiveItemCatalog.FIELD_SPAWN_ORDER)
	item_names.append_array(EXTRA_ACTIVE_ITEM_PREWARM_NAMES)
	for item_name_value in item_names:
		var item_name: String = str(item_name_value)
		if item_name == "":
			continue
		var item_data: Dictionary = _active_item_catalog.build_item_by_name(item_name)
		if item_data.is_empty():
			continue
		var display_name: String = str(item_data.get("display_name", ""))
		if display_name == "":
			display_name = str(_active_item_catalog.get_display_name(item_name))
		_text_size(font, display_name, 10)
		_text_size(font, display_name, 13)
		_text_size(font, _trim_label(display_name, 10), 10)
		_prewarm_text_block(font, _get_string_fallback(item_data, "description", "desc"), 13, 312.0, 5)


func _prewarm_runtime_perk_text(font: Font, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var catalog: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_catalog")
	if catalog == null:
		return false
	var character_type: String = _get_character_type(owner)
	var entries: Array = []
	if catalog.has_method("get_debug_perk_entries"):
		entries = _get_array(catalog.get_debug_perk_entries(character_type))
	elif catalog.has_method("get_all_perk_data"):
		var all_data: Dictionary = _get_dict(catalog.get_all_perk_data())
		for skill_id_value in all_data.keys():
			var entry: Dictionary = _get_dict(all_data[skill_id_value]).duplicate(true)
			entry["id"] = str(skill_id_value)
			entries.append(entry)
	for entry_value in entries:
		_prewarm_perk_text_entry(font, _get_dict(entry_value))

	var runtime_state: Object = _get_prewarm_instance(registry, module_getter, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("get_snapshot"):
		return true
	var snapshot: Dictionary = _get_dict(runtime_state.get_snapshot())
	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	for skill_id_value in levels.keys():
		var skill_id: String = str(skill_id_value)
		var level: int = int(levels.get(skill_id_value, 1))
		_text_size(font, "Lv.%d" % level, 9)
		if catalog.has_method("get_perk_data"):
			var data: Dictionary = _get_dict(catalog.get_perk_data(skill_id))
			if not data.is_empty():
				data["id"] = skill_id
				data["level"] = level
				_prewarm_perk_text_entry(font, data)
	return true


func _prewarm_perk_text_entry(font: Font, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var skill_id: String = str(entry.get("id", ""))
	var name: String = str(entry.get("name", skill_id))
	_text_size(font, name, 13)
	_text_size(font, name, 15)
	_text_size(font, _trim_label(name, 7), 10)
	for level in range(1, max(2, min(10, int(entry.get("max_level", 1))) + 1)):
		_text_size(font, "Lv.%d" % level, 9)
	var detail: String = _get_string_fallback(entry, "description", "detail")
	_prewarm_text_block(font, detail, 13, 312.0, 5)
	var descriptions: Dictionary = _get_dict(entry.get("descriptions", {}))
	for description_value in descriptions.values():
		_prewarm_text_block(font, str(description_value), 13, 312.0, 5)


func _prewarm_skill_text(font: Font, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var seen: Dictionary = {}
	var warmed := false
	for character_type_value in ["smasher", "viper", "soldier"]:
		var character_type: String = str(character_type_value)
		var config_key := "smasher_skill_config"
		if _character_runtime != null and _character_runtime.has_method("get_skill_config_key"):
			config_key = str(_character_runtime.get_skill_config_key(character_type))
		var skill_config: Object = _get_prewarm_instance(registry, module_getter, config_key)
		if skill_config == null or not skill_config.has_method("get_snapshot"):
			continue
		var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
		var skill_data: Dictionary = _get_dict(snapshot.get("skill_data", {}))
		for skill_id_value in skill_data.keys():
			var skill_id: String = str(skill_id_value)
			if seen.has(skill_id):
				continue
			seen[skill_id] = true
			var data: Dictionary = _get_dict(skill_data[skill_id_value])
			var name: String = str(data.get("korean", skill_id))
			_text_size(font, name, 10)
			_text_size(font, name, 15)
			_text_size(font, _trim_label(name, 7), 10)
			_prewarm_text_block(font, str(data.get("description", "")), 13, 312.0, 5)
			warmed = true
	var current_character: String = _get_character_type(owner)
	_text_size(font, _character_type_label(current_character), 14)
	return warmed


func _prewarm_text_block(font: Font, text: String, size: int, max_width: float, max_lines: int) -> void:
	if text == "":
		return
	_wrap_text_to_width(font, text, size, max_width, max_lines)


func _get_prewarm_instance(registry: Object, module_getter: Callable, key: String) -> Object:
	var registry_instance: Object = _get_instance(registry, key)
	if registry_instance != null:
		return registry_instance
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _build_acquired_perks_cached(
	levels: Dictionary,
	catalog: Object,
	runtime_state: Object = null,
	runtime_snapshot_override: Variant = null,
	equipped_skills_for_filter: Array = []
) -> Array:
	var effective_levels: Dictionary = _get_effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	var cache_hash: int = _get_acquired_perk_cache_hash(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter)
	if _acquired_perk_cache_ready and cache_hash == _acquired_perk_cache_hash:
		return _acquired_perk_cache
	_acquired_perk_cache_hash = cache_hash
	_acquired_perk_cache_ready = true
	_acquired_perk_cache = _build_acquired_perks(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter)
	return _acquired_perk_cache


func _get_acquired_perk_cache_hash(
	levels: Dictionary,
	catalog: Object,
	runtime_state: Object = null,
	runtime_snapshot_override: Variant = null,
	effective_levels: Dictionary = {},
	equipped_skills_for_filter: Array = []
) -> int:
	var catalog_id: int = catalog.get_instance_id() if catalog != null else 0
	var equipped_skills_hash: int = hash(equipped_skills_for_filter)
	var has_snapshot_effective_levels := runtime_snapshot_override is Dictionary and (runtime_snapshot_override as Dictionary).has("effective_runtime_skill_levels")
	if runtime_state != null and not has_snapshot_effective_levels:
		return _get_acquired_perk_runtime_cache_hash(levels, catalog_id, runtime_state, effective_levels, equipped_skills_hash)
	return hash([catalog_id, hash(levels), hash(effective_levels), equipped_skills_hash])


func _get_acquired_perk_runtime_cache_hash(
	levels: Dictionary,
	catalog_id: int,
	runtime_state: Object,
	effective_levels: Dictionary,
	equipped_skills_hash: int
) -> int:
	var result: int = hash(catalog_id)
	result = hash([result, equipped_skills_hash])
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var effective_level: int = _get_effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		result = hash([result, skill_id, base_level, effective_level])
	return result


func _build_acquired_perks(
	levels: Dictionary,
	catalog: Object,
	runtime_state: Object = null,
	runtime_snapshot_override: Variant = null,
	effective_levels_override: Dictionary = {},
	equipped_skills_for_filter: Array = []
) -> Array:
	var result: Array = []
	var effective_levels: Dictionary = effective_levels_override
	if effective_levels.is_empty():
		effective_levels = _get_effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	var equipped_skill_lookup: Dictionary = _build_equipped_skill_lookup(equipped_skills_for_filter)
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var level: int = _get_effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		var data: Dictionary = {}
		if catalog != null and catalog.has_method("get_perk_data"):
			data = catalog.get_perk_data(skill_id)
		if data.is_empty():
			data = {"name": skill_id, "icon_color": ACCENT_BLUE, "tree": ""}
		elif _should_hide_equipped_unlock_perk(data, equipped_skill_lookup):
			continue
		data = data.duplicate(true)
		data["id"] = skill_id
		data["base_level"] = base_level
		data["level"] = level
		if not data.has("description"):
			var descriptions: Dictionary = _get_dict(data.get("descriptions", {}))
			var description_value: Variant = descriptions.get(level, null)
			if description_value == null:
				description_value = data.get("detail", "")
			data["description"] = str(description_value)
		data["_draw_id"] = skill_id
		var draw_color: Color = _get_color(data.get("icon_color", ACCENT_BLUE))
		data["_draw_color"] = draw_color
		data["_draw_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.48)
		data["_draw_hover_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.92)
		data["_level_text"] = _perk_level_text(data)
		data["_level_color"] = _perk_level_color(data)
		result.append(data)
	result.sort_custom(Callable(self, "_sort_perks"))
	_refresh_acquired_perk_draw_arrays(result)
	return result


func _build_equipped_skill_lookup(equipped_skills: Array) -> Dictionary:
	var result: Dictionary = {}
	for skill_id_value in equipped_skills:
		var skill_id: String = str(skill_id_value)
		if skill_id != "":
			result[skill_id] = true
	return result


func _should_hide_equipped_unlock_perk(perk_data: Dictionary, equipped_skill_lookup: Dictionary) -> bool:
	if equipped_skill_lookup.is_empty():
		return false
	var unlocked_skill: String = str(perk_data.get("unlocks_skill", ""))
	return unlocked_skill != "" and bool(equipped_skill_lookup.get(unlocked_skill, false))


func _refresh_acquired_perk_draw_arrays(acquired: Array) -> void:
	var acquired_count: int = acquired.size()
	_acquired_perk_draw_id_cache.resize(acquired_count)
	_acquired_perk_draw_color_cache.resize(acquired_count)
	_acquired_perk_border_color_cache.resize(acquired_count)
	_acquired_perk_hover_border_color_cache.resize(acquired_count)
	_acquired_perk_level_text_cache.resize(acquired_count)
	_acquired_perk_level_color_cache.resize(acquired_count)
	_acquired_perk_hover_title_cache.resize(acquired_count)
	_acquired_perk_hover_body_cache.resize(acquired_count)
	for i in range(acquired_count):
		var perk: Dictionary = _get_dict(acquired[i])
		_acquired_perk_draw_id_cache[i] = str(perk.get("_draw_id", perk.get("id", "")))
		_acquired_perk_draw_color_cache[i] = _get_color(perk.get("_draw_color", perk.get("icon_color", ACCENT_BLUE)))
		_acquired_perk_border_color_cache[i] = _get_color(perk.get("_draw_border_color", Color(_acquired_perk_draw_color_cache[i].r, _acquired_perk_draw_color_cache[i].g, _acquired_perk_draw_color_cache[i].b, 0.48)))
		_acquired_perk_hover_border_color_cache[i] = _get_color(perk.get("_draw_hover_border_color", Color(_acquired_perk_draw_color_cache[i].r, _acquired_perk_draw_color_cache[i].g, _acquired_perk_draw_color_cache[i].b, 0.92)))
		_acquired_perk_level_text_cache[i] = str(perk.get("_level_text", _perk_level_text(perk)))
		_acquired_perk_level_color_cache[i] = _get_color(perk.get("_level_color", _perk_level_color(perk)))
		_acquired_perk_hover_title_cache[i] = _get_string_fallback(perk, "name", "id")
		_acquired_perk_hover_body_cache[i] = _get_string_fallback(perk, "description", "detail")


func _get_effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override: Variant) -> Dictionary:
	if runtime_snapshot_override is Dictionary:
		return _get_dict((runtime_snapshot_override as Dictionary).get("effective_runtime_skill_levels", {}))
	return {}


func _get_effective_runtime_perk_level(runtime_state: Object, skill_id: String, base_level: int, effective_levels: Dictionary = {}) -> int:
	if base_level <= 0:
		return base_level
	if effective_levels.has(skill_id):
		return max(0, int(effective_levels.get(skill_id, base_level)))
	if runtime_state != null and runtime_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_state.get_runtime_skill_level(skill_id)))
	return base_level


func _sort_perks(a: Dictionary, b: Dictionary) -> bool:
	var a_level: int = int(a.get("level", 0))
	var b_level: int = int(b.get("level", 0))
	if a_level == b_level:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return a_level > b_level


func _wrap_text_to_width(font: Font, text: String, size: int, max_width: float, max_lines: int) -> Array:
	if text == "" or max_lines <= 0:
		return []
	var size_key: int = _ui_font_size(size)
	var safe_width: float = max(1.0, max_width)
	var max_width_key: int = int(round(safe_width))
	if (
		text == _wrap_text_fast_text
		and size_key == _wrap_text_fast_size
		and max_width_key == _wrap_text_fast_width
		and max_lines == _wrap_text_fast_max_lines
	):
		return _wrap_text_fast_lines
	var cache_key := "%d:%d:%d:%s" % [size_key, max_width_key, max_lines, text]
	if _wrap_text_cache.has(cache_key):
		var cached_lines: Variant = _wrap_text_cache[cache_key]
		if cached_lines is Array:
			_wrap_text_fast_text = text
			_wrap_text_fast_size = size_key
			_wrap_text_fast_width = max_width_key
			_wrap_text_fast_max_lines = max_lines
			_wrap_text_fast_lines = cached_lines
			return cached_lines
		_wrap_text_cache.erase(cache_key)
	var lines: Array = []
	for paragraph_value in text.split("\n"):
		_append_wrapped_paragraph_lines(lines, str(paragraph_value).strip_edges(), font, size, safe_width, max_lines)
		if lines.size() >= max_lines:
			return _store_wrapped_text_lines(cache_key, text, size_key, max_width_key, max_lines, lines)
	while lines.size() > max_lines:
		lines.pop_back()
	return _store_wrapped_text_lines(cache_key, text, size_key, max_width_key, max_lines, lines)


func _append_wrapped_paragraph_lines(lines: Array, paragraph: String, font: Font, size: int, max_width: float, max_lines: int) -> void:
	if paragraph == "":
		return
	var words: PackedStringArray = paragraph.split(" ", false)
	var line := ""
	for word_value in words:
		var word: String = str(word_value)
		if word == "":
			continue
		var candidate := word if line == "" else "%s %s" % [line, word]
		if _text_size(font, candidate, size).x <= max_width:
			line = candidate
			continue
		if line != "":
			lines.append(line)
			if lines.size() >= max_lines:
				return
			line = ""
		if _text_size(font, word, size).x <= max_width:
			line = word
			continue
		var chunks: Array = _split_unbroken_text_to_width(font, word, size, max_width)
		for chunk in chunks:
			lines.append(str(chunk))
			if lines.size() >= max_lines:
				return
	if line != "" and lines.size() < max_lines:
		lines.append(line)


func _split_unbroken_text_to_width(font: Font, text: String, size: int, max_width: float) -> Array:
	var chunks: Array = []
	var chunk := ""
	for i in range(text.length()):
		var next_character: String = text.substr(i, 1)
		var candidate := chunk + next_character
		if chunk == "" or _text_size(font, candidate, size).x <= max_width:
			chunk = candidate
			continue
		chunks.append(chunk)
		chunk = next_character
	if chunk != "":
		chunks.append(chunk)
	return chunks


func _store_wrapped_text_lines(cache_key: String, text: String, size_key: int, max_width_key: int, max_lines: int, lines: Array) -> Array:
	if _wrap_text_cache.size() >= WRAP_TEXT_CACHE_LIMIT:
		_wrap_text_cache.clear()
	_wrap_text_cache[cache_key] = lines
	_wrap_text_fast_text = text
	_wrap_text_fast_size = size_key
	_wrap_text_fast_width = max_width_key
	_wrap_text_fast_max_lines = max_lines
	_wrap_text_fast_lines = lines
	return lines


func _try_handle_passive_inventory_context_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	var runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if runtime == null or not runtime.has_method("toggle_inventory_item"):
		return false
	var index: int = _get_cached_grid_hover_index(
		mouse_pos,
		_last_passive_inventory_grid_rect,
		_last_passive_grid_start,
		_last_passive_grid_cell_size,
		_last_passive_grid_stride,
		_last_passive_grid_columns,
		_last_passive_grid_item_count
	)
	if index >= 0:
		return bool(runtime.toggle_inventory_item(index, owner, registry))
	return false


func _try_handle_equipment_context_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	if not _last_equipment_rect.has_point(mouse_pos):
		return false
	var runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if runtime == null or not runtime.has_method("unequip_slot"):
		return false
	var slot_key: String = _get_equipment_slot_key_at_mouse(mouse_pos)
	if slot_key == "":
		return false
	return bool(runtime.unequip_slot(slot_key, owner, registry))


func _get_passive_inventory_items(owner: Object, registry: Object, mythic_item_runtime: Object = null) -> Array:
	var runtime: Object = mythic_item_runtime
	if runtime == null:
		runtime = _get_instance(registry, "mythic_item_runtime")
	if runtime != null:
		var live_items_value: Variant = runtime.get("inventory_items")
		if live_items_value is Array:
			return live_items_value
		if runtime.has_method("get_snapshot"):
			var snapshot: Dictionary = _get_dict(runtime.get_snapshot())
			var items: Array = _get_array(snapshot.get("inventory_items", []))
			if not items.is_empty():
				return items
	var direct: Array = _get_array(_safe_owner_get(owner, "passive_item_inventory", []))
	if not direct.is_empty():
		return direct
	var state: Dictionary = _get_dict(_safe_owner_get(owner, "mythic_item_state", {}))
	var state_items: Array = _get_array(state.get("inventory_items", []))
	if not state_items.is_empty():
		return state_items
	var equipped: Dictionary = _get_dict(state.get("equipped_items", {}))
	if not equipped.is_empty():
		var result: Array = []
		for item_name in equipped:
			var item_data: Dictionary = _get_dict(equipped[item_name])
			if not item_data.is_empty():
				result.append(item_data)
		return result
	return []


func _prepare_passive_inventory_draw_cache(inventory_items: Array) -> Dictionary:
	var item_count: int = inventory_items.size()
	var items_hash: int = hash(inventory_items)
	if _passive_inventory_draw_cache_matches(items_hash, item_count):
		return _passive_inventory_summary
	_ensure_passive_inventory_draw_cache_size(item_count)
	var equipped_count := 0
	for i in range(item_count):
		var item_value: Variant = inventory_items[i]
		var item_data: Dictionary = _get_dict(item_value)
		if item_data.is_empty():
			_passive_inventory_item_cache[i] = {}
			_passive_inventory_draw_color_cache[i] = Color.WHITE
			_passive_inventory_border_color_cache[i] = Color.TRANSPARENT
			_passive_inventory_active_border_color_cache[i] = Color.TRANSPARENT
			_passive_inventory_equipped_cache[i] = false
			continue
		_passive_inventory_item_cache[i] = item_data
		var cached_color: Variant = item_data.get("_draw_color", null)
		var color: Color = cached_color if cached_color is Color else _passive_item_frame_color(item_data)
		var equipped: bool = bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != ""
		var cached_equipped: Variant = item_data.get("_draw_equipped", null)
		if typeof(cached_equipped) != TYPE_BOOL or bool(cached_equipped) != equipped:
			item_data["_draw_equipped"] = equipped
		if equipped:
			equipped_count += 1
		if not (cached_color is Color):
			item_data["_draw_color"] = color
		if not (item_data.get("_draw_border_color", null) is Color):
			item_data["_draw_border_color"] = Color(color.r, color.g, color.b, 0.48)
		if not (item_data.get("_draw_active_border_color", null) is Color):
			item_data["_draw_active_border_color"] = Color(color.r, color.g, color.b, 0.90)
		_passive_inventory_draw_color_cache[i] = color
		_passive_inventory_border_color_cache[i] = item_data["_draw_border_color"] as Color
		_passive_inventory_active_border_color_cache[i] = item_data["_draw_active_border_color"] as Color
		_passive_inventory_equipped_cache[i] = equipped
	_passive_inventory_draw_cache_items_hash = hash(inventory_items)
	_passive_inventory_draw_cache_item_count = item_count
	return _set_passive_inventory_summary(item_count, equipped_count)


func _passive_inventory_draw_cache_matches(items_hash: int, item_count: int) -> bool:
	return (
		items_hash == _passive_inventory_draw_cache_items_hash
		and item_count == _passive_inventory_draw_cache_item_count
		and _passive_inventory_item_cache.size() == item_count
	)


func _ensure_passive_inventory_draw_cache_size(item_count: int) -> void:
	if (
		_passive_inventory_draw_color_cache.size() == item_count
		and _passive_inventory_border_color_cache.size() == item_count
		and _passive_inventory_active_border_color_cache.size() == item_count
		and _passive_inventory_equipped_cache.size() == item_count
		and _passive_inventory_item_cache.size() == item_count
	):
		return
	_passive_inventory_item_cache.resize(item_count)
	_passive_inventory_draw_color_cache.resize(item_count)
	_passive_inventory_border_color_cache.resize(item_count)
	_passive_inventory_active_border_color_cache.resize(item_count)
	_passive_inventory_equipped_cache.resize(item_count)


func _build_passive_item_body(item_data: Dictionary) -> String:
	var cache_hash: int = _passive_item_body_hash(item_data)
	if _passive_item_body_cache_ready and cache_hash == _passive_item_body_cache_hash:
		return _passive_item_body_cache
	var lines: Array = []
	var description: String = _get_string_fallback(item_data, "description", "desc")
	if description != "":
		lines.append(description)
	var equipped_slot: String = str(item_data.get("_equipped_slot", ""))
	if equipped_slot != "":
		lines.append("장착: %s" % _slot_display_label(equipped_slot))
	else:
		lines.append("미장착")
	var result: String = "\n".join(lines)
	_passive_item_body_cache_hash = cache_hash
	_passive_item_body_cache_ready = true
	_passive_item_body_cache = result
	return result


func _passive_item_body_hash(item_data: Dictionary) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("display_name", ""),
		item_data.get("korean", ""),
		item_data.get("description", ""),
		item_data.get("desc", ""),
		item_data.get("_equipped_slot", ""),
	])


func _get_item_slot_key(item_data: Dictionary) -> String:
	var equipped_slot: String = str(item_data.get("_equipped_slot", ""))
	if equipped_slot != "":
		return equipped_slot
	var slot_key: String = str(item_data.get("slot", ""))
	if slot_key != "":
		return slot_key
	return str(item_data.get("body_part", ""))


func _item_part_subtitle(slot_key: String) -> String:
	var label: String = _slot_display_label(slot_key)
	if label == "":
		return ""
	return "부위 : %s" % label


func _build_passive_item_roll_entries(item_data: Dictionary, registry: Object = null, mythic_item_runtime: Object = null, runtime_state: Object = null) -> Array:
	var rolls: Dictionary = _get_dict(item_data.get("rolls", {}))
	var option_source: Array = _get_array(item_data.get("rolled_options", []))
	if option_source.is_empty():
		option_source = _get_array(item_data.get("roll_options", []))
	var fixed_options: Array = _get_array(item_data.get("fixed_options", []))
	if fixed_options.is_empty() and option_source.is_empty():
		return []
	if mythic_item_runtime == null:
		mythic_item_runtime = _get_instance(registry, "mythic_item_runtime")
	var runtime_id: int = mythic_item_runtime.get_instance_id() if mythic_item_runtime != null else 0
	var polish_multiplier: float = _get_passive_item_roll_polish_multiplier(registry, runtime_state)
	var item_hash: int = hash(item_data)
	if (
		item_hash == _passive_item_roll_entries_cache_item_hash
		and runtime_id == _passive_item_roll_entries_cache_runtime_id
		and is_equal_approx(polish_multiplier, _passive_item_roll_entries_cache_polish_multiplier)
	):
		return _passive_item_roll_entries_cache
	_passive_item_roll_entries_cache.clear()
	var result: Array = _passive_item_roll_entries_cache
	for fixed_value in fixed_options:
		var fixed_option: Dictionary = _get_dict(fixed_value)
		var fixed_label: String = str(fixed_option.get("label", ""))
		if fixed_label == "":
			continue
		var fixed_text: String = "%s%s" % [
			str(fixed_option.get("value", "")),
			str(fixed_option.get("unit", "")),
		]
		var fixed_entry: Dictionary = _get_passive_item_roll_entry_dict(result.size())
		fixed_entry["text"] = "%s: %s" % [fixed_label, fixed_text]
		fixed_entry["color"] = STAT_BUFF_COLOR
		result.append(fixed_entry)
	for option_value in option_source:
		var option: Dictionary = _get_dict(option_value)
		var key: String = str(option.get("key", ""))
		if key == "":
			continue
		var label: String = str(option.get("label", key))
		var value: float = _get_roll_option_value(option, rolls, key)
		var effective_value: float = value
		if mythic_item_runtime != null and mythic_item_runtime.has_method("get_item_roll_value"):
			effective_value = float(mythic_item_runtime.get_item_roll_value(item_data, key, true, registry))
		var formatted: String = _format_roll_option_value(value, option)
		var delta_text: String = _format_roll_effective_delta(value, effective_value, option)
		formatted = "%s%s" % [formatted, delta_text]
		var option_entry: Dictionary = _get_passive_item_roll_entry_dict(result.size())
		option_entry["text"] = "%s: %s" % [label, formatted]
		option_entry["color"] = _get_color(option.get("color", ACCENT_GOLD))
		result.append(option_entry)
	_passive_item_roll_entries_cache_item_hash = item_hash
	_passive_item_roll_entries_cache_runtime_id = runtime_id
	_passive_item_roll_entries_cache_polish_multiplier = polish_multiplier
	return result


func _get_passive_item_roll_entry_dict(index: int) -> Dictionary:
	while _passive_item_roll_entry_dict_cache.size() <= index:
		_passive_item_roll_entry_dict_cache.append({})
	var data: Dictionary = _passive_item_roll_entry_dict_cache[index]
	data.clear()
	return data


func _get_passive_item_roll_polish_multiplier(registry: Object, runtime_state_override: Object) -> float:
	var runtime_state: Object = runtime_state_override
	if runtime_state == null:
		runtime_state = _get_instance(registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("get_effective_polish_multiplier"):
		return float(runtime_state.get_effective_polish_multiplier())
	return 1.0


func _format_roll_option_value(value: float, option: Dictionary) -> String:
	var step: float = float(option.get("step", 1.0))
	var unit: String = str(option.get("unit", ""))
	var prefix: String = str(option.get("prefix", ""))
	var value_text: String = "%.1f" % value if step > 0.0 and step < 1.0 else "%d" % int(round(value))
	if unit == "+":
		return "+%s" % value_text
	return "%s%s%s" % [prefix, value_text, unit]


func _get_roll_option_value(option: Dictionary, rolls: Dictionary, key: String) -> float:
	var direct_value: Variant = option.get("value", null)
	if direct_value != null:
		return float(direct_value)
	var rolled_value: Variant = rolls.get(key, null)
	if rolled_value != null:
		return float(rolled_value)
	var default_value: Variant = option.get("default", null)
	if default_value != null:
		return float(default_value)
	return float(option.get("min", 0.0))


func _format_roll_effective_delta(base_value: float, effective_value: float, option: Dictionary) -> String:
	var raw_delta: float = effective_value - base_value
	var prefix: String = str(option.get("prefix", ""))
	var reverse := bool(option.get("reverse", false))
	var delta: float = raw_delta
	if reverse and prefix == "-":
		delta = base_value - effective_value
	elif not reverse and prefix == "-":
		delta = base_value - effective_value
	if abs(delta) < 0.01:
		return ""
	var step: float = float(option.get("step", 1.0))
	if step >= 1.0 and int(round(abs(delta))) == 0:
		return ""
	var unit: String = str(option.get("unit", ""))
	@warning_ignore("shadowed_global_identifier")
	var sign := "+" if delta > 0.0 else "-"
	var absolute_delta: float = abs(delta)
	var value_text: String = "%.1f" % absolute_delta if step > 0.0 and step < 1.0 else "%d" % int(round(absolute_delta))
	if unit == "+":
		return " (%s%s)" % [sign, value_text]
	return " (%s%s%s)" % [sign, value_text, unit]


func _draw_equipped_badge(canvas: CanvasItem, badge_rect: Rect2, badge_center_x: float, badge_center_y: float, font: Font) -> void:
	canvas.draw_rect(badge_rect, OVERLAY_EQUIPPED_BADGE_FILL)
	canvas.draw_rect(badge_rect, Color.WHITE, false, 1.0)
	_draw_text_centered_xy(canvas, font, "E", badge_center_x, badge_center_y, 8, Color.WHITE)


func _passive_item_frame_color(item_data: Dictionary) -> Color:
	var raw: Variant = item_data.get("color", null)
	if raw is Color:
		return raw
	var cache_hash: int = _passive_item_frame_color_hash(item_data)
	var cached_color: Variant = _passive_item_frame_color_cache.get(cache_hash, null)
	if cached_color is Color:
		return cached_color
	var rarity: String = _get_string_fallback(item_data, "rarity", "type").to_lower()
	var result: Color
	match rarity:
		"mythic":
			result = Color(1.0, 215.0 / 255.0, 75.0 / 255.0)
		"legendary":
			result = Color(1.0, 130.0 / 255.0, 92.0 / 255.0)
		"passive":
			result = Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0)
		_:
			result = Color(185.0 / 255.0, 205.0 / 255.0, 235.0 / 255.0)
	if _passive_item_frame_color_cache.size() >= PASSIVE_FRAME_COLOR_CACHE_LIMIT:
		_passive_item_frame_color_cache.clear()
	_passive_item_frame_color_cache[cache_hash] = result
	return result


func _passive_item_frame_color_hash(item_data: Dictionary) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("rarity", ""),
		item_data.get("type", ""),
	])


func _slot_display_label(slot_key: String) -> String:
	match slot_key:
		"":
			return ""
		"head":
			return "머리"
		"top":
			return "상의"
		"torso":
			return "상의"
		"arm":
			return "팔"
		"left_arm":
			return "팔"
		"right_arm":
			return "팔"
		"belt":
			return "벨트"
		"belt2":
			return "등"
		"back":
			return "등"
		"등":
			return "등"
		"knee":
			return "무릎"
		"shoes":
			return "신발"
		"accessory":
			return "장신구"
		"accessory1":
			return "장신구"
		"accessory2":
			return "장신구"
		"accessory3":
			return "장신구"
		"accessory4":
			return "장신구"
		_:
			return slot_key


func _get_max_passive_inventory_scroll() -> float:
	return max(0.0, _last_passive_inventory_content_height - _last_passive_inventory_rect.size.y + 48.0)


func _update_passive_inventory_scrollbar_layout(grid_rect: Rect2, max_scroll: float) -> void:
	if (
		grid_rect == _passive_scrollbar_layout_rect
		and is_equal_approx(max_scroll, _passive_scrollbar_layout_max_scroll)
		and is_equal_approx(_last_passive_inventory_content_height, _passive_scrollbar_layout_content_height)
		and is_equal_approx(passive_inventory_scroll, _passive_scrollbar_layout_scroll)
	):
		return
	_passive_scrollbar_layout_rect = grid_rect
	_passive_scrollbar_layout_max_scroll = max_scroll
	_passive_scrollbar_layout_content_height = _last_passive_inventory_content_height
	_passive_scrollbar_layout_scroll = passive_inventory_scroll
	if max_scroll <= 0.0:
		_passive_scrollbar_track_rect = Rect2()
		_passive_scrollbar_thumb_rect = Rect2()
		return
	_passive_scrollbar_track_rect = Rect2(grid_rect.end.x - 6.0, grid_rect.position.y + 4.0, 4.0, grid_rect.size.y - 8.0)
	var thumb_h: float = max(22.0, _passive_scrollbar_track_rect.size.y * (grid_rect.size.y / max(grid_rect.size.y, _last_passive_inventory_content_height)))
	var thumb_y: float = _passive_scrollbar_track_rect.position.y + (_passive_scrollbar_track_rect.size.y - thumb_h) * (passive_inventory_scroll / max_scroll)
	_passive_scrollbar_thumb_rect = Rect2(_passive_scrollbar_track_rect.position.x, thumb_y, _passive_scrollbar_track_rect.size.x, thumb_h)


func _draw_passive_inventory_scrollbar(canvas: CanvasItem, grid_rect: Rect2, max_scroll: float) -> void:
	_update_passive_inventory_scrollbar_layout(grid_rect, max_scroll)
	canvas.draw_rect(_passive_scrollbar_track_rect, OVERLAY_SCROLLBAR_TRACK)
	canvas.draw_rect(_passive_scrollbar_thumb_rect, OVERLAY_PASSIVE_SCROLLBAR_THUMB)


func _get_max_perk_scroll() -> float:
	return max(0.0, _last_perk_content_height - _last_perk_grid_rect.size.y)


func _get_skill_config(registry: Object, character_type: String) -> Object:
	var key := "smasher_skill_config"
	if _character_runtime != null and _character_runtime.has_method("get_skill_config_key"):
		key = str(_character_runtime.get_skill_config_key(character_type))
	elif character_type == "viper":
		key = "viper_skill_config"
	elif character_type == "soldier":
		key = "commando_skill_config"
	return _get_instance(registry, key)


func _get_smasher_dash_snapshot(registry: Object, character_type: String) -> Dictionary:
	if character_type != "smasher":
		return {}
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	return dash_state.get_snapshot() if dash_state != null and dash_state.has_method("get_snapshot") else {}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_character_type(owner: Object) -> String:
	var value: Variant = _safe_owner_get(owner, "selected_character_type", "smasher")
	if _character_runtime != null and _character_runtime.has_method("normalize"):
		return str(_character_runtime.normalize(value))
	var normalized := str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	return "smasher"


func _get_character_display_name(owner: Object, character_type: String) -> String:
	var raw_name := str(_safe_owner_get(owner, "selected_character_name", ""))
	if raw_name != "" and raw_name.find("?") < 0:
		return raw_name
	if character_type == "viper":
		return "바이퍼"
	if character_type == "soldier":
		return "코만도"
	return "스매셔"


func _character_type_label(character_type: String) -> String:
	if character_type == "viper":
		return "바이퍼"
	if character_type == "soldier":
		return "코만도"
	return "스매셔"


func _character_color(character_type: String) -> Color:
	if character_type == "viper":
		return Color(190.0 / 255.0, 80.0 / 255.0, 1.0)
	if character_type == "soldier":
		return Color(120.0 / 255.0, 180.0 / 255.0, 82.0 / 255.0)
	return Color(70.0 / 255.0, 190.0 / 255.0, 1.0)


func _skill_fallback_color(character_type: String) -> Color:
	if character_type == "viper":
		return Color(190.0 / 255.0, 80.0 / 255.0, 1.0)
	if character_type == "soldier":
		return Color(120.0 / 255.0, 180.0 / 255.0, 82.0 / 255.0)
	return ACCENT_BLUE


func _short_skill_name(data: Dictionary, skill_id: String) -> String:
	var name := str(data.get("korean", skill_id))
	return _trim_label(name, 7)


func _trim_label(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max(1, max_len - 1)) + "."


func _format_int_pair(current: int, maximum: int) -> String:
	return str(current) + " / " + str(maximum)


func _format_seconds_text(seconds: float) -> String:
	if is_equal_approx(seconds, round(seconds)):
		return "%d초" % int(round(seconds))
	return "%.1f초" % seconds


func _format_percent_text(percent: float) -> String:
	if is_equal_approx(percent, round(percent)):
		return "%d%%" % int(round(percent))
	return "%.1f%%" % percent


func _format_plain_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.1f" % value


func _perk_level_text(perk: Dictionary) -> String:
	if int(perk.get("max_level", 1)) == 1 and str(perk.get("character_restriction", "")) != "":
		return "해금"
	return "Lv.%d" % int(perk.get("level", 1))


func _perk_level_color(perk: Dictionary) -> Color:
	if int(perk.get("max_level", 1)) == 1 and str(perk.get("character_restriction", "")) != "":
		return Color(120.0 / 255.0, 1.0, 210.0 / 255.0)
	return ACCENT_GOLD


func _get_item_color(item_data: Dictionary, visuals: Object) -> Color:
	if visuals != null and visuals.has_method("get_item_color"):
		var value: Variant = visuals.get_item_color(item_data)
		if value is Color:
			return value
	var raw: Variant = item_data.get("color", Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0))
	if raw is Color:
		return raw
	return Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)


func _get_equipment_state(owner: Object) -> Dictionary:
	var direct: Dictionary = _get_dict(_safe_owner_get(owner, "equipment_slots", {}))
	if not direct.is_empty():
		return direct
	var passive_slots: Dictionary = _get_dict(_safe_owner_get(owner, "passive_item_slots", {}))
	if not passive_slots.is_empty():
		return passive_slots
	var equipped_passives: Dictionary = _get_dict(_safe_owner_get(owner, "equipped_passive_items", {}))
	if not equipped_passives.is_empty():
		return equipped_passives
	return {}


func _get_equipment_item(slot_state: Dictionary, slot_key: String) -> Dictionary:
	return _get_equipment_item_or_empty(slot_state, slot_key)


func _get_equipment_item_or_empty(slot_state: Dictionary, slot_key: String) -> Dictionary:
	var value: Variant = slot_state.get(slot_key, null)
	if value is Dictionary:
		return value
	if value is Array:
		var items: Array = value
		if not items.is_empty() and items[0] is Dictionary:
			return items[0]
	return _empty_equipment_item


func _is_equipment_slot_enabled(slot_key: String, owner: Object, accessory_slot_count: int = -1) -> bool:
	var slot_number: int = _equipment_slot_accessory_number(slot_key)
	if slot_number <= 0:
		return true
	if accessory_slot_count < 1:
		accessory_slot_count = _get_accessory_slot_count(owner)
	return slot_number <= accessory_slot_count


func _equipment_slot_accessory_number(slot_key: String) -> int:
	if not slot_key.begins_with("accessory"):
		return 0
	return int(slot_key.substr("accessory".length(), 1))


func _get_accessory_slot_count(owner: Object) -> int:
	var explicit_count: int = int(_safe_owner_get(owner, "accessory_slot_count", 0))
	if explicit_count > 0:
		return clamp(explicit_count, 1, 4)
	var runtime_bonus: int = int(_safe_owner_get(owner, "runtime_accessory_slot_bonus", 0))
	var levels: Dictionary = _get_dict(_safe_owner_get(owner, "runtime_perk_levels", {}))
	runtime_bonus = max(runtime_bonus, int(levels.get("common_expansion", 0)))
	return clamp(BASE_ACCESSORY_SLOT_COUNT + runtime_bonus, 1, 4)


func _get_stat_sources(registry: Object) -> Array:
	return [
		_get_instance(registry, "runtime_perk_state"),
		_get_instance(registry, "active_item_runtime"),
		_get_instance(registry, "mythic_item_runtime"),
		_get_instance(registry, "lingpet_egg_runtime"),
	]


func _apply_stat_chain(base_value: float, sources: Array, method_name: String) -> float:
	var current: float = base_value
	for source_value in sources:
		if not (source_value is Object):
			continue
		var source: Object = source_value
		if source == null or not source.has_method(method_name):
			continue
		var result: Variant = source.call(method_name, current)
		if result is int or result is float:
			current = float(result)
	return current


func _call_numeric_multiplier(source: Object, method_name: String) -> float:
	if source == null or not source.has_method(method_name):
		return 1.0
	var result: Variant = source.call(method_name)
	if result is int or result is float:
		return max(0.0, float(result))
	return 1.0


func _get_active_item_slot_capacity(registry: Object) -> int:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	return _get_active_item_slot_capacity_for_sources(runtime_perk_state, mythic_item_runtime)


func _get_active_item_slot_capacity_for_sources(runtime_perk_state: Object, mythic_item_runtime: Object) -> int:
	var capacity := BASE_ACTIVE_ITEM_SLOT_COUNT
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = int(runtime_perk_state.get_active_item_slot_capacity(capacity))
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		capacity = int(mythic_item_runtime.get_active_item_slot_capacity(capacity))
	return max(1, capacity)


func _get_active_item_slot_count(owner: Object, active_item_slots_override: Variant = null) -> int:
	if active_item_slots_override is Array:
		return (active_item_slots_override as Array).size()
	return _get_array(_safe_owner_get(owner, "active_item_slots", [])).size()


func _get_effective_active_item_cooldown_msec(item_data: Dictionary, registry: Object, stat_sources: Array = []) -> int:
	var base_cooldown_msec: int = max(0, int(_get_number_fallback(item_data, "cooldown_msec", "cooldown_ms")))
	return _get_effective_active_item_cooldown_from_base(base_cooldown_msec, registry, stat_sources)


func _get_effective_default_active_item_cooldown_msec(registry: Object, stat_sources: Array = []) -> int:
	return _get_effective_active_item_cooldown_from_base(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC, registry, stat_sources)


func _get_effective_active_item_cooldown_from_base(base_cooldown_msec: int, registry: Object, stat_sources: Array = []) -> int:
	var sources: Array = stat_sources if not stat_sources.is_empty() else _get_stat_sources(registry)
	return max(0, int(round(_apply_stat_chain(
		float(base_cooldown_msec),
		sources,
		"get_active_item_cooldown_msec"
	))))


func _equipment_color(base: String, has_item: bool, enabled: bool) -> Color:
	if not enabled:
		return EQUIPMENT_COLOR_DISABLED
	if has_item:
		return EQUIPMENT_COLOR_FILLED
	return _equipment_empty_color_for_base(base)


func _equipment_empty_color_for_base(base: String) -> Color:
	match base:
		"head":
			return EQUIPMENT_COLOR_HEAD
		"top":
			return EQUIPMENT_COLOR_TOP
		"arm":
			return EQUIPMENT_COLOR_ARM
		"belt":
			return EQUIPMENT_COLOR_BELT
		"back":
			return EQUIPMENT_COLOR_BACK
		"knee":
			return EQUIPMENT_COLOR_KNEE
		"shoes":
			return EQUIPMENT_COLOR_SHOES
		_:
			return EQUIPMENT_COLOR_ACCESSORY


func _equipment_item_display_name(item_data: Dictionary) -> String:
	var cache_hash: int = _equipment_item_display_name_hash(item_data)
	if _equipment_item_display_name_cache_ready and cache_hash == _equipment_item_display_name_cache_hash:
		return _equipment_item_display_name_cache
	var qualified_name: String = str(item_data.get("qualified_display_name", ""))
	if qualified_name != "":
		_equipment_item_display_name_cache_hash = cache_hash
		_equipment_item_display_name_cache_ready = true
		_equipment_item_display_name_cache = qualified_name
		return qualified_name
	var display_name: String = str(item_data.get("display_name", ""))
	if display_name == "":
		display_name = str(item_data.get("korean", ""))
	var result := "장비"
	if display_name != "":
		result = PassiveItemQuality.format_item_display_name(item_data)
	else:
		var item_name: String = str(item_data.get("name", ""))
		if item_name != "":
			result = PassiveItemQuality.format_item_display_name(item_data)
	_equipment_item_display_name_cache_hash = cache_hash
	_equipment_item_display_name_cache_ready = true
	_equipment_item_display_name_cache = result
	return result


func _get_item_quality_color(item_data: Dictionary, fallback: Color = Color.WHITE) -> Color:
	var cache_hash: int = _item_quality_color_hash(item_data, fallback)
	if _item_quality_color_cache_ready and cache_hash == _item_quality_color_cache_hash:
		return _item_quality_color_cache
	var result: Color = PassiveItemQuality.get_item_quality_color(item_data, fallback)
	_item_quality_color_cache_hash = cache_hash
	_item_quality_color_cache_ready = true
	_item_quality_color_cache = result
	return result


func _equipment_item_display_name_hash(item_data: Dictionary) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("display_name", ""),
		item_data.get("korean", ""),
		item_data.get("korean_name", ""),
		item_data.get("name_prefix", ""),
		item_data.get("qualified_display_name", ""),
	])


func _item_quality_color_hash(item_data: Dictionary, fallback: Color) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("type", ""),
		item_data.get("rarity", ""),
		item_data.get("quality_tier", ""),
		item_data.get("quality_color", ""),
		fallback,
	])


func _equipment_slot_label(label: String, key: String, cell_size: float) -> String:
	if cell_size >= 42.0:
		return label
	if key.begins_with("accessory"):
		return "장신%s" % key.substr("accessory".length(), 1)
	return _trim_label(label, 4)


func _get_string_fallback(data: Dictionary, key: String, fallback_key: String, default_value: String = "") -> String:
	var primary: Variant = data.get(key, null)
	if primary != null:
		var primary_text := str(primary)
		if primary_text != "":
			return primary_text
	var fallback: Variant = data.get(fallback_key, null)
	if fallback != null:
		var fallback_text := str(fallback)
		if fallback_text != "":
			return fallback_text
	return default_value


func _get_array_fallback(data: Dictionary, key: String, fallback_key: String) -> Array:
	if data.has(key):
		return _get_array(data.get(key))
	return _get_array(data.get(fallback_key, []))


func _get_tooltip_roll_entries(data: Dictionary) -> Array:
	if data.has("roll_options"):
		return _get_array(data.get("roll_options"))
	if data.has("options"):
		return _get_array(data.get("options"))
	return _empty_tooltip_roll_entries


func _get_number_fallback(data: Dictionary, key: String, fallback_key: String, default_value: float = 0.0) -> float:
	var primary: Variant = data.get(key, null)
	if primary != null:
		return float(primary)
	var fallback: Variant = data.get(fallback_key, null)
	if fallback != null:
		return float(fallback)
	return default_value


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE
