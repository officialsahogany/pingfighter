extends SceneTree

const CharacterInfoTutorialHint := preload("res://scripts/hud/character_info_tutorial_hint.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "smasher"


class FakeHintModule:
	extends RefCounted

	var active := false
	var completed := false

	func is_active() -> bool:
		return active

	func has_completed_required_tutorials() -> bool:
		return completed


class ModuleHolder:
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
	_verify_runtime_wiring()
	_verify_gating_order_and_message()
	_verify_gamepad_message()
	_verify_keycap_tokenization()

	_restore_language_settings_snapshot()
	if _failures.is_empty():
		print("character_info_tutorial_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var hint_module: Object = registry.get_instance("character_info_tutorial_hint")
	_expect(hint_module != null and hint_module.has_method("update"), "character info hint should be registered in the gameplay module catalog")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("character_info_tutorial_hint") >= 0, "battle frame controller should update and draw the character info hint")


func _verify_gating_order_and_message() -> void:
	var holder := ModuleHolder.new()
	var skill := FakeHintModule.new()
	var junior := FakeHintModule.new()
	var item := FakeHintModule.new()
	holder.modules = {
		"skill_orb_tooltip_tutorial_hint": skill,
		"junior_mika_tutorial_hint": junior,
		"active_item_use_tutorial_hint": item,
	}
	var getter := Callable(holder, "get_module")
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = CharacterInfoTutorialHint.new()

	# 스킬 툴팁 튜토리얼이 끝나기 전에는 시간이 아무리 흘러도 뜨지 않는다.
	skill.completed = false
	hint.update(30.0, owner, null, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "character info hint should wait until skill tooltip tutorials complete")

	# 스킬 완료 직후에도 대기 시간이 남아 있으면 아직 뜨지 않는다.
	skill.completed = true
	hint.update(0.1, owner, null, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "character info hint should wait out its post-item delay")
	_expect(bool(hint.get_snapshot().get("delay_started", false)), "post-item delay should begin once prerequisites are met")

	# 대기 시간을 모두 채워 준비 상태로 만든다(아직 형제 힌트는 없음).
	hint.update(30.0, owner, null, getter)
	_expect(bool(hint.get_snapshot().get("delay_ready", false)), "post-item delay should be ready after enough time")

	# 준비가 끝났어도 형제 힌트가 활성 중이면 겹치지 않게 막힌다(_display_blocked 경로).
	item.active = true
	hint.update(0.0, owner, null, getter)
	_expect(not bool(hint.get_snapshot().get("active", false)), "character info hint should stay blocked while a sibling tutorial hint is active")

	# 형제 힌트가 끝나면 비로소 표시된다.
	item.active = false
	_expect(bool(hint.update(0.0, owner, null, getter)), "character info hint should start once the delay is ready and no sibling is active")
	_expect(bool(hint.get_snapshot().get("active", false)), "character info hint should become active")
	_expect(str(hint.get_snapshot().get("message", "")) == "TAB - 캐릭터 정보 확인", "keyboard grip should show the TAB character info hint")
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 1.0)), 0.0), "character info hint should begin fully faded out")

	hint.update(0.3, owner, null, getter)
	var fade_in_alpha: float = float(hint.get_snapshot().get("alpha", 0.0))
	_expect(fade_in_alpha > 0.0 and fade_in_alpha < 1.0, "character info hint should fade in over time")

	hint.update(0.5, owner, null, getter)
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 0.0)), 1.0), "character info hint should hold at full alpha")

	hint.update(5.0, owner, null, getter)
	_expect(not bool(hint.get_snapshot().get("active", true)), "character info hint should deactivate after its display window")
	_expect(bool(hint.get_snapshot().get("shown", false)), "character info hint should mark itself shown")
	_expect(not bool(hint.update(1.0, owner, null, getter)), "character info hint should not restart in the same battle")


func _verify_gamepad_message() -> void:
	var holder := ModuleHolder.new()
	var skill := FakeHintModule.new()
	skill.completed = true
	holder.modules = {"skill_orb_tooltip_tutorial_hint": skill}
	var getter := Callable(holder, "get_module")
	var owner := FakeOwner.new()
	owner.set_meta("junior_mika_grip_style", "gamepad")
	var hint: Object = CharacterInfoTutorialHint.new()
	hint.update(0.1, owner, null, getter)
	hint.update(30.0, owner, null, getter)
	_expect(bool(hint.update(0.0, owner, null, getter)), "gamepad character info hint should start once ready")
	_expect(str(hint.get_snapshot().get("message", "")) == "일시정지 메뉴에서 캐릭터 정보 확인", "gamepad grip should show the pause-menu character info hint")


# TAB만 키캡 그림으로 승격되고 나머지 문구는 텍스트로 남는지 봉인(공용 렌더러 경유).
func _verify_keycap_tokenization() -> void:
	var tokens: Array = TutorialHintKeycapRenderer.split_render_tokens("TAB - 캐릭터 정보 확인")
	var keys: Array = []
	var texts: Array = []
	for token_value in tokens:
		var token: Dictionary = token_value
		if str(token.get("type", "text")) == "key":
			keys.append(str(token.get("value", "")))
		else:
			texts.append(str(token.get("value", "")))
	_expect(keys == ["TAB"], "character info hint should keycap only the TAB key")
	_expect(texts == ["- 캐릭터 정보 확인"], "character info hint should keep the label as a text run")


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
