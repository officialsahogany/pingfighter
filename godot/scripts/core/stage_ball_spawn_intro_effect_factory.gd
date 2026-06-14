extends RefCounted


func make_quantum_particle(rng: RandomNumberGenerator, start_pos: Vector2, max_radius: float) -> Dictionary:
	var ang: float = rng.randf_range(0.0, TAU)
	var dist: float = max_radius * rng.randf_range(0.78, 1.18)
	var color_idx: int = rng.randi_range(0, 7)
	var palette: Array = [
		[Color(0.55, 0.85, 1.0), Color(0.31, 0.63, 1.0)],
		[Color(0.78, 0.50, 1.0), Color(0.71, 0.39, 1.0)],
		[Color(1.0, 0.78, 0.92), Color(1.0, 0.55, 0.86)],
		[Color(0.50, 1.0, 0.92), Color(0.24, 0.90, 1.0)],
		[Color(1.0, 0.85, 0.51), Color(1.0, 0.78, 0.31)],
		[Color(0.55, 1.0, 0.69), Color(0.39, 1.0, 0.59)],
		[Color(1.0, 0.55, 0.51), Color(1.0, 0.47, 0.39)],
		[Color(1.0, 1.0, 1.0), Color(0.86, 0.86, 1.0)],
	]
	var pair: Array = palette[color_idx]
	var base_size: float = rng.randf_range(2.6, 6.8)
	return {
		"x": start_pos.x + cos(ang) * dist,
		"y": start_pos.y + sin(ang) * dist,
		"angle": ang,
		"radius": dist,
		"base_size": base_size,
		"size": base_size,
		"speed": rng.randf_range(0.55, 1.95),
		"wobble_amp": rng.randf_range(2.0, 8.0),
		"wobble_freq": rng.randf_range(4.0, 12.0),
		"wobble_phase": rng.randf_range(0.0, TAU),
		"radial_pulse_amp": rng.randf_range(0.02, 0.06),
		"radial_pulse_freq": rng.randf_range(2.0, 6.0),
		"radial_pulse_phase": rng.randf_range(0.0, TAU),
		"color": pair[0],
		"halo_color": pair[1],
		"color_idx": color_idx,
		"brightness_phase": rng.randf_range(0.0, TAU),
		"brightness_speed": rng.randf_range(4.0, 10.0),
		"pulse_phase": rng.randf_range(0.0, TAU),
		"pulse_speed": rng.randf_range(3.0, 7.0),
		"pulse_amp": rng.randf_range(0.15, 0.30),
		"trail": [] as Array[Vector4],
		"trail_length": 3,
		"has_flare": base_size > 5.5,
		"flare_angle": rng.randf_range(0.0, PI),
		"flare_rotation_speed": rng.randf_range(0.4, 1.4),
	}


func make_vortex_ring(rng: RandomNumberGenerator, start_pos: Vector2, radius: float) -> Dictionary:
	var palette: Array = [
		[Color(0.43, 0.75, 1.0), Color(0.84, 0.92, 1.0)],
		[Color(0.75, 0.47, 1.0), Color(0.94, 0.86, 1.0)],
		[Color(1.0, 0.65, 0.85), Color(1.0, 0.92, 0.96)],
	]
	var idx: int = rng.randi_range(0, palette.size() - 1)
	return {
		"center": start_pos,
		"radius": radius,
		"angle": rng.randf_range(0.0, TAU),
		"rotation_speed": rng.randf_range(1.0, 3.0) * (1.0 if rng.randf() < 0.5 else -1.0),
		"thickness": rng.randf_range(2.4, 4.0),
		"dash_count": rng.randi_range(8, 11),
		"dash_fill": rng.randf_range(0.42, 0.62),
		"shimmer_phase": rng.randf_range(0.0, TAU),
		"shimmer_freq": rng.randf_range(3.0, 6.5),
		"shimmer_amp": rng.randf_range(0.18, 0.32),
		"time": 0.0,
		"glow_color": palette[idx][0],
		"core_color": palette[idx][1],
		"alpha": 0.66,
	}


func make_starfield_dot(rng: RandomNumberGenerator, game_width: float, game_height: float) -> Dictionary:
	return {
		"pos": Vector2(rng.randf_range(0.0, game_width), rng.randf_range(0.0, game_height)),
		"size": rng.randf_range(0.7, 2.0),
		"phase": rng.randf_range(0.0, TAU),
		"speed": rng.randf_range(2.5, 7.0),
		"hue": rng.randi_range(0, 4),
	}


