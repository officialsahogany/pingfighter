extends RefCounted

const ActiveItemHudSlotIconRenderer := preload("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")
const ActiveItemHudVisuals := preload("res://scripts/hud/active_item_hud_visuals.gd")
const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")

const PANEL_MARGIN := 28.0
const PANEL_WIDTH := 620.0
const HEADER_HEIGHT := 82.0
const TAB_HEIGHT := 34.0
const GRID_COLUMNS := 10
const GRID_ROWS := 10
const GRID_CAPACITY := GRID_COLUMNS * GRID_ROWS
const GRID_DEFAULT_CELL_SIZE := 44.0
const GRID_MIN_CELL_SIZE := 24.0
const GRID_GAP := 6.0
const GRID_SIDE_PADDING := 18.0
const GRID_TOP_PADDING := 18.0
const GRID_BOTTOM_PADDING := 18.0
const ICON_PADDING := 7.0
const ROLL_EDITOR_WIDTH := 300.0
const ROLL_EDITOR_HEADER_HEIGHT := 64.0
const ROLL_EDITOR_ROW_HEIGHT := 42.0
const ROLL_EDITOR_BUTTON_SIZE := Vector2(28.0, 24.0)
const DEBUG_ACTION_GRANT := "grant"
const DEBUG_ACTION_SPAWN := "spawn"
const DEBUG_ACTION_BUTTON_SIZE := Vector2(82.0, 24.0)
const DEBUG_ACTION_BUTTON_GAP := 8.0

var open := false
var selected_tab := 0
var action_mode := DEBUG_ACTION_GRANT
var icon_renderer: Object = ActiveItemHudSlotIconRenderer.new()
var icon_visuals: Object = ActiveItemHudVisuals.new()
var roll_editor_open := false
var roll_editor_inventory_index := -1
var roll_editor_item_name := ""
var debug_roll_overrides: Dictionary = {}
var _icons_prewarmed := false


func reset() -> void:
	open = false
	selected_tab = 0
	action_mode = DEBUG_ACTION_GRANT
	_close_roll_editor()


func toggle(initial_tab: int = 0) -> void:
	open = not open
	if open:
		selected_tab = clampi(initial_tab, 0, 1)


func prewarm_assets(runtime: Object = null) -> void:
	if _icons_prewarmed:
		return
	_icons_prewarmed = true
	if icon_visuals != null and icon_visuals.has_method("prewarm_catalog_icons"):
		icon_visuals.prewarm_catalog_icons()
	var items: Array = _get_debug_items(runtime)
	if icon_renderer != null and icon_renderer.has_method("prewarm_item_icons"):
		icon_renderer.prewarm_item_icons(items, icon_visuals)
		return
	for item_value in items:
		var item_data: Dictionary = _get_dict(item_value)
		if item_data.is_empty():
			continue
		if icon_visuals != null and icon_visuals.has_method("get_icon_texture"):
			var texture: Variant = icon_visuals.get_icon_texture(item_data)
			if texture is Texture2D:
				var texture_2d: Texture2D = texture as Texture2D
				texture_2d.get_size()


func close() -> void:
	open = false
	_close_roll_editor()


func is_open() -> bool:
	return open


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not open:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		var keycode: int = key_event.keycode
		var physical_keycode: int = key_event.physical_keycode
		if keycode == KEY_ESCAPE or physical_keycode == KEY_ESCAPE:
			if roll_editor_open:
				_close_roll_editor()
				_queue_owner_redraw(owner)
				return true
			close()
			return true
		if keycode == KEY_TAB or physical_keycode == KEY_TAB:
			selected_tab = (selected_tab + 1) % 2
			_close_roll_editor()
			return true
		if keycode == KEY_1 or physical_keycode == KEY_1:
			selected_tab = 0
			_close_roll_editor()
			return true
		if keycode == KEY_2 or physical_keycode == KEY_2:
			selected_tab = 1
			_close_roll_editor()
			return true
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed:
			return true
		var panel_rect: Rect2 = _get_panel_rect(view_size)
		var runtime: Object = _get_runtime(registry)
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var wheel_delta := 1 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if roll_editor_open and runtime != null:
				if _adjust_roll_from_editor_position(mouse_event.position, panel_rect, runtime, owner, registry, wheel_delta):
					_queue_owner_redraw(owner)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if roll_editor_open and _get_roll_editor_rect(panel_rect, runtime).has_point(mouse_event.position):
				_close_roll_editor()
				_queue_owner_redraw(owner)
				return true
			if runtime != null and _open_roll_editor_at(mouse_event.position, panel_rect, runtime, owner, registry):
				_queue_owner_redraw(owner)
				return true
			if not panel_rect.has_point(mouse_event.position):
				close()
				return true
			_close_roll_editor()
			_queue_owner_redraw(owner)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and roll_editor_open and runtime != null:
			if _handle_roll_editor_left_click(mouse_event.position, panel_rect, runtime, owner, registry):
				_queue_owner_redraw(owner)
				return true
			if _get_roll_editor_rect(panel_rect, runtime).has_point(mouse_event.position):
				return true
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return true
		var action_index: int = _get_action_button_index_at(mouse_event.position, panel_rect)
		if action_index >= 0:
			action_mode = _get_action_mode_for_index(action_index)
			_queue_owner_redraw(owner)
			return true
		for tab_index in range(2):
			if _get_tab_rect(panel_rect, tab_index).has_point(mouse_event.position):
				selected_tab = tab_index
				_close_roll_editor()
				return true
		if not panel_rect.has_point(mouse_event.position):
			close()
			return true
		if runtime == null:
			return true
		var items: Array = _get_selected_tab_items(runtime)
		var hit_item_index: int = _get_cell_index_at(mouse_event.position, panel_rect)
		if hit_item_index >= 0 and hit_item_index < items.size() and runtime.has_method("debug_add_item_to_inventory"):
			var item_data: Dictionary = _get_dict(items[hit_item_index])
			var item_name: String = str(item_data.get("name", ""))
			if action_mode == DEBUG_ACTION_SPAWN:
				_debug_spawn_item_from_menu(item_data, runtime, owner, registry)
			else:
				runtime.debug_add_item_to_inventory(item_name, owner, registry, _get_current_debug_rolls(runtime, item_name))
			_queue_owner_redraw(owner)
		return true

	if event is InputEventMouseMotion:
		return true

	return true


