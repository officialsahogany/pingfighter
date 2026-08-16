extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentChestContract := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_contract.gd"
)

const BOX_KIND_NORMAL := "normal"
const BOX_KIND_ADVANCED := "advanced"
const BOX_KIND_GUARANTEED_MYTHIC := "guaranteed_mythic"
const GUARANTEED_MYTHIC_BOX_CHANCE := 0.03
const ADVANCED_BOX_CHANCE := 0.20

var _tower_chest_contract: Object = TowerAscentChestContract.new()


func build_reward_plan(
	winning_score: int,
	losing_score: int,
	tower_context: Dictionary = {},
	tower_roll_override: float = -1.0
) -> Dictionary:
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		var tower_plan: Dictionary = _tower_chest_contract.build_reward_plan(
			tower_context,
			tower_roll_override
		)
		tower_plan["summary"] = LanguageSettings.format_item_box_summary(1)
		return tower_plan
	var boxes: Array = []
	var box_count: int = get_reward_box_count(winning_score, losing_score)
	_append_stage_clear_boxes(boxes, box_count)
	return {
		"summary": LanguageSettings.format_item_box_summary(box_count),
		"boxes": boxes,
		"reward_count": boxes.size(),
	}


func get_reward_box_count(winning_score: int, losing_score: int) -> int:
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return 1
	# 정규 승리 전 구간은 압승/일반 티어이고, 정본 WIN_GOAL을 넘는
	# 듀스 승리만 1개 티어다. 승리 점수를 리터럴로 복제하면 GRT-054처럼
	# 정규 승리 전체가 듀스 티어로 접힌다.
	if winning_score > MatchScoreState.WIN_GOAL:
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
