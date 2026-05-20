extends RefCounted

const WEATHER_OPTIONS := [
	{"id": "breeze", "name": "산들바람", "desc": "좌우로 밀리는 약한 바람", "tone": Color(0.52, 0.82, 1.0, 1.0)},
	{"id": "gust", "name": "돌풍", "desc": "강한 바람과 공 궤도 흔들림", "tone": Color(0.42, 0.70, 1.0, 1.0)},
	{"id": "fire", "name": "화재", "desc": "공속 상승과 열기 효과", "tone": Color(1.0, 0.36, 0.14, 1.0)},
	{"id": "ice", "name": "빙판", "desc": "미끄러운 조작과 슬라이드", "tone": Color(0.58, 0.92, 1.0, 1.0)},
	{"id": "rain", "name": "비", "desc": "이동 속도 감소", "tone": Color(0.45, 0.64, 1.0, 1.0)},
	{"id": "hail", "name": "우박", "desc": "충돌 파편과 얼음 조각", "tone": Color(0.82, 0.96, 1.0, 1.0)},
	{"id": "sand", "name": "모래폭풍", "desc": "벽에 쌓이는 모래 지대", "tone": Color(0.96, 0.72, 0.32, 1.0)},
	{"id": "", "name": "해제", "desc": "현재 날씨 이벤트 종료", "tone": Color(0.78, 0.82, 0.88, 1.0)},
]

const COLUMNS := 4
const CARD_SIZE := Vector2(154.0, 86.0)
const CARD_GAP := Vector2(14.0, 14.0)
const PANEL_PADDING := Vector2(28.0, 24.0)
const HEADER_HEIGHT := 74.0

var open := false
var selected_index := 0


func toggle(owner: Object = null) -> void:
	open = not open
	if open:
		selected_index = _get_weather_index(_get_current_weather(owner))


func close() -> void:
	open = false


func is_open() -> bool:
	return open


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not open:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if _is_key(key_event, KEY_ESCAPE):
			close()
			return true
		if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_SPACE):
			_apply_selected_weather(owner, registry)
			return true
		if _is_key(key_event, KEY_RIGHT) or _is_key(key_event, KEY_D):
			_move_selection(1, 0)
			return true
		if _is_key(key_event, KEY_LEFT) or _is_key(key_event, KEY_A):
			_move_selection(-1, 0)
			return true
		if _is_key(key_event, KEY_DOWN) or _is_key(key_event, KEY_S):
			_move_selection(0, 1)
			return true
		if _is_key(key_event, KEY_UP) or _is_key(key_event, KEY_W):
			_move_selection(0, -1)
			return true
		var digit_index: int = _digit_to_index(key_event)
		if digit_index >= 0:
			selected_index = digit_index
			_apply_selected_weather(owner, registry)
			return true
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed:
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return true
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return true
		var hit_index: int = _get_card_index_at(mouse_event.position, view_size)
		if hit_index >= 0:
			selected_index = hit_index
			_apply_selected_weather(owner, registry)
			return true
		if not _get_panel_rect(view_size).has_point(mouse_event.position):
			close()
		return true

	if event is InputEventMouseMotion:
		var hit_index: int = _get_card_index_at((event as InputEventMouseMotion).position, view_size)
		if hit_index >= 0:
			selected_index = hit_index
		return true

	return true


func draw(canvas: CanvasItem, owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var panel_rect: Rect2 = _get_panel_rect(view_size)
	var current_weather := _get_current_weather(owner)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.48))
	canvas.draw_rect(panel_rect, Color(0.030, 0.040, 0.060, 0.97))
	canvas.draw_rect(panel_rect, Color(0.52, 0.82, 1.0, 0.86), false, 2.0)

	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 32.0), "F6 날씨 디버그", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.90, 0.98, 1.0))
	var current_name := _get_weather_name(current_weather)
	var info := "현재: %s  /  클릭하면 즉시 해당 날씨가 재생됩니다." % ("없음" if current_name == "" else current_name)
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 58.0), info, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 13, Color(0.70, 0.80, 0.88))

	for index in range(WEATHER_OPTIONS.size()):
		_draw_card(canvas, font, _get_card_rect(index, panel_rect), WEATHER_OPTIONS[index], index == selected_index, current_weather)

	var foot := "방향키/WASD 이동, Enter/Space 재생, 우클릭/Esc 닫기"
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, panel_rect.size.y - 18.0), foot, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 12, Color(0.58, 0.66, 0.74))


