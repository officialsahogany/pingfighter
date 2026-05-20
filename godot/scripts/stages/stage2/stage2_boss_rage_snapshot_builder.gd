extends RefCounted


func build_snapshot(
	pending: bool,
	active: bool,
	timer: float,
	stomp_count: int,
	final_stomp_done: bool,
	offset_y: float,
	tint: float
) -> Dictionary:
	return {
		"pending": pending,
		"active": active,
		"timer": timer,
		"stomp_count": stomp_count,
		"final_stomp_done": final_stomp_done,
		"offset_y": offset_y,
		"tint": tint,
	}
