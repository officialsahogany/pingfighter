extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemHudSlotIconRenderer := preload("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")

const SPECIAL_GAUGE_MAX := 500.0
const PANEL_COLOR := Color(18.0 / 255.0, 22.0 / 255.0, 38.0 / 255.0, 0.96)
const PANEL_BORDER := Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 0.86)
const SECTION_COLOR := Color(24.0 / 255.0, 30.0 / 255.0, 50.0 / 255.0, 0.92)
const SECTION_BORDER := Color(78.0 / 255.0, 112.0 / 255.0, 165.0 / 255.0, 0.76)
const TEXT_DIM := Color(178.0 / 255.0, 188.0 / 255.0, 210.0 / 255.0)
const TEXT_SOFT := Color(210.0 / 255.0, 220.0 / 255.0, 235.0 / 255.0)
const ACCENT_BLUE := Color(0.0, 205.0 / 255.0, 1.0)
const ACCENT_GOLD := Color(1.0, 215.0 / 255.0, 85.0 / 255.0)
const BASE_ACCESSORY_SLOT_COUNT := 2
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
var _last_perk_grid_rect := Rect2()
var _last_perk_content_height := 0.0
var _active_item_catalog: Object = ActiveItemCatalog.new()
var _active_item_icon_renderer: Object = ActiveItemHudSlotIconRenderer.new()


func is_active() -> bool:
	return active


func open() -> void:
	active = true
	animation_time = 0.0
	perk_scroll = 0.0


func close() -> void:
	active = false


func toggle() -> void:
	if active:
		close()
	else:
		open()


func update(delta: float) -> void:
	if not active:
		return
	animation_time += delta


func handle_input(event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
	if not active:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
			close()
			return true
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
			close()
			return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and _last_perk_grid_rect.has_point(mouse_event.position):
			var max_scroll: float = _get_max_perk_scroll()
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				perk_scroll = clamp(perk_scroll - 48.0, 0.0, max_scroll)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				perk_scroll = clamp(perk_scroll + 48.0, 0.0, max_scroll)
		return true
	return true


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var alpha: float = clamp(animation_time / 0.14, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.58 * alpha))

	var panel_size := Vector2(
		min(940.0, max(360.0, view_size.x - 48.0)),
		min(700.0, max(420.0, view_size.y - 48.0))
	)
	var panel_rect := Rect2((view_size - panel_size) * 0.5, panel_size)
	var grow_offset: float = 10.0 * (1.0 - alpha)
	panel_rect = panel_rect.grow(-grow_offset)

	_draw_panel(canvas, panel_rect, PANEL_COLOR, PANEL_BORDER, 3.0)
	_draw_header(canvas, owner, panel_rect, font, registry)

	var inner_margin := 22.0
	var content_top := panel_rect.position.y + 74.0
	var content_bottom := panel_rect.end.y - 22.0
	var content_height: float = max(300.0, content_bottom - content_top)
	var column_gap := 18.0
	var left_w: float = min(360.0, (panel_rect.size.x - inner_margin * 2.0 - column_gap) * 0.43)
	var right_w: float = panel_rect.size.x - inner_margin * 2.0 - column_gap - left_w
	var left_rect := Rect2(Vector2(panel_rect.position.x + inner_margin, content_top), Vector2(left_w, content_height))
	var right_rect := Rect2(Vector2(left_rect.end.x + column_gap, content_top), Vector2(right_w, content_height))

	var mouse_pos := Vector2.ZERO
	if canvas.has_method("get_viewport") and canvas.get_viewport() != null:
		mouse_pos = canvas.get_viewport().get_mouse_position()

	var hover_data: Dictionary = {}
	hover_data = _draw_equipment_slots(canvas, owner, registry, _section_rect(left_rect, 0.0, 0.48), font, mouse_pos, hover_data)
	hover_data = _draw_skill_slots(canvas, owner, registry, _section_rect(left_rect, 0.50, 0.24), font, mouse_pos, hover_data)
	hover_data = _draw_active_items(canvas, owner, registry, _section_rect(left_rect, 0.76, 0.24), font, mouse_pos, hover_data)

	var perk_rect := _section_rect(right_rect, 0.0, 0.52)
	var stats_rect := _section_rect(right_rect, 0.56, 0.44)
	hover_data = _draw_perk_grid(canvas, owner, registry, perk_rect, font, mouse_pos, hover_data)
	_draw_stats_panel(canvas, owner, registry, stats_rect, font)

	if not hover_data.is_empty():
		_draw_tooltip(canvas, hover_data, mouse_pos, view_size, font)


