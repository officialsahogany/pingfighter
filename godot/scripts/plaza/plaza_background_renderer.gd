extends RefCounted

const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")

const FLOOR_REPEAT := 380.0
const GROUND_STRIP_REPEAT := 1140.0
const GROUND_STRIP_HEIGHT := 154.0
const MIDGROUND_WALL_REPEAT := 960.0
const MIDGROUND_WALL_TOP := 388.0
const MIDGROUND_WALL_HEIGHT := 180.0
const MIDGROUND_WALL_ALPHA := 0.90
const MIDGROUND_WALL_TOP_FADE_HEIGHT := 38.0
const MIDGROUND_WALL_TOP_FADE_SLICE := 4.0
const FAR_SKY_WIDTH := 1520.0
const FAR_SKY_HEIGHT := 430.0
const SIDEWALK_HEIGHT := 92.0
const UNDERGROUND_TOP := 688.0

const TEXTURE_KEYS := [
	"far_sky",
	"midground_wall",
	"ground_strip",
	"ground_strip_emissive",
	"base_01",
	"base_02",
	"border",
	"border_emissive",
	"medallion",
	"medallion_emissive",
	"medallion_cutout",
	"medallion_cutout_emissive",
	"accent",
	"accent_emissive",
	"accent_cutout",
	"accent_cutout_emissive",
]


static func draw(
	canvas: CanvasItem,
	textures: Dictionary,
	camera_x: float,
	exit_zone: Rect2,
	game_size: Vector2,
	render_size: Vector2,
	sidewalk_top: float,
	scale: float,
	ticks_msec: int
) -> void:
	if canvas == null:
		return
	_draw_parallax_background(canvas, textures, camera_x, game_size, scale)
	_draw_ground_strip(canvas, textures, camera_x, game_size, render_size, sidewalk_top, scale, ticks_msec)
	_draw_exit_zone(canvas, camera_x, exit_zone, scale)


static func supports_texture_key(texture_key: String) -> bool:
	return TEXTURE_KEYS.has(texture_key)


static func _draw_parallax_background(canvas: CanvasItem, textures: Dictionary, camera_x: float, game_size: Vector2, scale: float) -> void:
	_draw_sky_gradient(canvas, game_size, scale)
	if not _draw_far_sky_asset(canvas, textures, camera_x, game_size.x, scale):
		_draw_moon(canvas, camera_x, scale)
		_draw_cloud_band(canvas, camera_x, scale, 0.16, 92.0, Color(0.40, 0.66, 0.70, 0.58))
		_draw_cloud_band(canvas, camera_x, scale, 0.28, 152.0, Color(0.15, 0.31, 0.45, 0.64))
	_draw_midground_wall(canvas, textures, camera_x, scale)


static func _draw_sky_gradient(canvas: CanvasItem, game_size: Vector2, scale: float) -> void:
	var bands := 10
	for idx in range(bands):
		var t := float(idx) / float(max(1, bands - 1))
		var color := Color(0.025 + t * 0.035, 0.045 + t * 0.04, 0.105 + t * 0.07, 1.0)
		canvas.draw_rect(Rect2(Vector2(0.0, game_size.y * t * 0.62) * scale, Vector2(game_size.x, game_size.y * 0.07) * scale), color, true)


static func _draw_far_sky_asset(canvas: CanvasItem, textures: Dictionary, camera_x: float, game_width: float, scale: float) -> bool:
	var sky_texture: Texture2D = textures.get("far_sky", null)
	if sky_texture == null:
		return false
	var x := PlazaBackgroundProjection.get_far_sky_x(camera_x, FAR_SKY_WIDTH, game_width)
	canvas.draw_texture_rect(
		sky_texture,
		Rect2(Vector2(x, 0.0) * scale, Vector2(FAR_SKY_WIDTH, FAR_SKY_HEIGHT) * scale),
		false,
		Color(1.0, 1.0, 1.0, 0.96)
	)
	return true


static func _draw_moon(canvas: CanvasItem, camera_x: float, scale: float) -> void:
	var moon_center := Vector2(645.0 - camera_x * 0.04, 116.0) * scale
	canvas.draw_circle(moon_center, 78.0 * scale, Color(0.78, 0.94, 0.73, 0.88))
	canvas.draw_circle(moon_center + Vector2(-26.0, 14.0) * scale, 12.0 * scale, Color(0.55, 0.75, 0.58, 0.22))
	canvas.draw_circle(moon_center + Vector2(22.0, -16.0) * scale, 18.0 * scale, Color(0.50, 0.70, 0.58, 0.18))


