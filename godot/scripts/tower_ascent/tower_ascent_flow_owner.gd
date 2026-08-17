extends RefCounted

const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerAscentFlowRenderer := preload("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
const TowerAscentMapGenerator := preload("res://scripts/tower_ascent/tower_ascent_map_generator.gd")
const TowerAscentRouteCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_candidate_policy.gd"
)
const TowerAscentRunState := preload("res://scripts/tower_ascent/tower_ascent_run_state.gd")
const TowerAscentTuning := preload("res://scripts/tower_ascent/tower_ascent_tuning.gd")
const TowerAscentNodeResolutionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_resolution_transaction.gd"
)
const TowerAscentDefeatResolver := preload(
	"res://scripts/tower_ascent/tower_ascent_defeat_resolver.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentModalLifecycle := preload(
	"res://scripts/tower_ascent/tower_ascent_modal_lifecycle.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentShopInventory := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_inventory.gd"
)
const TowerAscentTrainingOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd"
)
const TowerAscentFallenMonkNode := preload(
	"res://scripts/tower_ascent/tower_ascent_fallen_monk_node.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentRestNode := preload(
	"res://scripts/tower_ascent/tower_ascent_rest_node.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)
const TowerAscentEndingState := preload(
	"res://scripts/tower_ascent/tower_ascent_ending_state.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)

const SNAPSHOT_SCHEMA_VERSION := TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION
const MAP_GENERATOR_VERSION := TowerAscentMapGenerator.GENERATOR_VERSION
const MAP_GRAPH_STORAGE_FULL := "full_graph"
const PHASE_COMBAT := 0
const PHASE_NODE_MODAL := 1
const PHASE_ROUTE_AIM := 2
const PHASE_MAP_TRANSITION := 3
const PHASE_FAKE_ENDING_TEASER := 4
const MAP_TRANSITION_SECONDS := 0.9
const SELECTOR_RADIUS := 11.0
const SELECTOR_SPEED := 520.0
const SELECTOR_ORIGIN := Vector2(380.0, 665.0)
const SELECTOR_TARGET_Y := 165.0
const SELECTOR_LEFT_WALL := 52.0
const SELECTOR_RIGHT_WALL := 708.0
const SELECTOR_RESET_Y := 92.0

var _active := false
var _map_seed := 0
var _prepared := false
var _prepared_resolution_id := ""
var _phase := PHASE_COMBAT
var _graph_phases: Array[Dictionary] = []
var _graph_nodes: Array[Dictionary] = []
var _graph_edges: Array[Dictionary] = []
var _current_node_id := ""
var _completed_nodes: Array[Dictionary] = []
var _resolution_ids: Dictionary = {}
var _pending_rewards: Array[Dictionary] = []
var _run_state: Object = TowerAscentRunState.new()
var _resolution_transaction: Object = TowerAscentNodeResolutionTransaction.new()
var _node_action_transaction: Object = TowerAscentNodeActionTransaction.new()
var _defeat_resolver: Object = TowerAscentDefeatResolver.new()
var _generated_shop_inventory: Array[Dictionary] = []
var _purchase_history: Array[Dictionary] = []
var _generated_training_offers: Array[Dictionary] = []
var _training_history: Array[Dictionary] = []
var _claimed_decoration_ids: Array[String] = []
var _build_state := {
	"mugong": [],
	"chosik": [],
	"active_items": [],
	"mythic": {},
}
var _guardian_state := {
	"soul_summoning_owned": false,
	"active_guardian": {},
	"sealed_guardians": [],
}
var _gameplay_rng_state := {"seed": 140913, "state": 140913}
var _route_history: Array[Dictionary] = []
var _route_source_node_id := ""
var _route_target_ids: Array[String] = []
var _available_route_target_ids: Array[String] = []
var _route_aim_targets_cache: Array[Dictionary] = []
var _selected_target_id := ""
var _selector_position := SELECTOR_ORIGIN
var _selector_velocity := Vector2.ZERO
var _selector_launched := false
var _aim_target_x := 220.0
var _map_transition_progress := 0.0
var _finish_callback := Callable()
var _renderer: Object = TowerAscentFlowRenderer.new()
var _map_generator: Object = TowerAscentMapGenerator.new()
var _route_candidate_policy: Object = TowerAscentRouteCandidatePolicy.new()
var _shop_inventory_builder: Object = TowerAscentShopInventory.new()
var _training_offer_builder: Object = TowerAscentTrainingOfferBuilder.new()
var _fallen_monk_node: Object = TowerAscentFallenMonkNode.new()
var _guardian_spring_node: Object = TowerAscentGuardianSpringNode.new()
var _rest_node: Object = TowerAscentRestNode.new()
var _record_store: Object = TowerAscentRecordStore.new()
var _ending_state: Object = TowerAscentEndingState.new()
var _node_modal_state: Object = TowerAscentNodeModalState.new()
var _modal_lifecycle: Object = TowerAscentModalLifecycle.new()
var _node_modal_kind := "guardian_spring"
var _active_owner: Object = null
var _active_registry: Object = null
var _pending_runtime_perk_rollback_snapshot: Dictionary = {}
var _header_subtitle := ""


func begin_vertical_slice(
	owner: Object,
	finish_callback: Callable,
	context: Dictionary = {}
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or _active:
		return false
	if not _prepared and not prepare_vertical_slice_combat(owner, context):
		return false
	var lifecycle_result: Dictionary = _modal_lifecycle.enter(
		owner,
		context.get("registry", null)
	)
	if not bool(lifecycle_result.get("accepted", false)):
		return false
	_finish_callback = finish_callback
	if not _complete_prepared_combat_resolution():
		_modal_lifecycle.leave()
		return false
	_prepared = false
	_prepared_resolution_id = ""
	_active_owner = owner
	_active_registry = context.get("registry", null)
	_guardian_spring_node.sync_owner_projection(owner)
	_active = true
	_phase = PHASE_NODE_MODAL
	_current_node_id = _route_source_node_id
	_open_node_modal()
	_request_redraw(owner)
	return true


func prepare_vertical_slice_combat(owner: Object, context: Dictionary = {}) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or _active:
		return false
	if _prepared:
		return true
	var existing_run_id: String = str(_run_state.get_run_id())
	var existing_economy: Dictionary = _run_state.export_economy()
	var existing_progress := {
		"skipped_boss_ids": _run_state.get_skipped_boss_ids(),
	}
	var existing_map_seed := _map_seed
	var reuse_existing_run: bool = bool(
		_run_state.has_started() and not context.has("run_id")
	)
	_reset_runtime_state()
	var run_id := str(context.get(
		"run_id",
		existing_run_id if reuse_existing_run else "vertical-slice-%d" % Time.get_ticks_msec()
	))
	var economy_variant: Variant = context.get(
		"run_state",
		existing_economy if reuse_existing_run else {}
	)
	var economy: Dictionary = economy_variant if economy_variant is Dictionary else {}
	var progress := existing_progress if reuse_existing_run else {}
	if not _run_state.begin(run_id, economy, [], progress):
		return false
	var current_stage := int(context.get("current_stage", _get_owner_int(owner, "current_stage", 1)))
	_map_seed = int(context.get(
		"map_seed",
		existing_map_seed if reuse_existing_run else _derive_map_seed(run_id, current_stage)
	))
	_node_modal_kind = _normalize_node_modal_kind(str(context.get(
		"node_modal_kind",
		"guardian_spring"
	)))
	_header_subtitle = "생성 지도 검증판 · %s" % _run_state.get_run_id()
	if not _build_generated_graph(current_stage):
		return false
	_current_node_id = _route_source_node_id
	_sync_run_state_phases()
	_prepared_resolution_id = _make_resolution_id(_route_source_node_id, "combat_victory")
	var reward_bundle_variant: Variant = context.get("node_reward_bundle", {})
	var reward_bundle: Dictionary = reward_bundle_variant if reward_bundle_variant is Dictionary else {}
	var pending: Dictionary = _resolution_transaction.prepare(
		_run_state.get_run_id(),
		_route_source_node_id,
		"combat_victory",
		"victory_loot_phase",
		reward_bundle,
		_prepared_resolution_id
	)
	if pending.is_empty():
		return false
	_pending_rewards.append(pending)
	_prepared = true
	return true


func restore_snapshot(
	snapshot: Dictionary,
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if not bool(snapshot.get("stable_boundary", false)):
		return false
	if str(snapshot.get("map_graph_storage", "")) != MAP_GRAPH_STORAGE_FULL:
		return false
	if str(snapshot.get("map_generator_version", "")) != MAP_GENERATOR_VERSION:
		return false
	if not snapshot.has("map_seed"):
		return false
	_reset_runtime_state()
	if not _run_state.restore_snapshot(snapshot):
		return false
	var phases: Array[Dictionary] = _run_state.get_phases()
	_graph_phases.assign(phases.duplicate(true))
	var graph: Dictionary = phases[0]
	var nodes_variant: Variant = graph.get("nodes", [])
	var edges_variant: Variant = graph.get("edges", [])
	if not (nodes_variant is Array) or (nodes_variant as Array).size() < 4:
		return false
	if not (edges_variant is Array) or (edges_variant as Array).size() < 3:
		return false
	_map_seed = int(snapshot.get("map_seed", 0))
	_header_subtitle = "생성 지도 검증판 · %s" % _run_state.get_run_id()
	_graph_nodes.assign((nodes_variant as Array).duplicate(true))
	_graph_edges.assign((edges_variant as Array).duplicate(true))
	_current_node_id = str(snapshot.get("current_node_id", ""))
	_completed_nodes.assign(_dictionary_array(snapshot.get("completed_nodes", [])))
	for entry in _completed_nodes:
		_resolution_ids[str(entry.get("node_resolution_id", ""))] = true
	_pending_rewards.assign(_dictionary_array(snapshot.get("pending_rewards", [])))
	_generated_shop_inventory.assign(_dictionary_array(snapshot.get("generated_shop_inventory", [])))
	_purchase_history.assign(_dictionary_array(snapshot.get("purchase_history", [])))
	for purchase in _purchase_history:
		var purchase_resolution_id := str(purchase.get("node_resolution_id", ""))
		if not purchase_resolution_id.is_empty():
			_resolution_ids[purchase_resolution_id] = true
	_generated_training_offers.assign(_dictionary_array(snapshot.get("generated_training_offers", [])))
	_training_history.assign(_dictionary_array(snapshot.get("training_history", [])))
	for training_record in _training_history:
		var training_resolution_id := str(training_record.get("node_resolution_id", ""))
		if not training_resolution_id.is_empty():
			_resolution_ids[training_resolution_id] = true
	_fallen_monk_node.restore_state(
		snapshot.get("generated_fallen_monk_offers", []),
		snapshot.get("fallen_monk_history", []),
		snapshot.get("fallen_monk_runtime_snapshot", {}),
		snapshot.get("fallen_monk_skill_config_snapshot", {})
	)
	for monk_record in _fallen_monk_node.get_history():
		var monk_resolution_id := str(monk_record.get("node_resolution_id", ""))
		if not monk_resolution_id.is_empty():
			_resolution_ids[monk_resolution_id] = true
	if not _fallen_monk_node.restore_runtime(owner, registry):
		_reset_runtime_state()
		return false
	_claimed_decoration_ids.assign(_string_array(snapshot.get("claimed_decoration_ids", [])))
	_build_state = _dictionary_copy(snapshot.get("build_state", {}))
	_guardian_state = _dictionary_copy(snapshot.get("guardian_state", {}))
	_guardian_spring_node.restore_state(_guardian_state)
	for guardian_record in _guardian_spring_node.get_history():
		var guardian_resolution_id := str(guardian_record.get("node_resolution_id", ""))
		if not guardian_resolution_id.is_empty():
			_resolution_ids[guardian_resolution_id] = true
	if not _guardian_spring_node.restore_runtime(owner, registry):
		_reset_runtime_state()
		return false
	_rest_node.restore_state(snapshot.get("rest_history", []))
	for rest_record in _rest_node.get_history():
		var rest_resolution_id := str(rest_record.get("node_resolution_id", ""))
		if not rest_resolution_id.is_empty():
			_resolution_ids[rest_resolution_id] = true
	if not _ending_state.restore_state(snapshot.get("ending_state", {})):
		_reset_runtime_state()
		return false
	_gameplay_rng_state = _dictionary_copy(snapshot.get("gameplay_rng_state", {}))
	_route_history.assign(_dictionary_array(snapshot.get("route_history", [])))
	_route_source_node_id = str(snapshot.get("route_source_node_id", ""))
	_route_target_ids.assign(_string_array(snapshot.get("route_target_ids", [])))
	if _route_source_node_id.is_empty() or _route_target_ids.size() != 2:
		return false
	_refresh_route_target_cache()
	_selected_target_id = str(snapshot.get("selected_target_id", ""))
	_node_modal_kind = _normalize_node_modal_kind(str(snapshot.get(
		"node_modal_kind",
		"guardian_spring"
	)))
	_phase = clampi(
		int(snapshot.get("phase", PHASE_NODE_MODAL)),
		PHASE_NODE_MODAL,
		PHASE_FAKE_ENDING_TEASER
	)
	_selector_position = snapshot.get("selector_position", SELECTOR_ORIGIN)
	_selector_velocity = snapshot.get("selector_velocity", Vector2.ZERO)
	_selector_launched = bool(snapshot.get("selector_launched", false))
	_aim_target_x = clampf(float(snapshot.get("aim_target_x", 220.0)), SELECTOR_LEFT_WALL, SELECTOR_RIGHT_WALL)
	_map_transition_progress = clampf(float(snapshot.get("map_transition_progress", 0.0)), 0.0, 1.0)
	_finish_callback = finish_callback
	if not _restore_runtime_perk_build_state(owner, registry):
		_reset_runtime_state()
		return false
	var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
	if not bool(lifecycle_result.get("accepted", false)):
		_reset_runtime_state()
		return false
	_active_owner = owner
	_active_registry = registry
	_guardian_spring_node.sync_owner_projection(owner)
	_active = true
	_prepared = false
	_prepared_resolution_id = ""
	if _phase == PHASE_NODE_MODAL:
		_open_node_modal()
	else:
		_node_modal_state.close()
	if _phase == PHASE_FAKE_ENDING_TEASER and not _ending_state.is_teaser_pending():
		_reset_runtime_state()
		return false
	return true


func export_snapshot() -> Dictionary:
	_sync_run_state_phases()
	_guardian_state = _guardian_spring_node.export_state()
	var snapshot: Dictionary = _run_state.export_snapshot_fields()
	snapshot.merge({
		"map_generator_version": MAP_GENERATOR_VERSION,
		"map_graph_storage": MAP_GRAPH_STORAGE_FULL,
		"map_seed": _map_seed,
		"current_node_id": _current_node_id,
		"completed_nodes": _completed_nodes.duplicate(true),
		"pending_rewards": _pending_rewards.duplicate(true),
		"generated_shop_inventory": _generated_shop_inventory.duplicate(true),
		"purchase_history": _purchase_history.duplicate(true),
		"generated_training_offers": _generated_training_offers.duplicate(true),
		"training_history": _training_history.duplicate(true),
		"generated_fallen_monk_offers": _fallen_monk_node.get_generated_offers(),
		"fallen_monk_history": _fallen_monk_node.get_history(),
		"fallen_monk_runtime_snapshot": _fallen_monk_node.get_runtime_snapshot(),
		"fallen_monk_skill_config_snapshot": _fallen_monk_node.get_skill_config_snapshot(),
		"claimed_decoration_ids": _claimed_decoration_ids.duplicate(),
		"build_state": _build_state.duplicate(true),
		"guardian_state": _guardian_state.duplicate(true),
		"rest_history": _rest_node.get_history(),
		"ending_state": _ending_state.export_state(),
		"gameplay_rng_state": _gameplay_rng_state.duplicate(true),
		"route_history": _route_history.duplicate(true),
		"route_source_node_id": _route_source_node_id,
		"route_target_ids": _route_target_ids.duplicate(),
		"selected_target_id": _selected_target_id,
		"node_modal_kind": _node_modal_kind,
		"phase": _phase,
		"selector_position": _selector_position,
		"selector_velocity": _selector_velocity,
		"selector_launched": _selector_launched,
		"aim_target_x": _aim_target_x,
		"map_transition_progress": _map_transition_progress,
		"stable_boundary": _phase in [
			PHASE_NODE_MODAL,
			PHASE_MAP_TRANSITION,
			PHASE_FAKE_ENDING_TEASER,
		],
	}, true)
	return snapshot


func export_persistable_snapshot() -> Dictionary:
	var snapshot := export_snapshot()
	if not bool(snapshot.get("stable_boundary", false)) or not _pending_rewards.is_empty():
		return {}
	return snapshot


func export_pending_reward_journal() -> Dictionary:
	return {
		"run_id": _run_state.get_run_id(),
		"pending_rewards": _pending_rewards.duplicate(true),
	}


func recover_pending_reward_journal(journal: Dictionary) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if str(journal.get("run_id", "")) != _run_state.get_run_id():
		return {"accepted": false, "reason": "run_id_mismatch"}
	var pending_entries := _dictionary_array(journal.get("pending_rewards", []))
	var applied_count := 0
	var committed_count := 0
	var skipped_count := 0
	for pending in pending_entries:
		var validation: Dictionary = _resolution_transaction.validate_pending(
			pending,
			_run_state.get_run_id()
		)
		if not bool(validation.get("accepted", false)):
			return {"accepted": false, "reason": validation.get("reason", "invalid_pending")}
		var resolution_id := str(pending.get("node_resolution_id", ""))
		if _resolution_ids.has(resolution_id):
			skipped_count += 1
			continue
		var apply_result: Dictionary = _resolution_transaction.apply_once(
			pending,
			_run_state,
			_resolution_ids
		)
		if not bool(apply_result.get("accepted", false)):
			return {"accepted": false, "reason": apply_result.get("reason", "reward_apply_failed")}
		if bool(apply_result.get("applied", false)):
			applied_count += 1
		if _commit_node_resolution(
			str(pending.get("node_id", "")),
			str(pending.get("resolution_kind", "")),
			{"reward_source": pending.get("reward_source", ""), "reward_bundle": pending.get("reward_bundle", {})},
			resolution_id
		):
			committed_count += 1
		_resolution_transaction.mark_committed(resolution_id)
	return {
		"accepted": true,
		"applied_count": applied_count,
		"committed_count": committed_count,
		"skipped_count": skipped_count,
	}


func is_active() -> bool:
	return _active


func blocks_battle_physics() -> bool:
	return _active


func get_phase() -> int:
	return _phase


func get_phase_name() -> String:
	match _phase:
		PHASE_NODE_MODAL:
			return "NODE_MODAL"
		PHASE_ROUTE_AIM:
			return "ROUTE_AIM"
		PHASE_MAP_TRANSITION:
			return "MAP_TRANSITION"
		PHASE_FAKE_ENDING_TEASER:
			return "FAKE_ENDING_TEASER"
	return "COMBAT"


func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if _phase == PHASE_FAKE_ENDING_TEASER:
		if _is_confirm_event(event):
			_dismiss_fake_ending_teaser()
		return true
	if _phase == PHASE_NODE_MODAL:
		_handle_node_modal_input(event)
		return true
	if _phase != PHASE_ROUTE_AIM:
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_LEFT or key_event.physical_keycode == KEY_LEFT:
				_set_aim_target(220.0)
			elif key_event.keycode == KEY_RIGHT or key_event.physical_keycode == KEY_RIGHT:
				_set_aim_target(540.0)
			elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_launch_selector()
	elif event is InputEventMouseMotion:
		_set_aim_target(220.0 if (event as InputEventMouseMotion).position.x < 380.0 else 540.0)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_aim_target(220.0 if mouse_event.position.x < 380.0 else 540.0)
			_launch_selector()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_set_aim_target(220.0 if touch_event.position.x < 380.0 else 540.0)
			_launch_selector()
	return true


func update_selective(delta: float, owner: Object = null) -> void:
	if not _active:
		return
	if _phase == PHASE_ROUTE_AIM and _selector_launched:
		_update_selector(maxf(0.0, delta))
	elif _phase == PHASE_MAP_TRANSITION:
		_map_transition_progress = minf(1.0, _map_transition_progress + maxf(0.0, delta) / MAP_TRANSITION_SECONDS)
		if _map_transition_progress >= 1.0:
			_finish_vertical_slice()
	_request_redraw(owner)


func draw(canvas: CanvasItem) -> void:
	if _renderer != null and _renderer.has_method("draw"):
		_renderer.draw(canvas, self)


func debug_advance_to_route_aim() -> void:
	if _active and _phase == PHASE_NODE_MODAL:
		_enter_route_aim()


func debug_launch_at_target(target_index: int) -> void:
	if not _active or _phase != PHASE_ROUTE_AIM:
		return
	_set_aim_target(_route_target_aim_position(target_index).x)
	_launch_selector()


func debug_launch_miss() -> void:
	if not _active or _phase != PHASE_ROUTE_AIM:
		return
	_set_aim_target(380.0)
	_launch_selector()


func get_graph_nodes() -> Array[Dictionary]:
	return _graph_nodes


func get_graph_phases() -> Array[Dictionary]:
	_sync_run_state_phases()
	return _graph_phases.duplicate(true)


func get_graph_floors() -> Array:
	if _graph_phases.is_empty():
		return []
	return _graph_phases[0].get("floors", [])


func get_route_target_ids() -> Array[String]:
	return _available_route_target_ids


func get_current_node_id() -> String:
	return _current_node_id


func get_route_aim_targets() -> Array[Dictionary]:
	return _route_aim_targets_cache


func get_skipped_boss_ids() -> Array[String]:
	return _run_state.get_skipped_boss_ids()


func get_current_node_risk_context() -> Dictionary:
	var node := _get_node(_current_node_id)
	if node.is_empty():
		node = _get_node(_route_source_node_id)
	return {
		"floor": maxi(1, int(node.get("floor", 1))),
		"is_elite": bool(node.get("elite", false)),
		"is_enraged": bool(node.get("enraged", false)),
		"is_gatekeeper": bool(node.get("gatekeeper", false)),
		"boss_slot_id": str(node.get("boss_slot_id", "")),
	}


func get_run_id() -> String:
	return _run_state.get_run_id()


func get_map_seed() -> int:
	return _map_seed


func get_run_state_snapshot() -> Dictionary:
	return _run_state.export_economy()


func collect_muhon(amount: int, owner: Object = null) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if amount <= 0:
		return {"accepted": false, "reason": "invalid_amount"}
	if not ensure_run_started(owner):
		return {"accepted": false, "reason": "run_unavailable"}
	var apply_result: Dictionary = _run_state.apply_reward_bundle({"muhon": amount})
	return {
		"accepted": true,
		"reason": "collected",
		"amount": amount,
		"balances": apply_result.get("balances", {}),
	}


func ensure_run_started(owner: Object, context: Dictionary = {}) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if _run_state.has_started():
		_sync_owner_chance_gems(owner)
		_guardian_spring_node.sync_owner_projection(owner)
		return true
	var run_id := str(context.get(
		"run_id",
		"tower-run-%d" % Time.get_ticks_msec()
	))
	var economy_variant: Variant = context.get("run_state", {})
	var economy: Dictionary = economy_variant if economy_variant is Dictionary else {}
	if not _run_state.begin(run_id, economy):
		return false
	_sync_owner_chance_gems(owner)
	_guardian_spring_node.sync_owner_projection(owner)
	return true


func has_soul_summoning() -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and _run_state.has_started()
		and _guardian_spring_node.has_soul_summoning()
	)


func record_guardian_identity_reveal(pet_id: String, registry: Object = null) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or not _run_state.has_started():
		return {
			"accepted": true,
			"handled": false,
			"tower_sealed": false,
			"reason": "tower_run_inactive",
		}
	var result: Dictionary = _guardian_spring_node.record_identity_reveal(pet_id, registry)
	_guardian_state = _guardian_spring_node.export_state()
	_guardian_spring_node.sync_owner_projection(_active_owner)
	if _active and _phase == PHASE_NODE_MODAL and _node_modal_kind == "guardian_spring":
		_refresh_guardian_spring_modal("")
	return result


func resolve_defeat(
	registry: Object,
	owner: Object,
	continue_callback: Callable,
	exit_callback: Callable
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if not _defeat_resolver.is_scoreboard_player_defeat(registry):
		return false
	if not ensure_run_started(owner):
		return false
	return _defeat_resolver.resolve(
		registry,
		owner,
		_run_state,
		continue_callback,
		exit_callback
	)


func get_header_subtitle() -> String:
	return _header_subtitle


func get_node_modal_view_model() -> Dictionary:
	if _node_modal_state == null or not _node_modal_state.has_method("build_view_model"):
		return {}
	return _node_modal_state.build_view_model()


func get_node_modal_kind() -> String:
	return _node_modal_kind


func get_generated_shop_inventory() -> Array[Dictionary]:
	return _generated_shop_inventory.duplicate(true)


func get_purchase_history() -> Array[Dictionary]:
	return _purchase_history.duplicate(true)


func get_generated_training_offers() -> Array[Dictionary]:
	return _generated_training_offers.duplicate(true)


func get_training_history() -> Array[Dictionary]:
	return _training_history.duplicate(true)


func get_generated_fallen_monk_offers() -> Array[Dictionary]:
	return _fallen_monk_node.get_generated_offers()


func get_fallen_monk_history() -> Array[Dictionary]:
	return _fallen_monk_node.get_history()


func get_guardian_spring_history() -> Array[Dictionary]:
	return _guardian_spring_node.get_history()


func get_guardian_state() -> Dictionary:
	return _guardian_spring_node.export_state()


func get_rest_history() -> Array[Dictionary]:
	return _rest_node.get_history()


func set_record_store_path_for_tests(path: String) -> void:
	_record_store.set_save_path(path)


func get_record_snapshot() -> Dictionary:
	return _record_store.get_snapshot()


func begin_floor_nine_resolution(
	resolution_id: String = "",
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if not ensure_run_started(owner):
		return {"accepted": false, "reason": "run_unavailable"}
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		normalized_resolution_id = _make_resolution_id(
			"floor_09_fake_ending",
			"ending_judgment"
		)
	var result: Dictionary = _ending_state.resolve_floor_nine(
		_run_state.get_run_id(),
		normalized_resolution_id,
		_record_store
	)
	if not bool(result.get("accepted", false)):
		return result
	if not _ending_state.is_teaser_pending():
		return result
	if not _modal_lifecycle.is_active():
		var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
		if not bool(lifecycle_result.get("accepted", false)):
			return {"accepted": false, "reason": lifecycle_result.get("reason", "modal_enter_failed")}
	_active_owner = owner
	_active_registry = registry
	_finish_callback = finish_callback
	_active = true
	_phase = PHASE_FAKE_ENDING_TEASER
	_node_modal_state.close()
	_request_redraw(owner)
	return result


func get_ending_state_snapshot() -> Dictionary:
	return _ending_state.export_state()


func get_ending_view_model() -> Dictionary:
	return _ending_state.build_teaser_view_model()


func execute_node_action(action_id: String, requested_resolution_id: String = "") -> Dictionary:
	if not _active or _phase != PHASE_NODE_MODAL:
		return {"accepted": false, "reason": "node_modal_inactive"}
	if _node_modal_kind == "shop" and action_id.begins_with("shop_purchase:"):
		return _execute_shop_purchase(
			action_id.trim_prefix("shop_purchase:"),
			requested_resolution_id
		)
	if _node_modal_kind == "training" and action_id.begins_with("training_"):
		return _execute_training_action(action_id, requested_resolution_id)
	if _node_modal_kind == "fallen_monk" and action_id.begins_with("fallen_monk:"):
		return _execute_fallen_monk_action(action_id, requested_resolution_id)
	if _node_modal_kind == "guardian_spring" and action_id.begins_with("guardian_spring:"):
		return _execute_guardian_spring_action(action_id, requested_resolution_id)
	if _node_modal_kind == "rest" and action_id.begins_with("rest:"):
		return _execute_rest_action(action_id, requested_resolution_id)
	return {"accepted": false, "reason": "unknown_node_action"}


func get_graph_edges() -> Array[Dictionary]:
	return _graph_edges


func get_selected_target_id() -> String:
	return _selected_target_id


func get_selector_origin() -> Vector2:
	return SELECTOR_ORIGIN


func get_selector_position() -> Vector2:
	return _selector_position


func get_aim_preview_point() -> Vector2:
	return Vector2(_aim_target_x, SELECTOR_TARGET_Y)


func is_selector_launched() -> bool:
	return _selector_launched


func get_map_transition_progress() -> float:
	return _map_transition_progress


func get_rest_node_position() -> Vector2:
	return _node_position(_route_source_node_id)


func get_selected_target_position() -> Vector2:
	return _node_position(_selected_target_id)


func _build_generated_graph(_current_stage: int) -> bool:
	var generated: Dictionary = _map_generator.generate_tower(
		_map_seed,
		_run_state.get_skipped_boss_ids()
	)
	var phases_variant: Variant = generated.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).size() != 1:
		return false
	_graph_phases.assign(_dictionary_array(phases_variant))
	var phase_variant: Variant = _graph_phases[0]
	if not (phase_variant is Dictionary):
		return false
	var phase := phase_variant as Dictionary
	_graph_nodes.assign(_dictionary_array(phase.get("nodes", [])))
	_graph_edges.assign(_dictionary_array(phase.get("edges", [])))
	_route_source_node_id = str(phase.get("entry_node_id", ""))
	_route_target_ids.assign(_string_array(phase.get("initial_route_candidate_ids", [])))
	var valid: bool = (
		int(phase.get("total_floors", 0)) == TowerAscentMapGenerator.TOWER_FLOOR_COUNT
		and not _route_source_node_id.is_empty()
		and _route_target_ids.size() == 2
		and _get_node(_route_source_node_id).get("kind", "") == "boss"
	)
	if valid:
		_refresh_route_target_cache()
	return valid


func _enter_route_aim() -> void:
	_node_modal_state.close()
	_phase = PHASE_ROUTE_AIM
	_reset_selector()


func _open_node_modal() -> void:
	_node_modal_state.open(
		_current_node_id,
		_node_modal_kind,
		_run_state.export_economy(),
		_build_node_modal_actions()
	)
	if _node_modal_kind == "shop" and _get_shop_inventory_entry().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_INVENTORY_UNAVAILABLE
		))
	elif _node_modal_kind == "training" and _get_training_offer_entry().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_OFFER_UNAVAILABLE
		))
	elif _node_modal_kind == "fallen_monk" and _build_fallen_monk_actions().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_MONK_OFFER_UNAVAILABLE
		))
	elif _node_modal_kind == "guardian_spring" and _build_guardian_spring_actions().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ACTION_UNAVAILABLE
		))


