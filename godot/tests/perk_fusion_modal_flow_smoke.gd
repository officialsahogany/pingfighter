extends SceneTree

const PerkFusionModalFlow := preload("res://scripts/characters/perk_fusion_modal_flow.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_start_normalizes_and_deep_copies()
	_verify_material_cancel_restores_exact_choices()
	_verify_selection_requires_exactly_two_sources()
	_verify_confirm_cancel_and_commit_contract()
	_verify_committed_record_animation_and_reveal_contract()
	_verify_timed_reveal_transition_runs_once()

	if _failures.is_empty():
		print("perk_fusion_modal_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_start_normalizes_and_deep_copies() -> void:
	var flow := PerkFusionModalFlow.new()
	var fusion_card := {"id": "perk_fusion", "meta": {"tone": "blue"}}
	var origin_choices := [
		{"id": "perk_fusion", "meta": {"rank": 1}},
		{"id": "dash_lightweight"},
	]
	_expect(flow.start(fusion_card, origin_choices, ["gamma", "alpha", "gamma", "", "beta"]), "start should accept two or more unique candidates")
	fusion_card["meta"]["tone"] = "red"
	origin_choices[0]["meta"]["rank"] = 9
	var snapshot: Dictionary = flow.get_snapshot()
	_expect(str(snapshot.get("phase", "")) == PerkFusionModalFlow.PHASE_MATERIALS, "start should enter materials phase")
	_expect(_dict(_dict(snapshot.get("fusion_card", {})).get("meta", {})).get("tone", "") == "blue", "fusion card should be deep-copied")
	_expect(int(_dict(_dict(_array(snapshot.get("origin_choices", []))[0]).get("meta", {})).get("rank", 0)) == 1, "origin choices should be deep-copied")
	_expect(_array(snapshot.get("candidate_ids", [])) == ["alpha", "beta", "gamma"], "candidate ids should be unique and sorted")
	_dict(snapshot.get("fusion_card", {}))["id"] = "mutated"
	_array(snapshot.get("origin_choices", []))[0] = {"id": "mutated"}
	var fresh_snapshot: Dictionary = flow.get_snapshot()
	_expect(str(_dict(fresh_snapshot.get("fusion_card", {})).get("id", "")) == "perk_fusion", "returned snapshots should not alias the stored fusion card")
	_expect(str(_dict(_array(fresh_snapshot.get("origin_choices", []))[0]).get("id", "")) == "perk_fusion", "returned snapshots should not alias stored choices")
	var rejected := PerkFusionModalFlow.new()
	_expect(not rejected.start({"id": "perk_fusion"}, [], ["only_one"]), "start should reject fewer than two unique candidates")
	_expect(not rejected.is_active(), "rejected start should remain inactive")


func _verify_material_cancel_restores_exact_choices() -> void:
	var flow := PerkFusionModalFlow.new()
	var origin_choices := [
		{"id": "one", "nested": {"value": 1}},
		{"id": "perk_fusion"},
		{"id": "three"},
	]
	flow.start({"id": "perk_fusion"}, origin_choices, ["source_b", "source_a"])
	var result: Dictionary = flow.cancel_current()
	_expect(bool(result.get("consumed", false)), "materials cancel should consume input")
	_expect(bool(result.get("cancel_to_choices", false)), "materials cancel should request a return to choices")
	_expect(_array(result.get("origin_choices", [])) == origin_choices, "materials cancel should restore the exact origin choice snapshot")
	_expect(not flow.is_active(), "materials cancel should reset the fusion flow")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_INACTIVE, "materials cancel should leave the flow inactive")
	_expect(not bool(flow.cancel_current().get("consumed", true)), "cancel should be inert after reset")


func _verify_selection_requires_exactly_two_sources() -> void:
	var flow := _started_flow(["source_c", "source_a", "source_b"])
	_expect(flow.select_source_at(0), "first candidate should be selectable")
	var one_source_result: Dictionary = flow.confirm_current()
	_expect(str(one_source_result.get("blocked_reason", "")) == "requires_two_sources", "materials confirm should require exactly two sources")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_MATERIALS, "blocked confirm should stay in materials")
	_expect(flow.select_source_at(1), "second candidate should be selectable")
	_expect(not flow.select_source_at(2), "a third candidate should not displace either selected source")
	_expect(_array(flow.get_snapshot().get("selected_source_ids", [])).size() == 2, "selection should never exceed two sources")
	_expect(bool(flow.confirm_current().get("entered_confirm", false)), "two selected sources should enter confirm")


