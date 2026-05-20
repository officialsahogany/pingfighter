extends RefCounted

const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")

const ROCK_GOLDEN_STYLE := "golden_rock"
const ROCK_IMAGEGEN_MIN_LONG_SIDE := 14.0
const ROCK_FRAGMENT_LIFE_SEC := 45.0 / 60.0
const STARPOINT_DROP_SIZE := 12.0
const ROCK_STYLE_COLOR_DATA := {
	"dark_granite": [[35, 35, 40], [55, 55, 60], [75, 75, 80]],
	"light_granite": [[120, 115, 110], [140, 135, 130], [160, 155, 150]],
	"reddish_stone": [[85, 65, 55], [105, 85, 75], [125, 105, 95]],
	"yellowish_stone": [[140, 120, 85], [160, 140, 105], [180, 160, 125]],
	"gray_stone": [[70, 70, 75], [90, 90, 95], [110, 110, 115]],
	"mixed_stone": [[95, 85, 80], [115, 105, 100], [135, 125, 120]],
	"golden_rock": [[255, 215, 0], [255, 223, 100], [255, 230, 150]],
}


func draw_starpoint_particles(canvas: CanvasItem, starpoint_particles: Array, shake_offset: Vector2, render_limit: int = -1) -> void:
	for particle_index in range(_recent_start(starpoint_particles, render_limit), starpoint_particles.size()):
		var particle_value: Variant = starpoint_particles[particle_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var color: Color = _get_starpoint_particle_color(float(particle.get("color_shift", 0.5)), alpha)
		canvas.draw_circle(pos, max(1.0, float(particle.get("size", 2.0))), color)


func draw_starpoint_drops(
	canvas: CanvasItem,
	starpoint_drops: Array,
	shake_offset: Vector2,
	game_offset: Vector2 = Vector2.ZERO,
	render_scale: float = 1.0
) -> void:
	# Stage 2 uses the same scrap-tone palette as Stage 1/3 for normal drops;
	# detector-bonus drops share the cyan/white palette. GPU shader handles
	# 4-layer glow + star fill + outline + center dot in a single quad per drop.
	# Convert playfield-local positions into rendered-playfield screen space
	# because the host is a child of the outer canvas, outside the playfield's
	# draw_set_transform window.
	var host: Node = CommonStarpointVisualHost.get_or_create_on_canvas(canvas)
	if host != null and host.has_method("sync_drop"):
		host.begin_frame()
		var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
		var scale: float = maxf(0.001, render_scale)
		for drop in starpoint_drops:
			var is_star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
			var playfield_pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			host.sync_drop({
				"pos": game_offset + playfield_pos * scale,
				"size": float(drop.get("size", STARPOINT_DROP_SIZE)) * scale,
				"life": float(drop.get("life", 0.0)),
				"rotation": float(drop.get("rotation", 0.0)),
				"glow_intensity": float(drop.get("glow_intensity", 1.0)),
				"star_detector_bonus": is_star_detector_bonus,
				"elapsed": elapsed,
				# Stage 2 shares Stage 1's pink + iridescent palette for normal
				# scrap-tone drops. Detector bonus stays cyan/white.
				"glow_color": Color(0.30, 0.92, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.45, 0.74, 1.0),
				"fill_color": Color(0.16, 0.82, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.42, 0.78, 1.0),
				"outline_color": Color(1.0, 1.0, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 1.0, 0.0, 1.0),
				"iridescent_shimmer_intensity": 0.0 if is_star_detector_bonus else 1.0,
				"sparkle_ray_intensity": 0.0 if is_star_detector_bonus else 1.0,
			})
		host.end_frame()
		return
	for drop in starpoint_drops:
		var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(drop.get("size", STARPOINT_DROP_SIZE)))
		var alpha: float = clamp(float(drop.get("life", 0.0)) * 2.0 / 255.0, 0.0, 1.0)
		var glow_intensity: float = clamp(float(drop.get("glow_intensity", 1.0)), 0.0, 1.0)
		var glow_alpha: float = alpha * 0.5 * glow_intensity
		var is_star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
		var glow_color := Color(0.30, 0.92, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.45, 0.74, 1.0)
		var fill_color := Color(0.16, 0.82, 1.0, alpha) if is_star_detector_bonus else Color(1.0, 0.0, 0.0, alpha)
		var outline_color := Color(1.0, 1.0, 1.0, alpha) if is_star_detector_bonus else Color(1.0, 1.0, 0.0, alpha)
		for layer in range(4):
			var glow_radius: float = size * (4.0 - float(layer) * 0.7)
			var layer_alpha: float = glow_alpha / float(4 - layer)
			canvas.draw_circle(pos, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, layer_alpha))

		var points := PackedVector2Array()
		var rotation: float = float(drop.get("rotation", 0.0))
		for point_index in range(10):
			var point_radius: float = size if point_index % 2 == 0 else size * 0.5
			var angle: float = rotation + float(point_index) * PI / 5.0
			points.append(pos + Vector2(cos(angle), sin(angle)) * point_radius)
		if points.size() >= 3:
			canvas.draw_colored_polygon(points, fill_color)
			for point_index in range(points.size()):
				canvas.draw_line(points[point_index], points[(point_index + 1) % points.size()], outline_color, 3.0)
		canvas.draw_circle(pos, 3.0, Color(1.0, 1.0, 1.0, alpha * glow_intensity))


