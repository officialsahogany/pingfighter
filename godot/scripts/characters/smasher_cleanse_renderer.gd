extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const MAX_RENDERED_CAST_PARTICLES := 24
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "cleanse_immunity"
const TIMER_STACK_INDEX := 0

var _prewarm_assets_step_index := 0


func prewarm_step() -> bool:
	if _prewarm_assets_step_index == 0:
		if not bool(ImpactFlareTextureCache.prewarm_step()):
			return false
		_prewarm_assets_step_index = 1
	if _prewarm_assets_step_index == 1:
		if not bool(ImpactShockwaveTextureCache.prewarm_step()):
			return false
		_prewarm_assets_step_index = 0
		return true
	_prewarm_assets_step_index = 0
	return true


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2,
	timer_stack: Object,
	visual_time_msec: float,
	active: bool,
	cast_timer_frames: float,
	immunity_timer_frames: float,
	immunity_total_frames: float,
	shield_transition_timer_frames: float,
	shield_transition_frames: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	center: Vector2,
	flash_alpha: float,
	wave_rings: Array[Dictionary],
	particles: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	_draw_cast_effect(
		canvas,
		shake_offset,
		active,
		cast_timer_frames,
		center,
		flash_alpha,
		wave_rings,
		particles
	)
	_draw_immunity_shield(
		canvas,
		shake_offset,
		visual_time_msec,
		active,
		immunity_timer_frames,
		immunity_total_frames,
		shield_transition_timer_frames,
		shield_transition_frames,
		last_player_pos,
		last_player_size
	)
	_draw_immunity_timer(
		canvas,
		timer_stack,
		visual_time_msec,
		immunity_timer_frames,
		immunity_total_frames
	)


func get_shield_projection_for_tests(
	visual_time_msec: float,
	immunity_timer_frames: float,
	immunity_total_frames: float,
	shield_transition_timer_frames: float,
	shield_transition_frames: float
) -> Vector4:
	var alpha_multiplier: float
	var shield_radius: float
	if shield_transition_timer_frames > 0.0:
		var transition_progress: float = shield_transition_timer_frames / max(1.0, shield_transition_frames)
		var eased: float = 1.0 - pow(1.0 - transition_progress, 2.0)
		shield_radius = lerp(100.0, 150.0, eased)
		alpha_multiplier = (1.0 - transition_progress) * 0.8 + 0.2
	else:
		shield_radius = 100.0
		alpha_multiplier = min(1.0, immunity_timer_frames / max(1.0, immunity_total_frames))
	var pulse: float = 0.85 + 0.15 * sin(visual_time_msec * 0.012)
	var base_alpha: float = clamp(0.86 * alpha_multiplier * pulse, 0.0, 0.86)
	var color_shift: float = sin(visual_time_msec * 0.003)
	return Vector4(shield_radius, base_alpha, pulse, color_shift)


func _draw_cast_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	active: bool,
	cast_timer_frames: float,
	center: Vector2,
	flash_alpha: float,
	wave_rings: Array[Dictionary],
	particles: Array[Dictionary]
) -> void:
	if not active:
		return
	if flash_alpha > 0.01:
		canvas.draw_rect(
			Rect2(Vector2.ZERO, Vector2(760.0, 750.0)),
			Color(200.0 / 255.0, 220.0 / 255.0, 1.0, min(0.40, flash_alpha * 0.18))
		)
	for ring in wave_rings:
		if not bool(ring.get("started", false)) or float(ring.get("alpha", 0.0)) <= 0.0:
			continue
		var radius: float = float(ring.get("radius", 10.0))
		var alpha: float = float(ring.get("alpha", 0.0))
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center + shake_offset,
			radius + 5.0,
			Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
			alpha * 0.26
		)
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center + shake_offset,
			radius,
			Color(220.0 / 255.0, 240.0 / 255.0, 1.0),
			alpha * 0.56
		)
	var particle_start: int = max(0, particles.size() - MAX_RENDERED_CAST_PARTICLES)
	for index in range(particle_start, particles.size()):
		var particle: Dictionary = particles[index]
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var hue: float = float(particle.get("hue", 0.0))
		var color := Color((100.0 + 155.0 * hue) / 255.0, (200.0 - 100.0 * hue) / 255.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("pos", center), center) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, size * 1.55, color, alpha * 0.62)
	if cast_timer_frames <= 10.0 and cast_timer_frames > 0.0:
		var shrink_progress: float = 1.0 - cast_timer_frames / 10.0
		var shrink_radius: float = 150.0 - 90.0 * shrink_progress
		var shrink_alpha: float = (100.0 + 155.0 * shrink_progress) / 255.0
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center + shake_offset,
			shrink_radius,
			Color(180.0 / 255.0, 230.0 / 255.0, 1.0),
			max(0.0, shrink_alpha * 0.50)
		)


