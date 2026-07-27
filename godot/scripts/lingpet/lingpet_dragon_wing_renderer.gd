extends RefCounted

const DragonBreathTextureCache := preload("res://scripts/lingpet/lingpet_dragon_breath_texture_cache.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const DRAGON_SHEET_PATH := "res://assets/sprites/lingpet/red_dragon_companion_side_fly_flap.png"
const DRAGON_SHEET_COLS := 5
const DRAGON_SHEET_ROWS := 5
const DRAGON_SHEET_FRAME_COUNT := 24
const DRAGON_SPRITE_DRAW_SIZE := 160.0
const DRAGON_FLAP_FPS := 22.0

var _additive_material: CanvasItemMaterial = null
var _dragon_sheet_texture: Texture2D = null


func prewarm() -> void:
	_ensure_material()
	_ensure_dragon_sheet()
	DragonBreathTextureCache.prewarm()
	ImpactFlareTextureCache.prewarm()


func prepare_launch() -> void:
	_ensure_dragon_sheet()


func draw_dragon_wing(
	canvas: CanvasItem,
	shake_offset: Vector2,
	swirl_active: bool,
	runtime_elapsed: float,
	swirl_envelope: float,
	swirl_center: Vector2,
	swirl_spin_sign: float,
	last_ball_pos: Vector2,
	wind_direction: float,
	wind_particles: Array[Dictionary],
	ball_swirl_trail: Array[Dictionary],
	swirl_trail_life_seconds: float,
	dragon_trail: Array[Dictionary],
	dragon_trail_life_seconds: float,
	flying_dragon: Dictionary,
	hit_flash_timer: float,
	hit_flash_seconds: float,
	last_hit_pos: Vector2,
	last_hit_dir: Vector2
) -> void:
	if canvas == null:
		return
	_ensure_material()
	var previous_material: Material = canvas.material
	canvas.material = _additive_material
	_draw_swirl_field(
		canvas,
		shake_offset,
		swirl_active,
		runtime_elapsed,
		swirl_envelope,
		swirl_center,
		swirl_spin_sign,
		last_ball_pos
	)
	_draw_ball_swirl_trail(canvas, shake_offset, ball_swirl_trail, swirl_trail_life_seconds, swirl_spin_sign)
	_draw_wind_particles(canvas, shake_offset, wind_particles, wind_direction)
	_draw_dragon_trail(canvas, shake_offset, dragon_trail, dragon_trail_life_seconds)
	_draw_flying_dragon(canvas, shake_offset, flying_dragon, wind_direction)
	if hit_flash_timer > 0.0:
		_draw_hit_flash(
			canvas,
			last_hit_pos + shake_offset,
			hit_flash_timer / maxf(0.001, hit_flash_seconds),
			last_hit_dir
		)
	canvas.material = previous_material


func get_swirl_ring_projection_for_tests(runtime_elapsed: float, ring_index: int, swirl_spin_sign: float) -> Dictionary:
	var projection := _get_swirl_ring_projection(runtime_elapsed, ring_index, swirl_spin_sign)
	return {"radius": projection.x, "start": projection.y}


func _draw_dragon_trail(
	canvas: CanvasItem,
	shake_offset: Vector2,
	dragon_trail: Array[Dictionary],
	dragon_trail_life_seconds: float
) -> void:
	if dragon_trail.is_empty():
		return
	var ember := DragonBreathTextureCache.get_ember_texture()
	if ember == null:
		return
	for entry in dragon_trail:
		var life := float(entry.get("life", 0.0))
		var max_life := maxf(0.01, float(entry.get("max_life", dragon_trail_life_seconds)))
		var ratio := clampf(life / max_life, 0.0, 1.0)
		if ratio <= 0.01:
			continue
		var pos: Vector2 = entry.get("pos", Vector2.ZERO) + shake_offset
		var grow := 1.0 - ratio
		_draw_centered_tex(canvas, ember, pos, lerpf(16.0, 52.0, grow), Color(1.0, 0.40, 0.11, 0.18 * ratio))
		_draw_centered_tex(canvas, ember, pos, lerpf(9.0, 26.0, grow), Color(1.0, 0.64, 0.24, 0.20 * ratio))


func _draw_wind_particles(
	canvas: CanvasItem,
	shake_offset: Vector2,
	wind_particles: Array[Dictionary],
	wind_direction: float
) -> void:
	for particle in wind_particles:
		var life := float(particle.get("life", 0.0))
		var max_life := maxf(0.01, float(particle.get("max_life", 1.0)))
		var ratio := clampf(life / max_life, 0.0, 1.0)
		if ratio <= 0.01:
			continue
		var pos: Vector2 = particle.get("pos", Vector2.ZERO) + shake_offset
		var vel: Vector2 = particle.get("vel", Vector2.RIGHT)
		var dir := vel.normalized() if vel.length_squared() > 0.001 else Vector2.RIGHT * wind_direction
		var perp := Vector2(-dir.y, dir.x)
		var length := float(particle.get("length", 36.0)) * 1.8
		var phase := float(particle.get("phase", 0.0))
		var width := maxf(1.0, float(particle.get("width", 2.0)))
		var segment_count := 7
		var points := PackedVector2Array()
		var core_colors := PackedColorArray()
		var halo_colors := PackedColorArray()
		var core_alpha := 0.22 * ratio
		var halo_alpha := 0.12 * ratio
		for i in range(segment_count + 1):
			var t := float(i) / float(segment_count)
			var along := lerpf(-length, 0.0, t)
			var bow := sin(t * PI * 1.15 + phase) * 6.0 * sin(t * PI)
			points.append(pos + dir * along + perp * bow)
			var gust := sin(t * PI)
			core_colors.append(Color(1.0, 0.84, 0.38, core_alpha * gust))
			halo_colors.append(Color(1.0, 0.54, 0.18, halo_alpha * gust))
		canvas.draw_polyline_colors(points, halo_colors, maxf(2.5, width * 3.0), true)
		canvas.draw_polyline_colors(points, core_colors, maxf(1.0, width), true)


func _draw_swirl_field(
	canvas: CanvasItem,
	shake_offset: Vector2,
	swirl_active: bool,
	runtime_elapsed: float,
	swirl_envelope: float,
	swirl_center: Vector2,
	swirl_spin_sign: float,
	last_ball_pos: Vector2
) -> void:
	if not swirl_active or swirl_center == Vector2.ZERO:
		return
	var center := swirl_center + shake_offset
	var glow_tex := ImpactFlareTextureCache.get_glow_texture()
	if glow_tex != null:
		var body_pulse := 0.5 + 0.5 * sin(runtime_elapsed * 4.2)
		_draw_centered_tex(canvas, glow_tex, center, 188.0 + body_pulse * 22.0, Color(1.0, 0.32, 0.07, 0.085 * swirl_envelope))
		_draw_centered_tex(canvas, glow_tex, center, 116.0 + body_pulse * 14.0, Color(1.0, 0.48, 0.14, 0.11 * swirl_envelope))
		_draw_centered_tex(canvas, glow_tex, center, 60.0, Color(1.0, 0.74, 0.32, 0.10 * swirl_envelope))
	for ring in range(4):
		var ring_float := float(ring)
		var projection := _get_swirl_ring_projection(runtime_elapsed, ring, swirl_spin_sign)
		var radius := projection.x
		var start := projection.y
		var alpha := (0.44 - ring_float * 0.065) * swirl_envelope
		canvas.draw_arc(center, radius, start, start + PI * 1.42, 52, Color(1.0, 0.42, 0.10, alpha), maxf(1.2, 4.0 - ring_float * 0.55), true)
		canvas.draw_arc(center + Vector2(0.0, -5.0), radius * 0.72, start + PI * 0.35, start + PI * 1.25, 38, Color(1.0, 0.88, 0.36, alpha * 0.72), 1.5, true)
	var swirl_ember := DragonBreathTextureCache.get_ember_texture()
	if swirl_ember != null:
		for i in range(7):
			var index_float := float(i)
			var orbit_angle := runtime_elapsed * (3.1 + index_float * 0.21) * swirl_spin_sign + index_float * (TAU / 7.0)
			var orbit_radius := 26.0 + index_float * 9.0 + sin(runtime_elapsed * 6.0 + index_float) * 4.0
			var ember_position := center + Vector2(cos(orbit_angle), sin(orbit_angle) * 0.78) * orbit_radius
			var ember_alpha := (0.5 - index_float * 0.04) * swirl_envelope
			_draw_centered_tex(canvas, swirl_ember, ember_position, lerpf(18.0, 9.0, index_float / 7.0), Color(1.0, 0.62, 0.24, ember_alpha))
			_draw_centered_tex(canvas, swirl_ember, ember_position, lerpf(8.0, 4.0, index_float / 7.0), Color(1.0, 0.95, 0.66, ember_alpha * 1.4))
	if last_ball_pos != Vector2.ZERO:
		var ball_center := last_ball_pos + shake_offset
		if glow_tex != null:
			_draw_centered_tex(canvas, glow_tex, ball_center, 54.0, Color(1.0, 0.62, 0.20, 0.22 * swirl_envelope))
		for ring in range(3):
			var ring_float := float(ring)
			var radius := 18.0 + ring_float * 8.0 + sin(runtime_elapsed * 10.0 + ring_float) * 2.2
			var start := -runtime_elapsed * (5.0 + ring_float) * swirl_spin_sign + ring_float * 1.7
			canvas.draw_arc(ball_center, radius, start, start + PI * 1.35, 36, Color(1.0, 0.74, 0.22, (0.42 - ring_float * 0.08) * swirl_envelope), 1.7, true)
		var spark := 0.55 + 0.45 * sin(runtime_elapsed * 12.0)
		ImpactFlareTextureCache.draw_sparkle(canvas, ball_center, lerpf(9.0, 15.0, spark), Color(1.0, 0.92, 0.56), 0.5 * swirl_envelope)


func _get_swirl_ring_projection(runtime_elapsed: float, ring_index: int, swirl_spin_sign: float) -> Vector2:
	var ring_float := float(ring_index)
	var radius := 34.0 + ring_float * 22.0 + sin(runtime_elapsed * 5.0 + ring_float) * 3.5
	var start := runtime_elapsed * (2.6 + ring_float * 0.38) * swirl_spin_sign + ring_float * 1.45
	return Vector2(radius, start)


func _draw_ball_swirl_trail(
	canvas: CanvasItem,
	shake_offset: Vector2,
	ball_swirl_trail: Array[Dictionary],
	swirl_trail_life_seconds: float,
	swirl_spin_sign: float
) -> void:
	for entry in ball_swirl_trail:
		var life := float(entry.get("life", 0.0))
		var max_life := maxf(0.01, float(entry.get("max_life", swirl_trail_life_seconds)))
		var ratio := clampf(life / max_life, 0.0, 1.0)
		if ratio <= 0.01:
			continue
		var pos: Vector2 = entry.get("pos", Vector2.ZERO) + shake_offset
		var phase := float(entry.get("phase", 0.0))
		var radius := lerpf(7.0, 21.0, 1.0 - ratio)
		var start := phase + (1.0 - ratio) * TAU * swirl_spin_sign
		var trail_ember := DragonBreathTextureCache.get_ember_texture()
		if trail_ember != null:
			_draw_centered_tex(canvas, trail_ember, pos, lerpf(6.0, 18.0, 1.0 - ratio), Color(1.0, 0.52, 0.18, 0.22 * ratio))
		canvas.draw_arc(pos, radius, start, start + PI * 1.2, 24, Color(1.0, 0.90, 0.42, 0.34 * ratio), 1.4, true)
		canvas.draw_arc(pos + Vector2(0.0, -2.0), radius * 0.64, start + PI * 0.65, start + PI * 1.55, 20, Color(1.0, 0.46, 0.14, 0.25 * ratio), 1.0, true)


func _draw_flying_dragon(
	canvas: CanvasItem,
	shake_offset: Vector2,
	flying_dragon: Dictionary,
	wind_direction: float
) -> void:
	if not bool(flying_dragon.get("active", false)):
		return
	var pos: Vector2 = flying_dragon.get("pos", Vector2.ZERO) + shake_offset
	var dir := float(flying_dragon.get("direction", wind_direction))
	var wing_time := float(flying_dragon.get("wing_time", 0.0))
	var glow_pulse := 0.5 + 0.5 * sin(wing_time * 9.0)
	var halo_tex := ImpactFlareTextureCache.get_glow_texture()
	if halo_tex != null:
		var halo_size := 132.0 + glow_pulse * 24.0
		_draw_centered_tex(canvas, halo_tex, pos, halo_size, Color(1.0, 0.32, 0.08, 0.26))
		_draw_centered_tex(canvas, halo_tex, pos, halo_size * 0.58, Color(1.0, 0.58, 0.18, 0.30))
		_draw_centered_tex(canvas, halo_tex, pos, halo_size * 0.32, Color(1.0, 0.86, 0.42, 0.26))
	else:
		canvas.draw_circle(pos, 52.0 + glow_pulse * 8.0, Color(1.0, 0.40, 0.10, 0.12))
		canvas.draw_circle(pos, 34.0, Color(1.0, 0.62, 0.18, 0.14))
	if _dragon_sheet_texture != null:
		_draw_dragon_sprite(canvas, pos, dir, wing_time)
	else:
		_draw_flying_dragon_procedural(canvas, pos, dir, wing_time)
	canvas.draw_line(pos - Vector2(dir * 22.0, -4.0), pos - Vector2(dir * 78.0, 22.0), Color(1.0, 0.86, 0.36, 0.62), 4.0, true)
	canvas.draw_line(pos - Vector2(dir * 30.0, 8.0), pos - Vector2(dir * 92.0, 34.0), Color(1.0, 0.46, 0.14, 0.46), 3.0, true)


func _draw_dragon_sprite(canvas: CanvasItem, pos: Vector2, dir: float, wing_time: float) -> void:
	var frame := int(wing_time * DRAGON_FLAP_FPS) % DRAGON_SHEET_FRAME_COUNT
	if frame < 0:
		frame += DRAGON_SHEET_FRAME_COUNT
	var texture_size := _dragon_sheet_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_draw_flying_dragon_procedural(canvas, pos, dir, wing_time)
		return
	var cell_width := texture_size.x / float(DRAGON_SHEET_COLS)
	var cell_height := texture_size.y / float(DRAGON_SHEET_ROWS)
	var column := frame % DRAGON_SHEET_COLS
	var row := frame / DRAGON_SHEET_COLS
	var source := Rect2(float(column) * cell_width, float(row) * cell_height, cell_width, cell_height)
	var half_size := DRAGON_SPRITE_DRAW_SIZE * 0.5
	var destination := Rect2(pos - Vector2(half_size, half_size), Vector2(DRAGON_SPRITE_DRAW_SIZE, DRAGON_SPRITE_DRAW_SIZE))
	var warm_tint := Color(1.0, 0.74, 0.52, 0.94)
	var previous_material: Material = canvas.material
	canvas.material = null
	if dir < 0.0:
		_blit_flipped_region(canvas, _dragon_sheet_texture, source, destination, warm_tint)
	else:
		canvas.draw_texture_rect_region(_dragon_sheet_texture, destination, source, warm_tint, false, true)
	canvas.material = previous_material


func _blit_flipped_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
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


func _draw_flying_dragon_procedural(canvas: CanvasItem, pos: Vector2, dir: float, wing_time: float) -> void:
	var flap := 0.5 + 0.5 * sin(wing_time * 9.0)
	var body_color := Color(0.95, 0.11, 0.06, 0.58)
	var glow_color := Color(1.0, 0.62, 0.16, 0.28)
	canvas.draw_arc(pos, 26.0, 0.0, TAU, 32, glow_color, 8.0, true)
	canvas.draw_circle(pos, 13.0, body_color)
	canvas.draw_circle(pos + Vector2(dir * 14.0, -2.0), 8.0, Color(1.0, 0.34, 0.10, 0.62))
	var wing_raise := lerpf(18.0, 34.0, flap)
	var left_root := pos + Vector2(-dir * 4.0, -2.0)
	var right_root := pos + Vector2(dir * 2.0, -2.0)
	var top_wing := PackedVector2Array([
		left_root,
		pos + Vector2(-dir * 44.0, -wing_raise),
		pos + Vector2(-dir * 22.0, 10.0),
	])
	var low_wing := PackedVector2Array([
		right_root,
		pos + Vector2(dir * 34.0, -wing_raise * 0.7),
		pos + Vector2(dir * 20.0, 13.0),
	])
	canvas.draw_colored_polygon(top_wing, Color(1.0, 0.22, 0.08, 0.38))
	canvas.draw_colored_polygon(low_wing, Color(1.0, 0.68, 0.24, 0.26))


func _draw_hit_flash(canvas: CanvasItem, center: Vector2, ratio: float, last_hit_dir: Vector2) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped <= 0.01:
		return
	var expand := 1.0 - clamped
	var radius := lerpf(46.0, 138.0, expand)
	ImpactFlareTextureCache.draw_glow(canvas, center, radius * 1.05, Color(1.0, 0.42, 0.12), 0.55 * clamped)
	ImpactFlareTextureCache.draw_burst(canvas, center, radius, Color(1.0, 0.82, 0.40), 0.95 * clamped)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, radius * 0.58, Color(1.0, 0.97, 0.72), 0.80 * clamped)
	canvas.draw_arc(center, radius * 0.88, 0.0, TAU, 56, Color(1.0, 0.90, 0.52, 0.55 * clamped), maxf(1.5, 3.0 * clamped), true)
	if last_hit_dir.length_squared() > 0.001:
		for i in range(3):
			var step := float(i + 1)
			var offset := last_hit_dir * (radius * 0.42 * step)
			var tail_size := radius * lerpf(0.78, 0.30, step / 3.0)
			var tail_alpha := clamped * lerpf(0.55, 0.20, step / 3.0)
			ImpactFlareTextureCache.draw_glow(canvas, center + offset, tail_size, Color(1.0, 0.62, 0.20), tail_alpha)


func _ensure_material() -> void:
	if _additive_material != null:
		return
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _draw_centered_tex(canvas: CanvasItem, texture: Texture2D, center: Vector2, size_pixels: float, color: Color) -> void:
	if canvas == null or texture == null or size_pixels <= 0.0 or color.a <= 0.0:
		return
	var size := Vector2(size_pixels, size_pixels)
	canvas.draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, color)


func _ensure_dragon_sheet() -> void:
	if _dragon_sheet_texture != null:
		return
	var resource: Variant = load(DRAGON_SHEET_PATH)
	if resource is Texture2D:
		_dragon_sheet_texture = resource as Texture2D
