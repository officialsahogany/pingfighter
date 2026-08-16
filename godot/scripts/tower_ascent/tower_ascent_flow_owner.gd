extends RefCounted

const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerAscentFlowRenderer := preload("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
const TowerAscentRunState := preload("res://scripts/tower_ascent/tower_ascent_run_state.gd")
const TowerAscentNodeResolutionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_resolution_transaction.gd"
)

const SNAPSHOT_SCHEMA_VERSION := TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION
const MAP_GENERATOR_VERSION := "fixed_vertical_slice_v1"
const PHASE_COMBAT := 0
const PHASE_NODE_MODAL := 1
const PHASE_ROUTE_AIM := 2
const PHASE_MAP_TRANSITION := 3
const MAP_TRANSITION_SECONDS := 0.9
const SELECTOR_RADIUS := 11.0
const SELECTOR_SPEED := 520.0
const SELECTOR_ORIGIN := Vector2(380.0, 665.0)
const SELECTOR_TARGET_Y := 165.0
const SELECTOR_LEFT_WALL := 52.0
const SELECTOR_RIGHT_WALL := 708.0
const SELECTOR_RESET_Y := 92.0
const ROUTE_TARGET_IDS := ["boss_left_02", "boss_right_02"]

var _active := false
var _prepared := false
var _prepared_resolution_id := ""
var _phase := PHASE_COMBAT
var _graph_nodes: Array[Dictionary] = []
var _graph_edges: Array[Dictionary] = []
var _current_node_id := ""
var _completed_nodes: Array[Dictionary] = []
var _resolution_ids: Dictionary = {}
var _skipped_boss_ids: Array[String] = []
var _pending_rewards: Array[Dictionary] = []
var _run_state: Object = TowerAscentRunState.new()
var _resolution_transaction: Object = TowerAscentNodeResolutionTransaction.new()
var _generated_shop_inventory: Array[Dictionary] = []
var _purchase_history: Array[Dictionary] = []
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
var _selected_target_id := ""
var _selector_position := SELECTOR_ORIGIN
var _selector_velocity := Vector2.ZERO
var _selector_launched := false
var _aim_target_x := 220.0
var _map_transition_progress := 0.0
var _finish_callback := Callable()
var _renderer: Object = TowerAscentFlowRenderer.new()
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
	_finish_callback = finish_callback
	if not _complete_prepared_combat_resolution():
		return false
	_prepared = false
	_prepared_resolution_id = ""
	_active = true
	_phase = PHASE_NODE_MODAL
	_current_node_id = "rest_01"
	_request_redraw(owner)
	return true


