extends SceneTree

# Seals the Lv.6+ (effective-level overflow) perk stat-line generator
# (2026-07-10 bug: a transcendent_crown Lv.7 비천보 tooltip still displayed the
# Lv.5 "대쉬 거리 35% 증가" line; every overflow-eligible perk shared the bug).
#
# Legs:
#  1. Reproduce seal: for EVERY registered pattern (linear, converted-template,
#     special-cased), the generated text must equal the catalog's authored
#     descriptions[level] VERBATIM at every defined level — template constants
#     cannot drift from catalog wording without failing here.
#  2. Overflow correctness: Lv.6+ values continue the runtime lanes (linear
#     constants, PerkConversionValues extrapolation + bounds, cap markers).
#  3. Runtime-table equality: the module's four_poisons lane tables equal
#     ViperSkillRuntime FOUR_POISONS_* consts, and the local extrapolation
#     math matches ViperSkillScaling for overflow levels.
#  4. Consumer wiring: the TAB character-info perk tooltip
#     (CharacterInfoOverlayPerkPresenter.acquired_perk_data) and the perk
#     overlay owned-perk tooltip (RuntimePerkOverlayRenderer._perk_stats_for_level)
#     both surface the generated Lv.6+ text instead of the stale Lv.5 text.
#  5. Non-Korean locales keep the collapsed summary fallback (no Korean
#     pattern text leaks into localized UIs).

