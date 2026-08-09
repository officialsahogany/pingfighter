extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkFusionRuntimeState := preload("res://scripts/characters/runtime_perk_fusion_runtime_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_owner_state_and_facade()
	_verify_offer_transaction()
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
		runtime_source.find("var _fusion_runtime_state: Object = RuntimePerkFusionRuntimeState.new()") >= 0,
		"runtime facade should construct one fusion runtime-state owner"
	)
	for removed_field: String in [
		"var _perk_fusion_state:",
		"var _perk_fusion_byproduct_runtime:",
		"var _perk_fusion_offer_planner:",
	]:
		_expect(runtime_source.find(removed_field) < 0, "runtime facade should not retain %s" % removed_field)
	_expect(
		owner_source.find("func get_fusion_state(") >= 0
		and owner_source.find("func try_inject_offer_from_runtime_state(") >= 0
		and owner_source.find("func begin_modal_from_runtime_state(") >= 0
		and owner_source.find("func confirm_modal_from_runtime_state(") >= 0
		and owner_source.find("func consume_wall_bounce_gold_award(") >= 0
		and owner_source.find("func reset(") >= 0,
		"fusion owner should contain state, offer, modal, byproduct, and reset responsibilities"
	)
	_expect(
		runtime_source.find("var _perk_fusion_modal_flow: Object:") >= 0
		and runtime_source.find("return _fusion_runtime_state.peek_modal_flow()") >= 0
		and runtime_source.find("_fusion_runtime_state.set_modal_flow(value)") >= 0
		and runtime_source.find("var _perk_fusion_modal_input: Object:") >= 0
		and runtime_source.find("return _fusion_runtime_state.peek_modal_input()") >= 0
		and runtime_source.find("var _perk_fusion_modal_catalog: Object:") >= 0
		and runtime_source.find("return _fusion_runtime_state.get_modal_catalog()") >= 0,
		"legacy modal seams should be owner-backed compatibility properties"
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
		_function_body(runtime_source, "func _try_inject_perk_fusion_offer(").find("randf()") < 0
		and _function_body(runtime_source, "func _confirm_perk_fusion_modal(").find("commit_perk_fusion") < 0
		and _function_body(runtime_source, "func _build_perk_fusion_commit_result(").find("randf()") < 0
		and _function_body(runtime_source, "func _finish_perk_fusion_modal(").find("_finish_successful_choice") < 0,
		"runtime wrappers should not retain owner transaction logic"
	)


func _verify_owner_state_and_facade() -> void:
	var owner := RuntimePerkFusionRuntimeState.new()
	var catalog := RuntimePerkCatalog.new()
	var levels := {"item_luck": 5, "common_bulk_up": 5}
	var record: Dictionary = owner.commit_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "side_effect", "option_penalties": {}},
		catalog,
		levels
	)
	_expect(not record.is_empty(), "owner should commit two valid sources through canonical fusion state")
	_expect(owner.get_revision() == 1, "owner commit should advance the canonical revision once")
	_expect(owner.get_slot_reduction() == 1, "owner should expose canonical slot reduction")
	_expect(
		(owner.get_snapshot().get("records", []) as Array).size() == 1,
		"owner snapshot should expose the committed record"
	)
	var revision_before_reset := owner.get_revision()
	owner.reset()
	_expect(owner.get_revision() == revision_before_reset + 1, "owner reset should advance revision exactly once")
	_expect((owner.get_snapshot().get("records", []) as Array).is_empty(), "owner reset should clear fusion records")

	var runtime := RuntimePerkState.new()
	_expect(runtime._perk_fusion_modal_flow == null and runtime._perk_fusion_modal_input == null, "fresh facade should keep modal helpers lazy")
	var modal_flow: Object = runtime._get_perk_fusion_modal_flow()
	var modal_input: Object = runtime._get_perk_fusion_modal_input()
	_expect(modal_flow != null and runtime._perk_fusion_modal_flow == modal_flow, "modal flow should resolve the owner-held lazy instance")
	_expect(modal_input != null and runtime._perk_fusion_modal_input == modal_input, "modal input should resolve the owner-held lazy instance")
	runtime.runtime_skill_levels["item_luck"] = 5
	var context: Dictionary = runtime._build_perk_fusion_result_context(["item_luck"], catalog)
	_expect(
		(context.get("limit_break_eligible_sources", []) as Array).has("item_luck"),
		"facade should delegate production result-context calculation"
	)
	seed(77331)
	var expected_next_roll := randf()
	seed(77331)
	runtime.queue_perk_fusion_player_point_lost(true)
	_expect(is_equal_approx(randf(), expected_next_roll), "match-finished cleanup should not consume gameplay RNG")


func _verify_offer_transaction() -> void:
	var owner := RuntimePerkFusionRuntimeState.new()
	var runtime := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	runtime.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	runtime.current_choices = [
		{"id": "ordinary", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "reserved", "offer_lane": "owned_upgrade_reserved", "offer_protected": true},
		{"id": "ordinary_2", "offer_lane": "replaceable", "offer_protected": false},
	]
	runtime.current_choice_context = {"source": "plaza_academy"}
	owner.set_test_offer_roll_override(0.0, 0.0)
	var denied: Dictionary = owner.try_inject_offer_from_runtime_state(runtime, catalog)
	_expect(not bool(denied.get("rolled", true)), "ineligible offer source should fail closed")
	_expect(not owner.get_test_offer_roll_override().is_empty(), "fail-closed offer should preserve deterministic rolls")
	runtime.current_choice_context = {"source": "battle_starpoint"}
	var injected: Dictionary = owner.try_inject_offer_from_runtime_state(runtime, catalog)
	_expect(bool(injected.get("appeared", false)), "eligible forced-zero fusion offer should appear")
	_expect(str((runtime.current_choices[0] as Dictionary).get("id", "")) == "perk_fusion", "owner should apply planned replacement")
	_expect(owner.get_test_offer_roll_override().is_empty(), "eligible injection should consume deterministic rolls once")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
