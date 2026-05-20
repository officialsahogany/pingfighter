extends SceneTree

const BOOT_FLOW_SCENE_PATH := "res://scenes/boot_flow.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const CHARACTER_SELECT_SCENE_PATH := "res://scenes/character_select.tscn"
const EXPECTED_VIEWPORT_WIDTH := 2020
const EXPECTED_VIEWPORT_HEIGHT := 1246


func _init() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect(
		main_scene == BOOT_FLOW_SCENE_PATH,
		"project main scene should stay on the boot flow path, not a battle scene UID"
	)
	_expect(
		int(ProjectSettings.get_setting("application/run/max_fps", 0)) == 48,
		"project default render FPS should stay on the 48 FPS stable 144Hz-divisor preset"
	)
	_expect(
		str(ProjectSettings.get_setting("autoload/GameSelectionState", "")) == "*res://scripts/core/game_selection_state.gd",
		"GameSelectionState autoload should persist selection across menu scenes"
	)
	_expect(
		str(ProjectSettings.get_setting("autoload/ScreenshotCapture", "")) == "*res://scripts/core/screenshot_capture.gd",
		"ScreenshotCapture autoload should stay registered"
	)
	_expect(
		str(ProjectSettings.get_setting("autoload/FullscreenToggle", "")) == "*res://scripts/core/fullscreen_toggle.gd",
		"FullscreenToggle autoload should stay registered"
	)
	_expect(
		str(ProjectSettings.get_setting("autoload/DisplayRefreshManager", "")) == "*res://scripts/core/display_refresh_manager.gd",
		"DisplayRefreshManager autoload should stay registered for opt-in refresh restore"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == EXPECTED_VIEWPORT_WIDTH,
		"project viewport width should keep the desktop-scale launch size"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == EXPECTED_VIEWPORT_HEIGHT,
		"project viewport height should keep the desktop-scale launch size"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)) == EXPECTED_VIEWPORT_WIDTH,
		"project window width override should keep the desktop-scale launch size"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)) == EXPECTED_VIEWPORT_HEIGHT,
		"project window height override should keep the desktop-scale launch size"
	)
	_expect(
		str(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items",
		"project stretch mode should scale canvas items instead of showing tiny default content"
	)
	_expect(
		str(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "expand",
		"project stretch aspect should expand the viewport in fullscreen instead of letterboxing"
	)
	_expect(FileAccess.file_exists(BOOT_FLOW_SCENE_PATH), "boot flow scene should exist")
	_expect(FileAccess.file_exists(MAIN_MENU_SCENE_PATH), "main menu scene should exist")
	_expect(FileAccess.file_exists(CHARACTER_SELECT_SCENE_PATH), "character select scene should exist")

	var packed := load(BOOT_FLOW_SCENE_PATH) as PackedScene
	_expect(packed != null, "boot flow scene should load")
	if packed != null:
		var boot_flow := packed.instantiate()
		_expect(
			str(boot_flow.get("post_intro_scene_path")) == MAIN_MENU_SCENE_PATH,
			"boot loading should hand off to the main menu before character select"
		)
		_expect(
			str(boot_flow.get("character_select_scene_path")) == CHARACTER_SELECT_SCENE_PATH,
			"boot prewarm should target the character select scene"
		)
		_expect(int(boot_flow.get("starting_stage")) == 1, "boot flow should prepare Stage 1 startup state")
		boot_flow.free()

	print("project_boot_flow_settings_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
