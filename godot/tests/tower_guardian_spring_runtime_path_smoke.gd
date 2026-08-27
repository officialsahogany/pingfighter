extends SceneTree

const BattleSceneInputController := preload(
	"res://scripts/core/battle_scene_input_controller.gd"
)
const BattleSceneModalGateController := preload(
	"res://scripts/core/battle_scene_modal_gate_controller.gd"
)
const BattleSceneOverlayInputController := preload(
	"res://scripts/core/battle_scene_overlay_input_controller.gd"
)
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetUnlockLoadoutReconciler := preload(
	"res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd"
)
const LingpetMainEggOverflowSmoke := preload(
	"res://tests/lingpet_main_egg_overflow_smoke.gd"
)
const LingpetOverflowChoiceOverlayHost := preload(
	"res://scripts/hud/lingpet_overflow_choice_overlay_host.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

var _failures: Array[String] = []


class Registry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class ModuleTable:
	extends RefCounted
	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


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


class TowerFlowBridge:
	extends RefCounted
	var spring: Object = null
	var run_state: Object = null
	var transaction: Object = null
	var resolution_ids: Dictionary = {}
	var owner: Object = null
	var registry: Object = null
	var input_calls := 0
	var discovery_calls: Array[String] = []

	func is_active() -> bool:
		return true

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func handle_input(_event: InputEvent) -> void:
		input_calls += 1

	func has_pending_guardian_spring_browse_compare(pet_id: String = "") -> bool:
		return spring != null and bool(spring.has_pending_browse_compare(pet_id))

	func cancel_guardian_spring_browse_compare() -> Dictionary:
		return spring.cancel_browse_compare()

	func commit_guardian_spring_browse_purchase(
		slot_index: int,
		commit_owner: Object = null,
		commit_registry: Object = null
	) -> Dictionary:
		return spring.commit_browse_purchase(
			slot_index,
			run_state,
			resolution_ids,
			transaction,
			commit_owner if commit_owner != null else owner,
			commit_registry if commit_registry != null else registry
		)

	func record_guardian_identity_reveal(
		pet_id: String,
		_registry: Object = null
	) -> Dictionary:
		discovery_calls.append(pet_id)
		return {
			"accepted": true,
			"handled": true,
			"tower_sealed": false,
			"pet_id": pet_id,
		}


func _initialize() -> void:
	_verify_actual_runtime_and_input_route()
	_verify_first_pick_cutin_input_route()
	_verify_single_candidate_level_one_rolls()
	call_deferred("_finish_after_resource_release")


func _finish_after_resource_release() -> void:
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("tower_guardian_spring_runtime_path_smoke: INPUT_DELEGATION_CONFIRM_CANCEL_OK")
		print("tower_guardian_spring_runtime_path_smoke: ACTUAL_RUNTIME_REPLACE_ROLLBACK_OK")
		print("tower_guardian_spring_runtime_path_smoke: ACQUIRE_CUTIN_DISMISS_OK")
		print("tower_guardian_spring_runtime_path_smoke: FIRST_PICK_LOADOUT_OK")
		print("tower_guardian_spring_runtime_path_smoke: FIRST_PICK_SINGLE_CANDIDATE_OK")
		print("tower_guardian_spring_runtime_path_smoke: FIRST_PICK_LEVEL_ONE_OK")
		print("tower_guardian_spring_runtime_path_smoke: FIRST_PICK_RNG_ISOLATION_OK")
		print("tower_guardian_spring_runtime_path_smoke: BROWSE_LOADOUT_CONTROL_OK")
		print("tower_guardian_spring_runtime_path_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_first_pick_cutin_input_route() -> void:
	var owner := LingpetMainEggOverflowSmoke.FakeOwner.new()
	var runtime := LingpetEggRuntime.new()
	var spring := TowerAscentGuardianSpringNode.new()
	var run_state := TowerAscentRunState.new()
	var transaction := TowerAscentNodeActionTransaction.new()
	var registry := Registry.new()
	var flow := TowerFlowBridge.new()
	var modal_gate := BattleSceneModalGateController.new()
	var overlay_input := BattleSceneOverlayInputController.new()
	var input_controller := BattleSceneInputController.new()
	var modules := ModuleTable.new()
	registry.instances = {
		"lingpet_egg_runtime": runtime,
		"tower_ascent_flow_owner": flow,
	}
	modules.modules = {
		"battle_scene_modal_gate_controller": modal_gate,
		"battle_scene_overlay_input_controller": overlay_input,
		"lingpet_egg_runtime": runtime,
	}
	flow.spring = spring
	flow.run_state = run_state
	flow.transaction = transaction
	flow.owner = owner
	flow.registry = registry
	var duration_rng := RandomNumberGenerator.new()
	duration_rng.seed = 7301
	runtime.set_duration_roll_rng_for_tests(duration_rng)
	_expect(run_state.begin("spring-first-pick-path", {"gold": 0, "muhon": 0}), "first-pick run must start")
	spring.restore_state({"soul_summoning_owned": true})
	var actions := spring.build_actions("spring-first-pick", 91281, run_state, owner, registry)
	var first_pick := _find_operation(actions, "first_pick")
	var selected_pet_id := str(first_pick.get("payload", {}).get("pet_id", ""))
	seed(92041)
	var expected_global_first := randi()
	var expected_global_second := randi()
	seed(92041)
	var observed_global_first := randi()
	var result := spring.execute_action(
		str(first_pick.get("id", "")),
		"spring-first-pick:commit",
		"spring-first-pick",
		91281,
		run_state,
		flow.resolution_ids,
		transaction,
		owner,
		registry
	)
	var observed_global_second := randi()
	_expect(bool(result.get("applied", false)), "first pick must commit through real Lingpet runtime")
	var first_pick_loadout := _runtime_loadout(runtime, selected_pet_id)
	_expect_first_pick_loadout_contract(first_pick_loadout, "first-pick real runtime")
	var active_candidates: Array[String] = (
		LingpetUnlockLoadoutReconciler.new().get_active_unlock_candidate_ids(selected_pet_id)
	)
	_expect(
		active_candidates.has(str(first_pick_loadout.get("active_skill_id", ""))),
		"first pick must choose its active skill from the reconciler's first raw candidates"
	)
	_expect(
		_passive_pool_ids(selected_pet_id).has(str(first_pick_loadout.get("passive_skill_id", ""))),
		"first pick must choose its passive skill from the shared catalog pool"
	)
	_expect(
		observed_global_first == expected_global_first
		and observed_global_second == expected_global_second,
		"first-pick loadout roll must not advance the global gameplay RNG stream"
	)
	_expect(
		str(runtime.get_snapshot().get("cutin_pet_id", "")) == selected_pet_id,
		"first-pick cut-in must display the selected guardian"
	)
	runtime.advance_acquire_cutin(10.0, registry)
	var module_getter := Callable(modules, "get_module")
	_dispatch_key(input_controller, KEY_ENTER, owner, registry, module_getter)
	_expect(runtime.is_acquire_cutin_dismissing(), "Tower-active input must dismiss first-pick cut-in")
	_expect(flow.input_calls == 0, "Tower flow must not swallow first-pick cut-in input")
	runtime.reset_for_tests()
	registry.instances.clear()
	modules.modules.clear()
	flow.spring = null
	flow.run_state = null
	flow.transaction = null
	flow.owner = null
	flow.registry = null


func _verify_actual_runtime_and_input_route() -> void:
	var owner := LingpetMainEggOverflowSmoke.FakeOwner.new()
	var runtime := LingpetEggRuntime.new()
	var spring := TowerAscentGuardianSpringNode.new()
	var run_state := TowerAscentRunState.new()
	var transaction := TowerAscentNodeActionTransaction.new()
	var registry := Registry.new()
	var flow := TowerFlowBridge.new()
	var overflow_host := LingpetOverflowChoiceOverlayHost.new()
	var modal_gate := BattleSceneModalGateController.new()
	var overlay_input := BattleSceneOverlayInputController.new()
	var input_controller := BattleSceneInputController.new()
	var modules := ModuleTable.new()
	registry.instances = {
		"lingpet_egg_runtime": runtime,
		"lingpet_overflow_choice_overlay_host": overflow_host,
		"tower_ascent_flow_owner": flow,
	}
	modules.modules = {
		"battle_scene_modal_gate_controller": modal_gate,
		"battle_scene_overlay_input_controller": overlay_input,
		"lingpet_egg_runtime": runtime,
	}
	flow.spring = spring
	flow.run_state = run_state
	flow.transaction = transaction
	flow.owner = owner
	flow.registry = registry
	_expect(run_state.begin("spring-runtime-path", {"gold": 4000, "muhon": 10}), "real-path run must start")
	run_state.reveal_floor(5)
	_expect(
		runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry),
		"real Lingpet runtime must start with Maribo active"
	)
	spring.restore_state({
		"soul_summoning_owned": true,
		"first_pick_completed": true,
		"active_guardian": {"pet_id": "maribo", "display_name": "마리보"},
	})
	_seed_old_companion_skill_state(runtime, owner, registry, "maribo")

	var actions := spring.build_actions("spring-runtime", 88051, run_state, owner, registry)
	var browse_action := _find_operation(actions, "browse")
	_expect(not browse_action.is_empty(), "active Spring menu must expose browse")
	var browse_result := spring.execute_action(
		str(browse_action.get("id", "")),
		"spring-runtime:browse:1",
		"spring-runtime",
		88051,
		run_state,
		flow.resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(bool(browse_result.get("applied", false)), "browse must build real elite offers")
	actions = spring.build_actions("spring-runtime", 88051, run_state, owner, registry)
	_expect(actions.size() == 4, "elite screen must keep three offers plus an explicit reroll card")
	_expect(not _find_operation(actions, "browse").is_empty(), "elite screen reroll card must be executable")
	var candidate := _find_operation(actions, "browse_candidate")
	var offer: Dictionary = candidate.get("payload", {}).get("offer", {}) as Dictionary
	_expect(not offer.is_empty(), "real-path seal requires an elite offer")
	var compare_result := spring.execute_action(
		str(candidate.get("id", "")),
		"spring-runtime:compare:1",
		"spring-runtime",
		88051,
		run_state,
		flow.resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(str(compare_result.get("reason", "")) == "compare_opened", "candidate must open actual overflow compare")
	_expect(runtime.is_overflow_choice_active(), "actual runtime overflow state must be active")
	_expect(flow.discovery_calls.is_empty(), "viewing a comparison must not record first_seen")

	var rollback_before := runtime.build_tower_spring_replace_rollback_snapshot()
	var reject_result := spring.commit_browse_purchase(
		0,
		RejectingEconomy.new(),
		{},
		transaction,
		owner,
		registry
	)
	_expect(not bool(reject_result.get("accepted", false)), "forced economy failure must reject")
	_expect(spring.has_pending_browse_compare(), "rollback must restore the pending comparison")
	_expect(runtime.is_overflow_choice_active(), "rollback must reopen actual overflow compare")
	_expect(
		not runtime.is_acquire_cutin_active(),
		"rollback must clear the uncommitted purchase cut-in"
	)
	_expect(
		runtime.build_tower_spring_replace_rollback_snapshot() == rollback_before,
		"rollback must restore runtime, loadout, run data, and companion-skill persistence"
	)

	var module_getter := Callable(modules, "get_module")
	_dispatch_key(input_controller, KEY_ENTER, owner, registry, module_getter)
	_expect(
		overflow_host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_CONFIRM,
		"Tower-active Enter must reach actual overlay compare and open confirmation"
	)
	_expect(flow.input_calls == 0, "Tower flow must not swallow comparison confirmation input")
	_dispatch_key(input_controller, KEY_ENTER, owner, registry, module_getter)
	var new_pet_id := str(offer.get("pet_id", ""))
	var committed_snapshot: Dictionary = runtime.build_save_snapshot()
	_expect(str(committed_snapshot.get("pet_id", "")) == new_pet_id, "actual replacement must activate offered guardian")
	_expect_nonempty_loadout_contract(
		_loadout_from_snapshot(committed_snapshot, new_pet_id),
		"paid browse replacement control"
	)
	_expect(
		_loadout_contract(committed_snapshot, new_pet_id) == _loadout_contract_from_offer(offer),
		"committed real runtime loadout must equal the deterministic offer"
	)
	_expect(_old_guardian_forgotten(runtime, committed_snapshot, "maribo"), "replacement must forget all three old-guardian stores")
	_expect(flow.discovery_calls == [new_pet_id], "first_seen must record exactly once on purchase commit")
	_expect(not runtime.is_overflow_choice_active(), "confirmed replacement must clear overflow state")

	var cutin_snapshot: Dictionary = runtime.get_snapshot()
	_expect(
		str(cutin_snapshot.get("cutin_pet_id", "")) == new_pet_id,
		"purchase acquire cut-in must display the purchased guardian"
	)
	runtime.advance_acquire_cutin(10.0, registry)
	_expect(runtime.is_acquire_cutin_awaiting_dismiss(), "purchase cut-in must reach input-waiting hold")
	_dispatch_key(input_controller, KEY_ENTER, owner, registry, module_getter)
	_expect(runtime.is_acquire_cutin_dismissing(), "Tower-active Enter must dismiss purchase cut-in through overlay input")
	_expect(flow.input_calls == 0, "Tower flow must not swallow acquire cut-in input")
	runtime.advance_acquire_cutin(10.0, registry)
	_expect(not runtime.is_acquire_cutin_active(), "dismiss animation must finish")

	actions = spring.build_actions("spring-runtime", 88051, run_state, owner, registry)
	browse_action = _find_operation(actions, "browse")
	browse_result = spring.execute_action(
		str(browse_action.get("id", "")),
		"spring-runtime:browse:2",
		"spring-runtime",
		88051,
		run_state,
		flow.resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(bool(browse_result.get("applied", false)), "second browse must open cancel fixture")
	actions = spring.build_actions("spring-runtime", 88051, run_state, owner, registry)
	candidate = _find_operation(actions, "browse_candidate")
	compare_result = spring.execute_action(
		str(candidate.get("id", "")),
		"spring-runtime:compare:2",
		"spring-runtime",
		88051,
		run_state,
		flow.resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(str(compare_result.get("reason", "")) == "compare_opened", "second candidate must open cancel fixture")
	_dispatch_key(input_controller, KEY_ESCAPE, owner, registry, module_getter)
	_expect(not spring.has_pending_browse_compare(), "Tower-active ESC must clear Spring pending compare")
	_expect(not runtime.is_overflow_choice_active(), "Tower-active ESC must clear runtime overflow gate")
	_expect(
		not modal_gate.is_lingpet_overflow_choice_active(module_getter),
		"next battle gate evaluation must not see a stale comparison"
	)
	_expect(flow.input_calls == 0, "Tower flow must not close its node modal before compare cancellation")
	runtime.reset_for_tests()
	registry.instances.clear()
	modules.modules.clear()
	flow.spring = null
	flow.run_state = null
	flow.transaction = null
	flow.owner = null
	flow.registry = null


func _verify_single_candidate_level_one_rolls() -> void:
	const PET_ID := "lunabi"
	var active_candidates: Array[String] = (
		LingpetUnlockLoadoutReconciler.new().get_active_unlock_candidate_ids(PET_ID)
	)
	_expect(active_candidates.size() == 1, "Lunabi fixture must expose exactly one active candidate")
	var seen_passive_ids: Dictionary = {}
	for roll_index in range(24):
		var owner := LingpetMainEggOverflowSmoke.FakeOwner.new()
		var runtime := LingpetEggRuntime.new()
		var registry := Registry.new()
		var duration_rng := RandomNumberGenerator.new()
		duration_rng.seed = 8100 + roll_index
		runtime.set_duration_roll_rng_for_tests(duration_rng)
		var accepted := runtime.grant_and_activate_tower_spring_guardian(
			PET_ID,
			owner,
			registry,
			30000 + roll_index
		)
		_expect(accepted, "single-candidate first-pick fixture must grant through real runtime")
		var loadout := _runtime_loadout(runtime, PET_ID)
		_expect_first_pick_loadout_contract(loadout, "single-candidate seed %d" % roll_index)
		_expect(
			str(loadout.get("active_skill_id", "")) == str(active_candidates[0]),
			"single active candidate must be selected without assuming a two-entry pool"
		)
		seen_passive_ids[str(loadout.get("passive_skill_id", ""))] = true
		runtime.reset_for_tests()
	_expect(seen_passive_ids.size() > 1, "repeated private seeds must vary the random shared passive pick")


func _seed_old_companion_skill_state(
	runtime: Object,
	owner: Object,
	registry: Object,
	pet_id: String
) -> void:
	var snapshot: Dictionary = runtime.build_save_snapshot()
	var restored: bool = bool(runtime.restore_tower_spring_replace_rollback_snapshot({
		"save_snapshot": snapshot,
		"companion_skill_persistence": {
			"state_by_pet_id": {
				pet_id: {
					"trigger_count": 7,
					"slot_0": {"skill_id": "fixture", "cooldown": 4.5},
				},
			},
			"trigger_count": 7,
			"shared_cooldown": 2.5,
			"last_seen_stage": 4,
		},
	}, owner, registry))
	_expect(restored, "companion-skill rollback fixture must seed through the runtime owner")


func _old_guardian_forgotten(runtime: Object, snapshot: Dictionary, pet_id: String) -> bool:
	var loadouts: Dictionary = snapshot.get("lingpet_loadouts", {}) as Dictionary
	var guardian_run: Dictionary = snapshot.get("guardian_run_state", {}) as Dictionary
	var pets: Dictionary = guardian_run.get("pets", {}) as Dictionary
	var rollback_snapshot: Dictionary = runtime.build_tower_spring_replace_rollback_snapshot()
	var persistence: Dictionary = rollback_snapshot.get("companion_skill_persistence", {}) as Dictionary
	var state_by_pet_id: Dictionary = persistence.get("state_by_pet_id", {}) as Dictionary
	return not loadouts.has(pet_id) and not pets.has(pet_id) and not state_by_pet_id.has(pet_id)


func _loadout_contract(snapshot: Dictionary, pet_id: String) -> Dictionary:
	var loadouts: Dictionary = snapshot.get("lingpet_loadouts", {}) as Dictionary
	return _normalize_loadout(loadouts.get(pet_id, {}) as Dictionary)


func _loadout_contract_from_offer(offer: Dictionary) -> Dictionary:
	return _normalize_loadout(offer.get("loadout", {}) as Dictionary)


func _runtime_loadout(runtime: Object, pet_id: String) -> Dictionary:
	return _loadout_from_snapshot(runtime.get_snapshot(), pet_id)


func _loadout_from_snapshot(snapshot: Dictionary, pet_id: String) -> Dictionary:
	var loadouts: Dictionary = snapshot.get("lingpet_loadouts", {}) as Dictionary
	var loadout_value: Variant = loadouts.get(pet_id, {})
	return (loadout_value as Dictionary).duplicate(true) if loadout_value is Dictionary else {}


func _expect_first_pick_loadout_contract(loadout: Dictionary, label: String) -> void:
	var active_ids: Array = loadout.get("active_skill_ids", []) as Array
	var passive_ids: Array = loadout.get("passive_skill_ids", []) as Array
	var active_slot_count := int(loadout.get("active_slot_count", 0))
	var passive_slot_count := int(loadout.get("passive_slot_count", 0))
	var active_level := int(loadout.get("active_skill_level", 0))
	var passive_level := int(loadout.get("passive_skill_level", 0))
	_expect(active_ids.size() == 1, "%s must store exactly one active skill; actual=%d" % [label, active_ids.size()])
	_expect(passive_ids.size() == 1, "%s must store exactly one passive skill; actual=%d" % [label, passive_ids.size()])
	_expect(active_slot_count == 1, "%s must open one active slot; actual=%d" % [label, active_slot_count])
	_expect(passive_slot_count == 1, "%s must open one passive slot; actual=%d" % [label, passive_slot_count])
	_expect(active_level == 1, "%s active skill must always start at Lv.1; actual=%d" % [label, active_level])
	_expect(passive_level == 1, "%s passive skill must always start at Lv.1; actual=%d" % [label, passive_level])


func _expect_nonempty_loadout_contract(loadout: Dictionary, label: String) -> void:
	var active_ids: Array = loadout.get("active_skill_ids", []) as Array
	var passive_ids: Array = loadout.get("passive_skill_ids", []) as Array
	_expect(not active_ids.is_empty(), "%s must retain at least one active skill" % label)
	_expect(not passive_ids.is_empty(), "%s must retain at least one passive skill" % label)
	_expect(int(loadout.get("active_slot_count", 0)) > 0, "%s must retain an active slot" % label)
	_expect(int(loadout.get("passive_slot_count", 0)) > 0, "%s must retain a passive slot" % label)


func _passive_pool_ids(pet_id: String) -> Array[String]:
	var result: Array[String] = []
	for passive in LingpetCatalog.get_passive_skill_pool(pet_id):
		var passive_id := str(passive.get("id", "")).strip_edges()
		if not passive_id.is_empty():
			result.append(passive_id)
	return result


func _normalize_loadout(loadout: Dictionary) -> Dictionary:
	var result := {}
	for key in [
		"active_skill_id",
		"passive_skill_id",
		"active_skill_level",
		"passive_skill_level",
		"second_active_skill_id",
		"second_passive_skill_id",
		"second_active_skill_level",
		"second_passive_skill_level",
	]:
		result[key] = loadout.get(key, "" if str(key).ends_with("_id") else 0)
	return result


func _find_operation(actions: Array, operation: String) -> Dictionary:
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		var payload: Dictionary = action.get("payload", {}) as Dictionary
		if str(payload.get("operation", "")) == operation:
			return action
	return {}


func _dispatch_key(
	controller: Object,
	keycode: int,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	controller.handle_unhandled_input(event, owner, registry, module_getter, {})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