func draw(canvas: CanvasItem, _owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var runtime: Object = _get_runtime(registry)
	var panel_rect: Rect2 = _get_panel_rect(view_size)
	var mouse_pos: Vector2 = _get_mouse_position(canvas)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.38))
	canvas.draw_rect(panel_rect, Color(0.035, 0.045, 0.068, 0.96))
	canvas.draw_rect(panel_rect, Color(0.35, 0.85, 1.0, 0.90), false, 2.0)

	var title_pos: Vector2 = panel_rect.position + Vector2(18.0, 30.0)
	canvas.draw_string(font, title_pos, "F3 패시브 / 신화 아이템 디버그", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.86, 0.96, 1.0))
	canvas.draw_string(font, title_pos + Vector2(0.0, 22.0), "10 x 10 아이콘 그리드 | Tab/1/2: 패시브/신화 | 좌: 선택 모드 실행 | 우: 롤옵션", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.70, 0.77, 0.84))

	_draw_action_mode_buttons(canvas, font, panel_rect, mouse_pos)
	_draw_tabs(canvas, font, panel_rect, mouse_pos)
	if runtime == null:
		_draw_empty_message(canvas, font, panel_rect, "mythic_item_runtime을 찾을 수 없습니다")
		return
	_draw_selected_item_grid(canvas, font, panel_rect, runtime, mouse_pos, view_size)
	_draw_roll_editor(canvas, font, panel_rect, runtime, mouse_pos)


func _draw_tabs(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	var labels := ["패시브", "신화"]
	for tab_index in range(labels.size()):
		var tab_rect: Rect2 = _get_tab_rect(panel_rect, tab_index)
		var active: bool = tab_index == selected_tab
		var hovered: bool = tab_rect.has_point(mouse_pos)
		var fill := Color(0.08, 0.12, 0.17, 0.96)
		var border := Color(0.25, 0.40, 0.54, 0.78)
		if active:
			fill = Color(0.13, 0.23, 0.22, 0.98) if tab_index == 0 else Color(0.23, 0.17, 0.08, 0.98)
			border = Color(0.35, 1.0, 0.65, 0.92) if tab_index == 0 else Color(1.0, 0.78, 0.25, 0.92)
		elif hovered:
			fill = Color(0.11, 0.16, 0.22, 0.98)
		canvas.draw_rect(tab_rect, fill)
		canvas.draw_rect(tab_rect, border, false, 1.5)
		canvas.draw_string(font, tab_rect.position + Vector2(13.0, 22.0), labels[tab_index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.93, 0.98, 1.0))


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
			Color(0.94, 0.98, 1.0)
		)


func _draw_selected_item_grid(
	canvas: CanvasItem,
	font: Font,
	panel_rect: Rect2,
	runtime: Object,
	mouse_pos: Vector2,
	view_size: Vector2
) -> void:
	var items: Array = _get_selected_tab_items(runtime)
	var inventory: Array = _get_inventory(runtime)
	var inventory_lookup: Dictionary = _build_inventory_lookup(inventory)
	var hovered_index: int = _get_cell_index_at(mouse_pos, panel_rect)
	for index in range(GRID_CAPACITY):
		var cell_rect: Rect2 = _get_cell_rect(panel_rect, index)
		if index < items.size():
			var item_data: Dictionary = _get_dict(items[index])
			var item_name: String = str(item_data.get("name", ""))
			_draw_item_cell(canvas, cell_rect, item_data, inventory_lookup, index == hovered_index, _get_inventory_item_count_from_lookup(item_name, inventory_lookup))
		else:
			_draw_empty_cell(canvas, cell_rect, index == hovered_index)
	if items.is_empty():
		var empty_label := "등록된 패시브 아이템이 없습니다" if selected_tab == 0 else "등록된 신화 아이템이 없습니다"
		_draw_empty_message(canvas, font, panel_rect, empty_label)
	if hovered_index >= 0 and hovered_index < items.size():
		var hovered_item_data: Dictionary = _get_dict(items[hovered_index])
		var hovered_item_name: String = str(hovered_item_data.get("name", ""))
		_draw_hover_tooltip(
			canvas,
			font,
			hovered_item_data,
			inventory_lookup,
			_get_cell_rect(panel_rect, hovered_index),
			view_size,
			_get_inventory_item_count_from_lookup(hovered_item_name, inventory_lookup)
		)


