extends RefCounted
class_name PremiumPanelFrame

const KIND_MAIN := 0
const KIND_SECTION := 1
const KIND_SLOT := 2
const KIND_CELL := 3

const _MAIN_RADIUS := 12
const _SECTION_RADIUS := 8
const _SLOT_RADIUS := 6
const _CELL_RADIUS := 4

const _MAIN_BORDER_WIDTH := 3
const _SECTION_BORDER_WIDTH := 2
const _SLOT_BORDER_WIDTH := 2
const _CELL_BORDER_WIDTH := 1

const _MAIN_HALO_WIDTH := 4
const _MAIN_HALO_GROW := 2.0

static var _box_main: StyleBoxFlat
static var _box_section: StyleBoxFlat
static var _box_slot: StyleBoxFlat
static var _box_cell: StyleBoxFlat
static var _halo_main: StyleBoxFlat


static func draw_panel(canvas: CanvasItem, rect: Rect2, kind: int, fill: Color, border: Color, border_width: float = -1.0) -> void:
	if canvas == null:
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_ensure()
	if kind == KIND_MAIN:
		_configure_halo(_halo_main, border)
		canvas.draw_style_box(_halo_main, rect.grow(_MAIN_HALO_GROW))
	var box: StyleBoxFlat = _configure_box(kind, fill, border, border_width)
	canvas.draw_style_box(box, rect)


static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, color: Color, pulse_alpha: float = 1.0, corner_scale: float = 0.24, max_corner: float = -1.0) -> void:
	if canvas == null:
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var alpha: float = clamp(color.a * pulse_alpha, 0.0, 1.0)
	var line_color := Color(color.r, color.g, color.b, alpha)
	var corner: float = max(1.0, min(rect.size.x, rect.size.y) * maxf(0.0, corner_scale))
	if max_corner > 0.0:
		corner = minf(max_corner, corner)
	var weight := 1.6
	canvas.draw_line(rect.position, rect.position + Vector2(corner, 0.0), line_color, weight)
	canvas.draw_line(rect.position, rect.position + Vector2(0.0, corner), line_color, weight)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - corner, rect.position.y), line_color, weight)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + corner), line_color, weight)
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + corner, rect.end.y), line_color, weight)
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - corner), line_color, weight)
	canvas.draw_line(rect.end, rect.end - Vector2(corner, 0.0), line_color, weight)
	canvas.draw_line(rect.end, rect.end - Vector2(0.0, corner), line_color, weight)


static func cache_instance_ids_for_tests() -> Dictionary:
	_ensure()
	return {
		"main": _box_main.get_instance_id(),
		"section": _box_section.get_instance_id(),
		"slot": _box_slot.get_instance_id(),
		"cell": _box_cell.get_instance_id(),
		"halo": _halo_main.get_instance_id(),
	}


static func configure_box_for_tests(kind: int, fill: Color, border: Color, border_width: float = -1.0) -> StyleBoxFlat:
	_ensure()
	return _configure_box(kind, fill, border, border_width)


static func geometry_snapshot_for_tests() -> Dictionary:
	_ensure()
	return {
		"main": _snapshot(_box_main),
		"section": _snapshot(_box_section),
		"slot": _snapshot(_box_slot),
		"cell": _snapshot(_box_cell),
		"halo": _snapshot(_halo_main),
	}


static func _ensure() -> void:
	if _box_main != null:
		return
	_box_main = _make_box(_MAIN_RADIUS, _MAIN_BORDER_WIDTH, 10, Color(0.0, 0.0, 0.0, 0.38), Vector2(0.0, 5.0), true)
	_box_section = _make_box(_SECTION_RADIUS, _SECTION_BORDER_WIDTH, 6, Color(0.0, 0.0, 0.0, 0.30), Vector2(0.0, 3.0), true)
	_box_slot = _make_box(_SLOT_RADIUS, _SLOT_BORDER_WIDTH, 0, Color.TRANSPARENT, Vector2.ZERO, true)
	_box_cell = _make_box(_CELL_RADIUS, _CELL_BORDER_WIDTH, 0, Color.TRANSPARENT, Vector2.ZERO, true)
	_halo_main = _make_box(_MAIN_RADIUS + _MAIN_HALO_WIDTH, _MAIN_HALO_WIDTH, 0, Color.TRANSPARENT, Vector2.ZERO, false)


static func _make_box(radius: int, border_width: int, shadow_size: int, shadow_color: Color, shadow_offset: Vector2, draw_center: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = draw_center
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color.TRANSPARENT
	box.anti_aliasing = true
	box.corner_detail = 6
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	_set_border_width(box, border_width)
	box.shadow_size = shadow_size
	box.shadow_color = shadow_color
	box.shadow_offset = shadow_offset
	return box


static func _configure_box(kind: int, fill: Color, border: Color, border_width: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = _box_for_kind(kind)
	box.bg_color = fill
	box.border_color = border
	var width: int = _default_border_width(kind) if border_width < 0.0 else max(0, int(round(border_width)))
	_set_border_width(box, width)
	return box


static func _configure_halo(box: StyleBoxFlat, border: Color) -> void:
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(border.r, border.g, border.b, border.a * 0.20)
	_set_border_width(box, _MAIN_HALO_WIDTH)


static func _box_for_kind(kind: int) -> StyleBoxFlat:
	match kind:
		KIND_MAIN:
			return _box_main
		KIND_SLOT:
			return _box_slot
		KIND_CELL:
			return _box_cell
		_:
			return _box_section


static func _default_border_width(kind: int) -> int:
	match kind:
		KIND_MAIN:
			return _MAIN_BORDER_WIDTH
		KIND_SLOT:
			return _SLOT_BORDER_WIDTH
		KIND_CELL:
			return _CELL_BORDER_WIDTH
		_:
			return _SECTION_BORDER_WIDTH


static func _set_border_width(box: StyleBoxFlat, width: int) -> void:
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width


static func _snapshot(box: StyleBoxFlat) -> Dictionary:
	return {
		"radius": box.corner_radius_top_left,
		"border_width": box.border_width_left,
		"shadow_size": box.shadow_size,
		"anti_aliasing": box.anti_aliasing,
		"corner_detail": box.corner_detail,
		"draw_center": box.draw_center,
	}
