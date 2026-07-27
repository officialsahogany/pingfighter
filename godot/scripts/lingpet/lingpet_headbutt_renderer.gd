extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const MISS_TEXT := "MISS!"
const MISS_TEXT_FLOAT_Y := 34.0
const GROUND_SLAM_DEBRIS_COUNT := 25
const GROUND_SLAM_CRACK_COUNT := 6
const GROUND_SLAM_SPARK_COUNT := 20
const GROUND_SLAM_FLAME_TONGUES := 12
const GROUND_SLAM_FLAME_BODY_RADIUS := 38.0

# Stateless procedural renderer for the shared Lunabi/Onimaru Headbutt runtime.
# Gameplay clocks, positions, hit outcomes, and deterministic seed state stay in
# the skill owner and are passed as scalars or borrowed arrays without copying.


func draw_mega_charge(canvas: CanvasItem, center: Vector2, ratio: float, elapsed: float) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var intensity := clamped_ratio * clamped_ratio
	var pulse := 0.5 + 0.5 * sin(elapsed * 26.0)
	var swell := lerpf(60.0, 30.0, clamped_ratio)
	# Gathering field: a soft violet aura that contracts and brightens as it charges.
	canvas.draw_circle(center, swell + 12.0, Color(0.42, 0.16, 0.95, 0.05 + 0.12 * intensity))
	canvas.draw_circle(center, swell, Color(0.60, 0.28, 1.0, 0.08 + 0.18 * intensity))
	# Converging energy streams pulled inward from the gathering field.
	for i in range(18):
		var a := TAU * float(i) / 18.0 + clamped_ratio * 1.8
		var dir := Vector2(cos(a), sin(a))
		var far := lerpf(98.0, 30.0, clamped_ratio) + 7.0 * sin(elapsed * 9.0 + float(i))
		var near := lerpf(42.0, 12.0, clamped_ratio)
		var streak_alpha := (0.10 + 0.45 * intensity) * (0.6 + 0.4 * pulse)
		canvas.draw_line(center + dir * far, center + dir * near, Color(0.80, 0.46, 1.0, streak_alpha), 1.2 + 1.8 * intensity, true)
		canvas.draw_circle(center + dir * near, 1.4 + 2.6 * intensity, Color(1.0, 0.9, 0.72, 0.4 + 0.5 * intensity))
	# Counter-rotating dashed energy rings.
	_draw_charge_ring(canvas, center, lerpf(56.0, 26.0, clamped_ratio), clamped_ratio * 5.0, 10, Color(0.92, 0.62, 1.0, 0.28 + 0.45 * intensity), 2.0 + 1.6 * intensity)
	_draw_charge_ring(canvas, center, lerpf(42.0, 18.0, clamped_ratio), -clamped_ratio * 7.0, 8, Color(0.70, 0.40, 1.0, 0.24 + 0.42 * intensity), 1.6 + 1.4 * intensity)
	# Crackling electric bolts radiating from the core (more of them as it charges).
	var bolt_count := 3 + int(round(3.0 * intensity))
	for i in range(bolt_count):
		_draw_charge_bolt(canvas, center, i, clamped_ratio, elapsed, intensity, pulse)
	# Pulsing white-hot core.
	var core := lerpf(5.0, 15.0, clamped_ratio) * (0.85 + 0.22 * pulse)
	canvas.draw_circle(center, core + 7.0, Color(0.85, 0.55, 1.0, 0.18 + 0.34 * intensity))
	canvas.draw_circle(center, core, Color(1.0, 0.93, 0.78, 0.55 + 0.4 * intensity))
	canvas.draw_circle(center, core * 0.5, Color(1.0, 1.0, 0.96, 0.7 + 0.3 * pulse))
	# Final-quarter shock ring telegraphs the imminent release.
	if clamped_ratio > 0.75:
		var burst := (clamped_ratio - 0.75) / 0.25
		canvas.draw_arc(center, lerpf(14.0, 72.0, burst), 0.0, TAU, 40, Color(1.0, 0.95, 0.8, 0.7 * (1.0 - burst)), 3.0 * (1.0 - burst) + 1.0, true)
	# Rising embers around the gather.
	for i in range(6):
		var t := fmod(elapsed * 0.7 + float(i) * 0.37, 1.0)
		var ex := center.x + sin(float(i) * 2.1 + elapsed * 3.0) * lerpf(8.0, 22.0, t)
		var ey := center.y + 18.0 - t * 46.0
		canvas.draw_circle(Vector2(ex, ey), 1.4 + 2.0 * (1.0 - t), Color(0.95, 0.72, 1.0, (1.0 - t) * (0.3 + 0.4 * intensity)))


func draw_dash(
	canvas: CanvasItem,
	shake_offset: Vector2,
	ground_slam: bool,
	trail: Array[Vector2],
	pos: Vector2,
	dash_radius: float,
	dash_dir: Vector2,
	dash_elapsed: float
) -> void:
	if ground_slam:
		# Onimaru charges the boss wrapped in fire. Lunabi keeps its violet magic dash below.
		_draw_dash_flames(canvas, shake_offset, trail, pos, dash_dir, dash_elapsed)
		return
	for i in range(trail.size()):
		var ratio := float(i + 1) / float(maxi(1, trail.size()))
		var trail_pos := trail[i] + shake_offset
		var alpha := 0.08 + 0.30 * ratio
		canvas.draw_circle(trail_pos, lerpf(3.0, 10.0, ratio), Color(0.84, 0.34, 1.0, alpha))
		if i > 0:
			var prev_pos := trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.55, 0.95, 1.0, 0.26 * ratio), maxf(1.0, 4.0 * ratio), true)
	var center := pos + shake_offset
	canvas.draw_circle(center, dash_radius + 9.0, Color(0.72, 0.25, 1.0, 0.12))
	canvas.draw_arc(center, dash_radius + 5.0, 0.0, TAU, 30, Color(0.92, 0.62, 1.0, 0.42), 1.8, true)


func draw_hit_impact(
	canvas: CanvasItem,
	pos: Vector2,
	stable_impact_pos: Vector2,
	ratio: float,
	ground_slam: bool,
	mega_impact: bool,
	slam_radius: float,
	target: Vector2,
	outcome_seed: int
) -> void:
	if ground_slam:
		# Cracks first so the dust rings + debris kick up OVER the split floor.
		_draw_ground_cracks(canvas, pos, ratio, slam_radius, stable_impact_pos, target, outcome_seed)
		_draw_ground_slam(canvas, pos, ratio, slam_radius, stable_impact_pos, target, outcome_seed)
	_draw_impact(canvas, pos, ratio, true)
	if mega_impact:
		_draw_mega_impact(canvas, pos, ratio)
	if ground_slam:
		# Hot sparks remain above the generic impact and mega overlays.
		_draw_ground_slam_sparks(canvas, pos, ratio, slam_radius, stable_impact_pos, target, outcome_seed)


func draw_miss_impact(canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
	_draw_impact(canvas, pos, ratio, false)


func draw_miss_text(canvas: CanvasItem, draw_origin: Vector2, progress: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var alpha := maxf(0.0, 1.0 - clamped_progress)
	var draw_pos := draw_origin + Vector2(0.0, -clamped_progress * MISS_TEXT_FLOAT_Y)
	draw_pos.x = clampf(draw_pos.x, 60.0, FIELD_WIDTH - 60.0)
	draw_pos.y = clampf(draw_pos.y, 60.0, FIELD_HEIGHT - 48.0)
	var font_size := int(round(24.0 + sin(clamped_progress * PI) * 3.0))
	canvas.draw_string(font, draw_pos + Vector2(-44.0, 2.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, Color(0.04, 0.02, 0.08, 0.78 * alpha))
	canvas.draw_string(font, draw_pos + Vector2(-46.0, 0.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, Color(0.86, 0.36, 1.0, 0.95 * alpha))


func draw_self_stun(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	# Stun stars orbit above the recoiling companion while it is incapacitated.
	var spin := elapsed * 6.0
	var head := center + Vector2(0.0, -34.0)
	var star_count := 3
	for i in range(star_count):
		var angle := spin + TAU * float(i) / float(star_count)
		var star_pos := head + Vector2(cos(angle) * 18.0, sin(angle) * 6.0)
		_draw_stun_star(canvas, star_pos, 5.0 + 1.4 * sin(spin * 2.0 + float(i)))


func _draw_dash_flames(
	canvas: CanvasItem,
	shake_offset: Vector2,
	trail: Array[Vector2],
	pos: Vector2,
	dash_dir: Vector2,
	dash_elapsed: float
) -> void:
	# Fire wraps the visible Onimaru body and uses the runtime-owned dash clock.
	var clock := dash_elapsed
	for i in range(trail.size()):
		var ratio := float(i + 1) / float(maxi(1, trail.size()))
		var trail_pos := trail[i] + shake_offset
		var puff := lerpf(2.0, 9.0, ratio)
		canvas.draw_circle(trail_pos, puff, Color(1.0, 0.40, 0.10, 0.05 + 0.20 * ratio))
		canvas.draw_circle(trail_pos, puff * 0.5, Color(1.0, 0.80, 0.34, 0.08 + 0.26 * ratio))
	var center := pos + shake_offset
	canvas.draw_circle(center, GROUND_SLAM_FLAME_BODY_RADIUS + 15.0, Color(1.0, 0.34, 0.08, 0.10))
	canvas.draw_circle(center, GROUND_SLAM_FLAME_BODY_RADIUS + 7.0, Color(1.0, 0.50, 0.16, 0.15))
	var back := -dash_dir
	if back.length_squared() < 0.01:
		back = Vector2(0.0, 1.0)
	for i in range(GROUND_SLAM_FLAME_TONGUES):
		var base_angle := TAU * float(i) / float(GROUND_SLAM_FLAME_TONGUES)
		var out := Vector2(cos(base_angle), sin(base_angle))
		var dir := (out + back * 0.55).normalized()
		var flick := 0.55 + 0.45 * sin(clock * 45.0 + float(i) * 1.7)
		var inner := GROUND_SLAM_FLAME_BODY_RADIUS * 0.55
		var reach := GROUND_SLAM_FLAME_BODY_RADIUS + 4.0 + flick * 16.0
		_draw_flame_tongue(canvas, center, dir, inner, reach, i, clock)


func _draw_flame_tongue(
	canvas: CanvasItem,
	center: Vector2,
	dir: Vector2,
	inner: float,
	reach: float,
	seed_index: int,
	clock: float
) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var steps := 3
	for step_index in range(steps + 1):
		var fraction := float(step_index) / float(steps)
		var distance := lerpf(inner, reach, fraction)
		var wobble := sin(clock * 30.0 + float(seed_index) * 2.1 + fraction * 3.4) * 2.4 * fraction
		var point := center + dir * distance + perp * wobble
		var size := lerpf(4.8, 1.0, fraction)
		var color := Color(1.0, lerpf(0.34, 0.95, fraction), lerpf(0.06, 0.55, fraction), lerpf(0.72, 0.18, fraction))
		canvas.draw_circle(point, maxf(0.6, size), color)


func _draw_impact(canvas: CanvasItem, pos: Vector2, ratio: float, hit: bool) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var color := Color(0.58, 0.95, 1.0, 1.0) if hit else Color(0.75, 0.68, 0.90, 1.0)
	var radius := lerpf(18.0, 58.0, expansion)
	canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.18 * clamped))
	canvas.draw_arc(pos, radius * 0.82, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.62 * clamped), 2.4)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + expansion * 0.55
		var start := pos + Vector2(cos(angle), sin(angle)) * radius * 0.26
		var end := pos + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(start, end, Color(1.0, 1.0, 1.0, 0.42 * clamped), 1.5, true)


func _draw_charge_ring(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	rotation_offset: float,
	segments: int,
	color: Color,
	width: float
) -> void:
	var step := TAU / float(maxi(1, segments))
	for i in range(segments):
		var a0 := step * float(i) + rotation_offset
		canvas.draw_arc(center, radius, a0, a0 + step * 0.55, 6, color, width, true)


func _draw_charge_bolt(
	canvas: CanvasItem,
	center: Vector2,
	seed_index: int,
	ratio: float,
	elapsed: float,
	intensity: float,
	pulse: float
) -> void:
	var base_angle := TAU * float(seed_index) / 6.0 + ratio * 3.3 + _bolt_hash(seed_index, elapsed) * 1.4
	var length := lerpf(22.0, 52.0, intensity)
	var forward := Vector2(cos(base_angle), sin(base_angle))
	var perpendicular := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array()
	points.append(center)
	for segment_index in range(1, 6):
		var fraction := float(segment_index) / 5.0
		var jitter := (_bolt_hash(seed_index * 17 + segment_index, elapsed + float(segment_index) * 0.13) - 0.5) * 18.0 * (1.0 - fraction * 0.4)
		points.append(center + forward * (length * fraction) + perpendicular * jitter)
	canvas.draw_polyline(points, Color(0.96, 0.82, 1.0, (0.22 + 0.5 * intensity) * (0.5 + 0.5 * pulse)), 1.6, true)


func _bolt_hash(index: int, time_seconds: float) -> float:
	var value := sin(float(index) * 12.9898 + floor(time_seconds * 38.0) * 78.233) * 43758.5453
	return value - floor(value)


func _draw_ground_cracks(
	canvas: CanvasItem,
	pos: Vector2,
	ratio: float,
	slam_radius: float,
	stable_impact_pos: Vector2,
	target: Vector2,
	outcome_seed: int
) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var grow := clampf(expansion / 0.28, 0.0, 1.0)
	var reach := slam_radius * 1.15 * grow
	if reach <= 6.0:
		return
	var fade := clampf(clamped * 1.5, 0.0, 1.0)
	canvas.draw_circle(pos, reach * 0.42, Color(0.05, 0.02, 0.02, 0.16 * fade))
	for i in range(GROUND_SLAM_CRACK_COUNT):
		var angle_seed := _deterministic_unit(stable_impact_pos + Vector2(float(i) * 7.3, 5.0), target, float(i + 3), outcome_seed)
		var base_angle := TAU * float(i) / float(GROUND_SLAM_CRACK_COUNT) + (angle_seed - 0.5) * 0.7
		var length_seed := 0.68 + _deterministic_unit(stable_impact_pos + Vector2(2.0, float(i) * 9.1), target, float(i + 11), outcome_seed) * 0.5
		_draw_single_crack(canvas, pos, base_angle, reach * length_seed, i, fade, 0, stable_impact_pos, target, outcome_seed)


func _draw_single_crack(
	canvas: CanvasItem,
	origin: Vector2,
	angle: float,
	length: float,
	seed_index: int,
	fade: float,
	depth: int,
	stable_impact_pos: Vector2,
	target: Vector2,
	outcome_seed: int
) -> void:
	if length <= 4.0:
		return
	var forward := Vector2(cos(angle), sin(angle))
	var perpendicular := Vector2(-forward.y, forward.x)
	var segment_count := 5
	var points := PackedVector2Array()
	points.append(origin)
	for segment_index in range(1, segment_count + 1):
		var fraction := float(segment_index) / float(segment_count)
		var wander := _deterministic_unit(stable_impact_pos + Vector2(float(seed_index) * 5.0, float(segment_index) * 12.0), target, float(seed_index * 13 + segment_index), outcome_seed) - 0.5
		var jitter := wander * length * 0.16 * (1.0 - fraction * 0.35)
		points.append(origin + forward * (length * fraction) + perpendicular * jitter)
	var body_base := 5.4 - float(depth) * 1.9
	for segment_index in range(points.size() - 1):
		var fraction := float(segment_index) / float(points.size() - 1)
		var width := lerpf(maxf(1.2, body_base), 0.9, fraction)
		canvas.draw_line(points[segment_index], points[segment_index + 1], Color(0.05, 0.02, 0.02, 0.9 * fade), width, true)
	var glow_base := 2.6 - float(depth) * 0.9
	for segment_index in range(points.size() - 1):
		var fraction := float(segment_index) / float(points.size() - 1)
		var width := lerpf(maxf(0.6, glow_base), 0.5, fraction)
		var green := 0.30 + 0.35 * (1.0 - fraction)
		canvas.draw_line(points[segment_index], points[segment_index + 1], Color(1.0, green, 0.12, 0.65 * fade * (1.0 - fraction * 0.5)), width, true)
	if depth == 0 and points.size() >= 4:
		var branch_seed := _deterministic_unit(stable_impact_pos + Vector2(float(seed_index) * 3.0, 21.0), target, float(seed_index + 29), outcome_seed)
		var branch_direction := 1.0 if branch_seed > 0.5 else -1.0
		var branch_angle := angle + branch_direction * lerpf(0.55, 1.0, branch_seed)
		_draw_single_crack(canvas, points[2], branch_angle, length * 0.44, seed_index * 7 + 5, fade * 0.8, 1, stable_impact_pos, target, outcome_seed)


func _draw_ground_slam(
	canvas: CanvasItem,
	pos: Vector2,
	ratio: float,
	slam_radius: float,
	stable_impact_pos: Vector2,
	target: Vector2,
	outcome_seed: int
) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	for i in range(3):
		var ring_delay := float(i) * 0.10
		var ring_progress := clampf((expansion - ring_delay) / maxf(0.001, 1.0 - ring_delay), 0.0, 1.0)
		if ring_progress <= 0.0:
			continue
		var radius := lerpf(10.0, slam_radius, ring_progress)
		var ring_alpha := (1.0 - ring_progress) * (0.78 - float(i) * 0.12)
		var ring_width := 8.0
		if i == 1:
			ring_width = 5.0
		elif i == 2:
			ring_width = 3.0
		canvas.draw_arc(pos, radius, 0.0, TAU, 40, Color(1.0, 0.32 + ring_progress * 0.22, 0.12, ring_alpha), ring_width, true)
	canvas.draw_circle(pos, lerpf(38.0, 10.0, expansion), Color(1.0, 0.55, 0.20, 0.55 * clamped))
	for i in range(GROUND_SLAM_DEBRIS_COUNT):
		var jitter := _deterministic_unit(stable_impact_pos + Vector2(float(i) * 13.0, 0.0), target, float(i + 1), outcome_seed) * 0.5
		var angle := TAU * float(i) / float(GROUND_SLAM_DEBRIS_COUNT) + jitter
		var direction := Vector2(cos(angle), sin(angle))
		var speed_seed := 0.65 + _deterministic_unit(stable_impact_pos, target + Vector2(float(i), 17.0), float(i + 5), outcome_seed) * 0.55
		var distance := lerpf(8.0, (slam_radius - 2.0) * speed_seed, expansion)
		var gravity := expansion * expansion * 48.0
		var debris_pos := pos + direction * distance + Vector2(0.0, gravity)
		var debris_size := lerpf(6.0, 1.2, expansion) * (0.7 + speed_seed * 0.45)
		canvas.draw_circle(debris_pos, maxf(0.7, debris_size), Color(1.0, 0.47, 0.20, (1.0 - expansion) * 0.9))


func _draw_ground_slam_sparks(
	canvas: CanvasItem,
	pos: Vector2,
	ratio: float,
	slam_radius: float,
	stable_impact_pos: Vector2,
	target: Vector2,
	outcome_seed: int
) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	if expansion <= 0.0:
		return
	var life := clamped
	for i in range(GROUND_SLAM_SPARK_COUNT):
		var angle_seed := _deterministic_unit(stable_impact_pos + Vector2(float(i) * 4.7, 11.0), target, float(i + 5), outcome_seed)
		var speed_seed := _deterministic_unit(stable_impact_pos + Vector2(3.0, float(i) * 6.3), target, float(i + 17), outcome_seed)
		var angle := -PI * 0.5 + (angle_seed - 0.5) * (TAU * 0.72)
		var direction := Vector2(cos(angle), sin(angle))
		var reach := lerpf(6.0, (slam_radius + 40.0) * lerpf(0.55, 1.0, speed_seed), expansion)
		var gravity := expansion * expansion * lerpf(26.0, 72.0, speed_seed)
		var head := pos + direction * reach + Vector2(0.0, gravity)
		var tail := pos + direction * (reach * 0.72) + Vector2(0.0, gravity * 0.58)
		var flicker := 0.58 + 0.42 * sin(expansion * 40.0 + float(i) * 2.3)
		var alpha := life * flicker
		canvas.draw_line(tail, head, Color(1.0, 0.60, 0.20, 0.55 * alpha), lerpf(2.4, 0.8, expansion), true)
		var head_size := lerpf(2.9, 0.7, expansion) * (0.7 + speed_seed * 0.6)
		canvas.draw_circle(head, maxf(0.6, head_size), Color(1.0, 0.90, 0.55, 0.9 * alpha))
		canvas.draw_circle(head, maxf(0.3, head_size * 0.5), Color(1.0, 1.0, 0.92, alpha))


func _draw_stun_star(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(5):
		var outer := center + Vector2(cos(TAU * float(i) / 5.0 - PI * 0.5), sin(TAU * float(i) / 5.0 - PI * 0.5)) * radius
		var inner_angle := TAU * (float(i) + 0.5) / 5.0 - PI * 0.5
		var inner := center + Vector2(cos(inner_angle), sin(inner_angle)) * (radius * 0.45)
		points.append(outer)
		points.append(inner)
	canvas.draw_colored_polygon(points, Color(1.0, 0.92, 0.4, 0.92))


func _draw_mega_impact(canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var radius := lerpf(30.0, 104.0, expansion)
	canvas.draw_circle(pos, radius, Color(1.0, 0.52, 0.16, 0.22 * clamped))
	canvas.draw_circle(pos, radius * 0.6, Color(1.0, 0.86, 0.42, 0.30 * clamped))
	canvas.draw_arc(pos, radius * 0.9, 0.0, TAU, 40, Color(1.0, 0.78, 0.36, 0.72 * clamped), 3.4, true)
	for i in range(14):
		var angle := TAU * float(i) / 14.0 + expansion * 0.7
		var start := pos + Vector2(cos(angle), sin(angle)) * radius * 0.22
		var end := pos + Vector2(cos(angle), sin(angle)) * radius * (1.0 + 0.18 * sin(float(i) * 1.7))
		canvas.draw_line(start, end, Color(1.0, 0.95, 0.7, 0.5 * clamped), 2.2, true)


func _deterministic_unit(origin: Vector2, boss_pos: Vector2, moving_speed: float, outcome_seed: int) -> float:
	var hash_seed := origin.x * 12.9898 + origin.y * 4.1414 + boss_pos.x * 78.233 + moving_speed * 37.719 + float(outcome_seed) * 11.13
	var value := sin(hash_seed) * 43758.5453
	return value - floor(value)
