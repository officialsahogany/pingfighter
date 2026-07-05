extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const CHARACTER_SELECT_SCENE_PATH := "res://scenes/character_select.tscn"
const LOGO_BAKED_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_logo.png"
const MAIN_MENU_BGM_PATH := "res://assets/bgm/main_menu_moon_crack.wav"
const MAIN_MENU_START_SFX_PATH := "res://assets/sounds/stagestart_godot_short.wav"
const BGM_BUS_NAME := "BGM"
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


var failure_count: int = 0
var menu: Control = null
var quit_calls: int = 0
var menu_background_prewarm: Object = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectResourceLoader.clear_caches()
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_expect(packed != null, "main menu scene should load")
	if packed == null:
		_finish()
		return

	menu = packed.instantiate()
	get_root().add_child(menu)
	current_scene = menu
	await process_frame
	# F10 booth-reset regression guard: the exhibition reset jumps straight to
	# this menu (skipping the boot loading screen) after battle teardown wiped
	# the resource caches, so the menu itself must re-begin the
	# character-select prewarm in the background during title idle.
	menu_background_prewarm = menu.get("character_select_prewarm")
	_expect(
		menu_background_prewarm != null,
		"main menu should begin the character-select background prewarm on ready (F10 booth reset skips the boot loading screen)"
	)
	var background := menu.get_node_or_null("Background") as TextureRect
	_expect(menu.get_node_or_null("BackgroundFill") == null, "main menu should not draw a cropped duplicate background strip above the title art")
	_expect(background != null, "main menu should expose the background texture rect")
	if background != null:
		_expect(
			background.stretch_mode == TextureRect.STRETCH_SCALE,
			"main menu background should stretch to the viewport with no crop or letterbox"
		)
		_expect(background.texture != null, "main menu background texture should load")
		if background.texture != null:
			_expect(
				background.texture.resource_path == LOGO_BAKED_BACKGROUND_PATH,
				"main menu background should use the logo-baked art resource"
			)
	var reveal := menu.get_node_or_null("RevealLayer") as Control
	_expect(reveal != null, "main menu should expose the intro reveal layer")
	if reveal != null and reveal.has_method("_background_image_rect"):
		var reveal_rect: Rect2 = reveal.call("_background_image_rect", Vector2(1920.0, 1080.0))
		_expect_background_rect_fills_viewport(
			reveal_rect,
			Vector2(1920.0, 1080.0),
			"main menu reveal 16:9"
		)
		var small_window_reveal_rect: Rect2 = reveal.call("_background_image_rect", Vector2(2020.0, 1246.0))
		_expect_background_rect_fills_viewport(
			small_window_reveal_rect,
			Vector2(2020.0, 1246.0),
			"main menu reveal small-window"
		)
	_expect(
		menu.get_node_or_null("LogoReveal") == null,
		"main menu should not have a logo reveal overlay (logo is baked into background)"
	)
	_expect(
		menu.get_node_or_null("VignetteBottom") == null,
		"main menu should not darken the lower background with a vignette overlay"
	)
	var ambient := menu.get_node_or_null("AmbientLayer") as Control
	_expect(ambient != null, "main menu should expose the ambient effects layer")
	if ambient != null:
		_expect(
			ambient.get_script() != null,
			"main menu ambient layer should use its effect script"
		)
		_expect(
			ambient.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"main menu ambient layer should not intercept input"
		)
		if ambient.has_method("_logo_glint_rect"):
			if ambient.has_method("_background_image_rect"):
				var small_window_ambient_rect: Rect2 = ambient.call("_background_image_rect", Vector2(2020.0, 1246.0))
				_expect_background_rect_fills_viewport(
					small_window_ambient_rect,
					Vector2(2020.0, 1246.0),
					"main menu ambient small-window"
				)
			var logo_glint_rect: Rect2 = ambient.call("_logo_glint_rect", Vector2(1920.0, 1080.0))
			_expect(
				logo_glint_rect.position.x <= 90.0 and logo_glint_rect.position.y <= 240.0,
				"main menu logo glint should stay anchored near the upper-left logo"
			)
			_expect(
				logo_glint_rect.end.x < 960.0 and logo_glint_rect.end.y < 500.0,
				"main menu logo glint should not sweep across the full upper background"
			)
		if ambient.has_method("_has_logo_letter_mask"):
			_expect(
				bool(ambient.call("_has_logo_letter_mask")),
				"main menu logo glint should build a letter-only alpha mask"
			)
		if ambient.has_method("_has_logo_orb_effect_mask"):
			_expect(
				bool(ambient.call("_has_logo_orb_effect_mask")),
				"main menu logo glint should build a masked purple-orb effect area"
			)
		_expect(
			ambient.get_node_or_null("LogoLetterGlint") == null,
			"main menu logo glint should not duplicate the baked logo through a separate texture layer"
		)
		if ambient.has_method("_is_logo_letter_source_pixel"):
			_expect(
				bool(ambient.call("_is_logo_letter_source_pixel", Vector2(620.0, 370.0))),
				"main menu logo glint mask should include bright letter pixels"
			)
			_expect(
				not bool(ambient.call("_is_logo_letter_source_pixel", Vector2(560.0, 380.0))),
				"main menu logo glint mask should exclude the non-letter logo orb area"
			)
		if ambient.has_method("_is_logo_orb_effect_source_pixel"):
			_expect(
				bool(ambient.call("_is_logo_orb_effect_source_pixel", Vector2(560.0, 382.0))),
				"main menu logo glint should include the purple orb core in its masked effect area"
			)
			_expect(
				bool(ambient.call("_is_logo_orb_effect_source_pixel", Vector2(482.0, 397.0))),
				"main menu logo glint should include the purple orb's surrounding effect area"
			)
	var bgm_player := menu.get("main_menu_bgm_player") as AudioStreamPlayer
	_expect(bgm_player != null, "main menu should create a BGM player")
	if bgm_player != null:
		_expect(bgm_player.bus == BGM_BUS_NAME, "main menu BGM should route through the BGM bus")
		_expect(bgm_player.stream != null, "main menu BGM player should load an audio stream")
		if bgm_player.stream != null:
			_expect(bgm_player.stream is AudioStreamWAV, "main menu BGM should load as a WAV stream")
			if bgm_player.stream is AudioStreamWAV:
				var wav_stream: AudioStreamWAV = bgm_player.stream
				_expect(
					wav_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
					"main menu BGM WAV stream should loop forward"
				)
		_expect(bgm_player.playing, "main menu BGM should start playing")
		_send_b_to_menu()
		await process_frame
		_expect(not bgm_player.playing, "B key should mute the main-menu BGM")
		_send_b_to_menu()
		await process_frame
		_expect(bgm_player.playing, "B key should resume the main-menu BGM")
	_finish_intro_reveal()
	await process_frame
	_expect(
		FileAccess.file_exists(MAIN_MENU_BGM_PATH) or ResourceLoader.exists(MAIN_MENU_BGM_PATH, "AudioStream"),
		"main menu BGM resource should exist"
	)
	var start_button := menu.get_node_or_null("ButtonStack/StartButton") as Button
	var settings_button := menu.get_node_or_null("ButtonStack/SettingsButton") as Button
	var quit_button := menu.get_node_or_null("ButtonStack/QuitButton") as Button
	var quit_overlay := menu.get_node_or_null("QuitConfirmOverlay") as Control
	var quit_yes_button := menu.get_node_or_null("QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/YesButton") as Button
	var quit_no_button := menu.get_node_or_null("QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/NoButton") as Button
	var button_stack := menu.get_node_or_null("ButtonStack") as VBoxContainer
	_expect(start_button != null, "main menu should expose a start button")
	_expect(settings_button != null, "main menu should expose a settings button")
	_expect(quit_button != null, "main menu should expose a quit button")
	_expect(quit_overlay != null, "main menu should expose a quit confirmation overlay")
	_expect(quit_yes_button != null, "quit confirmation should expose a yes button")
	_expect(quit_no_button != null, "quit confirmation should expose a no button")
	if button_stack != null:
		_expect(button_stack.get_child(0) == start_button, "start button should stay first in the main-menu stack")
		_expect(button_stack.get_child(1) == settings_button, "settings button should sit between start and quit")
		_expect(button_stack.get_child(2) == quit_button, "quit button should stay last in the main-menu stack")
	if start_button != null:
		_expect(start_button.text == "TOUCH TO START", "main menu start prompt should use the uppercase touch-to-start label")
		_expect(start_button.get_theme_font_size("font_size") >= 40, "touch-to-start prompt should stay scaled up in the faded ribbon")
		_expect(start_button.custom_minimum_size.x >= 845.0, "touch-to-start prompt should keep the enlarged ribbon width")
		var prompt_ribbon := start_button.get_node_or_null("PromptRibbon") as Control
		_expect(prompt_ribbon != null, "touch-to-start prompt should draw the background-matched faded ribbon")
		_expect(start_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "touch-to-start text should not intercept full-screen start input")
		var start_style := start_button.get_theme_stylebox("normal")
		if start_style is StyleBoxFlat:
			var flat_style: StyleBoxFlat = start_style
			_expect(flat_style.bg_color.a <= 0.01, "touch-to-start prompt should avoid a hard rectangular button fill")
			_expect(flat_style.border_width_left == 0 and flat_style.border_width_top == 0, "touch-to-start prompt should not draw a button border")
	if settings_button != null:
		_expect(not settings_button.visible, "main menu should hide the settings utility button from the touch-to-start screen")
	if quit_button != null:
		_expect(not quit_button.visible, "main menu should hide the quit utility button from the touch-to-start screen")
	if settings_button != null:
		settings_button.pressed.emit()
		await process_frame
		var settings_overlay: Object = menu.get("main_menu_settings_overlay")
		var settings_layer := menu.get_node_or_null("SettingsOverlayLayer") as Control
		_expect(settings_overlay != null, "settings button should create the shared pause settings overlay")
		_expect(
			settings_overlay != null and settings_overlay.has_method("is_options_open") and bool(settings_overlay.is_options_open()),
			"settings button should open the settings page directly"
		)
		_expect(settings_layer != null and settings_layer.visible, "settings overlay layer should be visible over the main menu")
		_send_escape_to_menu()
		await process_frame
		_expect(
			settings_overlay != null and settings_overlay.has_method("is_active") and not bool(settings_overlay.is_active()),
			"ESC from main-menu settings should close the settings overlay instead of showing the pause panel"
		)
	quit_calls = 0
	menu.set("application_quit_callback", Callable(self, "_request_quit"))
	if quit_button != null and quit_overlay != null:
		quit_button.pressed.emit()
		await process_frame
		_expect(quit_overlay.visible, "quit button should open the quit confirmation overlay")
		_expect(quit_no_button != null and quit_no_button.has_focus(), "quit confirmation should default focus to the no button")
		if quit_no_button != null:
			quit_no_button.pressed.emit()
		await process_frame
		_expect(not quit_overlay.visible, "no button should close the quit confirmation overlay")
		_expect(current_scene == menu, "canceling quit should keep the main menu active")
		quit_button.pressed.emit()
		await process_frame
		_expect(quit_overlay.visible, "quit confirmation should reopen on a repeated quit request")
		if quit_yes_button != null:
			quit_yes_button.pressed.emit()
		await process_frame
		_expect(not quit_overlay.visible, "yes button should close the quit confirmation overlay before quitting")
		_expect(quit_calls == 1, "yes button should trigger exactly one quit request")
		_expect(bool(menu.get("transitioning")), "confirmed quit should lock the menu transition state")
		menu.set("transitioning", false)
	menu.set("application_quit_callback", Callable())
	if bgm_player != null:
		_send_b_to_menu()
		await process_frame
		_expect(not bgm_player.playing, "B key should keep main-menu BGM muted before scene change")
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state != null and "skip_battle_logo_once" in selection_state:
		selection_state.set("skip_battle_logo_once", false)
	# Wait (bounded) for the background prewarm to claim the character-select
	# PackedScene BEFORE pressing start, so the scene_file_path assertion below
	# deterministically exercises the change_scene_to_packed branch instead of
	# racing the threaded load into the change_scene_to_file fallback.
	if menu_background_prewarm != null and menu_background_prewarm.has_method("get_loaded_scene"):
		for _i in range(600):
			if menu_background_prewarm.call("get_loaded_scene") != null:
				break
			await process_frame
		_expect(
			menu_background_prewarm.call("get_loaded_scene") != null,
			"main menu background prewarm should load the character-select PackedScene during title idle"
		)
	_send_gamepad_start_to_menu()
	await process_frame
	_expect(bool(menu.get("transitioning")), "start should lock the main menu while the entry animation plays")
	_expect(current_scene == menu, "start should wait for the entry animation before changing scenes")
	if selection_state != null and "skip_battle_logo_once" in selection_state:
		_expect(
			bool(selection_state.get("skip_battle_logo_once")),
			"main menu start should request one battle-logo skip after an exhibition reset clears the flag"
		)
	var transition_layer := menu.get_node_or_null("StartTransitionLayer") as Control
	_expect(transition_layer != null and transition_layer.visible, "start should show the one-second entry transition layer")
	var start_sfx_player := menu.get("start_transition_sfx_player") as AudioStreamPlayer
	_expect(start_sfx_player != null, "start should create an entry transition SFX player")
	if start_sfx_player != null:
		_expect(start_sfx_player.stream != null, "start transition SFX player should load a stream")
		if start_sfx_player.stream != null:
			_expect(
				FileAccess.file_exists(MAIN_MENU_START_SFX_PATH) or ResourceLoader.exists(MAIN_MENU_START_SFX_PATH, "AudioStream"),
				"start transition should use the stage-start style SFX resource"
			)
	var transition_timer := create_timer(1.12)
	await transition_timer.timeout
	transition_timer = null
	for _i in range(360):
		if current_scene != menu:
			break
		await process_frame
	await process_frame
	var active_scene := current_scene
	_expect(active_scene != null, "start should leave a current scene")
	if active_scene != null:
		_expect(
			active_scene.scene_file_path == CHARACTER_SELECT_SCENE_PATH,
			"start should change to character_select.tscn"
		)
		var character_bgm_player := active_scene.get("character_select_bgm_player") as AudioStreamPlayer
		_expect(character_bgm_player != null, "character select should create a BGM player")
		if character_bgm_player != null:
			_expect(
				not character_bgm_player.playing,
				"character select BGM should respect the B key mute from the main menu"
			)
			_send_b_to_character_select(active_scene)
			await process_frame
			_expect(
				character_bgm_player.playing,
				"B key should resume BGM from the character-select screen"
			)
			for _i in range(30):
				await process_frame
	await _cleanup_main_menu_reference()
	await _cleanup_current_scene()
	await _drain_menu_background_prewarm()
	ProjectResourceLoader.clear_caches()
	for _i in range(120):
		ProjectResourceLoader.try_resolve_finished_threaded_prewarm()
		await process_frame
	ProjectResourceLoader.clear_caches()
	_clear_root_bgm_meta()
	_finish()