func _verify_confirm_cancel_and_commit_contract() -> void:
	var flow := _started_flow(["source_b", "source_a"])
	flow.select_source_at(0)
	flow.select_source_at(1)
	var enter_confirm: Dictionary = flow.confirm_current()
	_expect(bool(enter_confirm.get("entered_confirm", false)), "first materials confirm should only enter confirm phase")
	_expect(not bool(enter_confirm.get("commit_requested", false)), "entering confirm should not request a commit")
	var cancel_result: Dictionary = flow.cancel_current()
	_expect(bool(cancel_result.get("entered_materials", false)), "confirm cancel should return to materials")
	_expect(flow.is_active(), "confirm cancel should keep the raw modal active")
	_expect(_array(flow.get_snapshot().get("selected_source_ids", [])).size() == 2, "confirm cancel should retain the selected pair")
	flow.confirm_current()
	var commit_result: Dictionary = flow.confirm_current()
	_expect(bool(commit_result.get("commit_requested", false)), "second confirm should request the runtime commit")
	_expect(_array(commit_result.get("source_ids", [])) == ["source_a", "source_b"], "commit request should return sorted source ids")
	_expect(flow.is_active(), "commit request must not close the raw perk modal")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_CONFIRM, "commit request should wait in confirm until a record is supplied")
	var duplicate_commit: Dictionary = flow.confirm_current()
	_expect(not bool(duplicate_commit.get("commit_requested", true)), "a repeated confirm should not emit a duplicate commit")
	_expect(bool(duplicate_commit.get("already_requested", false)), "a repeated commit request should report idempotency")
	_expect(not flow.begin_committed_result({}, 0.5), "an empty committed record should not enter animation")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_CONFIRM, "an empty committed record should leave confirm intact")


func _verify_committed_record_animation_and_reveal_contract() -> void:
	var flow := _committed_flow(1.1)
	var animation_snapshot: Dictionary = flow.get_snapshot()
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_ANIMATION, "a committed record should enter animation")
	_expect(str(_dict(animation_snapshot.get("committed_record", {})).get("outcome", "")) == "stable", "committed record should exist during animation")
	var animation_cancel: Dictionary = flow.cancel_current()
	_expect(bool(animation_cancel.get("consumed", false)), "animation cancel should be consumed")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_ANIMATION, "animation cancel should not roll back or close")
	var skip_result: Dictionary = flow.confirm_current()
	_expect(bool(skip_result.get("entered_reveal", false)), "animation confirm should skip to reveal")
	_expect(bool(skip_result.get("skipped_animation", false)), "animation skip should be explicit")
	var reveal_snapshot: Dictionary = flow.get_snapshot()
	_expect(str(_dict(reveal_snapshot.get("committed_record", {})).get("outcome", "")) == "stable", "committed record should survive into reveal")
	var reveal_cancel: Dictionary = flow.cancel_current()
	_expect(bool(reveal_cancel.get("consumed", false)), "reveal cancel should be consumed")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_REVEAL, "reveal cancel should not roll back")
	var finish_result: Dictionary = flow.confirm_current()
	_expect(bool(finish_result.get("finish_requested", false)), "only reveal confirm should request normal choice finish")
	_expect(str(_dict(finish_result.get("record", {})).get("outcome", "")) == "stable", "finish request should carry a copied committed record")
	_expect(flow.is_active(), "finish request should leave lifecycle mutation to the integrating owner")
	var duplicate_finish: Dictionary = flow.confirm_current()
	_expect(not bool(duplicate_finish.get("finish_requested", true)), "repeated reveal confirm should not emit duplicate finish")
	_expect(bool(duplicate_finish.get("already_requested", false)), "repeated finish should report idempotency")
	flow.reset()
	_expect(not flow.is_active(), "reset should deactivate a completed fusion flow")
	_expect(_dict(flow.get_snapshot().get("committed_record", {})).is_empty(), "reset should clear the committed record")


func _verify_timed_reveal_transition_runs_once() -> void:
	var flow := _committed_flow(0.2)
	_expect(not bool(flow.update(0.1).get("entered_reveal", true)), "partial animation update should not reveal")
	var reveal_result: Dictionary = flow.update(0.11)
	_expect(bool(reveal_result.get("entered_reveal", false)), "animation expiry should enter reveal once")
	_expect(flow.get_phase() == PerkFusionModalFlow.PHASE_REVEAL, "animation expiry should leave the flow in reveal")
	_expect(not bool(flow.update(1.0).get("entered_reveal", true)), "updates after reveal should not repeat the transition")


func _started_flow(candidate_ids: Array) -> Object:
	var flow := PerkFusionModalFlow.new()
	flow.start(
		{"id": "perk_fusion", "name": "퍽 융합"},
		[{"id": "choice_a"}, {"id": "perk_fusion"}, {"id": "choice_c"}],
		candidate_ids
	)
	return flow


func _committed_flow(duration: float) -> Object:
	var flow: Object = _started_flow(["source_b", "source_a"])
	flow.select_source_at(0)
	flow.select_source_at(1)
	flow.confirm_current()
	flow.confirm_current()
	_expect(flow.begin_committed_result({"outcome": "stable", "nested": {"value": 2}}, duration), "valid committed record should be accepted")
	return flow


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
