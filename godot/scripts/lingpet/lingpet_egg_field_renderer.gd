extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

# Shared soft-falloff halo sprite size, same convention as the in-game companion
# aura (lingpet_companion_renderer) and player state glow.
const SOFT_GLOW_TEX_SIZE := 64

const EGG_RADIUS := 28.0
const EGG_TEXTURE_DRAW_SIZE := Vector2(88.0, 88.0)
const EGG_SEMI_MAJOR := 34.0
const EGG_SEMI_MINOR := 27.0
const HATCH_FLASH_SECONDS := 0.50
const EGG_CRACK_LIGHT_MAIN_WIDTH := 2.1
const EGG_CRACK_LIGHT_GLOW_WIDTH := 6.0
# Shell-break sequence crack staging: progress ratios at which each successive
# break crack becomes visible (stage N = ratios crossed). Timing/motion live in
# lingpet_egg_field_state.advance_hatch_break; this renderer is draw-only.
const HATCH_BREAK_CRACK_STAGE_RATIOS: Array[float] = [0.14, 0.40, 0.62, 0.82]
# [path ratios (texture-rect space), width_scale, alpha_scale] per break stage.
const HATCH_BREAK_CRACK_PATHS: Array = [
	[[Vector2(0.50, 0.15), Vector2(0.46, 0.26), Vector2(0.51, 0.36), Vector2(0.45, 0.49), Vector2(0.49, 0.63)], 1.0, 1.0],
	[[Vector2(0.69, 0.24), Vector2(0.66, 0.35), Vector2(0.70, 0.48), Vector2(0.66, 0.60)], 0.8, 0.8],
	[[Vector2(0.33, 0.30), Vector2(0.37, 0.42), Vector2(0.33, 0.55), Vector2(0.38, 0.66)], 0.85, 0.85],
	[[Vector2(0.50, 0.56), Vector2(0.47, 0.68), Vector2(0.52, 0.80), Vector2(0.48, 0.88)], 0.9, 0.9],
]
const HATCH_BREAK_LIGHT_SHAFT_COUNT := 6
const HATCH_BREAK_SHARD_COUNT := 9
const HATCH_BREAK_SHARD_DISTANCE := 44.0
const HATCH_BREAK_SHARD_GRAVITY := 20.0
const EGG_BARE_VARIANT_PATHS := [
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_0_v1.png",
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_1_v1.png",
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_2_v1.png",
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_3_v1.png",
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_4_v1.png",
]
const EGG_VARIANT_GLOW := [
	Color(0.36, 0.82, 1.0),
	Color(1.0, 0.74, 0.32),
	Color(0.66, 0.50, 1.0),
	Color(1.0, 0.46, 0.64),
	Color(0.42, 0.92, 0.64),
]
# 히트 누적 금빛 도자기 균열 PNG 오버레이(수호령알 전통 디자인): 512
# 변형 캔버스와 1:1 정렬된 공유 균열 2단 — 같은 rect·같은 회전쿼드 변환을
# 지나므로 회전동기가 공짜다. 진행 코히런스: stage2 = stage1 ∪ 신규 웹
# (금은 자라기만 한다 — 재생성 시 필수 규칙). 로드 실패 시 절차 크랙 폴백.
const EGG_CRACK_STAGE_TEXTURE_PATHS := [
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_1_v1.png",
	"res://assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_2_v1.png",
]

var _variant_textures: Array = []
var _crack_stage_textures: Array = []


func prewarm() -> void:
	_variant_textures.clear()
	for path: String in EGG_BARE_VARIANT_PATHS:
		_variant_textures.append(_load_egg_texture(path))
	_crack_stage_textures.clear()
	for crack_path: String in EGG_CRACK_STAGE_TEXTURE_PATHS:
		_crack_stage_textures.append(_load_egg_texture(crack_path))


func get_variant_count() -> int:
	return EGG_BARE_VARIANT_PATHS.size()


