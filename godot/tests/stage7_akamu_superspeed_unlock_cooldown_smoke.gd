extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")

const COOLDOWN_SEC := 50.0
const ULTIMATE_ID := "stage7_superspeed"
const SUPERSPEED_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_superspeed_state.gd"
const HUD_BUILDER_PATH := "res://scripts/stages/stage7/stage7_akamu_hud_state_builder.gd"
const FACADE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_state.gd"
const LOCALIZED_COPY_KEYS := [
	"극정호신",
	"초각성 해금 · 게이지 250",
	"해금 및 종료 후 50초",
	"초각성 완료 시 해금되어 첫 발동까지 50초를 기다립니다. 발동하면 0.35초 동안 전장을 멈춘 뒤 10초간 공의 예상 궤도로 연속 활주하며, 지속 중 받아칠 때의 기력 수급은 20으로 감소합니다.",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_lock_and_unlock_cooldown()
	_verify_reuse_cooldown()
	_verify_unlock_card_rail_avoidance()
	_verify_seven_locale_copy()
	_verify_modular_single_source_contract()
	if _failures.is_empty():
		print("stage7_akamu_superspeed_unlock_cooldown_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lock_and_unlock_cooldown() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(500.0)
	_expect(
		not state.debug_start_superspeed(_base_context()),
		"a gauge-ready ultimate must stay locked before Awakening"
	)
	_expect(
		_find_skill(state.get_hud_context(), ULTIMATE_ID).is_empty(),
		"the locked ultimate must not appear on the boss skill-card rail"
	)

	state.debug_set_gauge(250.0)
	state.debug_force_complete_awakening()
	# Isolate the ultimate timer from the independent shuriken scheduler, which
	# can legitimately spend gauge during a 50-second synthetic wait.
	state.debug_set_shuriken_cooldown_remaining(999.0, 999.0)
	var snapshot: Dictionary = state.debug_get_superspeed_snapshot()
	_expect(not bool(snapshot.get("active", false)), "Awakening completion must not immediately fire a gauge-ready ultimate")
	_expect_close(state.debug_get_gauge(), 250.0, "the unlock cooldown must preserve the ready gauge")
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), COOLDOWN_SEC, "Awakening should arm the first 50-second cooldown")
	_expect_close(float(snapshot.get("cooldown_total_sec", 0.0)), COOLDOWN_SEC, "the debug surface should expose the shared cooldown source")
	var card := _find_skill(state.get_hud_context(), ULTIMATE_ID)
	_expect(not card.is_empty(), "Awakening should insert the ultimate card into the existing rail")
	_expect_close(float(card.get("cooldown_remaining", 0.0)), COOLDOWN_SEC, "the inserted card should start at zero cooldown progress")
	_expect_close(float(card.get("cooldown_total", 0.0)), COOLDOWN_SEC, "the inserted card should expose the 50-second total")

	var paused_context := _base_context()
	paused_context["active_item_boss_skill_cooldown_paused"] = true
	_advance_state(state, 1.0, paused_context)
	_expect_close(
		float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0)),
		COOLDOWN_SEC,
		"the established boss-skill pause gate should freeze the unlock cooldown"
	)

	var live_context := _base_context()
	_advance_state(state, COOLDOWN_SEC - 0.001, live_context)
	snapshot = state.debug_get_superspeed_snapshot()
	_expect(float(snapshot.get("cooldown_remaining_sec", 0.0)) > 0.0, "the first activation must remain closed immediately before 50 active seconds")
	_expect(not bool(snapshot.get("active", false)), "the ultimate must remain inactive before the unlock cooldown expires")
	_expect_close(state.debug_get_gauge(), 250.0, "the closed unlock gate must not spend gauge")
	state.update(0.0011, live_context)
	snapshot = state.debug_get_superspeed_snapshot()
	_expect(bool(snapshot.get("active", false)), "the gauge-ready ultimate should auto-start when the unlock cooldown expires")
	_expect_close(state.debug_get_gauge(), 0.0, "the first accepted activation should spend exactly 250 gauge")


func _verify_reuse_cooldown() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_awakened(true)
	state.debug_set_gauge(250.0)
	_expect(state.debug_start_superspeed(_base_context()), "reuse fixture should start the unlocked ultimate")
	_advance_state(state, 9.999, _base_context())
	_expect(bool(state.debug_get_superspeed_snapshot().get("active", false)), "the ultimate should remain active immediately before its ten-second duration ends")
	state.update(0.0011, _base_context())
	var snapshot: Dictionary = state.debug_get_superspeed_snapshot()
	_expect(not bool(snapshot.get("active", true)), "the ultimate should end after its ten-second duration")
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), COOLDOWN_SEC, "natural expiry should reuse the same 50-second cooldown")


