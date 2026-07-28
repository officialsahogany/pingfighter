extends RefCounted

const DEFAULT_SOURCE_SIZE := Vector2(250.0, 650.0)
const DEFAULT_GAUGE_CENTER := Vector2(141.0, 564.0)


func draw(
	canvas: CanvasItem,
	center: Vector2,
	orb_radius: float,
	icon_radius: float,
	positions: Array[Vector2],
	scale_factor: float,
	context: Dictionary
) -> void:
	var cluster_frame_texture = context.get("cluster_frame_texture", null)
	var cluster_frame_slots: int = int(context.get("cluster_frame_slots", positions.size()))
	if cluster_frame_texture is Texture2D and cluster_frame_slots == positions.size():
		var frame_size: Vector2 = _as_vector2(context.get("cluster_source_size", DEFAULT_SOURCE_SIZE), DEFAULT_SOURCE_SIZE) * scale_factor
		var gauge_center: Vector2 = _as_vector2(context.get("cluster_gauge_center", DEFAULT_GAUGE_CENTER), DEFAULT_GAUGE_CENTER)
		var frame_pos: Vector2 = center - gauge_center * scale_factor
		var cluster_texture: Texture2D = cluster_frame_texture
		canvas.draw_texture_rect(cluster_texture, Rect2(frame_pos, frame_size), false)
		return

	var frame_safe_pad: float = float(context.get("frame_safe_pad", 8.0))
	var frame_size_f: float = max(1.0, (icon_radius + frame_safe_pad * scale_factor) * 2.0)
	var frame_radius: float = frame_size_f * 0.5
	var connector_width: float = max(4.0, round(icon_radius * 0.30))
	for i in range(positions.size() - 1):
		_draw_cluster_connector(canvas, positions[i], positions[i + 1], connector_width)
	for slot_pos in positions:
		var dir: Vector2 = (center - slot_pos).normalized()
		var slot_edge: Vector2 = slot_pos + dir * (frame_radius * 0.55)
		var gauge_edge: Vector2 = center - dir * (orb_radius + 18.0 * scale_factor)
		_draw_cluster_connector(canvas, slot_edge, gauge_edge, max(3.0, connector_width - 1.0))
		canvas.draw_circle(slot_pos + Vector2(2.0, 3.0) * scale_factor, frame_radius + 3.0 * scale_factor, Color(0.0, 0.0, 0.0, 0.38))
		var skill_orb_frame_texture = context.get("skill_orb_frame_texture", null)
		if skill_orb_frame_texture is Texture2D:
			var frame_rect: Rect2 = Rect2(slot_pos - Vector2(frame_size_f, frame_size_f) * 0.5, Vector2(frame_size_f, frame_size_f))
			var frame_texture: Texture2D = skill_orb_frame_texture
			canvas.draw_texture_rect(frame_texture, frame_rect, false)
		else:
			canvas.draw_circle(slot_pos, frame_radius, Color(16.0 / 255.0, 18.0 / 255.0, 23.0 / 255.0, 225.0 / 255.0))
			canvas.draw_circle(slot_pos, frame_radius, Color(145.0 / 255.0, 112.0 / 255.0, 58.0 / 255.0, 230.0 / 255.0), false, 3.0 * scale_factor)
			canvas.draw_circle(slot_pos, max(1.0, frame_radius - 5.0 * scale_factor), Color(35.0 / 255.0, 195.0 / 255.0, 230.0 / 255.0, 145.0 / 255.0), false, 1.0)


func _draw_cluster_connector(canvas: CanvasItem, start: Vector2, end: Vector2, width: float) -> void:
	if width <= 0.0:
		return
	canvas.draw_line(start, end, Color(0.0, 0.0, 0.0, 118.0 / 255.0), width + 8.0)
	canvas.draw_line(start, end, Color(18.0 / 255.0, 11.0 / 255.0, 6.0 / 255.0, 238.0 / 255.0), width + 4.0)
	canvas.draw_line(start, end, Color(83.0 / 255.0, 48.0 / 255.0, 20.0 / 255.0, 230.0 / 255.0), width)
	canvas.draw_line(start, end, Color(190.0 / 255.0, 126.0 / 255.0, 42.0 / 255.0, 205.0 / 255.0), max(1.0, width / 3.0))
	canvas.draw_line(start, end, Color(22.0 / 255.0, 81.0 / 255.0, 70.0 / 255.0, 150.0 / 255.0), max(1.0, width / 4.0))


func _as_vector2(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
