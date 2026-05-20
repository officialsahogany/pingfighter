extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_ITEM_COLOR := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
const MEGINGJORD_ICON_SHEET_PATH := "res://assets/sprites/items/megingjord_icon_sheet.png"
const MEGINGJORD_ICON_FRAME_COUNT := 32
const MEGINGJORD_ICON_FRAME_MSEC := 33
const MEGINGJORD_ICON_SOURCE_INSET := 0.0
const MEGINGJORD_SMALL_SLOT_RECOVERY_PAD := 5.0
const MEGINGJORD_SMALL_SLOT_LIMIT := 58.0
const MEGINGJORD_FALLBACK_RING_SEGMENTS := 20

var _megingjord_icon_sheet: Texture2D = null
var _icon_sheet_cache: Dictionary = {}


func draw_icon(canvas: CanvasItem, slot_rect: Rect2, item_data: Dictionary, scale_factor: float, visuals) -> void:
	if str(item_data.get("icon_sheet_path", "")) != "":
		var animated_rect: Rect2 = _get_animated_icon_target_rect(slot_rect, item_data)
		if _draw_animated_icon_sheet(canvas, animated_rect, item_data):
			return
	if str(item_data.get("name", "")) == "megingjord":
		var megingjord_rect: Rect2 = _get_megingjord_target_rect(slot_rect)
		if _draw_megingjord_animated_icon(canvas, megingjord_rect):
			return
		_draw_megingjord_icon(canvas, megingjord_rect, scale_factor)
		return
	var pad: float = max(1.0, floor(slot_rect.size.x * 0.09))
	var icon_rect := Rect2(slot_rect.position.x + pad, slot_rect.position.y + pad, slot_rect.size.x - pad * 2.0, slot_rect.size.y - pad * 2.0)
	var icon_texture: Texture2D = _get_icon_texture(item_data, visuals)
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, icon_rect, false)
		return

	var item_color: Color = _get_item_color(item_data, visuals)
	var radius: float = slot_rect.size.x * 0.28
	var center: Vector2 = slot_rect.get_center()
	canvas.draw_circle(center, radius + 3.0 * scale_factor, Color(item_color.r, item_color.g, item_color.b, 0.18))
	canvas.draw_circle(center, radius, item_color)
	canvas.draw_circle(center + Vector2(-radius * 0.30, -radius * 0.35), max(1.0, radius * 0.28), Color(1.0, 1.0, 1.0, 0.28))


func prewarm_item_icons(items: Array, visuals = null) -> void:
	for item_value in items:
		if item_value is Dictionary:
			prewarm_item_icon(item_value, visuals)


func prewarm_item_icon(item_data: Dictionary, visuals = null) -> void:
	var sheet_path: String = str(item_data.get("icon_sheet_path", ""))
	if sheet_path != "":
		_touch_texture(_get_icon_sheet(sheet_path))
	if str(item_data.get("name", "")) == "megingjord":
		_touch_texture(_get_megingjord_icon_sheet())
	_touch_texture(_get_icon_texture(item_data, visuals))


func _draw_animated_icon_sheet(canvas: CanvasItem, icon_rect: Rect2, item_data: Dictionary) -> bool:
	var sheet_path: String = str(item_data.get("icon_sheet_path", ""))
	if sheet_path == "":
		return false
	var sheet: Texture2D = _get_icon_sheet(sheet_path)
	if sheet == null:
		return false
	var frame_count: int = max(1, int(item_data.get("icon_frame_count", 1)))
	var sheet_size: Vector2 = sheet.get_size()
	if sheet_size.x <= 0.0 or sheet_size.y <= 0.0:
		return false
	var frame_w: float = sheet_size.x / float(frame_count)
	var frame_h: float = sheet_size.y
	if frame_w <= 0.0 or frame_h <= 0.0:
		return false
	var frame_msec: int = max(1, int(item_data.get("icon_frame_msec", MEGINGJORD_ICON_FRAME_MSEC)))
	@warning_ignore("integer_division")
	var frame_index: int = int(Time.get_ticks_msec() / frame_msec) % frame_count
	var source_inset: float = clamp(float(item_data.get("icon_source_inset", 0.0)), 0.0, min(frame_w, frame_h) * 0.45)
	var source_rect := Rect2(float(frame_index) * frame_w + source_inset, source_inset, frame_w - source_inset * 2.0, frame_h - source_inset * 2.0)
	canvas.draw_texture_rect_region(sheet, icon_rect, source_rect)
	return true


