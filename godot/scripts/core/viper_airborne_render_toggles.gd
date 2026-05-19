extends RefCounted

# Diagnostic toggles that let a perf capture switch off individual viper
# airborne-only render passes one at a time. Use these to attribute the +150
# draw-call jump during sustained jetpack glide to a specific section by
# comparing `calls=N` in the perf log between baseline and each toggle on.
#
# Godot's `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` is only refreshed at
# frame end, so it cannot be sampled mid-frame to subdivide draw-call cost.
# Disabling one renderer section at a time and reading the frame-total calls
# difference is the accurate replacement.
#
# Each toggle is independent. They are all defaults-off; set the env var to a
# true value (or drop the matching flag file) and the section becomes a no-op.
# Setting the env var to an explicit false value wins over any stale flag file
# so automated A/B captures can force a clean baseline.

const HOVER_EMBERS_ENV := "PINGFIGHTER_VIPER_DISABLE_HOVER_EMBERS"
const HOVER_EMBERS_FLAG := "res://viper_disable_hover_embers.flag"

const HOLD_BAR_ENV := "PINGFIGHTER_VIPER_DISABLE_JETPACK_HOLD_BAR"
const HOLD_BAR_FLAG := "res://viper_disable_jetpack_hold_bar.flag"

const HOVER_SHEET_DRAW_ENV := "PINGFIGHTER_VIPER_DISABLE_HOVER_SHEET_DRAW"
const HOVER_SHEET_DRAW_FLAG := "res://viper_disable_hover_sheet_draw.flag"

static var _hover_embers_checked: bool = false
static var _hover_embers_disabled: bool = false

static var _hold_bar_checked: bool = false
static var _hold_bar_disabled: bool = false

static var _hover_sheet_draw_checked: bool = false
static var _hover_sheet_draw_disabled: bool = false


static func is_hover_embers_disabled() -> bool:
	if _hover_embers_checked:
		return _hover_embers_disabled
	_hover_embers_checked = true
	_hover_embers_disabled = _read_toggle(HOVER_EMBERS_ENV, HOVER_EMBERS_FLAG)
	return _hover_embers_disabled


static func is_hold_bar_disabled() -> bool:
	if _hold_bar_checked:
		return _hold_bar_disabled
	_hold_bar_checked = true
	_hold_bar_disabled = _read_toggle(HOLD_BAR_ENV, HOLD_BAR_FLAG)
	return _hold_bar_disabled


static func is_hover_sheet_draw_disabled() -> bool:
	if _hover_sheet_draw_checked:
		return _hover_sheet_draw_disabled
	_hover_sheet_draw_checked = true
	_hover_sheet_draw_disabled = _read_toggle(HOVER_SHEET_DRAW_ENV, HOVER_SHEET_DRAW_FLAG)
	return _hover_sheet_draw_disabled


static func reset_cache_for_test() -> void:
	_hover_embers_checked = false
	_hover_embers_disabled = false
	_hold_bar_checked = false
	_hold_bar_disabled = false
	_hover_sheet_draw_checked = false
	_hover_sheet_draw_disabled = false


static func _read_toggle(env_key: String, flag_path: String) -> bool:
	var value := OS.get_environment(env_key).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]:
		return true
	if value in ["0", "false", "no", "off"]:
		return false
	return FileAccess.file_exists(flag_path)
