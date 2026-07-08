extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const InfernoChargeFxHost := preload("res://scripts/stages/stage5/stage5_hongryun_inferno_charge_fx_host.gd")
const InfernoTrailFxHost := preload("res://scripts/stages/stage5/stage5_hongryun_inferno_trail_fx_host.gd")
const InfernoBurstFxHost := preload("res://scripts/stages/stage5/stage5_hongryun_inferno_burst_fx_host.gd")

const FIREBALL_ATLAS_PATH := "res://assets/sprites/hud/stage5_hongryun_fireball_sheet_autosprite_v1.png"
const FIREBALL_FALLBACK_ATLAS_PATH := "res://assets/sprites/hud/stage5_hongryun_motion_sprites_imagegen_v1.png"
const TRAIL_HEAD_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_layered_cyber_base_imagegen_v1.png"
const TRAIL_NODE_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_layered_cyber_base_imagegen_v2.png"
const FIRE_MACHINE_DRAGON_HEAD_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_dragon_head_sheet_imagegen_v3_16f.png"
const CENTER_BORDER_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_center_border_imagegen_v1.png"
const INFERNO_CHARGE_FX_HOST_NAME := "Stage5HongryunInfernoChargeFxHost"
const INFERNO_TRAIL_FX_HOST_NAME := "Stage5HongryunInfernoTrailFxHost"
const INFERNO_BURST_FX_HOST_NAME := "Stage5HongryunInfernoBurstFxHost"
const CENTER_BORDER_IMAGEGEN_DRAW_ENABLED := true
const CENTER_BORDER_FALLBACK_STROKE := 2.0
const CENTER_BORDER_COLLISION_EDGE_BAND_PX := 13.0
# Below this quality LOD we skip the node-backed shader/particle FX
# entirely and rely on the direct-draw aura fallback only.
const INFERNO_CHARGE_NODE_FX_QUALITY_GATE := 0.45
const INFERNO_TRAIL_NODE_FX_QUALITY_GATE := 0.45
const INFERNO_BURST_NODE_FX_QUALITY_GATE := 0.40

const FIREBALL_COLS := 4
const FIREBALL_ROWS := 4
const FIREBALL_FRAME_COUNT := FIREBALL_COLS * FIREBALL_ROWS
const FIREBALL_FRAME_RATE := 16.0
const FIRE_MACHINE_DRAGON_HEAD_FRAMES := 16
const FIRE_MACHINE_DRAGON_EMERGE_FRAMES := 8
const FIRE_MACHINE_DRAGON_JAW_FRAMES := 8
const TRAIL_RENDER_LIMIT := 30
const TRAIL_RENDER_LIMIT_LOD := 18
const TRAIL_RENDER_LIMIT_SEVERE_LOD := 12
const IMPACT_RENDER_LIMIT := 10
const FIRE_MACHINE_STREAM_RENDER_LIMIT := 4
const FIRE_MACHINE_ZONE_RENDER_LIMIT := 3
const FIRE_MACHINE_SMOKE_RENDER_LIMIT := 90
const SPRAY_PARTICLE_RENDER_LIMIT := 36
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_PARTICLE_RENDER_LIMIT := 48
const STARPOINT_PARTICLE_RENDER_LIMIT_LOD := 24

var fireball_atlas: Texture2D = null
var trail_head_texture: Texture2D = null
var trail_node_texture: Texture2D = null
var fire_machine_dragon_head_texture: Texture2D = null
var center_border_texture: Texture2D = null
var textures_loaded := false
var time_sec := 0.0
var _last_draw_msec := 0
var _inferno_charge_fx_host: Node = null
var _inferno_charge_fx_host_add_pending := false
var _inferno_trail_fx_host: Node = null
var _inferno_trail_fx_host_add_pending := false
var _inferno_burst_fx_host: Node = null
var _inferno_burst_fx_host_add_pending := false
# phase 전환 감지용 — phase 1 → 2 전환 frame에 charge host를 강제 queue_free
# (defense in depth, 2026-05-18 사용자 보고: charge VFX stuck after phase 2).
var _last_seen_inferno_phase := 0
var _last_seen_inferno_active := false
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded:
		return true
	match _prewarm_step_index:
		0:
			fireball_atlas = ProjectResourceLoader.load_texture(FIREBALL_ATLAS_PATH)
			if fireball_atlas == null:
				fireball_atlas = ProjectResourceLoader.load_texture(FIREBALL_FALLBACK_ATLAS_PATH)
		1:
			trail_head_texture = ProjectResourceLoader.load_texture(TRAIL_HEAD_TEXTURE_PATH)
		2:
			trail_node_texture = ProjectResourceLoader.load_texture(TRAIL_NODE_TEXTURE_PATH)
		3:
			fire_machine_dragon_head_texture = ProjectResourceLoader.load_texture(FIRE_MACHINE_DRAGON_HEAD_TEXTURE_PATH)
		4:
			center_border_texture = ProjectResourceLoader.load_texture(CENTER_BORDER_TEXTURE_PATH)
		5:
			InfernoChargeFxHost.prewarm_assets()
		6:
			InfernoTrailFxHost.prewarm_assets()
		7:
			InfernoBurstFxHost.prewarm_assets()
		_:
			textures_loaded = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func reset() -> void:
	time_sec = 0.0
	_last_draw_msec = 0
	_last_seen_inferno_phase = 0
	_last_seen_inferno_active = false
	if _is_valid_fx_host(_inferno_charge_fx_host) and _inferno_charge_fx_host.has_method("tear_down"):
		_inferno_charge_fx_host.tear_down(false)
	if _is_valid_fx_host(_inferno_trail_fx_host) and _inferno_trail_fx_host.has_method("tear_down"):
		_inferno_trail_fx_host.tear_down(false)
	if _is_valid_fx_host(_inferno_burst_fx_host) and _inferno_burst_fx_host.has_method("tear_down"):
		_inferno_burst_fx_host.tear_down(false)