func _draw_item_cell(canvas: CanvasItem, cell_rect: Rect2, item_data: Dictionary, inventory_lookup: Dictionary, hovered: bool, item_count: int = 0) -> void:
	var display_item: Dictionary = _get_display_item_data_from_lookup(item_data, inventory_lookup)
	var rarity: String = str(item_data.get("rarity", item_data.get("type", ""))).to_lower()
	var base := Color(0.095, 0.115, 0.150, 0.96)
	var border := Color(0.24, 0.35, 0.48, 0.70)
	if rarity == "mythic":
		base = Color(0.17, 0.12, 0.045, 0.96)
		border = Color(1.0, 0.72, 0.24, 0.72)
	elif item_count > 0:
		var quality_color: Color = PassiveItemQuality.get_item_quality_color(display_item, border)
		border = Color(quality_color.r, quality_color.g, quality_color.b, 0.76)
	if hovered:
		base = base.lerp(Color(0.18, 0.24, 0.30, 1.0), 0.42)
	canvas.draw_rect(cell_rect, base)
	canvas.draw_rect(cell_rect, border, false, 1.4 if hovered else 1.0)

	var icon_padding: float = max(3.0, min(ICON_PADDING, cell_rect.size.x * 0.18))
	var icon_rect := cell_rect.grow(-icon_padding)
	_draw_item_icon(canvas, icon_rect, item_data)

	var item_name: String = str(item_data.get("name", ""))
	var equipped: bool = _is_inventory_item_equipped_from_lookup(item_name, inventory_lookup)
	var owned: bool = _is_inventory_item_owned_from_lookup(item_name, inventory_lookup)
	if equipped:
		canvas.draw_circle(cell_rect.position + Vector2(cell_rect.size.x - 7.0, 7.0), 4.0, Color(0.42, 1.0, 0.62, 0.96))
	elif owned:
		canvas.draw_circle(cell_rect.position + Vector2(cell_rect.size.x - 7.0, 7.0), 4.0, Color(0.50, 0.74, 1.0, 0.92))
	if item_count > 0:
		_draw_count_badge(canvas, cell_rect, item_count)


func _draw_empty_cell(canvas: CanvasItem, cell_rect: Rect2, hovered: bool) -> void:
	canvas.draw_rect(cell_rect, Color(0.08, 0.10, 0.13, 0.32))
	var border := Color(0.22, 0.30, 0.38, 0.24)
	if hovered:
		border = Color(0.48, 0.62, 0.74, 0.52)
	canvas.draw_rect(cell_rect, border, false, 1.0)


