extends RefCounted


static func update_offset(rock: Dictionary, delta: float, quake_timer: float, quake_duration: float) -> void:
	var current: Vector2 = _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	if quake_timer <= 0.0:
		var decay: float = pow(0.55, max(0.0, delta) * 60.0)
		current *= decay
		if abs(current.x) < 0.15:
			current.x = 0.0
		if abs(current.y) < 0.15:
			current.y = 0.0
		rock["quake_offset"] = current
		return

	var elapsed: float = max(0.0, quake_duration - quake_timer) * 60.0
	var progress: float = clampf(elapsed / max(1.0, quake_duration * 60.0), 0.0, 1.0)
	var base_intensity: float = get_base_intensity(progress)
	var visual_radius: float = float(rock.get("visual_radius", rock.get("radius", 28.0)))
	var size_scale: float = clampf(visual_radius / 55.0, 0.78, 1.35)
	if bool(rock.get("falling", false)):
		size_scale *= 0.72
	base_intensity *= size_scale

	var phase: float = float(rock.get("phase", 0.0))
	var offset_x: float = sin(elapsed * 1.95 + phase) * base_intensity * 0.95
	offset_x += sin(elapsed * 4.7 + phase * 1.7) * base_intensity * 0.35
	var offset_y: float = cos(elapsed * 2.55 + phase * 1.3) * base_intensity * 0.70
	offset_y += sin(elapsed * 5.3 + phase * 0.9) * base_intensity * 0.22
	if not bool(rock.get("falling", false)):
		offset_y += sin(elapsed * 1.4 + phase * 0.5) * base_intensity * 0.18
	rock["quake_offset"] = Vector2(offset_x, offset_y)


static func get_base_intensity(progress: float) -> float:
	if progress < 0.16:
		return 6.8
	if progress < 0.72:
		var middle_progress: float = (progress - 0.16) / 0.56
		return 6.8 - middle_progress * 2.4
	var fade_progress: float = (progress - 0.72) / 0.28
	return 4.4 * (1.0 - clampf(fade_progress, 0.0, 1.0))


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
