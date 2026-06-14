extends RefCounted


static func build_residue(
	residue_id: int,
	floor_pos: Vector2,
	origin: Vector2,
	duration: float,
	total_gauge: float,
	tick_count: int,
	absorb_radius: float,
	seed_value: float,
	jet_emit_seconds: float,
	absorb_flash_seconds: float
) -> Dictionary:
	var safe_tick_count := maxi(1, tick_count)
	return {
		"id": residue_id,
		"pos": floor_pos,
		"origin": origin,
		"timer": duration,
		"duration": duration,
		"age": 0.0,
		"emit_timer": jet_emit_seconds,
		"emit_accum": 0.0,
		"lean": randf_range(-0.12, 0.12),
		"splats": [],
		"remaining_gauge": total_gauge,
		"total_gauge": total_gauge,
		"tick_gain": total_gauge / float(safe_tick_count),
		"absorb_accum": 0.0,
		"absorb_radius": maxf(8.0, absorb_radius),
		"seed": seed_value,
		"absorb_flash": absorb_flash_seconds,
	}


static func build_splat(landing_x: float, floor_y: float, born: float) -> Dictionary:
	return {
		"x": landing_x,
		"y": floor_y,
		"born": born,
		"size": randf_range(6.0, 12.0),
		"seed": fmod(absf(landing_x * 0.13 + born * 7.0), TAU),
	}


static func build_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int, params: Dictionary = {}) -> Dictionary:
	return {
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": maxf(0.01, life),
		"size": size,
		"kind": kind,
		"target": _as_vector2(params.get("target", Vector2.ZERO), Vector2.ZERO),
		"floor_y": float(params.get("floor_y", 0.0)),
		"pool_id": int(params.get("pool_id", -1)),
	}


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
