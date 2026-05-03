extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DEBUG_SPAWN_MENU_MARGIN := 18.0
const DEBUG_SPAWN_MENU_TOP := 70.0
const DEBUG_SPAWN_MENU_WIDTH := 330.0
const DEBUG_SPAWN_MENU_TITLE_HEIGHT := 48.0
const DEBUG_SPAWN_MENU_ROW_HEIGHT := 58.0
const DEBUG_SPAWN_MENU_ICON_SIZE := 36.0

var open := false
var item_catalog: Object = ActiveItemCatalog.new()
var icon_textures: Dictionary = {}


func reset() -> void:
	open = false


func toggle() -> void:
	open = not open


func is_open() -> bool:
	return open


func handle_click(mouse_position: Vector2, view_size: Vector2) -> Dictionary:
	if not open:
		return {
			"handled": false,
			"item_name": "",
		}

	var panel_rect: Rect2 = _get_panel_rect(view_size)
	if not panel_rect.has_point(mouse_position):
		open = false
		return {
			"handled": true,
			"item_name": "",
		}

	var entries: Array[Dictionary] = _get_entries()
	for i in range(entries.size()):
		var row_rect: Rect2 = _get_row_rect(panel_rect, i)
		if row_rect.has_point(mouse_position):
			open = false
			return {
				"handled": true,
				"item_name": str(entries[i].get("name", "")),
			}

	return {
		"handled": true,
		"item_name": "",
	}


func draw(canvas: CanvasItem, view_size: Vector2) -> void:
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
	canvas.draw_string(font, title_pos, "F2 Item Spawn", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.82, 0.95, 1.0, 1.0))
	canvas.draw_string(font, panel_rect.position + Vector2(16.0, 48.0), "Click an item to spawn it now", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.72, 0.78, 0.84, 1.0))

	var mouse_pos: Vector2 = Vector2(-9999.0, -9999.0)
	var viewport: Viewport = canvas.get_viewport()
	if viewport != null:
		mouse_pos = viewport.get_mouse_position()

	var entries: Array[Dictionary] = _get_entries()
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var row_rect: Rect2 = _get_row_rect(panel_rect, i)
		var hovered: bool = row_rect.has_point(mouse_pos)
		var base_color := Color(0.10, 0.12, 0.16, 0.95)
		if hovered:
			base_color = Color(0.14, 0.20, 0.27, 0.98)
		canvas.draw_rect(row_rect, base_color)
		canvas.draw_rect(row_rect, Color(0.24, 0.36, 0.48, 0.65), false, 1.0)

		var item_name: String = str(entry.get("name", ""))
		var icon_center: Vector2 = row_rect.position + Vector2(28.0, row_rect.size.y * 0.5)
		_draw_entry_icon(canvas, item_name, icon_center)
		canvas.draw_string(font, row_rect.position + Vector2(56.0, 23.0), str(entry.get("title", item_name)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 1.0, 1.0, 1.0))
		canvas.draw_string(font, row_rect.position + Vector2(56.0, 42.0), str(entry.get("subtitle", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.70, 0.76, 0.82, 1.0))


func _get_entries() -> Array[Dictionary]:
	return [
		{
			"name": "gauge_charge",
			"title": "에너지드링크",
			"subtitle": "active / gauge +220",
		},
		{
			"name": "grenade",
			"title": "수류탄",
			"subtitle": "active / throw explosive",
		},
		{
			"name": "flare",
			"title": "Flare",
			"subtitle": "active / throw confuse",
		},
		{
			"name": "long_boost",
			"title": "거대화포션",
			"subtitle": "active / paddle x1.5",
		},
		{
			"name": "regeneration_potion",
			"title": "재생물약",
			"subtitle": "active / reset skills",
		},
		{
			"name": "boomerang",
			"title": "부메랑",
			"subtitle": "active / throw return",
		},
	]


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var entries: Array[Dictionary] = _get_entries()
	var width: float = min(DEBUG_SPAWN_MENU_WIDTH, max(220.0, view_size.x - DEBUG_SPAWN_MENU_MARGIN * 2.0))
	var height: float = DEBUG_SPAWN_MENU_TITLE_HEIGHT + float(entries.size()) * DEBUG_SPAWN_MENU_ROW_HEIGHT + DEBUG_SPAWN_MENU_MARGIN
	var x: float = clamp(DEBUG_SPAWN_MENU_MARGIN, 0.0, max(0.0, view_size.x - width))
	var y: float = clamp(DEBUG_SPAWN_MENU_TOP, 0.0, max(0.0, view_size.y - height))
	return Rect2(Vector2(x, y), Vector2(width, height))


func _get_row_rect(panel_rect: Rect2, index: int) -> Rect2:
	return Rect2(
		panel_rect.position + Vector2(12.0, DEBUG_SPAWN_MENU_TITLE_HEIGHT + float(index) * DEBUG_SPAWN_MENU_ROW_HEIGHT + 4.0),
		Vector2(panel_rect.size.x - 24.0, DEBUG_SPAWN_MENU_ROW_HEIGHT - 8.0)
	)


func _draw_entry_icon(canvas: CanvasItem, item_name: String, center: Vector2) -> void:
	var texture: Texture2D = _get_icon_texture(item_name)
	var icon_size := Vector2(DEBUG_SPAWN_MENU_ICON_SIZE, DEBUG_SPAWN_MENU_ICON_SIZE)
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(center - icon_size * 0.5, icon_size), false)
		return

	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	var item_color: Color = _get_item_color(item_data)
	canvas.draw_circle(center, DEBUG_SPAWN_MENU_ICON_SIZE * 0.42, item_color)
	canvas.draw_circle(center + Vector2(-5.0, -6.0), 4.0, Color(1.0, 1.0, 1.0, 0.25))


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
