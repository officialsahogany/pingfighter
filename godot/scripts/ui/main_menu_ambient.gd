extends Control

# Subtle ambient effects layered on top of the static main-menu background.
# Rendered back-to-front in _draw():
#   1. Color drift -- full-screen tint slowly drifting between cool/warm purple
#      on a ~20 sec cycle (cinematic, focuses attention on the characters).
#   2. Sky twinkling -- 24 small point-lights in the upper ~33% of the screen
#      blink at independent random periods (distant city / drones lit windows).
#   3. Sky silhouettes -- occasional drone or bird flying across the sky band
#      every 14-28 sec (diegetic world activity).
#   4. Dust motes -- slow-rising white/violet motes (post-apocalyptic dust).
#   5. Logo glint -- slow prismatic highlight strokes clipped to the
#      baked-in upper-left DISK HEARTS letter pixels every ~9 sec.
#   6. Vignette breathing -- soft radial corner darken that breathes +/-5% on
#      a 6 sec cycle (cinematic focus).
# All layers are intentionally low-alpha so the scene reads as "잔잔".

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PARTICLE_COUNT := 32
const GLINT_PERIOD_SEC := 9.2
const GLINT_SWEEP_DURATION_SEC := 3.15
const GLINT_TILT_DEG := 15.0
const GLINT_INITIAL_PHASE_SEC := 0.55
const GLINT_VISIBLE_ALPHA_SCALE := 3.15
const GLINT_CORE_WIDTH := 3.4
const GLINT_GLOW_WIDTH := 9.2
const GLINT_SPARKLE_COUNT := 54
const GLINT_SPARKLE_BAND_PX := 42.0
const GLINT_SPARKLE_FADE_BAND_PX := 76.0
const GLINT_SPARKLE_MIN_ALPHA := 0.004
const GLINT_SPARKLE_TWINKLE_SPEED := 2.2
const BACKGROUND_SOURCE_SIZE := Vector2(2912.0, 1632.0)
const LOGO_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_logo.png"
const LOGO_NO_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_no_logo.png"
const LOGO_GLINT_SOURCE_RECT := Rect2(Vector2(90.0, 330.0), Vector2(1015.0, 126.0))
const LOGO_ORB_EFFECT_SOURCE_RECT := Rect2(Vector2(420.0, 205.0), Vector2(285.0, 310.0))
const LOGO_ORB_SOURCE_CENTER := Vector2(560.0, 382.0)
const LOGO_ORB_MASK_X := 420
const LOGO_ORB_MASK_Y := 205
const LOGO_ORB_MASK_WIDTH := 285
const LOGO_ORB_MASK_HEIGHT := 310
const LOGO_ORB_DIFF_THRESHOLD := 16.0 / 255.0
const LOGO_ORB_LUMA_THRESHOLD := 58.0 / 255.0
const LOGO_ORB_CHROMA_THRESHOLD := 18.0 / 255.0
const LOGO_ORB_PULSE_PERIOD_SEC := 2.85
const LOGO_ORB_SPARKLE_COUNT := 34
const LOGO_ORB_SPARKLE_SWEEP_FADE_PX := 92.0
const LOGO_ORB_SPARKLE_ORB_FADE_PX := 145.0
const LOGO_ORB_SPARKLE_TWINKLE_SPEED := 1.85
const LOGO_LETTER_MASK_X := 90
const LOGO_LETTER_MASK_Y := 330
const LOGO_LETTER_MASK_WIDTH := 1015
const LOGO_LETTER_MASK_HEIGHT := 126
const LOGO_LETTER_DIFF_THRESHOLD := 40.0 / 255.0
const LOGO_LETTER_LUMA_THRESHOLD := 180.0 / 255.0
const LOGO_LETTER_CHROMA_MAX := 110.0 / 255.0
const LOGO_LETTER_SAMPLE_STEP_PX := 1.35
const LOGO_WORD_SOURCE_RECTS := [
	Rect2(Vector2(90.0, 330.0), Vector2(360.0, 126.0)),
	Rect2(Vector2(585.0, 330.0), Vector2(520.0, 126.0)),
]
const RNG_SEED := 0x10617
const FALLBACK_VIEW_SIZE := Vector2(2020.0, 1246.0)

const COLOR_DRIFT_PERIOD_SEC := 20.0
const COLOR_DRIFT_TINT_COOL := Color(0.40, 0.32, 0.82, 1.0)
const COLOR_DRIFT_TINT_WARM := Color(0.74, 0.46, 0.62, 1.0)
const COLOR_DRIFT_ALPHA := 0.055

const VIGNETTE_BREATH_PERIOD_SEC := 6.0
const VIGNETTE_BASE_STRENGTH := 0.22
const VIGNETTE_BREATH_AMPLITUDE := 0.05
const VIGNETTE_TEXTURE_SIZE := 256
const VIGNETTE_FALLOFF_START := 0.45

const SKY_BAND_RATIO := 0.33
const SKY_LIGHT_COUNT := 24
const SKY_LIGHT_BASE_ALPHA := 0.55
const SKY_LIGHT_BLINK_PERIOD_MIN := 1.4
const SKY_LIGHT_BLINK_PERIOD_MAX := 5.0

const SILHOUETTE_SPAWN_MIN_SEC := 14.0
const SILHOUETTE_SPAWN_MAX_SEC := 28.0
const SILHOUETTE_MAX_ACTIVE := 2

