extends RefCounted
## 대성영단 시네마틱 드로우 헬퍼 (호환 ID: elixir_of_mastery)
## ElixirOfMasteryRuntime.get_draw_context()를 받아 _draw() 호출 시 렌더링

const ElixirRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const RUNE_RING_OUTER_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_rune_ring_outer_imagegen_v1.png"
const RUNE_RING_INNER_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_rune_ring_inner_imagegen_v1.png"
const GLOW_BACKPLATE_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_glow_backplate_imagegen_v2.png"
const PILL_FURNACE_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_pill_furnace_imagegen_v1.png"
const GLORY_RAYS_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_glory_rays_imagegen_v1.png"
const ICON_SEAL_FRAME_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_icon_seal_frame_imagegen_v1.png"
const GEUKSEONG_SEAL_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_geukseong_seal_imagegen_v1.png"
const CONFETTI_FLAKES_TEXTURE_PATH := "res://assets/sprites/effects/daeseong_yeongdan/daeseong_confetti_flakes_imagegen_v1.png"
# BUILDUP layer contract (bottom -> top): overlay -> baked glow (MIX) -> outer
# rune ring -> counter-rotating inner ring -> procedural rising energy motes ->
# solid pill/furnace art -> text/flash. Immediate CanvasItem material swaps are
# intentionally avoided; the glow's light budget is baked into its PNG.
const BUILDUP_TEXTURE_SPECS := [
	{
		"key": "glow_backplate",
		"path": GLOW_BACKPLATE_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(512, 512),
	},
	{
		"key": "rune_ring_outer",
		"path": RUNE_RING_OUTER_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(512, 512),
	},
	{
		"key": "rune_ring_inner",
		"path": RUNE_RING_INNER_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(512, 512),
	},
	{
		"key": "pill_furnace",
		"path": PILL_FURNACE_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(256, 256),
	},
]

# REVEAL/CELEBRATION layer contract (bottom -> top): reused low-alpha rune
# ring -> procedural shockwaves -> painted glory rays -> reused baked glow ->
# ornate icon frame -> shared production Mugong icon -> red Geukseong seal +
# runtime text -> procedural fireworks -> textured gold/crimson flakes -> banner.
# The shared ring/glow receive result-local cache keys so an incomplete result
# set falls back without disabling a fully prepared BUILDUP set.
const RESULT_TEXTURE_SPECS := [
	{
		"key": "result_rune_ring_outer",
		"path": RUNE_RING_OUTER_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(512, 512),
	},
	{
		"key": "result_glow_backplate",
		"path": GLOW_BACKPLATE_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(512, 512),
	},
	{
		"key": "glory_rays",
		"path": GLORY_RAYS_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(512, 512),
	},
	{
		"key": "icon_seal_frame",
		"path": ICON_SEAL_FRAME_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(256, 256),
	},
	{
		"key": "geukseong_seal",
		"path": GEUKSEONG_SEAL_TEXTURE_PATH,
		"source_size": Vector2i(1024, 1024),
		"runtime_size": Vector2i(128, 128),
	},
	{
		"key": "confetti_flakes",
		"path": CONFETTI_FLAKES_TEXTURE_PATH,
		"source_size": Vector2i(512, 512),
		"runtime_size": Vector2i(128, 128),
	},
]

const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.78)
const PILL_OUTLINE_COLOR := Color(0.16, 0.06, 0.02)
const PILL_DARK_COLOR := Color(0.74, 0.35, 0.04)
const PILL_GOLD_COLOR := Color(0.96, 0.65, 0.10)
const PILL_HIGHLIGHT_COLOR := Color(1.0, 0.93, 0.56)
const PILL_SEAL_COLOR := Color(0.72, 0.08, 0.04)
const CASKET_COLOR := Color(0.42, 0.04, 0.02)
const CASKET_EDGE_COLOR := Color(0.88, 0.16, 0.06)
const TITLE_COLOR := Color(1.0, 0.82, 0.22)
const SUBTITLE_COLOR := Color(1.0, 0.91, 0.66)
const FRAME_BG_COLOR := Color(0.12, 0.035, 0.015, 0.88)
const FRAME_OUTER_COLOR := Color(0.84, 0.16, 0.06)
const FRAME_INNER_COLOR := Color(1.0, 0.76, 0.16)
const LEVEL_COLOR := Color(1.0, 0.72, 0.16)
const HINT_COLOR := Color(1.0, 0.88, 0.62)

var _buildup_textures: Dictionary = {}
var _result_textures: Dictionary = {}
var _prewarm_step_index := 0
var _assets_prewarmed := false