func _draw_count_badge(canvas: CanvasItem, cell_rect: Rect2, item_count: int) -> void:
	var badge_size: float = clamp(cell_rect.size.x * 0.38, 14.0, 18.0)
	var badge_rect := Rect2(
		cell_rect.position + Vector2(cell_rect.size.x - badge_size - 2.0, cell_rect.size.y - badge_size - 2.0),
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


func _draw_hover_tooltip(
	canvas: CanvasItem,
	font: Font,
	item_data: Dictionary,
	inventory_lookup: Dictionary,
	cell_rect: Rect2,
	view_size: Vector2,
	item_count: int = 0
) -> void:
	var tooltip_size := Vector2(min(330.0, max(220.0, view_size.x - 20.0)), 122.0)
	var tooltip_pos := cell_rect.end + Vector2(10.0, -tooltip_size.y)
	if tooltip_pos.x + tooltip_size.x > view_size.x - 8.0:
		tooltip_pos.x = cell_rect.position.x - tooltip_size.x - 10.0
	if tooltip_pos.y < 8.0:
		tooltip_pos.y = cell_rect.end.y + 8.0
	tooltip_pos.x = clamp(tooltip_pos.x, 8.0, max(8.0, view_size.x - tooltip_size.x - 8.0))
	tooltip_pos.y = clamp(tooltip_pos.y, 8.0, max(8.0, view_size.y - tooltip_size.y - 8.0))

	var display_item: Dictionary = _get_display_item_data_from_lookup(item_data, inventory_lookup)
	var item_name: String = str(item_data.get("name", ""))
	var display_name: String = PassiveItemQuality.format_item_display_name(display_item)
	var title_color: Color = PassiveItemQuality.get_item_quality_color(display_item, Color(0.94, 0.98, 1.0))
	var slot_label: String = _slot_display_label(str(item_data.get("slot", "")))
	var status_text: String = _catalog_item_status_from_lookup(item_name, inventory_lookup)
	if item_count > 0:
		status_text = "%s x%d" % [status_text, item_count]
	var description: String = str(item_data.get("description", ""))
	var action_text := "좌클릭: 인벤토리에 1개 추가   우클릭: 롤옵션"
	if action_mode == DEBUG_ACTION_SPAWN:
		action_text = "좌클릭: 필드에 스폰   우클릭: 롤옵션"

	var tooltip_rect := Rect2(tooltip_pos, tooltip_size)
	canvas.draw_rect(tooltip_rect, Color(0.020, 0.026, 0.040, 0.97))
	canvas.draw_rect(tooltip_rect, Color(0.74, 0.88, 1.0, 0.72), false, 1.0)
	canvas.draw_string(font, tooltip_rect.position + Vector2(12.0, 25.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, tooltip_rect.size.x - 24.0, 15, title_color)
	canvas.draw_string(font, tooltip_rect.position + Vector2(12.0, 48.0), "부위 : %s | %s" % [slot_label, status_text], HORIZONTAL_ALIGNMENT_LEFT, tooltip_rect.size.x - 24.0, 12, Color(0.75, 0.84, 0.92))
	canvas.draw_string(font, tooltip_rect.position + Vector2(12.0, 74.0), description, HORIZONTAL_ALIGNMENT_LEFT, tooltip_rect.size.x - 24.0, 12, Color(0.82, 0.88, 0.93))
	canvas.draw_string(font, tooltip_rect.position + Vector2(12.0, 104.0), action_text, HORIZONTAL_ALIGNMENT_LEFT, tooltip_rect.size.x - 24.0, 11, Color(1.0, 0.86, 0.42))


func _draw_item_icon(canvas: CanvasItem, icon_rect: Rect2, item_data: Dictionary) -> void:
	canvas.draw_circle(icon_rect.get_center(), icon_rect.size.x * 0.55, Color(0.0, 0.0, 0.0, 0.22))
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		icon_renderer.draw_icon(canvas, icon_rect, item_data, 1.0, icon_visuals)
		return

	var color: Color = _get_color(item_data.get("color", Color(0.65, 0.78, 1.0)), Color(0.65, 0.78, 1.0))
	var icon_center: Vector2 = icon_rect.get_center()
	canvas.draw_circle(icon_center, icon_rect.size.x * 0.43, color)
	canvas.draw_circle(icon_center + Vector2(-4.0, -5.0), 4.0, Color(1.0, 1.0, 1.0, 0.30))
	canvas.draw_circle(icon_center, icon_rect.size.x * 0.43, Color(1.0, 1.0, 1.0, 0.52), false, 1.4)


func _draw_empty_message(canvas: CanvasItem, font: Font, panel_rect: Rect2, message: String) -> void:
	var content_rect: Rect2 = _get_grid_content_rect(panel_rect)
	var message_rect := Rect2(content_rect.position + Vector2(0.0, 8.0), Vector2(content_rect.size.x, 54.0))
	canvas.draw_rect(message_rect, Color(0.07, 0.09, 0.12, 0.90))
	canvas.draw_rect(message_rect, Color(0.22, 0.32, 0.44, 0.70), false, 1.0)
	canvas.draw_string(font, message_rect.position + Vector2(18.0, 34.0), message, HORIZONTAL_ALIGNMENT_LEFT, message_rect.size.x - 36.0, 13, Color(0.76, 0.83, 0.90))


func _draw_roll_editor(canvas: CanvasItem, font: Font, panel_rect: Rect2, runtime: Object, mouse_pos: Vector2) -> void:
	if not roll_editor_open or runtime == null:
		return
	var item_data: Dictionary = _get_roll_editor_item(runtime)
	if item_data.is_empty():
		_close_roll_editor()
		return
	var options: Array = _get_roll_options(item_data)
	var editor_rect: Rect2 = _get_roll_editor_rect(panel_rect, runtime)
	canvas.draw_rect(editor_rect, Color(0.025, 0.032, 0.048, 0.98))
	canvas.draw_rect(editor_rect, Color(1.0, 0.78, 0.25, 0.92), false, 1.5)

	var display_name: String = PassiveItemQuality.format_item_display_name(item_data)
	canvas.draw_string(font, editor_rect.position + Vector2(14.0, 24.0), "롤옵션", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 0.90, 0.42))
	canvas.draw_string(font, editor_rect.position + Vector2(14.0, 45.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, editor_rect.size.x - 28.0, 12, PassiveItemQuality.get_item_quality_color(item_data, Color(0.80, 0.86, 0.92)))

	if options.is_empty():
		canvas.draw_string(font, editor_rect.position + Vector2(14.0, ROLL_EDITOR_HEADER_HEIGHT + 28.0), "롤옵션 없음", HORIZONTAL_ALIGNMENT_LEFT, editor_rect.size.x - 28.0, 13, Color(0.70, 0.76, 0.82))
		return

	for index in range(options.size()):
		var row_rect: Rect2 = _get_roll_option_row_rect(editor_rect, index)
		var option: Dictionary = _get_dict(options[index])
		var hovered: bool = row_rect.has_point(mouse_pos)
		var fill := Color(0.07, 0.09, 0.12, 0.95)
		if hovered:
			fill = Color(0.12, 0.15, 0.19, 0.98)
		canvas.draw_rect(row_rect, fill)
		canvas.draw_rect(row_rect, Color(0.26, 0.35, 0.44, 0.70), false, 1.0)

		var label: String = str(option.get("label", option.get("key", "")))
		var value_text: String = _format_roll_value(_get_roll_value(item_data, option), option)
		canvas.draw_string(font, row_rect.position + Vector2(10.0, 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 112.0, 12, Color(0.92, 0.96, 1.0))
		canvas.draw_string(font, row_rect.position + Vector2(10.0, 34.0), value_text, HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 112.0, 13, Color(1.0, 0.86, 0.40))
		_draw_roll_button(canvas, font, _get_roll_button_rect(row_rect, false), "-", mouse_pos)
		_draw_roll_button(canvas, font, _get_roll_button_rect(row_rect, true), "+", mouse_pos)


func _draw_roll_button(canvas: CanvasItem, font: Font, rect: Rect2, label: String, mouse_pos: Vector2) -> void:
	var fill := Color(0.12, 0.16, 0.20, 0.98)
	if rect.has_point(mouse_pos):
		fill = Color(0.24, 0.30, 0.36, 1.0)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, Color(0.58, 0.70, 0.82, 0.76), false, 1.0)
	var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
	canvas.draw_string(font, rect.get_center() - Vector2(label_size.x * 0.5, -label_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.95, 0.98, 1.0))


func _debug_spawn_item_from_menu(item_data: Dictionary, runtime: Object, _owner: Object, registry: Object) -> bool:
	var active_item_runtime: Object = _get_active_item_runtime(registry)
	if active_item_runtime == null:
		return false
	var item_name: String = str(item_data.get("name", ""))
	if item_name == "":
		return false
	var spawn_item: Dictionary = _build_roll_editor_item(runtime, item_name)
	if spawn_item.is_empty():
		spawn_item = item_data.duplicate(true)
	if active_item_runtime.has_method("spawn_field_item_data"):
		return bool(active_item_runtime.spawn_field_item_data(spawn_item))
	if active_item_runtime.has_method("spawn_field_item"):
		return bool(active_item_runtime.spawn_field_item(item_name))
	return false


func _open_roll_editor_at(position: Vector2, panel_rect: Rect2, runtime: Object, _owner: Object, _registry: Object) -> bool:
	var items: Array = _get_selected_tab_items(runtime)
	var item_index: int = _get_cell_index_at(position, panel_rect)
	if item_index < 0 or item_index >= items.size():
		return false
	var debug_item: Dictionary = _get_dict(items[item_index])
	var item_name: String = str(debug_item.get("name", ""))
	if item_name == "":
		return false
	var draft_item: Dictionary = _build_roll_editor_item(runtime, item_name)
	if draft_item.is_empty():
		return false
	_ensure_debug_roll_overrides(item_name, draft_item)
	_open_roll_editor(-1, item_name)
	return true


func _open_roll_editor(inventory_index: int, item_name: String) -> void:
	roll_editor_open = true
	roll_editor_inventory_index = inventory_index
	roll_editor_item_name = item_name


func _close_roll_editor() -> void:
	roll_editor_open = false
	roll_editor_inventory_index = -1
	roll_editor_item_name = ""


func _handle_roll_editor_left_click(position: Vector2, panel_rect: Rect2, runtime: Object, owner: Object, registry: Object) -> bool:
	var editor_rect: Rect2 = _get_roll_editor_rect(panel_rect, runtime)
	if not editor_rect.has_point(position):
		return false
	var item_data: Dictionary = _get_roll_editor_item(runtime)
	var options: Array = _get_roll_options(item_data)
	for index in range(options.size()):
		var row_rect: Rect2 = _get_roll_option_row_rect(editor_rect, index)
		if not row_rect.has_point(position):
			continue
		var option: Dictionary = _get_dict(options[index])
		var option_key: String = str(option.get("key", ""))
		var delta := 0
		if _get_roll_button_rect(row_rect, false).has_point(position):
			delta = -1
		elif _get_roll_button_rect(row_rect, true).has_point(position):
			delta = 1
		if delta == 0:
			return true
		_adjust_roll_option(runtime, option_key, delta, owner, registry)
		return true
	return true


func _adjust_roll_from_editor_position(position: Vector2, panel_rect: Rect2, runtime: Object, owner: Object, registry: Object, delta_steps: int) -> bool:
	var editor_rect: Rect2 = _get_roll_editor_rect(panel_rect, runtime)
	if not editor_rect.has_point(position):
		return false
	var item_data: Dictionary = _get_roll_editor_item(runtime)
	var options: Array = _get_roll_options(item_data)
	for index in range(options.size()):
		var row_rect: Rect2 = _get_roll_option_row_rect(editor_rect, index)
		if row_rect.has_point(position):
			var option: Dictionary = _get_dict(options[index])
			return _adjust_roll_option(runtime, str(option.get("key", "")), delta_steps, owner, registry)
	return false


func _adjust_roll_option(runtime: Object, option_key: String, delta_steps: int, _owner: Object, _registry: Object) -> bool:
	if runtime == null or roll_editor_item_name == "" or option_key == "" or delta_steps == 0:
		return false
	var item_data: Dictionary = _get_roll_editor_item(runtime)
	var option: Dictionary = {}
	for option_value in _get_roll_options(item_data):
		var candidate: Dictionary = _get_dict(option_value)
		if str(candidate.get("key", "")) == option_key:
			option = candidate
			break
	if option.is_empty():
		return false
	var minimum: float = float(option.get("min", option.get("default", 0.0)))
	var maximum: float = float(option.get("max", minimum))
	if maximum < minimum:
		var tmp: float = minimum
		minimum = maximum
		maximum = tmp
	var step: float = max(0.0001, float(option.get("step", 1.0)))
	var rolls: Dictionary = _get_debug_roll_overrides(roll_editor_item_name)
	var current: float = float(rolls.get(option_key, option.get("value", option.get("default", minimum))))
	var next_value: float = clamp(current + step * float(delta_steps), minimum, maximum)
	next_value = minimum + round((next_value - minimum) / step) * step
	next_value = clamp(next_value, minimum, maximum)
	if step >= 1.0:
		next_value = round(next_value)
	if is_equal_approx(current, next_value):
		return false
	rolls[option_key] = next_value
	debug_roll_overrides[roll_editor_item_name] = rolls
	return true


func _get_roll_editor_rect(panel_rect: Rect2, runtime: Object) -> Rect2:
	var item_data: Dictionary = _get_roll_editor_item(runtime)
	var options: Array = _get_roll_options(item_data)
	var width: float = min(ROLL_EDITOR_WIDTH, panel_rect.size.x - 36.0)
	var height: float = ROLL_EDITOR_HEADER_HEIGHT + max(1.0, float(options.size())) * ROLL_EDITOR_ROW_HEIGHT + 14.0
	height = min(height, panel_rect.size.y - HEADER_HEIGHT - TAB_HEIGHT - 24.0)
	return Rect2(
		Vector2(panel_rect.end.x - width - 18.0, panel_rect.position.y + HEADER_HEIGHT + TAB_HEIGHT + 14.0),
		Vector2(width, height)
	)


func _get_roll_option_row_rect(editor_rect: Rect2, index: int) -> Rect2:
	return Rect2(
		editor_rect.position + Vector2(10.0, ROLL_EDITOR_HEADER_HEIGHT + float(index) * ROLL_EDITOR_ROW_HEIGHT),
		Vector2(editor_rect.size.x - 20.0, ROLL_EDITOR_ROW_HEIGHT - 6.0)
	)


func _get_roll_button_rect(row_rect: Rect2, positive: bool) -> Rect2:
	var x: float = row_rect.end.x - ROLL_EDITOR_BUTTON_SIZE.x - 8.0
	if not positive:
		x -= ROLL_EDITOR_BUTTON_SIZE.x + 6.0
	return Rect2(
		Vector2(x, row_rect.position.y + floor((row_rect.size.y - ROLL_EDITOR_BUTTON_SIZE.y) * 0.5)),
		ROLL_EDITOR_BUTTON_SIZE
	)


func _get_roll_editor_item(runtime: Object) -> Dictionary:
	if runtime != null and roll_editor_item_name != "":
		var draft_item: Dictionary = _build_roll_editor_item(runtime, roll_editor_item_name)
		if not draft_item.is_empty():
			return draft_item
	if runtime != null and roll_editor_inventory_index >= 0 and runtime.has_method("debug_get_inventory_item"):
		var direct: Dictionary = _get_dict(runtime.debug_get_inventory_item(roll_editor_inventory_index))
		if not direct.is_empty():
			return direct
	var inventory: Array = _get_inventory(runtime)
	if roll_editor_inventory_index >= 0 and roll_editor_inventory_index < inventory.size():
		var indexed: Dictionary = _get_dict(inventory[roll_editor_inventory_index])
		if roll_editor_item_name == "" or str(indexed.get("name", "")) == roll_editor_item_name:
			return indexed
	for item_value in inventory:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) == roll_editor_item_name:
			return item_data
	return {}


func _build_roll_editor_item(runtime: Object, item_name: String) -> Dictionary:
	if runtime != null and runtime.has_method("debug_build_roll_editor_item"):
		return _get_dict(runtime.debug_build_roll_editor_item(item_name, _get_debug_roll_overrides(item_name)))
	for item_value in _get_debug_items(runtime):
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) == item_name:
			return item_data
	return {}


