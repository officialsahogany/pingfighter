extends SceneTree

const DefeatChanceGemsContinueScreen := preload("res://scripts/core/defeat_chance_gems_continue_screen.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []
var _continue_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var chance_gems_count := 2
	var chance_gems_max := 3
	var redraws := 0

	func queue_redraw() -> void:
		redraws += 1


class FakeRegistry:
	extends RefCounted

	var continue_screen: Object = null

	func get_instance(key: String) -> Object:
		if key == "defeat_chance_gems_continue_screen":
			return continue_screen
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
	var owner := FakeOwner.new()
	var screen := DefeatChanceGemsContinueScreen.new()
	var registry := FakeRegistry.new()
	registry.continue_screen = screen

	_expect(screen.show(owner, registry, Callable(self, "_record_continue")), "show should open the soft defeat screen")
	_expect(screen.is_active(), "screen should become active after show")
	_expect(screen.remaining_gems == 2 and screen.max_gems == 3, "screen should snapshot owner chance gem mirrors")
	_expect(screen.are_assets_ready(), "show should prewarm defeat continue backdrop and chance gem PNG textures before draw")
	_expect(is_zero_approx(screen.reveal_elapsed) and is_zero_approx(screen.get_reveal_progress()), "entry reveal should start closed on show")
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

	var confirm_event := InputEventKey.new()
	confirm_event.pressed = true
	confirm_event.keycode = KEY_SPACE
	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(not screen.is_active(), "confirm key should close the screen")
	_expect(_continue_calls == 1, "confirm key should call the continue callback once")
	_expect(is_zero_approx(screen.reveal_elapsed) and is_zero_approx(screen.get_reveal_progress()), "closing the screen should reset entry reveal state")

	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(_continue_calls == 1, "closed screen must not call continue again")


func _verify_continue_screen_mouse_button_confirm() -> void:
	_continue_calls = 0
	var owner := FakeOwner.new()
	owner.chance_gems_count = 0
	var screen := DefeatChanceGemsContinueScreen.new()
	var registry := FakeRegistry.new()
	screen.show(owner, registry, Callable(self, "_record_continue"))
	_expect(screen.remaining_gems == 0, "last-chance screen should accept zero remaining gems after consume")

	screen.handle_input(_mouse_click(Vector2(100.0, 100.0)), owner, registry, Vector2(1280.0, 720.0))
	_expect(screen.is_active() and _continue_calls == 0, "outside mouse click should be swallowed without continuing")

	screen.handle_input(_mouse_click(Vector2(640.0, 669.0)), owner, registry, Vector2(1280.0, 720.0))
	_expect(not screen.is_active(), "button click should close the screen")
	_expect(_continue_calls == 1, "button click should call the continue callback")


func _verify_modal_gate_and_runtime_wiring() -> void:
	var registry := FakeRegistry.new()
	var screen := DefeatChanceGemsContinueScreen.new()
	registry.continue_screen = screen
	var gate := BattleSceneModalGateController.new()
	_expect(not gate.should_block_battle_physics(Callable(registry, "get_instance")), "inactive chance gem screen should not block physics")
	screen.show(FakeOwner.new(), registry, Callable(self, "_record_continue"))
	_expect(gate.is_defeat_chance_gems_continue_active(Callable(registry, "get_instance")), "modal gate should expose chance gem screen activity")
	_expect(gate.should_block_battle_physics(Callable(registry, "get_instance")), "active chance gem screen should block battle physics")
	screen.reset()
	registry.continue_screen = null

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_core_module_catalog.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_match_flow_driver.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var continue_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	var resources_source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	_expect(catalog_source.find("defeat_chance_gems_continue_screen") >= 0, "chance gem continue screen should be registered in the core module catalog")
	_expect(flow_source.find("_show_defeat_continue_screen") >= 0, "match flow should route chance gem defeats through the continue screen")
	_expect(flow_source.find("continue_screen.prewarm_assets()") >= 0, "match flow should prewarm chance gem textures before opening the screen")
	_expect(frame_source.find("process.frame.defeat_chance_gems_continue") >= 0, "frame controller should update the chance gem continue screen")
	_expect(frame_source.find("draw.frame.defeat_chance_gems_continue") >= 0, "frame controller should draw the chance gem continue screen")
	_expect(frame_source.find("physics.frame.gate.defeat_chance_gems_continue") >= 0, "frame controller should stop physics while the screen is active")
	_expect(input_source.find("_handle_defeat_chance_gems_continue_input") >= 0, "input controller should route input to the chance gem continue screen")
	_expect(continue_source.find("DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH") >= 0, "continue screen should define the full-screen defeat backdrop PNG path")
	_expect(continue_source.find("_draw_scene_backdrop") >= 0, "continue screen should draw a full-screen defeat scene backdrop")
	_expect(continue_source.find("_animate_backdrop_rect") < 0 and continue_source.find("_draw_portal_breath") < 0, "continue screen should keep the full-screen backdrop static")
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
	_expect(continue_source.find("_draw_gem_break_impact") >= 0 and continue_source.find("_draw_gem_break_sparkles") >= 0, "freshly consumed chance gems should add a short impact overlay beat")
	_expect(continue_source.find("ImpactFlareTextureCache") >= 0 and continue_source.find("_prewarm_liveliness_effects") >= 0, "liveliness flare textures should be prewarmed before draw")
	_expect(continue_source.find("draw_set_transform") < 0, "continue screen liveliness should not use transform-reset animation")
	_expect(continue_source.find("var consumed: int = max_gems - remaining_gems") >= 0, "chance gem gauge should calculate consumed slots")
	_expect(continue_source.find("i < consumed") >= 0 and continue_source.find("i == consumed - 1") >= 0, "chance gem gauge should break left-to-right")
	_expect(continue_source.find("_draw_gem_extinction_fx") < 0 and continue_source.find("_draw_gem_fading_motes") < 0, "chance gem shatter should not use the old procedural extinction effect")
	_expect(resources_source.find("defeat_continue_backdrop_texture") >= 0, "boss score result texture queue should prewarm the defeat backdrop texture")
	_expect(resources_source.find("chance_gem_full_texture") >= 0 and resources_source.find("chance_gem_broken_texture") >= 0, "boss score result texture queue should prewarm chance gem PNG textures")
	_expect(resources_source.find("chance_gem_shatter_sheet_texture") >= 0, "boss score result texture queue should prewarm the AutoSprite shatter sheet")


func _record_continue() -> void:
	_continue_calls += 1


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
