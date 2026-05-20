extends RefCounted


func get_left(context: Dictionary) -> float:
	return float(context.get("play_left", 0.0))


func get_right(context: Dictionary) -> float:
	return float(context.get("play_right", context.get("width", 760.0)))


func get_height(context: Dictionary) -> float:
	return float(context.get("height", 750.0))
