extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DEBUG_SPAWN_MENU_MARGIN := 18.0
const DEBUG_SPAWN_MENU_TOP := 70.0
const DEBUG_SPAWN_MENU_HEADER_HEIGHT := 64.0
const DEBUG_GRID_COLUMNS := 10
const DEBUG_GRID_ROWS := 10
const DEBUG_GRID_CAPACITY := DEBUG_GRID_COLUMNS * DEBUG_GRID_ROWS
const DEBUG_GRID_DEFAULT_CELL_SIZE := 44.0
const DEBUG_GRID_MIN_CELL_SIZE := 24.0
const DEBUG_GRID_GAP := 6.0
const DEBUG_GRID_PANEL_PADDING := 12.0
const DEBUG_ICON_PADDING := 7.0
const DEBUG_ACTION_GRANT := "grant"
const DEBUG_ACTION_SPAWN := "spawn"
const DEBUG_ACTION_BUTTON_SIZE := Vector2(82.0, 24.0)
const DEBUG_ACTION_BUTTON_GAP := 8.0

const DEBUG_ENTRY_ORDER := [
	"gauge_charge",
	"lingpet_spirit_water",
	"lingpet_feed",
	"lingpet_apple_feed",
	"lingpet_melon_feed",
	"lingpet_special_feed",
	"lingpet_egg",
	"life_elixir",
	"vitamin_pill",
	"strange_vial",
	"aipill",
	"pandora_box",
	"grenade",
	"flare",
	"tear_gas",
	"dynamite",
	"molotov",
	"stopwatch",
	"magnet_field",
	"hologram_disk",
	"long_boost",
	"regeneration_potion",
	"holy_barrier",
	"dash_boost",
	"wall",
	"trampoline",
	"boomerang",
	"banana",
	"soap",
	"spider_mine",
	"elixir_of_mastery",
]

var open := false
var action_mode := DEBUG_ACTION_GRANT
var item_catalog: Object = ActiveItemCatalog.new()
var icon_textures: Dictionary = {}


func reset() -> void:
	open = false
	action_mode = DEBUG_ACTION_GRANT


func toggle() -> void:
	open = not open


func close() -> void:
	open = false


func is_open() -> bool:
	return open


func handle_click(mouse_position: Vector2, view_size: Vector2) -> Dictionary:
	return handle_mouse_button(MOUSE_BUTTON_LEFT, mouse_position, view_size)


func handle_mouse_button(button_index: int, mouse_position: Vector2, view_size: Vector2) -> Dictionary:
	if not open:
		return {
			"handled": false,
			"action": DEBUG_ACTION_GRANT,
			"item_name": "",
			"delta": 0,
		}

	var panel_rect: Rect2 = _get_panel_rect(view_size)
	if not panel_rect.has_point(mouse_position):
		if button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT:
			open = false
		return {
			"handled": true,
			"action": DEBUG_ACTION_GRANT,
			"item_name": "",
			"delta": 0,
		}

	var action_index: int = _get_action_button_index_at(mouse_position, panel_rect)
	if action_index >= 0:
		if button_index == MOUSE_BUTTON_LEFT:
			action_mode = _get_action_mode_for_index(action_index)
		return {
			"handled": true,
			"action": DEBUG_ACTION_GRANT,
			"item_name": "",
			"delta": 0,
		}

	var entries: Array[Dictionary] = _get_entries()
	var cell_index: int = _get_cell_index_at(mouse_position, panel_rect)
	if cell_index >= 0:
		if cell_index < entries.size():
			var item_name: String = str(entries[cell_index].get("name", ""))
			if action_mode == DEBUG_ACTION_SPAWN:
				if button_index == MOUSE_BUTTON_LEFT:
					return {
						"handled": true,
						"action": DEBUG_ACTION_SPAWN,
						"item_name": item_name,
						"delta": 1,
					}
				return {
					"handled": true,
					"action": DEBUG_ACTION_SPAWN,
					"item_name": "",
					"delta": 0,
				}
			var delta := 0
			if button_index == MOUSE_BUTTON_LEFT:
				delta = 1
				open = false
			elif button_index == MOUSE_BUTTON_WHEEL_UP:
				delta = 1
			elif button_index == MOUSE_BUTTON_WHEEL_DOWN:
				delta = -1
			return {
				"handled": true,
				"action": DEBUG_ACTION_GRANT,
				"item_name": item_name,
				"delta": delta,
			}
		return {
			"handled": true,
			"action": DEBUG_ACTION_GRANT,
			"item_name": "",
			"delta": 0,
		}

	return {
		"handled": true,
		"action": DEBUG_ACTION_GRANT,
		"item_name": "",
		"delta": 0,
	}


