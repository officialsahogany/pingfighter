extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const SKY_BLUE := Color(100.0 / 255.0, 200.0 / 255.0, 1.0)
const MAIN_BLUE := Color(200.0 / 255.0, 230.0 / 255.0, 1.0)
const CORE_WHITE := Color(1.0, 1.0, 1.0)
# 원본(ui/hud_display.py `draw_dash_spirit_lasers`)은 "매우 얇고 긴 타원형" —
# 글로우 / 메인 / 코어 전부 `pygame.draw.ellipse`다. Godot `draw_line`은 라인 캡
# 옵션이 없어 무조건 직각(버트) 캡으로 끝나므로(antialiased=true는 가장자리만
# 부드럽게 할 뿐 끝을 둥글게 만들지 않는다) 같은 두께로 그려도 사각 막대로
# 읽힌다. 원본과 동일하게 채워진 타원 폴리곤을 겹쳐 그린다.
# 원본 `ellipse_height` = 5 (반높이), 코어는 반높이 3 + 양 끝 10px 인셋.
const LASER_HALF_HEIGHT := 5.0
const CORE_HALF_HEIGHT := 3.0
const CORE_END_INSET := 10.0
const GLOW_LAYER_COUNT := 5
const ELLIPSE_SEGMENTS := 48
const SPARK_COUNT := 3
const MAX_RENDERED_EVAPORATION_PARTICLES := 28

var _unit_ellipse_points_cache: Dictionary = {}


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw(canvas: CanvasItem, lasers: Array, particles: Array, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	if lasers.is_empty() and particles.is_empty():
		return
	for laser in lasers:
		_draw_laser(canvas, laser, shake_offset)
	var particle_start: int = max(0, particles.size() - MAX_RENDERED_EVAPORATION_PARTICLES)
	for index in range(particle_start, particles.size()):
		_draw_evaporation_particle(canvas, particles[index], shake_offset)


func _draw_laser(canvas: CanvasItem, laser: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(laser.get("alpha", 255.0)) / 255.0, 0.0, 1.0)
	if alpha < 0.04:
		return
	var start: Vector2 = _as_vector2(laser.get("start", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var end: Vector2 = _as_vector2(laser.get("end", Vector2.ZERO), Vector2.ZERO) + shake_offset
	if start.distance_squared_to(end) <= 0.01:
		return

	# 원본과 동일하게 가로 타원으로 잡는다 (레이저는 항상 수평이다).
	var center: Vector2 = (start + end) * 0.5
	var half_length: float = absf(end.x - start.x) * 0.5
	for layer in build_laser_layers(half_length, alpha):
		_draw_ellipse(
			canvas,
			center,
			float(layer.get("half_width", 0.0)),
			float(layer.get("half_height", 0.0)),
			_as_color(layer.get("color", MAIN_BLUE), MAIN_BLUE)
		)

	if float(laser.get("remaining_time", 0.0)) > float(laser.get("duration", 360.0)) - 10.0:
		var impact_frame: float = 10.0 - (float(laser.get("duration", 360.0)) - float(laser.get("remaining_time", 0.0)))
		var impact_radius: float = max(2.0, impact_frame * 3.0)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, start, impact_radius, Color(150.0 / 255.0, 220.0 / 255.0, 1.0), alpha * 0.28)

	var now: float = float(Time.get_ticks_msec()) * 0.001
	for i in range(SPARK_COUNT):
		var t: float = fmod(now * 0.72 + float(i) * 0.37, 1.0)
		var spark_pos: Vector2 = start.lerp(end, t) + Vector2(
			sin(now * 23.0 + float(i) * 2.0) * 3.0,
			cos(now * 19.0 + float(i) * 1.7) * (LASER_HALF_HEIGHT + 2.0)
		)
		var spark_alpha: float = alpha * (0.5 + 0.5 * (0.5 + 0.5 * sin(now * 17.0 + float(i))))
		ImpactFlareTextureCache.draw_sparkle(canvas, spark_pos, 2.2, MAIN_BLUE, spark_alpha * 0.70)


# 레이저 한 줄이 그리는 타원 레이어를 뒤 -> 앞 순서로 만든다. 원본 순서와 값:
# 글로우 5겹(i=5 가장 크고 옅음 -> i=1 가장 작고 진함) -> 메인 -> 코어(양 끝 인셋).
func build_laser_layers(half_length: float, alpha: float) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if half_length <= 0.0 or alpha <= 0.0:
		return layers
	for layer in range(GLOW_LAYER_COUNT, 0, -1):
		var glow_alpha: float = min(1.0, alpha * 0.20 / float(layer))
		if glow_alpha <= 0.0:
			continue
		layers.append({
			"half_width": half_length + float(layer) * 2.0,
			"half_height": LASER_HALF_HEIGHT + float(layer) * 2.0,
			"color": Color(SKY_BLUE.r, SKY_BLUE.g, SKY_BLUE.b, glow_alpha),
		})
	layers.append({
		"half_width": half_length,
		"half_height": LASER_HALF_HEIGHT,
		"color": Color(MAIN_BLUE.r, MAIN_BLUE.g, MAIN_BLUE.b, alpha),
	})
	var core_half_length: float = half_length - CORE_END_INSET
	if core_half_length > 0.0:
		layers.append({
			"half_width": core_half_length,
			"half_height": CORE_HALF_HEIGHT,
			"color": Color(CORE_WHITE.r, CORE_WHITE.g, CORE_WHITE.b, alpha * 0.80),
		})
	return layers


func _draw_evaporation_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 0.0)) / 255.0, 0.0, 1.0)
	var size: float = float(particle.get("size", 0.0))
	if alpha <= 0.0 or size <= 0.0:
		return
	var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var life_ratio: float = clamp(
		float(particle.get("lifetime", 1.0)) / max(1.0, float(particle.get("max_lifetime", 1.0))),
		0.0,
		1.0
	)
	var base_color: Color = _as_color(particle.get("color", MAIN_BLUE), MAIN_BLUE)
	var draw_color: Color = base_color.lerp(CORE_WHITE, 1.0 - life_ratio)
	ImpactFlareTextureCache.draw_sparkle(canvas, pos, max(2.4, size * 1.35), draw_color, alpha * 0.72)


func _draw_ellipse(canvas: CanvasItem, center: Vector2, half_width: float, half_height: float, color: Color) -> void:
	if half_width <= 0.0 or half_height <= 0.0:
		return
	var points := PackedVector2Array()
	for point in _get_unit_ellipse_points(ELLIPSE_SEGMENTS):
		points.append(center + Vector2(point.x * half_width, point.y * half_height))
	canvas.draw_colored_polygon(points, color)


func _get_unit_ellipse_points(segments: int) -> PackedVector2Array:
	var safe_segments: int = max(8, segments)
	if _unit_ellipse_points_cache.has(safe_segments):
		return _unit_ellipse_points_cache[safe_segments]
	var points := PackedVector2Array()
	for index in range(safe_segments):
		var angle: float = TAU * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle), sin(angle)))
	_unit_ellipse_points_cache[safe_segments] = points
	return points


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
