extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const COLUMNS := 3
const CARD_SIZE := Vector2(214.0, 112.0)
const CARD_GAP := Vector2(14.0, 14.0)
const PANEL_PADDING := Vector2(28.0, 24.0)
const HEADER_HEIGHT := 78.0

var open := false
var selected_index := 0
var _texture_cache: Dictionary = {}


func toggle(owner: Object = null) -> void:
	open = not open
	if open:
		selected_index = _get_pet_index(_get_current_pet_id(owner))
		_prewarm_card_textures()


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
			_apply_selected_lingpet(owner, registry)
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
			_apply_selected_lingpet(owner, registry)
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
			_apply_selected_lingpet(owner, registry)
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


func draw(canvas: CanvasItem, owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var entries: Array = _get_entries()
	var panel_rect: Rect2 = _get_panel_rect(view_size, entries.size())
	var current_pet_id := _get_current_pet_id(owner)
	var current_name := _get_display_name(current_pet_id, {})

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.50))
	canvas.draw_rect(panel_rect, Color(0.035, 0.042, 0.060, 0.97))
	canvas.draw_rect(panel_rect, Color(0.72, 0.82, 1.0, 0.86), false, 2.0)

	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 32.0), "F10 \ub9c1\ud3ab \ub514\ubc84\uadf8 \uc120\ud0dd", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.92, 0.97, 1.0))
	var info := "\ud604\uc7ac: %s  /  \ud074\ub9ad \ub610\ub294 \uc22b\uc790\ud0a4\ub85c \uc989\uc2dc \ucd94\uac00, \ubc29\ud5a5\ud0a4\u00b7WASD \uc774\ub3d9, Esc \ub2eb\uae30" % current_name
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 58.0), info, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 13, Color(0.74, 0.82, 0.90))

	for index in range(entries.size()):
		_draw_card(canvas, font, _get_card_rect(index, panel_rect), entries[index], index == selected_index, current_pet_id, index)

	var footer := "\uc120\ud0dd\ud55c \ub9c1\ud3ab\uc740 \ubcf4\uc720 \ubaa9\ub85d\uacfc \uc804\ud22c \uc2ac\ub86f\uc5d0 \uc989\uc2dc \ub4f1\ub85d\ub418\uace0 \ud604\uc7ac \uc804\ud22c\uc5d0 \ubc14\ub85c \ub4f1\uc7a5\ud569\ub2c8\ub2e4."
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, panel_rect.size.y - 18.0), footer, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 12, Color(0.60, 0.68, 0.76))


func get_card_rect_for_tests(index: int, view_size: Vector2) -> Rect2:
	return _get_card_rect(index, _get_panel_rect(view_size, _get_entries().size()))


func get_pet_id_for_tests(index: int) -> String:
	var entries: Array = _get_entries()
	if index < 0 or index >= entries.size():
		return ""
	return str((entries[index] as Dictionary).get("id", ""))


func _draw_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	entry: Dictionary,
	selected: bool,
	current_pet_id: String,
	index: int
) -> void:
	var pet_id := str(entry.get("id", ""))
	var is_current := pet_id == current_pet_id
	var tone := _get_card_color(pet_id)
	var base := Color(0.095, 0.115, 0.155, 0.96)
	var border := Color(tone.r, tone.g, tone.b, 0.72)
	if is_current:
		base = base.lerp(Color(0.22, 0.22, 0.10, 1.0), 0.46)
		border = Color(1.0, 0.84, 0.30, 0.96)
	if selected:
		base = base.lerp(Color(tone.r * 0.32, tone.g * 0.32, tone.b * 0.36, 1.0), 0.68)
		border = Color(max(tone.r, 0.82), max(tone.g, 0.90), max(tone.b, 0.95), 1.0)

	canvas.draw_rect(rect, base)
	canvas.draw_rect(rect, border, false, 2.0 if selected else 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color(tone.r, tone.g, tone.b, 0.82))

	var thumb_rect := Rect2(rect.position + Vector2(12.0, 16.0), Vector2(54.0, 54.0))
	_draw_pet_thumbnail(canvas, thumb_rect, entry)
	canvas.draw_string(font, rect.position + Vector2(12.0, 94.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 13, Color(1.0, 0.86, 0.38))
	canvas.draw_string(font, rect.position + Vector2(72.0, 29.0), _get_display_name(pet_id, entry), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 84.0, 18, Color(0.95, 0.98, 1.0))
	canvas.draw_string(font, rect.position + Vector2(72.0, 50.0), _get_motion_label(pet_id, entry), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 84.0, 12, Color(0.72, 0.80, 0.88))
	canvas.draw_string(font, rect.position + Vector2(72.0, 70.0), _get_summary_text(pet_id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 84.0, 11, Color(0.62, 0.70, 0.78))
	if is_current:
		canvas.draw_string(font, rect.position + Vector2(rect.size.x - 64.0, 94.0), "\uc801\uc6a9\uc911", HORIZONTAL_ALIGNMENT_RIGHT, 52.0, 11, Color(1.0, 0.86, 0.36))


func _draw_pet_thumbnail(canvas: CanvasItem, rect: Rect2, entry: Dictionary) -> void:
	canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.22))
	var path := str((entry.get("visuals", {}) as Dictionary).get("companion_walk", ""))
	var texture := _get_texture(path)
	if texture == null:
		canvas.draw_circle(rect.position + rect.size * 0.5, rect.size.x * 0.32, Color(0.75, 0.82, 0.92, 0.70))
		return
	var frame_size := Vector2(texture.get_width() / 5.0, texture.get_height() / 5.0)
	var region := Rect2(Vector2.ZERO, frame_size)
	canvas.draw_texture_rect_region(texture, rect.grow(-3.0), region, Color(1.0, 1.0, 1.0, 1.0))