func clear_transient_canvas_items() -> void:
	reset()


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	_ensure_textures()
	time_sec += _consume_draw_delta()
	var sample_start: int = _perf_begin(perf_logger)
	var width := maxf(1.0, float(context.get("width", 760.0)))
	var height := maxf(1.0, float(context.get("height", 750.0)))
	var quality_scale := _get_playfield_quality_scale(context)
	_draw_playfield_heat(canvas, width, height, context, quality_scale)
	_perf_end(perf_logger, "stage5.playfield.heat", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_fire_machine_event(canvas, context, shake_offset, quality_scale)
	_perf_end(perf_logger, "stage5.playfield.fire_machine", sample_start)

	sample_start = _perf_begin(perf_logger)
	_sync_inferno_charge_fx_host(canvas, context, shake_offset, quality_scale)
	_sync_inferno_trail_fx_host(canvas, context, shake_offset, quality_scale)
	_sync_inferno_burst_fx_host(canvas, context, shake_offset, quality_scale)
	_draw_inferno_charge_aura(canvas, context, shake_offset)
	_draw_inferno_trail(canvas, context, shake_offset, quality_scale)
	_perf_end(perf_logger, "stage5.playfield.inferno", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_fireballs(canvas, context, shake_offset)
	_draw_impact_events(canvas, context, shake_offset)
	_perf_end(perf_logger, "stage5.playfield.projectiles", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_starpoint_particles(canvas, context, shake_offset, quality_scale)
	_draw_starpoint_drops(canvas, context, shake_offset)
	_perf_end(perf_logger, "stage5.playfield.starpoints", sample_start)


func get_imagegen_asset_status() -> Dictionary:
	_ensure_textures()
	var status := {
		"stage5_fireball_atlas": fireball_atlas != null,
		"stage5_fireball_atlas_path": FIREBALL_ATLAS_PATH,
		"stage5_fireball_fallback_atlas_path": FIREBALL_FALLBACK_ATLAS_PATH,
		"stage5_trail_head_texture": trail_head_texture != null,
		"stage5_trail_node_texture": trail_node_texture != null,
		"stage5_fire_machine_dragon_head_texture": fire_machine_dragon_head_texture != null,
		"stage5_center_border_texture": center_border_texture != null,
		"stage5_center_border_path": CENTER_BORDER_TEXTURE_PATH,
		"stage5_center_border_draw_enabled": CENTER_BORDER_IMAGEGEN_DRAW_ENABLED,
		"stage5_center_border_fallback_stroke": CENTER_BORDER_FALLBACK_STROKE,
		"stage5_center_border_collision_edge_band_px": CENTER_BORDER_COLLISION_EDGE_BAND_PX,
		"stage5_center_border_inner_guides_removed": true,
		"trail_render_limit": TRAIL_RENDER_LIMIT,
		"trail_render_limit_lod": TRAIL_RENDER_LIMIT_LOD,
		"trail_render_limit_severe_lod": TRAIL_RENDER_LIMIT_SEVERE_LOD,
	}
	status.merge(InfernoChargeFxHost.build_pipeline_status(), true)
	status.merge(InfernoTrailFxHost.build_pipeline_status(), true)
	status.merge(InfernoBurstFxHost.build_pipeline_status(), true)
	return status


func _ensure_textures() -> void:
	if textures_loaded:
		return
	prewarm_assets()


func _draw_playfield_heat(canvas: CanvasItem, width: float, height: float, context: Dictionary, quality_scale: float) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(0.12, 0.035, 0.025, 0.16))
	var phase := time_sec * 0.8
	var line_count := 7 if quality_scale > 0.8 else 4
	for idx in range(line_count):
		var y := fposmod(phase * 38.0 + float(idx) * height / float(line_count), height)
		var alpha := 0.035 + 0.025 * sin(phase + float(idx))
		canvas.draw_line(Vector2(14.0, y), Vector2(width - 14.0, y + sin(phase + float(idx)) * 8.0), Color(1.0, 0.26, 0.08, alpha), 1.2, true)
	_draw_stage5_border(canvas, width, height, context, quality_scale)


func _draw_stage5_border(canvas: CanvasItem, width: float, height: float, context: Dictionary, quality_scale: float) -> void:
	var inferno_active := bool(context.get("stage5_hongryun_inferno_active", false))
	var alpha := 0.42 if inferno_active else 0.26
	if CENTER_BORDER_IMAGEGEN_DRAW_ENABLED and center_border_texture != null:
		var border_alpha := 1.0 if inferno_active else 0.94
		canvas.draw_texture_rect(
			center_border_texture,
			Rect2(0.0, 0.0, width, height),
			false,
			Color(1.0, 0.94 + alpha * 0.06, 0.86 + alpha * 0.10, border_alpha)
		)
		if inferno_active:
			canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(1.0, 0.16, 0.04, 0.10), false, 2.0, true)
		return
	var border_color := Color(0.92, 0.18, 0.08, alpha)
	var stroke := CENTER_BORDER_FALLBACK_STROKE if quality_scale > 0.65 else 1.0
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), border_color, false, stroke, true)
	canvas.draw_rect(Rect2(3.0, 3.0, maxf(1.0, width - 6.0), maxf(1.0, height - 6.0)), Color(1.0, 0.62, 0.18, alpha * 0.28), false, 1.0, true)


