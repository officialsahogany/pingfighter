extends RefCounted

const DROP_EFFECT_SECONDS := 0.55
const DROP_FALL_SPEED := 84.0
const PARTICLE_GRAVITY := 38.0
const PARTICLE_DAMPING_PER_FRAME := 0.92

var _drop_effects: Array[Dictionary] = []
var _explosion_effects: Array[Dictionary] = []


func reset() -> void:
	_drop_effects.clear()
	_explosion_effects.clear()


func advance(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)
	_update_drop_effects(safe_delta)
	_update_explosion_effects(safe_delta)


func spawn_drop(drop: Dictionary, fallback_position: Vector2) -> void:
	_drop_effects.append({
		"type": str(drop.get("type", "")),
		"item_id": str(drop.get("item_id", drop.get("weapon_id", ""))),
		"life": DROP_EFFECT_SECONDS,
		"duration": DROP_EFFECT_SECONDS,
		"pos": _get_vector2(drop.get("drop_position", fallback_position), fallback_position),
		"vy": DROP_FALL_SPEED,
	})


func spawn_aircraft_hit(pos: Vector2) -> void:
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		var speed: float = 58.0 + float(index % 4) * 12.0
		_explosion_effects.append({
			"kind": "spark",
			"pos": pos + Vector2(float((index % 3) - 1) * 5.0, float((index % 2) - 1) * 4.0),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"radius": 3.5 + float(index % 3),
			"life": 0.34,
			"duration": 0.34,
			"color": Color(1.0, 0.48 + float(index % 2) * 0.22, 0.08, 0.92),
		})
	for index in range(7):
		_explosion_effects.append({
			"kind": "smoke",
			"pos": pos + Vector2(float(index - 3) * 5.5, 4.0 + float(index % 2) * 4.0),
			"vel": Vector2(-12.0 + float(index) * 4.0, -28.0 - float(index % 3) * 8.0),
			"radius": 9.0 + float(index % 3) * 2.0,
			"life": 0.72,
			"duration": 0.72,
			"color": Color(0.16, 0.16, 0.14, 0.64),
		})


func spawn_aircraft_smoke(pos: Vector2, direction: String) -> void:
	var back_sign: float = -1.0 if direction != "right_to_left" else 1.0
	_explosion_effects.append({
		"kind": "smoke",
		"pos": pos + Vector2(24.0 * back_sign, 8.0),
		"vel": Vector2(18.0 * back_sign, -34.0),
		"radius": 11.0,
		"life": 0.62,
		"duration": 0.62,
		"color": Color(0.10, 0.10, 0.09, 0.68),
	})


func spawn_aircraft_explosion(pos: Vector2) -> void:
	# Motion accents only. The shared grenade drawer remains responsible for
	# the large fireball, flash, rings, and mushroom column.
	for index in range(18):
		var angle: float = TAU * float(index) / 18.0
		var speed: float = 84.0 + float(index % 5) * 16.0
		_explosion_effects.append({
			"kind": "spark",
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"radius": 5.0 + float(index % 4),
			"life": 0.58,
			"duration": 0.58,
			"color": Color(1.0, 0.32 + float(index % 3) * 0.18, 0.04, 0.96),
		})
	for index in range(14):
		var angle: float = TAU * float(index) / 14.0
		_explosion_effects.append({
			"kind": "smoke",
			"pos": pos + Vector2(cos(angle), sin(angle)) * 10.0,
			"vel": Vector2(cos(angle) * 38.0, sin(angle) * 20.0 - 42.0),
			"radius": 15.0 + float(index % 4) * 3.0,
			"life": 0.96,
			"duration": 0.96,
			"color": Color(0.12, 0.11, 0.10, 0.72),
		})
	for index in range(10):
		var angle: float = TAU * float(index) / 10.0 + 0.18
		_explosion_effects.append({
			"kind": "debris",
			"pos": pos,
			"vel": Vector2(cos(angle) * 74.0, sin(angle) * 48.0 - 22.0),
			"radius": 3.0 + float(index % 2),
			"life": 0.82,
			"duration": 0.82,
			"color": Color(0.21, 0.22, 0.17, 0.95),
		})


func has_effects() -> bool:
	return not _drop_effects.is_empty() or not _explosion_effects.is_empty()


func get_drop_effects() -> Array[Dictionary]:
	return _drop_effects


func get_explosion_effects() -> Array[Dictionary]:
	return _explosion_effects


func get_drop_effect_count() -> int:
	return _drop_effects.size()


func get_explosion_effect_count() -> int:
	return _explosion_effects.size()


func get_snapshot() -> Dictionary:
	return {
		"drop_effects": _drop_effects.duplicate(true),
		"explosion_effects": _explosion_effects.duplicate(true),
	}


func restore(snapshot: Dictionary) -> void:
	_drop_effects = _duplicate_dictionary_array(snapshot.get("drop_effects", []))
	_explosion_effects = _duplicate_dictionary_array(snapshot.get("explosion_effects", []))


func _update_drop_effects(delta: float) -> void:
	if _drop_effects.is_empty():
		return
	var next_effects: Array[Dictionary] = []
	for effect in _drop_effects:
		var next_effect: Dictionary = effect.duplicate(true)
		next_effect["life"] = max(0.0, float(next_effect.get("life", 0.0)) - delta)
		var pos: Vector2 = _get_vector2(next_effect.get("pos", Vector2.ZERO), Vector2.ZERO)
		pos.y += float(next_effect.get("vy", 0.0)) * delta
		next_effect["pos"] = pos
		if float(next_effect.get("life", 0.0)) > 0.0:
			next_effects.append(next_effect)
	_drop_effects = next_effects


func _update_explosion_effects(delta: float) -> void:
	if _explosion_effects.is_empty():
		return
	var next_effects: Array[Dictionary] = []
	for effect in _explosion_effects:
		var next_effect: Dictionary = effect.duplicate(true)
		next_effect["life"] = max(0.0, float(next_effect.get("life", 0.0)) - delta)
		var pos: Vector2 = _get_vector2(next_effect.get("pos", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(next_effect.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity.y += PARTICLE_GRAVITY * delta
		pos += velocity * delta
		next_effect["pos"] = pos
		next_effect["vel"] = velocity * pow(PARTICLE_DAMPING_PER_FRAME, delta * 60.0)
		if float(next_effect.get("life", 0.0)) > 0.0:
			next_effects.append(next_effect)
	_explosion_effects = next_effects


static func _duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
