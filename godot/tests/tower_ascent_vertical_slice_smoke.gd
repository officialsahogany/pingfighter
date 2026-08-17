extends SceneTree

const BattleSceneFrameController := preload(
	"res://scripts/core/battle_scene_frame_controller.gd"
)
const BattleSceneInputController := preload(
	"res://scripts/core/battle_scene_input_controller.gd"
)
const BattleSceneMatchFlowDriver := preload(
	"res://scripts/core/battle_scene_match_flow_driver.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)

var _failures: Array[String] = []
var _reset_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var ball_position := Vector2(310.0, 420.0)
	var player_score := 7
	var boss_score := 3
	var cooldown_seconds := 2.5
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeResultScreen:
	extends RefCounted

	var show_calls := 0

	func show_from_scoreboard(
		_owner: Object,
		_registry: Object,
		_reset_callback: Callable,
		_exit_callback: Callable
	) -> bool:
		show_calls += 1
		return true


class FakeScreen:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active

	func blocks_battle_physics() -> bool:
		return active


class FakeReadiness:
	extends RefCounted

	func is_logo_intro_active(_module_getter: Callable) -> bool:
		return false

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return true

	func is_stage_landing_intro_active(_module_getter: Callable) -> bool:
		return false

	func is_ball_spawn_intro_active(_module_getter: Callable) -> bool:
		return false


class FakeTransition:
	extends RefCounted

	func is_stage_transition_loading_active() -> bool:
		return false


class FakeGrip:
	extends RefCounted

	func update(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> bool:
		return false

	func is_active() -> bool:
		return false


class FakeModalGate:
	extends RefCounted

	func should_block_battle_physics_with_perf(
		_module_getter: Callable,
		_perf_logger: Object = null
	) -> bool:
		return false


class FakeModalPause:
	extends RefCounted

	var enter_calls := 0
	var leave_calls := 0

	func enter_modal_block(
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> void:
		enter_calls += 1

	func leave_modal_block(
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> void:
		leave_calls += 1


class FakeTowerModalRuntime:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var instance_reads: Array[String] = []
	var cached_reads: Array[String] = []

	func get_instance(key: String) -> Variant:
		instance_reads.append(key)
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		cached_reads.append(key)
		return instances.get(key, null)


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Variant:
		return modules.get(key, null)


func _init() -> void:
	_verify_flag_off_preserves_legacy_result_flow()
	_verify_match_flow_runs_one_fixed_cycle()
	_verify_snapshot_round_trip_and_required_fields()
	_verify_physics_gate_updates_only_selector_flow()
	_verify_input_controller_routes_modal_confirm()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()

	if _failures.is_empty():
		print("tower_ascent_vertical_slice_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_flag_off_preserves_legacy_result_flow() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var flow := TowerAscentFlowOwner.new()
	var result_screen := FakeResultScreen.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"stage_clear_result_screen": result_screen,
		"runtime_perk_state": FakeTowerModalRuntime.new(),
	}
	var owner := FakeOwner.new()
	BattleSceneMatchFlowDriver.new().call(
		"_finish_victory_loot_phase",
		registry,
		Callable(self, "_on_reset"),
		owner
	)
	_expect(result_screen.show_calls == 1, "flag OFF must preserve the existing result-screen continuation")
	_expect(not flow.is_active(), "flag OFF must not activate the tower flow")
	_expect(
		not registry.instance_reads.has("tower_ascent_flow_owner"),
		"flag OFF must not instantiate the tower flow owner"
	)


func _verify_match_flow_runs_one_fixed_cycle() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var result_screen := FakeResultScreen.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"stage_clear_result_screen": result_screen,
		"runtime_perk_state": FakeTowerModalRuntime.new(),
	}
	var owner := FakeOwner.new()
	var driver := BattleSceneMatchFlowDriver.new()
	driver.call(
		"_finish_victory_loot_phase",
		registry,
		Callable(self, "_on_reset"),
		owner
	)
	_expect(flow.is_active(), "flag ON must enter the tower flow after victory loot")
	_expect(flow.get_phase_name() == "ROUTE_AIM", "the first post-combat state must remain in the battle scene as ROUTE_AIM")
	_expect(result_screen.show_calls == 0, "legacy result screen must wait until the slice completes")
	var initial_snapshot: Dictionary = flow.export_snapshot()
	_expect(initial_snapshot.completed_nodes.size() == 1, "combat resolution must commit exactly once on entry")
	_expect(
		not flow.begin_vertical_slice(owner, Callable(), {"run_id": "duplicate"}),
		"a second begin during the active flow must be rejected"
	)
	_expect(flow.export_snapshot().completed_nodes.size() == 1, "rejected re-entry must not duplicate node rewards")

	flow.debug_launch_miss()
	flow.update_selective(1.5, owner)
	_expect(flow.get_phase_name() == "ROUTE_AIM", "a missed selector shot must remain in ROUTE_AIM")
	_expect(not flow.is_selector_launched(), "a missed selector shot must reset for unlimited retries")
	_expect(flow.get_selector_position().is_equal_approx(flow.get_selector_origin()), "miss reset must restore the selector origin")

	var selected_kind := str(flow.get_route_aim_targets()[0].get("kind", ""))
	flow.debug_launch_at_target(0)
	flow.update_selective(1.5, owner)
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "target hit must commit the route and enter MAP_TRANSITION")
	var committed_snapshot: Dictionary = flow.export_snapshot()
	_expect(committed_snapshot.completed_nodes.size() == 2, "route selection must add one idempotent node resolution")
	_expect(committed_snapshot.run_progress.skipped_boss_ids.size() <= 1, "only an unchosen generated boss slot may be recorded as skipped")
	_expect(bool(committed_snapshot.stable_boundary), "post-commit map transition must be a stable snapshot boundary")
	flow.update_selective(1.0, owner)
	if selected_kind in ["shop", "training", "fallen_monk", "guardian_spring", "rest"]:
		_expect(flow.is_active() and flow.get_phase_name() == "NODE_MODAL", "noncombat node work must begin only after map movement completes")
		_expect(result_screen.show_calls == 0, "arrival at a noncombat node must not leak to the legacy result flow")
		flow.call("_finish_vertical_slice")
	else:
		_expect(not flow.is_active(), "combat-node map arrival must close the vertical-slice owner")
	_expect(result_screen.show_calls == 1, "explicit slice exit must resume the current legacy continuation exactly once")


func _verify_snapshot_round_trip_and_required_fields() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var source := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	var snapshot_context := {
		"run_id": "snapshot-contract",
		"run_state": {"gold": 17, "muhon": 23, "chance_gems": 2},
		"node_reward_bundle": {"gold": 5, "muhon": 2},
	}
	_expect(source.prepare_vertical_slice_combat(owner, snapshot_context), "combat resolution must prepare before reward completion")
	var pending_snapshot: Dictionary = source.export_snapshot()
	_expect(not source.is_active(), "prepared combat resolution must not activate the map over victory loot")
	_expect(pending_snapshot.completed_nodes.is_empty(), "prepared resolution must not mark the combat node complete early")
	_expect(pending_snapshot.pending_rewards.size() == 1, "prepared resolution must carry one node_resolution_id through reward completion")
	var prepared_resolution_id := str(pending_snapshot.pending_rewards[0].node_resolution_id)
	var recovery_journal: Dictionary = source.export_pending_reward_journal()
	_expect(recovery_journal.pending_rewards.size() == 1, "prepared reward must be exported through the separate crash journal")
	_expect(source.begin_vertical_slice(owner, Callable(), snapshot_context), "snapshot fixture must start")
	_expect(source.export_persistable_snapshot().is_empty(), "route serving must remain an unstable snapshot boundary")
	source.debug_launch_at_target(0)
	source.update_selective(1.5, owner)
	_expect(source.get_phase_name() == "MAP_TRANSITION", "snapshot fixture must reach the post-selection stable boundary")
	var snapshot: Dictionary = source.export_snapshot()
	_expect(snapshot.pending_rewards.is_empty(), "completed victory loot must clear the pending reward record")
	_expect(str(snapshot.completed_nodes[0].node_resolution_id) == prepared_resolution_id, "prepare and commit must share the same node_resolution_id")
	var required_keys := [
		"schema_version",
		"map_generator_version",
		"run_id",
		"map_graph",
		"current_node_id",
		"completed_nodes",
		"run_progress",
		"pending_rewards",
		"run_state",
		"generated_shop_inventory",
		"purchase_history",
		"claimed_decoration_ids",
		"build_state",
		"guardian_state",
		"gameplay_rng_state",
	]
	for key in required_keys:
		_expect(snapshot.has(key), "snapshot must include required field: %s" % key)
	_expect(snapshot.run_state == {"gold": 22, "muhon": 25, "chance_gems": 2}, "node transaction must grant the prepared run-local reward exactly once")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "the fixed-graph snapshot must restore")
	var round_trip: Dictionary = restored.export_snapshot()
	_expect(round_trip.run_id == "snapshot-contract", "snapshot restore must preserve run_id")
	_expect(round_trip.map_graph == snapshot.map_graph, "snapshot restore must preserve the serialized full graph")
	_expect(round_trip.map_graph.phases.size() == 1, "serialized graph must preserve the one-phase phases array contract")
	var first_phase: Dictionary = round_trip.map_graph.phases[0]
	_expect(first_phase.floors.size() == 12, "serialized phase must include the generated 12-floor graph")
	_expect(first_phase.nodes.size() > 4 and first_phase.edges.size() > 3, "serialized phase must include generated nodes and edges")
	_expect(round_trip.completed_nodes == snapshot.completed_nodes, "snapshot restore must preserve node_resolution_id records")
	_expect(round_trip.run_state == snapshot.run_state, "snapshot restore must preserve run-local economy")
	_expect(not source.export_persistable_snapshot().is_empty(), "post-commit stable boundary must export a persistable snapshot")
	var unstable_snapshot := snapshot.duplicate(true)
	unstable_snapshot["phase"] = TowerAscentFlowOwner.PHASE_ROUTE_AIM
	unstable_snapshot["stable_boundary"] = false
	_expect(
		not TowerAscentFlowOwner.new().restore_snapshot(unstable_snapshot),
		"restore must reject a snapshot taken outside a post-commit stable boundary"
	)
	var pending_source := TowerAscentFlowOwner.new()
	_expect(pending_source.prepare_vertical_slice_combat(owner, {"run_id": "unstable-pending"}), "pending fixture must prepare")
	_expect(pending_source.export_persistable_snapshot().is_empty(), "pending reward boundary must not be persistable")


func _verify_physics_gate_updates_only_selector_flow() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	flow.begin_vertical_slice(owner, Callable(), {"run_id": "physics-gate"})
	flow.debug_launch_miss()
	var registry := FakeRegistry.new()
	registry.instances["tower_ascent_flow_owner"] = flow
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_match_event_driver": FakeTransition.new(),
		"stage_clear_result_screen": FakeScreen.new(),
		"defeat_chance_gems_continue_screen": FakeScreen.new(),
		"defeat_settlement_screen": FakeScreen.new(),
		"grip_style_selection_overlay": FakeGrip.new(),
		"battle_scene_modal_gate_controller": FakeModalGate.new(),
	}
	var pause := FakeModalPause.new()
	var before_ball := owner.ball_position
	var before_player_score := owner.player_score
	var before_boss_score := owner.boss_score
	var before_cooldown := owner.cooldown_seconds
	var before_selector := flow.get_selector_position()
	var uses_extracted_gate := ResourceLoader.exists(
		"res://scripts/core/battle_physics_gate_coordinator.gd"
	)
	var blocked := _run_tower_physics_gate(
		0.1,
		owner,
		registry,
		holder,
		pause
	)
	_expect(blocked, "active tower flow must block the normal combat physics ladder")
	if uses_extracted_gate:
		_expect(pause.enter_calls == 1, "tower flow must enter the existing modal pause fanout")
	_expect(not flow.get_selector_position().is_equal_approx(before_selector), "the separate selector ball must still advance")
	_expect(owner.ball_position == before_ball, "the live combat ball must remain untouched")
	_expect(owner.player_score == before_player_score and owner.boss_score == before_boss_score, "scores must remain frozen")
	_expect(is_equal_approx(owner.cooldown_seconds, before_cooldown), "combat cooldowns must remain frozen")

	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var unblocked := not _run_tower_physics_gate(
		0.1,
		owner,
		registry,
		holder,
		pause
	)
	_expect(unblocked, "flag OFF must release the tower-specific physics gate even if a fixture is active")


