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
const CLOUD_WALL_SPLIT_COUNTERPROOF_ENV := "TOWER_CLOUD_WALL_SPLIT_COUNTERPROOF"
const CLOUD_WALL_REVEAL_POP_COUNTERPROOF_ENV := "TOWER_CLOUD_WALL_REVEAL_POP_COUNTERPROOF"

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
	var draw_body := (
		_function_body(cloud_source, "func draw(")
		+ _function_body(cloud_source, "func _draw_bitmap_wall(")
		+ _function_body(cloud_source, "static func _draw_dissolve_with_join_blend(")
		+ _function_body(cloud_source, "static func _draw_wall_interior(")
		+ _function_body(cloud_source, "static func _draw_texture_rect_region_vertical_alpha(")
		+ _function_body(cloud_source, "static func _draw_texture_clipped_with_vertical_fade(")
	)
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
	_expect(
		cloud_source.find("BLEND_MODE_ADD") < 0
			and cloud_source.find("canvas.material") < 0,
		"GRT-047/GRT-056: the dark concealment wall must stay on MIX without material swaps"
	)
	var bitmap_draw_body := (
		_function_body(cloud_source, "func _draw_bitmap_wall(")
		+ _function_body(cloud_source, "static func wrapped_cloud_center_x(")
	)
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
		"the reveal title must draw after the clouds so it floats above the wall"
	)
	_expect(
		renderer_source.find("run_intro_title_visual", cloud_draw_index) > cloud_draw_index,
		"the renderer must fall back to the run-start title model at the title site"
	)
	# 코덱스 리뷰(8/23): 최초 1층 진입도 층 진입이다 — 걷힘 없는 런 시작은
	# 표시 전용 인트로 창이 타이틀을 공급하고, 구름 걷힘 모델은 오염되지
	# 않아야 한다.
	var intro_flow := _new_flow("intro-title")
	_expect(intro_flow != null, "run-start title leg requires a began floor-1 flow")
	if intro_flow != null:
		var intro_model: Dictionary = intro_flow.get_run_intro_title_visual_model()
		_expect(
			bool(intro_model.get("active", false)),
			"a fresh floor-1 run must arm the run-start title window"
		)
		_expect(
			int(intro_model.get("target_floor", 0)) == 1,
			"the run-start title must name floor one"
		)
		_expect(
			not bool(intro_flow.get_floor_reveal_visual_model().get("active", false)),
			"the run-start title must not fabricate an active cloud reveal"
		)
		for _tick in range(60):
			intro_flow.update_selective(TICK_SEC)
		_expect(
			float(intro_flow.get_run_intro_title_visual_model().get("progress", 0.0)) > 0.0,
			"the run-start title progress must advance on the ambient clock"
		)
		for _tick in range(200):
			intro_flow.update_selective(TICK_SEC)
		_expect(
			intro_flow.get_run_intro_title_visual_model().is_empty(),
			"the run-start title must retire after its reveal-length window"
		)


