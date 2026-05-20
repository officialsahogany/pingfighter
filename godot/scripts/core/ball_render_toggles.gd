extends RefCounted

# Diagnostic toggles for ball-only render passes. They are intentionally
# gameplay-neutral: the ball state and hit rewards still update, only the
# matching visual pass is skipped for A/B perf captures. Explicit false env
# values override stale flag files so baseline captures stay clean.

const INTENSITY_EFFECTS_ENV := "PINGFIGHTER_DISABLE_BALL_INTENSITY_EFFECTS"
const INTENSITY_EFFECTS_FLAG := "res://disable_ball_intensity_effects.flag"

const ENERGY_PARTICLES_ENV := "PINGFIGHTER_DISABLE_BALL_ENERGY_PARTICLES"
const ENERGY_PARTICLES_FLAG := "res://disable_ball_energy_particles.flag"

static var _intensity_checked := false
static var _intensity_disabled := false

static var _energy_checked := false
static var _energy_disabled := false


static func is_intensity_effects_disabled() -> bool:
	if _intensity_checked:
		return _intensity_disabled
	_intensity_checked = true
	_intensity_disabled = _read_toggle(INTENSITY_EFFECTS_ENV, INTENSITY_EFFECTS_FLAG)
	return _intensity_disabled


static func is_energy_particles_disabled() -> bool:
	if _energy_checked:
		return _energy_disabled
	_energy_checked = true
	_energy_disabled = _read_toggle(ENERGY_PARTICLES_ENV, ENERGY_PARTICLES_FLAG)
	return _energy_disabled


static func reset_cache_for_test() -> void:
	_intensity_checked = false
	_intensity_disabled = false
	_energy_checked = false
	_energy_disabled = false


static func _read_toggle(env_key: String, flag_path: String) -> bool:
	var value := OS.get_environment(env_key).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]:
		return true
	if value in ["0", "false", "no", "off"]:
		return false
	return FileAccess.file_exists(flag_path)
