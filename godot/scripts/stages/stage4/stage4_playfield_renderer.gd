extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

const CENTER_BACKGROUND_PATH := "res://assets/sprites/hud/stage4_center_background_base_imagegen_v2.png"
const CENTER_BORDER_PATH := "res://assets/sprites/hud/stage4_center_thin_border_imagegen_v1.png"
const TEMPLE_BUILDING_PATH := "res://assets/sprites/hud/stage4_center_temple_building_imagegen_v4.png"
const AMBIENT_ATLAS_PATH := "res://assets/sprites/hud/stage4_center_ambient_sprites_imagegen_v3.png"
const AURA_SHEET_PATH := "res://assets/sprites/hud/stage4_floating_temple_aura_sheet_imagegen_v1.png"
const EXPLOSION_SHEET_PATH := "res://assets/sprites/hud/stage4_temple_explosion_sheet_imagegen_v2.png"
const DEBRIS_ATLAS_PATH := "res://assets/sprites/hud/stage4_temple_debris_sprites_imagegen_v1.png"
const RED_MOON_FRAGMENT_ATLAS_PATH := "res://assets/sprites/hud/stage4_red_moon_fragment_atlas_imagegen_v1.png"

const LOGICAL_SIZE := Vector2(760.0, 750.0)
const AMBIENT_COLUMNS := 4
const AMBIENT_ROWS := 2
const AURA_COLUMNS := 4
const AURA_ROWS := 4
const EXPLOSION_COLUMNS := 4
const EXPLOSION_ROWS := 4
const DEBRIS_COLUMNS := 4
const DEBRIS_ROWS := 4
const RED_MOON_FRAGMENT_COLUMNS := 4
const RED_MOON_FRAGMENT_ROWS := 4
const RED_MOON_FRAGMENT_IMAGE_SCALE_MIN := 2.8
const RED_MOON_FRAGMENT_IMAGE_SCALE_MAX := 5.5
const MAX_RENDERED_MOON_FRAGMENTS := 28
const MAX_RENDERED_MOON_FRAGMENTS_LOD := 16
const MOON_FRAGMENT_TRAIL_POINT_LIMIT := 10
const MOON_FRAGMENT_TRAIL_POINT_LIMIT_LOD := 4
const TEMPLE_COLLAPSE_DURATION_SEC := 5.0
const EXPLOSION_START_COLLAPSE_PROGRESS := 0.08
const EXPLOSION_FRAME_INTERVAL_SEC := 0.032
const EXPLOSION_FINAL_HOLD_SEC := 0.10
const EXPLOSION_FADE_SEC := 0.14
const TEMPLE_DRAW_SIZE := Vector2(380.0, 380.0)
const TEMPLE_CENTER := Vector2(380.0, 282.0)
const TEMPLE_FLOAT_AMPLITUDE := 7.0
const TEMPLE_FLOAT_SPEED := 2.10
const STAGE4_CENTER_BORDER_DRAW_ENABLED := true
const STAGE4_CENTER_BORDER_THICKNESS := 2.0
const STAGE4_WALL_FLASH_DURATION_SEC := 15.0 / 60.0
const STAGE4_WALL_FLASH_SIDE_STRIP_STEPS := 3
const STAGE4_WALL_FLASH_SIDE_STRIP_STEPS_LOD := 2
const STAGE4_WALL_FLASH_SATELLITE_COUNT := 2
const STAGE4_WALL_FLASH_SATELLITE_COUNT_LOD := 1
const PLAYFIELD_AURA_SHEET_DRAW_ENABLED := false
const DRAW_DESTRUCTION_DUST_CLOUDS := false
const STAGE4_STADIUM_LINE_DRAW_ENABLED := false
const BACK_ATMOSPHERE_SPARK_COUNT := 10
const BACK_ATMOSPHERE_SPARK_COUNT_LOD := 5
const MAX_RENDERED_COLLAPSE_DEBRIS := 56
const MAX_RENDERED_COLLAPSE_DEBRIS_LOD := 32
const MAX_RENDERED_ROOF_FRAGMENTS := 24
const MAX_RENDERED_ROOF_FRAGMENTS_LOD := 14
const MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE := 8
const MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE_LOD := 5
const MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS := 4
const MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS_LOD := 2
const MAX_RENDERED_DESTRUCTION_WAVE_BEAMS := 12
const MAX_RENDERED_DESTRUCTION_WAVE_BEAMS_LOD := 7
const MAX_RENDERED_DESTRUCTION_WAVE_TRAIL := 22
const MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD := 12
const DESTRUCTION_WAVE_RING_ARC_POINTS := 36
const DESTRUCTION_WAVE_RING_ARC_POINTS_LOD := 24
const DESTRUCTION_WAVE_RING_LAYER_COUNT := 4
const DESTRUCTION_WAVE_RING_LAYER_COUNT_LOD := 2
const DESTRUCTION_WAVE_CORE_ARC_POINTS := 42
const DESTRUCTION_WAVE_CORE_ARC_POINTS_LOD := 28
const DESTRUCTION_WAVE_CORE_POINT_COUNT := 16
const DESTRUCTION_WAVE_CORE_POINT_COUNT_LOD := 12
const DESTRUCTION_WAVE_CORE_LAYER_COUNT := 4
const DESTRUCTION_WAVE_CORE_LAYER_COUNT_LOD := 3
const DESTRUCTION_WAVE_CORE_RING_STEP := 5
const DESTRUCTION_WAVE_CORE_RING_STEP_LOD := 10
const FLOATING_LEAF_RENDER_LIMIT_LOD := 8

const AMBIENT_SPECS := [
	{"index": 7, "center": Vector2(110.0, 120.0), "size": Vector2(92.0, 92.0), "alpha": 0.42},
]

const LANTERN_SPECS := [
	{"center": Vector2(130.0, 300.0), "size": "large", "phase": 0.30, "speed": 0.026},
	{"center": Vector2(630.0, 300.0), "size": "large", "phase": 2.20, "speed": 0.031},
	{"center": Vector2(230.0, 250.0), "size": "medium", "phase": 4.10, "speed": 0.034},
	{"center": Vector2(530.0, 250.0), "size": "medium", "phase": 1.40, "speed": 0.029},
	{"center": Vector2(330.0, 180.0), "size": "small", "phase": 3.20, "speed": 0.037},
	{"center": Vector2(430.0, 180.0), "size": "small", "phase": 5.30, "speed": 0.024},
]

const TRAINING_DUMMY_SPECS := [
	Vector2(200.0, 500.0),
	Vector2(560.0, 500.0),
]

const INCENSE_SPECS := [
	Vector2(150.0, 480.0),
	Vector2(300.0, 480.0),
	Vector2(450.0, 480.0),
]

const FLOATING_LEAF_SPECS := [
	{"start": Vector2(722.0, 42.0), "vel": Vector2(-54.0, 48.0), "size": 8.0, "phase": 0.2, "spin": 1.5},
	{"start": Vector2(646.0, 122.0), "vel": Vector2(-72.0, 62.0), "size": 13.0, "phase": 1.3, "spin": -1.1},
	{"start": Vector2(585.0, 22.0), "vel": Vector2(-64.0, 74.0), "size": 10.0, "phase": 2.1, "spin": 1.9},
	{"start": Vector2(512.0, 236.0), "vel": Vector2(-88.0, 50.0), "size": 15.0, "phase": 3.2, "spin": -1.4},
	{"start": Vector2(466.0, 82.0), "vel": Vector2(-60.0, 70.0), "size": 11.0, "phase": 4.4, "spin": 1.2},
	{"start": Vector2(398.0, 342.0), "vel": Vector2(-78.0, 42.0), "size": 9.0, "phase": 5.1, "spin": -1.7},
	{"start": Vector2(330.0, 190.0), "vel": Vector2(-66.0, 64.0), "size": 14.0, "phase": 0.9, "spin": 1.0},
	{"start": Vector2(268.0, 482.0), "vel": Vector2(-82.0, 58.0), "size": 12.0, "phase": 2.8, "spin": -1.5},
	{"start": Vector2(198.0, 318.0), "vel": Vector2(-70.0, 76.0), "size": 8.0, "phase": 3.7, "spin": 2.0},
	{"start": Vector2(132.0, 585.0), "vel": Vector2(-58.0, 54.0), "size": 15.0, "phase": 4.8, "spin": -0.9},
	{"start": Vector2(62.0, 432.0), "vel": Vector2(-90.0, 66.0), "size": 10.0, "phase": 5.8, "spin": 1.6},
	{"start": Vector2(748.0, 652.0), "vel": Vector2(-74.0, 45.0), "size": 13.0, "phase": 1.8, "spin": -1.3},
	{"start": Vector2(682.0, 538.0), "vel": Vector2(-62.0, 80.0), "size": 11.0, "phase": 2.5, "spin": 1.4},
	{"start": Vector2(604.0, 704.0), "vel": Vector2(-86.0, 40.0), "size": 9.0, "phase": 3.9, "spin": -1.8},
	{"start": Vector2(544.0, 618.0), "vel": Vector2(-68.0, 72.0), "size": 14.0, "phase": 0.5, "spin": 1.1},
]

