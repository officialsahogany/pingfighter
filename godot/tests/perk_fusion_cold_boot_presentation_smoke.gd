extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _failures: Array[String] = []


class RegistryStub:
	extends RefCounted

	var state: Object
	var catalog: Object

	func _init(state_value: Object, catalog_value: Object) -> void:
		state = state_value
		catalog = catalog_value

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return state
			"runtime_perk_catalog":
				return catalog
		return null


func _init() -> void:
	_verify_success_tier_clean_boot()
	_verify_side_effect_tier_counts_match_record()
	_verify_deletion_ejects_modules_with_count_parity()
	_verify_byproduct_tier_deploys_modules_with_count_parity()
	_verify_stable_save_tier_snaps_stabilizer()
	_verify_empty_penalty_stable_resolves_without_stabilizer()

	if _failures.is_empty():
		print("perk_fusion_cold_boot_presentation_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


# 실 committed_record 경로: 실 state 커밋(결정론 롤)으로 record를 만들고,
# 타임라인 스냅샷의 presentation을 읽는다 — force-inject 금지 계약.
func _commit_real_record(source_ids: Array, rolls: Dictionary, pre_own_core_stabilize: bool = false) -> Dictionary:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"common_swiftness": 5,
		"dash_lightweight": 5,
	}
	for source_value: Variant in source_ids:
		state.runtime_skill_levels[str(source_value)] = 5
	if pre_own_core_stabilize:
		var grant_record: Dictionary = state.commit_perk_fusion(
			["common_swiftness", "dash_lightweight"],
			{"outcome": "byproduct", "byproducts": ["core_stabilize"]},
			catalog
		)
		_expect(not grant_record.is_empty(), "stabilizer fixture should arm core_stabilize through a real grant commit")
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [{
		"id": "perk_fusion",
		"name": "퍽 융합",
		"is_perk_fusion": true,
		"eligible_sources": source_ids.duplicate(),
		"offer_lane": "fusion",
		"offer_protected": true,
	}]
	state.selected_index = 0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	state._perk_fusion_modal_flow.confirm_current()
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, rolls)
	_expect(bool(commit_result.get("accepted", false)), "presentation fixture should commit through the real modal path")
	var boot_snapshot: Dictionary = state._perk_fusion_modal_flow.get_snapshot().get("cold_boot", {}) as Dictionary
	return {
		"record": commit_result.get("record", {}) as Dictionary,
		"plan": boot_snapshot.get("presentation", {}) as Dictionary,
	}


func _rolls(outcome_roll: float, delete_roll: float = 1.0) -> Dictionary:
	return {
		"outcome": outcome_roll,
		"magnitude": [0.7, 0.7],
		"lane_selection": [0.0, 0.5],
		"delete": delete_roll,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0, 0.0],
	}


func _recount_penalties(record: Dictionary) -> int:
	var count := 0
	for perk_penalties_value: Variant in (record.get("option_penalties", {}) as Dictionary).values():
		if perk_penalties_value is Dictionary:
			count += (perk_penalties_value as Dictionary).size()
	return count


func _recount_deleted(record: Dictionary) -> int:
	var count := 0
	for deleted_keys_value: Variant in (record.get("deleted_options", {}) as Dictionary).values():
		if deleted_keys_value is Array:
			count += (deleted_keys_value as Array).size()
	return count


func _verify_success_tier_clean_boot() -> void:
	var driven: Dictionary = _commit_real_record(["item_luck", "common_bulk_up"], _rolls(0.0))
	var plan: Dictionary = driven.get("plan", {}) as Dictionary
	_expect(str(plan.get("tier", "")) == "success", "a clean success roll should plan the SYNC OK boot")
	_expect(str(plan.get("readout_id", "")) == "sync_ok", "success readout should be sync_ok")
	_expect(
		not bool(plan.get("boot_stutter", true))
			and not bool(plan.get("ignition_surge", true))
			and not bool(plan.get("boot_overshoot", true))
			and not bool(plan.get("stabilizer_snap", true)),
		"a clean boot must show no fault/overshoot/stabilizer tells"
	)
	_expect(
		int(plan.get("brown_out_lane_count", -1)) == 0
			and int(plan.get("ejected_module_count", -1)) == 0
			and int(plan.get("deployed_module_count", -1)) == 0,
		"a clean boot must carry zero mechanical fault/deploy counts"
	)


func _verify_side_effect_tier_counts_match_record() -> void:
	var driven: Dictionary = _commit_real_record(["item_luck", "common_bulk_up"], _rolls(0.25))
	var record: Dictionary = driven.get("record", {}) as Dictionary
	var plan: Dictionary = driven.get("plan", {}) as Dictionary
	_expect(str(plan.get("tier", "")) == "side_effect", "an unarmed side-effect roll should plan the OVERLOAD boot")
	_expect(str(plan.get("readout_id", "")) == "overload_derate", "side-effect readout should be overload_derate")
	_expect(bool(plan.get("boot_stutter", false)) and bool(plan.get("ignition_surge", false)), "side effect should stutter the gauge and surge the ignition")
	_expect(not bool(plan.get("boot_overshoot", true)) and not bool(plan.get("stabilizer_snap", true)), "side effect must not borrow jackpot/stabilizer tells")
	var expected_brown_out: int = _recount_penalties(record)
	_expect(expected_brown_out > 0, "side-effect fixture should actually produce at least one penalty lane")
	_expect(int(plan.get("brown_out_lane_count", -1)) == expected_brown_out, "brown-out lane count must equal the record's penalty option count")
	_expect(int(plan.get("ejected_module_count", -1)) == _recount_deleted(record), "eject count must equal the record's deleted option count")
	_expect(int(plan.get("deployed_module_count", -1)) == 0, "side effect deploys no awakening hardware")


