extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayTextLineCache := preload("res://scripts/hud/character_info_overlay_text_line_cache.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherDashSpiritState := preload("res://scripts/characters/smasher_dash_spirit_state.gd")


static func build_player_stat_rows(
	owner: Object,
	registry: Object,
	character_runtime: Object,
	runtime_state_override: Object = null,
	active_item_runtime_override: Object = null,
	mythic_item_runtime_override: Object = null,
	character_type_override: String = "",
	stat_sources_override: Array = [],
	active_item_slot_capacity_override: int = -1,
	active_item_slots_override: Variant = null,
	special_gauge_max: float = 500.0,
	player_base_paddle_width: float = 155.0,
	base_active_item_slot_count: int = 3,
	stat_buff_color: Color = Color.WHITE,
	stat_debuff_color: Color = Color.WHITE
) -> Array:
	var character_type: String = character_type_override if character_type_override != "" else CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var runtime_state: Object = runtime_state_override if runtime_state_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_state")
	var active_item_runtime: Object = active_item_runtime_override if active_item_runtime_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_runtime")
	var mythic_item_runtime: Object = mythic_item_runtime_override if mythic_item_runtime_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	var lingpet_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
	var stat_sources: Array = stat_sources_override if not stat_sources_override.is_empty() else [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]
	var smasher_recovery_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "smasher_recovery_state") if character_type == "smasher" else null
	var combo_key: String = character_runtime.get_combo_state_key(character_type) if character_runtime != null else ""
	var combo_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, combo_key) if combo_key != "" else null
	var base_max_gauge_value: float = special_gauge_max
	var base_move_speed_value: float = base_move_speed(character_type, character_runtime)
	var base_paddle_width_value: float = player_base_paddle_width
	var base_gauge_gain_value: float = BallUpdateStaticConfig.GAUGE_CHARGE_PER_HIT
	var base_dash_distance_value: float = SmasherDashState.DASH_BASE_DURATION_FRAMES * SmasherDashSpiritState.DASH_FRAME_SPEED * SmasherDashSpiritState.DASH_DISTANCE_SCALE
	var base_dash_recovery_seconds_value: float = frames_to_seconds(SmasherDashState.DASH_BASE_RECOVERY_FRAMES)
	var base_dash_cooldown_seconds_value: float = frames_to_seconds(SmasherDashState.DASH_BASE_RECHARGE_FRAMES)
	var base_item_cooldown_seconds_value: float = float(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC) / 1000.0
	var max_gauge: float = effective_max_gauge(max(1.0, float(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "special_gauge_max", special_gauge_max))), stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))
	var move_speed: float = effective_move_speed(character_type, character_runtime, runtime_state, smasher_recovery_state, active_item_runtime, mythic_item_runtime, lingpet_runtime, Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier"))
	var owner_width: float = float(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "player_paddle_width", 0.0))
	var runtime_scale_fallback: float = float(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_paddle_scale", 1.0))
	var paddle_width: float = effective_player_paddle_width(owner_width, runtime_scale_fallback, runtime_state, active_item_runtime, mythic_item_runtime, Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier"), player_base_paddle_width)
	var gauge_gain: float = effective_gauge_gain_per_hit(combo_state, stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))
	var dash_distance: float = effective_dash_distance(stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))
	var dash_recovery_seconds: float = frames_to_seconds(effective_dash_recovery_frames(stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain")))
	var dash_cooldown_seconds: float = frames_to_seconds(effective_dash_recharge_frames(stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain")))
	var item_cooldown_seconds: float = float(CharacterInfoOverlayOwnerState.active_item_cooldown_from_base(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC, stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))) / 1000.0
	var active_item_slot_capacity: int = active_item_slot_capacity_override if active_item_slot_capacity_override >= 1 else CharacterInfoOverlayOwnerState.active_item_slot_capacity(runtime_state, mythic_item_runtime, base_active_item_slot_count)
	var active_item_slot_count: int = CharacterInfoOverlayOwnerState.active_item_slot_count_from_owner(owner, active_item_slots_override)
	var active_item_slot_color: Color = stat_delta_color(float(base_active_item_slot_count), float(active_item_slot_capacity), true, stat_buff_color, stat_debuff_color)

	return [
		delta_stat_row("이동 속도", "%.2f" % move_speed, base_move_speed_value, move_speed, true, stat_buff_color, stat_debuff_color).merged({"icon": "speed", "tooltip_body": "패들이 좌우로 움직이는 속도입니다. 퍽·아이템·링펫 버프가 모두 반영된 최종 값이며, 높을수록 공을 따라잡기 쉽습니다."}),
		delta_stat_row("몸집 크기", "%.0fpx" % paddle_width, base_paddle_width_value, paddle_width, true, stat_buff_color, stat_debuff_color).merged({"icon": "size", "tooltip_body": "패들의 가로 길이입니다. 넓을수록 공을 받아내기 쉽습니다. 일부 아이템·보스 기술이 일시적으로 크기를 바꿉니다."}),
		delta_stat_row("게이지 획득량", "%dpt" % int(round(gauge_gain)), base_gauge_gain_value, gauge_gain, true, stat_buff_color, stat_debuff_color).merged({"icon": "gauge_gain", "tooltip_body": "공을 쳐낼 때마다 차오르는 스페셜 게이지의 1회 획득량입니다. 높을수록 스킬 게이지가 빨리 모입니다."}),
		delta_stat_row("최대 게이지", "%dpt" % int(round(max_gauge)), base_max_gauge_value, max_gauge, true, stat_buff_color, stat_debuff_color).merged({"icon": "gauge_max", "tooltip_body": "스페셜 게이지의 최대치입니다. 게이지가 가득 차면 강력한 스킬을 사용할 수 있습니다."}),
		delta_stat_row("대시 거리", "%dpx" % int(round(dash_distance)), base_dash_distance_value, dash_distance, true, stat_buff_color, stat_debuff_color).merged({"icon": "dash_range", "tooltip_body": "대시 한 번으로 이동하는 거리입니다. 길수록 먼 공도 한 번에 따라갈 수 있습니다."}),
		delta_stat_row("대시 후딜 시간", "%.2f초" % dash_recovery_seconds, base_dash_recovery_seconds_value, dash_recovery_seconds, false, stat_buff_color, stat_debuff_color).merged({"icon": "delay", "tooltip_body": "대시가 끝난 뒤 다음 행동까지 굳는 시간입니다. 짧을수록 연속 대응이 빨라집니다."}),
		delta_stat_row("대시 재충전", "%.2f초" % dash_cooldown_seconds, base_dash_cooldown_seconds_value, dash_cooldown_seconds, false, stat_buff_color, stat_debuff_color).merged({"icon": "recharge", "tooltip_body": "소모한 대시 토큰 1개가 다시 차오르는 데 걸리는 시간입니다. 짧을수록 대시를 자주 쓸 수 있습니다."}),
		delta_stat_row("아이템 재충전", "%.2f초" % item_cooldown_seconds, base_item_cooldown_seconds_value, item_cooldown_seconds, false, stat_buff_color, stat_debuff_color).merged({"icon": "recharge", "tooltip_body": "액티브 아이템을 사용한 뒤 다시 쓸 수 있을 때까지의 대기 시간입니다. 짧을수록 좋습니다."}),
		simple_stat_row("액티브 아이템 슬롯", CharacterInfoOverlayFormatter.format_int_pair(active_item_slot_count, active_item_slot_capacity), active_item_slot_color).merged({"icon": "slots", "tooltip_body": "장착 중인 액티브 아이템 수와 최대 슬롯 수입니다. 일부 신화 아이템이 슬롯을 늘려 줍니다."}),
	]


static func simple_stat_row(label: String, value_text: String, color: Color) -> Dictionary:
	return {
		"label": LanguageSettings.translate_text(label),
		"value": LanguageSettings.translate_text(value_text),
		"color": color,
	}


static func delta_stat_row(label: String, value_text: String, base_value: float, current_value: float, higher_is_better: bool, buff_color: Color, debuff_color: Color) -> Dictionary:
	var row: Dictionary = simple_stat_row(label, value_text, stat_delta_color(base_value, current_value, higher_is_better, buff_color, debuff_color))
	row["base"] = base_value
	row["current"] = current_value
	row["higher_is_better"] = higher_is_better
	return row


static func stat_delta_color(base_value: float, current_value: float, higher_is_better: bool, buff_color: Color, debuff_color: Color) -> Color:
	var delta: float = current_value - base_value
	if abs(delta) <= 0.001:
		return Color.WHITE
	var improved: bool = delta > 0.0 if higher_is_better else delta < 0.0
	return buff_color if improved else debuff_color


static func draw_cached_player_stat_rows(
	canvas: CanvasItem,
	font: Font,
	title: String,
	rect: Rect2,
	row_count: int,
	label_cache: Array,
	value_cache: Array,
	color_cache: Array,
	value_width_cache: Array,
	value_width_text_cache: Array,
	value_width_size_cache: Array,
	value_width_font_id_cache: Array,
	accent_blue: Color,
	text_dim: Color,
	empty_text_color: Color,
	ui_text_scale: float,
	mouse_pos: Vector2 = Vector2.INF,
	hover_data: Dictionary = {},
	hover_row_rects: Array = []
) -> Dictionary:
	canvas.draw_rect(rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.34))
	_draw_text_xy(canvas, font, title, rect.position.x + 2.0, rect.position.y + 20.0, 12, accent_blue, ui_text_scale)
	if row_count <= 0:
		_draw_text_centered_xy(canvas, font, "표시할 능력치 없음", rect.get_center().x, rect.get_center().y + 4.0, 12, empty_text_color, ui_text_scale)
		return hover_data
	var start_y: float = rect.position.y + 46.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(26.0, available_h / float(max(1, row_count)))
	var row_size: int = 11 if line_gap < 18.0 else 12 if line_gap < 20.0 else 13
	line_gap = max(16.0, line_gap)
	var label_x: float = rect.position.x + 2.0
	var value_right_x: float = rect.end.x - 2.0
	for i in range(row_count):
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		var row_rect := Rect2(rect.position.x, baseline_y - float(row_size) - 5.0, rect.size.x, line_gap)
		hover_row_rects.append(row_rect)
		var label_draw_x: float = label_x
		if i < _player_stat_icon_cache.size() and _player_stat_icon_cache[i] != "":
			CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(label_x + 6.0, baseline_y - float(row_size) * 0.38), 11.0, _player_stat_icon_cache[i], Color(text_dim.r, text_dim.g, text_dim.b, 0.85))
			label_draw_x += 19.0
		_draw_text_xy(canvas, font, str(label_cache[i]), label_draw_x, baseline_y, row_size, text_dim, ui_text_scale)
		var value_text: String = str(value_cache[i])
		var value_color: Color = color_cache[i] if color_cache[i] is Color else Color.WHITE
		var value_width: float = _get_cached_value_width(font, i, value_text, row_size, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache, ui_text_scale)
		_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color, ui_text_scale)
		if i < _player_stat_tooltip_cache.size() and _player_stat_tooltip_cache[i] != "" and row_rect.has_point(mouse_pos):
			_fill_hover_data(hover_data, str(label_cache[i]), value_text, _player_stat_tooltip_cache[i], value_color, row_rect)
	return hover_data


