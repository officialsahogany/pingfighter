extends RefCounted

const PillarShapeHelper := preload("res://scripts/hud/pillar_shape_helper.gd")
const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")

const ORB_FRAME_BASE_RADIUS := 55.0
const ORB_FRAME_BASE_SIZE := 196.0
const FRAME_OUTER_RING_SEGMENTS := 32
const FRAME_MID_RING_SEGMENTS := 32
const FRAME_HIGHLIGHT_ARC_SEGMENTS := 14
const FRAME_INNER_RING_SEGMENTS := 28
const GLASS_HIGHLIGHT_SEGMENTS := 12
const GLASS_SMALL_HIGHLIGHT_SEGMENTS := 10
const GLASS_RIM_SEGMENTS := 10
const MAX_TEXT_SIZE_CACHE_ENTRIES := 64
const TEXT_OUTLINE_OFFSETS := [
	Vector2(-1.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, -1.0),
	Vector2(0.0, 1.0),
]

# 라이브 HUD가 draw_pillar_orb_glass 에 넘기는 림 색 (프리웜 전용 키 목록).
# 순서: 플레이어 대쉬 오브 기본값(pillar_dash_orb_renderer), 보스 대쉬 오브
# (stage1_pillar_status_orb_context_builder.glass_rim_color), 게이지 오브
# (pillar_gauge_orb_renderer). 값이 바뀌면 여기도 같이 갱신할 것.
const GLASS_PREWARM_RIM_COLORS := [
	Color(1.0, 0.56, 0.50, 1.0),
	Color(0.86, 0.56, 1.0, 1.0),
	Color(0.50, 0.74, 1.0, 1.0),
]
# 라이브 반경은 55 * (game_size.y / 750) 의 연속값이라 프리웜은 흔한 화면
# 높이의 정확한 키만 노린다: 750(창모드 1x) / 1080(FHD) / 1440(QHD).
# 그 외 해상도는 정적 레이어 캐시의 예산제 백그라운드 빌드가 인트로 프레임
# 동안 즉시 경로 폴백을 유지한 채 채운다 (히치 없음).
const GLASS_PREWARM_RADII := [55.0, 63.25, 79.2, 91.08, 105.6, 121.44]

var shape_helper: Object = PillarShapeHelper.new()
var _text_size_cache: Dictionary = {}
var _static_layer_cache: Object = PillarOrbStaticLayerCache.new()
var _glass_prewarm_index := 0


func get_orb_frame_draw_size(radius: float) -> float:
	return max(1.0, round(radius * ORB_FRAME_BASE_SIZE / ORB_FRAME_BASE_RADIUS))


func draw_rotating_orb_frame_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	radius: float,
	spin_angle_degrees: float
) -> bool:
	if canvas == null or texture == null:
		return false

	var frame_size: float = get_orb_frame_draw_size(radius)
	var frame_vector := Vector2(frame_size, frame_size)
	if abs(spin_angle_degrees) > 0.01:
		canvas.draw_set_transform(center, -deg_to_rad(spin_angle_degrees), Vector2.ONE)
		canvas.draw_texture_rect(texture, Rect2(-frame_vector * 0.5, frame_vector), false)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect(texture, Rect2(center - frame_vector * 0.5, frame_vector), false)
	return true