func _section_rect(column_rect: Rect2, start_ratio: float, height_ratio: float) -> Rect2:
	var gap := 12.0
	var y: float = column_rect.position.y + column_rect.size.y * start_ratio
	var height: float = column_rect.size.y * height_ratio - gap
	return Rect2(Vector2(column_rect.position.x, y), Vector2(column_rect.size.x, max(64.0, height)))


func _draw_header(canvas: CanvasItem, owner: Object, panel_rect: Rect2, font: Font, registry: Object) -> void:
	var title_pos := panel_rect.position + Vector2(26.0, 42.0)
	_draw_text(canvas, font, "캐릭터 정보", title_pos, 28, Color.WHITE)
	var character_type: String = _get_character_type(owner)
	var display_name: String = _get_character_display_name(owner, character_type)
	var subtitle := "%s  /  %s" % [display_name, character_type.to_upper()]
	_draw_text(canvas, font, subtitle, title_pos + Vector2(0.0, 24.0), 14, TEXT_DIM)

	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	var snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var pending: int = int(snapshot.get("pending_skill_choices", _safe_owner_get(owner, "runtime_perk_pending_choices", 0)))
	var gold: int = int(snapshot.get("gold_from_perks", _safe_owner_get(owner, "runtime_perk_gold", 0)))
	var status := "Star choices %d   Gold %d" % [pending, gold]
	var status_size: Vector2 = font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14)
	_draw_text(canvas, font, status, Vector2(panel_rect.end.x - status_size.x - 26.0, title_pos.y + 16.0), 14, ACCENT_GOLD)


func _draw_character_card(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font) -> void:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text(canvas, font, "STATUS", rect.position + Vector2(14.0, 26.0), 14, ACCENT_BLUE)

	var character_type: String = _get_character_type(owner)
	var character_color: Color = _character_color(character_type)
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.34)
	var radius: float = min(rect.size.x, rect.size.y) * 0.18
	for glow in range(4, 0, -1):
		canvas.draw_circle(center, radius + float(glow) * 5.0, Color(character_color.r, character_color.g, character_color.b, 0.035 * float(glow)))
	canvas.draw_circle(center, radius, Color(character_color.r, character_color.g, character_color.b, 0.22))
	canvas.draw_arc(center, radius, -PI * 0.15, TAU - PI * 0.15, 56, character_color, 3.0)
	canvas.draw_rect(Rect2(center - Vector2(radius * 0.52, radius * 0.22), Vector2(radius * 1.04, radius * 0.44)), Color(character_color.r, character_color.g, character_color.b, 0.82))
	canvas.draw_line(center + Vector2(-radius * 0.62, radius * 0.40), center + Vector2(radius * 0.62, radius * 0.40), Color.WHITE, 2.0)

	var name := _get_character_display_name(owner, character_type)
	_draw_text_centered(canvas, font, name, Vector2(rect.get_center().x, center.y + radius + 40.0), 20, Color.WHITE)
	var stage := int(_safe_owner_get(owner, "current_stage", 1))
	_draw_text_centered(canvas, font, "Stage %d" % stage, Vector2(rect.get_center().x, center.y + radius + 62.0), 13, TEXT_DIM)

	var gauge: float = float(_safe_owner_get(owner, "special_gauge", 0.0))
	var bar_rect := Rect2(Vector2(rect.position.x + 22.0, rect.end.y - 64.0), Vector2(rect.size.x - 44.0, 12.0))
	_draw_meter(canvas, bar_rect, gauge / SPECIAL_GAUGE_MAX, Color(70.0 / 255.0, 160.0 / 255.0, 1.0), "게이지 %d / %d" % [int(gauge), int(SPECIAL_GAUGE_MAX)], font)

	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	var dash_snapshot: Dictionary = dash_state.get_snapshot() if dash_state != null and dash_state.has_method("get_snapshot") else {}
	var tokens: int = int(dash_snapshot.get("tokens", 0))
	var max_tokens: int = max(1, int(dash_snapshot.get("max_tokens", 1)))
	var token_text := "대시 토큰 %d / %d" % [tokens, max_tokens]
	_draw_text(canvas, font, token_text, rect.position + Vector2(22.0, rect.end.y - 22.0 - rect.position.y), 13, TEXT_SOFT)


