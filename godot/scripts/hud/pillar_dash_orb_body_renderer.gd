extends RefCounted

const PillarOrbBackgroundCache := preload("res://scripts/hud/pillar_orb_background_cache.gd")
const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")

# stage1_pillar_ui_layout.PILLAR_ORB_RADIUS_BASE 미러 — 라이브 scale_factor 는
# 항상 orb_radius / 55 이므로 프리웜에서 같은 관계로 복원한다.
const ORB_RADIUS_BASE := 55.0

const OUTER_GLOW_LAYERS := 2
const OUTER_GLOW_LAYERS_LOD := 1
const AMBIENT_PARTICLE_COUNT := 2
const AMBIENT_PARTICLE_COUNT_LOD := 1
const COMPACT_FRAME_OUTER_SEGMENTS := 24
const COMPACT_FRAME_OUTER_SEGMENTS_LOD := 16
const COMPACT_FRAME_HIGHLIGHT_SEGMENTS := 12
const COMPACT_FRAME_HIGHLIGHT_SEGMENTS_LOD := 8
const COMPACT_FRAME_INNER_SEGMENTS := 20
const COMPACT_FRAME_INNER_SEGMENTS_LOD := 14
const COMPACT_FRAME_OUTER_SEGMENTS_STATIC_LOD := 10
const COMPACT_FRAME_HIGHLIGHT_SEGMENTS_STATIC_LOD := 5
const COMPACT_FRAME_INNER_SEGMENTS_STATIC_LOD := 8

var background_cache: Object = PillarOrbBackgroundCache.new()
var _static_layer_cache: Object = PillarOrbStaticLayerCache.new()


func prewarm_caches(radius: float, context: Dictionary = {}) -> void:
	background_cache.prewarm_radial_background(
		max(1.0, radius),
		_get_color(context, "orb_background_outer", Color(0.06, 0.02, 0.03, 1.0)),
		_get_color(context, "orb_background_inner", Color(0.18, 0.06, 0.09, 1.0))
	)
	if bool(context.get("compact_fallback_frame", false)):
		var safe_radius: float = max(16.0, radius)
		var scale_factor: float = safe_radius / ORB_RADIUS_BASE
		var frame_width: float = max(4.0, float(context.get("frame_width_base", 7.0)) * scale_factor)
		var metal_dark: Color = _get_color(context, "orb_metal_dark", Color(0.16, 0.10, 0.09, 1.0))
		var metal_mid: Color = _get_color(context, "orb_metal_mid", Color(0.46, 0.34, 0.32, 1.0))
		var metal_light: Color = _get_color(context, "orb_metal_light", Color(0.70, 0.54, 0.50, 1.0))
		var gem_core: Color = _get_color(context, "orb_gem_core", Color(0.84, 0.20, 0.20, 1.0))
		_static_layer_cache.build_now(
			_compact_frame_cache_key(safe_radius, frame_width, metal_dark, metal_mid, metal_light, gem_core),
			_build_compact_frame_ops(safe_radius, frame_width, metal_dark, metal_mid, metal_light, gem_core)
		)


func draw(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	radius: float,
	frame_width: float,
	t: float,
	available_tokens: int,
	max_tokens: int,
	flash_timer: float,
	flash_duration: float,
	frame_texture,
	context: Dictionary
) -> void:
	if canvas == null or pillar_drawer == null:
		return

	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var outer_glow: float = 0.08 + 0.06 * pulse
	if available_tokens > 0:
		outer_glow += 0.08 + 0.06 * pulse
	if flash_timer > 0.0:
		outer_glow += 0.28 * (flash_timer / flash_duration)

	var lod_active: bool = _is_hud_lod_active(context)
	var static_hud_lod := bool(context.get("pillar_hud_static_lod", false))
	if not static_hud_lod:
		_draw_outer_glow(canvas, center, radius, frame_width, outer_glow, _get_color(context, "orb_outer_glow_color", Color(0.92, 0.28, 0.28, 1.0)), lod_active)
	if not (frame_texture is Texture2D):
		_draw_fallback_frame(canvas, pillar_drawer, center, radius, frame_width, context)
	_draw_background(canvas, center, radius, context)
	if not static_hud_lod:
		_draw_ambient_particles(canvas, center, radius, t, context)
	_draw_core(canvas, center, radius, t, available_tokens, max_tokens, context)


