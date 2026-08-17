extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const PowerSmashFeedbackEffectRenderer := preload("res://scripts/characters/smasher_power_smash_feedback_effect_renderer.gd")
const SmasherSkillTimingMonitorRenderer := preload("res://scripts/characters/smasher_skill_timing_monitor_renderer.gd")
const DASH_STATUS_COLOR := Color(0.20, 0.80, 1.0)
const HALF_DASH_STATUS_COLOR := Color(0.60, 0.60, 1.0, 0.40)
const MAGNUM_FIELD_RAY_COUNT := 4
const MAX_RENDERED_MAGNUM_PARTICLES := 32

var power_effect_renderer: Object = PowerSmashFeedbackEffectRenderer.new()
var timing_monitor_renderer: Object = SmasherSkillTimingMonitorRenderer.new()
var _text_size_cache: Dictionary = {}


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw_power_smash_effects(canvas: Node2D, power_state, shake_offset: Vector2) -> void:
	power_effect_renderer.draw(canvas, power_state, shake_offset)


func draw_magnum_grip_effect(
	canvas: CanvasItem,
	magnum_state: Object,
	context: Dictionary,
	shake_offset: Vector2
) -> void:
	if canvas == null or magnum_state == null or not magnum_state.has_method("get_draw_context"):
		return
	var grip_context: Dictionary = magnum_state.get_draw_context()
	if not bool(grip_context.get("active", false)):
		return

	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO) + shake_offset
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var paddle_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	var player_center: Vector2 = player_pos + paddle_size * 0.5 + shake_offset
	var link: Vector2 = player_center - ball_pos
	var distance: float = link.length()
	if distance <= 1.0:
		return

	var now_msec: int = Time.get_ticks_msec()
	var elapsed: float = float(now_msec - int(grip_context.get("start_msec", now_msec)))
	var duration: float = max(1.0, float(grip_context.get("max_duration_msec", 2500)))
	var fade: float = 1.0 - clamp(elapsed / duration, 0.0, 1.0) * 0.25
	var ring_phase: float = float(grip_context.get("ring_phase", 0.0))
	var arc_phase: float = float(grip_context.get("arc_phase", 0.0))
	var dir: Vector2 = link / distance
	var perp := Vector2(-dir.y, dir.x)
	var jagged_time: float = float(now_msec) * 0.027

	_draw_magnum_paddle_field(canvas, player_center, ring_phase, fade)
	_draw_magnum_bolts(canvas, ball_pos, player_center, perp, distance, arc_phase, fade, jagged_time)
	_draw_magnum_ball_crackle(canvas, ball_pos, arc_phase, fade)
	_draw_magnum_particles(canvas, grip_context, shake_offset, fade)
	_draw_magnum_burst(canvas, ball_pos, player_center, now_msec, int(grip_context.get("last_burst_msec", now_msec)), fade)


func draw_banners(canvas: Node2D, width: float, height: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var center_x: float = width * 0.5
	timing_monitor_renderer.draw(canvas, font, context)
	if bool(context.get("dash_active", false)):
		_draw_dash_status(canvas, font, center_x, height, bool(context.get("dash_is_half", false)))

	var drive_timer: float = float(context.get("drive_text_timer_frames", 0.0))
	var drive_duration: float = max(1.0, float(context.get("drive_text_duration_frames", 30.0)))
	if drive_timer > 0.0:
		_draw_drive_banner(canvas, font, center_x, height, drive_timer, drive_duration)

	var power_timer: float = float(context.get("power_smashing_text_timer_frames", 0.0))
	var power_duration: float = max(1.0, float(context.get("power_smash_text_duration_frames", 48.0)))
	if power_timer > 0.0:
		_draw_power_smash_banner(canvas, font, center_x, height, power_timer, power_duration)


func _draw_dash_status(canvas: Node2D, font: Font, center_x: float, height: float, is_half_dash: bool) -> void:
	var text: String = "HALF DASH!" if is_half_dash else "DASH!"
	var color: Color = HALF_DASH_STATUS_COLOR if is_half_dash else DASH_STATUS_COLOR
	canvas.draw_string(font, Vector2(center_x - 30.0, height - 30.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 16, color)


func _draw_drive_banner(
	canvas: Node2D,
	font: Font,
	center_x: float,
	height: float,
	timer_frames: float,
	duration_frames: float
) -> void:
	var fade_frames: float = 8.0
	var alpha: float = 1.0
	if timer_frames > duration_frames - fade_frames:
		alpha = clamp((duration_frames - timer_frames) / fade_frames, 0.0, 1.0)
	elif timer_frames < fade_frames:
		alpha = clamp(timer_frames / fade_frames, 0.0, 1.0)

	var text: String = "벽력타"
	var font_size: int = 28
	var text_size: Vector2 = _get_text_size(font, text, font_size)
	var text_pos: Vector2 = Vector2(center_x - text_size.x * 0.5, height * 0.60)
	canvas.draw_string(font, text_pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.1, 0.1, 0.1, 0.65 * alpha))
	canvas.draw_string(font, text_pos + Vector2(-1.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.38, 0.62, 1.0, 0.72 * alpha))
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.90, 0.98, 1.0, alpha))