static func draw_lingpet_stat_rows(
	canvas: CanvasItem,
	font: Font,
	title: String,
	rows: Array,
	rect: Rect2,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	row_rects: Array,
	accent_blue: Color,
	text_dim: Color,
	empty_text_color: Color,
	ui_text_scale: float
) -> Dictionary:
	canvas.draw_rect(rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.34))
	_draw_text_xy(canvas, font, title, rect.position.x + 2.0, rect.position.y + 20.0, 12, accent_blue, ui_text_scale)
	row_rects.clear()
	var row_count: int = rows.size()
	if row_count <= 0:
		_draw_text_centered_xy(canvas, font, "표시할 능력치 없음", rect.get_center().x, rect.get_center().y + 4.0, 12, empty_text_color, ui_text_scale)
		return hover_data
	var start_y: float = rect.position.y + 46.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(26.0, available_h / float(max(1, row_count)))
	var row_size: int = 11 if line_gap < 18.0 else 12 if line_gap < 20.0 else 13
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
		row_rects.append(row_rect)
		var label: String = str(row.get("label", ""))
		var value_text: String = str(row.get("value", ""))
		var value_color: Color = _get_color(row.get("color", Color.WHITE), Color.WHITE)
		var icon_kind: String = str(row.get("icon", ""))
		var label_draw_x: float = label_x
		if icon_kind != "":
			CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(label_x + 6.0, baseline_y - float(row_size) * 0.38), 11.0, icon_kind, Color(text_dim.r, text_dim.g, text_dim.b, 0.85))
			label_draw_x += 19.0
		_draw_text_xy(canvas, font, label, label_draw_x, baseline_y, row_size, text_dim, ui_text_scale)
		var value_width: float = _text_size(font, value_text, row_size, ui_text_scale).x
		_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color, ui_text_scale)
		var tooltip_body: String = str(row.get("tooltip_body", ""))
		if tooltip_body != "" and row_rect.has_point(mouse_pos):
			_fill_hover_data(hover_data, str(row.get("tooltip_title", label)), str(row.get("tooltip_subtitle", value_text)), tooltip_body, value_color, row_rect)
	return hover_data