func _verify_deletion_ejects_modules_with_count_parity() -> void:
	var driven: Dictionary = _commit_real_record(["sensor", "shrapnel_armor"], _rolls(0.25, 0.0))
	var record: Dictionary = driven.get("record", {}) as Dictionary
	var plan: Dictionary = driven.get("plan", {}) as Dictionary
	_expect(str(plan.get("tier", "")) == "side_effect", "a deletion roll is still the side-effect tier")
	var expected_ejected: int = _recount_deleted(record)
	_expect(expected_ejected > 0, "deletion fixture should actually delete at least one option (forward lane with >=2 options)")
	_expect(int(plan.get("ejected_module_count", -1)) == expected_ejected, "physically ejected fuse-module count must equal the record's deleted option count")
	_expect(int(plan.get("brown_out_lane_count", -1)) == _recount_penalties(record), "deletion branch brown-out parity must still hold")


func _verify_byproduct_tier_deploys_modules_with_count_parity() -> void:
	var driven: Dictionary = _commit_real_record(["item_luck", "common_bulk_up"], _rolls(0.90))
	var record: Dictionary = driven.get("record", {}) as Dictionary
	var plan: Dictionary = driven.get("plan", {}) as Dictionary
	_expect(str(plan.get("tier", "")) == "byproduct", "a jackpot roll should plan the CORE AWAKENED boot")
	_expect(str(plan.get("readout_id", "")) == "core_awakened", "byproduct readout should be core_awakened")
	_expect(bool(plan.get("boot_overshoot", false)) and bool(plan.get("ignition_dual_gold_ring", false)), "jackpot should overshoot the gauge and ignite the dual gold ring")
	_expect(not bool(plan.get("ignition_surge", true)) and not bool(plan.get("stabilizer_snap", true)), "jackpot must not borrow fault/stabilizer tells")
	var expected_deployed: int = (record.get("byproducts", []) as Array).size()
	_expect(expected_deployed >= 1, "byproduct fixture should actually grant at least one byproduct")
	_expect(int(plan.get("deployed_module_count", -1)) == expected_deployed, "deployed hardware module count must equal the record's byproduct count")
	_expect(int(plan.get("brown_out_lane_count", -1)) == 0 and int(plan.get("ejected_module_count", -1)) == 0, "jackpot boot must carry zero fault counts")


func _verify_stable_save_tier_snaps_stabilizer() -> void:
	var driven: Dictionary = _commit_real_record(["item_luck", "common_bulk_up"], _rolls(0.25), true)
	var record: Dictionary = driven.get("record", {}) as Dictionary
	var plan: Dictionary = driven.get("plan", {}) as Dictionary
	_expect(str(record.get("raw_outcome", "")) == "side_effect", "stabilizer fixture should roll a raw side effect")
	_expect(str(plan.get("tier", "")) == "stable", "an armed core must replace the side effect with the STABILIZED save branch")
	_expect(str(plan.get("readout_id", "")) == "stabilized", "stable readout should be stabilized")
	_expect(bool(plan.get("boot_stutter", false)), "the save branch still stutters the gauge (the surge really happened)")
	_expect(bool(plan.get("stabilizer_snap", false)), "the save branch must snap the cyan stabilizer coil in")
	_expect(not bool(plan.get("ignition_surge", true)), "the clamped ignition must not read as a confirmed overload surge")
	_expect(
		int(plan.get("brown_out_lane_count", -1)) == 0 and int(plan.get("ejected_module_count", -1)) == 0,
		"the stabilizer save leaves no confirmed fault counts (net-loss-free contract)"
	)


# 코덱스 CB2-P2: stable의 두 번째 성립 경로 — 페널티 lane이 아예 없는
# 소스 쌍(캐릭터 제한 numeric passive는 penalty_hookable=false)이 raw
# side_effect를 굴리면 빈 페널티 해소로 stable이 된다. core_stabilize는
# 소비되지 않았으므로 안정화 코일 SNAP-IN이 없어야 한다(서지는 자가
# 해소 — 게이지 스터터만 남는다).
func _verify_empty_penalty_stable_resolves_without_stabilizer() -> void:
	var driven: Dictionary = _commit_real_record(["dash_spirit", "extension_gear"], _rolls(0.25))
	var record: Dictionary = driven.get("record", {}) as Dictionary
	var plan: Dictionary = driven.get("plan", {}) as Dictionary
	_expect(str(record.get("raw_outcome", "")) == "side_effect", "empty-penalty fixture should roll a raw side effect")
	_expect(str(record.get("outcome", "")) == "stable", "an empty side effect should resolve to the stable branch")
	_expect(
		_recount_penalties(record) == 0 and _recount_deleted(record) == 0,
		"empty-penalty fixture must produce no penalties or deletions (non-hookable sources)"
	)
	_expect(not bool(record.get("core_stabilize_consumed", true)), "the empty-penalty path must not consume core_stabilize")
	_expect(str(plan.get("tier", "")) == "stable" and str(plan.get("readout_id", "")) == "stabilized", "empty-penalty stable should still read STABILIZED")
	_expect(bool(plan.get("boot_stutter", false)), "the gauge still stutters (the surge really rolled)")
	_expect(not bool(plan.get("stabilizer_snap", true)), "no stabilizer coil may snap in without core_stabilize consumption")
	_expect(not bool(plan.get("ignition_surge", true)), "the self-resolved surge must not read as a confirmed overload")
	_expect(
		int(plan.get("brown_out_lane_count", -1)) == 0
			and int(plan.get("ejected_module_count", -1)) == 0
			and int(plan.get("deployed_module_count", -1)) == 0,
		"the empty-penalty stable boot carries zero mechanical counts"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
