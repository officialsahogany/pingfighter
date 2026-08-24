extends SceneTree

const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerGuardianSpringOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_guardian_spring_offer_builder.gd"
)
const LingpetOverflowChoiceOverlayHost := preload(
	"res://scripts/hud/lingpet_overflow_choice_overlay_host.gd"
)
const LingpetOverflowChoiceState := preload(
	"res://scripts/lingpet/lingpet_overflow_choice_state.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var tower_ascent_prayer_count := 0
	var tower_ascent_prayer_locked := false
	var tower_ascent_soul_summoning_owned := true
	var tower_ascent_sealed_guardians: Array = []

	func set_tower_ascent_guardian_projection(
		sealed_guardians: Array,
		soul_summoning_owned: bool
	) -> void:
		tower_ascent_sealed_guardians = sealed_guardians.duplicate(true)
		tower_ascent_soul_summoning_owned = soul_summoning_owned

	func set_tower_ascent_prayer_projection(count: int, locked: bool) -> void:
		tower_ascent_prayer_count = count
		tower_ascent_prayer_locked = locked


class FakeLingpetRuntime:
	extends RefCounted
	var snapshot := {
		"state": "none",
		"pet_id": "",
		"owned_pet_ids": [],
		"guardian_run_state": {"pets": {}},
	}
	var pending_offer: Dictionary = {}
	var grant_calls := 0
	var replace_calls := 0
	var old_pet_forgotten := false

	func build_save_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func apply_save_snapshot(
		value: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		snapshot = value.duplicate(true)
		return {"restored": true}

	func grant_and_activate_tower_spring_guardian(
		pet_id: String,
		_owner: Object = null,
		_registry: Object = null
	) -> bool:
		if str(snapshot.get("state", "")) == "companion":
			return false
		grant_calls += 1
		snapshot = {
			"state": "companion",
			"pet_id": pet_id,
			"owned_pet_ids": [pet_id],
			"guardian_run_state": {"pets": {pet_id: {}}},
		}
		return true

	func build_guardian_enhance_live_candidates(_owner: Object = null) -> Array:
		return [{"type": "mobility"}]

	func begin_tower_spring_overflow_compare(
		offer: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> bool:
		pending_offer = offer.duplicate(true)
		return not pending_offer.is_empty()

	func commit_tower_spring_overflow_replace(
		_slot_index: int,
		offer: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> bool:
		var old_pet_id := str(snapshot.get("pet_id", ""))
		var new_pet_id := str(offer.get("pet_id", ""))
		if new_pet_id == "" or old_pet_id == "":
			return false
		replace_calls += 1
		old_pet_forgotten = old_pet_id != new_pet_id
		snapshot["pet_id"] = new_pet_id
		snapshot["owned_pet_ids"] = [new_pet_id]
		pending_offer.clear()
		return true


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class RejectingEconomy:
	extends RefCounted
	var prayer_count := 2
	var prayer_locked := true

	func can_afford(_costs: Dictionary) -> Dictionary:
		return {"accepted": true, "balances": {"gold": 9999, "muhon": 0}}

	func apply_economy_transaction(_costs: Dictionary, _rewards: Dictionary) -> Dictionary:
		return {"accepted": false, "reason": "forced_economy_failure"}

	func get_prayer_count() -> int:
		return prayer_count

	func is_guardian_prayer_locked() -> bool:
		return prayer_locked

	func restore_guardian_prayer_state(count: int, locked: bool) -> void:
		prayer_count = count
		prayer_locked = locked


func _init() -> void:
	_verify_deterministic_candidate_and_elite_contracts()
	_verify_first_pick_browse_compare_purchase_and_rollback()
	_verify_existing_compare_modal_and_forget_hooks()
	if _failures.is_empty():
		print("tower_guardian_spring_stage3_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_deterministic_candidate_and_elite_contracts() -> void:
	var builder := TowerGuardianSpringOfferBuilder.new()
	_expect(builder.price_for_roll_count(0) == 80 and builder.price_for_roll_count(5) == 280, "browse price must derive from the actually applied roll count")
	var first_a := builder.build_first_pick_candidates(7721, "spring-07")
	var first_b := builder.build_first_pick_candidates(7721, "spring-07")
	_expect(first_a == first_b, "first-pick seed must reproduce the same candidates")
	_expect(first_a.size() == 3 and _unique_pet_count(first_a) == 3, "first pick must expose three unique guardians")
	var browse_a := builder.build_browse_offers(7721, "spring-07", 1, 5)
	var browse_b := builder.build_browse_offers(7721, "spring-07", 1, 5)
	var browse_next := builder.build_browse_offers(7721, "spring-07", 2, 5)
	_expect(browse_a == browse_b, "browse seed and sequence must reproduce the same offers")
	_expect(browse_a != browse_next, "a new browse sequence must produce a different deterministic offer set")
	_expect(browse_a.size() == 3 and _unique_pet_count(browse_a) == 3, "browse must expose three unique elite guardians")
	for floor_and_price in [[0, 1, 120], [5, 5, 280], [99, 10, 480]]:
		var offers := builder.build_browse_offers(
			9001,
			"spring-price",
			int(floor_and_price[1]),
			int(floor_and_price[0])
		)
		for offer in offers:
			_expect(int(offer.get("applied_roll_count", -1)) == int(floor_and_price[1]), "browse roll count must clamp the current floor to 1..10")
			_expect(int(offer.get("price_gold", -1)) == int(floor_and_price[2]), "browse price must be 80 + 40 times applied rolls")
	var found_second_slot := false
	for seed_value in range(9100, 9120):
		for offer in builder.build_browse_offers(seed_value, "spring-slot", 1, 10):
			var counts: Dictionary = offer.get("reward_counts", {}) as Dictionary
			var loadout: Dictionary = offer.get("loadout", {}) as Dictionary
			if (
				bool(counts.get("second_active_unlocked", false))
				and str(loadout.get("second_active_skill_id", "")) != ""
			) or (
				bool(counts.get("second_passive_unlocked", false))
				and str(loadout.get("second_passive_skill_id", "")) != ""
			):
				found_second_slot = true
	_expect(found_second_slot, "elite rolls must preserve the existing second-slot unlock vocabulary and deterministic skill identity")


func _verify_first_pick_browse_compare_purchase_and_rollback() -> void:
	var spring := TowerAscentGuardianSpringNode.new()
	spring.restore_state({"soul_summoning_owned": true})
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {"lingpet_egg_runtime": runtime}
	var owner := FakeOwner.new()
	var run_state := TowerAscentRunState.new()
	_expect(run_state.begin("spring-s3", {"gold": 2000, "muhon": 10}), "S3 run must start")
	run_state.reveal_floor(5)
	var transaction := TowerAscentNodeActionTransaction.new()
	var resolution_ids := {}
	var actions := spring.build_actions("spring-05", 5005, run_state, owner, registry)
	_expect(actions.size() == 3, "palm completion must reveal three first-pick cards")
	for action in actions:
		var choice: Dictionary = action.get("payload", {}).get("choice", {}) as Dictionary
		_expect(bool(choice.get("guardian_blind_preview", false)), "first-pick cards must be blind previews")
		_expect(bool(choice.get("hide_skill_details", false)) and bool(choice.get("hide_numeric_details", false)), "blind previews must hide skill and numeric details")
		_expect(not str(choice.get("name", "")).is_empty() and not str(choice.get("guardian_portrait_path", "")).is_empty(), "blind previews must keep cut-in art and name")
	var pick_result := spring.execute_action(
		str(actions[0].get("id", "")),
		"spring-s3:first-pick",
		"spring-05",
		5005,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(bool(pick_result.get("applied", false)) and runtime.grant_calls == 1, "first pick must grant and activate exactly one guardian")
	_expect(run_state.is_guardian_prayer_locked(), "first guardian acquisition must permanently lock prayer")
	_expect(int(run_state.export_economy().get("gold", -1)) == 2000, "first guardian acquisition must remain free")
	var replay_result := spring.execute_action(
		str(actions[0].get("id", "")),
		"spring-s3:first-pick",
		"spring-05",
		5005,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(str(replay_result.get("reason", "")) == "already_committed" and runtime.grant_calls == 1, "first-pick resolution must be one-time and replay-safe")
	actions = spring.build_actions("spring-05", 5005, run_state, owner, registry)
	var browse_action := _find_action_with_prefix(actions, "guardian_spring:browse:")
	_expect(not browse_action.is_empty(), "guardian menu must expose browse after acquisition")
	var browse_result := spring.execute_action(
		str(browse_action.get("id", "")),
		"spring-s3:browse:1",
		"spring-05",
		5005,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(bool(browse_result.get("applied", false)), "browse must commit its deterministic reroll sequence")
	actions = spring.build_actions("spring-05", 5005, run_state, owner, registry)
	_expect(actions.size() == 3, "browse must replace the menu with three elite cards")
	for action in actions:
		_expect(str(action.get("cost_text", "")).contains("280"), "floor-five elite cards must display 280 Gold")
		_expect(bool(action.get("payload", {}).get("choice", {}).get("guardian_full_preview", false)), "elite cards must expose full preview data")
	var compare_result := spring.execute_action(
		str(actions[0].get("id", "")),
		"spring-s3:compare-open",
		"spring-05",
		5005,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(str(compare_result.get("reason", "")) == "compare_opened" and spring.has_pending_browse_compare(), "elite click must open the inherited overflow comparison")
	var old_pet_id := str(runtime.snapshot.get("pet_id", ""))
	var reject_result := spring.commit_browse_purchase(
		0,
		RejectingEconomy.new(),
		{},
		transaction,
		owner,
		registry
	)
	_expect(not bool(reject_result.get("accepted", false)), "failed economy commit must reject the browse purchase")
	_expect(str(runtime.snapshot.get("pet_id", "")) == old_pet_id, "failed economy commit must roll the active guardian back")
	_expect(spring.has_pending_browse_compare(), "failed economy commit must restore the pending comparison")
	var commit_result := spring.commit_browse_purchase(
		0,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(bool(commit_result.get("accepted", false)) and bool(commit_result.get("applied", false)), "confirmed browse purchase must commit")
	_expect(int(run_state.export_economy().get("gold", -1)) == 1720, "confirmed floor-five purchase must debit exactly 280 Gold")
	_expect(runtime.replace_calls == 2 and runtime.old_pet_forgotten, "replacement must run once for rollback proof and once for commit while forgetting the old guardian")
	_expect(not spring.has_pending_browse_compare(), "successful purchase must clear the pending comparison")


func _verify_existing_compare_modal_and_forget_hooks() -> void:
	var choice_state := LingpetOverflowChoiceState.new()
	choice_state.begin_main_overflow("lunabi", false, true)
	choice_state.activate_after_cutin()
	var compare_snapshot: Dictionary = choice_state.build_snapshot(null)
	var compare_host := LingpetOverflowChoiceOverlayHost.new()
	compare_host.call("_sync_modal_identity", compare_snapshot)
	_expect(bool(compare_snapshot.get("compare_only", false)) and compare_host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_COMPARE, "spring browse must open directly in the inherited comparison phase")
	var overlay_source := FileAccess.get_file_as_string(
		"res://scripts/hud/lingpet_overflow_choice_overlay_host.gd"
	)
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var priority_router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_lingpet_priority_input_router.gd"
	)
	var modal_gate_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_modal_gate_controller.gd"
	)
	_expect(overlay_source.contains("PHASE_COMPARE") and overlay_source.contains("commit_overflow_replace(0, owner, registry)"), "browse must inherit the existing compare and confirm modal hooks")
	_expect(runtime_source.contains("begin_main_overflow(pet_id, false, true)") and runtime_source.contains("_overflow_replace_plan.consume"), "Tower browse must route through the existing overflow replacement plan")
	_expect(runtime_source.contains("forget_pet_loadout_and_invalidate(owner, old_pet_id") and runtime_source.contains("_guardian_run_state.forget_pet_data(old_pet_id)"), "replacement must forget the old guardian loadout and run state")
	_expect(priority_router_source.contains("is_lingpet_overflow_choice_active") and priority_router_source.contains("_handle_overflow_choice_input"), "spring compare must inherit the overflow modal priority input route")
	_expect(modal_gate_source.contains("physics.modal_gate.lingpet_overflow_choice") and modal_gate_source.contains("is_overflow_choice_active"), "spring compare must inherit the overflow modal physics block")


func _unique_pet_count(entries: Array) -> int:
	var ids: Dictionary = {}
	for entry in entries:
		if entry is Dictionary:
			ids[str((entry as Dictionary).get("pet_id", ""))] = true
	return ids.size()


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for action in actions:
		if action is Dictionary and str((action as Dictionary).get("id", "")).begins_with(prefix):
			return action as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
