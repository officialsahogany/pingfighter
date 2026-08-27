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
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

const SAMPLE_SEED_COUNT := 2000
const SAMPLE_SEED_START := 1009
const SAMPLE_SEED_STEP := 7919
const TARGET_FLOOR_MIN := 2
const TARGET_FLOOR_MAX := 8
const MAP_DRAW_CALL_LIMIT := 1536
const FINAL_DOT_GAP_UPPER_BOUND := 44.378
const FLOAT_EPSILON := 0.001
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))

var _failures: Array[String] = []
var _generated_seed_count := 0
var _deterministic_seed_count := 0
var _budget_seed_count := 0
var _generation_retry_total := 0
var _generation_retry_max := 0
var _generation_retry_histogram: Dictionary = {}
var _lane_sequences_by_floor: Dictionary = {}
var _target_lane_sequence_counts: Dictionary = {}
var _target_floor_sample_count := 0
var _varied_run_count := 0
var _run_distinct_sequence_total := 0
var _run_pattern_examples: Dictionary = {}
var _target_min_route_width := 999
var _target_max_route_width := 0
var _target_consecutive_single_row_count := 0
var _gatekeeper_lane_violation_count := 0
var _minimum_budget_margin := MAP_DRAW_CALL_LIMIT
var _minimum_budget_margin_seed := 0
var _maximum_budget_total := 0
var _maximum_budget_path := 0
var _maximum_budget_clouds := 0
var _maximum_final_dot_gap := 0.0
var _maximum_final_dot_gap_seed := 0
var _final_dot_gap_overflow_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var generator := TowerAscentMapGenerator.new()
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := SAMPLE_SEED_START + seed_offset * SAMPLE_SEED_STEP
		var graph: Dictionary = generator.generate_tower(map_seed)
		var repeated: Dictionary = generator.generate_tower(map_seed)
		if graph.is_empty():
			_expect(false, "seed %d must generate" % map_seed)
			continue
		_generated_seed_count += 1
		if generator.encode_graph(graph) == generator.encode_graph(repeated):
			_deterministic_seed_count += 1
		else:
			_expect(false, "seed %d must reproduce byte-identical graph bytes" % map_seed)
		_record_generation_retry(graph)
		_record_lane_sequences(map_seed, graph)
		_verify_gatekeeper_lanes(map_seed, graph)
		_record_render_budget(map_seed)
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_print_report()
	_expect(
		_generated_seed_count == SAMPLE_SEED_COUNT,
		"all %d seeds must generate" % SAMPLE_SEED_COUNT
	)
	_expect(
		_deterministic_seed_count == SAMPLE_SEED_COUNT,
		"all %d seeds must remain byte deterministic" % SAMPLE_SEED_COUNT
	)
	_expect(
		_budget_seed_count == SAMPLE_SEED_COUNT,
		"all %d seeds must enter the production render budget path" % SAMPLE_SEED_COUNT
	)
	_expect(
		_minimum_budget_margin > 0,
		"minimum map render margin must stay positive"
	)
	_expect(
		_gatekeeper_lane_violation_count == 0,
		"every floor gate must remain a single-lane chokepoint"
	)
	if _failures.is_empty():
		print("tower_map_shape_seed_variety_diagnostic: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _record_generation_retry(graph: Dictionary) -> void:
	var retry_count := maxi(0, int(graph.get("generation_attempt", 0)))
	_generation_retry_total += retry_count
	_generation_retry_max = maxi(_generation_retry_max, retry_count)
	_generation_retry_histogram[retry_count] = int(
		_generation_retry_histogram.get(retry_count, 0)
	) + 1


func _record_lane_sequences(map_seed: int, graph: Dictionary) -> void:
	var profile := _lane_profile_by_segment_floor(graph)
	var run_target_sequences: Dictionary = {}
	var run_pattern: Array[String] = []
	for floor_number in range(1, TowerAscentMapGenerator.TOWER_FLOOR_COUNT + 1):
		var lanes: Array[int] = profile.get(floor_number, [])
		var signature := _lane_signature(lanes)
		_expect(not signature.is_empty(), "seed %d floor %d must expose a lane sequence" % [map_seed, floor_number])
		var floor_counts: Dictionary = _lane_sequences_by_floor.get(floor_number, {})
		floor_counts[signature] = int(floor_counts.get(signature, 0)) + 1
		_lane_sequences_by_floor[floor_number] = floor_counts
		if floor_number < TARGET_FLOOR_MIN or floor_number > TARGET_FLOOR_MAX:
			continue
		_target_floor_sample_count += 1
		_target_lane_sequence_counts[signature] = int(
			_target_lane_sequence_counts.get(signature, 0)
		) + 1
		run_target_sequences[signature] = true
		run_pattern.append(signature)
		var consecutive_single_rows := 0
		for lane_index in range(1, lanes.size()):
			var lane_count := lanes[lane_index]
			_target_min_route_width = mini(_target_min_route_width, lane_count)
			_target_max_route_width = maxi(_target_max_route_width, lane_count)
			if lanes[lane_index - 1] == 1 and lane_count == 1:
				consecutive_single_rows += 1
		_target_consecutive_single_row_count += consecutive_single_rows
	_run_distinct_sequence_total += run_target_sequences.size()
	if run_target_sequences.size() > 1:
		_varied_run_count += 1
	var run_signature := "/".join(run_pattern)
	if not _run_pattern_examples.has(run_signature) and _run_pattern_examples.size() < 8:
		_run_pattern_examples[run_signature] = map_seed


func _verify_gatekeeper_lanes(map_seed: int, graph: Dictionary) -> void:
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for floor_variant in (phase_variant as Dictionary).get("floors", []):
			if not (floor_variant is Dictionary):
				continue
			var floor_data := floor_variant as Dictionary
			var rows: Array = floor_data.get("rows", [])
			if rows.is_empty() or not (rows[-1] is Dictionary):
				_gatekeeper_lane_violation_count += 1
				continue
			var gate_row := rows[-1] as Dictionary
			if (
				not bool(gate_row.get("gatekeeper", false))
				or (gate_row.get("node_ids", []) as Array).size() != 1
			):
				_gatekeeper_lane_violation_count += 1
				_expect(
					false,
					"seed %d floor %d gate must remain one lane"
					% [map_seed, int(floor_data.get("floor", 0))]
				)


func _record_render_budget(map_seed: int) -> void:
	var flow := TowerAscentFlowOwner.new()
	if not flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-shape-seed-variety-%d" % map_seed,
		"map_seed": map_seed,
	}):
		_expect(false, "seed %d must enter the production flow" % map_seed)
		return
	var renderer := TowerAscentFlowRenderer.new()
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var cache: Dictionary = renderer.get_render_cache_debug_state()
	if model.is_empty():
		_expect(false, "seed %d must build the production fullscreen map model" % map_seed)
		return
	_budget_seed_count += 1
	var total_draw_calls := int(cache.get("total_map_draw_call_budget", 0))
	var margin := MAP_DRAW_CALL_LIMIT - total_draw_calls
	if margin < _minimum_budget_margin:
		_minimum_budget_margin = margin
		_minimum_budget_margin_seed = map_seed
	if total_draw_calls > _maximum_budget_total:
		_maximum_budget_total = total_draw_calls
		_maximum_budget_path = int(cache.get("path_draw_call_budget", 0))
		_maximum_budget_clouds = int(cache.get("cloud_draw_call_budget", 0))
	var final_dot_gap := float(cache.get("path_dot_gap", 0.0))
	if final_dot_gap > _maximum_final_dot_gap:
		_maximum_final_dot_gap = final_dot_gap
		_maximum_final_dot_gap_seed = map_seed
	if final_dot_gap > FINAL_DOT_GAP_UPPER_BOUND + FLOAT_EPSILON:
		_final_dot_gap_overflow_count += 1


