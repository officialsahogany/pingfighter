extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const DragonBreathTextureCache := preload("res://scripts/lingpet/lingpet_dragon_breath_texture_cache.gd")

const PROJECTION_FPS := 60.0


func draw_breath(
	canvas: CanvasItem,
	shake_offset: Vector2,
	breath_active: bool,
	elapsed: float,
	origin: Vector2,
	direction: float,
	particles: Array[Dictionary],
	hit_flash_timer: float,
	last_hit_pos: Vector2,
	hit_flash_seconds: float,
	breath_spawn_seconds: float,
	jet_material: ShaderMaterial,
	additive_material: CanvasItemMaterial
) -> void:
	_draw_breath_jet(
		canvas,
		shake_offset,
		breath_active,
		elapsed,
		origin,
		direction,
		breath_spawn_seconds,
		jet_material
	)
	var previous_material: Material = canvas.material
	canvas.material = additive_material
	_draw_breath_muzzle(canvas, shake_offset, breath_active, elapsed, origin, direction, breath_spawn_seconds)
	for particle_index in range(particles.size()):
		_draw_breath_particle(canvas, particles[particle_index], particle_index, shake_offset, elapsed, direction)
	if hit_flash_timer > 0.0:
		_draw_hit_flash(canvas, last_hit_pos + shake_offset, hit_flash_timer / hit_flash_seconds)
	canvas.material = previous_material


func get_particle_mote_roll_for_tests(particle: Dictionary, particle_index: int, elapsed: float) -> float:
	return _projection_unit(particle, particle_index, elapsed, 0)


func get_particle_mote_offset_for_tests(particle: Dictionary, particle_index: int, elapsed: float) -> Vector2:
	var size := maxf(0.0, float(particle.get("size", 0.0)))
	return Vector2(
		lerpf(-size, size, _projection_unit(particle, particle_index, elapsed, 1)),
		lerpf(-size, size, _projection_unit(particle, particle_index, elapsed, 2))
	)


func _draw_breath_jet(
	canvas: CanvasItem,
	shake_offset: Vector2,
	breath_active: bool,
	elapsed: float,
	origin_value: Vector2,
	direction: float,
	breath_spawn_seconds: float,
	jet_material: ShaderMaterial
) -> void:
	if jet_material == null:
		return
	var envelope := _jet_envelope(breath_active, elapsed, breath_spawn_seconds)
	if envelope <= 0.01:
		return
	var texture: Texture2D = DragonBreathTextureCache.get_flame_tongue_texture()
	if texture == null:
		return
	var pulse := 0.86 + 0.14 * sin(elapsed * 11.0)
	var up := Vector2(0.0, direction)
	var origin := origin_value + shake_offset
	var jet_length := lerpf(90.0, 230.0, envelope) * pulse
	var outer_width := lerpf(46.0, 86.0, envelope)
	jet_material.set_shader_parameter("elapsed", elapsed)
	jet_material.set_shader_parameter("intensity", 1.0 + 0.6 * envelope)
	var previous_material: Material = canvas.material
	canvas.material = jet_material
	_draw_flame_tongue(
		canvas,
		texture,
		origin + up * (jet_length * 0.5),
		up,
		outer_width,
		jet_length * 0.5,
		Color(1.0, 0.50, 0.15, 0.62 * envelope)
	)
	var inner_length := jet_length * 0.7
	_draw_flame_tongue(
		canvas,
		texture,
		origin + up * (inner_length * 0.5),
		up,
		outer_width * 0.55,
		inner_length * 0.5,
		Color(1.0, 0.82, 0.46, 0.7 * envelope)
	)
	canvas.material = previous_material


func _jet_envelope(breath_active: bool, elapsed: float, breath_spawn_seconds: float) -> float:
	if not breath_active or elapsed >= breath_spawn_seconds + 0.25:
		return 0.0
	var jet_in := _ease_out(clampf(elapsed / 0.18, 0.0, 1.0))
	var jet_out := 1.0 - _ease_out(clampf((elapsed - (breath_spawn_seconds - 0.30)) / 0.55, 0.0, 1.0))
	return jet_in * clampf(jet_out, 0.0, 1.0)


func _draw_breath_muzzle(
	canvas: CanvasItem,
	shake_offset: Vector2,
	breath_active: bool,
	elapsed: float,
	origin_value: Vector2,
	direction: float,
	breath_spawn_seconds: float
) -> void:
	var envelope := _jet_envelope(breath_active, elapsed, breath_spawn_seconds)
	if envelope <= 0.01:
		return
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	if ember == null:
		return
	var origin := origin_value + shake_offset
	var up := Vector2(0.0, direction)
	var pulse := 0.85 + 0.15 * sin(elapsed * 17.0)
	var root_length := 150.0 * envelope * pulse
	_draw_flame_tongue(
		canvas,
		DragonBreathTextureCache.get_flame_tongue_texture(),
		origin + up * (root_length * 0.5),
		up,
		46.0 * envelope,
		root_length * 0.5,
		Color(1.0, 0.52, 0.18, 0.4 * envelope)
	)
	_draw_centered_tex(canvas, ember, origin, 124.0 * envelope * pulse, Color(1.0, 0.46, 0.14, 0.4 * envelope))
	_draw_centered_tex(canvas, ember, origin, 72.0 * envelope * pulse, Color(1.0, 0.72, 0.32, 0.5 * envelope))
	_draw_centered_tex(canvas, ember, origin, 34.0 * envelope * pulse, Color(1.0, 0.96, 0.82, 0.62 * envelope))


func _draw_breath_particle(
	canvas: CanvasItem,
	particle: Dictionary,
	particle_index: int,
	shake_offset: Vector2,
	elapsed: float,
	direction: float
) -> void:
	if float(particle.get("delay", 0.0)) > 0.0:
		return
	var position: Vector2 = particle.get("pos", Vector2.ZERO) + shake_offset
	var size := float(particle.get("size", 0.0))
	if size <= 2.0:
		return
	var max_life := maxf(0.01, float(particle.get("max_life", 1.0)))
	var life := float(particle.get("life", 0.0))
	var life_ratio := _particle_life_ratio(life, max_life)
	if life_ratio <= 0.02:
		return
	var phase := float(particle.get("phase", 0.0))
	var age := 1.0 - clampf(life / max_life, 0.0, 1.0)
	var pop := _ease_out(clampf(age / 0.14, 0.0, 1.0))
	var draw_size := size * lerpf(0.5, 1.0, pop)
	var heat := clampf(0.30 + 0.70 * life_ratio, 0.0, 1.0)
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	_draw_centered_tex(canvas, ember, position, draw_size * 4.6, _tint(heat * 0.60, 0.20 * life_ratio))
	_draw_centered_tex(canvas, ember, position, draw_size * 2.7, _tint(heat * 0.85, 0.40 * life_ratio))
	var wob: float = float(particle.get("wob", 0.5))
	var lick_angle: float = (wob - 0.5) * 0.95 + sin(phase * 2.3 + wob * TAU) * 0.22
	var lick: Vector2 = Vector2(0.0, direction).rotated(lick_angle)
	var tongue: Texture2D = DragonBreathTextureCache.get_flame_tongue_texture()
	_draw_flame_tongue(canvas, tongue, position, lick, draw_size * 1.2, draw_size * 1.5, _tint(minf(heat, 0.80), 0.46 * life_ratio))
	_draw_centered_tex(canvas, ember, position, draw_size * 1.05, Color(1.0, 0.82, 0.50, 0.42 * life_ratio))
	if get_particle_mote_roll_for_tests(particle, particle_index, elapsed) < 0.05 * life_ratio:
		var mote_size := lerpf(2.5, 4.0, _projection_unit(particle, particle_index, elapsed, 3))
		_draw_centered_tex(
			canvas,
			ember,
			position + get_particle_mote_offset_for_tests(particle, particle_index, elapsed),
			mote_size,
			Color(1.0, 0.86, 0.56, 0.6)
		)


func _draw_hit_flash(canvas: CanvasItem, center: Vector2, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped <= 0.01:
		return
	var burst: Texture2D = ImpactFlareTextureCache.get_burst_texture()
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	var radius := lerpf(78.0, 22.0, clamped)
	_draw_centered_tex(canvas, ember, center, radius * 1.4, Color(1.0, 0.5, 0.13, 0.46 * clamped))
	_draw_centered_tex(canvas, burst, center, radius * 2.6, Color(1.0, 0.82, 0.40, 0.72 * clamped))
	_draw_centered_tex(canvas, burst, center, radius * 1.5, Color(1.0, 0.92, 0.6, 0.6 * clamped))
	_draw_centered_tex(canvas, ember, center, radius * 0.8, Color(1.0, 0.97, 0.84, 0.85 * clamped))


func _draw_flame_tongue(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	up: Vector2,
	half_width: float,
	half_height: float,
	color: Color
) -> void:
	if texture == null or half_width <= 0.0 or half_height <= 0.0:
		return
	var right := Vector2(-up.y, up.x)
	var tip := up * half_height
	var base := -up * half_height
	var right_width := right * half_width
	var points := PackedVector2Array([
		center + tip - right_width,
		center + tip + right_width,
		center + base + right_width,
		center + base - right_width,
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_colored_polygon(points, color, uvs, texture)


func _draw_centered_tex(canvas: CanvasItem, texture: Texture2D, center: Vector2, size_pixels: float, color: Color) -> void:
	if texture == null or size_pixels <= 0.0 or color.a <= 0.0:
		return
	var draw_size := Vector2(size_pixels, size_pixels)
	canvas.draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false, color)


func _particle_life_ratio(life: float, max_life: float) -> float:
	var fade_start := max_life * 0.4
	if life > fade_start:
		return 1.0
	if life > 0.0:
		var progress := life / fade_start
		var smooth_progress := progress * progress * (3.0 - 2.0 * progress)
		return 0.3 + 0.7 * smooth_progress
	var tail := clampf((life + 0.5) / 0.5, 0.0, 1.0)
	return 0.3 * tail * tail


func _tint(heat: float, alpha: float) -> Color:
	var color := _heat_color(heat)
	color.a = clampf(alpha, 0.0, 1.0)
	return color


func _heat_color(heat: float) -> Color:
	var clamped_heat := clampf(heat, 0.0, 1.0)
	if clamped_heat < 0.5:
		var low_progress := clamped_heat / 0.5
		return Color(1.0, lerpf(0.18, 0.48, low_progress), lerpf(0.03, 0.11, low_progress))
	var high_progress := (clamped_heat - 0.5) / 0.5
	return Color(1.0, lerpf(0.48, 0.84, high_progress), lerpf(0.11, 0.46, high_progress))


func _projection_unit(particle: Dictionary, particle_index: int, elapsed: float, channel: int) -> float:
	var frame_index := int(floor(maxf(0.0, elapsed) * PROJECTION_FPS))
	var phase := float(particle.get("phase", 0.0))
	var wob := float(particle.get("wob", 0.0))
	var seed := (
		phase * 12.9898
		+ wob * 78.233
		+ float(particle_index) * 37.719
		+ float(frame_index) * 5.3983
		+ float(channel) * 19.191
	)
	return fposmod(sin(seed) * 43758.5453, 1.0)


func _ease_out(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