func _verify_bitmap_density_wrap_parallax_and_fallback() -> void:
	var flow := _new_flow("cloud-bitmap-density")
	if flow == null:
		return
	var renderer: Object = flow.get("_renderer")
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var cloud_model: Dictionary = model.get("cloud_layer", {})
	_expect(
		str(cloud_model.get("render_mode", "")) == "bitmap",
		"all five prewarmed cloud assets must select bitmap rendering"
	)
	_expect(
		int(cloud_model.get("bitmap_asset_count", 0)) == 5,
		"bitmap rendering must bind wall interior, dissolve, and three motif textures"
	)
	_expect(
		int(cloud_model.get("parallax_layer_count", 0)) == 2,
		"the static wall and drifting foreground motifs must retain two depth layers"
	)
	var sealed_model := cloud_model.duplicate(true)
	if OS.get_environment(CLOUD_WALL_SPLIT_COUNTERPROOF_ENV) == "1":
		sealed_model["merged_region_count"] = 2
	_expect(
		TowerAscentMapCloudLayer.merged_region_contract_holds(sealed_model),
		"the locked range must remain one MIX-blended merged wall with one dissolve and eight motifs"
	)
	var split_counterproof := cloud_model.duplicate(true)
	split_counterproof["merged_region_count"] = 2
	_expect(
		not TowerAscentMapCloudLayer.merged_region_contract_holds(split_counterproof),
		"counterproof: restoring per-floor regions must break the merged-wall seal"
	)
	var expected_reserve := TowerAscentMapCloudLayer.estimate_draw_calls(
		model.get("overview_nodes", []),
		float(model.get("art_size", 0.0)),
		float(model.get("map_scale", 1.0))
	)
	_expect(
		int(cloud_model.get("maximum_draw_calls_per_merged_region", 0))
			== expected_reserve,
		"the merged-region model and renderer reserve must stay in exact lockstep"
	)
	_expect(
		expected_reserve < (cloud_model.get("floors", []) as Array).size() * 13,
		"the merged wall must materially reduce the retired thirteen-calls-per-floor reserve"
	)

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

	var floors: Array = cloud_model.get("floors", [])
	var previous_upper_boundary := INF
	for floor_variant in floors:
		if not (floor_variant is Dictionary):
			continue
		var floor_rect: Rect2 = (floor_variant as Dictionary).get("floor_rect", Rect2())
		_expect(floor_rect.has_area(), "each floor must retain an inspectable ownership span")
		if is_finite(previous_upper_boundary):
			_expect(
				is_equal_approx(floor_rect.end.y, previous_upper_boundary),
				"merged floor spans must share one boundary and include every inter-floor gap"
			)
		previous_upper_boundary = floor_rect.position.y
	var interior_spec: Dictionary = cloud_model.get("interior_spec", {})
	var dissolve_spec: Dictionary = cloud_model.get("dissolve_spec", {})
	_expect(
		float(interior_spec.get("opacity", 0.0)) >= 0.9,
		"the opaque wall interior must keep locked nodes and routes unreadable"
	)
	_expect(
		str(dissolve_spec.get("asset_key", ""))
			== TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE,
		"the merged wall must own one authored lower dissolve strip"
	)
	_expect(
		int(cloud_model.get("motif_count", 0))
			== TowerAscentMapCloudLayer.BITMAP_FRONT_CLOUD_COUNT,
		"eight seeded cloud motifs must break up the minimum-zoom interior repetition"
	)
	var build_map_scale := float(model.get("map_scale", 1.0))
	var expected_tile_world_size := TowerAscentMapCloudLayer.interior_tile_world_size(
		build_map_scale
	)
	var interior_world_size: Vector2 = interior_spec.get("world_size", Vector2.ZERO)
	_expect(
		interior_world_size.is_equal_approx(expected_tile_world_size),
		"build() and the draw-call estimator must consume one canonical interior tile size"
	)
	var base_tile_height := (
		float(TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR_WORLD_SIZE.y)
		* maxf(0.001, build_map_scale)
	)
	var adopted_y_scale := interior_world_size.y / maxf(0.001, base_tile_height)
	_expect(
		adopted_y_scale >= 1.999 and adopted_y_scale <= 3.001,
		"the adopted interior Y scale must stay inside the reviewed 2x-to-3x range"
	)
	var legacy_unscaled_reserve := _legacy_unscaled_cloud_reserve(
		model.get("overview_nodes", []),
		float(model.get("art_size", 0.0)),
		build_map_scale
	)
	_expect(
		expected_reserve < legacy_unscaled_reserve,
		"the larger canonical Y tile must automatically reduce the interior draw-call reserve"
	)
	var wrapped_motion_checked := false
	var wall_rect: Rect2 = cloud_model.get("wall_rect", Rect2())
	for spec_variant in cloud_model.get("motif_specs", []):
		if not (spec_variant is Dictionary):
			continue
		var spec := spec_variant as Dictionary
		var speed := float(spec.get("drift_speed", 0.0))
		if speed <= 0.001 or wall_rect.size.x <= 0.001:
			continue
		var start_x := TowerAscentMapCloudLayer.wrapped_cloud_center_x(
			spec,
			wall_rect,
			0.0
		)
		var cycle_x := TowerAscentMapCloudLayer.wrapped_cloud_center_x(
			spec,
			wall_rect,
			wall_rect.size.x / speed
		)
		_expect(
			is_equal_approx(start_x, cycle_x),
			"one full continuous drift cycle must wrap without a horizontal seam"
		)
		wrapped_motion_checked = true
		break
	_expect(wrapped_motion_checked, "the production fixture must expose one drifting motif")
	var revealed_floor := int(visual.get("revealed_floor", 1))
	var target_floor := revealed_floor + 1
	var before_state := TowerAscentMapCloudLayer.wall_visual_state(cloud_model, {
		"revealed_floor": revealed_floor,
		"pending": false,
	})
	var midpoint_visual := {
		"revealed_floor": revealed_floor,
		"target_floor": target_floor,
		"pending": true,
		"progress": 0.5,
	}
	var midpoint_state := TowerAscentMapCloudLayer.wall_visual_state(
		cloud_model,
		midpoint_visual
	)
	var after_state := TowerAscentMapCloudLayer.wall_visual_state(cloud_model, {
		"revealed_floor": target_floor,
		"pending": false,
	})
	var limit_state := TowerAscentMapCloudLayer.wall_visual_state(cloud_model, {
		"revealed_floor": revealed_floor,
		"target_floor": target_floor,
		"pending": true,
		"progress": 0.9999,
	})
	if OS.get_environment(CLOUD_WALL_REVEAL_POP_COUNTERPROOF_ENV) == "1":
		# Reproduce the retired whole-strip fade: it approaches alpha zero before
		# the completed steady state restores the same strip at alpha one.
		limit_state["dissolve_alpha"] = limit_state.get("reveal_alpha", 0.0)
	_expect(
		is_equal_approx(
			TowerAscentMapCloudLayer.floor_alpha_multiplier(target_floor, midpoint_visual),
			0.5
		),
		"the authoritative reveal progress must still drive the clearing segment alpha"
	)
	_expect(
		is_equal_approx(float(midpoint_state.get("reveal_alpha", 0.0)), 0.5),
		"the merged wall must consume the midpoint alpha multiplier"
	)
	_expect(
		float(before_state.get("boundary_y", 0.0))
			> float(midpoint_state.get("boundary_y", 0.0))
		and float(midpoint_state.get("boundary_y", 0.0))
			> float(after_state.get("boundary_y", 0.0)),
		"the lower dissolve boundary must move upward exactly one floor during reveal"
	)
	var midpoint_reveal_segment: Rect2 = midpoint_state.get(
		"reveal_segment_rect",
		Rect2()
	)
	_expect(
		not midpoint_reveal_segment.has_area()
			or midpoint_reveal_segment.position.y
				>= float(midpoint_state.get("end_boundary_y", INF)) - 0.001,
		"a fading interior tail must never extend above the final public boundary"
	)
	var limit_dissolve_rect: Rect2 = limit_state.get("dissolve_rect", Rect2())
	var after_dissolve_rect: Rect2 = after_state.get("dissolve_rect", Rect2())
	_expect(
		limit_dissolve_rect.is_equal_approx(after_dissolve_rect),
		"progress approaching one and the completed steady state must own the same dissolve rect"
	)
	_expect(
		is_equal_approx(
			float(limit_state.get("dissolve_alpha", 0.0)),
			float(after_state.get("dissolve_alpha", 0.0))
		),
		"progress approaching one must keep the landing dissolve as opaque as the completed frame"
	)
	_expect(
		(limit_state.get("stable_dissolve_rect", Rect2()) as Rect2).size.y
			>= after_dissolve_rect.size.y - 0.01,
		"the final landing strip must be opaque before the reveal completion tick"
	)
	_expect(
		not (limit_state.get("reveal_segment_rect", Rect2()) as Rect2).has_area(),
		"the public interior fade tail must collapse continuously before completion"
	)

	var build_args_nodes: Variant = model.get("overview_nodes", [])
	var build_world_rect: Rect2 = model.get("fit_all_camera_world_rect", Rect2())
	var build_seed := int(model.get("map_seed", 0))
	var build_art_size := float(model.get("art_size", 0.0))
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
		_boundary_signature(cloud_model) == _boundary_signature(same_seed),
		"floor boundaries must remain deterministic and independent of presentation RNG"
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
	for spec_variant in model.get("motif_specs", []):
		if not (spec_variant is Dictionary):
			continue
		var spec := spec_variant as Dictionary
		signature.append("%s:%s:%s:%s:%s:%s" % [
			str(spec.get("asset_key", "")),
			str(spec.get("size", Vector2.ZERO)),
			str(spec.get("base_center_x", 0.0)),
			str(spec.get("center_y", 0.0)),
			str(spec.get("drift_direction", 0.0)),
			str(spec.get("drift_speed", 0.0)),
		])
	return signature