func _finish() -> void:
	if failure_count > 0:
		quit(1)
		return
	print("main_menu_flow_smoke: ok")
	quit(0)


func _send_escape_to_menu() -> void:
	if menu == null:
		return
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = KEY_ESCAPE
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = KEY_ESCAPE
	menu._input(event)


func _send_b_to_menu() -> void:
	if menu == null:
		return
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = KEY_B
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = KEY_B
	menu._input(event)


func _send_gamepad_start_to_menu() -> void:
	if menu == null:
		return
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_A
	menu._input(event)


func _send_b_to_character_select(node: Node) -> void:
	if node == null or not node.has_method("_unhandled_input"):
		return
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = KEY_B
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = KEY_B
	node._unhandled_input(event)


func _finish_intro_reveal() -> void:
	if menu == null:
		return
	var reveal := menu.get_node_or_null("RevealLayer")
	if reveal != null and reveal.has_method("_finish_reveal"):
		reveal.call("_finish_reveal")


func _request_quit() -> void:
	quit_calls += 1


func _cleanup_current_scene() -> void:
	var scene := current_scene
	if scene == null:
		return
	_cleanup_audio_player(scene.get("main_menu_bgm_player") as AudioStreamPlayer)
	_cleanup_audio_player(scene.get("start_transition_sfx_player") as AudioStreamPlayer)
	_cleanup_audio_player(scene.get("character_select_bgm_player") as AudioStreamPlayer)
	await process_frame
	if current_scene == scene:
		current_scene = null
	scene.queue_free()
	if scene == menu:
		menu = null
	await process_frame
	await process_frame
	menu = null


