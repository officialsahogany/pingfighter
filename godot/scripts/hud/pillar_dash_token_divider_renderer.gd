extends RefCounted

const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")

# divider_anim_progress 가 이 값 이상이면 "정착 상태"로 보고 베이크 텍스처를
# 쓴다 (ease_out_cubic(0.999) 와 1.0 의 길이 차는 1e-9 px 수준).
const SETTLED_PROGRESS_THRESHOLD := 0.999

var _static_layer_cache: Object = PillarOrbStaticLayerCache.new()


# 로딩 프리웜: 정착 상태 분할선 베이크 (token_counts 의 각 토큰 수별 1장).
func prewarm_caches(inner_radius: float, token_counts: Array, start_angle_offset: float, scale_factor: float) -> void:
	for count_value in token_counts:
		var max_tokens: int = int(count_value)
		if max_tokens <= 1:
			continue
		var sector_angle: float = TAU / float(max_tokens)
		_static_layer_cache.build_now(
			_settled_cache_key(inner_radius, max_tokens, start_angle_offset, sector_angle, scale_factor),
			_build_settled_divider_ops(inner_radius, max_tokens, start_angle_offset, sector_angle, scale_factor)
		)


func draw(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	scale_factor: float
) -> void:
	if canvas == null or pillar_drawer == null:
		return
	if max_tokens <= 1:
		return

	# 정적 레이어: 분할선 애니메이션이 끝난 정착 상태(평상시 상태)는 베이크
	# 텍스처 blit 1회로 대체한다. 애니메이션 중에는 기존 즉시 경로 유지.
	if divider_anim_progress >= SETTLED_PROGRESS_THRESHOLD:
		var cache_key: String = _settled_cache_key(inner_radius, max_tokens, start_angle_offset, sector_angle, scale_factor)
		var cached_texture: Texture2D = _static_layer_cache.get_texture(cache_key)
		if cached_texture == null and not _static_layer_cache.is_pending(cache_key):
			cached_texture = _static_layer_cache.request_build(
				cache_key,
				_build_settled_divider_ops(inner_radius, max_tokens, start_angle_offset, sector_angle, scale_factor)
			)
		if cached_texture != null:
			_static_layer_cache.draw_centered(canvas, cached_texture, center)
			return

	var divider_progress: float = pillar_drawer.ease_out_cubic(divider_anim_progress)
	for i in range(max_tokens):
		_draw_divider_line(
			canvas,
			center,
			inner_radius,
			start_angle_offset + sector_angle * float(i),
			divider_progress,
			scale_factor
		)
	_draw_center_chrome(canvas, center, scale_factor)


func _draw_divider_line(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	divider_angle: float,
	divider_progress: float,
	scale_factor: float
) -> void:
	var current_length: float = (inner_radius - 6.0) * divider_progress
	for seg in range(12):
		var start_ratio: float = float(seg) / 12.0
		var end_ratio: float = float(seg + 1) / 12.0
		var seg_start: Vector2 = center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length * start_ratio
		var seg_end: Vector2 = center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length * end_ratio
		var thickness: float = max(1.0, 4.0 - float(seg) * 0.25)
		var gold_mix: float = 1.0 - float(seg) / 12.0
		canvas.draw_line(seg_start, seg_end, Color(0.62 + gold_mix * 0.18, 0.46 + gold_mix * 0.14, 0.20 + gold_mix * 0.10, 0.80), thickness)

	var tip_pos: Vector2 = center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length
	canvas.draw_circle(tip_pos, 3.0 * scale_factor, Color(0.82, 0.66, 0.34, 0.76))
	canvas.draw_circle(tip_pos, 2.0 * scale_factor, Color(1.0, 0.86, 0.54, 0.64))


func _draw_center_chrome(canvas: CanvasItem, center: Vector2, scale_factor: float) -> void:
	canvas.draw_circle(center, 6.0 * scale_factor, Color(0.70, 0.54, 0.24, 0.92))
	canvas.draw_circle(center, 4.0 * scale_factor, Color(0.90, 0.74, 0.40, 0.92))
	canvas.draw_circle(center, 2.0 * scale_factor, Color(1.0, 0.90, 0.66, 0.94))


func _settled_cache_key(
	inner_radius: float,
	max_tokens: int,
	start_angle_offset: float,
	sector_angle: float,
	scale_factor: float
) -> String:
	return "dividers|%.2f|%d|%.4f|%.4f|%.3f" % [
		inner_radius,
		max_tokens,
		start_angle_offset,
		sector_angle,
		scale_factor,
	]


# _draw_divider_line / _draw_center_chrome 의 progress=1.0 상태와 지오메트리
# 1:1 대응. 본문이 바뀌면 이 op 리스트도 같이 갱신해야 한다.
func _build_settled_divider_ops(
	inner_radius: float,
	max_tokens: int,
	start_angle_offset: float,
	sector_angle: float,
	scale_factor: float
) -> Array:
	var ops: Array = []
	var current_length: float = inner_radius - 6.0
	for i in range(max_tokens):
		var divider_angle: float = start_angle_offset + sector_angle * float(i)
		var direction := Vector2(cos(divider_angle), sin(divider_angle))
		for seg in range(12):
			var seg_start: Vector2 = direction * current_length * (float(seg) / 12.0)
			var seg_end: Vector2 = direction * current_length * (float(seg + 1) / 12.0)
			var thickness: float = max(1.0, 4.0 - float(seg) * 0.25)
			var gold_mix: float = 1.0 - float(seg) / 12.0
			ops.append(PillarOrbStaticLayerCache.make_line(seg_start, seg_end, thickness, Color(0.62 + gold_mix * 0.18, 0.46 + gold_mix * 0.14, 0.20 + gold_mix * 0.10, 0.80)))
		var tip_pos: Vector2 = direction * current_length
		ops.append(PillarOrbStaticLayerCache.make_circle(tip_pos, 3.0 * scale_factor, Color(0.82, 0.66, 0.34, 0.76)))
		ops.append(PillarOrbStaticLayerCache.make_circle(tip_pos, 2.0 * scale_factor, Color(1.0, 0.86, 0.54, 0.64)))
	ops.append(PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 6.0 * scale_factor, Color(0.70, 0.54, 0.24, 0.92)))
	ops.append(PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 4.0 * scale_factor, Color(0.90, 0.74, 0.40, 0.92)))
	ops.append(PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 2.0 * scale_factor, Color(1.0, 0.90, 0.66, 0.94)))
	return ops
