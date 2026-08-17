extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkFusionRuntimeState := preload("res://scripts/characters/runtime_perk_fusion_runtime_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_direct_state_and_runtime_facade()
	_verify_offer_injection_transaction()
	_verify_commit_preflight_fails_closed()
	if _failures.is_empty():
		print("runtime_perk_fusion_runtime_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_fusion_runtime_state.gd")
	_expect(RuntimePerkFusionRuntimeState != null, "fusion runtime-state owner should preload")
	_expect(
		runtime_source.find("RuntimePerkFusionRuntimeState") >= 0
		and runtime_source.find("var _fusion_runtime_state: Object = RuntimePerkFusionRuntimeState.new()") >= 0,
		"runtime perk facade should construct one fusion runtime-state owner"
	)
	for removed_field: String in [
		"var _perk_fusion_state:",
		"var _perk_fusion_byproduct_runtime:",
		"var _perk_fusion_offer_planner:",
	]:
		_expect(runtime_source.find(removed_field) < 0, "runtime facade should not retain fusion subsystem field %s" % removed_field)
	_expect(
		owner_source.find("func get_fusion_state(") >= 0
		and owner_source.find("func build_result_context(") >= 0
		and owner_source.find("func plan_offer(") >= 0
		and owner_source.find("func consume_wall_bounce_gold_award(") >= 0
		and owner_source.find("func queue_player_point_lost(") >= 0
		and owner_source.find("func reset(") >= 0,
		"fusion owner should contain core, offer, byproduct, and reset responsibilities"
	)
	_expect(
		runtime_source.find("var _perk_fusion_modal_flow: Object:") >= 0
		and runtime_source.find("return _fusion_runtime_state.peek_modal_flow()") >= 0
		and runtime_source.find("_fusion_runtime_state.set_modal_flow(value)") >= 0
		and runtime_source.find("var _perk_fusion_modal_input: Object:") >= 0
		and runtime_source.find("return _fusion_runtime_state.peek_modal_input()") >= 0
		and runtime_source.find("var _perk_fusion_modal_catalog: Object:") >= 0
		and runtime_source.find("return _fusion_runtime_state.get_modal_catalog()") >= 0,
		"fusion modal lookup/catalog seams should be computed owner-backed properties"
	)
	_expect(
		owner_source.find("func begin_modal_from_runtime_state(") >= 0
		and owner_source.find("func build_candidate_ids_from_runtime_state(") >= 0
		and owner_source.find("func handle_modal_input_from_runtime_state(") >= 0
		and owner_source.find("func cancel_modal_from_runtime_state(") >= 0
		and owner_source.find("func confirm_modal_from_runtime_state(") >= 0
		and owner_source.find("func build_commit_result_from_runtime_state(") >= 0
		and owner_source.find("func finish_modal_from_runtime_state(") >= 0,
		"fusion owner should own the complete S0-S4 modal transaction"
	)
	_expect(
		owner_source.find("func try_inject_offer_from_runtime_state(") >= 0
		and owner_source.find("func set_test_offer_roll_override(") >= 0
		and owner_source.find("func get_test_offer_roll_override(") >= 0,
		"fusion owner should own offer eligibility, RNG, replacement, and the deterministic roll seam"
	)
	for wrapper_contract: Array in [
		["func _try_inject_perk_fusion_offer(", "_fusion_runtime_state.try_inject_offer_from_runtime_state"],
		["func _begin_perk_fusion_modal(", "_fusion_runtime_state.begin_modal_from_runtime_state"],
		["func _build_perk_fusion_candidate_ids(", "_fusion_runtime_state.build_candidate_ids_from_runtime_state"],
		["func _handle_perk_fusion_modal_input(", "_fusion_runtime_state.handle_modal_input_from_runtime_state"],
		["func _cancel_perk_fusion_modal(", "_fusion_runtime_state.cancel_modal_from_runtime_state"],
		["func _confirm_perk_fusion_modal(", "_fusion_runtime_state.confirm_modal_from_runtime_state"],
		["func _build_perk_fusion_commit_result(", "_fusion_runtime_state.build_commit_result_from_runtime_state"],
		["func _finish_perk_fusion_modal(", "_fusion_runtime_state.finish_modal_from_runtime_state"],
	]:
		var body := _function_body(runtime_source, str(wrapper_contract[0]))
		_expect(body.find(str(wrapper_contract[1])) >= 0, "%s should delegate to the fusion owner" % str(wrapper_contract[0]))
	_expect(
		runtime_source.find("var _test_perk_fusion_offer_roll_override: Array = []") < 0
		and runtime_source.find("return _fusion_runtime_state.get_test_offer_roll_override()") >= 0
		and runtime_source.find("_fusion_runtime_state.set_test_offer_roll_override_values(value)") >= 0,
		"the legacy deterministic offer seam should be an owner-backed compatibility property"
	)
	_expect(
		_function_body(runtime_source, "func _try_inject_perk_fusion_offer(").find("randf()") < 0
		and _function_body(runtime_source, "func _try_inject_perk_fusion_offer(").find("current_choices =") < 0
		and _function_body(runtime_source, "func _confirm_perk_fusion_modal(").find("commit_perk_fusion") < 0
		and _function_body(runtime_source, "func _build_perk_fusion_commit_result(").find("randf()") < 0
		and _function_body(runtime_source, "func _finish_perk_fusion_modal(").find("_finish_successful_choice") < 0,
		"runtime fusion wrappers should not retain offer/result RNG, choice replacement, commit, or finish ordering"
	)


func _verify_direct_state_and_runtime_facade() -> void:
	var owner := RuntimePerkFusionRuntimeState.new()
	var catalog := RuntimePerkCatalog.new()
	var levels := {"item_luck": 5, "common_bulk_up": 5}
	var context: Dictionary = owner.build_result_context(["item_luck"], catalog, levels)
	_expect(
		(context.get("limit_break_eligible_sources", []) as Array).has("item_luck"),
		"owner should derive limit-break eligibility from invested levels and catalog max level"
	)
	_expect(
		not bool(owner.plan_offer([], [], "battle_starpoint", 0.0, 0.0).get("rolled", true)),
		"owner should preserve fail-closed fusion offer planning"
	)
	var record: Dictionary = owner.commit_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["overload_circuit", "reverb", "golden_trajectory"]},
		catalog,
		levels
	)
	_expect(not record.is_empty(), "owner should commit through the canonical fusion state")
	owner.notify_player_dash()
	owner.notify_skill_used()
	_expect(owner.can_trigger_dash_paddle_speed_boost(), "owner should expose an eligible Thunderbolt Drive dash hit")
	var thunder_drive: Dictionary = owner.try_trigger_dash_paddle_speed_boost(0.0, 13.0)
	_expect(
		bool(thunder_drive.get("triggered", false))
		and is_equal_approx(float(thunder_drive.get("speed_multiplier", 1.0)), 1.80),
		"owner should route the 15% roll success to an exact +80% speed boost"
	)
	_expect(is_equal_approx(owner.consume_boss_guard_restore_effective_speed(), 13.0), "owner should route the boss-guard restore speed")
	_expect(is_equal_approx(owner.get_move_speed_multiplier(), 1.70), "owner should route the active +70% reverb move speed")
	_expect(owner.consume_wall_bounce_gold_award(1.0, false) == 2, "owner should cap and record golden-trajectory wall gold")
	_expect(owner.get_round_golden_trajectory_gold() == 2, "owner should expose the recorded round gold")
	owner.try_trigger_dash_paddle_speed_boost(0.0, 15.0)
	var revision_before_reset := owner.get_revision()
	owner.reset()
	_expect(owner.get_revision() == revision_before_reset + 1, "owner reset should advance fusion revision exactly once")
	_expect((owner.get_snapshot().get("records", []) as Array).is_empty(), "owner reset should clear canonical fusion records")
	_expect(is_equal_approx(owner.get_move_speed_multiplier(), 1.0), "owner reset should clear timed byproduct state")
	_expect(is_equal_approx(owner.consume_boss_guard_restore_effective_speed(), 0.0), "owner reset should clear Thunderbolt Drive state")
	_expect(owner.get_round_golden_trajectory_gold() == 0, "owner reset should clear byproduct round gold")

	var runtime := RuntimePerkState.new()
	_expect(runtime._perk_fusion_modal_flow == null and runtime._perk_fusion_modal_input == null, "fresh runtime should keep fusion modal helpers lazy")
	var modal_flow: Object = runtime._get_perk_fusion_modal_flow()
	var modal_input: Object = runtime._get_perk_fusion_modal_input()
	_expect(modal_flow != null and runtime._perk_fusion_modal_flow == modal_flow, "fusion flow lookup should resolve the owner-held lazy instance")
	_expect(modal_input != null and runtime._perk_fusion_modal_input == modal_input, "fusion input lookup should resolve the owner-held lazy instance")
	runtime.runtime_skill_levels["item_luck"] = 5
	var facade_context: Dictionary = runtime._build_perk_fusion_result_context(["item_luck"], catalog)
	_expect(
		(facade_context.get("limit_break_eligible_sources", []) as Array).has("item_luck"),
		"runtime facade should delegate production result-context calculation"
	)
	_expect(runtime.get_perk_fusion_state() != null, "runtime facade should expose the owner-backed canonical fusion state")
	seed(77331)
	var expected_next_roll := randf()
	seed(77331)
	runtime.queue_perk_fusion_player_point_lost(true)
	_expect(
		is_equal_approx(randf(), expected_next_roll),
		"match-finished point loss should clear pending state without consuming the next gameplay RNG value"
	)


