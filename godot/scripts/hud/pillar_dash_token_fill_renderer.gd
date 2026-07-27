extends RefCounted

const PillarDashTokenDividerRenderer := preload("res://scripts/hud/pillar_dash_token_divider_renderer.gd")
const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")

# stage1_pillar_ui_layout.PILLAR_ORB_RADIUS_BASE 미러 (프리웜 스케일 복원용).
const ORB_RADIUS_BASE := 55.0
# 플레이어 대쉬 토큰의 흔한 최대 토큰 수 (정착 분할선 프리웜 키).
const DIVIDER_PREWARM_TOKEN_COUNTS := [2, 3]

const BOOST_SINGLE_RING_LAYERS := 1
const BOOST_SINGLE_RING_SEGMENTS := 24
const BOOST_SINGLE_RING_SEGMENTS_LOD := 16
const BOOST_SECTOR_BACKGROUND_SEGMENTS := 14
const BOOST_SECTOR_CHARGE_LAYERS := 2
const BOOST_SECTOR_CHARGE_SEGMENTS := 10
const BOOST_SECTOR_CORE_SEGMENTS := 8
const BOOST_SECTOR_PULSE_SEGMENTS := 9
const BOOST_SECTOR_RAINBOW_SEGMENTS := 9

const BELL_CELL_ORBIT_RATIO := 0.60
const BELL_CELL_SIZE_RATIO := 0.48
const BELL_SINGLE_SIZE_RATIO := 0.56
const BELL_SINGLE_Y_OFFSET_RATIO := -0.42
const BELL_VISUAL_CENTER_Y_RATIO := -0.067
const BELL_ACQUIRED_MODULATE := Color(1.0, 1.0, 1.0, 0.98)
const BELL_EMPTY_MODULATE := Color(0.24, 0.20, 0.16, 0.58)
const BELL_CHARGING_BASE_MODULATE := Color(0.36, 0.28, 0.20, 0.72)

var divider_renderer: Object = PillarDashTokenDividerRenderer.new()
var _static_layer_cache: Object = PillarOrbStaticLayerCache.new()


# 로딩 프리웜: 컴팩트 풀 단일 토큰 + 정착 상태 분할선 베이크.
# context 색 키는 stage1_pillar_status_orb_context_builder 와 동일 계약.
func prewarm_caches(orb_radius: float, context: Dictionary = {}) -> void:
	var safe_radius: float = max(16.0, orb_radius)
	var scale_factor: float = safe_radius / ORB_RADIUS_BASE
	var inner_radius: float = max(2.0, safe_radius - 5.0 * scale_factor)
	var liquid_top: Color = _get_color(context, "token_liquid_top", Color(0.98, 0.46, 0.36, 1.0))
	var liquid_bottom: Color = _get_color(context, "token_liquid_bottom", Color(0.42, 0.10, 0.12, 1.0))
	var wave_glow: Color = _get_color(context, "token_wave_glow", Color(1.0, 0.78, 0.70, 1.0))
	var inner_glow: Color = _get_color(context, "token_inner_glow", Color(1.0, 0.46, 0.36, 1.0))
	_static_layer_cache.build_now(
		_compact_token_cache_key(inner_radius, liquid_top, liquid_bottom, wave_glow, inner_glow),
		_build_compact_full_single_token_ops(inner_radius, liquid_top, liquid_bottom, wave_glow, inner_glow)
	)
	var token_counts: Array = DIVIDER_PREWARM_TOKEN_COUNTS
	if context.has("max_tokens"):
		token_counts = [int(context.get("max_tokens", 1))]
	divider_renderer.prewarm_caches(inner_radius, token_counts, -PI * 0.5, scale_factor)


func draw_tokens(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	t: float,
	scale_factor: float,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	context: Dictionary
) -> void:
	if max_tokens == 1:
		_draw_single_dash_token(canvas, pillar_drawer, center, inner_radius, available_tokens, charge_progress, t, context)
	else:
		_draw_multi_dash_tokens(
			canvas,
			pillar_drawer,
			center,
			inner_radius,
			max_tokens,
			available_tokens,
			charge_progress,
			t,
			scale_factor,
			divider_anim_progress,
			start_angle_offset,
			sector_angle,
			context
		)


