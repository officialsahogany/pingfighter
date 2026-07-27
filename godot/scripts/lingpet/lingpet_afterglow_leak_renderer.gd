extends RefCounted

const AfterglowFluidTextureCache := preload("res://scripts/effects/afterglow_fluid_texture_cache.gd")

const POOL_APPEAR_SECONDS := 0.12
const FILL_SECONDS := 0.66
const EMIT_FLASH_SECONDS := 0.18
const SPLAT_FADE_IN := 0.12

const KIND_JET := 0
const KIND_SPLASH := 1
const KIND_WISP := 3

const COLOR_GLOW := Color(0.20, 1.0, 0.62)
const COLOR_BODY := Color(0.32, 1.0, 0.72)
const COLOR_CORE := Color(0.88, 1.0, 0.74)
const COLOR_CAUSTIC := Color(0.72, 1.0, 0.78)
const COLOR_RIM := Color(0.82, 1.0, 0.70)
const COLOR_DROPLET_HOT := Color(1.0, 1.0, 0.84)
const COLOR_DROPLET_COOL := Color(0.50, 1.0, 0.70)

var _prewarmed := false


func prewarm() -> void:
	if _prewarmed:
		return
	AfterglowFluidTextureCache.prewarm()
	_prewarmed = true


func draw_afterglow(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_time_seconds: float,
	residues: Array[Dictionary],
	particles: Array,
	absorb_flash_timer: float,
	absorb_flash_seconds: float,
	last_absorb_pos: Vector2,
	default_duration_seconds: float,
	default_absorb_radius: float,
	seep_fade_seconds: float
) -> void:
	if canvas == null:
		return
	for residue in residues:
		_draw_residue(canvas, residue, shake_offset, visual_time_seconds, absorb_flash_seconds, default_duration_seconds, default_absorb_radius, seep_fade_seconds)
	_draw_particles(canvas, particles, shake_offset)
	if absorb_flash_timer > 0.0 and last_absorb_pos != Vector2.ZERO:
		var ratio: float = clampf(absorb_flash_timer / maxf(0.001, absorb_flash_seconds), 0.0, 1.0)
		var flash_pos: Vector2 = last_absorb_pos + shake_offset
		var flash_radius: float = lerpf(20.0, 46.0, 1.0 - ratio)
		_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), flash_pos, flash_radius, flash_radius, COLOR_DROPLET_HOT, 0.36 * ratio)
		canvas.draw_arc(flash_pos, lerpf(10.0, 32.0, 1.0 - ratio), 0.0, TAU, 36, Color(0.90, 1.0, 0.70, 0.55 * ratio), 2.0, true)


func get_pool_projection_for_tests(
	visual_time_seconds: float,
	residue: Dictionary,
	default_duration_seconds: float,
	default_absorb_radius: float,
	seep_fade_seconds: float
) -> Vector4:
	var duration: float = maxf(0.01, float(residue.get("duration", default_duration_seconds)))
	var timer: float = clampf(float(residue.get("timer", 0.0)), 0.0, duration)
	var age: float = float(residue.get("age", 0.0))
	var life_ratio: float = clampf(timer / duration, 0.0, 1.0)
	var seep_ratio: float = clampf(timer / maxf(0.001, seep_fade_seconds), 0.0, 1.0)
	var total_gauge: float = maxf(0.01, float(residue.get("total_gauge", 1.0)))
	var remaining_ratio: float = clampf(float(residue.get("remaining_gauge", 0.0)) / total_gauge, 0.0, 1.0)
	var alpha: float = minf(life_ratio, seep_ratio) * (0.42 + 0.58 * remaining_ratio)
	var fill: float = _ease_out_quad(clampf(age / FILL_SECONDS, 0.0, 1.0))
	var grow: float = 0.30 + 0.70 * fill
	var phase_seed: float = float(residue.get("seed", 0.0))
	var breathe: float = 0.94 + 0.06 * sin(visual_time_seconds * 2.4 + phase_seed)
	var radius: float = maxf(8.0, float(residue.get("absorb_radius", default_absorb_radius)))
	var rx: float = radius * 0.82 * grow * breathe
	return Vector4(rx, rx * 0.34, alpha, fill)


