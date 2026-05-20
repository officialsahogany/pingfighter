extends RefCounted

const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const CURSE_CHEST_SIZE := 36.0
const CURSE_SMOKE_TEXTURE_SIZE := 48
const STARPOINT_DROP_SIZE := 12.0
const MAX_RENDERED_TAIL_HIT_BURSTS := 2
const MAX_RENDERED_TAIL_HIT_BURSTS_LOD := 1
const MAX_RENDERED_TAIL_HIT_BURSTS_SEVERE_LOD := 1
const TAIL_HIT_RING_SEGMENTS := 24
const TAIL_HIT_RING_SEGMENTS_LOD := 16
const TAIL_HIT_RING_SEGMENTS_SEVERE_LOD := 12
const TAIL_HIT_SLASH_SEGMENTS := 16
const TAIL_HIT_SLASH_SEGMENTS_LOD := 12
const TAIL_HIT_SLASH_SEGMENTS_SEVERE_LOD := 8
const TAIL_HIT_ARC_COUNT := 3
const TAIL_HIT_ARC_COUNT_LOD := 2
const TAIL_HIT_ARC_COUNT_SEVERE_LOD := 1
const TAIL_HIT_ARC_SEGMENTS := 6
const TAIL_HIT_ARC_SEGMENTS_LOD := 4
const TAIL_HIT_ARC_SEGMENTS_SEVERE_LOD := 3
const TAIL_HIT_RAY_COUNT := 6
const TAIL_HIT_RAY_COUNT_LOD := 4
const TAIL_HIT_RAY_COUNT_SEVERE_LOD := 3
const MAX_RENDERED_PRISM_PARTICLES := 24
const MAX_RENDERED_PRISM_PARTICLES_LOD := 16
const MAX_RENDERED_PRISM_PARTICLES_SEVERE_LOD := 10
const MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES := 36
const MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES_LOD := 24
const MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES_SEVERE_LOD := 16
const MAX_RENDERED_CURSE_SMOKE_PARTICLES := 64
const MAX_RENDERED_CURSE_SMOKE_PARTICLES_LOD := 40
const MAX_RENDERED_CURSE_SMOKE_PARTICLES_SEVERE_LOD := 28
const MAX_RENDERED_CURSE_EXPLOSION_PARTICLES := 48
const MAX_RENDERED_CURSE_EXPLOSION_PARTICLES_LOD := 32
const MAX_RENDERED_CURSE_EXPLOSION_PARTICLES_SEVERE_LOD := 22
const MAX_RENDERED_KUROMI_EATING_PARTICLES := 40
const MAX_RENDERED_KUROMI_EATING_PARTICLES_LOD := 26
const MAX_RENDERED_KUROMI_EATING_PARTICLES_SEVERE_LOD := 18
const MAX_RENDERED_STARPOINT_PARTICLES := 48
const MAX_RENDERED_STARPOINT_PARTICLES_LOD := 30
const MAX_RENDERED_STARPOINT_PARTICLES_SEVERE_LOD := 20
const TAIL_DRAW_POINT_LIMIT := 18
const TAIL_DRAW_POINT_LIMIT_LOD := 14
const TAIL_DRAW_POINT_LIMIT_SEVERE_LOD := 10
const TAIL_FALLBACK_POINT_COUNT := 18
const TAIL_FALLBACK_POINT_COUNT_LOD := 14
const TAIL_FALLBACK_POINT_COUNT_SEVERE_LOD := 10

var curse_smoke_texture: Texture2D = null
var tail_draw_points: Array[Vector2] = []
var _active_quality_scale: float = 1.0


func prewarm_assets() -> void:
	_get_curse_smoke_texture()


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 3:
		return
	_active_quality_scale = _get_effect_quality_scale(context)
	_draw_psychoball_field(canvas, context, shake_offset)
	_draw_psychoball_hitstop_flash(canvas, context, shake_offset)
	_draw_psychoball_neutralize_particles(canvas, context, shake_offset)
	_draw_kuromi_spit_trail(canvas, context, shake_offset)
	_draw_kuromi_eating_particles(canvas, context, shake_offset)
	_draw_tail_whip(canvas, context, shake_offset)
	_draw_tail_hit_bursts(canvas, context, shake_offset)
	_draw_curse_chest(canvas, context, shake_offset)
	_draw_tears(canvas, context, shake_offset)
	_draw_prism_particles(canvas, context, shake_offset)
	_draw_starpoint_particles(canvas, context, shake_offset)
	_draw_starpoint_drops(canvas, context, shake_offset)


