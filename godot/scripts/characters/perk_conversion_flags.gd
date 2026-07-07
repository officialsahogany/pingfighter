extends RefCounted

static var _enabled: bool = false


static func is_enabled() -> bool:
	return _enabled


static func debug_set_enabled(value: bool) -> void:
	_enabled = bool(value)
