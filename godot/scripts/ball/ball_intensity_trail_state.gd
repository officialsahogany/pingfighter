extends RefCounted

var intensity_trail: Array[Dictionary] = []


func clear() -> void:
	intensity_trail.clear()


func update(ball_center: Vector2, fps_scale: float, intensity: float, colors: Array[Color]) -> void:
	var trail_spacing: float = 6.0 + intensity * 4.0
	var trail_length: int = int(8.0 + intensity * 8.0)
	var trail_alpha: float = (210.0 + intensity * 35.0) / 255.0
	var trail_size: float = 6.0 + intensity * 7.0
	if intensity_trail.is_empty():
		intensity_trail.append({
			"pos": ball_center,
			"alpha": trail_alpha,
			"size": trail_size,
			"color": colors[0],
		})
	else:
		var last_trail: Dictionary = intensity_trail[intensity_trail.size() - 1]
		var last_pos: Vector2 = last_trail["pos"]
		var delta_pos: Vector2 = ball_center - last_pos
		var distance: float = delta_pos.length()
		if distance >= trail_spacing:
			var segments: int = int(distance / trail_spacing)
			segments = clampi(segments, 1, 3)
			for step in range(1, segments + 1):
				var t: float = float(step) / float(segments)
				intensity_trail.append({
					"pos": last_pos.lerp(ball_center, t),
					"alpha": trail_alpha,
					"size": trail_size,
					"color": colors[0],
				})

	while intensity_trail.size() > trail_length:
		intensity_trail.pop_front()

	var updated_trail: Array[Dictionary] = []
	var trail_fade: float = pow(0.8 + intensity * 0.08, fps_scale)
	for point in intensity_trail:
		var p: Dictionary = point
		var alpha: float = float(p["alpha"]) * trail_fade
		var size: float = float(p["size"]) * pow(0.94, fps_scale)
		if alpha > 10.0 / 255.0 and size > 0.5:
			p["alpha"] = alpha
			p["size"] = size
			updated_trail.append(p)
	intensity_trail = updated_trail


func get_trail() -> Array[Dictionary]:
	return intensity_trail.duplicate()