func _handle_node_modal_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode in [KEY_UP, KEY_W]:
			_node_modal_state.move_selection(-1)
			return
		if key_event.keycode in [KEY_DOWN, KEY_S]:
			_node_modal_state.move_selection(1)
			return
		if key_event.keycode == KEY_ESCAPE:
			_enter_route_aim()
			return
		if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_confirm_node_modal_action()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _node_modal_state.select_at_position(mouse_event.position):
				_confirm_node_modal_action()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and _node_modal_state.select_at_position(touch_event.position):
			_confirm_node_modal_action()


func _confirm_node_modal_action() -> void:
	var action: Dictionary = _node_modal_state.get_selected_action()
	if action.is_empty():
		return
	if not bool(action.get("enabled", true)):
		_node_modal_state.set_status_text(str(action.get("unavailable_reason", "")))
		return
	if str(action.get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK:
		_enter_route_aim()
		return
	var action_result := execute_node_action(str(action.get("id", "")))
	if not bool(action_result.get("accepted", false)):
		_node_modal_state.set_status_text(str(action_result.get("message", action_result.get("reason", ""))))


func _build_node_modal_actions() -> Array[Dictionary]:
	if _node_modal_kind == "shop":
		return _build_shop_actions()
	if _node_modal_kind == "training":
		return _build_training_actions()
	if _node_modal_kind == "fallen_monk":
		return _build_fallen_monk_actions()
	if _node_modal_kind == "guardian_spring":
		return _build_guardian_spring_actions()
	if _node_modal_kind == "rest":
		return _build_rest_actions()
	return []


func _build_shop_actions() -> Array[Dictionary]:
	var inventory := _get_or_create_shop_inventory()
	if inventory.is_empty():
		return []
	var balances: Dictionary = _run_state.export_economy()
	var result: Array[Dictionary] = []
	for stock_value in inventory.get("stock", []):
		if not (stock_value is Dictionary):
			continue
		var stock := stock_value as Dictionary
		var sold := bool(stock.get("sold", false))
		var price := maxi(0, int(stock.get("price", 0)))
		var affordable := int(balances.get("gold", 0)) >= price
		var gem_full := (
			str(stock.get("kind", "")) == "chance_gem"
			and int(balances.get("chance_gems", 0)) >= TowerAscentRunState.MAX_CHANCE_GEMS
		)
		var enabled := not sold and affordable and not gem_full
		var unavailable_reason := ""
		if sold:
			unavailable_reason = TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_SOLD_OUT
			)
		elif gem_full:
			unavailable_reason = TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_GEM_FULL
			)
		elif not affordable:
			unavailable_reason = TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_GOLD,
				{
					"required": price,
					"shortfall": price - int(balances.get("gold", 0)),
				}
			)
		result.append({
			"id": "shop_purchase:%s" % str(stock.get("stock_id", "")),
			"label": _shop_stock_label(stock),
			"cost_text": (
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SHOP_SOLD_OUT
				)
				if sold
				else TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_COST_GOLD,
					{"amount": price}
				)
			),
			"enabled": enabled,
			"unavailable_reason": unavailable_reason,
			"payload": {"stock_id": str(stock.get("stock_id", ""))},
		})
	return result


