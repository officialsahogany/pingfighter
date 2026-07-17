extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MysticDiceLocalization := preload("res://scripts/characters/mystic_dice_localization.gd")
const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceModalLayout := preload("res://scripts/characters/mystic_dice_modal_layout.gd")
const MysticDiceOverlayRenderer := preload("res://scripts/hud/mystic_dice_overlay_renderer.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_result_projection_and_lib_polarity()
	_verify_localized_column_headers()
	_verify_bounded_long_hover_animation()
	_verify_minimum_view_layout()
	_verify_renderer_and_icon_contract()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("mystic_dice_overlay_renderer_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_result_projection_and_lib_polarity() -> void:
	var raw := {
		"player_speed": 3,
		"paddle_size": -3,
		"skill_gauge": 0,
		"dash_distance": 2,
		"dash_recovery": -3,
		"dash_cooldown": 3,
		"item_cooldown": -2,
	}
	var benefits := {}
	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		benefits[stat_key] = -int(raw[stat_key]) if stat_key in MysticDiceRoller.LOWER_IS_BETTER_STAT_KEYS else int(raw[stat_key])
	var modal_snapshot := {"current_roll": {"raw": raw, "benefits": benefits}}
	var dice_snapshot := {"permanent_raw": {"player_speed": 8, "dash_recovery": -8}}
	var rows: Array = MysticDiceOverlayRenderer.build_result_rows(modal_snapshot, dice_snapshot)
	_expect(rows.size() == 7, "D2 result projection should always expose seven stat rows")
	var by_key := {}
	for row_value: Variant in rows:
		var row: Dictionary = row_value as Dictionary
		by_key[str(row.get("stat_key", ""))] = row
	_expect(int((by_key.get("player_speed", {}) as Dictionary).get("accumulated_raw", 0)) == 9, "projected cumulative raw should clamp at +9")
	_expect(int((by_key.get("dash_recovery", {}) as Dictionary).get("accumulated_raw", 0)) == -9, "projected LIB cumulative raw should clamp at -9")
	_expect(int((by_key.get("dash_recovery", {}) as Dictionary).get("benefit", 0)) == 3, "negative dash recovery raw should remain a green benefit")
	_expect(int((by_key.get("dash_cooldown", {}) as Dictionary).get("benefit", 0)) == -3, "positive dash cooldown raw should remain a red harm")
	_expect(int((by_key.get("item_cooldown", {}) as Dictionary).get("accumulated_benefit", 0)) == 2, "LIB accumulated color sign should invert raw polarity")


func _verify_bounded_long_hover_animation() -> void:
	var flow := MysticDiceModalFlow.new()
	var units: Array = []
	for _stat_key: String in MysticDiceRoller.STAT_KEYS:
		units.append(1.0)
	var roll: Dictionary = MysticDiceRoller.new().roll(units)
	_expect(flow.start({"id": "mystic_dice"}, [{"id": "mystic_dice"}], roll), "valid roll should start modal for renderer timing")
	flow.update(MysticDiceModalFlow.ROLL_DURATION)
	flow.update(10.25)
	var snapshot: Dictionary = flow.get_snapshot()
	_expect(float(snapshot.get("phase_elapsed", -1.0)) >= 10.0, "D2 should advance its hover clock while waiting")
	flow.update(MysticDiceModalFlow.HOVER_TIME_WRAP * 4.0 + 0.5)
	snapshot = flow.get_snapshot()
	_expect(float(snapshot.get("phase_elapsed", -1.0)) < MysticDiceModalFlow.HOVER_TIME_WRAP, "D2 hover clock should stay bounded")
	var visual: Dictionary = MysticDiceOverlayRenderer.get_visual_state(snapshot, Vector2(760.0, 750.0))
	var center: Vector2 = visual.get("center", Vector2.ZERO)
	_expect(center.is_finite() and absf(center.y - 150.0) <= 8.0, "10s+ D2 hover should remain finite and bounded")
	_expect(absf(float(visual.get("rotation", 1.0))) <= 0.05, "D2 hover should sway instead of accumulating rotation")
	_expect(int(visual.get("face", 0)) in range(1, 7), "locked die face should remain valid")


func _verify_localized_column_headers() -> void:
	var original_language: String = LanguageSettings.get_language()
	var expected_headers := {
		LanguageSettings.LANGUAGE_KOREAN: ["이번 굴림", "누적"],
		LanguageSettings.LANGUAGE_ENGLISH: ["This Roll", "Total"],
		LanguageSettings.LANGUAGE_CHINESE: ["本次", "累计"],
		LanguageSettings.LANGUAGE_JAPANESE: ["今回", "累計"],
		LanguageSettings.LANGUAGE_SPANISH: ["Tirada", "Total"],
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: ["Rolagem", "Total"],
		LanguageSettings.LANGUAGE_RUSSIAN: ["Бросок", "Итог"],
	}
	for locale: String in expected_headers:
		LanguageSettings.set_test_locale_override(locale)
		var expected: Array = expected_headers.get(locale, []) as Array
		_expect(
			MysticDiceLocalization.text("roll_header") == str(expected[0]),
			"%s should explain the current-roll value column" % locale
		)
		_expect(
			MysticDiceLocalization.text("total_header") == str(expected[1]),
			"%s should explain the accumulated-total value column" % locale
		)
	LanguageSettings.set_test_locale_override(original_language)


func _verify_minimum_view_layout() -> void:
	var helper := MysticDiceModalLayout.new()
	var snapshot := {
		"phase": MysticDiceModalFlow.PHASE_RESULT,
		"rerolls_remaining": 2,
	}
	for view_size: Vector2 in [Vector2(760.0, 750.0), Vector2(420.0, 560.0), Vector2(300.0, 420.0)]:
		var bounds := Rect2(Vector2.ZERO, view_size)
		var rects: Dictionary = helper.get_action_rects(snapshot, view_size)
		_expect(rects.size() == 2, "D2 with rerolls should keep both actions")
		for rect_value: Variant in rects.values():
			var rect: Rect2 = rect_value as Rect2
			_expect(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= bounds.end.x and rect.end.y <= bounds.end.y, "D2 actions should stay inside minimum view bounds")


func _verify_renderer_and_icon_contract() -> void:
	var renderer := MysticDiceOverlayRenderer.new()
	renderer.prewarm_assets()
	renderer.reset()
	renderer.draw(null, {}, {}, Vector2.ZERO)
	_expect(FileAccess.file_exists("res://assets/sprites/perks/mystic_dice_perk_icon.png"), "imagegen icon must land before registration")
	var icon_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_icon_renderer.gd")
	_expect(icon_source.contains("mystic_dice_perk_icon.png"), "perk icon renderer should register the landed mystic dice PNG")
	var host_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(host_source.contains("MysticDiceOverlayRenderer") and host_source.contains("is_mystic_dice_modal_active"), "runtime overlay should route the dice modal through its focused renderer")
	_expect(host_source.contains("skill_id == \"mystic_dice\""), "runtime overlay should retain a procedural five-pip fallback")
	var source := FileAccess.get_file_as_string("res://scripts/hud/mystic_dice_overlay_renderer.gd")
	_expect(source.contains('MysticDiceLocalization.text("roll_header")'), "result renderer should label the current-roll value column")
	_expect(source.contains('MysticDiceLocalization.text("total_header")'), "result renderer should label the accumulated-total value column")
	_expect(source.contains("_draw_text_centered_fitted"), "localized result headers should shrink to fit narrow modal columns")
	_expect(not source.contains('"Δ"') and not source.contains('"Σ"'), "opaque math-symbol column headers must not return")
	_expect(not source.contains("draw_set_transform"), "dice geometry should rotate manually without leaking a canvas transform")
	_expect(not source.contains("Time.get_ticks") and not source.contains("randf") and not source.contains("randi"), "modal draw animation should consume snapshot time without wall-clock or RNG")
	_expect(not source.contains("Image.get_image") and not source.contains("create_from_image"), "draw path must not scan or construct textures")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