func _get_debug_roll_overrides(item_name: String) -> Dictionary:
	var value: Variant = debug_roll_overrides.get(item_name, {})
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _ensure_debug_roll_overrides(item_name: String, item_data: Dictionary) -> Dictionary:
	if item_name == "":
		return {}
	var existing: Dictionary = _get_debug_roll_overrides(item_name)
	if not existing.is_empty():
		return existing
	var rolls: Dictionary = _get_dict(item_data.get("rolls", {})).duplicate(true)
	debug_roll_overrides[item_name] = rolls
	return rolls


func _get_current_debug_rolls(runtime: Object, item_name: String) -> Dictionary:
	if item_name == "":
		return {}
	var draft_item: Dictionary = _build_roll_editor_item(runtime, item_name)
	if draft_item.is_empty():
		return {}
	return _ensure_debug_roll_overrides(item_name, draft_item)


func _get_roll_options(item_data: Dictionary) -> Array:
	if item_data.is_empty():
		return []
	return _get_array(item_data.get("roll_options", []))


func _get_roll_value(item_data: Dictionary, option: Dictionary) -> float:
	var key: String = str(option.get("key", ""))
	var rolls: Dictionary = _get_dict(item_data.get("rolls", {}))
	return float(rolls.get(key, option.get("value", option.get("default", option.get("min", 0.0)))))


