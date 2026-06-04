extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const COLUMNS := 3
const CARD_SIZE := Vector2(214.0, 112.0)
const CARD_GAP := Vector2(14.0, 14.0)
const PANEL_PADDING := Vector2(28.0, 24.0)
const HEADER_HEIGHT := 78.0
const SKILL_SECTION_HEIGHT := 156.0
const SKILL_COLUMN_GAP := 18.0
const SKILL_ROW_HEIGHT := 28.0
const SKILL_ROW_GAP := 6.0
const SKILL_LEVEL_BUTTON_SIZE := Vector2(18.0, 18.0)
const SKILL_LEVEL_LABEL_SIZE := Vector2(36.0, 18.0)
const SKILL_LEVEL_CONTROL_GAP := 3.0
const APPLY_BUTTON_SIZE := Vector2(128.0, 34.0)

var open := false
var selected_index := 0
var hovered_index := -1
var selected_active_skill_index := 0
var selected_passive_skill_index := 0
var selected_active_skill_level := LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL
var selected_passive_skill_level := LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
var _texture_cache: Dictionary = {}
var _entries_cache: Array = []
var _entries_cache_ready := false
var _entries_cache_build_count := 0
var _active_skill_pool_cache: Dictionary = {}
var _passive_skill_pool_cache: Dictionary = {}


func toggle(owner: Object = null) -> void:
	open = not open
	if open:
		selected_index = _get_pet_index(_get_current_pet_id(owner))
		hovered_index = -1
		_sync_skill_selection_to_current_loadout(owner)
		_prewarm_card_textures()


func close() -> void:
	open = false
	hovered_index = -1


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
			_sync_skill_selection_to_current_loadout(owner)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_LEFT) or _is_key(key_event, KEY_A):
			_move_selection(-1, 0, entries.size())
			_sync_skill_selection_to_current_loadout(owner)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_DOWN) or _is_key(key_event, KEY_S):
			_move_selection(0, 1, entries.size())
			_sync_skill_selection_to_current_loadout(owner)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_UP) or _is_key(key_event, KEY_W):
			_move_selection(0, -1, entries.size())
			_sync_skill_selection_to_current_loadout(owner)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_Q):
			_cycle_active_skill(-1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_E):
			_cycle_active_skill(1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_Z):
			_cycle_passive_skill(-1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_X):
			_cycle_passive_skill(1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_F):
			_adjust_active_skill_level(-1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_R):
			_adjust_active_skill_level(1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_C):
			_adjust_passive_skill_level(-1)
			_request_owner_redraw(owner)
			return true
		if _is_key(key_event, KEY_V):
			_adjust_passive_skill_level(1)
			_request_owner_redraw(owner)
			return true
		var digit_index: int = _digit_to_index(key_event, entries.size())
		if digit_index >= 0:
			_select_pet_index(digit_index, owner)
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
		var active_level_delta := _get_skill_level_delta_at(mouse_event.position, view_size, entries.size(), true)
		if active_level_delta != 0:
			_adjust_active_skill_level(active_level_delta)
			_request_owner_redraw(owner)
			return true
		var passive_level_delta := _get_skill_level_delta_at(mouse_event.position, view_size, entries.size(), false)
		if passive_level_delta != 0:
			_adjust_passive_skill_level(passive_level_delta)
			_request_owner_redraw(owner)
			return true
		var active_skill_hit: int = _get_active_skill_index_at(mouse_event.position, view_size, entries.size())
		if active_skill_hit >= 0:
			selected_active_skill_index = active_skill_hit
			_request_owner_redraw(owner)
			return true
		var passive_skill_hit: int = _get_passive_skill_index_at(mouse_event.position, view_size, entries.size())
		if passive_skill_hit >= 0:
			selected_passive_skill_index = passive_skill_hit
			_request_owner_redraw(owner)
			return true
		if _get_apply_button_rect(view_size, entries.size()).has_point(mouse_event.position):
			_apply_selected_lingpet(owner, registry)
			return true
		var hit_index: int = _get_card_index_at(mouse_event.position, view_size, entries.size())
		if hit_index >= 0:
			_select_pet_index(hit_index, owner)
			return true
		if not _get_panel_rect(view_size, entries.size()).has_point(mouse_event.position):
			close()
		return true

	if event is InputEventMouseMotion:
		var hit_index: int = _get_card_index_at((event as InputEventMouseMotion).position, view_size, entries.size())
		if hovered_index != hit_index:
			hovered_index = hit_index
			_request_owner_redraw(owner)
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

	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 32.0), "F7 \ub9c1\ud3ab \ub514\ubc84\uadf8 \uc120\ud0dd", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.92, 0.97, 1.0))
	var info := "현재: %s  /  클릭·숫자: 링펫 선택, Q/E 액티브, Z/X 패시브, R/F 액티브 Lv, V/C 패시브 Lv, Enter 적용" % current_name
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 58.0), info, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 13, Color(0.74, 0.82, 0.90))

	for index in range(entries.size()):
		_draw_card(canvas, font, _get_card_rect(index, panel_rect), entries[index], index == selected_index, index == hovered_index, current_pet_id, index)

	var selected_pet_id := _get_selected_pet_id()
	_draw_skill_selection(canvas, font, view_size, selected_pet_id, entries.size())
	_draw_apply_button(canvas, font, _get_apply_button_rect(view_size, entries.size()))

	var footer := "\uc120\ud0dd\ud55c \ub9c1\ud3ab\uc740 \ubcf4\uc720 \ubaa9\ub85d\uacfc \uc804\ud22c \uc2ac\ub86f\uc5d0 \uc989\uc2dc \ub4f1\ub85d\ub418\uace0 \ud604\uc7ac \uc804\ud22c\uc5d0 \ubc14\ub85c \ub4f1\uc7a5\ud569\ub2c8\ub2e4."
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, panel_rect.size.y - 18.0), footer, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 12, Color(0.60, 0.68, 0.76))