func _boundary_signature(model: Dictionary) -> PackedStringArray:
	var signature := PackedStringArray()
	for floor_variant in model.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_spec := floor_variant as Dictionary
		signature.append("%d:%s" % [
			int(floor_spec.get("floor", 0)),
			str(floor_spec.get("floor_rect", Rect2())),
		])
	return signature


func _legacy_unscaled_cloud_reserve(
	nodes_value: Variant,
	art_size: float,
	map_scale: float
) -> int:
	var nodes: Array = nodes_value if nodes_value is Array else []
	var floors: Dictionary = {}
	var minimum_y := INF
	var maximum_y := -INF
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if floor_number <= 0:
			continue
		var position: Vector2 = node.get("world_position", Vector2.ZERO)
		floors[floor_number] = true
		minimum_y = minf(minimum_y, position.y)
		maximum_y = maxf(maximum_y, position.y)
	if floors.is_empty() or not is_finite(minimum_y) or not is_finite(maximum_y):
		return 0
	var vertical_padding := maxf(art_size * 1.35, 20.0)
	var legacy_tile_height := maxf(
		1.0,
		float(TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR_WORLD_SIZE.y)
			* maxf(0.001, map_scale)
	)
	var conservative_height := maximum_y - minimum_y + vertical_padding * 2.0
	return (
		maxi(1, ceili(conservative_height / legacy_tile_height))
		+ TowerAscentMapCloudLayer.BITMAP_REVEAL_SPLIT_DRAW_CALLS
		+ TowerAscentMapCloudLayer.BITMAP_DISSOLVE_DRAW_CALLS
		+ TowerAscentMapCloudLayer.BITMAP_MAX_MOTIF_DRAW_CALLS
	)


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