func _run_tower_physics_gate(
	delta: float,
	owner: Object,
	registry: Object,
	holder: ModuleHolder,
	pause: FakeModalPause
) -> bool:
	var extracted_gate_path := "res://scripts/core/battle_physics_gate_coordinator.gd"
	if ResourceLoader.exists(extracted_gate_path):
		var gate_script: Script = load(extracted_gate_path)
		return bool(gate_script.new().should_block(
			delta,
			owner,
			registry,
			Callable(holder, "get_module"),
			_readiness_callbacks(),
			pause
		))
	return bool(BattleSceneFrameController.new().call(
		"_process_tower_ascent_flow",
		delta,
		owner,
		registry
	))


func _verify_input_controller_routes_modal_confirm() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	flow.begin_vertical_slice(owner, Callable(), {"run_id": "input-route"})
	var registry := FakeRegistry.new()
	registry.instances["tower_ascent_flow_owner"] = flow
	var holder := ModuleHolder.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	BattleSceneInputController.new().handle_unhandled_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		{}
	)
	_expect(flow.get_phase_name() == "ROUTE_AIM", "battle input router must deliver modal confirm to the tower owner")
	_expect(owner.redraw_requests >= 1, "tower input must request the coalesced battle redraw path")


func _readiness_callbacks() -> Dictionary:
	return {
		"is_battle_initialized": Callable(self, "_true"),
		"is_stage_landing_intro_started": Callable(self, "_true"),
	}


func _true() -> bool:
	return true


func _on_reset() -> void:
	_reset_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