func draw_rock(canvas: CanvasItem, rock: Dictionary, shake_offset: Vector2, assets: Dictionary) -> void:
	if float(rock.get("drop_delay", 0.0)) > 0.0:
		return
	if rock.has("spawn_delay_frames") and float(rock.get("delay_timer_frames", 0.0)) < float(rock.get("spawn_delay_frames", 0.0)):
		return
	var center: Vector2 = _get_rock_center(rock) + shake_offset
	var target_center: Vector2 = _get_rock_target_pos(rock)
	var radius: float = float(rock.get("visual_radius", rock.get("radius", 28.0)))
	var style_type: String = str(rock.get("style_type", "gray_stone"))
	var colors: Array = _get_array(rock.get("style_colors", []))
	if colors.size() < 3:
		colors = _get_rock_style_colors(style_type)
	var fixed_points: Array = _get_array(rock.get("fixed_points", []))
	if fixed_points.is_empty():
		fixed_points = _generate_rock_fixed_points(int(rock.get("rock_seed", rock.get("seed", 0))))
	var flash: float = clamp(float(rock.get("flash", 0.0)) / 0.30, 0.0, 1.0)
	_draw_rock_shadow(canvas, rock, target_center, radius, shake_offset)
	if not _draw_imagegen_rock_sprite(canvas, rock, center, radius, style_type, flash, assets):
		_draw_original_style_rock(canvas, center, radius, style_type, colors, fixed_points, int(rock.get("rock_seed", rock.get("seed", 0))), flash)
	if bool(rock.get("is_golden", false)):
		_draw_golden_rock_glow(canvas, center, radius)
	if flash > 0.0:
		canvas.draw_circle(center, radius * (1.0 + flash * 0.45), Color(0.70, 1.0, 0.36, 0.20 * flash))
	var target_flash: float = clamp(float(rock.get("water_target_flash", 0.0)), 0.0, 1.0)
	if target_flash > 0.0:
		canvas.draw_arc(center, radius + 7.0 + sin(float(Time.get_ticks_msec()) * 0.014) * 2.0, 0.0, TAU, 36, Color(0.36, 0.95, 1.0, 0.65 * target_flash), 2.5)