func draw(canvas: CanvasItem, view_size: Vector2, item_counts: Dictionary = {}) -> void:
	if canvas == null or not open:
		return

	var panel_rect: Rect2 = _get_panel_rect(view_size)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.26))
	canvas.draw_rect(panel_rect, Color(0.04, 0.05, 0.07, 0.94))
	canvas.draw_rect(panel_rect, Color(0.30, 0.74, 1.0, 0.88), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var title_pos := panel_rect.position + Vector2(16.0, 30.0)
	canvas.draw_string(font, title_pos, "F2 액티브 아이템 디버그", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.82, 0.95, 1.0, 1.0))
	canvas.draw_string(font, panel_rect.position + Vector2(16.0, 50.0), "10 x 10 아이콘 그리드 | 좌클릭: 선택 모드 실행 | 휠: 즉시획득 수량 조절", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.72, 0.78, 0.84, 1.0))

	var mouse_pos: Vector2 = Vector2(-9999.0, -9999.0)
	var viewport: Viewport = canvas.get_viewport()
	if viewport != null:
		mouse_pos = viewport.get_mouse_position()
	_draw_action_mode_buttons(canvas, font, panel_rect, mouse_pos)

	var entries: Array[Dictionary] = _get_entries()
	var hovered_index: int = _get_cell_index_at(mouse_pos, panel_rect)
	for index in range(DEBUG_GRID_CAPACITY):
		var cell_rect: Rect2 = _get_cell_rect(panel_rect, index)
		if index < entries.size():
			var item_name: String = str(entries[index].get("name", ""))
			_draw_item_cell(canvas, cell_rect, entries[index], index == hovered_index, int(item_counts.get(item_name, 0)))
		else:
			_draw_empty_cell(canvas, cell_rect, index == hovered_index)
	if hovered_index >= 0 and hovered_index < entries.size():
		var hovered_item_name: String = str(entries[hovered_index].get("name", ""))
		_draw_hover_tooltip(canvas, font, entries[hovered_index], _get_cell_rect(panel_rect, hovered_index), view_size, int(item_counts.get(hovered_item_name, 0)))


func _get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_name_value in DEBUG_ENTRY_ORDER:
		var item_name: String = str(item_name_value)
		entries.append({
			"name": item_name,
			"title": _get_debug_item_title(item_name),
			"subtitle": _get_debug_item_subtitle(item_name),
		})
	return entries


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var cell_size: float = _get_cell_size_for_view(view_size)
	var grid_width: float = float(DEBUG_GRID_COLUMNS) * cell_size + float(DEBUG_GRID_COLUMNS - 1) * DEBUG_GRID_GAP
	var grid_height: float = float(DEBUG_GRID_ROWS) * cell_size + float(DEBUG_GRID_ROWS - 1) * DEBUG_GRID_GAP
	var width: float = DEBUG_GRID_PANEL_PADDING * 2.0 + grid_width
	var height: float = DEBUG_SPAWN_MENU_HEADER_HEIGHT + DEBUG_GRID_PANEL_PADDING + grid_height
	var x: float = clamp(floor((view_size.x - width) * 0.5), 0.0, max(0.0, view_size.x - width))
	var y: float = clamp(floor((view_size.y - height) * 0.5), 0.0, max(0.0, view_size.y - height))
	return Rect2(Vector2(x, y), Vector2(width, height))