func _draw_single_dash_token(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	available_tokens: int,
	charge_progress: float,
	t: float,
	context: Dictionary
) -> void:
	var fill_ratio_total: float = 0.0
	if available_tokens >= 1:
		fill_ratio_total = 1.0
	elif charge_progress > 0.0:
		fill_ratio_total = charge_progress
	if fill_ratio_total <= 0.0:
		_draw_bell_cells(canvas, center, inner_radius, 1, available_tokens, charge_progress, -PI * 0.5, TAU, context)
		return

	var is_boost_charging: bool = _is_boost_charging_token(context, 0)
	if is_boost_charging:
		_draw_single_boost_charging_token(canvas, pillar_drawer, center, inner_radius, fill_ratio_total, t, context)
		_draw_bell_cells(canvas, center, inner_radius, 1, available_tokens, charge_progress, -PI * 0.5, TAU, context)
		return

	var liquid_top: Color = _get_color(context, "token_liquid_top", Color(0.98, 0.46, 0.36, 1.0))
	var liquid_bottom: Color = _get_color(context, "token_liquid_bottom", Color(0.42, 0.10, 0.12, 1.0))
	var wave_glow: Color = _get_color(context, "token_wave_glow", Color(1.0, 0.78, 0.70, 1.0))
	var inner_glow: Color = _get_color(context, "token_inner_glow", Color(1.0, 0.46, 0.36, 1.0))
	if _should_draw_compact_full_single_token(context, fill_ratio_total, is_boost_charging):
		_draw_compact_full_single_token(canvas, center, inner_radius, liquid_top, liquid_bottom, wave_glow, inner_glow)
		_draw_bell_cells(canvas, center, inner_radius, 1, available_tokens, charge_progress, -PI * 0.5, TAU, context)
		return
	pillar_drawer.draw_pillar_liquid_fill(canvas, center, inner_radius, fill_ratio_total, t, liquid_top, liquid_bottom, wave_glow, float(context.get("hud_lod_scale", 1.0)))
	canvas.draw_circle(center, inner_radius * (0.18 + fill_ratio_total * 0.24), Color(inner_glow.r, inner_glow.g, inner_glow.b, 0.12 + fill_ratio_total * 0.16))
	canvas.draw_circle(center + Vector2(0.0, inner_radius * 0.10), inner_radius * (0.10 + fill_ratio_total * 0.12), Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.06 + fill_ratio_total * 0.08))
	_draw_bell_cells(canvas, center, inner_radius, 1, available_tokens, charge_progress, -PI * 0.5, TAU, context)


