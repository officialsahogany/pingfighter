extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const GameplayHudModuleCatalog := preload("res://scripts/resources/gameplay_hud_module_catalog.gd")
const GripStyleSelectionOverlay := preload("res://scripts/hud/grip_style_selection_overlay.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "smasher"
	var view_size := Vector2(1280.0, 720.0)
	var redraw_calls := 0

	func queue_redraw() -> void:
		redraw_calls += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, view_size)


class FakeBallSpawnIntro:
	extends RefCounted

	var active := false
	var overlay_active := false
	var serve_handoff_done := false

	func is_active() -> bool:
		return active

	func is_overlay_active() -> bool:
		return overlay_active

	func _has_completed_serve_handoff() -> bool:
		return serve_handoff_done


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := true
	var player_serves := true
	var round_start_time_msec := 0

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve

	func does_player_serve() -> bool:
		return player_serves

	func get_round_start_time_msec() -> int:
		return round_start_time_msec


class FakeServeFlow:
	extends RefCounted

	var sync_calls := 0

	func sync_current_input_state() -> void:
		sync_calls += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


class FakeModuleGetter:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_catalog_registration()
	_verify_open_after_ball_spawn_intro()
	_verify_pre_input_serve_race_still_opens()
	_verify_realtime_language_switching()
	_verify_mouse_hover_and_click_feedback()
	_verify_selection_input_and_serve_sync()
	_verify_gamepad_axis_threshold_and_a_confirm()
	_verify_modal_gate_and_overlay_input()
	_verify_frame_controller_wiring()

	_restore_language_settings_snapshot()
	if _failures.is_empty():
		print("grip_style_selection_overlay_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_registration() -> void:
	var catalog := GameplayHudModuleCatalog.new()
	var spec: Dictionary = catalog.get_spec("grip_style_selection_overlay")
	_expect(str(spec.get("path", "")) == "res://scripts/hud/grip_style_selection_overlay.gd", "grip overlay should be registered in the HUD module catalog")


func _verify_open_after_ball_spawn_intro() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	var ball_spawn: FakeBallSpawnIntro = modules.modules["stage_ball_spawn_intro"]

	ball_spawn.active = true
	ball_spawn.overlay_active = true
	ball_spawn.serve_handoff_done = true
	_expect(not overlay.update(0.016, owner, registry, Callable(modules, "get_module")), "grip overlay should wait until the spawn overlay is gone")
	_expect(not overlay.is_active(), "grip overlay should remain inactive while spawn overlay is visible")

	ball_spawn.active = false
	ball_spawn.overlay_active = false
	ball_spawn.serve_handoff_done = false
	_expect(overlay.update(0.016, owner, registry, Callable(modules, "get_module")), "grip overlay should open after spawn intro cleanup resets the handoff flag")
	_expect(overlay.is_active(), "grip overlay should become active after opening")
	_expect(overlay.get_card_rects(Vector2(1280.0, 720.0)).size() == 3, "grip overlay should expose three selectable cards")


func _verify_pre_input_serve_race_still_opens() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	var ball_spawn: FakeBallSpawnIntro = modules.modules["stage_ball_spawn_intro"]
	ball_spawn.active = false
	ball_spawn.overlay_active = false
	var round_state: FakeRoundState = registry.instances["round_flow_state"] as FakeRoundState
	round_state.waiting_for_serve = false
	round_state.round_start_time_msec = 1234
	_expect(overlay.update(0.0, owner, registry, Callable(modules, "get_module")), "grip overlay should recover even if a pre-open input already changed serve state")
	_expect(overlay.is_active(), "grip overlay should become active after a pre-open serve race")

	var stored_owner := FakeOwner.new()
	stored_owner.set_meta("tutorial_grip_style", "space_arrows")
	var stored_overlay := GripStyleSelectionOverlay.new()
	_expect(not stored_overlay.update(0.0, stored_owner, registry, Callable(modules, "get_module")), "stored grip selection should not reopen the grip overlay")
	_expect(stored_overlay.has_completed(), "stored grip selection should mark the grip overlay complete")
	_expect(stored_overlay.get_selected_style() == "space_arrows", "stored grip selection should preserve the selected style")


func _verify_realtime_language_switching() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	overlay.update(0.016, owner, registry, Callable(modules, "get_module"))
	_expect(str(overlay.get_text_snapshot().get("title", "")) == "파지법 선택", "grip overlay should expose Korean text by default")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(overlay.update(0.0, owner, registry, Callable(modules, "get_module")), "active grip overlay should request redraw when the language changes")
	var english_snapshot: Dictionary = overlay.get_text_snapshot()
	var english_cards: Array = english_snapshot.get("cards", [])
	_expect(str(english_snapshot.get("title", "")) == "Grip Style", "grip overlay title should switch to English live")
	_expect(not english_cards.is_empty() and str((english_cards[0] as Dictionary).get("title", "")) == "WASD + Mouse", "grip card title should switch to English live")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(overlay.update(0.0, owner, registry, Callable(modules, "get_module")), "active grip overlay should request redraw on a second language change")
	var japanese_cards: Array = overlay.get_text_snapshot().get("cards", [])
	_expect(japanese_cards.size() > 1 and str((japanese_cards[1] as Dictionary).get("desc", "")).find("左親指") >= 0, "grip card description should switch to Japanese live")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_mouse_hover_and_click_feedback() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	overlay.update(0.016, owner, registry, Callable(modules, "get_module"))

	var card_rects: Array[Rect2] = overlay.get_card_rects(owner.get_viewport_rect().size)
	var motion := InputEventMouseMotion.new()
	motion.position = card_rects[1].get_center()
	_expect(overlay.handle_input(motion, owner, registry, owner.get_viewport_rect().size), "mouse motion over a grip card should request a redraw")
	_expect(int(overlay.get_snapshot().get("hovered_index", -1)) == 1, "hovering should track the hovered grip card")
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 1, "hovering should move the visible card selection")

	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = card_rects[2].get_center()
	_expect(overlay.handle_input(press, owner, registry, owner.get_viewport_rect().size), "mouse press should be handled by the grip overlay")
	_expect(int(overlay.get_snapshot().get("pressed_index", -1)) == 2, "pressing a grip card should expose a pressed-card state")
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 2, "pressing a grip card should select that card")
	_expect(not bool(overlay.get_snapshot().get("pending_confirm", false)), "mouse press should not immediately close the grip overlay")

	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = card_rects[2].get_center()
	_expect(overlay.handle_input(release, owner, registry, owner.get_viewport_rect().size), "mouse release should be handled by the grip overlay")
	_expect(bool(overlay.get_snapshot().get("pending_confirm", false)), "mouse release on the same card should start a short confirm flash")
	_expect(overlay.is_active(), "grip overlay should stay visible during the click confirm flash")
	overlay.update(0.2, owner, registry, Callable(modules, "get_module"))
	_expect(overlay.has_completed(), "grip overlay should complete after the click confirm flash")
	_expect(overlay.get_selected_style() == "gamepad", "click feedback should preserve the clicked grip card")