func _draw_fire_machine_event(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var active := bool(context.get("stage5_hongryun_fire_machine_active", false))
	var zones: Array = _as_array(context.get("stage5_hongryun_fire_machine_zones", []))
	var streams: Array = _as_array(context.get("stage5_hongryun_fire_machine_streams", []))
	var smoke_particles: Array = _as_array(context.get("stage5_hongryun_fire_machine_smoke_particles", []))
	var spray_particles: Array = _as_array(context.get("stage5_hongryun_fire_machine_spray_particles", []))
	if not active and zones.is_empty() and streams.is_empty() and smoke_particles.is_empty() and spray_particles.is_empty():
		return
	_draw_fire_machine_zones(canvas, zones, shake_offset, quality_scale)
	_draw_fire_machine_smoke(canvas, smoke_particles, shake_offset, quality_scale)
	if active:
		_draw_fire_machine_portal_and_core(canvas, context, shake_offset, quality_scale)
		_draw_fire_machine_dragons(canvas, context, shake_offset, quality_scale)
	_draw_fire_machine_streams(canvas, streams, shake_offset, quality_scale)
	_draw_fire_machine_spray_particles(canvas, spray_particles, shake_offset, quality_scale)


func _draw_fire_machine_zones(canvas: CanvasItem, zones: Array, shake_offset: Vector2, quality_scale: float) -> void:
	var start_index: int = max(0, zones.size() - FIRE_MACHINE_ZONE_RENDER_LIMIT)
	for zone_index in range(start_index, zones.size()):
		if not (zones[zone_index] is Dictionary):
			continue
		var zone: Dictionary = zones[zone_index]
		var center := _as_vector2(zone.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := Vector2(maxf(1.0, float(zone.get("width", 80.0))), maxf(1.0, float(zone.get("height", 32.0))))
		var life_ratio := clampf(float(zone.get("duration", 0.0)) / 150.0, 0.0, 1.0)
		canvas.draw_circle(center, maxf(size.x, size.y) * 0.58, Color(0.52, 0.04, 0.015, 0.10 * life_ratio))
		var flames: Array = _as_array(zone.get("flames", []))
		var render_count: int = flames.size() if quality_scale > 0.75 else min(flames.size(), 14)
		for flame_index in range(render_count):
			if not (flames[flame_index] is Dictionary):
				continue
			var flame: Dictionary = flames[flame_index]
			var pos := _as_vector2(flame.get("pos", center), center) + shake_offset
			var radius := maxf(1.0, float(flame.get("size", 5.0)))
			var color_phase := float(flame.get("color_phase", 0.0))
			var alpha := clampf(float(flame.get("life", 0.0)) / 30.0, 0.0, 1.0)
			var color := Color(1.0, 0.30, 0.03, 0.82 * alpha)
			if color_phase > 0.66:
				color = Color(1.0, 0.88, 0.18, 0.78 * alpha)
			elif color_phase > 0.33:
				color = Color(1.0, 0.55, 0.06, 0.82 * alpha)
			canvas.draw_circle(pos, radius * 0.52, Color(color.r, color.g, color.b, color.a * 0.18))
			canvas.draw_circle(pos + Vector2(0.0, -radius * 0.25), radius * 0.34, color)


func _draw_fire_machine_portal_and_core(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var center := _as_vector2(context.get("stage5_hongryun_fire_machine_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0)) + shake_offset
	var door_open := clampf(float(context.get("stage5_hongryun_fire_machine_door_open_percent", 0.0)), 0.0, 1.0)
	var machine_scale := clampf(float(context.get("stage5_hongryun_fire_machine_scale", 0.0)), 0.0, 1.2)
	if door_open > 0.001:
		var radius := 100.0 * door_open
		canvas.draw_circle(center, radius, Color(0.015, 0.0, 0.0, 0.72 * door_open))
		var ring_count := 4 if quality_scale > 0.65 else 2
		for layer in range(ring_count):
			var layer_radius := radius + float(layer) * 5.0
			var alpha := (0.46 - float(layer) * 0.08) * door_open
			canvas.draw_arc(center, layer_radius, time_sec * 0.35 + float(layer) * 0.3, TAU + time_sec * 0.35 + float(layer) * 0.3, 36, Color(1.0, 0.22, 0.06, alpha), 2.0, true)
	if machine_scale <= 0.001:
		return
	var core_radius := 42.0 * machine_scale
	var pulse := 0.72 + 0.28 * sin(time_sec * 5.0)
	canvas.draw_circle(center, core_radius * 1.30, Color(1.0, 0.05, 0.02, 0.10 * machine_scale * pulse))
	canvas.draw_circle(center, core_radius, Color(0.08, 0.0, 0.025, 0.92 * machine_scale))
	canvas.draw_arc(center, core_radius, time_sec * 1.2, TAU + time_sec * 1.2, 36, Color(1.0, 0.14, 0.20, 0.84 * machine_scale), 3.0, true)
	var petal_count := 8
	for index in range(petal_count):
		var angle := TAU * float(index) / float(petal_count) + time_sec * 1.4
		var dir := Vector2(cos(angle), sin(angle))
		var petal_center := center + dir * (54.0 * machine_scale)
		var petal_size := Vector2(16.0, 30.0) * machine_scale
		_draw_rotated_rect(canvas, petal_center, petal_size, angle, Color(0.82, 0.08, 0.16, 0.62 * machine_scale), Color(1.0, 0.42, 0.16, 0.42 * machine_scale))
		if machine_scale >= 0.88:
			var nozzle_pos := center + dir * (68.0 * machine_scale)
			canvas.draw_circle(nozzle_pos, 7.0 * machine_scale, Color(0.06, 0.0, 0.01, 0.90))
			canvas.draw_arc(nozzle_pos, 7.0 * machine_scale, 0.0, TAU, 12, Color(1.0, 0.55, 0.16, 0.74), 1.4, true)


func _draw_fire_machine_dragons(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var dragons: Array = _as_array(context.get("stage5_hongryun_fire_machine_dragons", []))
	if dragons.is_empty():
		return
	var machine_scale := clampf(float(context.get("stage5_hongryun_fire_machine_scale", 0.0)), 0.0, 1.2)
	var center := _as_vector2(context.get("stage5_hongryun_fire_machine_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0)) + shake_offset
	for value in dragons:
		if not (value is Dictionary):
			continue
		var dragon: Dictionary = value
		var emergence := clampf(float(dragon.get("cannon_emergence", 0.0)), 0.0, 1.0)
		if machine_scale < 0.08 or emergence < 0.08:
			continue
		var angle := float(dragon.get("cannon_angle", 0.0))
		var mouth := _as_vector2(dragon.get("mouth_pos", center), center) + shake_offset
		var head := _as_vector2(dragon.get("head_pos", mouth), mouth) + shake_offset
		_draw_fire_machine_dragon_neck(canvas, center, head, machine_scale, emergence)
		_draw_fire_machine_dragon_head(canvas, head, angle, machine_scale, emergence, float(dragon.get("jaw_open", 0.0)), str(dragon.get("jaw_phase", "closed")))
		if bool(dragon.get("is_aiming", false)) and quality_scale > 0.75:
			var target := _as_vector2(dragon.get("aim_target", mouth), mouth) + shake_offset
			canvas.draw_line(mouth, target, Color(1.0, 0.06, 0.04, 0.22), 1.0, true)
			canvas.draw_arc(target, 8.0, 0.0, TAU, 18, Color(1.0, 0.18, 0.10, 0.56), 1.4, true)


func _draw_fire_machine_dragon_neck(canvas: CanvasItem, center: Vector2, head: Vector2, machine_scale: float, emergence: float) -> void:
	# Tapered dragon-neck body emerging from the central core (parity with the
	# Python _draw_dragon_neck): wide base at machine center -> narrow tip at the
	# head, so the head reads as growing out of the pot instead of floating at the
	# rim. Replaces the old straight draw_line "stick".
	var neck_scale := machine_scale * maxf(0.0, emergence)
	if neck_scale <= 0.01:
		return
	var dir := head - center
	if dir.length() < 1.0:
		return
	var fwd := dir.normalized()
	var perp := fwd.orthogonal()
	var base_half := maxf(6.0, 15.0 * neck_scale)
	var mid_half := maxf(5.0, 12.0 * neck_scale)
	var tip_half := maxf(4.0, 8.0 * neck_scale)
	var mid_pt := center.lerp(head, 0.48)
	var alpha := clampf(emergence, 0.0, 1.0)
	var outer := PackedVector2Array([
		center + perp * base_half,
		mid_pt + perp * mid_half,
		head + perp * tip_half,
		head - perp * tip_half,
		mid_pt - perp * mid_half,
		center - perp * base_half,
	])
	var inner := PackedVector2Array([
		center + perp * (base_half * 0.58),
		mid_pt + perp * (mid_half * 0.55),
		head + perp * (tip_half * 0.52),
		head - perp * (tip_half * 0.52),
		mid_pt - perp * (mid_half * 0.55),
		center - perp * (base_half * 0.58),
	])
	canvas.draw_colored_polygon(outer, Color(0.20, 0.03, 0.06, 0.94 * alpha))
	canvas.draw_colored_polygon(inner, Color(0.52, 0.10, 0.16, 0.94 * alpha))
	var outline := outer.duplicate()
	outline.append(outer[0])
	canvas.draw_polyline(outline, Color(1.0, 0.46, 0.30, 0.66 * alpha), maxf(1.0, 2.0 * neck_scale), true)
	# Center highlight ridge running base -> tip for the organic spine read.
	canvas.draw_line(
		center + perp * (base_half * 0.40),
		head + perp * (tip_half * 0.35),
		Color(0.78, 0.26, 0.34, 0.62 * alpha),
		maxf(1.0, 2.0 * neck_scale),
		true
	)


func _draw_fire_machine_dragon_head(canvas: CanvasItem, head: Vector2, angle: float, machine_scale: float, emergence: float, jaw_open: float, jaw_phase: String) -> void:
	var draw_size := Vector2(104.0, 82.0) * maxf(0.1, machine_scale) * lerpf(0.72, 1.0, emergence)
	if fire_machine_dragon_head_texture != null:
		var frame := _get_fire_machine_dragon_frame(emergence, jaw_open, jaw_phase)
		var texture_size := fire_machine_dragon_head_texture.get_size()
		var frame_size := Vector2(texture_size.x / float(FIRE_MACHINE_DRAGON_HEAD_FRAMES), texture_size.y)
		var source_rect := Rect2(Vector2(frame_size.x * float(frame), 0.0), frame_size)
		_draw_rotated_texture_region(
			canvas,
			fire_machine_dragon_head_texture,
			source_rect,
			head,
			draw_size,
			angle,
			Vector2(0.36, 0.50),
			Color(1.0, 0.70, 0.56, 0.96)
		)
		return
	var dir := Vector2(cos(angle), sin(angle))
	var side := dir.orthogonal()
	var snout := head + dir * draw_size.x * 0.44
	var back := head - dir * draw_size.x * 0.28
	var upper := head - side * draw_size.y * (0.30 + jaw_open * 0.06)
	var lower := head + side * draw_size.y * (0.18 + jaw_open * 0.22)
	var points := PackedVector2Array([back - side * draw_size.y * 0.18, upper, snout, lower, back + side * draw_size.y * 0.22])
	canvas.draw_colored_polygon(points, Color(0.66, 0.05, 0.08, 0.94))
	canvas.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]), Color(1.0, 0.42, 0.18, 0.78), 2.0, true)


func _draw_fire_machine_streams(canvas: CanvasItem, streams: Array, shake_offset: Vector2, quality_scale: float) -> void:
	var start_index: int = max(0, streams.size() - FIRE_MACHINE_STREAM_RENDER_LIMIT)
	for stream_index in range(start_index, streams.size()):
		if not (streams[stream_index] is Dictionary):
			continue
		var stream: Dictionary = streams[stream_index]
		var start := _as_vector2(stream.get("start", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var target := _as_vector2(stream.get("target", start), start) + shake_offset
		var duration := maxf(1.0, float(stream.get("duration", 60.0)))
		var progress := clampf(float(stream.get("timer", 0.0)) / duration, 0.0, 1.0)
		var end := start.lerp(target, progress)
		var width := 9.0 + 7.0 * sin(progress * PI)
		canvas.draw_line(start, end, Color(0.74, 0.02, 0.0, 0.22), width + 15.0, true)
		canvas.draw_line(start, end, Color(1.0, 0.18, 0.02, 0.68), width + 4.0, true)
		canvas.draw_line(start, end, Color(1.0, 0.84, 0.18, 0.84), maxf(2.0, width * 0.34), true)
		var particles: Array = _as_array(stream.get("particles", []))
		var render_count: int = particles.size() if quality_scale > 0.75 else min(particles.size(), 14)
		var particle_start: int = max(0, particles.size() - render_count)
		for particle_index in range(particle_start, particles.size()):
			if not (particles[particle_index] is Dictionary):
				continue
			var particle: Dictionary = particles[particle_index]
			var pos := _as_vector2(particle.get("pos", start), start) + shake_offset
			var radius := maxf(1.0, float(particle.get("size", 4.0)))
			var life_alpha := clampf(float(particle.get("life", 0.0)) / 30.0, 0.0, 1.0)
			var color_value: Variant = particle.get("color", Color(1.0, 0.48, 0.08, 0.9))
			var color: Color = color_value if color_value is Color else Color(1.0, 0.48, 0.08, 0.9)
			canvas.draw_circle(pos, radius * 0.45, Color(color.r, color.g, color.b, color.a * life_alpha))


func _draw_fire_machine_smoke(canvas: CanvasItem, smoke_particles: Array, shake_offset: Vector2, quality_scale: float) -> void:
	if smoke_particles.is_empty():
		return
	var render_limit := FIRE_MACHINE_SMOKE_RENDER_LIMIT if quality_scale > 0.6 else int(FIRE_MACHINE_SMOKE_RENDER_LIMIT * 0.45)
	var start_index: int = max(0, smoke_particles.size() - render_limit)
	for index in range(start_index, smoke_particles.size()):
		if not (smoke_particles[index] is Dictionary):
			continue
		var particle: Dictionary = smoke_particles[index]
		var pos := _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var alpha := clampf(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.001:
			continue
		var radius := maxf(1.0, float(particle.get("size", 8.0)))
		var warmth := clampf(float(particle.get("warmth", 0.0)), 0.0, 1.0)
		var color := Color(0.62 + warmth * 0.15, 0.58 + warmth * 0.08, 0.56 - warmth * 0.08, alpha * 0.22)
		canvas.draw_circle(pos, radius, color)


func _draw_fire_machine_spray_particles(canvas: CanvasItem, spray_particles: Array, shake_offset: Vector2, quality_scale: float) -> void:
	if spray_particles.is_empty() or quality_scale < 0.45:
		return
	var start_index: int = max(0, spray_particles.size() - SPRAY_PARTICLE_RENDER_LIMIT)
	for index in range(start_index, spray_particles.size()):
		if not (spray_particles[index] is Dictionary):
			continue
		var particle: Dictionary = spray_particles[index]
		var pos := _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius := maxf(1.0, float(particle.get("size", 2.0)))
		canvas.draw_circle(pos, radius, Color(1.0, 0.45, 0.08, 0.55))


func _draw_rotated_rect(canvas: CanvasItem, center: Vector2, size: Vector2, angle: float, fill: Color, outline: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := dir.orthogonal()
	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	var points := PackedVector2Array([
		center - side * half_w - dir * half_h,
		center + side * half_w - dir * half_h,
		center + side * half_w + dir * half_h,
		center - side * half_w + dir * half_h,
	])
	canvas.draw_colored_polygon(points, fill)
	points.append(points[0])
	canvas.draw_polyline(points, outline, 1.2, true)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	size: Vector2,
	angle: float,
	pivot_ratio: Vector2,
	modulate: Color
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var local_top_left := -size * pivot_ratio
	var local_bottom_right := local_top_left + size
	var local_corners := [
		local_top_left,
		Vector2(local_bottom_right.x, local_top_left.y),
		local_bottom_right,
		Vector2(local_top_left.x, local_bottom_right.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(center + corner.rotated(angle))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		uv_min,
		Vector2(uv_max.x, uv_min.y),
		uv_max,
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _get_fire_machine_dragon_frame(emergence: float, jaw_open: float, jaw_phase: String) -> int:
	if jaw_phase in ["opening", "open", "breathing", "closing"] or jaw_open > 0.05:
		var jaw_frame := clampi(int(clampf(jaw_open, 0.0, 1.0) * float(FIRE_MACHINE_DRAGON_JAW_FRAMES - 1)), 0, FIRE_MACHINE_DRAGON_JAW_FRAMES - 1)
		return FIRE_MACHINE_DRAGON_EMERGE_FRAMES + jaw_frame
	return clampi(int(clampf(emergence, 0.0, 1.0) * float(FIRE_MACHINE_DRAGON_EMERGE_FRAMES - 1)), 0, FIRE_MACHINE_DRAGON_EMERGE_FRAMES - 1)


func _draw_fireballs(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var fireballs: Array = _as_array(context.get("stage5_hongryun_fireballs", []))
	for value in fireballs:
		if not (value is Dictionary):
			continue
		var projectile: Dictionary = value
		var pos := _as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius := maxf(4.0, float(projectile.get("radius", 8.0)))
		var age := float(projectile.get("age", 0.0)) / 60.0
		var frame := int(floor(age * FIREBALL_FRAME_RATE)) % FIREBALL_FRAME_COUNT
		var draw_size := Vector2.ONE * radius * 4.0
		var rect := Rect2(pos - draw_size * 0.5, draw_size)
		if not _draw_atlas_frame(canvas, fireball_atlas, FIREBALL_COLS, FIREBALL_ROWS, frame, rect, Color(1.0, 0.66, 0.34, 0.94)):
			canvas.draw_circle(pos, radius * 1.28, Color(1.0, 0.22, 0.05, 0.94))
			canvas.draw_circle(pos + Vector2(-radius * 0.2, -radius * 0.22), radius * 0.56, Color(1.0, 0.86, 0.26, 0.82))


func _draw_inferno_charge_aura(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage5_hongryun_inferno_active", false)):
		return
	if int(context.get("stage5_hongryun_inferno_phase", 0)) != 1:
		return
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0)) + shake_offset
	var pulse := 0.5 + 0.5 * sin(time_sec * 21.0)
	for layer in range(4):
		var radius := 42.0 + float(layer) * 18.0 + pulse * 9.0
		var alpha := 0.34 - float(layer) * 0.055
		canvas.draw_arc(ball_pos, radius, time_sec * (1.4 + float(layer) * 0.4), TAU + time_sec * (1.4 + float(layer) * 0.4), 48, Color(1.0, 0.18, 0.04, alpha), 2.0, true)
	canvas.draw_circle(ball_pos, 28.0 + pulse * 6.0, Color(1.0, 0.05, 0.02, 0.16))


func _draw_inferno_trail(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	if not bool(context.get("stage5_hongryun_inferno_active", false)):
		return
	var trail: Array = _as_array(context.get("stage5_hongryun_inferno_trail", []))
	if trail.size() < 2:
		return
	var render_limit := TRAIL_RENDER_LIMIT
	if quality_scale < 0.45:
		render_limit = TRAIL_RENDER_LIMIT_SEVERE_LOD
	elif quality_scale < 0.85:
		render_limit = TRAIL_RENDER_LIMIT_LOD
	var start_index: int = max(0, trail.size() - render_limit)
	var previous := _as_vector2(trail[start_index], Vector2.ZERO) + shake_offset
	for idx in range(start_index + 1, trail.size()):
		var current := _as_vector2(trail[idx], previous) + shake_offset
		var t := float(idx - start_index) / maxf(1.0, float(trail.size() - start_index - 1))
		var width := 4.0 + t * 10.0
		var alpha := 0.18 + t * 0.56
		canvas.draw_line(previous, current, Color(1.0, 0.07, 0.02, alpha * 0.44), width + 8.0, true)
		canvas.draw_line(previous, current, Color(1.0, 0.42, 0.12, alpha), width, true)
		if idx % 3 == 0 or idx == trail.size() - 1:
			_draw_trail_node(canvas, current, t, idx == trail.size() - 1)
		previous = current


func _draw_trail_node(canvas: CanvasItem, center: Vector2, t: float, is_head: bool) -> void:
	var size := Vector2.ONE * (18.0 + t * 24.0 + (14.0 if is_head else 0.0))
	var texture := trail_head_texture if is_head else trail_node_texture
	var alpha := 0.20 + t * 0.38
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1.0, 0.24, 0.08, alpha))
	canvas.draw_circle(center, size.x * (0.33 if is_head else 0.20), Color(1.0, 0.52, 0.14, 0.42 + t * 0.24))
	if is_head:
		canvas.draw_arc(center, size.x * 0.52, time_sec * 4.0, time_sec * 4.0 + PI * 1.4, 32, Color(1.0, 0.90, 0.22, 0.74), 2.0, true)


func _draw_starpoint_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var particles: Array = _as_array(context.get("stage5_hongryun_starpoint_particles", []))
	if particles.is_empty():
		return
	var render_limit := STARPOINT_PARTICLE_RENDER_LIMIT
	if quality_scale < 0.85:
		render_limit = STARPOINT_PARTICLE_RENDER_LIMIT_LOD
	for particle_index in range(max(0, particles.size() - render_limit), particles.size()):
		var particle_value: Variant = particles[particle_index]
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		var alpha: float = clampf(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var color: Color = _get_starpoint_particle_color(float(particle.get("color_shift", 0.5)), alpha)
		canvas.draw_circle(pos, maxf(1.0, float(particle.get("size", 2.0))), color)


func _draw_starpoint_drops(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var drops: Array = _as_array(context.get("stage5_hongryun_starpoint_drops", []))
	if drops.is_empty():
		CommonStarpointVisualHost.hide_on_canvas(canvas)
		return
	# Stage 5 화염 테마 — Stage 4의 골드/오렌지 팔레트 공유. 디텍터 보너스
	# 드랍은 전 스테이지 공통 시안/화이트. host는 outer canvas의 child라
	# playfield-local 좌표를 game_offset + render_scale로 스크린 좌표 변환.
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = maxf(0.001, float(context.get("render_scale", 1.0)))
	var host: Node = CommonStarpointVisualHost.get_or_create_on_canvas(canvas)
	if host != null and host.has_method("sync_drop"):
		host.begin_frame()
		var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
		for drop_value in drops:
			var drop: Dictionary = drop_value if drop_value is Dictionary else {}
			var star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
			var playfield_pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			host.sync_drop({
				"pos": game_offset + playfield_pos * render_scale,
				"size": float(drop.get("size", STARPOINT_DROP_SIZE)) * render_scale,
				"life": float(drop.get("life", 0.0)),
				"rotation": float(drop.get("rotation", 0.0)),
				"glow_intensity": float(drop.get("glow_intensity", 1.0)),
				"star_detector_bonus": star_detector_bonus,
				"elapsed": elapsed,
				"glow_color": Color(0.30, 0.92, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.64, 0.16, 1.0),
				"fill_color": Color(0.16, 0.82, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.68, 0.05, 1.0),
				"outline_color": Color(1.0, 1.0, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.98, 0.52, 1.0),
			})
		host.end_frame()
		return
	for drop_value in drops:
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = maxf(1.0, float(drop.get("size", STARPOINT_DROP_SIZE)))
		var alpha: float = clampf(float(drop.get("life", 0.0)) * 2.0 / 255.0, 0.0, 1.0)
		var glow_intensity: float = clampf(float(drop.get("glow_intensity", 1.0)), 0.0, 1.0)
		var glow_alpha: float = alpha * 0.5 * glow_intensity
		var star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
		var glow_color := Color(0.30, 0.92, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.64, 0.16, 1.0)
		var fill_color := Color(0.16, 0.82, 1.0, alpha) if star_detector_bonus else Color(1.0, 0.68, 0.05, alpha)
		var outline_color := Color(1.0, 1.0, 1.0, alpha) if star_detector_bonus else Color(1.0, 0.98, 0.52, alpha)
		for layer in range(4):
			var glow_radius: float = size * (4.0 - float(layer) * 0.7)
			var layer_alpha: float = glow_alpha / float(4 - layer)
			canvas.draw_circle(pos, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, layer_alpha))

		var points := PackedVector2Array()
		var star_rotation: float = float(drop.get("rotation", 0.0))
		for point_index in range(10):
			var point_radius: float = size if point_index % 2 == 0 else size * 0.5
			var angle: float = star_rotation + float(point_index) * PI / 5.0
			points.append(pos + Vector2(cos(angle), sin(angle)) * point_radius)
		if points.size() >= 3:
			canvas.draw_colored_polygon(points, fill_color)
			for point_index in range(points.size()):
				canvas.draw_line(points[point_index], points[(point_index + 1) % points.size()], outline_color, 3.0, true)
		canvas.draw_circle(pos, 3.0, Color(1.0, 1.0, 1.0, alpha * glow_intensity))


func _get_starpoint_particle_color(color_shift: float, alpha: float) -> Color:
	var clamped_shift: float = clampf(color_shift, 0.0, 1.0)
	if clamped_shift < 0.33:
		var warm_t: float = clamped_shift * 3.0
		return Color(1.0, 1.0, (100.0 + 155.0 * warm_t) / 255.0, alpha)
	if clamped_shift < 0.66:
		var blue_t: float = (clamped_shift - 0.33) * 3.0
		return Color((255.0 - 55.0 * blue_t) / 255.0, (255.0 - 30.0 * blue_t) / 255.0, 1.0, alpha)
	var cyan_t: float = (clamped_shift - 0.66) * 3.0
	return Color((200.0 - 100.0 * cyan_t) / 255.0, (225.0 + 30.0 * cyan_t) / 255.0, 1.0, alpha)


func _draw_impact_events(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var impacts: Array = _as_array(context.get("stage5_hongryun_fireball_impacts", []))
	if impacts.is_empty():
		return
	var start_index: int = max(0, impacts.size() - IMPACT_RENDER_LIMIT)
	for idx in range(start_index, impacts.size()):
		var impact: Dictionary = impacts[idx] if impacts[idx] is Dictionary else {}
		var pos := _as_vector2(impact.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var reason := str(impact.get("reason", "player"))
		var scale := float(impact.get("scale", 1.0))
		var radius := 28.0 * scale
		var color := Color(1.0, 0.32, 0.08, 0.86)
		if reason == "floor":
			radius *= 0.72
			color = Color(1.0, 0.55, 0.14, 0.68)
		elif reason == "inferno_player":
			radius *= 1.45
			color = Color(1.0, 0.05, 0.02, 0.92)
			canvas.draw_circle(pos, radius * 0.92, Color(0.04, 0.0, 0.0, 0.30))
		canvas.draw_circle(pos, radius * 0.34, Color(color.r, color.g, color.b, color.a * 0.22))
		canvas.draw_arc(pos, radius, 0.0, TAU, 48, color, 3.0, true)
		canvas.draw_arc(pos, radius * 0.62, -time_sec * 8.0, PI - time_sec * 8.0, 28, Color(1.0, 0.86, 0.24, color.a * 0.70), 1.8, true)


func _draw_atlas_frame(
	canvas: CanvasItem,
	texture: Texture2D,
	cols: int,
	rows: int,
	frame: int,
	rect: Rect2,
	modulate: Color
) -> bool:
	if texture == null:
		return false
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var frame_idx := clampi(frame, 0, cols * rows - 1)
	var col := frame_idx % cols
	@warning_ignore("integer_division")
	var row := int(frame_idx / cols)
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	canvas.draw_texture_rect_region(texture, rect, source_rect, modulate, false, true)
	return true


func _consume_draw_delta() -> float:
	var now := Time.get_ticks_msec()
	if _last_draw_msec <= 0:
		_last_draw_msec = now
		return 1.0 / 60.0
	var delta := clampf(float(now - _last_draw_msec) / 1000.0, 0.0, 0.1)
	_last_draw_msec = now
	return delta


func _get_playfield_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


# ---------------------------------------------------------------------------
# 홍련폭염 준비 페이즈 노드-기반 FX 호스트
# ---------------------------------------------------------------------------
# Direct-draw aura `_draw_inferno_charge_aura()`는 모든 LOD에서 fallback으로
# 유지된다. 이 호스트는 quality_scale이 게이트를 통과할 때만 셰이더 쿼드 +
# inward ember GPUParticles2D 레이어를 추가로 합성한다.
func _sync_inferno_charge_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var inferno_active := bool(context.get("stage5_hongryun_inferno_active", false))
	var inferno_phase := int(context.get("stage5_hongryun_inferno_phase", 0))
	# Phase 전환 감지 — charge phase(1) 종료 시 host를 강제 queue_free.
	# set_active(false)만으로는 시각이 stuck되는 케이스가 발견되어 (2026-05-18
	# 사용자 보고) 노드 자체를 free해 다음 charge에서 fresh build.
	var was_charge_phase: bool = _last_seen_inferno_active and _last_seen_inferno_phase == 1
	var charge_phase: bool = inferno_active and inferno_phase == 1
	if was_charge_phase and not charge_phase:
		_tear_down_inferno_charge_fx_host()
	_last_seen_inferno_active = inferno_active
	_last_seen_inferno_phase = inferno_phase
	if not charge_phase or quality_scale < INFERNO_CHARGE_NODE_FX_QUALITY_GATE:
		_hide_inferno_charge_fx_host()
		return
	var host: Node = _get_or_create_inferno_charge_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return
	# InfernoChargeFxHost is parented to the outer root canvas (not the
	# transformed playfield canvas), so playfield-coordinate ball_pos must be
	# shifted by game_offset to land inside the rendered playfield. Without
	# this, the VFX renders into the letterbox pillars whenever the ball/boss
	# sits near the playfield edge (left-pillar "preparation animation" bug).
	# Then clamp X so the dragon ring's outer radius cannot bleed back into the
	# letterbox on either side.
	#
	# render_scale must also be propagated so the host can match the playfield
	# draw_set_transform (game_offset + (pos + shake) * render_scale, scale =
	# render_scale). Otherwise the FX renders in 1.0x while the ball / direct-
	# draw trail render at render_scale, causing the "이펙트와 공 위치가 다름"
	# split when the window is resized away from native 760x750.
	var game_offset := _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = max(0.01, float(context.get("render_scale", 1.0)))
	var game_size := _as_vector2(context.get("game_size", Vector2(760.0, 750.0)), Vector2(760.0, 750.0))
	var raw_ball_pos := _as_vector2(context.get("ball_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0))
	var safe_margin: float = InfernoChargeFxHost.DRAGON_RING_BASE_SIZE * 0.5
	var min_x: float = safe_margin
	var max_x: float = maxf(safe_margin, game_size.x - safe_margin)
	var clamped_ball_pos := Vector2(clampf(raw_ball_pos.x, min_x, max_x), raw_ball_pos.y)
	var ball_pos := game_offset + (clamped_ball_pos + shake_offset) * render_scale
	var charge_ratio := clampf(float(context.get("stage5_hongryun_inferno_charge_ratio", 0.0)), 0.0, 1.0)
	var enraged := bool(context.get("stage5_hongryun_inferno_enraged", false))
	var state := {
		"phase_active": true,
		"ball_pos": ball_pos,
		"render_scale": render_scale,
		"charge_ratio": charge_ratio,
		"enraged": enraged,
		"quality_scale": quality_scale,
	}
	host.sync_state(state, true)


func _hide_inferno_charge_fx_host() -> void:
	if _is_valid_fx_host(_inferno_charge_fx_host) and _inferno_charge_fx_host.has_method("set_active"):
		_inferno_charge_fx_host.set_active(false)


# Phase 1 → 2 전환 시 강제로 노드 자체를 free. set_active(false)만으로는
# visible이 stuck되는 케이스를 차단 (2026-05-18 사용자 보고: charge VFX가
# 보스 옆에 큰 dragon ring으로 stuck). 다음 charge 시 fresh 재생성.
func _tear_down_inferno_charge_fx_host() -> void:
	if _is_valid_fx_host(_inferno_charge_fx_host):
		if _inferno_charge_fx_host.has_method("tear_down"):
			_inferno_charge_fx_host.tear_down(true)
		else:
			_inferno_charge_fx_host.queue_free()
	_inferno_charge_fx_host = null
	_inferno_charge_fx_host_add_pending = false


func _get_or_create_inferno_charge_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host(_inferno_charge_fx_host):
		return _inferno_charge_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(INFERNO_CHARGE_FX_HOST_NAME)
	if _is_valid_fx_host(existing):
		_inferno_charge_fx_host = existing
		_inferno_charge_fx_host_add_pending = false
		return _inferno_charge_fx_host
	_inferno_charge_fx_host = InfernoChargeFxHost.new()
	_inferno_charge_fx_host.name = INFERNO_CHARGE_FX_HOST_NAME
	_inferno_charge_fx_host.visible = false
	if not _inferno_charge_fx_host_add_pending:
		_inferno_charge_fx_host_add_pending = true
		parent.call_deferred("add_child", _inferno_charge_fx_host)
	return _inferno_charge_fx_host


func _is_valid_fx_host(host: Node) -> bool:
	return host != null and is_instance_valid(host) and not host.is_queued_for_deletion()


# Trail head VFX — phase 2 (snake trail). Charge phase 패턴과 동일한
# letterbox-safe matrix: ball_pos는 playfield 좌표라 game_offset 더하고,
# dragon ring 반지름만큼 X clamp.
func _sync_inferno_trail_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var inferno_active := bool(context.get("stage5_hongryun_inferno_active", false))
	var inferno_phase := int(context.get("stage5_hongryun_inferno_phase", 0))
	var trail_phase: bool = inferno_active and inferno_phase == 2
	if not trail_phase or quality_scale < INFERNO_TRAIL_NODE_FX_QUALITY_GATE:
		_hide_inferno_trail_fx_host()
		return
	var trail: Array = _as_array(context.get("stage5_hongryun_inferno_trail", []))
	if trail.is_empty():
		_hide_inferno_trail_fx_host()
		return
	var host: Node = _get_or_create_inferno_trail_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return
	var game_offset := _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = max(0.01, float(context.get("render_scale", 1.0)))
	var raw_head := _as_vector2(trail[trail.size() - 1], Vector2(380.0, 375.0))
	# 2026-05-18 사용자 손맛 요청: trail VFX는 ball을 letterbox로 자유롭게
	# 따라간다. Charge phase의 letterbox bleed clamp는 charge_fx_host에만
	# 적용되고 trail은 ball 좌표 그대로 사용 — 사용자 보고 "이펙트와 공
	# 위치 분리" 원인이 이전의 trail head clamp였음.
	# render_scale은 host node에 그대로 전파해 transformed playfield의
	# draw_set_transform (scale = render_scale) 과 일치시킨다. 누락 시
	# 창 크기에 따라 trail head가 공 위치에서 점점 멀어진다.
	var head_pos := game_offset + (raw_head + shake_offset) * render_scale
	var trail_elapsed := float(context.get("stage5_hongryun_inferno_trail_elapsed_sec", 0.0))
	var enraged := bool(context.get("stage5_hongryun_inferno_enraged", false))
	var state := {
		"phase_active": true,
		"head_pos": head_pos,
		"render_scale": render_scale,
		"trail_elapsed_sec": trail_elapsed,
		"enraged": enraged,
		"quality_scale": quality_scale,
	}
	host.sync_state(state, true)


func _hide_inferno_trail_fx_host() -> void:
	if _is_valid_fx_host(_inferno_trail_fx_host) and _inferno_trail_fx_host.has_method("set_active"):
		_inferno_trail_fx_host.set_active(false)


func _get_or_create_inferno_trail_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host(_inferno_trail_fx_host):
		return _inferno_trail_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(INFERNO_TRAIL_FX_HOST_NAME)
	if _is_valid_fx_host(existing):
		_inferno_trail_fx_host = existing
		_inferno_trail_fx_host_add_pending = false
		return _inferno_trail_fx_host
	_inferno_trail_fx_host = InfernoTrailFxHost.new()
	_inferno_trail_fx_host.name = INFERNO_TRAIL_FX_HOST_NAME
	_inferno_trail_fx_host.visible = false
	if not _inferno_trail_fx_host_add_pending:
		_inferno_trail_fx_host_add_pending = true
		parent.call_deferred("add_child", _inferno_trail_fx_host)
	return _inferno_trail_fx_host


# One-shot burst — pending flag는 state.gd가 hit / safety expire 한 프레임만 true.
# trigger_burst() 한 번이면 host 자체 tween으로 페이드인/아웃 진행.
func _sync_inferno_burst_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var pending := bool(context.get("stage5_hongryun_inferno_burst_pending", false))
	if not pending or quality_scale < INFERNO_BURST_NODE_FX_QUALITY_GATE:
		return
	var host: Node = _get_or_create_inferno_burst_fx_host(canvas)
	if host == null or not host.has_method("trigger_burst"):
		return
	var game_offset := _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = max(0.01, float(context.get("render_scale", 1.0)))
	var raw_burst_pos := _as_vector2(context.get("stage5_hongryun_inferno_burst_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0))
	var burst_pos := game_offset + (raw_burst_pos + shake_offset) * render_scale
	var enraged := bool(context.get("stage5_hongryun_inferno_enraged", false))
	host.trigger_burst(burst_pos, enraged, quality_scale, render_scale)


func _get_or_create_inferno_burst_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host(_inferno_burst_fx_host):
		return _inferno_burst_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(INFERNO_BURST_FX_HOST_NAME)
	if _is_valid_fx_host(existing):
		_inferno_burst_fx_host = existing
		_inferno_burst_fx_host_add_pending = false
		return _inferno_burst_fx_host
	_inferno_burst_fx_host = InfernoBurstFxHost.new()
	_inferno_burst_fx_host.name = INFERNO_BURST_FX_HOST_NAME
	_inferno_burst_fx_host.visible = false
	if not _inferno_burst_fx_host_add_pending:
		_inferno_burst_fx_host_add_pending = true
		parent.call_deferred("add_child", _inferno_burst_fx_host)
	return _inferno_burst_fx_host
