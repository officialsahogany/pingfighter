extends RefCounted

const PANEL_MARGIN := 28.0
const PANEL_MAX_WIDTH := 1180.0
const HEADER_HEIGHT := 86.0
const CARD_HEIGHT := 54.0
const CARD_GAP := 8.0
const MIN_CARD_WIDTH := 208.0
const ICON_SIZE := 36.0

var open := false
var target_level := 1
var last_applied_id := ""
var last_applied_timer := 0.0


func toggle() -> void:
	open = not open
	if open:
		target_level = max(1, target_level)


func close() -> void:
	open = false


func is_open() -> bool:
	return open


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not open:
		return false
	var catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var entries: Array = _get_entries(catalog, owner)

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
			close()
			return true
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mouse_event.pressed:
				_adjust_target_level(mouse_event, entries, view_size)
			return true
		if not mouse_event.pressed:
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return true
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return true
		var panel_rect: Rect2 = _get_panel_rect(view_size, entries.size())
		if not panel_rect.has_point(mouse_event.position):
			close()
			return true
		var hit_index: int = _get_entry_index_at(mouse_event.position, view_size, entries)
		if hit_index >= 0:
			_apply_entry(entries[hit_index], owner, registry, catalog)
		return true

	if event is InputEventMouseMotion:
		return true

	return true


func update(delta: float) -> void:
	if last_applied_timer > 0.0:
		last_applied_timer = max(0.0, last_applied_timer - delta)


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	var icon_renderer: Object = _get_instance(registry, "runtime_perk_icon_renderer")
	var entries: Array = _get_entries(catalog, owner)
	var panel_rect: Rect2 = _get_panel_rect(view_size, entries.size())
	var layout: Dictionary = _build_grid_layout(panel_rect, entries.size())
	var mouse_pos: Vector2 = _get_mouse_position(canvas)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.40))
	canvas.draw_rect(panel_rect, Color(0.035, 0.045, 0.070, 0.96))
	canvas.draw_rect(panel_rect, Color(0.30, 0.78, 1.0, 0.90), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var title_pos: Vector2 = panel_rect.position + Vector2(18.0, 30.0)
	canvas.draw_string(font, title_pos, "F4 Perk Debug", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.84, 0.96, 1.0))
	canvas.draw_string(font, panel_rect.position + Vector2(18.0, 52.0), "Click a perk to apply. Mouse wheel changes target level. Right click / Esc closes.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.70, 0.77, 0.84))
	var level_text := "Target Lv.%d" % target_level
	var level_size: Vector2 = font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18)
	canvas.draw_string(font, panel_rect.position + Vector2(panel_rect.size.x - level_size.x - 18.0, 32.0), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.84, 0.28))

	var levels: Dictionary = _get_runtime_levels(runtime_state, owner)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var card_rect: Rect2 = _get_card_rect(index, panel_rect, layout)
		var hovered: bool = card_rect.has_point(mouse_pos)
		_draw_card(canvas, font, card_rect, entry, hovered, levels, icon_renderer)