func _verify_selection_input_and_serve_sync() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	overlay.update(0.016, owner, registry, Callable(modules, "get_module"))

	var right_event := InputEventKey.new()
	right_event.pressed = true
	right_event.keycode = KEY_RIGHT
	right_event.physical_keycode = KEY_RIGHT
	_expect(overlay.handle_input(right_event, owner, registry, Vector2(1280.0, 720.0)), "right key should be handled by the grip overlay")
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 1, "right key should advance the selected grip card")

	var accept_event := InputEventKey.new()
	accept_event.pressed = true
	accept_event.keycode = KEY_ENTER
	accept_event.physical_keycode = KEY_ENTER
	_expect(overlay.handle_input(accept_event, owner, registry, Vector2(1280.0, 720.0)), "enter should confirm the selected grip card")
	_expect(overlay.has_completed(), "grip overlay should complete after confirmation")
	_expect(not overlay.is_active(), "grip overlay should close after confirmation")
	_expect(overlay.get_selected_style() == "space_arrows", "confirmed grip style should match the selected card")
	_expect(str(owner.get_meta("tutorial_grip_style", "")) == "space_arrows", "confirmed grip style should be stored on the owner metadata")
	_expect(int(registry.instances["serve_flow_controller"].sync_calls) == 1, "confirming grip should sync serve input so the confirm key does not launch serve")