func _draw_equipment_slots(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text(canvas, font, "장비 슬롯", rect.position + Vector2(12.0, 24.0), 13, ACCENT_BLUE)

	var slot_state: Dictionary = _get_equipment_state(owner)
	var columns := 4
	var gap := 7.0
	var grid_rect := Rect2(rect.position + Vector2(12.0, 38.0), rect.size - Vector2(24.0, 48.0))
	var cell_w: float = floor((grid_rect.size.x - gap * float(columns - 1)) / float(columns))
	var cell_h: float = floor((grid_rect.size.y - gap * 2.0) / 3.0)
	var cell_size: float = max(40.0, min(cell_w, cell_h))
	var total_w: float = cell_size * float(columns) + gap * float(columns - 1)
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - total_w) * 0.5
	var start_y: float = grid_rect.position.y + max(0.0, (grid_rect.size.y - (cell_size * 3.0 + gap * 2.0)) * 0.5)

	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	for i in range(EQUIPMENT_SLOT_DEFINITIONS.size()):
		var definition: Dictionary = _get_dict(EQUIPMENT_SLOT_DEFINITIONS[i])
		var key: String = str(definition.get("key", ""))
		var label: String = str(definition.get("label", key))
		var base: String = str(definition.get("base", key))
		var row: int = int(i / columns)
		var col: int = i % columns
		var slot_rect := Rect2(Vector2(start_x + float(col) * (cell_size + gap), start_y + float(row) * (cell_size + gap)), Vector2(cell_size, cell_size))
		var enabled: bool = _is_equipment_slot_enabled(key, owner)
		var item_data: Dictionary = _get_equipment_item(slot_state, key)
		var has_item: bool = not item_data.is_empty()
		var base_color: Color = _equipment_color(base, has_item, enabled)
		var bg_alpha: float = 0.94 if enabled else 0.48
		canvas.draw_rect(slot_rect, Color(13.0 / 255.0, 17.0 / 255.0, 29.0 / 255.0, bg_alpha))
		canvas.draw_rect(slot_rect, Color(base_color.r, base_color.g, base_color.b, 0.82 if has_item else 0.55), false, 1.6 if enabled else 1.0)
		if has_item:
			if _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon"):
				_active_item_icon_renderer.draw_icon(canvas, slot_rect.grow(-5.0), item_data, 1.0, visuals)
			else:
				_draw_fallback_symbol(canvas, slot_rect.grow(-9.0), base_color, str(item_data.get("name", key)))
		else:
			_draw_equipment_placeholder(canvas, slot_rect.grow(-8.0), base, base_color, enabled)
		if not enabled:
			_draw_locked_slot(canvas, slot_rect, base_color)
		_draw_text_centered(canvas, font, label, Vector2(slot_rect.get_center().x, slot_rect.end.y - 4.0), 9, TEXT_SOFT if enabled else Color(120.0 / 255.0, 126.0 / 255.0, 142.0 / 255.0))
		if slot_rect.has_point(mouse_pos):
			if has_item:
				var display_name: String = _equipment_item_display_name(item_data)
				hover_data = {
					"title": display_name,
					"subtitle": label,
					"body": str(item_data.get("description", item_data.get("desc", ""))),
					"color": base_color,
				}
			else:
				hover_data = {
					"title": label,
					"subtitle": "미장착" if enabled else "잠김",
					"body": "패시브 장비가 연결되면 이 슬롯에 표시됩니다.",
					"color": base_color,
				}
	return hover_data


