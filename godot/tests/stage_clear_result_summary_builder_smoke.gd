extends SceneTree

const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const SOURCE_STAGE := "stage"
const SOURCE_BOX := "box"

class FakeRuntimePerkState:
	extends RefCounted
	var gold_from_perks: int = 375

var _failures: Array[String] = []


func _init() -> void:
	_verify_reward_summaries()
	_verify_metric_helpers()
	_verify_perk_info_summary()
	_verify_perk_id_resolution()
	_verify_japanese_perk_info_summary()
	_verify_spanish_perk_info_summary()
	_verify_portuguese_brazil_perk_info_summary()
	_verify_russian_perk_info_summary()
	_verify_scene_delegates_summary_builder_directly()

	if _failures.is_empty():
		print("stage_clear_result_summary_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reward_summaries() -> void:
	var source_labels := {
		SOURCE_STAGE: "stage label",
		SOURCE_BOX: "box label",
	}
	var stage_snapshot := {
		"active_items": [
			{"type": "active", "label": "stage active"},
		],
		"passive_items": [
			{"type": "passive", "label": "stage passive"},
		],
		"perks": [
			{"type": "perk", "perk_id": "stage_perk"},
		],
	}
	var boxes := [
		{"reward": {"type": "mythic", "label": "box mythic"}},
		{"reward": {"type": "skill", "skill_id": "box_skill"}},
		{"reward": {
			"type": "starpoint",
			"amount": 3,
			"resolved_perk_rewards": [
				{"type": "perk", "perk_id": "box_starpoint_perk_a"},
				{"type": "perk", "perk_id": "box_starpoint_perk_b"},
			],
		}},
		{"reward": {"type": "gold", "amount": 999}},
		{"reward": {}},
	]

	var items: Array = StageClearResultSummaryBuilder.build_item_summary(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	var perks: Array = StageClearResultSummaryBuilder.build_perk_summary(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	var visible: Array = StageClearResultSummaryBuilder.build_visible_reward_summary(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	var state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	var item_groups: Dictionary = StageClearResultSummaryBuilder.split_item_rewards_by_type(items)
	_expect(items.size() == 3, "item summary should include stage active/passive and box item rewards")
	_expect(perks.size() == 4, "perk summary should include stage perks, box skill rewards, and box-selected perks")
	_expect(visible.size() == 5, "visible summary should replace resolved starpoints with selected perk rewards")
	_expect((item_groups.get("active_items", []) as Array).size() == 1, "item reward groups should split active items")
	_expect((item_groups.get("passive_items", []) as Array).size() == 1, "item reward groups should split passive items")
	_expect((item_groups.get("mythic_items", []) as Array).size() == 1, "item reward groups should split mythic items")
	_expect(int(StageClearResultSummaryBuilder.calculate_starpoint_total(boxes)) == 1, "starpoint total should count only unresolved box starpoints")
	_expect(int(state.get("item_reward_count", 0)) == items.size(), "summary state should expose item reward count")
	_expect(int(state.get("perk_reward_count", 0)) == perks.size(), "summary state should expose perk reward count")
	_expect(int(state.get("starpoint_total", 0)) == 1, "summary state should expose unresolved starpoint totals")

	var item_counts: Dictionary = StageClearResultSummaryBuilder.count_result_reward_sources(items, [SOURCE_STAGE, SOURCE_BOX])
	var perk_counts: Dictionary = StageClearResultSummaryBuilder.count_result_reward_sources(perks, [SOURCE_STAGE, SOURCE_BOX])
	_expect(int(item_counts.get(SOURCE_STAGE, 0)) == 2, "item source counts should include stage item rewards")
	_expect(int(item_counts.get(SOURCE_BOX, 0)) == 1, "item source counts should include box item rewards")
	_expect(int(perk_counts.get(SOURCE_STAGE, 0)) == 1, "perk source counts should include stage perk rewards")
	_expect(int(perk_counts.get(SOURCE_BOX, 0)) == 3, "perk source counts should include box skill and selected box perks")
	_expect(str((items[0] as Dictionary).get("_result_reward_source_label", "")) == "stage label", "stage rewards should receive the stage label")
	_expect(str((items[2] as Dictionary).get("_result_reward_source_label", "")) == "box label", "box rewards should receive the box label")
	_expect(str((perks[2] as Dictionary).get("_result_reward_source_label", "")) == "box label", "box-selected perks should receive the box label")
	_expect(str((visible[3] as Dictionary).get("perk_id", "")) == "box_starpoint_perk_a", "visible rewards should show the first selected box perk instead of the starpoint ticket")


func _verify_metric_helpers() -> void:
	var state := FakeRuntimePerkState.new()
	_expect(
		StageClearResultSummaryBuilder.resolve_display_gold(state, 1240) == 375,
		"display gold should prefer runtime perk gold when it exists"
	)
	_expect(
		StageClearResultSummaryBuilder.resolve_display_gold(null, 1240) == 1240,
		"display gold should fall back when runtime perk state is missing"
	)
	_expect(StageClearResultSummaryBuilder.calculate_score_rating(5, 0) == 3, "score margin 4+ should be a 3-star result")
	_expect(StageClearResultSummaryBuilder.calculate_score_rating(3, 1) == 2, "score margin 2-3 should be a 2-star result")
	_expect(StageClearResultSummaryBuilder.calculate_score_rating(2, 2) == 1, "score margin below 2 should be a 1-star result")


func _verify_perk_info_summary() -> void:
	var perk_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary(
		[
			{"type": "perk", "perk_id": "dash"},
			{"type": "skill", "skill_id": "guard"},
		],
		3,
		"대시 강화",
		"대시 충전 속도가 증가합니다."
	)
	_expect(str(perk_summary.get("kind", "")) == "perk", "perk info should prefer perk rewards over starpoints")
	_expect(str(perk_summary.get("eyebrow", "")) == "획득 퍽", "perk info should use the perk eyebrow")
	_expect(str(perk_summary.get("title", "")) == "대시 강화 외 1개", "perk info should summarize additional perks")
	_expect(str(perk_summary.get("detail", "")) == "대시 충전 속도가 증가합니다.", "perk info should preserve first perk detail")
	_expect(
		str(StageClearResultSummaryBuilder.build_perk_info_summary([{"type": "perk"}], 0, "", "").get("title", "")) == "획득 퍽",
		"perk info should keep a readable fallback title"
	)

	var starpoint_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary([], 2, "", "")
	_expect(str(starpoint_summary.get("kind", "")) == "starpoint", "empty perk info should surface starpoint choices")
	_expect(str(starpoint_summary.get("title", "")) == "퍽 선택권 +2", "starpoint info should include the earned amount")

	var empty_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary([], 0, "", "")
	_expect(str(empty_summary.get("kind", "")) == "empty", "empty perk info should report no perk rewards")
	_expect(str(empty_summary.get("title", "")) == "획득 퍽 없음", "empty perk info should use the no-perk title")


func _verify_perk_id_resolution() -> void:
	_expect(StageClearResultSummaryBuilder.is_perk_reward({"type": "skill", "skill_id": "blade"}), "skill rewards should count as perks")
	_expect(StageClearResultSummaryBuilder.is_perk_reward({"perk_data": {"id": "nested_perk"}}), "nested perk_data IDs should count as perk rewards")
	_expect(
		StageClearResultSummaryBuilder.get_reward_perk_id({"perk_data": {"id": "nested_perk"}}) == "nested_perk",
		"perk IDs should resolve from nested perk_data"
	)
	_expect(
		StageClearResultSummaryBuilder.get_stage_summary_array({"perks": [{"id": "a"}]}, "perks").size() == 1,
		"stage summary arrays should duplicate valid arrays"
	)
	_expect(
		StageClearResultSummaryBuilder.get_stage_summary_array({"perks": "bad"}, "perks").is_empty(),
		"stage summary arrays should ignore malformed values"
	)


func _verify_japanese_perk_info_summary() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	var perk_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary(
		[
			{"type": "perk", "perk_id": "dash"},
			{"type": "skill", "skill_id": "guard"},
		],
		3,
		"ダッシュ強化",
		"ダッシュ充填速度が増加します。"
	)
	_expect(str(perk_summary.get("title", "")) == "ダッシュ強化 他1個", "perk info extra count should localize to Japanese")
	var starpoint_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary([], 2, "", "")
	_expect(str(starpoint_summary.get("detail", "")) == "次回進行時、獲得数ぶんパーク選択画面が開きます。", "starpoint detail should localize to Japanese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_spanish_perk_info_summary() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	var perk_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary(
		[
			{"type": "perk", "perk_id": "dash"},
			{"type": "skill", "skill_id": "guard"},
		],
		3,
		"Dash",
		"Mejora el dash."
	)
	_expect(str(perk_summary.get("title", "")) == "Dash +1", "perk info extra count should localize to Spanish")
	var starpoint_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary([], 2, "", "")
	_expect(str(starpoint_summary.get("detail", "")) == "La siguiente partida abrirá elecciones de perks por la cantidad obtenida.", "starpoint detail should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_portuguese_brazil_perk_info_summary() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	var perk_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary(
		[
			{"type": "perk", "perk_id": "dash"},
			{"type": "skill", "skill_id": "guard"},
		],
		3,
		"Dash",
		"Melhora o dash."
	)
	_expect(str(perk_summary.get("title", "")) == "Dash +1", "perk info extra count should localize to Brazilian Portuguese")
	var starpoint_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary([], 2, "", "")
	_expect(str(starpoint_summary.get("detail", "")) == "A próxima partida abrirá escolhas de perks pela quantidade obtida.", "starpoint detail should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_russian_perk_info_summary() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	var perk_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary(
		[
			{"type": "perk", "perk_id": "dash"},
			{"type": "skill", "skill_id": "guard"},
		],
		3,
		"Dash",
		"Улучшает рывок."
	)
	_expect(str(perk_summary.get("title", "")) == "Dash +1", "perk info extra count should localize to Russian")
	var starpoint_summary: Dictionary = StageClearResultSummaryBuilder.build_perk_info_summary([], 2, "", "")
	_expect(str(starpoint_summary.get("detail", "")) == "В следующем забеге откроются выборы перков по полученному количеству.", "starpoint detail should localize to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_scene_delegates_summary_builder_directly() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("StageClearResultSummaryBuilder.build_result_summary_state") >= 0,
		"stage-clear result scene should use the aggregate summary state helper"
	)
	_expect(
		source.find("reward_summary_state.get(\"item_rewards\"") >= 0,
		"stage-clear result scene should render the item column from item-only rewards"
	)
	_expect(
		source.find("StageClearResultSummaryBuilder.split_item_rewards_by_type") >= 0
			and source.find("match str(item_dict.get(\"type\", \"\"))") < 0,
		"stage-clear result scene should delegate active/passive/mythic item grouping"
	)
	_expect(
		source.find("StageClearResultSummaryBuilder.resolve_display_gold") >= 0
			and source.find("StageClearResultSummaryBuilder.calculate_score_rating") >= 0,
		"stage-clear result scene should delegate summary-strip metric calculations"
	)
	for item_section_label in ["\"액티브 아이템\"", "\"패시브 아이템\"", "\"신화 아이템\""]:
		_expect(
			source.find(item_section_label) >= 0,
			"stage-clear result scene should label the split item reward bands (%s)" % item_section_label
		)
	for removed_wrapper in [
		"func _calculate_starpoint_total",
		"func _with_result_reward_source",
		"func _count_result_reward_sources",
		"func _get_stage_summary_array",
		"func _is_perk_reward",
		"func _get_reward_perk_id",
		"func _build_item_summary",
		"func _build_perk_summary",
		"func _build_visible_reward_summary",
		"StageClearResultSummaryBuilder.build_item_summary",
		"StageClearResultSummaryBuilder.build_perk_summary",
		"StageClearResultSummaryBuilder.build_visible_reward_summary",
		"StageClearResultSummaryBuilder.count_result_reward_sources",
		"StageClearResultSummaryBuilder.get_stage_summary_array",
	]:
		_expect(
			source.find(removed_wrapper) < 0,
			"stage-clear result scene should not keep summary pass-through wrapper %s" % removed_wrapper
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