func _get_cell_size_for_view(view_size: Vector2) -> float:
	var max_width: float = max(180.0, view_size.x - DEBUG_SPAWN_MENU_MARGIN * 2.0)
	var max_height: float = max(180.0, view_size.y - DEBUG_SPAWN_MENU_MARGIN * 2.0)
	var by_width: float = floor((max_width - DEBUG_GRID_PANEL_PADDING * 2.0 - float(DEBUG_GRID_COLUMNS - 1) * DEBUG_GRID_GAP) / float(DEBUG_GRID_COLUMNS))
	var by_height: float = floor((max_height - DEBUG_SPAWN_MENU_HEADER_HEIGHT - DEBUG_GRID_PANEL_PADDING - float(DEBUG_GRID_ROWS - 1) * DEBUG_GRID_GAP) / float(DEBUG_GRID_ROWS))
	return clamp(min(DEBUG_GRID_DEFAULT_CELL_SIZE, min(by_width, by_height)), DEBUG_GRID_MIN_CELL_SIZE, DEBUG_GRID_DEFAULT_CELL_SIZE)


func _get_cell_size_from_panel(panel_rect: Rect2) -> float:
	var grid_width: float = panel_rect.size.x - DEBUG_GRID_PANEL_PADDING * 2.0
	return (grid_width - float(DEBUG_GRID_COLUMNS - 1) * DEBUG_GRID_GAP) / float(DEBUG_GRID_COLUMNS)


func _get_cell_rect(panel_rect: Rect2, index: int) -> Rect2:
	var cell_size: float = _get_cell_size_from_panel(panel_rect)
	var column: int = index % DEBUG_GRID_COLUMNS
	@warning_ignore("integer_division")
	var row: int = int(index / DEBUG_GRID_COLUMNS)
	return Rect2(
		panel_rect.position + Vector2(
			DEBUG_GRID_PANEL_PADDING + float(column) * (cell_size + DEBUG_GRID_GAP),
			DEBUG_SPAWN_MENU_HEADER_HEIGHT + float(row) * (cell_size + DEBUG_GRID_GAP)
		),
		Vector2(cell_size, cell_size)
	)


func _get_cell_index_at(position: Vector2, panel_rect: Rect2) -> int:
	for index in range(DEBUG_GRID_CAPACITY):
		if _get_cell_rect(panel_rect, index).has_point(position):
			return index
	return -1


func _get_action_button_index_at(position: Vector2, panel_rect: Rect2) -> int:
	for index in range(2):
		if _get_action_button_rect(panel_rect, index).has_point(position):
			return index
	return -1


func _get_action_mode_for_index(index: int) -> String:
	return DEBUG_ACTION_SPAWN if index == 1 else DEBUG_ACTION_GRANT


func _get_action_button_rect(panel_rect: Rect2, index: int) -> Rect2:
	var total_width: float = DEBUG_ACTION_BUTTON_SIZE.x * 2.0 + DEBUG_ACTION_BUTTON_GAP
	var start_x: float = panel_rect.end.x - DEBUG_GRID_PANEL_PADDING - total_width
	return Rect2(
		Vector2(start_x + float(index) * (DEBUG_ACTION_BUTTON_SIZE.x + DEBUG_ACTION_BUTTON_GAP), panel_rect.position.y + 13.0),
		DEBUG_ACTION_BUTTON_SIZE
	)