func _draw_skill_slots(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text(canvas, font, "ACTIVE SKILLS", rect.position + Vector2(12.0, 24.0), 13, ACCENT_BLUE)

	var character_type: String = _get_character_type(owner)
	var skill_config: Object = _get_skill_config(registry, character_type)
	var snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var equipped: Array = _get_array(snapshot.get("equipped_skills", []))
	var max_slots: int = max(1, int(snapshot.get("max_slots", 5)))
	var skill_data: Dictionary = _get_dict(snapshot.get("skill_data", {}))
	var icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")

	var slot_size: float = min(54.0, max(38.0, (rect.size.x - 24.0 - float(max_slots - 1) * 8.0) / float(max_slots)))
	var start_x: float = rect.position.x + (rect.size.x - (slot_size * float(max_slots) + 8.0 * float(max_slots - 1))) * 0.5
	var slot_y: float = rect.position.y + 42.0
	for i in range(max_slots):
		var slot_rect := Rect2(Vector2(start_x + float(i) * (slot_size + 8.0), slot_y), Vector2(slot_size, slot_size))
		canvas.draw_rect(slot_rect, Color(12.0 / 255.0, 17.0 / 255.0, 29.0 / 255.0, 0.96))
		canvas.draw_rect(slot_rect, Color(80.0 / 255.0, 100.0 / 255.0, 140.0 / 255.0, 0.72), false, 1.5)
		if i >= equipped.size():
			canvas.draw_circle(slot_rect.get_center(), slot_size * 0.22, Color(80.0 / 255.0, 90.0 / 255.0, 110.0 / 255.0, 0.35))
			continue
		var skill_id: String = str(equipped[i])
		var data: Dictionary = _get_dict(skill_data.get(skill_id, {}))
		var color: Color = _get_color(data.get("color", _skill_fallback_color(character_type)))
		canvas.draw_rect(slot_rect, Color(color.r, color.g, color.b, 0.12))
		canvas.draw_rect(slot_rect, Color(color.r, color.g, color.b, 0.72), false, 2.0)
		if icon_renderer == null or not icon_renderer.has_method("draw_icon") or not bool(icon_renderer.draw_icon(canvas, skill_id, slot_rect.grow(-5.0), 1.0, true)):
			_draw_fallback_symbol(canvas, slot_rect.grow(-9.0), color, skill_id)
		var label: String = _short_skill_name(data, skill_id)
		_draw_text_centered(canvas, font, label, Vector2(slot_rect.get_center().x, slot_rect.end.y + 15.0), 10, TEXT_DIM)
		if slot_rect.has_point(mouse_pos):
			hover_data = {
				"title": str(data.get("korean", skill_id)),
				"subtitle": "Cost %d  Cooldown %.0fs" % [int(float(data.get("cost", 0.0))), float(data.get("cooldown", 0.0))],
				"body": str(data.get("description", "")),
				"color": color,
			}
	return hover_data


func _draw_active_items(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text(canvas, font, "ACTIVE ITEMS", rect.position + Vector2(12.0, 24.0), 13, ACCENT_BLUE)

	var slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	var max_slots: int = 3
	var slot_size: float = min(62.0, max(44.0, (rect.size.x - 34.0) / 3.0))
	var gap: float = max(8.0, (rect.size.x - slot_size * float(max_slots)) / float(max_slots + 1))
	var y: float = rect.position.y + 44.0
	for i in range(max_slots):
		var slot_rect := Rect2(Vector2(rect.position.x + gap + float(i) * (slot_size + gap), y), Vector2(slot_size, slot_size))
		canvas.draw_rect(slot_rect, Color(12.0 / 255.0, 17.0 / 255.0, 29.0 / 255.0, 0.96))
		canvas.draw_rect(slot_rect, Color(80.0 / 255.0, 100.0 / 255.0, 140.0 / 255.0, 0.72), false, 1.5)
		if i >= slots.size() or not (slots[i] is Dictionary):
			_draw_text_centered(canvas, font, "-", slot_rect.get_center() + Vector2(0.0, 5.0), 20, Color(95.0 / 255.0, 100.0 / 255.0, 120.0 / 255.0))
			continue
		var item_data: Dictionary = slots[i]
		if _active_item_icon_renderer != null and _active_item_icon_renderer.has_method("draw_icon"):
			_active_item_icon_renderer.draw_icon(canvas, slot_rect, item_data, 1.0, visuals)
		else:
			_draw_fallback_symbol(canvas, slot_rect.grow(-10.0), _get_item_color(item_data, visuals), str(item_data.get("name", "")))
		var item_name: String = str(item_data.get("name", ""))
		var display_name: String = str(item_data.get("display_name", ""))
		if display_name == "" and _active_item_catalog != null and _active_item_catalog.has_method("get_display_name"):
			display_name = str(_active_item_catalog.get_display_name(item_name))
		if display_name == "":
			display_name = item_name
		_draw_text_centered(canvas, font, _trim_label(display_name, 10), Vector2(slot_rect.get_center().x, slot_rect.end.y + 16.0), 10, TEXT_DIM)
		if slot_rect.has_point(mouse_pos):
			hover_data = {
				"title": display_name,
				"subtitle": "Slot %d" % (i + 1),
				"body": "Cooldown %.1fs" % (float(item_data.get("cooldown_msec", 0)) / 1000.0),
				"color": _get_item_color(item_data, visuals),
			}
	return hover_data


func _draw_perk_grid(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	rect: Rect2,
	font: Font,
	mouse_pos: Vector2,
	hover_data: Dictionary
) -> Dictionary:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text(canvas, font, "PERKS", rect.position + Vector2(12.0, 24.0), 13, ACCENT_BLUE)

	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	var catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")
	var snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", _safe_owner_get(owner, "runtime_perk_levels", {})))
	var acquired: Array = _build_acquired_perks(levels, catalog)

	var grid_rect := Rect2(rect.position + Vector2(12.0, 36.0), rect.size - Vector2(24.0, 48.0))
	_last_perk_grid_rect = grid_rect
	canvas.draw_rect(grid_rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.55))
	if acquired.is_empty():
		_draw_text_centered(canvas, font, "획득한 퍽 없음", grid_rect.get_center() + Vector2(0.0, 4.0), 14, Color(125.0 / 255.0, 132.0 / 255.0, 150.0 / 255.0))
		_last_perk_content_height = grid_rect.size.y
		return hover_data

	var columns: int = max(3, int(floor((grid_rect.size.x + 8.0) / 58.0)))
	var cell_size: float = min(52.0, floor((grid_rect.size.x - float(columns - 1) * 8.0) / float(columns)))
	var gap := 8.0
	var rows: int = int(ceil(float(acquired.size()) / float(columns)))
	_last_perk_content_height = float(rows) * (cell_size + gap) - gap
	perk_scroll = clamp(perk_scroll, 0.0, _get_max_perk_scroll())
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - (cell_size * float(columns) + gap * float(columns - 1))) * 0.5
	var start_y: float = grid_rect.position.y - perk_scroll

	for i in range(acquired.size()):
		var row: int = int(i / columns)
		var col: int = i % columns
		var cell_rect := Rect2(Vector2(start_x + float(col) * (cell_size + gap), start_y + float(row) * (cell_size + gap)), Vector2(cell_size, cell_size))
		if cell_rect.end.y < grid_rect.position.y or cell_rect.position.y > grid_rect.end.y:
			continue
		var perk: Dictionary = acquired[i]
		var color: Color = _get_color(perk.get("icon_color", ACCENT_BLUE))
		var hovered: bool = cell_rect.has_point(mouse_pos) and grid_rect.has_point(mouse_pos)
		canvas.draw_rect(cell_rect, Color(20.0 / 255.0, 25.0 / 255.0, 38.0 / 255.0, 0.96))
		canvas.draw_rect(cell_rect, Color(color.r, color.g, color.b, 0.48 if not hovered else 0.92), false, 2.0 if hovered else 1.0)
		var icon_rect := Rect2(cell_rect.position + Vector2(5.0, 4.0), Vector2(cell_size - 10.0, cell_size - 17.0))
		if icon_renderer == null or not icon_renderer.has_method("draw_icon") or not bool(icon_renderer.draw_icon(canvas, str(perk.get("id", "")), icon_rect, 1.0, true)):
			_draw_fallback_symbol(canvas, icon_rect, color, str(perk.get("id", "")))
		var level_text: String = _perk_level_text(perk)
		_draw_text_centered(canvas, font, level_text, Vector2(cell_rect.get_center().x, cell_rect.end.y - 4.0), 9, _perk_level_color(perk))
		if hovered:
			hover_data = {
				"title": str(perk.get("name", perk.get("id", ""))),
				"subtitle": level_text,
				"body": str(perk.get("description", perk.get("detail", ""))),
				"color": color,
			}
	if _get_max_perk_scroll() > 0.0:
		_draw_scrollbar(canvas, grid_rect)
	return hover_data


