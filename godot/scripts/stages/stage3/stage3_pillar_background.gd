extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const Stage3PillarBackgroundAssets := preload("res://scripts/stages/stage3/stage3_pillar_background_assets.gd")

const BASE_TEXTURE_PATH := Stage3PillarBackgroundAssets.BASE_TEXTURE_PATH
const AMBIENT_TEXTURE_PATH := Stage3PillarBackgroundAssets.AMBIENT_TEXTURE_PATH
const CENTER_FRAME_TEXTURE_PATH := Stage3PillarBackgroundAssets.CENTER_FRAME_TEXTURE_PATH
const AMBIENT_SOURCE_REGIONS := Stage3PillarBackgroundAssets.AMBIENT_SOURCE_REGIONS
const CENTER_FRAME_WINDOW_RECT := Stage3PillarBackgroundAssets.CENTER_FRAME_WINDOW_RECT
const PREWARM_STEP_COUNT := Stage3PillarBackgroundAssets.PREWARM_STEP_COUNT
const FLOATING_HEART_TARGET_PER_SIDE := 8
const FLOATING_HEART_DRAW_LIMIT_LOD := 10
const FLOATING_HEART_DRAW_LIMIT_SEVERE_LOD := 6
const FLOATING_HEART_POP_PARTICLE_COUNT := 4
const FLOATING_HEART_POP_PARTICLE_COUNT_LOD := 2
const FLOATING_HEART_POP_PARTICLE_COUNT_SEVERE_LOD := 0
const EDGE_ACCENT_COUNT := 2
const EDGE_ACCENT_COUNT_LOD := 1
const EDGE_ACCENT_COUNT_SEVERE_LOD := 1

var base_texture: Texture2D = null
var ambient_texture: Texture2D = null
var center_frame_texture: Texture2D = null
var textures_loaded: bool = false
var base_texture_checked: bool = false
var ambient_texture_checked: bool = false
var center_frame_texture_checked: bool = false
var ambient_regions: Array = []
var center_frame_window: Rect2 = Rect2()
var center_frame_window_checked: bool = false
var prewarm_step_index: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambient_time: float = 0.0
var floating_hearts: Array = []
var layout_view_size: Vector2 = Vector2.ZERO
var layout_game_offset: Vector2 = Vector2.ZERO
var layout_game_size: Vector2 = Vector2.ZERO
var _active_quality_scale: float = 1.0


func _init() -> void:
	rng.seed = 3304


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded and center_frame_window_checked:
		return true
	match prewarm_step_index:
		0:
			_ensure_base_texture()
		1:
			_ensure_ambient_texture()
		2:
			_ensure_center_frame_texture()
		_:
			_get_center_frame_window_rect()
	prewarm_step_index += 1
	if prewarm_step_index >= PREWARM_STEP_COUNT:
		_mark_textures_loaded_if_ready()
		prewarm_step_index = 0
		return textures_loaded and center_frame_window_checked
	return false


func reset() -> void:
	ambient_time = 0.0
	floating_hearts.clear()
	layout_view_size = Vector2.ZERO
	layout_game_offset = Vector2.ZERO
	layout_game_size = Vector2.ZERO


func update(delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	var clamped_delta: float = maxf(0.0, delta)
	ambient_time += clamped_delta
	_update_floating_hearts(clamped_delta)


func draw(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2, _field_width: float, context: Dictionary = {}, quality_scale: float = 1.0) -> bool:
	if canvas == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		return false
	_active_quality_scale = quality_scale if quality_scale < 0.99 else _get_pillar_quality_scale(context)
	_ensure_textures()
	_ensure_layout(view_size, game_offset, game_size)
	if base_texture != null:
		_draw_cover_texture(canvas, base_texture, view_size)
		_draw_edge_accents(canvas, game_offset, game_size)
	else:
		_draw_procedural_fallback(canvas, view_size, game_offset, game_size)
	_draw_ambient_layers(canvas, view_size, game_offset, game_size)
	_draw_center_frame(canvas, game_offset, game_size)
	_draw_floating_hearts(canvas)
	return true


func get_imagegen_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"base": base_texture != null,
		"ambient": ambient_texture != null and not ambient_regions.is_empty(),
		"center_frame": center_frame_texture != null,
		"ambient_sprite_count": ambient_regions.size(),
		"viper_airborne_lod_supported": true,
	}