func _draw_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	entry: Dictionary,
	hovered: bool,
	levels: Dictionary,
	icon_renderer: Object
) -> void:
	var perk_id: String = str(entry.get("id", ""))
	var max_level: int = int(entry.get("max_level", 1))
	var owned_level: int = int(levels.get(perk_id, 0))
	var apply_level: int = _get_apply_level_for_entry(entry)
	var is_last: bool = perk_id == last_applied_id and last_applied_timer > 0.0
	var base := Color(0.105, 0.125, 0.165, 0.96)
	if hovered:
		base = Color(0.14, 0.20, 0.27, 0.98)
	if is_last:
		base = base.lerp(Color(0.24, 0.34, 0.20, 1.0), 0.55)
	canvas.draw_rect(rect, base)
	canvas.draw_rect(rect, Color(0.25, 0.39, 0.52, 0.72), false, 1.0)

	var icon_rect := Rect2(rect.position + Vector2(9.0, (rect.size.y - ICON_SIZE) * 0.5), Vector2(ICON_SIZE, ICON_SIZE))
	var drew_icon := false
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		drew_icon = bool(icon_renderer.draw_icon(canvas, perk_id, icon_rect, 1.0, true))
	if not drew_icon:
		var color: Color = _get_color(entry.get("icon_color", Color(0.5, 0.8, 1.0)), Color(0.5, 0.8, 1.0))
		canvas.draw_circle(icon_rect.get_center(), ICON_SIZE * 0.40, color)
		canvas.draw_circle(icon_rect.get_center() + Vector2(-5.0, -6.0), 3.0, Color(1.0, 1.0, 1.0, 0.28))

	var text_x: float = rect.position.x + 53.0
	var title: String = str(entry.get("name", perk_id)).strip_edges()
	if title.is_empty():
		title = perk_id
	canvas.draw_string(font, Vector2(text_x, rect.position.y + 20.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 106.0, 13, Color(0.94, 0.98, 1.0))
	var group: String = str(entry.get("debug_group", entry.get("tree", "")))
	var status: String = group
	if max_level <= 0 or bool(entry.get("is_instant", false)):
		status += " / instant"
	else:
		status += " / own %d -> Lv.%d/%d" % [owned_level, apply_level, max_level]
	canvas.draw_string(font, Vector2(text_x, rect.position.y + 39.0), status, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 106.0, 11, Color(0.68, 0.75, 0.83))

	var level_badge: String = "GO" if max_level <= 0 or bool(entry.get("is_instant", false)) else "Lv.%d" % apply_level
	var badge_size: Vector2 = font.get_string_size(level_badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
	var badge_rect := Rect2(rect.position + Vector2(rect.size.x - badge_size.x - 18.0, rect.size.y * 0.5 - 12.0), Vector2(badge_size.x + 10.0, 22.0))
	canvas.draw_rect(badge_rect, Color(0.05, 0.09, 0.13, 0.92))
	canvas.draw_rect(badge_rect, Color(1.0, 0.84, 0.30, 0.82), false, 1.0)
	canvas.draw_string(font, badge_rect.position + Vector2(5.0, 15.0), level_badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.86, 0.36))


func _apply_entry(entry: Dictionary, owner: Object, registry: Object, catalog: Object) -> void:
	var runtime_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("debug_set_perk_level"):
		return
	var perk_id: String = str(entry.get("id", ""))
	var applied: bool = bool(runtime_state.debug_set_perk_level(perk_id, _get_apply_level_for_entry(entry), owner, registry, catalog))
	if applied:
		last_applied_id = perk_id
		last_applied_timer = 0.65


func _adjust_target_level(mouse_event: InputEventMouseButton, entries: Array, view_size: Vector2) -> void:
	var index: int = _get_entry_index_at(mouse_event.position, view_size, entries)
	var max_level: int = 5
	if index >= 0:
		max_level = max(1, int(entries[index].get("max_level", 1)))
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		target_level = min(max_level, target_level + 1)
	else:
		target_level = max(1, target_level - 1)


func _get_apply_level_for_entry(entry: Dictionary) -> int:
	var max_level: int = max(0, int(entry.get("max_level", 1)))
	if max_level <= 0 or bool(entry.get("is_instant", false)):
		return 0
	return clampi(target_level, 1, max_level)


func _get_entry_index_at(position: Vector2, view_size: Vector2, entries: Array) -> int:
	var panel_rect: Rect2 = _get_panel_rect(view_size, entries.size())
	var layout: Dictionary = _build_grid_layout(panel_rect, entries.size())
	for index in range(entries.size()):
		if _get_card_rect(index, panel_rect, layout).has_point(position):
			return index
	return -1


func _get_entries(catalog: Object, owner: Object) -> Array:
	if catalog != null and catalog.has_method("get_debug_perk_entries"):
		return catalog.get_debug_perk_entries(_get_character_type(owner))
	return []


func _get_panel_rect(view_size: Vector2, entry_count: int) -> Rect2:
	var width: float = min(PANEL_MAX_WIDTH, max(520.0, view_size.x - PANEL_MARGIN * 2.0))
	var columns: int = _get_column_count(width)
	var rows: int = int(ceil(float(max(1, entry_count)) / float(max(1, columns))))
	var content_height: float = HEADER_HEIGHT + float(rows) * CARD_HEIGHT + float(max(0, rows - 1)) * CARD_GAP + 24.0
	var height: float = min(max(360.0, content_height), max(360.0, view_size.y - PANEL_MARGIN * 2.0))
	var x: float = floor((view_size.x - width) * 0.5)
	var y: float = floor((view_size.y - height) * 0.5)
	return Rect2(Vector2(x, y), Vector2(width, height))


func _build_grid_layout(panel_rect: Rect2, entry_count: int) -> Dictionary:
	var columns: int = _get_column_count(panel_rect.size.x)
	var inner_width: float = panel_rect.size.x - 24.0
	var card_width: float = floor((inner_width - float(columns - 1) * CARD_GAP) / float(columns))
	var rows: int = int(ceil(float(max(1, entry_count)) / float(columns)))
	var available_height: float = max(160.0, panel_rect.size.y - HEADER_HEIGHT - 22.0)
	var row_height: float = min(CARD_HEIGHT, floor((available_height - float(max(0, rows - 1)) * CARD_GAP) / float(max(1, rows))))
	row_height = max(42.0, row_height)
	return {
		"columns": columns,
		"card_width": card_width,
		"row_height": row_height,
	}


func _get_card_rect(index: int, panel_rect: Rect2, layout: Dictionary) -> Rect2:
	var columns: int = max(1, int(layout.get("columns", 3)))
	var column: int = index % columns
	@warning_ignore("integer_division")
	var row: int = int(index / columns)
	var card_width: float = float(layout.get("card_width", MIN_CARD_WIDTH))
	var row_height: float = float(layout.get("row_height", CARD_HEIGHT))
	var x: float = panel_rect.position.x + 12.0 + float(column) * (card_width + CARD_GAP)
	var y: float = panel_rect.position.y + HEADER_HEIGHT + float(row) * (row_height + CARD_GAP)
	return Rect2(Vector2(x, y), Vector2(card_width, row_height))


func _get_column_count(width: float) -> int:
	return clampi(int(floor((width - 24.0 + CARD_GAP) / (MIN_CARD_WIDTH + CARD_GAP))), 3, 5)


func _get_runtime_levels(runtime_state: Object, owner: Object) -> Dictionary:
	if runtime_state != null and runtime_state.has_method("get_snapshot"):
		var snapshot: Variant = runtime_state.get_snapshot()
		if snapshot is Dictionary:
			var levels: Variant = snapshot.get("runtime_skill_levels", {})
			if levels is Dictionary:
				return levels
	if owner != null:
		var owner_levels: Variant = owner.get("runtime_perk_levels")
		if owner_levels is Dictionary:
			return owner_levels
	return {}


func _get_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	return str(value)


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	var viewport: Viewport = canvas.get_viewport()
	if viewport == null:
		return Vector2(-9999.0, -9999.0)
	return viewport.get_mouse_position()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
