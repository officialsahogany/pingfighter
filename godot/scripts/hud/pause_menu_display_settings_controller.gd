extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuDisplaySettingsState := preload("res://scripts/hud/pause_menu_display_settings_state.gd")

const DISPLAY_MODE_FULLSCREEN := PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
const DISPLAY_MODE_WINDOWED := PauseMenuDisplaySettingsState.DISPLAY_MODE_WINDOWED
const RENDER_FPS_CAP_UNLIMITED := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_UNLIMITED
const RENDER_FPS_CAP_STABILITY := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABILITY
const RENDER_FPS_CAP_SMOOTH := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_SMOOTH
const RENDER_FPS_CAP_BALANCED := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_BALANCED
const RENDER_FPS_CAP_MONITOR := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_MONITOR
const RENDER_FPS_CAP_STABLE_MONITOR := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABLE_MONITOR
const VSYNC_MODE_AUTO := PauseMenuDisplaySettingsState.VSYNC_MODE_AUTO
const VSYNC_MODE_DISABLED := PauseMenuDisplaySettingsState.VSYNC_MODE_DISABLED
const VSYNC_MODE_ENABLED := PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED
const VSYNC_MODE_MAILBOX := PauseMenuDisplaySettingsState.VSYNC_MODE_MAILBOX

var state: PauseMenuDisplaySettingsState


func _init(display_settings_state: PauseMenuDisplaySettingsState = null) -> void:
	state = display_settings_state if display_settings_state != null else PauseMenuDisplaySettingsState.new()


func cycle_render_fps_cap(direction: int, owner: Object, registry: Object) -> void:
	state.cycle_render_fps_cap(get_render_fps_cap_options(registry), direction)
	var view_layout := _get_view_layout(registry)
	var window := get_owner_window(owner)
	if view_layout != null and view_layout.has_method("apply_render_fps_cap"):
		state.render_fps_cap = int(view_layout.apply_render_fps_cap(window, state.render_fps_cap, state.vsync_mode))
	if state.vsync_mode == VSYNC_MODE_AUTO and view_layout != null and view_layout.has_method("apply_vsync_mode"):
		state.vsync_mode = int(view_layout.apply_vsync_mode(state.vsync_mode, window))


func cycle_vsync_mode(direction: int, owner: Object, registry: Object) -> void:
	state.cycle_vsync_mode(get_vsync_mode_options(registry), direction)
	var view_layout := _get_view_layout(registry)
	var window := get_owner_window(owner)
	if view_layout != null and view_layout.has_method("apply_vsync_mode"):
		state.vsync_mode = int(view_layout.apply_vsync_mode(state.vsync_mode, window))
	if view_layout != null and view_layout.has_method("apply_render_fps_cap"):
		state.render_fps_cap = int(view_layout.apply_render_fps_cap(window, state.render_fps_cap, state.vsync_mode))


func sync(owner: Object, registry: Object) -> void:
	var view_layout := _get_view_layout(registry)
	var window := get_owner_window(owner)
	if view_layout != null and view_layout.has_method("get_remember_display_mode"):
		state.remember_display_mode = bool(view_layout.get_remember_display_mode())
	if view_layout != null and view_layout.has_method("get_display_mode"):
		if state.remember_display_mode and view_layout.has_method("get_saved_display_mode"):
			state.display_mode = PauseMenuDisplaySettingsState.normalize_display_mode(str(view_layout.get_saved_display_mode()))
		else:
			state.display_mode = PauseMenuDisplaySettingsState.normalize_display_mode(str(view_layout.get_display_mode(window)))
	elif view_layout != null and view_layout.has_method("is_fullscreen"):
		state.display_mode = DISPLAY_MODE_FULLSCREEN if bool(view_layout.is_fullscreen(window)) else DISPLAY_MODE_WINDOWED
	if view_layout != null and view_layout.has_method("get_saved_render_fps_cap"):
		state.render_fps_cap = int(view_layout.get_saved_render_fps_cap())
	elif view_layout != null and view_layout.has_method("get_render_fps_cap"):
		state.render_fps_cap = int(view_layout.get_render_fps_cap(window))
	if view_layout != null and view_layout.has_method("get_saved_vsync_mode"):
		state.vsync_mode = int(view_layout.get_saved_vsync_mode())
	elif view_layout != null and view_layout.has_method("get_vsync_mode"):
		state.vsync_mode = int(view_layout.get_vsync_mode())
	if view_layout != null and view_layout.has_method("get_auto_refresh_rate_enabled"):
		state.auto_refresh_rate_60hz = bool(view_layout.get_auto_refresh_rate_enabled())
	state.sync_baseline()