func _draw_power_smash_banner(
	canvas: Node2D,
	font: Font,
	center_x: float,
	height: float,
	timer_frames: float,
	duration_frames: float
) -> void:
	var fade_frames: float = 10.0
	var alpha: float = 1.0
	if timer_frames > duration_frames - fade_frames:
		alpha = clamp((duration_frames - timer_frames) / fade_frames, 0.0, 1.0)
	elif timer_frames < fade_frames:
		alpha = clamp(timer_frames / fade_frames, 0.0, 1.0)

	var text: String = "천뢰격"
	var font_size: int = 30
	var text_size: Vector2 = _get_text_size(font, text, font_size)
	var text_pos: Vector2 = Vector2(center_x - text_size.x * 0.5, height * 0.54)
	var glow_color: Color = Color(0.18, 0.72, 1.0, 0.72 * alpha)
	canvas.draw_string(font, text_pos + Vector2(3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.01, 0.04, 0.16, 0.82 * alpha))
	canvas.draw_string(font, text_pos + Vector2(-1.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, glow_color)
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.92, 0.99, 1.0, alpha))


func _draw_magnum_paddle_field(canvas: CanvasItem, center: Vector2, ring_phase: float, fade: float) -> void:
	var blue := Color(70.0 / 255.0, 160.0 / 255.0, 1.0)
	var light := Color(150.0 / 255.0, 220.0 / 255.0, 1.0)
	var silver := Color(190.0 / 255.0, 215.0 / 255.0, 240.0 / 255.0)
	for i in range(2):
		var phase: float = fmod(ring_phase + float(i) * 0.55, 1.6)
		if phase >= 1.0:
			continue
		var radius: float = 20.0 + phase * 55.0
		var alpha: float = 0.90 * (1.0 - phase) * fade
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius, blue, alpha * 0.42)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, max(1.0, radius - 2.0), silver, alpha * 0.20)

	var pulse: float = 0.55 + 0.45 * sin(ring_phase * 3.2)
	var core_radius: float = 24.0 + pulse * 10.0
	ImpactFlareTextureCache.draw_glow(canvas, center, core_radius, blue, (0.26 + pulse * 0.13) * fade)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, core_radius * 0.42, light, (0.52 + pulse * 0.18) * fade)

	for i in range(MAGNUM_FIELD_RAY_COUNT):
		var angle: float = float(i) * TAU / float(MAGNUM_FIELD_RAY_COUNT) + ring_phase * 0.18
		var inner: float = 28.0 + sin(ring_phase * 2.0 + float(i) * 0.7) * 3.0
		var outer: float = inner + 10.0 + sin(ring_phase + float(i)) * 4.0
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * inner
		var finish: Vector2 = center + Vector2(cos(angle), sin(angle)) * outer
		var alpha: float = (0.38 + 0.22 * sin(ring_phase * 2.0 + float(i) * 0.9)) * fade
		canvas.draw_line(start, finish, Color(light.r, light.g, light.b, alpha), 2.0, true)


func _draw_magnum_bolts(
	canvas: CanvasItem,
	ball_pos: Vector2,
	player_center: Vector2,
	perp: Vector2,
	distance: float,
	arc_phase: float,
	fade: float,
	jagged_time: float
) -> void:
	var deep := Color(20.0 / 255.0, 70.0 / 255.0, 160.0 / 255.0)
	var blue := Color(70.0 / 255.0, 160.0 / 255.0, 1.0)
	var light := Color(150.0 / 255.0, 220.0 / 255.0, 1.0)
	var segments: int = max(5, int(distance / 34.0))
	for i in range(1):
		var points: PackedVector2Array = _magnum_jagged_points(ball_pos, player_center, segments, max(8.0, distance * 0.08), perp, arc_phase + float(i) * 1.7, jagged_time)
		var alpha: float = (0.70 - float(i) * 0.08) * fade
		canvas.draw_polyline(points, Color(deep.r, deep.g, deep.b, alpha * 0.42), 6.0, true)
		canvas.draw_polyline(points, Color(blue.r, blue.g, blue.b, alpha), 3.0, true)
		canvas.draw_polyline(points, Color(1.0, 1.0, 1.0, min(1.0, alpha + 0.22)), 1.0, true)
	for side in [-1.0, 1.0]:
		var offset_start: Vector2 = ball_pos + perp * 8.0 * side
		var points: PackedVector2Array = _magnum_jagged_points(offset_start, player_center, segments, max(10.0, distance * 0.11), perp, arc_phase + side * 2.3, jagged_time)
		canvas.draw_polyline(points, Color(light.r, light.g, light.b, 0.40 * fade), 2.0, true)


