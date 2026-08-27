extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const DefeatContinueVisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")

const AMBIENT_DIVINE_MOTE_COUNT := 34
const AMBIENT_DIVINE_RAY_COUNT := 9
const AMBIENT_DIVINE_PORTAL_BREATH_HZ := 0.08


static func get_status(
	active: bool,
	continue_reset_fired: bool,
	elapsed_sec: float,
	consume_boost: float,
	view_size: Vector2
) -> Dictionary:
	var is_visible := active and not continue_reset_fired and view_size.x > 1.0 and view_size.y > 1.0
	var breath := 0.5 + 0.5 * sin(elapsed_sec * TAU * AMBIENT_DIVINE_PORTAL_BREATH_HZ)
	var strength := (1.0 + consume_boost) if is_visible else 0.0
	return {
		"active": is_visible,
		"breath": breath,
		"strength": strength,
		"portal_glow_alpha": (0.20 + breath * 0.10) * strength,
		"ray_alpha": (0.022 + breath * 0.016) * strength,
		"mote_alpha": 0.44 * strength,
		"mote_count": AMBIENT_DIVINE_MOTE_COUNT,
		"ray_count": AMBIENT_DIVINE_RAY_COUNT,
		"clock_sec": elapsed_sec,
		"single_clock": true,
	}


static func draw_ambient_divine_motion(canvas: CanvasItem, view_size: Vector2, elapsed_sec: float, status: Dictionary) -> void:
	if canvas == null or not bool(status.get("active", false)):
		return
	var portal_center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 344.0))
	_draw_ambient_portal_glow(canvas, portal_center, view_size, status)
	_draw_ambient_light_shafts(canvas, portal_center, view_size, elapsed_sec, status)
	_draw_ambient_divine_motes(canvas, portal_center, view_size, elapsed_sec, status)


static func _draw_ambient_portal_glow(canvas: CanvasItem, portal_center: Vector2, view_size: Vector2, status: Dictionary) -> void:
	var glow_alpha := float(status.get("portal_glow_alpha", 0.0))
	if glow_alpha <= 0.001:
		return
	var breath := float(status.get("breath", 0.0))
	var radius := minf(view_size.x, view_size.y) * (0.28 + breath * 0.045)
	var ghost_jade := Color(0.30, 0.64, 0.53, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, portal_center, radius, ghost_jade, glow_alpha)
	ImpactFlareTextureCache.draw_burst(canvas, portal_center, radius * 0.68, Color(0.72, 0.78, 0.62, 1.0), glow_alpha * 0.18)
	var ring_radius := minf(view_size.x, view_size.y) * (0.24 + breath * 0.03)
	var ring_rect := Rect2(portal_center - Vector2(ring_radius, ring_radius * 0.57), Vector2(ring_radius * 2.0, ring_radius * 1.14))
	_draw_ellipse_arc(canvas, ring_rect, -PI * 0.94, -PI * 0.08, Color(0.38, 0.70, 0.56, glow_alpha * 0.52), 1.2)
	_draw_ellipse_arc(canvas, ring_rect, PI * 1.08, PI * 1.88, Color(0.72, 0.58, 0.32, glow_alpha * 0.38), 0.9)


static func _draw_ambient_light_shafts(
	canvas: CanvasItem,
	portal_center: Vector2,
	view_size: Vector2,
	elapsed_sec: float,
	status: Dictionary
) -> void:
	var base_alpha := float(status.get("ray_alpha", 0.0))
	if base_alpha <= 0.001:
		return
	var upper_y := -view_size.y * 0.08
	for i in range(AMBIENT_DIVINE_RAY_COUNT):
		var ratio := float(i) / float(maxi(1, AMBIENT_DIVINE_RAY_COUNT - 1))
		var phase := elapsed_sec * TAU * (0.052 + float(i % 3) * 0.006) + float(i) * 1.37
		var wave := 0.5 + 0.5 * sin(phase)
		var top_x := lerpf(view_size.x * 0.18, view_size.x * 0.82, ratio)
		top_x += sin(phase * 0.37) * 32.0
		var target_x := top_x + sin(phase * 0.52) * 34.0
		var target_y := view_size.y * 0.74 + wave * 18.0
		var half_width := 4.0 + wave * 4.0
		var alpha := base_alpha * (0.45 + 0.55 * wave)
		var start := Vector2(top_x, upper_y)
		var end := Vector2(target_x, target_y)
		canvas.draw_line(start, end, Color(0.42, 0.62, 0.52, alpha), half_width, true)


static func _draw_ambient_divine_motes(
	canvas: CanvasItem,
	portal_center: Vector2,
	view_size: Vector2,
	elapsed_sec: float,
	status: Dictionary
) -> void:
	var base_alpha := float(status.get("mote_alpha", 0.0))
	if base_alpha <= 0.001:
		return
	var span_x := minf(view_size.x * 0.56, 760.0)
	var top_y := _scaled_y(view_size, 176.0)
	var bottom_y := _scaled_y(view_size, 650.0)
	for i in range(AMBIENT_DIVINE_MOTE_COUNT):
		var seed := fposmod(float(i) * 0.61803398875, 1.0)
		var speed := 0.050 + float(i % 5) * 0.006
		var rise := fposmod(seed + elapsed_sec * speed, 1.0)
		var fade := sin(rise * PI)
		if fade <= 0.001:
			continue
		var sway := sin(elapsed_sec * TAU * (0.036 + float(i % 4) * 0.006) + seed * TAU * 2.0)
		var x := portal_center.x + (seed - 0.5) * span_x + sway * (28.0 + float(i % 3) * 12.0)
		var y := lerpf(bottom_y, top_y, rise) + sin(seed * TAU * 3.0 + elapsed_sec * TAU * 0.07) * 16.0
		if x < -16.0 or x > view_size.x + 16.0 or y < -16.0 or y > view_size.y + 16.0:
			continue
		var depth := 0.62 + 0.38 * fposmod(seed * 3.71, 1.0)
		var radius := 5.6 + depth * 6.8
		var alpha := base_alpha * fade * depth
		var color := Color(0.44 + depth * 0.12, 0.68 + depth * 0.15, 0.57 + depth * 0.10, 1.0)
		var mote_center := Vector2(x, y)
		canvas.draw_circle(mote_center, 0.7 + depth * 1.25, Color(color.r, color.g, color.b, alpha))
		canvas.draw_line(mote_center, mote_center + Vector2(-sway * 2.0, 5.0 + depth * 4.0), Color(color.r, color.g, color.b, alpha * 0.34), 0.75)
		if i % 4 == 0:
			ImpactFlareTextureCache.draw_glow(canvas, mote_center, radius * 2.2, color, alpha * 0.28)


static func _draw_ellipse_arc(
	canvas: CanvasItem,
	rect: Rect2,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x := rect.size.x * 0.5
	var radius_y := rect.size.y * 0.5
	for i in range(28):
		var t := float(i) / 27.0
		var angle := start_angle + (end_angle - start_angle) * t
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width)


static func _scaled_y(view_size: Vector2, base_y: float) -> float:
	return DefeatContinueVisualProjection.scaled_y(view_size, base_y)
