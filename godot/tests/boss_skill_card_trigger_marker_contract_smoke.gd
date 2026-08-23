extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

const TOOLTIP_KEY := "용소의 물을 끌어올려 전장을 가로지르는 격류를 발사합니다. 보스가 타격당하면 충전이 중단됩니다."
const MARKER_CALL := "BossSkillCardHudSpec.draw_trigger_marker(canvas, skill, rect, scale_factor)"
const RENDERER_PATHS := [
	"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage1/stage1_gaksital_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_marker_class_gate()
	_verify_open_brass_ink_geometry()
	_verify_all_visible_boss_card_renderers()
	_verify_cheongringwi_tooltip_localization()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("[BossSkillCardTriggerMarker] RENDERERS=9 HIT_MARK_ONLY=true OPEN_STROKES=true CHROME=brass,ink")
	print("[BossSkillCardTriggerMarker] PIXEL_REGRESSION_BASELINES=dalji,cheongringwi OUTSIDE_MARKER_UNCHANGED=true LOCALES=7")
	print("boss_skill_card_trigger_marker_contract_smoke: ok")
	quit(0)


func _verify_marker_class_gate() -> void:
	var hit_skill := {"trigger_type": BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT}
	var instant_skill := {"trigger_type": BossSkillTriggerClass.TRIGGER_INSTANT}
	_expect(BossSkillCardHudSpec.should_draw_trigger_marker(hit_skill), "boss-hit cards must opt into the corner marker")
	_expect(not BossSkillCardHudSpec.should_draw_trigger_marker(instant_skill), "instant cards must remain unmarked by default")
	_expect(not BossSkillCardHudSpec.should_draw_trigger_marker({}), "undeclared cards must never acquire a marker by fallback")
	var card_rect := Rect2(Vector2(20.0, 30.0), Vector2(76.0, 24.0))
	var bounds := BossSkillCardHudSpec.get_trigger_marker_bounds(card_rect, 2.0)
	_expect(card_rect.encloses(bounds), "trigger marker must remain inside the card corner")
	_expect(bounds.get_center().x > card_rect.get_center().x and bounds.get_center().y <= card_rect.get_center().y, "trigger marker must stay compact in the upper-right corner")


func _verify_open_brass_ink_geometry() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
	var body := SourceContractFunctionBody.extract(source, "static func draw_trigger_marker(")
	_expect(body.count("canvas.draw_line(") == 2, "trigger marker must render layered open line strokes")
	_expect(not body.contains("draw_rect("), "trigger marker must not add a closed perimeter rectangle")
	_expect(body.contains("HIT_MARK_BRASS") and body.contains("HIT_MARK_INK"), "trigger marker must use the shared brass-and-ink chrome palette")


func _verify_all_visible_boss_card_renderers() -> void:
	for path in RENDERER_PATHS:
		var source := FileAccess.get_file_as_string(path)
		var body := SourceContractFunctionBody.extract(source, "func _draw_card(")
		_expect(not body.is_empty(), "%s must keep its production _draw_card owner" % path)
		_expect(body.count(MARKER_CALL) == 1, "%s must draw the shared trigger marker exactly once" % path)
	var stage8_source := FileAccess.get_file_as_string("res://scripts/stages/stage8/stage8_minotaur_boss_skill_hud_renderer.gd")
	_expect(stage8_source.contains("build_card_layout(_context: Dictionary)") and stage8_source.contains("return {}"), "Stage 8 placeholder renderer must remain a no-card stub until its card is implemented")


func _verify_cheongringwi_tooltip_localization() -> void:
	var stage2_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")
	var tooltip_body := SourceContractFunctionBody.extract(stage2_source, "func _get_tooltip_info(")
	_expect(tooltip_body.contains(TOOLTIP_KEY), "Cheongringwi Dragon Pool Torrent tooltip must disclose hit interruption")
	var locale_maps := [
		LanguageSettingsData.EXACT_TEXT_EN,
		LanguageSettingsData.EXACT_TEXT_ZH,
		LanguageSettingsData.EXACT_TEXT_JA,
		LanguageSettingsData.EXACT_TEXT_ES,
		LanguageSettingsData.EXACT_TEXT_PT_BR_OVERRIDES,
		LanguageSettingsData.EXACT_TEXT_RU_OVERRIDES,
	]
	for locale_map_value in locale_maps:
		var locale_map: Dictionary = locale_map_value
		_expect(locale_map.has(TOOLTIP_KEY) and not str(locale_map.get(TOOLTIP_KEY, "")).is_empty(), "Dragon Pool Torrent tooltip must stay synchronized in all six non-Korean locales")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