var center_background: Texture2D = null
var center_border_texture: Texture2D = null
var temple_building: Texture2D = null
var ambient_atlas: Texture2D = null
var aura_sheet: Texture2D = null
var explosion_sheet: Texture2D = null
var debris_atlas: Texture2D = null
var red_moon_fragment_atlas: Texture2D = null
var textures_loaded := false
var time_sec := 0.0
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded:
		return true
	match _prewarm_step_index:
		0:
			center_background = ProjectResourceLoader.load_texture(CENTER_BACKGROUND_PATH)
		1:
			center_border_texture = ProjectResourceLoader.load_texture(CENTER_BORDER_PATH)
		2:
			temple_building = ProjectResourceLoader.load_texture(TEMPLE_BUILDING_PATH)
		3:
			ambient_atlas = ProjectResourceLoader.load_texture(AMBIENT_ATLAS_PATH)
		4:
			aura_sheet = ProjectResourceLoader.load_texture(AURA_SHEET_PATH)
		5:
			explosion_sheet = ProjectResourceLoader.load_texture(EXPLOSION_SHEET_PATH)
		6:
			debris_atlas = ProjectResourceLoader.load_texture(DEBRIS_ATLAS_PATH)
		7:
			red_moon_fragment_atlas = ProjectResourceLoader.load_texture(RED_MOON_FRAGMENT_ATLAS_PATH)
		_:
			textures_loaded = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 7:
		textures_loaded = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	time_sec = 0.0


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	_ensure_textures()
	time_sec += 1.0 / 60.0
	var width: float = maxf(1.0, float(context.get("width", LOGICAL_SIZE.x)))
	var height: float = maxf(1.0, float(context.get("height", LOGICAL_SIZE.y)))
	var scale := Vector2(width / LOGICAL_SIZE.x, height / LOGICAL_SIZE.y)
	var quality_scale: float = _get_playfield_quality_scale(context)
	if center_background != null:
		canvas.draw_texture_rect(center_background, Rect2(Vector2.ZERO, Vector2(width, height)), false)
	else:
		_draw_fallback_background(canvas, width, height)
	_draw_back_atmosphere(canvas, scale, shake_offset, quality_scale)
	var temple_float_offset: float = _get_temple_float_offset()
	if _should_draw_temple_support_aura(context):
		_draw_floating_aura(canvas, scale, shake_offset, temple_float_offset)
	_draw_temple(canvas, context, scale, shake_offset)
	_draw_ambient_props(canvas, context, scale, shake_offset, quality_scale)
	_draw_destruction_particles(canvas, context, scale, shake_offset, quality_scale)
	_draw_stage4_border(canvas, width, height, context, shake_offset)
	_draw_stage4_wall_contact_flash(canvas, context, width, height, shake_offset, quality_scale)
	_draw_destruction_overlays(canvas, context, width, height, scale, shake_offset, quality_scale)


func draw_moon_fragments(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	_ensure_textures()
	var fragments: Array = _as_array(context.get("stage4_moon_fragments", []))
	if fragments.is_empty():
		return
	var width: float = maxf(1.0, float(context.get("width", LOGICAL_SIZE.x)))
	var height: float = maxf(1.0, float(context.get("height", LOGICAL_SIZE.y)))
	var scale := Vector2(width / LOGICAL_SIZE.x, height / LOGICAL_SIZE.y)
	var quality_scale: float = _get_playfield_quality_scale(context)
	var fragment_render_limit: int = _get_lod_count(MAX_RENDERED_MOON_FRAGMENTS, MAX_RENDERED_MOON_FRAGMENTS_LOD, quality_scale)
	var trail_point_limit: int = _get_lod_count(MOON_FRAGMENT_TRAIL_POINT_LIMIT, MOON_FRAGMENT_TRAIL_POINT_LIMIT_LOD, quality_scale)
	for fragment_index in _get_moon_fragment_render_indices(fragments, fragment_render_limit):
		var fragment_value: Variant = fragments[fragment_index]
		if fragment_value is Dictionary:
			_draw_moon_fragment(canvas, fragment_value as Dictionary, scale, shake_offset, trail_point_limit)


func get_imagegen_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"center_background": center_background != null,
		"center_border_texture": center_border_texture != null,
		"center_border_draw_enabled": STAGE4_CENTER_BORDER_DRAW_ENABLED,
		"center_border_thickness": STAGE4_CENTER_BORDER_THICKNESS,
		"wall_contact_flash_enabled": true,
		"wall_contact_flash_duration_sec": STAGE4_WALL_FLASH_DURATION_SEC,
		"wall_contact_flash_side_strip_steps": STAGE4_WALL_FLASH_SIDE_STRIP_STEPS,
		"temple_building": temple_building != null,
		"ambient_atlas": ambient_atlas != null,
		"aura_sheet": aura_sheet != null,
		"explosion_sheet": explosion_sheet != null,
		"debris_atlas": debris_atlas != null,
		"red_moon_fragment_atlas": red_moon_fragment_atlas != null,
		"ambient_sprite_count": AMBIENT_COLUMNS * AMBIENT_ROWS,
		"aura_frame_count": AURA_COLUMNS * AURA_ROWS,
		"explosion_frame_count": EXPLOSION_COLUMNS * EXPLOSION_ROWS,
		"explosion_frame_interval_sec": EXPLOSION_FRAME_INTERVAL_SEC,
		"explosion_animation_duration_sec": _get_explosion_animation_duration_sec(),
		"debris_hint_removed": true,
		"destruction_dust_cloud_draw_enabled": DRAW_DESTRUCTION_DUST_CLOUDS,
		"procedural_ruins_draw_enabled": false,
		"destruction_wave_payload_draw_enabled": true,
		"support_aura_removed_on_collapse": true,
		"stadium_line_draw_enabled": STAGE4_STADIUM_LINE_DRAW_ENABLED,
		"red_moon_fragment_frame_count": RED_MOON_FRAGMENT_COLUMNS * RED_MOON_FRAGMENT_ROWS,
		"red_moon_fragment_image_scale_min": RED_MOON_FRAGMENT_IMAGE_SCALE_MIN,
		"red_moon_fragment_image_scale_max": RED_MOON_FRAGMENT_IMAGE_SCALE_MAX,
		"red_moon_fragment_render_limit": MAX_RENDERED_MOON_FRAGMENTS,
		"red_moon_fragment_render_limit_lod": MAX_RENDERED_MOON_FRAGMENTS_LOD,
		"red_moon_fragment_trail_point_limit": MOON_FRAGMENT_TRAIL_POINT_LIMIT,
		"red_moon_fragment_trail_point_limit_lod": MOON_FRAGMENT_TRAIL_POINT_LIMIT_LOD,
		"floating_motion_enabled": true,
		"floating_lantern_count": LANTERN_SPECS.size(),
		"floating_leaf_count": FLOATING_LEAF_SPECS.size(),
		"playfield_aura_sheet_draw_enabled": PLAYFIELD_AURA_SHEET_DRAW_ENABLED,
		"viper_airborne_lod_supported": true,
		"shared_render_quality_lod_supported": true,
		"back_atmosphere_spark_count": BACK_ATMOSPHERE_SPARK_COUNT,
		"back_atmosphere_spark_count_lod": BACK_ATMOSPHERE_SPARK_COUNT_LOD,
		"floating_leaf_render_limit_lod": FLOATING_LEAF_RENDER_LIMIT_LOD,
		"collapse_debris_render_limit": MAX_RENDERED_COLLAPSE_DEBRIS,
		"collapse_debris_render_limit_lod": MAX_RENDERED_COLLAPSE_DEBRIS_LOD,
		"roof_fragment_render_limit": MAX_RENDERED_ROOF_FRAGMENTS,
		"roof_fragment_render_limit_lod": MAX_RENDERED_ROOF_FRAGMENTS_LOD,
		"ground_fire_particle_render_limit": MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE,
		"ground_fire_particle_render_limit_lod": MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE_LOD,
		"destruction_wave_energy_ring_render_limit": MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS,
		"destruction_wave_energy_ring_render_limit_lod": MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS_LOD,
		"destruction_wave_beam_render_limit": MAX_RENDERED_DESTRUCTION_WAVE_BEAMS,
		"destruction_wave_beam_render_limit_lod": MAX_RENDERED_DESTRUCTION_WAVE_BEAMS_LOD,
		"destruction_wave_trail_render_limit": MAX_RENDERED_DESTRUCTION_WAVE_TRAIL,
		"destruction_wave_trail_render_limit_lod": MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD,
		"destruction_wave_ring_arc_points": DESTRUCTION_WAVE_RING_ARC_POINTS,
		"destruction_wave_ring_arc_points_lod": DESTRUCTION_WAVE_RING_ARC_POINTS_LOD,
		"destruction_wave_ring_layer_count": DESTRUCTION_WAVE_RING_LAYER_COUNT,
		"destruction_wave_ring_layer_count_lod": DESTRUCTION_WAVE_RING_LAYER_COUNT_LOD,
		"destruction_wave_core_arc_points": DESTRUCTION_WAVE_CORE_ARC_POINTS,
		"destruction_wave_core_arc_points_lod": DESTRUCTION_WAVE_CORE_ARC_POINTS_LOD,
		"destruction_wave_core_point_count": DESTRUCTION_WAVE_CORE_POINT_COUNT,
		"destruction_wave_core_point_count_lod": DESTRUCTION_WAVE_CORE_POINT_COUNT_LOD,
		"destruction_wave_core_layer_count": DESTRUCTION_WAVE_CORE_LAYER_COUNT,
		"destruction_wave_core_layer_count_lod": DESTRUCTION_WAVE_CORE_LAYER_COUNT_LOD,
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	prewarm_assets()


func _draw_fallback_background(canvas: CanvasItem, width: float, height: float) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(0.09, 0.075, 0.12, 1.0))
	for idx in range(18):
		var y: float = float(idx) * height / 18.0
		var color := Color(0.12 + float(idx) * 0.002, 0.10, 0.15 + float(idx) * 0.003, 1.0)
		canvas.draw_rect(Rect2(0.0, y, width, height / 18.0 + 1.0), color)


