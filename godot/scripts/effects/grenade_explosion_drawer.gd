extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const GRENADE_EXPLOSION_FIRE_RINGS := 5
const GRENADE_EXPLOSION_SMOKE_PUFFS := 3
const GRENADE_EXPLOSION_SPARKS := 4
const FIRE_SUPPORT_EXPLOSION_STYLE := "airstrike"
const FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES := 48.0
const FIRE_SUPPORT_TEXTURE_LAYER_COUNT := 12
const FIRE_SUPPORT_SHOCKWAVE_RINGS := 4
const FIRE_SUPPORT_SMOKE_PUFFS := 9
const FIRE_SUPPORT_SPARKS := 14
const FIRE_SUPPORT_DEBRIS_CHUNKS := 12
const FIRE_SUPPORT_MUSHROOM_PUFFS := 5


static func prewarm_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


static func get_texture_layer_count(zone: Dictionary) -> int:
	return FIRE_SUPPORT_TEXTURE_LAYER_COUNT if _is_fire_support_airstrike(zone) else 0


static func are_texture_assets_ready() -> bool:
	return (
		ImpactFlareTextureCache.get_glow_texture() != null
		and ImpactFlareTextureCache.get_burst_texture() != null
		and ImpactFlareTextureCache.get_sparkle_texture() != null
		and ImpactShockwaveTextureCache.get_full_ring_texture() != null
	)