static func lingpet_stat_rows_visible_capacity(rect: Rect2, row_count: int) -> int:
	if row_count <= 0:
		return 0
	var start_y: float = rect.position.y + 46.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(26.0, available_h / float(max(1, row_count)))
	line_gap = max(16.0, line_gap)
	var visible_count := 0
	for i in range(row_count):
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		visible_count += 1
	return visible_count


static func lingpet_stat_rect_for_sections(rect: Rect2) -> Rect2:
	var inner_rect := Rect2(rect.position.x + 12.0, rect.position.y + 38.0, rect.size.x - 24.0, rect.size.y - 50.0)
	var column_gap := 18.0
	if inner_rect.size.x >= 620.0:
		var column_w: float = (inner_rect.size.x - column_gap) * 0.5
		var player_rect := Rect2(inner_rect.position, Vector2(column_w, inner_rect.size.y))
		return Rect2(player_rect.end.x + column_gap, inner_rect.position.y, column_w, inner_rect.size.y)
	var row_gap := 10.0
	var row_h: float = (inner_rect.size.y - row_gap) * 0.5
	var stacked_player_rect := Rect2(inner_rect.position, Vector2(inner_rect.size.x, row_h))
	return Rect2(inner_rect.position.x, stacked_player_rect.end.y + row_gap, inner_rect.size.x, row_h)