func _draw_multi_dash_tokens(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	t: float,
	scale_factor: float,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	context: Dictionary
) -> void:
	var token_full: Color = _get_color(context, "token_full_color", Color(0.78, 0.16, 0.20, 1.0))
	var token_inner: Color = _get_color(context, "token_inner_glow", Color(1.0, 0.52, 0.42, 1.0))
	var lod_active: bool = _is_hud_lod_active(context)
	var full_segments: int = 16 if lod_active else 24
	var inner_segments: int = 10 if lod_active else 16
	for i in range(max_tokens):
		var start_rad: float = start_angle_offset + sector_angle * float(i)
		var end_rad: float = start_rad + sector_angle
		if i < available_tokens:
			var token_pulse: float = 0.5 + 0.5 * sin(t * 3.5 + float(i) * 1.2)
			var base_alpha: float = 0.88 + 0.10 * token_pulse
			canvas.draw_colored_polygon(pillar_drawer.build_sector_points(center, inner_radius, start_rad, end_rad, full_segments), Color(token_full.r, token_full.g, token_full.b, base_alpha))
			canvas.draw_colored_polygon(pillar_drawer.build_sector_points(center, inner_radius * 0.72, start_rad, end_rad, inner_segments), Color(token_inner.r, token_inner.g, token_inner.b, 0.12 + 0.10 * token_pulse))
		elif charge_progress > 0.0 and i == available_tokens:
			if _is_boost_charging_token(context, i):
				# Boost sector migrated to the GPU shader host. When the host is
				# wired into the context we let it draw the sector; the CPU path
				# stays as a fallback for early-boot frames before the deferred
				# add_child lands and for headless tests where no FX host exists.
				if _has_active_boost_fx_host(context):
					continue
				_draw_boost_charging_dash_sector(canvas, pillar_drawer, center, inner_radius, start_rad, end_rad, charge_progress, t, scale_factor)
			else:
				pillar_drawer.draw_dash_sector_liquid(canvas, center, inner_radius, start_rad, end_rad, charge_progress, t, scale_factor, float(context.get("hud_lod_scale", 1.0)))

	_draw_bell_cells(
		canvas,
		center,
		inner_radius,
		max_tokens,
		available_tokens,
		charge_progress,
		start_angle_offset,
		sector_angle,
		context
	)
	divider_renderer.draw(
		canvas,
		pillar_drawer,
		center,
		inner_radius,
		max_tokens,
		divider_anim_progress,
		start_angle_offset,
		sector_angle,
		scale_factor
	)


# Bell cells stay outside the compact liquid cache so acquired / empty /
# charging modulates remain live. This also keeps texture identity out of the
# compact cache key and prevents a stale baked bell after early-boot fallback.
func _draw_bell_cells(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	context: Dictionary
) -> void:
	var texture_value: Variant = context.get("bell_cell_texture", null)
	if not (texture_value is Texture2D):
		return
	var texture: Texture2D = texture_value
	var safe_max_tokens: int = max(1, max_tokens)
	var safe_available_tokens: int = clamp(available_tokens, 0, safe_max_tokens)
	if safe_max_tokens == 1:
		canvas.draw_texture_rect(
			texture,
			_get_single_bell_cell_rect(center, inner_radius),
			false,
			_get_bell_cell_modulate(0, safe_available_tokens, charge_progress)
		)
		return
	for token_index in range(safe_max_tokens):
		canvas.draw_texture_rect(
			texture,
			_get_multi_bell_cell_rect(
				center,
				inner_radius,
				token_index,
				start_angle_offset,
				sector_angle
			),
			false,
			_get_bell_cell_modulate(token_index, safe_available_tokens, charge_progress)
		)


func build_bell_cell_draw_specs(
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	context: Dictionary
) -> Array:
	var texture_value: Variant = context.get("bell_cell_texture", null)
	if not (texture_value is Texture2D):
		return []
	var texture: Texture2D = texture_value
	var safe_max_tokens: int = max(1, max_tokens)
	var safe_available_tokens: int = clamp(available_tokens, 0, safe_max_tokens)
	var specs: Array = []
	if safe_max_tokens == 1:
		specs.append({
			"texture": texture,
			"rect": _get_single_bell_cell_rect(center, inner_radius),
			"modulate": _get_bell_cell_modulate(0, safe_available_tokens, charge_progress),
		})
		return specs

	for token_index in range(safe_max_tokens):
		specs.append({
			"texture": texture,
			"rect": _get_multi_bell_cell_rect(
				center,
				inner_radius,
				token_index,
				start_angle_offset,
				sector_angle
			),
			"modulate": _get_bell_cell_modulate(token_index, safe_available_tokens, charge_progress),
		})
	return specs


func _get_single_bell_cell_rect(center: Vector2, inner_radius: float) -> Rect2:
	var single_size: float = max(10.0, inner_radius * BELL_SINGLE_SIZE_RATIO)
	var single_center := center + Vector2(
		0.0,
		inner_radius * BELL_SINGLE_Y_OFFSET_RATIO + single_size * BELL_VISUAL_CENTER_Y_RATIO
	)
	return Rect2(single_center - Vector2.ONE * single_size * 0.5, Vector2.ONE * single_size)


