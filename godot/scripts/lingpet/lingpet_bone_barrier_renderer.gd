extends RefCounted

# Warm ivory bone palette ported 1:1 from the original Necro BoneBarrier.
# Green is reserved for spike poison wisps and the shatter shockwave.
const BONE_COLOR := Color(0.824, 0.784, 0.686, 1.0)
const BONE_DARK := Color(0.627, 0.588, 0.471, 1.0)
const BONE_HILITE := Color(0.902, 0.882, 0.784, 1.0)
const BONE_SHADOW := Color(0.471, 0.431, 0.333, 1.0)
const BONE_CREAM := Color(0.922, 0.894, 0.824, 1.0)
const SPIKE_COLOR := Color(0.784, 0.745, 0.627, 1.0)
const SPIKE_HILITE := Color(0.882, 0.855, 0.765, 1.0)
const SOUL_COLOR := Color(0.314, 1.0, 0.471, 1.0)
const CRACK_COLOR := Color(0.471, 0.431, 0.333, 1.0)


func prewarm() -> void:
	pass


func draw_bone_barrier(
	canvas: CanvasItem,
	shake_offset: Vector2,
	build_time: float,
	death_duration: float,
	barriers: Array[Dictionary],
	dying_barriers: Array[Dictionary],
	particles: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, particles, shake_offset)
	for dying in dying_barriers:
		_draw_dying_barrier(canvas, dying, shake_offset, death_duration)
	for barrier in barriers:
		_draw_barrier(canvas, barrier, shake_offset, build_time)


static func get_build_segment_adjusted_progress(build_timer: float, delay: float, build_time: float) -> float:
	var safe_build_time := maxf(0.001, build_time)
	var build_progress := clampf(build_timer / safe_build_time, 0.0, 1.0)
	var delay_norm := clampf(delay / safe_build_time, 0.0, 0.99)
	return clampf((build_progress - delay_norm) / maxf(0.01, 1.0 - delay_norm), 0.0, 1.0)


func _draw_barrier(canvas: CanvasItem, barrier: Dictionary, shake_offset: Vector2, build_time: float) -> void:
	var rect := _get_barrier_rect(barrier)
	rect.position += shake_offset
	var progress := clampf(float(barrier.get("timer", 0.0)) / maxf(0.001, build_time), 0.0, 1.0)
	if bool(barrier.get("built", false)):
		_draw_built_barrier(canvas, barrier, rect, progress)
	else:
		_draw_building_barrier(canvas, barrier, shake_offset, progress, build_time)


func _draw_building_barrier(
	canvas: CanvasItem,
	barrier: Dictionary,
	shake_offset: Vector2,
	_progress: float,
	build_time: float
) -> void:
	var segments: Array = barrier.get("bone_segments", []) as Array
	var build_timer := float(barrier.get("timer", 0.0))
	for segment in segments:
		var delay := float(segment.get("delay", 0.0))
		var adjusted := get_build_segment_adjusted_progress(build_timer, delay, build_time)
		if adjusted <= 0.001:
			continue
		var eased := 1.0 - pow(1.0 - adjusted, 3.0)
		var start_pos := _get_dict_vector2(segment, "start_pos", Vector2.ZERO)
		var final_pos := _get_dict_vector2(segment, "final_pos", Vector2.ZERO)
		var pos := start_pos.lerp(final_pos, eased) + shake_offset
		var rotation := lerpf(float(segment.get("rotation_start", 0.0)), float(segment.get("rotation_end", 0.0)), eased)
		var alpha := clampf(adjusted * 2.5, 0.0, 1.0)
		_draw_bone_segment(canvas, pos, float(segment.get("length", 10.0)), rotation, Color(BONE_COLOR.r, BONE_COLOR.g, BONE_COLOR.b, alpha))


func _draw_built_barrier(canvas: CanvasItem, barrier: Dictionary, rect: Rect2, _progress: float) -> void:
	# The barrier build timer remains the animation clock after construction, so
	# pulses freeze with the skill tick instead of free-running on wall time.
	var runtime_time := float(barrier.get("timer", 0.0))
	var phase := float(barrier.get("phase", 0.0))
	var is_top := bool(barrier.get("caster_is_top", false))
	var width := rect.size.x
	var height := rect.size.y
	var center_y := rect.position.y + height * 0.5
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), BONE_SHADOW, true)
	canvas.draw_rect(rect, BONE_DARK, true)
	canvas.draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 2.0)), BONE_COLOR, true)
	var inner_height := maxf(1.0, height - 4.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(3.0, (height - inner_height) * 0.5), Vector2(maxf(1.0, width - 6.0), inner_height)), BONE_CREAM, true)
	var segment_count := maxi(1, int(width / 10.0))
	for index in range(segment_count):
		var line_x := rect.position.x + width * 0.5
		if segment_count > 1:
			line_x = rect.position.x + 5.0 + float(index) * (width - 10.0) / float(segment_count - 1)
		canvas.draw_line(Vector2(line_x, rect.position.y + 1.0), Vector2(line_x, rect.end.y - 1.0), BONE_DARK, 1.0)
		canvas.draw_circle(Vector2(line_x, center_y), 3.0, BONE_HILITE)
		canvas.draw_arc(Vector2(line_x, center_y), 3.0, 0.0, TAU, 12, BONE_COLOR, 1.0, true)
		canvas.draw_circle(Vector2(line_x, center_y), 1.0, BONE_DARK)
		if index < segment_count - 1:
			var next_x := rect.position.x + 5.0 + float(index + 1) * (width - 10.0) / float(maxi(1, segment_count - 1))
			var marrow_alpha := 0.16 * (0.8 + 0.2 * sin(runtime_time * 2.0 + float(index) * 0.8))
			canvas.draw_line(Vector2(line_x + 3.0, center_y), Vector2(next_x - 3.0, center_y), Color(BONE_CREAM.r, BONE_CREAM.g, BONE_CREAM.b, marrow_alpha), 1.0)
		if index % 3 == 1:
			var crack_y := rect.position.y + 2.0
			canvas.draw_line(Vector2(line_x + 2.0, crack_y), Vector2(line_x + 4.0, crack_y + 3.0), CRACK_COLOR, 1.0)
	var spike_heights: Array = barrier.get("spike_heights", []) as Array
	var spike_count := spike_heights.size() if not spike_heights.is_empty() else maxi(1, int(width / 14.0))
	var direction := 1.0 if is_top else -1.0
	var base_y := rect.end.y if is_top else rect.position.y
	for index in range(spike_count):
		var spike_x := rect.position.x + (float(index) + 0.5) * width / float(spike_count)
		var spike_height := float(spike_heights[index]) if index < spike_heights.size() else 7.0
		var wobble := sin(runtime_time * 4.0 + float(index) * 1.5)
		var tip_y := base_y + direction * (spike_height + wobble)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(spike_x - 3.0, base_y + direction), Vector2(spike_x + 1.0, tip_y + direction), Vector2(spike_x + 4.0, base_y + direction),
		]), BONE_SHADOW)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(spike_x - 3.0, base_y), Vector2(spike_x, tip_y), Vector2(spike_x + 3.0, base_y),
		]), SPIKE_COLOR)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(spike_x - 2.0, base_y), Vector2(spike_x, tip_y), Vector2(spike_x, base_y),
		]), SPIKE_HILITE)
		canvas.draw_line(Vector2(spike_x, base_y), Vector2(spike_x, tip_y), BONE_DARK, 1.0)
		var poison := sin(runtime_time * 5.0 + float(index) * 2.3 + phase)
		if poison > 0.6:
			var poison_alpha := (poison - 0.6) / 0.4 * 0.55
			canvas.draw_circle(Vector2(spike_x, tip_y + direction * 2.0), 1.4, Color(SOUL_COLOR.r, SOUL_COLOR.g, SOUL_COLOR.b, poison_alpha))
	canvas.draw_line(Vector2(rect.position.x + 3.0, rect.position.y + 1.0), Vector2(rect.end.x - 3.0, rect.position.y + 1.0), BONE_HILITE, 1.0)
	canvas.draw_line(Vector2(rect.position.x + 3.0, rect.end.y - 1.0), Vector2(rect.end.x - 3.0, rect.end.y - 1.0), BONE_SHADOW, 1.0)


func _draw_dying_barrier(canvas: CanvasItem, dying: Dictionary, shake_offset: Vector2, death_duration: float) -> void:
	var timer := float(dying.get("timer", 0.0))
	var ratio := clampf(timer / maxf(0.001, death_duration), 0.0, 1.0)
	var impact_pos := _get_dict_vector2(dying, "impact_pos", Vector2.ZERO) + shake_offset
	canvas.draw_arc(impact_pos, 8.0 + 42.0 * ratio, 0.0, TAU, 36, Color(SOUL_COLOR.r, SOUL_COLOR.g, SOUL_COLOR.b, 0.52 * (1.0 - ratio)), 2.0, true)
	var fragments: Array = dying.get("fragments", []) as Array
	for fragment in fragments:
		var pos := _get_dict_vector2(fragment, "pos", Vector2.ZERO) + shake_offset
		var alpha := clampf(1.0 - ratio, 0.0, 1.0)
		_draw_bone_segment(canvas, pos, float(fragment.get("length", 9.0)), float(fragment.get("rotation", 0.0)), Color(BONE_COLOR.r, BONE_COLOR.g, BONE_COLOR.b, alpha))


func _draw_particles(canvas: CanvasItem, particles: Array[Dictionary], shake_offset: Vector2) -> void:
	for particle in particles:
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 1.0)))
		var ratio := clampf(age / life, 0.0, 1.0)
		var color: Color = particle.get("color", SOUL_COLOR) as Color
		color.a *= 1.0 - ratio
		canvas.draw_circle(_get_dict_vector2(particle, "pos", Vector2.ZERO) + shake_offset, float(particle.get("size", 2.0)) * (1.0 + ratio * 0.4), color)


func _draw_bone_segment(canvas: CanvasItem, pos: Vector2, length: float, rotation: float, color: Color) -> void:
	var axis := Vector2(cos(rotation), sin(rotation))
	var half := length * 0.5
	var start := pos - axis * half
	var end := pos + axis * half
	var alpha := color.a
	canvas.draw_line(start + Vector2(1.0, 1.0), end + Vector2(1.0, 1.0), Color(BONE_SHADOW.r, BONE_SHADOW.g, BONE_SHADOW.b, alpha * 0.4), 3.0, true)
	canvas.draw_line(start, end, color, 2.5, true)
	var middle := (start + end) * 0.5
	canvas.draw_line(start, middle, Color(BONE_HILITE.r, BONE_HILITE.g, BONE_HILITE.b, alpha * 0.6), 1.5, true)
	canvas.draw_circle(start, 2.0, Color(BONE_HILITE.r, BONE_HILITE.g, BONE_HILITE.b, alpha))
	canvas.draw_circle(end, 2.0, Color(BONE_DARK.r, BONE_DARK.g, BONE_DARK.b, alpha))


func _get_barrier_rect(barrier: Dictionary) -> Rect2:
	var position := _get_dict_vector2(barrier, "pos", Vector2.ZERO)
	return Rect2(position, Vector2(maxf(1.0, float(barrier.get("width", 72.0))), maxf(1.0, float(barrier.get("height", 12.0)))))


func _get_dict_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector2 else fallback
