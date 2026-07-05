extends SceneTree

const CommandoFirearmTutorialHint := preload("res://scripts/hud/commando_firearm_tutorial_hint.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "commando"


class FakeJuniorHint:
	extends RefCounted

	var dash_done := false

	func has_completed_dash_tutorial() -> bool:
		return dash_done


class FakeWeaponController:
	extends RefCounted

	var weapons: Array = ["pistol"]

	func get_weapons() -> Array:
		return weapons


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_runtime_wiring()
	_verify_pistol_track()
	_verify_swap_triggers_on_firearm_acquire()
	_verify_swap_does_not_show_without_extra_firearm()
	_verify_non_commando_never_starts()
	_verify_gamepad_message()
	_verify_input_glyph_tokenization()

	_restore_language_settings_snapshot()
	if _failures.is_empty():
		print("commando_firearm_tutorial_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var hint_module: Object = registry.get_instance("commando_firearm_tutorial_hint")
	_expect(hint_module != null and hint_module.has_method("update"), "commando firearm hint should be registered in the gameplay module catalog")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("commando_firearm_tutorial_hint") >= 0, "battle frame controller should update and draw the commando firearm hint")


func _verify_pistol_track() -> void:
	var junior := FakeJuniorHint.new()
	var holder := ModuleHolder.new()
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = CommandoFirearmTutorialHint.new()

	junior.dash_done = false
	hint.update(30.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("pistol_active", false)), "pistol hint should wait for the dash tutorial to complete")

	junior.dash_done = true
	hint.update(0.1, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("pistol_active", false)), "pistol hint should wait out its post-dash delay")

	hint.update(5.0, owner, registry, getter)
	_expect(bool(hint.update(0.0, owner, registry, getter)), "pistol hint should start after the post-dash delay")
	_expect(bool(hint.get_snapshot().get("pistol_active", false)), "pistol hint should become active")
	_expect(str(hint.get_snapshot().get("message", "")) == "[LMB] - 권총 발사", "pistol hint should teach left-click pistol fire")

	# 권총 안내는 단일 시간 단계다: 시간이 지나면 완료되고, 그것만으로 중간 튜토리얼 완료.
	hint.update(5.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("pistol_active", true)), "pistol hint should deactivate after its display window")
	_expect(bool(hint.has_completed_required_tutorials()), "pistol completion alone should satisfy the mid-tutorial gate")
	_expect(not bool(hint.get_snapshot().get("swap_active", false)), "swap hint must not appear during the initial sequence without a second firearm")


func _verify_swap_triggers_on_firearm_acquire() -> void:
	var junior := FakeJuniorHint.new()
	junior.dash_done = true
	var holder := ModuleHolder.new()
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var weapon_controller := FakeWeaponController.new()
	var registry := FakeRegistry.new()
	registry.instances = {"commando_weapon_controller": weapon_controller}
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = CommandoFirearmTutorialHint.new()

	# 권총 트랙을 완료시킨다.
	hint.update(0.1, owner, registry, getter)
	hint.update(5.0, owner, registry, getter)
	hint.update(0.0, owner, registry, getter)
	hint.update(5.0, owner, registry, getter)
	_expect(bool(hint.has_completed_required_tutorials()), "pistol track should complete before firearm acquisition")

	# 기본 권총만 있을 때는 교체 안내가 뜨지 않는다.
	hint.update(0.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("swap_active", false)), "swap hint should stay hidden while only the base pistol is owned")

	# 화기류 퍽/물자보급 대여로 두 번째 화기를 획득 -> weapons.size() == 2.
	weapon_controller.weapons = ["pistol", "bazooka"]
	_expect(bool(hint.update(0.0, owner, registry, getter)), "swap hint should trigger when a second firearm is acquired")
	_expect(bool(hint.get_snapshot().get("swap_active", false)), "swap hint should become active on firearm acquisition")
	_expect(str(hint.get_snapshot().get("message", "")) == "[WHEEL] ( 마우스 휠 돌리기 ) - 화기 교체", "swap hint should show the wheel icon plus the '마우스 휠 돌리기' clarification")

	hint.update(6.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("swap_active", true)), "swap hint should deactivate after its window")
	# 이미 보여준 뒤에는 다시 뜨지 않는다(화기가 계속 여러 개여도).
	_expect(not bool(hint.update(0.0, owner, registry, getter)), "swap hint should not re-trigger once shown")
	_expect(not bool(hint.get_snapshot().get("swap_active", false)), "swap hint should stay hidden after being shown once")


