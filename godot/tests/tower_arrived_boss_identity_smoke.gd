extends SceneTree

const BattleSceneMatchEventDriver := preload(
	"res://scripts/core/battle_scene_match_event_driver.gd"
)
const BattleSceneMatchFlowDriver := preload(
	"res://scripts/core/battle_scene_match_flow_driver.gd"
)
const BattleSceneSelectionStartupLifecycle := preload(
	"res://scripts/core/battle_scene_selection_startup_lifecycle.gd"
)
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const StageBossVariantCatalog := preload(
	"res://scripts/stages/common/stage_boss_variant_catalog.gd"
)
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapIconography := preload(
	"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const MAP_SEED := 475523
const RESEED_SWEEP_SEED_COUNT := 128
const FLOOR_ONE_CASES := [
	{"slot_id": "floor_01_dalji", "variant": "dalji", "icon_id": "dalji"},
	{"slot_id": "floor_01_gaksital", "variant": "gaksi", "icon_id": "gaksital"},
	{"slot_id": "floor_01_podo", "variant": "podo", "icon_id": "podo"},
]

var _failures: Array[String] = []
var _leg_count := 0
var _reset_calls := 0
var _captured_encounter: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var selection_state: Object
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := "dalji"
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var redraw_requests := 0

	func _init(value: Object) -> void:
		selection_state = value

	func get_node_or_null(path: NodePath) -> Object:
		return selection_state if str(path) == "/root/GameSelectionState" else null

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeModalRuntime:
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
	var requested_script_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)

	func request_threaded_script(key: String) -> bool:
		if not requested_script_keys.has(key):
			requested_script_keys.append(key)
		return true

	func is_threaded_script_ready(_key: String) -> bool:
		return true


class CountingTransitionDriver:
	extends RefCounted

	var begin_calls := 0

	func begin_tower_boss_transition(
		_owner: Object,
		_registry: Object,
		_encounter: Dictionary
	) -> bool:
		begin_calls += 1
		return true


class RejectingTransitionDriver:
	extends RefCounted

	var begin_calls := 0

	func begin_tower_boss_transition(
		_owner: Object,
		_registry: Object,
		_encounter: Dictionary
	) -> bool:
		begin_calls += 1
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	for case in FLOOR_ONE_CASES:
		_verify_production_arrival(case)
	_verify_corrupted_standin_prefers_visible_identity()
	_verify_failed_transition_rearms_real_flow()
	_verify_empty_encounter_never_replays_current_boss()
	_verify_snapshot_restore_repairs_stale_standin()
	_verify_gatekeeper_reseed_preserves_terminal_reachability()
	_verify_zero_target_route_aim_lands_once()
	_verify_alias_and_seed_zero_boundary()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(_leg_count == 10, "all ten arrived-boss identity legs must execute")
	if _failures.is_empty():
		print("tower_arrived_boss_identity_smoke: legs=%d" % _leg_count)
		print("tower_arrived_boss_identity_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_production_arrival(case: Dictionary) -> void:
	_leg_count += 1
	var selection := GameSelectionState.new()
	var owner := FakeOwner.new(selection)
	var boss_registry := TowerAscentBossRegistry.new()
	var opening_slot: Dictionary = boss_registry.get_seeded_floor_slots(1, MAP_SEED)[0]
	owner.stage1_boss_variant = str(opening_slot.get("variant", "dalji"))
	var flow := TowerAscentFlowOwner.new()
	var event_driver := BattleSceneMatchEventDriver.new()
	var match_driver := BattleSceneMatchFlowDriver.new()
	var module_registry := FakeRegistry.new()
	module_registry.instances = {
		"battle_scene_match_event_driver": event_driver,
		"runtime_perk_state": FakeModalRuntime.new(),
		"tower_ascent_flow_owner": flow,
	}
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "arrived-boss-%s" % str(case.get("variant", "")),
		"map_seed": MAP_SEED,
		"current_stage": 1,
		"registry": module_registry,
	}), "%s seeded production flow must prepare" % str(case.get("variant", "")))
	var node := _find_node_for_slot(flow, str(case.get("slot_id", "")))
	_expect(not node.is_empty(), "%s arrival node must exist" % str(case.get("slot_id", "")))
	if node.is_empty():
		selection.free()
		return
	var route_icon := str(
		TowerAscentFlowRenderer.new().build_map_icon_presentation(node).get("boss_id", "")
	)
	flow.set("_active", true)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", module_registry)
	flow.set(
		"_finish_callback",
		Callable(match_driver, "_finish_tower_boss_route").bind(
			module_registry,
			owner,
			Callable(self, "_on_reset")
		)
	)
	flow.set("_selected_target_id", str(node.get("id", "")))
	flow.call("_complete_map_transition")
	var arrived_node := _find_node_for_slot(flow, str(case.get("slot_id", "")))
	var arrived_boss_id := boss_registry.resolve_boss_icon_id_for_node(arrived_node)
	var owner_boss_id := boss_registry.resolve_boss_icon_id_for_route({
		"stage": 1,
		"variant": owner.stage1_boss_variant,
	})
	_expect(
		owner.stage1_boss_variant == str(case.get("variant", "")),
		"%s real begin_tower_boss_transition must apply the arrived variant"
		% str(case.get("slot_id", ""))
	)
	_expect(
		route_icon == str(case.get("icon_id", ""))
		and arrived_boss_id == route_icon
		and owner_boss_id == route_icon,
		"%s route icon, arrived resolver, and battle owner must converge"
		% str(case.get("slot_id", ""))
	)
	_expect(
		bool(event_driver.get("_stage_transition_loading_active")),
		"%s production transition must enter loading" % str(case.get("slot_id", ""))
	)
	selection.free()