func _draw_psychoball_field(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage3_emotional_overdrive_active", false)):
		return
	var timer: int = int(floor(float(context.get("stage3_psycho_bg_timer", 0.0))))
	var color := Color(255.0 / 255.0, 100.0 / 255.0, 255.0 / 255.0, 1.0)
	if timer % 35 >= 15:
		color = Color(100.0 / 255.0, 0.0, 150.0 / 255.0, 1.0)
	canvas.draw_rect(Rect2(shake_offset, Vector2(WIDTH, HEIGHT)), color)


func _draw_psychoball_hitstop_flash(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage3_psychoball_hitstop_active", false)):
		return
	var ratio: float = clamp(float(context.get("stage3_psychoball_hitstop_ratio", 0.0)), 0.0, 1.0)
	var alpha: float = 0.32 * ratio
	canvas.draw_rect(Rect2(shake_offset, Vector2(WIDTH, HEIGHT)), Color(1.0, 0.86, 1.0, alpha))
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2(WIDTH * 0.5, HEIGHT * 0.5)), Vector2(WIDTH * 0.5, HEIGHT * 0.5)) + shake_offset
	var radius: float = 34.0 + (1.0 - ratio) * 58.0
	canvas.draw_arc(ball_pos, radius, 0.0, TAU, _get_lod_segment_count(48), Color(1.0, 0.92, 1.0, 0.86 * ratio), 4.0, true)
	canvas.draw_arc(ball_pos, radius * 0.62, 0.0, TAU, _get_lod_segment_count(40), Color(1.0, 0.22, 0.86, 0.70 * ratio), 2.0, true)


func _draw_psychoball_neutralize_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var particles: Array = _as_array(context.get("stage3_psychoball_neutralize_particles", []))
	var render_limit: int = _get_lod_count(MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES, MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES_LOD, MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES_SEVERE_LOD)
	for particle_index in range(_recent_start(particles, render_limit), particles.size()):
		var value: Variant = particles[particle_index]
		var particle: Dictionary = value if value is Dictionary else {}
		var life_frames: float = float(particle.get("life_frames", 0.0))
		if life_frames <= 0.0:
			continue
		var pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var alpha: float = clamp(life_frames * 8.0 / 255.0, 0.0, 1.0)
		var size: float = max(2.0, floor(life_frames / 3.0))
		var color := Color(
			float(particle.get("color_r", 170)) / 255.0,
			float(particle.get("color_g", 0)) / 255.0,
			float(particle.get("color_b", 220)) / 255.0,
			alpha
		)
		canvas.draw_circle(pos, size, color)


