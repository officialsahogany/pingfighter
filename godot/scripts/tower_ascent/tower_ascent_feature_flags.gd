extends RefCounted

const VERTICAL_SLICE_ENV_KEY := "TOWER_ASCENT_VERTICAL_SLICE"

static var _vertical_slice_override: int = -1


static func is_vertical_slice_enabled() -> bool:
	if _vertical_slice_override >= 0:
		return _vertical_slice_override == 1
	var raw_value := OS.get_environment(VERTICAL_SLICE_ENV_KEY).strip_edges().to_lower()
	return raw_value in ["1", "true", "yes", "on"]


static func debug_set_vertical_slice_enabled(enabled: bool) -> void:
	_vertical_slice_override = 1 if enabled else 0


static func debug_clear_vertical_slice_override() -> void:
	_vertical_slice_override = -1
