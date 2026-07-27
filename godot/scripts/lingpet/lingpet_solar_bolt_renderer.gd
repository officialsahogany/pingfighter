extends RefCounted

# Original PingFighter SolarBolt palette. Glow alpha is raised because Godot's
# immediate draw_polyline path has no per-call additive blend.
const BOLT_GLOW_COLOR := Color(1.0, 0.706, 0.118, 0.34)
const BOLT_CORE_COLOR := Color(1.0, 0.941, 0.549, 1.0)
const BOLT_WHITE_COLOR := Color(1.0, 1.0, 0.941, 1.0)
const BRANCH_CORE_COLOR := Color(0.863, 0.863, 1.0, 1.0)
const BRANCH_GLOW_COLOR := Color(0.784, 0.706, 1.0, 0.28)
const FORK_GLOW_COLOR := Color(1.0, 1.0, 0.902, 0.63)
const FLASH_COLOR := Color(1.0, 0.90, 0.39, 1.0)
const EXPL_FLASH_COLOR := Color(1.0, 1.0, 0.941, 1.0)
const EXPL_CORE_COLOR := Color(1.0, 0.941, 0.588, 1.0)
const EXPL_INNER_COLOR := Color(1.0, 1.0, 0.863, 1.0)
const EXPL_RING_COLOR := Color(1.0, 0.784, 0.314, 1.0)
const EXPL_ARC_COLORS: Array[Color] = [
	Color(0.706, 0.824, 1.0),
	Color(1.0, 0.941, 0.706),
	Color(0.863, 0.902, 1.0),
]


func prewarm() -> void:
	pass


func draw_solar_bolt(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime_elapsed: float,
	effects: Array[Dictionary],
	particles: Array[Dictionary],
	field_size: Vector2,
	lightning_seconds: float,
	explosion_seconds: float,
	spark_seconds: float,
	screen_flash_alpha: float
) -> void:
	if canvas == null:
		return
	_draw_screen_flash(canvas, effects, field_size, lightning_seconds, screen_flash_alpha)
	for effect in effects:
		_draw_effect(canvas, effect, shake_offset, runtime_elapsed, explosion_seconds)
	_draw_particles(canvas, particles, shake_offset, spark_seconds)


func is_bolt_visible_for_tests(runtime_elapsed: float, seed_value: float) -> bool:
	return _is_bolt_visible(runtime_elapsed, seed_value)


func _draw_screen_flash(
	canvas: CanvasItem,
	effects: Array[Dictionary],
	field_size: Vector2,
	lightning_seconds: float,
	screen_flash_alpha: float
) -> void:
	var alpha := 0.0
	for effect in effects:
		alpha = maxf(alpha, clampf(float(effect.get("lightning", 0.0)) / maxf(0.001, lightning_seconds), 0.0, 1.0) * screen_flash_alpha)
	if alpha > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, field_size), Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, alpha), true)


func _draw_effect(
	canvas: CanvasItem,
	effect: Dictionary,
	shake_offset: Vector2,
	runtime_elapsed: float,
	explosion_seconds: float
) -> void:
	var end: Vector2 = effect.get("end", Vector2.ZERO)
	var lightning_left := float(effect.get("lightning", 0.0))
	var explosion_left := float(effect.get("explosion", 0.0))
	var seed_value := float(effect.get("seed", 0.0))
	# The original fixed strike-time path flickers at 85% visibility. Runtime
	# time and the effect seed preserve that cadence without redraw-side RNG.
	if lightning_left > 0.0 and _is_bolt_visible(runtime_elapsed, seed_value):
		var fade := minf(1.0, lightning_left / 0.06)
		var main: PackedVector2Array = effect.get("main", PackedVector2Array())
		var branches: Array = effect.get("branches", [])
		if main.size() >= 2:
			var main_pts := _shift_points(main, shake_offset)
			canvas.draw_polyline(main_pts, Color(BOLT_GLOW_COLOR.r, BOLT_GLOW_COLOR.g, BOLT_GLOW_COLOR.b, BOLT_GLOW_COLOR.a * fade), 6.0, true)
			for branch in branches:
				var branch_glow: PackedVector2Array = branch
				if branch_glow.size() >= 2:
					canvas.draw_polyline(_shift_points(branch_glow, shake_offset), Color(BRANCH_GLOW_COLOR.r, BRANCH_GLOW_COLOR.g, BRANCH_GLOW_COLOR.b, BRANCH_GLOW_COLOR.a * fade), 4.0, true)
			canvas.draw_polyline(main_pts, Color(BOLT_CORE_COLOR.r, BOLT_CORE_COLOR.g, BOLT_CORE_COLOR.b, fade), 2.0, true)
			for branch in branches:
				var branch_core: PackedVector2Array = branch
				if branch_core.size() >= 2:
					canvas.draw_polyline(_shift_points(branch_core, shake_offset), Color(BRANCH_CORE_COLOR.r, BRANCH_CORE_COLOR.g, BRANCH_CORE_COLOR.b, fade), 1.0, true)
			canvas.draw_polyline(main_pts, Color(BOLT_WHITE_COLOR.r, BOLT_WHITE_COLOR.g, BOLT_WHITE_COLOR.b, fade), 1.0, true)
			for branch in branches:
				var branch_fork: PackedVector2Array = branch
				if branch_fork.size() >= 1:
					canvas.draw_circle(branch_fork[0] + shake_offset, 2.5, Color(FORK_GLOW_COLOR.r, FORK_GLOW_COLOR.g, FORK_GLOW_COLOR.b, FORK_GLOW_COLOR.a * fade))
	if explosion_left > 0.0:
		_draw_explosion(canvas, end + shake_offset, explosion_left, seed_value, runtime_elapsed, explosion_seconds)


func _draw_explosion(
	canvas: CanvasItem,
	center: Vector2,
	explosion_left: float,
	seed_value: float,
	runtime_elapsed: float,
	explosion_seconds: float
) -> void:
	var progress := clampf(1.0 - explosion_left / maxf(0.001, explosion_seconds), 0.0, 1.0)
	var life_ratio := 1.0 - progress
	if progress < 0.3:
		var flash_alpha := 1.0 - progress / 0.3
		canvas.draw_circle(center, 12.0 + progress * 30.0, Color(EXPL_FLASH_COLOR.r, EXPL_FLASH_COLOR.g, EXPL_FLASH_COLOR.b, 0.85 * flash_alpha))
	var core_radius := 6.0 + progress * 40.0
	canvas.draw_circle(center, core_radius * 0.6, Color(EXPL_CORE_COLOR.r, EXPL_CORE_COLOR.g, EXPL_CORE_COLOR.b, 0.78 * life_ratio))
	canvas.draw_circle(center, core_radius * 0.3, Color(EXPL_INNER_COLOR.r, EXPL_INNER_COLOR.g, EXPL_INNER_COLOR.b, 0.5 * life_ratio))
	for ring_index in range(3):
		var ring_delay := float(ring_index) * 0.1
		var ring_progress := (progress - ring_delay) / maxf(0.01, 1.0 - ring_delay)
		if ring_progress <= 0.0 or ring_progress > 1.0:
			continue
		var ring_radius := explosion_seconds * 60.0 * ring_progress * float(ring_index + 1) * 0.25
		var ring_alpha := (0.63 - float(ring_index) * 0.16) * (1.0 - ring_progress)
		if ring_alpha <= 0.0 or ring_radius <= 4.0:
			continue
		canvas.draw_arc(center, ring_radius, 0.0, TAU, 48, Color(EXPL_RING_COLOR.r, EXPL_RING_COLOR.g, EXPL_RING_COLOR.b, ring_alpha), maxf(1.0, 3.0 - float(ring_index)), true)
	if progress < 0.7:
		var arc_count := 5 + int(progress * 8.0)
		var flicker_frame := floorf(maxf(0.0, runtime_elapsed) * 30.0)
		for index in range(arc_count):
			var angle := (float(index) / float(arc_count)) * TAU + (_seeded_unit(seed_value + float(index), flicker_frame) - 0.5) * 0.4
			var inner_radius := 4.0 + progress * 15.0
			var outer_radius := inner_radius + lerpf(15.0, 35.0, _seeded_unit(seed_value + float(index) + 5.0, flicker_frame)) * (1.0 + progress)
			var direction := Vector2(cos(angle), sin(angle))
			var arc_start := center + direction * inner_radius
			var arc_end := center + direction * outer_radius
			var arc_mid := (arc_start + arc_end) * 0.5 + Vector2(
				(_seeded_unit(seed_value + float(index), flicker_frame + 3.0) - 0.5) * 12.0,
				(_seeded_unit(seed_value + float(index), flicker_frame + 7.0) - 0.5) * 12.0
			)
			var color: Color = EXPL_ARC_COLORS[index % EXPL_ARC_COLORS.size()]
			canvas.draw_polyline(PackedVector2Array([arc_start, arc_mid, arc_end]), Color(color.r, color.g, color.b, 0.9 * life_ratio), 1.0, true)


func _shift_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	if offset == Vector2.ZERO:
		return points
	var shifted := PackedVector2Array()
	shifted.resize(points.size())
	for index in range(points.size()):
		shifted[index] = points[index] + offset
	return shifted


func _draw_particles(
	canvas: CanvasItem,
	particles: Array[Dictionary],
	shake_offset: Vector2,
	spark_seconds: float
) -> void:
	for particle in particles:
		var max_life := maxf(0.01, float(particle.get("max_life", spark_seconds)))
		var life_ratio := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var alpha := minf(1.0, life_ratio * 2.0)
		var color: Color = particle.get("color", Color.WHITE)
		var pos: Vector2 = (particle.get("pos", Vector2.ZERO) as Vector2) + shake_offset
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		var size := maxf(1.0, float(particle.get("size", 2.0)) * alpha)
		var particle_type: String = particle.get("type", "dot")
		if particle_type == "streak":
			var tail := pos - vel * (0.8 / 60.0)
			canvas.draw_line(tail, pos, Color(color.r, color.g, color.b, alpha), maxf(1.0, size * 0.5), true)
			canvas.draw_circle(pos, maxf(1.0, size * 0.34), Color(1.0, 1.0, 1.0, alpha))
		elif particle_type == "flash":
			canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.7 * alpha))
			canvas.draw_circle(pos, maxf(1.0, size * 0.5), Color(1.0, 1.0, 1.0, 0.6 * alpha))
		else:
			canvas.draw_circle(pos, maxf(1.0, size * 0.5), Color(color.r, color.g, color.b, alpha))
			if size > 2.0:
				canvas.draw_circle(pos, maxf(1.0, size * 0.25), Color(1.0, 1.0, 1.0, alpha))


func _is_bolt_visible(runtime_elapsed: float, seed_value: float) -> bool:
	var flicker_frame := floorf(maxf(0.0, runtime_elapsed) * 60.0)
	return _seeded_unit(seed_value, flicker_frame + 17.0) < 0.85


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed := sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
