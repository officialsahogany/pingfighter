extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

const VASE_LANTERN_PATH := "res://assets/sprites/hud/stage5_hongryun_vase_lantern_sprites_imagegen_v2.png"
const SNAKE_POT_PATH := "res://assets/sprites/hud/stage5_hongryun_snake_pot_imagegen_v1.png"
const WALLMOUNT_PATH := "res://assets/sprites/hud/stage5_hongryun_snake_pot_wallmount_v2.png"
const LOTUS_PULSE_PATH := "res://assets/sprites/hud/stage5_hongryun_snake_pot_lotus_pulse_sheet_v1.png"
const CYBER_SNAKE_PATH := "res://assets/sprites/hud/stage5_hongryun_cyber_snake_sheet_imagegen_v2.png"
const MOTION_SPRITES_PATH := "res://assets/sprites/hud/stage5_hongryun_motion_sprites_imagegen_v2.png"

# Per-asset atlas grid. Each migrated PNG has a different layout — vase_lantern
# is a 2-cell mirror pair, lotus_pulse is an 8-frame row, cyber_snake is a
# 16-frame row, motion_sprites is a 3x2 mini-atlas. A single 4x4 assumption
# slices every asset incorrectly and produces box/row fragments in-game.
const VASE_LANTERN_COLS := 2
const VASE_LANTERN_ROWS := 1
const VASE_LANTERN_FRAMES := VASE_LANTERN_COLS * VASE_LANTERN_ROWS
const LOTUS_PULSE_COLS := 8
const LOTUS_PULSE_ROWS := 1
const LOTUS_PULSE_FRAMES := LOTUS_PULSE_COLS * LOTUS_PULSE_ROWS
const CYBER_SNAKE_COLS := 16
const CYBER_SNAKE_ROWS := 1
const CYBER_SNAKE_FRAMES := CYBER_SNAKE_COLS * CYBER_SNAKE_ROWS
const MOTION_SPRITES_COLS := 3
const MOTION_SPRITES_ROWS := 2
const MOTION_SPRITES_FRAMES := MOTION_SPRITES_COLS * MOTION_SPRITES_ROWS
const LOTUS_FRAME_INTERVAL_SEC := 1.0 / 12.0
const SNAKE_FRAME_INTERVAL_SEC := 1.0 / 10.0
const INFERNO_PILLAR_TRAIL_RENDER_LIMIT := 14
const INFERNO_PILLAR_TRAIL_RENDER_LIMIT_LOD := 9
const INFERNO_PILLAR_TRAIL_RENDER_LIMIT_SEVERE_LOD := 6
const INFERNO_PILLAR_EDGE_BIAS_MIN := 0.18
const STAGE5_STATIC_HUD_LOD_SCALE := BattleRenderQuality.FPS_CAP_EFFECT_SCALE
const STAGE5_PILLAR_LOD_THRESHOLD := 0.7
const STAGE5_PILLAR_SEVERE_LOD_THRESHOLD := 0.6
# Pillar-letterbox aura widens as the ball drifts outside the central
# playfield. The real ball trail already renders into the letterbox via the
# transformed playfield pass, so this stage only adds ambient pillar wisps
# anchored to the pillar edges rather than a separate snake-shape proxy.
const INFERNO_PILLAR_AURA_OUTSIDE_MARGIN := 12.0

const LEFT_PILLAR_SPECS := [
	{"kind": "lantern", "anchor": Vector2(0.55, 0.16), "size": Vector2(76.0, 76.0), "frame": 0, "alpha": 0.82},
	{"kind": "lantern", "anchor": Vector2(0.36, 0.31), "size": Vector2(62.0, 62.0), "frame": 1, "alpha": 0.68},
	{"kind": "pot", "anchor": Vector2(0.52, 0.61), "size": Vector2(118.0, 128.0), "alpha": 0.82},
	{"kind": "wallmount", "anchor": Vector2(0.64, 0.39), "size": Vector2(86.0, 88.0), "alpha": 0.72},
]
const RIGHT_PILLAR_SPECS := [
	{"kind": "lantern", "anchor": Vector2(0.46, 0.18), "size": Vector2(72.0, 72.0), "frame": 1, "alpha": 0.78},
	{"kind": "lantern", "anchor": Vector2(0.67, 0.34), "size": Vector2(58.0, 58.0), "frame": 0, "alpha": 0.66},
	{"kind": "pot", "anchor": Vector2(0.50, 0.64), "size": Vector2(120.0, 130.0), "alpha": 0.82},
]