func get_buildup_texture_specs() -> Array:
	return BUILDUP_TEXTURE_SPECS.duplicate(true)


func get_result_texture_specs() -> Array:
	return RESULT_TEXTURE_SPECS.duplicate(true)


func prewarm_assets_step() -> bool:
	if _assets_prewarmed:
		return true
	var buildup_spec_count := BUILDUP_TEXTURE_SPECS.size()
	var total_spec_count := buildup_spec_count + RESULT_TEXTURE_SPECS.size()
	if _prewarm_step_index >= total_spec_count:
		_assets_prewarmed = true
		_prewarm_step_index = 0
		return true
	var is_result_spec := _prewarm_step_index >= buildup_spec_count
	var spec_index := _prewarm_step_index - buildup_spec_count if is_result_spec else _prewarm_step_index
	var spec: Dictionary = RESULT_TEXTURE_SPECS[spec_index] if is_result_spec else BUILDUP_TEXTURE_SPECS[spec_index]
	var path: String = str(spec.get("path", ""))
	var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"Missing Daeseong Yeongdan cinematic texture: %s",
		"Failed to load Daeseong Yeongdan cinematic texture: %s",
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
		false,
		true
	)
	if not bool(result.get("done", true)):
		return false
	var texture: Variant = result.get("texture", null)
	var key: String = str(spec.get("key", ""))
	var target_cache: Dictionary = _result_textures if is_result_spec else _buildup_textures
	if texture is Texture2D:
		target_cache[key] = texture
	else:
		target_cache.erase(key)
	_prewarm_step_index += 1
	return false


func is_textured_buildup_ready() -> bool:
	for spec_value in BUILDUP_TEXTURE_SPECS:
		var spec: Dictionary = spec_value if spec_value is Dictionary else {}
		var texture: Variant = _buildup_textures.get(str(spec.get("key", "")), null)
		if not (texture is Texture2D):
			return false
	return true


func is_textured_result_ready() -> bool:
	for spec_value in RESULT_TEXTURE_SPECS:
		var spec: Dictionary = spec_value if spec_value is Dictionary else {}
		var texture: Variant = _result_textures.get(str(spec.get("key", "")), null)
		if not (texture is Texture2D):
			return false
	return true


func set_buildup_textures_for_tests(textures: Dictionary) -> void:
	_buildup_textures = textures.duplicate()
	_assets_prewarmed = true
	_prewarm_step_index = 0


func set_result_textures_for_tests(textures: Dictionary) -> void:
	_result_textures = textures.duplicate()
	_assets_prewarmed = true
	_prewarm_step_index = 0


static func compute_buildup_convergence_scale(progress: float) -> float:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	return lerpf(1.08, 0.72, clamped_progress * clamped_progress * clamped_progress)


func draw_cinematic(
	canvas: CanvasItem,
	ctx: Dictionary,
	view_size: Vector2,
	perk_icon_renderer: Object = null
) -> void:
	if not bool(ctx.get("active", false)):
		return

	var cx: float = view_size.x * 0.5
	var cy: float = view_size.y * 0.5

	# 어두운 오버레이
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), OVERLAY_COLOR)

	var phase: int = int(ctx.get("phase", 0))
	match phase:
		ElixirRuntime.Phase.BUILDUP:
			_draw_buildup(canvas, ctx, cx, cy, view_size)
		ElixirRuntime.Phase.REVEAL, ElixirRuntime.Phase.CELEBRATION:
			_draw_result(canvas, ctx, cx, cy, view_size, perk_icon_renderer)

	# 플래시 효과
	var flash_a: float = float(ctx.get("flash_alpha", 0.0))
	if flash_a > 0.01:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 1.0, 1.0, minf(1.0, flash_a)))