func draw_egg(
	canvas: CanvasItem,
	center: Vector2,
	hatch_hits: int,
	required_hits: int,
	wobble_angle: float,
	variant_index: int,
	roll_angle: float = 0.0
) -> void:
	if canvas == null:
		return
	var hit_ratio: float = clampf(float(hatch_hits) / float(maxi(1, required_hits)), 0.0, 1.0)
	var pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.5
	var glow_color: Color = _get_glow_for_index(variant_index)
	# Overall halo intensity: a calm base that brightens as the egg accumulates
	# hatch hits. The organic breathing pulse now lives inside the soft-glow blit
	# (two-rate swell), so it is intentionally NOT folded into this value.
	var glow_intensity: float = 0.70 + 0.50 * hit_ratio
	_draw_soft_egg_glow(canvas, center + Vector2(0.0, 3.0), glow_color, glow_intensity)
	var final_rotation: float = roll_angle + deg_to_rad(wobble_angle)
	var visual_center: Vector2 = center + Vector2(0.0, _get_roll_bob_offset(roll_angle))
	var texture_rect := Rect2(
		visual_center - EGG_TEXTURE_DRAW_SIZE * 0.5,
		EGG_TEXTURE_DRAW_SIZE
	)
	var egg_texture: Texture2D = _get_cached_variant_texture(variant_index)
	if egg_texture != null:
		_draw_rotated_texture(canvas, egg_texture, texture_rect, final_rotation)
	_draw_egg_crack_overlay(canvas, texture_rect, hatch_hits, pulse, final_rotation)


# 히트 누적 크랙: PNG 오버레이 우선, 로드 실패 시 절차 크랙 폴백. 펄스는
# 동일 텍스처 2회 블릿(오프셋/스케일 변주 금지 — 오정렬 방지)으로 알파만
# 맥동시킨다.
func _draw_egg_crack_overlay(canvas: CanvasItem, texture_rect: Rect2, hatch_hits: int, pulse: float, rotation: float) -> void:
	if hatch_hits <= 0:
		return
	var stage_index: int = clampi(hatch_hits, 1, EGG_CRACK_STAGE_TEXTURE_PATHS.size()) - 1
	var crack_texture: Texture2D = _get_cached_crack_texture(stage_index)
	if crack_texture == null:
		_draw_egg_crack_light(canvas, texture_rect, hatch_hits, pulse, rotation)
		return
	_draw_rotated_texture(canvas, crack_texture, texture_rect, rotation)
	_draw_rotated_texture(
		canvas,
		crack_texture,
		texture_rect,
		rotation,
		Color(1.0, 1.0, 1.0, 0.18 + 0.30 * pulse)
	)


func _get_cached_crack_texture(stage_index: int) -> Texture2D:
	if EGG_CRACK_STAGE_TEXTURE_PATHS.is_empty():
		return null
	var normalized_index: int = clampi(stage_index, 0, EGG_CRACK_STAGE_TEXTURE_PATHS.size() - 1)
	if normalized_index < _crack_stage_textures.size():
		var cached_value: Variant = _crack_stage_textures[normalized_index]
		if cached_value is Texture2D:
			return cached_value as Texture2D
	var shared_cached: Texture2D = ProjectResourceLoader.get_cached_texture(EGG_CRACK_STAGE_TEXTURE_PATHS[normalized_index])
	if shared_cached != null:
		while _crack_stage_textures.size() < EGG_CRACK_STAGE_TEXTURE_PATHS.size():
			_crack_stage_textures.append(null)
		_crack_stage_textures[normalized_index] = shared_cached
	return shared_cached


func draw_profile_egg(
	canvas: CanvasItem,
	center: Vector2,
	hatch_hits: int,
	required_hits: int,
	wobble_angle: float,
	variant_index: int,
	roll_angle: float = 0.0
) -> void:
	if canvas == null:
		return
	draw_egg(canvas, center, hatch_hits, required_hits, wobble_angle, variant_index, roll_angle)


static func get_hatch_break_crack_stage(progress: float) -> int:
	var stage := 0
	for ratio: float in HATCH_BREAK_CRACK_STAGE_RATIOS:
		if progress >= ratio:
			stage += 1
	return stage


