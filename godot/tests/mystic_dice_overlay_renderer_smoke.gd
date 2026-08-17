extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MysticDiceLocalization := preload("res://scripts/characters/mystic_dice_localization.gd")
const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceModalLayout := preload("res://scripts/characters/mystic_dice_modal_layout.gd")
const MysticDiceOverlayRenderer := preload("res://scripts/hud/mystic_dice_overlay_renderer.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const MysticDiceActiveItemIcon := "res://assets/sprites/items/mystic_dice_icon_hq_v1.png"

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
		LanguageSettings.LANGUAGE_KOREAN: ["이번 던짐", "누적"],
		LanguageSettings.LANGUAGE_ENGLISH: ["This Throw", "Total"],
		LanguageSettings.LANGUAGE_CHINESE: ["本次", "累计"],
		LanguageSettings.LANGUAGE_JAPANESE: ["今回", "累計"],
		LanguageSettings.LANGUAGE_SPANISH: ["Lanzamiento", "Total"],
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: ["Lançamento", "Total"],
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
	# 신비의 주사위는 무공 카드가 아니라 액티브 아이템이다. 호환 퍽 ID를 그리는
	# 자리(능력치 원인표기·TAB 누적 엔트리)도 아이템 정본 아이콘을 써야 한다.
	# 소스 문자열이 아니라 실제 맵을 조회해 경로 리터럴이 옮겨져도 계약이 남게 한다.
	var registered_icon_path: String = str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("mystic_dice", ""))
	_expect(
		registered_icon_path == MysticDiceActiveItemIcon,
		"compat perk id should register the canonical active-item PNG, got '%s'" % registered_icon_path
	)
	var catalog_icon_path := str(ActiveItemCatalog.new().build_item_by_name("mystic_dice").get("icon_path", ""))
	_expect(
		catalog_icon_path == MysticDiceActiveItemIcon,
		"active-item catalog should register the same canonical yut PNG, got '%s'" % catalog_icon_path
	)
	_expect(FileAccess.file_exists(registered_icon_path), "the registered mystic dice icon must land on disk")
	var host_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(host_source.contains("MysticDiceOverlayRenderer") and host_source.contains("is_mystic_dice_modal_active"), "runtime overlay should route the dice modal through its focused renderer")
	_expect(host_source.contains("skill_id == \"mystic_dice\""), "runtime overlay should retain a procedural yut-bundle fallback")
	_expect(not host_source.contains("five-pip") and not host_source.contains("pip_offset"), "procedural compatibility fallback must not return to dice pips")
	var source := FileAccess.get_file_as_string("res://scripts/hud/mystic_dice_overlay_renderer.gd")
	_expect(source.contains('MysticDiceLocalization.text("roll_header")'), "result renderer should label the current-roll value column")
	_expect(source.contains('MysticDiceLocalization.text("total_header")'), "result renderer should label the accumulated-total value column")
	_expect(source.contains("_draw_text_centered_fitted"), "localized result headers should shrink to fit narrow modal columns")
	_expect(not source.contains('"Δ"') and not source.contains('"Σ"'), "opaque math-symbol column headers must not return")
	_expect(source.contains("YUT_STICK_COUNT := 4"), "modal centerpiece should render the complete four-stick yut set")
	_expect(not source.contains("FACE_GLYPHS") and not source.contains("LINGPET_GLYPH_FONT"), "six-face Lingpet glyph dice art must not return")
	var expected_back_counts := [1, 2, 3, 4, 0, 1]
	for face: int in range(1, 7):
		_expect(
			MysticDiceOverlayRenderer.get_yut_back_count(face) == int(expected_back_counts[face - 1]),
			"compat face %d should project to the intended four-stick back/front pattern" % face
		)
	_expect(
		MysticDiceOverlayRenderer.PANEL_BORDER_COLOR.r > MysticDiceOverlayRenderer.PANEL_BORDER_COLOR.b
		and MysticDiceOverlayRenderer.PANEL_BORDER_COLOR.g > MysticDiceOverlayRenderer.PANEL_BORDER_COLOR.b,
		"modal panel border should stay in the brass-gold palette"
	)
	_expect(
		MysticDiceOverlayRenderer.YUT_BODY_LIT.r > MysticDiceOverlayRenderer.YUT_BODY_LIT.g
		and MysticDiceOverlayRenderer.YUT_BODY_LIT.g > MysticDiceOverlayRenderer.YUT_BODY_LIT.b,
		"yut body highlight should stay warm birch cream"
	)
	_expect(
		MysticDiceOverlayRenderer.BENEFIT_COLOR.b > MysticDiceOverlayRenderer.BENEFIT_COLOR.r
		and MysticDiceOverlayRenderer.HARM_COLOR.r > MysticDiceOverlayRenderer.HARM_COLOR.b,
		"benefit/harm colors should stay obangsaek blue/red"
	)
	_expect(
		source.contains("_draw_yut_knot")
		and MysticDiceOverlayRenderer.YUT_KNOT_RED.r > MysticDiceOverlayRenderer.YUT_KNOT_RED.g * 4.0,
		"modal yut bundle should retain the icon-matching red silk binding"
	)
	_expect(not source.contains("draw_set_transform"), "yut geometry should tumble manually without leaking a canvas transform")
	_expect(not source.contains("Time.get_ticks") and not source.contains("randf") and not source.contains("randi"), "modal draw animation should consume snapshot time without wall-clock or RNG")
	_expect(not source.contains("Image.get_image") and not source.contains("create_from_image"), "draw path must not scan or construct textures")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
