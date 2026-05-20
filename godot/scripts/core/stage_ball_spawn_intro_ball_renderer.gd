extends RefCounted

const EnergyBallRenderer := preload("res://scripts/ball/energy_ball_renderer.gd")

var _energy_ball_renderer: Object = null


func _ensure_energy_renderer() -> Object:
	if _energy_ball_renderer == null:
		_energy_ball_renderer = EnergyBallRenderer.new()
	return _energy_ball_renderer


func clear() -> void:
	if _energy_ball_renderer != null and _energy_ball_renderer.has_method("clear"):
		_energy_ball_renderer.clear()


func draw_landing_shockwave(
	canvas: CanvasItem,
	center: Vector2,
	t: float,
	ball_render_radius: float,
	glow_texture: Texture2D
) -> void:
	if t <= 0.0:
		return
	var max_radius: float = ball_render_radius * 7.5
	var radius: float = max_radius * pow(t, 0.55)
	var fade: float = 1.0 - t
	for i in range(3):
		var rr: float = radius * (1.0 - float(i) * 0.18)
		if rr < 4.0:
			continue
		var ra: float = fade * (0.55 - float(i) * 0.12)
		if ra <= 0.02:
			continue
		canvas.draw_arc(center, rr, 0.0, TAU, 40, Color(0.78, 0.94, 1.0, ra), 2.5 + float(i) * 0.6, true)

	var bloom_diam: float = ball_render_radius * 6.0 * (0.5 + t * 0.5)
	canvas.draw_texture_rect(
		glow_texture,
		Rect2(center.x - bloom_diam * 0.5, center.y - bloom_diam * 0.5, bloom_diam, bloom_diam),
		false,
		Color(0.85, 0.96, 1.0, fade * 0.42),
	)


func draw_phase3_trail(
	canvas: CanvasItem,
	phase3_trail: Array,
	ball_render_radius: float,
	glow_texture: Texture2D
) -> void:
	var trail_len: int = phase3_trail.size()
	if trail_len < 2:
		return
	var ghost_colors: Array = [
		Color(1.0, 1.0, 1.0),
		Color(0.84, 0.90, 1.0),
		Color(0.71, 0.78, 1.0),
		Color(0.62, 0.71, 0.94),
		Color(0.55, 0.63, 0.86),
	]
	@warning_ignore("integer_division")
	var step: int = max(1, trail_len / 8)
	var i: int = 0
	while i < trail_len - 1:
		var ratio: float = float(i) / float(trail_len)
		var alpha: float = 0.50 * ratio * ratio
		if alpha < 0.025:
			i += step
			continue
		var pos: Vector2 = phase3_trail[i]
		var ghost_r: float = max(2.0, ball_render_radius * (0.4 + ratio * 0.5))
		var color_idx: int = clampi(int((1.0 - ratio) * float(ghost_colors.size())), 0, ghost_colors.size() - 1)
		var gc: Color = ghost_colors[color_idx]
		var diam: float = ghost_r * 4.0
		canvas.draw_texture_rect(
			glow_texture,
			Rect2(pos.x - diam * 0.5, pos.y - diam * 0.5, diam, diam),
			false,
			Color(gc.r, gc.g, gc.b, alpha)
		)
		i += step


