extends RefCounted


func build_state(
	phase: String,
	start: Vector2,
	target: Vector2,
	current: Vector2,
	progress: float,
	timer: float,
	charge_sec: float,
	trail_life_sec: float
) -> Dictionary:
	return {
		"phase": phase,
		"start": start,
		"target": target,
		"current": current,
		"progress": progress,
		"timer": timer,
		"charge_sec": charge_sec,
		"trail_life_sec": trail_life_sec,
	}