var particles: Array[Dictionary] = []
var sky_lights: Array[Dictionary] = []
var silhouettes: Array[Dictionary] = []
var next_silhouette_spawn_time: float = 0.0
var vignette_texture: ImageTexture = null
var elapsed_time: float = 0.0
var rng := RandomNumberGenerator.new()
var intro_reveal_active: bool = true
var logo_letter_mask: PackedByteArray = PackedByteArray()
var logo_orb_effect_mask: PackedByteArray = PackedByteArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = RNG_SEED
	_seed_particles(true)
	_seed_sky_lights()
	_schedule_next_silhouette()
	vignette_texture = _build_vignette_texture()
	_build_logo_letter_mask()
	set_process(false)


func _process(delta: float) -> void:
	if intro_reveal_active:
		return
	if delta < 0.0:
		delta = 0.0
	elapsed_time += delta
	_update_particles(delta)
	_update_silhouettes(delta)
	queue_redraw()


func _draw() -> void:
	if intro_reveal_active:
		return
	var view_size := _view_size()
	_draw_color_drift(view_size)
	_draw_sky_lights(view_size)
	_draw_silhouettes(view_size)
	_draw_particles(view_size)
	_draw_glint(view_size)
	_draw_vignette(view_size)


# --- Particles ------------------------------------------------------------


func _seed_particles(scatter_initial: bool) -> void:
	var view_size := _view_size()
	particles.clear()
	for i in PARTICLE_COUNT:
		particles.append(_make_particle(view_size, scatter_initial))


func _make_particle(view_size: Vector2, scatter_initial: bool) -> Dictionary:
	var lifetime: float = rng.randf_range(9.0, 15.0)
	var initial_y: float
	var initial_age: float
	if scatter_initial:
		initial_y = rng.randf_range(0.0, view_size.y)
		initial_age = rng.randf_range(0.0, lifetime * 0.85)
	else:
		initial_y = view_size.y + rng.randf_range(20.0, 80.0)
		initial_age = 0.0
	var kind := "white" if rng.randf() < 0.82 else "violet"
	return {
		"x": rng.randf_range(0.0, view_size.x),
		"y": initial_y,
		"vx": rng.randf_range(-5.0, 5.0),
		"vy": rng.randf_range(-24.0, -11.0),
		"age": initial_age,
		"lifetime": lifetime,
		"size": rng.randf_range(1.3, 2.7),
		"kind": kind,
	}


func _update_particles(delta: float) -> void:
	var view_size := _view_size()
	for p in particles:
		p["x"] = float(p["x"]) + float(p["vx"]) * delta
		p["y"] = float(p["y"]) + float(p["vy"]) * delta
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["lifetime"]) or float(p["y"]) < -30.0:
			var fresh: Dictionary = _make_particle(view_size, false)
			for k in fresh:
				p[k] = fresh[k]


func _draw_particles(_particle_view_size: Vector2) -> void:
	for p in particles:
		var t: float = float(p["age"]) / float(p["lifetime"])
		var alpha: float = 1.0
		if t < 0.18:
			alpha = t / 0.18
		elif t > 0.72:
			alpha = (1.0 - t) / 0.28
		alpha = clampf(alpha, 0.0, 1.0) * 0.58
		if alpha < 0.02:
			continue
		var base_color: Color
		if String(p["kind"]) == "white":
			base_color = Color(0.94, 0.96, 1.0, alpha)
		else:
			base_color = Color(0.80, 0.72, 0.98, alpha)
		var pos := Vector2(float(p["x"]), float(p["y"]))
		var r: float = float(p["size"])
		var halo_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.30)
		draw_circle(pos, r * 2.4, halo_color)
		draw_circle(pos, r, base_color)


# --- Logo glint sweep -----------------------------------------------------


func _draw_glint(view_size: Vector2) -> void:
	if logo_letter_mask.is_empty() and logo_orb_effect_mask.is_empty():
		return
	var logo_rect := _logo_glint_rect(view_size)
	if logo_rect.size.x <= 4.0 or logo_rect.size.y <= 4.0:
		return
	var phase: float = fposmod(elapsed_time, GLINT_PERIOD_SEC)
	if phase > GLINT_SWEEP_DURATION_SEC:
		return
	var progress: float = phase / GLINT_SWEEP_DURATION_SEC
	var sweep_curve: float = sin(progress * PI)  # 0 -> 1 -> 0 smooth
	if sweep_curve < 0.01:
		return
	var sweep_y_top: float = logo_rect.position.y
	var sweep_y_bot: float = logo_rect.end.y
	var band_half_width: float = logo_rect.size.x * 0.095
	var travel: float = logo_rect.size.x + band_half_width * 4.0
	var center_x: float = logo_rect.position.x - band_half_width * 2.0 + progress * travel
	var angle_rad: float = deg_to_rad(GLINT_TILT_DEG)
	var tilt_x: float = (sweep_y_bot - sweep_y_top) * tan(angle_rad)
	var slice_count: int = 36
	for i in slice_count:
		var ti: float = (float(i) / float(slice_count - 1) - 0.5) * 2.0
		var slice_falloff: float = pow(1.0 - absf(ti), 1.35)
		var alpha: float = slice_falloff * sweep_curve * 0.40 * GLINT_VISIBLE_ALPHA_SCALE
		if alpha < 0.01:
			continue
		var glow_color := Color(0.16, 0.92, 1.0, alpha * 0.34)
		var prism_color := Color(1.0, 0.28, 0.95, alpha * 0.32)
		var gold_color := Color(1.0, 0.80, 0.20, alpha * 0.26)
		var core_color := Color(0.96, 1.0, 1.0, alpha * 0.74)
		var slice_x: float = center_x + ti * band_half_width
		var pt_top := Vector2(slice_x, sweep_y_top)
		var pt_bot := Vector2(slice_x + tilt_x, sweep_y_bot)
		var clipped_line := _clipped_line_to_rect(pt_top, pt_bot, logo_rect)
		if clipped_line.size() < 2:
			continue
		_draw_logo_letter_masked_line(clipped_line[0], clipped_line[1], glow_color, GLINT_GLOW_WIDTH, view_size)
		_draw_logo_letter_masked_line(clipped_line[0], clipped_line[1], prism_color, GLINT_GLOW_WIDTH * 0.62, view_size)
		_draw_logo_letter_masked_line(clipped_line[0], clipped_line[1], gold_color, GLINT_GLOW_WIDTH * 0.42, view_size)
		_draw_logo_letter_masked_line(clipped_line[0], clipped_line[1], core_color, GLINT_CORE_WIDTH, view_size)
	_draw_logo_letter_sparkles(view_size, logo_rect, center_x, tilt_x, sweep_curve)
	_draw_logo_orb_effects(view_size, center_x, tilt_x, sweep_curve)


