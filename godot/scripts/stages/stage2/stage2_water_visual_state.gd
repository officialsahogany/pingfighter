extends RefCounted


static func update_trail(water_trail: Array, delta: float) -> void:
	var write_index := 0
	var trail_count := water_trail.size()
	for index in range(trail_count):
		var trail: Dictionary = water_trail[index]
		var life: float = float(trail.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		trail["life"] = life
		water_trail[write_index] = trail
		write_index += 1
	if write_index < trail_count:
		water_trail.resize(write_index)


static func update_splashes(water_splashes: Array, delta: float) -> void:
	var write_index := 0
	var splash_count := water_splashes.size()
	for index in range(splash_count):
		var splash: Dictionary = water_splashes[index]
		if not update_splash(splash, delta):
			continue
		water_splashes[write_index] = splash
		write_index += 1
	if write_index < splash_count:
		water_splashes.resize(write_index)


static func update_splash(splash: Dictionary, delta: float) -> bool:
	var life: float = float(splash.get("life", 0.0)) - delta
	if life <= 0.0:
		return false
	var pos: Vector2 = _get_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO)
	var vel: Vector2 = _get_vector2(splash.get("vel", Vector2.ZERO), Vector2.ZERO)
	vel.y += float(splash.get("gravity", 300.0)) * delta
	vel *= pow(0.975, delta * 60.0)
	pos += vel * delta
	splash["pos"] = pos
	splash["vel"] = vel
	splash["life"] = life
	splash["rot"] = float(splash.get("rot", 0.0)) + float(splash.get("spin", 0.0)) * delta
	return true


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