@warning_ignore("unused_parameter")
func _draw_buildup(canvas: CanvasItem, ctx: Dictionary, cx: float, cy: float, view_size: Vector2) -> void:
	var timer: float = float(ctx.get("timer", 0.0))
	var progress: float = minf(1.0, timer / ElixirRuntime.BUILDUP_DURATION)
	if is_textured_buildup_ready():
		_draw_textured_buildup(canvas, ctx, Vector2(cx, cy), timer, progress)
		_draw_buildup_text(canvas, cx, cy, progress, 205.0)
		return

	# 텍스처를 사용할 수 없을 때만 유지되는 결정론적 절차 폴백.
	var rune_circles: Array = ctx.get("rune_circles", []) if ctx.get("rune_circles") is Array else []
	for rc in rune_circles:
		var alpha: float = float(rc.get("alpha", 0.5)) * (0.5 + 0.5 * sin(timer * 2.0))
		var r: float = float(rc.get("radius", 100.0)) * (1.0 - progress * 0.3)
		var segments: int = int(rc.get("segments", 6))
		var rot: float = float(rc.get("rotation", 0.0))
		var color := Color(0.93, 0.61, 0.12, alpha)
		for i in range(segments):
			var angle1: float = rot + (TAU * float(i) / float(segments))
			var angle2: float = rot + (TAU * (float(i) + 0.7) / float(segments))
			var p1 := Vector2(cx + r * cos(angle1), cy + r * sin(angle1))
			var p2 := Vector2(cx + r * cos(angle2), cy + r * sin(angle2))
			canvas.draw_line(p1, p2, color, 2.0)
			canvas.draw_circle(p1, 3.0, Color(0.84, 0.16, 0.06, alpha))

	# 금빛 내공 입자
	var particles: Array = ctx.get("particles", []) if ctx.get("particles") is Array else []
	for p in particles:
		var dist: float = float(p.get("dist", 100.0))
		var angle: float = float(p.get("angle", 0.0))
		var px: float = cx + dist * cos(angle)
		var py: float = cy + dist * sin(angle) - float(p.get("rise", 0.0))
		var pulse: float = 0.5 + 0.5 * sin(timer * 4.0 + float(p.get("phase_offset", 0.0)))
		var size: float = maxf(1.0, float(p.get("size", 3.0)) * pulse)
		var p_color: Color = p.get("color", Color.WHITE) if p.get("color") is Color else Color.WHITE
		p_color.a = float(p.get("alpha", 0.8)) * pulse
		canvas.draw_circle(Vector2(px, py), size, p_color)

	# 중앙 영단 글로우
	var glow_r: float = 80.0 + 40.0 * sin(timer * 3.0)
	var glow_alpha: float = (100.0 + 50.0 * progress) / 255.0
	canvas.draw_circle(Vector2(cx, cy), glow_r, Color(0.93, 0.41, 0.06, glow_alpha * 0.35))
	canvas.draw_circle(Vector2(cx, cy), glow_r * 0.5, Color(1.0, 0.78, 0.20, glow_alpha * 0.68))

	# 호환 draw context의 bottle_scale/rotation 값을 영단 호흡과 인장 회전에 재사용한다.
	var pill_scale: float = float(ctx.get("bottle_scale", 1.0))
	var pill_center := Vector2(cx, cy - 10.0 * pill_scale)
	var pill_radius: float = 29.0 * pill_scale
	var casket_rect := Rect2(
		cx - 36.0 * pill_scale,
		cy + 23.0 * pill_scale,
		72.0 * pill_scale,
		22.0 * pill_scale
	)
	canvas.draw_rect(casket_rect.grow(3.0 * pill_scale), PILL_OUTLINE_COLOR)
	canvas.draw_rect(casket_rect, CASKET_COLOR)
	canvas.draw_line(
		Vector2(casket_rect.position.x, casket_rect.position.y + 5.0 * pill_scale),
		Vector2(casket_rect.end.x, casket_rect.position.y + 5.0 * pill_scale),
		CASKET_EDGE_COLOR,
		3.0 * pill_scale
	)
	canvas.draw_line(
		Vector2(cx - 14.0 * pill_scale, casket_rect.end.y - 4.0 * pill_scale),
		Vector2(cx + 14.0 * pill_scale, casket_rect.end.y - 4.0 * pill_scale),
		Color(1.0, 0.65, 0.12),
		2.0 * pill_scale
	)
	canvas.draw_circle(pill_center, pill_radius + 3.0 * pill_scale, PILL_OUTLINE_COLOR)
	canvas.draw_circle(pill_center, pill_radius, PILL_DARK_COLOR)
	canvas.draw_circle(pill_center + Vector2(-2.0, -3.0) * pill_scale, pill_radius * 0.88, PILL_GOLD_COLOR)
	canvas.draw_circle(pill_center + Vector2(-8.0, -10.0) * pill_scale, 6.0 * pill_scale, PILL_HIGHLIGHT_COLOR)
	var seal_rotation := deg_to_rad(float(ctx.get("bottle_rotation", 0.0)) * 0.22)
	canvas.draw_circle(pill_center, 4.0 * pill_scale, PILL_SEAL_COLOR)
	for i in range(6):
		var seal_angle: float = seal_rotation + TAU * float(i) / 6.0
		var seal_inner := pill_center + Vector2.from_angle(seal_angle) * 7.0 * pill_scale
		var seal_outer := pill_center + Vector2.from_angle(seal_angle) * 17.0 * pill_scale
		canvas.draw_line(seal_inner, seal_outer, PILL_SEAL_COLOR, 2.5 * pill_scale)

	_draw_buildup_text(canvas, cx, cy, progress)