func _draw_tears(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage3_tears_active", false)):
		return
	var tears: Array = _as_array(context.get("stage3_falling_tears", []))
	for value in tears:
		var tear: Dictionary = value if value is Dictionary else {}
		var pos := Vector2(float(tear.get("x", 0.0)), float(tear.get("y", 0.0))) + shake_offset
		if pos.y < -24.0 or pos.y > HEIGHT + 24.0:
			continue
		var tail_start := pos + Vector2(0.0, -11.0)
		canvas.draw_line(tail_start, pos + Vector2(0.0, 7.0), Color(0.72, 0.88, 1.0, 0.55), 2.0)
		canvas.draw_circle(pos, 5.0, Color(0.55, 0.82, 1.0, 0.78))
		canvas.draw_circle(pos + Vector2(-1.5, -2.0), 1.8, Color(1.0, 1.0, 1.0, 0.72))


func _draw_curse_chest(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var phase: String = str(context.get("stage3_curse_chest_phase", "idle"))
	if phase == "idle":
		_draw_curse_reverse_overlay(canvas, context, shake_offset)
		return
	if phase == "windup":
		var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
		var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
		var progress: float = clamp(float(context.get("stage3_curse_chest_windup_progress", 0.0)), 0.0, 1.0)
		var wobble: float = sin(float(Time.get_ticks_msec()) * 0.020) * 5.0
		var pos := boss_pos + Vector2(boss_size.x * 0.5 + wobble, boss_size.y + 22.0) + shake_offset
		_draw_chest_symbol(canvas, pos, CURSE_CHEST_SIZE * (0.45 + progress * 0.55), wobble * 0.03, false)
		for idx in range(4):
			var angle := float(Time.get_ticks_msec()) * 0.006 + TAU * float(idx) / 4.0
			canvas.draw_circle(pos + Vector2(cos(angle) * 18.0, sin(angle) * 8.0), 2.0, Color(1.0, 0.45, 0.78, 0.55))
	elif phase == "throwing":
		var pos := _as_vector2(context.get("stage3_curse_chest_throw_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var progress: float = clamp(float(context.get("stage3_curse_chest_throw_progress", 0.0)), 0.0, 1.0)
		_draw_chest_symbol(canvas, pos, CURSE_CHEST_SIZE, progress * TAU * 2.0, false)
		for idx in range(3):
			var t: float = clamp(progress - 0.035 * float(idx + 1), 0.0, 1.0)
			var trail: Vector2 = _as_vector2(context.get("stage3_curse_chest_throw_start", Vector2.ZERO), Vector2.ZERO).lerp(
				_as_vector2(context.get("stage3_curse_chest_target", Vector2.ZERO), Vector2.ZERO),
				t
			)
			var arc: float = -180.0 * (4.0 * t * (1.0 - t))
			trail.y += arc
			canvas.draw_circle(trail + shake_offset, 4.0, Color(1.0, 0.35, 0.68, 0.38 - float(idx) * 0.08))
	elif phase == "closed" or phase == "open":
		var pos := _as_vector2(context.get("stage3_curse_chest_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var wobble_angle: float = deg_to_rad(float(context.get("stage3_curse_chest_wobble", 0.0)))
		_draw_chest_symbol(canvas, pos, CURSE_CHEST_SIZE, wobble_angle, phase == "open")
		if phase == "closed" and float(context.get("stage3_curse_chest_lifetime_ratio", 1.0)) < 0.25:
			var blink: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.045)
			canvas.draw_rect(Rect2(pos - Vector2(25.0, 17.0), Vector2(50.0, 34.0)), Color(1.0, 0.08, 0.10, 0.12 + blink * 0.18))
		_draw_curse_smoke(canvas, context, shake_offset)
	elif phase == "exploding":
		_draw_curse_explosion(canvas, context, shake_offset)
	_draw_curse_reverse_overlay(canvas, context, shake_offset)


func _draw_chest_symbol(canvas: CanvasItem, center: Vector2, size: float, _rotation: float, opened: bool) -> void:
	var half := size * 0.5
	var body_rect := Rect2(center + Vector2(-half, -half * 0.10), Vector2(size, half * 0.76))
	var lid_rect := Rect2(center + Vector2(-half - 2.0, -half * 0.36), Vector2(size + 4.0, half * 0.30))
	var color_body := Color(0.74, 0.18, 0.42, 0.94)
	var color_lid := Color(0.96, 0.36, 0.62, 0.96)
	if opened:
		color_body = Color(0.50, 0.10, 0.29, 0.94)
		lid_rect.position.y -= half * 0.35
		lid_rect.size.y *= 0.82
	canvas.draw_rect(body_rect, color_body)
	canvas.draw_rect(lid_rect, color_lid)
	canvas.draw_rect(body_rect.grow(1.5), Color(1.0, 0.68, 0.88, 0.82), false, 1.5)
	_draw_heart(canvas, center + Vector2(0.0, half * 0.17), max(4.0, size * 0.15), Color(1.0, 0.72, 0.86, 0.96))


func _draw_curse_smoke(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var smoke: Array = _as_array(context.get("stage3_curse_chest_smoke", []))
	var smoke_texture: Texture2D = _get_curse_smoke_texture()
	var render_limit: int = _get_lod_count(MAX_RENDERED_CURSE_SMOKE_PARTICLES, MAX_RENDERED_CURSE_SMOKE_PARTICLES_LOD, MAX_RENDERED_CURSE_SMOKE_PARTICLES_SEVERE_LOD)
	for smoke_index in range(_recent_start(smoke, render_limit), smoke.size()):
		var value: Variant = smoke[smoke_index]
		var p: Dictionary = value if value is Dictionary else {}
		var alpha: float = clamp(float(p.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var pos := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))) + shake_offset
		var size: float = float(p.get("size", 10.0))
		if smoke_texture != null:
			canvas.draw_texture_rect(
				smoke_texture,
				Rect2(pos - Vector2(size, size), Vector2(size * 2.0, size * 2.0)),
				false,
				Color(1.0, 1.0, 1.0, 0.78 * alpha)
			)
		else:
			canvas.draw_circle(pos, size, Color(1.0, 0.35, 0.70, 0.22 * alpha))


func _draw_curse_explosion(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var particles: Array = _as_array(context.get("stage3_curse_chest_explosion_particles", []))
	var render_limit: int = _get_lod_count(MAX_RENDERED_CURSE_EXPLOSION_PARTICLES, MAX_RENDERED_CURSE_EXPLOSION_PARTICLES_LOD, MAX_RENDERED_CURSE_EXPLOSION_PARTICLES_SEVERE_LOD)
	for particle_index in range(_recent_start(particles, render_limit), particles.size()):
		var value: Variant = particles[particle_index]
		var p: Dictionary = value if value is Dictionary else {}
		var pos := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))) + shake_offset
		var alpha: float = clamp(float(p.get("life_ratio", 0.0)), 0.0, 1.0)
		canvas.draw_circle(pos, float(p.get("size", 4.0)), Color(1.0, 0.28, 0.55, 0.72 * alpha))


func _draw_tail_whip(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage3_tail_whip_active", false)):
		return
	var progress: float = clamp(float(context.get("stage3_tail_whip_progress", 0.0)), 0.0, 1.0)
	tail_draw_points.clear()
	var runtime_points: Array = _as_array(context.get("stage3_tail_points", []))
	_copy_tail_draw_points(runtime_points, _get_lod_count(TAIL_DRAW_POINT_LIMIT, TAIL_DRAW_POINT_LIMIT_LOD, TAIL_DRAW_POINT_LIMIT_SEVERE_LOD), shake_offset)
	if tail_draw_points.is_empty():
		tail_draw_points = _build_fallback_tail_points(progress, context, shake_offset)
	if tail_draw_points.size() < 2:
		return
	var shadow_step: int = _get_tail_shadow_step()
	if shadow_step > 0:
		for idx in range(0, tail_draw_points.size() - 1, shadow_step):
			var thickness: float = max(1.0, (8.0 - float(idx) * 0.3) * 1.5)
			canvas.draw_line(tail_draw_points[idx] + Vector2(2.0, 2.0), tail_draw_points[idx + 1] + Vector2(2.0, 2.0), Color(230.0 / 255.0, 190.0 / 255.0, 1.0, 46.0 / 255.0), thickness + 2.0, true)
	for idx in range(tail_draw_points.size() - 1):
		var segment_t: float = float(idx) / max(1.0, float(tail_draw_points.size()))
		var color := Color(
			lerp(60.0 / 255.0, 230.0 / 255.0, segment_t),
			lerp(60.0 / 255.0, 190.0 / 255.0, segment_t),
			lerp(60.0 / 255.0, 1.0, segment_t),
			1.0
		)
		canvas.draw_line(tail_draw_points[idx], tail_draw_points[idx + 1], color, max(2.0, 10.0 - float(idx) * 0.3), true)
	var end: Vector2 = tail_draw_points[tail_draw_points.size() - 1]
	_draw_heart(canvas, end, 10.0, Color(1.0, 0.71, 0.76, 0.96))
	if 0.4 <= progress and progress <= 0.6 and not _is_severe_lod_active():
		canvas.draw_arc(tail_draw_points[maxi(0, tail_draw_points.size() - 5)], 28.0, 0.0, TAU, _get_lod_count(TAIL_HIT_RING_SEGMENTS, TAIL_HIT_RING_SEGMENTS_LOD, TAIL_HIT_RING_SEGMENTS_SEVERE_LOD), Color(1.0, 0.62, 0.90, 0.42), 2.4, true)


func _build_fallback_tail_points(progress: float, context: Dictionary, shake_offset: Vector2) -> Array[Vector2]:
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5) + shake_offset
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2(WIDTH * 0.5, HEIGHT * 0.5)), Vector2(WIDTH * 0.5, HEIGHT * 0.5)) + shake_offset
	var angle_to_target: float = atan2(ball_pos.y - center.y, ball_pos.x - center.x)
	var distance_to_target: float = center.distance_to(ball_pos)
	var angle_to_ball: float = angle_to_target
	if progress < 0.3:
		angle_to_ball = angle_to_target + PI
	var tail_base_angle: float = angle_to_ball
	var frame_time: float = float(Time.get_ticks_msec()) * 0.06
	var points: Array[Vector2] = []
	var point_count: int = _get_lod_count(TAIL_FALLBACK_POINT_COUNT, TAIL_FALLBACK_POINT_COUNT_LOD, TAIL_FALLBACK_POINT_COUNT_SEVERE_LOD)
	for idx in range(point_count):
		var t: float = float(idx) / float(maxi(1, point_count - 1))
		var wave: float = 0.0
		var distance: float = 0.0
		var depth_offset: float = 0.0
		if progress < 0.3:
			var spiral: float = t * PI * 4.0
			var wave_amplitude: float = 30.0 * (1.0 - t * 0.5)
			wave = sin(spiral - progress * PI * 3.0) * wave_amplitude
			distance = 25.0 * t * t * (1.0 - progress * 2.0)
		elif progress < 0.6:
			var whip_power: float = (progress - 0.3) / 0.3
			distance = distance_to_target * t * whip_power
			var wave_amplitude: float = 5.0 * (1.0 - t) * (1.0 - whip_power)
			wave = sin(t * PI * 2.0) * wave_amplitude
		else:
			var recovery: float = (progress - 0.6) / 0.4
			var spiral: float = t * PI * 2.0
			var wave_amplitude: float = 15.0 * (1.0 - t * 0.5) * recovery
			wave = sin(spiral + frame_time * 0.01) * wave_amplitude
			distance = 35.0 * t * t * (0.5 + recovery * 0.5)
			depth_offset = cos(frame_time * 0.008 + t * 3.0) * 8.0 * (1.0 - t) * recovery
		var tail_angle: float = tail_base_angle + wave * 0.02
		points.append(center + Vector2(
			distance * cos(tail_angle) + depth_offset * sin(tail_angle),
			distance * sin(tail_angle) - depth_offset * cos(tail_angle)
		))
	return points


func _draw_tail_hit_bursts(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var bursts: Array = _as_array(context.get("stage3_tail_hit_bursts", []))
	var burst_limit: int = _get_lod_count(MAX_RENDERED_TAIL_HIT_BURSTS, MAX_RENDERED_TAIL_HIT_BURSTS_LOD, MAX_RENDERED_TAIL_HIT_BURSTS_SEVERE_LOD)
	var ring_segments: int = _get_lod_count(TAIL_HIT_RING_SEGMENTS, TAIL_HIT_RING_SEGMENTS_LOD, TAIL_HIT_RING_SEGMENTS_SEVERE_LOD)
	var slash_segments: int = _get_lod_count(TAIL_HIT_SLASH_SEGMENTS, TAIL_HIT_SLASH_SEGMENTS_LOD, TAIL_HIT_SLASH_SEGMENTS_SEVERE_LOD)
	var arc_count: int = _get_lod_count(TAIL_HIT_ARC_COUNT, TAIL_HIT_ARC_COUNT_LOD, TAIL_HIT_ARC_COUNT_SEVERE_LOD)
	var arc_segments: int = _get_lod_count(TAIL_HIT_ARC_SEGMENTS, TAIL_HIT_ARC_SEGMENTS_LOD, TAIL_HIT_ARC_SEGMENTS_SEVERE_LOD)
	var ray_count: int = _get_lod_count(TAIL_HIT_RAY_COUNT, TAIL_HIT_RAY_COUNT_LOD, TAIL_HIT_RAY_COUNT_SEVERE_LOD)
	var start_index: int = max(0, bursts.size() - burst_limit)
	for burst_index in range(start_index, bursts.size()):
		var burst: Dictionary = bursts[burst_index] if bursts[burst_index] is Dictionary else {}
		var max_life: float = max(0.001, float(burst.get("max_life", 0.55)))
		var life: float = clamp(float(burst.get("life", 0.0)) / max_life, 0.0, 1.0)
		if life <= 0.0:
			continue
		var progress: float = 1.0 - life
		var center := Vector2(float(burst.get("x", 0.0)), float(burst.get("y", 0.0))) + shake_offset
		var angle: float = float(burst.get("angle", 0.0))
		@warning_ignore("shadowed_global_identifier")
		var seed: float = float(int(burst.get("seed", 0)) % 10000)
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.025 + seed * 0.01)
		canvas.draw_circle(center, 24.0 + progress * 44.0, Color(1.0, 0.82, 1.0, 0.10 * life))
		canvas.draw_arc(center, 22.0 + progress * 54.0, 0.0, TAU, ring_segments, Color(1.0, 0.92, 1.0, 0.70 * life), 4.0 - progress * 1.4, true)
		canvas.draw_arc(center, 13.0 + progress * 35.0, angle - PI * 0.85, angle + PI * 0.85, slash_segments, Color(1.0, 0.34, 0.78, 0.65 * life), 3.0 + pulse, true)
		for idx in range(arc_count):
			var hue: float = float(idx) / float(arc_count)
			var start_angle: float = angle + float(idx) * TAU / float(arc_count) + progress * 1.2
			var radius: float = 30.0 + float(idx % 3) * 5.0 + progress * 38.0
			var color := Color.from_hsv(hue, 0.78, 1.0, 0.34 * life)
			canvas.draw_arc(center, radius, start_angle, start_angle + PI * 0.35, arc_segments, color, 2.2, true)
		for idx in range(ray_count):
			var jitter: float = sin(seed * 0.17 + float(idx) * 12.989) * 0.28
			var ray_angle: float = angle + float(idx) * TAU / float(ray_count) + jitter
			var dir := Vector2(cos(ray_angle), sin(ray_angle))
			var length: float = 18.0 + progress * 48.0 + absf(sin(seed + float(idx) * 1.7)) * 16.0
			var inner: Vector2 = center + dir * (7.0 + progress * 10.0)
			var outer: Vector2 = center + dir * length
			var color := Color.from_hsv(fposmod(float(idx) / 7.0 + progress * 0.08, 1.0), 0.65, 1.0, 0.58 * life)
			canvas.draw_line(inner, outer, color, 2.0, true)
			if idx % 2 == 0 and not _is_lod_active():
				canvas.draw_circle(outer, 2.2 + pulse * 1.2, Color(1.0, 1.0, 1.0, 0.42 * life))
		var slash_dir := Vector2(cos(angle), sin(angle))
		var slash_side := Vector2(-slash_dir.y, slash_dir.x)
		for side in [-1.0, 1.0]:
			var slash_start: Vector2 = center - slash_dir * (34.0 + progress * 14.0) + slash_side * side * 8.0
			var slash_end: Vector2 = center + slash_dir * (44.0 + progress * 22.0) - slash_side * side * 8.0
			canvas.draw_line(slash_start, slash_end, Color(1.0, 0.76, 0.92, 0.50 * life), 3.0, true)


func _draw_kuromi_eating_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var particles: Array = _as_array(context.get("stage3_kuromi_eating_particles", []))
	var render_limit: int = _get_lod_count(MAX_RENDERED_KUROMI_EATING_PARTICLES, MAX_RENDERED_KUROMI_EATING_PARTICLES_LOD, MAX_RENDERED_KUROMI_EATING_PARTICLES_SEVERE_LOD)
	for particle_index in range(_recent_start(particles, render_limit), particles.size()):
		var value: Variant = particles[particle_index]
		var p: Dictionary = value if value is Dictionary else {}
		var life: float = clamp(float(p.get("life", 0.0)) / max(0.001, float(p.get("max_life", 0.9))), 0.0, 1.0)
		if life <= 0.0:
			continue
		var pos := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))) + shake_offset
		var hue: float = fposmod(float(p.get("hue", 0.92)), 1.0)
		var color := Color.from_hsv(hue, 0.58, 1.0, 0.62 * life)
		canvas.draw_circle(pos, float(p.get("size", 3.0)) * (0.6 + life), color)


