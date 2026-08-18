extends SceneTree

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const StageClearResultRewardPlanBuilder := preload(
	"res://scripts/core/stage_clear_result_reward_plan_builder.gd"
)
const StageClearRewardResolver := preload(
	"res://scripts/core/stage_clear_reward_resolver.gd"
)
const TowerAscentChestContract := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_contract.gd"
)
const TowerAscentChestContextBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_context_builder.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_flag_off_legacy_contract()
	_verify_one_box_and_three_kinds()
	_verify_risk_and_floor_raise_grade_weights()
	_verify_secret_downshift_chain()
	_verify_secret_context_and_reward()
	_verify_production_wiring_and_normal_jackpot()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_chest_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_flag_off_legacy_contract() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var builder := StageClearResultRewardPlanBuilder.new()
	var observed_counts := [
		builder.get_reward_box_count(5, 0),
		builder.get_reward_box_count(5, 2),
		builder.get_reward_box_count(6, 4),
		builder.get_reward_box_count(MatchScoreState.WIN_GOAL, 0),
		builder.get_reward_box_count(MatchScoreState.WIN_GOAL, 3),
		builder.get_reward_box_count(MatchScoreState.WIN_GOAL + 1, MatchScoreState.WIN_GOAL - 1),
	]
	_expect(observed_counts.has(3), "flag OFF must preserve a dominant-win three-box tier")
	_expect(observed_counts.has(2), "flag OFF must preserve an ordinary-win two-box tier")
	_expect(observed_counts.has(1), "flag OFF must preserve a deuce one-box tier")
	_expect(builder.roll_stage_clear_box_kind(0.0) == "guaranteed_mythic", "flag OFF must preserve the independent guaranteed-mythic roll")


func _verify_one_box_and_three_kinds() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var builder := StageClearResultRewardPlanBuilder.new()
	var base_context := {
		"floor": 1,
		"secret_chosik_id": "dalji_vision",
		"secret_chosik_eligible": true,
		"supreme_art_available": true,
	}
	for scores in [[MatchScoreState.WIN_GOAL, 0], [MatchScoreState.WIN_GOAL, MatchScoreState.WIN_GOAL - 1], [MatchScoreState.WIN_GOAL + 1, MatchScoreState.WIN_GOAL - 1]]:
		var plan: Dictionary = builder.build_reward_plan(int(scores[0]), int(scores[1]), base_context, 0.999999)
		_expect(int(plan.get("reward_count", 0)) == 1, "flag ON must always report exactly one box")
		_expect((plan.get("boxes", []) as Array).size() == 1, "flag ON must materialize exactly one box")
	var contract := TowerAscentChestContract.new()
	var weights: Dictionary = contract.get_chest_weights(base_context)
	var total := _weight_total(weights)
	var secret_roll := float(weights[TowerAscentChestContract.CHEST_SECRET_CHOSIK]) * 0.5 / total
	var supreme_roll := (
		float(weights[TowerAscentChestContract.CHEST_SECRET_CHOSIK])
		+ float(weights[TowerAscentChestContract.CHEST_SUPREME_ART]) * 0.5
	) / total
	var normal_roll := (
		float(weights[TowerAscentChestContract.CHEST_SECRET_CHOSIK])
		+ float(weights[TowerAscentChestContract.CHEST_SUPREME_ART])
		+ float(weights[TowerAscentChestContract.CHEST_NORMAL]) * 0.5
	) / total
	_expect(_kind(contract.build_reward_plan(base_context, secret_roll)) == TowerAscentChestContract.CHEST_SECRET_CHOSIK, "eligible rare roll must produce the independent secret-Chosik chest")
	_expect(_kind(contract.build_reward_plan(base_context, supreme_roll)) == TowerAscentChestContract.CHEST_SUPREME_ART, "middle rare roll must produce the supreme-art chest")
	_expect(_kind(contract.build_reward_plan(base_context, normal_roll)) == TowerAscentChestContract.CHEST_NORMAL, "ordinary roll must produce the normal chest")


