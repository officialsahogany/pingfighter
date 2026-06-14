extends RefCounted

const ELECTRIC_STUN_VISUAL := "lumion_thunder_orb"


static func build_electric_stun_status_data() -> Dictionary:
	return {
		"cleansable": true,
		"visual": ELECTRIC_STUN_VISUAL,
		"suppress_stun_stars": true,
		"electric_stun": true,
	}


static func build_energy_particle(orb_pos: Vector2, orb_visual_radius: float, energy_colors: Array[Color]) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var dist := orb_visual_radius * randf_range(0.9, 1.5)
	return {
		"pos": orb_pos + Vector2(cos(angle) * dist, sin(angle) * dist),
		"vel": Vector2(randf_range(-12.0, 12.0), randf_range(-42.0, -16.0)),
		"life": randf_range(0.33, 0.66),
		"max_life": 0.66,
		"size": randf_range(1.2, 2.6),
		"color": _pick_color(energy_colors),
	}


static func build_large_explosion_particle(origin: Vector2, large_particle_colors: Array[Color]) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(200.0, 600.0)
	return build_particle(
		origin + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
		Vector2(cos(angle), sin(angle)) * speed,
		randf_range(0.20, 0.45),
		randf_range(2.0, 5.0),
		0,
		_pick_color(large_particle_colors)
	)


static func build_small_explosion_particle(origin: Vector2, energy_colors: Array[Color]) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(300.0, 800.0)
	return build_particle(
		origin + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
		Vector2(cos(angle), sin(angle)) * speed,
		randf_range(0.10, 0.30),
		randf_range(1.0, 2.5),
		1,
		_pick_color(energy_colors)
	)


static func build_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int, color: Color = Color.WHITE) -> Dictionary:
	var safe_life := maxf(0.01, life)
	return {
		"pos": pos,
		"vel": vel,
		"life": safe_life,
		"max_life": safe_life,
		"size": size,
		"kind": kind,
		"color": color,
	}


static func _pick_color(colors: Array[Color]) -> Color:
	if colors.is_empty():
		return Color.WHITE
	return colors[randi() % colors.size()]