func _cleanup_main_menu_reference() -> void:
	if menu == null:
		return
	if is_instance_valid(menu):
		_cleanup_audio_player(menu.get("main_menu_bgm_player") as AudioStreamPlayer)
		_cleanup_audio_player(menu.get("start_transition_sfx_player") as AudioStreamPlayer)
		menu.set("application_quit_callback", Callable())
		var overlay: Object = menu.get("main_menu_settings_overlay")
		if overlay != null:
			if overlay.has_method("clear_runtime_state"):
				overlay.clear_runtime_state()
			elif overlay.has_method("close"):
				overlay.close()
		var registry: Object = menu.get("main_menu_settings_registry")
		if registry != null:
			if registry.has_method("clear_runtime_state"):
				registry.clear_runtime_state()
			elif "audio_settings" in registry:
				registry.set("audio_settings", null)
			if "view_layout" in registry:
				registry.set("view_layout", null)
		menu.set("main_menu_settings_overlay", null)
		menu.set("main_menu_settings_registry", null)
		await process_frame
		if not menu.is_queued_for_deletion():
			menu.queue_free()
			await process_frame
	menu = null
	await process_frame
	await process_frame


func _drain_menu_background_prewarm() -> void:
	# Claim every threaded load the menu's background prewarm still has in
	# flight so the smoke does not quit with dangling load_threaded_request
	# handles. Bounded so a stuck load cannot hang the smoke.
	if menu_background_prewarm == null:
		return
	for _i in range(600):
		if bool(menu_background_prewarm.update()):
			break
		await process_frame
	menu_background_prewarm = null


func _cleanup_audio_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null


func _clear_root_bgm_meta() -> void:
	var tree_root := get_root()
	if tree_root == null:
		return
	if tree_root.has_meta("bgm_muted"):
		tree_root.remove_meta("bgm_muted")
	if tree_root.has_meta("main_menu_bgm_muted"):
		tree_root.remove_meta("main_menu_bgm_muted")


func _expect_background_rect_fills_viewport(rect: Rect2, view_size: Vector2, label: String) -> void:
	var tolerance := 0.05
	_expect(rect.position.distance_to(Vector2.ZERO) <= tolerance, "%s background rect should start at the viewport origin" % label)
	_expect(rect.size.distance_to(view_size) <= tolerance, "%s background rect should fill the viewport exactly" % label)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