func _draw_kuromi_spit_trail(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var trails: Array = _as_array(context.get("stage3_kuromi_spit_trail", []))
	if trails.is_empty():
		return
	var phase: float = float(context.get("stage3_kuromi_spit_trail_phase", 0.0))
	for idx in range(trails.size()):
		var p: Dictionary = trails[idx] if trails[idx] is Dictionary else {}
		var life: float = clamp(float(p.get("life", 0.0)), 0.0, 1.0)
		var hue: float = fposmod(phase + float(idx) * 0.08, 1.0)
		var color := Color.from_hsv(hue, 0.45, 1.0, 0.42 * life)
		canvas.draw_circle(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))) + shake_offset, float(p.get("size", 12.0)) * life, color)


func _draw_starpoint_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var particles: Array = _as_array(context.get("stage3_starpoint_particles", []))
	var render_limit: int = _get_lod_count(MAX_RENDERED_STARPOINT_PARTICLES, MAX_RENDERED_STARPOINT_PARTICLES_LOD, MAX_RENDERED_STARPOINT_PARTICLES_SEVERE_LOD)
	for particle_index in range(_recent_start(particles, render_limit), particles.size()):
		var value: Variant = particles[particle_index]
		var particle: Dictionary = value if value is Dictionary else {}
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var color: Color = _get_starpoint_particle_color(float(particle.get("color_shift", 0.5)), alpha)
		canvas.draw_circle(pos, max(1.0, float(particle.get("size", 2.0))), color)