func draw_rock_fragment(canvas: CanvasItem, fragment: Dictionary, shake_offset: Vector2, assets: Dictionary) -> void:
	var default_life: float = float(assets.get("rock_fragment_life_sec", ROCK_FRAGMENT_LIFE_SEC))
	var life: float = clamp(float(fragment.get("life", 0.0)), 0.0, float(fragment.get("max_life", default_life)))
	if life <= 0.0:
		return
	var fade: float = life / max(0.001, float(fragment.get("max_life", default_life)))
	var pos: Vector2 = _get_vector2(fragment.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var size: float = float(fragment.get("size", 8.0))
	if draw_imagegen_debris_sprite(canvas, fragment, pos, size, fade, assets):
		return
	var rotation: float = float(fragment.get("rotation", 0.0))
	var vertices := 5
	var points := PackedVector2Array()
	for idx in range(vertices):
		var angle: float = TAU * float(idx) / float(vertices) + rotation
		var jag: float = 0.74 + _seeded_unit(pos.x + pos.y + float(idx) * 13.0) * 0.36
		points.append(pos + Vector2(cos(angle), sin(angle)) * size * jag)
	var color: Color = fragment.get("color", Color(0.28, 0.28, 0.24, 1.0))
	color.a *= fade
	canvas.draw_colored_polygon(points, color)
	canvas.draw_line(pos + Vector2(-size * 0.3, -size * 0.2), pos + Vector2(size * 0.28, size * 0.16), Color(0.04, 0.035, 0.03, 0.45 * fade), 1.0, true)


func draw_imagegen_debris_sprite(
	canvas: CanvasItem,
	fragment: Dictionary,
	pos: Vector2,
	size: float,
	fade: float,
	assets: Dictionary
) -> bool:
	var rock_debris_texture: Texture2D = assets.get("rock_debris_texture", null) as Texture2D
	var rock_debris_source_regions: Array = _get_array(assets.get("rock_debris_source_regions", []))
	if rock_debris_texture == null or rock_debris_source_regions.is_empty():
		return false
	var sprite_index: int = int(fragment.get("sprite_index", -1))
	if sprite_index < 0:
		sprite_index = int(abs(pos.x * 31.0) + abs(pos.y * 17.0) + abs(size * 13.0))
	var source: Rect2 = _get_rect2(rock_debris_source_regions[sprite_index % rock_debris_source_regions.size()])
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return false
	var target_size := _fit_source_to_long_side(source.size, max(8.0, size * 2.65))
	canvas.draw_texture_rect_region(
		rock_debris_texture,
		Rect2(pos - target_size * 0.5, target_size),
		source,
		Color(1.0, 1.0, 1.0, clamp(fade, 0.0, 1.0)),
		false,
		true
	)
	return true


func _draw_rock_shadow(canvas: CanvasItem, rock: Dictionary, target_center: Vector2, size: float, global_shake: Vector2) -> void:
	var shadow_scale: float = clamp(float(rock.get("shadow_scale", 1.0)), 0.2, 1.15)
	var rock_offset: Vector2 = _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	var shadow_center := Vector2(
		target_center.x + rock_offset.x * 0.65,
		target_center.y + rock_offset.y * 0.35
	) + global_shake + Vector2(0.0, size * 0.42)
	var width: float = size * 2.2 * shadow_scale
	var height: float = size * 0.8 * shadow_scale
	var points := PackedVector2Array()
	for idx in range(8):
		var angle: float = TAU * float(idx) / 8.0
		var wobble: float = 0.86 + _seeded_unit(float(rock.get("rock_seed", rock.get("seed", 0))) + float(idx) * 3.7) * 0.22
		points.append(shadow_center + Vector2(cos(angle) * width * 0.5, sin(angle) * height * 0.5) * wobble)
	canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, (30.0 + 20.0 * shadow_scale) / 255.0))