func _get_multi_bell_cell_rect(
	center: Vector2,
	inner_radius: float,
	token_index: int,
	start_angle_offset: float,
	sector_angle: float
) -> Rect2:
	var cell_size: float = max(10.0, inner_radius * BELL_CELL_SIZE_RATIO)
	var orbit_radius: float = inner_radius * BELL_CELL_ORBIT_RATIO
	var middle_angle: float = start_angle_offset + sector_angle * (float(token_index) + 0.5)
	var cell_center := (
		center
		+ Vector2(cos(middle_angle), sin(middle_angle)) * orbit_radius
		+ Vector2(0.0, cell_size * BELL_VISUAL_CENTER_Y_RATIO)
	)
	return Rect2(cell_center - Vector2.ONE * cell_size * 0.5, Vector2.ONE * cell_size)


func _get_bell_cell_modulate(token_index: int, available_tokens: int, charge_progress: float) -> Color:
	if token_index < available_tokens:
		return BELL_ACQUIRED_MODULATE
	if token_index == available_tokens and charge_progress > 0.0:
		var progress: float = clamp(charge_progress, 0.0, 1.0)
		return BELL_CHARGING_BASE_MODULATE.lerp(BELL_ACQUIRED_MODULATE, progress)
	return BELL_EMPTY_MODULATE


func _get_color(context: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = context.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _should_draw_compact_full_single_token(context: Dictionary, fill_ratio_total: float, is_boost_charging: bool) -> bool:
	if fill_ratio_total < 0.999 or is_boost_charging:
		return false
	if bool(context.get("pillar_hud_static_lod", false)):
		return true
	if bool(context.get("compact_fallback_frame", false)) or bool(context.get("compact_full_single_token", false)):
		return true
	return (
		not bool(context.get("dash_active", false))
		and not bool(context.get("dash_recovering", false))
		and float(context.get("dash_stun_timer", 0.0)) <= 0.0
		and float(context.get("flash_timer", 0.0)) <= 0.0
		and float(context.get("charge_timer", 0.0)) <= 0.0
	)


func _draw_compact_full_single_token(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	liquid_top: Color,
	liquid_bottom: Color,
	wave_glow: Color,
	inner_glow: Color
) -> void:
	# 정적 레이어: 베이크 텍스처가 준비되면 4개 드로우 대신 blit 1회.
	var cache_key: String = _compact_token_cache_key(inner_radius, liquid_top, liquid_bottom, wave_glow, inner_glow)
	var cached_texture: Texture2D = _static_layer_cache.get_texture(cache_key)
	if cached_texture == null and not _static_layer_cache.is_pending(cache_key):
		cached_texture = _static_layer_cache.request_build(
			cache_key,
			_build_compact_full_single_token_ops(inner_radius, liquid_top, liquid_bottom, wave_glow, inner_glow)
		)
	if cached_texture != null:
		_static_layer_cache.draw_centered(canvas, cached_texture, center)
		return
	canvas.draw_circle(center, inner_radius, Color(liquid_bottom.r, liquid_bottom.g, liquid_bottom.b, 0.92))
	canvas.draw_circle(center + Vector2(0.0, -inner_radius * 0.18), inner_radius * 0.76, Color(liquid_top.r, liquid_top.g, liquid_top.b, 0.42))
	canvas.draw_circle(center, inner_radius * 0.42, Color(inner_glow.r, inner_glow.g, inner_glow.b, 0.22))
	canvas.draw_arc(center, inner_radius * 0.82, deg_to_rad(205.0), deg_to_rad(335.0), 16, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.34), 2.0, true)


func _compact_token_cache_key(
	inner_radius: float,
	liquid_top: Color,
	liquid_bottom: Color,
	wave_glow: Color,
	inner_glow: Color
) -> String:
	return "compact_token|%.2f|%s|%s|%s|%s" % [
		inner_radius,
		PillarOrbStaticLayerCache.color_key(liquid_top),
		PillarOrbStaticLayerCache.color_key(liquid_bottom),
		PillarOrbStaticLayerCache.color_key(wave_glow),
		PillarOrbStaticLayerCache.color_key(inner_glow),
	]


# _draw_compact_full_single_token 의 즉시 드로우 본문과 지오메트리 1:1 대응.
# 림 아크만 원본이 antialiased=true 라서 AA 밴드 op 를 쓴다.
func _build_compact_full_single_token_ops(
	inner_radius: float,
	liquid_top: Color,
	liquid_bottom: Color,
	wave_glow: Color,
	inner_glow: Color
) -> Array:
	return [
		PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, inner_radius, Color(liquid_bottom.r, liquid_bottom.g, liquid_bottom.b, 0.92)),
		PillarOrbStaticLayerCache.make_circle(Vector2(0.0, -inner_radius * 0.18), inner_radius * 0.76, Color(liquid_top.r, liquid_top.g, liquid_top.b, 0.42)),
		PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, inner_radius * 0.42, Color(inner_glow.r, inner_glow.g, inner_glow.b, 0.22)),
		PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, inner_radius * 0.82, deg_to_rad(205.0), deg_to_rad(335.0), 2.0, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.34)),
	]


func _draw_single_boost_charging_token(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	fill_ratio: float,
	t: float,
	context: Dictionary
) -> void:
	var hue_base: float = fmod(t * 0.42, 1.0)
	var liquid_top: Color = _rainbow_color(hue_base + 0.12, 0.98)
	var liquid_bottom: Color = _rainbow_color(hue_base + 0.58, 0.92).darkened(0.22)
	var wave_glow: Color = Color(1.0, 1.0, 1.0, 0.95)
	canvas.draw_circle(center, inner_radius, Color(0.04, 0.02, 0.08, 0.34))
	pillar_drawer.draw_pillar_liquid_fill(canvas, center, inner_radius, fill_ratio, t, liquid_top, liquid_bottom, wave_glow, float(context.get("hud_lod_scale", 1.0)))
	canvas.draw_circle(center, inner_radius * (0.22 + fill_ratio * 0.26), Color(1.0, 1.0, 1.0, 0.08 + fill_ratio * 0.12))
	canvas.draw_circle(center + Vector2(0.0, inner_radius * 0.08), inner_radius * (0.12 + fill_ratio * 0.12), Color(liquid_top.r, liquid_top.g, liquid_top.b, 0.10 + fill_ratio * 0.10))
	var ring_segments: int = BOOST_SINGLE_RING_SEGMENTS_LOD if _is_hud_lod_active(context) else BOOST_SINGLE_RING_SEGMENTS
	for layer in range(BOOST_SINGLE_RING_LAYERS):
		var layer_phase: float = t * (1.6 + float(layer) * 0.25) + float(layer) * 0.33
		var ring_radius: float = inner_radius * (0.68 + 0.08 * sin(layer_phase) + float(layer) * 0.10)
		var ring_color: Color = _rainbow_color(hue_base + float(layer) * 0.18, 0.22 - float(layer) * 0.04)
		canvas.draw_arc(center, ring_radius, 0.0, TAU, ring_segments, ring_color, 2.0, true)


func _draw_boost_charging_dash_sector(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	start_rad: float,
	end_rad: float,
	progress: float,
	t: float,
	scale_factor: float
) -> void:
	var clamped_progress: float = clamp(progress, 0.0, 1.0)
	if clamped_progress <= 0.0:
		return
	var hue_base: float = fmod(t * 0.45, 1.0)
	canvas.draw_colored_polygon(
		pillar_drawer.build_sector_points(center, inner_radius, start_rad, end_rad, BOOST_SECTOR_BACKGROUND_SEGMENTS),
		Color(0.04, 0.02, 0.09, 0.42)
	)
	var charge_radius: float = max(2.0, inner_radius * clamped_progress)
	for layer in range(BOOST_SECTOR_CHARGE_LAYERS):
		var layer_scale: float = 1.0 - float(layer) * 0.15
		var layer_radius: float = charge_radius * layer_scale
		if layer_radius <= 1.0:
			continue
		var layer_color: Color = _rainbow_color(hue_base + float(layer) * 0.16 + clamped_progress * 0.18, 0.74 - float(layer) * 0.10)
		canvas.draw_colored_polygon(
			pillar_drawer.build_sector_points(center, layer_radius, start_rad, end_rad, BOOST_SECTOR_CHARGE_SEGMENTS),
			layer_color
		)
	if clamped_progress > 0.12:
		canvas.draw_colored_polygon(
			pillar_drawer.build_sector_points(center, charge_radius * 0.64, start_rad, end_rad, BOOST_SECTOR_CORE_SEGMENTS),
			Color(1.0, 1.0, 1.0, 0.12 + 0.10 * clamped_progress)
		)
	var pulse_radius: float = charge_radius * (0.86 + 0.12 * sin(t * 5.5))
	canvas.draw_arc(center, pulse_radius, start_rad, end_rad, BOOST_SECTOR_PULSE_SEGMENTS, Color(1.0, 1.0, 1.0, 0.30), max(1.0, 2.4 * scale_factor), true)
	canvas.draw_arc(center, inner_radius * (0.92 + 0.04 * sin(t * 7.0)), start_rad, end_rad, BOOST_SECTOR_RAINBOW_SEGMENTS, _rainbow_color(hue_base + 0.35, 0.44), max(1.0, 2.0 * scale_factor), true)


func _is_boost_charging_token(context: Dictionary, token_index: int) -> bool:
	var boost_index: int = int(context.get("boost_charging_token_index", -1))
	if boost_index == token_index:
		return true
	if boost_index >= 0 or not bool(context.get("boost_charging_pending_dash_refund", false)):
		return false
	var available_tokens: int = clamp(int(context.get("tokens", 0)), 0, max(1, int(context.get("max_tokens", 1))))
	return token_index == available_tokens


func _is_hud_lod_active(context: Dictionary) -> bool:
	return float(context.get("hud_lod_scale", 1.0)) < 0.85


# True when the boost FX host (shader overlay) is wired into the context and
# alive in the scene tree. In that case the boost sector is drawn by the host
# and the CPU sector polygon path is suppressed.
func _has_active_boost_fx_host(context: Dictionary) -> bool:
	var host_value: Variant = context.get("boost_fx_host", null)
	if host_value == null:
		return false
	if not (host_value is Object):
		return false
	var host: Object = host_value as Object
	if not is_instance_valid(host):
		return false
	if host.has_method("is_queued_for_deletion") and bool(host.call("is_queued_for_deletion")):
		return false
	return host.has_method("sync_slot")


func _rainbow_color(phase: float, alpha: float = 1.0) -> Color:
	var h: float = fmod(phase, 1.0)
	if h < 0.0:
		h += 1.0
	var scaled: float = h * 6.0
	var c: float = 1.0
	var x: float = c * (1.0 - abs(fmod(scaled, 2.0) - 1.0))
	var rgb := Color(c, x, 0.0, alpha)
	if scaled < 1.0:
		rgb = Color(c, x, 0.0, alpha)
	elif scaled < 2.0:
		rgb = Color(x, c, 0.0, alpha)
	elif scaled < 3.0:
		rgb = Color(0.0, c, x, alpha)
	elif scaled < 4.0:
		rgb = Color(0.0, x, c, alpha)
	elif scaled < 5.0:
		rgb = Color(x, 0.0, c, alpha)
	else:
		rgb = Color(c, 0.0, x, alpha)
	return Color(
		clamp(rgb.r * 0.86 + 0.14, 0.0, 1.0),
		clamp(rgb.g * 0.86 + 0.14, 0.0, 1.0),
		clamp(rgb.b * 0.86 + 0.14, 0.0, 1.0),
		alpha
	)