func _draw_starpoint_drops(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var drops: Array = _as_array(context.get("stage3_starpoint_drops", []))
	# Stage 3 shares the Stage 1/2 scrap palette; commonization keeps the look
	# identical while removing the duplicate CPU loop. game_offset shifts the
	# playfield-local drop positions and sizes into rendered-playfield screen
	# coordinates since the host is a child of the outer canvas (outside the
	# playfield's draw_set_transform window).
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = maxf(0.001, float(context.get("render_scale", 1.0)))
	var host: Node = CommonStarpointVisualHost.get_or_create_on_canvas(canvas)
	if host != null and host.has_method("sync_drop"):
		host.begin_frame()
		var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
		for value in drops:
			var drop: Dictionary = value if value is Dictionary else {}
			var is_star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
			var playfield_pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			host.sync_drop({
				"pos": game_offset + playfield_pos * render_scale,
				"size": float(drop.get("size", STARPOINT_DROP_SIZE)) * render_scale,
				"life": float(drop.get("life", 0.0)),
				"rotation": float(drop.get("rotation", 0.0)),
				"glow_intensity": float(drop.get("glow_intensity", 1.0)),
				"star_detector_bonus": is_star_detector_bonus,
				"elapsed": elapsed,
				# Match Stage 1/2 pink + iridescent palette.
				"glow_color": Color(0.30, 0.92, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.45, 0.74, 1.0),
				"fill_color": Color(0.16, 0.82, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.42, 0.78, 1.0),
				"outline_color": Color(1.0, 1.0, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 1.0, 0.0, 1.0),
				"iridescent_shimmer_intensity": 0.0 if is_star_detector_bonus else 1.0,
				"sparkle_ray_intensity": 0.0 if is_star_detector_bonus else 1.0,
			})
		host.end_frame()
		return
	for value in drops:
		var drop: Dictionary = value if value is Dictionary else {}
		var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(drop.get("size", STARPOINT_DROP_SIZE)))
		var alpha: float = clamp(float(drop.get("life", 0.0)) * 2.0 / 255.0, 0.0, 1.0)
		var glow_intensity: float = clamp(float(drop.get("glow_intensity", 1.0)), 0.0, 1.0)
		var glow_alpha: float = alpha * 0.5 * glow_intensity
		var is_star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
		var glow_color := Color(0.30, 0.92, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.45, 0.74, 1.0)
		var fill_color := Color(0.16, 0.82, 1.0, alpha) if is_star_detector_bonus else Color(1.0, 0.0, 0.0, alpha)
		var outline_color := Color(1.0, 1.0, 1.0, alpha) if is_star_detector_bonus else Color(1.0, 1.0, 0.0, alpha)
		for layer in range(4):
			var glow_radius: float = size * (4.0 - float(layer) * 0.7)
			var layer_alpha: float = glow_alpha / float(4 - layer)
			canvas.draw_circle(pos, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, layer_alpha))

		var points := PackedVector2Array()
		var rotation: float = float(drop.get("rotation", 0.0))
		for point_index in range(10):
			var point_radius: float = size if point_index % 2 == 0 else size * 0.5
			var angle: float = rotation + float(point_index) * PI / 5.0
			points.append(pos + Vector2(cos(angle), sin(angle)) * point_radius)
		if points.size() >= 3:
			canvas.draw_colored_polygon(points, fill_color)
			for point_index in range(points.size()):
				canvas.draw_line(points[point_index], points[(point_index + 1) % points.size()], outline_color, 3.0)
		canvas.draw_circle(pos, 3.0, Color(1.0, 1.0, 1.0, alpha * glow_intensity))