func _draw_textured_buildup(
	canvas: CanvasItem,
	ctx: Dictionary,
	center: Vector2,
	timer: float,
	progress: float
) -> void:
	var climax: float = smoothstep(0.78, 1.0, progress)
	var accelerated_phase: float = timer * (1.8 + 5.8 * progress * progress)
	var end_pulse: float = 0.5 + 0.5 * sin(accelerated_phase)
	var glow_alpha: float = clampf(
		lerpf(0.18, 0.82, pow(progress, 0.72)) * lerpf(0.92, 1.24, climax * end_pulse),
		0.0,
		1.0
	)
	var glow_scale: float = lerpf(0.72, 1.08, pow(progress, 0.82)) * (1.0 + 0.055 * climax * end_pulse)
	_draw_rotated_texture(
		canvas,
		_get_buildup_texture("glow_backplate"),
		center,
		Vector2.ONE * 282.0 * glow_scale,
		0.0,
		glow_alpha
	)

	# 마지막 0.5초에 수렴 가속이 가장 크게 보이는 cubic ease-in.
	var convergence_scale: float = compute_buildup_convergence_scale(progress)
	var ring_alpha: float = clampf(progress / 0.22, 0.0, 1.0) * lerpf(0.68, 1.0, progress)
	var rune_circles: Array = ctx.get("rune_circles", []) if ctx.get("rune_circles") is Array else []
	var outer_rotation: float = _get_rune_rotation(rune_circles, 2, timer * 0.45)
	var inner_rotation: float = _get_rune_rotation(rune_circles, 1, -timer * 0.62)
	_draw_rotated_texture(
		canvas,
		_get_buildup_texture("rune_ring_outer"),
		center,
		Vector2.ONE * 380.0 * convergence_scale,
		outer_rotation,
		ring_alpha
	)
	_draw_rotated_texture(
		canvas,
		_get_buildup_texture("rune_ring_inner"),
		center,
		Vector2.ONE * 272.0 * convergence_scale,
		inner_rotation,
		ring_alpha * 0.88
	)

	_draw_buildup_particles(canvas, ctx, center, timer)

	var pill_scale: float = clampf(float(ctx.get("bottle_scale", 1.0)), 0.82, 1.18)
	var pill_alpha: float = clampf(progress / 0.16, 0.0, 1.0)
	_draw_rotated_texture(
		canvas,
		_get_buildup_texture("pill_furnace"),
		center + Vector2(0.0, 3.0),
		Vector2.ONE * 154.0 * pill_scale,
		0.0,
		pill_alpha
	)


func _draw_buildup_particles(canvas: CanvasItem, ctx: Dictionary, center: Vector2, timer: float) -> void:
	var particles: Array = ctx.get("particles", []) if ctx.get("particles") is Array else []
	for p in particles:
		var dist: float = float(p.get("dist", 100.0))
		var angle: float = float(p.get("angle", 0.0))
		var particle_pos := center + Vector2.from_angle(angle) * dist
		particle_pos.y -= float(p.get("rise", 0.0))
		var pulse: float = 0.5 + 0.5 * sin(timer * 4.0 + float(p.get("phase_offset", 0.0)))
		var size: float = maxf(1.0, float(p.get("size", 3.0)) * pulse)
		var p_color: Color = p.get("color", Color.WHITE) if p.get("color") is Color else Color.WHITE
		p_color.a = float(p.get("alpha", 0.8)) * pulse
		canvas.draw_circle(particle_pos, size, p_color)


func _draw_buildup_text(
	canvas: CanvasItem,
	cx: float,
	cy: float,
	progress: float,
	title_offset_y: float = 100.0
) -> void:
	if progress > 0.3:
		var text_alpha: float = minf(1.0, (progress - 0.3) * 2.5)
		var title_pos := Vector2(cx, cy + title_offset_y)
		_draw_centered_text(canvas, LanguageSettings.translate_text("대성영단"), title_pos, 28, Color(TITLE_COLOR, text_alpha))

	if progress > 0.5:
		var sub_alpha: float = minf(0.8, (progress - 0.5) * 2.0)
		var sub_pos := Vector2(cx, cy + title_offset_y + 35.0)
		_draw_centered_text(canvas, LanguageSettings.translate_text("무공의 극성을 깨웁니다..."), sub_pos, 16, Color(SUBTITLE_COLOR, sub_alpha))