func draw_ball(
	canvas: CanvasItem,
	pos: Vector2,
	scale: float,
	alpha: float,
	elapsed_sec: float,
	ball_render_radius: float,
	glow_texture: Texture2D,
	ball_texture: Texture2D,
	draw_body: bool = true
) -> void:
	var radius: float = max(2.0, ball_render_radius * scale)
	var t: float = elapsed_sec

	var halo_diam: float = radius * 13.0
	canvas.draw_texture_rect(
		ball_texture,
		Rect2(pos.x - halo_diam * 0.5, pos.y - halo_diam * 0.5, halo_diam, halo_diam),
		false,
		Color(0.42, 0.78, 1.0, alpha * 0.22),
	)

	var chroma_off: float = radius * 0.10 + sin(t * 3.4) * radius * 0.04
	var chroma_diam: float = radius * 7.5
	var pink_pos: Vector2 = pos + Vector2(chroma_off, -chroma_off * 0.4)
	var cyan_pos: Vector2 = pos + Vector2(-chroma_off, chroma_off * 0.4)
	canvas.draw_texture_rect(
		ball_texture,
		Rect2(pink_pos.x - chroma_diam * 0.5, pink_pos.y - chroma_diam * 0.5, chroma_diam, chroma_diam),
		false,
		Color(1.0, 0.62, 0.88, alpha * 0.32),
	)
	canvas.draw_texture_rect(
		ball_texture,
		Rect2(cyan_pos.x - chroma_diam * 0.5, cyan_pos.y - chroma_diam * 0.5, chroma_diam, chroma_diam),
		false,
		Color(0.40, 0.92, 1.0, alpha * 0.34),
	)

	var ring_radius: float = radius * 1.55 + sin(t * 7.0) * radius * 0.12
	var ring_count: int = 22
	for i in range(ring_count):
		var ang: float = TAU * float(i) / float(ring_count) + t * 2.4
		var rp: Vector2 = pos + Vector2(cos(ang), sin(ang)) * ring_radius
		var beat: float = 0.5 + 0.5 * sin(ang * 3.0 + t * 6.0)
		var ring_alpha: float = alpha * (0.30 + 0.60 * pow(beat, 2.0))
		if ring_alpha > 0.04:
			canvas.draw_circle(rp, 1.4, Color(0.72, 0.94, 1.0, ring_alpha))

	var orbital_count: int = 5
	for i in range(orbital_count):
		var orbit_speed: float = 3.6 + float(i) * 0.7
		var orbit_radius: float = radius * (1.30 + 0.32 * sin(t * 1.8 + float(i) * 1.3))
		var oa: float = t * orbit_speed + float(i) * TAU / float(orbital_count)
		var op: Vector2 = pos + Vector2(cos(oa), sin(oa)) * orbit_radius
		var od: float = radius * 1.4
		canvas.draw_texture_rect(
			glow_texture,
			Rect2(op.x - od * 0.5, op.y - od * 0.5, od, od),
			false,
			Color(0.85, 0.96, 1.0, alpha * 0.85),
		)
		canvas.draw_circle(op, 1.6, Color(1.0, 1.0, 1.0, alpha))

	if draw_body and alpha > 0.001 and scale > 0.001:
		var renderer: Object = _ensure_energy_renderer()
		canvas.draw_set_transform(pos, 0.0, Vector2(scale, scale))
		renderer.draw(
			canvas,
			Vector2.ZERO,
			false,
			Vector2.ZERO,
			{
				"screen_pos": pos,
				"render_scale": scale,
			},
			{},
			"",
			false
		)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var star_pulse: float = 0.55 + 0.45 * sin(t * 4.2)
	var star_alpha: float = alpha * star_pulse * 0.55
	if star_alpha > 0.04:
		var sl_h: float = radius * 5.5
		var sl_v: float = radius * 3.6
		var streak_color: Color = Color(0.92, 0.97, 1.0, star_alpha)
		canvas.draw_line(pos + Vector2(-sl_h, 0.0), pos + Vector2(sl_h, 0.0), streak_color, 1.6, true)
		canvas.draw_line(pos + Vector2(0.0, -sl_v), pos + Vector2(0.0, sl_v), streak_color, 1.4, true)
		var diag_color: Color = Color(1.0, 1.0, 1.0, star_alpha * 0.55)
		var sl_d: float = radius * 2.5
		canvas.draw_line(pos + Vector2(-sl_d, -sl_d), pos + Vector2(sl_d, sl_d), diag_color, 1.0, true)
		canvas.draw_line(pos + Vector2(-sl_d, sl_d), pos + Vector2(sl_d, -sl_d), diag_color, 1.0, true)


func draw_phase_flash(
	canvas: CanvasItem,
	ball_state: Dictionary,
	elapsed_sec: float,
	game_width: float,
	game_height: float
) -> void:
	var alpha: float = 0.0
	var phase: int = int(ball_state.get("phase", 1))
	var pp: float = float(ball_state.get("phase_progress", 0.0))
	if phase == 1 and elapsed_sec < 0.18:
		alpha = 0.18 * (1.0 - elapsed_sec / 0.18)
	elif phase == 2:
		alpha = max(alpha, 0.055 * sin(pp * PI))
	elif phase == 3 and pp < 0.14:
		alpha = max(alpha, 0.11 * (1.0 - pp / 0.14))
	if alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(0.0, 0.0, game_width, game_height), Color(0.62, 0.88, 1.0, alpha))