func _draw_action_mode_buttons(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	var labels := ["즉시획득", "스폰"]
	for index in range(labels.size()):
		var mode: String = _get_action_mode_for_index(index)
		var rect: Rect2 = _get_action_button_rect(panel_rect, index)
		var active: bool = action_mode == mode
		var hovered: bool = rect.has_point(mouse_pos)
		var fill := Color(0.08, 0.11, 0.15, 0.96)
		var border := Color(0.25, 0.40, 0.54, 0.78)
		if active:
			fill = Color(0.13, 0.22, 0.20, 0.98) if mode == DEBUG_ACTION_GRANT else Color(0.22, 0.16, 0.08, 0.98)
			border = Color(0.45, 1.0, 0.72, 0.92) if mode == DEBUG_ACTION_GRANT else Color(1.0, 0.76, 0.30, 0.92)
		elif hovered:
			fill = Color(0.12, 0.16, 0.21, 0.98)
		canvas.draw_rect(rect, fill)
		canvas.draw_rect(rect, border, false, 1.4)
		var label: String = str(labels[index])
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
		canvas.draw_string(
			font,
			rect.position + Vector2((rect.size.x - text_size.x) * 0.5, 16.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x,
			12,
			Color(0.94, 0.98, 1.0, 1.0)
		)


func _draw_item_cell(canvas: CanvasItem, cell_rect: Rect2, entry: Dictionary, hovered: bool, item_count: int = 0) -> void:
	var item_name: String = str(entry.get("name", ""))
	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	var item_color: Color = _get_item_color(item_data)
	var fill_color := Color(item_color.r * 0.18, item_color.g * 0.18, item_color.b * 0.18, 0.72)
	var border_color := Color(item_color.r, item_color.g, item_color.b, 0.72)
	if hovered:
		fill_color = fill_color.lightened(0.22)
		border_color = Color(1.0, 0.96, 0.62, 1.0)
	canvas.draw_rect(cell_rect, fill_color)
	canvas.draw_rect(cell_rect, border_color, false, 1.4 if hovered else 1.0)

	var padding: float = max(3.0, min(DEBUG_ICON_PADDING, cell_rect.size.x * 0.18))
	_draw_entry_icon(canvas, item_name, cell_rect.grow(-padding))
	if item_count > 0:
		_draw_count_badge(canvas, cell_rect, item_count)


func _draw_empty_cell(canvas: CanvasItem, cell_rect: Rect2, hovered: bool) -> void:
	canvas.draw_rect(cell_rect, Color(0.10, 0.12, 0.15, 0.34))
	var border_color := Color(0.26, 0.34, 0.42, 0.26)
	if hovered:
		border_color = Color(0.52, 0.66, 0.78, 0.58)
	canvas.draw_rect(cell_rect, border_color, false, 1.0)


func _draw_entry_icon(canvas: CanvasItem, item_name: String, icon_rect: Rect2) -> void:
	var texture: Texture2D = _get_icon_texture(item_name)
	if texture != null:
		canvas.draw_texture_rect(texture, icon_rect, false)
		return

	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	var item_color: Color = _get_item_color(item_data)
	var center: Vector2 = icon_rect.get_center()
	var radius: float = min(icon_rect.size.x, icon_rect.size.y) * 0.42
	canvas.draw_circle(center, radius, item_color)
	canvas.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.32), radius * 0.22, Color(1.0, 1.0, 1.0, 0.25))


func _draw_count_badge(canvas: CanvasItem, cell_rect: Rect2, item_count: int) -> void:
	var badge_size: float = clamp(cell_rect.size.x * 0.38, 14.0, 18.0)
	var badge_rect := Rect2(
		cell_rect.position + Vector2(cell_rect.size.x - badge_size - 2.0, 2.0),
		Vector2(badge_size, badge_size)
	)
	canvas.draw_rect(badge_rect, Color(0.02, 0.04, 0.06, 0.92))
	canvas.draw_rect(badge_rect, Color(1.0, 0.92, 0.46, 0.95), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var count_text: String = str(min(item_count, 99))
	var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10)
	var text_pos := badge_rect.position + Vector2(
		(badge_rect.size.x - text_size.x) * 0.5,
		badge_rect.size.y - 4.0
	)
	canvas.draw_string(font, text_pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.96, 0.72, 1.0))


func _draw_hover_tooltip(canvas: CanvasItem, font: Font, entry: Dictionary, cell_rect: Rect2, view_size: Vector2, item_count: int = 0) -> void:
	var tooltip_size := Vector2(min(260.0, max(190.0, view_size.x - 20.0)), 68.0)
	var tooltip_pos := cell_rect.end + Vector2(8.0, -tooltip_size.y)
	if tooltip_pos.x + tooltip_size.x > view_size.x - 8.0:
		tooltip_pos.x = cell_rect.position.x - tooltip_size.x - 8.0
	if tooltip_pos.y < 8.0:
		tooltip_pos.y = cell_rect.end.y + 8.0
	tooltip_pos.x = clamp(tooltip_pos.x, 8.0, max(8.0, view_size.x - tooltip_size.x - 8.0))
	tooltip_pos.y = clamp(tooltip_pos.y, 8.0, max(8.0, view_size.y - tooltip_size.y - 8.0))
	var tooltip_rect := Rect2(tooltip_pos, tooltip_size)
	canvas.draw_rect(tooltip_rect, Color(0.02, 0.025, 0.035, 0.96))
	canvas.draw_rect(tooltip_rect, Color(0.74, 0.88, 1.0, 0.72), false, 1.0)
	canvas.draw_string(font, tooltip_rect.position + Vector2(10.0, 25.0), str(entry.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.92, 0.98, 1.0, 1.0))
	var subtitle: String = str(entry.get("subtitle", ""))
	if item_count > 0:
		subtitle = "%s  x%d" % [subtitle, item_count]
	canvas.draw_string(font, tooltip_rect.position + Vector2(10.0, 48.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.72, 0.80, 0.88, 1.0))