func draw_pillar_orb_frame(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	frame_width: float,
	metal_dark: Color,
	metal_mid: Color,
	metal_light: Color,
	gem_core: Color,
	gem_highlight: Color
) -> void:
	if canvas == null:
		return

	canvas.draw_circle(center, radius + frame_width, metal_dark)
	canvas.draw_arc(center, radius + frame_width - 1.0, 0.0, TAU, FRAME_OUTER_RING_SEGMENTS, Color(metal_mid.r, metal_mid.g, metal_mid.b, 0.95), 4.0)
	canvas.draw_arc(center, radius + frame_width - 4.5, 0.0, TAU, FRAME_MID_RING_SEGMENTS, Color(metal_light.r, metal_light.g, metal_light.b, 0.82), 2.0)
	canvas.draw_arc(center, radius + frame_width - 5.5, deg_to_rad(200.0), deg_to_rad(340.0), FRAME_HIGHLIGHT_ARC_SEGMENTS, Color(1.0, 0.97, 0.86, 0.62), 3.0)
	canvas.draw_arc(center, radius + frame_width - 5.5, deg_to_rad(20.0), deg_to_rad(160.0), FRAME_HIGHLIGHT_ARC_SEGMENTS, Color(0.12, 0.08, 0.05, 0.62), 3.0)
	canvas.draw_arc(center, radius + 1.5, 0.0, TAU, FRAME_INNER_RING_SEGMENTS, Color(0.08, 0.06, 0.04, 0.85), 2.0)

	for i in range(8):
		var angle: float = -PI * 0.5 + float(i) * TAU / 8.0
		var stud_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.55)
		canvas.draw_circle(stud_pos, frame_width * 0.58, Color(metal_dark.r * 0.70, metal_dark.g * 0.70, metal_dark.b * 0.70, 1.0))
		canvas.draw_circle(stud_pos, frame_width * 0.48, metal_mid)
		canvas.draw_circle(stud_pos, frame_width * 0.36, metal_light)
		canvas.draw_circle(stud_pos, frame_width * 0.24, gem_core)
		canvas.draw_circle(stud_pos + Vector2(-1.0, -1.0), frame_width * 0.11, Color(gem_highlight.r, gem_highlight.g, gem_highlight.b, 0.90))

	for angle_deg in [315.0, 45.0, 225.0, 135.0]:
		var angle: float = deg_to_rad(angle_deg)
		var bolt_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.92)
		canvas.draw_circle(bolt_pos, frame_width * 0.60, Color(metal_dark.r * 0.82, metal_dark.g * 0.82, metal_dark.b * 0.82, 1.0))
		canvas.draw_circle(bolt_pos, frame_width * 0.50, metal_mid)
		canvas.draw_circle(bolt_pos, frame_width * 0.38, metal_light)
		canvas.draw_circle(bolt_pos, frame_width * 0.24, gem_core)
		canvas.draw_circle(bolt_pos + Vector2(-1.0, -1.0), frame_width * 0.12, Color(gem_highlight.r, gem_highlight.g, gem_highlight.b, 0.72))


func draw_pillar_orb_glass(canvas: CanvasItem, center: Vector2, radius: float, rim_color: Color) -> void:
	if canvas == null:
		return

	# 정적 레이어: 베이크된 텍스처가 있으면 6개 벡터 드로우 대신 blit 1회.
	var cache_key: String = _glass_cache_key(radius, rim_color)
	var cached_texture: Texture2D = _static_layer_cache.get_texture(cache_key)
	if cached_texture == null and not _static_layer_cache.is_pending(cache_key):
		cached_texture = _static_layer_cache.request_build(cache_key, _build_glass_ops(radius, rim_color))
	if cached_texture != null:
		_static_layer_cache.draw_centered(canvas, cached_texture, center)
		return

	# 베이크 완료 전까지는 기존 즉시 드로우 경로 그대로 (시각 동일 폴백).
	var highlight_rect_1 := Rect2(center.x - radius + 8.0, center.y - radius + 5.0, radius + 12.0, radius * 0.55)
	var highlight_rect_2 := Rect2(center.x - radius + 14.0, center.y - radius + 11.0, max(8.0, radius - 10.0), radius * 0.36)
	var highlight_rect_3 := Rect2(center.x - radius + 18.0, center.y - radius + 15.0, max(7.0, radius * 0.56), max(6.0, radius * 0.25))
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect_1, GLASS_HIGHLIGHT_SEGMENTS), Color(1.0, 1.0, 1.0, 0.12))
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect_2, GLASS_HIGHLIGHT_SEGMENTS), Color(1.0, 1.0, 1.0, 0.18))
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect_3, GLASS_SMALL_HIGHLIGHT_SEGMENTS), Color(1.0, 1.0, 1.0, 0.22))
	canvas.draw_circle(center + Vector2(-radius * 0.34, -radius * 0.34), max(1.5, radius * 0.06), Color(1.0, 1.0, 1.0, 0.72))
	canvas.draw_circle(center + Vector2(-radius * 0.30, -radius * 0.30), max(1.0, radius * 0.04), Color(1.0, 1.0, 1.0, 0.42))
	canvas.draw_arc(center, radius - 2.0, deg_to_rad(30.0), deg_to_rad(150.0), GLASS_RIM_SEGMENTS, Color(rim_color.r, rim_color.g, rim_color.b, 0.20), 2.0)


func prewarm_static_layers(radius: float) -> void:
	for rim_value in GLASS_PREWARM_RIM_COLORS:
		var rim_color: Color = rim_value
		_static_layer_cache.build_now(_glass_cache_key(radius, rim_color), _build_glass_ops(radius, rim_color))