func _verify_offer_injection_transaction() -> void:
	var owner := RuntimePerkFusionRuntimeState.new()
	if not owner.has_method("try_inject_offer_from_runtime_state") \
	or not owner.has_method("set_test_offer_roll_override") \
	or not owner.has_method("get_test_offer_roll_override"):
		_expect(false, "fusion owner offer transaction methods should be callable")
		return
	var runtime := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	runtime.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	runtime.current_choice_context = {"source": "plaza_academy"}
	runtime.current_choices = [
		{"id": "ordinary", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "reserved", "offer_lane": "owned_upgrade_reserved", "offer_protected": true},
		{"id": "ordinary_2", "offer_lane": "replaceable", "offer_protected": false},
	]
	seed(88421)
	var expected_next_roll := randf()
	seed(88421)
	var denied: Dictionary = owner.call("try_inject_offer_from_runtime_state", runtime, catalog)
	_expect(not bool(denied.get("rolled", true)), "ineligible sources should fail closed in the owner")
	_expect(
		is_equal_approx(randf(), expected_next_roll),
		"ineligible fusion offers should not consume global gameplay RNG"
	)
	owner.call("set_test_offer_roll_override", 0.0, 0.0)
	owner.call("try_inject_offer_from_runtime_state", runtime, catalog)
	_expect(
		not (owner.call("get_test_offer_roll_override") as Array).is_empty(),
		"ineligible fusion offers should not consume the one-shot deterministic seam"
	)
	runtime.current_choice_context = {"source": "battle_starpoint"}
	var injected: Dictionary = owner.call("try_inject_offer_from_runtime_state", runtime, catalog)
	_expect(bool(injected.get("appeared", false)), "eligible forced-zero owner offer should appear")
	_expect(
		str((runtime.current_choices[0] as Dictionary).get("id", "")) == "perk_fusion",
		"fusion owner should commit the planned replacement to runtime current choices"
	)
	_expect(
		(owner.call("get_test_offer_roll_override") as Array).is_empty(),
		"eligible owner injection should consume the deterministic seam exactly once"
	)
	owner.call("set_test_offer_roll_override", 0.0, 0.0)
	owner.reset()
	_expect(
		(owner.call("get_test_offer_roll_override") as Array).is_empty(),
		"fusion owner reset should clear the deterministic offer seam"
	)