func _get_starpoint_particle_color(color_shift: float, alpha: float) -> Color:
	var clamped_shift: float = clamp(color_shift, 0.0, 1.0)
	if clamped_shift < 0.33:
		var low_t: float = clamped_shift * 3.0
		return Color(1.0, 1.0, (100.0 + 155.0 * low_t) / 255.0, alpha)
	if clamped_shift < 0.66:
		var mid_t: float = (clamped_shift - 0.33) * 3.0
		return Color((255.0 - 55.0 * mid_t) / 255.0, (255.0 - 30.0 * mid_t) / 255.0, 1.0, alpha)
	var t: float = (clamped_shift - 0.66) * 3.0
	return Color((200.0 - 100.0 * t) / 255.0, (225.0 + 30.0 * t) / 255.0, 1.0, alpha)


func _draw_prism_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var particles: Array = _as_array(context.get("stage3_prism_particles", []))
	var render_limit: int = _get_lod_count(MAX_RENDERED_PRISM_PARTICLES, MAX_RENDERED_PRISM_PARTICLES_LOD, MAX_RENDERED_PRISM_PARTICLES_SEVERE_LOD)
	var start_index: int = max(0, particles.size() - render_limit)
	for idx in range(start_index, particles.size()):
		var p: Dictionary = particles[idx] if particles[idx] is Dictionary else {}
		var max_life: float = max(0.001, float(p.get("max_life", 1.0)))
		var life: float = clamp(float(p.get("life", 0.0)) / max_life, 0.0, 1.0)
		if life <= 0.0:
			continue
		var pos := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))) + shake_offset
		var sparkle: float = float(p.get("sparkle", 0.0))
		var size: float = float(p.get("size", 2.0)) * (1.0 + sin(sparkle) * 0.30)
		var hue: float = fposmod(float(p.get("hue", 0.0)), 1.0)
		var color := Color.from_hsv(hue, 0.72, 1.0, 0.86 * life)
		if life > 0.34 and idx % 4 == 0:
			var glow_color := Color.from_hsv(hue, 0.36, 1.0, 0.20 * life)
			canvas.draw_circle(pos, size * 2.15, glow_color)
		canvas.draw_circle(pos, size, color)
		if idx % 5 == 0 and not _is_lod_active():
			canvas.draw_circle(pos + Vector2(-size * 0.28, -size * 0.28), max(1.0, size * 0.32), Color(1.0, 1.0, 1.0, 0.78 * life))