func _draw_back_atmosphere(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2, quality_scale: float) -> void:
	var center := Vector2(LOGICAL_SIZE.x * 0.5, LOGICAL_SIZE.y * 0.50) * scale + shake_offset
	if STAGE4_STADIUM_LINE_DRAW_ENABLED:
		var ring_color := Color(0.94, 0.70, 0.28, 0.22)
		canvas.draw_arc(center, 120.0 * scale.x, 0.0, TAU, 96, ring_color, 2.0, true)
		canvas.draw_line(Vector2(0.0, center.y), Vector2(LOGICAL_SIZE.x * scale.x, center.y), Color(0.76, 0.50, 0.25, 0.20), 2.0, true)
	var spark_count: int = _get_lod_count(BACK_ATMOSPHERE_SPARK_COUNT, BACK_ATMOSPHERE_SPARK_COUNT_LOD, quality_scale)
	for idx in range(spark_count):
		var x: float = fposmod(time_sec * 12.0 + float(idx) * 79.0, LOGICAL_SIZE.x) * scale.x
		var y: float = (95.0 + sin(time_sec * 0.7 + float(idx)) * 26.0 + float(idx % 3) * 42.0) * scale.y
		canvas.draw_circle(Vector2(x, y) + shake_offset, 1.5 + float(idx % 2), Color(1.0, 0.95, 0.62, 0.35))


func _should_draw_temple_support_aura(context: Dictionary) -> bool:
	var visibility: Dictionary = _get_static_decoration_visibility(context)
	return bool(visibility.get("support_aura", false))


func _get_temple_float_offset() -> float:
	return sin(time_sec * TEMPLE_FLOAT_SPEED) * TEMPLE_FLOAT_AMPLITUDE