func _verify_corrupted_standin_prefers_visible_identity() -> void:
	_leg_count += 1
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.prepare_vertical_slice_combat(null, {
		"run_id": "arrived-visible-counterproof",
		"map_seed": MAP_SEED,
	}), "corrupted-standin fixture must prepare")
	var node := _find_node_for_slot(flow, "floor_01_gaksital")
	var boss_registry := TowerAscentBossRegistry.new()
	var corrupted := node.duplicate(true)
	corrupted["standin"] = boss_registry.get_standin("floor_01_podo")
	var raw_slot_encounter := boss_registry.resolve_battle_encounter(
		"floor_01_gaksital"
	)
	var corrected := boss_registry.resolve_battle_encounter_for_node(corrupted)
	var visible_icon := TowerAscentMapIconography.new().resolve_boss_id_for_node(corrupted)
	_expect(
		str(raw_slot_encounter.get("variant", "")) == "gaksi",
		"RED counterproof must show the old slot-only route selecting Gaksital"
	)
	_expect(
		str(corrected.get("variant", "")) == "podo"
		and str(corrected.get("icon_boss_id", "")) == "podo"
		and visible_icon == "podo"
		and bool(corrected.get("identity_corrected", false)),
		"corrupted sibling standin must correct battle to the identity the player saw"
	)


