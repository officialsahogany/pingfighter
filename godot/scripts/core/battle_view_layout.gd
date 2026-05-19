extends RefCounted

const VIEW_WIDTH := 1488.0
const VIEW_HEIGHT := 918.0
const WINDOW_TARGET_HEIGHT_RATIO := 0.865
const WINDOW_TARGET_WIDTH_RATIO := 0.90
const GAME_RENDER_MARGIN_Y_RATIO := 0.065
const GAME_RENDER_MIN_MARGIN_Y := 30.0
const MOBILE_SAFE_MARGIN_MIN := 8.0
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := "exclusive_fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"
const SETTINGS_PATH := "user://display_settings.cfg"
const SETTINGS_SCHEMA_VERSION := 3
const RENDER_FPS_CAP_UNLIMITED := 0
const RENDER_FPS_CAP_STABILITY := 48
const RENDER_FPS_CAP_SMOOTH := 60
const RENDER_FPS_CAP_BALANCED := 72
const RENDER_FPS_CAP_DEFAULT := RENDER_FPS_CAP_STABILITY
const RENDER_FPS_CAP_MONITOR := -1
const RENDER_FPS_CAP_STABLE_MONITOR := -2
const RENDER_FPS_CAP_STABLE_MAX := 90
const RENDER_FPS_CAP_STABLE_MIN := 45
const RENDER_FPS_CAP_STABLE_PREFERRED_MAX := 60
const RENDER_FPS_DRIVER_PRESENT_MIN_HZ := 120
const VSYNC_MODE_AUTO := -1
const VSYNC_MODE_OPTIONS: Array[int] = [
	VSYNC_MODE_AUTO,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_MAILBOX,
	DisplayServer.VSYNC_DISABLED,
]
const RENDER_FPS_CAP_OPTIONS: Array[int] = [
	RENDER_FPS_CAP_UNLIMITED,
	RENDER_FPS_CAP_STABILITY,
	RENDER_FPS_CAP_SMOOTH,
	RENDER_FPS_CAP_BALANCED,
	RENDER_FPS_CAP_STABLE_MONITOR,
	RENDER_FPS_CAP_MONITOR,
]

var _last_windowed_size := Vector2i.ZERO
var _last_windowed_position := Vector2i.ZERO
static var _runtime_render_fps_cap := RENDER_FPS_CAP_DEFAULT
static var _configure_window_count := 0
static var _last_configure_window_summary := "not_called"
static var _last_settings_save_summary := "not_saved"


func configure_window(window: Window) -> void:
	if window == null:
		return
	_configure_window_count += 1
	var can_manage_window := _can_manage_os_window()
	var saved_display_mode := get_saved_display_mode()
	var remember_display_mode := get_remember_display_mode()
	var saved_vsync_mode: int = get_saved_vsync_mode()
	var saved_render_cap: int = get_saved_render_fps_cap()
	if can_manage_window:
		if remember_display_mode:
			apply_display_mode(window, saved_display_mode)
		elif not is_fullscreen(window):
			var target_rect := _build_default_window_rect()
			if target_rect.size.x > 0 and target_rect.size.y > 0:
				window.size = target_rect.size
				window.position = target_rect.position
				_remember_windowed_geometry(window)
	apply_render_fps_cap(window, saved_render_cap, saved_vsync_mode)
	apply_vsync_mode(saved_vsync_mode, window)
	_last_configure_window_summary = "count=%d can_manage=%s saved_window=%s remember=%s saved_cap=%s saved_vsync=%s actual_window=%s actual_vsync=%s" % [
		_configure_window_count,
		"on" if can_manage_window else "off",
		saved_display_mode,
		"on" if remember_display_mode else "off",
		str(get_render_fps_cap_label(saved_render_cap, window)).replace(" ", "_"),
		get_vsync_mode_label(saved_vsync_mode).replace(" ", "_"),
		get_display_mode(window),
		get_vsync_mode_label(get_vsync_mode()).replace(" ", "_"),
	]


func toggle_fullscreen(window: Window) -> void:
	if window == null:
		return
	if not _can_manage_os_window():
		return
	var new_mode: String
	if is_fullscreen(window):
		apply_display_mode(window, DISPLAY_MODE_WINDOWED)
		new_mode = DISPLAY_MODE_WINDOWED
	else:
		apply_display_mode(window, DISPLAY_MODE_FULLSCREEN)
		new_mode = DISPLAY_MODE_FULLSCREEN
	# When the user has opted into "remember display mode," keep the saved
	# preference in sync with the runtime toggle so subsequent scene
	# transitions (configure_window) don't bounce the window back to the
	# previously persisted mode.
	if get_remember_display_mode():
		save_display_mode_default(new_mode, true)


func apply_display_mode(window: Window, mode: String) -> String:
	var normalized_mode := _normalize_display_mode(mode)
	if window == null:
		return normalized_mode
	if not _can_manage_os_window():
		return get_display_mode(window)
	if normalized_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN:
		if window.mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
			_remember_windowed_geometry(window)
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized_mode == DISPLAY_MODE_FULLSCREEN:
		if window.mode != Window.MODE_FULLSCREEN:
			_remember_windowed_geometry(window)
			window.mode = Window.MODE_FULLSCREEN
		return DISPLAY_MODE_FULLSCREEN
	_restore_windowed(window)
	return DISPLAY_MODE_WINDOWED


func get_display_mode(window: Window) -> String:
	if window == null:
		return DISPLAY_MODE_WINDOWED
	if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if window.mode == Window.MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


func get_remember_display_mode() -> bool:
	var config := _load_display_settings()
	if config.has_section_key("graphics", "remember_display_mode"):
		return bool(config.get_value("graphics", "remember_display_mode", false))
	var saved_mode := _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))
	return saved_mode != DISPLAY_MODE_WINDOWED


func get_saved_display_mode() -> String:
	var config := _load_display_settings()
	return _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))


func save_display_mode_default(mode: String, remember_default: bool) -> bool:
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	var normalized_mode := _normalize_display_mode(mode)
	if normalized_mode != DISPLAY_MODE_WINDOWED:
		remember_default = true
	config.set_value("graphics", "remember_display_mode", remember_default)
	if remember_default:
		config.set_value("graphics", "display_mode", normalized_mode)
	elif config.has_section_key("graphics", "display_mode"):
		config.erase_section_key("graphics", "display_mode")
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("display", config, result)
	return result == OK


func get_render_fps_cap(window: Window = null) -> int:
	var current_cap: int = int(Engine.get("max_fps"))
	var runtime_cap: int = get_runtime_render_fps_cap()
	if current_cap <= 0:
		if _should_use_driver_present_for_cap(window, runtime_cap, get_saved_vsync_mode()):
			return runtime_cap
		return RENDER_FPS_CAP_UNLIMITED
	var saved_cap: int = get_saved_render_fps_cap()
	if saved_cap == RENDER_FPS_CAP_STABLE_MONITOR and current_cap == _get_stable_monitor_refresh_rate(window):
		return RENDER_FPS_CAP_STABLE_MONITOR
	if saved_cap == RENDER_FPS_CAP_MONITOR and current_cap == _get_monitor_refresh_rate(window):
		return RENDER_FPS_CAP_MONITOR
	return current_cap


func get_saved_render_fps_cap() -> int:
	var config := _load_display_settings()
	var default_cap: int = int(ProjectSettings.get_setting("application/run/max_fps", RENDER_FPS_CAP_DEFAULT))
	return _normalize_render_fps_cap(int(config.get_value("graphics", "render_fps_cap", default_cap)))


func get_render_fps_cap_options() -> Array[int]:
	return RENDER_FPS_CAP_OPTIONS.duplicate()


func apply_render_fps_cap(window: Window, cap: int, vsync_mode: int = VSYNC_MODE_AUTO) -> int:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	_runtime_render_fps_cap = normalized_cap
	Engine.set("max_fps", _resolve_render_fps_cap(window, normalized_cap, vsync_mode))
	return normalized_cap


static func get_runtime_render_fps_cap() -> int:
	return _runtime_render_fps_cap


static func get_configure_window_summary() -> String:
	return _last_configure_window_summary


static func get_settings_save_summary() -> String:
	return _last_settings_save_summary


func save_render_fps_cap_default(cap: int) -> bool:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	_runtime_render_fps_cap = normalized_cap
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	config.set_value("graphics", "render_fps_cap", normalized_cap)
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("render_cap", config, result)
	return result == OK


func get_vsync_mode() -> int:
	return _normalize_vsync_mode(int(DisplayServer.window_get_vsync_mode()))


func get_saved_vsync_mode() -> int:
	var config := _load_display_settings()
	return _normalize_vsync_mode(int(config.get_value("graphics", "vsync_mode", VSYNC_MODE_AUTO)))


func get_vsync_mode_options() -> Array[int]:
	return VSYNC_MODE_OPTIONS.duplicate()


func apply_vsync_mode(mode: int, window: Window = null) -> int:
	var normalized_mode: int = _normalize_vsync_mode(mode)
	DisplayServer.window_set_vsync_mode(_resolve_vsync_mode(window, normalized_mode))
	return normalized_mode


func save_vsync_mode_default(mode: int) -> bool:
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	config.set_value("graphics", "vsync_mode", _normalize_vsync_mode(mode))
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("vsync", config, result)
	return result == OK


func get_vsync_mode_label(mode: int) -> String:
	var normalized_mode: int = _normalize_vsync_mode(mode)
	if normalized_mode == VSYNC_MODE_AUTO:
		return "Auto"
	if normalized_mode == DisplayServer.VSYNC_DISABLED:
		return "VSync Off"
	if normalized_mode == DisplayServer.VSYNC_ADAPTIVE:
		return "Adaptive"
	if normalized_mode == DisplayServer.VSYNC_MAILBOX:
		return "Mailbox"
	return "VSync On"


func get_render_fps_cap_label(cap: int, window: Window = null) -> String:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	if normalized_cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return "Stable %d FPS" % _get_stable_monitor_refresh_rate(window)
	if normalized_cap == RENDER_FPS_CAP_UNLIMITED:
		return "제한 없음"
	if normalized_cap == RENDER_FPS_CAP_MONITOR:
		return "%d Hz" % _get_monitor_refresh_rate(window)
	return "%d FPS" % normalized_cap


func is_fullscreen(window: Window) -> bool:
	if window == null:
		return false
	return window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func _normalize_display_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower()
	if normalized == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN or normalized == "exclusive":
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized == DISPLAY_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


func _normalize_render_fps_cap(cap: int) -> int:
	if cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return RENDER_FPS_CAP_STABLE_MONITOR
	if cap == RENDER_FPS_CAP_MONITOR:
		return RENDER_FPS_CAP_MONITOR
	if cap <= 0:
		return RENDER_FPS_CAP_UNLIMITED
	return max(1, cap)


func _normalize_vsync_mode(mode: int) -> int:
	if mode == VSYNC_MODE_AUTO:
		return VSYNC_MODE_AUTO
	if mode == DisplayServer.VSYNC_DISABLED:
		return DisplayServer.VSYNC_DISABLED
	if mode == DisplayServer.VSYNC_MAILBOX:
		return DisplayServer.VSYNC_MAILBOX
	if mode == DisplayServer.VSYNC_ADAPTIVE:
		return DisplayServer.VSYNC_ADAPTIVE
	return DisplayServer.VSYNC_ENABLED


func _resolve_render_fps_cap(window: Window, cap: int, vsync_mode: int = VSYNC_MODE_AUTO) -> int:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	if normalized_cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return _get_stable_monitor_refresh_rate(window)
	if normalized_cap == RENDER_FPS_CAP_MONITOR:
		return _get_monitor_refresh_rate(window)
	if _should_use_driver_present_for_cap(window, normalized_cap, vsync_mode):
		return RENDER_FPS_CAP_UNLIMITED
	return normalized_cap


func _should_use_driver_present_for_cap(window: Window, cap: int, vsync_mode: int = VSYNC_MODE_AUTO) -> bool:
	var normalized_vsync: int = _normalize_vsync_mode(vsync_mode)
	var can_delegate_present: bool = (
		normalized_vsync == VSYNC_MODE_AUTO
		or normalized_vsync == DisplayServer.VSYNC_ADAPTIVE
	)
	return (
		_normalize_render_fps_cap(cap) == RENDER_FPS_CAP_BALANCED
		and can_delegate_present
		and _get_monitor_refresh_rate(window) >= RENDER_FPS_DRIVER_PRESENT_MIN_HZ
	)


