extends RefCounted

const SETTINGS_PATH := "user://input_settings.cfg"
const SETTINGS_SCHEMA_VERSION := 1
const SETTINGS_SECTION := "input"
const SETTINGS_SCHEMA_KEY := "schema_version"
const SETTINGS_VIBRATION_LEVEL_KEY := "gamepad_vibration_level"

const VIBRATION_LEVEL_MIN := 1
const VIBRATION_LEVEL_MAX := 5
const VIBRATION_LEVEL_DEFAULT := 3
const VIBRATION_LEVEL_NAMES := ["약함", "낮음", "보통", "강함", "최대"]
const VIBRATION_MOTOR_SCALES := [0.45, 0.70, 1.0, 1.20, 1.40]
const VIBRATION_DURATION_SCALES := [0.75, 0.88, 1.0, 1.08, 1.15]

static var _cached_vibration_level := 0


static func get_vibration_level() -> int:
	if _cached_vibration_level >= VIBRATION_LEVEL_MIN:
		return _cached_vibration_level
	var config := _load_settings()
	_cached_vibration_level = normalize_vibration_level(
		int(config.get_value(SETTINGS_SECTION, SETTINGS_VIBRATION_LEVEL_KEY, VIBRATION_LEVEL_DEFAULT))
	)
	return _cached_vibration_level


static func set_vibration_level(level: int) -> int:
	var normalized := normalize_vibration_level(level)
	_cached_vibration_level = normalized
	var config := _load_settings()
	config.set_value(SETTINGS_SECTION, SETTINGS_SCHEMA_KEY, SETTINGS_SCHEMA_VERSION)
	config.set_value(SETTINGS_SECTION, SETTINGS_VIBRATION_LEVEL_KEY, normalized)
	if config.save(SETTINGS_PATH) != OK:
		return normalized
	return normalized


static func adjust_vibration_level(delta: int) -> int:
	return set_vibration_level(get_vibration_level() + delta)


static func normalize_vibration_level(level: int) -> int:
	return clampi(level, VIBRATION_LEVEL_MIN, VIBRATION_LEVEL_MAX)


static func get_vibration_level_label(level: int = 0) -> String:
	var normalized := get_vibration_level() if level < VIBRATION_LEVEL_MIN else normalize_vibration_level(level)
	var name := str(VIBRATION_LEVEL_NAMES[normalized - VIBRATION_LEVEL_MIN])
	return "%d / %d %s" % [normalized, VIBRATION_LEVEL_MAX, name]


static func get_vibration_motor_scale(level: int = 0) -> float:
	var normalized := get_vibration_level() if level < VIBRATION_LEVEL_MIN else normalize_vibration_level(level)
	return float(VIBRATION_MOTOR_SCALES[normalized - VIBRATION_LEVEL_MIN])


static func get_vibration_duration_scale(level: int = 0) -> float:
	var normalized := get_vibration_level() if level < VIBRATION_LEVEL_MIN else normalize_vibration_level(level)
	return float(VIBRATION_DURATION_SCALES[normalized - VIBRATION_LEVEL_MIN])


static func apply_vibration_sensitivity(vibration: Dictionary, level: int = 0) -> Dictionary:
	if vibration.is_empty():
		return {}
	var normalized := get_vibration_level() if level < VIBRATION_LEVEL_MIN else normalize_vibration_level(level)
	var motor_scale := get_vibration_motor_scale(normalized)
	var duration_scale := get_vibration_duration_scale(normalized)
	var scaled := vibration.duplicate(true)
	scaled["weak"] = clampf(float(scaled.get("weak", 0.0)) * motor_scale, 0.0, 1.0)
	scaled["strong"] = clampf(float(scaled.get("strong", 0.0)) * motor_scale, 0.0, 1.0)
	scaled["duration"] = max(0.0, float(scaled.get("duration", 0.0)) * duration_scale)
	scaled["vibration_level"] = normalized
	scaled["vibration_scale"] = motor_scale
	return scaled


static func _load_settings() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH):
		var result := config.load(SETTINGS_PATH)
		if result != OK:
			return ConfigFile.new()
	return config