static func _draw_cloud_band(canvas: CanvasItem, camera_x: float, scale: float, parallax: float, y: float, color: Color) -> void:
	var tile_width := 420.0
	var offset := PlazaBackgroundProjection.get_parallax_tile_offset(camera_x, parallax, tile_width)
	for idx in range(5):
		var x := offset + float(idx) * tile_width
		canvas.draw_circle(Vector2(x + 70.0, y) * scale, 42.0 * scale, color)
		canvas.draw_circle(Vector2(x + 132.0, y - 18.0) * scale, 58.0 * scale, color)
		canvas.draw_circle(Vector2(x + 210.0, y + 4.0) * scale, 46.0 * scale, color)
		canvas.draw_rect(Rect2(Vector2(x + 62.0, y - 6.0) * scale, Vector2(188.0, 38.0) * scale), color, true)


static func _draw_midground_wall(canvas: CanvasItem, textures: Dictionary, camera_x: float, scale: float) -> void:
	var wall_texture: Texture2D = textures.get("midground_wall", null)
	if wall_texture != null:
		var texture_offset := PlazaBackgroundProjection.get_parallax_tile_offset(camera_x, 0.48, MIDGROUND_WALL_REPEAT)
		for idx in range(4):
			var texture_x := texture_offset + float(idx) * MIDGROUND_WALL_REPEAT
			_draw_midground_wall_asset_tile(canvas, wall_texture, texture_x, scale)
		return
	var parallax := 0.48
	var tile_width := 320.0
	var offset := PlazaBackgroundProjection.get_parallax_tile_offset(camera_x, parallax, tile_width)
	var wall_y := 458.0
	for idx in range(8):
		var x := offset + float(idx) * tile_width
		var wall_rect := Rect2(Vector2(x, wall_y) * scale, Vector2(260.0, 98.0) * scale)
		canvas.draw_rect(wall_rect, Color(0.045, 0.075, 0.105, 0.88), true)
		canvas.draw_rect(wall_rect, Color(0.0, 0.72, 0.86, 0.20), false, max(1.0, 1.0 * scale))
		for post_idx in range(4):
			var post_x := x + 28.0 + float(post_idx) * 68.0
			canvas.draw_rect(Rect2(Vector2(post_x, wall_y - 24.0) * scale, Vector2(10.0, 122.0) * scale), Color(0.11, 0.095, 0.065, 0.95), true)
			canvas.draw_circle(Vector2(post_x + 5.0, wall_y - 28.0) * scale, 9.0 * scale, Color(0.98, 0.72, 0.26, 0.68))


static func _draw_midground_wall_asset_tile(canvas: CanvasItem, wall_texture: Texture2D, texture_x: float, scale: float) -> void:
	var texture_size := wall_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fade_height := minf(MIDGROUND_WALL_TOP_FADE_HEIGHT, MIDGROUND_WALL_HEIGHT)
	var y := 0.0
	while y < fade_height:
		var slice_height := minf(MIDGROUND_WALL_TOP_FADE_SLICE, fade_height - y)
		var fade_t := (y + slice_height * 0.5) / maxf(1.0, fade_height)
		_draw_midground_wall_asset_region(canvas, wall_texture, texture_size, texture_x, y, slice_height, PlazaBackgroundProjection.smooth_unit(fade_t) * MIDGROUND_WALL_ALPHA, scale)
		y += slice_height
	if fade_height < MIDGROUND_WALL_HEIGHT:
		_draw_midground_wall_asset_region(
			canvas,
			wall_texture,
			texture_size,
			texture_x,
			fade_height,
			MIDGROUND_WALL_HEIGHT - fade_height,
			MIDGROUND_WALL_ALPHA,
			scale
		)


static func _draw_midground_wall_asset_region(
	canvas: CanvasItem,
	wall_texture: Texture2D,
	texture_size: Vector2,
	texture_x: float,
	region_y: float,
	region_height: float,
	alpha: float,
	scale: float
) -> void:
	var source_y := region_y / MIDGROUND_WALL_HEIGHT * texture_size.y
	var source_height := region_height / MIDGROUND_WALL_HEIGHT * texture_size.y
	canvas.draw_texture_rect_region(
		wall_texture,
		Rect2(Vector2(texture_x, MIDGROUND_WALL_TOP + region_y) * scale, Vector2(MIDGROUND_WALL_REPEAT, region_height) * scale),
		Rect2(Vector2(0.0, source_y), Vector2(texture_size.x, source_height)),
		Color(1.0, 1.0, 1.0, alpha)
	)