func _logo_glint_rect(view_size: Vector2) -> Rect2:
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return Rect2()
	var source_scale := _background_source_scale(view_size)
	var rect := Rect2(
		_source_to_screen(LOGO_GLINT_SOURCE_RECT.position, view_size),
		LOGO_GLINT_SOURCE_RECT.size * source_scale
	)
	return _intersect_rect(rect, Rect2(Vector2.ZERO, view_size))


func _logo_orb_effect_rect(view_size: Vector2) -> Rect2:
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return Rect2()
	var source_scale := _background_source_scale(view_size)
	var rect := Rect2(
		_source_to_screen(LOGO_ORB_EFFECT_SOURCE_RECT.position, view_size),
		LOGO_ORB_EFFECT_SOURCE_RECT.size * source_scale
	)
	return _intersect_rect(rect, Rect2(Vector2.ZERO, view_size))


func _background_image_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, view_size)


func _background_source_scale(view_size: Vector2) -> Vector2:
	if BACKGROUND_SOURCE_SIZE.x <= 1.0 or BACKGROUND_SOURCE_SIZE.y <= 1.0:
		return Vector2.ONE
	return Vector2(
		view_size.x / BACKGROUND_SOURCE_SIZE.x,
		view_size.y / BACKGROUND_SOURCE_SIZE.y
	)


func _source_to_screen(source_pos: Vector2, view_size: Vector2) -> Vector2:
	return _background_image_rect(view_size).position + source_pos * _background_source_scale(view_size)


func _screen_to_source(screen_pos: Vector2, view_size: Vector2) -> Vector2:
	var background_rect := _background_image_rect(view_size)
	var source_scale := _background_source_scale(view_size)
	if source_scale.x <= 0.0 or source_scale.y <= 0.0:
		return Vector2.ZERO
	return (screen_pos - background_rect.position) / source_scale


func _intersect_rect(a: Rect2, b: Rect2) -> Rect2:
	var x0: float = maxf(a.position.x, b.position.x)
	var y0: float = maxf(a.position.y, b.position.y)
	var x1: float = minf(a.end.x, b.end.x)
	var y1: float = minf(a.end.y, b.end.y)
	if x1 <= x0 or y1 <= y0:
		return Rect2()
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


func _clipped_line_to_rect(line_start: Vector2, line_end: Vector2, rect: Rect2) -> PackedVector2Array:
	var delta := line_end - line_start
	var t_min: float = 0.0
	var t_max: float = 1.0
	var clip_edges := [
		Vector2(-delta.x, line_start.x - rect.position.x),
		Vector2(delta.x, rect.end.x - line_start.x),
		Vector2(-delta.y, line_start.y - rect.position.y),
		Vector2(delta.y, rect.end.y - line_start.y),
	]
	for edge in clip_edges:
		var p: float = edge.x
		var q: float = edge.y
		if is_zero_approx(p):
			if q < 0.0:
				return PackedVector2Array()
			continue
		var ratio: float = q / p
		if p < 0.0:
			if ratio > t_max:
				return PackedVector2Array()
			t_min = maxf(t_min, ratio)
		else:
			if ratio < t_min:
				return PackedVector2Array()
			t_max = minf(t_max, ratio)
	var result := PackedVector2Array()
	result.append(line_start + delta * t_min)
	result.append(line_start + delta * t_max)
	return result


func _draw_logo_letter_masked_line(
	line_start: Vector2,
	line_end: Vector2,
	color: Color,
	width: float,
	view_size: Vector2
) -> void:
	var delta := line_end - line_start
	var length: float = delta.length()
	if length <= 0.5:
		return
	var step_count: int = max(2, int(ceil(length / LOGO_LETTER_SAMPLE_STEP_PX)))
	var drawing_segment := false
	var segment_start := line_start
	var last_visible_point := line_start
	for sample_index in range(step_count + 1):
		var t: float = float(sample_index) / float(step_count)
		var point := line_start + delta * t
		var is_sample_visible := _is_logo_letter_screen_point(point, view_size)
		if is_sample_visible:
			if not drawing_segment:
				segment_start = point
				drawing_segment = true
			last_visible_point = point
		elif drawing_segment:
			if segment_start.distance_to(last_visible_point) >= 0.5:
				draw_line(segment_start, last_visible_point, color, width, true)
			drawing_segment = false
	if drawing_segment and segment_start.distance_to(last_visible_point) >= 0.5:
		draw_line(segment_start, last_visible_point, color, width, true)


