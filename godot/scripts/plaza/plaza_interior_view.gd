extends Control

const GAME_SIZE := Vector2(760.0, 750.0)
const NPC_RECT := Rect2(Vector2(26.0, 118.0), Vector2(236.0, 500.0))
const TITLE_RECT := Rect2(Vector2(24.0, 20.0), Vector2(330.0, 76.0))
const GOLD_RECT := Rect2(Vector2(610.0, 22.0), Vector2(126.0, 34.0))
const EXIT_RECT := Rect2(Vector2(24.0, 700.0), Vector2(88.0, 30.0))
const PANEL_RECT := Rect2(Vector2(516.0, 456.0), Vector2(212.0, 186.0))
const PANEL_CONFIRM_RECT := Rect2(Vector2(540.0, 588.0), Vector2(80.0, 32.0))
const PANEL_CANCEL_RECT := Rect2(Vector2(632.0, 588.0), Vector2(70.0, 32.0))
const HOVER_SPEED := 10.0
const FLARE_DURATION := 0.42

var _building_type := ""
var _title := ""
var _subtitle := ""
var _actions: Array[String] = []
var _last_message := ""
var _npc_name := ""
var _npc_texture: Texture2D = null
var _room_backdrop_texture: Texture2D = null
var _object_textures: Dictionary = {}
var _accent := Color(0.0, 0.86, 1.0, 1.0)
var _save_snapshot: Dictionary = {}
var _close_callback: Callable = Callable()
var _action_callback: Callable = Callable()
var _object_specs: Array[Dictionary] = []
var _object_hover: Dictionary = {}
var _hovered_object_id := ""
var _selected_object_id := ""
var _clicked_object_id := ""
var _panel_open := false
var _flare_timer := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(true)


func configure(data: Dictionary, close_callback: Callable, action_callback: Callable) -> void:
	_close_callback = close_callback
	_action_callback = action_callback
	update_state(data)
	grab_focus()


func update_state(data: Dictionary) -> void:
	_building_type = str(data.get("building_type", _building_type))
	_title = str(data.get("title", _title))
	_subtitle = str(data.get("subtitle", _subtitle))
	_actions = _get_string_array(data.get("actions", _actions))
	_last_message = str(data.get("last_message", _last_message))
	_npc_name = str(data.get("npc_name", _npc_name))
	var texture_value: Variant = data.get("npc_texture", _npc_texture)
	_npc_texture = texture_value if texture_value is Texture2D else null
	var room_texture_value: Variant = data.get("room_texture", _room_backdrop_texture)
	_room_backdrop_texture = room_texture_value if room_texture_value is Texture2D else null
	var object_textures_value: Variant = data.get("object_textures", _object_textures)
	if object_textures_value is Dictionary:
		_object_textures = (object_textures_value as Dictionary).duplicate(false)
	var accent_value: Variant = data.get("accent_color", _accent)
	_accent = accent_value if accent_value is Color else _accent
	var snapshot_value: Variant = data.get("save_snapshot", _save_snapshot)
	if snapshot_value is Dictionary:
		_save_snapshot = (snapshot_value as Dictionary).duplicate(true)
	_object_specs = _build_object_specs()
	for spec in _object_specs:
		var object_id := str(spec.get("id", ""))
		if object_id != "" and not _object_hover.has(object_id):
			_object_hover[object_id] = 0.0
	if _selected_object_id != "" and _find_object_spec(_selected_object_id).is_empty():
		_panel_open = false
		_selected_object_id = ""
	queue_redraw()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE:
			_close()
			return true
		if _panel_open and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			_confirm_selected_object()
			return true
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			var action_index := int(key_event.keycode - KEY_1)
			_open_object_by_action_index(action_index)
			return true
		return true
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		_set_hovered_object(_get_object_at_local_pos(mouse_event.position))
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
			return true
		_handle_left_click(mouse_button.position)
		return true
	return true


func get_status() -> Dictionary:
	return {
		"active": true,
		"building_type": _building_type,
		"object_count": _object_specs.size(),
		"hovered_object_id": _hovered_object_id,
		"selected_object_id": _selected_object_id,
		"clicked_object_id": _clicked_object_id,
		"panel_open": _panel_open,
		"room_replaces_plaza": true,
		"object_texture_count": _get_loaded_object_texture_count(),
	}


