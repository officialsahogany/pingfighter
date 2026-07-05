extends SceneTree

const JuniorMikaTutorialHint := preload("res://scripts/hud/junior_mika_tutorial_hint.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "smasher"


class FakeDashState:
	extends RefCounted

	var active := false
	var recovering := false

	func get_snapshot() -> Dictionary:
		return {
			"active": active,
			"recovering": recovering,
		}


class FakeRegistry:
	extends RefCounted

	var dash_state := FakeDashState.new()

	func get_instance(key: String) -> Object:
		if key == "smasher_dash_state":
			return dash_state
		return null


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_runtime_wiring()
	_verify_waits_for_grip_selection()
	_verify_junior_mika_hint_timing()
	_verify_grip_style_specific_messages()
	_verify_realtime_language_switching()
	_verify_non_junior_or_non_mika_does_not_start()
	_verify_keycap_tokenization()

	_restore_language_settings_snapshot()
	if _failures.is_empty():
		print("junior_mika_tutorial_hint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var hint_module: Object = registry.get_instance("junior_mika_tutorial_hint")
	_expect(hint_module != null and hint_module.has_method("update"), "junior Mika hint should be registered in the gameplay module catalog")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("junior_mika_tutorial_hint") >= 0, "battle frame controller should update and draw the junior Mika hint")


func _verify_junior_mika_hint_timing() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "junior league"
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var hint: Object = JuniorMikaTutorialHint.new()
	_expect(hint.get_draw_center(Vector2(1920.0, 1080.0)) == Vector2(960.0, 540.0), "junior Mika hint should draw near the stadium center line")
	_expect(hint.update(0.0, owner), "junior Mika hint should start on the first eligible frame")
	_expect(bool(hint.get_snapshot().get("active", false)), "junior Mika hint should become active")
	_expect(str(hint.get_snapshot().get("message", "")) == "A / D - 이동", "junior Mika hint should use the selected grip movement text")
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 0.0)), 0.0), "junior Mika hint should begin fully faded out")

	_expect(hint.update(0.325, owner), "junior Mika hint should request redraw during fade in")
	var fade_in_alpha: float = float(hint.get_snapshot().get("alpha", 0.0))
	_expect(fade_in_alpha > 0.0 and fade_in_alpha < 1.0, "junior Mika hint should fade in over time")

	hint.update(0.50, owner)
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 0.0)), 1.0), "junior Mika hint should hold at full alpha after fade in")

	hint.update(2.90, owner)
	var fade_out_alpha: float = float(hint.get_snapshot().get("alpha", 0.0))
	_expect(fade_out_alpha > 0.0 and fade_out_alpha < 1.0, "junior Mika hint should fade out before ending")

	hint.update(1.0, owner)
	_expect(bool(hint.get_snapshot().get("active", false)), "junior Mika hint sequence should stay active during the gap before dash guidance")
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 1.0)), 0.0), "junior Mika hint should stay hidden between movement and dash guidance")

	hint.update(1.775, owner)
	_expect(str(hint.get_snapshot().get("message", "")).find("이동 중") >= 0, "junior Mika hint should switch to dash guidance after the movement hint")
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 1.0)), 0.0), "junior Mika dash hint should begin fully faded out")

	hint.update(0.325, owner)
	var dash_fade_in_alpha: float = float(hint.get_snapshot().get("alpha", 0.0))
	_expect(dash_fade_in_alpha > 0.0 and dash_fade_in_alpha < 1.0, "junior Mika dash hint should fade in over time")
	_expect(str(hint.get_snapshot().get("message", "")) == "A / D 이동 중 S - 대쉬", "junior Mika dash hint should describe the selected grip dash input")

	hint.update(0.50, owner)
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 0.0)), 1.0), "junior Mika dash hint should hold at full alpha after fade in")

	hint.update(5.0, owner)
	_expect(bool(hint.get_snapshot().get("active", false)), "junior Mika dash hint should stay visible until the player dashes")
	_expect(is_equal_approx(float(hint.get_snapshot().get("alpha", 0.0)), 1.0), "junior Mika dash hint should hold at full alpha while waiting for dash")
	_expect(not bool(hint.get_snapshot().get("dash_tutorial_completed", false)), "junior Mika dash tutorial should remain incomplete before dash")

	var registry := FakeRegistry.new()
	registry.dash_state.active = true
	_expect(hint.update(0.0, owner, registry), "junior Mika hint should dismiss when the player activates dash")
	_expect(not bool(hint.get_snapshot().get("active", true)), "junior Mika hint should stop after dash activation")
	_expect(bool(hint.get_snapshot().get("dash_tutorial_completed", false)), "junior Mika dash tutorial should complete after dash activation")
	registry.dash_state.active = false
	_expect(not hint.update(0.1, owner, registry), "junior Mika hint should not restart in the same battle")