const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const ViperSkillScaling := preload("res://scripts/characters/viper_skill_scaling.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SPECIAL_PATTERN_IDS := [
	"downtown_treasure_map",
	"combo_amplifier_chip",
	"pistol_enhance",
	"jetpack_enhance",
	"kick_enhance",
	"blade_amp",
	"four_poisons",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 비저장 locale 고정(표준): 저장형 set_language()는 실 user://
	# language_settings.cfg를 저장한다 — 정상 완주해도 원래 언어를
	# 파괴하고, 중간 종료 시 영어가 남는다. 성공·실패 공통 종료에서
	# ""로 해제한다.
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_test_reproduces_every_authored_level()
	_test_linear_overflow_values()
	_test_converted_overflow_single_sourced()
	_test_special_overflow_values()
	_test_four_poisons_tables_match_runtime()
	_test_presenter_consumes_overflow_text()
	_test_overlay_renderer_consumes_overflow_text()
	_test_non_korean_keeps_summary_fallback()
	LanguageSettings.set_test_locale_override("")
	if not _failures.is_empty():
		ProjectResourceLoader.clear_caches()
		quit(1)
		return
	print("runtime_perk_overflow_description_smoke: ok")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _registered_pattern_ids() -> Array:
	var ids: Array = []
	for skill_id in RuntimePerkOverflowDescriptions.LINEAR_PATTERNS.keys():
		ids.append(str(skill_id))
	for skill_id in RuntimePerkOverflowDescriptions.CONVERTED_TEMPLATES.keys():
		ids.append(str(skill_id))
	for skill_id in SPECIAL_PATTERN_IDS:
		ids.append(str(skill_id))
	return ids


func _test_reproduces_every_authored_level() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var all_data: Dictionary = catalog.get_all_perk_data()
	for skill_id in _registered_pattern_ids():
		_expect(all_data.has(skill_id), "registered pattern id must exist in the catalog: %s" % skill_id)
		if not all_data.has(skill_id):
			continue
		var perk_data: Dictionary = all_data[skill_id]
		var descriptions: Dictionary = perk_data.get("descriptions", {})
		_expect(not descriptions.is_empty(), "catalog perk must have descriptions: %s" % skill_id)
		for level_key in descriptions.keys():
			var level: int = int(level_key)
			var authored: String = str(descriptions[level_key])
			var generated: String = RuntimePerkOverflowDescriptions.generate_stats_text(skill_id, level)
			_expect(
				generated == authored,
				"%s Lv.%d template drift:\n  generated: %s\n  authored:  %s" % [skill_id, level, generated, authored]
			)


func _test_linear_overflow_values() -> void:
	# The reported bug: 비천보 Lv.7 must show 49%, not the Lv.5 35%.
	_expect_text("dash_jump", 7, "활주 거리 49% 증가")
	_expect_text("dash_lightweight", 6, "활주 재충전 72% 감소")
	_expect_text("common_swiftness", 6, "이동속도 36% 증가")
	_expect_text("perk_laurel_shield", 7, "벽사 잎 7개 보호")
	# value_max lanes clamp like their runtime consumers.
	_expect_text("item_recycle", 15, "아이템 유지 확률 90%")
	_expect_text("perk_boost_charge", 15, "확률 +100%, 발동 시 다음 활주 무료 + 재충전 -90%")


func _test_converted_overflow_single_sourced() -> void:
	# adversity_armor Lv.6: 40+5=45% / 15+2.5=17.5초 (average-slope extrapolation).
	_expect_text("adversity_armor", 6, "실점 후 발동 45%, 보호 17.5초")
	# battery Lv.6 hits its 100% overflow bound.
	_expect_text("battery", 6, "스테이지 전환 기력 보존 100%")
	_expect_text("neural_helmet", 6, "신령환 가드 기력 비용 35 감소, 패들 반사 공속 추가 +12%, 스폰 +387.5%")
	# sensor Lv.9 token count follows the int(round()) consumer (2.25 -> 2... 3.0 at Lv.9).
	var sensor_tokens: float = PerkConversionValues.get_value("sensor", "auto_dash_token_count", 9)
	_expect(int(round(sensor_tokens)) == 3, "fixture: sensor Lv.9 token lane should round to 3, got %f" % sensor_tokens)
	_expect_text("sensor", 9, "자동 활주 3회, 쿨타임 %s초" % _fmt(PerkConversionValues.get_value("sensor", "auto_dash_cooldown_sec", 9)))
	# Structural: every converted template lane matches get_value at an overflow level.
	for skill_id_value in RuntimePerkOverflowDescriptions.CONVERTED_TEMPLATES.keys():
		var skill_id: String = str(skill_id_value)
		var generated: String = RuntimePerkOverflowDescriptions.generate_stats_text(skill_id, 7)
		_expect(generated != "", "converted template must generate overflow text: %s" % skill_id)


func _test_special_overflow_values() -> void:
	# 천기보도 Lv.7: 승리 보상 픽의 절세무공 카드 등장 배율이 상한 없이 선형 증가한다.
	_expect_text("downtown_treasure_map", 7, "승리 보상 픽 절세무공 등장 확률 +1050%")
	# combo chip Lv.7: uncapped lanes keep scaling, capped lanes hold with (캡).
	_expect_text(
		"combo_amplifier_chip", 7,
		"콤보 효과 증폭: 벽력타 공속+630%, 커브+15%(캡), 천뢰격 공속+315%, 초기부스트 감쇄 -50%(캡)"
	)
	# pistol Lv.7: only the magazine keeps growing (documented Lv.6+ contract).
	_expect_text("pistol_enhance", 7, "단총통 정확도 ±1°, 탄속 +50%, 넉백 +150%, 장전 9발")
	_expect_text("jetpack_enhance", 6, "제트팩 최대 게이지 +120%, 체공 중 게이지 획득 +40%")
	_expect_text("kick_enhance", 7, "킥 발사 정밀도 +56%, 공속 +84%, 준비 -49%, 용광로 넉백볼 50%")
	# blade_amp Lv.6: range holds at the runtime clamp (+50%), speed keeps scaling.
	_expect_text("blade_amp", 6, "참격 사거리/가로폭 +50%(캡), 참격 속도 +60%, 추가 유도검기")
	# four_poisons Lv.6 extrapolates every lane by its runtime per-extra step.
	_expect_text(
		"four_poisons", 6,
		"천뢰진각/혼천흑창 준비 -44%, 천뢰진각 수면 +30%, 독영절맥 혼란 +80%, 쌍영분신 지속 +38%, 쌍영분신 HP 5, 4초식 쿨 -24%, 슈퍼아머, 분신 복제"
	)


func _test_four_poisons_tables_match_runtime() -> void:
	_expect_lane_matches_runtime("prep", RuntimePerkOverflowDescriptions.FOUR_POISONS_PREP, ViperSkillRuntime.FOUR_POISONS_PREP_REDUCTION_PCT_BY_LEVEL, ViperSkillRuntime.FOUR_POISONS_PREP_REDUCTION_PCT_PER_EXTRA_LEVEL, ViperSkillRuntime.FOUR_POISONS_PREP_REDUCTION_PCT_CAP)
	_expect_lane_matches_runtime("sleep", RuntimePerkOverflowDescriptions.FOUR_POISONS_SLEEP, ViperSkillRuntime.FOUR_POISONS_EMP_SLEEP_PCT_BY_LEVEL, ViperSkillRuntime.FOUR_POISONS_EMP_SLEEP_PCT_PER_EXTRA_LEVEL, ViperSkillRuntime.FOUR_POISONS_EMP_SLEEP_PCT_CAP)
	_expect_lane_matches_runtime("confusion", RuntimePerkOverflowDescriptions.FOUR_POISONS_CONFUSION, ViperSkillRuntime.FOUR_POISONS_VENOM_CONFUSION_PCT_BY_LEVEL, ViperSkillRuntime.FOUR_POISONS_VENOM_CONFUSION_PCT_PER_EXTRA_LEVEL, ViperSkillRuntime.FOUR_POISONS_VENOM_CONFUSION_PCT_CAP)
	_expect_lane_matches_runtime("dual_duration", RuntimePerkOverflowDescriptions.FOUR_POISONS_DUAL_DURATION, ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_BY_LEVEL, ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_PER_EXTRA_LEVEL, ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_CAP)
	_expect_lane_matches_runtime("cooldown", RuntimePerkOverflowDescriptions.FOUR_POISONS_COOLDOWN, ViperSkillRuntime.FOUR_POISONS_COOLDOWN_REDUCTION_PCT_BY_LEVEL, ViperSkillRuntime.FOUR_POISONS_COOLDOWN_REDUCTION_PCT_PER_EXTRA_LEVEL, ViperSkillRuntime.FOUR_POISONS_COOLDOWN_REDUCTION_PCT_CAP)
	_expect(
		RuntimePerkOverflowDescriptions.FOUR_POISONS_CLONE_HP["values"] == ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL,
		"clone HP table must equal ViperSkillRuntime FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL"
	)
	_expect(
		int(RuntimePerkOverflowDescriptions.FOUR_POISONS_CLONE_HP["cap"]) == ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP,
		"clone HP cap must equal ViperSkillRuntime FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP"
	)
	# The local extrapolation math must agree with ViperSkillScaling for
	# authored AND overflow levels.
	var scaling: Object = ViperSkillScaling.new()
	for level in range(1, 9):
		var expected_pct: int = scaling.get_four_poisons_scaled_pct(
			level,
			ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_BY_LEVEL,
			ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_CAP,
			ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_PER_EXTRA_LEVEL
		)
		var actual_pct: int = RuntimePerkOverflowDescriptions._four_poisons_scaled_pct(level, RuntimePerkOverflowDescriptions.FOUR_POISONS_DUAL_DURATION)
		_expect(actual_pct == expected_pct, "dual duration pct Lv.%d must match ViperSkillScaling (%d vs %d)" % [level, actual_pct, expected_pct])
		var expected_hp: int = scaling.get_dual_glitch_clone_hp(
			level,
			ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL,
			ViperSkillRuntime.FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP
		)
		var actual_hp: int = RuntimePerkOverflowDescriptions._four_poisons_clone_hp(level)
		_expect(actual_hp == expected_hp, "clone HP Lv.%d must match ViperSkillScaling (%d vs %d)" % [level, actual_hp, expected_hp])


func _expect_lane_matches_runtime(lane_name: String, lane: Dictionary, runtime_values: Array, runtime_per_extra: int, runtime_cap: int) -> void:
	_expect(lane["values"] == runtime_values, "four_poisons %s values must equal the ViperSkillRuntime table" % lane_name)
	_expect(int(lane["per_extra"]) == runtime_per_extra, "four_poisons %s per_extra must equal the ViperSkillRuntime const" % lane_name)
	_expect(int(lane["cap"]) == runtime_cap, "four_poisons %s cap must equal the ViperSkillRuntime const" % lane_name)


func _test_presenter_consumes_overflow_text() -> void:
	# The reported bug path: TAB character-info perk tooltip at base Lv.5 /
	# effective Lv.7 (transcendent_crown +2) must show the Lv.7 stats.
	var catalog: Object = RuntimePerkCatalog.new()
	var data: Dictionary = CharacterInfoOverlayPerkPresenter.acquired_perk_data(
		"dash_jump", 5, 7, catalog, {}, Color.WHITE
	)
	var stats: String = str(data.get("description", ""))
	_expect(
		stats == "활주 거리 49% 증가",
		"TAB perk tooltip must show the generated Lv.7 stats, got: %s" % stats
	)


func _test_overlay_renderer_consumes_overflow_text() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var skill: Dictionary = catalog.get_perk_data("dash_jump")
	skill["id"] = "dash_jump"
	skill["level"] = 7
	var stats: String = renderer._perk_stats_for_level(skill)
	_expect(
		stats == "활주 거리 49% 증가",
		"perk overlay owned-perk tooltip must show the generated Lv.7 stats, got: %s" % stats
	)


func _test_non_korean_keeps_summary_fallback() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	var generated: String = RuntimePerkOverflowDescriptions.generate_stats_text("dash_jump", 7)
	_expect(generated == "", "non-Korean locales must not generate Korean pattern text")
	var catalog: Object = RuntimePerkCatalog.new()
	var localized: Dictionary = catalog.get_perk_data("dash_jump")
	var descriptions: Dictionary = localized.get("descriptions", {})
	var resolved: String = RuntimePerkOverflowDescriptions.resolve_stats_text("dash_jump", descriptions, 7)
	var summary: String = str(descriptions.get(5, descriptions.get("5", "")))
	_expect(
		resolved == summary and resolved != "",
		"non-Korean overflow must fall back to the localized summary, got: %s" % resolved
	)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _expect_text(skill_id: String, level: int, expected: String) -> void:
	var generated: String = RuntimePerkOverflowDescriptions.generate_stats_text(skill_id, level)
	_expect(
		generated == expected,
		"%s Lv.%d overflow mismatch:\n  generated: %s\n  expected:  %s" % [skill_id, level, generated, expected]
	)


func _fmt(value: float) -> String:
	return RuntimePerkOverflowDescriptions._format_number(value)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("runtime_perk_overflow_description_smoke FAIL: " + message)