func hover_object_for_test(object_id: String) -> Dictionary:
	if _find_object_spec(object_id).is_empty():
		_set_hovered_object("")
	else:
		_set_hovered_object(object_id)
	return get_status()


func click_object_for_test(object_id: String) -> Dictionary:
	var spec := _find_object_spec(object_id)
	if spec.is_empty():
		return get_status()
	_open_object_panel(spec)
	return get_status()


func confirm_selected_object_for_test() -> bool:
	return _confirm_selected_object()


func click_action_for_test(action_index: int) -> bool:
	if not _open_object_by_action_index(action_index):
		return false
	return _confirm_selected_object()


func _process(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)
	_time += safe_delta
	_flare_timer = max(0.0, _flare_timer - safe_delta)
	var changed := _flare_timer > 0.0
	for spec in _object_specs:
		var object_id := str(spec.get("id", ""))
		var current := float(_object_hover.get(object_id, 0.0))
		var target := 1.0 if object_id == _hovered_object_id else 0.0
		var next := move_toward(current, target, safe_delta * HOVER_SPEED)
		if not is_equal_approx(current, next):
			changed = true
			_object_hover[object_id] = next
	if changed:
		queue_redraw()


func _draw() -> void:
	var scale := _get_game_scale()
	_draw_room_background(scale)
	_draw_title_bar(scale)
	_draw_npc(scale)
	if _room_backdrop_texture == null:
		_draw_shop_table(scale)
	_draw_objects(scale)
	if _panel_open:
		_draw_object_panel(scale)


func _draw_room_background(scale: float) -> void:
	if _draw_room_backdrop_texture():
		return
	var full_rect := Rect2(Vector2.ZERO, size)
	draw_rect(full_rect, Color(0.006, 0.008, 0.014, 1.0), true)
	for idx in range(16):
		var t := float(idx) / 15.0
		var band := Rect2(Vector2(0.0, t * GAME_SIZE.y) * scale, Vector2(GAME_SIZE.x, GAME_SIZE.y / 15.0 + 2.0) * scale)
		draw_rect(band, Color(0.012 + t * 0.018, 0.010 + t * 0.010, 0.025 + t * 0.026, 1.0), true)
	var pulse := 0.5 + 0.5 * sin(_time * 3.7)
	for idx in range(10):
		var x := 296.0 + float(idx) * 46.0
		var y := 96.0 + float(idx % 3) * 42.0
		draw_line(Vector2(x, y) * scale, Vector2(x + 72.0, y + 122.0) * scale, Color(_accent.r, _accent.g, _accent.b, 0.07 + pulse * 0.03), max(1.0, 1.4 * scale))
	for idx in range(7):
		var panel := Rect2(Vector2(305.0 + float(idx) * 58.0, 70.0 + float(idx % 2) * 28.0) * scale, Vector2(42.0, 82.0) * scale)
		draw_rect(panel, Color(0.015, 0.020, 0.034, 0.84), true)
		draw_rect(panel, Color(0.75, 0.12, 0.95, 0.18), false, max(1.0, 1.0 * scale))
	var floor_rect := Rect2(Vector2(258.0, 464.0) * scale, Vector2(486.0, 226.0) * scale)
	draw_rect(floor_rect, Color(0.028, 0.026, 0.038, 0.98), true)
	for idx in range(9):
		var y := 484.0 + float(idx) * 22.0
		draw_line(Vector2(270.0, y) * scale, Vector2(724.0, y - 18.0) * scale, Color(0.0, 0.80, 0.94, 0.050), max(1.0, 1.0 * scale))
	for idx in range(8):
		var x := 292.0 + float(idx) * 54.0
		draw_line(Vector2(x, 666.0) * scale, Vector2(x + 88.0, 476.0) * scale, Color(1.0, 0.22, 0.92, 0.042), max(1.0, 1.0 * scale))
	draw_rect(Rect2(Vector2(544.0, 108.0) * scale, Vector2(116.0, 54.0) * scale), Color(0.018, 0.024, 0.036, 0.92), true)
	draw_rect(Rect2(Vector2(544.0, 108.0) * scale, Vector2(116.0, 54.0) * scale), Color(1.0, 0.08, 0.80, 0.46), false, max(1.0, 1.4 * scale))
	_draw_text_shadow(ThemeDB.fallback_font, Vector2(565.0, 142.0) * scale, "BUY", int(23.0 * scale), Color(1.0, 0.40, 0.95, 0.94))
	_draw_wall_neon_props(scale)
	_draw_room_clutter(scale)