func _format_roll_value(value: float, option: Dictionary) -> String:
	var unit: String = str(option.get("unit", ""))
	var prefix: String = str(option.get("prefix", ""))
	var value_text := ""
	if is_equal_approx(value, round(value)):
		value_text = str(int(round(value)))
	else:
		value_text = "%.2f" % value
	if unit == "+":
		return "+%s" % value_text
	return "%s%s%s" % [prefix, value_text, unit]


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var cell_size: float = _get_cell_size_for_view(view_size)
	var grid_width: float = float(GRID_COLUMNS) * cell_size + float(GRID_COLUMNS - 1) * GRID_GAP
	var grid_height: float = float(GRID_ROWS) * cell_size + float(GRID_ROWS - 1) * GRID_GAP
	var width: float = min(PANEL_WIDTH, max(360.0, GRID_SIDE_PADDING * 2.0 + grid_width))
	width = min(width, max(360.0, view_size.x - PANEL_MARGIN * 2.0))
	var height: float = HEADER_HEIGHT + TAB_HEIGHT + GRID_TOP_PADDING + grid_height + GRID_BOTTOM_PADDING
	height = min(height, max(360.0, view_size.y - PANEL_MARGIN * 2.0))
	var pos := Vector2(floor((view_size.x - width) * 0.5), floor((view_size.y - height) * 0.5))
	return Rect2(pos, Vector2(width, height))


