extends RefCounted

# Diagnostic override that lets a perf capture switch off the viper air-strike
# flash render (the 18-frame post-hit cyan burst/glow/sparkle/ring that fires
# whenever the player hits the ball while airborne) while leaving every other
# air-strike gameplay effect intact (ball velocity 1.15x boost, gauge bonus,
# gold award, paddle_hit_pulse_kind = "viper_air_strike"). Use this for A/B
# comparison of `proc_after_draw` gap in `air_strike=post_hit:N` windows.
#
# Set the env var `PINGFIGHTER_VIPER_DISABLE_AIR_STRIKE_FLASH=1` (or drop the
# `res://viper_disable_air_strike_flash.flag` file into the project) and the
# next session will leave `air_strike_flash_timer = 0.0` after every hit, so
# `_draw_viper_air_strike_flash` returns immediately and the cached burst /
# glow / sparkle / ring texture draws stop firing. An explicit false env value
# overrides a stale flag file for clean A/B baselines.

const ENV_KEY := "PINGFIGHTER_VIPER_DISABLE_AIR_STRIKE_FLASH"
const FLAG_PATH := "res://viper_disable_air_strike_flash.flag"

static var _checked: bool = false
static var _disabled: bool = false


static func is_disabled() -> bool:
	if _checked:
		return _disabled
	_checked = true
	var value := OS.get_environment(ENV_KEY).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]:
		_disabled = true
	elif value in ["0", "false", "no", "off"]:
		_disabled = false
	else:
		_disabled = FileAccess.file_exists(FLAG_PATH)
	return _disabled


static func reset_cache_for_test() -> void:
	_checked = false
	_disabled = false
