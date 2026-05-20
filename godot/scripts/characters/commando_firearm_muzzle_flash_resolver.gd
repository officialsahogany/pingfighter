extends RefCounted


static func build_flash(
	origin: Vector2,
	direction: Vector2,
	profile: Dictionary,
	weapon_id: String
) -> Dictionary:
	var timer_frames: float = max(1.0, float(profile.get("muzzle_flash_frames", 8.0)))
	return {
		"weapon_id": weapon_id,
		"kind": str(profile.get("kind", "bullet")),
		"pos": origin,
		"direction": direction,
		"radius": max(10.0, float(profile.get("radius", 5.0)) * 2.2),
		"timer_frames": timer_frames,
		"max_timer_frames": timer_frames,
		"color": profile.get("secondary", Color(1.0, 0.7, 0.2)),
	}