func make_haze_cloud(rng: RandomNumberGenerator, game_width: float, game_height: float) -> Dictionary:
	var palette: Array = [
		Color(0.55, 0.75, 1.0),
		Color(0.78, 0.62, 1.0),
		Color(1.0, 0.72, 0.92),
		Color(0.66, 0.92, 1.0),
	]
	return {
		"pos": Vector2(rng.randf_range(80.0, game_width - 80.0), rng.randf_range(80.0, game_height - 80.0)),
		"radius": rng.randf_range(180.0, 320.0),
		"drift_angle": rng.randf_range(0.0, TAU),
		"drift_speed": rng.randf_range(8.0, 20.0),
		"rotation": rng.randf_range(0.0, TAU),
		"rotation_speed": rng.randf_range(-0.3, 0.3),
		"pulse_phase": rng.randf_range(0.0, TAU),
		"pulse_speed": rng.randf_range(0.7, 1.6),
		"color": palette[rng.randi_range(0, palette.size() - 1)],
	}


func make_lightning_bolt(
	rng: RandomNumberGenerator,
	start_pt: Vector2,
	end_pt: Vector2,
	is_main: bool,
	branch_depth: int
) -> Dictionary:
	var color_pool: Array = [
		Color(0.78, 0.90, 1.0),
		Color(0.90, 0.78, 1.0),
		Color(1.0, 1.0, 0.94),
		Color(0.86, 1.0, 1.0),
		Color(1.0, 0.86, 1.0),
		Color(1.0, 1.0, 1.0),
		Color(0.71, 1.0, 0.90),
		Color(1.0, 0.90, 0.78),
		Color(0.82, 0.82, 1.0),
	]
	var color: Color = color_pool[rng.randi_range(0, color_pool.size() - 1)]
	var thickness: int = rng.randi_range(1, 3) if is_main else rng.randi_range(1, 2)
	var base_opacity: float = rng.randf_range(0.45, 0.70) if is_main else rng.randf_range(0.30, 0.50)
	var lifetime: float = rng.randf_range(0.10, 0.22) if is_main else rng.randf_range(0.06, 0.16)
	var segments: Array = make_lightning_segments(rng, start_pt, end_pt)
	var bolt: Dictionary = {
		"start": start_pt,
		"end": end_pt,
		"segments": segments,
		"branches": [],
		"lifetime": lifetime,
		"max_lifetime": lifetime,
		"fade_in_time": lifetime * 0.20,
		"color": color,
		"thickness": thickness,
		"base_opacity": base_opacity,
		"is_main": is_main,
		"branch_depth": branch_depth,
	}
	if branch_depth < 1 and is_main and segments.size() >= 2 and rng.randf() < 0.55:
		var pool_size: int = max(1, segments.size() - 1)
		var idx: int = rng.randi_range(0, pool_size - 1)
		var seg: Vector4 = segments[idx]
		var branch_start: Vector2 = Vector2(seg.z, seg.w)
		var main_angle: float = (end_pt - start_pt).angle()
		var branch_angle: float = main_angle + rng.randf_range(-PI / 3.0, PI / 3.0)
		var main_len: float = start_pt.distance_to(end_pt)
		var branch_len: float = main_len * rng.randf_range(0.22, 0.42)
		var branch_end: Vector2 = branch_start + Vector2(cos(branch_angle), sin(branch_angle)) * branch_len
		bolt.branches.append(make_lightning_bolt(rng, branch_start, branch_end, false, branch_depth + 1))
	return bolt


func make_lightning_segments(rng: RandomNumberGenerator, start_pt: Vector2, end_pt: Vector2) -> Array:
	var d: Vector2 = end_pt - start_pt
	var length: float = d.length()
	var out: Array = []
	if length < 1.0:
		out.append(Vector4(start_pt.x, start_pt.y, end_pt.x, end_pt.y))
		return out
	var num_segments: int = max(3, int(length / 18.0))
	var perp: Vector2 = Vector2(-d.y, d.x) / length
	var current: Vector2 = start_pt
	for i in range(num_segments):
		var t: float = float(i + 1) / float(num_segments)
		var nx: Vector2 = start_pt + d * t
		if i < num_segments - 1:
			var max_offset: float = 18.0 * (1.0 - t * 0.3)
			var off: float = rng.randf_range(-max_offset, max_offset)
			nx += perp * off
		out.append(Vector4(current.x, current.y, nx.x, nx.y))
		current = nx
	return out


