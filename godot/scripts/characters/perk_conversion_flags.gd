extends RefCounted

static var _enabled: bool = false


static func is_enabled() -> bool:
	return _enabled


# Production runtime enable. Called once at app boot (boot_flow_scene._ready)
# so the passive->perk conversion is live in-game while the compile-time
# default stays OFF (keeps legacy item-path smokes unaffected by the default).
static func set_enabled(value: bool) -> void:
	_enabled = bool(value)


# Test-only alias; smokes toggle the flag per-leg via this entry point.
static func debug_set_enabled(value: bool) -> void:
	set_enabled(value)
