extends RefCounted

const PillarOrbBackgroundCache := preload("res://scripts/hud/pillar_orb_background_cache.gd")
const PillarGaugeOrbFillRenderer := preload("res://scripts/hud/pillar_gauge_orb_fill_renderer.gd")

const OUTER_GLOW_LAYERS := 1
const AMBIENT_PARTICLE_COUNT := 1
const FLASH_LAYER_COUNT := 2
const FLASH_LAYER_COUNT_LOD := 1
const FLASH_RING_SEGMENTS := 10
const FLASH_RING_SEGMENTS_LOD := 8
const IDLE_RING_SEGMENTS := 10
const IDLE_RING_SEGMENTS_LOD := 8
const LIQUID_DISPLAY_RISE_RESPONSE := 9.0
const LIQUID_DISPLAY_FALL_RESPONSE := 18.0
const LIQUID_DISPLAY_MAX_DELTA_SECONDS := 0.25
const LIQUID_DISPLAY_SNAP_EPSILON := 0.002
const FULL_GAUGE_SNAP_THRESHOLD := 0.999
const KI_JADE_ORNAMENT_SIZE_RATIO := 28.0 / 55.0
const KI_JADE_ORNAMENT_Y_OFFSET_RATIO := -65.0 / 55.0
const KI_JADE_ORNAMENT_MODULATE := Color(1.0, 1.0, 1.0, 0.98)

var background_cache: Object = PillarOrbBackgroundCache.new()
var fill_renderer: Object = PillarGaugeOrbFillRenderer.new()
var _display_full_ratio := 0.0
var _display_ratio_initialized := false
var _display_ratio_last_time := 0.0


func prewarm_caches(orb_radius: float, _context: Dictionary = {}) -> void:
	background_cache.prewarm_radial_background(
		max(16.0, orb_radius),
		Color(0.02, 0.05, 0.12, 1.0),
		Color(0.08, 0.13, 0.26, 1.0)
	)


