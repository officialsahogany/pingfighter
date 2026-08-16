extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const CHEST_NORMAL := "chest_normal"
const CHEST_SUPREME_ART := "chest_supreme_art"
const CHEST_SECRET_CHOSIK := "chest_secret_chosik"


func build_reward_plan(context: Dictionary, roll_override: float = -1.0) -> Dictionary:
	var weights := get_chest_weights(context)
	var roll := randf() if roll_override < 0.0 else clampf(roll_override, 0.0, 0.999999)
	var rolled_kind := _roll_weighted_kind(weights, roll)
	var resolved_kind := _downshift_kind(rolled_kind, context)
	var box := {
		"kind": resolved_kind,
		"rolled_kind": rolled_kind,
	}
	if resolved_kind == CHEST_SECRET_CHOSIK:
		box["boss_vision_offer_id"] = str(context.get("secret_chosik_id", "")).strip_edges()
	return {
		"boxes": [box],
		"reward_count": 1,
		"weights": weights,
	}


func get_chest_weights(context: Dictionary) -> Dictionary:
	var floor_number := maxi(1, int(context.get("floor", 1)))
	var floor_steps := floor_number - 1
	var risk_steps := 0
	for risk_key in ["is_elite", "is_enraged", "is_gatekeeper"]:
		if bool(context.get(risk_key, false)):
			risk_steps += 1
	return {
		CHEST_NORMAL: maxf(
			0.0,
			TowerAscentTuning.CHEST_NORMAL_BASE_WEIGHT
				- TowerAscentTuning.CHEST_FLOOR_NORMAL_WEIGHT_REDUCTION * float(floor_steps)
				- TowerAscentTuning.CHEST_RISK_NORMAL_WEIGHT_REDUCTION * float(risk_steps)
		),
		CHEST_SUPREME_ART: maxf(
			0.0,
			TowerAscentTuning.CHEST_SUPREME_ART_BASE_WEIGHT
				+ TowerAscentTuning.CHEST_FLOOR_SUPREME_WEIGHT_BONUS * float(floor_steps)
				+ TowerAscentTuning.CHEST_RISK_SUPREME_WEIGHT_BONUS * float(risk_steps)
		),
		CHEST_SECRET_CHOSIK: maxf(
			0.0,
			TowerAscentTuning.CHEST_SECRET_CHOSIK_BASE_WEIGHT
				+ TowerAscentTuning.CHEST_FLOOR_SECRET_WEIGHT_BONUS * float(floor_steps)
				+ TowerAscentTuning.CHEST_RISK_SECRET_WEIGHT_BONUS * float(risk_steps)
		),
	}


func _roll_weighted_kind(weights: Dictionary, roll: float) -> String:
	var secret_weight := maxf(0.0, float(weights.get(CHEST_SECRET_CHOSIK, 0.0)))
	var supreme_weight := maxf(0.0, float(weights.get(CHEST_SUPREME_ART, 0.0)))
	var normal_weight := maxf(0.0, float(weights.get(CHEST_NORMAL, 0.0)))
	var total_weight := secret_weight + supreme_weight + normal_weight
	if total_weight <= 0.0:
		return CHEST_NORMAL
	var weighted_roll := clampf(roll, 0.0, 0.999999) * total_weight
	if weighted_roll < secret_weight:
		return CHEST_SECRET_CHOSIK
	weighted_roll -= secret_weight
	if weighted_roll < supreme_weight:
		return CHEST_SUPREME_ART
	return CHEST_NORMAL


func _downshift_kind(rolled_kind: String, context: Dictionary) -> String:
	if rolled_kind == CHEST_SECRET_CHOSIK:
		var secret_id := str(context.get("secret_chosik_id", "")).strip_edges()
		if bool(context.get("secret_chosik_eligible", false)) and not secret_id.is_empty():
			return CHEST_SECRET_CHOSIK
		if bool(context.get("supreme_art_available", true)):
			return CHEST_SUPREME_ART
		return CHEST_NORMAL
	if rolled_kind == CHEST_SUPREME_ART:
		return CHEST_SUPREME_ART if bool(context.get("supreme_art_available", true)) else CHEST_NORMAL
	return CHEST_NORMAL