func _draw_stats_panel(canvas: CanvasItem, owner: Object, registry: Object, rect: Rect2, font: Font) -> void:
	_draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER, 2.0)
	_draw_text(canvas, font, "능력치", rect.position + Vector2(12.0, 24.0), 13, ACCENT_BLUE)
	var stats: Array = _build_stats(owner, registry)
	var y: float = rect.position.y + 48.0
	var line_gap := 23.0
	for stat_value in stats:
		var stat: Dictionary = _get_dict(stat_value)
		if y > rect.end.y - 12.0:
			break
		_draw_text(canvas, font, str(stat.get("label", "")), Vector2(rect.position.x + 14.0, y), 13, TEXT_DIM)
		var value_text: String = str(stat.get("value", ""))
		var value_color: Color = _get_color(stat.get("color", Color.WHITE))
		var size: Vector2 = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
		_draw_text(canvas, font, value_text, Vector2(rect.end.x - size.x - 14.0, y), 13, value_color)
		y += line_gap


func _build_stats(owner: Object, registry: Object) -> Array:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	var dash_snapshot: Dictionary = dash_state.get_snapshot() if dash_state != null and dash_state.has_method("get_snapshot") else {}
	var skill_config: Object = _get_skill_config(registry, _get_character_type(owner))
	var skill_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var equipped: Array = _get_array(skill_snapshot.get("equipped_skills", []))
	var active_slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	var runtime_snapshot: Dictionary = runtime_state.get_snapshot() if runtime_state != null and runtime_state.has_method("get_snapshot") else {}
	var levels: Dictionary = _get_dict(runtime_snapshot.get("runtime_skill_levels", _safe_owner_get(owner, "runtime_perk_levels", {})))

	return [
		{"label": "게이지", "value": "%d / %d" % [int(float(_safe_owner_get(owner, "special_gauge", 0.0))), int(SPECIAL_GAUGE_MAX)], "color": ACCENT_BLUE},
		{"label": "패들 너비", "value": "%.0f" % float(_safe_owner_get(owner, "player_paddle_width", 0.0)), "color": Color.WHITE},
		{"label": "패들 높이", "value": "%.0f" % float(_safe_owner_get(owner, "player_paddle_height", 0.0)), "color": Color.WHITE},
		{"label": "이동 속도", "value": "%.1f" % float(_safe_owner_get(owner, "player_speed", 0.0)), "color": Color.WHITE},
		{"label": "대시 토큰", "value": "%d / %d" % [int(dash_snapshot.get("tokens", 0)), max(1, int(dash_snapshot.get("max_tokens", 1)))], "color": ACCENT_GOLD},
		{"label": "장착 스킬", "value": "%d / %d" % [equipped.size(), int(skill_snapshot.get("max_slots", 5))], "color": TEXT_SOFT},
		{"label": "액티브 아이템", "value": "%d / 3" % active_slots.size(), "color": TEXT_SOFT},
		{"label": "획득 퍽", "value": "%d" % levels.size(), "color": TEXT_SOFT},
		{"label": "퍽 골드", "value": "%d" % int(runtime_snapshot.get("gold_from_perks", _safe_owner_get(owner, "runtime_perk_gold", 0))), "color": ACCENT_GOLD},
	]


