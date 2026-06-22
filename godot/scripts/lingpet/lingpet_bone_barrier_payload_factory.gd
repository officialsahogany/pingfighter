extends RefCounted


static func build_barrier(
	barrier_id: int,
	position: Vector2,
	width: float,
	height: float,
	caster_is_top: bool
) -> Dictionary:
	var segment_count := randi_range(10, 14)
	var bone_segments: Array[Dictionary] = []
	for index in range(segment_count):
		var t := (float(index) + 0.5) / float(segment_count)
		var final_pos := position + Vector2(width * t + randf_range(-2.5, 2.5), height * 0.5 + randf_range(-4.0, 4.0))
		var scatter_angle := randf_range(0.0, TAU)
		var scatter_dist := randf_range(50.0, 120.0)
		var start_pos := final_pos + Vector2(cos(scatter_angle), sin(scatter_angle)) * scatter_dist
		bone_segments.append({
			"start_pos": start_pos,
			"final_pos": final_pos,
			"length": randf_range(8.0, 14.0),
			"delay": float(index) * 0.04 + randf_range(0.0, 0.15),
			"rotation_start": randf_range(-PI, PI),
			"rotation_end": randf_range(-0.32, 0.32),
		})

	var spike_heights: Array[float] = []
	for _index in range(maxi(1, int(width / 14.0))):
		spike_heights.append(randf_range(5.0, 10.0))

	return {
		"id": barrier_id,
		"pos": position,
		"width": width,
		"height": height,
		"timer": 0.0,
		"built": false,
		"caster_is_top": caster_is_top,
		"bone_segments": bone_segments,
		"spike_heights": spike_heights,
		"phase": randf_range(0.0, TAU),
	}


static func build_build_particle(position: Vector2) -> Dictionary:
	var angle := randf_range(PI, TAU)
	var speed := randf_range(26.0, 110.0)
	return {
		"pos": position + Vector2(randf_range(-48.0, 48.0), randf_range(-8.0, 8.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -38.0),
		"age": 0.0,
		"life": randf_range(0.34, 0.82),
		"size": randf_range(1.5, 4.2),
		"color": Color(0.85, 0.86, 0.74, randf_range(0.30, 0.66)),
	}


static func build_hit_particle(position: Vector2, incoming_velocity: Vector2, index: int) -> Dictionary:
	var base_angle := incoming_velocity.angle() + PI
	var angle := base_angle + randf_range(-0.95, 0.95) + float(index) * 0.03
	var speed := randf_range(80.0, 260.0)
	return {
		"pos": position,
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"age": 0.0,
		"life": randf_range(0.20, 0.48),
		"size": randf_range(2.0, 5.2),
		"color": Color(0.86, 0.82, 0.70, randf_range(0.48, 0.88)),
	}


static func build_bone_fragment(position: Vector2, incoming_velocity: Vector2, index: int) -> Dictionary:
	var base_angle := incoming_velocity.angle() + PI
	if incoming_velocity.length_squared() <= 0.0001:
		base_angle = -PI * 0.5
	var angle := base_angle + randf_range(-1.15, 1.15) + float(index) * 0.08
	var speed := randf_range(95.0, 285.0)
	return {
		"pos": position + Vector2(randf_range(-50.0, 50.0), randf_range(-7.0, 7.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -70.0),
		"rotation": randf_range(0.0, TAU),
		"rotation_speed": randf_range(-10.0, 10.0),
		"length": randf_range(6.0, 16.0),
	}