func _verify_waits_for_grip_selection() -> void:
	var owner := FakeOwner.new()
	var hint: Object = JuniorMikaTutorialHint.new()
	_expect(not hint.update(0.0, owner), "Junior Mika tutorial should wait until a grip style has been selected")
	_expect(not bool(hint.get_snapshot().get("active", true)), "Junior Mika tutorial should remain inactive before grip selection")
	_expect(not bool(hint.get_snapshot().get("has_started", true)), "Junior Mika tutorial should not consume its one-shot start before grip selection")

	owner.set_meta("tutorial_grip_style", "space_arrows")
	_expect(hint.update(0.0, owner), "Junior Mika tutorial should start after grip selection is stored")
	_expect(str(hint.get_snapshot().get("message", "")) == "방향키 ← / → - 이동", "Junior Mika tutorial should start with the selected grip movement text")


func _verify_grip_style_specific_messages() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var wasd_owner := FakeOwner.new()
	wasd_owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var wasd_hint: Object = JuniorMikaTutorialHint.new()
	_expect(wasd_hint.update(0.0, wasd_owner), "WASD grip should start the junior tutorial hint")
	_expect(str(wasd_hint.get_snapshot().get("message", "")) == "A / D - 이동", "WASD grip should show A/D movement only")
	wasd_hint.update(6.5, wasd_owner)
	_expect(str(wasd_hint.get_snapshot().get("message", "")) == "A / D 이동 중 S - 대쉬", "WASD grip should show S as the dash input")

	var arrows_owner := FakeOwner.new()
	arrows_owner.set_meta("tutorial_grip_style", "space_arrows")
	var arrows_hint: Object = JuniorMikaTutorialHint.new()
	_expect(arrows_hint.update(0.0, arrows_owner), "arrow-key grip should start the junior tutorial hint")
	_expect(str(arrows_hint.get_snapshot().get("message", "")) == "방향키 ← / → - 이동", "arrow-key grip should show arrow movement only")
	arrows_hint.update(6.5, arrows_owner)
	_expect(str(arrows_hint.get_snapshot().get("message", "")) == "← / → 이동 중 ↓ - 대쉬", "arrow-key grip should show down arrow as the dash input")

	var gamepad_owner := FakeOwner.new()
	gamepad_owner.set_meta("junior_mika_grip_style", "gamepad")
	var gamepad_hint: Object = JuniorMikaTutorialHint.new()
	_expect(gamepad_hint.update(0.0, gamepad_owner), "gamepad grip should start the junior tutorial hint")
	_expect(str(gamepad_hint.get_snapshot().get("message", "")) == "왼쪽 스틱 / D-Pad ← / → - 이동", "gamepad grip should show left stick or D-Pad movement")
	gamepad_hint.update(6.5, gamepad_owner)
	_expect(str(gamepad_hint.get_snapshot().get("message", "")) == "왼쪽 스틱 이동 중 B - 대쉬", "gamepad grip should show B as the dash input")