func _draw_outer_glow(canvas: CanvasItem, center: Vector2, radius: float, frame_width: float, outer_glow: float, glow_color: Color, lod_active: bool) -> void:
	var layer_count: int = OUTER_GLOW_LAYERS_LOD if lod_active else OUTER_GLOW_LAYERS
	for layer in range(layer_count):
		var glow_radius: float = radius + frame_width + 14.0 - float(layer) * 3.0
		var alpha: float = outer_glow * (1.0 - float(layer) * 0.18)
		canvas.draw_circle(center, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, alpha))


func _draw_fallback_frame(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	radius: float,
	frame_width: float,
	context: Dictionary
) -> void:
	if bool(context.get("compact_fallback_frame", false)):
		_draw_compact_fallback_frame(canvas, center, radius, frame_width, context)
		return
	pillar_drawer.draw_pillar_orb_frame(
		canvas,
		center,
		radius,
		frame_width,
		_get_color(context, "orb_metal_dark", Color(0.16, 0.10, 0.09, 1.0)),
		_get_color(context, "orb_metal_mid", Color(0.46, 0.34, 0.32, 1.0)),
		_get_color(context, "orb_metal_light", Color(0.70, 0.54, 0.50, 1.0)),
		_get_color(context, "orb_gem_core", Color(0.84, 0.20, 0.20, 1.0)),
		_get_color(context, "orb_gem_highlight", Color(1.0, 0.72, 0.72, 1.0))
	)


func _draw_compact_fallback_frame(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	frame_width: float,
	context: Dictionary
) -> void:
	if canvas == null:
		return
	var metal_dark: Color = _get_color(context, "orb_metal_dark", Color(0.16, 0.10, 0.09, 1.0))
	var metal_mid: Color = _get_color(context, "orb_metal_mid", Color(0.46, 0.34, 0.32, 1.0))
	var metal_light: Color = _get_color(context, "orb_metal_light", Color(0.70, 0.54, 0.50, 1.0))
	var gem_core: Color = _get_color(context, "orb_gem_core", Color(0.84, 0.20, 0.20, 1.0))
	var outer_radius: float = radius + frame_width
	if bool(context.get("pillar_hud_static_lod", false)):
		_draw_static_compact_fallback_frame(canvas, center, radius, frame_width, metal_dark, metal_mid, metal_light)
		return
	var lod_active: bool = _is_hud_lod_active(context)
	# 정적 레이어: 풀 퀄리티 변형만 베이크한다. LOD 변형은 세그먼트 수가 달라
	# 지오메트리가 다르고 이미 충분히 싸므로 즉시 경로를 유지한다.
	if not lod_active:
		var cache_key: String = _compact_frame_cache_key(radius, frame_width, metal_dark, metal_mid, metal_light, gem_core)
		var cached_texture: Texture2D = _static_layer_cache.get_texture(cache_key)
		if cached_texture == null and not _static_layer_cache.is_pending(cache_key):
			cached_texture = _static_layer_cache.request_build(
				cache_key,
				_build_compact_frame_ops(radius, frame_width, metal_dark, metal_mid, metal_light, gem_core)
			)
		if cached_texture != null:
			_static_layer_cache.draw_centered(canvas, cached_texture, center)
			return
	var outer_segments: int = COMPACT_FRAME_OUTER_SEGMENTS_LOD if lod_active else COMPACT_FRAME_OUTER_SEGMENTS
	var highlight_segments: int = COMPACT_FRAME_HIGHLIGHT_SEGMENTS_LOD if lod_active else COMPACT_FRAME_HIGHLIGHT_SEGMENTS
	var inner_segments: int = COMPACT_FRAME_INNER_SEGMENTS_LOD if lod_active else COMPACT_FRAME_INNER_SEGMENTS
	canvas.draw_circle(center, outer_radius, metal_dark)
	canvas.draw_arc(center, outer_radius - 2.0, 0.0, TAU, outer_segments, Color(metal_mid.r, metal_mid.g, metal_mid.b, 0.88), max(2.0, frame_width * 0.42))
	canvas.draw_arc(center, outer_radius - frame_width * 0.52, deg_to_rad(205.0), deg_to_rad(335.0), highlight_segments, Color(1.0, 0.96, 0.86, 0.46), max(1.0, frame_width * 0.26))
	canvas.draw_arc(center, radius + 1.0, 0.0, TAU, inner_segments, Color(0.08, 0.06, 0.08, 0.76), max(1.0, frame_width * 0.20))
	for angle_deg in [45.0, 135.0, 225.0, 315.0]:
		var angle: float = deg_to_rad(angle_deg)
		var bolt_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.76)
		canvas.draw_circle(bolt_pos, frame_width * 0.44, metal_mid)
		canvas.draw_circle(bolt_pos, frame_width * 0.27, metal_light)
		canvas.draw_circle(bolt_pos, frame_width * 0.15, gem_core)


