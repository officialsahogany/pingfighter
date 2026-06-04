extends RefCounted

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const SUPPORTED_RUNTIME_IDS := ["smasher", "soldier", "optimus", "viper", "blacksmith"]
const COLUMNS := 3
const CARD_SIZE := Vector2(188.0, 92.0)
const CARD_GAP := Vector2(14.0, 14.0)
const PANEL_PADDING := Vector2(28.0, 24.0)
const HEADER_HEIGHT := 78.0
const FALLBACK_CHARACTERS := [
	{"id": "ufo_player", "runtime_id": "smasher", "name": "\uc2a4\ub9e4\uc154", "card_color": Color(0.0, 0.90, 1.0)},
	{"id": "soldier", "runtime_id": "soldier", "name": "\ucf54\ub9cc\ub3c4", "card_color": Color(0.38, 0.68, 0.36)},
	{"id": "optimus", "runtime_id": "optimus", "name": "\uc774\uc624", "card_color": Color(0.44, 0.78, 0.96)},
	{"id": "viper", "runtime_id": "viper", "name": "\ubc14\uc774\ud37c", "card_color": Color(0.72, 0.30, 1.0)},
	{"id": "blacksmith", "runtime_id": "blacksmith", "name": "\ucf54\ud558\ucfe0", "card_color": Color(0.86, 0.58, 0.24)},
]

var open := false
var selected_index := 0
var character_runtime: Object = PlayerCharacterRuntime.new()


func toggle(owner: Object = null) -> void:
	open = not open
	if open:
		selected_index = _get_character_index(_get_current_runtime_character(owner))


func close() -> void:
	open = false


func is_open() -> bool:
	return open


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not open:
		return false
	var entries: Array = _get_entries()
	if entries.is_empty():
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if _is_key(key_event, KEY_ESCAPE):
			close()
			return true
		if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_SPACE):
			_apply_selected_character(owner, registry)
			return true
		if _is_key(key_event, KEY_RIGHT) or _is_key(key_event, KEY_D):
			_move_selection(1, 0, entries.size())
			return true
		if _is_key(key_event, KEY_LEFT) or _is_key(key_event, KEY_A):
			_move_selection(-1, 0, entries.size())
			return true
		if _is_key(key_event, KEY_DOWN) or _is_key(key_event, KEY_S):
			_move_selection(0, 1, entries.size())
			return true
		if _is_key(key_event, KEY_UP) or _is_key(key_event, KEY_W):
			_move_selection(0, -1, entries.size())
			return true
		var digit_index: int = _digit_to_index(key_event, entries.size())
		if digit_index >= 0:
			selected_index = digit_index
			_apply_selected_character(owner, registry)
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
		var hit_index: int = _get_card_index_at(mouse_event.position, view_size, entries.size())
		if hit_index >= 0:
			selected_index = hit_index
			_apply_selected_character(owner, registry)
			return true
		if not _get_panel_rect(view_size, entries.size()).has_point(mouse_event.position):
			close()
		return true

	if event is InputEventMouseMotion:
		var hit_index: int = _get_card_index_at((event as InputEventMouseMotion).position, view_size, entries.size())
		if hit_index >= 0:
			selected_index = hit_index
		return true

	return true


func draw(canvas: CanvasItem, owner: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var entries: Array = _get_entries()
	var panel_rect: Rect2 = _get_panel_rect(view_size, entries.size())
	var current_runtime: String = _get_current_runtime_character(owner)
	var current_name: String = _get_runtime_display_name(current_runtime)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.48))
	canvas.draw_rect(panel_rect, Color(0.035, 0.045, 0.070, 0.97))
	canvas.draw_rect(panel_rect, Color(0.35, 0.78, 1.0, 0.88), false, 2.0)

	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 32.0), "F1 \uce90\ub9ad\ud130 \ub514\ubc84\uadf8 \uc120\ud0dd", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.88, 0.97, 1.0))
	var info := "\ud604\uc7ac: %s  /  \ubc29\ud5a5\ud0a4\u00b7WASD \uc774\ub3d9, Enter\u00b7Space \ubcc0\uacbd, Esc \ub2eb\uae30" % current_name
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 58.0), info, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 13, Color(0.72, 0.80, 0.88))

	for index in range(entries.size()):
		_draw_card(canvas, font, _get_card_rect(index, panel_rect), entries[index], index == selected_index, current_runtime, index)

	var foot := "\uc120\ud0dd\ud558\uba74 \ub7f0\ud0c0\uc784 \uce90\ub9ad\ud130\uc640 HUD \uc2a4\ud0ac \uc0c1\ud0dc\uac00 \uc989\uc2dc \ubc18\uc601\ub429\ub2c8\ub2e4."
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, panel_rect.size.y - 18.0), foot, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 12, Color(0.58, 0.66, 0.74))


