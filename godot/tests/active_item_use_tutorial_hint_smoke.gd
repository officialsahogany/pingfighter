extends SceneTree

const ActiveItemUseTutorialHint := preload("res://scripts/hud/active_item_use_tutorial_hint.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}
var _active_modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "smasher"
	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class FakeSkillTooltipHint:
	extends RefCounted

	var completed := false
	var active := false

	func has_completed_required_tutorials() -> bool:
		return completed

	func is_active() -> bool:
		return active


class FakeJuniorHint:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_runtime_wiring()
	_verify_waits_until_skill_tutorials_complete()
	_verify_item_acquired_after_prerequisites_starts_hint()
	_verify_blocks_while_other_tutorials_are_active()
	_verify_language_switching_and_gamepad_text()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("active_item_use_tutorial_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var hint_module: Object = registry.get_instance("active_item_use_tutorial_hint")
	_expect(hint_module != null and hint_module.has_method("update"), "active item use tutorial hint should be registered in the HUD module catalog")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("active_item_use_tutorial_hint") >= 0, "battle frame controller should update and draw the active item use tutorial hint")


func _verify_waits_until_skill_tutorials_complete() -> void:
	var owner := _make_owner("space_arrows")
	owner.active_item_slots = [{"name": "banana"}]
	var skill_hint := FakeSkillTooltipHint.new()
	skill_hint.completed = false
	_active_modules = {"skill_orb_tooltip_tutorial_hint": skill_hint}
	var hint := ActiveItemUseTutorialHint.new()
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should wait until Drive and Power Smashing tutorials are complete")

	skill_hint.completed = true
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should not start immediately after skill tutorials complete")
	_expect(bool(hint.get_snapshot().get("post_skill_delay_started", false)), "active item tutorial should start the 20s post-skill delay")
	_expect(int(hint.get_snapshot().get("observed_slot_count", -1)) == 1, "active item tutorial delay should baseline already-held items")
	_expect(not hint.update(20.1, owner, FakeRegistry.new(), Callable(self, "_get_module")), "already-held active item should not trigger after the 20s delay")
	owner.active_item_slots.append({"name": "soap"})
	_expect(hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should start for a new item acquired after the 20s delay")
	_expect(str(hint.get_snapshot().get("message", "")).find("2") >= 0, "keyboard active item tutorial should mention the newly acquired slot key")
	_expect(hint.get_highlight_rect(owner, FakeRegistry.new(), Vector2(1280.0, 900.0)).size != Vector2.ZERO, "active item tutorial should expose a HUD slot highlight rect")
	_active_modules.clear()


func _verify_item_acquired_after_prerequisites_starts_hint() -> void:
	var owner := _make_owner("wasd_mouse")
	var skill_hint := FakeSkillTooltipHint.new()
	skill_hint.completed = true
	_active_modules = {"skill_orb_tooltip_tutorial_hint": skill_hint}
	var hint := ActiveItemUseTutorialHint.new()
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should start its post-skill delay with no item baseline")
	_expect(int(hint.get_snapshot().get("observed_slot_count", -1)) == 0, "active item tutorial should baseline zero active items")
	_expect(not hint.update(10.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should still wait during the first half of the delay")

	owner.active_item_slots = [{"name": "boomerang"}]
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "item acquired during the 20s delay should be absorbed into the baseline")
	_expect(int(hint.get_snapshot().get("observed_slot_count", -1)) == 1, "delay baseline should track items acquired before the delay expires")
	_expect(not hint.update(10.1, owner, FakeRegistry.new(), Callable(self, "_get_module")), "item acquired during the delay should not appear when the delay expires")
	_expect(bool(hint.get_snapshot().get("post_skill_delay_ready", false)), "active item tutorial should be armed after the 20s delay")

	owner.active_item_slots.append({"name": "soap"})
	_expect(hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should start when an active item is acquired after the delay")
	_expect(int(hint.get_snapshot().get("target_slot_index", -1)) == 1, "active item tutorial should target the newly appended active slot")
	hint.update(5.0, owner, FakeRegistry.new(), Callable(self, "_get_module"))
	owner.active_item_slots.append({"name": "banana"})
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should only show once")
	_active_modules.clear()


func _verify_blocks_while_other_tutorials_are_active() -> void:
	var owner := _make_owner("space_arrows")
	owner.active_item_slots = [{"name": "banana"}]
	var skill_hint := FakeSkillTooltipHint.new()
	skill_hint.completed = true
	skill_hint.active = true
	_active_modules = {"skill_orb_tooltip_tutorial_hint": skill_hint}
	var hint := ActiveItemUseTutorialHint.new()
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should not overlap the skill tooltip focus tutorial")

	skill_hint.active = false
	var junior_hint := FakeJuniorHint.new()
	junior_hint.active = true
	_active_modules["junior_mika_tutorial_hint"] = junior_hint
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should not overlap the movement or dash tutorial")
	_active_modules.clear()


func _verify_language_switching_and_gamepad_text() -> void:
	var owner := _make_owner("gamepad")
	var skill_hint := FakeSkillTooltipHint.new()
	skill_hint.completed = true
	_active_modules = {"skill_orb_tooltip_tutorial_hint": skill_hint}
	var hint := ActiveItemUseTutorialHint.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_expect(not hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "gamepad active item tutorial should wait through the post-skill delay")
	_expect(not hint.update(20.1, owner, FakeRegistry.new(), Callable(self, "_get_module")), "gamepad active item tutorial should not start without a new post-delay item")
	owner.active_item_slots = [{"name": "banana"}]
	_expect(hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "gamepad active item tutorial should start after a post-delay item pickup")
	_expect(str(hint.get_snapshot().get("message", "")).find("Y") >= 0, "gamepad active item tutorial should explain Y item use")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(hint.update(0.0, owner, FakeRegistry.new(), Callable(self, "_get_module")), "active item tutorial should request redraw when language changes")
	_expect(str(hint.get_snapshot().get("message", "")) == "Use item: LB/RB select, Y use", "active item tutorial should switch to English live")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_active_modules.clear()


func _make_owner(grip_style: String) -> FakeOwner:
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", grip_style)
	return owner


func _get_module(key: String) -> Object:
	return _active_modules.get(key, null)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


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
