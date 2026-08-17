extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const CARD_ID := "mystic_dice"
# Explicit retirement gate. This must remain independent of the active item's
# use-count representation so changing an unlimited-use sentinel can never
# resurrect the former perk offer.
const OFFER_ROTATION_ENABLED := false
const APPEARANCE_CHANCE := 0.25

const OFFER_SOURCE_BATTLE_STARPOINT := "battle_starpoint"
const OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE := "result_box_starpoint_choice"
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
		"append_index": -1,
	}
	if not can_roll(planned_choices, offer_source, remaining_uses):
		return base_result

	base_result["rolled"] = true
	if clampf(appearance_roll_unit, 0.0, 1.0) >= APPEARANCE_CHANCE:
		return base_result

	var append_index := planned_choices.size()
	planned_choices.append(build_card())
	base_result["appeared"] = true
	base_result["append_index"] = append_index
	return base_result


func can_roll(choices: Array, offer_source: String, remaining_uses: int) -> bool:
	if not OFFER_ROTATION_ENABLED:
		return false
	return (
		remaining_uses > 0
		and is_offer_source_allowed(offer_source)
		and not choices.is_empty()
		and not _has_mystic_dice_lane(choices)
	)


func is_offer_source_allowed(offer_source: String) -> bool:
	return bool(ALLOWED_OFFER_SOURCES.get(offer_source.strip_edges(), false))


static func build_card() -> Dictionary:
	var card := {
		"id": CARD_ID,
		"name": "팔자윷",
		"description": "윷가락을 던져 7가지 능력치를 이번 플레이 동안 누적 조정합니다. 다시 던지기 2회.",
		"detail": "행운이 살짝 미소 짓는 윷가락입니다. 엎어지고 자빠진 그대로의 팔자가 이번 플레이가 끝날 때까지 당신을 따라갑니다.",
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
	return LanguageSettings.localize_perk_data(card)


func _has_mystic_dice_lane(choices: Array) -> bool:
	for choice_value: Variant in choices:
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value as Dictionary
		if bool(choice.get("is_mystic_dice", false)):
			return true
		if str(choice.get("offer_lane", "")).strip_edges().to_lower() == OFFER_LANE_MYSTIC_DICE:
			return true
	return false