func _verify_failed_transition_rearms_real_flow() -> void:
	_leg_count += 1
	_reset_calls = 0
	var boss_registry := TowerAscentBossRegistry.new()
	var selection := GameSelectionState.new()
	var owner := FakeOwner.new(selection)
	var opening_slot: Dictionary = boss_registry.get_seeded_floor_slots(1, MAP_SEED)[0]
	owner.stage1_boss_variant = str(opening_slot.get("variant", "dalji"))
	var flow := TowerAscentFlowOwner.new()
	var event_driver := BattleSceneMatchEventDriver.new()
	event_driver.set("_stage_transition_loading_active", true)
	var match_driver := BattleSceneMatchFlowDriver.new()
	var module_registry := FakeRegistry.new()
	module_registry.instances = {
		"battle_scene_match_event_driver": event_driver,
		"runtime_perk_state": FakeModalRuntime.new(),
		"tower_ascent_flow_owner": flow,
	}
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "arrived-transition-recovery",
		"map_seed": MAP_SEED,
		"current_stage": 1,
		"registry": module_registry,
	}), "real failed-transition flow must prepare")
	var node := _find_node_for_slot(flow, "floor_01_gaksital")
	_expect(not node.is_empty(), "real failed-transition flow must expose Gaksital")
	flow.set("_active", true)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", module_registry)
	flow.set(
		"_finish_callback",
		Callable(match_driver, "_finish_tower_boss_route").bind(
			module_registry,
			owner,
			Callable(self, "_on_reset")
		)
	)
	flow.set("_selected_target_id", str(node.get("id", "")))
	flow.call("_complete_map_transition")
	var rebound_callback: Variant = flow.get("_finish_callback")
	_expect(_reset_calls == 0, "recoverable transition failure must not invoke legacy reset")
	_expect(
		flow.get_phase_name() == "ROUTE_AIM"
		and bool(flow.get("_active"))
		and flow.get("_active_owner") == owner
		and flow.get("_active_registry") == module_registry
		and rebound_callback is Callable
		and (rebound_callback as Callable).is_valid(),
		"failed transition must rebind the real flow into an interactive ROUTE_AIM"
	)
	_expect(
		not flow.get_route_aim_targets().is_empty(),
		"rearmed flow must expose at least one selectable route"
	)
	flow.debug_launch_at_target(0)
	flow.update_selective(_arrival_flight_seconds())
	_expect(
		flow.get_phase_name() == "MAP_TRANSITION",
		"rearmed selector must still confirm a route after transition failure"
	)
	_reset_calls = 0
	var rejecting_driver := RejectingTransitionDriver.new()
	var hard_failure_registry := FakeRegistry.new()
	hard_failure_registry.instances = {
		"battle_scene_match_event_driver": rejecting_driver,
	}
	match_driver.call(
		"_finish_tower_boss_route",
		boss_registry.resolve_battle_encounter("floor_01_gaksital"),
		hard_failure_registry,
		owner,
		Callable(self, "_on_reset")
	)
	_expect(
		rejecting_driver.begin_calls == 1 and _reset_calls == 1,
		"unavailable route recovery must land through one legacy reset"
	)
	flow.call("_reset_runtime_state")
	selection.free()


func _verify_empty_encounter_never_replays_current_boss() -> void:
	_leg_count += 1
	_reset_calls = 0
	var selection := GameSelectionState.new()
	var owner := FakeOwner.new(selection)
	owner.stage1_boss_variant = "podo"
	var flow := TowerAscentFlowOwner.new()
	var transition_driver := CountingTransitionDriver.new()
	var module_registry := FakeRegistry.new()
	module_registry.instances = {
		"battle_scene_match_event_driver": transition_driver,
		"runtime_perk_state": FakeModalRuntime.new(),
		"tower_ascent_flow_owner": flow,
	}
	var match_driver := BattleSceneMatchFlowDriver.new()
	var finish_callback := Callable(
		match_driver,
		"_finish_tower_boss_route"
	).bind(module_registry, owner, Callable(self, "_on_reset"))
	_expect(flow.begin_vertical_slice(owner, finish_callback, {
		"run_id": "arrived-empty-never-replays",
		"map_seed": MAP_SEED,
		"registry": module_registry,
	}), "empty-encounter real flow must begin")
	var previous_node_id := flow.get_current_node_id()
	flow.call("_finish_vertical_slice")
	_expect(_reset_calls == 1, "empty encounter must land through the legacy reset callback")
	_expect(transition_driver.begin_calls == 0, "empty encounter must never synthesize or begin combat")
	_expect(flow.get_current_node_id() == previous_node_id, "empty encounter must not replay or move the previous node")
	_expect(owner.stage1_boss_variant == "podo", "empty encounter must not mutate the previous boss identity")
	selection.free()