func _draw_room_backdrop_texture() -> bool:
	if _room_backdrop_texture == null:
		return false
	var texture_size := _room_backdrop_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 1.0), true)
	var target_ratio := size.x / size.y
	var source_ratio := texture_size.x / texture_size.y
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	if source_ratio > target_ratio:
		var crop_width := texture_size.y * target_ratio
		source_rect.position.x = (texture_size.x - crop_width) * 0.5
		source_rect.size.x = crop_width
	elif source_ratio < target_ratio:
		var crop_height := texture_size.x / target_ratio
		source_rect.position.y = (texture_size.y - crop_height) * 0.5
		source_rect.size.y = crop_height
	draw_texture_rect_region(_room_backdrop_texture, Rect2(Vector2.ZERO, size), source_rect)
	return true


func _draw_title_bar(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var title_rect := Rect2(TITLE_RECT.position * scale, TITLE_RECT.size * scale)
	draw_rect(title_rect, Color(0.020, 0.016, 0.052, 0.78), true)
	draw_rect(title_rect, Color(0.78, 0.18, 1.0, 0.62), false, max(1.0, 1.2 * scale))
	_draw_text_shadow(font, title_rect.position + Vector2(18.0, 34.0) * scale, "VR " + _title, int(27.0 * scale), Color(0.94, 0.70, 1.0, 1.0))
	if _subtitle != "":
		_draw_text_shadow(font, title_rect.position + Vector2(20.0, 58.0) * scale, _subtitle, int(13.0 * scale), Color(0.88, 0.96, 1.0, 0.82))
	var gold_rect := Rect2(GOLD_RECT.position * scale, GOLD_RECT.size * scale)
	draw_rect(gold_rect, Color(0.014, 0.018, 0.022, 0.82), true)
	draw_rect(gold_rect, Color(1.0, 0.78, 0.24, 0.42), false, max(1.0, 1.0 * scale))
	_draw_text_shadow(font, gold_rect.position + Vector2(24.0, 23.0) * scale, "%dG" % int(_save_snapshot.get("plaza_gold", 0)), int(15.0 * scale), Color(1.0, 0.90, 0.52, 0.96))
	var exit_rect := Rect2(EXIT_RECT.position * scale, EXIT_RECT.size * scale)
	draw_rect(exit_rect, Color(0.040, 0.015, 0.070, 0.86), true)
	draw_rect(exit_rect, Color(0.88, 0.20, 1.0, 0.56), false, max(1.0, 1.0 * scale))
	_draw_text_shadow(font, exit_rect.position + Vector2(20.0, 21.0) * scale, "나가기", int(14.0 * scale), Color(0.96, 0.80, 1.0, 0.96))


func _draw_npc(scale: float) -> void:
	var font := ThemeDB.fallback_font
	var npc_rect := Rect2(NPC_RECT.position * scale, NPC_RECT.size * scale)
	draw_rect(npc_rect, Color(0.006, 0.010, 0.020, 0.92), true)
	draw_rect(npc_rect, Color(_accent.r * 0.10, _accent.g * 0.10, _accent.b * 0.14, 0.44), true)
	draw_rect(npc_rect, Color(0.76, 0.20, 1.0, 0.52), false, max(1.0, 1.4 * scale))
	if _npc_texture != null:
		var tex_size := _npc_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var fit_rect := Rect2((NPC_RECT.position + Vector2(6.0, 10.0)) * scale, (NPC_RECT.size - Vector2(12.0, 72.0)) * scale)
			var fit_scale: float = min(fit_rect.size.x / tex_size.x, fit_rect.size.y / tex_size.y)
			var draw_size := tex_size * fit_scale
			var draw_pos := Vector2(fit_rect.get_center().x - draw_size.x * 0.5, fit_rect.end.y - draw_size.y)
			draw_texture_rect(_npc_texture, Rect2(draw_pos, draw_size), false)
	else:
		_draw_npc_placeholder(scale)
	if font == null:
		return
	_draw_text_shadow(font, (NPC_RECT.position + Vector2(18.0, NPC_RECT.size.y - 40.0)) * scale, _npc_name, int(15.0 * scale), Color(0.94, 0.98, 1.0, 0.95))
	var message := _last_message if _last_message != "" else "필요한 물건이 있으면 테이블의 물건을 골라봐."
	_draw_text_shadow(font, (NPC_RECT.position + Vector2(18.0, NPC_RECT.size.y - 18.0)) * scale, message, int(12.0 * scale), Color(1.0, 0.78, 0.95, 0.88))


func _draw_npc_placeholder(scale: float) -> void:
	var center := NPC_RECT.position + Vector2(NPC_RECT.size.x * 0.5, 216.0)
	draw_circle(center * scale, 42.0 * scale, Color(0.64, 0.68, 0.76, 0.92))
	draw_rect(Rect2((center + Vector2(-46.0, 46.0)) * scale, Vector2(92.0, 150.0) * scale), Color(0.22, 0.22, 0.30, 0.94), true)
	draw_line((center + Vector2(-34.0, 76.0)) * scale, (center + Vector2(-86.0, 126.0)) * scale, Color(0.78, 0.76, 0.86, 0.86), max(1.0, 8.0 * scale))
	draw_line((center + Vector2(34.0, 76.0)) * scale, (center + Vector2(88.0, 120.0)) * scale, Color(0.78, 0.76, 0.86, 0.86), max(1.0, 8.0 * scale))


func _draw_shop_table(scale: float) -> void:
	var table_rect := Rect2(Vector2(292.0, 438.0) * scale, Vector2(438.0, 154.0) * scale)
	draw_rect(table_rect, Color(0.030, 0.022, 0.034, 0.98), true)
	draw_rect(table_rect, Color(0.0, 0.88, 0.92, 0.20), false, max(1.0, 1.5 * scale))
	draw_line(Vector2(308.0, 458.0) * scale, Vector2(710.0, 430.0) * scale, Color(1.0, 0.18, 0.92, 0.28), max(1.0, 1.0 * scale))
	draw_line(Vector2(312.0, 594.0) * scale, Vector2(704.0, 566.0) * scale, Color(0.0, 0.90, 1.0, 0.20), max(1.0, 1.0 * scale))
	_draw_table_clutter(scale)


func _draw_wall_neon_props(scale: float) -> void:
	var cat_rect := Rect2(Vector2(650.0, 196.0) * scale, Vector2(68.0, 62.0) * scale)
	draw_rect(cat_rect, Color(0.018, 0.018, 0.032, 0.78), true)
	draw_rect(cat_rect, Color(1.0, 0.16, 0.82, 0.34), false, max(1.0, 1.0 * scale))
	var cat_center := Vector2(684.0, 226.0)
	draw_circle(cat_center * scale, 16.0 * scale, Color(1.0, 0.18, 0.86, 0.08))
	draw_arc(cat_center * scale, 16.0 * scale, 0.0, TAU, 32, Color(1.0, 0.28, 0.90, 0.72), max(1.0, 1.3 * scale), true)
	draw_line((cat_center + Vector2(-10.0, -12.0)) * scale, (cat_center + Vector2(-18.0, -24.0)) * scale, Color(1.0, 0.28, 0.90, 0.72), max(1.0, 1.3 * scale))
	draw_line((cat_center + Vector2(10.0, -12.0)) * scale, (cat_center + Vector2(18.0, -24.0)) * scale, Color(1.0, 0.28, 0.90, 0.72), max(1.0, 1.3 * scale))
	draw_circle((cat_center + Vector2(-6.0, -2.0)) * scale, 2.0 * scale, Color(0.0, 0.92, 1.0, 0.90))
	draw_circle((cat_center + Vector2(7.0, -2.0)) * scale, 2.0 * scale, Color(0.0, 0.92, 1.0, 0.90))
	var board_rect := Rect2(Vector2(596.0, 282.0) * scale, Vector2(122.0, 72.0) * scale)
	draw_rect(board_rect, Color(0.016, 0.026, 0.030, 0.70), true)
	draw_rect(board_rect, Color(0.0, 0.88, 1.0, 0.24), false, max(1.0, 1.0 * scale))
	for idx in range(5):
		var y := 296.0 + float(idx) * 10.0
		draw_line(Vector2(610.0, y) * scale, Vector2(700.0 - float(idx % 2) * 18.0, y + 4.0) * scale, Color(0.0, 0.92, 1.0, 0.13), max(1.0, 0.8 * scale))


func _draw_room_clutter(scale: float) -> void:
	for idx in range(22):
		var x := 288.0 + fposmod(float(idx) * 71.0, 438.0)
		var y := 604.0 + fposmod(float(idx) * 37.0, 78.0)
		var color := Color(1.0, 0.72, 0.24, 0.20) if idx % 3 == 0 else Color(0.0, 0.86, 1.0, 0.13)
		if idx % 4 == 0:
			draw_circle(Vector2(x, y) * scale, (3.5 + float(idx % 5)) * scale, color)
			draw_circle(Vector2(x, y) * scale, (2.0 + float(idx % 3)) * scale, Color(0.0, 0.0, 0.0, 0.28))
		else:
			var chip := Rect2(Vector2(x, y) * scale, Vector2(18.0 + float(idx % 5) * 3.0, 8.0 + float(idx % 3) * 3.0) * scale)
			draw_rect(chip, Color(0.018, 0.024, 0.030, 0.72), true)
			draw_rect(chip, color, false, max(1.0, 0.8 * scale))
	for idx in range(7):
		var start := Vector2(312.0 + float(idx) * 58.0, 686.0)
		var end := start + Vector2(44.0 + float(idx % 2) * 30.0, -34.0 - float(idx % 3) * 14.0)
		draw_line(start * scale, end * scale, Color(0.68, 0.16, 0.92, 0.13), max(1.0, 1.2 * scale))


func _draw_table_clutter(scale: float) -> void:
	for idx in range(18):
		var x := 316.0 + fposmod(float(idx) * 49.0, 386.0)
		var y := 470.0 + fposmod(float(idx) * 29.0, 96.0)
		if idx % 5 == 0:
			draw_circle(Vector2(x, y) * scale, 6.0 * scale, Color(1.0, 0.76, 0.22, 0.46))
			draw_circle(Vector2(x, y) * scale, 3.0 * scale, Color(0.25, 0.15, 0.04, 0.46))
		elif idx % 3 == 0:
			var vial := Rect2(Vector2(x, y) * scale, Vector2(8.0, 24.0) * scale)
			draw_rect(vial, Color(0.0, 0.94, 1.0, 0.18), true)
			draw_rect(vial, Color(0.0, 0.94, 1.0, 0.42), false, max(1.0, 0.8 * scale))
		else:
			var card := Rect2(Vector2(x, y) * scale, Vector2(24.0, 16.0) * scale)
			draw_rect(card, Color(0.024, 0.028, 0.040, 0.82), true)
			draw_rect(card, Color(1.0, 0.24, 0.88, 0.22), false, max(1.0, 0.8 * scale))


func _draw_objects(scale: float) -> void:
	for spec in _object_specs:
		_draw_object(spec, scale)


func _draw_object(spec: Dictionary, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var object_id := str(spec.get("id", ""))
	var rect: Rect2 = spec.get("rect", Rect2())
	var hover := float(_object_hover.get(object_id, 0.0))
	var selected := object_id == _selected_object_id and _panel_open
	var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if object_id == _clicked_object_id else 0.0
	var lift := hover * 12.0 + flare * 10.0
	var draw_rect_game := Rect2(rect.position + Vector2(0.0, -lift), rect.size)
	var center := draw_rect_game.get_center()
	var glow_color := Color(_accent.r, _accent.g, _accent.b, 0.16 + hover * 0.20 + flare * 0.32)
	draw_circle(center * scale, (54.0 + hover * 10.0 + flare * 28.0) * scale, glow_color)
	draw_circle(center * scale, (34.0 + hover * 4.0) * scale, Color(0.0, 0.95, 1.0, 0.15 + hover * 0.12))
	var pedestal := Rect2(Vector2(rect.position.x + 10.0, rect.end.y - 22.0) * scale, Vector2(rect.size.x - 20.0, 26.0) * scale)
	draw_rect(pedestal, Color(0.014, 0.022, 0.030, 0.94), true)
	draw_rect(pedestal, Color(0.0, 0.88, 1.0, 0.28), false, max(1.0, 1.0 * scale))
	_draw_object_icon(str(spec.get("kind", "crystal")), center, hover, flare, scale)
	var ring_color := Color(1.0, 0.36, 0.94, 0.68) if selected else Color(0.0, 0.86, 1.0, 0.34 + hover * 0.34)
	draw_arc(center * scale, (43.0 + hover * 5.0) * scale, -PI * 0.12 + _time, TAU * 0.82 + _time, 42, ring_color, max(1.0, 1.8 * scale), true)
	if font != null:
		var label := str(spec.get("label", ""))
		var label_rect := Rect2(Vector2(rect.position.x - 8.0, rect.end.y + 10.0) * scale, Vector2(rect.size.x + 16.0, 38.0) * scale)
		draw_rect(label_rect, Color(0.012, 0.014, 0.022, 0.78), true)
		draw_rect(label_rect, Color(_accent.r, _accent.g, _accent.b, 0.30), false, max(1.0, 1.0 * scale))
		_draw_text_shadow(font, label_rect.position + Vector2(10.0, 24.0) * scale, label, int(13.0 * scale), Color(0.94, 0.98, 1.0, 0.96))


func _draw_object_icon(kind: String, center: Vector2, hover: float, flare: float, scale: float) -> void:
	if _draw_object_texture(kind, center, hover, flare, scale):
		return
	var alpha := 0.88 + hover * 0.10
	match kind:
		"capsule":
			var body := Rect2((center + Vector2(-18.0, -30.0 - flare * 5.0)) * scale, Vector2(36.0, 60.0) * scale)
			draw_rect(body, Color(0.06, 0.95, 1.0, 0.24 + hover * 0.16), true)
			draw_rect(body, Color(0.0, 0.96, 1.0, alpha), false, max(1.0, 2.0 * scale))
			draw_circle((center + Vector2(0.0, -20.0)) * scale, 18.0 * scale, Color(1.0, 0.30, 0.92, 0.50))
			draw_circle((center + Vector2(0.0, 20.0)) * scale, 18.0 * scale, Color(0.0, 0.88, 1.0, 0.46))
		"sell":
			draw_rect(Rect2((center + Vector2(-30.0, -20.0)) * scale, Vector2(60.0, 40.0) * scale), Color(1.0, 0.72, 0.22, 0.24), true)
			draw_rect(Rect2((center + Vector2(-30.0, -20.0)) * scale, Vector2(60.0, 40.0) * scale), Color(1.0, 0.82, 0.32, alpha), false, max(1.0, 2.0 * scale))
			draw_line((center + Vector2(-20.0, 0.0)) * scale, (center + Vector2(20.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), max(1.0, 3.0 * scale))
			draw_line((center + Vector2(9.0, -12.0)) * scale, (center + Vector2(22.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), max(1.0, 3.0 * scale))
			draw_line((center + Vector2(9.0, 12.0)) * scale, (center + Vector2(22.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), max(1.0, 3.0 * scale))
		_:
			draw_circle(center * scale, (25.0 + flare * 5.0) * scale, Color(0.80, 0.22, 1.0, 0.30 + hover * 0.16))
			draw_rect(Rect2((center + Vector2(-15.0, -25.0)) * scale, Vector2(30.0, 50.0) * scale), Color(0.76, 0.20, 1.0, 0.24), true)
			draw_line((center + Vector2(0.0, -30.0)) * scale, (center + Vector2(24.0, 2.0)) * scale, Color(0.92, 0.58, 1.0, alpha), max(1.0, 2.2 * scale))
			draw_line((center + Vector2(24.0, 2.0)) * scale, (center + Vector2(0.0, 32.0)) * scale, Color(0.55, 0.94, 1.0, alpha), max(1.0, 2.2 * scale))
			draw_line((center + Vector2(0.0, 32.0)) * scale, (center + Vector2(-24.0, 2.0)) * scale, Color(0.92, 0.58, 1.0, alpha), max(1.0, 2.2 * scale))
			draw_line((center + Vector2(-24.0, 2.0)) * scale, (center + Vector2(0.0, -30.0)) * scale, Color(0.55, 0.94, 1.0, alpha), max(1.0, 2.2 * scale))


func _draw_object_texture(kind: String, center: Vector2, hover: float, flare: float, scale: float) -> bool:
	var texture := _get_object_texture(kind)
	if texture == null:
		return false
	var draw_size := _get_object_texture_draw_size(kind) * (1.0 + hover * 0.07 + flare * 0.12)
	var center_offset := _get_object_texture_center_offset(kind)
	var rect := Rect2((center + center_offset - draw_size * 0.5) * scale, draw_size * scale)
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.96 + hover * 0.04))
	return true


func _get_object_texture(kind: String) -> Texture2D:
	var texture: Variant = _object_textures.get(kind, null)
	return texture if texture is Texture2D else null


func _get_object_texture_draw_size(kind: String) -> Vector2:
	match kind:
		"capsule":
			return Vector2(74.0, 96.0)
		"sell":
			return Vector2(92.0, 88.0)
		_:
			return Vector2(72.0, 98.0)


func _get_object_texture_center_offset(kind: String) -> Vector2:
	match kind:
		"sell":
			return Vector2(0.0, -2.0)
		_:
			return Vector2(0.0, -4.0)


func _get_loaded_object_texture_count() -> int:
	var count := 0
	for texture in _object_textures.values():
		if texture is Texture2D:
			count += 1
	return count


func _draw_object_panel(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var spec := _find_object_spec(_selected_object_id)
	if spec.is_empty():
		return
	var panel := Rect2(PANEL_RECT.position * scale, PANEL_RECT.size * scale)
	draw_rect(panel, Color(0.010, 0.014, 0.024, 0.96), true)
	draw_rect(panel, Color(_accent.r * 0.12, _accent.g * 0.12, _accent.b * 0.12, 0.50), true)
	draw_rect(panel, Color(0.0, 0.90, 1.0, 0.48), false, max(1.0, 1.2 * scale))
	_draw_text_shadow(font, panel.position + Vector2(20.0, 32.0) * scale, str(spec.get("label", "")), int(18.0 * scale), Color(0.94, 0.98, 1.0, 0.96))
	_draw_text_shadow(font, panel.position + Vector2(20.0, 62.0) * scale, "선택한 오브젝트의 기능을 실행합니다.", int(12.0 * scale), Color(0.78, 0.92, 0.96, 0.78))
	var ap_text := "AP %d" % int(_save_snapshot.get("ap_current", 0))
	_draw_text_shadow(font, panel.position + Vector2(20.0, 92.0) * scale, ap_text, int(13.0 * scale), Color(0.72, 1.0, 0.88, 0.90))
	if _last_message != "":
		_draw_text_shadow(font, panel.position + Vector2(20.0, 118.0) * scale, _last_message, int(12.0 * scale), Color(1.0, 0.78, 0.58, 0.90))
	_draw_button(PANEL_CONFIRM_RECT, "실행", Color(0.0, 0.84, 1.0, 0.86), scale)
	_draw_button(PANEL_CANCEL_RECT, "취소", Color(1.0, 0.30, 0.90, 0.70), scale)


func _draw_button(rect: Rect2, label: String, color: Color, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var draw_rect_scaled := Rect2(rect.position * scale, rect.size * scale)
	draw_rect(draw_rect_scaled, Color(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.92), true)
	draw_rect(draw_rect_scaled, color, false, max(1.0, 1.0 * scale))
	if font != null:
		_draw_text_shadow(font, draw_rect_scaled.position + Vector2(21.0, 22.0) * scale, label, int(13.0 * scale), Color(0.94, 0.98, 1.0, 0.96))


func _handle_left_click(local_pos: Vector2) -> void:
	var game_pos := _to_game_pos(local_pos)
	if EXIT_RECT.has_point(game_pos):
		_close()
		return
	if _panel_open:
		if PANEL_CONFIRM_RECT.has_point(game_pos):
			_confirm_selected_object()
			return
		if PANEL_CANCEL_RECT.has_point(game_pos):
			_panel_open = false
			_selected_object_id = ""
			queue_redraw()
			return
	var object_id := _get_object_at_game_pos(game_pos)
	if object_id != "":
		var spec := _find_object_spec(object_id)
		_open_object_panel(spec)


func _open_object_panel(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	_selected_object_id = str(spec.get("id", ""))
	_clicked_object_id = _selected_object_id
	_panel_open = true
	_flare_timer = FLARE_DURATION
	_set_hovered_object(_selected_object_id)
	queue_redraw()


func _confirm_selected_object() -> bool:
	var spec := _find_object_spec(_selected_object_id)
	if spec.is_empty():
		return false
	var action_index := int(spec.get("action_index", -1))
	if action_index < 0:
		return false
	if _action_callback.is_valid():
		var result: Variant = _action_callback.call(action_index)
		queue_redraw()
		return bool(result)
	return false


func _open_object_by_action_index(action_index: int) -> bool:
	for spec in _object_specs:
		if int(spec.get("action_index", -1)) == action_index:
			_open_object_panel(spec)
			return true
	return false


func _close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _set_hovered_object(object_id: String) -> void:
	if _hovered_object_id == object_id:
		return
	_hovered_object_id = object_id
	queue_redraw()


func _get_object_at_local_pos(local_pos: Vector2) -> String:
	return _get_object_at_game_pos(_to_game_pos(local_pos))


func _get_object_at_game_pos(game_pos: Vector2) -> String:
	for idx in range(_object_specs.size() - 1, -1, -1):
		var spec := _object_specs[idx]
		var rect: Rect2 = spec.get("rect", Rect2())
		if rect.grow(12.0).has_point(game_pos):
			return str(spec.get("id", ""))
	return ""


func _find_object_spec(object_id: String) -> Dictionary:
	for spec in _object_specs:
		if str(spec.get("id", "")) == object_id:
			return spec
	return {}


func _build_object_specs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = mini(_actions.size(), 4)
	if count <= 0:
		return result
	var rects := _get_default_object_rects(count)
	for idx in range(count):
		var kind := _get_object_kind(idx)
		result.append({
			"id": "%s_action_%d" % [_building_type, idx],
			"action_index": idx,
			"label": str(_actions[idx]),
			"kind": kind,
			"rect": rects[idx],
		})
	return result


func _get_default_object_rects(count: int) -> Array[Rect2]:
	if count == 1:
		return [Rect2(Vector2(438.0, 392.0), Vector2(126.0, 132.0))]
	if count == 2:
		return [
			Rect2(Vector2(368.0, 400.0), Vector2(118.0, 128.0)),
			Rect2(Vector2(548.0, 400.0), Vector2(118.0, 128.0)),
		]
	if count == 3:
		if _room_backdrop_texture != null and _building_type == "shop":
			return [
				Rect2(Vector2(282.0, 348.0), Vector2(112.0, 118.0)),
				Rect2(Vector2(408.0, 344.0), Vector2(118.0, 122.0)),
				Rect2(Vector2(560.0, 350.0), Vector2(112.0, 118.0)),
			]
		return [
			Rect2(Vector2(318.0, 404.0), Vector2(116.0, 124.0)),
			Rect2(Vector2(464.0, 390.0), Vector2(126.0, 136.0)),
			Rect2(Vector2(610.0, 404.0), Vector2(112.0, 124.0)),
		]
	return [
		Rect2(Vector2(304.0, 406.0), Vector2(100.0, 118.0)),
		Rect2(Vector2(418.0, 394.0), Vector2(108.0, 128.0)),
		Rect2(Vector2(540.0, 394.0), Vector2(108.0, 128.0)),
		Rect2(Vector2(662.0, 406.0), Vector2(84.0, 118.0)),
	]


func _get_object_kind(index: int) -> String:
	match _building_type:
		"shop":
			return ["crystal", "capsule", "sell"][mini(index, 2)]
		"bank":
			return "sell"
		"gacha", "lingpet_store":
			return "capsule"
		_:
			return "crystal"


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(str(item))
	return result


func _to_game_pos(local_pos: Vector2) -> Vector2:
	var scale := _get_game_scale()
	if scale <= 0.0:
		return local_pos
	return local_pos / scale


func _get_game_scale() -> float:
	if GAME_SIZE.x <= 0.0:
		return 1.0
	return size.x / GAME_SIZE.x


func _draw_text_shadow(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	if font == null or text == "":
		return
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(0.82, color.a)))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