func _shop_stock_label(stock: Dictionary) -> String:
	match str(stock.get("kind", "")):
		"premium":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_PREMIUM_ITEM,
				{"name": str(stock.get("display_name", ""))}
			)
		"capsule":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE
			)
		"chance_gem":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_CHANCE_GEM
			)
	return str(stock.get("display_name", stock.get("item_name", "")))


func _execute_shop_purchase(stock_id: String, requested_resolution_id: String = "") -> Dictionary:
	var stock := _find_shop_stock(stock_id)
	if stock.is_empty():
		return {"accepted": false, "reason": "unknown_shop_stock"}
	if bool(stock.get("sold", false)):
		return {"accepted": false, "reason": "sold_out"}
	var price := maxi(0, int(stock.get("price", 0)))
	var affordability: Dictionary = _run_state.can_afford({"gold": price})
	if not bool(affordability.get("accepted", false)):
		_refresh_shop_modal(str(affordability.get("reason", "insufficient_gold")))
		return affordability
	var stock_kind := str(stock.get("kind", ""))
	if stock_kind == "chance_gem" and _run_state.get_chance_gems() >= TowerAscentRunState.MAX_CHANCE_GEMS:
		var gem_full_result := {
			"accepted": false,
			"reason": "chance_gems_full",
			"message": TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_GEM_FULL
			),
		}
		_refresh_shop_modal(str(gem_full_result.message))
		return gem_full_result
	var item_name := str(stock.get("item_name", ""))
	var effect_callback := Callable()
	var rollback_callback := Callable()
	var rewards := {}
	if stock_kind == "chance_gem":
		rewards = {"chance_gems": 1}
	else:
		effect_callback = Callable(self, "_grant_shop_active_item").bind(item_name)
		rollback_callback = Callable(self, "_rollback_shop_active_item").bind(item_name)
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(
			_current_node_id,
			"shop_purchase:%s" % stock_id
		)
	var transaction_result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{"gold": price},
		rewards,
		_run_state,
		_resolution_ids,
		effect_callback,
		rollback_callback
	)
	if not bool(transaction_result.get("accepted", false)) or not bool(transaction_result.get("applied", false)):
		var message := (
			TowerAscentNodeModalLocalization.text(TowerAscentNodeModalLocalization.KEY_SHOP_SLOT_FULL)
			if str(transaction_result.get("reason", "")) == "effect_rejected"
			else str(transaction_result.get("reason", "purchase_failed"))
		)
		transaction_result["message"] = message
		_refresh_shop_modal(message)
		return transaction_result
	stock["sold"] = true
	var purchase := {
		"node_id": _current_node_id,
		"node_resolution_id": resolution_id,
		"stock_id": stock_id,
		"kind": stock_kind,
		"item_name": item_name,
		"price": price,
	}
	_purchase_history.append(purchase)
	if stock_kind != "chance_gem":
		var active_items: Array = _build_state.get("active_items", [])
		active_items.append({
			"item_name": item_name,
			"node_resolution_id": resolution_id,
		})
		_build_state["active_items"] = active_items
	_sync_owner_chance_gems(_active_owner)
	var purchased_name := (
		TowerAscentNodeModalLocalization.text(TowerAscentNodeModalLocalization.KEY_SHOP_CHANCE_GEM)
		if stock_kind == "chance_gem"
		else str(stock.get("display_name", item_name))
	)
	var success_message := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SHOP_PURCHASED,
		{"name": purchased_name}
	)
	_refresh_shop_modal(success_message)
	transaction_result["purchase"] = purchase.duplicate(true)
	transaction_result["message"] = success_message
	return transaction_result