func _draw_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	entry: Dictionary,
	selected: bool,
	current_runtime: String,
	index: int
) -> void:
	var runtime_id: String = str(entry.get("_runtime_character_id", "smasher"))
	var is_current := runtime_id == current_runtime
	var tone: Color = _get_color(entry.get("card_color", Color(0.35, 0.78, 1.0)))
	var base := Color(0.10, 0.13, 0.18, 0.96)
	var border := Color(tone.r, tone.g, tone.b, 0.76)
	if is_current:
		base = base.lerp(Color(0.22, 0.24, 0.12, 1.0), 0.45)
		border = Color(1.0, 0.83, 0.28, 0.95)
	if selected:
		base = base.lerp(Color(tone.r * 0.32, tone.g * 0.34, tone.b * 0.40, 1.0), 0.66)
		border = Color(max(tone.r, 0.80), max(tone.g, 0.92), max(tone.b, 0.96), 1.0)

	canvas.draw_rect(rect, base)
	canvas.draw_rect(rect, border, false, 2.0 if selected else 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color(tone.r, tone.g, tone.b, 0.80))

	canvas.draw_string(font, rect.position + Vector2(12.0, 25.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 0.86, 0.38))
	canvas.draw_string(font, rect.position + Vector2(34.0, 26.0), _get_entry_display_name(entry), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 46.0, 18, Color(0.94, 0.98, 1.0))
	canvas.draw_string(font, rect.position + Vector2(12.0, 58.0), _get_runtime_label(runtime_id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 12, Color(0.68, 0.78, 0.86))
	if is_current:
		canvas.draw_string(font, rect.position + Vector2(rect.size.x - 58.0, 25.0), "\uc801\uc6a9\uc911", HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 11, Color(1.0, 0.86, 0.36))


func _apply_selected_character(owner: Object, registry: Object) -> void:
	var entries: Array = _get_entries()
	if owner == null or selected_index < 0 or selected_index >= entries.size():
		return
	var entry: Dictionary = entries[selected_index]
	var runtime_id: String = str(entry.get("_runtime_character_id", "smasher"))
	_sync_selection_state(owner, entry, runtime_id)
	var api: Object = _get_instance(registry, "battle_scene_api")
	if api != null and api.has_method("configure_player_character"):
		api.configure_player_character(owner, registry, runtime_id)
	else:
		owner.set("selected_character_type", runtime_id)
		owner.set("selected_runtime_character_id", runtime_id)
		owner.set("player_speed", 0.0)
	_sync_owner_character_fields(owner, entry, runtime_id)
	close()
	if owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _sync_owner_character_fields(owner: Object, entry: Dictionary, runtime_id: String) -> void:
	owner.set("selected_character_id", str(entry.get("id", runtime_id)))
	owner.set("selected_runtime_character_id", runtime_id)
	owner.set("selected_character_type", runtime_id)
	owner.set("selected_character_name", _get_entry_display_name(entry))


func _sync_selection_state(owner: Object, entry: Dictionary, runtime_id: String) -> void:
	if owner == null or not owner.has_method("get_node_or_null"):
		return
	var selection_state: Node = owner.get_node_or_null("/root/GameSelectionState")
	if selection_state == null or not selection_state.has_method("set_character"):
		return
	var stored_entry: Dictionary = entry.duplicate(true)
	stored_entry["runtime_id"] = runtime_id
	stored_entry["name"] = _get_entry_display_name(entry)
	selection_state.set_character(stored_entry)


func _get_entries() -> Array:
	var entries: Array = []
	for value in CharacterSelectData.get_characters():
		if not (value is Dictionary):
			continue
		var character: Dictionary = value
		var runtime_id: String = _normalize_runtime_id(character.get("runtime_id", character.get("id", "")))
		var raw_runtime: String = str(character.get("runtime_id", character.get("id", ""))).strip_edges().to_lower()
		if not SUPPORTED_RUNTIME_IDS.has(runtime_id):
			continue
		if runtime_id != raw_runtime and raw_runtime != "commando":
			continue
		var entry: Dictionary = character.duplicate(true)
		entry["_runtime_character_id"] = runtime_id
		entries.append(entry)
	if entries.is_empty():
		for fallback in FALLBACK_CHARACTERS:
			var fallback_entry: Dictionary = (fallback as Dictionary).duplicate(true)
			fallback_entry["_runtime_character_id"] = str(fallback_entry.get("runtime_id", "smasher"))
			entries.append(fallback_entry)
	return entries


func _move_selection(dx: int, dy: int, entry_count: int) -> void:
	if entry_count <= 0:
		return
	var columns: int = min(COLUMNS, max(1, entry_count))
	var row: int = int(floor(float(selected_index) / float(columns)))
	var col: int = selected_index % columns
	var rows: int = int(ceil(float(entry_count) / float(columns)))
	row = wrapi(row + dy, 0, rows)
	col = wrapi(col + dx, 0, columns)
	selected_index = clampi(row * columns + col, 0, entry_count - 1)


func _digit_to_index(key_event: InputEventKey, entry_count: int) -> int:
	for index in range(min(entry_count, 9)):
		var keycode: int = KEY_1 + index
		if _is_key(key_event, keycode):
			return index
	return -1


func _get_panel_rect(view_size: Vector2, entry_count: int) -> Rect2:
	var safe_view := Vector2(max(view_size.x, 760.0), max(view_size.y, 540.0))
	var columns: int = min(COLUMNS, max(1, entry_count))
	var rows: int = int(ceil(float(max(1, entry_count)) / float(max(1, columns))))
	var grid_size := Vector2(
		float(columns) * CARD_SIZE.x + float(max(0, columns - 1)) * CARD_GAP.x,
		float(rows) * CARD_SIZE.y + float(max(0, rows - 1)) * CARD_GAP.y
	)
	var panel_size := grid_size + PANEL_PADDING * 2.0 + Vector2(0.0, HEADER_HEIGHT + 30.0)
	var pos := (safe_view - panel_size) * 0.5
	return Rect2(Vector2(max(pos.x, 12.0), max(pos.y, 12.0)), panel_size)


func _get_card_rect(index: int, panel_rect: Rect2) -> Rect2:
	var columns: int = min(COLUMNS, max(1, _get_entries().size()))
	var row: int = int(floor(float(index) / float(columns)))
	var col: int = index % columns
	var origin := panel_rect.position + Vector2(PANEL_PADDING.x, PANEL_PADDING.y + HEADER_HEIGHT)
	return Rect2(origin + Vector2(col * (CARD_SIZE.x + CARD_GAP.x), row * (CARD_SIZE.y + CARD_GAP.y)), CARD_SIZE)


func _get_card_index_at(position: Vector2, view_size: Vector2, entry_count: int) -> int:
	var panel_rect: Rect2 = _get_panel_rect(view_size, entry_count)
	for index in range(entry_count):
		if _get_card_rect(index, panel_rect).has_point(position):
			return index
	return -1


func _get_character_index(runtime_id: String) -> int:
	var entries: Array = _get_entries()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if str(entry.get("_runtime_character_id", "")) == runtime_id:
			return index
	return 0


func _get_current_runtime_character(owner: Object) -> String:
	if owner != null:
		var owner_value: Variant = owner.get("selected_character_type")
		if owner_value != null:
			return _normalize_runtime_id(owner_value)
		if owner.has_method("get_node_or_null"):
			var selection_state: Node = owner.get_node_or_null("/root/GameSelectionState")
			if selection_state != null and selection_state.has_method("get_selection"):
				var selection: Dictionary = selection_state.get_selection()
				return _normalize_runtime_id(selection.get("runtime_character_id", "smasher"))
	return "smasher"


func _normalize_runtime_id(value: Variant) -> String:
	if character_runtime != null and character_runtime.has_method("normalize"):
		return str(character_runtime.normalize(value))
	return "smasher"


func _get_entry_display_name(entry: Dictionary) -> String:
	var runtime_id: String = str(entry.get("_runtime_character_id", entry.get("runtime_id", "")))
	return _get_runtime_display_name(runtime_id)


func _get_runtime_display_name(runtime_id: String) -> String:
	match runtime_id:
		"soldier":
			return "\ucf54\ub9cc\ub3c4"
		"optimus":
			return "\uc774\uc624"
		"viper":
			return "\ubc14\uc774\ud37c"
		"blacksmith":
			return "\ucf54\ud558\ucfe0"
	return "\uc2a4\ub9e4\uc154"


func _get_runtime_label(runtime_id: String) -> String:
	match runtime_id:
		"soldier":
			return "\uc804\uc220 \uc7a5\ube44 / \ucd1d\uae30"
		"optimus":
			return "\ubc30\ud130\ub9ac / \uac00\ubcc0 \ud328\ub4e4"
		"viper":
			return "\uadfc\uc811 \uc5f0\uacc4 / \uae30\ub3d9"
		"blacksmith":
			return "\ud1a0\ub974\uc274\ub4dc / \uac74\uc124"
	return "\ucd94\uc9c4 \ub4dc\ub77c\uc774\ube0c / \uc624\ube0c"


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
	return Color(0.35, 0.78, 1.0)