func _draw_static_compact_fallback_frame(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	frame_width: float,
	metal_dark: Color,
	metal_mid: Color,
	metal_light: Color
) -> void:
	var outer_radius: float = radius + frame_width
	canvas.draw_circle(center, outer_radius, metal_dark)
	canvas.draw_arc(center, outer_radius - 2.0, 0.0, TAU, COMPACT_FRAME_OUTER_SEGMENTS_STATIC_LOD, Color(metal_mid.r, metal_mid.g, metal_mid.b, 0.86), max(2.0, frame_width * 0.38))
	canvas.draw_arc(center, outer_radius - frame_width * 0.52, deg_to_rad(212.0), deg_to_rad(328.0), COMPACT_FRAME_HIGHLIGHT_SEGMENTS_STATIC_LOD, Color(metal_light.r, metal_light.g, metal_light.b, 0.36), max(1.0, frame_width * 0.22))
	canvas.draw_arc(center, radius + 1.0, 0.0, TAU, COMPACT_FRAME_INNER_SEGMENTS_STATIC_LOD, Color(0.08, 0.06, 0.08, 0.68), max(1.0, frame_width * 0.18))
	for angle_deg in [45.0, 135.0, 225.0, 315.0]:
		var angle: float = deg_to_rad(angle_deg)
		var bolt_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.76)
		canvas.draw_circle(bolt_pos, frame_width * 0.30, metal_mid)


func _compact_frame_cache_key(
	radius: float,
	frame_width: float,
	metal_dark: Color,
	metal_mid: Color,
	metal_light: Color,
	gem_core: Color
) -> String:
	return "compact_frame|%.2f|%.2f|%s|%s|%s|%s" % [
		radius,
		frame_width,
		PillarOrbStaticLayerCache.color_key(metal_dark),
		PillarOrbStaticLayerCache.color_key(metal_mid),
		PillarOrbStaticLayerCache.color_key(metal_light),
		PillarOrbStaticLayerCache.color_key(gem_core),
	]


# _draw_compact_fallback_frame 의 풀 퀄리티 즉시 드로우 본문과 지오메트리
# 1:1 대응. 본문이 바뀌면 이 op 리스트도 같이 갱신해야 한다.
func _build_compact_frame_ops(
	radius: float,
	frame_width: float,
	metal_dark: Color,
	metal_mid: Color,
	metal_light: Color,
	gem_core: Color
) -> Array:
	var outer_radius: float = radius + frame_width
	var ops: Array = [
		PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, outer_radius, metal_dark),
		PillarOrbStaticLayerCache.make_arc_band(Vector2.ZERO, outer_radius - 2.0, 0.0, TAU, COMPACT_FRAME_OUTER_SEGMENTS, max(2.0, frame_width * 0.42), Color(metal_mid.r, metal_mid.g, metal_mid.b, 0.88)),
		PillarOrbStaticLayerCache.make_arc_band(Vector2.ZERO, outer_radius - frame_width * 0.52, deg_to_rad(205.0), deg_to_rad(335.0), COMPACT_FRAME_HIGHLIGHT_SEGMENTS, max(1.0, frame_width * 0.26), Color(1.0, 0.96, 0.86, 0.46)),
		PillarOrbStaticLayerCache.make_arc_band(Vector2.ZERO, radius + 1.0, 0.0, TAU, COMPACT_FRAME_INNER_SEGMENTS, max(1.0, frame_width * 0.20), Color(0.08, 0.06, 0.08, 0.76)),
	]
	for angle_deg in [45.0, 135.0, 225.0, 315.0]:
		var angle: float = deg_to_rad(angle_deg)
		var bolt_pos: Vector2 = Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.76)
		ops.append(PillarOrbStaticLayerCache.make_circle(bolt_pos, frame_width * 0.44, metal_mid))
		ops.append(PillarOrbStaticLayerCache.make_circle(bolt_pos, frame_width * 0.27, metal_light))
		ops.append(PillarOrbStaticLayerCache.make_circle(bolt_pos, frame_width * 0.15, gem_core))
	return ops


