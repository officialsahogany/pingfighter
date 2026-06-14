extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage5HongryunPillarBackgroundPayloadFactory := preload("res://scripts/stages/stage5/stage5_hongryun_pillar_background_payload_factory.gd")

const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_layered_cyber_base_imagegen_v3.png"
const INFERNO_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_center_background_imagegen_v1.png"

const INFERNO_FADE_IN_SEC := 0.40
const INFERNO_FADE_OUT_SEC := 0.70
const SPIRAL_BURST_LIFETIME_SEC := 0.72
const FIRE_IMPACT_LIFETIME_SEC := 0.42
const MAX_SPIRAL_BURSTS := 6
const MAX_FIRE_IMPACTS := 12
const LOD_ACTIVE_THRESHOLD := 0.7
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.6
const SPIRAL_BURST_ARM_COUNT := 4
const SPIRAL_BURST_ARM_COUNT_LOD := 3
const SPIRAL_BURST_ARM_COUNT_SEVERE_LOD := 2
const SPIRAL_BURST_PRIMARY_SEGMENTS := 32
const SPIRAL_BURST_PRIMARY_SEGMENTS_LOD := 22
const SPIRAL_BURST_PRIMARY_SEGMENTS_SEVERE_LOD := 14
const SPIRAL_BURST_SECONDARY_SEGMENTS := 24
const SPIRAL_BURST_SECONDARY_SEGMENTS_LOD := 14
const FIRE_IMPACT_OUTER_SEGMENTS := 40
const FIRE_IMPACT_OUTER_SEGMENTS_LOD := 28
const FIRE_IMPACT_OUTER_SEGMENTS_SEVERE_LOD := 20
const FIRE_IMPACT_INNER_SEGMENTS := 24
const FIRE_IMPACT_INNER_SEGMENTS_LOD := 14
const VIGNETTE_STEPS := 7
const VIGNETTE_STEPS_LOD := 4
const VIGNETTE_STEPS_SEVERE_LOD := 3

var base_texture: Texture2D = null
var inferno_texture: Texture2D = null
var textures_loaded := false
var inferno_mode_active := false
var inferno_blend := 0.0
var time_sec := 0.0
var _last_draw_msec := 0
var _spiral_bursts: Array = []
var _fire_impacts: Array = []
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded:
		return true
	match _prewarm_step_index:
		0:
			base_texture = ProjectResourceLoader.load_texture(BASE_TEXTURE_PATH)
		1:
			inferno_texture = ProjectResourceLoader.load_texture(INFERNO_TEXTURE_PATH)
		_:
			textures_loaded = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func reset() -> void:
	inferno_mode_active = false
	inferno_blend = 0.0
	time_sec = 0.0
	_last_draw_msec = 0
	_spiral_bursts.clear()
	_fire_impacts.clear()