# Shell-break sequence body: the egg keeps rolling (motion scripted by the field
# state), cracks spread in stages, and light leaks through the gaps -- surging
# white-hot with radial shafts just before the shell bursts into the existing
# hatch flash / shard burst.
func draw_hatch_break_egg(
	canvas: CanvasItem,
	center: Vector2,
	progress: float,
	wobble_angle: float,
	variant_index: int,
	roll_angle: float
) -> void:
	if canvas == null:
		return
	var t: float = clampf(progress, 0.0, 1.0)
	var glow_color: Color = _get_glow_for_index(variant_index)
	# Halo surges toward the burst (ease-in) on top of the ambient premium glow.
	_draw_soft_egg_glow(canvas, center + Vector2(0.0, 3.0), glow_color, 1.0 + 2.2 * t * t)
	var final_rotation: float = roll_angle + deg_to_rad(wobble_angle)
	var visual_center: Vector2 = center + Vector2(0.0, _get_roll_bob_offset(roll_angle))
	var texture_rect := Rect2(
		visual_center - EGG_TEXTURE_DRAW_SIZE * 0.5,
		EGG_TEXTURE_DRAW_SIZE
	)
	var egg_texture: Texture2D = _get_cached_variant_texture(variant_index)
	if egg_texture != null:
		_draw_rotated_texture(canvas, egg_texture, texture_rect, final_rotation)
	# 셸브레이크 중에도 히트로 쌓인 누적 크랙(최종 단계)은 유지 드로우 —
	# 금이 사라졌다 브레이크 크랙이 새로 생기면 연출이 끊긴다.
	var accumulated_pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.5
	_draw_egg_crack_overlay(
		canvas,
		texture_rect,
		EGG_CRACK_STAGE_TEXTURE_PATHS.size(),
		accumulated_pulse,
		final_rotation
	)
	var stage: int = get_hatch_break_crack_stage(t)
	if stage <= 0:
		return
	var pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.012) * 0.5
	# Light leaking through the shell gaps brightens as the break progresses.
	var leak_alpha: float = clampf(0.42 + 0.50 * t + 0.16 * pulse, 0.0, 1.0)
	for crack_index in range(mini(stage, HATCH_BREAK_CRACK_PATHS.size())):
		var crack_spec: Array = HATCH_BREAK_CRACK_PATHS[crack_index]
		var path_ratios: Array[Vector2] = []
		for ratio_point: Vector2 in (crack_spec[0] as Array):
			path_ratios.append(ratio_point)
		_draw_egg_crack_light_path(
			canvas,
			texture_rect,
			path_ratios,
			leak_alpha * float(crack_spec[2]),
			float(crack_spec[1]),
			final_rotation
		)
	_draw_hatch_break_light_shafts(canvas, visual_center, t, pulse, final_rotation)


# Final pre-burst beat: radial light shafts escaping between the shell pieces
# plus a white core charging up. Anchored to the egg's rotation so the rays
# read as light through fixed gaps, not a detached halo.
func _draw_hatch_break_light_shafts(
	canvas: CanvasItem,
	visual_center: Vector2,
	progress: float,
	pulse: float,
	rotation: float
) -> void:
	var shaft_start: float = HATCH_BREAK_CRACK_STAGE_RATIOS[HATCH_BREAK_CRACK_STAGE_RATIOS.size() - 1]
	if progress < shaft_start:
		return
	var strength: float = clampf((progress - shaft_start) / maxf(0.001, 1.0 - shaft_start), 0.0, 1.0)
	for i in range(HATCH_BREAK_LIGHT_SHAFT_COUNT):
		var angle: float = rotation + TAU * float(i) / float(HATCH_BREAK_LIGHT_SHAFT_COUNT) + 0.35 * sin(float(i) * 2.7)
		var dir := Vector2(cos(angle), sin(angle))
		var inner: float = EGG_SEMI_MINOR * 0.55
		var outer: float = EGG_SEMI_MAJOR + lerpf(10.0, 26.0, strength) * (0.75 + 0.25 * pulse)
		var shaft_alpha: float = (0.14 + 0.30 * strength) * (0.70 + 0.30 * pulse)
		canvas.draw_line(
			visual_center + dir * inner,
			visual_center + dir * outer,
			Color(1.0, 0.98, 0.88, shaft_alpha),
			2.4,
			true
		)
		canvas.draw_line(
			visual_center + dir * inner,
			visual_center + dir * (inner + (outer - inner) * 0.6),
			Color(1.0, 1.0, 1.0, shaft_alpha * 0.8),
			1.0,
			true
		)
	# White core charging up right before the burst.
	var core_ramp: float = clampf((progress - 0.90) / 0.10, 0.0, 1.0)
	if core_ramp > 0.0:
		canvas.draw_circle(
			visual_center,
			lerpf(6.0, 20.0, core_ramp),
			Color(1.0, 1.0, 0.97, 0.16 + 0.30 * core_ramp)
		)


