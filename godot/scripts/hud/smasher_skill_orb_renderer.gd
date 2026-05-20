extends RefCounted

const SmasherSkillOrbUnderlayRenderer := preload("res://scripts/hud/smasher_skill_orb_underlay_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")

const HEAVENLY_CAPE_SLOT_START_ANGLE := 144.0

var underlay_renderer: Object = SmasherSkillOrbUnderlayRenderer.new()
var slot_renderer: Object = SmasherSkillOrbSlotRenderer.new()
var _slot_positions_cache_key: String = ""
var _slot_positions_cache: Array[Vector2] = []
var _slot_angles_cache: Dictionary = {}


func draw(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	draw_underlay(canvas, center, orb_radius, scale_factor, context)
	draw_orbs(canvas, center, orb_radius, t, scale_factor, context)


func draw_underlay(canvas: CanvasItem, center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var icon_radius: float = float(context.get("skill_orb_radius", 24.0)) * scale_factor
	var max_slots: int = int(context.get("max_slots", 5))
	var positions: Array[Vector2] = _get_slot_positions(
		center,
		orb_radius,
		icon_radius,
		max_slots,
		float(context.get("gauge_gap", 28.0)),
		float(context.get("orb_radius_base", 55.0)),
		float(context.get("slot_base_angle", 165.0)),
		float(context.get("slot_angle_step", 33.0))
	)

	underlay_renderer.draw(canvas, center, orb_radius, icon_radius, positions, scale_factor, context)


func draw_orbs(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var icon_radius: float = float(context.get("skill_orb_radius", 24.0)) * scale_factor
	var max_slots: int = int(context.get("max_slots", 5))
	var positions: Array[Vector2] = _get_slot_positions(
		center,
		orb_radius,
		icon_radius,
		max_slots,
		float(context.get("gauge_gap", 28.0)),
		float(context.get("orb_radius_base", 55.0)),
		float(context.get("slot_base_angle", 165.0)),
		float(context.get("slot_angle_step", 33.0))
	)

	slot_renderer.draw(canvas, center, icon_radius, positions, t, scale_factor, context)


func get_slot_positions(center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> Array[Vector2]:
	var icon_radius: float = float(context.get("skill_orb_radius", 24.0)) * scale_factor
	return _get_slot_positions(
		center,
		orb_radius,
		icon_radius,
		int(context.get("max_slots", 5)),
		float(context.get("gauge_gap", 28.0)),
		float(context.get("orb_radius_base", 55.0)),
		float(context.get("slot_base_angle", 165.0)),
		float(context.get("slot_angle_step", 33.0))
	)


func get_cluster_bounds(center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> Rect2:
	var icon_radius: float = float(context.get("skill_orb_radius", 24.0)) * scale_factor
	var frame_safe_pad: float = float(context.get("frame_safe_pad", 8.0)) * scale_factor
	var socket_overlap: float = float(context.get("socket_overlap", 1.0)) * scale_factor
	var pad: float = icon_radius + frame_safe_pad + socket_overlap + 5.0 * scale_factor
	var min_x: float = center.x - orb_radius - pad
	var max_x: float = center.x + orb_radius + pad
	var min_y: float = center.y - orb_radius - pad
	var max_y: float = center.y + orb_radius + pad
	for slot_pos in get_slot_positions(center, orb_radius, scale_factor, context):
		min_x = min(min_x, slot_pos.x - pad)
		max_x = max(max_x, slot_pos.x + pad)
		min_y = min(min_y, slot_pos.y - pad)
		max_y = max(max_y, slot_pos.y + pad)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _get_orbit_radius(orb_radius: float, icon_radius: float, gauge_gap: float, orb_radius_base: float) -> float:
	return orb_radius + icon_radius + gauge_gap * (orb_radius / orb_radius_base)


func _get_slot_angles(max_slots: int, base_angle: float, angle_step: float) -> Array[float]:
	var slot_count: int = max(0, max_slots)
	var angle_key: String = "%d|%.3f|%.3f" % [slot_count, base_angle, angle_step]
	var cached: Variant = _slot_angles_cache.get(angle_key, null)
	if cached is Array:
		return cached
	var angles: Array[float] = []
	if slot_count == 6:
		for i in range(slot_count):
			angles.append(HEAVENLY_CAPE_SLOT_START_ANGLE + float(i) * angle_step)
		_slot_angles_cache[angle_key] = angles
		return angles

	for i in range(slot_count):
		var angle: float = base_angle + float(i) * angle_step
		if slot_count >= 5 and i >= 4:
			angle += 5.0
		angles.append(angle)
	_slot_angles_cache[angle_key] = angles
	return angles


func _get_slot_positions(
	center: Vector2,
	orb_radius: float,
	icon_radius: float,
	max_slots: int,
	gauge_gap: float,
	orb_radius_base: float,
	base_angle: float,
	angle_step: float
) -> Array[Vector2]:
	var cache_key: String = "%s|%.3f|%.3f|%d|%.3f|%.3f|%.3f|%.3f" % [
		center,
		orb_radius,
		icon_radius,
		max_slots,
		gauge_gap,
		orb_radius_base,
		base_angle,
		angle_step,
	]
	if cache_key == _slot_positions_cache_key:
		return _slot_positions_cache
	var positions: Array[Vector2] = []
	var orbit_radius: float = _get_orbit_radius(orb_radius, icon_radius, gauge_gap, orb_radius_base)
	for angle_deg in _get_slot_angles(max_slots, base_angle, angle_step):
		var angle_rad: float = deg_to_rad(angle_deg)
		positions.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * orbit_radius)
	_slot_positions_cache_key = cache_key
	_slot_positions_cache = positions
	return positions
