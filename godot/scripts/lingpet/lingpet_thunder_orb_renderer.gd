extends RefCounted

const ORB_INNER_COLOR := Color(0.78, 0.90, 1.0)
const ORB_RING_COLOR := Color(0.31, 0.63, 1.0)
const ARC_GLOW_COLOR := Color(0.24, 0.51, 1.0)
const ARC_CORE_COLOR := Color(0.78, 0.90, 1.0)
const TRAIL_COLOR := Color(0.39, 0.70, 1.0)
const OUTER_ARC_COLORS: Array[Color] = [
	Color(0.47, 0.71, 1.0),
	Color(0.31, 0.55, 1.0),
	Color(0.63, 0.78, 1.0),
	Color(1.0, 0.94, 0.47),
	Color(1.0, 0.86, 0.31),
]
const SPARK_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 1.0, 0.90),
	Color(0.78, 0.90, 1.0),
]
const RING_COLORS: Array[Color] = [
	Color(0.39, 0.70, 1.0),
	Color(0.59, 0.82, 1.0),
	Color(0.31, 0.63, 1.0),
	Color(0.71, 0.86, 1.0),
	Color(0.24, 0.55, 0.94),
]
const MINI_SPARK_BOLT_COUNT := 10
const MINI_SPARK_DOT_COUNT := 6
const CRACKLE_PROJECTION_FPS := 60.0


func draw_particles(canvas: CanvasItem, explosion_particles: Array, shake_offset: Vector2) -> void:
	for particle in explosion_particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_progress: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var position: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.7 + 0.3 * life_progress)
		var base: Color = particle.get("color", ORB_INNER_COLOR)
		var alpha: float = (0.72 if int(particle["kind"]) == 0 else 0.6) * life_progress
		canvas.draw_circle(position, size, Color(base.r, base.g, base.b, alpha))


func draw_explosion(
	canvas: CanvasItem,
	center: Vector2,
	explosion_timer: float,
	explosion_duration_seconds: float,
	explosion_radius: float,
	visual_seed: float
) -> void:
	var ratio := clampf(explosion_timer / explosion_duration_seconds, 0.0, 1.0)
	var progress := 1.0 - ratio
	var current_radius := explosion_radius * clampf(progress * 1.1, 0.0, 1.0)
	var flicker_frame := floorf(progress * 60.0)
	if progress < 0.4:
		var flash_progress := 1.0 - progress / 0.4
		canvas.draw_circle(center, current_radius * 0.9, Color(0.39, 0.70, 1.0, 0.31 * flash_progress))
		canvas.draw_circle(center, current_radius * 0.5, Color(1.0, 1.0, 1.0, 0.86 * flash_progress))
	for ring_index in range(5):
		var ring_delay := float(ring_index) * 0.07
		var ring_progress := progress - ring_delay
		if ring_progress <= 0.0:
			continue
		var ring_radius := explosion_radius * minf(1.0, ring_progress * 1.4)
		var ring_alpha := (0.86 - float(ring_index) * 0.12) * (1.0 - minf(1.0, ring_progress))
		if ring_radius <= 0.0 or ring_alpha <= 0.0:
			continue
		var ring_width := maxf(1.0, 4.0 - float(ring_index))
		var ring_color: Color = RING_COLORS[ring_index]
		if ring_width >= 2.0:
			canvas.draw_arc(
				center,
				ring_radius + 2.0,
				0.0,
				TAU,
				56,
				Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha / 3.0),
				ring_width + 2.0,
				true
			)
		canvas.draw_arc(center, ring_radius, 0.0, TAU, 56, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), ring_width, true)
	canvas.draw_circle(center, current_radius * 0.9, Color(0.08, 0.31, 0.71, 0.20 * ratio))
	canvas.draw_circle(center, current_radius * 0.5, Color(0.24, 0.55, 0.90, 0.35 * ratio))
	var arc_count := 12 + int(progress * 10.0)
	var web_points := PackedVector2Array()
	for arc_index in range(arc_count):
		var bolt_seed := visual_seed + float(arc_index) * 2.1 + flicker_frame
		var angle := (float(arc_index) / float(arc_count)) * TAU + (_seeded_unit(bolt_seed, 3.0) - 0.5) * 0.3
		var direction := Vector2(cos(angle), sin(angle))
		var start := center + direction * (current_radius * 0.1)
		var end := center + direction * (current_radius * lerpf(0.85, 1.15, _seeded_unit(bolt_seed, 7.0)))
		var points := _build_bolt(start, end, bolt_seed, 4, 14.0)
		web_points.append(end)
		var glow: Color = OUTER_ARC_COLORS[arc_index % OUTER_ARC_COLORS.size()]
		canvas.draw_polyline(points, Color(glow.r, glow.g, glow.b, 0.39 * ratio), 4.0, true)
		var middle_color: Color = SPARK_COLORS[arc_index % SPARK_COLORS.size()]
		canvas.draw_polyline(points, Color(middle_color.r, middle_color.g, middle_color.b, 0.80 * ratio), 2.0, true)
		canvas.draw_polyline(points, Color(1.0, 1.0, 1.0, 0.92 * ratio), 1.0, true)
	for point_index in range(web_points.size()):
		if _seeded_unit(visual_seed + float(point_index) * 1.7, flicker_frame + 51.0) < 0.7:
			var first_point := web_points[point_index]
			var second_point := web_points[(point_index + 1) % web_points.size()]
			var midpoint := (first_point + second_point) * 0.5 + Vector2(
				(_seeded_unit(visual_seed + float(point_index), flicker_frame + 5.0) - 0.5) * 16.0,
				(_seeded_unit(visual_seed + float(point_index), flicker_frame + 9.0) - 0.5) * 16.0
			)
			canvas.draw_polyline(
				PackedVector2Array([first_point, midpoint, second_point]),
				Color(0.86, 0.94, 1.0, 0.7 * ratio),
				1.4,
				true
			)
	var core_progress := ratio
	canvas.draw_circle(center, maxf(3.0, 18.0 * core_progress), Color(0.31, 0.63, 1.0, 0.5 * core_progress))
	canvas.draw_circle(center, maxf(2.0, 12.0 * core_progress), Color(0.78, 0.90, 1.0, 0.86 * core_progress))
	canvas.draw_circle(center, maxf(1.0, 6.0 * core_progress), Color(1.0, 1.0, 1.0, core_progress))


