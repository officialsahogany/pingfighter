extends SceneTree
# 바이퍼 체공(제트팩) 안내: 대쉬 완료 후 표시, 실제 체공 시 완료(행동 기반),
# 연습모드 게이트 공급(has_completed_jetpack_tutorial). 키캡 토큰화 봉인 포함.

const ViperJetpackTutorialHint := preload("res://scripts/hud/viper_jetpack_tutorial_hint.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "viper"


class FakeJuniorHint:
	extends RefCounted

	var dash_done := false

	func has_completed_dash_tutorial() -> bool:
		return dash_done


class FakeJetpackState:
	extends RefCounted

	var active := false
	var airborne := false

	func is_airborne(_threshold: float = 0.1) -> bool:
		return airborne


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

	var jetpack_state := FakeJetpackState.new()

	func get_instance(key: String) -> Object:
		if key == "viper_jetpack_state":
			return jetpack_state
		return null


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_runtime_wiring()
	_verify_gating_and_behavior_dismissal()
	_verify_non_viper_never_starts()
	_verify_gamepad_message()
	_verify_keycap_tokenization()

	_restore_language_settings_snapshot()
	if _failures.is_empty():
		print("viper_jetpack_tutorial_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var hint_module: Object = registry.get_instance("viper_jetpack_tutorial_hint")
	_expect(hint_module != null and hint_module.has_method("update"), "viper jetpack hint should be registered in the gameplay module catalog")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("viper_jetpack_tutorial_hint") >= 0, "battle frame controller should update and draw the viper jetpack hint")
	var practice_source: String = FileAccess.get_file_as_string("res://scripts/hud/viper_practice_mode.gd")
	_expect(practice_source.find("viper_jetpack_tutorial_hint") >= 0, "practice mode should gate its start on the jetpack tutorial")


func _verify_gating_and_behavior_dismissal() -> void:
	var holder := ModuleHolder.new()
	var junior := FakeJuniorHint.new()
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = ViperJetpackTutorialHint.new()

	# 대쉬 안내가 끝나기 전에는 시작하지 않는다.
	junior.dash_done = false
	hint.update(30.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "jetpack hint should wait for the dash tutorial to complete")

	# 대쉬 완료 후 대기 시간이 지나야 시작.
	junior.dash_done = true
	hint.update(0.1, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "jetpack hint should wait out its post-dash delay")
	hint.update(2.5, owner, registry, getter)
	_expect(bool(hint.update(0.0, owner, registry, getter)), "jetpack hint should start after the post-dash delay")
	_expect(str(hint.get_snapshot().get("message", "")) == "[LMB] 또는 SPACE 홀드 - 체공", "keyboard grip should teach the left-click/space jetpack hold")

	# 시간이 지나도 체공 전까지는 사라지지 않는다(행동 기반 유지).
	hint.update(10.0, owner, registry, getter)
	_expect(bool(hint.get_snapshot().get("active", false)), "jetpack hint should stay visible until the player actually jetpacks")
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 0.0)), 1.0), "jetpack hint should hold at full alpha while waiting")

	# 플레이어가 실제로 체공하면 완료.
	registry.jetpack_state.airborne = true
	_expect(bool(hint.update(0.016, owner, registry, getter)), "jetpack use should dismiss the hint")
	_expect(not bool(hint.get_snapshot().get("active", true)), "jetpack hint should deactivate once airborne")
	_expect(bool(hint.has_completed_jetpack_tutorial()), "jetpack hint should report completion for the practice-mode gate")
	registry.jetpack_state.airborne = false
	_expect(not bool(hint.update(0.1, owner, registry, getter)), "jetpack hint should not restart in the same battle")


func _verify_non_viper_never_starts() -> void:
	var holder := ModuleHolder.new()
	var junior := FakeJuniorHint.new()
	junior.dash_done = true
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "smasher"
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = ViperJetpackTutorialHint.new()
	for _i in range(4):
		hint.update(3.0, owner, registry, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "jetpack hint must never start for a non-viper character")


func _verify_gamepad_message() -> void:
	var holder := ModuleHolder.new()
	var junior := FakeJuniorHint.new()
	junior.dash_done = true
	holder.modules = {"junior_mika_tutorial_hint": junior}
	var getter := Callable(holder, "get_module")
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("junior_mika_grip_style", "gamepad")
	var hint: Object = ViperJetpackTutorialHint.new()
	hint.update(0.1, owner, registry, getter)
	hint.update(2.5, owner, registry, getter)
	_expect(bool(hint.update(0.0, owner, registry, getter)), "gamepad jetpack hint should start once ready")
	_expect(str(hint.get_snapshot().get("message", "")) == "A / X 홀드 - 체공", "gamepad grip should show the controller jetpack buttons")


# [LMB]는 마우스 아이콘, SPACE는 키캡, '또는/홀드 - 체공'은 텍스트로 남는지 봉인.
func _verify_keycap_tokenization() -> void:
	var tokens: Array = TutorialHintKeycapRenderer.split_render_tokens("[LMB] 또는 SPACE 홀드 - 체공")
	var types: Array = []
	var values: Array = []
	for token_value in tokens:
		var token: Dictionary = token_value
		types.append(str(token.get("type", "text")))
		values.append(str(token.get("value", "")))
	_expect(types == ["mouse", "text", "key", "text"], "jetpack hint should render mouse icon + text + SPACE keycap + text")
	_expect(values == ["left", "또는", "SPACE", "홀드 - 체공"], "jetpack hint token values should match the message layout")


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