func _get_or_create_shop_inventory() -> Dictionary:
	var existing := _get_shop_inventory_entry()
	if not existing.is_empty():
		return existing
	var generated: Dictionary = _shop_inventory_builder.build_inventory(
		_current_node_id,
		_map_seed,
		_active_owner,
		_active_registry
	)
	if not bool(generated.get("accepted", false)):
		return {}
	_generated_shop_inventory.append(generated)
	return _generated_shop_inventory.back()


func _get_shop_inventory_entry() -> Dictionary:
	for inventory in _generated_shop_inventory:
		if str(inventory.get("node_id", "")) == _current_node_id:
			return inventory
	return {}


func _find_shop_stock(stock_id: String) -> Dictionary:
	var inventory := _get_or_create_shop_inventory()
	for stock_value in inventory.get("stock", []):
		if stock_value is Dictionary and str((stock_value as Dictionary).get("stock_id", "")) == stock_id:
			return stock_value as Dictionary
	return {}


func _grant_shop_active_item(item_name: String) -> bool:
	var runtime := _get_registry_instance(_active_registry, "active_item_runtime")
	return (
		runtime != null
		and runtime.has_method("grant_item_to_slot")
		and bool(runtime.call("grant_item_to_slot", item_name, _active_owner, _active_registry, false))
	)


