extends RefCounted

const ACTION_INVALID := "invalid"
const ACTION_CONVERT_TO_GOLD := "convert_to_gold"
const ACTION_FULL_GAUGE := "full_gauge"
const ACTION_FULL_GAUGE_DEFERRED := "full_gauge_deferred"
const ACTION_DIMENSION_GATE := "dimension_gate"
const ACTION_DIMENSION_GATE_DEFERRED := "dimension_gate_deferred"
const ACTION_MONKEY_BLESSING := "monkey_blessing"
const ACTION_TREASURE_HUNT := "treasure_hunt"
const ACTION_LINGPET_AFFINITY_CHIP := "lingpet_affinity_chip"
const ACTION_LINGPET_RING_CORE_UPGRADE := "lingpet_ring_core_upgrade"
const ACTION_LINGPET_GUARDIAN_ENHANCE := "lingpet_guardian_enhance"
const ACTION_STANDARD := "standard"


func build_dispatch(
	choice: Dictionary,
	defer_full_gauge: bool,
	defer_dimension_gate: bool,
	lingpet_affinity_chip_id: String,
	lingpet_ring_core_upgrade_id: String
) -> Dictionary:
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	if choice_id == "":
		return {
			"accepted": false,
			"choice_id": "",
			"action": ACTION_INVALID,
		}

	return {
		"accepted": true,
		"choice_id": choice_id,
		"action": _resolve_action(
			choice_id,
			defer_full_gauge,
			defer_dimension_gate,
			lingpet_affinity_chip_id,
			lingpet_ring_core_upgrade_id
		),
	}


func _resolve_action(
	choice_id: String,
	defer_full_gauge: bool,
	defer_dimension_gate: bool,
	lingpet_affinity_chip_id: String,
	lingpet_ring_core_upgrade_id: String
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
		"instant_treasure_hunt":
			return ACTION_TREASURE_HUNT
	if choice_id == lingpet_affinity_chip_id:
		return ACTION_LINGPET_AFFINITY_CHIP
	if choice_id == lingpet_ring_core_upgrade_id:
		return ACTION_LINGPET_RING_CORE_UPGRADE
	if choice_id == ACTION_LINGPET_GUARDIAN_ENHANCE:
		return ACTION_LINGPET_GUARDIAN_ENHANCE
	return ACTION_STANDARD