func make_electric_arc(rng: RandomNumberGenerator, center: Vector2, radius: float) -> Dictionary:
	var palette: Array = [
		Color(0.59, 0.78, 1.0),
		Color(0.78, 0.59, 1.0),
		Color(1.0, 1.0, 0.78),
		Color(0.78, 1.0, 1.0),
		Color(0.62, 1.0, 0.86),
		Color(1.0, 0.78, 0.90),
		Color(0.90, 0.86, 1.0),
	]
	var noise: Array = []
	for _i in range(8):
		noise.append(rng.randf_range(-5.0, 5.0))
	var lifetime: float = rng.randf_range(0.32, 0.78)
	return {
		"center": center,
		"radius": radius,
		"angle": rng.randf_range(0.0, TAU),
		"arc_length": rng.randf_range(PI / 4.0, PI / 2.0),
		"rotation_speed": rng.randf_range(3.0, 8.0) * (1.0 if rng.randf() < 0.5 else -1.0),
		"color": palette[rng.randi_range(0, palette.size() - 1)],
		"thickness": rng.randi_range(1, 3),
		"lifetime": lifetime,
		"max_lifetime": lifetime,
		"noise": noise,
	}


func make_hologram_ring(rng: RandomNumberGenerator, center: Vector2, radius: float) -> Dictionary:
	var base_color_pool: Array = [
		Color(0.39, 0.78, 1.0),
		Color(0.59, 0.39, 1.0),
		Color(0.39, 1.0, 0.78),
	]
	var seg_count: int = rng.randi_range(14, 22)
	var distortion: Array = []
	for _i in range(seg_count):
		distortion.append(rng.randf_range(-3.0, 3.0))
	var lifetime: float = rng.randf_range(0.45, 1.0)
	return {
		"center": center,
		"radius": radius,
		"target_radius": radius,
		"flicker_phase": rng.randf_range(0.0, TAU),
		"flicker_speed": rng.randf_range(8.0, 15.0),
		"base_color": base_color_pool[rng.randi_range(0, base_color_pool.size() - 1)],
		"thickness": rng.randf_range(1.0, 2.0),
		"segments": seg_count,
		"distortion": distortion,
		"lifetime": lifetime,
		"max_lifetime": lifetime,
	}


func make_spark(rng: RandomNumberGenerator, pos: Vector2, direction: float) -> Dictionary:
	var color_pool: Array = [
		Color(1.0, 1.0, 0.78),
		Color(1.0, 0.78, 0.39),
		Color(0.78, 0.86, 1.0),
		Color(1.0, 1.0, 1.0),
		Color(1.0, 0.78, 1.0),
		Color(0.78, 1.0, 0.90),
		Color(1.0, 0.94, 0.59),
	]
	var speed: float = rng.randf_range(70.0, 220.0)
	var lifetime: float = rng.randf_range(0.22, 0.55)
	return {
		"pos": pos,
		"vel": Vector2(cos(direction), sin(direction)) * speed,
		"gravity": rng.randf_range(120.0, 320.0),
		"color": color_pool[rng.randi_range(0, color_pool.size() - 1)],
		"size": rng.randf_range(1.6, 3.6),
		"lifetime": lifetime,
		"max_lifetime": lifetime,
		"trail": [] as Array[Vector2],
		"trail_length": 4,
	}


func make_energy_ring(rng: RandomNumberGenerator, center: Vector2, start_radius: float) -> Dictionary:
	var palette: Array = [
		Color(0.59, 0.78, 1.0),
		Color(0.78, 0.59, 1.0),
		Color(1.0, 0.78, 0.59),
		Color(0.59, 1.0, 0.78),
	]
	var lifetime: float = rng.randf_range(0.30, 0.60)
	return {
		"center": center,
		"radius": start_radius,
		"max_radius": start_radius * 5.0,
		"color": palette[rng.randi_range(0, palette.size() - 1)],
		"thickness": 2.0,
		"lifetime": lifetime,
		"max_lifetime": lifetime,
		"expansion_speed": rng.randf_range(120.0, 220.0),
	}