func _verify_unlock_card_rail_avoidance() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_force_complete_awakening()
	var context: Dictionary = state.get_hud_context().duplicate(true)
	context.merge({
		"current_stage": 7,
		"view_size": Vector2(2048.0, 1152.0),
		"game_offset": Vector2(512.0, 64.0),
		"game_size": Vector2(1024.0, 1024.0),
	}, true)
	var renderer: Object = Stage7AkamuBossSkillHudRenderer.new()
	var default_layout: Dictionary = renderer.build_card_layout(context)
	var default_entries: Array = default_layout.get("entries", [])
	_expect(default_entries.size() == 4, "the post-unlock production rail should contain four cards")
	var default_bottom := _stack_bottom(default_layout)
	var panel_rect := Rect2(
		Vector2(_stack_left(default_layout) + 6.0, default_bottom - 12.0),
		Vector2(60.0, 140.0)
	)
	_expect(default_bottom > panel_rect.position.y, "the fixture should place the Commando panel across the default rail")
	context["commando_firearm_panel_rect"] = panel_rect
	var shifted_layout: Dictionary = renderer.build_card_layout(context)
	var scale_factor: float = float(shifted_layout.get("scale_factor", 1.0))
	var required_gap: float = BossSkillCardHudSpec.get_commando_firearm_panel_gap(scale_factor)
	_expect(
		_stack_bottom(shifted_layout) <= panel_rect.position.y - required_gap + 0.01,
		"the unlocked ultimate card must retain the shared Commando-safe rail offset"
	)
	_expect(_stack_top(shifted_layout) < _stack_top(default_layout), "the overlapping four-card rail should move upward")


func _verify_seven_locale_copy() -> void:
	var locale_tables := {
		"ko": {},
		"en": LanguageSettingsData.EXACT_TEXT_EN,
		"zh": LanguageSettingsData.EXACT_TEXT_ZH,
		"ja": LanguageSettingsData.EXACT_TEXT_JA,
		"es": LanguageSettingsData.EXACT_TEXT_ES,
		"pt-BR": LanguageSettingsData.EXACT_TEXT_PT_BR_OVERRIDES,
		"ru": LanguageSettingsData.EXACT_TEXT_RU_OVERRIDES,
	}
	_expect(locale_tables.size() == 7, "the unlock copy seal should cover all seven supported locales")
	for locale_value in locale_tables:
		var locale := str(locale_value)
		var table: Dictionary = locale_tables[locale]
		for source_value in LOCALIZED_COPY_KEYS:
			var source := str(source_value)
			var translated := source if locale == "ko" else str(table.get(source, ""))
			_expect(not translated.is_empty(), "%s should register the ultimate unlock copy: %s" % [locale, source])
			if locale != "ko":
				_expect(translated != source, "%s should not leak the Korean unlock copy" % locale)
			_expect(translated.find("—") < 0, "%s ultimate copy must not use an em dash" % locale)


func _verify_modular_single_source_contract() -> void:
	var superspeed_source := FileAccess.get_file_as_string(SUPERSPEED_STATE_PATH)
	var facade_source := FileAccess.get_file_as_string(FACADE_STATE_PATH)
	var hud_builder_source := FileAccess.get_file_as_string(HUD_BUILDER_PATH)
	_expect(
		superspeed_source.count("const COOLDOWN_SEC := 50.0") == 1,
		"the focused Superspeed owner should define the 50-second cooldown once"
	)
	_expect(superspeed_source.find("COOLDOWN_SEC := 25.0") < 0, "the removed 25-second cooldown must not survive")
	var completion_body := _function_body(facade_source, "func _complete_awakening(")
	var end_body := _function_body(superspeed_source, "func _end() -> void:")
	_expect(
		completion_body.find("_superspeed_state.set_cooldown_remaining(Stage7AkamuSuperspeedState.COOLDOWN_SEC)") >= 0,
		"Awakening completion should arm the focused owner's shared cooldown"
	)
	_expect(
		end_body.find("cooldown_remaining_sec = COOLDOWN_SEC") >= 0,
		"ultimate expiry should reuse the same focused-owner cooldown"
	)
	_expect(completion_body.find("_try_start_superspeed") < 0, "Awakening completion must not retain the legacy immediate-start chain")
	_expect(
		hud_builder_source.find("if awakened:") >= 0
			and hud_builder_source.find("skills.append(superspeed_state.build_hud_skill(") >= 0,
		"the focused HUD builder should own post-Awakening card insertion"
	)


func _advance_state(state: Object, duration_sec: float, context: Dictionary) -> void:
	var remaining := maxf(0.0, duration_sec)
	while remaining > 0.000001:
		var step := minf(0.05, remaining)
		state.update(step, context)
		remaining -= step


func _base_context() -> Dictionary:
	return {
		"player_score": 0,
		"waiting_for_serve": false,
		"ball_active": true,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 650.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"play_height": 750.0,
	}


func _find_skill(hud_context: Dictionary, skill_id: String) -> Dictionary:
	var values: Variant = hud_context.get("stage7_boss_skill_hud_skills", [])
	if not (values is Array):
		return {}
	for value in values:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return value as Dictionary
	return {}


func _stack_top(layout: Dictionary) -> float:
	var rects: Array = layout.get("rects", [])
	return float((rects[0] as Rect2).position.y) if not rects.is_empty() else 0.0


func _stack_bottom(layout: Dictionary) -> float:
	var rects: Array = layout.get("rects", [])
	return float((rects[-1] as Rect2).end.y) if not rects.is_empty() else 0.0


func _stack_left(layout: Dictionary) -> float:
	var rects: Array = layout.get("rects", [])
	return float((rects[0] as Rect2).position.x) if not rects.is_empty() else 0.0


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