func _verify_risk_and_floor_raise_grade_weights() -> void:
	var contract := TowerAscentChestContract.new()
	var base: Dictionary = contract.get_chest_weights({"floor": 1})
	var danger: Dictionary = contract.get_chest_weights({
		"floor": 12,
		"is_elite": true,
		"is_enraged": true,
		"is_gatekeeper": true,
	})
	var base_upper := float(base[TowerAscentChestContract.CHEST_SUPREME_ART]) + float(base[TowerAscentChestContract.CHEST_SECRET_CHOSIK])
	var danger_upper := float(danger[TowerAscentChestContract.CHEST_SUPREME_ART]) + float(danger[TowerAscentChestContract.CHEST_SECRET_CHOSIK])
	_expect(danger_upper > base_upper, "higher floor and risk flags must raise only upper-grade chest weight")
	_expect(float(danger[TowerAscentChestContract.CHEST_NORMAL]) < float(base[TowerAscentChestContract.CHEST_NORMAL]), "risk premium must not create extra box quantity; it must shift normal weight downward")


func _verify_secret_downshift_chain() -> void:
	var contract := TowerAscentChestContract.new()
	var ineligible := {
		"secret_chosik_id": "",
		"secret_chosik_eligible": false,
		"supreme_art_available": true,
	}
	_expect(_kind(contract.build_reward_plan(ineligible, 0.0)) == TowerAscentChestContract.CHEST_SUPREME_ART, "ineligible secret chest must downshift to supreme art")
	ineligible["supreme_art_available"] = false
	_expect(_kind(contract.build_reward_plan(ineligible, 0.0)) == TowerAscentChestContract.CHEST_NORMAL, "unavailable supreme fallback must downshift again to normal")


func _verify_secret_context_and_reward() -> void:
	var context_builder := TowerAscentChestContextBuilder.new()
	var context: Dictionary = context_builder.build(null, null, 2)
	var vision_id := str(context.get("secret_chosik_id", ""))
	_expect(not vision_id.is_empty(), "a mapped stage boss must carry the canonical compatibility offer id")
	var reward: Dictionary = context_builder.build_secret_chosik_reward(vision_id)
	if bool(context.get("secret_chosik_catalog_available", false)):
		_expect(bool(context.get("secret_chosik_eligible", false)), "an unowned eligible stage boss must expose its secret Chosik chest identity")
		_expect(str(reward.get("reserved_perk_offer_id", "")) == vision_id, "secret chest reward must reserve the exact eligible Chosik")
		_expect(int(reward.get("amount", 0)) == 1, "secret Chosik chest must still grant exactly one content result")
	else:
		_expect(not bool(context.get("secret_chosik_eligible", true)), "missing boss-Vision content must fail closed into the documented downshift")
		_expect(reward.is_empty(), "missing boss-Vision content must not manufacture an ungrantable reward")


func _verify_production_wiring_and_normal_jackpot() -> void:
	var resolver := StageClearRewardResolver.new()
	var retired_kind_result: Dictionary = resolver.roll_reward("guaranteed_mythic", null, null, 0.999999)
	_expect(str(retired_kind_result.get("type", "")) not in ["mythic", "mythic_perk", "mythic_perk_choice"], "flag ON must not treat guaranteed_mythic as an independent guaranteed result")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/core/stage_clear_reward_resolver.gd")
	_expect(resolver_source.find("TOWER_NORMAL_MYTHIC_JACKPOT_CHANCE := 0.03") >= 0, "normal tower chest must absorb the confirmed three-percent mythic jackpot")
	var loot_source := FileAccess.get_file_as_string("res://scripts/core/victory_loot_phase_state.gd")
	_expect(loot_source.find("TowerRewardPickState") >= 0, "live tower victory loot must own the reward-pick replacement state")
	_expect(loot_source.find("_reward_pick_state.start(") >= 0, "live tower victory loot must enter the four-card reward pick instead of building chests")
	var legacy_marker_pos := loot_source.find("func _try_mark_boss_vision_offer_box")
	_expect(
		legacy_marker_pos < 0
			or loot_source.find("if TowerAscentFeatureFlags.is_vertical_slice_enabled():\n\t\treturn", legacy_marker_pos) >= 0,
		"tower path must bypass the legacy vision-box substitution when that compatibility path exists"
	)


func _kind(plan: Dictionary) -> String:
	var boxes_value: Variant = plan.get("boxes", [])
	if not (boxes_value is Array) or (boxes_value as Array).is_empty():
		return ""
	var box_value: Variant = (boxes_value as Array)[0]
	return str((box_value as Dictionary).get("kind", "")) if box_value is Dictionary else ""


func _weight_total(weights: Dictionary) -> float:
	return (
		float(weights.get(TowerAscentChestContract.CHEST_NORMAL, 0.0))
		+ float(weights.get(TowerAscentChestContract.CHEST_SUPREME_ART, 0.0))
		+ float(weights.get(TowerAscentChestContract.CHEST_SECRET_CHOSIK, 0.0))
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
