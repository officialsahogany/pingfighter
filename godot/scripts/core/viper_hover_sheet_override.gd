extends RefCounted

# Diagnostic override that lets a perf capture force the viper jetpack into
# its procedural-particle path even when the hover sprite sheet textures are
# present. Set the env var `PINGFIGHTER_VIPER_FORCE_PARTICLE_FX=1` (or drop a
# `res://viper_force_particle_fx.flag` file into the project) and the next
# session will report `has_viper_hover_sheet=false` to the actor renderer and
# `viper_jetpack_hover_sheet_fx=false` to the jetpack state, so the procedural
# particle stream + nozzle pulse are restored. Use this for A/B comparison of
# `draw.frame.battle_scene` calls/prims between hover-sheet and procedural
# paths during airborne sequences.

const ENV_KEY := "PINGFIGHTER_VIPER_FORCE_PARTICLE_FX"
const FLAG_PATH := "res://viper_force_particle_fx.flag"

static var _checked: bool = false
static var _force_disable_hover_sheet: bool = false


static func is_hover_sheet_force_disabled() -> bool:
	if _checked:
		return _force_disable_hover_sheet
	_checked = true
	var value := OS.get_environment(ENV_KEY).strip_edges().to_lower()
	_force_disable_hover_sheet = value in ["1", "true", "yes", "on"] or FileAccess.file_exists(FLAG_PATH)
	return _force_disable_hover_sheet


static func reset_cache_for_test() -> void:
	_checked = false
	_force_disable_hover_sheet = false