func save(owner: Object, registry: Object) -> void:
	state.display_mode = PauseMenuDisplaySettingsState.normalize_display_mode(state.display_mode)
	var view_layout := _get_view_layout(registry)
	var window := get_owner_window(owner)
	if state.should_save_display():
		if view_layout != null and view_layout.has_method("apply_display_mode"):
			state.display_mode = PauseMenuDisplaySettingsState.normalize_display_mode(str(view_layout.apply_display_mode(window, state.display_mode)))
		elif view_layout != null and view_layout.has_method("toggle_fullscreen"):
			var current_mode := DISPLAY_MODE_WINDOWED
			if view_layout.has_method("get_display_mode"):
				current_mode = PauseMenuDisplaySettingsState.normalize_display_mode(str(view_layout.get_display_mode(window)))
			if current_mode != state.display_mode:
				view_layout.toggle_fullscreen(window)
		if view_layout != null and view_layout.has_method("save_display_mode_default"):
			view_layout.save_display_mode_default(state.display_mode, state.remember_display_mode)
		state.sync_baseline()
	if view_layout != null and view_layout.has_method("apply_render_fps_cap"):
		state.render_fps_cap = int(view_layout.apply_render_fps_cap(window, state.render_fps_cap, state.vsync_mode))
	if view_layout != null and view_layout.has_method("save_render_fps_cap_default"):
		view_layout.save_render_fps_cap_default(state.render_fps_cap)
	if view_layout != null and view_layout.has_method("apply_vsync_mode"):
		state.vsync_mode = int(view_layout.apply_vsync_mode(state.vsync_mode, window))
	if view_layout != null and view_layout.has_method("save_vsync_mode_default"):
		view_layout.save_vsync_mode_default(state.vsync_mode)
	if view_layout != null and view_layout.has_method("save_auto_refresh_rate_default"):
		view_layout.save_auto_refresh_rate_default(state.auto_refresh_rate_60hz, window)
	elif view_layout != null and view_layout.has_method("apply_auto_refresh_rate"):
		view_layout.apply_auto_refresh_rate(window, state.auto_refresh_rate_60hz)


func apply_recommended(owner: Object, registry: Object) -> void:
	state.apply_recommended()
	save(owner, registry)


func apply_60hz_now(owner: Object, registry: Object) -> void:
	var view_layout := _get_view_layout(registry)
	var window := get_owner_window(owner)
	var applied := false
	state.mark_auto_refresh_saved(true)
	if view_layout != null and view_layout.has_method("save_auto_refresh_rate_default"):
		applied = bool(view_layout.save_auto_refresh_rate_default(true, window))
	elif view_layout != null and view_layout.has_method("apply_auto_refresh_rate"):
		applied = bool(view_layout.apply_auto_refresh_rate(window, true))
	if not applied:
		open_system_display_settings(registry)


func get_display_mode_description() -> String:
	if state.display_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN:
		return LanguageSettings.translate("display.desc.exclusive")
	if state.display_mode == DISPLAY_MODE_FULLSCREEN:
		return LanguageSettings.translate("display.desc.fullscreen")
	return LanguageSettings.translate("display.desc.windowed")


func get_render_fps_cap_options(registry: Object) -> Array[int]:
	var view_layout := _get_view_layout(registry)
	if view_layout != null and view_layout.has_method("get_render_fps_cap_options"):
		var raw_options: Variant = view_layout.get_render_fps_cap_options()
		if raw_options is Array:
			var options: Array[int] = []
			for raw_value in raw_options:
				options.append(int(raw_value))
			if not options.is_empty():
				return options
	return [
		RENDER_FPS_CAP_UNLIMITED,
		RENDER_FPS_CAP_STABILITY,
		RENDER_FPS_CAP_SMOOTH,
		RENDER_FPS_CAP_BALANCED,
		RENDER_FPS_CAP_STABLE_MONITOR,
		RENDER_FPS_CAP_MONITOR,
	]