func _draw_residue(
	canvas: CanvasItem,
	residue: Dictionary,
	shake_offset: Vector2,
	visual_time_seconds: float,
	absorb_flash_seconds: float,
	default_duration_seconds: float,
	default_absorb_radius: float,
	seep_fade_seconds: float
) -> void:
	var pool: Vector2 = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var origin: Vector2 = _as_vector2(residue.get("origin", residue.get("pos", Vector2.ZERO)), pool) + shake_offset
	var age: float = float(residue.get("age", 0.0))
	var emit_flash: float = 1.0 - clampf(age / EMIT_FLASH_SECONDS, 0.0, 1.0)
	if emit_flash > 0.0:
		var flash_radius: float = lerpf(10.0, 30.0, 1.0 - emit_flash)
		_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), origin, flash_radius, flash_radius, COLOR_DROPLET_HOT, 0.55 * emit_flash)
		canvas.draw_arc(origin, flash_radius * 0.7, 0.0, TAU, 26, Color(0.92, 1.0, 0.76, 0.5 * emit_flash), 2.0, true)

	var projection: Vector4 = get_pool_projection_for_tests(visual_time_seconds, residue, default_duration_seconds, default_absorb_radius, seep_fade_seconds)
	if projection.z <= 0.01:
		return
	var rx: float = projection.x
	var ry: float = projection.y
	var alpha: float = projection.z
	var fill: float = projection.w
	var appear: float = clampf(age / POOL_APPEAR_SECONDS, 0.0, 1.0)
	var pool_alpha: float = alpha * appear
	var phase_seed: float = float(residue.get("seed", 0.0))
	var absorb_ratio: float = clampf(float(residue.get("absorb_flash", 0.0)) / maxf(0.001, absorb_flash_seconds), 0.0, 1.0)

	_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), pool, rx * 1.55, ry * 2.6, COLOR_GLOW, pool_alpha * (0.30 + 0.14 * absorb_ratio))
	_draw_splats(canvas, residue, shake_offset, age, pool_alpha, visual_time_seconds)
	_draw_tongues(canvas, pool, rx, ry, fill, phase_seed, visual_time_seconds, pool_alpha)
	_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), pool, rx, ry, COLOR_BODY, pool_alpha * 0.64)
	_blit(canvas, AfterglowFluidTextureCache.get_body_texture(), pool, rx * 0.92, ry * 0.92, COLOR_BODY, pool_alpha * 0.5)
	_blit(canvas, AfterglowFluidTextureCache.get_body_texture(), pool, rx * 0.46, ry * 0.52, COLOR_CORE, pool_alpha * (0.44 + 0.18 * absorb_ratio))
	var caustic_breathe: float = 1.0 + 0.08 * sin(visual_time_seconds * 1.5 + phase_seed)
	_blit(canvas, AfterglowFluidTextureCache.get_caustic_texture(), pool + Vector2(sin(visual_time_seconds * 1.1 + phase_seed) * 4.0, 0.0), rx * 0.9 * caustic_breathe, ry * 0.9 * caustic_breathe, COLOR_CAUSTIC, pool_alpha * 0.52)
	_blit(canvas, AfterglowFluidTextureCache.get_caustic_texture(), pool + Vector2(-sin(visual_time_seconds * 0.8 + phase_seed) * 4.0, 0.0), rx * 0.64, ry * 0.64, Color(0.95, 1.0, 0.88), pool_alpha * 0.36)
	_blit(canvas, AfterglowFluidTextureCache.get_body_texture(), pool + Vector2(0.0, ry * 0.46), rx * 0.72, ry * 0.30, COLOR_RIM, pool_alpha * 0.30)


func _draw_splats(canvas: CanvasItem, residue: Dictionary, shake_offset: Vector2, age: float, pool_alpha: float, visual_time_seconds: float) -> void:
	if pool_alpha <= 0.02:
		return
	var splats: Array = residue.get("splats", [])
	if splats.is_empty():
		return
	var body: Texture2D = AfterglowFluidTextureCache.get_body_texture()
	var glow: Texture2D = AfterglowFluidTextureCache.get_glow_texture()
	for splat in splats:
		var splat_age: float = age - float(splat.get("born", 0.0))
		var splat_in: float = clampf(splat_age / SPLAT_FADE_IN, 0.0, 1.0)
		if splat_in <= 0.0:
			continue
		var splat_seed: float = float(splat.get("seed", 0.0))
		var wobble: float = 0.92 + 0.08 * sin(visual_time_seconds * 2.0 + splat_seed)
		var width: float = float(splat.get("size", 8.0)) * (0.6 + 0.4 * splat_in) * wobble
		var height: float = width * 0.42
		var pos: Vector2 = Vector2(float(splat.get("x", 0.0)), float(splat.get("y", 0.0))) + shake_offset
		_blit(canvas, glow, pos, width * 1.4, height * 1.6, COLOR_GLOW, pool_alpha * 0.20 * splat_in)
		_blit(canvas, body, pos, width, height, COLOR_BODY, pool_alpha * 0.50 * splat_in)
		_blit(canvas, body, pos, width * 0.5, height * 0.55, COLOR_CORE, pool_alpha * 0.30 * splat_in)