func get_card_rect_for_tests(index: int, view_size: Vector2) -> Rect2:
	return _get_card_rect(index, _get_panel_rect(view_size, _get_entries().size()))


func get_pet_id_for_tests(index: int) -> String:
	var entries: Array = _get_entries()
	if index < 0 or index >= entries.size():
		return ""
	return str((entries[index] as Dictionary).get("id", ""))


func get_active_skill_rect_for_tests(index: int, view_size: Vector2) -> Rect2:
	return _get_skill_row_rect(view_size, _get_entries().size(), true, index)


func get_passive_skill_rect_for_tests(index: int, view_size: Vector2) -> Rect2:
	return _get_skill_row_rect(view_size, _get_entries().size(), false, index)


func get_apply_button_rect_for_tests(view_size: Vector2) -> Rect2:
	return _get_apply_button_rect(view_size, _get_entries().size())


func get_selected_pet_id_for_tests() -> String:
	return _get_selected_pet_id()


func get_active_skill_level_for_tests() -> int:
	return selected_active_skill_level


func get_passive_skill_level_for_tests() -> int:
	return selected_passive_skill_level


func get_active_skill_level_plus_rect_for_tests(view_size: Vector2) -> Rect2:
	return _get_skill_level_plus_rect(view_size, _get_entries().size(), true, selected_active_skill_index)


func get_passive_skill_level_plus_rect_for_tests(view_size: Vector2) -> Rect2:
	return _get_skill_level_plus_rect(view_size, _get_entries().size(), false, selected_passive_skill_index)


func get_entries_build_count_for_tests() -> int:
	return _entries_cache_build_count


func get_active_skill_id_for_tests(index: int = -1) -> String:
	var skill_index := selected_active_skill_index if index < 0 else index
	return _get_skill_id_from_pool(_get_skill_pool(_get_selected_pet_id(), true), skill_index)


func get_passive_skill_id_for_tests(index: int = -1) -> String:
	var skill_index := selected_passive_skill_index if index < 0 else index
	return _get_skill_id_from_pool(_get_skill_pool(_get_selected_pet_id(), false), skill_index)


func _draw_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	entry: Dictionary,
	selected: bool,
	hovered: bool,
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
	elif hovered:
		base = base.lerp(Color(tone.r * 0.18, tone.g * 0.18, tone.b * 0.20, 1.0), 0.40)
		border = Color(max(tone.r, 0.56), max(tone.g, 0.62), max(tone.b, 0.72), 0.92)

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


