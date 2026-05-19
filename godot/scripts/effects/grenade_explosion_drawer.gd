extends RefCounted

const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const GRENADE_EXPLOSION_FIRE_RINGS := 5
const GRENADE_EXPLOSION_SMOKE_PUFFS := 3
const GRENADE_EXPLOSION_SPARKS := 4


static func draw_zone(canvas: CanvasItem, zone: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not bool(zone.get("active", true)):
		return
	var center: Vector2 = _get_zone_center(zone) + shake_offset
	var radius: float = float(zone.get("radius", GRENADE_EXPLOSION_RADIUS))
	var max_duration: float = max(1.0, float(zone.get("max_duration_frames", GRENADE_EXPLOSION_DURATION_FRAMES)))
	var remaining: float = clamp(float(zone.get("duration_frames", zone.get("timer_frames", max_duration))), 0.0, max_duration)
	var elapsed: float = max_duration - remaining
	var life: float = remaining / max_duration

	var shockwave_radius: float = radius + elapsed * 6.0
	if shockwave_radius < radius * 2.5:
		canvas.draw_arc(center, shockwave_radius, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.18 * life), 4.0)

	var fire_scale: float = min(1.0, (elapsed + 1.0) / 3.0) if elapsed < 4.0 else max(0.0, 1.0 - (elapsed - 4.0) / 21.0)
	var fire_radius: float = radius * fire_scale
	if fire_radius > 3.0:
		for step in range(0, GRENADE_EXPLOSION_FIRE_RINGS):
			var ratio: float = 1.0 - float(step) / float(GRENADE_EXPLOSION_FIRE_RINGS)
			var ring_radius: float = max(2.0, fire_radius * ratio)
			var color: Color
			if remaining > max_duration * 0.65:
				color = Color(1.0, lerp(155.0 / 255.0, 1.0, ratio), lerp(50.0 / 255.0, 200.0 / 255.0, ratio), 0.78 * life * ratio)
			elif remaining > max_duration * 0.3:
				color = Color(1.0, lerp(50.0 / 255.0, 150.0 / 255.0, ratio), lerp(10.0 / 255.0, 50.0 / 255.0, ratio), 0.72 * life * ratio)
			else:
				color = Color(lerp(100.0 / 255.0, 200.0 / 255.0, ratio), lerp(10.0 / 255.0, 50.0 / 255.0, ratio), 30.0 / 255.0, 0.58 * life * ratio)
			canvas.draw_circle(center, ring_radius, color)

	var smoke_radius: float = radius * 0.6 + elapsed * 3.0
	for j in range(GRENADE_EXPLOSION_SMOKE_PUFFS):
		var angle: float = float(j) * TAU / float(GRENADE_EXPLOSION_SMOKE_PUFFS) + elapsed * 0.09
		var distance: float = 16.0 + float((j * 17) % 31)
		var offset := Vector2(cos(angle), sin(angle)) * distance + Vector2(0.0, -elapsed * 1.5)
		var smoke_alpha: float = 0.22 * life
		var tone: float = 0.22 + float(j % 3) * 0.04
		canvas.draw_circle(center + offset, smoke_radius * (0.42 + float(j % 2) * 0.08), Color(tone, tone * 0.9, tone * 0.78, smoke_alpha))

	if elapsed < 6.0:
		var spark_alpha: float = 0.78 * (1.0 - elapsed / 6.0)
		for k in range(GRENADE_EXPLOSION_SPARKS):
			var angle: float = float(k) * TAU / float(GRENADE_EXPLOSION_SPARKS) + sin(float(k) * 2.17 + elapsed) * 0.22
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius * 0.7 + float((k * 11) % 21))
			canvas.draw_line(center, end_pos, Color(1.0, 1.0, 200.0 / 255.0, spark_alpha), 2.0)
			canvas.draw_circle(end_pos, 4.0, Color(1.0, 1.0, 220.0 / 255.0, spark_alpha * 0.6))

	if elapsed < 3.0:
		var flash_alpha: float = 0.78 * (1.0 - elapsed / 3.0)
		canvas.draw_circle(center, radius * 0.4, Color(1.0, 250.0 / 255.0, 230.0 / 255.0, flash_alpha))


static func _get_zone_center(zone: Dictionary) -> Vector2:
	var value: Variant = zone.get("position", zone.get("pos", Vector2.ZERO))
	if value is Vector2:
		return value
	return Vector2.ZERO
