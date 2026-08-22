extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const TICK_SEC := 1.0 / 72.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_reveal_sequence_persistence_and_rng()
	_verify_skip_reset_and_hot_path_contracts()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_floor_reveal_cloud_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_reveal_sequence_persistence_and_rng() -> void:
	var flow := _new_flow("cloud-sequence")
	if flow == null:
		return
	var initial_snapshot: Dictionary = flow.export_snapshot()
	var initial_revealed := int(initial_snapshot.get("run_progress", {}).get("revealed_floor", 0))
	_expect(initial_revealed == 1, "a new run must begin with only its entry floor revealed")
	var target_id := _target_or_promote_above_floor(flow, initial_revealed)
	_expect(not target_id.is_empty(), "cloud sequence fixture must expose a newly opened floor")
	if target_id.is_empty():
		return
	var gameplay_rng_before: Dictionary = initial_snapshot.get("gameplay_rng_state", {}).duplicate(true)
	flow.call("_resolve_route_target", target_id)
	_expect(bool(flow.is_floor_reveal_pending()), "selecting a higher segment_floor must queue one reveal")
	var renderer: Object = flow.get("_renderer")
	var built_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	_expect(
		flow.export_snapshot().get("gameplay_rng_state", {}) == gameplay_rng_before,
		"cloud precomputation must not advance authoritative gameplay RNG"
	)
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("cloud_draw_call_budget", 0)) > 0, "cached map build must precompute cloud layers")
	_expect(
		int(cache_state.get("total_map_draw_call_budget", 0))
			<= TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
		"cloud reserve plus adaptive dotted routes must stay inside the 1536 map budget"
	)
	_expect(not built_model.get("cloud_layer", {}).is_empty(), "renderer must expose a replaceable cached cloud layer model")

	var guard_ticks := 0
	while not bool(flow.get_floor_reveal_visual_model().get("active", false)) and guard_ticks < 120:
		flow.update_selective(TICK_SEC)
		guard_ticks += 1
	_expect(guard_ticks < 120, "reveal must begin after the map becomes visible")
	var held_transition_progress := float(flow.get_map_transition_progress())
	var held_visual: Dictionary = flow.get_map_transition_visual_model()
	_expect(
		is_zero_approx(float(held_visual.get("travel_progress", -1.0))),
		"walker travel must be zero when the reveal starts"
	)
	for _index in range(72):
		flow.update_selective(TICK_SEC)
	_expect(bool(flow.is_floor_reveal_pending()), "the two-second reveal must still be active after one second")
	_expect(
		is_equal_approx(float(flow.get_map_transition_progress()), held_transition_progress),
		"the walker timeline must remain paused throughout cloud clearing"
	)
	for _index in range(73):
		flow.update_selective(TICK_SEC)
	_expect(not bool(flow.is_floor_reveal_pending()), "the reveal must finish after about 2.0 seconds")
	var revealed_snapshot: Dictionary = flow.export_snapshot()
	var target_floor := _node_floor(flow, target_id)
	_expect(
		int(revealed_snapshot.get("run_progress", {}).get("revealed_floor", 0)) == target_floor,
		"completed reveal must persist the newly opened segment_floor in run_progress"
	)
	_expect(
		is_equal_approx(float(flow.get_map_transition_progress()), held_transition_progress),
		"walker movement must not advance on the reveal-completion tick"
	)
	flow.update_selective(TICK_SEC)
	_expect(
		float(flow.get_map_transition_progress()) > held_transition_progress,
		"walker intro must resume only after cloud clearing completes"
	)
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(flow.export_snapshot()), "revealed-floor snapshot must restore")
	_expect(
		not bool(restored.is_floor_reveal_pending()),
		"load/re-entry of an already revealed target must not replay cloud clearing"
	)
	_expect(
		int(restored.export_snapshot().get("run_progress", {}).get("revealed_floor", 0)) == target_floor,
		"revealed floor must round-trip without shrinking"
	)
	var fresh := _new_flow("cloud-new-run-reset")
	_expect(
		int(fresh.export_snapshot().get("run_progress", {}).get("revealed_floor", 0)) == 1,
		"a new run must reset disclosure instead of inheriting the prior run"
	)


func _verify_skip_reset_and_hot_path_contracts() -> void:
	var flow := _new_flow("cloud-skip")
	if flow == null:
		return
	var current_revealed := int(flow.export_snapshot().get("run_progress", {}).get("revealed_floor", 0))
	var target_id := _target_or_promote_above_floor(flow, current_revealed)
	if target_id.is_empty():
		_expect(false, "skip fixture must expose a newly opened floor")
		return
	flow.call("_resolve_route_target", target_id)
	var guard_ticks := 0
	while not bool(flow.get_floor_reveal_visual_model().get("active", false)) and guard_ticks < 120:
		flow.update_selective(TICK_SEC)
		guard_ticks += 1
	var held_progress := float(flow.get_map_transition_progress())
	flow.handle_input(_left_button(VIEWPORT_RECT.get_center(), true))
	_expect(not bool(flow.is_floor_reveal_pending()), "one click must skip a repetitive active reveal")
	_expect(
		is_equal_approx(float(flow.get_map_transition_progress()), held_progress),
		"the skip click must be consumed and must not also move the walker"
	)
	var reset_flow := _new_flow("cloud-cancel-reset")
	var reset_target := _target_or_promote_above_floor(
		reset_flow,
		int(reset_flow.export_snapshot().get("run_progress", {}).get("revealed_floor", 0))
	)
	reset_flow.call("_resolve_route_target", reset_target)
	_expect(bool(reset_flow.is_floor_reveal_pending()), "reset fixture must begin pending")
	reset_flow.call("_reset_runtime_state")
	_expect(not bool(reset_flow.is_floor_reveal_pending()), "run reset must cancel the reveal timer")

	var cloud_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
	)
	var draw_body := cloud_source.substr(cloud_source.find("func draw("))
	draw_body = draw_body.substr(0, draw_body.find("static func _build_soft_band_points"))
	_expect(
		draw_body.find("RandomNumberGenerator.new") < 0
			and draw_body.find("PackedVector2Array(") < 0,
		"GRT-003: cloud draw must consume cached specs without RNG or array construction"
	)
	_expect(
		cloud_source.find("draw_set_transform") >= 0,
		"cloud drift must use stable-owner time offsets without spawning interpolated overlay nodes"
	)


func _new_flow(run_id: String) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": run_id,
		"map_seed": 83521,
	}), "%s must begin" % run_id)
	return flow


func _target_or_promote_above_floor(flow: Object, revealed_floor: int) -> String:
	for target_id in flow.get_route_target_ids():
		if _node_floor(flow, target_id) > revealed_floor:
			return target_id
	# The first selectable row belongs to the already-open entry segment. Promote
	# one fixture target to the next segment so this focused seal reaches the
	# production crossing-floor path without simulating an intervening battle.
	var targets: Array[String] = flow.get_route_target_ids()
	if not targets.is_empty():
		var target_id := targets[0]
		var node_by_id: Dictionary = flow.get("_graph_node_by_id")
		var node_value: Variant = node_by_id.get(target_id, null)
		if node_value is Dictionary:
			(node_value as Dictionary)["segment_floor"] = revealed_floor + 1
			return target_id
	return ""


func _node_floor(flow: Object, node_id: String) -> int:
	for node_variant in flow.get_graph_nodes():
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if str(node.get("id", "")) == node_id:
			return int(node.get("segment_floor", node.get("floor", 0)))
	return 0


func _left_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