func _draw_floating_aura(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2, temple_float_offset: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(time_sec * 2.8)
	var shadow_center := Vector2(TEMPLE_CENTER.x, 472.0) * scale + shake_offset
	_draw_ellipse_polygon(canvas, shadow_center, Vector2(170.0, 24.0) * scale, Color(0.02, 0.0, 0.05, 0.25 + pulse * 0.08))
	for idx in range(4):
		var ratio: float = -0.36 + float(idx) * 0.24
		var x: float = TEMPLE_CENTER.x + TEMPLE_DRAW_SIZE.x * ratio * 0.42
		var y1: float = TEMPLE_CENTER.y + TEMPLE_DRAW_SIZE.y * 0.50 + temple_float_offset - 10.0
		var y2: float = 442.0
		canvas.draw_line(
			Vector2(x, y1) * scale + shake_offset,
			Vector2(TEMPLE_CENTER.x + TEMPLE_DRAW_SIZE.x * ratio * 0.12, y2) * scale + shake_offset,
			Color(0.42, 0.92, 0.96, 0.10 + pulse * 0.08),
			1.5,
			true
		)
	if not PLAYFIELD_AURA_SHEET_DRAW_ENABLED or aura_sheet == null:
		_draw_subtle_floating_aura(canvas, shadow_center, scale, pulse)
		return
	var texture_size: Vector2 = aura_sheet.get_size()
	var cell := Vector2(texture_size.x / float(AURA_COLUMNS), texture_size.y / float(AURA_ROWS))
	var frame: int = int(floor(float(Time.get_ticks_msec()) / 95.0)) % (AURA_COLUMNS * AURA_ROWS)
	@warning_ignore("integer_division")
	var source := Rect2(float(frame % AURA_COLUMNS) * cell.x, float(int(frame / AURA_COLUMNS)) * cell.y, cell.x, cell.y)
	var draw_size := Vector2(330.0, 118.0) * scale
	canvas.draw_texture_rect_region(aura_sheet, Rect2(shadow_center - draw_size * 0.5, draw_size), source, Color(1.0, 1.0, 1.0, 0.66 + pulse * 0.14), false, true)


func _draw_subtle_floating_aura(canvas: CanvasItem, shadow_center: Vector2, scale: Vector2, pulse: float) -> void:
	var aura_center := shadow_center - Vector2(0.0, 28.0) * scale
	_draw_ellipse_outline(canvas, aura_center, Vector2(150.0, 22.0) * scale, Color(0.34, 0.92, 0.96, 0.16 + pulse * 0.07), 2.0)
	_draw_ellipse_outline(canvas, aura_center + Vector2(0.0, 5.0) * scale, Vector2(112.0, 15.0) * scale, Color(0.55, 0.22, 0.82, 0.12 + pulse * 0.05), 1.5)
	for idx in range(5):
		var x: float = aura_center.x + (-92.0 + float(idx) * 46.0) * scale.x
		var h: float = (18.0 + sin(time_sec * 2.2 + float(idx)) * 7.0) * scale.y
		canvas.draw_line(
			Vector2(x, aura_center.y + 6.0 * scale.y),
			Vector2(x, aura_center.y - h),
			Color(0.30, 0.86, 0.96, 0.08 + pulse * 0.06),
			1.4,
			true
		)


func _draw_temple(canvas: CanvasItem, context: Dictionary, scale: Vector2, shake_offset: Vector2) -> void:
	var collapse: float = clampf(float(context.get("stage4_collapse_progress", 0.0)), 0.0, 1.0)
	if bool(context.get("stage4_temple_destroyed", false)):
		_draw_ruins(canvas, scale, shake_offset)
		return
	if collapse > EXPLOSION_START_COLLAPSE_PROGRESS:
		if _draw_explosion_sheet(canvas, context, collapse, scale, shake_offset):
			return
		_draw_ruins(canvas, scale, shake_offset)
		return
	if temple_building == null:
		_draw_fallback_temple(canvas, scale, shake_offset, collapse)
		return
	var sink := Vector2(0.0, 130.0 * collapse) * scale
	var crush_scale_y: float = 1.0 - collapse * 0.50
	var draw_size := Vector2(TEMPLE_DRAW_SIZE.x * scale.x, TEMPLE_DRAW_SIZE.y * scale.y * crush_scale_y)
	var float_offset: float = _get_temple_float_offset() * (1.0 - collapse)
	var center := (TEMPLE_CENTER + Vector2(0.0, float_offset)) * scale + shake_offset + sink
	canvas.draw_texture_rect(temple_building, Rect2(center - draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, 0.96))


func get_debug_temple_explosion_frame_index(context: Dictionary) -> int:
	var collapse: float = clampf(float(context.get("stage4_collapse_progress", 0.0)), 0.0, 1.0)
	if collapse <= EXPLOSION_START_COLLAPSE_PROGRESS:
		return -1
	var explosion_elapsed: float = _get_explosion_elapsed_seconds(context, collapse)
	if _get_explosion_alpha(explosion_elapsed) <= 0.01:
		return -1
	return _get_explosion_frame_index(explosion_elapsed)


func _draw_explosion_sheet(canvas: CanvasItem, context: Dictionary, progress: float, scale: Vector2, shake_offset: Vector2) -> bool:
	if explosion_sheet == null:
		return false
	var explosion_elapsed: float = _get_explosion_elapsed_seconds(context, progress)
	var alpha: float = _get_explosion_alpha(explosion_elapsed)
	if alpha <= 0.01:
		return false
	var texture_size: Vector2 = explosion_sheet.get_size()
	var cell := Vector2(texture_size.x / float(EXPLOSION_COLUMNS), texture_size.y / float(EXPLOSION_ROWS))
	var frame: int = _get_explosion_frame_index(explosion_elapsed)
	@warning_ignore("integer_division")
	var source := Rect2(float(frame % EXPLOSION_COLUMNS) * cell.x, float(int(frame / EXPLOSION_COLUMNS)) * cell.y, cell.x, cell.y)
	var animation_ratio: float = clampf(explosion_elapsed / maxf(0.001, _get_explosion_animation_duration_sec()), 0.0, 1.0)
	var draw_size := Vector2(420.0, 420.0) * scale * (1.0 + animation_ratio * 0.08)
	var center := Vector2(380.0, 332.0) * scale + shake_offset
	canvas.draw_texture_rect_region(explosion_sheet, Rect2(center - draw_size * 0.5, draw_size), source, Color(1.0, 1.0, 1.0, alpha), false, true)
	return true


func _get_explosion_elapsed_seconds(context: Dictionary, collapse_progress: float) -> float:
	var collapse_elapsed: float = maxf(
		0.0,
		float(context.get("stage4_destruction_phase_timer", collapse_progress * TEMPLE_COLLAPSE_DURATION_SEC))
	)
	var start_time: float = EXPLOSION_START_COLLAPSE_PROGRESS * TEMPLE_COLLAPSE_DURATION_SEC
	return maxf(0.0, collapse_elapsed - start_time)


func _get_explosion_frame_index(explosion_elapsed: float) -> int:
	var frame_count: int = EXPLOSION_COLUMNS * EXPLOSION_ROWS
	return clampi(int(floor(maxf(0.0, explosion_elapsed) / EXPLOSION_FRAME_INTERVAL_SEC)), 0, frame_count - 1)


func _get_explosion_animation_duration_sec() -> float:
	return EXPLOSION_FRAME_INTERVAL_SEC * float(EXPLOSION_COLUMNS * EXPLOSION_ROWS)


func _get_explosion_alpha(explosion_elapsed: float) -> float:
	var fade_start: float = _get_explosion_animation_duration_sec() + EXPLOSION_FINAL_HOLD_SEC
	if explosion_elapsed <= fade_start:
		return 1.0
	return clampf(1.0 - (explosion_elapsed - fade_start) / maxf(0.001, EXPLOSION_FADE_SEC), 0.0, 1.0)


func _draw_ruins(_canvas: CanvasItem, _scale: Vector2, _shake_offset: Vector2) -> void:
	# Python Stage 4 leaves the floating temple space clean after destruction.
	return


func _draw_fallback_temple(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2, collapse: float) -> void:
	var float_offset: float = _get_temple_float_offset() * (1.0 - collapse)
	var center := (TEMPLE_CENTER + Vector2(0.0, float_offset)) * scale + shake_offset + Vector2(0.0, 120.0 * collapse) * scale
	var body_rect := Rect2(center + Vector2(-120.0, -80.0) * scale, Vector2(240.0, 150.0) * scale)
	canvas.draw_rect(body_rect, Color(0.20, 0.17, 0.19, 0.96))
	for level in range(5):
		var y: float = center.y - (134.0 - float(level) * 42.0) * scale.y
		var half_w: float = (110.0 - float(level) * 13.0) * scale.x
		var points := PackedVector2Array([
			Vector2(center.x - half_w, y),
			Vector2(center.x + half_w, y),
			Vector2(center.x + half_w * 0.82, y - 18.0 * scale.y),
			Vector2(center.x - half_w * 0.82, y - 18.0 * scale.y),
		])
		canvas.draw_colored_polygon(points, Color(0.38, 0.15, 0.13, 0.96))


func _draw_ambient_props(canvas: CanvasItem, context: Dictionary, scale: Vector2, shake_offset: Vector2, quality_scale: float) -> void:
	var visibility: Dictionary = _get_static_decoration_visibility(context)
	if ambient_atlas == null:
		if bool(visibility.get("brazier", false)):
			_draw_fallback_brazier(canvas, context, scale, shake_offset)
		return
	for spec in AMBIENT_SPECS:
		var center: Vector2 = spec["center"] * scale + shake_offset
		var bob := Vector2(0.0, sin(time_sec * 2.0 + float(spec["index"])) * 2.0) * scale
		_draw_atlas_sprite(canvas, int(spec["index"]), center + bob, spec["size"] * scale, float(spec["alpha"]))
	if bool(visibility.get("lanterns", false)):
		_draw_lanterns(canvas, scale, shake_offset)
	if bool(visibility.get("training_dummies", false)):
		_draw_training_dummies(canvas, scale, shake_offset)
	if bool(visibility.get("incense", false)):
		_draw_incense(canvas, scale, shake_offset)
	if bool(visibility.get("brazier", false)):
		var brazier_index: int = 4 if bool(context.get("stage4_brazier_lit", false)) else 3
		var brazier_bob: float = sin(time_sec * 1.44 + 1.8) * 4.0
		_draw_atlas_sprite_midbottom(canvas, brazier_index, (Vector2(380.0, 608.0 + brazier_bob) * scale) + shake_offset, Vector2(98.0, 96.0) * scale, 0.96)
	_draw_floating_leaves(canvas, scale, shake_offset, quality_scale)


func get_debug_static_decoration_visibility(context: Dictionary) -> Dictionary:
	return _get_static_decoration_visibility(context)


func _get_static_decoration_visibility(context: Dictionary) -> Dictionary:
	var collapse: float = clampf(float(context.get("stage4_collapse_progress", 0.0)), 0.0, 1.0)
	var destroyed: bool = bool(context.get("stage4_temple_destroyed", false))
	var destruction_active: bool = bool(context.get("stage4_destruction_active", false))
	var phase: int = int(context.get("stage4_destruction_phase", 0))
	var collapsing: bool = phase >= 4 or collapse > EXPLOSION_START_COLLAPSE_PROGRESS
	var decorations_gone: bool = bool(context.get("stage4_decorations_destroyed", false)) or destroyed or collapsing
	return {
		"lanterns": not destruction_active and not decorations_gone,
		"training_dummies": not decorations_gone,
		"incense": not decorations_gone,
		"brazier": not decorations_gone,
		"support_aura": not decorations_gone,
		"stadium_lines": STAGE4_STADIUM_LINE_DRAW_ENABLED,
	}


func _draw_lanterns(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2) -> void:
	for lantern in LANTERN_SPECS:
		var size_name: String = str(lantern.get("size", "medium"))
		var sprite_index := 0
		var sprite_size := Vector2(66.0, 88.0)
		if size_name == "large":
			sprite_index = 1
			sprite_size = Vector2(86.0, 104.0)
		elif size_name == "small":
			sprite_size = Vector2(56.0, 76.0)
		var phase: float = float(lantern.get("phase", 0.0))
		var frame_phase: float = time_sec * 60.0
		var swing: float = sin(frame_phase * float(lantern.get("speed", 0.03)) + phase) * 4.0
		var bob: float = sin(frame_phase * 0.032 + phase * 0.73) * 5.0
		var pulse: float = 0.92 + 0.08 * sin(time_sec * 1.8 + phase)
		var center: Vector2 = _as_vector2(lantern.get("center", Vector2.ZERO), Vector2.ZERO) + Vector2(swing, bob)
		_draw_atlas_sprite(canvas, sprite_index, center * scale + shake_offset, sprite_size * scale, clampf(0.91 * pulse, 0.74, 1.0))


func _draw_training_dummies(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2) -> void:
	for pos_value in TRAINING_DUMMY_SPECS:
		var pos: Vector2 = _as_vector2(pos_value, Vector2.ZERO)
		var bob: float = sin(time_sec * 60.0 * 0.026 + pos.x * 0.017) * 5.0
		_draw_atlas_sprite_midbottom(canvas, 2, (pos + Vector2(0.0, 24.0 + bob)) * scale + shake_offset, Vector2(86.0, 108.0) * scale, 0.82)


func _draw_incense(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2) -> void:
	var alpha: float = clampf((188.0 + 34.0 * sin(time_sec * 60.0 * 0.05)) / 255.0, 0.47, 0.92)
	for idx in range(INCENSE_SPECS.size()):
		var pos: Vector2 = _as_vector2(INCENSE_SPECS[idx], Vector2.ZERO)
		var bob: float = sin(time_sec * 60.0 * 0.028 + float(idx) * 1.47) * 4.0
		_draw_atlas_sprite_midbottom(canvas, 5, (pos + Vector2(0.0, 4.0 + bob)) * scale + shake_offset, Vector2(66.0, 84.0) * scale, alpha)


func _draw_floating_leaves(canvas: CanvasItem, scale: Vector2, shake_offset: Vector2, quality_scale: float) -> void:
	var leaf_count: int = _get_lod_count(FLOATING_LEAF_SPECS.size(), FLOATING_LEAF_RENDER_LIMIT_LOD, quality_scale)
	for leaf_index in range(leaf_count):
		var spec_index: int = int(floor(float(leaf_index) * float(FLOATING_LEAF_SPECS.size()) / maxf(1.0, float(leaf_count))))
		var leaf: Dictionary = FLOATING_LEAF_SPECS[spec_index]
		var start: Vector2 = _as_vector2(leaf.get("start", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(leaf.get("vel", Vector2(-66.0, 58.0)), Vector2(-66.0, 58.0))
		var phase: float = float(leaf.get("phase", 0.0))
		var wind: Vector2 = Vector2(
			sin(time_sec * 1.3 + phase) * 18.0,
			cos(time_sec * 0.9 + phase * 1.7) * 9.0
		)
		var pos := Vector2(
			fposmod(start.x + vel.x * time_sec + wind.x + 50.0, LOGICAL_SIZE.x + 100.0) - 50.0,
			fposmod(start.y + vel.y * time_sec + wind.y + 50.0, LOGICAL_SIZE.y + 100.0) - 50.0
		)
		var leaf_size: float = float(leaf.get("size", 10.0))
		var rotation: float = phase + time_sec * float(leaf.get("spin", 1.0))
		_draw_atlas_sprite_rotated(canvas, 6, pos * scale + shake_offset, Vector2(maxf(18.0, leaf_size * 3.0), maxf(14.0, leaf_size * 2.0)) * scale, rotation, 0.82)


func _draw_destruction_particles(canvas: CanvasItem, context: Dictionary, scale: Vector2, shake_offset: Vector2, quality_scale: float) -> void:
	if DRAW_DESTRUCTION_DUST_CLOUDS:
		_draw_dust_clouds(canvas, _as_array(context.get("stage4_dust_clouds", [])), scale, shake_offset)
	var collapse_debris_limit: int = _get_lod_count(MAX_RENDERED_COLLAPSE_DEBRIS, MAX_RENDERED_COLLAPSE_DEBRIS_LOD, quality_scale)
	var roof_fragment_limit: int = _get_lod_count(MAX_RENDERED_ROOF_FRAGMENTS, MAX_RENDERED_ROOF_FRAGMENTS_LOD, quality_scale)
	var ground_fire_particle_limit: int = _get_lod_count(MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE, MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE_LOD, quality_scale)
	_draw_falling_lanterns(canvas, _as_array(context.get("stage4_falling_lanterns", [])), scale, shake_offset)
	_draw_debris_array(canvas, _as_array(context.get("stage4_collapse_debris", [])), context, scale, shake_offset, collapse_debris_limit)
	_draw_debris_array(canvas, _as_array(context.get("stage4_roof_fragments", [])), context, scale, shake_offset, roof_fragment_limit)
	_draw_ground_fires(canvas, _as_array(context.get("stage4_ground_fires", [])), scale, shake_offset, ground_fire_particle_limit)


func _draw_debris_array(canvas: CanvasItem, debris_values: Array, context: Dictionary, scale: Vector2, shake_offset: Vector2, render_limit: int) -> void:
	var phase_timer: float = float(context.get("stage4_destruction_phase_timer", 0.0))
	for debris_index in range(_recent_start(debris_values, render_limit), debris_values.size()):
		var debris_value: Variant = debris_values[debris_index]
		if debris_value is Dictionary:
			_draw_debris_piece(canvas, debris_value as Dictionary, phase_timer, scale, shake_offset)


func _draw_debris_piece(canvas: CanvasItem, debris: Dictionary, phase_timer: float, scale: Vector2, shake_offset: Vector2) -> void:
	if phase_timer <= float(debris.get("delay", 0.0)):
		return
	var opacity: float = clampf(float(debris.get("opacity", 1.0)), 0.0, 1.0)
	if opacity <= 0.01:
		return
	var center := Vector2(float(debris.get("x", 0.0)), float(debris.get("y", 0.0))) * scale + shake_offset
	var logical_size: float = clampf(float(debris.get("size", 8.0)) * 3.0 * float(debris.get("sprite_scale_jitter", 1.0)), 4.0, 72.0)
	var draw_size := Vector2(logical_size, logical_size) * scale
	if debris_atlas != null:
		var texture_size: Vector2 = debris_atlas.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var cell := Vector2(texture_size.x / float(DEBRIS_COLUMNS), texture_size.y / float(DEBRIS_ROWS))
			var sprite_index: int = wrapi(int(debris.get("sprite_index", 15)), 0, DEBRIS_COLUMNS * DEBRIS_ROWS)
			@warning_ignore("integer_division")
			var source := Rect2(float(sprite_index % DEBRIS_COLUMNS) * cell.x, float(int(sprite_index / DEBRIS_COLUMNS)) * cell.y, cell.x, cell.y)
			_draw_texture_region_rotated(canvas, debris_atlas, source, center, draw_size, deg_to_rad(-float(debris.get("rotation", 0.0))), Color(1.0, 1.0, 1.0, opacity), bool(debris.get("sprite_flip_x", false)))
			return
	_draw_fallback_debris_piece(canvas, center, draw_size.x * 0.5, str(debris.get("type", "stone")), opacity, deg_to_rad(float(debris.get("rotation", 0.0))))


func _draw_falling_lanterns(canvas: CanvasItem, lantern_values: Array, scale: Vector2, shake_offset: Vector2) -> void:
	for lantern_value in lantern_values:
		if not (lantern_value is Dictionary):
			continue
		var lantern: Dictionary = lantern_value as Dictionary
		if bool(lantern.get("broken", false)):
			continue
		var size_name: String = str(lantern.get("size", "medium"))
		var sprite_index := 0
		var sprite_size := Vector2(66.0, 88.0)
		if size_name == "large":
			sprite_index = 1
			sprite_size = Vector2(86.0, 104.0)
		elif size_name == "small":
			sprite_size = Vector2(56.0, 76.0)
		var deformation: float = clampf(float(lantern.get("deformation", 0.0)), 0.0, 0.8)
		var draw_size := Vector2(sprite_size.x * (1.0 + deformation * 0.5), sprite_size.y * (1.0 - deformation)) * scale
		var center := Vector2(float(lantern.get("x", 0.0)), float(lantern.get("y", 0.0))) * scale + shake_offset
		var alpha: float = clampf(0.82 - deformation * 0.28, 0.42, 0.86)
		if ambient_atlas != null:
			_draw_atlas_sprite_rotated(canvas, sprite_index, center, draw_size, deg_to_rad(float(lantern.get("rotation", 0.0))), alpha)
		else:
			_draw_fallback_falling_lantern(canvas, center, draw_size, deg_to_rad(float(lantern.get("rotation", 0.0))), alpha)


func _draw_dust_clouds(canvas: CanvasItem, dust_values: Array, scale: Vector2, shake_offset: Vector2) -> void:
	for dust_value in dust_values:
		if not (dust_value is Dictionary):
			continue
		var dust: Dictionary = dust_value as Dictionary
		var opacity: float = clampf(float(dust.get("opacity", 0.0)), 0.0, 1.0)
		if opacity <= 0.01:
			continue
		var center := Vector2(float(dust.get("x", 0.0)), float(dust.get("y", 0.0))) * scale + shake_offset
		var size: float = maxf(2.0, float(dust.get("size", 30.0)) * scale.x)
		var color := Color(0.28, 0.24, 0.20, opacity * 0.52)
		for layer in range(3):
			var layer_ratio: float = 1.0 - float(layer) * 0.22
			var layer_alpha: float = opacity * (0.42 - float(layer) * 0.10)
			var offsets := [
				Vector2.ZERO,
				Vector2(-size * 0.28, -size * 0.12),
				Vector2(size * 0.28, -size * 0.08),
				Vector2(-size * 0.18, size * 0.16),
				Vector2(size * 0.20, size * 0.13),
			]
			for offset in offsets:
				canvas.draw_circle(center + offset, size * 0.42 * layer_ratio, Color(color.r, color.g, color.b, layer_alpha))


func _draw_ground_fires(canvas: CanvasItem, fire_values: Array, scale: Vector2, shake_offset: Vector2, particle_render_limit: int) -> void:
	for fire_value in fire_values:
		if not (fire_value is Dictionary):
			continue
		var particles: Array = _as_array((fire_value as Dictionary).get("particles", []))
		for particle_index in range(_recent_start(particles, particle_render_limit), particles.size()):
			var particle_value: Variant = particles[particle_index]
			if not (particle_value is Dictionary):
				continue
			var particle: Dictionary = particle_value as Dictionary
			var life_ratio: float = clampf(float(particle.get("life", 0.0)) / 40.0, 0.0, 1.0)
			if life_ratio <= 0.01:
				continue
			var phase: float = float(particle.get("color_phase", 0.0))
			var color := Color(1.0, 0.22, 0.12, 0.72 * life_ratio)
			if phase < 0.3:
				color = Color(1.0, 0.92, 0.36, 0.76 * life_ratio)
			elif phase < 0.6:
				color = Color(1.0, 0.55, 0.18, 0.74 * life_ratio)
			var pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) * scale + shake_offset
			var radius: float = maxf(1.0, float(particle.get("size", 3.0)) * scale.x)
			canvas.draw_circle(pos, radius, color)
			canvas.draw_circle(pos, maxf(1.0, radius * 0.34), Color(1.0, 0.94, 0.68, color.a * 0.86))


func _draw_texture_region_rotated(canvas: CanvasItem, texture: Texture2D, source: Rect2, center: Vector2, size: Vector2, rotation: float, color: Color, flip_x: bool = false) -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var half := size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner.rotated(rotation))
	var left_x: float = source.position.x
	var right_x: float = source.position.x + source.size.x
	if flip_x:
		var tmp: float = left_x
		left_x = right_x
		right_x = tmp
	var uvs := PackedVector2Array([
		Vector2(left_x, source.position.y),
		Vector2(right_x, source.position.y),
		Vector2(right_x, source.position.y + source.size.y),
		Vector2(left_x, source.position.y + source.size.y),
	])
	canvas.draw_polygon(points, PackedColorArray([color, color, color, color]), uvs, texture)


func _draw_fallback_debris_piece(canvas: CanvasItem, center: Vector2, radius: float, debris_type: String, opacity: float, rotation: float) -> void:
	var color := Color(0.36, 0.25, 0.20, opacity)
	if debris_type == "roof_tile":
		color = Color(0.52, 0.16, 0.13, opacity)
	elif debris_type == "glass":
		color = Color(1.0, 0.62, 0.42, opacity)
	elif debris_type == "spire_ornament":
		color = Color(0.95, 0.72, 0.28, opacity)
	var points := PackedVector2Array()
	for idx in range(5):
		var angle: float = rotation + TAU * float(idx) / 5.0
		var local_radius: float = radius * (0.65 + 0.18 * float(idx % 2))
		points.append(center + Vector2(cos(angle), sin(angle)) * local_radius)
	canvas.draw_colored_polygon(points, color)


func _draw_fallback_falling_lantern(canvas: CanvasItem, center: Vector2, size: Vector2, rotation: float, alpha: float) -> void:
	var half := size * 0.5
	var corners := [
		Vector2(-half.x * 0.55, -half.y * 0.45),
		Vector2(half.x * 0.55, -half.y * 0.45),
		Vector2(half.x * 0.42, half.y * 0.48),
		Vector2(-half.x * 0.42, half.y * 0.48),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner.rotated(rotation))
	canvas.draw_colored_polygon(points, Color(0.75, 0.08, 0.06, alpha))
	canvas.draw_polyline(points, Color(0.16, 0.10, 0.07, alpha), 1.0, true)


func _draw_atlas_sprite(canvas: CanvasItem, index: int, center: Vector2, size: Vector2, alpha: float) -> void:
	var texture_size: Vector2 = ambient_atlas.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cell := Vector2(texture_size.x / float(AMBIENT_COLUMNS), texture_size.y / float(AMBIENT_ROWS))
	var safe_index: int = wrapi(index, 0, AMBIENT_COLUMNS * AMBIENT_ROWS)
	@warning_ignore("integer_division")
	var source := Rect2(float(safe_index % AMBIENT_COLUMNS) * cell.x, float(int(safe_index / AMBIENT_COLUMNS)) * cell.y, cell.x, cell.y)
	canvas.draw_texture_rect_region(ambient_atlas, Rect2(center - size * 0.5, size), source, Color(1.0, 1.0, 1.0, alpha), false, true)


func _draw_atlas_sprite_midbottom(canvas: CanvasItem, index: int, midbottom: Vector2, size: Vector2, alpha: float) -> void:
	_draw_atlas_sprite(canvas, index, midbottom - Vector2(0.0, size.y * 0.5), size, alpha)


func _draw_atlas_sprite_rotated(canvas: CanvasItem, index: int, center: Vector2, size: Vector2, rotation: float, alpha: float) -> void:
	var texture_size: Vector2 = ambient_atlas.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var cell := Vector2(texture_size.x / float(AMBIENT_COLUMNS), texture_size.y / float(AMBIENT_ROWS))
	var safe_index: int = wrapi(index, 0, AMBIENT_COLUMNS * AMBIENT_ROWS)
	@warning_ignore("integer_division")
	var source := Rect2(float(safe_index % AMBIENT_COLUMNS) * cell.x, float(int(safe_index / AMBIENT_COLUMNS)) * cell.y, cell.x, cell.y)
	var half := size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner.rotated(rotation))
	var uvs := PackedVector2Array([
		source.position,
		source.position + Vector2(source.size.x, 0.0),
		source.position + source.size,
		source.position + Vector2(0.0, source.size.y),
	])
	var colors := PackedColorArray([
		Color(1.0, 1.0, 1.0, alpha),
		Color(1.0, 1.0, 1.0, alpha),
		Color(1.0, 1.0, 1.0, alpha),
		Color(1.0, 1.0, 1.0, alpha),
	])
	canvas.draw_polygon(points, colors, uvs, ambient_atlas)