func _draw_curse_reverse_overlay(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var ratio: float = clamp(float(context.get("stage3_curse_reverse_ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(350.0, 700.0)), Vector2(350.0, 700.0))
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var center := player_pos + Vector2(player_size.x * 0.5, player_size.y * 0.24) + shake_offset
	var t: float = float(Time.get_ticks_msec()) * 0.006
	var pulse: float = 0.5 + 0.5 * sin(t * 1.7)
	canvas.draw_circle(center, 34.0 + pulse * 7.0, Color(1.0, 0.25, 0.68, 0.07 * ratio))
	canvas.draw_arc(center, 38.0 + pulse * 5.0, t, t + PI * 1.4, _get_lod_segment_count(36), Color(1.0, 0.30, 0.72, 0.20 * ratio), 2.0, true)
	canvas.draw_arc(center, 25.0 + pulse * 3.0, t + PI, t + TAU * 0.92, _get_lod_segment_count(30), Color(1.0, 0.72, 0.90, 0.16 * ratio), 1.5, true)


func _draw_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(-size * 0.36, -size * 0.22), size * 0.48, color)
	canvas.draw_circle(center + Vector2(size * 0.36, -size * 0.22), size * 0.48, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.92, -size * 0.05),
		center + Vector2(size * 0.92, -size * 0.05),
		center + Vector2(0.0, size * 1.10),
	]), color)


