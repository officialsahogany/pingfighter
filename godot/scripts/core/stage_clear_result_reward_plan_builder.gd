extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BOX_KIND_NORMAL := "normal"
const BOX_KIND_ADVANCED := "advanced"
const BOX_KIND_GUARANTEED_MYTHIC := "guaranteed_mythic"
const GUARANTEED_MYTHIC_BOX_CHANCE := 0.03
const ADVANCED_BOX_CHANCE := 0.20


func build_reward_plan(winning_score: int, losing_score: int) -> Dictionary:
	var boxes: Array = []
	var box_count: int = get_reward_box_count(winning_score, losing_score)
	_append_stage_clear_boxes(boxes, box_count)
	return {
		"summary": LanguageSettings.format_item_box_summary(box_count),
		"boxes": boxes,
		"reward_count": boxes.size(),
	}


func get_reward_box_count(winning_score: int, losing_score: int) -> int:
	# 2026-07-28 보상 하향: 압승(5:0~5:1) 3개 / 일반 승리(5:2~5:4) 2개 /
	# 듀스 승리(6:4·6:5·7:5·7:6) 1개.
	if winning_score > 5:
		return 1
	if losing_score <= 1:
		return 3
	return 2


func roll_stage_clear_box_kind(roll: float) -> String:
	var clamped_roll: float = clamp(roll, 0.0, 0.999999)
	if clamped_roll < GUARANTEED_MYTHIC_BOX_CHANCE:
		return BOX_KIND_GUARANTEED_MYTHIC
	if clamped_roll < GUARANTEED_MYTHIC_BOX_CHANCE + ADVANCED_BOX_CHANCE:
		return BOX_KIND_ADVANCED
	return BOX_KIND_NORMAL


func _append_stage_clear_boxes(boxes: Array, count: int) -> void:
	for _index in range(max(0, count)):
		boxes.append({"kind": roll_stage_clear_box_kind(randf())})