func _draw_fallback_brazier(canvas: CanvasItem, context: Dictionary, scale: Vector2, shake_offset: Vector2) -> void:
	var center := Vector2(380.0, 582.0) * scale + shake_offset
	canvas.draw_rect(Rect2(center + Vector2(-34.0, -8.0) * scale, Vector2(68.0, 20.0) * scale), Color(0.28, 0.21, 0.18, 1.0))
	if bool(context.get("stage4_brazier_lit", false)):
		canvas.draw_circle(center + Vector2(0.0, -18.0) * scale, 18.0 * scale.x, Color(1.0, 0.28, 0.08, 0.65))


func _draw_stage4_border(canvas: CanvasItem, width: float, height: float, context: Dictionary, shake_offset: Vector2) -> void:
	if STAGE4_CENTER_BORDER_DRAW_ENABLED:
		_draw_stage4_center_border(canvas, width, height, context, shake_offset)
	if not STAGE4_STADIUM_LINE_DRAW_ENABLED:
		return
	_draw_stage4_stadium_line_border(canvas, width, height, context, shake_offset)


func _draw_stage4_center_border(canvas: CanvasItem, width: float, height: float, context: Dictionary, shake_offset: Vector2) -> void:
	if center_border_texture != null:
		canvas.draw_texture_rect(center_border_texture, Rect2(shake_offset, Vector2(width, height)), false)
		return
	var red: float = clampf(float(context.get("stage4_moon_red_intensity", 0.0)), 0.0, 1.0)
	var outer := Color(0.74 + red * 0.16, 0.48 - red * 0.16, 0.22 - red * 0.06, 0.62)
	var inner := Color(0.28 + red * 0.16, 0.82 - red * 0.38, 0.86 - red * 0.44, 0.30)
	var shadow := Color(0.02, 0.01, 0.03, 0.36)
	var outer_rect := Rect2(Vector2(1.0, 1.0) + shake_offset, Vector2(width - 2.0, height - 2.0))
	var inner_rect := Rect2(Vector2(7.0, 7.0) + shake_offset, Vector2(width - 14.0, height - 14.0))
	canvas.draw_rect(outer_rect, shadow, false, STAGE4_CENTER_BORDER_THICKNESS + 1.0, true)
	canvas.draw_rect(outer_rect, outer, false, STAGE4_CENTER_BORDER_THICKNESS, true)
	canvas.draw_rect(inner_rect, inner, false, 1.0, true)
	var corner_len: float = 34.0
	var inset: float = 12.0
	var right: float = width - inset
	var bottom: float = height - inset
	var accent := Color(0.88, 0.64, 0.24, 0.48)
	for corner in [
		Vector2(inset, inset),
		Vector2(right, inset),
		Vector2(inset, bottom),
		Vector2(right, bottom),
	]:
		var x_dir: float = 1.0 if corner.x < width * 0.5 else -1.0
		var y_dir: float = 1.0 if corner.y < height * 0.5 else -1.0
		canvas.draw_line(corner + shake_offset, corner + Vector2(corner_len * x_dir, 0.0) + shake_offset, accent, 1.0, true)
		canvas.draw_line(corner + shake_offset, corner + Vector2(0.0, corner_len * y_dir) + shake_offset, accent, 1.0, true)