func _verify_swap_does_not_show_without_extra_firearm() -> void:
	var junior := FakeJuniorHint.new()
	junior.dash_done = true
	var holder := ModuleHolder.new()
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var weapon_controller := FakeWeaponController.new()
	weapon_controller.weapons = ["pistol"]
	var registry := FakeRegistry.new()
	registry.instances = {"commando_weapon_controller": weapon_controller}
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = CommandoFirearmTutorialHint.new()
	for _i in range(6):
		hint.update(3.0, owner, registry, getter)
	# swap_shown is a latch that stays true once the hint has appeared; asserting it
	# (not the momentary swap_active) catches a hint that wrongly appeared and finished.
	_expect(not bool(hint.get_snapshot().get("swap_shown", false)), "swap hint must never appear while the commando only holds the base pistol")


func _verify_non_commando_never_starts() -> void:
	var junior := FakeJuniorHint.new()
	junior.dash_done = true
	var holder := ModuleHolder.new()
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var weapon_controller := FakeWeaponController.new()
	weapon_controller.weapons = ["pistol", "bazooka"]
	var registry := FakeRegistry.new()
	registry.instances = {"commando_weapon_controller": weapon_controller}
	var owner := FakeOwner.new()
	owner.selected_character_type = "smasher"
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = CommandoFirearmTutorialHint.new()
	for _i in range(5):
		hint.update(3.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "commando firearm hint must never start for a non-commando character")


func _verify_gamepad_message() -> void:
	var junior := FakeJuniorHint.new()
	junior.dash_done = true
	var holder := ModuleHolder.new()
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("junior_mika_grip_style", "gamepad")
	var hint: Object = CommandoFirearmTutorialHint.new()
	hint.update(0.1, owner, registry, getter)
	hint.update(5.0, owner, registry, getter)
	_expect(bool(hint.update(0.0, owner, registry, getter)), "gamepad commando firearm hint should start once ready")
	_expect(str(hint.get_snapshot().get("message", "")) == "A / X - 발사", "gamepad grip should show the controller fire buttons")


# 마우스 센티넬 [LMB]/[WHEEL]은 마우스 아이콘으로, 게임패드 A/X는 키캡으로 승격되고,
# 휠 옆 '( 마우스 휠 돌리기 )'는 텍스트로 남는지 봉인.
func _verify_input_glyph_tokenization() -> void:
	var pistol: Array = TutorialHintKeycapRenderer.split_render_tokens("[LMB] - 권총 발사")
	_expect(_types(pistol) == ["mouse", "text"] and _values(pistol) == ["left", "- 권총 발사"], "pistol hint should render a left-click mouse glyph plus a text run")

	var swap: Array = TutorialHintKeycapRenderer.split_render_tokens("[WHEEL] ( 마우스 휠 돌리기 ) - 화기 교체")
	_expect(_types(swap) == ["mouse", "text"], "swap hint should render a wheel mouse glyph plus a single text run")
	_expect(_values(swap) == ["wheel", "( 마우스 휠 돌리기 ) - 화기 교체"], "swap hint should keep the '마우스 휠 돌리기' clarification as plain text")

	var gamepad: Array = TutorialHintKeycapRenderer.split_render_tokens("A / X - 발사")
	_expect(_types(gamepad) == ["key", "text", "key", "text"] and _values(gamepad) == ["A", "/", "X", "- 발사"], "gamepad fire hint should keycap A and X only")


func _types(elements: Array) -> Array:
	var result: Array = []
	for element_value in elements:
		var element: Dictionary = element_value
		result.append(str(element.get("type", "text")))
	return result


func _values(elements: Array) -> Array:
	var result: Array = []
	for element_value in elements:
		var element: Dictionary = element_value
		result.append(str(element.get("value", "")))
	return result


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
