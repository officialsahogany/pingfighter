extends RefCounted


func draw_haze_clouds(
	canvas: CanvasItem,
	phase: int,
	haze_clouds: Array,
	elapsed_sec: float,
	phase_1_duration: float,
	phase_2_duration: float,
	phase_3_duration: float,
	game_width: float,
	game_height: float,
	ball_texture: Texture2D
) -> void:
	if haze_clouds.is_empty():
		return
	var intensity: float
	if phase == 1:
		intensity = 0.85
	elif phase == 2:
		var p2: float = clamp((elapsed_sec - phase_1_duration) / phase_2_duration, 0.0, 1.0)
		intensity = 0.85 * (1.0 - p2 * 0.5)
	else:
		var p3: float = clamp((elapsed_sec - phase_1_duration - phase_2_duration) / phase_3_duration, 0.0, 1.0)
		intensity = 0.45 * (1.0 - p3)
	if intensity <= 0.04:
		return

	for cloud in haze_clouds:
		var pulse: float = 0.65 + 0.35 * sin(elapsed_sec * cloud.pulse_speed + cloud.pulse_phase)
		var drift: Vector2 = Vector2(cos(cloud.drift_angle), sin(cloud.drift_angle)) * cloud.drift_speed * elapsed_sec
		var p: Vector2 = cloud.pos + drift
		p.x = fposmod(p.x, game_width + 200.0) - 100.0
		p.y = fposmod(p.y, game_height + 200.0) - 100.0
		var diam: float = min(cloud.radius * 2.0 * pulse, min(game_width, game_height) * 0.72)
		var half_diam: float = diam * 0.5
		# This atmospheric layer is drawn directly by the battle canvas, so keep
		# the soft glow quad inside the playfield instead of letting it wash over
		# the pillar backgrounds.
		p.x = clamp(p.x, half_diam, max(half_diam, game_width - half_diam))
		p.y = clamp(p.y, half_diam, max(half_diam, game_height - half_diam))
		var col: Color = Color(cloud.color.r, cloud.color.g, cloud.color.b, intensity * 0.18 * pulse)
		canvas.draw_texture_rect(ball_texture, Rect2(p.x - diam * 0.5, p.y - diam * 0.5, diam, diam), false, col)


func draw_starfield(
	canvas: CanvasItem,
	phase: int,
	starfield: Array,
	elapsed_sec: float,
	phase_1_duration: float,
	phase_2_duration: float,
	phase_3_duration: float
) -> void:
	if starfield.is_empty():
		return
	var intensity: float
	if phase == 1:
		intensity = 0.90
	elif phase == 2:
		var p2: float = clamp((elapsed_sec - phase_1_duration) / phase_2_duration, 0.0, 1.0)
		intensity = 0.85 * (1.0 - p2 * 0.4)
	else:
		var p3: float = clamp((elapsed_sec - phase_1_duration - phase_2_duration) / phase_3_duration, 0.0, 1.0)
		intensity = 0.55 * (1.0 - p3 * 0.7)
	if intensity <= 0.05:
		return

	var hue_palette: Array = [
		Color(0.78, 0.92, 1.0),
		Color(1.0, 0.92, 0.78),
		Color(0.92, 0.78, 1.0),
		Color(0.78, 1.0, 0.92),
		Color(1.0, 1.0, 1.0),
	]
	for star in starfield:
		var twinkle: float = 0.45 + 0.55 * sin(elapsed_sec * star.speed + star.phase)
		var alpha: float = clamp(intensity * pow(max(0.0, twinkle), 1.4) * 0.85, 0.0, 1.0)
		if alpha < 0.05:
			continue
		var col: Color = hue_palette[int(star.hue)]
		canvas.draw_circle(star.pos, star.size, Color(col.r, col.g, col.b, alpha))


func draw_god_rays(
	canvas: CanvasItem,
	phase: int,
	elapsed_sec: float,
	phase_1_duration: float,
	phase_2_duration: float,
	game_width: float,
	game_height: float,
	start_pos: Vector2
) -> void:
	var intensity: float
	if phase == 1:
		intensity = clamp(elapsed_sec / phase_1_duration, 0.0, 1.0)
		intensity = 0.55 + 0.40 * intensity
	elif phase == 2:
		var p2: float = clamp((elapsed_sec - phase_1_duration) / phase_2_duration, 0.0, 1.0)
		intensity = 0.95 * (1.0 - p2 * 0.85)
	else:
		return
	if intensity <= 0.04:
		return

	var ray_count: int = 18
	var phase_t: float = elapsed_sec * 0.85
	var max_len: float = max(game_width, game_height) * 0.62
	for i in range(ray_count):
		var ang: float = TAU * float(i) / float(ray_count) + phase_t * 0.18
		var beat_a: float = sin(float(i) * 0.71 + phase_t * 1.4)
		var beat_b: float = sin(float(i) * 1.83 + phase_t * 0.6)
		var beat: float = max(0.0, beat_a * 0.6 + beat_b * 0.4)
		var brightness: float = pow(beat, 1.6)
		if brightness < 0.06:
			continue
		var len_jitter: float = 1.0 + sin(float(i) * 0.43 + phase_t * 1.1) * 0.15
		var ray_len: float = max_len * len_jitter
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var p1: Vector2 = start_pos + dir * 18.0
		var p2: Vector2 = start_pos + dir * ray_len
		var ra: float = clamp(intensity * 0.32 * brightness, 0.0, 1.0)
		canvas.draw_line(p1, p2, Color(0.78, 0.90, 1.0, ra * 0.35), 4.0, true)
		canvas.draw_line(p1, p2, Color(0.95, 0.98, 1.0, ra * 0.85), 1.4, true)


func draw_aurora_fog(
	canvas: CanvasItem,
	fog_alpha: float,
	fog_color: Color,
	game_width: float,
	game_height: float,
	start_pos: Vector2,
	glow_texture: Texture2D
) -> void:
	if fog_alpha <= 0.5:
		return
	var a: float = clamp(fog_alpha / 255.0, 0.0, 1.0)
	canvas.draw_rect(Rect2(0.0, 0.0, game_width, game_height), Color(fog_color.r, fog_color.g, fog_color.b, a * 0.62))
	var hot_size: float = min(max(game_width, game_height) * 1.05, min(game_width, game_height))
	var half_hot: float = hot_size * 0.5
	var hot_center := Vector2(
		clamp(start_pos.x, half_hot, max(half_hot, game_width - half_hot)),
		clamp(start_pos.y, half_hot, max(half_hot, game_height - half_hot))
	)
	var hot_rect: Rect2 = Rect2(hot_center.x - half_hot, hot_center.y - half_hot, hot_size, hot_size)
	canvas.draw_texture_rect(glow_texture, hot_rect, false, Color(fog_color.r, fog_color.g, fog_color.b, a * 0.55))