func draw(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var pillar_drawer = context.get("pillar_drawer", null)
	if pillar_drawer == null:
		return

	var radius: float = max(16.0, orb_radius)
	var frame_width_base: float = float(context.get("frame_width_base", 7.0))
	var frame_width: float = max(4.0, frame_width_base * scale_factor)
	var gauge_value: float = float(context.get("gauge_value", 0.0))
	var gauge_max: float = max(1.0, float(context.get("gauge_max", 500.0)))
	var full_ratio: float = clamp(gauge_value / gauge_max, 0.0, 1.0)
	var display_full_ratio: float = _update_display_ratio(full_ratio, t)
	var lod_active: bool = float(context.get("hud_lod_scale", 1.0)) < 0.85
	var static_hud_lod := bool(context.get("pillar_hud_static_lod", false))
	var flash_duration: float = max(0.001, float(context.get("flash_duration", 1.0)))
	var flash_timer: float = max(0.0, float(context.get("flash_timer", 0.0)))
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var glow_strength: float = 0.08 + 0.06 * pulse
	if display_full_ratio >= 0.999:
		glow_strength += 0.14 + 0.10 * pulse
	if flash_timer > 0.0:
		glow_strength += 0.28 * (flash_timer / flash_duration)

	var outer_glow_layers: int = 0 if static_hud_lod else (1 if lod_active else OUTER_GLOW_LAYERS)
	for layer in range(outer_glow_layers):
		var glow_radius: float = radius + frame_width + 14.0 - float(layer) * 3.0
		var alpha: float = glow_strength * (1.0 - float(layer) * 0.18)
		canvas.draw_circle(center, glow_radius, Color(0.36, 0.58, 1.0, alpha))

	var frame_texture = context.get("frame_texture", null)
	if not (frame_texture is Texture2D):
		pillar_drawer.draw_pillar_orb_frame(
			canvas,
			center,
			radius,
			frame_width,
			Color(0.18, 0.14, 0.08, 1.0),
			Color(0.58, 0.48, 0.24, 1.0),
			Color(0.85, 0.73, 0.42, 1.0),
			Color(0.18, 0.46, 0.88, 1.0),
			Color(0.72, 0.88, 1.0, 1.0)
		)

	background_cache.draw_radial_background(
		canvas,
		center,
		radius,
		Color(0.02, 0.05, 0.12, 1.0),
		Color(0.08, 0.13, 0.26, 1.0)
	)

	var inner_limit_sq: float = (radius - 5.0) * (radius - 5.0)
	var ambient_particle_count: int = 0 if static_hud_lod else (1 if lod_active else AMBIENT_PARTICLE_COUNT)
	for i in range(ambient_particle_count):
		var pa: float = t * 0.8 + float(i) * 1.05
		var orbit_r: float = (radius - 10.0) * (0.25 + 0.45 * abs(sin(pa * 0.5 + float(i) * 0.7)))
		var orbit_angle: float = pa * (0.6 + float(i % 3) * 0.15)
		var particle_pos := center + Vector2(cos(orbit_angle), sin(orbit_angle * 0.8 + float(i))) * orbit_r
		if particle_pos.distance_squared_to(center) < inner_limit_sq:
			var pa_alpha: float = 0.30 + 0.20 * abs(sin(pa * 1.3))
			var pa_size: float = 1.8 + float(i % 3) * 0.6
			canvas.draw_circle(particle_pos, pa_size, Color(0.55, 0.78, 1.0, pa_alpha))
			canvas.draw_circle(particle_pos, pa_size * 0.4, Color(1.0, 1.0, 1.0, pa_alpha * 0.5))

	if not static_hud_lod:
		var core_pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		var core_alpha: float = 0.06 + 0.05 * core_pulse + display_full_ratio * 0.08
		canvas.draw_circle(center, radius * 0.55, Color(0.30, 0.55, 1.0, core_alpha))
		canvas.draw_circle(center, radius * 0.30, Color(0.50, 0.75, 1.0, core_alpha * 0.7))

	fill_renderer.draw(canvas, pillar_drawer, center, radius, t, scale_factor, display_full_ratio, context)
	if static_hud_lod and pillar_drawer.has_method("draw_pillar_orb_glass_lod"):
		pillar_drawer.draw_pillar_orb_glass_lod(canvas, center, radius, Color(0.50, 0.74, 1.0, 1.0))
	else:
		pillar_drawer.draw_pillar_orb_glass(canvas, center, radius, Color(0.50, 0.74, 1.0, 1.0))
	if frame_texture is Texture2D:
		var texture: Texture2D = frame_texture
		var spin_angle: float = _get_frame_spin_angle(context)
		pillar_drawer.draw_rotating_orb_frame_texture(canvas, texture, center, radius, spin_angle)
	_draw_ki_jade_ornament_overlay(canvas, center, radius, context)

	if flash_timer > 0.0 and not static_hud_lod:
		var flash_progress: float = flash_timer / flash_duration
		var flash_layer_count: int = FLASH_LAYER_COUNT_LOD if lod_active else FLASH_LAYER_COUNT
		for layer in range(flash_layer_count):
			var flash_radius: float = radius + 10.0 * scale_factor + float(layer) * 12.0 * scale_factor
			var flash_alpha: float = (0.38 - float(layer) * 0.10) * flash_progress
			canvas.draw_circle(center, flash_radius, Color(1.0, 0.82, 0.46, flash_alpha))
		var flash_ring_segments: int = FLASH_RING_SEGMENTS_LOD if lod_active else FLASH_RING_SEGMENTS
		canvas.draw_arc(center, radius + 26.0 * scale_factor * (1.0 - flash_progress), 0.0, TAU, flash_ring_segments, Color(1.0, 0.86, 0.50, 0.50 * flash_progress), 3.0)

	var ring_phase: float = fmod(t * 0.8, 1.0)
	var ring_r: float = radius * (0.5 + ring_phase * 0.5)
	var ring_alpha: float = 0.0 if static_hud_lod else 0.12 * (1.0 - ring_phase)
	if ring_alpha > 0.01:
		var idle_ring_segments: int = IDLE_RING_SEGMENTS_LOD if lod_active else IDLE_RING_SEGMENTS
		canvas.draw_arc(center, ring_r, 0.0, TAU, idle_ring_segments, Color(0.50, 0.74, 1.0, ring_alpha), 1.5)

	canvas.draw_circle(center, radius * 0.40, Color(0.78, 0.90, 1.0, 0.12 + display_full_ratio * 0.18))
	var gauge_text := "%d/%d" % [int(round(gauge_value)), int(round(gauge_max))]
	var gauge_font_size: int = int(round(16.0 * scale_factor))
	if static_hud_lod and pillar_drawer.has_method("draw_pillar_text_centered_lod"):
		pillar_drawer.draw_pillar_text_centered_lod(canvas, center, gauge_text, gauge_font_size, Color.WHITE)
	else:
		pillar_drawer.draw_pillar_text_centered(canvas, center, gauge_text, gauge_font_size, Color.WHITE)


func build_ki_jade_ornament_draw_spec(center: Vector2, radius: float, context: Dictionary) -> Dictionary:
	var texture_value: Variant = context.get("ornament_texture", null)
	if not (texture_value is Texture2D):
		return {}
	var ornament_size: float = max(10.0, radius * KI_JADE_ORNAMENT_SIZE_RATIO)
	var ornament_center := center + Vector2(0.0, radius * KI_JADE_ORNAMENT_Y_OFFSET_RATIO)
	return {
		"texture": texture_value,
		"rect": Rect2(ornament_center - Vector2.ONE * ornament_size * 0.5, Vector2.ONE * ornament_size),
		"modulate": KI_JADE_ORNAMENT_MODULATE,
	}


func _draw_ki_jade_ornament_overlay(canvas: CanvasItem, center: Vector2, radius: float, context: Dictionary) -> void:
	var draw_spec := build_ki_jade_ornament_draw_spec(center, radius, context)
	if draw_spec.is_empty():
		return
	var texture := draw_spec.get("texture", null) as Texture2D
	var rect: Rect2 = draw_spec.get("rect", Rect2())
	var modulate: Color = draw_spec.get("modulate", Color.WHITE)
	canvas.draw_texture_rect(
		texture,
		rect,
		false,
		modulate
	)


func _update_display_ratio(target_ratio: float, time_seconds: float) -> float:
	var clamped_target: float = clamp(target_ratio, 0.0, 1.0)
	if clamped_target >= FULL_GAUGE_SNAP_THRESHOLD:
		_display_full_ratio = 1.0
		_display_ratio_last_time = time_seconds
		_display_ratio_initialized = true
		return _display_full_ratio
	if not _display_ratio_initialized or time_seconds < _display_ratio_last_time:
		_display_full_ratio = clamped_target
		_display_ratio_last_time = time_seconds
		_display_ratio_initialized = true
		return _display_full_ratio

	var delta_seconds: float = clamp(time_seconds - _display_ratio_last_time, 0.0, LIQUID_DISPLAY_MAX_DELTA_SECONDS)
	_display_ratio_last_time = time_seconds
	if delta_seconds <= 0.0:
		return _display_full_ratio

	var response: float = LIQUID_DISPLAY_RISE_RESPONSE if clamped_target > _display_full_ratio else LIQUID_DISPLAY_FALL_RESPONSE
	var follow_alpha: float = 1.0 - exp(-response * delta_seconds)
	_display_full_ratio = lerpf(_display_full_ratio, clamped_target, follow_alpha)
	if abs(_display_full_ratio - clamped_target) <= LIQUID_DISPLAY_SNAP_EPSILON:
		_display_full_ratio = clamped_target
	return _display_full_ratio


func _get_frame_spin_angle(context: Dictionary) -> float:
	# Static HUD LOD trims ornamental layers, but the event-triggered frame spin
	# is just the already-drawn frame texture with a transform while active.
	return float(context.get("frame_spin_angle", 0.0))