func draw_hatch_flash(canvas: CanvasItem, center: Vector2, hatch_flash_timer: float, variant_index: int = -1) -> void:
	if canvas == null:
		return
	var glow: Color = _get_glow_for_index(variant_index)
	var t: float = clampf(hatch_flash_timer / HATCH_FLASH_SECONDS, 0.0, 1.0)
	_draw_hatch_shell_burst(canvas, center, t, variant_index)
	var radius: float = lerpf(18.0, 74.0, 1.0 - t)
	canvas.draw_circle(center, radius, Color(glow.r, glow.g, glow.b, 0.24 * t))
	canvas.draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(0.44, 1.0, 1.0, 0.58 * t), 3.0, true)


func _load_egg_texture(path: String) -> Texture2D:
	return ProjectResourceLoader.load_imported_texture(
		path,
		"[LingpetEggFieldRenderer] missing resonance egg texture: %s",
		"[LingpetEggFieldRenderer] failed to load resonance egg texture: %s"
	)


func _get_cached_variant_texture(index: int) -> Texture2D:
	if EGG_BARE_VARIANT_PATHS.is_empty():
		return null
	var normalized_index: int = _normalize_variant_index(index)
	if normalized_index < _variant_textures.size():
		var cached_value: Variant = _variant_textures[normalized_index]
		if cached_value is Texture2D:
			return cached_value as Texture2D
	var shared_cached: Texture2D = ProjectResourceLoader.get_cached_texture(EGG_BARE_VARIANT_PATHS[normalized_index])
	if shared_cached != null:
		while _variant_textures.size() < get_variant_count():
			_variant_textures.append(null)
		_variant_textures[normalized_index] = shared_cached
	return shared_cached


func _get_glow_for_index(index: int) -> Color:
	if EGG_VARIANT_GLOW.is_empty():
		return Color.WHITE
	var normalized_index: int = _normalize_variant_index(index)
	if normalized_index >= EGG_VARIANT_GLOW.size():
		return EGG_VARIANT_GLOW[0]
	return EGG_VARIANT_GLOW[normalized_index]


func _normalize_variant_index(index: int) -> int:
	var variant_count: int = get_variant_count()
	if index >= 0 and index < variant_count:
		return index
	return 0


# Premium installed-egg halo. Upgraded from a hard stacked-disc ring to the same
# cos^2 feathered soft-glow recipe the in-game companion aura uses
# (lingpet_companion_renderer._draw_soft_aura): three fully-overlapping blits of
# the shared radial-falloff sprite (outer rim / mid body / whiter core) driven by
# a two-rate organic breathing pulse, so the light falls off smoothly well past
# the shell instead of reading as a flat saturated disc. `intensity` is the
# hatch-progress brightness multiplier from draw_egg; the pulse is internal.
func _draw_soft_egg_glow(canvas: CanvasItem, glow_center: Vector2, glow_color: Color, intensity: float) -> void:
	if intensity <= 0.001:
		return
	var tex: Texture2D = SoftGlowTexture.get_texture(SOFT_GLOW_TEX_SIZE)
	if tex == null:
		return
	var now_ms: float = float(Time.get_ticks_msec())
	# Two-rate breathing: slow primary swell mixed with a gentler faster shimmer so
	# the pulse never reads as one mechanical sine (matches the companion aura).
	var breath_slow: float = 0.5 + 0.5 * sin(now_ms * 0.00082)
	var breath_fast: float = 0.5 + 0.5 * sin(now_ms * 0.0021 + 1.3)
	var breath: float = lerpf(breath_slow, breath_fast, 0.32)
	# Layers sized off the visible shell extent, feathered outward. The rim/mid keep
	# the variant pastel hue; the core lerps whiter so it reads as light with
	# substance hugging the shell rather than a colored patch.
	var pastel: Color = glow_color.lerp(Color.WHITE, 0.45)
	var core_tint: Color = glow_color.lerp(Color.WHITE, 0.66)
	var body_r: float = EGG_RADIUS + 12.0
	var core_r: float = body_r + lerpf(11.0, 15.0, breath)
	var core_a: float = clampf(lerpf(0.18, 0.24, breath) * intensity, 0.0, 1.0)
	var mid_r: float = body_r + lerpf(22.0, 28.0, breath)
	var mid_a: float = clampf(lerpf(0.115, 0.150, breath) * intensity, 0.0, 1.0)
	var outer_r: float = body_r + lerpf(35.0, 44.0, breath)
	var outer_a: float = clampf(lerpf(0.060, 0.088, breath) * intensity, 0.0, 1.0)
	_blit_soft_egg_glow(canvas, tex, glow_center, outer_r, Color(pastel.r, pastel.g, pastel.b, outer_a))
	_blit_soft_egg_glow(canvas, tex, glow_center, mid_r, Color(pastel.r, pastel.g, pastel.b, mid_a))
	_blit_soft_egg_glow(canvas, tex, glow_center, core_r, Color(core_tint.r, core_tint.g, core_tint.b, core_a))