static func _draw_ground_strip(
	canvas: CanvasItem,
	textures: Dictionary,
	camera_x: float,
	game_size: Vector2,
	render_size: Vector2,
	sidewalk_top: float,
	scale: float,
	ticks_msec: int
) -> void:
	var ground_strip: Texture2D = textures.get("ground_strip", null)
	var ground_strip_emissive: Texture2D = textures.get("ground_strip_emissive", null)
	var base_01: Texture2D = textures.get("base_01", null)
	var base_02: Texture2D = textures.get("base_02", null)
	var border: Texture2D = textures.get("border", null)
	var border_emissive: Texture2D = textures.get("border_emissive", null)
	var medallion: Texture2D = textures.get("medallion", null)
	var medallion_emissive: Texture2D = textures.get("medallion_emissive", null)
	var accent: Texture2D = textures.get("accent", null)
	var accent_emissive: Texture2D = textures.get("accent_emissive", null)
	var use_side_cutouts := ground_strip != null
	if use_side_cutouts:
		medallion = textures.get("medallion_cutout", medallion)
		medallion_emissive = textures.get("medallion_cutout_emissive", medallion_emissive)
		accent = textures.get("accent_cutout", accent)
		accent_emissive = textures.get("accent_cutout_emissive", accent_emissive)
	var first_x: int
	if ground_strip != null:
		first_x = PlazaBackgroundProjection.get_world_tile_start(camera_x, GROUND_STRIP_REPEAT)
		for world_x in range(first_x - int(GROUND_STRIP_REPEAT), int(camera_x + game_size.x + GROUND_STRIP_REPEAT), int(GROUND_STRIP_REPEAT)):
			var strip_rect := Rect2(Vector2(world_x, sidewalk_top), Vector2(GROUND_STRIP_REPEAT, GROUND_STRIP_HEIGHT))
			_draw_texture_world(canvas, ground_strip, strip_rect, camera_x, render_size, scale)
			var strip_alpha := PlazaBackgroundProjection.flicker_alpha("ground:%d" % world_x, 0.48, 0.18, ticks_msec)
			_draw_texture_world(canvas, ground_strip_emissive, strip_rect, camera_x, render_size, scale, Color(1.0, 1.0, 1.0, strip_alpha))
	else:
		first_x = PlazaBackgroundProjection.get_world_tile_start(camera_x, FLOOR_REPEAT)
		for world_x in range(first_x - int(FLOOR_REPEAT), int(camera_x + game_size.x + FLOOR_REPEAT), int(FLOOR_REPEAT)):
			var tile_x := int(world_x / int(FLOOR_REPEAT))
			var texture := base_01 if tile_x % 2 == 0 else base_02
			_draw_texture_world(canvas, texture, Rect2(Vector2(world_x, sidewalk_top), Vector2(FLOOR_REPEAT, SIDEWALK_HEIGHT)), camera_x, render_size, scale)
		canvas.draw_rect(Rect2(Vector2(0.0, UNDERGROUND_TOP) * scale, Vector2(game_size.x, game_size.y - UNDERGROUND_TOP) * scale), Color(0.006, 0.011, 0.026, 1.0), true)
		_draw_vr_strata(canvas, camera_x, game_size.x, scale, ticks_msec)
		canvas.draw_line(Vector2(0.0, UNDERGROUND_TOP) * scale, Vector2(game_size.x, UNDERGROUND_TOP) * scale, Color(1.0, 0.32, 0.92, 0.54), max(1.0, 2.0 * scale))
	if use_side_cutouts:
		var border_alpha := PlazaBackgroundProjection.flicker_alpha("border:%d" % first_x, 0.12, 0.14, ticks_msec)
		_draw_texture_world(canvas, border_emissive, Rect2(Vector2(first_x - FLOOR_REPEAT, sidewalk_top + 8.0), Vector2(FLOOR_REPEAT * 4.0, 28.0)), camera_x, render_size, scale, Color(1.0, 1.0, 1.0, border_alpha))
	else:
		_draw_texture_world(canvas, border, Rect2(Vector2(first_x - FLOOR_REPEAT, sidewalk_top + 8.0), Vector2(FLOOR_REPEAT * 4.0, 28.0)), camera_x, render_size, scale, Color(1.0, 1.0, 1.0, 0.92))
		_draw_texture_world(canvas, border_emissive, Rect2(Vector2(first_x - FLOOR_REPEAT, sidewalk_top + 8.0), Vector2(FLOOR_REPEAT * 4.0, 28.0)), camera_x, render_size, scale, Color(1.0, 1.0, 1.0, 0.50))
	for pos_x in [560.0, 1320.0, 2080.0, 2840.0]:
		_draw_texture_world(canvas, medallion, Rect2(Vector2(pos_x, sidewalk_top + 20.0), Vector2(118.0, 118.0)), camera_x, render_size, scale)
		var medallion_alpha := PlazaBackgroundProjection.flicker_alpha("medallion:%d" % int(pos_x), 0.34, 0.18, ticks_msec)
		_draw_texture_world(canvas, medallion_emissive, Rect2(Vector2(pos_x, sidewalk_top + 20.0), Vector2(118.0, 118.0)), camera_x, render_size, scale, Color(1.0, 1.0, 1.0, medallion_alpha))
	for pos_x in [250.0, 980.0, 1750.0, 2460.0]:
		_draw_texture_world(canvas, accent, Rect2(Vector2(pos_x, sidewalk_top + 28.0), Vector2(96.0, 96.0)), camera_x, render_size, scale)
		var accent_alpha := PlazaBackgroundProjection.flicker_alpha("accent:%d" % int(pos_x), 0.40, 0.18, ticks_msec)
		_draw_texture_world(canvas, accent_emissive, Rect2(Vector2(pos_x, sidewalk_top + 28.0), Vector2(96.0, 96.0)), camera_x, render_size, scale, Color(1.0, 1.0, 1.0, accent_alpha))
	canvas.draw_line(Vector2(0.0, sidewalk_top) * scale, Vector2(game_size.x, sidewalk_top) * scale, Color(0.0, 0.9, 1.0, 0.28), max(1.0, 1.5 * scale))