func _draw_stage4_stadium_line_border(canvas: CanvasItem, width: float, height: float, context: Dictionary, shake_offset: Vector2) -> void:
	var red: float = clampf(float(context.get("stage4_moon_red_intensity", 0.0)), 0.0, 1.0)
	var outer := Color(0.72 + red * 0.22, 0.48 - red * 0.18, 0.18 - red * 0.08, 0.82)
	var inner := Color(0.12 + red * 0.45, 0.72 - red * 0.42, 0.72 - red * 0.55, 0.35 + red * 0.20)
	canvas.draw_rect(Rect2(shake_offset, Vector2(width, height)), outer, false, 5.0, true)
	canvas.draw_rect(Rect2(Vector2(8.0, 8.0) + shake_offset, Vector2(width - 16.0, height - 16.0)), inner, false, 2.0, true)
	for idx in range(16):
		var x: float = 18.0 + float(idx) * (width - 36.0) / 15.0
		canvas.draw_line(Vector2(x, 9.0) + shake_offset, Vector2(x + 10.0, 24.0) + shake_offset, Color(0.95, 0.66, 0.25, 0.36), 1.0, true)
		canvas.draw_line(Vector2(x, height - 9.0) + shake_offset, Vector2(x - 10.0, height - 24.0) + shake_offset, Color(0.95, 0.66, 0.25, 0.36), 1.0, true)