func _draw_background(canvas: CanvasItem, center: Vector2, radius: float, context: Dictionary) -> void:
	var outer_color: Color = _get_color(context, "orb_background_outer", Color(0.06, 0.02, 0.03, 1.0))
	var inner_color: Color = _get_color(context, "orb_background_inner", Color(0.18, 0.06, 0.09, 1.0))
	background_cache.draw_radial_background(canvas, center, radius, outer_color, inner_color)


func _draw_ambient_particles(canvas: CanvasItem, center: Vector2, radius: float, t: float, context: Dictionary) -> void:
	var particle_color: Color = _get_color(context, "orb_particle_color", Color(1.0, 0.55, 0.42, 1.0))
	var particle_core_color: Color = _get_color(context, "orb_particle_core_color", Color(1.0, 1.0, 0.9, 1.0))
	var inner_limit_sq: float = (radius - 5.0) * (radius - 5.0)
	var particle_count: int = AMBIENT_PARTICLE_COUNT_LOD if _is_hud_lod_active(context) else AMBIENT_PARTICLE_COUNT
	for i in range(particle_count):
		var pa: float = t * 0.9 + float(i) * 1.26
		var orbit_r: float = (radius - 10.0) * (0.25 + 0.45 * abs(sin(pa * 0.5 + float(i) * 0.8)))
		var orbit_angle: float = pa * (0.7 + float(i % 3) * 0.12)
		var particle_pos: Vector2 = center + Vector2(cos(orbit_angle), sin(orbit_angle * 0.8 + float(i))) * orbit_r
		if particle_pos.distance_squared_to(center) < inner_limit_sq:
			var pa_alpha: float = 0.28 + 0.18 * abs(sin(pa * 1.2))
			var pa_size: float = 1.6 + float(i % 3) * 0.5
			canvas.draw_circle(particle_pos, pa_size, Color(particle_color.r, particle_color.g, particle_color.b, pa_alpha))
			canvas.draw_circle(particle_pos, pa_size * 0.4, Color(particle_core_color.r, particle_core_color.g, particle_core_color.b, pa_alpha * 0.5))


func _draw_core(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	t: float,
	available_tokens: int,
	max_tokens: int,
	context: Dictionary
) -> void:
	var core_pulse: float = 0.5 + 0.5 * sin(t * 3.2)
	var core_a: float = 0.06 + 0.05 * core_pulse + float(available_tokens) / float(max_tokens) * 0.08
	var core_outer: Color = _get_color(context, "orb_core_outer_color", Color(0.80, 0.20, 0.18, 1.0))
	var core_inner: Color = _get_color(context, "orb_core_inner_color", Color(1.0, 0.45, 0.35, 1.0))
	canvas.draw_circle(center, radius * 0.50, Color(core_outer.r, core_outer.g, core_outer.b, core_a))
	canvas.draw_circle(center, radius * 0.28, Color(core_inner.r, core_inner.g, core_inner.b, core_a * 0.7))


func _get_color(context: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = context.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _is_hud_lod_active(context: Dictionary) -> bool:
	return float(context.get("hud_lod_scale", 1.0)) < 0.85
