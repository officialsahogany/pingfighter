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
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
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
	_expect(model.floors.size() == 9, "ordinary renderer model must expose the complete human-realm map")
	_expect(
		model.nodes.size() == flow.get_graph_nodes().size()
		and model.edges.size() == flow.get_graph_edges().size()
		and model.nodes.size() > 25,
		"renderer model must consume the complete widened active-phase graph"
	)
	_expect(str(model.realm_kind) == "human_realm", "ordinary renderer model must identify the human realm")
	_expect((model.locked_phase_hints as Array).size() == 1, "human-realm model must hint at the locked immortal realm")
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
	_expect((targets[0] as Dictionary).position == Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_LEFT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y), "left generated candidate must own the left serve target")
	_expect((targets[1] as Dictionary).position == Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_RIGHT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y), "right generated candidate must own the right serve target")
	_expect(
		flow.call("_route_target_aim_position", 0, 1) == Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_CENTER_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y),
		"a single available candidate must move to the center serve target"
	)
	for target_variant in targets:
		var target := target_variant as Dictionary
		_expect(not str(target.get("id", "")).is_empty() and not str(target.get("label", "")).is_empty(), "route target presentation must derive id and label from graph data")
		if str(target.get("kind", "")) == "guardian_spring":
			_expect(str(target.get("label", "")) == "수호의 샘터", "noncombat targets must reuse the canonical node display name")
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
	_expect(source.count("_draw_map_surface(canvas, flow") == 2, "the local map surface must remain limited to map movement and its compatibility draw entry")
	_expect(source.find("if phase_name == \"MAP_OVERLAY\":\n\t\t_draw_map_surface(canvas, flow, true)\n\t\treturn") >= 0, "the read-only map overlay must reuse the generated map surface")
	_expect(source.find("func draw_fullscreen_map") >= 0 and source.find("canvas.get_viewport_rect()") >= 0, "the production map overlay must expose a viewport-owned fullscreen draw path")
	_expect(source.find("NODE_ART_PATHS") >= 0 and source.find("build_fullscreen_map_model") >= 0, "fullscreen nodes must publish existing art slots through the data-driven model")
	_expect(source.find("if phase_name == \"ROUTE_AIM\":\n\t\t_draw_route_aim(canvas, flow)\n\t\treturn") >= 0, "route serving must return before the map surface draw")
	_expect(source.find("if phase_name == \"NODE_MODAL\":\n\t\t_draw_node_modal(canvas, flow)\n\t\treturn") >= 0, "arrived node work must return before the map surface draw")


func _verify_flag_off_has_no_render_model() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(null, Callable(), {"run_id": "renderer-off"}), "flag OFF must not activate the generated renderer")
	_expect(TowerAscentFlowRenderer.new().build_render_model(flow).is_empty(), "inactive flag-OFF flow must publish no map render model")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