func _draw_imagegen_rock_sprite(
	canvas: CanvasItem,
	rock: Dictionary,
	center: Vector2,
	size: float,
	style_type: String,
	flash: float,
	assets: Dictionary
) -> bool:
	var rock_texture: Texture2D = assets.get("rock_texture", null) as Texture2D
	var rock_source_regions: Array = _get_array(assets.get("rock_source_regions", []))
	if rock_texture == null or rock_source_regions.is_empty():
		return false
	var sprite_index: int = _select_imagegen_rock_sprite_index(style_type, bool(rock.get("is_golden", false)), int(rock.get("rock_seed", rock.get("seed", 0))), rock_source_regions.size())
	var source: Rect2 = _get_rect2(rock_source_regions[sprite_index % rock_source_regions.size()])
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return false
	var target_long: float = max(ROCK_IMAGEGEN_MIN_LONG_SIDE, size * 2.25)
	var target_size := _fit_source_to_long_side(source.size, target_long)
	var modulate := Color.WHITE.lerp(Color(0.70, 1.0, 0.36, 1.0), flash * 0.20)
	canvas.draw_texture_rect_region(
		rock_texture,
		Rect2(center - target_size * 0.5, target_size),
		source,
		modulate,
		false,
		true
	)
	return true


func _select_imagegen_rock_sprite_index(style_type: String, is_golden: bool, seed_value: int, region_count: int) -> int:
	if region_count <= 0:
		return 0
	var style_pools := {
		"dark_granite": [1, 3, 5, 13],
		"light_granite": [0, 6, 10, 12, 14],
		"reddish_stone": [2, 4, 9, 11],
		"yellowish_stone": [2, 9, 11],
		"gray_stone": [0, 6, 10, 12, 14],
		"mixed_stone": [3, 5, 10, 13, 14],
		"golden_rock": [7],
	}
	var pool: Array = style_pools.get(style_type, [])
	if is_golden:
		pool = style_pools["golden_rock"]
	if pool.is_empty():
		return abs(seed_value) % region_count
	return int(pool[abs(seed_value) % pool.size()]) % region_count


func _draw_original_style_rock(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	style_type: String,
	colors: Array,
	fixed_points: Array,
	seed_value: int,
	flash: float
) -> void:
	var c0: Color = colors[0]
	var c1: Color = colors[1]
	var c2: Color = colors[2]
	var layer_specs := [
		[1.00, c0],
		[0.88, c0.lerp(c1, 0.5)],
		[0.75, c1],
		[0.60, c1.lerp(c2, 0.5)],
		[0.42, c2],
	]
	var roundness: float = _get_rock_roundness(style_type)
	var aspect_y: float = _get_rock_aspect_y(style_type)
	for layer in layer_specs:
		var scale: float = float(layer[0])
		var color: Color = _flash_rock_color(layer[1], flash)
		var points: PackedVector2Array = _build_rock_polygon(center, size, fixed_points, scale, roundness, aspect_y)
		canvas.draw_colored_polygon(points, color)
	var outline: PackedVector2Array = _build_rock_polygon(center, size, fixed_points, 1.01, roundness, aspect_y)
	_draw_closed_polyline(canvas, outline, _shift_color(c0, -20.0), 1.6)
	canvas.draw_circle(center + Vector2(-size * 0.25, -size * 0.25), size * 0.20, Color(1.0, 1.0, 1.0, 0.13))
	canvas.draw_circle(center + Vector2(size * 0.20, size * 0.25), size * 0.24, Color(0.0, 0.0, 0.0, 0.12))
	var speckle_count: int = max(2, int(size / 8.0))
	for idx in range(speckle_count):
		var px: float = (_seeded_unit(float(seed_value) + 100.0 + float(idx) * 9.1) - 0.5) * size * 1.12
		var py: float = (_seeded_unit(float(seed_value) + 150.0 + float(idx) * 11.3) - 0.5) * size * 0.96 * aspect_y
		var speckle_size: float = 1.0 + _seeded_unit(float(seed_value) + 220.0 + float(idx) * 7.7) * max(1.0, size / 28.0)
		canvas.draw_circle(center + Vector2(px, py), speckle_size, _shift_color(c1, _seeded_unit(float(seed_value) + float(idx) * 4.9) * 30.0 - 18.0))
	var crack_count: int = 0
	if size >= 35.0:
		crack_count = 1 + int(_seeded_unit(float(seed_value) + 301.0) > 0.45)
	elif _seeded_unit(float(seed_value) + 302.0) > 0.68:
		crack_count = 1
	for idx in range(crack_count):
		_draw_seeded_crack(canvas, center, size, aspect_y, seed_value, idx)
	canvas.draw_circle(center + Vector2(-size * 0.18, -size * 0.22), max(1.4, size * 0.045), Color(1.0, 1.0, 1.0, 0.22))
	if style_type == ROCK_GOLDEN_STYLE:
		_draw_closed_polyline(canvas, outline, Color(1.0, 0.92, 0.28, 0.85), 2.0)