func _draw_tooltip(canvas: CanvasItem, data: Dictionary, mouse_pos: Vector2, view_size: Vector2, font: Font) -> void:
	var color: Color = _get_color(data.get("color", ACCENT_BLUE))
	var title: String = str(data.get("title", ""))
	var subtitle: String = str(data.get("subtitle", ""))
	var body: String = str(data.get("body", ""))
	var width: float = min(340.0, max(240.0, view_size.x - 40.0))
	var body_lines: Array = _wrap_text_to_width(font, body, 13, width - 28.0, 5)
	var height: float = 54.0 + float(body_lines.size()) * 18.0
	if subtitle != "":
		height += 18.0
	var pos: Vector2 = mouse_pos + Vector2(16.0, 14.0)
	if pos.x + width > view_size.x - 8.0:
		pos.x = mouse_pos.x - width - 14.0
	if pos.y + height > view_size.y - 8.0:
		pos.y = mouse_pos.y - height - 12.0
	pos.x = clamp(pos.x, 8.0, max(8.0, view_size.x - width - 8.0))
	pos.y = clamp(pos.y, 8.0, max(8.0, view_size.y - height - 8.0))
	var rect: Rect2 = Rect2(pos, Vector2(width, height))
	_draw_panel(canvas, rect, Color(12.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.97), color, 2.0)
	_draw_text(canvas, font, title, rect.position + Vector2(14.0, 24.0), 15, Color.WHITE)
	var y := rect.position.y + 44.0
	if subtitle != "":
		_draw_text(canvas, font, subtitle, Vector2(rect.position.x + 14.0, y), 12, Color(color.r, color.g, color.b, 0.95))
		y += 18.0
	for line in body_lines:
		_draw_text(canvas, font, str(line), Vector2(rect.position.x + 14.0, y), 13, TEXT_SOFT)
		y += 18.0


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, border_width)
	canvas.draw_line(rect.position + Vector2(12.0, 3.0), Vector2(rect.end.x - 12.0, rect.position.y + 3.0), Color(border.r, border.g, border.b, 0.35), 1.0)


func _draw_meter(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color, label: String, font: Font) -> void:
	canvas.draw_rect(rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
	var fill_rect := Rect2(rect.position, Vector2(rect.size.x * clamp(ratio, 0.0, 1.0), rect.size.y))
	canvas.draw_rect(fill_rect, Color(color.r, color.g, color.b, 0.82))
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.85), false, 1.0)
	_draw_text(canvas, font, label, rect.position + Vector2(0.0, -8.0), 12, TEXT_DIM)


