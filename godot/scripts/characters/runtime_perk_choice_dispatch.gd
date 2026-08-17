extends RefCounted

const ACTION_INVALID := "invalid"
const ACTION_CONVERT_TO_GOLD := "convert_to_gold"
const ACTION_FULL_GAUGE := "full_gauge"
const ACTION_FULL_GAUGE_DEFERRED := "full_gauge_deferred"
const ACTION_DIMENSION_GATE := "dimension_gate"
const ACTION_DIMENSION_GATE_DEFERRED := "dimension_gate_deferred"
const ACTION_MONKEY_BLESSING := "monkey_blessing"
const ACTION_LINGPET_GUARDIAN_ENHANCE := "lingpet_guardian_enhance"
const ACTION_PHYSIQUE_TRAINING := "physique_training"
const ACTION_STANDARD := "standard"
# 은퇴 묘비(tombstone). 보물탐색 런타임 서브트리는 2026-08-06에 전부 제거됐지만,
# 구형 세이브·직렬화된 퍽 카드가 이 id를 그대로 들고 들어올 수 있다. 여기 남아 있어야
# build_dispatch가 ACTION_INVALID + blocked_reason="retired_choice"로 막는다 —
# 이 항목을 지우면 그 입력이 ACTION_STANDARD로 새어 존재하지 않는 퍽을 지급하려 든다.
# ⚠️되살리는 것도 금지: 액션/런타임이 없으므로 id만 복구하면 도달 불가 분기가 된다.
const RETIRED_CHOICE_IDS := {
	"instant_treasure_hunt": true,
}


func build_dispatch(
	choice: Dictionary,
	defer_full_gauge: bool,
	defer_dimension_gate: bool
) -> Dictionary:
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	if choice_id == "":
		return {
			"accepted": false,
			"choice_id": "",
			"action": ACTION_INVALID,
		}
	if RETIRED_CHOICE_IDS.has(choice_id):
		return {
			"accepted": false,
			"choice_id": choice_id,
			"action": ACTION_INVALID,
			"blocked_reason": "retired_choice",
		}

	return {
		"accepted": true,
		"choice_id": choice_id,
		"action": ACTION_PHYSIQUE_TRAINING if bool(choice.get("is_physique_training", false)) else _resolve_action(
			choice_id,
			defer_full_gauge,
			defer_dimension_gate
		),
	}


func _resolve_action(
	choice_id: String,
	defer_full_gauge: bool,
	defer_dimension_gate: bool
) -> String:
	match choice_id:
		ACTION_CONVERT_TO_GOLD:
			return ACTION_CONVERT_TO_GOLD
		"instant_gauge_full":
			return ACTION_FULL_GAUGE_DEFERRED if defer_full_gauge else ACTION_FULL_GAUGE
		"instant_dimension_gate":
			return ACTION_DIMENSION_GATE_DEFERRED if defer_dimension_gate else ACTION_DIMENSION_GATE
		"instant_monkey_blessing":
			return ACTION_MONKEY_BLESSING
	if choice_id == ACTION_LINGPET_GUARDIAN_ENHANCE:
		return ACTION_LINGPET_GUARDIAN_ENHANCE
	return ACTION_STANDARD