func _draw_skill_selection(canvas: CanvasItem, font: Font, view_size: Vector2, pet_id: String, entry_count: int) -> void:
	var rect := _get_skill_section_rect(view_size, entry_count)
	canvas.draw_rect(rect, Color(0.070, 0.084, 0.112, 0.92))
	canvas.draw_rect(rect, Color(0.42, 0.58, 0.78, 0.68), false, 1.0)
	canvas.draw_string(font, rect.position + Vector2(12.0, 23.0), "스킬 로드아웃: %s" % _get_display_name(pet_id, LingpetCatalog.get_entry(pet_id)), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 15, Color(0.88, 0.95, 1.0))

	var active_pool := _get_skill_pool(pet_id, true)
	var passive_pool := _get_skill_pool(pet_id, false)
	_draw_skill_rows(canvas, font, view_size, entry_count, true, active_pool, selected_active_skill_index, selected_active_skill_level)
	_draw_skill_rows(canvas, font, view_size, entry_count, false, passive_pool, selected_passive_skill_index, selected_passive_skill_level)


func _draw_skill_rows(canvas: CanvasItem, font: Font, view_size: Vector2, entry_count: int, active_column: bool, pool: Array, selected_skill_index: int, selected_skill_level: int) -> void:
	var column_rect := _get_skill_column_rect(view_size, entry_count, active_column)
	var label := "액티브 스킬 1개 · R/F 레벨" if active_column else "패시브 스킬 1개 · V/C 레벨"
	canvas.draw_string(font, column_rect.position + Vector2(0.0, 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, column_rect.size.x, 13, Color(0.78, 0.88, 0.96))
	if pool.is_empty():
		var disabled_rect := _get_skill_row_rect(view_size, entry_count, active_column, 0)
		canvas.draw_rect(disabled_rect, Color(0.02, 0.025, 0.034, 0.58))
		canvas.draw_rect(disabled_rect, Color(0.22, 0.28, 0.36, 0.72), false, 1.0)
		canvas.draw_string(font, disabled_rect.position + Vector2(10.0, 19.0), "선택 가능한 스킬 없음", HORIZONTAL_ALIGNMENT_LEFT, disabled_rect.size.x - 20.0, 12, Color(0.52, 0.60, 0.68))
		return
	for index in range(pool.size()):
		var skill := pool[index] as Dictionary
		var row_rect := _get_skill_row_rect(view_size, entry_count, active_column, index)
		var selected := index == selected_skill_index
		var row_base := Color(0.12, 0.16, 0.22, 0.94)
		var row_border := Color(0.28, 0.38, 0.52, 0.82)
		if selected:
			row_base = Color(0.16, 0.30, 0.40, 0.98) if active_column else Color(0.22, 0.24, 0.34, 0.98)
			row_border = Color(0.48, 0.86, 1.0, 0.98) if active_column else Color(0.82, 0.76, 1.0, 0.98)
		canvas.draw_rect(row_rect, row_base)
		canvas.draw_rect(row_rect, row_border, false, 1.0)
		var name := str(skill.get("name", skill.get("id", "")))
		var cooldown := float(skill.get("cooldown", 0.0))
		var suffix := (" / %.0f초" % cooldown) if active_column and cooldown > 0.0 else ""
		var text_color := Color(0.95, 0.99, 1.0) if selected else Color(0.72, 0.80, 0.88)
		var text_width := row_rect.size.x - (100.0 if selected else 20.0)
		canvas.draw_string(font, row_rect.position + Vector2(10.0, 19.0), "%s%s" % [name, suffix], HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, text_color)
		if selected:
			_draw_skill_level_controls(canvas, font, view_size, entry_count, active_column, index, selected_skill_level)


func _draw_skill_level_controls(canvas: CanvasItem, font: Font, view_size: Vector2, entry_count: int, active_column: bool, row_index: int, level: int) -> void:
	var minus_rect := _get_skill_level_minus_rect(view_size, entry_count, active_column, row_index)
	var label_rect := _get_skill_level_label_rect(view_size, entry_count, active_column, row_index)
	var plus_rect := _get_skill_level_plus_rect(view_size, entry_count, active_column, row_index)
	_draw_level_button(canvas, font, minus_rect, "-", level > LingpetCatalog.SKILL_LEVEL_MIN)
	canvas.draw_rect(label_rect, Color(0.02, 0.03, 0.045, 0.78))
	canvas.draw_rect(label_rect, Color(0.42, 0.56, 0.72, 0.74), false, 1.0)
	canvas.draw_string(font, label_rect.position + Vector2(0.0, 14.0), "Lv.%d" % LingpetCatalog.clamp_skill_level(level), HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, 10, Color(0.94, 0.98, 1.0))
	_draw_level_button(canvas, font, plus_rect, "+", level < LingpetCatalog.SKILL_LEVEL_MAX)


func _draw_level_button(canvas: CanvasItem, font: Font, rect: Rect2, text: String, enabled: bool) -> void:
	var fill := Color(0.12, 0.18, 0.24, 0.94) if enabled else Color(0.06, 0.07, 0.09, 0.62)
	var border := Color(0.62, 0.84, 1.0, 0.86) if enabled else Color(0.25, 0.30, 0.36, 0.62)
	var text_color := Color(0.96, 1.0, 1.0) if enabled else Color(0.46, 0.52, 0.58)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 1.0)
	canvas.draw_string(font, rect.position + Vector2(0.0, 14.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, text_color)


func _draw_apply_button(canvas: CanvasItem, font: Font, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(0.18, 0.38, 0.48, 0.96))
	canvas.draw_rect(rect, Color(0.62, 0.92, 1.0, 0.98), false, 1.5)
	canvas.draw_string(font, rect.position + Vector2(0.0, 23.0), "적용", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color(0.94, 1.0, 1.0))


func _apply_selected_lingpet(owner: Object, registry: Object) -> void:
	var entries: Array = _get_entries()
	if selected_index < 0 or selected_index >= entries.size():
		return
	var pet_id := str((entries[selected_index] as Dictionary).get("id", ""))
	var runtime := _get_instance(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("debug_grant_and_activate_pet"):
		runtime.debug_grant_and_activate_pet(
			pet_id,
			owner,
			true,
			_get_selected_active_skill_id(pet_id),
			_get_selected_passive_skill_id(pet_id),
			registry,
			selected_active_skill_level,
			selected_passive_skill_level
		)
	close()
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_entries() -> Array:
	if _entries_cache_ready:
		return _entries_cache
	var entries: Array = []
	for pet_id in LingpetCatalog.get_pet_ids(false):
		var normalized := str(pet_id)
		var entry := LingpetCatalog.get_entry(normalized).duplicate(true)
		entry["id"] = normalized
		entries.append(entry)
	_entries_cache = entries
	_entries_cache_ready = true
	_entries_cache_build_count += 1
	return _entries_cache


func _get_skill_pool(pet_id: String, active_skill: bool) -> Array:
	var normalized := pet_id.strip_edges().to_lower()
	var cache: Dictionary = _active_skill_pool_cache if active_skill else _passive_skill_pool_cache
	if cache.has(normalized):
		var cached: Variant = cache.get(normalized)
		if cached is Array:
			return cached as Array
	var pool: Array = (
		LingpetCatalog.get_active_skill_pool(normalized)
		if active_skill
		else LingpetCatalog.get_passive_skill_pool(normalized)
	)
	cache[normalized] = pool
	return pool


func _prewarm_card_textures() -> void:
	for entry_value in _get_entries():
		var entry := entry_value as Dictionary
		var visuals := entry.get("visuals", {}) as Dictionary
		_get_texture(str(visuals.get("companion_walk", "")))


func _select_pet_index(index: int, owner: Object) -> void:
	var entries := _get_entries()
	if entries.is_empty():
		selected_index = 0
		selected_active_skill_index = 0
		selected_passive_skill_index = 0
		return
	var next_index := clampi(index, 0, entries.size() - 1)
	if selected_index != next_index:
		selected_index = next_index
		_sync_skill_selection_to_current_loadout(owner)
		_request_owner_redraw(owner)


func _cycle_active_skill(direction: int) -> void:
	var pool := _get_skill_pool(_get_selected_pet_id(), true)
	selected_active_skill_index = _cycle_skill_index(selected_active_skill_index, direction, pool.size())


func _cycle_passive_skill(direction: int) -> void:
	var pool := _get_skill_pool(_get_selected_pet_id(), false)
	selected_passive_skill_index = _cycle_skill_index(selected_passive_skill_index, direction, pool.size())


func _adjust_active_skill_level(direction: int) -> void:
	selected_active_skill_level = _adjust_skill_level(selected_active_skill_level, direction)


func _adjust_passive_skill_level(direction: int) -> void:
	selected_passive_skill_level = _adjust_skill_level(selected_passive_skill_level, direction)


func _adjust_skill_level(current_level: int, direction: int) -> int:
	return LingpetCatalog.clamp_skill_level(current_level + direction)


func _cycle_skill_index(current_index: int, direction: int, pool_size: int) -> int:
	if pool_size <= 0:
		return 0
	return wrapi(current_index + direction, 0, pool_size)


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


func _sync_skill_selection_to_current_loadout(owner: Object) -> void:
	var pet_id := _get_selected_pet_id()
	var active_pool := _get_skill_pool(pet_id, true)
	var passive_pool := _get_skill_pool(pet_id, false)
	var active_index := _find_skill_index(active_pool, _get_stored_skill_id(owner, pet_id, true))
	var passive_index := _find_skill_index(passive_pool, _get_stored_skill_id(owner, pet_id, false))
	selected_active_skill_index = clampi(active_index if active_index >= 0 else 0, 0, max(0, active_pool.size() - 1))
	selected_passive_skill_index = clampi(passive_index if passive_index >= 0 else 0, 0, max(0, passive_pool.size() - 1))
	selected_active_skill_level = _get_stored_skill_level(owner, pet_id, true)
	selected_passive_skill_level = _get_stored_skill_level(owner, pet_id, false)


func _get_selected_pet_id() -> String:
	var entries: Array = _get_entries()
	if selected_index < 0 or selected_index >= entries.size():
		return ""
	return str((entries[selected_index] as Dictionary).get("id", ""))


func _get_selected_active_skill_id(pet_id: String) -> String:
	return _get_skill_id_from_pool(_get_skill_pool(pet_id, true), selected_active_skill_index)


func _get_selected_passive_skill_id(pet_id: String) -> String:
	return _get_skill_id_from_pool(_get_skill_pool(pet_id, false), selected_passive_skill_index)


func _get_stored_skill_id(owner: Object, pet_id: String, active_skill: bool) -> String:
	if owner == null or pet_id == "":
		return ""
	var loadout_key := "active_skill_id" if active_skill else "passive_skill_id"
	for collection_key in ["lingpet_loadouts", "ringpet_loadouts", "owned_lingpet_loadouts", "owned_ringpet_loadouts"]:
		var collection_value: Variant = owner.get(str(collection_key))
		if not (collection_value is Dictionary):
			continue
		var loadout_value: Variant = (collection_value as Dictionary).get(pet_id, {})
		if not (loadout_value is Dictionary):
			continue
		var stored_id := str((loadout_value as Dictionary).get(loadout_key, ""))
		if stored_id.strip_edges() != "":
			return stored_id
	if _get_current_pet_id(owner) == pet_id:
		var active_keys := ["lingpet_active_skill_id", "ringpet_active_skill_id"] if active_skill else ["lingpet_passive_skill_id", "ringpet_passive_skill_id"]
		for key in active_keys:
			var value: Variant = owner.get(str(key))
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()
	return ""


func _get_stored_skill_level(owner: Object, pet_id: String, active_skill: bool) -> int:
	var fallback := LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL if active_skill else LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
	if owner == null or pet_id == "":
		return fallback
	var loadout_key := "active_skill_level" if active_skill else "passive_skill_level"
	for collection_key in ["lingpet_loadouts", "ringpet_loadouts", "owned_lingpet_loadouts", "owned_ringpet_loadouts"]:
		var collection_value: Variant = owner.get(str(collection_key))
		if not (collection_value is Dictionary):
			continue
		var loadout_value: Variant = (collection_value as Dictionary).get(pet_id, {})
		if not (loadout_value is Dictionary):
			continue
		return LingpetCatalog.clamp_skill_level(int((loadout_value as Dictionary).get(loadout_key, fallback)))
	if _get_current_pet_id(owner) == pet_id:
		var level_keys := ["lingpet_active_skill_level", "ringpet_active_skill_level"] if active_skill else ["lingpet_passive_skill_level", "ringpet_passive_skill_level"]
		for key in level_keys:
			var value: Variant = owner.get(str(key))
			if value != null and int(value) > 0:
				return LingpetCatalog.clamp_skill_level(int(value))
	return fallback


func _find_skill_index(pool: Array, skill_id: String) -> int:
	var normalized := skill_id.strip_edges().to_lower()
	if normalized == "":
		return -1
	for index in range(pool.size()):
		var skill := pool[index] as Dictionary
		if str(skill.get("id", "")).strip_edges().to_lower() == normalized:
			return index
	return -1


func _get_skill_id_from_pool(pool: Array, index: int) -> String:
	if index < 0 or index >= pool.size():
		return ""
	var skill := pool[index] as Dictionary
	return str(skill.get("id", "")).strip_edges()


func _digit_to_index(key_event: InputEventKey, entry_count: int) -> int:
	for index in range(min(entry_count, 9)):
		var keycode: int = KEY_1 + index
		if _is_key(key_event, keycode):
			return index
	return -1


func _get_grid_size(entry_count: int) -> Vector2:
	var columns: int = min(COLUMNS, max(1, entry_count))
	var rows: int = int(ceil(float(max(1, entry_count)) / float(max(1, columns))))
	return Vector2(
		float(columns) * CARD_SIZE.x + float(max(0, columns - 1)) * CARD_GAP.x,
		float(rows) * CARD_SIZE.y + float(max(0, rows - 1)) * CARD_GAP.y
	)


func _get_panel_rect(view_size: Vector2, entry_count: int) -> Rect2:
	var safe_view := Vector2(max(view_size.x, 760.0), max(view_size.y, 540.0))
	var grid_size := _get_grid_size(entry_count)
	var panel_size := grid_size + PANEL_PADDING * 2.0 + Vector2(0.0, HEADER_HEIGHT + CARD_GAP.y + SKILL_SECTION_HEIGHT + 30.0)
	var pos := (safe_view - panel_size) * 0.5
	return Rect2(Vector2(max(pos.x, 12.0), max(pos.y, 12.0)), panel_size)


func _get_card_rect(index: int, panel_rect: Rect2) -> Rect2:
	var columns: int = min(COLUMNS, max(1, _entries_count()))
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


func _get_skill_section_rect(view_size: Vector2, entry_count: int) -> Rect2:
	var panel_rect := _get_panel_rect(view_size, entry_count)
	var grid_size := _get_grid_size(entry_count)
	var origin := panel_rect.position + Vector2(PANEL_PADDING.x, PANEL_PADDING.y + HEADER_HEIGHT + grid_size.y + CARD_GAP.y)
	return Rect2(origin, Vector2(grid_size.x, SKILL_SECTION_HEIGHT))


func _get_skill_column_rect(view_size: Vector2, entry_count: int, active_column: bool) -> Rect2:
	var section_rect := _get_skill_section_rect(view_size, entry_count)
	var inner := section_rect.grow(-12.0)
	inner.position.y += 27.0
	inner.size.y -= 27.0
	var column_width := (inner.size.x - SKILL_COLUMN_GAP) * 0.5
	var offset_x := 0.0 if active_column else column_width + SKILL_COLUMN_GAP
	return Rect2(inner.position + Vector2(offset_x, 0.0), Vector2(column_width, inner.size.y))


func _get_skill_row_rect(view_size: Vector2, entry_count: int, active_column: bool, index: int) -> Rect2:
	var column_rect := _get_skill_column_rect(view_size, entry_count, active_column)
	return Rect2(
		column_rect.position + Vector2(0.0, 24.0 + float(index) * (SKILL_ROW_HEIGHT + SKILL_ROW_GAP)),
		Vector2(column_rect.size.x, SKILL_ROW_HEIGHT)
	)


func _get_active_skill_index_at(position: Vector2, view_size: Vector2, entry_count: int) -> int:
	return _get_skill_index_at(position, view_size, entry_count, true, _get_skill_pool(_get_selected_pet_id(), true).size())


func _get_passive_skill_index_at(position: Vector2, view_size: Vector2, entry_count: int) -> int:
	return _get_skill_index_at(position, view_size, entry_count, false, _get_skill_pool(_get_selected_pet_id(), false).size())


func _get_skill_index_at(position: Vector2, view_size: Vector2, entry_count: int, active_column: bool, pool_size: int) -> int:
	for index in range(pool_size):
		if _get_skill_row_rect(view_size, entry_count, active_column, index).has_point(position):
			return index
	return -1


func _get_skill_level_delta_at(position: Vector2, view_size: Vector2, entry_count: int, active_column: bool) -> int:
	var pool_size := _get_skill_pool(_get_selected_pet_id(), active_column).size()
	if pool_size <= 0:
		return 0
	var row_index := selected_active_skill_index if active_column else selected_passive_skill_index
	row_index = clampi(row_index, 0, pool_size - 1)
	if _get_skill_level_minus_rect(view_size, entry_count, active_column, row_index).has_point(position):
		return -1
	if _get_skill_level_plus_rect(view_size, entry_count, active_column, row_index).has_point(position):
		return 1
	return 0


func _get_skill_level_minus_rect(view_size: Vector2, entry_count: int, active_column: bool, row_index: int) -> Rect2:
	var row_rect := _get_skill_row_rect(view_size, entry_count, active_column, row_index)
	var total_width := SKILL_LEVEL_BUTTON_SIZE.x * 2.0 + SKILL_LEVEL_LABEL_SIZE.x + SKILL_LEVEL_CONTROL_GAP * 2.0
	var pos := Vector2(row_rect.end.x - total_width - 8.0, row_rect.position.y + (row_rect.size.y - SKILL_LEVEL_BUTTON_SIZE.y) * 0.5)
	return Rect2(pos, SKILL_LEVEL_BUTTON_SIZE)


func _get_skill_level_label_rect(view_size: Vector2, entry_count: int, active_column: bool, row_index: int) -> Rect2:
	var minus_rect := _get_skill_level_minus_rect(view_size, entry_count, active_column, row_index)
	return Rect2(minus_rect.end + Vector2(SKILL_LEVEL_CONTROL_GAP, 0.0), SKILL_LEVEL_LABEL_SIZE)


func _get_skill_level_plus_rect(view_size: Vector2, entry_count: int, active_column: bool, row_index: int) -> Rect2:
	var label_rect := _get_skill_level_label_rect(view_size, entry_count, active_column, row_index)
	return Rect2(label_rect.end + Vector2(SKILL_LEVEL_CONTROL_GAP, 0.0), SKILL_LEVEL_BUTTON_SIZE)


func _get_apply_button_rect(view_size: Vector2, entry_count: int) -> Rect2:
	var section_rect := _get_skill_section_rect(view_size, entry_count)
	return Rect2(
		section_rect.position + Vector2(section_rect.size.x - APPLY_BUTTON_SIZE.x - 12.0, section_rect.size.y - APPLY_BUTTON_SIZE.y - 10.0),
		APPLY_BUTTON_SIZE
	)


func _get_pet_index(pet_id: String) -> int:
	var entries: Array = _get_entries()
	for index in range(entries.size()):
		if str((entries[index] as Dictionary).get("id", "")) == pet_id:
			return index
	return 0


func _entries_count() -> int:
	return _get_entries().size()


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
		"milkring":
			return "\ubc00\ud06c\ub9c1"
		"volty":
			return "볼티"
		"orbi":
			return "오르비"
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
		"milkring":
			return "\uc6b0\uc720 \ubd84\uc0ac \uc7a5\ube44\ub85c \uacf5 \ubc18\uaca9 + \uc7a5\ud310 \ubcf4\uc870"
		"volty":
			return "전기 호버 바디로 공 반격 + 돌진 보조"
		"orbi":
			return "푸른 링 궤도로 공 반격 + 둔화장 보조"
	return "\uc804\ud22c \ubcf4\uc870 \ub9c1\ud3ab"


func _get_card_color(pet_id: String) -> Color:
	match pet_id:
		"lunabi":
			return Color(0.72, 0.56, 1.0)
		"maribo":
			return Color(0.34, 0.78, 1.0)
		"milkring":
			return Color(0.74, 0.94, 1.0)
		"volty":
			return Color(0.98, 0.84, 0.22)
		"orbi":
			return Color(0.30, 1.0, 0.92)
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


func _request_owner_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
