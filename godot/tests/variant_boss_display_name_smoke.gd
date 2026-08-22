extends SceneTree

const DefeatSettlementScreen := preload("res://scripts/core/defeat_settlement_screen.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ScoreboardOverlayHeaderRenderer := preload("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const Stage2ArachneBossState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage2MolewangBossState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const Stage3AliceBossState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")
const Stage3BossSkillHudStateBuilder := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_state_builder.gd")
const Stage3TeddyBearBossState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")
const TowerAscentBossRegistry := preload("res://scripts/tower_ascent/tower_ascent_boss_registry.gd")

const HEADER_PATH := "res://scripts/hud/scoreboard_overlay_header_renderer.gd"
const SETTLEMENT_PATH := "res://scripts/core/defeat_settlement_screen.gd"
const STAGE3_HUD_BUILDER_PATH := "res://scripts/stages/stage3/stage3_boss_skill_hud_state_builder.gd"
const TARGET_DISPLAY_NAMES := {
	"arachne": "거미각시",
	"molewang": "지굴왕",
	"alice": "옥토선자",
	"teddy_bear": "포웅귀",
}
const LEGACY_DISPLAY_NAMES := {
	"arachne": "아라크네",
	"molewang": "두더지왕",
	"alice": "엘리스",
	"teddy_bear": "테디베어",
}
const TOWER_SLOT_BY_VARIANT := {
	"dalji": "floor_01_dalji",
	"gaksi": "floor_01_gaksital",
	"podo": "floor_01_podo",
	"cheongringwi": "floor_02_cheongringwi",
	"molewang": "floor_02_molewang",
	"arachne": "floor_02_arachne",
	"yeonmyo": "floor_03_yeonmyo",
	"teddy_bear": "floor_03_teddy_bear",
	"alice": "floor_03_alice",
}
const EXPECTED_LOCALIZED_TARGET_NAMES := {
	"ko": {"arachne": "거미각시", "molewang": "지굴왕", "alice": "옥토선자", "teddy_bear": "포웅귀"},
	"en": {"arachne": "Spider Bride", "molewang": "Burrow King", "alice": "Jade Rabbit Sage", "teddy_bear": "Bear-Hug Ghost"},
	"zh": {"arachne": "蜘蛛新娘", "molewang": "地窟王", "alice": "玉兔仙子", "teddy_bear": "抱熊鬼"},
	"ja": {"arachne": "蜘蛛の花嫁", "molewang": "地窟王", "alice": "玉兎仙子", "teddy_bear": "抱熊鬼"},
	"es": {"arachne": "Novia Araña", "molewang": "Rey de la Madriguera", "alice": "Sabia del Conejo de Jade", "teddy_bear": "Fantasma Abrazaosos"},
	"pt-BR": {"arachne": "Noiva-Aranha", "molewang": "Rei da Toca", "alice": "Sábia do Coelho de Jade", "teddy_bear": "Fantasma Abraça-Urso"},
	"ru": {"arachne": "Невеста-паучиха", "molewang": "Король нор", "alice": "Мудрая Нефритовая Зайчиха", "teddy_bear": "Дух медвежьих объятий"},
}
const PRODUCTION_VARIANT_NAME_CONSUMER_PATHS := [
	"res://scripts/hud/scoreboard_overlay_header_renderer.gd",
	"res://scripts/core/defeat_settlement_screen.gd",
	"res://scripts/stages/stage2/stage2_arachne_boss_state.gd",
	"res://scripts/stages/stage2/stage2_molewang_boss_state.gd",
	"res://scripts/stages/stage3/stage3_alice_boss_state.gd",
	"res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd",
	"res://scripts/stages/stage3/stage3_boss_skill_hud_state_builder.gd",
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd",
]
const EXPECTED_LEG_COUNT := 7

var _failures: Array[String] = []
var _leg_count := 0


class FakeTearShowerState:
	extends RefCounted

	var tears_active := false
	var tears_cooldown := 25.0


class FakeCurseChestState:
	extends RefCounted

	var curse_phase := "idle"
	var curse_cooldown := 35.0


class FakePsychoballState:
	extends RefCounted

	var overdrive_active := false
	var psycho_cooldown := 70.0


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_confirmed_rebrand_names_and_compatibility_ids()
	_verify_catalog_drives_every_variant_consumer()
	_verify_default_bosses_are_unchanged()
	_verify_stage1_compatibility_key_is_unchanged()
	_verify_non_variant_stage_fallbacks_are_unchanged()
	_verify_catalog_names_cover_all_seven_locales()
	_verify_consumers_do_not_reintroduce_variant_name_tables()
	LanguageSettings.set_test_locale_override("")
	_expect(_leg_count == EXPECTED_LEG_COUNT, "all variant boss display-name smoke legs must execute")

	if _failures.is_empty():
		print("variant_boss_display_name_smoke: PASS=%d" % _leg_count)
		print("variant_boss_display_name_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_confirmed_rebrand_names_and_compatibility_ids() -> void:
	_leg_count += 1
	for variant_id in TARGET_DISPLAY_NAMES:
		_expect(StageBossVariantCatalog.VARIANTS.has(variant_id), "%s compatibility id must remain registered" % variant_id)
		var entry: Dictionary = StageBossVariantCatalog.VARIANTS.get(variant_id, {})
		_expect(
			str(entry.get("display_name", "")) == str(TARGET_DISPLAY_NAMES[variant_id]),
			"%s must use the user-confirmed Hwangyeok display name" % variant_id
		)
		_expect(
			str(entry.get("display_name", "")) != str(LEGACY_DISPLAY_NAMES[variant_id]),
			"%s must not retain its legacy player-facing name" % variant_id
		)


func _verify_catalog_drives_every_variant_consumer() -> void:
	_leg_count += 1
	var scoreboard: Object = ScoreboardOverlayHeaderRenderer.new()
	var settlement: Object = DefeatSettlementScreen.new()
	var stage3_hud_builder: Object = Stage3BossSkillHudStateBuilder.new()
	var tears := FakeTearShowerState.new()
	var curse := FakeCurseChestState.new()
	var psycho := FakePsychoballState.new()
	var direct_hud_context_by_variant := {
		"arachne": Stage2ArachneBossState.new().get_hud_context(),
		"molewang": Stage2MolewangBossState.new().get_hud_context(),
		"alice": Stage3AliceBossState.new().get_hud_context(),
		"teddy_bear": Stage3TeddyBearBossState.new().get_hud_context(),
	}
	var tower_registry := TowerAscentBossRegistry.new()

	for variant_id in _catalog_variant_ids():
		var source_entry: Dictionary = StageBossVariantCatalog.VARIANTS.get(variant_id, {})
		var stage_id: int = int(source_entry.get("stage", 0))
		var catalog_entry: Dictionary = StageBossVariantCatalog.get_entry(stage_id, variant_id)
		var expected_name: String = str(catalog_entry.get("display_name", ""))
		_expect(expected_name != "", "catalog variant %s should publish display_name" % variant_id)

		# Stage 1 predates the catalog and keeps its variant in a SEPARATE owner
		# field, so the consumer context key differs by stage.
		var scoreboard_context: Dictionary = {"current_stage": stage_id}
		if stage_id == 1:
			scoreboard_context["stage1_boss_variant"] = variant_id
		else:
			scoreboard_context["stage_boss_variant"] = variant_id
		var scoreboard_name: String = str(scoreboard.resolve_boss_name(scoreboard_context))
		_expect(
			scoreboard_name == expected_name,
			"scoreboard should resolve %s from the catalog (expected %s, got %s)" % [variant_id, expected_name, scoreboard_name]
		)

		var stage_snapshot_value: Variant = (
			settlement.call("_build_stage_snapshot", stage_id, "", variant_id)
			if stage_id == 1
			else settlement.call("_build_stage_snapshot", stage_id, variant_id)
		)
		var stage_snapshot: Dictionary = stage_snapshot_value as Dictionary
		var settlement_name: String = str(stage_snapshot.get("current_boss", ""))
		_expect(
			settlement_name == expected_name,
			"defeat settlement should resolve %s from the catalog (expected %s, got %s)" % [variant_id, expected_name, settlement_name]
		)

		var slot_id: String = str(TOWER_SLOT_BY_VARIANT.get(variant_id, ""))
		var tower_slot: Dictionary = tower_registry.get_slot(slot_id)
		_expect(
			str(tower_slot.get("display_name", "")) == expected_name,
			"Tower slot should resolve %s from the catalog" % variant_id
		)

		if direct_hud_context_by_variant.has(variant_id):
			var direct_hud_context: Dictionary = direct_hud_context_by_variant[variant_id]
			var direct_hud_name: String = str(direct_hud_context.get(
				"stage%d_boss_skill_hud_boss_name" % stage_id,
				""
			))
			_expect(
				direct_hud_name == expected_name,
				"variant skill HUD should resolve %s from the catalog" % variant_id
			)

		if stage_id == 3:
			var hud_context: Dictionary = stage3_hud_builder.build_context(
				"charging",
				0.0,
				500.0,
				tears,
				curse,
				psycho,
				variant_id
			)
			var hud_name: String = str(hud_context.get("stage3_boss_skill_hud_boss_name", ""))
			_expect(
				hud_name == expected_name,
				"Stage 3 skill HUD builder should resolve %s from the catalog (expected %s, got %s)" % [variant_id, expected_name, hud_name]
			)

	var default_stage2: Dictionary = StageBossVariantCatalog.get_entry(2, "")
	var default_stage3: Dictionary = StageBossVariantCatalog.get_entry(3, "")
	_expect(
		str(scoreboard.resolve_boss_name({"current_stage": 2})) == str(default_stage2.get("display_name", "")),
		"missing Stage 2 variant should retain the catalog default"
	)
	_expect(
		str(scoreboard.resolve_boss_name({"current_stage": 3})) == str(default_stage3.get("display_name", "")),
		"missing Stage 3 variant should retain the catalog default"
	)


func _verify_default_bosses_are_unchanged() -> void:
	_leg_count += 1
	var scoreboard: Object = ScoreboardOverlayHeaderRenderer.new()
	var settlement: Object = DefeatSettlementScreen.new()
	var tower_registry := TowerAscentBossRegistry.new()
	var stage2_hud: Dictionary = Stage2BossSkillState.new().get_hud_context()
	var stage3_hud: Dictionary = Stage3BossSkillHudStateBuilder.new().build_context(
		"charging",
		0.0,
		500.0,
		FakeTearShowerState.new(),
		FakeCurseChestState.new(),
		FakePsychoballState.new(),
		"yeonmyo"
	)
	var expected_by_variant := {
		"cheongringwi": {"stage": 2, "display_name": "청린귀"},
		"yeonmyo": {"stage": 3, "display_name": "환묘 연묘"},
	}
	for variant_id in expected_by_variant:
		var expected: Dictionary = expected_by_variant[variant_id]
		var stage_id: int = int(expected.get("stage", 0))
		var expected_name: String = str(expected.get("display_name", ""))
		_expect(
			str(StageBossVariantCatalog.get_entry(stage_id, variant_id).get("display_name", "")) == expected_name,
			"%s catalog name must remain unchanged" % variant_id
		)
		_expect(
			str(scoreboard.resolve_boss_name({"current_stage": stage_id, "stage_boss_variant": variant_id})) == expected_name,
			"%s scoreboard name must remain unchanged" % variant_id
		)
		var settlement_snapshot: Dictionary = settlement.call("_build_stage_snapshot", stage_id, variant_id) as Dictionary
		_expect(
			str(settlement_snapshot.get("current_boss", "")) == expected_name,
			"%s settlement name must remain unchanged" % variant_id
		)
		var tower_slot: Dictionary = tower_registry.get_slot(str(TOWER_SLOT_BY_VARIANT[variant_id]))
		_expect(
			str(tower_slot.get("display_name", "")) == expected_name,
			"%s Tower slot name must remain unchanged" % variant_id
		)
	_expect(
		str(stage2_hud.get("stage2_boss_skill_hud_boss_name", "")) == "청린귀",
		"base Stage 2 skill HUD must retain 청린귀"
	)
	_expect(
		str(stage3_hud.get("stage3_boss_skill_hud_boss_name", "")) == "환묘 연묘",
		"base Stage 3 skill HUD must retain 환묘 연묘"
	)


func _verify_stage1_compatibility_key_is_unchanged() -> void:
	_leg_count += 1
	var scoreboard: Object = ScoreboardOverlayHeaderRenderer.new()
	var settlement: Object = DefeatSettlementScreen.new()
	var expected_by_stage1_variant := {
		"dalji": "달지",
		"gaksi": "각시탈",
		"podo": "포도대장",
	}
	for variant_id in expected_by_stage1_variant:
		var actual: String = str(scoreboard.resolve_boss_name({
			"current_stage": 1,
			"stage1_boss_variant": variant_id,
			"stage_boss_variant": "teddy_bear",
		}))
		_expect(
			actual == str(expected_by_stage1_variant[variant_id]),
			"Stage 1 compatibility key should preserve %s display name" % variant_id
		)
	var stage1_snapshot: Dictionary = settlement.call("_build_stage_snapshot", 1, "teddy_bear") as Dictionary
	_expect(
		str(stage1_snapshot.get("current_boss", "")) == "달지",
		"defeat settlement must not reinterpret stage_boss_variant as the Stage 1 compatibility key"
	)


func _verify_non_variant_stage_fallbacks_are_unchanged() -> void:
	_leg_count += 1
	var scoreboard: Object = ScoreboardOverlayHeaderRenderer.new()
	var settlement: Object = DefeatSettlementScreen.new()
	var scoreboard_names := {
		4: "퐁크",
		5: "홍련",
		6: "테트리서",
		7: "아카무 리고",
		8: "미노타우로스",
	}
	var settlement_names := {
		4: "폰크",
		5: "홍련",
		6: "테트리서",
		7: "스테이지 7 보스",
		8: "스테이지 8 보스",
	}
	for stage_id in scoreboard_names:
		var scoreboard_name: String = str(scoreboard.resolve_boss_name({
			"current_stage": stage_id,
			"stage_boss_variant": "not_a_variant",
		}))
		_expect(
			scoreboard_name == str(scoreboard_names[stage_id]),
			"scoreboard Stage %d fallback should remain unchanged" % stage_id
		)
		var stage_snapshot: Dictionary = settlement.call(
			"_build_stage_snapshot",
			stage_id,
			"not_a_variant"
		) as Dictionary
		_expect(
			str(stage_snapshot.get("current_boss", "")) == str(settlement_names[stage_id]),
			"defeat settlement Stage %d fallback should remain unchanged" % stage_id
		)


func _verify_catalog_names_cover_all_seven_locales() -> void:
	_leg_count += 1
	var locales: Array[String] = LanguageSettings.get_language_options()
	_expect(locales.size() == 7, "boss-name coverage seal should exercise all seven supported locales")
	for locale in locales:
		LanguageSettings.set_test_locale_override(locale)
		var expected_target_names: Dictionary = EXPECTED_LOCALIZED_TARGET_NAMES.get(locale, {})
		_expect(expected_target_names.size() == TARGET_DISPLAY_NAMES.size(), "%s should define all four rebranded names" % locale)
		for variant_id in _catalog_variant_ids():
			var entry: Dictionary = StageBossVariantCatalog.VARIANTS.get(variant_id, {})
			var source_name: String = str(entry.get("display_name", ""))
			var translated_name: String = LanguageSettings.translate_text(source_name)
			_expect(translated_name != "", "%s should not resolve to an empty name in %s" % [variant_id, locale])
			if locale == LanguageSettings.LANGUAGE_KOREAN:
				_expect(translated_name == source_name, "%s should preserve its Korean source name" % variant_id)
			else:
				_expect(
					translated_name != source_name,
					"%s should have an explicit %s localization" % [variant_id, locale]
				)
		for variant_id in TARGET_DISPLAY_NAMES:
			var source_name: String = str(TARGET_DISPLAY_NAMES[variant_id])
			_expect(
				LanguageSettings.translate_text(source_name) == str(expected_target_names.get(variant_id, "")),
				"%s should use the approved %s localization" % [variant_id, locale]
			)
			var legacy_name: String = str(LEGACY_DISPLAY_NAMES[variant_id])
			var translated_legacy_name: String = LanguageSettings.translate_text(legacy_name)
			_expect(translated_legacy_name != "", "%s legacy save-facing name should remain translatable in %s" % [variant_id, locale])
			if locale != LanguageSettings.LANGUAGE_KOREAN:
				_expect(
					translated_legacy_name != legacy_name,
					"%s legacy translation key should remain registered in %s" % [variant_id, locale]
				)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _verify_consumers_do_not_reintroduce_variant_name_tables() -> void:
	_leg_count += 1
	var header_source: String = FileAccess.get_file_as_string(HEADER_PATH)
	var settlement_source: String = FileAccess.get_file_as_string(SETTLEMENT_PATH)
	var stage3_builder_source: String = FileAccess.get_file_as_string(STAGE3_HUD_BUILDER_PATH)
	for source_case in [
		{"label": "scoreboard", "source": header_source},
		{"label": "defeat settlement", "source": settlement_source},
		{"label": "Stage 3 skill HUD", "source": stage3_builder_source},
	]:
		_expect(
			str(source_case["source"]).contains("StageBossVariantCatalog.get_entry("),
			"%s should read the canonical variant catalog" % str(source_case["label"])
		)
	_expect(not header_source.contains("\t2: \"청린귀\""), "scoreboard should not retain a Stage 2 variant-name row")
	_expect(not header_source.contains("\t3: \"환묘 연묘\""), "scoreboard should not retain a Stage 3 variant-name row")
	_expect(not settlement_source.contains("\t2: \"청린귀\""), "defeat settlement should not retain a Stage 2 variant-name row")
	_expect(not settlement_source.contains("\t3: \"환묘 연묘\""), "defeat settlement should not retain a Stage 3 variant-name row")
	_expect(not stage3_builder_source.contains("const BOSS_NAME"), "Stage 3 skill HUD should not retain a fixed boss-name constant")
	for path in PRODUCTION_VARIANT_NAME_CONSUMER_PATHS:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains("StageBossVariantCatalog"), "%s should depend on the canonical variant catalog" % path)
		for legacy_name in LEGACY_DISPLAY_NAMES.values():
			_expect(
				not source.contains('"%s"' % str(legacy_name)),
				"%s should not hardcode legacy variant name %s" % [path, str(legacy_name)]
			)


func _catalog_variant_ids() -> Array[String]:
	var variant_ids: Array[String] = []
	for variant_id_value in StageBossVariantCatalog.VARIANTS.keys():
		variant_ids.append(str(variant_id_value))
	variant_ids.sort()
	return variant_ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