func _draw_magnum_ball_crackle(canvas: CanvasItem, ball_pos: Vector2, arc_phase: float, fade: float) -> void:
	var blue := Color(70.0 / 255.0, 160.0 / 255.0, 1.0)
	var light := Color(150.0 / 255.0, 220.0 / 255.0, 1.0)
	for i in range(3):
		var angle: float = arc_phase * 0.7 + float(i) * TAU / 3.0
		var r0: float = 10.0 + 3.0 * sin(arc_phase + float(i))
		var r1: float = r0 + 12.0 + 4.0 * cos(arc_phase * 1.4 + float(i))
		var start: Vector2 = ball_pos + Vector2(cos(angle), sin(angle)) * r0
		var finish: Vector2 = ball_pos + Vector2(cos(angle), sin(angle)) * r1
		canvas.draw_line(start, finish, Color(blue.r, blue.g, blue.b, 0.70 * fade), 2.0, true)

	for ring_i in range(2):
		var phase: float = fmod(arc_phase * 0.15 + float(ring_i) * 0.5, 1.0)
		var radius: float = 28.0 - phase * 20.0
		if radius <= 4.0:
			continue
		var alpha: float = 0.70 * (1.0 - phase) * fade
		ImpactShockwaveTextureCache.draw_full_ring(canvas, ball_pos, radius, light, alpha * 0.38)


func _draw_magnum_particles(canvas: CanvasItem, grip_context: Dictionary, shake_offset: Vector2, fade: float) -> void:
	var particle_list: Variant = grip_context.get("particles", [])
	if not (particle_list is Array):
		return
	var particle_start: int = max(0, particle_list.size() - MAX_RENDERED_MAGNUM_PARTICLES)
	for index in range(particle_start, particle_list.size()):
		var particle: Variant = particle_list[index]
		if not (particle is Dictionary):
			continue
		var p: Dictionary = particle
		var max_life: float = max(1.0, float(p.get("max_life", 1.0)))
		var life_ratio: float = clamp(float(p.get("life", 0.0)) / max_life, 0.0, 1.0)
		var alpha: float = (1.0 - life_ratio * life_ratio) * fade
		if alpha <= 0.02:
			continue
		var pos: Vector2 = _as_vector2(p.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(p.get("size", 2.0)) * (1.0 - life_ratio * 0.3))
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, size * 1.8, Color(150.0 / 255.0, 220.0 / 255.0, 1.0), alpha * 0.58)


func _draw_magnum_burst(
	canvas: CanvasItem,
	ball_pos: Vector2,
	player_center: Vector2,
	now_msec: int,
	last_burst_msec: int,
	fade: float
) -> void:
	var elapsed: int = now_msec - last_burst_msec
	if elapsed < 0 or elapsed >= 400:
		return
	var t: float = float(elapsed) / 400.0
	var alpha: float = (1.0 - t) * fade
	var radius: float = 28.0 + t * 100.0
	ImpactFlareTextureCache.draw_burst(canvas, player_center, radius, Color(70.0 / 255.0, 160.0 / 255.0, 1.0), alpha * 0.18)
	ImpactFlareTextureCache.draw_glow(canvas, ball_pos, radius * 0.60, Color(150.0 / 255.0, 220.0 / 255.0, 1.0), alpha * 0.12)


@warning_ignore("shadowed_global_identifier")
func _magnum_jagged_points(start: Vector2, finish: Vector2, segments: int, jitter_amp: float, perp: Vector2, seed: float, jagged_time: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(start)
	for i in range(1, segments):
		var u: float = float(i) / float(segments)
		var base: Vector2 = start.lerp(finish, u)
		var damp: float = sin(u * PI)
		var jitter: float = sin(seed * 3.1 + float(i) * 1.73 + jagged_time) * jitter_amp * damp
		points.append(base + perp * jitter)
	points.append(finish)
	return points


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key: String = "%s|%d" % [text, font_size]
	if _text_size_cache.has(cache_key):
		return _text_size_cache[cache_key]
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_text_size_cache[cache_key] = text_size
	return text_size


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