func get_render_fps_cap_label(registry: Object, owner: Object = null) -> String:
	var view_layout := _get_view_layout(registry)
	if state.render_fps_cap == RENDER_FPS_CAP_UNLIMITED:
		return LanguageSettings.translate("display.fps.unlimited")
	if state.render_fps_cap == RENDER_FPS_CAP_MONITOR:
		return LanguageSettings.translate("display.fps.monitor") % get_monitor_refresh_rate(registry, owner)
	if view_layout != null and view_layout.has_method("get_render_fps_cap_label"):
		return str(view_layout.get_render_fps_cap_label(state.render_fps_cap, get_owner_window(owner)))
	if state.render_fps_cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return "Stable 48 FPS"
	return "%d FPS" % state.render_fps_cap


func get_vsync_mode_options(registry: Object) -> Array[int]:
	var view_layout := _get_view_layout(registry)
	if view_layout != null and view_layout.has_method("get_vsync_mode_options"):
		var raw_options: Variant = view_layout.get_vsync_mode_options()
		if raw_options is Array:
			var options: Array[int] = []
			for raw_value in raw_options:
				options.append(int(raw_value))
			if not options.is_empty():
				return options
	return [
		VSYNC_MODE_AUTO,
		VSYNC_MODE_ENABLED,
		VSYNC_MODE_MAILBOX,
		VSYNC_MODE_DISABLED,
	]


func get_vsync_mode_label(registry: Object) -> String:
	var view_layout := _get_view_layout(registry)
	if view_layout != null and view_layout.has_method("get_vsync_mode_label"):
		return str(view_layout.get_vsync_mode_label(state.vsync_mode))
	if state.vsync_mode == VSYNC_MODE_AUTO:
		return "Auto"
	if state.vsync_mode == VSYNC_MODE_DISABLED:
		return "VSync Off"
	if state.vsync_mode == VSYNC_MODE_MAILBOX:
		return "Mailbox"
	return "VSync On"


func get_display_pacing_recommendation(registry: Object, owner: Object = null) -> String:
	var monitor_rate := get_monitor_refresh_rate(registry, owner)
	if monitor_rate <= 0:
		return LanguageSettings.translate("display.recommendation.fallback")
	var stable_settings_ready := (
		state.display_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
		and state.render_fps_cap == RENDER_FPS_CAP_STABLE_MONITOR
		and (state.vsync_mode == VSYNC_MODE_AUTO or state.vsync_mode == VSYNC_MODE_ENABLED)
	)
	if stable_settings_ready:
		return LanguageSettings.translate("display.recommendation.ready") % monitor_rate
	if state.render_fps_cap == RENDER_FPS_CAP_MONITOR:
		return LanguageSettings.translate("display.recommendation.monitor") % monitor_rate
	return LanguageSettings.translate("display.recommendation.default") % monitor_rate


func get_monitor_refresh_rate(registry: Object, owner: Object = null) -> int:
	var view_layout := _get_view_layout(registry)
	if view_layout != null and view_layout.has_method("get_monitor_refresh_rate"):
		return int(view_layout.get_monitor_refresh_rate(get_owner_window(owner)))
	return 60


func open_system_display_settings(registry: Object) -> void:
	var view_layout := _get_view_layout(registry)
	if view_layout != null and view_layout.has_method("open_system_display_settings"):
		view_layout.open_system_display_settings()
		return
	if OS.get_name() == "Windows":
		OS.shell_open("ms-settings:display")


func get_owner_window(owner: Object) -> Object:
	if owner != null and owner.has_method("get_window"):
		var window: Variant = owner.get_window()
		if typeof(window) == TYPE_OBJECT and is_instance_valid(window):
			return window as Object
	return null


func _get_view_layout(registry: Object) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("battle_view_layout")
	return null