func _blit_soft_egg_glow(canvas: CanvasItem, tex: Texture2D, center: Vector2, glow_radius: float, color: Color) -> void:
	if color.a <= 0.001:
		return
	var r: float = maxf(1.0, glow_radius)
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)


func _get_roll_bob_offset(roll_angle: float) -> float:
	var contact_height: float = sqrt(
		pow(EGG_SEMI_MAJOR * cos(roll_angle), 2.0)
		+ pow(EGG_SEMI_MINOR * sin(roll_angle), 2.0)
	)
	return EGG_SEMI_MAJOR - contact_height


func _draw_rotated_texture(canvas: CanvasItem, texture: Texture2D, texture_rect: Rect2, rotation: float, modulate: Color = Color.WHITE) -> void:
	var points: PackedVector2Array = _build_rotated_rect_points(texture_rect, rotation)
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_polygon(points, colors, uvs, texture)


func _build_rotated_rect_points(texture_rect: Rect2, rotation: float) -> PackedVector2Array:
	var center: Vector2 = texture_rect.get_center()
	var corners: Array[Vector2] = [
		texture_rect.position,
		texture_rect.position + Vector2(texture_rect.size.x, 0.0),
		texture_rect.position + texture_rect.size,
		texture_rect.position + Vector2(0.0, texture_rect.size.y),
	]
	var points := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(center + (corner - center).rotated(rotation))
	return points


func build_crack_light_points_for_tests(texture_rect: Rect2, path_ratios: Array[Vector2], rotation: float = 0.0) -> PackedVector2Array:
	return _build_egg_crack_light_points(texture_rect, path_ratios, rotation)


func _build_egg_crack_light_points(texture_rect: Rect2, path_ratios: Array[Vector2], rotation: float) -> PackedVector2Array:
	var center: Vector2 = texture_rect.get_center()
	var points := PackedVector2Array()
	for ratio: Vector2 in path_ratios:
		var point: Vector2 = texture_rect.position + Vector2(texture_rect.size.x * ratio.x, texture_rect.size.y * ratio.y)
		points.append(center + (point - center).rotated(rotation))
	return points


func _draw_egg_crack_light(canvas: CanvasItem, texture_rect: Rect2, hatch_hits: int, pulse: float, rotation: float) -> void:
	if hatch_hits <= 0:
		return
	var stage_boost: float = clampf(float(hatch_hits - 1) * 0.22, 0.0, 0.34)
	var leak_alpha: float = clampf(0.46 + 0.24 * pulse + stage_boost, 0.0, 0.92)
	var main_crack: Array[Vector2] = [
		Vector2(0.50, 0.15),
		Vector2(0.46, 0.26),
		Vector2(0.51, 0.36),
		Vector2(0.45, 0.49),
		Vector2(0.49, 0.63),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, main_crack, leak_alpha, 1.0, rotation)
	var side_crack: Array[Vector2] = [
		Vector2(0.69, 0.24),
		Vector2(0.66, 0.35),
		Vector2(0.70, 0.48),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, side_crack, leak_alpha * 0.72, 0.74, rotation)
	if hatch_hits >= 2:
		var lower_crack: Array[Vector2] = [
			Vector2(0.50, 0.56),
			Vector2(0.47, 0.68),
			Vector2(0.52, 0.80),
		]
		_draw_egg_crack_light_path(canvas, texture_rect, lower_crack, leak_alpha * 0.82, 0.86, rotation)


