extends SceneTree

const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ServeWaitIndicatorRenderer := preload("res://scripts/hud/serve_wait_indicator_renderer.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")

const RENDERER_PATH := "res://scripts/hud/serve_wait_indicator_renderer.gd"
const PLAYFIELD_CONTEXT_PATH := "res://scripts/core/battle_draw_playfield_scene_context.gd"
const OVERLAY_DRAWER_PATH := "res://scripts/core/battle_playfield_overlay_drawer.gd"
const STAGE1_LABELS_KO := {
	"dalji": "달지 차례",
	"gaksital": "각시탈 차례",
	"podo": "포도대장 차례",
}
const NON_VARIANT_LABELS_KO := {
	4: "퐁크 차례",
	5: "홍련 차례",
	6: "테트리서 차례",
	7: "아카무 리고 차례",
	8: "미노타우로스 차례",
}

const LOCALE_CASES := [
	{
		"locale": LanguageSettings.LANGUAGE_KOREAN,
		"dalji": "달지 차례",
		"generic": "보스 차례",
		"player": "플레이어 서브",
		"preparing": "준비중..",
		"ready": "준비 완료",
	},
	{
		"locale": LanguageSettings.LANGUAGE_ENGLISH,
		"dalji": "Dalji Serve",
		"generic": "Boss Serve",
		"player": "Player Serve",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_CHINESE,
		"dalji": "达尔吉 Serve",
		"generic": "首领 Serve",
		"player": "玩家发球",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_JAPANESE,
		"dalji": "ダルジ Serve",
		"generic": "ボス Serve",
		"player": "プレイヤーのサーブ",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_SPANISH,
		"dalji": "Dalji Serve",
		"generic": "Jefe Serve",
		"player": "Saque del jugador",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		"dalji": "Dalji Serve",
		"generic": "Chefe Serve",
		"player": "Saque do jogador",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_RUSSIAN,
		"dalji": "Dalji Serve",
		"generic": "Босс Serve",
		"player": "Подача игрока",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
]

const REMOVED_PANEL_TOKENS := [
	"BOSS_PANEL_MAX_WIDTH",
	"BOSS_PANEL_HEIGHT",
	"BOSS_PANEL_TOP",
	"BOSS_PROGRESS_HEIGHT",
	"_draw_boss_serve_panel(",
	"fill_rect.grow(6.0)",
]

var _failures: Array[String] = []


class FakeDrawOwner:
	extends RefCounted

	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""


func _init() -> void:
	_verify_all_supported_locales()
	_verify_variant_boss_labels()
	_verify_production_context_wiring()
	_verify_production_renderer_contract()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("serve_wait_indicator_localization_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_all_supported_locales() -> void:
	var renderer := ServeWaitIndicatorRenderer.new()
	var covered_locales: Array[String] = []
	for locale_case in LOCALE_CASES:
		var locale := str(locale_case.get("locale", ""))
		covered_locales.append(locale)
		LanguageSettings.set_test_locale_override(locale)
		_expect(
			renderer._get_serve_label(false, {"current_stage": 1, "stage1_boss_variant": "dalji"}) == str(locale_case.get("dalji", "")),
			"%s stage-one boss turn label should match its locale contract" % locale
		)
		_expect(
			renderer._get_serve_label(false, {"current_stage": 99}) == str(locale_case.get("generic", "")),
			"%s unmapped-stage boss turn label should retain the generic fallback" % locale
		)
		_expect(
			renderer._get_serve_label(true, {"current_stage": 1}) == str(locale_case.get("player", "")),
			"%s player serve label should retain the Z7 localization structure" % locale
		)
		var preparing := LanguageSettings.translate("hud.serve_wait.preparing")
		var ready := LanguageSettings.translate("hud.serve_wait.ready")
		_expect(preparing == str(locale_case.get("preparing", "")), "%s preparing copy should match" % locale)
		_expect(ready == str(locale_case.get("ready", "")), "%s ready copy should match" % locale)
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			_expect(preparing.ends_with("..") and preparing.find("…") < 0, "Korean preparing copy should preserve the user's two periods")
		else:
			_expect(renderer._get_serve_label(false, {"current_stage": 1, "stage1_boss_variant": "dalji"}).ends_with(" Serve"), "%s boss format should retain the original English Serve suffix" % locale)
			_expect(preparing == "Preparing..." and ready == "Ready", "%s boss status should retain the original English copy" % locale)
		for variant_id_value in StageBossVariantCatalog.VARIANTS.keys():
			var variant_id := str(variant_id_value)
			var entry: Dictionary = StageBossVariantCatalog.VARIANTS.get(variant_id, {})
			var stage_id := int(entry.get("stage", 0))
			var context := _build_variant_context(stage_id, variant_id)
			var expected_name := LanguageSettings.translate_text(str(entry.get("display_name", "")))
			var expected_label := LanguageSettings.translate("hud.serve_wait.boss_turn_format") % expected_name
			_expect(
				renderer._get_serve_label(false, context) == expected_label,
				"%s %s boss turn label should consume the catalog display name" % [locale, variant_id]
			)
	covered_locales.sort()
	var supported_locales := LanguageSettings.SUPPORTED_LANGUAGES.duplicate()
	supported_locales.sort()
	_expect(covered_locales == supported_locales, "locale seal should cover every supported language exactly once")


func _verify_variant_boss_labels() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var renderer := ServeWaitIndicatorRenderer.new()
	for variant_id in STAGE1_LABELS_KO:
		_expect(
			renderer._get_serve_label(false, _build_variant_context(1, variant_id)) == str(STAGE1_LABELS_KO[variant_id]),
			"Stage 1 %s should publish its authoritative Korean turn label" % variant_id
		)
	var expected_stage2_labels := {
		"cheongringwi": "청린귀 차례",
		"molewang": "지굴왕 차례",
		"arachne": "거미각시 차례",
	}
	for variant_id in expected_stage2_labels:
		_expect(
			renderer._get_serve_label(false, _build_variant_context(2, variant_id)) == str(expected_stage2_labels[variant_id]),
			"Stage 2 %s should publish its catalog-backed Korean turn label" % variant_id
		)
	for stage_id in NON_VARIANT_LABELS_KO:
		_expect(
			renderer._get_serve_label(false, {"current_stage": stage_id}) == str(NON_VARIANT_LABELS_KO[stage_id]),
			"non-variant Stage %d should retain its established boss name" % stage_id
		)
	_expect(
		renderer._get_serve_label(false, {
			"current_stage": 1,
			"stage1_boss_variant": "gaksi",
			"stage_boss_variant": "alice",
		}) == "각시탈 차례",
		"Stage 1 must read its separate owner-authority key instead of stage_boss_variant"
	)


func _verify_production_context_wiring() -> void:
	var owner := FakeDrawOwner.new()
	owner.current_stage = 1
	owner.stage1_boss_variant = "gaksi"
	owner.stage_boss_variant = "alice"
	var context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, null)
	_expect(context.get("stage1_boss_variant", "") == "gaksi", "playfield draw context should project the Stage 1 owner variant")
	_expect(context.get("stage_boss_variant", "") == "alice", "playfield draw context should project the cross-stage owner variant")
	var context_source := FileAccess.get_file_as_string(PLAYFIELD_CONTEXT_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_DRAWER_PATH)
	_expect(context_source.contains('"stage1_boss_variant": str(_get_owner_value(owner, "stage1_boss_variant", "dalji"))'), "production playfield context should read Stage 1 owner authority")
	_expect(context_source.contains('"stage_boss_variant": str(_get_owner_value(owner, "stage_boss_variant", ""))'), "production playfield context should read cross-stage owner authority")
	_expect(overlay_source.contains("serve_wait_renderer.draw(canvas, width, height, draw_context, draw_deps)"), "serve wait should consume the shared production draw_context unchanged")


func _verify_production_renderer_contract() -> void:
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	var localization_source := FileAccess.get_file_as_string("res://scripts/core/language_settings_data.gd")
	var rejected_copy := "기를 모으는" + " 중"
	_expect(renderer_source.find(rejected_copy) < 0, "production renderer should remove the rejected charging copy")
	_expect(localization_source.find(rejected_copy) < 0, "localization data should remove the rejected charging copy")
	_expect(renderer_source.find("var center := Vector2(width * 0.5, 80.0)") >= 0, "boss wait title should return to the original y=80 anchor")
	_expect(renderer_source.find("_draw_accent_line(canvas, width, serve_rect, accent_color)") >= 0, "boss wait title should retain the original single accent line")
	_expect(renderer_source.find("INFO_FONT_SIZE := 16") >= 0, "boss wait status should restore the original font size")
	_expect(renderer_source.find("hud.serve_wait.boss_turn_format") >= 0, "boss turn title should use the seven-locale key")
	_expect(renderer_source.find("hud.serve_wait.preparing") >= 0, "preparing copy should use the seven-locale key")
	_expect(renderer_source.find("hud.serve_wait.ready") >= 0, "ready copy should use the seven-locale key")
	_expect(renderer_source.find("StageBossVariantCatalog.get_entry(") >= 0, "boss labels should read the scoreboard's canonical variant catalog")
	_expect(renderer_source.find("stage1_boss_variant") >= 0, "boss labels should retain the separate Stage 1 context authority")
	_expect(renderer_source.find("stage_boss_variant") >= 0, "boss labels should read the cross-stage context authority")
	_expect(renderer_source.find("const STAGE_BOSS_NAMES") < 0, "serve wait should not restore the stale stage-number boss table")
	for token in REMOVED_PANEL_TOKENS:
		_expect(renderer_source.find(token) < 0, "rejected boss panel token should stay removed: %s" % token)
	_expect(renderer_source.find("canvas.draw_circle(") < 0, "boss wait renderer should not retain moving light motes")
	_expect(renderer_source.find("\"Preparing...\"") < 0, "production renderer should not hardcode the English preparing copy")
	_expect(renderer_source.find("\"Ready\"") < 0, "production renderer should not hardcode the English ready copy")
	_expect(renderer_source.find("%s Serve") < 0, "production renderer should not hardcode the non-Korean title format")
	_expect(renderer_source.find("—") < 0, "boss serve Korean copy should not contain an em dash")


func _build_variant_context(stage_id: int, variant_id: String) -> Dictionary:
	var context := {"current_stage": stage_id}
	if stage_id == 1:
		context["stage1_boss_variant"] = variant_id
	else:
		context["stage_boss_variant"] = variant_id
	return context


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