func _draw_rotated_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	size: Vector2,
	rotation: float,
	alpha: float
) -> void:
	if texture == null or alpha <= 0.001:
		return
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	canvas.draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	size: Vector2,
	source_rect: Rect2,
	rotation: float,
	alpha: float
) -> void:
	if texture == null or alpha <= 0.001:
		return
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(-size * 0.5, size),
		source_rect,
		Color(1.0, 1.0, 1.0, alpha)
	)
	# Each flake restores immediately so the next particle never inherits the
	# previous particle's transform, even when a later draw branch returns.
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_buildup_texture(key: String) -> Texture2D:
	var value: Variant = _buildup_textures.get(key, null)
	return value as Texture2D if value is Texture2D else null


func _get_result_texture(key: String) -> Texture2D:
	var value: Variant = _result_textures.get(key, null)
	return value as Texture2D if value is Texture2D else null


func _get_rune_rotation(rune_circles: Array, index: int, fallback: float) -> float:
	if index >= 0 and index < rune_circles.size() and rune_circles[index] is Dictionary:
		return float((rune_circles[index] as Dictionary).get("rotation", fallback))
	return fallback


func _draw_result(
	canvas: CanvasItem,
	ctx: Dictionary,
	cx: float,
	cy: float,
	view_size: Vector2,
	perk_icon_renderer: Object = null
) -> void:
	var result_a: float = float(ctx.get("result_alpha", 0.0))
	var celebration: bool = bool(ctx.get("celebration_triggered", false))
	var cel_timer: float = float(ctx.get("celebration_timer", 0.0))
	var textured_result := is_textured_result_ready()

	# 스파클
	var sparkles: Array = ctx.get("sparkles", []) if ctx.get("sparkles") is Array else []
	for s in sparkles:
		var life_ratio: float = maxf(0.0, float(s.get("life", 0.0)) / maxf(0.01, float(s.get("max_life", 3.0))))
		var size: float = maxf(1.0, float(s.get("size", 3.0)) * life_ratio)
		var sx: float = cx + float(s.get("x", 0.0))
		var sy: float = cy + float(s.get("y", 0.0))
		var s_color: Color = s.get("color", Color.WHITE) if s.get("color") is Color else Color.WHITE
		s_color.a = life_ratio
		canvas.draw_circle(Vector2(sx, sy), size, s_color)

	var selected_data: Dictionary = ctx.get("selected_perk_data", {}) if ctx.get("selected_perk_data") is Dictionary else {}
	if selected_data.is_empty():
		return

	var icon_center := Vector2(cx, cy - 30.0)

	# 결과 프레임
	var frame_size: float = 120.0
	var frame_x: float = cx - frame_size * 0.5
	var frame_y: float = icon_center.y - frame_size * 0.5
	var frame_rect := Rect2(frame_x, frame_y, frame_size, frame_size)

	# 결과 전용 준비 게이트가 닫히면 BUILDUP 준비 상태와 무관하게 이 화면만
	# 기존 절차 폴백을 사용한다. 핫패스에서는 파일 검사나 로드를 하지 않는다.
	if textured_result:
		_draw_textured_result_ritual_backdrop(canvas, icon_center, ctx, result_a)
	if celebration:
		_draw_shockwaves(canvas, cx, icon_center.y, ctx)
		if textured_result:
			_draw_textured_glory_rays(canvas, icon_center, ctx, result_a)
		else:
			_draw_radial_rays(canvas, cx, icon_center.y, ctx)

	if textured_result:
		_draw_textured_result_icon_layers(canvas, icon_center, cel_timer, result_a)
	else:
		# 결과 텍스처가 하나라도 빠졌을 때만 유지되는 절차 글로우/프레임.
		if result_a > 0.1:
			var glow_r: float = frame_size * 0.5 + 20.0
			canvas.draw_circle(icon_center, glow_r, Color(0.84, 0.16, 0.06, 0.24 * result_a))
			canvas.draw_circle(icon_center, glow_r * 0.75, Color(0.95, 0.61, 0.10, 0.35 * result_a))
			canvas.draw_circle(icon_center, glow_r * 0.5, Color(1.0, 1.0, 1.0, 0.4 * result_a))
		canvas.draw_rect(frame_rect, Color(FRAME_BG_COLOR, FRAME_BG_COLOR.a * result_a))
		canvas.draw_rect(frame_rect, Color(FRAME_OUTER_COLOR, result_a), false, 3.0)
		canvas.draw_rect(frame_rect.grow(-3.0), Color(FRAME_INNER_COLOR, result_a * 0.8), false, 2.0)

	# 선택된 무공 ID를 공용 아이콘 렌더러에 넘긴다. 결과 화면만 별도의
	# 첫 글자 임시 아이콘을 그리면 TAB/선택 카드와 무공 정체성이 어긋난다.
	if result_a > 0.2:
		var selected_perk_id: String = str(ctx.get("selected_perk_id", ""))
		var icon_size := 82.0
		var icon_rect := Rect2(
			icon_center - Vector2.ONE * icon_size * 0.5,
			Vector2.ONE * icon_size
		)
		if not _draw_linked_perk_icon(
			canvas,
			perk_icon_renderer,
			selected_perk_id,
			icon_rect,
			result_a
		):
			var icon_color: Color = selected_data.get("icon_color", PILL_GOLD_COLOR) if selected_data.get("icon_color") is Color else PILL_GOLD_COLOR
			var breath: float = float(ctx.get("icon_breath_scale", 1.0)) if celebration else 1.0
			var icon_r: float = 30.0 * breath
			canvas.draw_circle(icon_center, icon_r, Color(icon_color, result_a))
			var perk_name: String = str(selected_data.get("name", "?"))
			if perk_name.length() > 0:
				_draw_centered_text(canvas, perk_name.left(1).to_upper(), icon_center, int(24.0 * breath), Color(1.0, 1.0, 1.0, result_a))

	# 텍스트 표시
	if result_a > 0.4:
		var skill_name: String = str(selected_data.get("name", "???"))
		_draw_centered_text(canvas, skill_name, Vector2(cx, cy + 45.0), 24, Color(TITLE_COLOR, result_a))

		var old_lv: int = int(ctx.get("old_level", 0))
		var target_level: int = int(ctx.get("target_level", 0))
		var level_text: String = LanguageSettings.format_mugong_level_transition(old_lv, target_level, target_level)
		var lv_color: Color = LEVEL_COLOR
		if celebration:
			var pulse: float = (sin(cel_timer * 6.0) + 1.0) * 0.5
			lv_color = Color(1.0, 0.84 + 0.16 * pulse, 0.31 + 0.24 * pulse)
		_draw_centered_text(canvas, level_text, Vector2(cx, cy + 72.0), 20, Color(lv_color, result_a))

	# 축하 전경 레이어
	if celebration:
		if textured_result:
			_draw_textured_level5_badge(canvas, frame_rect, ctx, result_a)
		else:
			_draw_level5_badge(canvas, cx, icon_center.y, ctx)
		_draw_fireworks(canvas, cx, icon_center.y, ctx)
		if textured_result:
			_draw_textured_confetti(canvas, cx, icon_center.y, ctx, view_size)
		else:
			_draw_confetti(canvas, cx, icon_center.y, ctx, view_size)
		_draw_celebration_banner(canvas, cx, cy, view_size, ctx)

	# 확인 안내
	if bool(ctx.get("waiting_for_confirm", false)):
		var blink: float = (sin(cel_timer * 4.0) + 1.0) * 0.5
		_draw_centered_text(canvas, LanguageSettings.translate_text("[ Space / Click 으로 계속 ]"), Vector2(cx, cy + 130.0), 14, Color(HINT_COLOR, blink))


