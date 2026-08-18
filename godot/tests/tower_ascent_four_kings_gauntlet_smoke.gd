extends SceneTree

const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentGauntletState := preload(
	"res://scripts/tower_ascent/tower_ascent_gauntlet_state.gd"
)

var _failures: Array[String] = []
var _transition_calls := 0
var _last_transition_plan: Dictionary = {}


class FakeRuntimeState:
	extends RefCounted
	var pause_calls := 0
	var resume_calls := 0
	var arm_calls := 0
	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass
	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1
	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1
	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		arm_calls += 1


class FakeOwner:
	extends RefCounted
	var current_stage := 11
	var chance_gems_count := 3
	var chance_gems_max := 3
	var redraws := 0
	func request_battle_redraw() -> void:
		redraws += 1


class FakeRegistry:
	extends RefCounted
	var runtime := FakeRuntimeState.new()
	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime
		return null
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_state_contract()
	_verify_flow_snapshot_and_transition()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_four_kings_gauntlet_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_state_contract() -> void:
	var state := TowerAscentGauntletState.new()
	var sequence := _registered_sequence()
	_expect(sequence.size() == 4, "fixture should use all four registered Phase-B stand-ins")
	_expect(bool(state.start("node-11:gauntlet", sequence).get("accepted", false)), "four registered encounters should start")
	for completed_index in range(3):
		var victory: Dictionary = state.resolve_victory("node-11:encounter:%d:victory" % completed_index)
		_expect(str(victory.get("reason", "")) == "next_encounter", "first three wins should remain inside the node")
		var plan: Dictionary = victory.get("transition_plan", {})
		_expect(bool(plan.get("reset_active_item_cooldowns", false)), "node-internal reset must reset active-item cooldowns")
		_expect(not bool(plan.get("increment_mythic_stage_progress", true)), "node-internal reset must not increment mythic stage progress")
		_expect(plan.get("preserve", []) == ["field_items", "mugong", "chosik", "fx"], "field items, mugong, chosik, and FX must survive")
		_expect(not bool(plan.get("recover_between_encounters", true)), "gauntlet must not heal between matches")
		_expect(int(plan.get("intermediate_chest_count", -1)) == 0, "gauntlet must not create an intermediate chest")
		if completed_index == 0:
			var retry_index := int(state.export_state().get("encounter_index", -1))
			var defeat: Dictionary = state.record_defeat("node-11:encounter:1:defeat:1")
			_expect(int(defeat.get("retry_encounter_index", -1)) == retry_index, "defeat must retry the same encounter")
			_expect(int(state.export_state().get("encounter_index", -1)) == retry_index, "defeat must not rewind to encounter zero")
		_expect(bool(state.acknowledge_transition().get("accepted", false)), "transition should acknowledge before the next match")
	var final: Dictionary = state.resolve_victory("node-11:encounter:3:victory")
	_expect(str(final.get("reason", "")) == "gauntlet_completed", "fourth win should complete the single node")
	var duplicate_final: Dictionary = state.resolve_victory("node-11:encounter:3:victory")
	_expect(bool(duplicate_final.get("accepted", false)) and not bool(duplicate_final.get("changed", true)), "replayed final victory must be idempotent")
	_expect(not final.has("final_chest"), "gauntlet completion must not leak the retired tower chest")
	var reward_hook: Dictionary = final.get("reward_pick_hook", {})
	_expect(int(reward_hook.get("screen_count", 0)) == 1, "gauntlet completion must reserve exactly one reward-pick screen")
	_expect(str(reward_hook.get("source", "")) == "four_kings_completion", "gauntlet reward hook must remain explicit and unwired")
	_expect(str(reward_hook.get("node_resolution_id", "")) == "node-11:gauntlet", "gauntlet reward hook must carry the node resolution identity")
	var context: Dictionary = reward_hook.get("context", {})
	_expect(str(context.get("boss_slot_id", "")) == "floor_11_four_kings_group", "gauntlet reward hook must identify the grouped boss slot")
	_expect(bool(context.get("is_elite", false)) and bool(context.get("is_enraged", false)) and bool(context.get("is_gatekeeper", false)), "gauntlet reward hook must carry the maximum existing risk flags")


func _verify_flow_snapshot_and_transition() -> void:
	_transition_calls = 0
	_last_transition_plan.clear()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "gauntlet-flow",
		"current_stage": 11,
		"map_seed": 41111,
		"registry": registry,
	}), "gauntlet fixture should prepare a generated floor-eleven graph")
	_expect(flow.begin_vertical_slice(owner, Callable(), {"registry": registry}), "gauntlet fixture should commit the prepared match")
	_expect(bool(flow.call("_activate_graph_phase", 1)), "gauntlet fixture must enter the phase-2 graph that owns floor 11")
	var start: Dictionary = flow.begin_floor_eleven_gauntlet("gauntlet-flow:floor11")
	_expect(bool(start.get("accepted", false)), "flow should unlock the registered floor-eleven group")
	_expect(_floor_eleven_group_unlocked(flow.get_graph_nodes()), "Phase-D gauntlet should clear only the group encounter lock")
	var victory: Dictionary = flow.resolve_gauntlet_victory(
		Callable(self, "_record_transition"),
		owner,
		registry,
		"gauntlet-flow:encounter:0:victory"
	)
	_expect(bool(victory.get("accepted", false)), "first encounter victory should open a transition")
	_expect(flow.get_phase_name() == "GAUNTLET_TRANSITION", "between-match transition should physically block battle")
	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "transition boundary should persist encounter_index")
	_expect(int((snapshot.get("gauntlet_state", {}) as Dictionary).get("encounter_index", -1)) == 1, "snapshot should resume at the second encounter")

	var restore_owner := FakeOwner.new()
	var restore_registry := FakeRegistry.new()
	flow = null
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(
		snapshot,
		Callable(),
		restore_owner,
		restore_registry,
		Callable(self, "_record_transition")
	), "crash resume should restore the pending gauntlet transition")
	_expect(int(restored.get_gauntlet_state_snapshot().get("encounter_index", -1)) == 1, "restored flow must not restart the gauntlet")
	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	_expect(restored.handle_input(confirm), "transition should consume confirm")
	_expect(_transition_calls == 1, "transition should execute exactly one node-internal reset callback")
	_expect(bool(_last_transition_plan.get("reset_active_item_cooldowns", false)), "executed reset plan should include active cooldown reset")
	_expect(not bool(_last_transition_plan.get("increment_mythic_stage_progress", true)), "executed reset plan should skip mythic stage progression")
	_expect(not restored.is_active(), "confirmed transition should return control to combat")
	_expect(restore_registry.runtime.resume_calls == 1 and restore_registry.runtime.arm_calls == 1, "transition close should satisfy GRT-058 lifecycle")


func _registered_sequence() -> Array[Dictionary]:
	var registry := TowerAscentBossRegistry.new()
	var result: Array[Dictionary] = []
	for slot in registry.get_floor_slots(11):
		var slot_id := str(slot.get("slot_id", ""))
		result.append({
			"slot_id": slot_id,
			"display_name": str(slot.get("display_name", "")),
			"standin": registry.get_standin(slot_id),
		})
	return result


func _floor_eleven_group_unlocked(nodes: Array[Dictionary]) -> bool:
	for node in nodes:
		if str(node.get("boss_slot_id", "")) == "floor_11_four_kings_group":
			return not bool(node.get("encounter_locked", true))
	return false


func _record_transition(plan: Dictionary) -> void:
	_transition_calls += 1
	_last_transition_plan = plan.duplicate(true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