func _draw_stage4_wall_contact_flash(
	canvas: CanvasItem,
	context: Dictionary,
	width: float,
	height: float,
	shake_offset: Vector2,
	quality_scale: float
) -> void:
	var timer: float = float(context.get("stage4_wall_flash_timer", 0.0))
	if timer <= 0.0:
		return
	var duration: float = maxf(0.001, float(context.get("stage4_wall_flash_duration", STAGE4_WALL_FLASH_DURATION_SEC)))
	var ratio: float = clampf(timer / duration, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var impact_pos: Vector2 = _as_vector2(
		context.get("stage4_wall_flash_position", Vector2(width * 0.5, height * 0.5)),
		Vector2(width * 0.5, height * 0.5)
	)
	var side: String = str(context.get("stage4_wall_flash_side", "")).strip_edges().to_lower()
	if side != "left" and side != "right":
		side = "left" if impact_pos.x <= width * 0.5 else "right"
	if side != "left" and side != "right":
		return
	var speed_scale: float = clampf(float(context.get("stage4_wall_flash_speed", 0.0)) / 35.0, 0.70, 1.45)
	var side_dir: float = 1.0 if side == "left" else -1.0
	var wall_x: float = STAGE4_CENTER_BORDER_THICKNESS * 0.5 if side == "left" else width - STAGE4_CENTER_BORDER_THICKNESS * 0.5
	var spark_y: float = clampf(impact_pos.y, 16.0, height - 16.0)
	var strip_steps: int = _get_lod_count(
		STAGE4_WALL_FLASH_SIDE_STRIP_STEPS,
		STAGE4_WALL_FLASH_SIDE_STRIP_STEPS_LOD,
		quality_scale
	)
	for i in range(strip_steps):
		var side_t: float = 1.0 - float(i) / maxf(1.0, float(strip_steps))
		var side_alpha: float = 0.12 * ratio * side_t * side_t
		var strip_x: float = float(i) if side == "left" else width - 1.0 - float(i)
		canvas.draw_rect(
			Rect2(Vector2(strip_x, 0.0) + shake_offset, Vector2(1.0, height)),
			Color(0.32, 0.94, 1.0, side_alpha)
		)
	var local_span: float = 82.0 + 36.0 * speed_scale
	var y0: float = clampf(spark_y - local_span, 0.0, height)
	var y1: float = clampf(spark_y + local_span, 0.0, height)
	canvas.draw_line(
		Vector2(wall_x, y0) + shake_offset,
		Vector2(wall_x, y1) + shake_offset,
		Color(1.0, 0.82, 0.30, 0.30 * ratio),
		1.15 + 0.65 * speed_scale,
		true
	)
	canvas.draw_line(
		Vector2(wall_x, spark_y) + shake_offset,
		Vector2(wall_x + side_dir * (24.0 + 14.0 * speed_scale), spark_y) + shake_offset,
		Color(1.0, 0.96, 0.66, 0.46 * ratio),
		1.25 + 0.45 * speed_scale,
		true
	)
	_draw_stage4_wall_flash_sparkle(canvas, Vector2(wall_x, spark_y) + shake_offset, side_dir, ratio, speed_scale, quality_scale)


func _draw_stage4_wall_flash_sparkle(
	canvas: CanvasItem,
	center: Vector2,
	side_dir: float,
	ratio: float,
	speed_scale: float,
	quality_scale: float
) -> void:
	var glow_alpha: float = minf(0.24, 0.13 * ratio * speed_scale)
	var core_alpha: float = minf(0.54, 0.32 * ratio * speed_scale)
	canvas.draw_circle(center, 5.0 + 5.0 * ratio * speed_scale, Color(0.36, 0.92, 1.0, glow_alpha))
	canvas.draw_circle(center, 1.8 + 1.8 * ratio, Color(1.0, 0.96, 0.72, core_alpha))
	var horizontal_len: float = 22.0 * ratio * speed_scale
	var vertical_len: float = 10.0 * ratio * speed_scale
	canvas.draw_line(
		center + Vector2(-side_dir * 2.0, 0.0),
		center + Vector2(side_dir * horizontal_len, 0.0),
		Color(1.0, 0.91, 0.46, 0.42 * ratio),
		1.45,
		true
	)
	canvas.draw_line(
		center + Vector2(0.0, -vertical_len),
		center + Vector2(0.0, vertical_len),
		Color(0.42, 0.95, 1.0, 0.28 * ratio),
		1.0,
		true
	)
	var satellite_count: int = _get_lod_count(
		STAGE4_WALL_FLASH_SATELLITE_COUNT,
		STAGE4_WALL_FLASH_SATELLITE_COUNT_LOD,
		quality_scale
	)
	for i in range(satellite_count):
		var y_offset: float = (-18.0 if i == 0 else 18.0) * ratio
		var tick_center: Vector2 = center + Vector2(side_dir * (5.0 + float(i) * 3.0), y_offset)
		canvas.draw_line(
			tick_center + Vector2(-side_dir * 3.0, -3.0),
			tick_center + Vector2(side_dir * (9.0 + 4.0 * speed_scale), 3.0),
			Color(0.92, 0.98, 1.0, 0.26 * ratio),
			1.0,
			true
		)


func _draw_destruction_overlays(canvas: CanvasItem, context: Dictionary, width: float, height: float, scale: Vector2, shake_offset: Vector2, quality_scale: float) -> void:
	var alpha: float = clampf(float(context.get("stage4_red_light_alpha", 0.0)), 0.0, 1.0)
	if alpha > 0.01:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), Color(1.0, 0.06, 0.03, alpha * 0.35))
	if bool(context.get("stage4_destruction_wave_active", false)):
		var wave_value: Variant = context.get("stage4_destruction_wave", {})
		if wave_value is Dictionary:
			_draw_destruction_wave_payload(canvas, wave_value as Dictionary, scale, shake_offset, quality_scale)


func _draw_destruction_wave_payload(canvas: CanvasItem, wave: Dictionary, scale: Vector2, shake_offset: Vector2, quality_scale: float) -> void:
	if wave.is_empty():
		return
	var energy_ring_limit: int = _get_lod_count(MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS, MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS_LOD, quality_scale)
	var beam_render_limit: int = _get_lod_count(MAX_RENDERED_DESTRUCTION_WAVE_BEAMS, MAX_RENDERED_DESTRUCTION_WAVE_BEAMS_LOD, quality_scale)
	var trail_render_limit: int = _get_lod_count(MAX_RENDERED_DESTRUCTION_WAVE_TRAIL, MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD, quality_scale)
	var ring_arc_points: int = _get_lod_count(DESTRUCTION_WAVE_RING_ARC_POINTS, DESTRUCTION_WAVE_RING_ARC_POINTS_LOD, quality_scale)
	var ring_layer_count: int = _get_lod_count(DESTRUCTION_WAVE_RING_LAYER_COUNT, DESTRUCTION_WAVE_RING_LAYER_COUNT_LOD, quality_scale)
	var start := Vector2(float(wave.get("start_x", LOGICAL_SIZE.x + 24.0)), float(wave.get("start_y", 10.0))) * scale + shake_offset
	var head := Vector2(float(wave.get("current_x", LOGICAL_SIZE.x + 24.0)), float(wave.get("current_y", 10.0))) * scale + shake_offset
	var radius: float = maxf(25.0, float(wave.get("radius", 25.0))) * (scale.x + scale.y) * 0.5
	var beam_width: float = maxf(3.0, radius * 0.11)
	var energy_rings: Array = _as_array(wave.get("energy_rings", []))
	for ring_index in range(_recent_start(energy_rings, energy_ring_limit), energy_rings.size()):
		var ring_value: Variant = energy_rings[ring_index]
		if ring_value is Dictionary:
			var ring := ring_value as Dictionary
			var ring_center := Vector2(float(ring.get("x", 0.0)), float(ring.get("y", 0.0))) * scale + shake_offset
			var ring_radius: float = float(ring.get("radius", 0.0)) * scale.x
			var ring_alpha: float = clampf(float(ring.get("opacity", 0.0)), 0.0, 1.0)
			if ring_radius > 2.0 and ring_alpha > 0.01:
				for layer in range(ring_layer_count, 0, -1):
					canvas.draw_arc(ring_center, maxf(1.0, ring_radius - float(layer) * 2.0), 0.0, TAU, ring_arc_points, Color(1.0, 0.32 + float(layer) * 0.09, 0.08, ring_alpha * 0.24), float(layer), true)
	canvas.draw_line(start, head, Color(1.0, 0.03, 0.01, 0.30), beam_width * 4.0, true)
	canvas.draw_line(start, head, Color(1.0, 0.22, 0.06, 0.54), beam_width * 2.2, true)
	canvas.draw_line(start, head, Color(1.0, 0.88, 0.58, 0.88), maxf(2.0, beam_width * 0.55), true)
	var beams: Array = _as_array(wave.get("beam_particles", []))
	for beam_index in range(_recent_start(beams, beam_render_limit), beams.size()):
		var beam_value: Variant = beams[beam_index]
		if beam_value is Dictionary:
			var beam := beam_value as Dictionary
			var life_ratio: float = clampf(float(beam.get("life", 0.0)) / 40.0, 0.0, 1.0)
			if life_ratio <= 0.0:
				continue
			var origin := Vector2(float(beam.get("x", 0.0)), float(beam.get("y", 0.0))) * scale + shake_offset
			var angle: float = float(beam.get("angle", 0.0))
			var length: float = float(beam.get("length", 0.0)) * scale.x
			var tip := origin + Vector2(cos(angle), sin(angle)) * length
			var particle_width: float = maxf(1.0, float(beam.get("width", 2.0)) * scale.x)
			canvas.draw_line(origin, tip, Color(1.0, 0.96, 0.58, 0.24 * life_ratio), particle_width * 3.0, true)
			canvas.draw_line(origin, tip, Color(1.0, 1.0, 0.82, 0.68 * life_ratio), particle_width, true)
	var trail_particles: Array = _as_array(wave.get("trail", []))
	for particle_index in range(_recent_start(trail_particles, trail_render_limit), trail_particles.size()):
		var particle_value: Variant = trail_particles[particle_index]
		if particle_value is Dictionary:
			var particle := particle_value as Dictionary
			var life_ratio: float = clampf(float(particle.get("life", 0.0)) / 30.0, 0.0, 1.0)
			if life_ratio <= 0.0:
				continue
			var pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) * scale + shake_offset
			var size: float = float(particle.get("size", 1.0)) * scale.x
			var phase: float = float(particle.get("color_phase", 0.0))
			var color := Color(1.0, 0.22 + phase * 0.22, 0.02, 0.34 * life_ratio)
			canvas.draw_circle(pos, size * 1.8, Color(color.r, color.g, color.b, color.a * 0.35))
			canvas.draw_circle(pos, size, color)
	_draw_destruction_wave_core(canvas, head, radius, float(wave.get("core_rotation", 0.0)), quality_scale)