var hud_scene_drawer: Object = Stage1PillarHudSceneDrawer.new()
var vase_lantern_texture: Texture2D = null
var snake_pot_texture: Texture2D = null
var wallmount_texture: Texture2D = null
var lotus_pulse_texture: Texture2D = null
var cyber_snake_texture: Texture2D = null
var motion_sprites_texture: Texture2D = null
var textures_loaded := false
var _prewarm_step_index := 0
var _prewarm_character_type := ""
var _prewarm_finished_for := ""


func prewarm_assets(module_getter: Callable, selected_character_type: String = "smasher") -> void:
	while not prewarm_assets_step(module_getter, selected_character_type):
		pass


func prewarm_assets_step(module_getter: Callable, selected_character_type: String = "smasher") -> bool:
	var character_type := str(selected_character_type)
	if _prewarm_finished_for == character_type:
		return true
	if _prewarm_character_type != character_type:
		_prewarm_character_type = character_type
		_prewarm_step_index = 0

	match _prewarm_step_index:
		0:
			if vase_lantern_texture == null:
				vase_lantern_texture = ProjectResourceLoader.load_texture(VASE_LANTERN_PATH)
		1:
			if snake_pot_texture == null:
				snake_pot_texture = ProjectResourceLoader.load_texture(SNAKE_POT_PATH)
		2:
			if wallmount_texture == null:
				wallmount_texture = ProjectResourceLoader.load_texture(WALLMOUNT_PATH)
		3:
			if lotus_pulse_texture == null:
				lotus_pulse_texture = ProjectResourceLoader.load_texture(LOTUS_PULSE_PATH)
		4:
			if cyber_snake_texture == null:
				cyber_snake_texture = ProjectResourceLoader.load_texture(CYBER_SNAKE_PATH)
		5:
			if motion_sprites_texture == null:
				motion_sprites_texture = ProjectResourceLoader.load_texture(MOTION_SPRITES_PATH)
			textures_loaded = true
		6:
			if hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets_step"):
				if not bool(hud_scene_drawer.prewarm_assets_step(module_getter, character_type)):
					return false
			elif hud_scene_drawer != null and hud_scene_drawer.has_method("prewarm_assets"):
				hud_scene_drawer.prewarm_assets(module_getter, character_type)
		7:
			var skill_hud: Object = _get_module(module_getter, "stage5_hongryun_boss_skill_hud_renderer")
			if skill_hud != null and skill_hud.has_method("prewarm_assets_step"):
				if not bool(skill_hud.prewarm_assets_step()):
					return false
			elif skill_hud != null and skill_hud.has_method("prewarm_assets"):
				skill_hud.prewarm_assets()
		8:
			_get_module(module_getter, "stage1_fallback_pillar_renderer")
		_:
			_prewarm_finished_for = character_type
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var total_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var quality_scale: float = _get_pillar_quality_scale(context)

	var stage_background: Object = states.get("stage_background", null)
	var drew_layered_background := false
	var sample_start: int = _perf_begin(perf_logger)
	if stage_background != null:
		drew_layered_background = _draw_stage_background(canvas, stage_background, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	if not drew_layered_background:
		var fallback_renderer: Object = registry.get_instance("stage1_fallback_pillar_renderer")
		if fallback_renderer != null and fallback_renderer.has_method("draw"):
			fallback_renderer.draw(canvas, view_size, game_offset, game_size, height, time_seconds)
	_perf_end(perf_logger, "stage5.pillar.background", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_hongryun_chrome(canvas, view_size, game_offset, game_size, stage_background, time_seconds, quality_scale)
	_draw_inferno_pillar_flourish(canvas, context, view_size, game_offset, game_size, width, height, time_seconds, quality_scale)
	_perf_end(perf_logger, "stage5.pillar.chrome", sample_start)

	sample_start = _perf_begin(perf_logger)
	hud_scene_drawer.draw(
		canvas,
		_with_stage5_hud_lod_context(context, quality_scale),
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
	_perf_end(perf_logger, "stage5.pillar.hud_scene", sample_start)
	_perf_end(perf_logger, "stage5.pillar.total", total_start)


func draw_pillar_hud_overlay(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	hud_scene_drawer.draw(
		canvas,
		_with_stage5_hud_lod_context(context, _get_pillar_quality_scale(context)),
		registry,
		states,
		view_size,
		game_offset,
		game_size,
		time_seconds
	)
	_perf_end(perf_logger, "stage5.pillar.hud_overlay_scene", sample_start)


func draw_pillar_background_overlay(canvas: CanvasItem, context: Dictionary, registry: Object, states: Dictionary) -> void:
	if canvas == null or registry == null:
		return
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var quality_scale: float = _get_pillar_quality_scale(context)
	var stage_background: Object = states.get("stage_background", null)
	if stage_background != null and stage_background.has_method("draw_pillar_background_overlay"):
		stage_background.draw_pillar_background_overlay(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale)
	_perf_end(perf_logger, "stage5.pillar.background_overlay", sample_start)


func draw_post_playfield_hud(canvas: CanvasItem, context: Dictionary, registry: Object) -> void:
	if canvas == null or registry == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_vector2(context, "view_size", Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(context, "game_size", Vector2.ZERO)
	hud_scene_drawer.draw_active_item_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage5.pillar.post_active_hud", sample_start)
	if bool(context.get("suppress_boss_skill_hud", false)):
		return

	sample_start = _perf_begin(perf_logger)
	_draw_stage5_hongryun_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage5.pillar.hongryun_boss_hud", sample_start)


func get_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"vase_lantern": vase_lantern_texture != null,
		"snake_pot": snake_pot_texture != null,
		"wallmount": wallmount_texture != null,
		"lotus_pulse": lotus_pulse_texture != null,
		"cyber_snake": cyber_snake_texture != null,
		"motion_sprites": motion_sprites_texture != null,
		"left_pillar_spec_count": LEFT_PILLAR_SPECS.size(),
		"right_pillar_spec_count": RIGHT_PILLAR_SPECS.size(),
		"inferno_pillar_trail_render_limit": INFERNO_PILLAR_TRAIL_RENDER_LIMIT,
		"inferno_pillar_aura_outside_margin": INFERNO_PILLAR_AURA_OUTSIDE_MARGIN,
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	vase_lantern_texture = ProjectResourceLoader.load_texture(VASE_LANTERN_PATH)
	snake_pot_texture = ProjectResourceLoader.load_texture(SNAKE_POT_PATH)
	wallmount_texture = ProjectResourceLoader.load_texture(WALLMOUNT_PATH)
	lotus_pulse_texture = ProjectResourceLoader.load_texture(LOTUS_PULSE_PATH)
	cyber_snake_texture = ProjectResourceLoader.load_texture(CYBER_SNAKE_PATH)
	motion_sprites_texture = ProjectResourceLoader.load_texture(MOTION_SPRITES_PATH)
	textures_loaded = true


func _draw_hongryun_chrome(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	stage_background: Object,
	time_seconds: float,
	quality_scale: float
) -> void:
	_ensure_textures()
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = game_offset * 2.0 + game_size
	var left_rect := Rect2(Vector2.ZERO, Vector2(maxf(0.0, game_offset.x), view_size.y))
	var right_x := game_offset.x + game_size.x
	var right_rect := Rect2(Vector2(right_x, 0.0), Vector2(maxf(0.0, view_size.x - right_x), view_size.y))
	var inferno_blend := _get_inferno_blend(stage_background)
	_draw_pillar_specs(canvas, left_rect, LEFT_PILLAR_SPECS, false, time_seconds, inferno_blend, quality_scale)
	_draw_pillar_specs(canvas, right_rect, RIGHT_PILLAR_SPECS, true, time_seconds, inferno_blend, quality_scale)
	_draw_motion_sparks(canvas, right_rect, time_seconds, inferno_blend, quality_scale)
	_draw_inferno_chrome(canvas, left_rect, false, time_seconds, inferno_blend)
	_draw_inferno_chrome(canvas, right_rect, true, time_seconds, inferno_blend)


func _draw_pillar_specs(
	canvas: CanvasItem,
	pillar_rect: Rect2,
	specs: Array,
	flip_h: bool,
	time_seconds: float,
	inferno_blend: float,
	quality_scale: float
) -> void:
	if pillar_rect.size.x <= 4.0 or pillar_rect.size.y <= 4.0:
		return
	var scale := clampf(minf(pillar_rect.size.x / 170.0, pillar_rect.size.y / 750.0), 0.55, 1.55)
	var alpha_scale := clampf(0.78 + quality_scale * 0.22, 0.65, 1.0)
	for value in specs:
		if not (value is Dictionary):
			continue
		var spec: Dictionary = value
		var kind := str(spec.get("kind", ""))
		var anchor := _as_vector2(spec.get("anchor", Vector2(0.5, 0.5)), Vector2(0.5, 0.5))
		var base_size := _as_vector2(spec.get("size", Vector2(64.0, 64.0)), Vector2(64.0, 64.0)) * scale
		var center := pillar_rect.position + Vector2(pillar_rect.size.x * anchor.x, pillar_rect.size.y * anchor.y)
		var bob := sin(time_seconds * 2.0 + center.x * 0.01) * (2.0 if kind == "lantern" else 1.0)
		var rect := Rect2(center - base_size * 0.5 + Vector2(0.0, bob), base_size)
		var alpha := clampf(float(spec.get("alpha", 1.0)) * alpha_scale, 0.0, 1.0)
		match kind:
			"lantern":
				_draw_sheet_frame(canvas, vase_lantern_texture, int(spec.get("frame", 0)), rect, Color(1.0, 0.82 + inferno_blend * 0.12, 0.62, alpha), flip_h, VASE_LANTERN_COLS, VASE_LANTERN_ROWS)
			"pot":
				_draw_texture(canvas, snake_pot_texture, rect, Color(0.86 + inferno_blend * 0.14, 0.68, 0.58, alpha), flip_h)
				if inferno_blend > 0.02:
					var lotus_rect := Rect2(rect.get_center() - rect.size * 0.39, rect.size * 0.78)
					var lotus_frame := int(floor(time_seconds / LOTUS_FRAME_INTERVAL_SEC)) % LOTUS_PULSE_FRAMES
					_draw_sheet_frame(canvas, lotus_pulse_texture, lotus_frame, lotus_rect, Color(1.0, 0.42, 0.24, 0.58 * inferno_blend), flip_h, LOTUS_PULSE_COLS, LOTUS_PULSE_ROWS)
			"wallmount":
				_draw_texture(canvas, wallmount_texture, rect, Color(0.90, 0.68 + inferno_blend * 0.12, 0.58, alpha), flip_h)


func _draw_motion_sparks(canvas: CanvasItem, pillar_rect: Rect2, time_seconds: float, inferno_blend: float, quality_scale: float) -> void:
	if pillar_rect.size.x <= 4.0 or motion_sprites_texture == null:
		return
	var spark_count := 4
	if _is_pillar_severe_lod(quality_scale):
		spark_count = 1
	elif quality_scale <= 0.8:
		spark_count = 2
	for idx in range(spark_count):
		var phase := time_seconds * (0.55 + float(idx) * 0.13) + float(idx) * 1.7
		var center := pillar_rect.position + Vector2(
			pillar_rect.size.x * (0.32 + 0.36 * abs(sin(phase * 0.6))),
			pillar_rect.size.y * (0.18 + 0.55 * fposmod(phase * 0.11 + float(idx) * 0.23, 1.0))
		)
		var size := Vector2.ONE * (18.0 + float(idx % 2) * 8.0)
		var frame := (idx + int(floor(time_seconds * 9.0))) % MOTION_SPRITES_FRAMES
		var alpha := 0.22 + inferno_blend * 0.28
		_draw_sheet_frame(canvas, motion_sprites_texture, frame, Rect2(center - size * 0.5, size), Color(1.0, 0.48, 0.18, alpha), false, MOTION_SPRITES_COLS, MOTION_SPRITES_ROWS)


func _draw_inferno_chrome(canvas: CanvasItem, pillar_rect: Rect2, flip_h: bool, time_seconds: float, inferno_blend: float) -> void:
	if inferno_blend <= 0.02 or pillar_rect.size.x <= 4.0:
		return
	var snake_size := Vector2(
		clampf(pillar_rect.size.x * 0.72, 64.0, 132.0),
		clampf(pillar_rect.size.y * 0.24, 112.0, 190.0)
	)
	var center := pillar_rect.position + Vector2(pillar_rect.size.x * 0.52, pillar_rect.size.y * 0.48)
	center.y += sin(time_seconds * 2.4) * 6.0
	var frame := int(floor(time_seconds / SNAKE_FRAME_INTERVAL_SEC)) % CYBER_SNAKE_FRAMES
	_draw_sheet_frame(canvas, cyber_snake_texture, frame, Rect2(center - snake_size * 0.5, snake_size), Color(1.0, 0.28, 0.14, 0.70 * inferno_blend), flip_h, CYBER_SNAKE_COLS, CYBER_SNAKE_ROWS)


func _draw_inferno_pillar_flourish(
	canvas: CanvasItem,
	context: Dictionary,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	field_width: float,
	field_height: float,
	time_seconds: float,
	quality_scale: float
) -> void:
	if not bool(context.get("stage5_hongryun_inferno_active", false)):
		return
	if int(context.get("stage5_hongryun_inferno_phase", 0)) != 2:
		return
	var trail: Array = _as_array(context.get("stage5_hongryun_inferno_trail", []))
	if trail.size() < 2:
		return
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = game_offset * 2.0 + game_size
	var left_rect := Rect2(Vector2.ZERO, Vector2(maxf(0.0, game_offset.x), view_size.y))
	var right_x := game_offset.x + game_size.x
	var right_rect := Rect2(Vector2(right_x, 0.0), Vector2(maxf(0.0, view_size.x - right_x), view_size.y))
	if left_rect.size.x <= 4.0 and right_rect.size.x <= 4.0:
		return

	# Pillar overshoot rendering: the real ball trail now reaches the letterbox
	# directly because the playfield transform pass does not clip on the main
	# scene canvas (see CLAUDE.md "Godot 플레이필드 = 풀 캔버스, 필러는 레터박스").
	# Here we only paint ambient pillar wisps and overshoot-aware bleed that
	# react to how far the actual head has crossed the playfield boundary.
	var render_limit := _get_pillar_lod_count(
		INFERNO_PILLAR_TRAIL_RENDER_LIMIT,
		INFERNO_PILLAR_TRAIL_RENDER_LIMIT_LOD,
		INFERNO_PILLAR_TRAIL_RENDER_LIMIT_SEVERE_LOD,
		quality_scale
	)
	var start_index: int = max(0, trail.size() - render_limit)
	var head_point := _as_vector2(trail[trail.size() - 1], Vector2(field_width * 0.5, field_height * 0.5))
	var head_left_overshoot: float = maxf(0.0, -head_point.x)
	var head_right_overshoot: float = maxf(0.0, head_point.x - field_width)
	for idx in range(start_index, trail.size()):
		var point := _as_vector2(trail[idx], Vector2.ZERO)
		var t := float(idx - start_index) / maxf(1.0, float(trail.size() - start_index - 1))
		var edge_bias: float = clampf(abs(point.x - field_width * 0.5) / maxf(1.0, field_width * 0.5), INFERNO_PILLAR_EDGE_BIAS_MIN, 1.0)
		var side_wave := sin(time_seconds * 5.0 + float(idx) * 1.13 + point.y * 0.018)
		var draw_left := point.x <= field_width * 0.5 or side_wave < -0.28
		var draw_right := point.x >= field_width * 0.5 or side_wave > 0.28
		var y: float = game_offset.y + clampf(point.y / maxf(1.0, field_height), 0.0, 1.0) * game_size.y
		var alpha: float = (0.10 + t * 0.36) * edge_bias
		var size := Vector2(38.0 + 82.0 * t * edge_bias, 18.0 + 42.0 * t)
		if draw_left:
			var left_boost: float = 1.0 + minf(2.0, head_left_overshoot / 90.0) * t
			_draw_inferno_pillar_wisp(canvas, left_rect, Vector2(game_offset.x + 10.0, y), size * left_boost, t, alpha * left_boost, false, time_seconds, idx, quality_scale)
		if draw_right:
			var right_boost: float = 1.0 + minf(2.0, head_right_overshoot / 90.0) * t
			_draw_inferno_pillar_wisp(canvas, right_rect, Vector2(game_offset.x + game_size.x - 10.0, y), size * right_boost, t, alpha * right_boost, true, time_seconds, idx, quality_scale)


func _draw_inferno_pillar_wisp(
	canvas: CanvasItem,
	pillar_rect: Rect2,
	edge_point: Vector2,
	size: Vector2,
	t: float,
	alpha: float,
	right_side: bool,
	time_seconds: float,
	idx: int,
	quality_scale: float
) -> void:
	if pillar_rect.size.x <= 4.0 or alpha <= 0.0:
		return
	var severe_lod := _is_pillar_severe_lod(quality_scale)
	var side_anchor_x := pillar_rect.position.x + pillar_rect.size.x * (0.30 if right_side else 0.70)
	var drift := sin(time_seconds * 4.1 + float(idx) * 0.61) * pillar_rect.size.x * 0.12
	var center := Vector2(side_anchor_x + drift, edge_point.y + sin(time_seconds * 3.4 + float(idx)) * 10.0)
	var glow_color := Color(1.0, 0.10, 0.02, alpha * 0.34)
	var core_color := Color(1.0, 0.46, 0.12, alpha)
	canvas.draw_line(edge_point, center, glow_color, maxf(8.0, size.y * 0.48), true)
	canvas.draw_line(edge_point, center, core_color, maxf(2.0, size.y * 0.18), true)
	if not severe_lod:
		canvas.draw_circle(center, size.y * 0.92, Color(1.0, 0.07, 0.02, alpha * 0.22))
	canvas.draw_circle(center, size.y * 0.42, Color(1.0, 0.78, 0.20, alpha * 0.46))
	if motion_sprites_texture != null and idx % 2 == 0 and not severe_lod:
		var frame := (idx + int(floor(time_seconds * 12.0))) % MOTION_SPRITES_FRAMES
		var rect := Rect2(center - size * 0.5, size)
		_draw_sheet_frame(canvas, motion_sprites_texture, frame, rect, Color(1.0, 0.36, 0.12, minf(0.75, alpha * 1.8)), right_side, MOTION_SPRITES_COLS, MOTION_SPRITES_ROWS)
	if t > 0.72 and not severe_lod:
		canvas.draw_arc(center, size.x * 0.38, -time_seconds * 5.0, PI * 1.35 - time_seconds * 5.0, 30, Color(1.0, 0.86, 0.26, alpha * 0.82), 2.0, true)


func _draw_stage5_hongryun_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var renderer: Object = _get_stage5_boss_skill_renderer(registry)
	if renderer == null or not renderer.has_method("draw"):
		return
	var state: Object = registry.get_instance("stage5_hongryun_state")
	if state == null or not state.has_method("get_hud_context"):
		return
	var hud_context: Dictionary = context.duplicate(true)
	hud_context.merge(state.get_hud_context(null, context), true)
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	hud_context["time_seconds"] = float(Time.get_ticks_msec()) / 1000.0
	hud_context["stage5_hud_quality_scale"] = _get_pillar_quality_scale(context)
	# Stage 5 routes through this Hongryun drawer, so append the persistent
	# companion card here as well as the legacy compatibility drawer.
	LingpetRailCard.append_entry(hud_context, registry, "stage5_boss_skill_hud_skills", "stage5_boss_skill_hud_active")
	renderer.draw(canvas, hud_context)


func _get_stage5_boss_skill_renderer(registry: Object) -> Object:
	var renderer_key := "stage5_hongryun_boss_skill_hud_renderer"
	var router: Object = registry.get_instance("stage_runtime_router")
	if router != null and router.has_method("get_module_key"):
		var routed_key: String = str(router.get_module_key(5, "boss_skill_hud_renderer"))
		if routed_key != "":
			renderer_key = routed_key
	return registry.get_instance(renderer_key)


func _draw_stage_background(
	canvas: CanvasItem,
	stage_background: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	width: float,
	perf_logger: Object,
	quality_scale: float
) -> bool:
	if not stage_background.has_method("draw"):
		return false
	var arg_count: int = _get_method_argument_count(stage_background, "draw")
	if arg_count >= 7:
		return bool(stage_background.draw(canvas, view_size, game_offset, game_size, width, perf_logger, quality_scale))
	if arg_count >= 6:
		return bool(stage_background.draw(canvas, view_size, game_offset, game_size, width, perf_logger))
	return bool(stage_background.draw(canvas, view_size, game_offset, game_size, width))


func _draw_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color, flip_h: bool) -> void:
	if texture == null:
		_draw_missing_prop(canvas, rect, modulate)
		return
	if flip_h:
		_draw_flipped_texture(canvas, texture, rect, modulate)
	else:
		canvas.draw_texture_rect(texture, rect, false, modulate)


func _draw_sheet_frame(
	canvas: CanvasItem,
	texture: Texture2D,
	frame: int,
	rect: Rect2,
	modulate: Color,
	flip_h: bool,
	cols: int,
	rows: int
) -> void:
	if texture == null:
		_draw_missing_prop(canvas, rect, modulate)
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var safe_cols: int = maxi(1, cols)
	var safe_rows: int = maxi(1, rows)
	var frame_count: int = safe_cols * safe_rows
	var cell_size := Vector2(texture_size.x / float(safe_cols), texture_size.y / float(safe_rows))
	var frame_idx := clampi(frame, 0, frame_count - 1)
	var col := frame_idx % safe_cols
	@warning_ignore("integer_division")
	var row := int(frame_idx / safe_cols)
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	if flip_h:
		_draw_flipped_texture_region(canvas, texture, source_rect, rect, modulate)
	else:
		canvas.draw_texture_rect_region(texture, rect, source_rect, modulate, false, true)


func _draw_flipped_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color) -> void:
	var source_rect := Rect2(Vector2.ZERO, texture.get_size())
	_draw_flipped_texture_region(canvas, texture, source_rect, rect, modulate)


func _draw_flipped_texture_region(canvas: CanvasItem, texture: Texture2D, source_rect: Rect2, rect: Rect2, modulate: Color) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_missing_prop(canvas: CanvasItem, rect: Rect2, modulate: Color) -> void:
	canvas.draw_rect(rect, Color(modulate.r, modulate.g * 0.45, modulate.b * 0.35, modulate.a * 0.28))
	canvas.draw_rect(rect, Color(1.0, 0.42, 0.18, modulate.a * 0.45), false, 1.5, true)


func _get_inferno_blend(stage_background: Object) -> float:
	if stage_background == null:
		return 0.0
	if stage_background.has_method("get_inferno_blend"):
		return clampf(float(stage_background.get_inferno_blend()), 0.0, 1.0)
	if stage_background.has_method("is_inferno_mode_active"):
		return 1.0 if bool(stage_background.is_inferno_mode_active()) else 0.0
	return 0.0


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	for method_info in target.get_method_list():
		if str(method_info.get("name", "")) == method_name:
			var args: Variant = method_info.get("args", [])
			return args.size() if args is Array else 0
	return 0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_pillar_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _with_stage5_hud_lod_context(context: Dictionary, quality_scale: float) -> Dictionary:
	var high_refresh_lod_active := BattleRenderQuality.is_high_refresh_lod_active()
	if quality_scale > STAGE5_STATIC_HUD_LOD_SCALE and not high_refresh_lod_active:
		return context
	var hud_context: Dictionary = context.duplicate()
	hud_context["stage5_pillar_hud_static_lod"] = true
	hud_context["pillar_hud_static_lod"] = true
	return hud_context


func _get_pillar_lod_count(normal_count: int, lod_count: int, severe_count: int, quality_scale: float) -> int:
	if quality_scale <= STAGE5_PILLAR_SEVERE_LOD_THRESHOLD:
		return severe_count
	if quality_scale <= STAGE5_PILLAR_LOD_THRESHOLD:
		return lod_count
	return normal_count


func _is_pillar_severe_lod(quality_scale: float) -> bool:
	return quality_scale <= STAGE5_PILLAR_SEVERE_LOD_THRESHOLD


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