func _verify_gamepad_axis_threshold_and_a_confirm() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	overlay.update(0.016, owner, registry, Callable(modules, "get_module"))

	_expect(overlay.handle_input(_axis(JOY_AXIS_LEFT_X, 0.86), owner, registry, Vector2(1280.0, 720.0)), "left-stick motion should be consumed by the grip overlay")
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 0, "sub-threshold left-stick motion should not move grip selection")

	overlay.handle_input(_axis(JOY_AXIS_LEFT_X, 0.93), owner, registry, Vector2(1280.0, 720.0))
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 1, "firm left-stick motion should move grip selection once")

	overlay.handle_input(_axis(JOY_AXIS_LEFT_X, 0.96), owner, registry, Vector2(1280.0, 720.0))
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 1, "held left-stick motion should not repeatedly move grip selection")

	overlay.handle_input(_axis(JOY_AXIS_LEFT_X, 0.0), owner, registry, Vector2(1280.0, 720.0))
	overlay.handle_input(_axis(JOY_AXIS_LEFT_X, 0.93), owner, registry, Vector2(1280.0, 720.0))
	_expect(int(overlay.get_snapshot().get("selected_index", -1)) == 2, "left-stick motion should move again after returning to neutral")

	_expect(overlay.handle_input(_button(JOY_BUTTON_A), owner, registry, Vector2(1280.0, 720.0)), "Xbox A should confirm the selected grip card")
	_expect(overlay.has_completed(), "Xbox A should complete the grip selection")
	_expect(overlay.get_selected_style() == "gamepad", "Xbox A should preserve the currently selected grip")
	_expect(int(registry.instances["serve_flow_controller"].sync_calls) == 1, "Xbox A confirm should sync serve input")


func _verify_modal_gate_and_overlay_input() -> void:
	var owner := FakeOwner.new()
	var registry := _build_registry()
	var modules := _build_modules()
	var overlay := GripStyleSelectionOverlay.new()
	var modal_gate := BattleSceneModalGateController.new()
	modules.modules["grip_style_selection_overlay"] = overlay
	modules.modules["battle_scene_modal_gate_controller"] = modal_gate
	overlay.update(0.016, owner, registry, Callable(modules, "get_module"))

	_expect(modal_gate.is_grip_style_selection_active(Callable(modules, "get_module")), "modal gate should expose grip selection activity")
	_expect(modal_gate.should_block_battle_physics(Callable(modules, "get_module")), "active grip selection should block battle physics")

	var input := BattleSceneOverlayInputController.new()
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = overlay.get_card_rects(owner.get_viewport_rect().size)[2].get_center()
	_expect(input.handle_input(click, owner, registry, Callable(modules, "get_module"), {}), "overlay input controller should route click presses to active grip selection")
	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = click.position
	_expect(input.handle_input(release, owner, registry, Callable(modules, "get_module"), {}), "overlay input controller should route click releases to active grip selection")
	overlay.update(0.2, owner, registry, Callable(modules, "get_module"))
	_expect(overlay.get_selected_style() == "gamepad", "clicking the third grip card should select gamepad")


func _verify_frame_controller_wiring() -> void:
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	var modal_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(frame_source.find("grip_style_selection_overlay") >= 0, "battle frame controller should update and draw the grip overlay")
	_expect(frame_source.find("_process_grip_selection_physics_gate") >= 0, "battle frame controller should open grip selection before physics serve updates")
	_expect(input_source.find("grip_style_selection_overlay") >= 0, "overlay input controller should route grip overlay input")
	_expect(modal_source.find("grip_style_selection_overlay") >= 0, "modal gate should block physics while grip overlay is active")


func _build_registry() -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances["round_flow_state"] = FakeRoundState.new()
	registry.instances["serve_flow_controller"] = FakeServeFlow.new()
	return registry


func _build_modules() -> FakeModuleGetter:
	var modules := FakeModuleGetter.new()
	var ball_spawn := FakeBallSpawnIntro.new()
	modules.modules["stage_ball_spawn_intro"] = ball_spawn
	return modules


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button_index
	return event


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	_restore_settings_file(
		LanguageSettings.SETTINGS_PATH,
		bool(_language_settings_snapshot.get("had", false)),
		_language_settings_snapshot.get("bytes", PackedByteArray())
	)
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _restore_settings_file(path: String, had_file: bool, file_bytes: PackedByteArray) -> void:
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(file_bytes)
			file.close()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