# 로딩 프리웜 스텝 머신 (pillar_status_orb_renderer.prewarm_caches_step 패턴).
# true 를 돌려주면 완료 + 인덱스 리셋.
func prewarm_static_layers_step() -> bool:
	if _glass_prewarm_index >= GLASS_PREWARM_RADII.size():
		_glass_prewarm_index = 0
		return true
	prewarm_static_layers(float(GLASS_PREWARM_RADII[_glass_prewarm_index]))
	_glass_prewarm_index += 1
	if _glass_prewarm_index >= GLASS_PREWARM_RADII.size():
		_glass_prewarm_index = 0
		return true
	return false


func _glass_cache_key(radius: float, rim_color: Color) -> String:
	return "glass|%.2f|%s" % [radius, PillarOrbStaticLayerCache.color_key(rim_color)]


# draw_pillar_orb_glass 의 즉시 드로우 본문과 지오메트리 1:1 대응. 본문이
# 바뀌면 이 op 리스트도 같이 갱신해야 한다.
func _build_glass_ops(radius: float, rim_color: Color) -> Array:
	var highlight_rect_1 := Rect2(-radius + 8.0, -radius + 5.0, radius + 12.0, radius * 0.55)
	var highlight_rect_2 := Rect2(-radius + 14.0, -radius + 11.0, max(8.0, radius - 10.0), radius * 0.36)
	var highlight_rect_3 := Rect2(-radius + 18.0, -radius + 15.0, max(7.0, radius * 0.56), max(6.0, radius * 0.25))
	return [
		PillarOrbStaticLayerCache.make_polygon(shape_helper.build_ellipse_points(highlight_rect_1, GLASS_HIGHLIGHT_SEGMENTS), Color(1.0, 1.0, 1.0, 0.12)),
		PillarOrbStaticLayerCache.make_polygon(shape_helper.build_ellipse_points(highlight_rect_2, GLASS_HIGHLIGHT_SEGMENTS), Color(1.0, 1.0, 1.0, 0.18)),
		PillarOrbStaticLayerCache.make_polygon(shape_helper.build_ellipse_points(highlight_rect_3, GLASS_SMALL_HIGHLIGHT_SEGMENTS), Color(1.0, 1.0, 1.0, 0.22)),
		PillarOrbStaticLayerCache.make_circle(Vector2(-radius * 0.34, -radius * 0.34), max(1.5, radius * 0.06), Color(1.0, 1.0, 1.0, 0.72)),
		PillarOrbStaticLayerCache.make_circle(Vector2(-radius * 0.30, -radius * 0.30), max(1.0, radius * 0.04), Color(1.0, 1.0, 1.0, 0.42)),
		PillarOrbStaticLayerCache.make_arc_band(Vector2.ZERO, radius - 2.0, deg_to_rad(30.0), deg_to_rad(150.0), GLASS_RIM_SEGMENTS, 2.0, Color(rim_color.r, rim_color.g, rim_color.b, 0.20)),
	]


func draw_pillar_orb_glass_lod(canvas: CanvasItem, center: Vector2, radius: float, rim_color: Color) -> void:
	if canvas == null:
		return
	var highlight_rect := Rect2(center.x - radius + 10.0, center.y - radius + 8.0, radius + 4.0, radius * 0.42)
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect, 8), Color(1.0, 1.0, 1.0, 0.13))
	canvas.draw_circle(center + Vector2(-radius * 0.32, -radius * 0.32), max(1.5, radius * 0.055), Color(1.0, 1.0, 1.0, 0.58))
	canvas.draw_arc(center, radius - 2.0, deg_to_rad(35.0), deg_to_rad(145.0), 6, Color(rim_color.r, rim_color.g, rim_color.b, 0.16), 1.5)


func draw_pillar_text_centered(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color) -> void:
	if canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = _get_cached_text_size(font, text, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	for offset in TEXT_OUTLINE_OFFSETS:
		canvas.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(1.0, color.a + 0.20)))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func draw_pillar_text_centered_lod(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color) -> void:
	if canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = _get_cached_text_size(font, text, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(0.92, color.a + 0.16)))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_cached_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key: String = "%s|%d" % [text, font_size]
	var cached: Variant = _text_size_cache.get(cache_key, null)
	if cached is Vector2:
		return cached
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	if _text_size_cache.size() >= MAX_TEXT_SIZE_CACHE_ENTRIES:
		_text_size_cache.clear()
	_text_size_cache[cache_key] = text_size
	return text_size
