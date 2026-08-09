extends SceneTree

const PauseMenuDisplaySettingsController := preload("res://scripts/hud/pause_menu_display_settings_controller.gd")
const PauseMenuDisplaySettingsState := preload("res://scripts/hud/pause_menu_display_settings_state.gd")


class FakeViewLayout:
	var display_mode := PauseMenuDisplaySettingsState.DISPLAY_MODE_WINDOWED
	var saved_display_mode := PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	var remember_display_mode := true
	var render_fps_cap := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_BALANCED
	var saved_render_fps_cap := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABILITY
	var vsync_mode := PauseMenuDisplaySettingsState.VSYNC_MODE_DISABLED
	var saved_vsync_mode := PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED
	var auto_refresh_enabled := true
	var apply_display_count := 0
	var save_display_count := 0
	var apply_render_fps_count := 0
	var save_render_fps_count := 0
	var apply_vsync_count := 0
	var save_vsync_count := 0
	var save_auto_refresh_count := 0
	var system_settings_count := 0

	func get_remember_display_mode() -> bool:
		return remember_display_mode

	func get_display_mode(_window: Object) -> String:
		return display_mode

	func get_saved_display_mode() -> String:
		return saved_display_mode

	func apply_display_mode(_window: Object, mode: String) -> String:
		display_mode = PauseMenuDisplaySettingsState.normalize_display_mode(mode)
		apply_display_count += 1
		return display_mode

	func save_display_mode_default(mode: String, remember: bool) -> bool:
		saved_display_mode = mode
		remember_display_mode = remember
		save_display_count += 1
		return true

	func get_saved_render_fps_cap() -> int:
		return saved_render_fps_cap

	func get_render_fps_cap_options() -> Array[int]:
		return [
			PauseMenuDisplaySettingsState.RENDER_FPS_CAP_UNLIMITED,
			PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABILITY,
			PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABLE_MONITOR,
		]

	func apply_render_fps_cap(_window: Object, cap: int, _vsync: int) -> int:
		render_fps_cap = cap
		apply_render_fps_count += 1
		return cap

	func save_render_fps_cap_default(cap: int) -> bool:
		saved_render_fps_cap = cap
		save_render_fps_count += 1
		return true

	func get_render_fps_cap_label(cap: int, _window: Object) -> String:
		return "cap:%d" % cap

	func get_saved_vsync_mode() -> int:
		return saved_vsync_mode

	func get_vsync_mode_options() -> Array[int]:
		return [
			PauseMenuDisplaySettingsState.VSYNC_MODE_AUTO,
			PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED,
			PauseMenuDisplaySettingsState.VSYNC_MODE_DISABLED,
		]

	func apply_vsync_mode(mode: int, _window: Object = null) -> int:
		vsync_mode = mode
		apply_vsync_count += 1
		return mode

	func save_vsync_mode_default(mode: int) -> bool:
		saved_vsync_mode = mode
		save_vsync_count += 1
		return true

	func get_vsync_mode_label(mode: int) -> String:
		return "vsync:%d" % mode

	func get_auto_refresh_rate_enabled() -> bool:
		return auto_refresh_enabled

	func save_auto_refresh_rate_default(enabled: bool, _window: Object = null) -> bool:
		auto_refresh_enabled = enabled
		save_auto_refresh_count += 1
		return true

	func get_monitor_refresh_rate(_window: Object = null) -> int:
		return 144

	func open_system_display_settings() -> void:
		system_settings_count += 1


class FakeRegistry:
	var view_layout := FakeViewLayout.new()

	func get_instance(key: String) -> Object:
		if key == "battle_view_layout":
			return view_layout
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_controller_contract()
	_verify_overlay_delegation_contract()
	if _failures.is_empty():
		print("pause_menu_display_settings_controller_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_direct_controller_contract() -> void:
	var registry := FakeRegistry.new()
	var controller := PauseMenuDisplaySettingsController.new()
	var state := controller.state
	controller.sync(null, registry)
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, "sync should prefer the remembered display mode")
	_expect(state.render_fps_cap == PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABILITY, "sync should load the saved render FPS cap")
	_expect(state.vsync_mode == PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED, "sync should load the saved VSync mode")
	_expect(state.auto_refresh_rate_60hz, "sync should load automatic refresh preference")
	_expect(not state.preference_dirty, "sync should seal the loaded state as its baseline")

	state.select_display_mode(PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN)
	state.render_fps_cap = PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABLE_MONITOR
	state.vsync_mode = PauseMenuDisplaySettingsState.VSYNC_MODE_AUTO
	state.auto_refresh_rate_60hz = false
	controller.save(null, registry)
	_expect(registry.view_layout.apply_display_count == 1, "dirty display mode should be applied by the controller")
	_expect(registry.view_layout.save_display_count == 1, "dirty display mode should be persisted by the controller")
	_expect(registry.view_layout.apply_render_fps_count == 1 and registry.view_layout.save_render_fps_count == 1, "render FPS should be applied and persisted together")
	_expect(registry.view_layout.apply_vsync_count == 1 and registry.view_layout.save_vsync_count == 1, "VSync should be applied and persisted together")
	_expect(registry.view_layout.save_auto_refresh_count == 1, "automatic refresh preference should be persisted by the controller")

	controller.cycle_render_fps_cap(1, null, registry)
	_expect(state.render_fps_cap == PauseMenuDisplaySettingsState.RENDER_FPS_CAP_UNLIMITED, "render FPS cycling should use the view-layout option order")
	controller.cycle_vsync_mode(1, null, registry)
	_expect(state.vsync_mode == PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED, "VSync cycling should use the view-layout option order")
	state.render_fps_cap = PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABILITY
	_expect(controller.get_render_fps_cap_label(registry) == "cap:48", "ordinary render FPS labels should be delegated to the view-layout owner")
	_expect(controller.get_vsync_mode_label(registry) == "vsync:1", "VSync label should be delegated to the view-layout owner")
	_expect(controller.get_monitor_refresh_rate(registry) == 144, "monitor refresh should be read through the view-layout owner")

	controller.apply_recommended(null, registry)
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, "recommended settings should remain a state-plus-save transaction")
	_expect(state.render_fps_cap == PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABLE_MONITOR, "recommended settings should select stable monitor FPS")
	controller.apply_60hz_now(null, registry)
	_expect(state.auto_refresh_rate_60hz, "explicit 60Hz apply should update controller state")


func _verify_overlay_delegation_contract() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_display_settings_controller.gd")
	_expect(overlay_source.find("PauseMenuDisplaySettingsController") >= 0, "overlay should preload the display-settings controller")
	for delegation in [
		"_display_settings_controller.sync(owner, registry)",
		"_display_settings_controller.save(owner, registry)",
		"_display_settings_controller.cycle_render_fps_cap(direction, owner, registry)",
		"_display_settings_controller.cycle_vsync_mode(direction, owner, registry)",
		"_display_settings_controller.apply_recommended(owner, registry)",
		"_display_settings_controller.apply_60hz_now(owner, registry)",
	]:
		_expect(overlay_source.find(delegation) >= 0, "overlay should delegate display integration: %s" % delegation)
	_expect(controller_source.find("get_instance(\"battle_view_layout\")") >= 0, "display controller should own battle-view-layout discovery")
	_expect(controller_source.find("apply_display_mode") >= 0, "display controller should own live display-mode application")
	_expect(controller_source.find("save_render_fps_cap_default") >= 0, "display controller should own render-FPS persistence")
	_expect(controller_source.find("save_vsync_mode_default") >= 0, "display controller should own VSync persistence")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