func _rollback_shop_active_item(item_name: String) -> void:
	var runtime := _get_registry_instance(_active_registry, "active_item_runtime")
	if runtime != null and runtime.has_method("debug_remove_item_from_slot"):
		runtime.call("debug_remove_item_from_slot", item_name, _active_owner, _active_registry)


func _refresh_shop_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_shop_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)


func _build_training_actions() -> Array[Dictionary]:
	var offer := _get_or_create_training_offer()
	if offer.is_empty():
		return []
	var balances: Dictionary = _run_state.export_economy()
	var used_count := _get_training_use_count(_current_node_id)
	var visit_complete := used_count >= TowerAscentTuning.TEMP_PHASE_C_TRAINING_USES_PER_VISIT
	var consumed_ids := _get_consumed_training_choice_ids(_current_node_id)
	var result: Array[Dictionary] = []
	for choice_value in offer.get("stat_choices", []):
		if choice_value is Dictionary:
			result.append(_build_training_action(
				"stat",
				choice_value as Dictionary,
				TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST,
				balances,
				visit_complete,
				consumed_ids
			))
	for choice_value in offer.get("mugong_choices", []):
		if choice_value is Dictionary:
			result.append(_build_training_action(
				"mugong",
				choice_value as Dictionary,
				TowerAscentTuning.TEMP_PHASE_C_TRAINING_MUGONG_COST,
				balances,
				visit_complete,
				consumed_ids
			))
	return result