func _draw_logo_letter_sparkles(
	view_size: Vector2,
	logo_rect: Rect2,
	center_x: float,
	tilt_x: float,
	sweep_curve: float
) -> void:
	var source_scale_vec := _background_source_scale(view_size)
	var source_scale: float = minf(source_scale_vec.x, source_scale_vec.y)
	if source_scale <= 0.0:
		return
	for i in range(GLINT_SPARKLE_COUNT * 2):
		var sparkle_seed: float = float(i) + 1.0
		var source_pos := Vector2(
			LOGO_GLINT_SOURCE_RECT.position.x + _hash01(sparkle_seed * 12.9898) * LOGO_GLINT_SOURCE_RECT.size.x,
			LOGO_GLINT_SOURCE_RECT.position.y + _hash01(sparkle_seed * 78.233) * LOGO_GLINT_SOURCE_RECT.size.y
		)
		if not _is_logo_letter_source_pixel(source_pos):
			continue
		var screen_pos := _source_to_screen(source_pos, view_size)
		if not logo_rect.has_point(screen_pos):
			continue
		var y_ratio: float = clampf((screen_pos.y - logo_rect.position.y) / maxf(1.0, logo_rect.size.y), 0.0, 1.0)
		var sweep_x_at_y: float = center_x + tilt_x * y_ratio
		var dist: float = absf(screen_pos.x - sweep_x_at_y)
		if dist > GLINT_SPARKLE_FADE_BAND_PX:
			continue
		var band_fade: float = _sparkle_fade_curve(1.0 - dist / GLINT_SPARKLE_FADE_BAND_PX)
		var twinkle: float = _sparkle_fade_curve(0.5 + 0.5 * sin(elapsed_time * GLINT_SPARKLE_TWINKLE_SPEED + sparkle_seed * 2.17))
		var life_fade: float = _sparkle_fade_curve(sweep_curve)
		var alpha: float = clampf(band_fade * life_fade * lerpf(0.50, 1.0, twinkle) * 0.92, 0.0, 0.88)
		if alpha < GLINT_SPARKLE_MIN_ALPHA:
			continue
		var size_fade: float = _sparkle_fade_curve(alpha / 0.88)
		var radius: float = (1.4 + _hash01(sparkle_seed * 37.719) * 2.4) * source_scale * lerpf(0.05, 1.0, size_fade)
		var color := Color(0.62, 0.96, 1.0, alpha)
		if _hash01(sparkle_seed * 5.371) > 0.68:
			color = Color(1.0, 0.78, 0.25, alpha)
		elif _hash01(sparkle_seed * 9.917) > 0.58:
			color = Color(1.0, 0.36, 0.95, alpha)
		draw_circle(screen_pos, radius * 1.75, Color(color.r, color.g, color.b, color.a * 0.22))
		draw_line(screen_pos - Vector2(radius * 2.2, 0.0), screen_pos + Vector2(radius * 2.2, 0.0), color, maxf(0.04, radius * 0.42), true)
		draw_line(screen_pos - Vector2(0.0, radius * 1.8), screen_pos + Vector2(0.0, radius * 1.8), Color(1.0, 1.0, 1.0, alpha * 0.78), maxf(0.04, radius * 0.34), true)


func _draw_logo_orb_effects(view_size: Vector2, center_x: float, tilt_x: float, sweep_curve: float) -> void:
	if logo_orb_effect_mask.is_empty():
		return
	var orb_rect := _logo_orb_effect_rect(view_size)
	if orb_rect.size.x <= 4.0 or orb_rect.size.y <= 4.0:
		return
	var source_scale_vec := _background_source_scale(view_size)
	var source_scale: float = minf(source_scale_vec.x, source_scale_vec.y)
	var orb_center := _source_to_screen(LOGO_ORB_SOURCE_CENTER, view_size)
	var orb_pulse: float = 0.5 + 0.5 * sin(elapsed_time * TAU / LOGO_ORB_PULSE_PERIOD_SEC)
	var breath_alpha: float = lerpf(0.20, 0.48, orb_pulse)
	var core_radius: float = 31.0 * source_scale
	draw_circle(orb_center, core_radius * 1.45, Color(0.58, 0.28, 1.0, breath_alpha * 0.18))
	draw_circle(orb_center, core_radius * 0.78, Color(0.80, 0.56, 1.0, breath_alpha * 0.20))
	var sweep_line_start := Vector2(
		_logo_orb_sweep_x_at_y(orb_rect.position.y, orb_center.y, center_x, tilt_x, orb_rect),
		orb_rect.position.y
	)
	var sweep_line_end := Vector2(
		_logo_orb_sweep_x_at_y(orb_rect.end.y, orb_center.y, center_x, tilt_x, orb_rect),
		orb_rect.end.y
	)
	var clipped_line := _clipped_line_to_rect(sweep_line_start, sweep_line_end, orb_rect)
	if clipped_line.size() >= 2:
		var orb_alpha: float = sweep_curve * GLINT_VISIBLE_ALPHA_SCALE
		_draw_logo_orb_masked_line(clipped_line[0], clipped_line[1], Color(0.22, 0.94, 1.0, orb_alpha * 0.30), 10.0, view_size)
		_draw_logo_orb_masked_line(clipped_line[0], clipped_line[1], Color(1.0, 0.30, 0.98, orb_alpha * 0.26), 6.2, view_size)
		_draw_logo_orb_masked_line(clipped_line[0], clipped_line[1], Color(1.0, 0.90, 0.42, orb_alpha * 0.24), 4.2, view_size)
		_draw_logo_orb_masked_line(clipped_line[0], clipped_line[1], Color(1.0, 1.0, 1.0, orb_alpha * 0.54), 2.2, view_size)
	_draw_logo_orb_sparkles(view_size, orb_rect, orb_center, source_scale, center_x, tilt_x, sweep_curve)