func _draw_destruction_wave_core(canvas: CanvasItem, center: Vector2, radius: float, rotation_degrees: float, quality_scale: float) -> void:
	var core_arc_points: int = _get_lod_count(DESTRUCTION_WAVE_CORE_ARC_POINTS, DESTRUCTION_WAVE_CORE_ARC_POINTS_LOD, quality_scale)
	var core_point_count: int = _get_lod_count(DESTRUCTION_WAVE_CORE_POINT_COUNT, DESTRUCTION_WAVE_CORE_POINT_COUNT_LOD, quality_scale)
	var core_layer_count: int = _get_lod_count(DESTRUCTION_WAVE_CORE_LAYER_COUNT, DESTRUCTION_WAVE_CORE_LAYER_COUNT_LOD, quality_scale)
	var core_ring_step: int = DESTRUCTION_WAVE_CORE_RING_STEP_LOD if _is_playfield_lod_active(quality_scale) else DESTRUCTION_WAVE_CORE_RING_STEP
	for ring_offset in range(0, 30, core_ring_step):
		canvas.draw_arc(center, radius + float(ring_offset), 0.0, TAU, core_arc_points, Color(1.0, 0.08, 0.0, maxf(0.0, 0.36 - float(ring_offset) * 0.01)), 2.0, true)
	var rotation: float = deg_to_rad(rotation_degrees)
	for layer in range(core_layer_count):
		var points := PackedVector2Array()
		var layer_scale: float = 1.0 - float(layer) * 0.15
		for idx in range(core_point_count):
			var angle: float = TAU * float(idx) / float(core_point_count) + rotation + float(layer) * 0.2
			var spike: float = 1.28 if idx % 4 == 0 else 0.88
			var wobble: float = 1.0 + sin(time_sec * 10.0 + float(idx) * 1.7 + float(layer)) * 0.11
			points.append(center + Vector2(cos(angle), sin(angle)) * radius * layer_scale * spike * wobble)
		var color := Color(1.0, 1.0, 1.0, 0.7)
		match layer:
			0:
				color = Color(0.82, 0.0, 0.0, 0.34)
			1:
				color = Color(1.0, 0.0, 0.0, 0.42)
			2:
				color = Color(1.0, 0.48, 0.08, 0.56)
			3:
				color = Color(1.0, 0.90, 0.22, 0.70)
			_:
				color = Color(1.0, 1.0, 1.0, 0.86)
		canvas.draw_colored_polygon(points, color)
	var core_radius: float = maxf(4.0, radius * 0.22)
	canvas.draw_circle(center, core_radius * 3.0, Color(1.0, 0.88, 0.55, 0.22))
	canvas.draw_circle(center, core_radius * 1.6, Color(1.0, 0.96, 0.72, 0.58))
	canvas.draw_circle(center, core_radius, Color(1.0, 1.0, 1.0, 1.0))


func _draw_ellipse_polygon(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for idx in range(36):
		var angle: float = TAU * float(idx) / 36.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_colored_polygon(points, color)


func _draw_ellipse_outline(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, width: float = 1.0) -> void:
	var previous := center + Vector2(radius.x, 0.0)
	for idx in range(1, 49):
		var angle: float = TAU * float(idx) / 48.0
		var current := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		canvas.draw_line(previous, current, color, width, true)
		previous = current


func _draw_moon_fragment(canvas: CanvasItem, fragment: Dictionary, scale: Vector2, shake_offset: Vector2, trail_point_limit: int = MOON_FRAGMENT_TRAIL_POINT_LIMIT) -> void:
	var pos := Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0))) * scale + shake_offset
	var size: float = maxf(3.0, float(fragment.get("size", 10.0)) * scale.x)
	var visual_scale: float = _get_moon_fragment_visual_scale(fragment)
	var visual_radius: float = size * visual_scale * 0.5
	var rotation: float = deg_to_rad(float(fragment.get("rotation", 0.0)))
	var trail: Array = _as_array(fragment.get("trail", []))
	var trail_start: int = _recent_start(trail, trail_point_limit)
	for idx in range(trail_start, trail.size()):
		var trail_pos: Vector2 = _as_vector2(trail[idx], Vector2.ZERO) * scale + shake_offset
		var t: float = float(idx + 1) / maxf(1.0, float(trail.size()))
		canvas.draw_circle(trail_pos, maxf(1.2, size * (0.25 + t * 0.26)), Color(1.0, 0.22, 0.08, 0.10 + t * 0.20))
	if bool(fragment.get("impact", false)):
		var radius: float = maxf(visual_radius, float(fragment.get("shockwave_radius", 0.0)) * scale.x)
		var alpha: float = clampf(float(fragment.get("impact_timer", 0.0)) / 30.0, 0.0, 1.0)
		canvas.draw_circle(pos, radius, Color(1.0, 0.28, 0.07, 0.24 * alpha), false, 3.0, true)
		canvas.draw_circle(pos, maxf(2.0, visual_radius * 0.46), Color(1.0, 0.78, 0.30, 0.52 * alpha))
		return
	if red_moon_fragment_atlas != null:
		var texture_size: Vector2 = red_moon_fragment_atlas.get_size()
		var cell := Vector2(texture_size.x / float(RED_MOON_FRAGMENT_COLUMNS), texture_size.y / float(RED_MOON_FRAGMENT_ROWS))
		var safe_index: int = wrapi(int(fragment.get("sprite_index", 0)), 0, RED_MOON_FRAGMENT_COLUMNS * RED_MOON_FRAGMENT_ROWS)
		@warning_ignore("integer_division")
		var source := Rect2(float(safe_index % RED_MOON_FRAGMENT_COLUMNS) * cell.x, float(int(safe_index / RED_MOON_FRAGMENT_COLUMNS)) * cell.y, cell.x, cell.y)
		var draw_size := Vector2(size * visual_scale, size * visual_scale)
		_draw_texture_region_rotated(canvas, red_moon_fragment_atlas, source, pos, draw_size, rotation, Color.WHITE)
	else:
		canvas.draw_circle(pos, visual_radius * 1.10, Color(1.0, 0.08, 0.02, 0.26))
		canvas.draw_circle(pos, visual_radius * 0.72, Color(1.0, 0.23, 0.08, 0.92))
		canvas.draw_circle(pos + Vector2(-visual_radius * 0.18, -visual_radius * 0.15).rotated(rotation), visual_radius * 0.24, Color(1.0, 0.86, 0.42, 0.85))
	if bool(fragment.get("deflected", false)):
		canvas.draw_circle(pos, maxf(size * 2.0, visual_radius * 0.95), Color(0.95, 0.92, 1.0, 0.32), false, 2.0, true)


func _get_moon_fragment_visual_scale(fragment: Dictionary) -> float:
	var default_scale: float = RED_MOON_FRAGMENT_IMAGE_SCALE_MIN * float(fragment.get("sprite_scale_jitter", 1.0))
	return clampf(
		float(fragment.get("visual_scale", default_scale)),
		RED_MOON_FRAGMENT_IMAGE_SCALE_MIN,
		RED_MOON_FRAGMENT_IMAGE_SCALE_MAX
	)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return source.size()
	return max(0, source.size() - render_limit)


func _get_moon_fragment_render_indices(fragments: Array, render_limit: int) -> Array[int]:
	var result: Array[int] = []
	if render_limit <= 0 or fragments.is_empty():
		return result
	for index in range(fragments.size() - 1, -1, -1):
		if result.size() >= render_limit:
			break
		var fragment_value: Variant = fragments[index]
		if fragment_value is Dictionary and _is_moon_fragment_visible_for_budget(fragment_value as Dictionary):
			result.push_front(index)
	if result.size() < render_limit:
		for index in range(_recent_start(fragments, render_limit), fragments.size()):
			if result.size() >= render_limit:
				break
			if result.has(index) or not (fragments[index] is Dictionary):
				continue
			result.append(index)
	result.sort()
	return result


func _is_moon_fragment_visible_for_budget(fragment: Dictionary) -> bool:
	var pos := Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0)))
	var size: float = maxf(3.0, float(fragment.get("size", 10.0)))
	var visual_radius: float = size * _get_moon_fragment_visual_scale(fragment) * 0.5
	if bool(fragment.get("impact", false)):
		visual_radius = maxf(visual_radius, float(fragment.get("shockwave_radius", 0.0)))
	var margin: float = maxf(12.0, visual_radius)
	return (
		pos.x >= -margin
		and pos.x <= LOGICAL_SIZE.x + margin
		and pos.y >= -margin
		and pos.y <= LOGICAL_SIZE.y + margin
	)


func _get_playfield_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _is_playfield_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.85


func _get_lod_count(base_count: int, lod_count: int, quality_scale: float) -> int:
	if base_count <= 0:
		return 0
	if not _is_playfield_lod_active(quality_scale):
		return base_count
	return clampi(lod_count, 0, base_count)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