func _build_training_action(
	choice_kind: String,
	choice: Dictionary,
	cost: int,
	balances: Dictionary,
	visit_complete: bool,
	consumed_ids: Dictionary
) -> Dictionary:
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var action_id := "training_%s:%s" % [choice_kind, choice_id]
	var consumed := consumed_ids.has("%s:%s" % [choice_kind, choice_id])
	var affordable := int(balances.get("muhon", 0)) >= cost
	var enabled := not visit_complete and not consumed and affordable
	var unavailable_reason := ""
	if visit_complete:
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_VISIT_COMPLETE
		)
	elif consumed:
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_CHOICE_USED
		)
	elif not affordable:
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": cost - int(balances.get("muhon", 0)),
			}
		)
	var display_name := str(choice.get("name", choice_id))
	var label_key := (
		TowerAscentNodeModalLocalization.KEY_TRAINING_STAT_OPTION
		if choice_kind == "stat"
		else TowerAscentNodeModalLocalization.KEY_TRAINING_MUGONG_OPTION
	)
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(
			label_key,
			{"name": display_name}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_MUHON,
			{"amount": cost}
		),
		"enabled": enabled,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"choice_kind": choice_kind,
			"choice_id": choice_id,
		},
	}


func _execute_training_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var parsed := _parse_training_action_id(action_id)
	if parsed.is_empty():
		return {"accepted": false, "reason": "invalid_training_action"}
	if _get_training_use_count(_current_node_id) >= TowerAscentTuning.TEMP_PHASE_C_TRAINING_USES_PER_VISIT:
		var complete_message := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_VISIT_COMPLETE
		)
		_refresh_training_modal(complete_message)
		return {
			"accepted": false,
			"reason": "training_visit_complete",
			"message": complete_message,
		}
	var choice_kind := str(parsed.get("choice_kind", ""))
	var choice_id := str(parsed.get("choice_id", ""))
	if _get_consumed_training_choice_ids(_current_node_id).has("%s:%s" % [choice_kind, choice_id]):
		return {"accepted": false, "reason": "training_choice_used"}
	var choice := _find_training_choice(choice_kind, choice_id)
	if choice.is_empty():
		return {"accepted": false, "reason": "unknown_training_choice"}
	var cost := (
		TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST
		if choice_kind == "stat"
		else TowerAscentTuning.TEMP_PHASE_C_TRAINING_MUGONG_COST
	)
	var affordability: Dictionary = _run_state.can_afford({"muhon": cost})
	if not bool(affordability.get("accepted", false)):
		var insufficient_message := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": int(affordability.get("shortfall", cost)),
			}
		)
		affordability["message"] = insufficient_message
		_refresh_training_modal(insufficient_message)
		return affordability
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var transaction_result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{"muhon": cost},
		{},
		_run_state,
		_resolution_ids,
		Callable(self, "_grant_training_choice").bind(choice),
		Callable(self, "_rollback_training_choice")
	)
	_pending_runtime_perk_rollback_snapshot.clear()
	if not bool(transaction_result.get("accepted", false)) or not bool(transaction_result.get("applied", false)):
		var failed_message := str(transaction_result.get("reason", "training_failed"))
		transaction_result["message"] = failed_message
		_refresh_training_modal(failed_message)
		return transaction_result
	var display_name := str(choice.get("name", choice_id))
	var record := {
		"node_id": _current_node_id,
		"node_resolution_id": resolution_id,
		"choice_kind": choice_kind,
		"choice_id": choice_id,
		"display_name": display_name,
		"cost": cost,
	}
	_training_history.append(record)
	_capture_runtime_perk_build_state()
	var build_key := "mugong" if choice_kind == "mugong" else "training"
	var build_entries: Array = _build_state.get(build_key, [])
	build_entries.append(record.duplicate(true))
	_build_state[build_key] = build_entries
	var success_message := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_TRAINING_COMPLETED,
		{"name": display_name}
	)
	_refresh_training_modal(success_message)
	transaction_result["training"] = record.duplicate(true)
	transaction_result["message"] = success_message
	return transaction_result


func _get_or_create_training_offer() -> Dictionary:
	var existing := _get_training_offer_entry()
	if not existing.is_empty():
		return existing
	var generated: Dictionary = _training_offer_builder.build_offer(
		_current_node_id,
		_map_seed,
		_active_owner,
		_active_registry
	)
	if not bool(generated.get("accepted", false)):
		return {}
	_generated_training_offers.append(generated)
	return _generated_training_offers.back()


func _get_training_offer_entry() -> Dictionary:
	for offer in _generated_training_offers:
		if str(offer.get("node_id", "")) == _current_node_id:
			return offer
	return {}