func _draw_tongues(canvas: CanvasItem, pool: Vector2, rx: float, ry: float, fill: float, residue_seed: float, visual_time_seconds: float, pool_alpha: float) -> void:
	if pool_alpha <= 0.02:
		return
	var body: Texture2D = AfterglowFluidTextureCache.get_body_texture()
	if body == null:
		return
	for index in range(4):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var lane: float = 1.0 if index < 2 else 0.55
		var wobble: float = 0.7 + 0.3 * sin(visual_time_seconds * 1.6 + residue_seed + float(index) * 1.3)
		var reach: float = rx * (0.55 + 0.7 * fill) * lane * wobble
		if reach <= 2.0:
			continue
		var lobe_center_x: float = pool.x + side * reach * 0.6
		var lobe_y: float = pool.y + ry * (0.1 + 0.16 * sin(visual_time_seconds * 1.2 + residue_seed + float(index) * 2.0))
		var lobe_width: float = reach * 0.62
		var lobe_height: float = ry * (0.62 if index < 2 else 0.5)
		_blit(canvas, body, Vector2(lobe_center_x, lobe_y), lobe_width, lobe_height, COLOR_BODY, pool_alpha * 0.34)


func _draw_particles(canvas: CanvasItem, particles: Array, shake_offset: Vector2) -> void:
	if particles.is_empty():
		return
	var droplet: Texture2D = AfterglowFluidTextureCache.get_droplet_texture()
	if droplet == null:
		return
	for particle in particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var kind: int = int(particle["kind"])
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"])
		if kind == KIND_JET:
			var alpha: float = clampf(life_t * 2.0, 0.0, 1.0)
			if alpha <= 0.02:
				continue
			var velocity: Vector2 = particle["vel"]
			var speed: float = velocity.length()
			var direction: Vector2 = velocity / speed if speed > 1.0 else Vector2(0.0, 1.0)
			var streak_length: float = clampf(speed * 0.05, 5.0, 22.0)
			var tail: Vector2 = pos - direction * streak_length
			canvas.draw_line(tail, pos, Color(COLOR_BODY.r, COLOR_BODY.g, COLOR_BODY.b, alpha * 0.42), size * 2.0, true)
			canvas.draw_line(tail, pos, Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, alpha * 0.95), maxf(1.0, size * 0.9), true)
			_blit(canvas, droplet, pos, size * 0.95, size * 0.95, COLOR_DROPLET_HOT, alpha)
			continue
		var particle_alpha: float = clampf(life_t * 1.3, 0.0, 1.0) if kind == KIND_SPLASH else life_t
		if particle_alpha <= 0.02:
			continue
		var draw_size: float = size * (0.65 + 0.35 * life_t)
		var color: Color
		if kind == KIND_SPLASH:
			color = Color(COLOR_DROPLET_HOT.r, COLOR_DROPLET_HOT.g, COLOR_DROPLET_HOT.b, particle_alpha * 0.9)
		elif kind == KIND_WISP:
			color = Color(0.78, 1.0, 0.72, particle_alpha * 0.9)
		else:
			color = Color(COLOR_DROPLET_COOL.r, COLOR_DROPLET_COOL.g, COLOR_DROPLET_COOL.b, particle_alpha * 0.55)
		canvas.draw_texture_rect(droplet, Rect2(pos - Vector2(draw_size, draw_size), Vector2(draw_size * 2.0, draw_size * 2.0)), false, color)


func _blit(canvas: CanvasItem, texture: Texture2D, center: Vector2, rx: float, ry: float, color: Color, blit_alpha: float) -> void:
	if texture == null or rx <= 0.5 or ry <= 0.5 or blit_alpha <= 0.0:
		return
	canvas.draw_texture_rect(texture, Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), false, Color(color.r, color.g, color.b, clampf(blit_alpha, 0.0, 1.0)))


func _ease_out_quad(x: float) -> float:
	var clamped: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value as Vector2 if value is Vector2 else fallback