func _get_tab_rect(panel_rect: Rect2, tab_index: int) -> Rect2:
	var tab_w: float = (panel_rect.size.x - 36.0 - 8.0) * 0.5
	return Rect2(panel_rect.position + Vector2(18.0 + float(tab_index) * (tab_w + 8.0), HEADER_HEIGHT), Vector2(tab_w, TAB_HEIGHT))


func _get_cell_size_for_view(view_size: Vector2) -> float:
	var available_width: float = min(PANEL_WIDTH, max(360.0, view_size.x - PANEL_MARGIN * 2.0))
	var available_height: float = max(360.0, view_size.y - PANEL_MARGIN * 2.0)
	var grid_width: float = available_width - GRID_SIDE_PADDING * 2.0
	var grid_height: float = available_height - HEADER_HEIGHT - TAB_HEIGHT - GRID_TOP_PADDING - GRID_BOTTOM_PADDING
	var by_width: float = floor((grid_width - float(GRID_COLUMNS - 1) * GRID_GAP) / float(GRID_COLUMNS))
	var by_height: float = floor((grid_height - float(GRID_ROWS - 1) * GRID_GAP) / float(GRID_ROWS))
	return clamp(min(GRID_DEFAULT_CELL_SIZE, min(by_width, by_height)), GRID_MIN_CELL_SIZE, GRID_DEFAULT_CELL_SIZE)


func _get_cell_size_from_panel(panel_rect: Rect2) -> float:
	var grid_width: float = panel_rect.size.x - GRID_SIDE_PADDING * 2.0
	return (grid_width - float(GRID_COLUMNS - 1) * GRID_GAP) / float(GRID_COLUMNS)


func _get_grid_content_rect(panel_rect: Rect2) -> Rect2:
	var cell_size: float = _get_cell_size_from_panel(panel_rect)
	var grid_width: float = float(GRID_COLUMNS) * cell_size + float(GRID_COLUMNS - 1) * GRID_GAP
	var grid_height: float = float(GRID_ROWS) * cell_size + float(GRID_ROWS - 1) * GRID_GAP
	return Rect2(
		panel_rect.position + Vector2(GRID_SIDE_PADDING, HEADER_HEIGHT + TAB_HEIGHT + GRID_TOP_PADDING),
		Vector2(grid_width, grid_height)
	)


func _get_cell_rect(panel_rect: Rect2, index: int) -> Rect2:
	var content_rect: Rect2 = _get_grid_content_rect(panel_rect)
	var cell_size: float = _get_cell_size_from_panel(panel_rect)
	var column: int = index % GRID_COLUMNS
	@warning_ignore("integer_division")
	var row: int = int(index / GRID_COLUMNS)
	return Rect2(
		content_rect.position + Vector2(float(column) * (cell_size + GRID_GAP), float(row) * (cell_size + GRID_GAP)),
		Vector2(cell_size, cell_size)
	)


func _get_cell_index_at(position: Vector2, panel_rect: Rect2) -> int:
	for index in range(GRID_CAPACITY):
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
	var start_x: float = panel_rect.end.x - GRID_SIDE_PADDING - total_width
	return Rect2(
		Vector2(start_x + float(index) * (DEBUG_ACTION_BUTTON_SIZE.x + DEBUG_ACTION_BUTTON_GAP), panel_rect.position.y + 13.0),
		DEBUG_ACTION_BUTTON_SIZE
	)


func _get_runtime(registry: Object) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("mythic_item_runtime")
	return null


func _get_active_item_runtime(registry: Object) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("active_item_runtime")
	return null


func _get_inventory(runtime: Object) -> Array:
	if runtime != null and runtime.has_method("get_snapshot"):
		var snapshot: Dictionary = _get_dict(runtime.get_snapshot())
		return _get_array(snapshot.get("inventory_items", []))
	return []


func _get_debug_items(runtime: Object) -> Array:
	if runtime != null and runtime.has_method("get_debug_item_entries"):
		return _get_array(runtime.get_debug_item_entries())
	return []


func _get_selected_tab_items(runtime: Object) -> Array:
	return _filter_debug_items(_get_debug_items(runtime), _get_selected_tab_rarity())


func _get_selected_tab_rarity() -> String:
	return "passive" if selected_tab == 0 else "mythic"


func _get_display_item_data(catalog_item: Dictionary, inventory: Array) -> Dictionary:
	var item_name: String = str(catalog_item.get("name", ""))
	if item_name != "":
		for item_value in inventory:
			var inventory_item: Dictionary = _get_dict(item_value)
			if str(inventory_item.get("name", "")) == item_name:
				return inventory_item
	return catalog_item