func _get_animated_icon_target_rect(slot_rect: Rect2, item_data: Dictionary) -> Rect2:
	if not bool(item_data.get("icon_fill_slot", false)):
		return slot_rect
	return _grow_rect_xy(slot_rect, float(item_data.get("icon_target_pad", 0.0)))


func _draw_megingjord_animated_icon(canvas: CanvasItem, icon_rect: Rect2) -> bool:
	var sheet: Texture2D = _get_megingjord_icon_sheet()
	if sheet == null:
		return false
	var sheet_size: Vector2 = sheet.get_size()
	if sheet_size.x <= 0.0 or sheet_size.y <= 0.0:
		return false
	var frame_w: float = sheet_size.x / float(MEGINGJORD_ICON_FRAME_COUNT)
	var frame_h: float = sheet_size.y
	@warning_ignore("integer_division")
	var frame_index: int = int(Time.get_ticks_msec() / MEGINGJORD_ICON_FRAME_MSEC) % MEGINGJORD_ICON_FRAME_COUNT
	var source_rect := Rect2(float(frame_index) * frame_w + MEGINGJORD_ICON_SOURCE_INSET, MEGINGJORD_ICON_SOURCE_INSET, frame_w - MEGINGJORD_ICON_SOURCE_INSET * 2.0, frame_h - MEGINGJORD_ICON_SOURCE_INSET * 2.0)
	canvas.draw_texture_rect_region(sheet, icon_rect, source_rect)
	return true


func _get_megingjord_target_rect(slot_rect: Rect2) -> Rect2:
	var shortest_side: float = min(slot_rect.size.x, slot_rect.size.y)
	if shortest_side <= MEGINGJORD_SMALL_SLOT_LIMIT:
		return _grow_rect_xy(slot_rect, MEGINGJORD_SMALL_SLOT_RECOVERY_PAD)
	return slot_rect