static func draw_stat_sections(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	player_row_count: int,
	label_cache: Array,
	value_cache: Array,
	color_cache: Array,
	value_width_cache: Array,
	value_width_text_cache: Array,
	value_width_size_cache: Array,
	value_width_font_id_cache: Array,
	lingpet_rows: Array,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	lingpet_row_rects: Array,
	accent_blue: Color,
	text_dim: Color,
	empty_text_color: Color,
	ui_text_scale: float
) -> Dictionary:
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
	# Lingpet rows draw first: their drawer clears the shared hover-rect list,
	# then the player rows append into it so mouse-motion redraw gating covers
	# both stat columns.
	hover_data = draw_lingpet_stat_rows(canvas, font, "링펫 능력치", lingpet_rows, lingpet_rect, mouse_pos, hover_data, lingpet_row_rects, accent_blue, text_dim, empty_text_color, ui_text_scale)
	return draw_cached_player_stat_rows(canvas, font, "플레이어 능력치", player_rect, player_row_count, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache, accent_blue, text_dim, empty_text_color, ui_text_scale, mouse_pos, hover_data, lingpet_row_rects)


static func build_overlay_player_stat_rows(
	target: Object,
	owner: Object,
	registry: Object,
	character_runtime: Object,
	runtime_state_override: Object,
	active_item_runtime_override: Object,
	mythic_item_runtime_override: Object,
	character_type_override: String,
	stat_sources_override: Array,
	write_row_cache: bool,
	active_item_slot_capacity_override: int,
	active_item_slots_override: Variant,
	row_count: int,
	row_cache: Array,
	label_cache: Array[String],
	value_cache: Array[String],
	color_cache: Array[Color],
	value_width_cache: Array[float],
	value_width_text_cache: Array[String],
	value_width_size_cache: Array[int],
	value_width_font_id_cache: Array[int],
	special_gauge_max: float,
	player_base_paddle_width: float,
	base_active_item_slot_count: int,
	stat_buff_color: Color,
	stat_debuff_color: Color
) -> Array:
	var rows: Array = build_player_stat_rows(owner, registry, character_runtime, runtime_state_override, active_item_runtime_override, mythic_item_runtime_override, character_type_override, stat_sources_override, active_item_slot_capacity_override, active_item_slots_override, special_gauge_max, player_base_paddle_width, base_active_item_slot_count, stat_buff_color, stat_debuff_color)
	refresh_player_stat_cache(rows, row_count, write_row_cache, row_cache, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache)
	target.set("_stats_row_count", row_count)
	return row_cache


# Row icon kinds, refreshed alongside the label/value caches (single-instance
# overlay, so a presenter-level static avoids threading a new cache array
# through four call signatures).
static var _player_stat_icon_cache: Array[String] = []
static var _player_stat_tooltip_cache: Array[String] = []


