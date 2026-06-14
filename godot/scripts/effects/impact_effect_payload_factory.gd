extends RefCounted


static func build_energy_burst(
	pos: Vector2,
	scale: float,
	intensity: float,
	colors: Array[Color],
	radius_base: float,
	radius_intensity_bonus: float,
	life_base: float,
	life_intensity_bonus: float
) -> Dictionary:
	var normalized_intensity := clampf(intensity, 0.0, 1.5)
	var clamped_scale := maxf(0.10, scale)
	return {
		"pos": pos,
		"size": (radius_base + radius_intensity_bonus * normalized_intensity) * clamped_scale,
		"lifetime": 0.0,
		"max_lifetime": (life_base + life_intensity_bonus * normalized_intensity) * clamped_scale,
		"color": colors[randi() % colors.size()],
		"intensity": normalized_intensity,
		"type": "burst",
	}


static func build_drive_spark(pos: Vector2, colors: Array[Color]) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(3.0, 8.0)
	return {
		"pos": pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -1.5),
		"size": randf_range(2.0, 4.0),
		"lifetime": 0.0,
		"max_lifetime": float(randi_range(14, 24)),
		"color": colors[randi() % colors.size()],
		"type": "spark",
	}


static func build_wall_ring(pos: Vector2, side: String, speed_bonus: float, ring_life: float, colors: Array[Color]) -> Dictionary:
	return {
		"pos": pos,
		"side": side,
		"life": ring_life,
		"max_life": ring_life,
		"start_radius": 10.0,
		"end_radius": 36.0 + speed_bonus * 30.0,
		"thickness": 2.0 + speed_bonus * 1.8,
		"color": colors[randi() % colors.size()],
	}


static func build_wall_particle(
	pos: Vector2,
	direction_mult: float,
	speed_bonus: float,
	life_min: float,
	life_max: float,
	colors: Array[Color]
) -> Dictionary:
	var angle := randf_range(-0.8, 0.8)
	var speed := randf_range(3.0, 6.4 + speed_bonus * 2.4)
	var max_life := randf_range(life_min, life_max)
	return {
		"pos": pos,
		"vel": Vector2(cos(angle) * speed * direction_mult, sin(angle) * speed + randf_range(-1.0, 1.0)),
		"life": max_life,
		"max_life": max_life,
		"size": randf_range(2.4, 4.8 + speed_bonus),
		"color": colors[randi() % colors.size()],
		"trail": randf_range(8.0, 16.0 + speed_bonus * 9.0),
	}


static func build_paddle_spark(
	pos: Vector2,
	color: Color,
	direction: Vector2,
	tangent: Vector2,
	force: float,
	life_min: float,
	life_max: float
) -> Dictionary:
	var spread := randf_range(-1.0, 1.0)
	var push: Vector2 = (direction * randf_range(3.0, 6.4 + force * 3.0)) + (tangent * spread * randf_range(1.2, 4.6))
	push += Vector2(randf_range(-0.55, 0.55), randf_range(-0.55, 0.55))
	var max_life := randf_range(life_min, life_max + force * 0.025)
	return {
		"pos": pos + tangent * randf_range(-4.0, 4.0),
		"vel": push,
		"life": max_life,
		"max_life": max_life,
		"size": randf_range(1.8, 4.2 + force * 0.9),
		"color": color,
		"trail": randf_range(7.0, 16.0 + force * 8.0),
	}


static func build_paddle_primary_ring(pos: Vector2, color: Color, force: float, ring_life: float) -> Dictionary:
	return {
		"pos": pos,
		"life": ring_life + force * 0.04,
		"max_life": ring_life + force * 0.04,
		"start_radius": 8.0 + force * 3.0,
		"end_radius": 32.0 + force * 28.0,
		"color": color,
		"thickness": 2.4 + force * 1.6,
	}


static func build_paddle_core_ring(
	pos: Vector2,
	color: Color,
	direction: Vector2,
	force: float,
	ring_life: float,
	core_flash_color: Color
) -> Dictionary:
	return {
		"pos": pos - direction * (4.0 + force * 3.0),
		"life": ring_life * 0.72,
		"max_life": ring_life * 0.72,
		"start_radius": 4.0 + force * 2.0,
		"end_radius": 18.0 + force * 18.0,
		"color": core_flash_color.lerp(color, 0.35),
		"thickness": 1.6 + force,
	}


static func build_paddle_streak(pos: Vector2, color: Color, direction: Vector2, tangent: Vector2, force: float, streak_life: float) -> Dictionary:
	var tangent_bias := randf_range(-1.0, 1.0)
	var streak_dir: Vector2 = (tangent * tangent_bias * randf_range(0.7, 1.45) + direction * randf_range(0.45, 1.0)).normalized()
	if streak_dir.length_squared() <= 0.001:
		streak_dir = direction
	return {
		"pos": pos + tangent * randf_range(-12.0, 12.0) - direction * randf_range(0.0, 5.0),
		"vel": streak_dir * randf_range(2.4, 5.4 + force * 2.0),
		"dir": streak_dir,
		"life": streak_life + randf_range(-0.025, 0.04),
		"max_life": streak_life + 0.04,
		"length": randf_range(20.0, 36.0 + force * 30.0),
		"width": randf_range(1.5, 2.9 + force * 1.1),
		"color": color,
	}


static func build_paddle_flash(pos: Vector2, color: Color, force: float, flash_life: float, core_flash_color: Color) -> Dictionary:
	return {
		"pos": pos,
		"life": flash_life,
		"max_life": flash_life,
		"radius": 18.0 + force * 26.0,
		"color": core_flash_color.lerp(color, 0.28),
	}