func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a * pow(1.0 - t, 2.0) + b * (2.0 * (1.0 - t) * t) + c * pow(t, 2.0)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return source.size()
	return max(0, source.size() - render_limit)


func _copy_tail_draw_points(runtime_points: Array, draw_limit: int, shake_offset: Vector2) -> void:
	if runtime_points.is_empty() or draw_limit <= 0:
		return
	if runtime_points.size() <= 1:
		var single_value: Variant = runtime_points[0]
		if single_value is Vector2:
			tail_draw_points.append(single_value + shake_offset)
		return
	var safe_limit: int = clampi(draw_limit, 2, runtime_points.size())
	if runtime_points.size() <= safe_limit:
		for value in runtime_points:
			if value is Vector2:
				tail_draw_points.append(value + shake_offset)
		return
	var last_index: int = runtime_points.size() - 1
	var previous_source_index: int = -1
	for sample_index in range(safe_limit):
		var source_index: int = int(round(float(sample_index) * float(last_index) / float(maxi(1, safe_limit - 1))))
		if source_index == previous_source_index:
			continue
		previous_source_index = source_index
		var value: Variant = runtime_points[source_index]
		if value is Vector2:
			tail_draw_points.append(value + shake_offset)


func _get_tail_shadow_step() -> int:
	if _is_severe_lod_active():
		return 0
	if _is_lod_active():
		return 3
	return 2


func _get_effect_quality_scale(context: Dictionary) -> float:
	return ViperAirborneLod.effect_scale(context)


func _is_lod_active() -> bool:
	return _active_quality_scale < 0.85


func _is_severe_lod_active() -> bool:
	return _active_quality_scale < 0.66


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int) -> int:
	if base_count <= 0:
		return 0
	if _is_severe_lod_active():
		return clampi(severe_lod_count, 0, base_count)
	if _is_lod_active():
		return clampi(lod_count, 0, base_count)
	return base_count


func _get_lod_segment_count(base_segments: int) -> int:
	var safe_segments: int = maxi(8, base_segments)
	var lod_segments: int = maxi(8, int(ceil(float(safe_segments) * 0.72)))
	var severe_segments: int = maxi(8, int(ceil(float(safe_segments) * 0.50)))
	return _get_lod_count(safe_segments, lod_segments, severe_segments)


func _get_curse_smoke_texture() -> Texture2D:
	if curse_smoke_texture != null:
		return curse_smoke_texture
	var image := Image.create(CURSE_SMOKE_TEXTURE_SIZE, CURSE_SMOKE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(CURSE_SMOKE_TEXTURE_SIZE) * 0.5, float(CURSE_SMOKE_TEXTURE_SIZE) * 0.5)
	var radius: float = float(CURSE_SMOKE_TEXTURE_SIZE) * 0.48
	for y in range(CURSE_SMOKE_TEXTURE_SIZE):
		for x in range(CURSE_SMOKE_TEXTURE_SIZE):
			var pos := Vector2(float(x) + 0.5, float(y) + 0.5)
			var main_dist: float = pos.distance_to(center) / radius
			var lobe_dist: float = pos.distance_to(center + Vector2(radius * 0.18, -radius * 0.12)) / (radius * 0.55)
			var main_alpha: float = pow(maxf(0.0, 1.0 - main_dist), 1.45)
			var lobe_alpha: float = pow(maxf(0.0, 1.0 - lobe_dist), 1.20) * 0.72
			var alpha: float = maxf(main_alpha, lobe_alpha)
			if alpha <= 0.001:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var edge: float = clampf(main_dist, 0.0, 1.0)
			var color := Color(
				lerp(1.0, 0.74, edge),
				lerp(0.35, 0.20, edge),
				lerp(0.70, 0.58, edge),
				alpha
			)
			image.set_pixel(x, y, color)
	curse_smoke_texture = ImageTexture.create_from_image(image)
	return curse_smoke_texture


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