func _resolve_vsync_mode(window: Window, mode: int) -> int:
	var normalized_mode: int = _normalize_vsync_mode(mode)
	if normalized_mode != VSYNC_MODE_AUTO:
		return normalized_mode
	var render_cap: int = int(Engine.get("max_fps"))
	if render_cap <= 0 and _should_use_driver_present_for_cap(window, get_runtime_render_fps_cap(), normalized_mode):
		return DisplayServer.VSYNC_ADAPTIVE
	if render_cap > 0 and render_cap < _get_monitor_refresh_rate(window):
		return DisplayServer.VSYNC_DISABLED
	return DisplayServer.VSYNC_ENABLED


func _get_monitor_refresh_rate(window: Window = null) -> int:
	var screen_index: int = DisplayServer.SCREEN_OF_MAIN_WINDOW
	if window != null:
		screen_index = window.current_screen
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate(screen_index)
	if refresh_rate <= 0.0:
		refresh_rate = 60.0
	return max(30, int(round(refresh_rate)))


func _get_stable_monitor_refresh_rate(window: Window = null) -> int:
	var monitor_rate: int = _get_monitor_refresh_rate(window)
	if monitor_rate <= RENDER_FPS_CAP_STABLE_MAX:
		return monitor_rate
	# Prefer divisors with enough headroom to avoid near-budget VSync misses.
	for divisor in range(2, 9):
		if monitor_rate % divisor != 0:
			continue
		@warning_ignore("integer_division")
		var candidate: int = monitor_rate / divisor
		if candidate <= RENDER_FPS_CAP_STABLE_PREFERRED_MAX and candidate >= RENDER_FPS_CAP_STABLE_MIN:
			return candidate
	for divisor in range(2, 9):
		if monitor_rate % divisor != 0:
			continue
		@warning_ignore("integer_division")
		var candidate: int = monitor_rate / divisor
		if candidate <= RENDER_FPS_CAP_STABLE_MAX and candidate >= RENDER_FPS_CAP_STABLE_MIN:
			return candidate
	return min(RENDER_FPS_CAP_DEFAULT, monitor_rate)


func _load_display_settings() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH):
		var result := config.load(SETTINGS_PATH)
		if result != OK:
			return ConfigFile.new()
		_migrate_display_settings(config)
	return config


func _migrate_display_settings(config: ConfigFile) -> void:
	var version: int = int(config.get_value("meta", "settings_schema_version", 0))
	if version >= SETTINGS_SCHEMA_VERSION:
		return
	var changed := false
	if version < 2 and config.has_section_key("graphics", "render_fps_cap"):
		var saved_cap: int = _normalize_render_fps_cap(int(config.get_value(
			"graphics",
			"render_fps_cap",
			RENDER_FPS_CAP_DEFAULT
		)))
		if saved_cap == RENDER_FPS_CAP_BALANCED:
			config.set_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
			changed = true
	if version < 3 and not config.has_section_key("graphics", "remember_display_mode"):
		var saved_display_mode := _normalize_display_mode(str(config.get_value(
			"graphics",
			"display_mode",
			DISPLAY_MODE_WINDOWED
		)))
		if saved_display_mode != DISPLAY_MODE_WINDOWED:
			config.set_value("graphics", "remember_display_mode", true)
			changed = true
	_stamp_display_settings_schema(config)
	changed = true
	if changed:
		var result := config.save(SETTINGS_PATH)
		_record_settings_save("migrate", config, result)


func _stamp_display_settings_schema(config: ConfigFile) -> void:
	config.set_value("meta", "settings_schema_version", SETTINGS_SCHEMA_VERSION)


func _record_settings_save(reason: String, config: ConfigFile, result: int) -> void:
	var saved_mode := _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))
	var remember := bool(config.get_value("graphics", "remember_display_mode", false))
	var saved_cap := _normalize_render_fps_cap(int(config.get_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)))
	var saved_vsync := _normalize_vsync_mode(int(config.get_value("graphics", "vsync_mode", VSYNC_MODE_AUTO)))
	_last_settings_save_summary = "%s_ok=%s_window=%s_remember=%s_cap=%s_vsync=%s" % [
		reason,
		"on" if result == OK else "off",
		saved_mode,
		"on" if remember else "off",
		str(get_render_fps_cap_label(saved_cap, null)).replace(" ", "_"),
		get_vsync_mode_label(saved_vsync).replace(" ", "_"),
	]


