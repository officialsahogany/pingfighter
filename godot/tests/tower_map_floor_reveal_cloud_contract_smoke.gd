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
const TowerAscentMapCloudLayer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
)
const TowerAscentFloorTitleCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_floor_title_catalog.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)

const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const TICK_SEC := 1.0 / 72.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_reveal_sequence_persistence_and_rng()
	_verify_bitmap_density_wrap_parallax_and_fallback()
	_verify_skip_reset_and_hot_path_contracts()
	_verify_floor_reveal_title_catalog_and_wiring()
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
		draw_body.find("texture.get_size") < 0,
		"GRT-053: cloud draw must consume declared texture sizes instead of inferring geometry"
	)
	_expect(
		cloud_source.find("draw_set_transform") >= 0,
		"cloud drift must use stable-owner time offsets without spawning interpolated overlay nodes"
	)
	var bitmap_draw_body := _function_body(cloud_source, "func _draw_bitmap_floor(")
	_expect(
		bitmap_draw_body.find("sin(") < 0 and bitmap_draw_body.find("fposmod(") >= 0,
		"bitmap clouds must flow continuously through wrap coordinates instead of oscillating"
	)


func _verify_floor_reveal_title_catalog_and_wiring() -> void:
	# 피드백2 9항: 층 진입 타이틀 정본·포락·배선 봉인.
	for floor_number in range(1, 13):
		_expect(
			not TowerAscentFloorTitleCatalog.floor_title(floor_number).is_empty(),
			"floor %d must own a reveal title" % floor_number
		)
	_expect(
		TowerAscentFloorTitleCatalog.floor_title(0).is_empty()
		and TowerAscentFloorTitleCatalog.floor_title(13).is_empty(),
		"out-of-tower floors must not fabricate a reveal title"
	)
	var catalog_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_floor_title_catalog.gd"
	)
	_expect(
		catalog_source.find("—") < 0,
		"Korean floor title copy must not contain an em dash"
	)
	_expect(
		is_equal_approx(TowerAscentFloorTitleCatalog.title_alpha(0.0), 0.0)
		and is_equal_approx(TowerAscentFloorTitleCatalog.title_alpha(
			TowerAscentFloorTitleCatalog.TITLE_FADE_IN_END
		), 1.0)
		and is_equal_approx(TowerAscentFloorTitleCatalog.title_alpha(0.5), 1.0)
		and is_equal_approx(TowerAscentFloorTitleCatalog.title_alpha(
			TowerAscentFloorTitleCatalog.TITLE_HOLD_END
		), 1.0)
		and is_equal_approx(TowerAscentFloorTitleCatalog.title_alpha(1.0), 0.0),
		"reveal title alpha must fade in, hold through the cloud fade, then leave"
	)
	var mid_fade := TowerAscentFloorTitleCatalog.title_alpha(0.89)
	_expect(
		mid_fade > 0.0 and mid_fade < 1.0,
		"reveal title fade-out must pass through partial alpha"
	)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var cloud_draw_index := renderer_source.find("_map_cloud_layer.draw(")
	var title_draw_index := renderer_source.find(
		"_draw_floor_reveal_title(",
		cloud_draw_index
	)
	_expect(
		cloud_draw_index >= 0 and title_draw_index > cloud_draw_index,
		"the reveal title must draw after the clouds so it floats above the fog"
	)


