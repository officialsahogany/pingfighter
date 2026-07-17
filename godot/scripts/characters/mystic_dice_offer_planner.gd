extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const CARD_ID := "mystic_dice"
const APPEARANCE_CHANCE := 0.5

const OFFER_SOURCE_BATTLE_STARPOINT := "battle_starpoint"
const OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE := "result_box_starpoint_choice"
const OFFER_LANE_GOLD := "gold"
const OFFER_LANE_MYSTIC_DICE := "mystic_dice"

const ALLOWED_OFFER_SOURCES := {
	OFFER_SOURCE_BATTLE_STARPOINT: true,
	OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE: true,
}


func plan_offer(
	choices: Array,
	offer_source: String,
	remaining_uses: int,
	appearance_roll_unit: float
) -> Dictionary:
	var planned_choices: Array = choices.duplicate(true)
	var base_result := {
		"choices": planned_choices,
		"rolled": false,
		"appeared": false,
		"replacement_index": -1,
	}
	if not can_roll(planned_choices, offer_source, remaining_uses):
		return base_result

	base_result["rolled"] = true
	if clampf(appearance_roll_unit, 0.0, 1.0) >= APPEARANCE_CHANCE:
		return base_result

	var replacement_index := _find_gold_lane_index(planned_choices)
	var replaced_choice: Dictionary = (planned_choices[replacement_index] as Dictionary).duplicate(true)
	planned_choices[replacement_index] = build_card(replaced_choice)
	base_result["appeared"] = true
	base_result["replacement_index"] = replacement_index
	return base_result


func can_roll(choices: Array, offer_source: String, remaining_uses: int) -> bool:
	return (
		remaining_uses > 0
		and is_offer_source_allowed(offer_source)
		and _find_gold_lane_index(choices) >= 0
	)


func is_offer_source_allowed(offer_source: String) -> bool:
	return bool(ALLOWED_OFFER_SOURCES.get(offer_source.strip_edges(), false))


static func build_card(replaced_choice_snapshot: Dictionary = {}) -> Dictionary:
	var card := {
		"id": CARD_ID,
		"name": "신비의 주사위",
		"description": "퍽을 포기하고 주사위를 굴려 7가지 능력치를 영구히 조정합니다. 다시 굴리기 2회.",
		"detail": "행운이 살짝 미소 짓는 주사위입니다. 유리한 변화가 조금 더 자주 나오지만, 손해도 감수해야 합니다.",
		"icon_color": Color(0.38, 0.28, 0.82),
		"tree": "system_choice",
		"character_restriction": "",
		"is_mystic_dice": true,
		"offer_protected": true,
		"offer_lane": OFFER_LANE_MYSTIC_DICE,
		"current_level": 0,
		"next_level": 0,
		"max_level": 0,
	}
	if not replaced_choice_snapshot.is_empty():
		card["replaced_choice_snapshot"] = replaced_choice_snapshot.duplicate(true)
	return LanguageSettings.localize_perk_data(card)


func _find_gold_lane_index(choices: Array) -> int:
	for index: int in range(choices.size() - 1, -1, -1):
		var choice_value: Variant = choices[index]
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value as Dictionary
		if str(choice.get("offer_lane", "")).strip_edges().to_lower() == OFFER_LANE_GOLD:
			return index
	return -1