func _find_training_choice(choice_kind: String, choice_id: String) -> Dictionary:
	var offer := _get_or_create_training_offer()
	var list_key := "stat_choices" if choice_kind == "stat" else "mugong_choices"
	for choice_value in offer.get(list_key, []):
		if (
			choice_value is Dictionary
			and str((choice_value as Dictionary).get("id", (choice_value as Dictionary).get("perk_id", ""))) == choice_id
		):
			return choice_value as Dictionary
	return {}


func _parse_training_action_id(action_id: String) -> Dictionary:
	for choice_kind in ["stat", "mugong"]:
		var prefix := "training_%s:" % choice_kind
		if action_id.begins_with(prefix):
			var choice_id := action_id.trim_prefix(prefix).strip_edges()
			if not choice_id.is_empty():
				return {"choice_kind": choice_kind, "choice_id": choice_id}
	return {}


func _get_training_use_count(node_id: String) -> int:
	var count := 0
	for record in _training_history:
		if str(record.get("node_id", "")) == node_id:
			count += 1
	return count


func _get_consumed_training_choice_ids(node_id: String) -> Dictionary:
	var result := {}
	for record in _training_history:
		if str(record.get("node_id", "")) != node_id:
			continue
		result["%s:%s" % [
			str(record.get("choice_kind", "")),
			str(record.get("choice_id", "")),
		]] = true
	return result


func _grant_training_choice(choice: Dictionary) -> bool:
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("apply_choice"):
		return false
	_pending_runtime_perk_rollback_snapshot.clear()
	if runtime_state.has_method("build_unlock_save_snapshot"):
		var snapshot_value: Variant = runtime_state.call("build_unlock_save_snapshot")
		if snapshot_value is Dictionary:
			_pending_runtime_perk_rollback_snapshot = (snapshot_value as Dictionary).duplicate(true)
	return bool(runtime_state.call("apply_choice", choice, _active_owner, _active_registry))


func _rollback_training_choice() -> void:
	if _pending_runtime_perk_rollback_snapshot.is_empty():
		return
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("apply_unlock_save_snapshot"):
		runtime_state.call(
			"apply_unlock_save_snapshot",
			_pending_runtime_perk_rollback_snapshot,
			_active_owner,
			_active_registry
		)


func _capture_runtime_perk_build_state() -> void:
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("build_unlock_save_snapshot"):
		return
	var snapshot_value: Variant = runtime_state.call("build_unlock_save_snapshot")
	if snapshot_value is Dictionary:
		_build_state["runtime_perk_snapshot"] = (snapshot_value as Dictionary).duplicate(true)


func _restore_runtime_perk_build_state(owner: Object, registry: Object) -> bool:
	var snapshot_value: Variant = _build_state.get("runtime_perk_snapshot", {})
	if not (snapshot_value is Dictionary) or (snapshot_value as Dictionary).is_empty():
		return true
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("apply_unlock_save_snapshot"):
		return false
	var result_value: Variant = runtime_state.call(
		"apply_unlock_save_snapshot",
		snapshot_value as Dictionary,
		owner,
		registry
	)
	return result_value is Dictionary and bool((result_value as Dictionary).get("restored", false))


func _refresh_training_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_training_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)


func _build_fallen_monk_actions() -> Array[Dictionary]:
	return _fallen_monk_node.build_actions(
		_current_node_id,
		_map_seed,
		_run_state,
		_active_owner,
		_active_registry
	)


func _execute_fallen_monk_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var result: Dictionary = _fallen_monk_node.execute_action(
		action_id,
		resolution_id,
		_current_node_id,
		_map_seed,
		_run_state,
		_resolution_ids,
		_node_action_transaction,
		_active_owner,
		_active_registry
	)
	if bool(result.get("accepted", false)) and bool(result.get("applied", false)):
		_build_state["chosik"] = _fallen_monk_node.get_history()
		_build_state["runtime_perk_snapshot"] = _fallen_monk_node.get_runtime_snapshot()
	_refresh_fallen_monk_modal(str(result.get("message", result.get("reason", ""))))
	return result


func _refresh_fallen_monk_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_fallen_monk_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)


func _build_guardian_spring_actions() -> Array[Dictionary]:
	return _guardian_spring_node.build_actions(
		_current_node_id,
		_map_seed,
		_run_state,
		_active_owner,
		_active_registry
	)


func _execute_guardian_spring_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var result: Dictionary = _guardian_spring_node.execute_action(
		action_id,
		resolution_id,
		_current_node_id,
		_map_seed,
		_run_state,
		_resolution_ids,
		_node_action_transaction,
		_active_owner,
		_active_registry
	)
	_guardian_state = _guardian_spring_node.export_state()
	_guardian_spring_node.sync_owner_projection(_active_owner)
	_refresh_guardian_spring_modal(str(result.get("message", result.get("reason", ""))))
	return result


func _refresh_guardian_spring_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_guardian_spring_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)


func _build_rest_actions() -> Array[Dictionary]:
	return _rest_node.build_actions(_current_node_id, _run_state)


func _execute_rest_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var result: Dictionary = _rest_node.execute_action(
		action_id,
		resolution_id,
		_current_node_id,
		_run_state,
		_resolution_ids,
		_node_action_transaction
	)
	_sync_owner_chance_gems(_active_owner)
	_refresh_rest_modal(str(result.get("message", result.get("reason", ""))))
	return result


func _refresh_rest_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_rest_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null


func _set_aim_target(x_value: float) -> void:
	if _selector_launched:
		return
	_aim_target_x = clampf(x_value, SELECTOR_LEFT_WALL, SELECTOR_RIGHT_WALL)


func _launch_selector() -> void:
	if _selector_launched:
		return
	var direction := (Vector2(_aim_target_x, SELECTOR_TARGET_Y) - SELECTOR_ORIGIN).normalized()
	_selector_velocity = direction * SELECTOR_SPEED
	_selector_launched = true