func _draw_megingjord_icon(canvas: CanvasItem, icon_rect: Rect2, scale_factor: float) -> void:
	var center: Vector2 = icon_rect.get_center()
	var unit: float = max(1.0, min(icon_rect.size.x, icon_rect.size.y) / 32.0)
	var belt_rect := Rect2(
		center - Vector2(13.0 * unit, 3.8 * unit),
		Vector2(26.0 * unit, 7.6 * unit)
	)
	var glow_radius: float = 13.5 * unit
	canvas.draw_circle(center, glow_radius, Color(1.0, 210.0 / 255.0, 70.0 / 255.0, 0.18))
	canvas.draw_circle(center, glow_radius * 0.72, Color(70.0 / 255.0, 160.0 / 255.0, 1.0, 0.08))

	canvas.draw_rect(_grow_rect_xy(belt_rect, 1.2 * unit), Color(34.0 / 255.0, 19.0 / 255.0, 9.0 / 255.0, 1.0))
	canvas.draw_rect(belt_rect, Color(92.0 / 255.0, 52.0 / 255.0, 24.0 / 255.0, 1.0))
	canvas.draw_line(
		belt_rect.position + Vector2(2.0 * unit, 2.0 * unit),
		Vector2(belt_rect.end.x - 2.0 * unit, belt_rect.position.y + 2.0 * unit),
		Color(170.0 / 255.0, 105.0 / 255.0, 48.0 / 255.0, 0.82),
		max(1.0, unit)
	)

	var buckle_radius: float = 7.4 * unit
	canvas.draw_circle(center, buckle_radius + 1.3 * unit, Color(135.0 / 255.0, 92.0 / 255.0, 4.0 / 255.0, 1.0))
	canvas.draw_circle(center, buckle_radius, Color(1.0, 214.0 / 255.0, 48.0 / 255.0, 1.0))
	canvas.draw_circle(center, buckle_radius * 0.58, Color(28.0 / 255.0, 35.0 / 255.0, 48.0 / 255.0, 1.0))
	canvas.draw_circle(center, buckle_radius * 0.34, Color(92.0 / 255.0, 190.0 / 255.0, 1.0, 0.82))

	for side in [-1.0, 1.0]:
		var rune_x: float = center.x + side * 8.9 * unit
		canvas.draw_circle(Vector2(rune_x, center.y), 1.3 * unit, Color(105.0 / 255.0, 210.0 / 255.0, 1.0, 0.92))
		canvas.draw_line(Vector2(rune_x - side * 1.8 * unit, center.y - 2.0 * unit), Vector2(rune_x + side * 1.8 * unit, center.y + 2.0 * unit), Color(1.0, 235.0 / 255.0, 150.0 / 255.0, 0.90), max(1.0, unit * 0.8))

	var bolt := PackedVector2Array([
		center + Vector2(-3.0 * unit, -11.0 * unit),
		center + Vector2(1.0 * unit, -3.0 * unit),
		center + Vector2(-1.8 * unit, -3.0 * unit),
		center + Vector2(3.4 * unit, 10.5 * unit),
		center + Vector2(1.0 * unit, 1.0 * unit),
		center + Vector2(4.0 * unit, 1.0 * unit),
	])
	canvas.draw_colored_polygon(bolt, Color(1.0, 240.0 / 255.0, 130.0 / 255.0, 0.95))
	canvas.draw_polyline(bolt, Color.WHITE, max(1.0, 0.9 * unit), true)
	canvas.draw_arc(center, glow_radius + 2.0 * unit * scale_factor, -PI * 0.25, TAU - PI * 0.25, MEGINGJORD_FALLBACK_RING_SEGMENTS, Color(1.0, 220.0 / 255.0, 90.0 / 255.0, 0.24), max(1.0, unit))


func _get_megingjord_icon_sheet() -> Texture2D:
	if _megingjord_icon_sheet != null:
		return _megingjord_icon_sheet
	_megingjord_icon_sheet = ProjectResourceLoader.load_texture(
		MEGINGJORD_ICON_SHEET_PATH,
		"Missing Megingjord animated icon sheet at %s",
		"Failed to load Megingjord animated icon sheet at %s"
	)
	return _megingjord_icon_sheet


func _get_icon_sheet(sheet_path: String) -> Texture2D:
	if _icon_sheet_cache.has(sheet_path):
		var cached_sheet: Variant = _icon_sheet_cache[sheet_path]
		if cached_sheet is Texture2D:
			return cached_sheet as Texture2D
		_icon_sheet_cache.erase(sheet_path)
	var sheet: Texture2D = ProjectResourceLoader.load_texture(
		sheet_path,
		"Missing animated item icon sheet at %s",
		"Failed to load animated item icon sheet at %s"
	)
	if sheet != null:
		_icon_sheet_cache[sheet_path] = sheet
	return sheet


func _get_icon_texture(item_data: Dictionary, visuals) -> Texture2D:
	if visuals != null:
		var module_texture: Variant = visuals.get_icon_texture(item_data)
		if module_texture is Texture2D:
			return module_texture as Texture2D
	return null


func _grow_rect_xy(rect: Rect2, amount: float) -> Rect2:
	var diameter: float = amount * 2.0
	return Rect2(rect.position.x - amount, rect.position.y - amount, rect.size.x + diameter, rect.size.y + diameter)


func _get_item_color(item_data: Dictionary, visuals) -> Color:
	if visuals != null:
		var module_color: Variant = visuals.get_item_color(item_data)
		if module_color is Color:
			return module_color as Color
	return DEFAULT_ITEM_COLOR


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
