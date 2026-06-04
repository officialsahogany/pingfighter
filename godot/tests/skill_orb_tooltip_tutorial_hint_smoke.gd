extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SkillOrbTooltipTutorialHint := preload("res://scripts/hud/skill_orb_tooltip_tutorial_hint.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}
var _active_modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "smasher"
	var special_gauge := 0.0


class FakeSkillState:
	extends RefCounted

	var cooldown_ratios: Dictionary = {}

	func get_cooldown_remaining(skill_name: String, _time_now: int, _cooldown_seconds: float) -> float:
		return float(cooldown_ratios.get(skill_name, 0.0))


class FakeJuniorHint:
	extends RefCounted

	var active := false
	var dash_completed := false

	func is_active() -> bool:
		return active

	func has_completed_dash_tutorial() -> bool:
		return dash_completed


class FakeHoverState:
	extends RefCounted

	var result: Dictionary = {}

	func update_hover_state(_owner: Object, _registry: Object) -> Dictionary:
		return result


class FakeTooltipDriver:
	extends RefCounted

	var queue_calls := 0

	func queue_tooltip_overlay_redraw(_owner: Object, _registry: Object) -> void:
		queue_calls += 1


class FakeRegistry:
	extends RefCounted

	var skill_config: Object = SmasherSkillConfig.new()
	var skill_state: Object = FakeSkillState.new()
	var extra_instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		if extra_instances.has(key):
			return extra_instances[key]
		match key:
			"smasher_skill_config":
				return skill_config
			"smasher_skill_state":
				return skill_state
		return null


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_runtime_wiring()
	_verify_waits_for_ready_drive_gauge()
	_verify_grip_specific_messages_and_language_switching()
	_verify_blocks_while_movement_tutorial_is_active()
	_verify_focus_freeze_until_target_tooltip_seen()
	_verify_dialogue_advances_to_pointer_animation()
	_verify_power_smashing_gets_its_own_hint_after_drive()
	_verify_cooldown_blocks_ready_hint()
	_verify_non_junior_or_non_mika_does_not_start()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("skill_orb_tooltip_tutorial_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var hint_module: Object = registry.get_instance("skill_orb_tooltip_tutorial_hint")
	_expect(hint_module != null and hint_module.has_method("update"), "skill tooltip tutorial hint should be registered in the HUD module catalog")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("skill_orb_tooltip_tutorial_hint") >= 0, "battle frame controller should update and draw the skill tooltip tutorial hint")
	var hint_source: String = FileAccess.get_file_as_string("res://scripts/hud/skill_orb_tooltip_tutorial_hint.gd")
	var hint_renderer_source: String = FileAccess.get_file_as_string("res://scripts/hud/skill_orb_tooltip_tutorial_hint_renderer.gd")
	_expect(hint_renderer_source.find("_draw_guidance_pointer") >= 0, "skill tutorial should draw a guided cursor toward the orb")
	_expect(hint_renderer_source.find("POINTER_TRAIL_COUNT") >= 0, "skill tutorial cursor should include trail afterimages")
	_expect(hint_source.find("handle_input") >= 0, "skill tutorial should advance dialogue through input")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	_expect(input_source.find("skill_orb_tooltip_tutorial_hint") >= 0, "overlay input controller should route input to the active skill tutorial")
	_expect(hint_source.find("POST_DASH_TUTORIAL_DELAY_SECONDS := 5.0") >= 0, "skill tutorial should wait after the dash tutorial before showing Drive")
	_expect(hint_source.find("BETWEEN_SKILL_TUTORIAL_DELAY_SECONDS := 5.0") >= 0, "skill tutorial should wait between Drive and Power Smashing hints")


func _verify_waits_for_ready_drive_gauge() -> void:
	var owner := _make_owner("space_arrows")
	var registry := FakeRegistry.new()
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	owner.special_gauge = 149.0
	_expect(not hint.update(0.0, owner, registry), "tooltip tutorial should wait until Drive has enough gauge")
	owner.special_gauge = 150.0
	_expect(hint.update(0.0, owner, registry), "tooltip tutorial should start when Drive becomes usable")
	_expect(str(hint.get_snapshot().get("target_skill", "")) == "drive", "first ready hint should target Drive")
	_expect(int(hint.get_snapshot().get("dialogue_index", -1)) == 0, "ready skill hint should start on the first dialogue paragraph")
	_expect(_get_array(hint.get_snapshot().get("message_lines", [])).size() == 1, "ready skill hint should show one dialogue paragraph at a time")
	_expect(hint.get_highlight_rect(owner, registry, Vector2(1280.0, 720.0)).size != Vector2.ZERO, "ready skill hint should expose a target orb highlight rect")


func _verify_grip_specific_messages_and_language_switching() -> void:
	var registry := FakeRegistry.new()
	var wasd_owner := _make_owner("wasd_mouse")
	wasd_owner.special_gauge = 150.0
	var wasd_hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(wasd_hint.update(0.0, wasd_owner, registry), "WASD+mouse grip should start the ready skill hint")
	wasd_hint.handle_input(_left_click_event(), wasd_owner, registry)
	wasd_hint.handle_input(_space_event(), wasd_owner, registry)
	_expect(str(wasd_hint.get_snapshot().get("message", "")).find("마우스") >= 0, "WASD+mouse grip should explain mouse hover")

	var gamepad_owner := _make_owner("gamepad")
	gamepad_owner.special_gauge = 150.0
	var gamepad_hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(gamepad_hint.update(0.0, gamepad_owner, registry), "gamepad grip should start the ready skill hint")
	gamepad_hint.handle_input(_space_event(), gamepad_owner, registry)
	gamepad_hint.handle_input(_space_event(), gamepad_owner, registry)
	_expect(str(gamepad_hint.get_snapshot().get("message", "")).find("View") >= 0, "gamepad grip should explain View button tooltip access")

	var arrows_owner := _make_owner("space_arrows")
	arrows_owner.special_gauge = 150.0
	var arrows_hint: Object = SkillOrbTooltipTutorialHint.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_expect(arrows_hint.update(0.0, arrows_owner, registry), "arrow-space hint should start in Korean")
	arrows_hint.handle_input(_left_click_event(), arrows_owner, registry)
	arrows_hint.handle_input(_left_click_event(), arrows_owner, registry)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(arrows_hint.update(0.0, arrows_owner, registry), "active ready skill hint should request redraw when language changes")
	_expect(str(arrows_hint.get_snapshot().get("message", "")) == "Press Shift to open the skill orb details.", "active ready skill hint should switch to English live")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_blocks_while_movement_tutorial_is_active() -> void:
	var owner := _make_owner("space_arrows")
	owner.special_gauge = 150.0
	var registry := FakeRegistry.new()
	var junior_hint := FakeJuniorHint.new()
	junior_hint.active = true
	_active_modules = {"junior_mika_tutorial_hint": junior_hint}
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(not hint.update(0.0, owner, registry, Callable(self, "_get_module")), "skill tooltip tutorial should wait while movement/dash tutorial is visible")
	junior_hint.active = false
	_expect(not hint.update(0.0, owner, registry, Callable(self, "_get_module")), "skill tooltip tutorial should wait until the player has used dash")
	junior_hint.dash_completed = true
	_expect(not hint.update(0.0, owner, registry, Callable(self, "_get_module")), "skill tooltip tutorial should not start immediately after dash completion")
	_expect(not hint.update(4.9, owner, registry, Callable(self, "_get_module")), "skill tooltip tutorial should wait through the post-dash grace period")
	_expect(hint.update(0.1, owner, registry, Callable(self, "_get_module")), "skill tooltip tutorial should start after the 5s post-dash grace period")
	_active_modules.clear()


func _verify_focus_freeze_until_target_tooltip_seen() -> void:
	var owner := _make_owner("space_arrows")
	owner.special_gauge = 150.0
	var registry := FakeRegistry.new()
	var hover_state := FakeHoverState.new()
	var tooltip_driver := FakeTooltipDriver.new()
	registry.extra_instances["skill_orb_tooltip_hover_state"] = hover_state
	registry.extra_instances["battle_scene_skill_tooltip_driver"] = tooltip_driver
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(hint.update(0.0, owner, registry), "ready skill tutorial should start before the tooltip is opened")
	_expect(bool(hint.get_snapshot().get("active", false)), "ready skill tutorial should remain active while waiting for the target tooltip")

	var modal_gate := BattleSceneModalGateController.new()
	_active_modules = {"skill_orb_tooltip_tutorial_hint": hint}
	_expect(
		modal_gate.is_skill_orb_tooltip_tutorial_active(Callable(self, "_get_module")),
		"modal gate should expose active skill orb tooltip tutorial focus"
	)
	_expect(
		modal_gate.should_block_battle_physics(Callable(self, "_get_module")),
		"active skill orb tooltip tutorial focus should freeze battle physics"
	)

	hover_state.result = {"skill_name": "power_smashing"}
	_expect(hint.update(0.016, owner, registry), "wrong skill tooltip hover should still request focus redraw")
	_expect(bool(hint.get_snapshot().get("active", false)), "wrong skill tooltip should not release the Drive focus")

	hover_state.result = {"skill_name": "drive"}
	_expect(hint.update(0.016, owner, registry), "early target hover should still redraw while dialogue is not on the instruction paragraph")
	_expect(bool(hint.get_snapshot().get("active", false)), "early target hover should not skip the dialogue paragraphs")
	hint.handle_input(_left_click_event(), owner, registry)
	hint.handle_input(_space_event(), owner, registry)
	_expect(hint.update(0.016, owner, registry), "target skill tooltip hover should complete the focus tutorial")
	_expect(not bool(hint.get_snapshot().get("active", true)), "target skill tooltip should release the focus freeze")
	_expect(bool(_get_dictionary(hint.get_snapshot().get("completed_skills", {})).get("drive", false)), "target skill tooltip should mark Drive tutorial complete")
	_expect(tooltip_driver.queue_calls == 1, "target skill tooltip completion should redraw the real tooltip overlay")
	_expect(
		not modal_gate.should_block_battle_physics(Callable(self, "_get_module")),
		"completed skill orb tooltip tutorial should stop blocking battle physics"
	)
	_active_modules.clear()


func _verify_dialogue_advances_to_pointer_animation() -> void:
	var owner := _make_owner("wasd_mouse")
	owner.special_gauge = 150.0
	var registry := FakeRegistry.new()
	var tooltip_driver := FakeTooltipDriver.new()
	registry.extra_instances["battle_scene_skill_tooltip_driver"] = tooltip_driver
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(hint.update(0.0, owner, registry), "guided skill tutorial should start when Drive is ready")
	_expect(float(hint.get_snapshot().get("pointer_progress", -1.0)) == 0.0, "guided cursor should start before moving")
	_expect(hint.update(4.0, owner, registry), "dialogue tutorial should redraw fade timing without auto-advancing")
	_expect(bool(hint.get_snapshot().get("active", false)), "dialogue tutorial should stay active until player advances it")
	_expect(int(hint.get_snapshot().get("dialogue_index", -1)) == 0, "dialogue tutorial should not advance by timeout")
	_expect(hint.handle_input(_left_click_event(), owner, registry), "left click should advance the skill tutorial dialogue")
	_expect(int(hint.get_snapshot().get("dialogue_index", -1)) == 1, "left click should move to the second paragraph")
	_expect(hint.handle_input(_space_event(), owner, registry), "Space should advance the skill tutorial dialogue")
	_expect(int(hint.get_snapshot().get("dialogue_index", -1)) == 2, "Space should move to the instruction paragraph")
	_expect(hint.handle_input(_joy_a_event(), owner, registry), "gamepad A should start the cursor animation from the instruction paragraph")
	_expect(str(hint.get_snapshot().get("phase", "")) == "pointer", "final advance should switch to cursor animation phase")
	_expect(_get_array(hint.get_snapshot().get("message_lines", [])).is_empty(), "cursor animation phase should hide the dialogue card")
	_expect(hint.update(0.65, owner, registry), "guided cursor movement should request redraw during the pointer animation")
	var mid_progress := float(hint.get_snapshot().get("pointer_progress", 0.0))
	_expect(mid_progress > 0.0 and mid_progress < 1.0, "guided cursor should move toward the orb after the final advance")
	_expect(bool(hint.get_snapshot().get("active", false)), "guided skill tutorial should still freeze while the cursor is moving")
	_expect(hint.update(0.9, owner, registry), "guided skill tutorial should redraw when the pointer animation completes")
	_expect(not bool(hint.get_snapshot().get("active", true)), "guided skill tutorial should return to play after the cursor animation")
	_expect(bool(_get_dictionary(hint.get_snapshot().get("completed_skills", {})).get("drive", false)), "guided pointer animation should count Drive tutorial as complete")
	_expect(tooltip_driver.queue_calls == 0, "guided pointer animation should not force-open a tooltip overlay")


func _verify_power_smashing_gets_its_own_hint_after_drive() -> void:
	var owner := _make_owner("space_arrows")
	owner.special_gauge = 300.0
	var registry := FakeRegistry.new()
	var hover_state := FakeHoverState.new()
	registry.extra_instances["skill_orb_tooltip_hover_state"] = hover_state
	registry.extra_instances["battle_scene_skill_tooltip_driver"] = FakeTooltipDriver.new()
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(hint.update(0.0, owner, registry), "ready hint should start at high gauge")
	_expect(str(hint.get_snapshot().get("target_skill", "")) == "drive", "Drive hint should appear before Power Smashing when both become ready at once")
	hint.handle_input(_left_click_event(), owner, registry)
	hint.handle_input(_space_event(), owner, registry)
	hover_state.result = {"skill_name": "drive"}
	hint.update(0.016, owner, registry)
	_expect(not bool(hint.get_snapshot().get("active", true)), "first ready skill hint should end after its tooltip is opened")
	hover_state.result = {}
	_expect(not hint.update(0.0, owner, registry), "Power Smashing hint should not start immediately after the Drive hint")
	_expect(not hint.update(4.9, owner, registry), "Power Smashing hint should wait through the post-Drive grace period")
	_expect(hint.update(0.1, owner, registry), "Power Smashing hint should start after the 5s post-Drive grace period")
	_expect(str(hint.get_snapshot().get("target_skill", "")) == "power_smashing", "second ready hint should target Power Smashing")
	_expect(str(hint.get_snapshot().get("phase", "")) == "pointer", "Power Smashing tutorial should skip multi-step dialogue")
	_expect(str(hint.get_snapshot().get("message", "")) == "파워스매싱도 준비되었습니다. 사용법을 확인해보세요!", "Power Smashing tutorial should use the short follow-up message")
	_expect(float(hint.get_snapshot().get("pointer_progress", -1.0)) == 0.0, "Power Smashing cursor animation should start immediately")
	_expect(hint.update(0.65, owner, registry), "Power Smashing cursor animation should request redraw while moving")
	var power_progress := float(hint.get_snapshot().get("pointer_progress", 0.0))
	_expect(power_progress > 0.0 and power_progress < 1.0, "Power Smashing cursor animation should move toward the orb")
	_expect(hint.update(0.9, owner, registry), "Power Smashing tutorial should redraw when the cursor animation completes")
	_expect(not bool(hint.get_snapshot().get("active", true)), "Power Smashing tutorial should end after the cursor animation")
	_expect(bool(_get_dictionary(hint.get_snapshot().get("completed_skills", {})).get("power_smashing", false)), "Power Smashing cursor animation should mark tutorial complete")


func _verify_cooldown_blocks_ready_hint() -> void:
	var owner := _make_owner("space_arrows")
	owner.special_gauge = 150.0
	var registry := FakeRegistry.new()
	registry.skill_state.cooldown_ratios["drive"] = 0.5
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	_expect(not hint.update(0.0, owner, registry), "tooltip tutorial should not start for a skill that is still on cooldown")


func _verify_non_junior_or_non_mika_does_not_start() -> void:
	var owner := _make_owner("space_arrows")
	owner.special_gauge = 150.0
	var registry := FakeRegistry.new()
	var hint: Object = SkillOrbTooltipTutorialHint.new()
	owner.ai_mode = "champion"
	_expect(not hint.update(0.0, owner, registry), "Champion Mika should not start the junior skill tooltip tutorial")
	owner.ai_mode = "junior"
	owner.selected_character_type = "viper"
	_expect(not hint.update(0.0, owner, registry), "Junior non-Mika character should not start the Mika skill tooltip tutorial")


func _make_owner(grip_style: String) -> FakeOwner:
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", grip_style)
	return owner


func _get_module(key: String) -> Object:
	return _active_modules.get(key, null)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _left_click_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _space_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event


func _joy_a_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
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
