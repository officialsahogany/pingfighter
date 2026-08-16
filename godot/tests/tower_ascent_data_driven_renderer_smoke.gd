extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_full_graph_and_two_active_candidates()
	_verify_route_aim_targets_follow_generated_data()
	_verify_renderer_has_no_fixed_fixture_ids()
	_verify_flag_off_has_no_render_model()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_data_driven_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_full_graph_and_two_active_candidates() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "renderer-map", "map_seed": 83521}), "renderer fixture must begin")
	var model := TowerAscentFlowRenderer.new().build_render_model(flow)
	_expect(model.floors.size() == 12, "renderer model must expose the complete 12-floor map")
	_expect(model.nodes.size() == 34 and model.edges.size() > 30, "renderer model must consume the complete generated graph, not the four-node fixture")
	_expect(model.active_candidate_ids.size() == 2, "only the next generated row may be active")
	var active_count := 0
	for node_variant in model.nodes:
		if node_variant is Dictionary and model.active_candidate_ids.has(str((node_variant as Dictionary).get("id", ""))):
			active_count += 1
	_expect(active_count == 2, "exactly two published nodes must match the active target list")


func _verify_route_aim_targets_follow_generated_data() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "renderer-aim", "map_seed": 83521}), "route-aim renderer fixture must begin")
	flow.debug_advance_to_route_aim()
	var targets := flow.get_route_aim_targets()
	_expect(targets.size() == 2, "route aim must expose two generated target records")
	_expect((targets[0] as Dictionary).position == Vector2(220.0, 165.0), "left generated candidate must own the left selector target")
	_expect((targets[1] as Dictionary).position == Vector2(540.0, 165.0), "right generated candidate must own the right selector target")
	for target_variant in targets:
		var target := target_variant as Dictionary
		_expect(not str(target.get("id", "")).is_empty() and not str(target.get("label", "")).is_empty(), "route target presentation must derive id and label from graph data")
	flow.debug_launch_at_target(1)
	flow.update_selective(1.5)
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "generated target hit must enter map transition")
	_expect(flow.get_selected_target_position() != Vector2.ZERO, "map movement must use the generated node coordinate")


func _verify_renderer_has_no_fixed_fixture_ids() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
	for retired_id in ["rest_01", "boss_left_02", "boss_right_02"]:
		_expect(source.find(retired_id) < 0, "renderer must not retain fixed fixture id: %s" % retired_id)
	_expect(source.find("build_render_model") >= 0 and source.find("get_graph_floors") >= 0, "renderer must use the generated floor and graph data surfaces")
	_expect(source.find("var model := build_render_model") < 0, "hot draw path must not duplicate the full render model")


func _verify_flag_off_has_no_render_model() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(null, Callable(), {"run_id": "renderer-off"}), "flag OFF must not activate the generated renderer")
	_expect(TowerAscentFlowRenderer.new().build_render_model(flow).is_empty(), "inactive flag-OFF flow must publish no map render model")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
