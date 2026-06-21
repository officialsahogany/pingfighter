extends SceneTree

const DefeatChanceGemsContinueScreen := preload("res://scripts/core/defeat_chance_gems_continue_screen.gd")
const DefeatContinueRevivalBeatState := preload("res://scripts/core/defeat_continue_revival_beat_state.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []
var _continue_calls := 0
var _consume_calls := 0
var _next_consume_remaining := 1


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var chance_gems_count := 2
	var chance_gems_max := 3
	var selected_character_type := "smasher"
	var player_pos := Vector2(280.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var redraws := 0

	func queue_redraw() -> void:
		redraws += 1


class FakeAudio:
	extends RefCounted

	var defeat_jewel_calls := 0
	var defeat_gem_shatter_calls := 0

	func play_defeat_jewel() -> void:
		defeat_jewel_calls += 1

	func play_defeat_gem_shatter() -> void:
		defeat_gem_shatter_calls += 1


class FakeRegistry:
	extends RefCounted

	var continue_screen: Object = null
	var revival_beat_state: Object = DefeatContinueRevivalBeatState.new()
	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "defeat_chance_gems_continue_screen":
			return continue_screen
		if key == "defeat_continue_revival_beat_state":
			return revival_beat_state
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_continue_screen_waits_for_confirm()
	_verify_continue_screen_mouse_button_confirm()
	_verify_modal_gate_and_runtime_wiring()

	if _failures.is_empty():
		print("defeat_chance_gems_continue_screen_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_continue_screen_waits_for_confirm() -> void:
	_continue_calls = 0
	_consume_calls = 0
	_next_consume_remaining = 1
	var owner := FakeOwner.new()
	var screen := DefeatChanceGemsContinueScreen.new()
	var registry := FakeRegistry.new()
	registry.continue_screen = screen

	_expect(screen.show_with_consume(owner, registry, Callable(self, "_record_continue"), Callable(self, "_record_consume")), "show should open the soft defeat screen")
	_expect(screen.is_active(), "screen should become active after show")
	_expect(screen.remaining_gems == 2 and screen.max_gems == 3, "screen should snapshot owner chance gem mirrors")
	_expect(screen.are_assets_ready(), "show should prewarm defeat continue backdrop and chance gem PNG textures before draw")
	_expect(is_zero_approx(screen.reveal_elapsed) and is_zero_approx(screen.get_reveal_progress()), "entry reveal should start closed on show")
	_expect(not screen.is_consuming_continue() and screen.blocks_battle_physics(), "screen should wait in PRESENT and block battle before confirm")
	var ambient_status := screen.get_ambient_divine_status(Vector2(1280.0, 720.0))
	_expect(bool(ambient_status.get("active", false)), "ambient divine motion should be active while the continue screen is readable")
	_expect(float(ambient_status.get("portal_glow_alpha", 0.0)) > 0.05, "ambient portal glow should be present before confirm")
	_expect(float(ambient_status.get("ray_alpha", 0.0)) > 0.02, "ambient god rays should be present before confirm")
	_expect(float(ambient_status.get("mote_alpha", 0.0)) > 0.10, "ambient motes should be present before confirm")
	_expect(int(ambient_status.get("mote_count", 0)) >= 18 and bool(ambient_status.get("single_clock", false)), "ambient motes should use a fixed set driven by the continue screen clock")
	_expect(owner.redraws == 1, "show should request redraw")

	var echo_event := InputEventKey.new()
	echo_event.pressed = true
	echo_event.echo = true
	echo_event.keycode = KEY_SPACE
	screen.handle_input(echo_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(screen.is_active() and _continue_calls == 0, "echo confirm key must not continue")

	screen.update(0.25)
	_expect(screen.elapsed_sec >= 0.25, "screen should advance its animation timer while active")
	_expect(screen.reveal_elapsed >= 0.25 and screen.get_reveal_progress() > 0.0, "screen should advance its entry reveal timer while active")
	ambient_status = screen.get_ambient_divine_status(Vector2(1280.0, 720.0))
	_expect(float(ambient_status.get("clock_sec", 0.0)) >= 0.25, "ambient divine motion should share the screen elapsed clock")

	var confirm_event := InputEventKey.new()
	confirm_event.pressed = true
	confirm_event.keycode = KEY_SPACE
	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(screen.is_active() and screen.is_consuming_continue(), "confirm key should start the continue cinematic instead of closing immediately")
	_expect(_consume_calls == 1, "confirm key should consume exactly one chance gem")
	_expect(_continue_calls == 0, "confirm key should wait until whiteout peak before continuing")
	_expect(registry.audio.defeat_jewel_calls == 1, "confirm key should play the defeat jewel sfx once at shake start")
	_expect(screen.blocks_battle_physics(), "continue cinematic should keep battle blocked before reset")
	_expect(screen.get_whiteout_alpha() <= 0.001, "whiteout should not start at confirm")

	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(_consume_calls == 1 and _continue_calls == 0, "repeated confirm during cinematic must not double-consume or continue early")
	_expect(registry.audio.defeat_jewel_calls == 1, "repeated confirm during cinematic must not replay the defeat jewel sfx")

	screen.update(1.80)
	_expect(screen.is_active() and screen.is_consuming_continue(), "screen should remain active during pre-shatter buildup")
	_expect(screen.get_pre_shatter_charge_strength() > 0.70 and screen.get_pre_shatter_crack_strength() > 0.70, "pre-shatter buildup should drive charge and crack envelopes")
	_expect(screen.get_impact_flash_alpha() <= 0.001 and screen.get_chroma_split_strength() <= 0.001, "impact flash and chroma should stay gated until the shatter window")
	_expect(registry.audio.defeat_gem_shatter_calls == 0, "defeat gem shatter sfx should not play before the shatter start time")

	screen.update(0.30)
	_expect(screen.is_active() and screen.is_consuming_continue(), "screen should remain active during shatter")
	_expect(_continue_calls == 0, "shatter window should still delay reset")
	_expect(screen.get_impact_flash_alpha() > 0.0, "shatter window should fire the impact flash envelope")
	_expect(screen.get_chroma_split_strength() > 0.0, "shatter window should fire chroma split only during impact")
	_expect(screen.get_impact_light_beam_alpha() > 0.0, "shatter window should fire the cross light beams")
	_expect(screen.get_impact_shake_offset().length() > 0.01, "shatter window should add a bounded slam shake")
	_expect(registry.audio.defeat_gem_shatter_calls == 1, "defeat gem shatter sfx should play once when the shatter starts")

	screen.update(0.84)
	_expect(_continue_calls == 1, "whiteout peak should call the continue callback once")
	_expect(registry.audio.defeat_gem_shatter_calls == 1, "defeat gem shatter sfx should not replay after its one-shot guard fires")
	_expect(screen.is_active(), "screen should keep drawing white fadeback after reset")
	_expect(screen.is_revival_beat_active(), "hidden reset should start the continue revival beat")
	_expect(screen.blocks_battle_physics(), "revival beat should keep battle blocked after the hidden reset")
	_expect(screen.get_whiteout_alpha() > 0.70, "reset should happen under an opaque whiteout")
	_expect(screen.get_impact_shake_offset().length() <= 0.01, "slam shake should settle before the reset-under-white frame")

	screen.update(0.70)
	_expect(screen.is_active() and screen.blocks_battle_physics(), "screen should stay active and block until the revival beat finishes")
	_expect(screen.get_whiteout_alpha() <= 0.001, "revival beat should continue after the white fadeback clears")
	screen.update(2.30)
	_expect(not screen.is_active(), "screen should close after the revival beat")
	_expect(_continue_calls == 1 and _consume_calls == 1, "closed screen must not add extra consume or continue calls")
	_expect(is_zero_approx(screen.reveal_elapsed) and is_zero_approx(screen.get_reveal_progress()), "closing the screen should reset entry reveal state")

	_continue_calls = 0
	_consume_calls = 0
	_next_consume_remaining = 1
	owner = FakeOwner.new()
	screen = DefeatChanceGemsContinueScreen.new()
	registry.continue_screen = screen
	_expect(screen.show_with_consume(owner, registry, Callable(self, "_record_continue"), Callable(self, "_record_consume")), "hitch setup should open the screen")
	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	screen.update(4.0)
	_expect(screen.is_active(), "large delta crossing reset should keep one peak-white frame drawable")
	_expect(_continue_calls == 1 and _consume_calls == 1, "large delta crossing reset should still consume and reset exactly once")
	_expect(screen.blocks_battle_physics(), "large delta crossing reset should still hold battle while the revival beat is active")
	_expect(screen.is_revival_beat_active(), "large delta crossing reset should start but not skip the revival beat")
	_expect(screen.get_whiteout_alpha() > 0.99, "large delta crossing reset should clamp to peak white before fadeback")
	screen.update(0.61)
	_expect(screen.is_active() and screen.blocks_battle_physics(), "large-delta guard should keep blocking after fadeback until revival beat end")
	registry.revival_beat_state.force_wall_clock_timeout_for_tests()
	_expect(not screen.blocks_battle_physics(), "continue screen should route revival HOLD through the beat physics-block lever")
	screen.update(0.01)
	_expect(not screen.is_active(), "large-delta peak-white guard should close once the revival beat failsafe releases")


func _verify_continue_screen_mouse_button_confirm() -> void:
	_continue_calls = 0
	_consume_calls = 0
	_next_consume_remaining = 0
	var owner := FakeOwner.new()
	owner.chance_gems_count = 1
	var screen := DefeatChanceGemsContinueScreen.new()
	var registry := FakeRegistry.new()
	screen.show_with_consume(owner, registry, Callable(self, "_record_continue"), Callable(self, "_record_consume"))
	_expect(screen.remaining_gems == 1, "last-chance screen should display the final intact gem before confirm")

	screen.handle_input(_mouse_click(Vector2(100.0, 100.0)), owner, registry, Vector2(1280.0, 720.0))
	_expect(screen.is_active() and _continue_calls == 0, "outside mouse click should be swallowed without continuing")

	screen.handle_input(_mouse_click(Vector2(640.0, 669.0)), owner, registry, Vector2(1280.0, 720.0))
	_expect(screen.is_active() and screen.is_consuming_continue(), "button click should start the continue cinematic")
	_expect(_consume_calls == 1 and _continue_calls == 0, "button click should consume once but delay the reset callback")


func _verify_modal_gate_and_runtime_wiring() -> void:
	var registry := FakeRegistry.new()
	var screen := DefeatChanceGemsContinueScreen.new()
	registry.continue_screen = screen
	var gate := BattleSceneModalGateController.new()
	_expect(not gate.should_block_battle_physics(Callable(registry, "get_instance")), "inactive chance gem screen should not block physics")
	screen.show(FakeOwner.new(), registry, Callable(self, "_record_continue"))
	_expect(gate.is_defeat_chance_gems_continue_active(Callable(registry, "get_instance")), "modal gate should expose chance gem screen activity")
	_expect(gate.should_block_battle_physics(Callable(registry, "get_instance")), "active chance gem screen should block battle physics")
	screen.handle_input(_key_confirm(), FakeOwner.new(), registry, Vector2(1280.0, 720.0))
	screen.update(3.0)
	_expect(screen.is_active() and gate.should_block_battle_physics(Callable(registry, "get_instance")), "revival beat should extend modal physics blocking after the hidden reset")
	screen.update(3.10)
	_expect(not gate.should_block_battle_physics(Callable(registry, "get_instance")), "modal gate should release once the revival beat finishes")
	screen.reset()
	registry.continue_screen = null

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_core_module_catalog.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_match_flow_driver.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var continue_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	var audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	var resources_source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	_expect(catalog_source.find("defeat_chance_gems_continue_screen") >= 0, "chance gem continue screen should be registered in the core module catalog")
	_expect(catalog_source.find("defeat_continue_revival_beat_state") >= 0, "continue revival beat state should be registered in the core module catalog")
	_expect(flow_source.find("_show_defeat_continue_screen") >= 0, "match flow should route chance gem defeats through the continue screen")
	_expect(flow_source.find("continue_screen.prewarm_assets()") >= 0, "match flow should prewarm chance gem textures before opening the screen")
	_expect(frame_source.find("process.frame.defeat_chance_gems_continue") >= 0, "frame controller should update the chance gem continue screen")
	_expect(frame_source.find("draw.frame.defeat_chance_gems_continue") >= 0, "frame controller should draw the chance gem continue screen")
	_expect(frame_source.find("physics.frame.gate.defeat_chance_gems_continue") >= 0, "frame controller should stop physics while the screen is active")
	_expect(input_source.find("_handle_defeat_chance_gems_continue_input") >= 0, "input controller should route input to the chance gem continue screen")
	_expect(continue_source.find("DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH") >= 0, "continue screen should define the full-screen defeat backdrop PNG path")
	_expect(continue_source.find("_draw_scene_backdrop") >= 0, "continue screen should draw a full-screen defeat scene backdrop")
	_expect(continue_source.find("_animate_backdrop_rect") < 0 and continue_source.find("_draw_portal_breath") < 0, "continue screen should keep the full-screen backdrop static")
	_expect(continue_source.find("_draw_ambient_divine_motion") >= 0, "continue screen should add constant foreground divine ambient motion")
	_expect(continue_source.find("_draw_ambient_divine_motes") >= 0 and continue_source.find("_draw_ambient_light_shafts") >= 0 and continue_source.find("_draw_ambient_portal_glow") >= 0, "ambient divine motion should be motes, fixed fan light shafts, and foreground portal glow")
	_expect(continue_source.find("AMBIENT_DIVINE_MOTE_COUNT") >= 0 and continue_source.find("AMBIENT_DIVINE_RAY_COUNT") >= 0, "ambient divine motion should use bounded fixed-count elements")
	_expect(continue_source.find("elapsed_sec * TAU * AMBIENT_DIVINE_PORTAL_BREATH_HZ") >= 0, "ambient divine motion should be driven from the existing screen elapsed clock")
	_expect(continue_source.find("canvas.draw_line(start, end") >= 0, "ambient god rays should be line-based instead of animated filled polygons")
	_expect(continue_source.find("_draw_backdrop_vignette_bands") >= 0, "continue screen should soften backdrop readability scrims with vignette bands")
	_expect(continue_source.find("view_size.y * 0.24") < 0 and continue_source.find("view_size.y * 0.74") < 0, "continue screen should not reintroduce hard horizontal scrim bands")
	_expect(continue_source.find("_draw_reveal_veil") >= 0 and continue_source.find("_draw_entry_reveal_glow") >= 0, "continue screen should add entry reveal as a foreground overlay")
	_expect(continue_source.find("REVEAL_DURATION_SEC") >= 0 and continue_source.find("get_reveal_progress") >= 0, "entry reveal should be driven by its own elapsed timer")
	_expect(continue_source.find("_draw_boss_portal_figure") >= 0, "continue screen should composite the cached boss victory sheet in the portal")
	_expect(continue_source.find("get_resource_cache") >= 0 and continue_source.find("boss_victory_sheet") >= 0, "continue screen should use the prewarmed boss victory texture cache for portal composition")
	_expect(continue_source.find("PANEL_SIZE") < 0, "continue screen should not keep the compact panel layout")
	_expect(continue_source.find("CHANCE_GEM_FULL_TEXTURE_PATH") >= 0, "continue screen should define the full chance gem PNG path")
	_expect(continue_source.find("CHANCE_GEM_BROKEN_TEXTURE_PATH") >= 0, "continue screen should define the broken chance gem PNG path")
	_expect(continue_source.find("CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH") >= 0, "continue screen should define the AutoSprite shatter sheet path")
	_expect(continue_source.find("GEM_SHATTER_FRAME_COUNT := 64") >= 0 and continue_source.find("GEM_SHATTER_SHEET_COLS := 8") >= 0, "chance gem shatter animation should use a 64-frame 8x8 sheet")
	_expect(continue_source.find("draw_texture_rect") >= 0, "continue screen should render chance gems from PNG textures")
	_expect(continue_source.find("_draw_gem_shatter_sheet") >= 0 and continue_source.find("draw_texture_rect_region") >= 0, "freshly consumed chance gems should play the AutoSprite shatter sheet")
	_expect(continue_source.find("GEM_SHATTER_HANDOFF_SEC") >= 0 and continue_source.find("handoff_progress") >= 0, "chance gem shatter should crossfade into the static broken gem instead of hard-swapping")
	_expect(continue_source.find("_get_static_gem_frame_size") >= 0 and continue_source.find("GEM_SHATTER_FALLBACK_FRAME_SIZE") >= 0, "chance gem shatter frames should render in the same frame as the static gem PNGs")
	_expect(continue_source.find("_draw_gem_break_impact") >= 0 and continue_source.find("_draw_gem_break_sparkles") >= 0, "freshly consumed chance gems should add a short impact overlay beat")
	_expect(continue_source.find("ImpactFlareTextureCache") >= 0 and continue_source.find("_prewarm_liveliness_effects") >= 0, "liveliness flare textures should be prewarmed before draw")
	_expect(continue_source.find("DefeatGemShatterFxHost") >= 0, "continue screen should own the cyan WritheEmber shatter host")
	_expect(continue_source.find("DefeatGemShatterFxHost.prewarm_assets()") >= 0, "continue screen should prewarm the cyan shatter host before draw/update sync")
	_expect(continue_source.find("DefeatContinueColorRestoreFxHost") >= 0, "continue screen should own the color-restore screen postprocess host")
	_expect(continue_source.find("DefeatContinueColorRestoreFxHost.prewarm_assets()") >= 0, "continue screen should prewarm the color-restore shader before the revival beat")
	_expect(continue_source.find("DefeatContinueRevivalBeatState.prewarm_assets()") >= 0, "continue screen should prewarm the continue revival beat assets before reset")
	_expect(continue_source.find("_start_continue_revival_beat") >= 0 and continue_source.find("_is_continue_revival_beat_active") >= 0, "continue screen should start and gate on the post-reset revival beat")
	_expect(continue_source.find("beat_state.blocks_battle_physics()") >= 0, "continue screen should gate on the beat's physics-block contract, not a dead active mirror")
	_expect(continue_source.find("_ensure_gem_shatter_fx_host") >= 0 and continue_source.find("_sync_gem_shatter_fx_host") >= 0, "continue screen should create the shatter host outside draw and sync it from the shatter clock")
	_expect(continue_source.find("_set_gem_shatter_fx_active(false)") >= 0, "continue screen reset should shut down the shatter host")
	_expect(continue_source.find("_ensure_color_restore_fx_host") >= 0 and continue_source.find("_sync_color_restore_fx_host") >= 0, "continue screen should create the color-restore host outside draw and sync it from the revival beat")
	_expect(continue_source.find("_set_color_restore_fx_active(false)") >= 0, "continue screen reset should shut down the color-restore host")
	_expect(continue_source.find("get_color_restore_status") >= 0, "continue screen should drive the color-restore host from the revival beat state")
	_expect(continue_source.find("show_with_consume") >= 0 and continue_source.find("confirm_elapsed") >= 0, "continue screen should consume through the confirm cinematic clock")
	_expect(continue_source.find("_play_defeat_jewel_sfx") >= 0 and continue_source.find("\"game_audio\"") >= 0, "continue screen should play the defeat jewel sfx when the confirm cinematic starts")
	_expect(continue_source.find("_shatter_sfx_fired") >= 0 and continue_source.find("_fire_shatter_sfx_if_ready") >= 0, "continue screen should gate the shatter sfx with a one-shot flag")
	_expect(continue_source.find("_play_defeat_gem_shatter_sfx") >= 0 and continue_source.find("play_defeat_gem_shatter") >= 0, "continue screen should play the gem shatter sfx at the shatter start time")
	_expect(continue_source.find("CONFIRM_SHAKE_DURATION_SEC") >= 0 and continue_source.find("CONFIRM_WHITEOUT_START_SEC") >= 0, "continue screen should define shake and whiteout timing")
	_expect(continue_source.find("IMPACT_FLASH_DURATION_SEC") >= 0 and continue_source.find("_draw_shatter_impact_layers") >= 0, "continue screen should add S-CC2 impact visual envelopes on the confirm clock")
	_expect(continue_source.find("_draw_pre_shatter_cracks") >= 0 and continue_source.find("_draw_pre_shatter_charge") >= 0, "continue screen should add pre-shatter crack and charge buildup")
	_expect(continue_source.find("_draw_impact_chroma_split") >= 0 and continue_source.find("_draw_impact_light_beams") >= 0, "continue screen should gate chroma split and light beams to the shatter impact window")
	_expect(continue_source.find("blocks_battle_physics") >= 0, "continue screen should release battle blocking during fadeback while it still draws")
	_expect(continue_source.find("_get_consumed_gem_center") >= 0 and continue_source.find("\"gem_center\"") >= 0, "continue screen should drive the shatter host from the consumed slot center")
	_expect(continue_source.find("game_offset") < 0 and continue_source.find("render_scale") < 0, "continue screen shatter host sync should stay in screen-space coordinates")
	_expect(continue_source.find("draw_set_transform") < 0, "continue screen liveliness should not use transform-reset animation")
	_expect(continue_source.find("var consumed: int = max_gems - _get_visual_remaining_gems()") >= 0, "chance gem gauge should calculate consumed slots from the cinematic visual state")
	_expect(continue_source.find("i < consumed") >= 0 and continue_source.find("_get_breaking_gem_index") >= 0, "chance gem gauge should break left-to-right")
	_expect(continue_source.find("_draw_gem_extinction_fx") < 0 and continue_source.find("_draw_gem_fading_motes") < 0, "chance gem shatter should not use the old procedural extinction effect")
	_expect(resources_source.find("defeat_continue_backdrop_texture") >= 0, "boss score result texture queue should prewarm the defeat backdrop texture")
	_expect(resources_source.find("chance_gem_full_texture") >= 0 and resources_source.find("chance_gem_broken_texture") >= 0, "boss score result texture queue should prewarm chance gem PNG textures")
	_expect(resources_source.find("chance_gem_shatter_sheet_texture") >= 0, "boss score result texture queue should prewarm the AutoSprite shatter sheet")
	_expect(audio_source.find("DEFEAT_JEWEL_SOUND_PATH") >= 0 and audio_source.find("defeatjewel1.wav") >= 0, "game audio should define the defeat jewel sound path")
	_expect(audio_source.find("defeat_jewel_sfx = player_factory.create") >= 0 and audio_source.find("DefeatJewelSfx") >= 0, "game audio should create the defeat jewel sfx player")
	_expect(audio_source.find("func play_defeat_jewel") >= 0 and audio_source.find("_play_with_pitch(defeat_jewel_sfx") >= 0, "game audio should expose a pitched defeat jewel one-shot")
	_expect(audio_source.find("DEFEAT_GEM_SHATTER_SOUND_PATH") >= 0 and audio_source.find("defeat_gem_shatter.wav") >= 0, "game audio should define the defeat gem shatter sound path")
	_expect(audio_source.find("defeat_gem_shatter_sfx = player_factory.create") >= 0 and audio_source.find("DefeatGemShatterSfx") >= 0, "game audio should create the defeat gem shatter sfx player")
	_expect(audio_source.find("func play_defeat_gem_shatter") >= 0 and audio_source.find("_play_with_pitch(defeat_gem_shatter_sfx") >= 0, "game audio should expose a pitched defeat gem shatter one-shot")


func _record_continue() -> void:
	_continue_calls += 1


func _record_consume() -> int:
	_consume_calls += 1
	return _next_consume_remaining


func _key_confirm() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	return event


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