func _lane_profile_by_segment_floor(graph: Dictionary) -> Dictionary:
	var rows_by_floor: Dictionary = {}
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			var floor_number := int(node.get("segment_floor", 0))
			var global_row := int(node.get("global_row", -1))
			var floor_rows: Dictionary = rows_by_floor.get(floor_number, {})
			floor_rows[global_row] = int(floor_rows.get(global_row, 0)) + 1
			rows_by_floor[floor_number] = floor_rows
	var result: Dictionary = {}
	for floor_variant in rows_by_floor.keys():
		var floor_number := int(floor_variant)
		var floor_rows: Dictionary = rows_by_floor.get(floor_number, {})
		var row_numbers: Array = floor_rows.keys()
		row_numbers.sort()
		var lanes: Array[int] = []
		for row_variant in row_numbers:
			lanes.append(int(floor_rows.get(row_variant, 0)))
		result[floor_number] = lanes
	return result


func _lane_signature(lanes: Array[int]) -> String:
	var parts: Array[String] = []
	for lane_count in lanes:
		parts.append(str(lane_count))
	return "-".join(parts)


func _modal_sequence() -> Dictionary:
	var result := {"signature": "", "count": 0}
	for signature_variant in _target_lane_sequence_counts.keys():
		var signature := str(signature_variant)
		var count := int(_target_lane_sequence_counts.get(signature_variant, 0))
		if count > int(result.get("count", 0)):
			result = {"signature": signature, "count": count}
	return result