static func _draw_vr_strata(canvas: CanvasItem, camera_x: float, game_width: float, scale: float, ticks_msec: int) -> void:
	for layer_idx in range(4):
		var y := UNDERGROUND_TOP + 10.0 + float(layer_idx) * 15.0
		var layer_alpha := PlazaBackgroundProjection.flicker_alpha("strata-line:%d" % layer_idx, 0.14, 0.10, ticks_msec)
		var color := Color(0.0, 0.56 + float(layer_idx) * 0.08, 0.86, layer_alpha)
		canvas.draw_line(Vector2(0.0, y) * scale, Vector2(game_width, y + 6.0) * scale, color, max(1.0, 1.0 * scale))
	for idx in range(18):
		var block_rect := PlazaBackgroundProjection.get_vr_strata_block_rect(idx, camera_x, game_width, UNDERGROUND_TOP)
		var block_alpha := PlazaBackgroundProjection.flicker_alpha("strata-block:%d" % idx, 0.10, 0.16, ticks_msec)
		var color := Color(0.0, 0.92, 1.0, block_alpha)
		canvas.draw_rect(Rect2(block_rect.position * scale, block_rect.size * scale), color, true)


static func _draw_exit_zone(canvas: CanvasItem, camera_x: float, exit_zone: Rect2, scale: float) -> void:
	var rect := PlazaWorldGeometry.world_rect_to_local(exit_zone, camera_x, scale)
	canvas.draw_rect(rect, Color(0.0, 0.9, 1.0, 0.12), true)
	canvas.draw_rect(rect, Color(0.0, 0.9, 1.0, 0.42), false, max(1.0, 2.0 * scale))
	var font := ThemeDB.fallback_font
	if font != null:
		canvas.draw_string(font, rect.position + Vector2(25.0, 55.0) * scale, "나가기", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(22.0 * scale), Color(0.78, 1.0, 1.0, 0.92))


static func _draw_texture_world(
	canvas: CanvasItem,
	texture: Texture2D,
	world_rect: Rect2,
	camera_x: float,
	render_size: Vector2,
	scale: float,
	modulate: Color = Color.WHITE
) -> void:
	if texture == null:
		return
	var local_rect := PlazaWorldGeometry.world_rect_to_local(world_rect, camera_x, scale)
	if local_rect.position.x > render_size.x or local_rect.end.x < 0.0 or local_rect.position.y > render_size.y or local_rect.end.y < 0.0:
		return
	canvas.draw_texture_rect(texture, local_rect, false, modulate)
