extends RefCounted

const FALLBACK_DEBRIS_SPRITE_INDEX := 15


static func make_debris(data: Dictionary, random: RandomNumberGenerator, variants_by_type: Dictionary) -> Dictionary:
	var debris := data.duplicate()
	var debris_type: String = str(debris.get("type", "stone"))
	debris["type"] = debris_type
	debris["sprite_index"] = int(debris.get("sprite_index", _pick_debris_sprite_index(debris_type, random, variants_by_type)))
	debris["sprite_flip_x"] = bool(debris.get("sprite_flip_x", random.randf() < 0.5))
	debris["sprite_scale_jitter"] = float(debris.get("sprite_scale_jitter", random.randf_range(0.88, 1.14)))
	debris["opacity"] = float(debris.get("opacity", 1.0))
	debris["delay"] = float(debris.get("delay", 0.0))
	debris["gravity"] = float(debris.get("gravity", 0.35))
	debris["drag"] = float(debris.get("drag", 0.98))
	return debris


static func make_dust_cloud(
	x: float,
	y: float,
	size: float,
	max_opacity: float,
	expand_rate: float,
	rise_speed: float,
	delay: float
) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"size": size,
		"opacity": 0.0,
		"max_opacity": max_opacity,
		"expand_rate": expand_rate,
		"rise_speed": rise_speed,
		"delay": delay,
	}


static func make_fire_particle(
	x: float,
	y: float,
	vx: float,
	vy: float,
	size: float,
	life: float,
	random: RandomNumberGenerator
) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"vx": vx,
		"vy": vy,
		"size": size,
		"life": life,
		"color_phase": random.randf(),
	}


static func make_falling_lantern(lantern: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var x: float = float(lantern.get("x", 0.0))
	var target_x: float = 300.0 + float(random.randi_range(-100, 100))
	var vx: float = clampf((target_x - x) / 100.0 + random.randf_range(-1.0, 1.0), -4.0, 4.0)
	return {
		"x": x,
		"y": float(lantern.get("y", 0.0)),
		"vx": vx,
		"vy": 0.0,
		"rotation": 0.0,
		"rotation_speed": random.randf_range(-5.0, 5.0),
		"size": str(lantern.get("size", "medium")),
		"broken": false,
		"ground_y": 650.0 + float(random.randi_range(-10, 10)),
		"deformation": 0.0,
		"bounce_count": 0,
	}


static func _pick_debris_sprite_index(
	debris_type: String,
	random: RandomNumberGenerator,
	variants_by_type: Dictionary
) -> int:
	var variants: Array = variants_by_type.get(debris_type, [FALLBACK_DEBRIS_SPRITE_INDEX])
	if variants.is_empty():
		return FALLBACK_DEBRIS_SPRITE_INDEX
	return int(variants[random.randi_range(0, variants.size() - 1)])