func _verify_snapshot_restore_repairs_stale_standin() -> void:
	_leg_count += 1
	var source := TowerAscentFlowOwner.new()
	_expect(source.begin_vertical_slice(null, Callable(), {
		"run_id": "arrived-snapshot-repair",
		"map_seed": MAP_SEED,
	}), "snapshot repair fixture must begin")
	source.debug_launch_at_target(0)
	source.update_selective(_arrival_flight_seconds())
	_expect(source.get_phase_name() == "MAP_TRANSITION", "snapshot fixture must reach a stable transition")
	var snapshot := source.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "snapshot fixture must export a stable snapshot")
	var phases: Array = (snapshot.get("map_graph", {}) as Dictionary).get("phases", [])
	var corrupted_node_id := ""
	var downgraded_node_id := ""
	var boss_registry := TowerAscentBossRegistry.new()
	for phase_variant in phases:
		if not (phase_variant is Dictionary):
			continue
		var nodes: Array = (phase_variant as Dictionary).get("nodes", [])
		for node_variant in nodes:
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if str(node.get("boss_slot_id", "")) != "floor_01_gaksital":
				if (
					downgraded_node_id.is_empty()
					and int(node.get("segment_floor", node.get("floor", 0))) >= 3
					and bool(node.get("gatekeeper", false))
					and node.has("boss_slot_id")
					and not node.has("boss_sequence_slot_ids")
				):
					downgraded_node_id = str(node.get("id", ""))
					node["boss_slot_id"] = "floor_99_removed_save_slot"
					node["boss_encounter_key"] = "99:removed_save_slot"
					node["standin"] = {}
					node["content_state"] = TowerAscentBossRegistry.CONTENT_REGISTRY_ONLY
					node["route_disabled"] = true
					node["skipped"] = true
				continue
			if corrupted_node_id.is_empty():
				corrupted_node_id = str(node.get("id", ""))
				node["standin"] = boss_registry.get_standin("floor_01_podo")
	_expect(not corrupted_node_id.is_empty(), "snapshot fixture must locate the Gaksital node")
	_expect(not downgraded_node_id.is_empty(), "snapshot fixture must locate one removable future boss node")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "stale and removed-slot snapshot must restore without discarding the run")
	var repaired := _find_node_by_id(restored, corrupted_node_id)
	var downgraded := _find_node_by_id(restored, downgraded_node_id)
	var report := boss_registry.analyze_boss_node_identity(repaired)
	var reseeded_report := boss_registry.analyze_boss_node_identity(downgraded)
	var encounter := boss_registry.resolve_battle_encounter_for_node(repaired)
	_expect(
		bool(report.get("valid", false))
		and boss_registry.resolve_boss_icon_id_for_node(repaired) == "gaksital"
		and str(encounter.get("variant", "")) == "gaksi",
		"snapshot restore must reconverge standin, icon, and battle to the live slot"
	)
	_expect(
		str(downgraded.get("content_state", "")) == TowerAscentBossRegistry.CONTENT_GENERATED
		and str(downgraded.get("boss_assignment_state", "")) == "snapshot_gatekeeper_reseeded"
		and bool(downgraded.get("gatekeeper", false))
		and not bool(downgraded.get("route_disabled", false))
		and not downgraded.has("skipped")
		and bool(reseeded_report.get("valid", false))
		and restored.get_run_id() == "arrived-snapshot-repair",
		"an unrepairable saved gatekeeper must reseed to a live same-floor boss without blocking the run"
	)


