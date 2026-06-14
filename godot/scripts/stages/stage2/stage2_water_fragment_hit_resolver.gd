extends RefCounted

const Stage2WaterFragmentHitPayloadFactory := preload("res://scripts/stages/stage2/stage2_water_fragment_hit_payload_factory.gd")


static func resolve_hits(water_splashes: Array, player_rects: Array[Rect2], collision_geometry: Object) -> Array:
	var hits: Array = []
	if collision_geometry == null or not collision_geometry.has_method("get_first_overlapping_rect"):
		return hits
	for index in range(water_splashes.size()):
		var splash: Dictionary = water_splashes[index]
		if not bool(splash.get("can_hit_player", false)):
			continue
		if float(splash.get("hit_cooldown", 0.0)) > 0.0:
			splash["hit_cooldown"] = max(0.0, float(splash.get("hit_cooldown", 0.0)) - 1.0)
			water_splashes[index] = splash
			continue
		var pos: Vector2 = _get_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO)
		var radius: float = max(3.0, float(splash.get("hit_radius", float(splash.get("radius", 5.0)) * 1.55)))
		var hit_rect: Rect2 = collision_geometry.get_first_overlapping_rect(pos, radius, player_rects)
		if hit_rect.size.x <= 0.0:
			continue
		hits.append(Stage2WaterFragmentHitPayloadFactory.build_hit(index, splash, pos, hit_rect))
	return hits


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
