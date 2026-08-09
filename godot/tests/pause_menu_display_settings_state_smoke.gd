extends SceneTree

const PauseMenuDisplaySettingsState := preload("res://scripts/hud/pause_menu_display_settings_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_transition_owner_contract()
	var state := PauseMenuDisplaySettingsState.new()
	_expect(not state.should_save_display(), "factory windowed state should match its initial baseline")
	_expect(state.select_display_mode(" FULLSCREEN "), "normalized display selection should report a change")
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN, "display selection should normalize whitespace and case")
	_expect(state.should_save_display(), "display-mode drift should require save")
	_expect(not state.select_display_mode(PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN), "selecting the active display mode should be a no-op")
	_expect(state.cycle_display_mode(1), "display cycle should advance")
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, "display cycle should preserve canonical ordering")
	_expect(state.cycle_display_mode(-1), "reverse display cycle should advance")
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN, "reverse display cycle should wrap through canonical ordering")
	state.sync_baseline()
	_expect(state.should_save_display(), "remembered non-windowed mode should remain materialized on save")
	state.reset_factory()
	_expect(state.preference_dirty, "factory reset should mark display preferences dirty")
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_WINDOWED, "factory reset should restore windowed mode")
	_expect(state.render_fps_cap == PauseMenuDisplaySettingsState.RENDER_FPS_CAP_DEFAULT, "factory reset should restore the stable FPS cap")
	_expect(state.vsync_mode == PauseMenuDisplaySettingsState.VSYNC_MODE_AUTO, "factory reset should restore automatic VSync")
	var fps_options: Array[int] = [0, 48, 60]
	state.render_fps_cap = 999
	_expect(state.cycle_render_fps_cap(fps_options, 1), "unknown FPS cap should enter the canonical cycle")
	_expect(state.render_fps_cap == 48, "unknown FPS cap should preserve the existing forward-cycle fallback")
	var vsync_options: Array[int] = [-1, 1, 3, 0]
	_expect(state.cycle_vsync_mode(vsync_options, 1), "VSync cycle should advance")
	_expect(state.vsync_mode == PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED, "VSync cycle should preserve canonical ordering")
	state.preference_dirty = false
	state.toggle_remember_display_mode()
	_expect(state.remember_display_mode and state.preference_dirty, "remember-mode toggle should mark display preferences dirty")
	state.preference_dirty = false
	state.toggle_auto_refresh_rate()
	_expect(state.auto_refresh_rate_60hz and state.preference_dirty, "auto-refresh toggle should mark display preferences dirty")
	state.apply_recommended()
	_expect(state.display_mode == PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, "recommended settings should select exclusive fullscreen")
	_expect(state.remember_display_mode, "recommended settings should remember the display mode")
	_expect(state.render_fps_cap == PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABLE_MONITOR, "recommended settings should select the stable monitor cap")
	_expect(not state.auto_refresh_rate_60hz, "recommended settings should not silently force 60Hz")
	state.sync_baseline()
	state.mark_auto_refresh_saved(true)
	var status := state.get_status()
	_expect(bool(status.get("auto_refresh_rate_60hz", false)), "explicit 60Hz apply should update current state")
	_expect(bool(status.get("synced_auto_refresh_rate_60hz", false)), "explicit 60Hz apply should update the saved baseline")

	if _failures.is_empty():
		print("pause_menu_display_settings_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_overlay_transition_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	for delegation in [
		"_display_settings_state.cycle_display_mode(direction)",
		"_display_settings_state.select_display_mode(mode)",
		"_display_settings_state.toggle_remember_display_mode()",
		"_display_settings_state.toggle_auto_refresh_rate()",
		"_display_settings_controller.cycle_render_fps_cap(direction, owner, registry)",
		"_display_settings_controller.cycle_vsync_mode(direction, owner, registry)",
		"PauseMenuDisplaySettingsState.normalize_display_mode(mode)",
	]:
		_expect(source.find(delegation) >= 0, "overlay should delegate display transition: %s" % delegation)
	_expect(source.find("remember_display_mode = not remember_display_mode") == -1, "overlay should not toggle remember-mode outside the display state")
	_expect(source.find("auto_refresh_rate_60hz = not auto_refresh_rate_60hz") == -1, "overlay should not toggle auto-refresh outside the display state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
