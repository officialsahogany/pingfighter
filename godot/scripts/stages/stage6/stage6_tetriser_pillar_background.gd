extends RefCounted

# Stage 6 Tetriser static pillar background.
#
# The live self-playing Tetris wells were intentionally retired: this layer is
# now a quiet imagegen mood backdrop behind the shared HUD, matching the Stage 3
# texture-first pattern while keeping the full 760x750 playfield readable.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LOGICAL := Vector2(760.0, 750.0)
const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage6_tetriser_pillar_bg_imagegen_v1.png"
const PREWARM_STEP_COUNT := 1

const VOID_FALLBACK := Color(0.004, 0.006, 0.014, 1.0)
const FIELD_SHADE := Color(0.004, 0.007, 0.018, 0.72)
const FIELD_BORDER := Color(0.18, 0.38, 0.72, 0.46)
const FIELD_BORDER_SOFT := Color(0.94, 0.68, 0.20, 0.20)
const SIDE_VIGNETTE := Color(0.0, 0.0, 0.0, 0.18)

var base_texture: Texture2D = null
var base_texture_checked := false
var textures_loaded := false
var prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded:
		return true
	match prewarm_step_index:
		0:
			_ensure_base_texture()
		_:
			_mark_textures_loaded_if_ready()
			prewarm_step_index = 0
			return true
	prewarm_step_index += 1
	if prewarm_step_index >= PREWARM_STEP_COUNT:
		_mark_textures_loaded_if_ready()
		prewarm_step_index = 0
		return textures_loaded
	return false


func reset() -> void:
	pass


func update(_delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	pass


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	quality_scale: float = 1.0
) -> bool:
	if canvas == null:
		return false
	_ensure_textures()

	var target_size := _resolve_target_size(view_size, game_offset, game_size)
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return false
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		game_offset = Vector2.ZERO
		game_size = target_size

	if base_texture != null:
		_draw_cover_texture(canvas, base_texture, target_size)
	else:
		_draw_static_fallback(canvas, target_size)
	_draw_side_vignette(canvas, target_size, game_offset, game_size, quality_scale)
	_draw_playfield_backplate(canvas, game_offset, game_size, quality_scale)
	return true


func draw_pillar_background_overlay(
	_canvas: CanvasItem,
	_view_size: Vector2,
	_game_offset: Vector2,
	_game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> void:
	pass


func get_asset_status() -> Dictionary:
	_ensure_base_texture()
	return {
		"theme": "static_tetriser_ringpia",
		"base_texture_path": BASE_TEXTURE_PATH,
		"base_texture": base_texture != null,
		"uses_static_texture": true,
		"draws_old_tetris_columns": false,
		"draws_live_tetris_wells": false,
		"dense_cabinet_fill": false,
		"has_runtime_animation": false,
	}


func get_imagegen_asset_status() -> Dictionary:
	return get_asset_status()


func _ensure_textures() -> void:
	if textures_loaded:
		return
	_ensure_base_texture()
	_mark_textures_loaded_if_ready()


func _ensure_base_texture() -> void:
	if base_texture_checked:
		return
	base_texture_checked = true
	base_texture = ProjectResourceLoader.load_texture(BASE_TEXTURE_PATH)


func _mark_textures_loaded_if_ready() -> void:
	textures_loaded = base_texture_checked


func _resolve_target_size(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Vector2:
	if view_size.x > 0.0 and view_size.y > 0.0:
		return view_size
	var fallback := game_offset * 2.0 + game_size
	if fallback.x > 0.0 and fallback.y > 0.0:
		return fallback
	return LOGICAL


func _draw_cover_texture(canvas: CanvasItem, texture: Texture2D, view_size: Vector2) -> void:
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = maxf(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * scale_factor
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	canvas.draw_texture_rect(texture, Rect2(target_pos, target_size), false)


func _draw_static_fallback(canvas: CanvasItem, view_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), VOID_FALLBACK)
	var center := view_size * 0.5
	var radius := minf(view_size.x, view_size.y) * 0.34
	canvas.draw_circle(center, radius, Color(0.04, 0.08, 0.16, 0.22))
	canvas.draw_circle(center, radius * 0.62, Color(0.12, 0.08, 0.28, 0.14))


func _draw_side_vignette(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	quality_scale: float
) -> void:
	var left_w := maxf(0.0, game_offset.x)
	var right_x := game_offset.x + game_size.x
	var right_w := maxf(0.0, view_size.x - right_x)
	if left_w > 1.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(left_w, view_size.y)), SIDE_VIGNETTE)
	if right_w > 1.0:
		canvas.draw_rect(Rect2(Vector2(right_x, 0.0), Vector2(right_w, view_size.y)), SIDE_VIGNETTE)
	if quality_scale <= 0.5:
		return
	var rail_alpha := 0.18
	if left_w > 32.0:
		canvas.draw_line(Vector2(left_w - 1.0, 0.0), Vector2(left_w - 1.0, view_size.y), Color(0.10, 0.48, 0.82, rail_alpha), 1.0, true)
	if right_w > 32.0:
		canvas.draw_line(Vector2(right_x + 1.0, 0.0), Vector2(right_x + 1.0, view_size.y), Color(0.10, 0.48, 0.82, rail_alpha), 1.0, true)


func _draw_playfield_backplate(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	var play_rect := Rect2(game_offset, game_size)
	canvas.draw_rect(play_rect, FIELD_SHADE)
	var scale := maxf(1.0, game_size.x / LOGICAL.x)
	var border_w := maxf(1.0, roundf(2.0 * scale))
	canvas.draw_rect(play_rect.grow(2.0 * scale), FIELD_BORDER_SOFT, false, border_w, true)
	if quality_scale > 0.48:
		canvas.draw_rect(play_rect, FIELD_BORDER, false, border_w, true)