func get_performance_snapshot() -> Dictionary:
	return {
		"floating_heart_target_total": FLOATING_HEART_TARGET_PER_SIDE * 2,
		"floating_heart_pop_particle_count": FLOATING_HEART_POP_PARTICLE_COUNT,
		"floating_heart_draw_limit_lod": FLOATING_HEART_DRAW_LIMIT_LOD,
		"floating_heart_draw_limit_severe_lod": FLOATING_HEART_DRAW_LIMIT_SEVERE_LOD,
		"floating_heart_pop_particle_count_lod": FLOATING_HEART_POP_PARTICLE_COUNT_LOD,
		"floating_heart_pop_particle_count_severe_lod": FLOATING_HEART_POP_PARTICLE_COUNT_SEVERE_LOD,
		"edge_accent_count": EDGE_ACCENT_COUNT,
		"edge_accent_count_lod": EDGE_ACCENT_COUNT_LOD,
		"edge_accent_count_severe_lod": EDGE_ACCENT_COUNT_SEVERE_LOD,
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	_ensure_base_texture()
	_ensure_ambient_texture()
	_ensure_center_frame_texture()
	_mark_textures_loaded_if_ready()


func _ensure_base_texture() -> void:
	if base_texture_checked:
		return
	base_texture_checked = true
	base_texture = ProjectResourceLoader.load_texture(BASE_TEXTURE_PATH)


func _ensure_ambient_texture() -> void:
	if ambient_texture_checked:
		return
	ambient_texture_checked = true
	ambient_texture = ProjectResourceLoader.load_texture(AMBIENT_TEXTURE_PATH)
	if ambient_texture != null:
		ambient_regions = AMBIENT_SOURCE_REGIONS.duplicate()


func _ensure_center_frame_texture() -> void:
	if center_frame_texture_checked:
		return
	center_frame_texture_checked = true
	center_frame_texture = ProjectResourceLoader.load_texture(CENTER_FRAME_TEXTURE_PATH)


func _mark_textures_loaded_if_ready() -> void:
	textures_loaded = base_texture_checked and ambient_texture_checked and center_frame_texture_checked


func _ensure_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	if layout_view_size == view_size and layout_game_offset == game_offset and layout_game_size == game_size and not floating_hearts.is_empty():
		return
	layout_view_size = view_size
	layout_game_offset = game_offset
	layout_game_size = game_size
	_generate_floating_hearts(view_size, game_offset, game_size)


func _draw_cover_texture(canvas: CanvasItem, texture: Texture2D, view_size: Vector2) -> void:
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = maxf(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * scale_factor
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	canvas.draw_texture_rect(texture, Rect2(target_pos, target_size), false)


func _draw_edge_accents(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2) -> void:
	var game_rect: Rect2 = Rect2(game_offset, game_size)
	var scale: float = maxf(1.0, game_size.x / 600.0) if game_size.x > 0.0 else 1.0
	var accents: Array = [
		{"inset": 3.0, "color": Color(1.0, 120.0 / 255.0, 195.0 / 255.0, 50.0 / 255.0)},
		{"inset": 7.0, "color": Color(102.0 / 255.0, 228.0 / 255.0, 1.0, 36.0 / 255.0)},
	]
	var accent_count: int = _get_lod_count(EDGE_ACCENT_COUNT, EDGE_ACCENT_COUNT_LOD, EDGE_ACCENT_COUNT_SEVERE_LOD)
	for accent_idx in range(accent_count):
		var accent: Dictionary = accents[accent_idx]
		var rect: Rect2 = game_rect.grow(float(accent["inset"]))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			canvas.draw_rect(rect, accent["color"], false, maxf(1.0, roundf(scale)), true)


func _draw_ambient_layers(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	if ambient_texture == null or ambient_regions.is_empty():
		return
	var left_w: float = maxf(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = maxf(0.0, view_size.x - right_x)
	if left_w > 28.0:
		_draw_ambient_sprite(canvas, 0, Vector2(left_w * 0.54, view_size.y * 0.24), Vector2(left_w * 0.46, view_size.y * 0.075), 110.0 / 255.0, 1.8, 2.6, 0.1, 2.7)
		if not _is_lod_active():
			_draw_ambient_sprite(canvas, 4, Vector2(left_w * 0.46, view_size.y * 0.70), Vector2(left_w * 0.48, view_size.y * 0.085), 96.0 / 255.0, 2.4, 1.8, 2.0, 2.2)
	if right_w > 28.0:
		_draw_ambient_sprite(canvas, 1, Vector2(right_x + right_w * 0.47, view_size.y * 0.28), Vector2(right_w * 0.50, view_size.y * 0.080), 112.0 / 255.0, 1.9, 2.8, 0.7, 2.9)
		if not _is_lod_active():
			_draw_ambient_sprite(canvas, 7, Vector2(right_x + right_w * 0.52, view_size.y * 0.72), Vector2(right_w * 0.54, view_size.y * 0.080), 102.0 / 255.0, 2.2, 2.0, 3.4, 2.4)


func _draw_ambient_sprite(
	canvas: CanvasItem,
	sprite_index: int,
	center: Vector2,
	max_size: Vector2,
	base_alpha: float,
	amp_x: float,
	amp_y: float,
	phase: float,
	speed: float
) -> void:
	var source: Rect2 = ambient_regions[sprite_index % ambient_regions.size()]
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	var scale_factor: float = minf(max_size.x / source.size.x, max_size.y / source.size.y)
	if scale_factor <= 0.0:
		return
	var motion_phase: float = ambient_time * speed + phase
	var target_size: Vector2 = source.size * scale_factor
	var bob: Vector2 = Vector2(sin(motion_phase) * amp_x, cos(motion_phase * 0.8) * amp_y)
	var alpha: float = clampf(base_alpha + sin(motion_phase * 1.7) * 18.0 / 255.0, 0.0, 1.0)
	canvas.draw_texture_rect_region(
		ambient_texture,
		Rect2(center + bob - target_size * 0.5, target_size),
		source,
		Color(1.0, 1.0, 1.0, alpha),
		false,
		true
	)


func _draw_center_frame(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2) -> void:
	if center_frame_texture == null or game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	var window: Rect2 = _get_center_frame_window_rect()
	if window.size.x <= 0.0 or window.size.y <= 0.0:
		return
	var source_size: Vector2 = center_frame_texture.get_size()
	var scale: Vector2 = Vector2(game_size.x / window.size.x, game_size.y / window.size.y)
	var outer_pos: Vector2 = game_offset - window.position * scale
	var source_right: float = window.position.x + window.size.x
	var source_bottom: float = window.position.y + window.size.y
	var pieces: Array = [
		Rect2(0.0, 0.0, source_size.x, window.position.y),
		Rect2(0.0, window.position.y, window.position.x, window.size.y),
		Rect2(source_right, window.position.y, source_size.x - source_right, window.size.y),
		Rect2(0.0, source_bottom, source_size.x, source_size.y - source_bottom),
	]
	for source in pieces:
		if source.size.x <= 0.0 or source.size.y <= 0.0:
			continue
		var dest: Rect2 = Rect2(outer_pos + source.position * scale, source.size * scale)
		canvas.draw_texture_rect_region(
			center_frame_texture,
			dest,
			source,
			Color(1.0, 1.0, 1.0, 248.0 / 255.0),
			false,
			true
		)


func _get_center_frame_window_rect() -> Rect2:
	if center_frame_window_checked:
		return center_frame_window
	center_frame_window_checked = true
	_ensure_center_frame_texture()
	if center_frame_texture == null:
		center_frame_window = Rect2()
		return center_frame_window
	center_frame_window = CENTER_FRAME_WINDOW_RECT
	return center_frame_window


func _generate_floating_hearts(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	floating_hearts.clear()
	for _idx in range(FLOATING_HEART_TARGET_PER_SIDE):
		_spawn_floating_heart("left", view_size, game_offset, game_size)
		_spawn_floating_heart("right", view_size, game_offset, game_size)


func _spawn_floating_heart(side: String, view_size: Vector2, game_offset: Vector2, game_size: Vector2, existing: Dictionary = {}) -> Dictionary:
	var left_w: float = maxf(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = maxf(0.0, view_size.x - right_x)
	var x: float = 0.0
	if side == "left":
		if left_w <= 12.0:
			return existing
		x = rng.randf_range(8.0, maxf(9.0, left_w - 8.0))
	else:
		if right_w <= 12.0:
			return existing
		x = rng.randf_range(right_x + 8.0, maxf(right_x + 9.0, view_size.x - 8.0))
	var y: float = rng.randf_range(18.0, maxf(19.0, view_size.y - 18.0))
	var heart: Dictionary = {
		"side": side,
		"x": x,
		"y": y,
		"start_x": x,
		"start_y": y,
		"size": rng.randf_range(10.0, 28.0),
		"alpha": rng.randf_range(40.0, 90.0) / 255.0,
		"phase": rng.randf_range(0.0, TAU),
		"speed_x": rng.randf_range(0.3, 0.8),
		"speed_y": rng.randf_range(0.5, 1.0),
		"range_x": rng.randf_range(8.0, 20.0),
		"range_y": rng.randf_range(10.0, 25.0),
		"life": rng.randf_range(3.0, 8.0),
		"max_life": 1.0,
		"state": "floating",
		"pop": 0.0,
	}
	heart["max_life"] = heart["life"]
	if existing.is_empty():
		floating_hearts.append(heart)
		return heart
	return heart


func _update_floating_hearts(delta: float) -> void:
	if floating_hearts.is_empty() or layout_view_size == Vector2.ZERO:
		return
	for idx in range(floating_hearts.size()):
		var heart: Dictionary = floating_hearts[idx]
		var state: String = str(heart.get("state", "floating"))
		if state == "floating":
			heart["phase"] = float(heart.get("phase", 0.0)) + delta * 0.5
			var phase: float = float(heart["phase"])
			heart["x"] = float(heart.get("start_x", 0.0)) + sin(phase * float(heart.get("speed_x", 0.4))) * float(heart.get("range_x", 12.0))
			heart["y"] = float(heart.get("start_y", 0.0)) + sin(phase * float(heart.get("speed_y", 0.7)) + 0.5) * float(heart.get("range_y", 15.0))
			heart["life"] = float(heart.get("life", 0.0)) - delta
			if float(heart["life"]) <= 0.0:
				heart["state"] = "popping"
				heart["pop"] = 0.0
		elif state == "popping":
			heart["pop"] = float(heart.get("pop", 0.0)) + delta * 3.0
			if float(heart["pop"]) >= 1.0:
				heart = _spawn_floating_heart(str(heart.get("side", "left")), layout_view_size, layout_game_offset, layout_game_size, heart)
		floating_hearts[idx] = heart


func _draw_floating_hearts(canvas: CanvasItem) -> void:
	var draw_limit: int = _get_lod_count(
		floating_hearts.size(),
		FLOATING_HEART_DRAW_LIMIT_LOD,
		FLOATING_HEART_DRAW_LIMIT_SEVERE_LOD
	)
	var pop_particle_count: int = _get_lod_count(
		FLOATING_HEART_POP_PARTICLE_COUNT,
		FLOATING_HEART_POP_PARTICLE_COUNT_LOD,
		FLOATING_HEART_POP_PARTICLE_COUNT_SEVERE_LOD
	)
	for heart_index in range(mini(floating_hearts.size(), draw_limit)):
		var heart: Dictionary = floating_hearts[heart_index]
		var color: Color = Color(1.0, 130.0 / 255.0, 185.0 / 255.0, float(heart.get("alpha", 0.22)))
		var size: float = float(heart.get("size", 16.0))
		if str(heart.get("state", "floating")) == "popping":
			var progress: float = clampf(float(heart.get("pop", 0.0)), 0.0, 1.0)
			size *= 1.0 + progress * 0.9
			color.a *= 1.0 - progress
			for idx in range(pop_particle_count):
				var angle: float = TAU * float(idx) / float(maxi(1, pop_particle_count))
				var particle_pos: Vector2 = Vector2(float(heart.get("x", 0.0)), float(heart.get("y", 0.0))) + Vector2(cos(angle), sin(angle)) * size * progress
				canvas.draw_circle(particle_pos, maxf(1.0, size * 0.10 * (1.0 - progress)), Color(color.r, color.g, color.b, color.a * 0.65))
		if color.a <= 0.01:
			continue
		_draw_heart(canvas, Vector2(float(heart.get("x", 0.0)), float(heart.get("y", 0.0))), size * 0.45, color)


func _draw_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(-size * 0.45, -size * 0.34), size * 0.50, color)
	canvas.draw_circle(center + Vector2(size * 0.45, -size * 0.34), size * 0.50, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size, -size * 0.10),
		center + Vector2(0.0, size),
		center + Vector2(size, -size * 0.10),
	]), color)


func _draw_procedural_fallback(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(18.0 / 255.0, 12.0 / 255.0, 22.0 / 255.0, 1.0))
	var left_w: float = maxf(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = maxf(0.0, view_size.x - right_x)
	if left_w > 0.0:
		canvas.draw_rect(Rect2(0.0, 0.0, left_w, view_size.y), Color(54.0 / 255.0, 30.0 / 255.0, 62.0 / 255.0, 1.0))
	if right_w > 0.0:
		canvas.draw_rect(Rect2(right_x, 0.0, right_w, view_size.y), Color(62.0 / 255.0, 30.0 / 255.0, 54.0 / 255.0, 1.0))


func _get_pillar_quality_scale(context: Dictionary) -> float:
	if context.is_empty():
		return 1.0
	return BattleRenderQuality.effect_scale(context)


func _is_lod_active() -> bool:
	return _active_quality_scale < 0.85


func _is_severe_lod_active() -> bool:
	return _active_quality_scale < 0.66


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int) -> int:
	if base_count <= 0:
		return 0
	if _is_severe_lod_active():
		return clampi(severe_lod_count, 0, base_count)
	if _is_lod_active():
		return clampi(lod_count, 0, base_count)
	return base_count