func _verify_gatekeeper_reseed_preserves_terminal_reachability() -> void:
	_leg_count += 1
	var boss_registry := TowerAscentBossRegistry.new()
	var map_generator := TowerAscentMapGenerator.new()
	var reseeded_gate_count := 0
	var red_counterproof_seen := false
	for map_seed in range(RESEED_SWEEP_SEED_COUNT):
		var generated := map_generator.generate_tower(map_seed, [])
		var phases: Array = generated.get("phases", [])
		_expect(not phases.is_empty(), "reseed sweep seed %d must decorate a graph" % map_seed)
		if phases.is_empty() or not (phases[0] is Dictionary):
			continue
		var phase := (phases[0] as Dictionary).duplicate(true)
		var clear_floor := int(phase.get("standard_clear_floor", 0))
		var nodes: Array = phase.get("nodes", [])
		var red_gate_index := -1
		for node_index in range(nodes.size()):
			if not (nodes[node_index] is Dictionary):
				continue
			var node := nodes[node_index] as Dictionary
			var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
			if (
				not bool(node.get("gatekeeper", false))
				or floor_number > clear_floor
				or str(node.get("content_state", "")) != TowerAscentBossRegistry.CONTENT_GENERATED
				or str(node.get("kind", "")) not in TowerAscentBossRegistry.COMBAT_NODE_KINDS
			):
				continue
			if red_gate_index < 0 and floor_number > 1 and floor_number < clear_floor:
				red_gate_index = node_index
			var corrupted := node.duplicate(true)
			corrupted["boss_slot_id"] = "floor_99_removed_save_slot"
			corrupted["boss_encounter_key"] = "99:removed_save_slot"
			corrupted["standin"] = {}
			corrupted["content_state"] = TowerAscentBossRegistry.CONTENT_REGISTRY_ONLY
			corrupted["route_disabled"] = true
			corrupted["skipped"] = true
			var reseed := boss_registry.reseed_gatekeeper_boss_node_identity(
				corrupted,
				map_seed
			)
			var reseeded: Dictionary = reseed.get("node", {})
			var reseeded_floor := int(reseeded.get(
				"segment_floor",
				reseeded.get("floor", 0)
			))
			_expect(
				bool(reseed.get("valid", false))
				and reseeded_floor == floor_number
				and int(boss_registry.get_slot(str(reseeded.get("boss_slot_id", ""))).get(
					"slot_floor",
					0
				)) == floor_number
				and not bool(reseeded.get("route_disabled", false))
				and not reseeded.has("skipped"),
				"seed %d floor %d gate must reseed to one enabled same-floor live slot"
				% [map_seed, floor_number]
			)
			nodes[node_index] = reseeded
			reseeded_gate_count += 1
		if map_seed == 0 and red_gate_index >= 0:
			var red_phase := phase.duplicate(true)
			var red_nodes: Array = red_phase.get("nodes", [])
			var blocked_gate := (red_nodes[red_gate_index] as Dictionary).duplicate(true)
			blocked_gate["route_disabled"] = true
			red_nodes[red_gate_index] = blocked_gate
			red_phase["nodes"] = red_nodes
			red_counterproof_seen = not _has_enabled_entry_to_terminal_path(red_phase)
		phase["nodes"] = nodes
		_expect(
			_has_enabled_entry_to_terminal_path(phase),
			"seed %d must retain an enabled entry-to-terminal route after every gate downgrade"
			% map_seed
		)
	_expect(
		red_counterproof_seen,
		"RED counterproof must show one route-disabled single-lane gate cutting terminal reachability"
	)
	_expect(
		reseeded_gate_count >= RESEED_SWEEP_SEED_COUNT,
		"the reseed sweep must exercise at least one gate per seed"
	)


func _verify_zero_target_route_aim_lands_once() -> void:
	_leg_count += 1
	_reset_calls = 0
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(self, "_on_reset"), {
		"run_id": "arrived-zero-target-landing",
		"map_seed": MAP_SEED,
	}), "zero-target landing fixture must begin through the real flow")
	var target_ids := flow.get_route_target_ids().duplicate()
	_expect(not target_ids.is_empty(), "zero-target RED fixture must start with live route targets")
	for target_id_variant in target_ids:
		var target_node := _find_node_by_id(flow, str(target_id_variant))
		target_node["route_disabled"] = true
	flow.call("_refresh_route_target_cache")
	_expect(
		flow.get_route_target_ids().is_empty()
		and flow.get_route_aim_targets().is_empty()
		and bool(flow.get("_active"))
		and _reset_calls == 0,
		"RED counterproof must reproduce the active zero-target softlock before the entry guard"
	)
	var entered := flow.debug_reenter_route_aim()
	_expect(
		not entered
		and _reset_calls == 1
		and not bool(flow.get("_active"))
		and flow.get_phase_name() == "COMBAT",
		"zero-target route entry must reject and land through exactly one defined reset callback"
	)