func _draw_scrollbar(canvas: CanvasItem, grid_rect: Rect2) -> void:
	var track := Rect2(Vector2(grid_rect.end.x - 6.0, grid_rect.position.y + 4.0), Vector2(4.0, grid_rect.size.y - 8.0))
	canvas.draw_rect(track, Color(0.0, 0.0, 0.0, 0.35))
	var max_scroll: float = _get_max_perk_scroll()
	var thumb_h: float = max(22.0, track.size.y * (grid_rect.size.y / max(grid_rect.size.y, _last_perk_content_height)))
	var thumb_y: float = track.position.y + (track.size.y - thumb_h) * (perk_scroll / max_scroll)
	canvas.draw_rect(Rect2(Vector2(track.position.x, thumb_y), Vector2(track.size.x, thumb_h)), Color(120.0 / 255.0, 170.0 / 255.0, 1.0, 0.72))


func _draw_fallback_symbol(canvas: CanvasItem, rect: Rect2, color: Color, id_text: String) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.38
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, 32, color, 2.0)
	var letter := "?"
	if id_text.length() > 0:
		letter = id_text.substr(0, 1).to_upper()
	_draw_text_centered(canvas, ThemeDB.fallback_font, letter, center + Vector2(0.0, 3.0), int(radius * 1.2), Color.WHITE)


func _draw_equipment_placeholder(canvas: CanvasItem, rect: Rect2, base: String, color: Color, enabled: bool) -> void:
	var alpha: float = 0.42 if enabled else 0.20
	var center := rect.get_center()
	var stroke := Color(color.r, color.g, color.b, alpha)
	match base:
		"head":
			canvas.draw_arc(center + Vector2(0.0, 2.0), rect.size.x * 0.25, PI, TAU, 18, stroke, 1.6)
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
			canvas.draw_arc(center, rect.size.x * 0.22, -PI * 0.15, PI * 1.15, 18, stroke, 1.8)
			canvas.draw_line(center + Vector2(-rect.size.x * 0.22, rect.size.y * 0.08), center + Vector2(rect.size.x * 0.20, rect.size.y * 0.12), stroke, 1.6)
		"shoes":
			var sole := Rect2(center - Vector2(rect.size.x * 0.28, rect.size.y * 0.02), Vector2(rect.size.x * 0.56, rect.size.y * 0.14))
			canvas.draw_rect(sole, Color(color.r, color.g, color.b, alpha * 0.28))
			canvas.draw_rect(sole, stroke, false, 1.4)
			canvas.draw_line(sole.position + Vector2(rect.size.x * 0.10, 0.0), center + Vector2(-rect.size.x * 0.05, -rect.size.y * 0.18), stroke, 1.4)
		_:
			canvas.draw_circle(center, rect.size.x * 0.22, Color(color.r, color.g, color.b, alpha * 0.24))
			canvas.draw_arc(center, rect.size.x * 0.22, 0.0, TAU, 24, stroke, 1.5)


func _draw_locked_slot(canvas: CanvasItem, slot_rect: Rect2, color: Color) -> void:
	var line_color := Color(color.r, color.g, color.b, 0.32)
	canvas.draw_line(slot_rect.position + Vector2(9.0, 9.0), slot_rect.end - Vector2(9.0, 9.0), line_color, 1.4)
	canvas.draw_line(Vector2(slot_rect.end.x - 9.0, slot_rect.position.y + 9.0), Vector2(slot_rect.position.x + 9.0, slot_rect.end.y - 9.0), line_color, 1.4)


func _draw_text(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, size: int, color: Color) -> void:
	if text == "":
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color) -> void:
	if text == "":
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _build_acquired_perks(levels: Dictionary, catalog: Object) -> Array:
	var result: Array = []
	for skill_id_value in levels.keys():
		var skill_id: String = str(skill_id_value)
		var level: int = int(levels.get(skill_id_value, 0))
		if level <= 0:
			continue
		var data: Dictionary = {}
		if catalog != null and catalog.has_method("get_perk_data"):
			data = catalog.get_perk_data(skill_id)
		if data.is_empty():
			data = {"name": skill_id, "icon_color": ACCENT_BLUE, "tree": ""}
		data = data.duplicate(true)
		data["id"] = skill_id
		data["level"] = level
		if not data.has("description"):
			var descriptions: Dictionary = _get_dict(data.get("descriptions", {}))
			data["description"] = str(descriptions.get(level, data.get("detail", "")))
		result.append(data)
	result.sort_custom(Callable(self, "_sort_perks"))
	return result


func _sort_perks(a: Dictionary, b: Dictionary) -> bool:
	var a_level: int = int(a.get("level", 0))
	var b_level: int = int(b.get("level", 0))
	if a_level == b_level:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return a_level > b_level