func _build_rock_polygon(
	center: Vector2,
	size: float,
	fixed_points: Array,
	scale: float,
	roundness: float,
	aspect_y: float
) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in fixed_points:
		var local: Vector2 = point
		if roundness < 1.0:
			polygon.append(center + Vector2(local.x * size * scale, local.y * size * aspect_y * scale))
		else:
			var angle: float = atan2(local.y, local.x)
			var radius: float = sqrt(local.x * local.x + local.y * local.y) * size * 0.75 * scale
			polygon.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * aspect_y))
	return polygon


func _draw_seeded_crack(canvas: CanvasItem, center: Vector2, size: float, aspect_y: float, seed_value: int, index: int) -> void:
	var seed_offset: float = float(seed_value) + float(index) * 73.0
	var angle: float = _seeded_unit(seed_offset + 1.0) * TAU
	var start_radius: float = size * (0.08 + _seeded_unit(seed_offset + 2.0) * 0.20)
	var length: float = size * (0.22 + _seeded_unit(seed_offset + 3.0) * 0.18)
	var start := center + Vector2(cos(angle) * start_radius, sin(angle) * start_radius * aspect_y)
	var mid_angle: float = angle + (_seeded_unit(seed_offset + 4.0) - 0.5) * 0.9
	var mid := start + Vector2(cos(mid_angle) * length * 0.58, sin(mid_angle) * length * 0.58 * aspect_y)
	var end_angle: float = mid_angle + (_seeded_unit(seed_offset + 5.0) - 0.5) * 0.7
	var finish := mid + Vector2(cos(end_angle) * length * 0.44, sin(end_angle) * length * 0.44 * aspect_y)
	canvas.draw_line(start, mid, Color(0.04, 0.035, 0.03, 0.56), 1.5, true)
	canvas.draw_line(mid, finish, Color(0.04, 0.035, 0.03, 0.50), 1.2, true)
	if _seeded_unit(seed_offset + 6.0) > 0.46:
		var branch_angle: float = mid_angle + (0.7 if _seeded_unit(seed_offset + 7.0) > 0.5 else -0.7)
		var branch := mid + Vector2(cos(branch_angle) * length * 0.24, sin(branch_angle) * length * 0.24 * aspect_y)
		canvas.draw_line(mid, branch, Color(0.04, 0.035, 0.03, 0.42), 1.0, true)


func _draw_closed_polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], color, width, true)