func _build_inventory_lookup(inventory: Array) -> Dictionary:
	var items_by_name: Dictionary = {}
	var counts_by_name: Dictionary = {}
	var equipped_by_name: Dictionary = {}
	var owned_by_name: Dictionary = {}
	for item_value in inventory:
		var item_data: Dictionary = _get_dict(item_value)
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "":
			continue
		if not items_by_name.has(item_name):
			items_by_name[item_name] = item_data
		counts_by_name[item_name] = int(counts_by_name.get(item_name, 0)) + 1
		owned_by_name[item_name] = true
		if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
			equipped_by_name[item_name] = true
	return {
		"items_by_name": items_by_name,
		"counts_by_name": counts_by_name,
		"equipped_by_name": equipped_by_name,
		"owned_by_name": owned_by_name,
	}


func _get_display_item_data_from_lookup(catalog_item: Dictionary, inventory_lookup: Dictionary) -> Dictionary:
	var item_name: String = str(catalog_item.get("name", ""))
	if item_name == "":
		return catalog_item
	var items_by_name: Dictionary = _get_dict(inventory_lookup.get("items_by_name", {}))
	var item_value: Variant = items_by_name.get(item_name, null)
	if item_value is Dictionary:
		return item_value
	return catalog_item


func _get_inventory_item_count_from_lookup(item_name: String, inventory_lookup: Dictionary) -> int:
	if item_name == "":
		return 0
	var counts_by_name: Dictionary = _get_dict(inventory_lookup.get("counts_by_name", {}))
	return int(counts_by_name.get(item_name, 0))


func _is_inventory_item_equipped_from_lookup(item_name: String, inventory_lookup: Dictionary) -> bool:
	if item_name == "":
		return false
	var equipped_by_name: Dictionary = _get_dict(inventory_lookup.get("equipped_by_name", {}))
	return bool(equipped_by_name.get(item_name, false))


func _is_inventory_item_owned_from_lookup(item_name: String, inventory_lookup: Dictionary) -> bool:
	if item_name == "":
		return false
	var owned_by_name: Dictionary = _get_dict(inventory_lookup.get("owned_by_name", {}))
	return bool(owned_by_name.get(item_name, false))


func _catalog_item_status_from_lookup(item_name: String, inventory_lookup: Dictionary) -> String:
	var item_data: Dictionary = _get_display_item_data_from_lookup({"name": item_name}, inventory_lookup).duplicate(true)
	if item_data.is_empty():
		item_data["name"] = item_name
	if _is_inventory_item_equipped_from_lookup(item_name, inventory_lookup):
		item_data["equipped"] = true
		return _catalog_item_status(item_name, [item_data])
	if _is_inventory_item_owned_from_lookup(item_name, inventory_lookup):
		return _catalog_item_status(item_name, [item_data])
	return _catalog_item_status(item_name, [])


func _filter_debug_items(items: Array, rarity_filter: String) -> Array:
	var result: Array = []
	for item_value in items:
		var item_data: Dictionary = _get_dict(item_value)
		var rarity: String = str(item_data.get("rarity", item_data.get("type", ""))).to_lower()
		if rarity == rarity_filter:
			result.append(item_data)
	return result


func _get_inventory_index_for_item_name(runtime: Object, item_name: String) -> int:
	return _get_inventory_index_for_item_name_in_inventory(_get_inventory(runtime), item_name)


func _get_inventory_index_for_item_name_in_inventory(inventory: Array, item_name: String) -> int:
	for index in range(inventory.size()):
		var item_data: Dictionary = _get_dict(inventory[index])
		if str(item_data.get("name", "")) == item_name:
			return index
	return -1


func _get_inventory_item_count(item_name: String, inventory: Array) -> int:
	var count := 0
	for item_value in inventory:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) == item_name:
			count += 1
	return count


func _is_inventory_item_equipped(item_name: String, inventory: Array) -> bool:
	for item_value in inventory:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) != item_name:
			continue
		return bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != ""
	return false


func _catalog_item_status(item_name: String, inventory: Array) -> String:
	var owned := false
	for item_value in inventory:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) != item_name:
			continue
		owned = true
		if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
			return "보유 / 장착됨"
	if owned:
		return "보유 / 미장착"
	return "미보유"


func _inventory_status(item_data: Dictionary) -> String:
	if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
		return "장착됨: %s" % _slot_display_label(str(item_data.get("_equipped_slot", item_data.get("slot", ""))))
	return "보관 중"


func _mythic_status(item_name: String, inventory: Array) -> String:
	for item_value in inventory:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) != item_name:
			continue
		if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
			return "보유 / 장착됨"
		return "보유 / 미장착"
	return "미보유"


func _slot_display_label(slot_key: String) -> String:
	match slot_key:
		"head":
			return "머리"
		"top", "torso":
			return "상의"
		"left_arm", "right_arm", "arm":
			return "팔"
		"belt":
			return "벨트"
		"belt2", "back", "등":
			return "등"
		"knee":
			return "무릎"
		"shoes":
			return "신발"
		"accessory", "accessory1", "accessory2", "accessory3", "accessory4":
			return "장신구"
		_:
			return slot_key


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	var viewport: Viewport = canvas.get_viewport()
	if viewport != null:
		return viewport.get_mouse_position()
	return Vector2(-9999.0, -9999.0)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func _queue_owner_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