func update(delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	_advance_visual_time(clampf(delta, 0.0, 0.1))


func trigger_spiral_burst(inferno_active: bool = false) -> void:
	_spiral_bursts.append(Stage5HongryunPillarBackgroundPayloadFactory.build_spiral_burst(
		_spiral_bursts.size(),
		time_sec,
		SPIRAL_BURST_LIFETIME_SEC,
		inferno_active
	))
	while _spiral_bursts.size() > MAX_SPIRAL_BURSTS:
		_spiral_bursts.pop_front()


func set_inferno_mode(active: bool) -> void:
	inferno_mode_active = active


func add_fire_impact(x: float, y: float) -> void:
	_fire_impacts.append(Stage5HongryunPillarBackgroundPayloadFactory.build_fire_impact(
		Vector2(x, y),
		FIRE_IMPACT_LIFETIME_SEC
	))
	while _fire_impacts.size() > MAX_FIRE_IMPACTS:
		_fire_impacts.pop_front()


func is_inferno_mode_active() -> bool:
	return inferno_mode_active or inferno_blend > 0.02


func get_inferno_blend() -> float:
	return inferno_blend


func get_debug_snapshot() -> Dictionary:
	_ensure_textures()
	return {
		"base_texture_loaded": base_texture != null,
		"inferno_texture_loaded": inferno_texture != null,
		"inferno_mode_active": inferno_mode_active,
		"inferno_blend": inferno_blend,
		"spiral_burst_count": _spiral_bursts.size(),
		"fire_impact_count": _fire_impacts.size(),
	}


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> bool:
	if canvas == null:
		return false
	_ensure_textures()
	_advance_visual_time(_consume_draw_delta())
	var target_size := view_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = game_offset * 2.0 + game_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = Vector2(760.0, 750.0)
	var full_rect := Rect2(Vector2.ZERO, target_size)
	_draw_base(canvas, full_rect)
	_draw_inferno_overlay(canvas, full_rect)
	_draw_pillar_heat_tint(canvas, full_rect, game_offset, game_size, _quality_scale)
	_draw_spiral_bursts(canvas, full_rect, game_offset, game_size, _quality_scale)
	_draw_fire_impacts(canvas, game_offset, _quality_scale)
	_draw_vignette(canvas, full_rect, _quality_scale)
	return true


func draw_pillar_background_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> void:
	if canvas == null:
		return
	var target_size := view_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = game_offset * 2.0 + game_size
	_draw_spiral_bursts(canvas, Rect2(Vector2.ZERO, target_size), game_offset, game_size, _quality_scale)


func _ensure_textures() -> void:
	if textures_loaded:
		return
	prewarm_assets()


func _advance_visual_time(delta: float) -> void:
	time_sec += delta
	var target := 1.0 if inferno_mode_active else 0.0
	var fade_sec := INFERNO_FADE_IN_SEC if inferno_mode_active else INFERNO_FADE_OUT_SEC
	inferno_blend = _move_toward_float(inferno_blend, target, delta / maxf(0.001, fade_sec))
	_tick_transient_list(_spiral_bursts, delta)
	_tick_transient_list(_fire_impacts, delta)


func _consume_draw_delta() -> float:
	var now := Time.get_ticks_msec()
	if _last_draw_msec <= 0:
		_last_draw_msec = now
		return 1.0 / 60.0
	var delta := clampf(float(now - _last_draw_msec) / 1000.0, 0.0, 0.1)
	_last_draw_msec = now
	return delta


func _tick_transient_list(values: Array, delta: float) -> void:
	var next_values: Array = []
	for value in values:
		if not (value is Dictionary):
			continue
		var item: Dictionary = value
		item["age"] = float(item.get("age", 0.0)) + delta
		if float(item.get("age", 0.0)) < float(item.get("life", 0.1)):
			next_values.append(item)
	values.assign(next_values)


func _draw_base(canvas: CanvasItem, rect: Rect2) -> void:
	if base_texture != null:
		canvas.draw_texture_rect(base_texture, rect, false, Color(0.76, 0.54, 0.50, 1.0))
		return
	canvas.draw_rect(rect, Color(0.12, 0.045, 0.035, 1.0))
	for idx in range(16):
		var y := rect.position.y + float(idx) * rect.size.y / 16.0
		var tone := 0.025 + float(idx) * 0.004
		canvas.draw_rect(Rect2(rect.position.x, y, rect.size.x, rect.size.y / 16.0 + 1.0), Color(0.10 + tone, 0.025, 0.020, 1.0))


func _draw_inferno_overlay(canvas: CanvasItem, rect: Rect2) -> void:
	if inferno_blend <= 0.001:
		return
	if inferno_texture != null:
		canvas.draw_texture_rect(inferno_texture, rect, false, Color(1.0, 0.55, 0.55, 0.85 * inferno_blend))
	canvas.draw_rect(rect, Color(0.72, 0.04, 0.015, 0.16 * inferno_blend))


func _draw_pillar_heat_tint(canvas: CanvasItem, rect: Rect2, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	var pillar_alpha := 0.18 + inferno_blend * 0.18
	var severe_lod := _is_severe_lod(quality_scale)
	var left_rect := Rect2(rect.position, Vector2(maxf(0.0, game_offset.x), rect.size.y))
	var right_x := game_offset.x + game_size.x
	var right_rect := Rect2(Vector2(right_x, rect.position.y), Vector2(maxf(0.0, rect.size.x - right_x), rect.size.y))
	for side_rect in [left_rect, right_rect]:
		if side_rect.size.x <= 0.0:
			continue
		canvas.draw_rect(side_rect, Color(0.20, 0.045, 0.025, pillar_alpha))
		if not severe_lod:
			canvas.draw_rect(side_rect.grow(-4.0), Color(0.58, 0.10, 0.045, 0.06 + inferno_blend * 0.07), false, 2.0)


func _draw_spiral_bursts(canvas: CanvasItem, rect: Rect2, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	if _spiral_bursts.is_empty():
		return
	var center := game_offset + game_size * 0.5
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		center = rect.get_center()
	var arm_count: int = _get_lod_count(SPIRAL_BURST_ARM_COUNT, SPIRAL_BURST_ARM_COUNT_LOD, SPIRAL_BURST_ARM_COUNT_SEVERE_LOD, quality_scale)
	var primary_segments: int = _get_lod_count(SPIRAL_BURST_PRIMARY_SEGMENTS, SPIRAL_BURST_PRIMARY_SEGMENTS_LOD, SPIRAL_BURST_PRIMARY_SEGMENTS_SEVERE_LOD, quality_scale)
	var secondary_segments: int = SPIRAL_BURST_SECONDARY_SEGMENTS_LOD if quality_scale <= LOD_ACTIVE_THRESHOLD else SPIRAL_BURST_SECONDARY_SEGMENTS
	var severe_lod := _is_severe_lod(quality_scale)
	for value in _spiral_bursts:
		if not (value is Dictionary):
			continue
		var burst: Dictionary = value
		var age := float(burst.get("age", 0.0))
		var life := maxf(0.001, float(burst.get("life", SPIRAL_BURST_LIFETIME_SEC)))
		var progress := clampf(age / life, 0.0, 1.0)
		var intensity := float(burst.get("intensity", 1.0))
		var phase := float(burst.get("phase", 0.0))
		var alpha := (1.0 - progress) * (0.38 + inferno_blend * 0.22)
		var radius := (54.0 + progress * 160.0) * intensity
		for arm in range(arm_count):
			var start := phase + float(arm) * TAU / float(maxi(1, arm_count)) + progress * TAU * 1.25
			canvas.draw_arc(center, radius + float(arm) * 10.0, start, start + PI * 0.72, primary_segments, Color(1.0, 0.28, 0.10, alpha), 2.4, true)
			if not severe_lod:
				canvas.draw_arc(center, radius * 0.68 + float(arm) * 7.0, -start, -start + PI * 0.48, secondary_segments, Color(1.0, 0.78, 0.22, alpha * 0.52), 1.4, true)


func _draw_fire_impacts(canvas: CanvasItem, game_offset: Vector2, quality_scale: float) -> void:
	var outer_segments: int = _get_lod_count(FIRE_IMPACT_OUTER_SEGMENTS, FIRE_IMPACT_OUTER_SEGMENTS_LOD, FIRE_IMPACT_OUTER_SEGMENTS_SEVERE_LOD, quality_scale)
	var inner_segments: int = FIRE_IMPACT_INNER_SEGMENTS_LOD if quality_scale <= LOD_ACTIVE_THRESHOLD else FIRE_IMPACT_INNER_SEGMENTS
	var severe_lod := _is_severe_lod(quality_scale)
	for value in _fire_impacts:
		if not (value is Dictionary):
			continue
		var impact: Dictionary = value
		var pos := _as_vector2(impact.get("pos", Vector2.ZERO), Vector2.ZERO) + game_offset
		var age := float(impact.get("age", 0.0))
		var life := maxf(0.001, float(impact.get("life", FIRE_IMPACT_LIFETIME_SEC)))
		var progress := clampf(age / life, 0.0, 1.0)
		var alpha := 1.0 - progress
		var radius := (18.0 + progress * 46.0) * float(impact.get("scale", 1.0))
		canvas.draw_circle(pos, radius * 0.45, Color(1.0, 0.16, 0.04, 0.18 * alpha))
		canvas.draw_arc(pos, radius, 0.0, TAU, outer_segments, Color(1.0, 0.38, 0.12, 0.72 * alpha), 3.0, true)
		if not severe_lod:
			canvas.draw_arc(pos, radius * 0.62, -time_sec * 7.0, -time_sec * 7.0 + PI, inner_segments, Color(1.0, 0.86, 0.22, 0.52 * alpha), 1.8, true)


func _draw_vignette(canvas: CanvasItem, rect: Rect2, quality_scale: float) -> void:
	var alpha := 0.10 + inferno_blend * 0.30
	if alpha <= 0.001:
		return
	var steps := _get_lod_count(VIGNETTE_STEPS, VIGNETTE_STEPS_LOD, VIGNETTE_STEPS_SEVERE_LOD, quality_scale)
	for idx in range(steps):
		var t := float(idx + 1) / float(steps)
		var grow := rect.size.length() * 0.015 * float(idx)
		var color := Color(0.24 + inferno_blend * 0.36, 0.0, 0.0, alpha * t * 0.22)
		canvas.draw_rect(rect.grow(-grow), color, false, 10.0 + float(idx) * 4.0, true)


func _move_toward_float(value: float, target: float, delta: float) -> float:
	if value < target:
		return minf(target, value + delta)
	if value > target:
		return maxf(target, value - delta)
	return value


func _get_lod_count(normal_count: int, lod_count: int, severe_count: int, quality_scale: float) -> int:
	if quality_scale <= SEVERE_LOD_ACTIVE_THRESHOLD:
		return severe_count
	if quality_scale <= LOD_ACTIVE_THRESHOLD:
		return lod_count
	return normal_count


func _is_severe_lod(quality_scale: float) -> bool:
	return quality_scale <= SEVERE_LOD_ACTIVE_THRESHOLD


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