func _draw_textured_result_ritual_backdrop(
	canvas: CanvasItem,
	center: Vector2,
	ctx: Dictionary,
	result_alpha: float
) -> void:
	var rays_rotation_degrees: float = float(ctx.get("rays_rotation", 0.0))
	_draw_rotated_texture(
		canvas,
		_get_result_texture("result_rune_ring_outer"),
		center,
		Vector2.ONE * 430.0,
		deg_to_rad(rays_rotation_degrees * 0.18),
		0.16 * result_alpha
	)


func _draw_textured_glory_rays(
	canvas: CanvasItem,
	center: Vector2,
	ctx: Dictionary,
	result_alpha: float
) -> void:
	var cel_timer: float = float(ctx.get("celebration_timer", 0.0))
	var entry_alpha: float = smoothstep(0.0, 0.42, cel_timer)
	var rotation := deg_to_rad(float(ctx.get("rays_rotation", 0.0)))
	_draw_rotated_texture(
		canvas,
		_get_result_texture("glory_rays"),
		center,
		Vector2.ONE * 480.0,
		rotation,
		0.62 * entry_alpha * result_alpha
	)


func _draw_textured_result_icon_layers(
	canvas: CanvasItem,
	center: Vector2,
	celebration_timer: float,
	result_alpha: float
) -> void:
	if result_alpha > 0.1:
		var glow_pulse: float = 0.5 + 0.5 * sin(celebration_timer * 4.0)
		var glow_scale: float = 1.0 + 0.055 * glow_pulse
		_draw_rotated_texture(
			canvas,
			_get_result_texture("result_glow_backplate"),
			center,
			Vector2.ONE * 202.0 * glow_scale,
			0.0,
			result_alpha * (0.60 + 0.10 * glow_pulse)
		)
	_draw_rotated_texture(
		canvas,
		_get_result_texture("icon_seal_frame"),
		center,
		Vector2.ONE * 156.0,
		0.0,
		result_alpha
	)


