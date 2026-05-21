extends SceneTree

const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")

const SOURCE_STAGE := "stage"
const SOURCE_BOX := "box"

var _failures: Array[String] = []


func _init() -> void:
	_verify_reward_summaries()
	_verify_perk_info_summary()
	_verify_perk_id_resolution()

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
		{"reward": {"type": "starpoint", "amount": 3}},
		{"reward": {"type": "gold", "amount": 999}},
		{"reward": {}},
	]

	var items: Array = StageClearResultSummaryBuilder.build_item_summary(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	var perks: Array = StageClearResultSummaryBuilder.build_perk_summary(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	var visible: Array = StageClearResultSummaryBuilder.build_visible_reward_summary(stage_snapshot, boxes, SOURCE_STAGE, SOURCE_BOX, source_labels)
	_expect(items.size() == 3, "item summary should include stage active/passive and box item rewards")
	_expect(perks.size() == 2, "perk summary should include stage perks and box skill rewards")
	_expect(visible.size() == 4, "visible summary should include visible items and starpoints but ignore gold fallback")
	_expect(int(StageClearResultSummaryBuilder.calculate_starpoint_total(boxes)) == 3, "starpoint total should add box starpoint rewards")

	var item_counts: Dictionary = StageClearResultSummaryBuilder.count_result_reward_sources(items, [SOURCE_STAGE, SOURCE_BOX])
	var perk_counts: Dictionary = StageClearResultSummaryBuilder.count_result_reward_sources(perks, [SOURCE_STAGE, SOURCE_BOX])
	_expect(int(item_counts.get(SOURCE_STAGE, 0)) == 2, "item source counts should include stage item rewards")
	_expect(int(item_counts.get(SOURCE_BOX, 0)) == 1, "item source counts should include box item rewards")
	_expect(int(perk_counts.get(SOURCE_STAGE, 0)) == 1, "perk source counts should include stage perk rewards")
	_expect(int(perk_counts.get(SOURCE_BOX, 0)) == 1, "perk source counts should include box skill rewards")
	_expect(str((items[0] as Dictionary).get("_result_reward_source_label", "")) == "stage label", "stage rewards should receive the stage label")
	_expect(str((items[2] as Dictionary).get("_result_reward_source_label", "")) == "box label", "box rewards should receive the box label")


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
