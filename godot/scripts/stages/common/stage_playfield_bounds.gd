extends RefCounted


static func get_left(context: Dictionary) -> float:
	return float(context.get("play_left", 0.0))


static func get_right(context: Dictionary, default_width: float = 760.0) -> float:
	return float(context.get("play_right", context.get("width", default_width)))


static func get_height(context: Dictionary, default_height: float = 750.0) -> float:
	return float(context.get("height", default_height))