func _draw_card(canvas: CanvasItem, font: Font, rect: Rect2, option: Dictionary, selected: bool, current_weather: String) -> void:
	var weather_id := str(option.get("id", ""))
	var tone: Color = _get_color(option.get("tone", Color.WHITE))
	var is_current := weather_id == current_weather
	var is_clear := weather_id == ""
	var base := Color(0.095, 0.120, 0.170, 0.96)
	var border := Color(tone.r, tone.g, tone.b, 0.64)
	if is_clear:
		base = Color(0.105, 0.110, 0.125, 0.96)
	if is_current:
		base = base.lerp(Color(0.22, 0.24, 0.12, 1.0), 0.42)
		border = Color(1.0, 0.83, 0.28, 0.96)
	if selected:
		base = base.lerp(Color(tone.r * 0.32, tone.g * 0.34, tone.b * 0.40, 1.0), 0.66)
		border = Color(max(tone.r, 0.82), max(tone.g, 0.92), max(tone.b, 0.96), 1.0)

	canvas.draw_rect(rect, base)
	canvas.draw_rect(rect, border, false, 2.0 if selected else 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color(tone.r, tone.g, tone.b, 0.80))

	@warning_ignore("incompatible_ternary")
	var key_text := str((_get_weather_index(weather_id) + 1) if weather_id != "" else "8")
	canvas.draw_string(font, rect.position + Vector2(12.0, 24.0), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(tone.r, tone.g, tone.b, 0.94))
	canvas.draw_string(font, rect.position + Vector2(34.0, 25.0), str(option.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 46.0, 17, Color(0.94, 0.98, 1.0))
	canvas.draw_string(font, rect.position + Vector2(12.0, 56.0), str(option.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 12, Color(0.68, 0.78, 0.86))
	if is_current:
		canvas.draw_string(font, rect.position + Vector2(rect.size.x - 46.0, 24.0), "재생중", HORIZONTAL_ALIGNMENT_RIGHT, 34.0, 11, Color(1.0, 0.86, 0.36))


func _apply_selected_weather(owner: Object, registry: Object) -> void:
	var option: Dictionary = WEATHER_OPTIONS[selected_index]
	var weather_id := str(option.get("id", ""))
	var driver: Object = _get_instance(registry, "battle_scene_weather_update_driver")
	if driver != null and driver.has_method("debug_force_weather_event"):
		driver.debug_force_weather_event(weather_id, owner, registry)
	else:
		var weather: Object = _get_instance(registry, "weather_event_state")
		if weather_id == "":
			if weather != null and weather.has_method("force_end_weather_event"):
				weather.force_end_weather_event(owner, registry)
		elif weather != null and weather.has_method("force_start_weather_event"):
			weather.force_start_weather_event(weather_id, 3, 1, owner, registry)
	close()
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _move_selection(dx: int, dy: int) -> void:
	var row: int = int(floor(float(selected_index) / float(COLUMNS)))
	var col: int = selected_index % COLUMNS
	var rows: int = int(ceil(float(WEATHER_OPTIONS.size()) / float(COLUMNS)))
	row = wrapi(row + dy, 0, rows)
	col = wrapi(col + dx, 0, COLUMNS)
	selected_index = clampi(row * COLUMNS + col, 0, WEATHER_OPTIONS.size() - 1)


func _digit_to_index(key_event: InputEventKey) -> int:
	for index in range(WEATHER_OPTIONS.size()):
		var keycode: int = KEY_1 + index
		if _is_key(key_event, keycode):
			return index
	return -1


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var safe_view := Vector2(max(view_size.x, 760.0), max(view_size.y, 540.0))
	var rows: int = int(ceil(float(WEATHER_OPTIONS.size()) / float(COLUMNS)))
	var grid_size := Vector2(
		COLUMNS * CARD_SIZE.x + (COLUMNS - 1) * CARD_GAP.x,
		float(rows) * CARD_SIZE.y + float(max(0, rows - 1)) * CARD_GAP.y
	)
	var panel_size := grid_size + PANEL_PADDING * 2.0 + Vector2(0.0, HEADER_HEIGHT + 30.0)
	var pos := (safe_view - panel_size) * 0.5
	return Rect2(Vector2(max(pos.x, 12.0), max(pos.y, 12.0)), panel_size)


func _get_card_rect(index: int, panel_rect: Rect2) -> Rect2:
	var row: int = int(floor(float(index) / float(COLUMNS)))
	var col: int = index % COLUMNS
	var origin := panel_rect.position + Vector2(PANEL_PADDING.x, PANEL_PADDING.y + HEADER_HEIGHT)
	return Rect2(origin + Vector2(col * (CARD_SIZE.x + CARD_GAP.x), row * (CARD_SIZE.y + CARD_GAP.y)), CARD_SIZE)


func _get_card_index_at(position: Vector2, view_size: Vector2) -> int:
	var panel_rect: Rect2 = _get_panel_rect(view_size)
	for index in range(WEATHER_OPTIONS.size()):
		if _get_card_rect(index, panel_rect).has_point(position):
			return index
	return -1


func _get_weather_index(weather_id: String) -> int:
	for index in range(WEATHER_OPTIONS.size()):
		if str(WEATHER_OPTIONS[index].get("id", "")) == weather_id:
			return index
	return 0


func _get_weather_name(weather_id: String) -> String:
	if weather_id == "":
		return ""
	for option in WEATHER_OPTIONS:
		if str(option.get("id", "")) == weather_id:
			return str(option.get("name", weather_id))
	return weather_id


func _get_current_weather(owner: Object) -> String:
	if owner == null:
		return ""
	var value: Variant = owner.get("weather_type")
	return "" if value == null else str(value)


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE
