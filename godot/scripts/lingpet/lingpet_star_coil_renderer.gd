extends RefCounted

const STAR_INNER_RATIO := 0.46


func prewarm() -> void:
	pass


func draw_star_coil(
	canvas: CanvasItem,
	shake_offset: Vector2,
	trail_visible: bool,
	trail: Array[Vector2],
	sparks: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	if trail_visible:
		_draw_motion_trail(canvas, trail, shake_offset)
	_draw_sparks(canvas, sparks, shake_offset)


func get_star_vertices_for_tests(center: Vector2, radius: float, rotation: float, points: int) -> PackedVector2Array:
	return _build_star_vertices(center, radius, rotation, points)


func _draw_motion_trail(canvas: CanvasItem, trail: Array[Vector2], shake_offset: Vector2) -> void:
	for index in range(trail.size()):
		var ratio := float(index + 1) / float(maxi(1, trail.size()))
		var trail_pos: Vector2 = trail[index] + shake_offset
		var alpha := 0.08 + ratio * 0.18
		canvas.draw_circle(trail_pos, lerpf(2.0, 7.0, ratio), Color(0.34, 0.26, 0.74, alpha))
		if index % 3 == 0:
			canvas.draw_circle(trail_pos, lerpf(1.0, 2.2, ratio), Color(1.0, 0.86, 0.42, alpha + 0.08))


func _draw_sparks(canvas: CanvasItem, sparks: Array[Dictionary], shake_offset: Vector2) -> void:
	for spark in sparks:
		var max_life := maxf(0.001, float(spark.get("max_life", 0.3)))
		var ratio := clampf(float(spark.get("life", 0.0)) / max_life, 0.0, 1.0)
		var pos: Vector2 = spark.get("pos", Vector2.ZERO) + shake_offset
		var base_color: Color = spark.get("color", Color(1.0, 0.84, 0.36))
		var size := float(spark.get("size", 2.0)) * (0.55 + ratio * 0.45)
		# Soft colored glow remains visible even if a future malformed polygon fill
		# is rejected by Godot's triangulator.
		canvas.draw_circle(pos, size + 2.4, Color(base_color.r, base_color.g, base_color.b, 0.16 * ratio))
		_draw_star(
			canvas,
			pos,
			size,
			float(spark.get("rotation", 0.0)),
			Color(base_color.r, base_color.g, base_color.b, clampf(ratio * 1.1, 0.0, 1.0)),
			int(spark.get("points", 5))
		)
		canvas.draw_circle(pos, maxf(0.5, size * 0.30), Color(1.0, 1.0, 1.0, 0.85 * ratio))


func _draw_star(canvas: CanvasItem, center: Vector2, radius: float, rotation: float, color: Color, points: int) -> void:
	canvas.draw_colored_polygon(_build_star_vertices(center, radius, rotation, points), color)


func _build_star_vertices(center: Vector2, radius: float, rotation: float, points: int) -> PackedVector2Array:
	var point_count := maxi(4, points)
	var inner := radius * STAR_INNER_RATIO
	var vertices := PackedVector2Array()
	var total := point_count * 2
	for index in range(total):
		var vertex_radius := radius if (index % 2 == 0) else inner
		var angle := rotation + float(index) * PI / float(point_count)
		vertices.push_back(center + Vector2(cos(angle), sin(angle)) * vertex_radius)
	return vertices