func _draw_logo_orb_masked_line(
	line_start: Vector2,
	line_end: Vector2,
	color: Color,
	width: float,
	view_size: Vector2
) -> void:
	var delta := line_end - line_start
	var length: float = delta.length()
	if length <= 0.5:
		return
	var step_count: int = max(2, int(ceil(length / LOGO_LETTER_SAMPLE_STEP_PX)))
	var drawing_segment := false
	var segment_start := line_start
	var last_visible_point := line_start
	for sample_index in range(step_count + 1):
		var t: float = float(sample_index) / float(step_count)
		var point := line_start + delta * t
		var is_sample_visible := _is_logo_orb_effect_screen_point(point, view_size)
		if is_sample_visible:
			if not drawing_segment:
				segment_start = point
				drawing_segment = true
			last_visible_point = point
		elif drawing_segment:
			if segment_start.distance_to(last_visible_point) >= 0.5:
				draw_line(segment_start, last_visible_point, color, width, true)
			drawing_segment = false
	if drawing_segment and segment_start.distance_to(last_visible_point) >= 0.5:
		draw_line(segment_start, last_visible_point, color, width, true)


func _draw_logo_orb_sparkles(
	view_size: Vector2,
	orb_rect: Rect2,
	orb_center: Vector2,
	source_scale: float,
	center_x: float,
	tilt_x: float,
	sweep_curve: float
) -> void:
	for i in range(LOGO_ORB_SPARKLE_COUNT * 3):
		var sparkle_seed: float = float(i) + 2.0
		var source_pos := Vector2(
			LOGO_ORB_EFFECT_SOURCE_RECT.position.x + _hash01(sparkle_seed * 19.113) * LOGO_ORB_EFFECT_SOURCE_RECT.size.x,
			LOGO_ORB_EFFECT_SOURCE_RECT.position.y + _hash01(sparkle_seed * 43.771) * LOGO_ORB_EFFECT_SOURCE_RECT.size.y
		)
		if not _is_logo_orb_effect_source_pixel(source_pos):
			continue
		var screen_pos := _source_to_screen(source_pos, view_size)
		if not orb_rect.has_point(screen_pos):
			continue
		var sweep_x_at_y: float = _logo_orb_sweep_x_at_y(screen_pos.y, orb_center.y, center_x, tilt_x, orb_rect)
		var dist_from_sweep: float = absf(screen_pos.x - sweep_x_at_y)
		var dist_from_orb: float = screen_pos.distance_to(orb_center)
		var sweep_fade: float = _sparkle_fade_curve(1.0 - dist_from_sweep / (LOGO_ORB_SPARKLE_SWEEP_FADE_PX * source_scale))
		var orb_fade: float = _sparkle_fade_curve(1.0 - dist_from_orb / (LOGO_ORB_SPARKLE_ORB_FADE_PX * source_scale))
		var twinkle: float = _sparkle_fade_curve(0.5 + 0.5 * sin(elapsed_time * LOGO_ORB_SPARKLE_TWINKLE_SPEED + sparkle_seed))
		var life_fade: float = _sparkle_fade_curve(sweep_curve)
		var sweep_alpha: float = sweep_fade * life_fade
		var orb_alpha: float = orb_fade * life_fade * lerpf(0.42, 1.0, twinkle)
		var alpha: float = clampf(maxf(sweep_alpha, orb_alpha) * 0.95, 0.0, 0.92)
		if alpha < GLINT_SPARKLE_MIN_ALPHA:
			continue
		var size_fade: float = _sparkle_fade_curve(alpha / 0.92)
		var radius: float = (1.6 + _hash01(sparkle_seed * 31.79) * 3.2) * source_scale * lerpf(0.05, 1.0, size_fade)
		var color := Color(0.54, 0.92, 1.0, alpha)
		if _hash01(sparkle_seed * 7.71) > 0.70:
			color = Color(1.0, 0.72, 0.24, alpha)
		elif _hash01(sparkle_seed * 9.37) > 0.56:
			color = Color(1.0, 0.30, 1.0, alpha)
		draw_circle(screen_pos, radius * 2.0, Color(color.r, color.g, color.b, color.a * 0.20))
		draw_line(screen_pos - Vector2(radius * 2.5, 0.0), screen_pos + Vector2(radius * 2.5, 0.0), color, maxf(0.04, radius * 0.38), true)
		draw_line(screen_pos - Vector2(0.0, radius * 2.0), screen_pos + Vector2(0.0, radius * 2.0), Color(1.0, 1.0, 1.0, alpha * 0.70), maxf(0.04, radius * 0.30), true)


func _logo_sweep_x_at_y(screen_y: float, logo_rect: Rect2, center_x: float, tilt_x: float) -> float:
	if logo_rect.size.y <= 1.0:
		return center_x
	var y_ratio: float = (screen_y - logo_rect.position.y) / logo_rect.size.y
	return center_x + tilt_x * y_ratio


func _logo_orb_sweep_x_at_y(
	screen_y: float,
	orb_center_y: float,
	center_x: float,
	tilt_x: float,
	orb_rect: Rect2
) -> float:
	if orb_rect.size.y <= 1.0:
		return center_x
	var y_ratio: float = (screen_y - orb_center_y) / orb_rect.size.y
	return center_x + tilt_x * y_ratio