func _draw_golden_rock_glow(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var time: float = float(Time.get_ticks_msec()) / 1000.0
	canvas.draw_circle(center, size * (1.10 + sin(time * 4.0) * 0.06), Color(1.0, 0.75, 0.12, 0.14))
	for idx in range(3):
		var angle: float = time * 2.8 + float(idx) * TAU / 3.0
		var pos := center + Vector2(cos(angle), sin(angle)) * size * (0.52 + 0.10 * sin(time * 3.0 + float(idx)))
		canvas.draw_circle(pos, max(1.5, size * 0.035), Color(1.0, 0.93, 0.42, 0.72))


func _get_starpoint_particle_color(color_shift: float, alpha: float) -> Color:
	var clamped_shift: float = clamp(color_shift, 0.0, 1.0)
	if clamped_shift < 0.33:
		var low_t: float = clamped_shift * 3.0
		return Color(1.0, 1.0, (100.0 + 155.0 * low_t) / 255.0, alpha)
	if clamped_shift < 0.66:
		var mid_t: float = (clamped_shift - 0.33) * 3.0
		return Color((255.0 - 55.0 * mid_t) / 255.0, (255.0 - 30.0 * mid_t) / 255.0, 1.0, alpha)
	var t: float = (clamped_shift - 0.66) * 3.0
	return Color((200.0 - 100.0 * t) / 255.0, (225.0 + 30.0 * t) / 255.0, 1.0, alpha)


func _generate_rock_fixed_points(seed_value: int) -> Array:
	var count: int = 12 + int(floor(_seeded_unit(float(seed_value) + 0.37) * 9.0))
	var points: Array = []
	for idx in range(count):
		var angle: float = TAU * float(idx) / float(count)
		var base_radius := 0.80
		var wave1: float = sin(angle * 2.3) * 0.15
		var wave2: float = sin(angle * 3.7) * 0.10
		var noise: float = _seeded_unit(float(seed_value) + float(idx) * 17.13) * 0.20 - 0.10
		var radius_ratio: float = clamp(base_radius + wave1 + wave2 + noise, 0.50, 1.0)
		points.append(Vector2(cos(angle) * radius_ratio, sin(angle) * radius_ratio))
	return points


func _get_rock_style_colors(style_type: String) -> Array:
	var color_data: Array = ROCK_STYLE_COLOR_DATA.get(style_type, ROCK_STYLE_COLOR_DATA["gray_stone"])
	var colors: Array = []
	for rgb in color_data:
		var values: Array = rgb
		colors.append(Color(
			float(values[0]) / 255.0,
			float(values[1]) / 255.0,
			float(values[2]) / 255.0,
			1.0
		))
	return colors


func _get_rock_roundness(style_type: String) -> float:
	if style_type in [ROCK_GOLDEN_STYLE, "dark_granite"]:
		return 0.0
	return 1.0


func _get_rock_aspect_y(style_type: String) -> float:
	match style_type:
		"light_granite":
			return 0.85
		"reddish_stone":
			return 0.88
		"yellowish_stone":
			return 0.90
		"gray_stone":
			return 0.80
		"mixed_stone":
			return 0.85
		_:
			return 1.0


func _get_rock_target_pos(rock: Dictionary) -> Vector2:
	var fallback: Vector2 = _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	return _get_vector2(rock.get("target_pos", fallback), fallback)


func _get_rock_center(rock: Dictionary) -> Vector2:
	if rock.has("fall_y"):
		var target_pos: Vector2 = _get_rock_target_pos(rock)
		var y: float = float(rock.get("fall_y", target_pos.y)) if bool(rock.get("falling", false)) else target_pos.y
		return Vector2(target_pos.x, y) + _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	return pos + _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)


func _fit_source_to_long_side(source_size: Vector2, target_long: float) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2(target_long, target_long)
	if source_size.x >= source_size.y:
		return Vector2(target_long, max(1.0, target_long * source_size.y / source_size.x))
	return Vector2(max(1.0, target_long * source_size.x / source_size.y), target_long)


func _flash_rock_color(color: Color, flash: float) -> Color:
	if flash <= 0.0:
		return color
	return color.lerp(Color(0.70, 1.0, 0.36, 1.0), flash * 0.28)


func _shift_color(color: Color, amount_255: float) -> Color:
	var amount: float = amount_255 / 255.0
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)


func _seeded_unit(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898 + 78.233) * 43758.5453, 1.0)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return 0 if render_limit < 0 else source.size()
	return max(0, source.size() - render_limit)