func _print_report() -> void:
	var modal := _modal_sequence()
	var modal_share := _safe_ratio(
		int(modal.get("count", 0)),
		_target_floor_sample_count
	)
	print(
		"tower_map_shape_seed_variety_diagnostic: generation seeds=%d success=%d success_rate=%0.6f deterministic=%d retry_avg=%0.6f retry_max=%d retry_histogram=%s"
		% [
			SAMPLE_SEED_COUNT,
			_generated_seed_count,
			_safe_ratio(_generated_seed_count, SAMPLE_SEED_COUNT),
			_deterministic_seed_count,
			_safe_ratio(_generation_retry_total, _generated_seed_count),
			_generation_retry_max,
			str(_generation_retry_histogram),
		]
	)
	print(
		"tower_map_shape_seed_variety_diagnostic: diversity target_floors=%d-%d samples=%d unique=%d distribution=%s modal=%s modal_share=%0.6f varied_runs=%d varied_run_ratio=%0.6f avg_distinct_per_run=%0.6f run_examples=%s"
		% [
			TARGET_FLOOR_MIN,
			TARGET_FLOOR_MAX,
			_target_floor_sample_count,
			_target_lane_sequence_counts.size(),
			str(_target_lane_sequence_counts),
			str(modal.get("signature", "")),
			modal_share,
			_varied_run_count,
			_safe_ratio(_varied_run_count, _generated_seed_count),
			_safe_ratio(_run_distinct_sequence_total, _generated_seed_count),
			str(_run_pattern_examples),
		]
	)
	print(
		"tower_map_shape_seed_variety_diagnostic: lane_sequences_by_floor=%s target_min_route_width=%d target_max_route_width=%d target_consecutive_single_rows=%d gatekeeper_lane_violations=%d"
		% [
			str(_lane_sequences_by_floor),
			_target_min_route_width,
			_target_max_route_width,
			_target_consecutive_single_row_count,
			_gatekeeper_lane_violation_count,
		]
	)
	print(
		"tower_map_shape_seed_variety_diagnostic: budget seeds=%d path=%d clouds=%d total=%d limit=%d min_margin=%d min_margin_seed=%d max_final_dot_gap=%0.3f max_final_dot_gap_seed=%d upper=%0.3f overflow_seeds=%d"
		% [
			_budget_seed_count,
			_maximum_budget_path,
			_maximum_budget_clouds,
			_maximum_budget_total,
			MAP_DRAW_CALL_LIMIT,
			_minimum_budget_margin,
			_minimum_budget_margin_seed,
			_maximum_final_dot_gap,
			_maximum_final_dot_gap_seed,
			FINAL_DOT_GAP_UPPER_BOUND,
			_final_dot_gap_overflow_count,
		]
	)


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _expect(condition: bool, message: String) -> void:
	if not condition and _failures.size() < 16 and not _failures.has(message):
		_failures.append(message)