func _sparkle_fade_curve(raw_amount: float) -> float:
	var t: float = clampf(raw_amount, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


# Exported builds pack only the imported texture (.ctex), never the original
# PNG, so a raw Image.load_from_file here would silently return null in every
# shipped build. Both mask PNGs import lossless (compress/mode=0, size_limit=0),
# so get_image() pixels match the raw source exactly.
func _load_mask_source_image(path: String) -> Image:
	var texture: Texture2D = ProjectResourceLoader.load_texture(path)
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	return image


func _build_logo_letter_mask() -> void:
	logo_letter_mask.clear()
	logo_orb_effect_mask.clear()
	var logo_image := _load_mask_source_image(LOGO_BACKGROUND_PATH)
	var base_image := _load_mask_source_image(LOGO_NO_BACKGROUND_PATH)
	if logo_image == null or base_image == null or logo_image.is_empty() or base_image.is_empty():
		push_warning("Main-menu logo glint mask could not load background comparison images.")
		return
	if logo_image.get_size() != base_image.get_size():
		push_warning("Main-menu logo glint mask skipped because background image sizes differ.")
		return
	var total_pixels: int = LOGO_LETTER_MASK_WIDTH * LOGO_LETTER_MASK_HEIGHT
	logo_letter_mask.resize(total_pixels)
	var write_index := 0
	for y in LOGO_LETTER_MASK_HEIGHT:
		var source_y: int = LOGO_LETTER_MASK_Y + y
		for x in LOGO_LETTER_MASK_WIDTH:
			var source_x: int = LOGO_LETTER_MASK_X + x
			var source_pos := Vector2(float(source_x), float(source_y))
			var is_letter := false
			if _is_source_point_inside_logo_word(source_pos):
				is_letter = _is_logo_letter_color(
					logo_image.get_pixel(source_x, source_y),
					base_image.get_pixel(source_x, source_y)
			)
			logo_letter_mask[write_index] = 1 if is_letter else 0
			write_index += 1
	var orb_pixels: int = LOGO_ORB_MASK_WIDTH * LOGO_ORB_MASK_HEIGHT
	logo_orb_effect_mask.resize(orb_pixels)
	write_index = 0
	for y in LOGO_ORB_MASK_HEIGHT:
		var source_y: int = LOGO_ORB_MASK_Y + y
		for x in LOGO_ORB_MASK_WIDTH:
			var source_x: int = LOGO_ORB_MASK_X + x
			var source_pos := Vector2(float(source_x), float(source_y))
			var is_orb_effect := _is_logo_orb_effect_color(
				logo_image.get_pixel(source_x, source_y),
				base_image.get_pixel(source_x, source_y),
				source_pos
			)
			logo_orb_effect_mask[write_index] = 1 if is_orb_effect else 0
			write_index += 1


func _is_logo_letter_screen_point(screen_point: Vector2, view_size: Vector2) -> bool:
	if logo_letter_mask.is_empty():
		return false
	var source_pos := _screen_to_source(screen_point, view_size)
	return _is_logo_letter_source_pixel(source_pos)


func _is_logo_letter_source_pixel(source_pos: Vector2) -> bool:
	var local_x: int = int(floor(source_pos.x)) - LOGO_LETTER_MASK_X
	var local_y: int = int(floor(source_pos.y)) - LOGO_LETTER_MASK_Y
	if local_x < 0 or local_y < 0 or local_x >= LOGO_LETTER_MASK_WIDTH or local_y >= LOGO_LETTER_MASK_HEIGHT:
		return false
	var mask_index: int = local_y * LOGO_LETTER_MASK_WIDTH + local_x
	return logo_letter_mask[mask_index] != 0


func _is_logo_orb_effect_screen_point(screen_point: Vector2, view_size: Vector2) -> bool:
	if logo_orb_effect_mask.is_empty():
		return false
	var source_pos := _screen_to_source(screen_point, view_size)
	return _is_logo_orb_effect_source_pixel(source_pos)


func _is_logo_orb_effect_source_pixel(source_pos: Vector2) -> bool:
	var local_x: int = int(floor(source_pos.x)) - LOGO_ORB_MASK_X
	var local_y: int = int(floor(source_pos.y)) - LOGO_ORB_MASK_Y
	if local_x < 0 or local_y < 0 or local_x >= LOGO_ORB_MASK_WIDTH or local_y >= LOGO_ORB_MASK_HEIGHT:
		return false
	var mask_index: int = local_y * LOGO_ORB_MASK_WIDTH + local_x
	return logo_orb_effect_mask[mask_index] != 0


func _is_source_point_inside_logo_word(source_pos: Vector2) -> bool:
	for word_rect in LOGO_WORD_SOURCE_RECTS:
		if word_rect.has_point(source_pos):
			return true
	return false


func _is_logo_letter_color(logo_color: Color, base_color: Color) -> bool:
	var diff: float = _max3(
		absf(logo_color.r - base_color.r),
		absf(logo_color.g - base_color.g),
		absf(logo_color.b - base_color.b)
	)
	if diff < LOGO_LETTER_DIFF_THRESHOLD:
		return false
	var luma: float = logo_color.r * 0.2126 + logo_color.g * 0.7152 + logo_color.b * 0.0722
	if luma < LOGO_LETTER_LUMA_THRESHOLD:
		return false
	var chroma: float = _max3(logo_color.r, logo_color.g, logo_color.b) - _min3(logo_color.r, logo_color.g, logo_color.b)
	return chroma <= LOGO_LETTER_CHROMA_MAX


func _is_logo_orb_effect_color(logo_color: Color, base_color: Color, source_pos: Vector2) -> bool:
	var diff: float = _max3(
		absf(logo_color.r - base_color.r),
		absf(logo_color.g - base_color.g),
		absf(logo_color.b - base_color.b)
	)
	if diff < LOGO_ORB_DIFF_THRESHOLD:
		return false
	var luma: float = logo_color.r * 0.2126 + logo_color.g * 0.7152 + logo_color.b * 0.0722
	if luma < LOGO_ORB_LUMA_THRESHOLD:
		return false
	var chroma: float = _max3(logo_color.r, logo_color.g, logo_color.b) - _min3(logo_color.r, logo_color.g, logo_color.b)
	var dist: float = source_pos.distance_to(LOGO_ORB_SOURCE_CENTER)
	var near_core: bool = dist <= 74.0
	var near_ring: bool = dist <= 150.0 and chroma >= LOGO_ORB_CHROMA_THRESHOLD
	var changed_bright: bool = dist <= 125.0 and luma >= 0.55
	return near_core or near_ring or changed_bright


func _has_logo_letter_mask() -> bool:
	return not logo_letter_mask.is_empty()


func _has_logo_orb_effect_mask() -> bool:
	return not logo_orb_effect_mask.is_empty()


func _max3(a: float, b: float, c: float) -> float:
	return maxf(maxf(a, b), c)


func _min3(a: float, b: float, c: float) -> float:
	return minf(minf(a, b), c)


func _hash01(value: float) -> float:
	return fposmod(sin(value) * 43758.5453, 1.0)


# --- Color drift ----------------------------------------------------------


func _draw_color_drift(view_size: Vector2) -> void:
	var t: float = (elapsed_time / COLOR_DRIFT_PERIOD_SEC) * TAU
	var mix_factor: float = 0.5 + 0.5 * sin(t)
	var tint: Color = COLOR_DRIFT_TINT_COOL.lerp(COLOR_DRIFT_TINT_WARM, mix_factor)
	var fill := Color(tint.r, tint.g, tint.b, COLOR_DRIFT_ALPHA)
	draw_rect(Rect2(Vector2.ZERO, view_size), fill)


# --- Sky twinkling --------------------------------------------------------


func _seed_sky_lights() -> void:
	sky_lights.clear()
	for i in SKY_LIGHT_COUNT:
		sky_lights.append({
			"x_rel": rng.randf(),
			"y_rel": rng.randf_range(0.05, 0.92),
			"blink_period": rng.randf_range(SKY_LIGHT_BLINK_PERIOD_MIN, SKY_LIGHT_BLINK_PERIOD_MAX),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(0.7, 1.9),
			"color_kind": rng.randi() % 3,
		})


func _draw_sky_lights(view_size: Vector2) -> void:
	var sky_h: float = view_size.y * SKY_BAND_RATIO
	for light in sky_lights:
		var x: float = float(light["x_rel"]) * view_size.x
		var y: float = float(light["y_rel"]) * sky_h
		var period: float = float(light["blink_period"])
		var phase: float = float(light["phase"])
		var t: float = elapsed_time * TAU / period + phase
		var raw_pulse: float = (sin(t) + 1.0) * 0.5
		# Cubic shaping -- mostly dim, occasional brighter peaks (city blink feel).
		var pulse: float = raw_pulse * raw_pulse * raw_pulse
		var alpha: float = SKY_LIGHT_BASE_ALPHA * pulse
		if alpha < 0.02:
			continue
		var color: Color
		var kind: int = int(light["color_kind"])
		if kind == 0:
			color = Color(1.0, 0.78, 0.42, alpha)  # warm window
		elif kind == 1:
			color = Color(0.62, 0.86, 1.0, alpha)  # cool LED
		else:
			color = Color(0.96, 0.98, 1.0, alpha)  # white
		var r: float = float(light["size"])
		var halo := Color(color.r, color.g, color.b, color.a * 0.30)
		var pos := Vector2(x, y)
		draw_circle(pos, r * 3.0, halo)
		draw_circle(pos, r, color)


# --- Sky silhouettes (drones / birds) ------------------------------------


func _schedule_next_silhouette() -> void:
	next_silhouette_spawn_time = elapsed_time + rng.randf_range(SILHOUETTE_SPAWN_MIN_SEC, SILHOUETTE_SPAWN_MAX_SEC)


func _make_silhouette(view_size: Vector2) -> Dictionary:
	var is_drone: bool = rng.randf() < 0.45
	var go_right: bool = rng.randf() < 0.5
	var sky_h: float = view_size.y * SKY_BAND_RATIO
	var y: float = rng.randf_range(sky_h * 0.18, sky_h * 0.82)
	var speed: float
	if is_drone:
		speed = rng.randf_range(40.0, 75.0)
	else:
		speed = rng.randf_range(90.0, 150.0)
	var start_x: float = -60.0 if go_right else view_size.x + 60.0
	var vx: float = speed if go_right else -speed
	return {
		"kind": "drone" if is_drone else "bird",
		"x": start_x,
		"y": y,
		"vx": vx,
		"vy": rng.randf_range(-3.5, 3.5),
		"age": 0.0,
		"phase": rng.randf_range(0.0, TAU),
		"scale": rng.randf_range(0.85, 1.4),
	}


func _update_silhouettes(delta: float) -> void:
	var view_size := _view_size()
	if elapsed_time >= next_silhouette_spawn_time and silhouettes.size() < SILHOUETTE_MAX_ACTIVE:
		silhouettes.append(_make_silhouette(view_size))
		_schedule_next_silhouette()
	var i: int = silhouettes.size() - 1
	while i >= 0:
		var s: Dictionary = silhouettes[i]
		s["x"] = float(s["x"]) + float(s["vx"]) * delta
		s["y"] = float(s["y"]) + float(s["vy"]) * delta
		s["age"] = float(s["age"]) + delta
		var x_pos: float = float(s["x"])
		var dir_sign: float = 1.0 if float(s["vx"]) > 0.0 else -1.0
		if (dir_sign > 0.0 and x_pos > view_size.x + 80.0) or (dir_sign < 0.0 and x_pos < -80.0):
			silhouettes.remove_at(i)
		i -= 1


func _draw_silhouettes(view_size: Vector2) -> void:
	for s in silhouettes:
		var pos := Vector2(float(s["x"]), float(s["y"]))
		var kind: String = String(s["kind"])
		var scale_factor: float = float(s["scale"])
		var t_local: float = float(s["age"]) + float(s["phase"])
		var dir_sign: float = 1.0 if float(s["vx"]) > 0.0 else -1.0
		# Edge fade: alpha rises while entering the screen and falls before exiting.
		var x_norm: float = clampf(pos.x / view_size.x, 0.0, 1.0)
		var edge_alpha: float = clampf(minf(x_norm * 4.0, (1.0 - x_norm) * 4.0), 0.0, 1.0)
		var alpha: float = 0.55 * edge_alpha
		if alpha < 0.02:
			continue
		var ink := Color(0.04, 0.05, 0.10, alpha)
		if kind == "drone":
			_draw_drone_shape(pos, scale_factor, t_local, ink)
		else:
			_draw_bird_shape(pos, scale_factor, t_local, dir_sign, ink)


func _draw_drone_shape(pos: Vector2, scale_factor: float, t_local: float, ink: Color) -> void:
	var w: float = 14.0 * scale_factor
	var h: float = 3.5 * scale_factor
	var prop_r: float = 1.8 * scale_factor
	var bob: float = sin(t_local * 6.0) * 1.6
	var p := pos + Vector2(0.0, bob)
	draw_rect(Rect2(p - Vector2(w * 0.5, h * 0.5), Vector2(w, h)), ink)
	var prop_offset_x: float = w * 0.45
	var prop_offset_y: float = h * 0.9
	var prop_positions: Array = [
		p + Vector2(-prop_offset_x, -prop_offset_y),
		p + Vector2(prop_offset_x, -prop_offset_y),
		p + Vector2(-prop_offset_x, prop_offset_y),
		p + Vector2(prop_offset_x, prop_offset_y),
	]
	for prop_pos in prop_positions:
		draw_circle(prop_pos, prop_r, ink)


func _draw_bird_shape(pos: Vector2, scale_factor: float, t_local: float, dir_sign: float, ink: Color) -> void:
	var span: float = 18.0 * scale_factor
	var flap: float = sin(t_local * 8.0) * 5.0 * scale_factor
	var stroke: float = maxf(1.6 * scale_factor, 1.2)
	var tip_left := pos + Vector2(-span * 0.5 * dir_sign, -flap)
	var tip_right := pos + Vector2(span * 0.5 * dir_sign, -flap)
	var apex := pos + Vector2(0.0, flap * 0.25)
	draw_line(tip_left, apex, ink, stroke, true)
	draw_line(apex, tip_right, ink, stroke, true)


# --- Vignette breathing ---------------------------------------------------


func _build_vignette_texture() -> ImageTexture:
	var size_px: int = VIGNETTE_TEXTURE_SIZE
	var img: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var cx: float = float(size_px) * 0.5
	var cy: float = float(size_px) * 0.5
	var max_dist: float = sqrt(cx * cx + cy * cy)
	for y in size_px:
		for x in size_px:
			var dx: float = float(x) + 0.5 - cx
			var dy: float = float(y) + 0.5 - cy
			var d: float = sqrt(dx * dx + dy * dy) / max_dist
			var t: float = clampf((d - VIGNETTE_FALLOFF_START) / (1.0 - VIGNETTE_FALLOFF_START), 0.0, 1.0)
			# Cubic smoothstep.
			t = t * t * (3.0 - 2.0 * t)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, t))
	return ImageTexture.create_from_image(img)


func _draw_vignette(view_size: Vector2) -> void:
	if vignette_texture == null:
		return
	var breath: float = sin(elapsed_time * TAU / VIGNETTE_BREATH_PERIOD_SEC)
	var strength: float = VIGNETTE_BASE_STRENGTH + VIGNETTE_BREATH_AMPLITUDE * breath
	if strength <= 0.001:
		return
	draw_texture_rect(
		vignette_texture,
		Rect2(Vector2.ZERO, view_size),
		false,
		Color(1.0, 1.0, 1.0, strength)
	)


func set_intro_reveal_active(active: bool) -> void:
	if intro_reveal_active == active:
		return
	intro_reveal_active = active
	if intro_reveal_active:
		set_process(false)
	else:
		elapsed_time = GLINT_INITIAL_PHASE_SEC
		_seed_particles(true)
		_schedule_next_silhouette()
		set_process(true)
	queue_redraw()


# --- Helpers --------------------------------------------------------------


func _view_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	return FALLBACK_VIEW_SIZE