func _build_default_window_rect() -> Rect2i:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return Rect2i()

	var width_scale: float = (float(usable_rect.size.x) * WINDOW_TARGET_WIDTH_RATIO) / VIEW_WIDTH
	var height_scale: float = (float(usable_rect.size.y) * WINDOW_TARGET_HEIGHT_RATIO) / VIEW_HEIGHT
	var target_scale: float = min(width_scale, height_scale)
	if target_scale <= 0.0:
		return Rect2i()

	var target_size := Vector2i(
		int(round(VIEW_WIDTH * target_scale)),
		int(round(VIEW_HEIGHT * target_scale))
	)
	@warning_ignore("integer_division")
	var target_position := usable_rect.position + (usable_rect.size - target_size) / 2
	return Rect2i(target_position, target_size)


func _remember_windowed_geometry(window: Window) -> void:
	if window == null or is_fullscreen(window):
		return
	if window.size.x <= 0 or window.size.y <= 0:
		return
	_last_windowed_size = window.size
	_last_windowed_position = window.position


func _restore_windowed(window: Window) -> void:
	window.mode = Window.MODE_WINDOWED
	if _last_windowed_size.x <= 0 or _last_windowed_size.y <= 0:
		var target_rect := _build_default_window_rect()
		if target_rect.size.x <= 0 or target_rect.size.y <= 0:
			return
		_last_windowed_size = target_rect.size
		_last_windowed_position = target_rect.position
	window.size = _last_windowed_size
	window.position = _last_windowed_position


func build_game_layout(view_size: Vector2, game_width: float, game_height: float) -> Dictionary:
	var layout_rect: Rect2 = _build_layout_rect(view_size)
	if game_width <= 0.0 or game_height <= 0.0:
		return {
			"view_size": view_size,
			"safe_rect": layout_rect,
			"game_offset": Vector2.ZERO,
			"game_size": Vector2.ZERO,
			"render_scale": 1.0,
		}

	var render_margin_y: float = _get_render_margin_y(layout_rect)
	var available_height: float = max(1.0, layout_rect.size.y - render_margin_y * 2.0)
	var available_width: float = max(1.0, layout_rect.size.x)
	var render_scale: float = min(available_width / game_width, available_height / game_height)
	var game_size := Vector2(game_width * render_scale, game_height * render_scale)
	var game_offset := layout_rect.position + Vector2(
		(layout_rect.size.x - game_size.x) * 0.5,
		(layout_rect.size.y - game_size.y) * 0.5
	)
	return {
		"view_size": view_size,
		"safe_rect": layout_rect,
		"game_offset": game_offset,
		"game_size": game_size,
		"render_scale": render_scale,
	}


func _get_render_margin_y(layout_rect: Rect2) -> float:
	if _is_mobile_runtime():
		return 0.0
	return max(floor(layout_rect.size.y * GAME_RENDER_MARGIN_Y_RATIO), GAME_RENDER_MIN_MARGIN_Y)


func _build_layout_rect(view_size: Vector2) -> Rect2:
	var fallback := Rect2(Vector2.ZERO, view_size)
	if not _is_mobile_runtime():
		return fallback
	var safe_rect: Rect2 = _get_scaled_display_safe_rect(view_size)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return fallback.grow_individual(
			-MOBILE_SAFE_MARGIN_MIN,
			-MOBILE_SAFE_MARGIN_MIN,
			-MOBILE_SAFE_MARGIN_MIN,
			-MOBILE_SAFE_MARGIN_MIN
		)
	return safe_rect.intersection(fallback)


func _get_scaled_display_safe_rect(view_size: Vector2) -> Rect2:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Rect2()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return Rect2(Vector2(safe_area.position), Vector2(safe_area.size))
	var scale := Vector2(
		view_size.x / float(window_size.x),
		view_size.y / float(window_size.y)
	)
	return Rect2(
		Vector2(safe_area.position) * scale,
		Vector2(safe_area.size) * scale
	)


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _can_manage_os_window() -> bool:
	if _is_mobile_runtime():
		return false
	# Godot editor game embedding owns the host window; moving or switching it
	# prints "Embedded window can't be moved" and fullscreen mode is unsupported.
	return not Engine.is_embedded_in_editor()