func prepare_vertical_slice_combat(owner: Object, context: Dictionary = {}) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or _active:
		return false
	if _prepared:
		return true
	_reset_runtime_state()
	var run_id := str(context.get("run_id", "vertical-slice-%d" % Time.get_ticks_msec()))
	var economy_variant: Variant = context.get("run_state", {})
	var economy: Dictionary = economy_variant if economy_variant is Dictionary else {}
	if not _run_state.begin(run_id, economy):
		return false
	_header_subtitle = "고정 그래프 검증판 · %s" % _run_state.get_run_id()
	_build_fixed_graph(int(context.get("current_stage", _get_owner_int(owner, "current_stage", 1))))
	_sync_run_state_phases()
	_prepared_resolution_id = _make_resolution_id("combat_01", "combat_victory")
	var reward_bundle_variant: Variant = context.get("node_reward_bundle", {})
	var reward_bundle: Dictionary = reward_bundle_variant if reward_bundle_variant is Dictionary else {}
	var pending: Dictionary = _resolution_transaction.prepare(
		_run_state.get_run_id(),
		"combat_01",
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


func restore_snapshot(snapshot: Dictionary, finish_callback: Callable = Callable()) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if not bool(snapshot.get("stable_boundary", false)):
		return false
	if str(snapshot.get("map_generator_version", "")) != MAP_GENERATOR_VERSION:
		return false
	_reset_runtime_state()
	if not _run_state.restore_snapshot(snapshot):
		return false
	var phases: Array[Dictionary] = _run_state.get_phases()
	var graph: Dictionary = phases[0]
	var nodes_variant: Variant = graph.get("nodes", [])
	var edges_variant: Variant = graph.get("edges", [])
	if not (nodes_variant is Array) or (nodes_variant as Array).size() < 4:
		return false
	if not (edges_variant is Array) or (edges_variant as Array).size() < 3:
		return false
	_header_subtitle = "고정 그래프 검증판 · %s" % _run_state.get_run_id()
	_graph_nodes.assign((nodes_variant as Array).duplicate(true))
	_graph_edges.assign((edges_variant as Array).duplicate(true))
	_current_node_id = str(snapshot.get("current_node_id", ""))
	_completed_nodes.assign(_dictionary_array(snapshot.get("completed_nodes", [])))
	for entry in _completed_nodes:
		_resolution_ids[str(entry.get("node_resolution_id", ""))] = true
	_skipped_boss_ids.assign(_string_array(snapshot.get("skipped_boss_ids", [])))
	_pending_rewards.assign(_dictionary_array(snapshot.get("pending_rewards", [])))
	_generated_shop_inventory.assign(_dictionary_array(snapshot.get("generated_shop_inventory", [])))
	_purchase_history.assign(_dictionary_array(snapshot.get("purchase_history", [])))
	_claimed_decoration_ids.assign(_string_array(snapshot.get("claimed_decoration_ids", [])))
	_build_state = _dictionary_copy(snapshot.get("build_state", {}))
	_guardian_state = _dictionary_copy(snapshot.get("guardian_state", {}))
	_gameplay_rng_state = _dictionary_copy(snapshot.get("gameplay_rng_state", {}))
	_route_history.assign(_dictionary_array(snapshot.get("route_history", [])))
	_selected_target_id = str(snapshot.get("selected_target_id", ""))
	_phase = clampi(int(snapshot.get("phase", PHASE_NODE_MODAL)), PHASE_NODE_MODAL, PHASE_MAP_TRANSITION)
	_selector_position = snapshot.get("selector_position", SELECTOR_ORIGIN)
	_selector_velocity = snapshot.get("selector_velocity", Vector2.ZERO)
	_selector_launched = bool(snapshot.get("selector_launched", false))
	_aim_target_x = clampf(float(snapshot.get("aim_target_x", 220.0)), SELECTOR_LEFT_WALL, SELECTOR_RIGHT_WALL)
	_map_transition_progress = clampf(float(snapshot.get("map_transition_progress", 0.0)), 0.0, 1.0)
	_finish_callback = finish_callback
	_active = true
	_prepared = false
	_prepared_resolution_id = ""
	return true


func export_snapshot() -> Dictionary:
	_sync_run_state_phases()
	var snapshot: Dictionary = _run_state.export_snapshot_fields()
	snapshot.merge({
		"map_generator_version": MAP_GENERATOR_VERSION,
		"current_node_id": _current_node_id,
		"completed_nodes": _completed_nodes.duplicate(true),
		"skipped_boss_ids": _skipped_boss_ids.duplicate(),
		"pending_rewards": _pending_rewards.duplicate(true),
		"generated_shop_inventory": _generated_shop_inventory.duplicate(true),
		"purchase_history": _purchase_history.duplicate(true),
		"claimed_decoration_ids": _claimed_decoration_ids.duplicate(),
		"build_state": _build_state.duplicate(true),
		"guardian_state": _guardian_state.duplicate(true),
		"gameplay_rng_state": _gameplay_rng_state.duplicate(true),
		"route_history": _route_history.duplicate(true),
		"selected_target_id": _selected_target_id,
		"phase": _phase,
		"selector_position": _selector_position,
		"selector_velocity": _selector_velocity,
		"selector_launched": _selector_launched,
		"aim_target_x": _aim_target_x,
		"map_transition_progress": _map_transition_progress,
		"stable_boundary": _phase == PHASE_NODE_MODAL or _phase == PHASE_MAP_TRANSITION,
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
	return "COMBAT"


func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if _phase == PHASE_NODE_MODAL:
		if _is_confirm_event(event):
			_enter_route_aim()
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
	_set_aim_target(220.0 if target_index <= 0 else 540.0)
	_launch_selector()


func debug_launch_miss() -> void:
	if not _active or _phase != PHASE_ROUTE_AIM:
		return
	_set_aim_target(380.0)
	_launch_selector()


func get_graph_nodes() -> Array[Dictionary]:
	return _graph_nodes


func get_run_id() -> String:
	return _run_state.get_run_id()


func get_run_state_snapshot() -> Dictionary:
	return _run_state.export_economy()


func get_header_subtitle() -> String:
	return _header_subtitle


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
	return _node_position("rest_01")


func get_selected_target_position() -> Vector2:
	return _node_position(_selected_target_id)


func _build_fixed_graph(current_stage: int) -> void:
	_graph_nodes = [
		{"id": "combat_01", "kind": "boss", "label": "보스 %d" % maxi(1, current_stage), "position": Vector2(380.0, 590.0), "completed": false},
		{"id": "rest_01", "kind": "rest", "label": "샘터", "position": Vector2(380.0, 430.0), "completed": false},
		{"id": "boss_left_02", "kind": "boss_fixture", "label": "왼길", "position": Vector2(220.0, SELECTOR_TARGET_Y), "completed": false},
		{"id": "boss_right_02", "kind": "boss_fixture", "label": "오른길", "position": Vector2(540.0, SELECTOR_TARGET_Y), "completed": false},
	]
	_graph_edges = [
		{"from": "combat_01", "to": "rest_01"},
		{"from": "rest_01", "to": "boss_left_02"},
		{"from": "rest_01", "to": "boss_right_02"},
	]


func _enter_route_aim() -> void:
	_phase = PHASE_ROUTE_AIM
	_reset_selector()


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
	for target_id in ROUTE_TARGET_IDS:
		if _selector_position.distance_to(_node_position(target_id)) <= 49.0:
			_resolve_route_target(target_id)
			return true
	return false


func _resolve_route_target(target_id: String) -> void:
	_selected_target_id = target_id
	_commit_node_resolution("rest_01", "route_selected", {"target_node_id": target_id})
	for candidate_id in ROUTE_TARGET_IDS:
		if candidate_id != target_id and not _skipped_boss_ids.has(candidate_id):
			_skipped_boss_ids.append(candidate_id)
	_route_history.append({"from": "rest_01", "to": target_id})
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
		str(pending.get("node_id", "combat_01")),
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
	_active = false
	_phase = PHASE_COMBAT
	if callback.is_valid():
		callback.call()


func _reset_selector() -> void:
	_selector_position = SELECTOR_ORIGIN
	_selector_velocity = Vector2.ZERO
	_selector_launched = false
	_aim_target_x = 220.0


func _reset_runtime_state() -> void:
	_active = false
	_prepared = false
	_prepared_resolution_id = ""
	_phase = PHASE_COMBAT
	_run_state.reset()
	_header_subtitle = ""
	_graph_nodes.clear()
	_graph_edges.clear()
	_current_node_id = ""
	_completed_nodes.clear()
	_resolution_ids.clear()
	_resolution_transaction.reset()
	_skipped_boss_ids.clear()
	_pending_rewards.clear()
	_generated_shop_inventory.clear()
	_purchase_history.clear()
	_claimed_decoration_ids.clear()
	_build_state = {
		"mugong": [],
		"chosik": [],
		"active_items": [],
		"mythic": {},
	}
	_guardian_state = {
		"soul_summoning_owned": false,
		"active_guardian": {},
		"sealed_guardians": [],
	}
	_gameplay_rng_state = {"seed": 140913, "state": 140913}
	_route_history.clear()
	_selected_target_id = ""
	_map_transition_progress = 0.0
	_finish_callback = Callable()
	_reset_selector()


func _node_position(node_id: String) -> Vector2:
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			return node.get("position", Vector2.ZERO)
	return Vector2.ZERO


func _sync_run_state_phases() -> void:
	if _graph_nodes.is_empty():
		return
	_run_state.set_phases([{
		"id": "phase_01",
		"nodes": _graph_nodes.duplicate(true),
		"edges": _graph_edges.duplicate(true),
	}])


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