func _verify_alias_and_seed_zero_boundary() -> void:
	_leg_count += 1
	var lifecycle := BattleSceneSelectionStartupLifecycle.new()
	_expect(
		StageBossVariantCatalog.canonicalize_variant_id("talchum") == "gaksi"
		and lifecycle.normalize_stage1_boss_variant("talchum") == "gaksi",
		"all Stage 1 identity authorities must consume the shared talchum alias"
	)
	var selection := GameSelectionState.new()
	selection.set_stage1_boss_variant("talchum")
	_expect(
		str(selection.get_selection().get("stage1_boss_variant", "")) == "gaksi",
		"GameSelectionState must delegate talchum normalization to the catalog"
	)
	var zero_seed_variant := lifecycle.resolve_stage1_boss_variant({
		"tower_map_seed": 0,
		"tower_map_seed_available": true,
	}, 1)
	var zero_seed_slots := TowerAscentBossRegistry.new().get_seeded_floor_slots(1, 0)
	_expect(
		not zero_seed_slots.is_empty()
		and zero_seed_variant == str(zero_seed_slots[0].get("variant", "")),
		"seed-zero Tower identity must resolve the same generated opening gate"
	)
	selection.free()


func _arrival_flight_seconds() -> float:
	return (
		TowerAscentNodeArrivalTestFixture.REFERENCE_FLIGHT_SECONDS
		* TowerAscentNodeArrivalTestFixture.REFERENCE_SERVE_SPEED_PER_SECOND
		/ maxf(1.0, TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND)
	)


func _find_node_for_slot(flow: Object, slot_id: String) -> Dictionary:
	for node in flow.get_graph_nodes():
		if str(node.get("boss_slot_id", "")) == slot_id:
			return node
	return {}


func _find_node_by_id(flow: Object, node_id: String) -> Dictionary:
	for node in flow.get_graph_nodes():
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _has_enabled_entry_to_terminal_path(phase: Dictionary) -> bool:
	var entry_node_id := str(phase.get("entry_node_id", ""))
	var clear_floor := int(phase.get("standard_clear_floor", 0))
	var enabled_node_ids: Dictionary = {}
	var terminal_node_id := ""
	for node_variant in phase.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if bool(node.get("route_disabled", false)):
			continue
		var node_id := str(node.get("id", ""))
		enabled_node_ids[node_id] = true
		if (
			int(node.get("segment_floor", node.get("floor", 0))) == clear_floor
			and bool(node.get("gatekeeper", false))
			and bool(node.get("floor_boundary", false))
		):
			terminal_node_id = node_id
	if (
		entry_node_id.is_empty()
		or terminal_node_id.is_empty()
		or not enabled_node_ids.has(entry_node_id)
		or not enabled_node_ids.has(terminal_node_id)
	):
		return false
	var adjacency: Dictionary = {}
	for edge_variant in phase.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if not enabled_node_ids.has(from_id) or not enabled_node_ids.has(to_id):
			continue
		var targets: Array = adjacency.get(from_id, [])
		targets.append(to_id)
		adjacency[from_id] = targets
	var visited: Dictionary = {entry_node_id: true}
	var pending: Array[String] = [entry_node_id]
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		if current_id == terminal_node_id:
			return true
		for target_variant in adjacency.get(current_id, []):
			var target_id := str(target_variant)
			if visited.has(target_id):
				continue
			visited[target_id] = true
			pending.append(target_id)
	return false


func _on_reset() -> void:
	_reset_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