func _apply_selected_lingpet(owner: Object, registry: Object) -> void:
	var entries: Array = _get_entries()
	if selected_index < 0 or selected_index >= entries.size():
		return
	var pet_id := str((entries[selected_index] as Dictionary).get("id", ""))
	var runtime := _get_instance(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("debug_grant_and_activate_pet"):
		runtime.debug_grant_and_activate_pet(pet_id, owner, true)
	close()
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_entries() -> Array:
	var entries: Array = []
	for pet_id in LingpetCatalog.get_pet_ids(false):
		var normalized := str(pet_id)
		var entry := LingpetCatalog.get_entry(normalized)
		entry["id"] = normalized
		entries.append(entry)
	return entries


func _prewarm_card_textures() -> void:
	for entry_value in _get_entries():
		var entry := entry_value as Dictionary
		var visuals := entry.get("visuals", {}) as Dictionary
		_get_texture(str(visuals.get("companion_walk", "")))


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


func _get_pet_index(pet_id: String) -> int:
	var entries: Array = _get_entries()
	for index in range(entries.size()):
		if str((entries[index] as Dictionary).get("id", "")) == pet_id:
			return index
	return 0


func _get_current_pet_id(owner: Object) -> String:
	if owner == null:
		return ""
	for key in ["active_lingpet_id", "current_lingpet_id", "lingpet_id"]:
		var value: Variant = owner.get(str(key))
		if value != null and str(value).strip_edges() != "":
			return str(value).strip_edges().to_lower()
	return ""


func _get_display_name(pet_id: String, entry: Dictionary) -> String:
	match pet_id:
		"maribo":
			return "\ub9c8\ub9ac\ubcf4"
		"lunabi":
			return "\ub8e8\ub098\ube44"
	var fallback := str(entry.get("display_name", pet_id))
	return fallback if fallback.strip_edges() != "" else "\ubbf8\ud655\uc778 \ub9c1\ud3ab"


func _get_motion_label(pet_id: String, entry: Dictionary) -> String:
	var motion_style := str(entry.get("motion_style", LingpetCatalog.get_motion_style(pet_id))).strip_edges().to_lower()
	match motion_style:
		"sortie_flight":
			return "\ucd9c\uaca9 \ube44\ud589"
		"free_flight":
			return "\uc790\uc720 \ube44\ud589"
	return "\ud50c\ub808\uc774\uc5b4 \ud6c4\ubc29 \uc21c\ucc30"


func _get_summary_text(pet_id: String) -> String:
	match pet_id:
		"lunabi":
			return "\ud654\uba74\uc744 \uc790\uc720\ub86d\uac8c \ub0a0\uba70 \uacf5\uc744 \ubc18\uaca9"
		"maribo":
			return "\uacf5 \ubc18\uaca9 + \uac8c\uc774\uc9c0 \ud68d\ub4dd \ubcf4\uc870"
	return "\uc804\ud22c \ubcf4\uc870 \ub9c1\ud3ab"


func _get_card_color(pet_id: String) -> Color:
	match pet_id:
		"lunabi":
			return Color(0.72, 0.56, 1.0)
		"maribo":
			return Color(0.34, 0.78, 1.0)
	return Color(0.70, 0.82, 0.92)


func _get_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		var cached: Variant = _texture_cache.get(path)
		if cached is Texture2D:
			return cached
		return null
	var loaded: Variant = ResourceLoader.load(path)
	if loaded is Texture2D:
		_texture_cache[path] = loaded
		return loaded
	_texture_cache[path] = null
	return null


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