func _draw_immunity_shield(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_time_msec: float,
	active: bool,
	immunity_timer_frames: float,
	immunity_total_frames: float,
	shield_transition_timer_frames: float,
	shield_transition_frames: float,
	last_player_pos: Vector2,
	last_player_size: Vector2
) -> void:
	if immunity_timer_frames <= 0.0 or active:
		return
	var shield_center: Vector2 = last_player_pos + last_player_size * 0.5 + shake_offset
	var projection := get_shield_projection_for_tests(
		visual_time_msec,
		immunity_timer_frames,
		immunity_total_frames,
		shield_transition_timer_frames,
		shield_transition_frames
	)
	var shield_radius: float = projection.x
	var base_alpha: float = projection.y
	var color_shift: float = projection.w
	ImpactFlareTextureCache.draw_glow(
		canvas,
		shield_center,
		shield_radius + 20.0,
		Color((80.0 + 60.0 * max(0.0, color_shift)) / 255.0, (180.0 - 40.0 * abs(color_shift)) / 255.0, 1.0),
		base_alpha * 0.22
	)
	for i in range(2):
		var ring_alpha: float = max(0.0, base_alpha * (0.90 - float(i) * 0.25))
		var phase: float = visual_time_msec * 0.008 + float(i) * 1.2
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			shield_center,
			shield_radius + float(i) * 4.0,
			Color((100.0 + 80.0 * sin(phase)) / 255.0, (200.0 + 40.0 * sin(phase + 1.5)) / 255.0, 1.0),
			ring_alpha * 0.54
		)
	ImpactFlareTextureCache.draw_glow(canvas, shield_center, shield_radius - 4.0, Color(130.0 / 255.0, 210.0 / 255.0, 1.0), base_alpha * 0.08)
	for arc_i in range(3):
		var angle: float = fmod(visual_time_msec * 0.006 + float(arc_i) * (TAU / 3.0), TAU)
		var p0: Vector2 = shield_center + Vector2(cos(angle), sin(angle)) * shield_radius * 0.80
		var p1: Vector2 = shield_center + Vector2(cos(angle + 0.4), sin(angle + 0.4)) * shield_radius * 0.85
		var arc_alpha: float = base_alpha * (0.5 + 0.3 * sin(visual_time_msec * 0.02 + float(arc_i)))
		canvas.draw_line(
			p0,
			p1,
			Color((150.0 + 105.0 * sin(visual_time_msec * 0.015 + float(arc_i))) / 255.0, (220.0 + 35.0 * sin(visual_time_msec * 0.02 + float(arc_i))) / 255.0, 1.0, arc_alpha),
			2.0,
			true
		)
	ImpactFlareTextureCache.draw_glow(canvas, shield_center + Vector2(0.0, -shield_radius * 0.40), shield_radius * 0.5, Color(220.0 / 255.0, 245.0 / 255.0, 1.0), base_alpha * 0.22)


func _draw_immunity_timer(
	canvas: CanvasItem,
	timer_stack: Object,
	visual_time_msec: float,
	immunity_timer_frames: float,
	immunity_total_frames: float
) -> void:
	if immunity_timer_frames <= 0.0:
		return
	var ratio: float = clamp(immunity_timer_frames / max(1.0, immunity_total_frames), 0.0, 1.0)
	var remaining_seconds: float = immunity_timer_frames / 60.0
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(16.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(40.0 / 255.0, 80.0 / 255.0, 130.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(80.0 / 255.0, 140.0 / 255.0, 200.0 / 255.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(20.0 / 255.0, 24.0 / 255.0, 36.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.04, 0.06, 0.10, 0.94))
	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 3.0:
		base_color = Color(60.0 / 255.0, 180.0 / 255.0, 220.0 / 255.0, 0.98)
		highlight_color = Color(140.0 / 255.0, 220.0 / 255.0, 1.0, 0.98)
	elif remaining_seconds > 1.5:
		base_color = Color(120.0 / 255.0, 160.0 / 255.0, 220.0 / 255.0, 0.98)
		highlight_color = Color(180.0 / 255.0, 200.0 / 255.0, 1.0, 0.98)
	else:
		var pulse: float = abs(sin(visual_time_msec * 0.015))
		base_color = Color(220.0 / 255.0, (100.0 + 80.0 * pulse) / 255.0, 60.0 / 255.0, 0.99)
		highlight_color = Color(1.0, (150.0 + 60.0 * pulse) / 255.0, 100.0 / 255.0, 0.99)
	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(160.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 0.92),
			1.0
		)
	var icon_center := frame_rect.position + Vector2(-16.0, frame_rect.size.y * 0.5)
	var icon_pulse: float = 1.0 + 0.15 * sin(visual_time_msec * 0.02)
	var icon_radius: float = max(7.0, 9.0 * icon_pulse)
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, icon_radius + 4.0, Color(0.0, 0.0, 0.0), 0.28)
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, icon_radius, Color(40.0 / 255.0, 160.0 / 255.0, 210.0 / 255.0), 0.46)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, icon_center, icon_radius, Color(100.0 / 255.0, 220.0 / 255.0, 1.0), 0.50)
	canvas.draw_line(icon_center + Vector2(0.0, -icon_radius * 0.55), icon_center + Vector2(0.0, icon_radius * 0.55), Color.WHITE, 2.0, true)
	canvas.draw_line(icon_center + Vector2(-icon_radius * 0.55, 0.0), icon_center + Vector2(icon_radius * 0.55, 0.0), Color.WHITE, 2.0, true)


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		760.0 - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		750.0 - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * TIMER_STACK_SPACING
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