static func refresh_player_stat_cache(
	rows: Array,
	row_count: int,
	write_row_cache: bool,
	row_cache: Array,
	label_cache: Array[String],
	value_cache: Array[String],
	color_cache: Array[Color],
	value_width_cache: Array[float],
	value_width_text_cache: Array[String],
	value_width_size_cache: Array[int],
	value_width_font_id_cache: Array[int]
) -> void:
	while row_cache.size() < row_count:
		CharacterInfoOverlayValueUtils.append_empty_stats_row(row_cache, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache)
	if row_cache.size() > row_count:
		CharacterInfoOverlayValueUtils.resize_arrays([row_cache, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache], row_count)
	if _player_stat_icon_cache.size() != row_count:
		_player_stat_icon_cache.resize(row_count)
	if _player_stat_tooltip_cache.size() != row_count:
		_player_stat_tooltip_cache.resize(row_count)
	for i in range(min(row_count, rows.size())):
		var row_data: Dictionary = CharacterInfoOverlayValueUtils.get_dict(rows[i])
		_player_stat_icon_cache[i] = str(row_data.get("icon", ""))
		_player_stat_tooltip_cache[i] = LanguageSettings.translate_text(str(row_data.get("tooltip_body", "")))
		var label: String = str(row_data.get("label", ""))
		var value_text: String = str(row_data.get("value", ""))
		var color: Color = CharacterInfoOverlayValueUtils.get_color(row_data.get("color", Color.WHITE))
		if write_row_cache:
			var row: Dictionary = row_cache[i]
			row["label"] = label
			row["value"] = value_text
			row["color"] = color
			if row_data.has("base"):
				row["base"] = float(row_data.get("base", 0.0))
				row["current"] = float(row_data.get("current", 0.0))
				row["higher_is_better"] = bool(row_data.get("higher_is_better", true))
			else:
				row.erase("base")
				row.erase("current")
				row.erase("higher_is_better")
		label_cache[i] = label
		value_cache[i] = value_text
		color_cache[i] = color


static func _get_cached_value_width(font: Font, index: int, value_text: String, size: int, value_width_cache: Array, value_width_text_cache: Array, value_width_size_cache: Array, value_width_font_id_cache: Array, ui_text_scale: float) -> float:
	if font == null or value_text == "":
		return 0.0
	var font_id: int = font.get_instance_id()
	if index < value_width_cache.size() and value_width_text_cache[index] == value_text and int(value_width_size_cache[index]) == size and int(value_width_font_id_cache[index]) == font_id:
		return float(value_width_cache[index])
	var width := _text_size(font, value_text, size, ui_text_scale).x
	if index < value_width_cache.size():
		value_width_cache[index] = width
		value_width_text_cache[index] = value_text
		value_width_size_cache[index] = size
		value_width_font_id_cache[index] = font_id
	return width


static func _fill_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, anchor_rect: Rect2) -> void:
	data.clear()
	data["title"] = title
	data["subtitle"] = subtitle
	data["body"] = body
	data["color"] = color
	data["anchor_rect"] = anchor_rect


static func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


static func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "":
		return
	# draw_string과 픽셀 동일한 셰이핑 캐시 경로 (Font 내부 64-LRU 순환 축출 회피).
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(baseline_x, baseline_y), LanguageSettings.translate_text(text), _ui_font_size(size, ui_text_scale), color)


static func _draw_text_centered_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "" or font == null:
		return
	var visible_text := LanguageSettings.translate_text(text)
	var text_size: Vector2 = _text_size(font, visible_text, size, ui_text_scale)
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34), visible_text, _ui_font_size(size, ui_text_scale), color)


static func _text_size(font: Font, text: String, size: int, ui_text_scale: float) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	# get_string_size와 동일 값. 매 프레임 그려지는 행 텍스트라 셰이핑 캐시를 공유한다.
	return CharacterInfoOverlayTextLineCache.get_string_size_cached(font, text, _ui_font_size(size, ui_text_scale))


static func _ui_font_size(size: int, ui_text_scale: float) -> int:
	return max(1, int(round(float(size) * ui_text_scale)))


static func effective_max_gauge(base_gauge: float, stat_sources: Array, apply_stat_chain: Callable) -> float:
	return max(1.0, float(apply_stat_chain.call(base_gauge, stat_sources, "get_special_gauge_max")))


static func effective_move_speed(
	character_type: String,
	character_runtime: Object,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	lingpet_runtime: Object,
	call_numeric_multiplier: Callable
) -> float:
	return base_move_speed(character_type, character_runtime) * effective_move_speed_multiplier(
		character_type,
		runtime_state,
		smasher_recovery_state,
		active_item_runtime,
		mythic_item_runtime,
		lingpet_runtime,
		call_numeric_multiplier
	)