func draw_mini_spark_flashes(
	canvas: CanvasItem,
	mini_spark_flashes: Array,
	shake_offset: Vector2,
	mini_spark_flash_seconds: float,
	mini_spark_visual_radius: float
) -> void:
	for flash in mini_spark_flashes:
		var life_progress: float = clampf(float(flash["timer"]) / mini_spark_flash_seconds, 0.0, 1.0)
		var center: Vector2 = (flash["pos"] as Vector2) + shake_offset
		var seed_value: float = float(flash["seed"])
		var progress: float = 1.0 - life_progress
		var tick: float = floorf(progress * 13.0)
		for bolt_index in range(MINI_SPARK_BOLT_COUNT):
			if _seeded_unit(seed_value + float(bolt_index) * 7.3, tick + 5.0) > 0.66:
				continue
			var projection_seed: float = seed_value + float(bolt_index) * 3.1 + tick
			var anchor_angle: float = _seeded_unit(projection_seed, 1.0) * TAU
			var anchor_radius: float = mini_spark_visual_radius * (0.10 + 0.78 * _seeded_unit(projection_seed, 2.0))
			var bolt_start: Vector2 = center + Vector2(cos(anchor_angle), sin(anchor_angle)) * anchor_radius
			var jump_angle: float = _seeded_unit(projection_seed, 3.0) * TAU
			var jump_length: float = mini_spark_visual_radius * (0.16 + 0.36 * _seeded_unit(projection_seed, 4.0))
			var bolt_end: Vector2 = bolt_start + Vector2(cos(jump_angle), sin(jump_angle)) * jump_length
			var bolt_points := _build_bolt(bolt_start, bolt_end, projection_seed, 3, 8.0)
			var glow: Color = OUTER_ARC_COLORS[bolt_index % OUTER_ARC_COLORS.size()]
			canvas.draw_polyline(bolt_points, Color(glow.r, glow.g, glow.b, 0.40 * life_progress), 2.5, true)
			canvas.draw_polyline(bolt_points, Color(1.0, 1.0, 1.0, 0.88 * life_progress), 1.0, true)
		for dot_index in range(MINI_SPARK_DOT_COUNT):
			if _seeded_unit(seed_value + float(dot_index) * 5.7, tick + 11.0) > 0.5:
				continue
			var dot_angle := _seeded_unit(seed_value + float(dot_index) * 5.7, tick + 1.0) * TAU
			var dot_radius := mini_spark_visual_radius * _seeded_unit(seed_value + float(dot_index) * 5.7, tick + 2.0)
			var dot_position := center + Vector2(cos(dot_angle), sin(dot_angle)) * dot_radius
			var dot_size := 1.0 + _seeded_unit(seed_value + float(dot_index) * 5.7, tick + 3.0) * 1.4
			canvas.draw_circle(dot_position, dot_size, Color(1.0, 1.0, 0.9, 0.9 * life_progress))


func draw_orb(
	canvas: CanvasItem,
	position: Vector2,
	shake_offset: Vector2,
	elapsed: float,
	visual_seed: float,
	orb_rotation: float,
	orb_visual_radius: float,
	trail: Array[Vector2],
	energy_particles: Array
) -> void:
	for trail_index in range(trail.size()):
		var trail_position: Vector2 = trail[trail_index] + shake_offset
		var trail_progress: float = float(trail_index + 1) / float(maxi(1, trail.size()))
		canvas.draw_circle(
			trail_position,
			lerpf(4.0, 12.0, trail_progress),
			Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.06 + 0.20 * trail_progress)
		)
		if trail_index > 0:
			var previous_position: Vector2 = trail[trail_index - 1] + shake_offset
			canvas.draw_line(
				previous_position,
				trail_position,
				Color(0.62, 0.80, 1.0, 0.24 * trail_progress),
				maxf(1.0, 3.0 * trail_progress),
				true
			)
	for particle in energy_particles:
		var life_progress := clampf(float(particle["life"]) / maxf(0.01, float(particle["max_life"])), 0.0, 1.0)
		var mote_color: Color = particle["color"]
		canvas.draw_circle(
			(particle["pos"] as Vector2) + shake_offset,
			maxf(1.0, float(particle["size"]) * life_progress),
			Color(mote_color.r, mote_color.g, mote_color.b, 0.78 * life_progress)
		)
	var pulse := 1.0 + 0.10 * sin(elapsed * 5.0 + visual_seed * TAU)
	var orb_radius := orb_visual_radius * 0.40 * pulse
	canvas.draw_circle(position, orb_radius * 1.6, Color(ORB_INNER_COLOR.r, ORB_INNER_COLOR.g, ORB_INNER_COLOR.b, 0.20))
	canvas.draw_circle(position, orb_radius * 1.2, Color(ORB_INNER_COLOR.r, ORB_INNER_COLOR.g, ORB_INNER_COLOR.b, 0.31))
	canvas.draw_circle(position, orb_radius, Color(ORB_INNER_COLOR.r, ORB_INNER_COLOR.g, ORB_INNER_COLOR.b, 0.63))
	canvas.draw_circle(position, orb_radius * 0.75, Color(0.82, 0.92, 1.0, 0.75))
	canvas.draw_circle(position, orb_radius * 0.5, Color(0.86, 0.94, 1.0, 0.86))
	canvas.draw_circle(position, maxf(2.0, orb_radius * 0.35), Color(1.0, 1.0, 1.0, 0.94))
	canvas.draw_circle(position, maxf(1.0, orb_radius * 0.175), Color(1.0, 1.0, 1.0, 0.98))
	var hex_radius := orb_visual_radius * 1.15
	var hex_points := PackedVector2Array()
	for vertex_index in range(6):
		var vertex_angle := TAU * float(vertex_index) / 6.0 - PI * 0.5 + orb_rotation
		hex_points.append(position + Vector2(cos(vertex_angle), sin(vertex_angle)) * hex_radius)
	canvas.draw_arc(position, hex_radius * 0.92, 0.0, TAU, 40, Color(ORB_RING_COLOR.r, ORB_RING_COLOR.g, ORB_RING_COLOR.b, 0.5), 1.5, true)
	for arc_index in range(6):
		var arc_angle := TAU * float(arc_index) / 6.0 - PI * 0.5 + orb_rotation
		var arc_start := position + Vector2(cos(arc_angle), sin(arc_angle)) * (orb_radius * 0.9)
		var wobble := sin(elapsed * 8.0 + float(arc_index) * 1.1) * deg_to_rad(5.0)
		var middle_angle := arc_angle + deg_to_rad(10.0) + wobble
		var midpoint := position + Vector2(cos(middle_angle), sin(middle_angle)) * (hex_radius * 0.55)
		var arc_points := PackedVector2Array([arc_start, midpoint, hex_points[arc_index]])
		canvas.draw_polyline(arc_points, Color(ARC_GLOW_COLOR.r, ARC_GLOW_COLOR.g, ARC_GLOW_COLOR.b, 0.35), 3.0, true)
		canvas.draw_polyline(arc_points, Color(ARC_CORE_COLOR.r, ARC_CORE_COLOR.g, ARC_CORE_COLOR.b, 0.86), 1.0, true)
	for hex_point in hex_points:
		canvas.draw_circle(hex_point, 3.0, Color(0.70, 0.86, 1.0, 0.78))
		canvas.draw_circle(hex_point, 1.0, Color(1.0, 1.0, 1.0, 0.63))
	var outer_arc_count := 2 + int(floor(get_crackle_unit_for_tests(visual_seed, elapsed, 0, 0) * 3.0))
	for outer_index in range(outer_arc_count):
		var angle := get_crackle_unit_for_tests(visual_seed, elapsed, outer_index, 1) * TAU
		var start_radius := orb_visual_radius * lerpf(0.8, 1.3, get_crackle_unit_for_tests(visual_seed, elapsed, outer_index, 2))
		var start := position + Vector2(cos(angle), sin(angle)) * start_radius
		var end_angle := angle + lerpf(-0.6, 0.6, get_crackle_unit_for_tests(visual_seed, elapsed, outer_index, 3))
		var end_radius := start_radius + lerpf(5.0, 12.0, get_crackle_unit_for_tests(visual_seed, elapsed, outer_index, 4))
		var end := position + Vector2(cos(end_angle), sin(end_angle)) * end_radius
		var color_index := mini(
			OUTER_ARC_COLORS.size() - 1,
			int(floor(get_crackle_unit_for_tests(visual_seed, elapsed, outer_index, 5) * float(OUTER_ARC_COLORS.size())))
		)
		var arc_color: Color = OUTER_ARC_COLORS[color_index]
		canvas.draw_line(start, end, Color(arc_color.r, arc_color.g, arc_color.b, 0.85), 1.0, true)
	if get_crackle_unit_for_tests(visual_seed, elapsed, 97, 0) < 0.6:
		var spark_angle := get_crackle_unit_for_tests(visual_seed, elapsed, 97, 1) * TAU
		var spark_start_radius := orb_visual_radius * lerpf(0.6, 1.1, get_crackle_unit_for_tests(visual_seed, elapsed, 97, 2))
		var spark_start := position + Vector2(cos(spark_angle), sin(spark_angle)) * spark_start_radius
		var spark_end := position + Vector2(cos(spark_angle), sin(spark_angle)) * (
			spark_start_radius + lerpf(4.0, 10.0, get_crackle_unit_for_tests(visual_seed, elapsed, 97, 3))
		)
		var spark_color_index := mini(
			SPARK_COLORS.size() - 1,
			int(floor(get_crackle_unit_for_tests(visual_seed, elapsed, 97, 4) * float(SPARK_COLORS.size())))
		)
		canvas.draw_line(spark_start, spark_end, SPARK_COLORS[spark_color_index], 1.0, true)


func get_crackle_unit_for_tests(visual_seed: float, elapsed: float, projection_index: int, channel: int) -> float:
	var frame := float(int(floor(maxf(0.0, elapsed) * CRACKLE_PROJECTION_FPS)))
	return _seeded_unit(visual_seed + float(projection_index) * 3.17, frame + float(channel) * 11.31)


func _build_bolt(start: Vector2, end: Vector2, seed_value: float, segments: int, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta := end - start
	var normal := delta.orthogonal()
	if normal.length_squared() > 0.001:
		normal = normal.normalized()
	var segment_count: int = maxi(2, segments)
	for segment_index in range(segment_count + 1):
		var progress := float(segment_index) / float(segment_count)
		var taper := 1.0 - absf(progress * 2.0 - 1.0) * 0.25
		var jitter_offset := (_seeded_unit(seed_value, float(segment_index) + 1.0) - 0.5) * jitter * taper
		points.append(start.lerp(end, progress) + normal * jitter_offset)
	return points


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed := sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