func _verify_realtime_language_switching() -> void:
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "space_arrows")
	var hint: Object = JuniorMikaTutorialHint.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_expect(hint.update(0.0, owner), "localized junior Mika hint should start")
	_expect(str(hint.get_snapshot().get("message", "")) == "방향키 ← / → - 이동", "localized junior Mika hint should start in Korean")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(hint.update(0.0, owner), "active junior Mika hint should request redraw when the language changes")
	_expect(str(hint.get_snapshot().get("message", "")) == "Arrow Keys ← / → - Move", "active junior Mika movement hint should switch to English live")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	_expect(hint.update(0.0, owner), "active junior Mika hint should request redraw on a second language change")
	_expect(str(hint.get_snapshot().get("message", "")) == "方向键 ← / → - 移动", "active junior Mika movement hint should switch to Chinese live")
	hint.update(6.5, owner)
	_expect(str(hint.get_snapshot().get("message", "")) == "按住 ← / → 移动时按 ↓ - 冲刺", "active junior Mika dash hint should use the current language after the gap")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_non_junior_or_non_mika_does_not_start() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var owner := FakeOwner.new()
	var hint: Object = JuniorMikaTutorialHint.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	owner.ai_mode = "champion"
	_expect(not hint.update(0.0, owner), "Champion Mika should not start the junior tutorial hint")
	_expect(not bool(hint.get_snapshot().get("active", true)), "Champion Mika hint should remain inactive")

	# 이동/대쉬 안내는 시작 튜토리얼 캐릭터(스매셔/코만도/바이퍼) 공용이 됐다.
	# 옵티머스는 여전히 미대상.
	owner.ai_mode = "junior"
	owner.selected_character_type = "optimus"
	owner.set_meta("tutorial_grip_style", "space_arrows")
	hint = JuniorMikaTutorialHint.new()
	_expect(not hint.update(0.0, owner), "Junior non-starter character should not start the tutorial hint")
	_expect(not bool(hint.get_snapshot().get("active", true)), "Junior non-starter hint should remain inactive")

	# 바이퍼는 연습모드(쉐백 대쉬 선행조건) 때문에 이동/대쉬 안내를 공유한다.
	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	viper_owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var viper_hint: Object = JuniorMikaTutorialHint.new()
	_expect(viper_hint.update(0.0, viper_owner), "Junior Viper should start the move/dash tutorial hint")
	_expect(bool(viper_hint.get_snapshot().get("active", false)), "Junior Viper hint should become active")


# 키보드 입력 글자만 키캡 그림으로 승격되고, 주변 단어(특히 "D-Pad"/"Dash")는
# 텍스트로 남는지 봉인한다. draw()가 이 토크나이저로 레이아웃을 만든다.
func _verify_keycap_tokenization() -> void:
	var hint: Object = JuniorMikaTutorialHint.new()

	var wasd_dash: Array = hint._split_render_tokens("A / D 이동 중 S - 대쉬")
	_expect(_keycap_values(wasd_dash) == ["A", "D", "S"], "WASD dash hint should keycap A, D and S")
	_expect(_text_values(wasd_dash) == ["/", "이동 중", "- 대쉬"], "WASD dash hint should keep the connective phrases as text runs")

	var arrows_dash: Array = hint._split_render_tokens("← / → 이동 중 ↓ / S - 대쉬")
	_expect(_keycap_values(arrows_dash) == ["←", "→", "↓", "S"], "arrow dash hint should keycap the arrow glyphs and S")

	# 게임패드 이동 안내의 "D-Pad"는 D 키로 오인되면 안 된다(정확 일치만 키캡).
	var gamepad_move: Array = hint._split_render_tokens("왼쪽 스틱 / D-Pad ← / → - 이동")
	_expect(_keycap_values(gamepad_move) == ["←", "→"], "gamepad move hint should keycap only the arrows, never the D inside D-Pad")
	_expect("왼쪽 스틱 / D-Pad" in _text_values(gamepad_move), "gamepad move hint should keep 'D-Pad' inside a text run")

	var gamepad_dash: Array = hint._split_render_tokens("왼쪽 스틱 이동 중 B - 대쉬")
	_expect(_keycap_values(gamepad_dash) == ["B"], "gamepad dash hint should keycap the B button")

	# 영어권 단어 'Dash' / 'Move'의 대문자는 키로 승격되면 안 된다.
	var english_dash: Array = hint._split_render_tokens("Hold ← / → and press ↓ / S - Dash")
	_expect(_keycap_values(english_dash) == ["←", "→", "↓", "S"], "English dash hint should keycap keys but not the word Dash")


func _keycap_values(elements: Array) -> Array:
	var result: Array = []
	for element_value in elements:
		var element: Dictionary = element_value
		if str(element.get("type", "text")) == "key":
			result.append(str(element.get("value", "")))
	return result


func _text_values(elements: Array) -> Array:
	var result: Array = []
	for element_value in elements:
		var element: Dictionary = element_value
		if str(element.get("type", "text")) == "text":
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