func _draw_egg_crack_light_path(
	canvas: CanvasItem,
	texture_rect: Rect2,
	path_ratios: Array[Vector2],
	alpha: float,
	width_scale: float,
	rotation: float
) -> void:
	if path_ratios.size() < 2:
		return
	var points: PackedVector2Array = _build_egg_crack_light_points(texture_rect, path_ratios, rotation)
	var glow_width: float = EGG_CRACK_LIGHT_GLOW_WIDTH * width_scale
	var core_width: float = EGG_CRACK_LIGHT_MAIN_WIDTH * width_scale
	canvas.draw_polyline(points, Color(0.20, 1.0, 1.0, 0.20 * alpha), glow_width, true)
	canvas.draw_polyline(points, Color(1.0, 0.92, 0.36, 0.50 * alpha), core_width, true)
	canvas.draw_polyline(points, Color(1.0, 1.0, 0.86, 0.82 * alpha), maxf(0.75, core_width * 0.38), true)
	for i in range(points.size()):
		if i % 2 == 0:
			canvas.draw_circle(points[i], maxf(1.0, core_width * 0.44), Color(0.78, 1.0, 1.0, 0.34 * alpha))


func _draw_hatch_shell_burst(canvas: CanvasItem, center: Vector2, timer_ratio: float, variant_index: int = -1) -> void:
	var burst_progress: float = clampf(1.0 - timer_ratio, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - burst_progress, 2.0)
	var fade: float = clampf(timer_ratio * 1.18, 0.0, 1.0)
	var glow: Color = _get_glow_for_index(variant_index)
	var egg_center: Vector2 = center + Vector2(0.0, -EGG_TEXTURE_DRAW_SIZE.y * 0.06)
	for i in range(HATCH_BREAK_SHARD_COUNT):
		var unit: float = float(i) / float(HATCH_BREAK_SHARD_COUNT)
		var angle: float = -PI * 0.92 + unit * PI * 1.84
		var drift: float = sin(float(i) * 2.17) * 0.18
		var dir := Vector2(cos(angle + drift), sin(angle + drift))
		var travel: float = HATCH_BREAK_SHARD_DISTANCE * (0.45 + 0.55 * _hatch_shard_unit(i + 2)) * eased
		var gravity := Vector2(0.0, HATCH_BREAK_SHARD_GRAVITY * burst_progress * burst_progress)
		var shard_center: Vector2 = egg_center + dir * travel + gravity
		var size: float = lerpf(8.5, 4.0, burst_progress) * (0.78 + 0.34 * _hatch_shard_unit(i + 11))
		var rotation: float = angle + burst_progress * lerpf(-1.7, 1.7, _hatch_shard_unit(i + 19))
		# Shards are the breaking shell, so they carry the egg's own variant tone
		# (lerped toward white for shell brightness) instead of a fixed pink palette.
		var shell_color: Color = glow.lerp(Color.WHITE, 0.25)
		shell_color.a = 0.82 * fade
		if i % 3 == 1:
			shell_color = glow.lerp(Color.WHITE, 0.55)
			shell_color.a = 0.74 * fade
		elif i % 3 == 2:
			shell_color = glow.lerp(Color.WHITE, 0.82)
			shell_color.a = 0.78 * fade
		_draw_hatch_shell_shard(canvas, shard_center, size, rotation, shell_color, fade)
		if i % 2 == 0:
			var sparkle_pos: Vector2 = egg_center + dir * (travel + 8.0)
			canvas.draw_circle(sparkle_pos, maxf(1.0, size * 0.22), Color(0.92, 1.0, 1.0, 0.58 * fade))


func _draw_hatch_shell_shard(canvas: CanvasItem, center: Vector2, size: float, rotation: float, fill_color: Color, fade: float) -> void:
	var points := PackedVector2Array()
	var local_points := [
		Vector2(-0.68, 0.46),
		Vector2(-0.18, -0.72),
		Vector2(0.70, -0.22),
		Vector2(0.32, 0.64),
	]
	for local: Vector2 in local_points:
		points.append(center + local.rotated(rotation) * size)
	canvas.draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array()
	for point: Vector2 in points:
		outline.append(point)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(0.18, 0.11, 0.24, 0.36 * fade), 1.0, true)


func _hatch_shard_unit(index: int) -> float:
	var shard_seed: int = int((index * 1103515245 + 12345) % 10000)
	return float(shard_seed) / 10000.0
