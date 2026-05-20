extends RefCounted


func draw(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	radius: float,
	t: float,
	scale_factor: float,
	full_ratio: float,
	context: Dictionary = {}
) -> void:
	if canvas == null or pillar_drawer == null:
		return

	var palette: Dictionary = _get_fill_palette(full_ratio)
	var fill_top_color: Color = palette["top"]
	var fill_bottom_color: Color = palette["bottom"]
	var wave_glow: Color = palette["glow"]
	# The static-LOD fallback rendered just a couple of circles + an arc, which read
	# as broken when the player actually saw it (see "weird liquid fill" report).
	# Always use the proper liquid wave; the LOD path inside draw_pillar_liquid_fill
	# already drops detail for Viper-airborne / FPS-cap frames via hud_lod_scale.
	pillar_drawer.draw_pillar_liquid_fill(
		canvas,
		center,
		radius - 5.0 * scale_factor,
		full_ratio,
		t,
		fill_top_color,
		fill_bottom_color,
		wave_glow,
		float(context.get("hud_lod_scale", 1.0))
	)
	_draw_fill_glow(canvas, center, radius, full_ratio, wave_glow)


func _get_fill_palette(full_ratio: float) -> Dictionary:
	var fill_top_color: Color = Color(0.36, 0.70, 1.0, 1.0)
	var fill_bottom_color: Color = Color(0.10, 0.26, 0.72, 1.0)
	var wave_glow: Color = Color(0.82, 0.94, 1.0, 1.0)
	if full_ratio >= 0.999:
		fill_top_color = Color(1.0, 0.92, 0.62, 1.0)
		fill_bottom_color = Color(0.70, 0.52, 0.16, 1.0)
		wave_glow = Color(1.0, 0.95, 0.82, 1.0)
	elif full_ratio >= 0.75:
		fill_top_color = Color(0.58, 0.86, 1.0, 1.0)
		fill_bottom_color = Color(0.18, 0.46, 0.88, 1.0)
	elif full_ratio < 0.35:
		fill_top_color = Color(0.22, 0.46, 0.92, 1.0)
		fill_bottom_color = Color(0.07, 0.17, 0.48, 1.0)
	return {
		"top": fill_top_color,
		"bottom": fill_bottom_color,
		"glow": wave_glow,
	}


func _draw_fill_glow(canvas: CanvasItem, center: Vector2, radius: float, full_ratio: float, wave_glow: Color) -> void:
	if full_ratio <= 0.0:
		return
	canvas.draw_circle(center, radius * (0.20 + full_ratio * 0.24), Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.12 + full_ratio * 0.16))
	canvas.draw_circle(center + Vector2(0.0, radius * 0.10), radius * (0.10 + full_ratio * 0.12), Color(1.0, 1.0, 1.0, 0.06 + full_ratio * 0.07))


func _draw_static_fill(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	full_ratio: float,
	fill_top_color: Color,
	fill_bottom_color: Color,
	wave_glow: Color
) -> void:
	if full_ratio <= 0.0:
		return
	var fill_radius: float = inner_radius * (0.28 + 0.58 * sqrt(clamp(full_ratio, 0.0, 1.0)))
	canvas.draw_circle(center, fill_radius, Color(fill_bottom_color.r, fill_bottom_color.g, fill_bottom_color.b, 0.74))
	canvas.draw_circle(center + Vector2(0.0, -fill_radius * 0.18), fill_radius * 0.72, Color(fill_top_color.r, fill_top_color.g, fill_top_color.b, 0.38))
	canvas.draw_arc(center, inner_radius * 0.82, -PI * 0.5, -PI * 0.5 + TAU * full_ratio, 14, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.46), 2.0, true)
