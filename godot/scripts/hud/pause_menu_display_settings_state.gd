extends RefCounted

const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := "exclusive_fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"

const RENDER_FPS_CAP_UNLIMITED := 0
const RENDER_FPS_CAP_STABILITY := 48
const RENDER_FPS_CAP_SMOOTH := 60
const RENDER_FPS_CAP_BALANCED := 72
const RENDER_FPS_CAP_MONITOR := -1
const RENDER_FPS_CAP_STABLE_MONITOR := -2
const RENDER_FPS_CAP_DEFAULT := RENDER_FPS_CAP_STABLE_MONITOR

const VSYNC_MODE_AUTO := -1
const VSYNC_MODE_DISABLED := 0
const VSYNC_MODE_ENABLED := 1
const VSYNC_MODE_MAILBOX := 3

var display_mode := DISPLAY_MODE_WINDOWED
var remember_display_mode := false
var auto_refresh_rate_60hz := false
var render_fps_cap := RENDER_FPS_CAP_DEFAULT
var vsync_mode := VSYNC_MODE_AUTO
var preference_dirty := false

var _synced_display_mode := DISPLAY_MODE_WINDOWED
var _synced_remember_display_mode := false
var _synced_auto_refresh_rate_60hz := false


static func normalize_display_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower()
	if normalized == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN or normalized == "exclusive":
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized == DISPLAY_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


func select_display_mode(mode: String) -> bool:
	var normalized := normalize_display_mode(mode)
	if normalized == display_mode:
		return false
	display_mode = normalized
	preference_dirty = true
	return true


func cycle_display_mode(direction: int) -> bool:
	var options: Array[String] = [
		DISPLAY_MODE_FULLSCREEN,
		DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		DISPLAY_MODE_WINDOWED,
	]
	var index := options.find(display_mode)
	if index < 0:
		index = 0
	var step := 1 if direction >= 0 else -1
	return select_display_mode(options[(index + step + options.size()) % options.size()])


func cycle_render_fps_cap(options: Array[int], direction: int) -> bool:
	if options.is_empty():
		return false
	var previous_cap := render_fps_cap
	render_fps_cap = _cycle_int_option(render_fps_cap, options, direction)
	return render_fps_cap != previous_cap


func cycle_vsync_mode(options: Array[int], direction: int) -> bool:
	if options.is_empty():
		return false
	var previous_mode := vsync_mode
	vsync_mode = _cycle_int_option(vsync_mode, options, direction)
	return vsync_mode != previous_mode


func toggle_remember_display_mode() -> void:
	remember_display_mode = not remember_display_mode
	preference_dirty = true


func toggle_auto_refresh_rate() -> void:
	auto_refresh_rate_60hz = not auto_refresh_rate_60hz
	preference_dirty = true


func reset_factory() -> void:
	display_mode = DISPLAY_MODE_WINDOWED
	render_fps_cap = RENDER_FPS_CAP_DEFAULT
	vsync_mode = VSYNC_MODE_AUTO
	remember_display_mode = false
	auto_refresh_rate_60hz = false
	preference_dirty = true


func apply_recommended() -> void:
	display_mode = DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	remember_display_mode = true
	render_fps_cap = RENDER_FPS_CAP_STABLE_MONITOR
	vsync_mode = VSYNC_MODE_AUTO
	auto_refresh_rate_60hz = false
	preference_dirty = true


func sync_baseline() -> void:
	_synced_display_mode = display_mode
	_synced_remember_display_mode = remember_display_mode
	_synced_auto_refresh_rate_60hz = auto_refresh_rate_60hz
	preference_dirty = false


func mark_auto_refresh_saved(enabled: bool) -> void:
	auto_refresh_rate_60hz = enabled
	_synced_auto_refresh_rate_60hz = enabled


func should_save_display() -> bool:
	return (
		preference_dirty
		or display_mode != _synced_display_mode
		or remember_display_mode != _synced_remember_display_mode
		or auto_refresh_rate_60hz != _synced_auto_refresh_rate_60hz
		or remember_display_mode
		or display_mode != DISPLAY_MODE_WINDOWED
	)


func get_status() -> Dictionary:
	return {
		"display_mode": display_mode,
		"remember_display_mode": remember_display_mode,
		"auto_refresh_rate_60hz": auto_refresh_rate_60hz,
		"render_fps_cap": render_fps_cap,
		"vsync_mode": vsync_mode,
		"preference_dirty": preference_dirty,
		"synced_display_mode": _synced_display_mode,
		"synced_remember_display_mode": _synced_remember_display_mode,
		"synced_auto_refresh_rate_60hz": _synced_auto_refresh_rate_60hz,
	}


func _cycle_int_option(current_value: int, options: Array[int], direction: int) -> int:
	var index := options.find(current_value)
	if index < 0:
		index = 0
	var step := 1 if direction >= 0 else -1
	return int(options[(index + step + options.size()) % options.size()])