func _verify_bitmap_density_wrap_parallax_and_fallback() -> void:
	var flow := _new_flow("cloud-bitmap-density")
	if flow == null:
		return
	var renderer: Object = flow.get("_renderer")
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var cloud_model: Dictionary = model.get("cloud_layer", {})
	_expect(str(cloud_model.get("render_mode", "")) == "bitmap", "all four prewarmed cloud assets must select bitmap rendering")
	_expect(int(cloud_model.get("bitmap_asset_count", 0)) == 4, "bitmap rendering must bind all four approved assets")
	_expect(int(cloud_model.get("parallax_layer_count", 0)) == 2, "locked clouds must retain slow haze plus faster foreground depth")
	_expect(int(cloud_model.get("maximum_draw_calls_per_floor", 0)) == 11, "each locked floor must reserve the exact fog cover plus two-wrap haze plus four two-wrap motif worst case")

	var visual: Dictionary = flow.get_floor_reveal_visual_model()
	_expect(
		TowerAscentMapCloudLayer.estimate_visible_draw_calls(cloud_model, visual) > 0,
		"a new run must visibly cover locked floors"
	)
	var public_visual := visual.duplicate(true)
	public_visual["revealed_floor"] = 999
	public_visual["pending"] = false
	_expect(
		TowerAscentMapCloudLayer.estimate_visible_draw_calls(cloud_model, public_visual) == 0,
		"revealed floors must schedule zero cloud draws"
	)

	var inspected_density := false
	var wrapped_motion_checked := false
	for floor_variant in cloud_model.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_spec := floor_variant as Dictionary
		var floor_number := int(floor_spec.get("floor", 0))
		if floor_number <= int(visual.get("revealed_floor", 0)):
			continue
		var fog_count := 0
		var haze_count := 0
		var front_count := 0
		var haze_speed := INF
		var minimum_front_speed := INF
		var floor_rect: Rect2 = floor_spec.get("floor_rect", Rect2())
		for spec_variant in floor_spec.get("bitmap_specs", []):
			if not (spec_variant is Dictionary):
				continue
			var spec := spec_variant as Dictionary
			if str(spec.get("kind", "")) == "fog":
				fog_count += 1
				_expect(
					float(spec.get("opacity", 0.0)) >= 0.9,
					"the locked-floor fog cover must be near-opaque to conceal upper nodes"
				)
			elif str(spec.get("kind", "")) == "haze":
				haze_count += 1
				haze_speed = minf(haze_speed, float(spec.get("drift_speed", INF)))
			else:
				front_count += 1
				minimum_front_speed = minf(minimum_front_speed, float(spec.get("drift_speed", INF)))
				if not wrapped_motion_checked:
					var speed := float(spec.get("drift_speed", 0.0))
					if speed > 0.001 and floor_rect.size.x > 0.001:
						var start_x := TowerAscentMapCloudLayer.wrapped_cloud_center_x(spec, floor_rect, 0.0)
						var cycle_x := TowerAscentMapCloudLayer.wrapped_cloud_center_x(
							spec,
							floor_rect,
							floor_rect.size.x / speed
						)
						_expect(is_equal_approx(start_x, cycle_x), "one full continuous drift cycle must wrap to the same cloud center without a seam")
						wrapped_motion_checked = true
		_expect(
			fog_count == 1 and haze_count == 1 and front_count == 4,
			"each locked floor must stack one fog cover, one full-width haze band, and four seeded swirl/wisp motifs"
		)
		_expect(minimum_front_speed > haze_speed, "foreground motifs must drift faster than the rear haze layer")
		var midpoint_visual := {
			"revealed_floor": floor_number - 1,
			"target_floor": floor_number,
			"pending": true,
			"progress": 0.5,
		}
		_expect(
			is_equal_approx(TowerAscentMapCloudLayer.floor_alpha_multiplier(floor_number, midpoint_visual), 0.5),
			"the two-second reveal fade must remove the complete dense bitmap composition as one layer"
		)
		inspected_density = true
		break
	_expect(inspected_density and wrapped_motion_checked, "the production fixture must expose one inspectable locked bitmap floor")

	var build_args_nodes: Variant = model.get("overview_nodes", [])
	var build_world_rect: Rect2 = model.get("fit_all_camera_world_rect", Rect2())
	var build_seed := int(model.get("map_seed", 0))
	var build_art_size := float(model.get("art_size", 0.0))
	var build_map_scale := float(model.get("map_scale", 1.0))
	var asset_resolutions: Dictionary = model.get("map_scroll_assets", {})
	var cloud_layer := TowerAscentMapCloudLayer.new()
	var same_seed := cloud_layer.build(
		build_args_nodes,
		build_world_rect,
		build_seed,
		build_art_size,
		asset_resolutions,
		build_map_scale
	)
	var different_seed := cloud_layer.build(
		build_args_nodes,
		build_world_rect,
		build_seed + 1,
		build_art_size,
		asset_resolutions,
		build_map_scale
	)
	_expect(
		_bitmap_layout_signature(cloud_model) == _bitmap_layout_signature(same_seed),
		"the same presentation seed must reproduce cloud placement, direction, speed, and phase"
	)
	_expect(
		_bitmap_layout_signature(cloud_model) != _bitmap_layout_signature(different_seed),
		"a different presentation seed must change cached cloud drift without touching gameplay RNG"
	)
	var fallback := cloud_layer.build(
		build_args_nodes,
		build_world_rect,
		build_seed,
		build_art_size,
		{},
		build_map_scale
	)
	_expect(str(fallback.get("render_mode", "")) == "procedural", "missing bitmap assets must retain the procedural cloud fallback")
	_expect(not (fallback.get("floors", []) as Array).is_empty(), "procedural fallback geometry must remain precomputed")


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


func _bitmap_layout_signature(model: Dictionary) -> PackedStringArray:
	var signature := PackedStringArray()
	for floor_variant in model.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_spec := floor_variant as Dictionary
		for spec_variant in floor_spec.get("bitmap_specs", []):
			if not (spec_variant is Dictionary):
				continue
			var spec := spec_variant as Dictionary
			signature.append("%d:%s:%s:%s:%s:%s:%s" % [
				int(floor_spec.get("floor", 0)),
				str(spec.get("asset_key", "")),
				str(spec.get("size", Vector2.ZERO)),
				str(spec.get("base_center_x", 0.0)),
				str(spec.get("center_y", 0.0)),
				str(spec.get("drift_direction", 0.0)),
				str(spec.get("drift_speed", 0.0)),
			])
	return signature


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	var next_static := source.find("\nstatic func ", start + signature.length())
	var next_boundary := next_func
	if next_static >= 0 and (next_boundary < 0 or next_static < next_boundary):
		next_boundary = next_static
	return source.substr(start) if next_boundary < 0 else source.substr(start, next_boundary - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