static func draw_zone(canvas: CanvasItem, zone: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not bool(zone.get("active", true)):
		return
	var center: Vector2 = _get_zone_center(zone) + shake_offset
	var radius: float = float(zone.get("radius", GRENADE_EXPLOSION_RADIUS))
	var max_duration: float = max(1.0, float(zone.get("max_duration_frames", GRENADE_EXPLOSION_DURATION_FRAMES)))
	var remaining: float = clamp(float(zone.get("duration_frames", zone.get("timer_frames", max_duration))), 0.0, max_duration)
	var elapsed: float = max_duration - remaining
	var life: float = remaining / max_duration
	var is_airstrike: bool = _is_fire_support_airstrike(zone)
	if is_airstrike:
		_draw_fire_support_airstrike_layers(canvas, center, radius, elapsed, life, zone)

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

	if is_airstrike:
		_draw_fire_support_foreground_sparks(canvas, center, radius, elapsed, life, zone)


static func _get_zone_center(zone: Dictionary) -> Vector2:
	var value: Variant = zone.get("position", zone.get("pos", Vector2.ZERO))
	if value is Vector2:
		return value
	return Vector2.ZERO


static func _is_fire_support_airstrike(zone: Dictionary) -> bool:
	return (
		str(zone.get("explosion_style", "")) == FIRE_SUPPORT_EXPLOSION_STYLE
		or str(zone.get("weapon_id", "")) == "fire_support"
	)


static func _draw_fire_support_airstrike_layers(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float,
	life: float,
	zone: Dictionary
) -> void:
	var color: Color = _get_color(zone.get("color", Color(1.0, 0.34, 0.16)), Color(1.0, 0.34, 0.16))
	var secondary: Color = _get_color(zone.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	var blast_progress: float = clamp(elapsed / 12.0, 0.0, 1.0)

	_draw_fire_support_overpressure_flash(canvas, center, radius, elapsed)

	var bloom_alpha: float = 0.34 * life + 0.28 * (1.0 - blast_progress)
	ImpactFlareTextureCache.draw_glow(canvas, center, radius * (1.20 + blast_progress * 0.42), color, bloom_alpha)
	ImpactFlareTextureCache.draw_burst(canvas, center, radius * (0.72 + blast_progress * 0.34), Color(1.0, 0.93, 0.58), 0.62 * max(life, 1.0 - blast_progress))

	for ring_index in range(FIRE_SUPPORT_SHOCKWAVE_RINGS):
		var ring_lag: float = float(ring_index) * 0.18
		var ring_progress: float = clamp(blast_progress - ring_lag, 0.0, 1.0)
		if ring_progress <= 0.0:
			continue
		var ring_radius: float = radius * (0.62 + ring_progress * (1.40 + float(ring_index) * 0.26))
		var ring_alpha: float = (0.36 - float(ring_index) * 0.05) * life * (1.0 - ring_progress * 0.30)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, ring_radius, secondary, ring_alpha)

	_draw_fire_support_smoke_column(canvas, center, radius, elapsed, life)
	_draw_fire_support_mushroom_cap(canvas, center, radius, elapsed, life)
	_draw_fire_support_debris_chunks(canvas, center, radius, elapsed, life)


static func _draw_fire_support_overpressure_flash(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float
) -> void:
	if elapsed >= 5.0:
		return
	var t: float = clamp(elapsed / 5.0, 0.0, 1.0)
	var flash_alpha: float = pow(1.0 - t, 1.6) * 0.92
	var flash_radius: float = radius * (1.55 + t * 0.40)
	ImpactFlareTextureCache.draw_glow(canvas, center, flash_radius, Color(1.0, 0.98, 0.82), flash_alpha * 0.78)
	canvas.draw_circle(center, radius * (0.32 + t * 0.10), Color(1.0, 0.99, 0.90, flash_alpha))
	canvas.draw_circle(center, radius * (0.62 + t * 0.20), Color(1.0, 0.92, 0.62, flash_alpha * 0.55))


static func _draw_fire_support_mushroom_cap(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float,
	life: float
) -> void:
	if elapsed < 6.0:
		return
	var rise_progress: float = clamp((elapsed - 6.0) / 24.0, 0.0, 1.0)
	var cap_center: Vector2 = center + Vector2(0.0, -radius * (0.40 + rise_progress * 0.55))
	for index in range(FIRE_SUPPORT_MUSHROOM_PUFFS):
		var ratio: float = float(index) / float(max(1, FIRE_SUPPORT_MUSHROOM_PUFFS - 1))
		var angle: float = ratio * PI - PI * 0.5 + sin(elapsed * 0.08 + float(index)) * 0.12
		var offset := Vector2(cos(angle), sin(angle) * 0.55) * radius * (0.36 + rise_progress * 0.20)
		var puff_radius: float = radius * (0.34 + ratio * 0.10) + elapsed * 0.6
		var tone: float = 0.22 - ratio * 0.04
		var alpha: float = (0.22 + ratio * 0.06) * sqrt(life) * (0.55 + rise_progress * 0.45)
		canvas.draw_circle(cap_center + offset, puff_radius, Color(tone, tone * 0.94, tone * 0.82, alpha))
		canvas.draw_circle(cap_center + offset + Vector2(-puff_radius * 0.20, -puff_radius * 0.16), puff_radius * 0.42, Color(0.36, 0.32, 0.26, alpha * 0.42))


static func _draw_fire_support_debris_chunks(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float,
	life: float
) -> void:
	if elapsed >= 28.0:
		return
	var window: float = clamp(1.0 - elapsed / 28.0, 0.0, 1.0)
	for index in range(FIRE_SUPPORT_DEBRIS_CHUNKS):
		var base_angle: float = float(index) * TAU / float(FIRE_SUPPORT_DEBRIS_CHUNKS)
		var jitter: float = sin(float(index) * 2.41) * 0.22
		var angle: float = base_angle + jitter
		var dir := Vector2(cos(angle), sin(angle))
		var speed: float = radius * (0.046 + float((index * 7) % 5) * 0.008)
		var horiz: float = dir.x * speed * elapsed * 60.0 * (1.0 / 60.0)
		var arc_height: float = radius * (0.55 + float(index % 3) * 0.10)
		var horiz_distance: float = horiz
		var arc_t: float = clamp(elapsed / 20.0, 0.0, 1.0)
		var vert: float = -arc_height * (1.0 - pow(2.0 * arc_t - 1.0, 2.0)) + dir.y * speed * elapsed * 30.0 * (1.0 / 60.0)
		var pos := center + Vector2(horiz_distance, vert)
		var size: float = 3.4 + float((index * 13) % 4) * 0.7
		var alpha: float = window * (0.78 - float(index % 4) * 0.10) * (0.65 + life * 0.35)
		var rect_color := Color(0.20, 0.16, 0.13, alpha)
		var trail_color := Color(0.55, 0.42, 0.28, alpha * 0.50)
		var trail_start: Vector2 = pos - dir * size * 2.8
		canvas.draw_line(trail_start, pos, trail_color, max(1.0, size * 0.45), true)
		canvas.draw_circle(pos, size, rect_color)
		if index % 4 == 0:
			canvas.draw_circle(pos + Vector2(-size * 0.3, -size * 0.3), size * 0.4, Color(1.0, 0.78, 0.40, alpha * 0.7))


static func _draw_fire_support_smoke_column(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float,
	life: float
) -> void:
	var lingering: float = sqrt(clamp(life, 0.0, 1.0))
	for index in range(FIRE_SUPPORT_SMOKE_PUFFS):
		var ratio: float = float(index) / float(max(1, FIRE_SUPPORT_SMOKE_PUFFS - 1))
		var angle: float = ratio * TAU * 1.35 + elapsed * 0.055
		var drift := Vector2(cos(angle) * radius * (0.10 + ratio * 0.18), -elapsed * (1.15 + ratio * 0.35))
		var smoke_pos: Vector2 = center + drift + Vector2(sin(elapsed * 0.10 + float(index)) * 9.0, -radius * ratio * 0.18)
		var smoke_radius: float = radius * (0.28 + ratio * 0.26) + elapsed * (1.3 + ratio * 0.8)
		var tone: float = 0.20 + ratio * 0.07
		var alpha: float = (0.22 + ratio * 0.08) * lingering
		canvas.draw_circle(smoke_pos, smoke_radius, Color(tone, tone * 0.92, tone * 0.78, alpha))
		canvas.draw_circle(smoke_pos + Vector2(-smoke_radius * 0.22, -smoke_radius * 0.18), smoke_radius * 0.42, Color(0.36, 0.32, 0.26, alpha * 0.45))


static func _draw_fire_support_foreground_sparks(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float,
	life: float,
	zone: Dictionary
) -> void:
	var secondary: Color = _get_color(zone.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	var spark_window: float = clamp(1.0 - elapsed / 16.0, 0.0, 1.0)
	if spark_window <= 0.0:
		return
	for index in range(FIRE_SUPPORT_SPARKS):
		var angle: float = float(index) * TAU / float(FIRE_SUPPORT_SPARKS) + sin(float(index) * 1.93) * 0.22
		var dir := Vector2(cos(angle), sin(angle))
		var length: float = radius * (0.62 + float(index % 4) * 0.14) + elapsed * (6.2 + float(index % 3) * 1.6)
		var start: Vector2 = center + dir * radius * 0.16
		var end: Vector2 = center + dir * length
		var alpha: float = (0.84 - float(index % 3) * 0.09) * spark_window * sqrt(life)
		canvas.draw_line(start, end, Color(1.0, 0.94, 0.54, alpha), 2.8, true)
		canvas.draw_line(start + dir * length * 0.10, end, Color(1.0, 0.80, 0.32, alpha * 0.6), 1.4, true)
		if index % 4 == 0:
			ImpactFlareTextureCache.draw_sparkle(canvas, end, radius * 0.10, secondary, alpha * 0.55)


static func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