static func base_move_speed(character_type: String, character_runtime: Object) -> float:
	var config: Dictionary = character_runtime.get_base_movement_config(character_type) if character_runtime != null else {}
	return max(
		float(config.get("paddle_speed", 0.0)),
		float(config.get("paddle_max_speed", 0.0))
	)


static func effective_move_speed_multiplier(
	character_type: String,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	lingpet_runtime: Object,
	call_numeric_multiplier: Callable
) -> float:
	var multiplier: float = 1.0
	multiplier *= float(call_numeric_multiplier.call(runtime_state, "get_player_speed_multiplier"))
	if character_type == "smasher":
		multiplier *= float(call_numeric_multiplier.call(smasher_recovery_state, "get_player_speed_multiplier"))
	multiplier *= float(call_numeric_multiplier.call(active_item_runtime, "get_player_speed_multiplier"))
	multiplier *= float(call_numeric_multiplier.call(mythic_item_runtime, "get_player_speed_multiplier"))
	multiplier *= float(call_numeric_multiplier.call(lingpet_runtime, "get_player_speed_multiplier"))
	return max(0.0, multiplier)


static func effective_player_paddle_width(
	owner_width: float,
	runtime_scale_fallback: float,
	runtime_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	call_numeric_multiplier: Callable,
	base_paddle_width: float
) -> float:
	var runtime_scale: float = runtime_paddle_scale(runtime_scale_fallback, runtime_state)
	var mythic_item_scale: float = float(call_numeric_multiplier.call(mythic_item_runtime, "get_player_paddle_scale"))
	var base_width: float = base_paddle_width * runtime_scale * mythic_item_scale
	var active_item_scale: float = float(call_numeric_multiplier.call(active_item_runtime, "get_player_paddle_scale"))
	var calculated_width: float = base_width
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_width"):
		calculated_width = max(1.0, float(active_item_runtime.get_player_paddle_width(base_width)))
	if abs(runtime_scale - 1.0) > 0.001 or abs(mythic_item_scale - 1.0) > 0.001 or abs(active_item_scale - 1.0) > 0.001:
		return calculated_width
	return max(1.0, owner_width if owner_width > 0.0 else calculated_width)


static func runtime_paddle_scale(runtime_scale_fallback: float, runtime_state: Object) -> float:
	if runtime_state != null and runtime_state.has_method("get_player_paddle_size_multiplier"):
		return max(0.1, float(runtime_state.get_player_paddle_size_multiplier()))
	return max(0.1, runtime_scale_fallback)


static func effective_gauge_gain_per_hit(combo_state: Object, stat_sources: Array, apply_stat_chain: Callable) -> float:
	var gauge_gain: float = BallUpdateStaticConfig.GAUGE_CHARGE_PER_HIT
	if combo_state != null and combo_state.has_method("get_gauge_gain"):
		gauge_gain = float(combo_state.get_gauge_gain(gauge_gain))
	return max(0.0, float(apply_stat_chain.call(gauge_gain, stat_sources, "get_gauge_gain_per_hit")))


static func effective_dash_distance(stat_sources: Array, apply_stat_chain: Callable) -> float:
	var duration_frames: float = effective_dash_duration_frames(stat_sources, apply_stat_chain)
	return max(1.0, duration_frames * SmasherDashSpiritState.DASH_FRAME_SPEED * SmasherDashSpiritState.DASH_DISTANCE_SCALE)


static func effective_dash_duration_frames(stat_sources: Array, apply_stat_chain: Callable) -> float:
	return max(1.0, float(apply_stat_chain.call(
		SmasherDashState.DASH_BASE_DURATION_FRAMES,
		stat_sources,
		"get_dash_duration_frames"
	)))


static func effective_dash_recovery_frames(stat_sources: Array, apply_stat_chain: Callable) -> float:
	return max(1.0, float(apply_stat_chain.call(
		SmasherDashState.DASH_BASE_RECOVERY_FRAMES,
		stat_sources,
		"get_dash_recovery_frames"
	)))


static func effective_dash_recharge_frames(stat_sources: Array, apply_stat_chain: Callable) -> float:
	return max(1.0, float(apply_stat_chain.call(
		SmasherDashState.DASH_BASE_RECHARGE_FRAMES,
		stat_sources,
		"get_dash_recharge_frames"
	)))


static func frames_to_seconds(frames: float) -> float:
	return CharacterInfoOverlayFormatter.frames_to_seconds(frames)