func _update_selector(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0 and _selector_launched and _phase == PHASE_ROUTE_AIM:
		var step := minf(remaining, 1.0 / 120.0)
		remaining -= step
		_selector_position += _selector_velocity * step
		if _selector_position.x - SELECTOR_RADIUS <= SELECTOR_LEFT_WALL:
			_selector_position.x = SELECTOR_LEFT_WALL + SELECTOR_RADIUS
			_selector_velocity.x = absf(_selector_velocity.x)
		elif _selector_position.x + SELECTOR_RADIUS >= SELECTOR_RIGHT_WALL:
			_selector_position.x = SELECTOR_RIGHT_WALL - SELECTOR_RADIUS
			_selector_velocity.x = -absf(_selector_velocity.x)
		if _try_hit_route_target():
			return
		if _selector_position.y <= SELECTOR_RESET_Y:
			_reset_selector()
			return


func _try_hit_route_target() -> bool:
	for target_index in range(_route_target_ids.size()):
		var target_id := _route_target_ids[target_index]
		if not get_route_target_ids().has(target_id):
			continue
		if _selector_position.distance_to(_route_target_aim_position(target_index)) <= 49.0:
			_resolve_route_target(target_id)
			return true
	return false


func _resolve_route_target(target_id: String) -> void:
	if not get_route_target_ids().has(target_id):
		return
	_selected_target_id = target_id
	_commit_node_resolution(_route_source_node_id, "route_selected", {"target_node_id": target_id})
	for candidate_id in _route_target_ids:
		if candidate_id == target_id:
			continue
		var skipped_node := _get_node(candidate_id)
		var skipped_slot_id := str(skipped_node.get("boss_slot_id", ""))
		if (
			str(skipped_node.get("kind", "")) in TowerAscentRouteCandidatePolicy.COMBAT_NODE_KINDS
			and _run_state.mark_boss_skipped(skipped_slot_id)
		):
			_mark_boss_slot_skipped_in_graph(skipped_slot_id)
	_route_history.append({"from": _route_source_node_id, "to": target_id})
	_current_node_id = target_id
	_phase = PHASE_MAP_TRANSITION
	_map_transition_progress = 0.0
	_selector_launched = false
	_selector_velocity = Vector2.ZERO


func _commit_node_resolution(
	node_id: String,
	resolution_kind: String,
	payload: Dictionary,
	requested_resolution_id: String = ""
) -> bool:
	var resolution_id := requested_resolution_id
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(node_id, resolution_kind)
	if _resolution_ids.has(resolution_id):
		return false
	_resolution_ids[resolution_id] = true
	_completed_nodes.append({
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"resolution_kind": resolution_kind,
		"payload": payload.duplicate(true),
	})
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			node["completed"] = true
			break
	return true


func _complete_prepared_combat_resolution() -> bool:
	var pending := _find_pending_reward(_prepared_resolution_id)
	if pending.is_empty():
		return false
	var apply_result: Dictionary = _resolution_transaction.apply_once(
		pending,
		_run_state,
		_resolution_ids
	)
	if not bool(apply_result.get("accepted", false)):
		return false
	var committed := _commit_node_resolution(
		str(pending.get("node_id", _route_source_node_id)),
		str(pending.get("resolution_kind", "combat_victory")),
		{
			"reward_source": pending.get("reward_source", "victory_loot_phase"),
			"reward_status": apply_result.get("reason", "reward_applied"),
			"reward_bundle": pending.get("reward_bundle", {}),
		},
		_prepared_resolution_id
	)
	if not committed and not _resolution_ids.has(_prepared_resolution_id):
		return false
	_resolution_transaction.mark_committed(_prepared_resolution_id)
	_remove_pending_reward(_prepared_resolution_id)
	return true


func _find_pending_reward(resolution_id: String) -> Dictionary:
	for pending in _pending_rewards:
		if str(pending.get("node_resolution_id", "")) == resolution_id:
			return pending
	return {}


func _remove_pending_reward(resolution_id: String) -> void:
	for index in range(_pending_rewards.size() - 1, -1, -1):
		if str(_pending_rewards[index].get("node_resolution_id", "")) == resolution_id:
			_pending_rewards.remove_at(index)


func _make_resolution_id(node_id: String, resolution_kind: String) -> String:
	return "%s:%s:%s" % [_run_state.get_run_id(), node_id, resolution_kind]


func _finish_vertical_slice() -> void:
	var callback := _finish_callback
	_finish_callback = Callable()
	_modal_lifecycle.leave()
	_node_modal_state.close()
	_active_owner = null
	_active_registry = null
	_active = false
	_map_seed = 0
	_phase = PHASE_COMBAT
	if callback.is_valid():
		callback.call()


func _dismiss_fake_ending_teaser() -> void:
	var result: Dictionary = _ending_state.mark_teaser_presented()
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return
	_finish_vertical_slice()


func _reset_selector() -> void:
	_selector_position = SELECTOR_ORIGIN
	_selector_velocity = Vector2.ZERO
	_selector_launched = false
	_aim_target_x = 220.0


func _reset_runtime_state() -> void:
	_modal_lifecycle.leave()
	_node_modal_state.close()
	_active_owner = null
	_active_registry = null
	_active = false
	_prepared = false
	_prepared_resolution_id = ""
	_phase = PHASE_COMBAT
	_run_state.reset()
	_header_subtitle = ""
	_graph_phases.clear()
	_graph_nodes.clear()
	_graph_edges.clear()
	_current_node_id = ""
	_completed_nodes.clear()
	_resolution_ids.clear()
	_resolution_transaction.reset()
	_pending_rewards.clear()
	_generated_shop_inventory.clear()
	_purchase_history.clear()
	_generated_training_offers.clear()
	_training_history.clear()
	_fallen_monk_node.reset()
	_guardian_spring_node.reset()
	_rest_node.reset()
	_ending_state.reset()
	_pending_runtime_perk_rollback_snapshot.clear()
	_claimed_decoration_ids.clear()
	_build_state = {
		"mugong": [],
		"chosik": [],
		"active_items": [],
		"mythic": {},
	}
	_guardian_state = {
		"soul_summoning_owned": false,
		"soul_summoning_node_id": "",
		"active_guardian": {},
		"sealed_guardians": [],
		"history": [],
		"runtime_snapshot": {},
	}
	_gameplay_rng_state = {"seed": 140913, "state": 140913}
	_route_history.clear()
	_route_source_node_id = ""
	_route_target_ids.clear()
	_available_route_target_ids.clear()
	_route_aim_targets_cache.clear()
	_node_modal_kind = "guardian_spring"
	_selected_target_id = ""
	_map_transition_progress = 0.0
	_finish_callback = Callable()
	_reset_selector()


func _node_position(node_id: String) -> Vector2:
	var node := _get_node(node_id)
	if not node.is_empty():
		return _vector2(node.get("position", Vector2.ZERO))
	return Vector2.ZERO


func _get_node(node_id: String) -> Dictionary:
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _route_target_aim_position(target_index: int) -> Vector2:
	return Vector2(220.0 if target_index <= 0 else 540.0, SELECTOR_TARGET_Y)


func _mark_boss_slot_skipped_in_graph(boss_slot_id: String) -> void:
	if boss_slot_id.is_empty():
		return
	for node in _graph_nodes:
		if str(node.get("boss_slot_id", "")) == boss_slot_id:
			node["route_disabled"] = true
			node["skipped"] = true
	_refresh_route_target_cache()


func _refresh_route_target_cache() -> void:
	_available_route_target_ids.assign(_route_candidate_policy.filter_available(
		_graph_nodes,
		_route_target_ids,
		_run_state.get_skipped_boss_ids()
	))
	_route_aim_targets_cache.clear()
	for raw_index in range(_route_target_ids.size()):
		var target_id := _route_target_ids[raw_index]
		if not _available_route_target_ids.has(target_id):
			continue
		var node := _get_node(target_id)
		_route_aim_targets_cache.append({
			"id": target_id,
			"label": str(node.get("label", "행로")),
			"kind": str(node.get("kind", "")),
			"enraged": bool(node.get("enraged", false)),
			"position": _route_target_aim_position(raw_index),
			"map_position": _node_position(target_id),
		})


func _sync_run_state_phases() -> void:
	if _graph_nodes.is_empty():
		return
	var phase := (
		_graph_phases[0].duplicate(true)
		if not _graph_phases.is_empty()
		else {"id": "phase_01"}
	)
	phase["nodes"] = _graph_nodes.duplicate(true)
	phase["edges"] = _graph_edges.duplicate(true)
	_graph_phases = [phase]
	_run_state.set_phases(_graph_phases)


func _dictionary_copy(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _get_owner_int(owner: Object, property_name: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else int(value)


func _is_confirm_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _request_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _sync_owner_chance_gems(owner: Object) -> void:
	if owner == null:
		return
	owner.set("chance_gems_count", _run_state.get_chance_gems())
	owner.set("chance_gems_max", TowerAscentRunState.MAX_CHANCE_GEMS)


func _derive_map_seed(run_id: String, current_stage: int) -> int:
	return absi(hash("%s:%d:%s" % [run_id, current_stage, MAP_GENERATOR_VERSION]))


func _normalize_node_modal_kind(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["shop", "training", "fallen_monk", "guardian_spring", "rest", "common_shell"]:
		return normalized
	return "common_shell"


func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