func _wrap_text_to_width(font: Font, text: String, size: int, max_width: float, max_lines: int) -> Array:
	var lines: Array = []
	for paragraph in text.split("\n"):
		var words: PackedStringArray = paragraph.strip_edges().split(" ", false)
		var line := ""
		for word in words:
			var candidate := word if line == "" else "%s %s" % [line, word]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= max_width:
				line = candidate
			else:
				if line != "":
					lines.append(line)
				line = word
				if lines.size() >= max_lines:
					return lines
		if line != "":
			lines.append(line)
		if lines.size() >= max_lines:
			return lines.slice(0, max_lines)
	return lines.slice(0, max_lines)


func _get_max_perk_scroll() -> float:
	return max(0.0, _last_perk_content_height - _last_perk_grid_rect.size.y)


func _get_skill_config(registry: Object, character_type: String) -> Object:
	var key := "viper_skill_config" if character_type == "viper" else "smasher_skill_config"
	return _get_instance(registry, key)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_character_type(owner: Object) -> String:
	var value: Variant = _safe_owner_get(owner, "selected_character_type", "smasher")
	var normalized := str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	return "smasher"


func _get_character_display_name(owner: Object, character_type: String) -> String:
	var raw_name := str(_safe_owner_get(owner, "selected_character_name", ""))
	if raw_name != "" and raw_name.find("?") < 0:
		return raw_name
	if character_type == "viper":
		return "바이퍼"
	return "스매셔"


func _character_color(character_type: String) -> Color:
	if character_type == "viper":
		return Color(190.0 / 255.0, 80.0 / 255.0, 1.0)
	return Color(70.0 / 255.0, 190.0 / 255.0, 1.0)


func _skill_fallback_color(character_type: String) -> Color:
	if character_type == "viper":
		return Color(190.0 / 255.0, 80.0 / 255.0, 1.0)
	return ACCENT_BLUE


func _short_skill_name(data: Dictionary, skill_id: String) -> String:
	var name := str(data.get("korean", skill_id))
	return _trim_label(name, 7)


func _trim_label(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max(1, max_len - 1)) + "."


func _perk_level_text(perk: Dictionary) -> String:
	if int(perk.get("max_level", 1)) == 1 and str(perk.get("character_restriction", "")) != "":
		return "ACTIVE"
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
	var value: Variant = slot_state.get(slot_key, null)
	if value is Dictionary:
		return value
	if value is Array:
		var items: Array = value
		if not items.is_empty() and items[0] is Dictionary:
			return items[0]
	return {}


func _is_equipment_slot_enabled(slot_key: String, owner: Object) -> bool:
	if not slot_key.begins_with("accessory"):
		return true
	var slot_number: int = int(slot_key.substr("accessory".length(), 1))
	if slot_number <= 0:
		return true
	return slot_number <= _get_accessory_slot_count(owner)


func _get_accessory_slot_count(owner: Object) -> int:
	var explicit_count: int = int(_safe_owner_get(owner, "accessory_slot_count", 0))
	if explicit_count > 0:
		return clamp(explicit_count, 1, 4)
	var runtime_bonus: int = int(_safe_owner_get(owner, "runtime_accessory_slot_bonus", 0))
	var levels: Dictionary = _get_dict(_safe_owner_get(owner, "runtime_perk_levels", {}))
	runtime_bonus = max(runtime_bonus, int(levels.get("common_expansion", 0)))
	return clamp(BASE_ACCESSORY_SLOT_COUNT + runtime_bonus, 1, 4)


func _equipment_color(base: String, has_item: bool, enabled: bool) -> Color:
	if not enabled:
		return Color(85.0 / 255.0, 91.0 / 255.0, 112.0 / 255.0)
	if has_item:
		return Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0)
	match base:
		"head":
			return Color(120.0 / 255.0, 190.0 / 255.0, 1.0)
		"top":
			return Color(1.0, 160.0 / 255.0, 95.0 / 255.0)
		"arm":
			return Color(185.0 / 255.0, 145.0 / 255.0, 1.0)
		"belt":
			return Color(1.0, 215.0 / 255.0, 100.0 / 255.0)
		"back":
			return Color(125.0 / 255.0, 220.0 / 255.0, 1.0)
		"knee":
			return Color(120.0 / 255.0, 1.0, 205.0 / 255.0)
		"shoes":
			return Color(115.0 / 255.0, 230.0 / 255.0, 150.0 / 255.0)
		_:
			return Color(220.0 / 255.0, 175.0 / 255.0, 1.0)


func _equipment_item_display_name(item_data: Dictionary) -> String:
	var display_name: String = str(item_data.get("display_name", item_data.get("korean", "")))
	if display_name != "":
		return display_name
	var item_name: String = str(item_data.get("name", ""))
	if item_name != "":
		return item_name
	return "장비"


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