func _draw_linked_perk_icon(
	canvas: CanvasItem,
	perk_icon_renderer: Object,
	perk_id: String,
	rect: Rect2,
	alpha: float
) -> bool:
	if perk_icon_renderer == null or perk_id == "" or not perk_icon_renderer.has_method("draw_icon"):
		return false
	if perk_icon_renderer.has_method("has_icon") and not bool(perk_icon_renderer.has_icon(perk_id)):
		return false
	return bool(perk_icon_renderer.draw_icon(canvas, perk_id, rect, alpha, true))


func _draw_radial_rays(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var rays_rot: float = float(ctx.get("rays_rotation", 0.0))
	var num_rays := 12
	var length := 240.0
	for i in range(num_rays):
		var angle: float = deg_to_rad(rays_rot + float(i) * (360.0 / float(num_rays)))
		var tip := Vector2(cx + cos(angle) * length, cy + sin(angle) * length)
		var alpha: float = 0.25 if i % 2 == 0 else 0.18
		var color := Color(1.0, 0.84, 0.39, alpha) if i % 2 == 0 else Color(1.0, 1.0, 1.0, alpha)
		canvas.draw_line(Vector2(cx, cy), tip, color, 3.0)


func _draw_shockwaves(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var sws: Array = ctx.get("shockwaves", []) if ctx.get("shockwaves") is Array else []
	for sw in sws:
		if float(sw.get("delay", 0.0)) > 0.0:
			continue
		var alpha: float = float(sw.get("current_alpha", 1.0))
		if alpha <= 0.01:
			continue
		var r: float = maxf(1.0, float(sw.get("radius", 0.0)))
		var w: float = maxf(1.0, float(sw.get("width", 4.0)))
		var sw_color: Color = sw.get("color", Color.WHITE) if sw.get("color") is Color else Color.WHITE
		sw_color.a = alpha
		canvas.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 64, sw_color, w)


func _draw_fireworks(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var fws: Array = ctx.get("fireworks", []) if ctx.get("fireworks") is Array else []
	for f in fws:
		var life_ratio: float = maxf(0.0, float(f.get("life", 0.0)) / maxf(0.01, float(f.get("max_life", 1.2))))
		var size: float = maxf(1.0, float(f.get("size", 2.0)) * (0.4 + 0.8 * life_ratio))
		var fx: float = cx + float(f.get("x", 0.0))
		var fy: float = cy + float(f.get("y", 0.0))
		var f_color: Color = f.get("color", Color.WHITE) if f.get("color") is Color else Color.WHITE
		f_color.a = life_ratio
		canvas.draw_circle(Vector2(fx, fy), size * 3.0, Color(f_color, f_color.a * 0.33))
		canvas.draw_circle(Vector2(fx, fy), size, f_color)


func _draw_textured_confetti(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary, view_size: Vector2) -> void:
	var texture := _get_result_texture("confetti_flakes")
	if texture == null:
		return
	var texture_size := texture.get_size()
	var cell_size := texture_size * 0.5
	var conf: Array = ctx.get("confetti", []) if ctx.get("confetti") is Array else []
	for c in conf:
		var draw_x: float = cx + float(c.get("x", 0.0))
		var draw_y: float = cy + float(c.get("y", 0.0))
		if draw_x < -60.0 or draw_x > view_size.x + 60.0:
			continue
		if draw_y < -60.0 or draw_y > view_size.y + 60.0:
			continue
		var life_ratio: float = maxf(0.0, minf(1.0, float(c.get("life", 0.0)) / maxf(0.01, float(c.get("max_life", 4.5)))))
		var alpha: float = 0.5 + 0.5 * life_ratio
		var size: float = float(c.get("size", 6.0))
		var variant: int = posmod(int(c.get("variant", 0)), 4)
		var column := variant % 2
		var row := int(variant / 2)
		var source_rect := Rect2(Vector2(column, row) * cell_size, cell_size)
		var draw_size := Vector2.ONE * clampf(size * 4.2, 20.0, 40.0)
		_draw_rotated_texture_region(
			canvas,
			texture,
			Vector2(draw_x, draw_y),
			draw_size,
			source_rect,
			deg_to_rad(float(c.get("rotation", 0.0))),
			alpha
		)


func _draw_confetti(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary, view_size: Vector2) -> void:
	var conf: Array = ctx.get("confetti", []) if ctx.get("confetti") is Array else []
	for c in conf:
		var draw_x: float = cx + float(c.get("x", 0.0))
		var draw_y: float = cy + float(c.get("y", 0.0))
		if draw_x < -60.0 or draw_x > view_size.x + 60.0:
			continue
		if draw_y < -60.0 or draw_y > view_size.y + 60.0:
			continue
		var life_ratio: float = maxf(0.0, minf(1.0, float(c.get("life", 0.0)) / maxf(0.01, float(c.get("max_life", 4.5)))))
		var alpha: float = 0.5 + 0.5 * life_ratio
		var size: float = float(c.get("size", 6.0))
		var c_color: Color = c.get("color", Color.WHITE) if c.get("color") is Color else Color.WHITE
		c_color.a = alpha
		var w: float = maxf(2.0, size * 1.8)
		var h: float = maxf(1.0, size * 0.8)
		canvas.draw_rect(Rect2(draw_x - w * 0.5, draw_y - h * 0.5, w, h), c_color)


func _draw_textured_level5_badge(
	canvas: CanvasItem,
	frame_rect: Rect2,
	ctx: Dictionary,
	result_alpha: float
) -> void:
	# S3: the ceiling is no longer a fixed 5, so read the actual target level.
	var target_level: int = int(ctx.get("target_level", 0))
	var scale: float = clampf(float(ctx.get("level5_impact_scale", 1.0)), 0.2, 2.2)
	# Anchor to the frame's top-right corner instead of a fixed cx offset. The
	# seal now reads as a stamp on the frame and cannot drift into its right edge.
	var anchor := frame_rect.end - Vector2(3.0, frame_rect.size.y - 5.0)
	_draw_rotated_texture(
		canvas,
		_get_result_texture("geukseong_seal"),
		anchor,
		Vector2.ONE * 68.0 * scale,
		0.0,
		result_alpha
	)
	_draw_centered_text(
		canvas,
		LanguageSettings.format_mugong_level(target_level, target_level),
		anchor,
		int(18.0 * scale),
		Color(1.0, 0.94, 0.68, result_alpha)
	)


func _draw_level5_badge(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var scale: float = maxf(0.2, float(ctx.get("level5_impact_scale", 1.0)))
	var cel_timer: float = float(ctx.get("celebration_timer", 0.0))
	var anchor_x: float = cx + 95.0
	var anchor_y: float = cy - 10.0
	var pulse: float = (sin(cel_timer * 5.0) + 1.0) * 0.5
	var glow_r: float = 30.0 + 12.0 * pulse
	canvas.draw_circle(Vector2(anchor_x, anchor_y), glow_r, Color(1.0, 0.86, 0.39, 0.4 + 0.3 * pulse))
	var target_level: int = int(ctx.get("target_level", 0))
	_draw_centered_text(canvas, LanguageSettings.format_mugong_level(target_level, target_level), Vector2(anchor_x, anchor_y), int(20.0 * scale), Color(1.0, 0.92, 0.35))


@warning_ignore("unused_parameter")
func _draw_celebration_banner(canvas: CanvasItem, cx: float, cy: float, view_size: Vector2, ctx: Dictionary) -> void:
	var bp: float = float(ctx.get("banner_progress", 0.0))
	if bp <= 0.0:
		return
	var eased: float = 1.0 - pow(1.0 - bp, 3.0)
	var box_w: float = 400.0
	var box_h: float = 70.0
	var target_y: float = cy - 195.0
	var start_y: float = -box_h
	var banner_y: float = start_y + (target_y - start_y) * eased
	var box_x: float = cx - box_w * 0.5
	# 박스 본체
	canvas.draw_rect(Rect2(box_x, banner_y, box_w, box_h), Color(0.16, 0.035, 0.015, 0.94))
	canvas.draw_rect(Rect2(box_x, banner_y, box_w, box_h), Color(1.0, 0.84, 0.31), false, 3.0)
	# 타이틀
	_draw_centered_text(canvas, LanguageSettings.translate_text("Lv.5 달성!"), Vector2(cx, banner_y + 28.0), 36, Color(1.0, 0.9, 0.47))
	_draw_centered_text(canvas, LanguageSettings.translate_text("대성영단"), Vector2(cx, banner_y + 54.0), 16, SUBTITLE_COLOR)


func _draw_centered_text(canvas: CanvasItem, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var draw_pos := Vector2(pos.x - text_size.x * 0.5, pos.y + text_size.y * 0.25)
	canvas.draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
