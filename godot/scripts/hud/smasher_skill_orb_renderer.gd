extends RefCounted

const SmasherSkillOrbUnderlayRenderer := preload("res://scripts/hud/smasher_skill_orb_underlay_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")

var underlay_renderer: Object = SmasherSkillOrbUnderlayRenderer.new()
var slot_renderer: Object = SmasherSkillOrbSlotRenderer.new()


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
		float(context.get("orb_radius_base", 55.0))
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
		float(context.get("orb_radius_base", 55.0))
	)

	slot_renderer.draw(canvas, center, icon_radius, positions, t, scale_factor, context)


func _get_orbit_radius(orb_radius: float, icon_radius: float, gauge_gap: float, orb_radius_base: float) -> float:
	return orb_radius + icon_radius + gauge_gap * (orb_radius / orb_radius_base)


func _get_slot_angles(max_slots: int) -> Array[float]:
	var slot_count: int = max(0, max_slots)
	var angles: Array[float] = []
	if slot_count == 6:
		for i in range(slot_count):
			angles.append(150.0 + float(i) * 33.0)
		return angles

	for i in range(slot_count):
		var angle: float = 165.0 + float(i) * 33.0
		if slot_count >= 5 and i >= 4:
			angle += 5.0
		angles.append(angle)
	return angles


func _get_slot_positions(
	center: Vector2,
	orb_radius: float,
	icon_radius: float,
	max_slots: int,
	gauge_gap: float,
	orb_radius_base: float
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var orbit_radius: float = _get_orbit_radius(orb_radius, icon_radius, gauge_gap, orb_radius_base)
	for angle_deg in _get_slot_angles(max_slots):
		var angle_rad: float = deg_to_rad(angle_deg)
		positions.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * orbit_radius)
	return positions