func _verify_commit_preflight_fails_closed() -> void:
	var owner := RuntimePerkFusionRuntimeState.new()
	var flow: Object = owner.get_modal_flow()
	_expect(
		bool(flow.start(
			{"id": "perk_fusion", "type": "fusion"},
			[],
			["item_luck", "common_bulk_up"]
		)),
		"preflight fixture should open the owner-held fusion flow"
	)
	flow.select_source_at(0)
	flow.select_source_at(1)
	var missing_finish_runtime := RefCounted.new()
	var enter_confirm: Dictionary = owner.confirm_modal_from_runtime_state(
		missing_finish_runtime,
		null,
		null,
		{}
	)
	_expect(bool(enter_confirm.get("entered_confirm", false)), "preflight fixture should reach S2 confirm")
	var revision_before := owner.get_revision()
	var rejected: Dictionary = owner.confirm_modal_from_runtime_state(
		missing_finish_runtime,
		null,
		null,
		{
			"outcome": 0.0,
			"magnitude": [0.0, 0.0],
			"lane_selection": [0.0, 0.0],
			"delete": 0.0,
			"byproduct_count": 0.0,
			"byproduct_selection": [0.0, 0.0],
		}
	)
	_expect(
		not bool(rejected.get("accepted", true))
		and str(rejected.get("blocked_reason", "")) == "missing_choice_finish",
		"missing common choice-finish dependency should reject before S2 commit"
	)
	_expect(owner.get_revision() == revision_before, "failed preflight must not advance fusion revision")
	_expect((owner.get_snapshot().get("records", []) as Array).is_empty(), "failed preflight must not persist a fusion record")
	_expect(str(flow.get_phase()) == "confirm", "failed preflight should leave the retryable confirm state intact")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
