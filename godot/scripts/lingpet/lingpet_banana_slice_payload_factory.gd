extends RefCounted

const BURST_COLORS := [
	Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0),
	Color(227.0 / 255.0, 189.0 / 255.0, 52.0 / 255.0, 1.0),
	Color(198.0 / 255.0, 156.0 / 255.0, 41.0 / 255.0, 1.0),
	Color(1.0, 1.0, 200.0 / 255.0, 1.0),
	Color(139.0 / 255.0, 90.0 / 255.0, 43.0 / 255.0, 1.0),
]


static func build_projectile(
	start_pos: Vector2,
	target_x: float,
	index: int,
	land_y: float,
	throw_aim_x_divisor: float,
	throw_speed_x_max_per_frame: float,
	throw_speed_y_per_frame: float,
	second_throw_delay_seconds: float
) -> Dictionary:
	var dx := target_x - start_pos.x
	var x_speed := minf(absf(dx) / maxf(0.001, throw_aim_x_divisor), throw_speed_x_max_per_frame)
	var x_dir := -1.0 if dx < 0.0 else 1.0
	if absf(dx) <= 0.001:
		x_dir = 0.0
	var rotation_speed := randf_range(480.0, 900.0)
	var rotation_sign := -1.0 if randf() < 0.5 else 1.0
	return {
		"position": start_pos,
		"velocity": Vector2(x_dir * x_speed, throw_speed_y_per_frame),
		"target_position": Vector2(target_x, land_y),
		"delay": second_throw_delay_seconds * float(index),
		"rotation_degrees": 0.0,
		"rotation_speed_degrees": rotation_speed * rotation_sign,
		"trail": [start_pos],
	}


static func build_landed_banana(
	position: Vector2,
	land_x_min: float,
	land_x_max: float,
	land_y: float,
	timer_seconds: float,
	max_timer_seconds: float = -1.0
) -> Dictionary:
	var max_timer := max_timer_seconds if max_timer_seconds >= 0.0 else timer_seconds
	return {
		"position": Vector2(clampf(position.x, land_x_min, land_x_max), land_y),
		"timer": maxf(0.0, timer_seconds),
		"max_timer": max_timer,
		"slip_triggered": false,
	}


static func build_burst_particle(position: Vector2) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(180.0, 480.0)
	var color: Color = BURST_COLORS[randi() % BURST_COLORS.size()]
	return {
		"position": position,
		"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -180.0),
		"life": randf_range(0.33, 0.67),
		"max_life": 0.67,
		"size": randf_range(3.0, 7.0),
		"color": color,
	}