func _get_icon_texture(item_name: String) -> Texture2D:
	if icon_textures.has(item_name):
		var cached_texture: Variant = icon_textures.get(item_name)
		if cached_texture is Texture2D:
			return cached_texture
		return null

	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	var icon_path: String = str(item_data.get("icon_path", ""))
	if icon_path == "":
		icon_textures[item_name] = null
		return null

	var texture: Texture2D = ProjectResourceLoader.load_texture(
		icon_path,
		"Missing debug item icon at %s",
		"Failed to load debug item icon at %s"
	)
	icon_textures[item_name] = texture
	return texture


func _get_debug_item_title(item_name: String) -> String:
	match item_name:
		"gauge_charge":
			return "에너지드링크"
		"lingpet_feed":
			return "귤"
		"lingpet_apple_feed":
			return "사과"
		"lingpet_melon_feed":
			return "멜론"
		"lingpet_special_feed":
			return "특제 사료"
		"life_elixir":
			return "생명수"
		"vitamin_pill":
			return "비타민드링크"
		"strange_vial":
			return "이상한 약병"
		"aipill":
			return "AI 알약"
		"pandora_box":
			return "판도라의 상자"
		"grenade":
			return "수류탄"
		"flare":
			return "조명탄"
		"tear_gas":
			return "최루탄"
		"dynamite":
			return "다이너마이트"
		"molotov":
			return "화염병"
		"stopwatch":
			return "스탑워치"
		"magnet_field":
			return "자기장"
		"long_boost":
			return "거대화포션"
		"regeneration_potion":
			return "재생물약"
		"holy_barrier":
			return "홀리베리어"
		"dash_boost":
			return "대쉬부스트"
		"wall":
			return "벽돌"
		"boomerang":
			return "부메랑"
		"banana":
			return "바나나"
		"soap":
			return "비누"
		"spider_mine":
			return "스파이더지뢰"
		_:
			return item_name


func _get_debug_item_subtitle(item_name: String) -> String:
	match item_name:
		"gauge_charge":
			return "게이지 +220 충전"
		"lingpet_spirit_water":
			return "수호령 지속시간 전량 회복"
		"lingpet_feed":
			return "포만도 +40"
		"lingpet_apple_feed":
			return "포만도 +30"
		"lingpet_melon_feed":
			return "포만도 +50"
		"lingpet_special_feed":
			return "포만도 +100"
		"life_elixir":
			return "게이지 최대 충전"
		"vitamin_pill":
			return "이동속도 증가"
		"strange_vial":
			return "무작위 크기 / 속도 변화"
		"aipill":
			return "자동 가드 / 히트당 공속 +25%"
		"pandora_box":
			return "차원문 아이템 소환"
		"grenade":
			return "투척 폭발 / 스턴"
		"flare":
			return "투척 혼란"
		"tear_gas":
			return "투척 연막 / 보스 쿨다운 정지"
		"dynamite":
			return "카운트다운 폭발"
		"molotov":
			return "화염 장판"
		"stopwatch":
			return "시간 정지"
		"magnet_field":
			return "공 끌어당김"
		"long_boost":
			return "패들 거대화"
		"regeneration_potion":
			return "쿨타임 초기화 / 대시토큰 회복"
		"holy_barrier":
			return "하단 방벽"
		"dash_boost":
			return "대쉬 무료 / 즉시 충전"
		"wall":
			return "벽돌 설치"
		"boomerang":
			return "부메랑 투척"
		"banana":
			return "미끄럼 함정"
		"soap":
			return "미끄럼 투척"
		"spider_mine":
			return "벽타는 지뢰"
		_:
			return "액티브 아이템"


func _get_item_color(item_data: Dictionary) -> Color:
	return _get_color(
		item_data.get("color", Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)),
		Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
	)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback
