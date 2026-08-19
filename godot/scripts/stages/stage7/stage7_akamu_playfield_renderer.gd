extends RefCounted

# Stage 7 Akamu Rigo code-native playfield placeholder.
#
# The state owner already publishes separate clone, projectile, cloud, aura,
# afterimage, and particle channels. Slice 1 keeps their draw contract cheap and
# texture-free; accepted art can replace individual channels later.

const VfxTextureCache := preload("res://scripts/stages/stage7/stage7_akamu_vfx_texture_cache.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")

const FIELD_SIZE := Vector2(760.0, 750.0)
const CLONE_VISUAL_CENTER_Y_OFFSET := 12.0
const ESCAPE_VISUAL_CENTER_Y_OFFSET := 12.0
const CLONE_COLOR := Color(0.38, 0.28, 0.62, 0.42)
const SHADOW_CLONE_TINT := Color(150.0 / 255.0, 150.0 / 255.0, 180.0 / 255.0)
const TEMP_GOLDEN_CLONE_TINT := Color(1.0, 0.82, 0.32)
const TEMP_GOLDEN_CLONE_GLOW_ALPHA := 0.35
const TEMP_GOLDEN_CLONE_GLOW_RADIUS_SCALE := 1.15
const TEMP_GOLDEN_CLONE_GLITCH_COLORS := [
	Color(1.0, 0.64, 0.08),
	Color(1.0, 0.92, 0.48),
	Color(0.90, 0.94, 1.0),
]
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_PARTICLE_RENDER_LIMIT := 96
const SHURIKEN_BLADE_COLOR := Color(180.0 / 255.0, 190.0 / 255.0, 200.0 / 255.0)
const SHURIKEN_BLADE_HIGHLIGHT_COLOR := Color(220.0 / 255.0, 230.0 / 255.0, 240.0 / 255.0)
const SHURIKEN_BLADE_OUTLINE_COLOR := Color(60.0 / 255.0, 70.0 / 255.0, 80.0 / 255.0)
const SHURIKEN_HUB_DARK_COLOR := Color(80.0 / 255.0, 90.0 / 255.0, 100.0 / 255.0)
const SHURIKEN_HUB_LIGHT_COLOR := Color(120.0 / 255.0, 130.0 / 255.0, 140.0 / 255.0)
const SHURIKEN_HUB_OUTLINE_COLOR := Color(40.0 / 255.0, 50.0 / 255.0, 60.0 / 255.0)
const SHURIKEN_HUB_HOLE_COLOR := Color(30.0 / 255.0, 30.0 / 255.0, 40.0 / 255.0)
const CLOUD_FILL_COLOR := Color(45.0 / 255.0, 38.0 / 255.0, 70.0 / 255.0)
const CLOUD_SMOKE_COLORS := [
	Color(40.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0),
	Color(50.0 / 255.0, 40.0 / 255.0, 80.0 / 255.0),
	Color(60.0 / 255.0, 50.0 / 255.0, 100.0 / 255.0),
	Color(45.0 / 255.0, 55.0 / 255.0, 90.0 / 255.0),
	Color(35.0 / 255.0, 45.0 / 255.0, 75.0 / 255.0),
]
const CLOUD_SPARKLE_COLOR := Color(180.0 / 255.0, 140.0 / 255.0, 1.0)
const CLOUD_BURST_COLOR := Color(150.0 / 255.0, 100.0 / 255.0, 1.0)
const CLOUD_CHAKRA_OUTER_COLOR := Color(100.0 / 255.0, 60.0 / 255.0, 180.0 / 255.0, 50.0 / 255.0)
const CLOUD_CHAKRA_MID_COLOR := Color(140.0 / 255.0, 100.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0)
const CLOUD_CHAKRA_CORE_COLOR := Color(180.0 / 255.0, 150.0 / 255.0, 1.0, 120.0 / 255.0)
const CLOUD_CHAKRA_SPARK_COLOR := Color(1.0, 1.0, 1.0, 150.0 / 255.0)
const AURA_COLOR := Color(0.56, 0.88, 1.0, 0.64)
const WIND_AURA_COLOR := Color(0.40, 0.92, 1.0, 0.78)
const WIND_AURA_INNER_COLOR := Color(0.58, 1.0, 0.78, 0.58)
const WIND_AURA_DEPLETED_COLOR := Color(0.30, 0.38, 0.46, 0.34)
const SUPERSPEED_AURA_COLOR := Color(1.0, 0.42, 0.08, 0.88)
const SUPERSPEED_AURA_DARK_COLOR := Color(0.12, 0.03, 0.12, 0.76)
const AWAKENING_OVERLAY_COLOR := Color(0.015, 0.025, 0.06, 0.72)
# 원본 draw_stage8_wind_aura 팔레트 (기본 시안/민트 ↔ 극정호신 주황).
const WIND_AURA_GLOW_CYAN := Color(100.0 / 255.0, 220.0 / 255.0, 1.0)
const WIND_AURA_STREAM_CYAN := Color(150.0 / 255.0, 240.0 / 255.0, 1.0)
const WIND_AURA_RING_SUB_MINT := Color(150.0 / 255.0, 1.0, 200.0 / 255.0)
const WIND_AURA_GLOW_ORANGE := Color(1.0, 150.0 / 255.0, 50.0 / 255.0)
const WIND_AURA_STREAM_ORANGE := Color(1.0, 180.0 / 255.0, 80.0 / 255.0)
const WIND_AURA_RING_SUB_ORANGE := Color(1.0, 200.0 / 255.0, 100.0 / 255.0)
const SUPERSPEED_PARTICLE_ORANGES := [
	Color(1.0, 180.0 / 255.0, 100.0 / 255.0),
	Color(1.0, 140.0 / 255.0, 60.0 / 255.0),
	Color(1.0, 200.0 / 255.0, 120.0 / 255.0),
	Color(1.0, 160.0 / 255.0, 80.0 / 255.0),
]
# 원본 극정호신 오버레이 팔레트 (노란 타이틀 + 다크 그림자 + 노란 타이머 바).
const SUPERSPEED_TITLE_COLOR := Color(1.0, 230.0 / 255.0, 80.0 / 255.0)
const SUPERSPEED_TITLE_SHADOW_COLOR := Color(20.0 / 255.0, 10.0 / 255.0, 0.0)
const SUPERSPEED_BAR_FILL_COLOR := Color(1.0, 200.0 / 255.0, 60.0 / 255.0)
# 보스 프레임 고스트(환영/trail/탈출 잔상/홀로그램)의 스프라이트 드로우 크기 —
# 보스 본체 DRAW_SIZE(128x128)와 동일 계열, visual_scale로 난쟁이 축소 반영.
const GHOST_SPRITE_SIZE := Vector2(128.0, 128.0)
const ESCAPE_COLOR := Color(0.38, 0.78, 0.94, 0.72)
const HOLOGRAM_COLOR := Color(0.62, 0.90, 1.0, 0.72)
const CLOUD_EXPAND_SIDE := 253.0
const CLOUD_EXPAND_TOP := 138.0
const CLONE_GLITCH_COLORS := [
	Color(0.0, 1.0, 1.0),
	Color(1.0, 0.0, 1.0),
	Color(1.0, 1.0, 0.0),
]

# 그림자분신 스프라이트 프레임 소스(보스 액터 렌더러). 부모 액터 렌더러가
# 생성 시점에 물려주며, 비어 있으면 코드-네이티브 박스 폴백으로 그린다.
var _clone_sprite_source: Object = null
# draw_underlay가 프레임당 1회 해석하는 보스 프레임 스펙 캐시. 분신 외에
# 환영/trail/탈출 잔상/홀로그램 고스트도 이 스펙으로 스프라이트를 그린다.
var _ghost_frame_spec: Dictionary = {}
# bake-once VFX 텍스처 준비 여부. 프레임당 1회(draw_underlay/draw_overlay
# 진입 시) 갱신하며, false면 모든 프리미티브 헬퍼가 원본 벡터 드로로
# 폴백한다(correctness-identical fallback — 프리웜 전 로딩 프레임 한정).
var _vfx_baked := false


func set_clone_sprite_source(source: Object) -> void:
	_clone_sprite_source = source


func get_debug_clone_render_mode(context: Dictionary) -> String:
	return "sprite" if not _resolve_clone_frame_spec(context).is_empty() else "placeholder"


func get_debug_starpoint_coordinate_payload(
	drop: Dictionary,
	context: Dictionary,
	shake_offset: Vector2
) -> Dictionary:
	return _build_starpoint_coordinate_payload(drop, context, shake_offset)


func prewarm_assets() -> void:
	VfxTextureCache.prewarm()


func prewarm_assets_step() -> bool:
	return VfxTextureCache.prewarm_step()


func reset() -> void:
	CommonStarpointVisualHost.hide_all_existing_hosts()


func clear_transient_canvas_items() -> void:
	CommonStarpointVisualHost.hide_all_existing_hosts()


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, _perf_logger: Object = null) -> void:
	draw_underlay(canvas, context, shake_offset, _perf_logger)
	draw_overlay(canvas, context, shake_offset, _perf_logger)


func draw_underlay(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	_perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	_vfx_baked = VfxTextureCache.is_ready()
	# 보스 프레임 고스트(환영/trail/탈출 잔상/홀로그램)용 스펙을 프레임당 1회
	# 해석한다. 원본은 이들 전부 보스 이미지 블릿이다.
	_ghost_frame_spec = _resolve_clone_frame_spec(context)
	_draw_superspeed_dash_wake(canvas, context, shake_offset)
	var trail_values: Variant = context.get("stage7_akamu_superspeed_trails", [])
	if trail_values is Array:
		for value in trail_values:
			if value is Dictionary:
				_draw_superspeed_silhouette(canvas, value, shake_offset, true)
	var superspeed_ghost_values: Variant = context.get("stage7_akamu_superspeed_afterimages", [])
	if superspeed_ghost_values is Array:
		var superspeed_ghosts: Array = superspeed_ghost_values
		for index in range(superspeed_ghosts.size() - 1, -1, -1):
			var value: Variant = superspeed_ghosts[index]
			if value is Dictionary:
				_draw_superspeed_silhouette(canvas, value, shake_offset, false)
	var dark_particle_values: Variant = context.get("stage7_akamu_superspeed_dark_particles", [])
	if dark_particle_values is Array:
		for value in dark_particle_values:
			if value is Dictionary:
				_draw_superspeed_dark_particle(canvas, value, shake_offset)
	var afterimage_values: Variant = context.get("stage7_akamu_afterimages", [])
	if afterimage_values is Array:
		var afterimages: Array = afterimage_values
		# Legacy draws the delayed ghosts back-to-front so ghost 0 (alpha 255)
		# remains the topmost trail image.
		for index in range(afterimages.size() - 1, -1, -1):
			var value: Variant = afterimages[index]
			if value is Dictionary:
				_draw_afterimage(canvas, value, shake_offset)
	var hologram: Variant = context.get("stage7_akamu_hologram", {})
	if hologram is Dictionary:
		_draw_hologram(canvas, hologram, shake_offset)
	var clone_values: Variant = context.get("stage7_akamu_clones", [])
	if clone_values is Array and not (clone_values as Array).is_empty():
		for value in clone_values:
			if value is Dictionary:
				_draw_clone(canvas, value, shake_offset, _ghost_frame_spec)
	_draw_starpoint_particles(canvas, context, shake_offset)
	_draw_starpoint_drops(canvas, context, shake_offset)
	for value in context.get("stage7_akamu_shurikens", []):
		if value is Dictionary:
			_draw_shuriken(canvas, value, shake_offset)
	var aura: Variant = context.get("stage7_akamu_aura", {})
	if aura is Dictionary and str((aura as Dictionary).get("kind", "")) != "cloud_precast":
		# 차크라 집중 오라는 원본처럼 보스 위에 그려야 하므로 overlay 패스 소유.
		_draw_aura(canvas, aura, shake_offset)
	for value in context.get("stage7_akamu_particles", []):
		if value is Dictionary:
			_draw_particle(canvas, value, shake_offset)
	if bool(context.get("stage7_akamu_gameplay_freeze_active", false)):
		canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.05, 0.08, 0.16, 0.16))


func draw_overlay(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	_perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	_vfx_baked = VfxTextureCache.is_ready()
	var overlay_aura: Variant = context.get("stage7_akamu_aura", {})
	if overlay_aura is Dictionary and str((overlay_aura as Dictionary).get("kind", "")) == "cloud_precast":
		_draw_aura(canvas, overlay_aura, shake_offset)
	var cloud: Variant = context.get("stage7_akamu_cloud", {})
	if cloud is Dictionary:
		_draw_cloud(canvas, cloud, shake_offset)
	var wind_aura: Variant = context.get("stage7_akamu_wind_aura", {})
	if wind_aura is Dictionary:
		_draw_wind_aura(canvas, wind_aura, shake_offset)
	var burst_values: Variant = context.get("stage7_akamu_wind_burst_particles", [])
	if burst_values is Array:
		for value in burst_values:
			if value is Dictionary:
				_draw_wind_burst_particle(canvas, value, shake_offset)
	_draw_slice5_cinematic_overlay(canvas, context)


func get_asset_status() -> Dictionary:
	return {
		"uses_code_native_placeholder": true,
		"generated_art_loaded": false,
		"runtime_nodes_required": false,
	}


func get_imagegen_asset_status() -> Dictionary:
	return get_asset_status()


func _draw_clone(canvas: CanvasItem, clone: Dictionary, shake_offset: Vector2, frame_spec: Dictionary = {}) -> void:
	var center: Vector2 = _as_vector2(clone.get("center", clone.get("pos", Vector2.ZERO))) \
		+ Vector2(0.0, CLONE_VISUAL_CENTER_Y_OFFSET) \
		+ Vector2(0.0, float(clone.get("hop_offset", 0.0))) \
		+ shake_offset
	var size: Vector2 = _as_vector2(clone.get("size", Vector2(86.0, 52.0)))
	var alpha: float = clampf(float(clone.get("alpha", 0.42)), 0.0, 1.0)
	if alpha <= 0.001:
		return
	var phase: String = str(clone.get("phase", "active"))
	var death_progress: float = clampf(float(clone.get("death_progress", 0.0)), 0.0, 1.0)
	var golden: bool = bool(clone.get("golden", false))
	var clone_tint: Color = TEMP_GOLDEN_CLONE_TINT if golden else SHADOW_CLONE_TINT
	if golden:
		_draw_golden_clone_underlay(canvas, center, size, alpha)
	if _draw_clone_sprite(
		canvas,
		clone,
		center,
		size,
		alpha,
		phase,
		death_progress,
		frame_spec,
		clone_tint
	):
		return
	# 코드-네이티브 폴백: 보스 시트 프리웜 전(로딩 프레임)에만 도달한다.
	if phase == "dying":
		center.x += sin(float(int(clone.get("id", 0))) * 2.17 + death_progress * 31.0) * 7.0 * death_progress
		size.y *= 1.0 - death_progress * 0.28
	var color := Color(0.96, 0.60, 0.10, 0.70) if golden else CLONE_COLOR
	color.a = alpha
	var body_rect := Rect2(center - size * 0.5, size)
	canvas.draw_rect(body_rect, color)
	var hood_radius: float = maxf(8.0, minf(size.x, size.y) * 0.22)
	var hood_color := Color(0.38, 0.20, 0.04, alpha * 0.96) if golden else Color(0.14, 0.10, 0.26, alpha * 0.96)
	canvas.draw_circle(center + Vector2(0.0, -size.y * 0.20), hood_radius, hood_color)
	var mask_rect := Rect2(
		center + Vector2(-size.x * 0.28, -size.y * 0.20),
		Vector2(size.x * 0.56, size.y * 0.18)
	)
	var mask_color := Color(1.0, 0.92, 0.58, alpha * 0.90) if golden else Color(0.54, 0.50, 0.72, alpha * 0.72)
	canvas.draw_rect(mask_rect, mask_color)
	canvas.draw_line(
		center + Vector2(-size.x * 0.20, -size.y * 0.10),
		center + Vector2(size.x * 0.20, -size.y * 0.10),
		Color(1.0, 0.96, 0.78, alpha) if golden else Color(0.86, 0.76, 1.0, alpha),
		2.0,
		true
	)
	canvas.draw_line(
		body_rect.position + Vector2(size.x * 0.14, size.y * 0.78),
		body_rect.end - Vector2(size.x * 0.14, size.y * 0.22),
		Color(1.0, 0.78, 0.24, alpha * 0.78) if golden else Color(0.68, 0.58, 0.92, alpha * 0.68),
		2.0,
		true
	)
	if phase == "emerging":
		var emerge_progress: float = clampf(float(clone.get("emerge_progress", 0.0)), 0.0, 1.0)
		canvas.draw_rect(
			body_rect.grow(5.0 * (1.0 - emerge_progress)),
			Color(0.72, 0.60, 1.0, alpha * 0.55),
			false,
			2.0
		)
	elif phase == "dying":
		var glitch_colors: Array = TEMP_GOLDEN_CLONE_GLITCH_COLORS if golden else CLONE_GLITCH_COLORS
		for stripe_index in range(3):
			var stripe_y: float = body_rect.position.y + body_rect.size.y * (0.22 + float(stripe_index) * 0.26)
			var stripe_shift: float = sin(death_progress * 24.0 + float(stripe_index) * 1.9) * 9.0
			canvas.draw_line(
				Vector2(body_rect.position.x + stripe_shift, stripe_y),
				Vector2(body_rect.end.x + stripe_shift, stripe_y),
				Color(glitch_colors[stripe_index], alpha * 0.62),
				2.0,
				true
			)


func _draw_golden_clone_underlay(
	canvas: CanvasItem,
	center: Vector2,
	size: Vector2,
	alpha: float
) -> void:
	var glow_radius: float = maxf(size.x, size.y) * 0.5 * TEMP_GOLDEN_CLONE_GLOW_RADIUS_SCALE
	var glow_rect := Rect2(center - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0)
	var glow_modulate := Color(
		TEMP_GOLDEN_CLONE_TINT.r,
		TEMP_GOLDEN_CLONE_TINT.g,
		TEMP_GOLDEN_CLONE_TINT.b,
		TEMP_GOLDEN_CLONE_GLOW_ALPHA * alpha
	)
	var aura_texture: Texture2D = VfxTextureCache.get_texture(VfxTextureCache.KEY_AURA_GLOW_STACK)
	var core_texture: Texture2D = VfxTextureCache.get_texture(VfxTextureCache.KEY_FLAT_DISC)
	if aura_texture != null:
		canvas.draw_texture_rect(aura_texture, glow_rect, false, glow_modulate)
	if core_texture != null:
		var core_size := size * Vector2(0.72, 0.82)
		canvas.draw_texture_rect(
			core_texture,
			Rect2(center - core_size * 0.5, core_size),
			false,
			Color(1.0, 0.88, 0.38, TEMP_GOLDEN_CLONE_GLOW_ALPHA * 0.78 * alpha)
		)
	if aura_texture == null and core_texture == null:
		# Prewarm-safe loading fallback. The accepted path still reuses the baked
		# textures above; this prevents the first loading frame from reverting to
		# a dark purple clone while those textures are not materialized yet.
		canvas.draw_circle(center, glow_radius, glow_modulate)
		canvas.draw_circle(
			center,
			minf(size.x, size.y) * 0.30,
			Color(1.0, 0.88, 0.38, TEMP_GOLDEN_CLONE_GLOW_ALPHA * 0.78 * alpha)
		)


func _draw_starpoint_particles(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2
) -> void:
	var particle_values: Variant = context.get("stage7_akamu_starpoint_particles", [])
	if not (particle_values is Array):
		return
	var particles: Array = particle_values
	var first_index: int = maxi(0, particles.size() - STARPOINT_PARTICLE_RENDER_LIMIT)
	for particle_index in range(first_index, particles.size()):
		var particle_value: Variant = particles[particle_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var particle_alpha: float = clampf(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if particle_alpha <= 0.0:
			continue
		var particle_pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO)) + shake_offset
		var particle_color: Color = CommonStarpointVisualHost.get_muhon_particle_color(
			float(particle.get("color_shift", 0.5)),
			particle_alpha
		)
		canvas.draw_circle(
			particle_pos,
			maxf(1.0, float(particle.get("size", 2.0))),
			particle_color
		)


func _draw_starpoint_drops(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2
) -> void:
	var drop_values: Variant = context.get("stage7_akamu_starpoint_drops", [])
	if not (drop_values is Array) or (drop_values as Array).is_empty():
		CommonStarpointVisualHost.hide_on_canvas(canvas)
		return
	var drops: Array = drop_values
	var host: Node = CommonStarpointVisualHost.get_or_create_on_canvas(canvas)
	if host != null and host.has_method("sync_drop"):
		host.begin_frame()
		for drop_value in drops:
			var drop: Dictionary = drop_value if drop_value is Dictionary else {}
			var payload := _build_starpoint_coordinate_payload(drop, context, shake_offset)
			host.sync_drop({
				"pos": payload.get("gpu_pos", Vector2.ZERO),
				"size": float(payload.get("gpu_size", STARPOINT_DROP_SIZE)),
				"life": float(drop.get("life", 0.0)),
				"rotation": float(drop.get("rotation", 0.0)),
				"glow_intensity": float(drop.get("glow_intensity", 1.0)),
				"star_detector_bonus": false,
				"elapsed": float(drop.get("glow_timer", 0.0)) / 6.0,
			})
		host.end_frame()
		return
	for drop_value in drops:
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		var payload := _build_starpoint_coordinate_payload(drop, context, shake_offset)
		var life_alpha: float = clampf(float(drop.get("life", 0.0)) * 2.0 / 255.0, 0.0, 1.0)
		CommonStarpointVisualHost.draw_muhon_fallback(
			canvas,
			payload.get("fallback_pos", Vector2.ZERO),
			float(payload.get("fallback_size", STARPOINT_DROP_SIZE)),
			life_alpha,
			float(drop.get("glow_intensity", 1.0)),
			false,
			float(drop.get("glow_timer", 0.0))
		)


func _build_starpoint_coordinate_payload(
	drop: Dictionary,
	context: Dictionary,
	shake_offset: Vector2
) -> Dictionary:
	var playfield_pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO)) + shake_offset
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO))
	var render_scale: float = maxf(0.001, float(context.get("render_scale", 1.0)))
	var drop_size: float = maxf(1.0, float(drop.get("size", STARPOINT_DROP_SIZE)))
	return {
		"gpu_pos": game_offset + playfield_pos * render_scale,
		"gpu_size": drop_size * render_scale,
		# Immediate CanvasItem fallback already inherits the playfield transform.
		# Keep it in unscaled playfield coordinates; only local shake belongs here.
		"fallback_pos": playfield_pos,
		"fallback_size": drop_size,
	}


func _resolve_clone_frame_spec(context: Dictionary) -> Dictionary:
	if _clone_sprite_source == null \
			or not is_instance_valid(_clone_sprite_source) \
			or not _clone_sprite_source.has_method("get_shadow_clone_frame_spec"):
		return {}
	var spec_value: Variant = _clone_sprite_source.get_shadow_clone_frame_spec(context)
	return spec_value as Dictionary if spec_value is Dictionary else {}


# 원본 파리티: 분신은 보스의 현재 애니메이션 프레임을 (150,150,180) 곱연산
# 틴트 + 알파(200/255 * emerge * fade — state가 발행)로 블릿한다. 소멸은
# 위→아래 스캔라인 증발 + 경계 글리치 라인(시안/마젠타/옐로) 홀로그램 연출.
func _draw_clone_sprite(
	canvas: CanvasItem,
	clone: Dictionary,
	center: Vector2,
	size: Vector2,
	alpha: float,
	phase: String,
	death_progress: float,
	frame_spec: Dictionary,
	clone_tint: Color
) -> bool:
	var texture_value: Variant = frame_spec.get("texture", null)
	if not (texture_value is Texture2D):
		return false
	var source_value: Variant = frame_spec.get("source_rect", null)
	if not (source_value is Rect2):
		return false
	var source_rect: Rect2 = source_value
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	var texture: Texture2D = texture_value as Texture2D
	var modulate := Color(clone_tint.r, clone_tint.g, clone_tint.b, alpha)
	var dest := Rect2(center - size * 0.5, size)
	if phase != "dying" or death_progress <= 0.0:
		canvas.draw_texture_rect_region(texture, dest, source_rect, modulate, false, true)
		return true
	# 홀로그램 증발: 지나간 스캔라인 위쪽은 사라지고, 남은 아래쪽만
	# 글리치 오프셋과 함께 그린다 (원본의 row 루프를 region 절단 1회로 축약).
	var hidden_ratio: float = clampf(death_progress, 0.0, 1.0)
	var visible_height: float = size.y * (1.0 - hidden_ratio)
	if visible_height < 1.0:
		return true
	var clone_id: float = float(int(clone.get("id", 0)))
	var glitch_strength: float = 15.0 * death_progress
	var glitch_offset := Vector2(
		sin(death_progress * 20.0 + clone_id * 1.7) * glitch_strength,
		cos(death_progress * 15.0 + clone_id * 0.9) * glitch_strength * 0.5
	)
	var sub_source := Rect2(
		source_rect.position + Vector2(0.0, source_rect.size.y * hidden_ratio),
		Vector2(source_rect.size.x, source_rect.size.y * (1.0 - hidden_ratio))
	)
	var sub_dest := Rect2(
		dest.position + Vector2(0.0, size.y * hidden_ratio) + glitch_offset,
		Vector2(size.x, visible_height)
	)
	canvas.draw_texture_rect_region(texture, sub_dest, sub_source, modulate, false, true)
	var boundary_y: float = sub_dest.position.y
	for stripe_index in range(3):
		var stripe_phase: float = death_progress * 24.0 + float(stripe_index) * 2.1 + clone_id
		if sin(stripe_phase) <= -0.1:
			continue
		var glitch_colors: Array = (
			TEMP_GOLDEN_CLONE_GLITCH_COLORS
			if bool(clone.get("golden", false))
			else CLONE_GLITCH_COLORS
		)
		var glitch_color: Color = glitch_colors[
			(stripe_index + int(death_progress * 24.0) + int(clone_id)) % glitch_colors.size()
		]
		glitch_color.a = alpha * 0.55
		var stripe_y: float = boundary_y + float(stripe_index) * 3.0
		canvas.draw_line(
			Vector2(sub_dest.position.x + sin(stripe_phase) * 9.0, stripe_y),
			Vector2(sub_dest.end.x + sin(stripe_phase) * 9.0, stripe_y),
			glitch_color,
			2.0,
			true
		)
	return true


func _draw_shuriken(canvas: CanvasItem, shuriken: Dictionary, shake_offset: Vector2) -> void:
	var center: Vector2 = _as_vector2(shuriken.get("center", shuriken.get("pos", Vector2.ZERO))) + shake_offset
	var angle: float = float(shuriken.get("angle", 0.0))
	# 원본 draw_stage8_shurikens 파리티: ~39px 은빛 금속 4날 수리검.
	# base_size = max(18,10)+8 = 26, size = 26*1.5 = 39 → 날 길이 39//2-3 = 16,
	# 날 시작 거리 6, 날 반너비 9//2 = 4. 고정 형상의 강체 회전이라 폴리곤
	# 삼각분할은 항상 유효하다.
	var blade_length := 16.0
	var inner_dist := 6.0
	var blade_half_width := 4.0
	for index in range(4):
		var blade_angle: float = angle + float(index) * PI * 0.5
		var blade_dir := Vector2(cos(blade_angle), sin(blade_angle))
		var perp := Vector2(-blade_dir.y, blade_dir.x)
		var tip: Vector2 = center + blade_dir * blade_length
		var blade_start: Vector2 = center + blade_dir * inner_dist
		var left: Vector2 = blade_start + perp * blade_half_width
		var right: Vector2 = blade_start - perp * blade_half_width
		canvas.draw_colored_polygon(
			PackedVector2Array([tip, left, right]),
			SHURIKEN_BLADE_COLOR
		)
		canvas.draw_colored_polygon(
			PackedVector2Array([tip, (tip + left) * 0.5, blade_start]),
			SHURIKEN_BLADE_HIGHLIGHT_COLOR
		)
		canvas.draw_polyline(
			PackedVector2Array([tip, left, right, tip]),
			SHURIKEN_BLADE_OUTLINE_COLOR,
			1.0,
			true
		)
	canvas.draw_circle(center, 7.0, SHURIKEN_HUB_DARK_COLOR)
	canvas.draw_circle(center, 4.0, SHURIKEN_HUB_LIGHT_COLOR)
	canvas.draw_arc(center, 7.0, 0.0, TAU, 20, SHURIKEN_HUB_OUTLINE_COLOR, 1.0, true)
	canvas.draw_circle(center, 3.0, SHURIKEN_HUB_HOLE_COLOR)


func _draw_cloud(canvas: CanvasItem, cloud: Dictionary, shake_offset: Vector2) -> void:
	if cloud.is_empty() or not bool(cloud.get("active", true)):
		return
	var alpha: float = clampf(float(cloud.get("alpha", 0.0)), 0.0, 1.0)
	if alpha <= 0.001:
		return
	var profile: Dictionary = _resolve_cloud_draw_profile(cloud)
	var center: Vector2 = (profile.get("ellipse_center") as Vector2) + shake_offset
	var smoke_size: Vector2 = profile.get("ellipse_size") as Vector2
	var eased_expand: float = float(profile.get("eased_expand", 1.0))
	var expanding: bool = str(profile.get("mode", "sustained")) == "expanding"
	var elapsed_sec: float = maxf(0.0, float(cloud.get("elapsed_sec", 0.0)))
	if smoke_size.x <= 40.0:
		return
	# 원본 draw_stage8_cloud 파리티: 착지 중심의 짙은 보라 연막 타원(45,38,70) +
	# 나선 배치 파티클 레이어. 741x700 풋프린트의 위쪽 138px는 파티클 헤드룸.
	var fill := CLOUD_FILL_COLOR
	fill.a = alpha
	_draw_ellipse(canvas, center, smoke_size * 0.5, fill)

	if expanding:
		for layer in range(3):
			var layer_progress: float = minf(1.0, eased_expand * (1.0 + float(layer) * 0.2))
			var layer_color: Color = CLOUD_SMOKE_COLORS[layer % CLOUD_SMOKE_COLORS.size()]
			layer_color.a = (200.0 / 255.0) * layer_progress * (1.0 - float(layer) * 0.15) * alpha
			var layer_scale: float = 0.6 + float(layer) * 0.15
			var particle_count: int = 12 + layer * 4
			for index in range(particle_count):
				var t: float = float(index) / float(particle_count)
				var particle_angle: float = t * PI * 4.0 + float(layer) * 0.5 \
					+ elapsed_sec * (0.3 + float(layer) * 0.1)
				var particle_dist: float = (0.15 + t * 0.85) * smoke_size.x * 0.5 * layer_scale
				var particle_size: float = (28.0 + float(index % 3) * 10.0) \
					* layer_progress * (1.2 - float(layer) * 0.1)
				if particle_size <= 5.0:
					continue
				_fill_circle(
					canvas,
					center + Vector2(
						cos(particle_angle) * particle_dist,
						sin(particle_angle) * particle_dist * 0.5
					),
					particle_size,
					layer_color
				)
		# 확장 초기 차크라 버스트 링 2개 (원본 glow ring 파리티).
		var burst_intensity: float = maxf(0.0, 1.0 - eased_expand * 1.5)
		if burst_intensity > 0.15:
			for ring in range(2):
				var ring_color := CLOUD_BURST_COLOR
				ring_color.a = maxf(0.0, (200.0 * burst_intensity - float(ring) * 60.0) / 255.0) * alpha
				canvas.draw_arc(
					center,
					50.0 * (1.0 - burst_intensity) + float(ring) * 35.0,
					0.0,
					TAU,
					36,
					ring_color,
					3.0,
					true
				)
		return

	# 지속 상태: 파티클 레이어 3 + 신비 스파클 8 + 부유 연막 덩어리 4 (원본 파리티).
	for layer in range(3):
		var layer_color: Color = CLOUD_SMOKE_COLORS[layer % CLOUD_SMOKE_COLORS.size()]
		layer_color.a = (180.0 / 255.0) * (1.0 - float(layer) * 0.15) * alpha
		var layer_scale: float = 0.65 + float(layer) * 0.12
		var particle_count: int = 10 + layer * 3
		for index in range(particle_count):
			var t: float = float(index) / float(particle_count)
			var particle_angle: float = t * PI * 4.0 + float(layer) * 0.7 \
				+ elapsed_sec * (0.15 + float(layer) * 0.05)
			var particle_dist: float = (0.1 + t * 0.9) * smoke_size.x * 0.5 * layer_scale
			var particle_size: float = (35.0 + float(index % 3) * 12.0) * (1.15 - float(layer) * 0.08)
			if particle_size <= 6.0:
				continue
			_fill_circle(
				canvas,
				center + Vector2(
					cos(particle_angle) * particle_dist,
					sin(particle_angle) * particle_dist * 0.5
				),
				particle_size,
				layer_color
			)
	for index in range(8):
		var sparkle_angle: float = float(index) / 8.0 * TAU + elapsed_sec * 0.8
		var sparkle_dist: float = (0.3 + float(index) * 0.07) * smoke_size.x * 0.45
		var sparkle_pulse: float = 0.5 + 0.5 * sin(elapsed_sec * 3.0 + float(index) * 0.8)
		var sparkle_color := CLOUD_SPARKLE_COLOR
		sparkle_color.a = (120.0 + sparkle_pulse * 80.0) / 255.0 * alpha
		_fill_circle(
			canvas,
			center + Vector2(
				cos(sparkle_angle) * sparkle_dist,
				sin(sparkle_angle) * sparkle_dist * 0.5
			),
			4.0 + sparkle_pulse * 5.0,
			sparkle_color
		)
	var floating_smokes := [
		[-0.35, -0.3, 50.0, 0.0],
		[0.35, -0.25, 45.0, 1.5],
		[-0.3, 0.3, 42.0, 3.0],
		[0.3, 0.25, 48.0, 4.5],
	]
	for lump_value in floating_smokes:
		var lump: Array = lump_value
		var phase: float = float(lump[3])
		var lump_color: Color = CLOUD_SMOKE_COLORS[int(phase) % CLOUD_SMOKE_COLORS.size()]
		lump_color.a = (150.0 / 255.0) * alpha
		_fill_circle(
			canvas,
			center + Vector2(
				float(lump[0]) * smoke_size.x + sin(elapsed_sec * 0.02 + phase) * smoke_size.x * 0.15,
				float(lump[1]) * smoke_size.y + cos(elapsed_sec * 0.4 + phase) * 12.0
			),
			float(lump[2]),
			lump_color
		)


func get_debug_cloud_draw_profile(cloud: Dictionary) -> Dictionary:
	return _resolve_cloud_draw_profile(cloud)


func _resolve_cloud_draw_profile(cloud: Dictionary) -> Dictionary:
	var logical_size: Vector2 = _as_vector2(cloud.get("logical_size", Vector2(235.0, 56.0)))
	logical_size.x = maxf(24.0, logical_size.x)
	logical_size.y = maxf(18.0, logical_size.y)
	var full_size := logical_size + Vector2(
		CLOUD_EXPAND_SIDE * 2.0,
		CLOUD_EXPAND_SIDE * 2.0 + CLOUD_EXPAND_TOP
	)
	var expand_progress: float = clampf(float(cloud.get("expand_progress", 1.0)), 0.0, 1.0)
	var eased_expand: float = 1.0 - pow(1.0 - expand_progress, 3.0)
	var scale: float = 0.1 + 0.9 * eased_expand
	return {
		"mode": "sustained" if expand_progress >= 1.0 else "expanding",
		# 원본: 타원 중심 = logical rect 중심(착지 중심). 풋프린트만 위로
		# CLOUD_EXPAND_TOP(138px)만큼 더 넓다 — 파티클 헤드룸.
		"ellipse_center": _as_vector2(cloud.get("center", Vector2(380.0, 120.0))),
		"ellipse_size": Vector2(full_size.x * 0.85, full_size.y * 0.65) * scale,
		"expand_progress": expand_progress,
		"eased_expand": eased_expand,
		"full_size": full_size,
		"fill_color": CLOUD_FILL_COLOR,
	}


func _draw_ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(36):
		var angle: float = TAU * float(index) / 36.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, color)


# --- bake-once 프리미티브 헬퍼 ---------------------------------------------
# 기하 계산은 호출부 한 벌만 유지하고, 프리미티브 수준에서만 baked 블릿과
# 원본 벡터 드로를 분기한다. AA 서클/아크 1개 = 수십 트라이앵글인 반면
# 텍스처 쿼드는 2개라, 각성 후 상시 오라(~134드로) + 극정호신 다크파티클
# (<=800드로)의 프리미티브 볼륨이 프레임드랍 주범이었다(2026-07-11 실측).


func _fill_circle(canvas: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	if _vfx_baked:
		var texture := VfxTextureCache.get_texture(VfxTextureCache.KEY_FLAT_DISC)
		if texture != null:
			var half: float = float(VfxTextureCache.FLAT_DISC_TEXTURE_SIZE) * 0.5 \
				* (radius / VfxTextureCache.FLAT_DISC_BAKE_RADIUS)
			canvas.draw_texture_rect(
				texture,
				Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0),
				false,
				color
			)
			return
	canvas.draw_circle(pos, radius, color)


# 얇은 풀서클 링. baked 경로의 선폭은 스케일 비례(~2px * radius/72)라
# 원본 draw_arc width 인자와 +-1px 오차가 있다 — 펄싱 글로우 링 용도 한정.
func _ring(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float,
	color: Color,
	width: float,
	point_count: int
) -> void:
	if _vfx_baked:
		var texture := VfxTextureCache.get_texture(VfxTextureCache.KEY_THIN_RING)
		if texture != null:
			var half: float = float(VfxTextureCache.THIN_RING_TEXTURE_SIZE) * 0.5 \
				* (radius / VfxTextureCache.THIN_RING_BAKE_RADIUS)
			canvas.draw_texture_rect(
				texture,
				Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0),
				false,
				color
			)
			return
	canvas.draw_arc(pos, radius, 0.0, TAU, point_count, color, width, true)


func _particle_rim(canvas: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	if _vfx_baked:
		var texture := VfxTextureCache.get_texture(VfxTextureCache.KEY_PARTICLE_RIM)
		if texture != null:
			var half: float = float(VfxTextureCache.PARTICLE_RIM_TEXTURE_SIZE) * 0.5 \
				* (radius / VfxTextureCache.PARTICLE_RIM_BAKE_RADIUS)
			canvas.draw_texture_rect(
				texture,
				Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0),
				false,
				color
			)
			return
	canvas.draw_arc(pos, radius, 0.0, TAU, 12, color, 1.0, true)


func _draw_aura(canvas: CanvasItem, aura: Dictionary, shake_offset: Vector2) -> void:
	if aura.is_empty() or not bool(aura.get("active", true)):
		return
	var center: Vector2 = _as_vector2(aura.get("center", Vector2(380.0, 70.0))) + shake_offset
	if str(aura.get("kind", "")) == "cloud_precast":
		# 원본 차크라 집중 오라(draw_stage8_cloud pre/down/up): 펄스하는 보라
		# 3중 원 + 궤도 화이트 스파크 3개.
		var pulse_sec: float = maxf(0.0, float(aura.get("pulse_sec", 0.0)))
		var pulse: float = 0.6 + 0.4 * sin(pulse_sec * 25.0)
		var chakra_radius: float = 35.0 * pulse
		canvas.draw_circle(center, chakra_radius + 2.0, CLOUD_CHAKRA_OUTER_COLOR)
		canvas.draw_circle(center, chakra_radius, CLOUD_CHAKRA_MID_COLOR)
		canvas.draw_circle(center, maxf(1.0, chakra_radius - 8.0), CLOUD_CHAKRA_CORE_COLOR)
		for index in range(3):
			var spark_angle: float = pulse_sec * 5.0 + float(index) * TAU / 3.0
			canvas.draw_circle(
				center + Vector2(cos(spark_angle), sin(spark_angle)) * (chakra_radius - 5.0),
				3.0,
				CLOUD_CHAKRA_SPARK_COLOR
			)
		return
	var radius: float = maxf(12.0, float(aura.get("radius", 72.0)))
	var alpha: float = clampf(float(aura.get("alpha", AURA_COLOR.a)), 0.0, 1.0)
	var color := AURA_COLOR
	color.a = alpha
	canvas.draw_arc(center, radius, 0.0, TAU, 40, color, 3.0, true)
	canvas.draw_arc(center, radius * 0.82, PI * 0.1, PI * 1.55, 32, Color(color.r, color.g, color.b, alpha * 0.45), 1.5, true)


func _draw_wind_aura(canvas: CanvasItem, aura: Dictionary, shake_offset: Vector2) -> void:
	if aura.is_empty() or not bool(aura.get("active", true)):
		return
	var center: Vector2 = _as_vector2(aura.get("center", Vector2(380.0, 70.0))) + shake_offset
	var radius: float = maxf(16.0, float(aura.get("radius", 90.0)))
	var strength: float = clampf(float(aura.get("strength", 0.0)), 0.0, 1.0)
	var ripple: float = clampf(float(aura.get("ripple_intensity", 0.0)), 0.0, 1.0)
	var elapsed_sec: float = maxf(0.0, float(aura.get("elapsed_sec", 0.0)))
	var depleted: bool = bool(aura.get("depleted", false))
	var superspeed: bool = bool(aura.get("superspeed", false))
	if depleted:
		# 원본은 소진 시 오라를 완전히 숨긴다. 재충전 피드백(희미한 회색 링 +
		# 진행 아크)만 Godot UX 개선으로 유지한다.
		canvas.draw_arc(
			center,
			radius,
			0.0,
			TAU,
			44,
			Color(WIND_AURA_DEPLETED_COLOR.r, WIND_AURA_DEPLETED_COLOR.g, WIND_AURA_DEPLETED_COLOR.b, 0.28),
			2.0,
			true
		)
		var recharge_total: float = maxf(0.001, float(aura.get("recharge_total", 10.0)))
		var recharge_remaining: float = clampf(
			float(aura.get("recharge_remaining", recharge_total)),
			0.0,
			recharge_total
		)
		var recharge_progress: float = 1.0 - recharge_remaining / recharge_total
		if recharge_progress > 0.001:
			canvas.draw_arc(
				center,
				radius + 3.0,
				-PI * 0.5,
				-PI * 0.5 + TAU * recharge_progress,
				40,
				Color(0.48, 0.88, 1.0, 0.66),
				3.0,
				true
			)
		return

	# 원본 draw_stage8_wind_aura 파리티: 글로우 링 6겹 + 회전 스트림 커브 +
	# 궤도 파티클(꼬리+화이트 림) + 외곽 펄싱 이중 링 + 리플 충격파.
	var glow_color := WIND_AURA_GLOW_ORANGE if superspeed else WIND_AURA_GLOW_CYAN
	var stream_color := WIND_AURA_STREAM_ORANGE if superspeed else WIND_AURA_STREAM_CYAN
	var ring_sub_color := WIND_AURA_RING_SUB_ORANGE if superspeed else WIND_AURA_RING_SUB_MINT
	var ripple_offset: float = ripple * 20.0 * sin(elapsed_sec * 20.0)

	var glow_radius: float = 70.0 + sin(elapsed_sec * 5.0) * 8.0 + ripple_offset
	if _vfx_baked and glow_radius > 1.0:
		# 글로우 6겹은 방사대칭이라 스택 전체를 1블릿으로 (원본 6 AA 아크).
		var stack_texture := VfxTextureCache.get_texture(VfxTextureCache.KEY_AURA_GLOW_STACK)
		var stack_half: float = float(VfxTextureCache.AURA_GLOW_TEXTURE_SIZE) * 0.5 \
			* (glow_radius / VfxTextureCache.AURA_GLOW_BAKE_RADIUS)
		canvas.draw_texture_rect(
			stack_texture,
			Rect2(center - Vector2(stack_half, stack_half), Vector2(stack_half, stack_half) * 2.0),
			false,
			Color(glow_color.r, glow_color.g, glow_color.b, (40.0 / 255.0) * strength)
		)
	else:
		_draw_wind_aura_glow_stack_vector(canvas, center, glow_radius, glow_color, strength)

	# Godot 강화: 세그먼트별 라인 대신 per-점 알파 그라데이션 polyline.
	var stream_count: int = maxi(2, int(6.0 * strength))
	for stream_index in range(stream_count):
		var base_angle: float = float(stream_index) / float(stream_count) * TAU + elapsed_sec * 3.0
		if ripple > 0.0:
			base_angle += sin(elapsed_sec * 15.0 + float(stream_index)) * ripple * 0.3
		var stream_points := PackedVector2Array()
		var stream_colors := PackedColorArray()
		for seg in range(9):
			var seg_angle: float = base_angle + float(seg) * 0.12
			var seg_radius: float = 45.0 + float(seg) * 8.0 + ripple_offset * 0.5
			stream_points.append(center + Vector2(cos(seg_angle), sin(seg_angle)) * seg_radius)
			stream_colors.append(Color(
				stream_color.r,
				stream_color.g,
				stream_color.b,
				(120.0 / 255.0) * (1.0 - float(seg) / 8.0) * strength
			))
		canvas.draw_polyline_colors(stream_points, stream_colors, 2.0, true)

	var particle_values: Variant = aura.get("particles", [])
	if particle_values is Array:
		var particles: Array = particle_values
		var visible_count: int = mini(int(float(particles.size()) * strength), particles.size())
		for particle_index in range(visible_count):
			var value: Variant = particles[particle_index]
			if not (value is Dictionary):
				continue
			var particle: Dictionary = value
			var angle: float = float(particle.get("angle", 0.0))
			var orbit_radius: float = float(particle.get("radius", radius * 0.72))
			if ripple > 0.0:
				orbit_radius += sin(elapsed_sec * 20.0 + float(particle.get("phase", 0.0))) * ripple * 15.0
			var size: float = maxf(1.0, float(particle.get("size", 3.0)) * strength)
			var particle_color := _as_color(particle.get("color", glow_color))
			if superspeed:
				var orange: Color = SUPERSPEED_PARTICLE_ORANGES[
					(particle_index * 7 + int(float(particle.get("base_radius", 64.0))))
					% SUPERSPEED_PARTICLE_ORANGES.size()
				]
				particle_color = Color(orange.r, orange.g, orange.b, particle_color.a)
			var particle_alpha: float = particle_color.a * strength
			var orbit_speed: float = float(particle.get("speed", 0.03))
			var tail_count: int = maxi(1, int(3.0 * strength))
			for tail in range(1, tail_count + 1):
				var tail_angle: float = angle - orbit_speed * float(tail) * 3.0
				var tail_radius: float = orbit_radius - float(tail) * 2.0
				_fill_circle(
					canvas,
					center + Vector2(cos(tail_angle), sin(tail_angle)) * tail_radius,
					maxf(1.0, size - float(tail)),
					Color(
						particle_color.r,
						particle_color.g,
						particle_color.b,
						particle_alpha * (1.0 - float(tail) / float(tail_count + 1)) * 0.5
					)
				)
			var pos := center + Vector2(cos(angle), sin(angle)) * orbit_radius
			_fill_circle(canvas, pos, size, Color(particle_color.r, particle_color.g, particle_color.b, particle_alpha))
			if size > 1.5:
				_particle_rim(canvas, pos, size, Color(1.0, 1.0, 1.0, particle_alpha * 0.5))

	var outer_ring_radius: float = (90.0 + sin(elapsed_sec * 4.0) * 5.0 + ripple_offset) * (0.7 + 0.3 * strength)
	var ring_alpha: float = (60.0 + 30.0 * sin(elapsed_sec * 6.0)) / 255.0 * strength
	if ring_alpha > 0.02:
		_ring(
			canvas,
			center,
			outer_ring_radius,
			Color(glow_color.r, glow_color.g, glow_color.b, ring_alpha),
			2.0,
			48
		)
		_ring(
			canvas,
			center,
			outer_ring_radius + 5.0,
			Color(ring_sub_color.r, ring_sub_color.g, ring_sub_color.b, ring_alpha * 0.5),
			1.0,
			48
		)

	if ripple > 0.1:
		_ring(
			canvas,
			center,
			radius * (1.0 + ripple * 0.5),
			Color(1.0, 1.0, 1.0, ripple * 100.0 / 255.0),
			3.0,
			48
		)


# 프리웜 전 로딩 프레임 전용 벡터 폴백 (원본 글로우 스택 6 AA 아크).
func _draw_wind_aura_glow_stack_vector(
	canvas: CanvasItem,
	center: Vector2,
	glow_radius: float,
	glow_color: Color,
	strength: float
) -> void:
	for ring_step in range(6):
		var ring_radius: float = glow_radius - float(ring_step) * 5.0
		if ring_radius <= 1.0:
			continue
		var glow_alpha: float = (40.0 / 255.0) * (1.0 - float(ring_step) * 5.0 / 30.0) * strength
		canvas.draw_arc(
			center,
			ring_radius,
			0.0,
			TAU,
			40,
			Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha),
			2.0,
			true
		)


func _draw_wind_burst_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO)) + shake_offset
	var size: float = maxf(1.0, float(particle.get("size", 3.0)))
	var rotation: float = float(particle.get("rotation", 0.0))
	var alpha: float = clampf(float(particle.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= 0.001:
		return
	var color := _as_color(particle.get("color", WIND_AURA_COLOR))
	color.a *= alpha
	# 원본 draw_stage8_wind_burst 파리티: 회전하는 4각 다이아몬드 폴리곤 +
	# 화이트 외곽선(알파 절반). 고정 형상 강체 회전이라 삼각분할 항상 유효.
	var points := PackedVector2Array()
	for index in range(4):
		var point_angle: float = rotation + float(index) * PI * 0.5
		var dist: float = size if index % 2 == 0 else size * 0.4
		points.append(pos + Vector2(cos(point_angle), sin(point_angle)) * dist)
	canvas.draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(1.0, 1.0, 1.0, color.a * 0.5), 1.0, true)


func _draw_slice5_cinematic_overlay(canvas: CanvasItem, context: Dictionary) -> void:
	var freeze_reason: String = str(context.get("stage7_akamu_gameplay_freeze_reason", ""))
	var awakening_pending: bool = bool(context.get("stage7_akamu_awakening_intro_pending", false))
	if awakening_pending or freeze_reason == "awakening":
		canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), AWAKENING_OVERLAY_COLOR)
		_draw_centered_text(canvas, "초각성 준비...", 356.0, 32, Color(0.72, 0.94, 1.0, 1.0))
		var freeze_remaining: float = maxf(
			0.0,
			float(context.get("stage7_akamu_gameplay_freeze_remaining", 0.0))
		)
		if freeze_remaining > 0.0:
			_draw_centered_text(canvas, "%.1f" % freeze_remaining, 392.0, 16, Color(0.72, 0.80, 0.92, 0.88))
	var superspeed_active: bool = bool(context.get("stage7_akamu_superspeed_active", false))
	var text_remaining: float = maxf(0.0, float(context.get("stage7_akamu_superspeed_text_remaining", 0.0)))
	if not superspeed_active and text_remaining <= 0.0:
		return
	# 원본 파리티: 극정호신 지속 내내 화면 무드 틴트 + 중앙 타이틀(노랑+그림자).
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(10.0 / 255.0, 10.0 / 255.0, 20.0 / 255.0, 0.16))
	if freeze_reason == "superspeed":
		# 발동 350ms 정지 연출 동안 추가 암전 (원본 black alpha 120).
		canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.0, 0.0, 0.0, 120.0 / 255.0))
	var title_center_y: float = FIELD_SIZE.y * 0.5 - 40.0
	_draw_centered_text(canvas, "극정호신!", title_center_y + 4.0, 40, SUPERSPEED_TITLE_SHADOW_COLOR, Vector2(4.0, 0.0))
	_draw_centered_text(canvas, "극정호신!", title_center_y, 40, SUPERSPEED_TITLE_COLOR)
	if not superspeed_active:
		return
	# 원본 파리티: 우상단 220x14 노란 타이머 바 + 좌측 라벨.
	var remaining: float = maxf(0.0, float(context.get("stage7_akamu_superspeed_remaining", 0.0)))
	var duration: float = maxf(0.001, float(context.get("stage7_akamu_superspeed_duration", 10.0)))
	var bar_size := Vector2(220.0, 14.0)
	var bar_pos := Vector2(FIELD_SIZE.x - bar_size.x - 16.0, 16.0)
	canvas.draw_rect(Rect2(bar_pos - Vector2(4.0, 4.0), bar_size + Vector2(8.0, 8.0)), Color(15.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 1.0))
	canvas.draw_rect(Rect2(bar_pos - Vector2(4.0, 4.0), bar_size + Vector2(8.0, 8.0)), Color(70.0 / 255.0, 70.0 / 255.0, 90.0 / 255.0, 1.0), false, 2.0)
	var fill_ratio: float = clampf(remaining / duration, 0.0, 1.0)
	if fill_ratio > 0.0:
		canvas.draw_rect(Rect2(bar_pos, Vector2(bar_size.x * fill_ratio, bar_size.y)), SUPERSPEED_BAR_FILL_COLOR)
	canvas.draw_rect(Rect2(bar_pos, bar_size), Color(60.0 / 255.0, 40.0 / 255.0, 0.0, 1.0), false, 2.0)
	var font := ThemeDB.fallback_font
	if font != null:
		var label := "극정호신"
		var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
		canvas.draw_string(
			font,
			Vector2(bar_pos.x - label_size.x - 8.0, bar_pos.y + bar_size.y * 0.5 + label_size.y * 0.30),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			SUPERSPEED_TITLE_COLOR
		)


func _draw_centered_text(
	canvas: CanvasItem,
	label: String,
	baseline_y: float,
	font_size: int,
	color: Color,
	offset: Vector2 = Vector2.ZERO
) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	canvas.draw_string(
		font,
		Vector2(0.0, baseline_y) + offset + Vector2(2.0, 2.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		FIELD_SIZE.x,
		font_size,
		Color(0.0, 0.0, 0.0, color.a * 0.78)
	)
	canvas.draw_string(
		font,
		Vector2(0.0, baseline_y) + offset,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		FIELD_SIZE.x,
		font_size,
		color
	)


func _draw_boss_frame_ghost(
	canvas: CanvasItem,
	center: Vector2,
	draw_size: Vector2,
	modulate: Color
) -> bool:
	var texture_value: Variant = _ghost_frame_spec.get("texture", null)
	if not (texture_value is Texture2D):
		return false
	var source_value: Variant = _ghost_frame_spec.get("source_rect", null)
	if not (source_value is Rect2):
		return false
	var source_rect: Rect2 = source_value
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	canvas.draw_texture_rect_region(
		texture_value as Texture2D,
		Rect2(center - draw_size * 0.5, draw_size),
		source_rect,
		modulate,
		false,
		true
	)
	return true


func _draw_superspeed_silhouette(
	canvas: CanvasItem,
	payload: Dictionary,
	shake_offset: Vector2,
	is_trail: bool
) -> void:
	if not is_trail and float(payload.get("delay_remaining_sec", 0.0)) > 0.0:
		return
	var center: Vector2 = _as_vector2(payload.get("center", payload.get("pos", Vector2.ZERO))) \
		+ Vector2(0.0, ESCAPE_VISUAL_CENTER_Y_OFFSET) \
		+ shake_offset
	var payload_size: Vector2 = _as_vector2(payload.get("size", Vector2(100.0, 40.0)))
	var visual_scale: float = clampf(float(payload.get("visual_scale", 1.0)), 0.2, 1.0)
	var draw_size := _resolve_escape_draw_size(payload_size) * visual_scale
	var alpha: float = clampf(float(payload.get("alpha", 0.25)), 0.0, 1.0)
	if alpha <= 0.001:
		return
	# 원본 파리티: trail은 보스 이미지의 어두운 보라 고스트(RGB_SUB 근사),
	# 환영 분신은 주황 ADD 틴트 고스트(모듈레이트 근사).
	var ghost_modulate := Color(0.55, 0.45, 0.65, alpha * 0.85) if is_trail \
		else Color(1.0, 0.72, 0.42, alpha)
	if _draw_boss_frame_ghost(canvas, center, GHOST_SPRITE_SIZE * visual_scale, ghost_modulate):
		return
	var body_rect := Rect2(center - draw_size * 0.5, draw_size)
	var body_color := Color(0.08, 0.02, 0.11, alpha * (0.30 if is_trail else 0.58))
	var edge_color := Color(1.0, 0.28, 0.06, alpha * (0.24 if is_trail else 0.52))
	canvas.draw_rect(body_rect, body_color)
	canvas.draw_rect(body_rect.grow(1.5), edge_color, false, 1.5)
	canvas.draw_circle(
		center + Vector2(0.0, -draw_size.y * 0.20),
		maxf(5.0, minf(draw_size.x, draw_size.y) * 0.22),
		Color(0.12, 0.02, 0.15, alpha * (0.36 if is_trail else 0.64))
	)
	if not is_trail:
		canvas.draw_line(
			center + Vector2(-draw_size.x * 0.18, -draw_size.y * 0.08),
			center + Vector2(draw_size.x * 0.18, -draw_size.y * 0.08),
			edge_color,
			2.0,
			true
		)


func _draw_superspeed_dash_wake(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2
) -> void:
	if not bool(context.get("stage7_akamu_superspeed_active", false)):
		return
	var dash_direction: int = clampi(
		int(context.get("stage7_akamu_superspeed_dash_direction", 0)),
		-1,
		1
	)
	if dash_direction == 0:
		return
	var aura := _as_dictionary(context.get("stage7_akamu_wind_aura", {}))
	var fallback_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)))
	var fallback_center: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0))) \
		+ fallback_size * 0.5
	var center: Vector2 = _as_vector2(aura.get("center", fallback_center)) + shake_offset
	var backward := Vector2(float(-dash_direction), 0.0)
	for index in range(3):
		var y_offset: float = (float(index) - 1.0) * 15.0
		var start := center + Vector2(float(-dash_direction) * 22.0, y_offset)
		var end := start + backward * (48.0 + float(index) * 15.0)
		canvas.draw_line(
			start,
			end,
			Color(1.0, 0.25, 0.06, 0.34 - float(index) * 0.07),
			3.0 - float(index) * 0.5,
			true
		)


func _draw_superspeed_dark_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO)) + shake_offset
	var radius: float = maxf(1.0, float(particle.get("radius", 2.0)))
	var max_life: float = maxf(1.0, float(particle.get("max_life_frames", 1.0)))
	var life: float = clampf(float(particle.get("life_frames", 0.0)), 0.0, max_life)
	var life_ratio: float = clampf(life / max_life, 0.0, 1.0)
	if life_ratio <= 0.001:
		return
	var color := _as_color(particle.get("color", Color(0.08, 0.02, 0.10, 1.0)))
	# 원본 파리티(예산 절충): 어두운 불꽃 — 글로우 2겹 + 코어 + 간헐 스파크.
	# max 200개 x 극정호신 10초 윈도우 한정. baked 경로는 글로우+코어 합성을
	# 1블릿으로 (원본 3 AA 서클), 폴백은 벡터 헬퍼가 동일 프로파일을 그린다.
	if _vfx_baked:
		var flame_texture := VfxTextureCache.get_texture(VfxTextureCache.KEY_DARK_FLAME)
		var flame_half: float = float(VfxTextureCache.DARK_FLAME_TEXTURE_SIZE) * 0.5 \
			* (radius / VfxTextureCache.DARK_FLAME_CORE_BAKE_RADIUS)
		canvas.draw_texture_rect(
			flame_texture,
			Rect2(pos - Vector2(flame_half, flame_half), Vector2(flame_half, flame_half) * 2.0),
			false,
			Color(color.r, color.g, color.b, life_ratio)
		)
	else:
		_draw_superspeed_dark_flame_vector(canvas, pos, radius, color, life_ratio)
	# 원본의 random 30% 스파크를 결정적 노이즈로 치환(VFX 시드 룰).
	if fmod(pos.x * 3.7 + life * 11.0, 10.0) < 3.0:
		_fill_circle(
			canvas,
			pos,
			maxf(1.0, radius * 0.5),
			Color(
				minf(1.0, color.r + 80.0 / 255.0),
				minf(1.0, color.g + 30.0 / 255.0),
				minf(1.0, color.b + 80.0 / 255.0),
				(150.0 / 255.0) * life_ratio
			)
		)


# 프리웜 전 로딩 프레임 전용 벡터 폴백 (원본 글로우 2겹 + 코어 서클).
func _draw_superspeed_dark_flame_vector(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float,
	color: Color,
	life_ratio: float
) -> void:
	for layer in [[1.8, 0.20], [1.3, 0.32]]:
		var glow_radius: float = radius * float(layer[0])
		if glow_radius <= 0.5:
			continue
		canvas.draw_circle(
			pos,
			glow_radius,
			Color(color.r, color.g, color.b, (180.0 / 255.0) * float(layer[1]) * life_ratio)
		)
	canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, (200.0 / 255.0) * life_ratio))


func _draw_afterimage(canvas: CanvasItem, afterimage: Dictionary, shake_offset: Vector2) -> void:
	var center: Vector2 = _as_vector2(afterimage.get("center", afterimage.get("pos", Vector2.ZERO)))
	var size: Vector2 = _as_vector2(afterimage.get("size", Vector2(72.0, 38.0)))
	var alpha: float = clampf(float(afterimage.get("alpha", 0.2)), 0.0, 1.0)
	if alpha <= 0.001:
		return
	if str(afterimage.get("kind", "")) == "escape":
		_draw_escape_silhouette(
			canvas,
			center + Vector2(0.0, ESCAPE_VISUAL_CENTER_Y_OFFSET) + shake_offset,
			size,
			alpha,
			clampf(float(afterimage.get("progress", 0.0)), 0.0, 1.0),
			int(afterimage.get("index", 0)),
			false,
			clampf(float(afterimage.get("visual_scale", 1.0)), 0.2, 1.0)
		)
		return
	canvas.draw_rect(
		Rect2(center + shake_offset - size * 0.5, size),
		Color(0.42, 0.72, 0.92, alpha)
	)


func _draw_hologram(canvas: CanvasItem, hologram: Dictionary, shake_offset: Vector2) -> void:
	if hologram.is_empty() or not bool(hologram.get("active", true)):
		return
	var alpha: float = clampf(float(hologram.get("alpha", 0.0)), 0.0, 1.0)
	if alpha <= 0.001:
		return
	var center: Vector2 = _as_vector2(hologram.get("center", Vector2.ZERO)) \
		+ Vector2(0.0, ESCAPE_VISUAL_CENTER_Y_OFFSET) \
		+ shake_offset
	var size: Vector2 = _as_vector2(hologram.get("size", Vector2(100.0, 40.0)))
	var total_sec: float = maxf(0.001, float(hologram.get("total_sec", 0.4)))
	var remaining_sec: float = clampf(
		float(hologram.get("remaining_sec", total_sec)),
		0.0,
		total_sec
	)
	var progress: float = 1.0 - remaining_sec / total_sec
	_draw_escape_silhouette(
		canvas,
		center,
		size,
		alpha,
		progress,
		0,
		true,
		clampf(float(hologram.get("visual_scale", 1.0)), 0.2, 1.0)
	)


func _draw_escape_silhouette(
	canvas: CanvasItem,
	center: Vector2,
	payload_size: Vector2,
	alpha: float,
	progress: float,
	index: int,
	is_hologram: bool,
	visual_scale: float
) -> void:
	var draw_size := _resolve_escape_draw_size(payload_size) * visual_scale
	# 원본 파리티: 탈출 잔상은 보스 이미지 알파 고스트, 홀로그램 허수아비도
	# 보스 이미지 페이드(여기에 Godot 강화로 시안 틴트 + 스캔라인 유지).
	var sprite_modulate := Color(0.75, 0.95, 1.0, alpha * 0.9) if is_hologram \
		else Color(0.92, 0.98, 1.0, alpha)
	if _draw_boss_frame_ghost(canvas, center, GHOST_SPRITE_SIZE * visual_scale, sprite_modulate):
		if is_hologram:
			var sprite_rect := Rect2(center - GHOST_SPRITE_SIZE * visual_scale * 0.5, GHOST_SPRITE_SIZE * visual_scale)
			for stripe_index in range(3):
				var stripe_t: float = (float(stripe_index) + 1.0) / 4.0
				var stripe_y: float = sprite_rect.position.y + sprite_rect.size.y * stripe_t
				var stripe_shift: float = sin(progress * 25.0 + float(stripe_index) * 2.1) * 5.0
				canvas.draw_line(
					Vector2(sprite_rect.position.x + stripe_shift, stripe_y),
					Vector2(sprite_rect.end.x + stripe_shift, stripe_y),
					Color(0.70, 0.96, 1.0, alpha * 0.46),
					1.5,
					true
				)
		return
	var body_rect := Rect2(center - draw_size * 0.5, draw_size)
	var color := HOLOGRAM_COLOR if is_hologram else ESCAPE_COLOR
	color.a = alpha * (0.58 if is_hologram else 0.48)
	canvas.draw_rect(body_rect, color)
	var hood_radius: float = maxf(8.0, minf(draw_size.x, draw_size.y) * 0.22)
	var hood_color := Color(0.16, 0.38, 0.52, alpha * (0.68 if is_hologram else 0.56))
	canvas.draw_circle(center + Vector2(0.0, -draw_size.y * 0.20), hood_radius, hood_color)
	var mask_rect := Rect2(
		center + Vector2(-draw_size.x * 0.28, -draw_size.y * 0.20),
		Vector2(draw_size.x * 0.56, draw_size.y * 0.18)
	)
	canvas.draw_rect(mask_rect, Color(0.66, 0.90, 1.0, alpha * 0.54))
	var outline_alpha: float = alpha * (0.58 + 0.22 * sin(progress * 18.0 + float(index) * 1.7))
	canvas.draw_rect(
		body_rect.grow(2.0 + progress * 2.0),
		Color(0.54, 0.90, 1.0, outline_alpha),
		false,
		2.0
	)
	var stripe_count := 3 if is_hologram else 2
	for stripe_index in range(stripe_count):
		var stripe_t: float = (float(stripe_index) + 1.0) / float(stripe_count + 1)
		var stripe_y: float = body_rect.position.y + body_rect.size.y * stripe_t
		var stripe_shift: float = sin(progress * 25.0 + float(stripe_index + index) * 2.1) * 5.0
		canvas.draw_line(
			Vector2(body_rect.position.x + stripe_shift, stripe_y),
			Vector2(body_rect.end.x + stripe_shift, stripe_y),
			Color(0.70, 0.96, 1.0, alpha * (0.46 if is_hologram else 0.32)),
			1.5,
			true
		)


func _resolve_escape_draw_size(payload_size: Vector2) -> Vector2:
	var safe_size := Vector2(maxf(24.0, payload_size.x), maxf(18.0, payload_size.y))
	if safe_size.y <= safe_size.x * 0.62:
		return Vector2(safe_size.x * 1.12, maxf(safe_size.y * 2.30, safe_size.x * 0.82))
	return safe_size


func _draw_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO)) + shake_offset
	var radius: float = maxf(1.0, float(particle.get("radius", 2.0)))
	var color: Color = _as_color(particle.get("color", Color(0.44, 0.64, 0.88, 0.5)))
	canvas.draw_circle(pos, radius, color)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color(0.44, 0.64, 0.88, 0.5)


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
