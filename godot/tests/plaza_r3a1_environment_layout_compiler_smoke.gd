extends SceneTree

# Candidate-only R3-A1.1 preflight seal. It verifies the exact 13->7 semantic
# mapping and every direction-compatible road draw. The immutable plan remains
# production-disconnected and requires a separate Vulkan composition approval,
# while its geometry must already close the vertical-road, plaza-exclusion,
# exposed-endpoint, material-hierarchy, and main-spine contracts.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const SEED_CENSUS_COUNT := 24
const EXPECTED_GENERATOR_TYPES := [
	"bench_and_lanterns",
	"boundary_pines",
	"cloth_awning_cluster",
	"crossroad_lanterns",
	"guardian_tree_grove",
	"jade_rock_garden",
	"market_stalls",
	"quiet_pond",
	"seal_stone_court",
	"small_vendor_court",
	"spirit_tree_cluster",
	"stone_lantern_gate",
	"stone_marker_cluster",
]
const EXPECTED_ASSET_IDS := [
	"market",
	"pine",
	"pond",
	"ritual_stone_garden",
	"stone_lantern_rest",
	"supply",
	"wayfinder",
]
const EXPECTED_ROAD_RENDER_ASSET_IDS := [
	"entrance_forecourt",
	"plot_spur",
	"secondary_horizontal",
	"secondary_negative",
	"secondary_positive",
	"straight_horizontal",
	"straight_negative",
	"straight_positive",
	"terminus",
	"three_way",
	"trail_horizontal",
	"trail_negative",
	"trail_positive",
	"turn_court",
]
const EXPECTED_COMPLETED_LEGS := 4
const MIN_ASSERTIONS_BY_LEG := {
	"catalog_mapping": 6,
	"production_seed_census": 360,
	"mutation_counterproofs": 10,
	"production_disconnection": 2,
}

var _failures: Array[String] = []
var _assertion_count := 0
var _legs_completed := 0
var _leg_assertion_counts := {}


func _init() -> void:
	_verify_catalog_and_fail_closed_mapping()
	_verify_production_seed_census()
	_verify_plan_mutation_counterproofs()
	_verify_production_disconnection()
	if _legs_completed != EXPECTED_COMPLETED_LEGS:
		_failures.append("GRT-040 completion gate: expected %d completed verification legs, got %d" % [EXPECTED_COMPLETED_LEGS, _legs_completed])
	for leg_name_value in MIN_ASSERTIONS_BY_LEG.keys():
		var leg_name := str(leg_name_value)
		var minimum := int(MIN_ASSERTIONS_BY_LEG.get(leg_name, 0))
		var actual := int(_leg_assertion_counts.get(leg_name, 0))
		if actual < minimum:
			_failures.append("GRT-040 completion gate: leg %s executed %d assertions, expected at least %d" % [leg_name, actual, minimum])
	if _assertion_count <= 0:
		_failures.append("GRT-040 completion gate: smoke executed zero assertions")
	if _failures.is_empty() and _legs_completed == EXPECTED_COMPLETED_LEGS and _assertion_count > 0:
		print("plaza_r3a1_environment_layout_compiler_smoke: ok")
		print("plaza_r3a1_environment_layout_compiler_smoke: legs=%d assertions=%d" % [_legs_completed, _assertion_count])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_fail_closed_mapping() -> void:
	var assertion_start := _assertion_count
	var catalog := PlazaR3EnvironmentLayoutCompiler.validate_decor_mapping_catalog()
	_expect(bool(catalog.get("valid", false)), "exact generator decor catalog must have a complete semantic mapping")
	_expect(catalog.get("generator_cluster_types", []) == EXPECTED_GENERATOR_TYPES, "decor catalog must cover the exact 13 generator types, including currently sparse guardian_tree_grove")
	_expect(catalog.get("used_asset_ids", []) == EXPECTED_ASSET_IDS, "13 generator types must map onto exact seven semantically approved runtime assets")
	var missing := PlazaR3EnvironmentLayoutCompiler.DECOR_ASSET_BY_CLUSTER_TYPE.duplicate(true)
	missing.erase("seal_stone_court")
	var missing_result := PlazaR3EnvironmentLayoutCompiler.validate_decor_mapping_catalog(missing)
	_expect(not bool(missing_result.get("valid", true)), "removing the most frequent seal_stone_court mapping must fail closed")
	_expect(_has_violation(missing_result, "decor_mapping_catalog_mismatch"), "unmapped decor type must expose catalog mismatch instead of a fallback")
	var unknown := PlazaR3EnvironmentLayoutCompiler.DECOR_ASSET_BY_CLUSTER_TYPE.duplicate(true)
	unknown["__unknown_silent_fallback_trap__"] = "supply"
	var unknown_result := PlazaR3EnvironmentLayoutCompiler.validate_decor_mapping_catalog(unknown)
	_expect(not bool(unknown_result.get("valid", true)), "an unknown generator decor type must not silently fall back to supply")
	_complete_leg("catalog_mapping", assertion_start)


func _verify_production_seed_census() -> void:
	var assertion_start := _assertion_count
	var aggregate_basis := {"horizontal": 0, "vertical": 0, "positive": 0, "negative": 0}
	var aggregate_assets := {}
	var aggregate_decor_assets := {}
	var observed_cluster_types: Array[String] = []
	var visual_seed_with_both_new_assets := -1
	var fingerprints := {}
	var total_segments := 0
	var composition_blocked_seed_count := 0
	var aggregate_overlap_count := 0
	var aggregate_uncovered_basis_endcaps := 0
	for map_seed in range(1, SEED_CENSUS_COUNT + 1):
		var roster := PlazaAssetLoader.build_hwangyeok_building_specs(1, map_seed, false, false)
		var promoted := PlazaMapRoadSkeletonR3.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
		var promoted_validation := promoted.get("validation", {}) as Dictionary
		_expect(bool(promoted_validation.get("valid", false)), "seed %d R3-A0.6 layout must remain valid" % map_seed)
		var plan := PlazaR3EnvironmentLayoutCompiler.compile_layout(promoted)
		var repeated := PlazaR3EnvironmentLayoutCompiler.compile_layout(promoted)
		var validation := plan.get("validation", {}) as Dictionary
		_expect(not bool(validation.get("valid", true)), "seed %d must remain fail-closed until the whole-road composition receives visual approval" % map_seed)
		_expect(not _has_violation(validation, "road_special_orientation_unrepresentable"), "seed %d special-road directions must match authored PNG geometry" % map_seed)
		_expect(_has_violation(validation, "road_network_composition_unapproved"), "seed %d must expose the whole-road composition decision" % map_seed)
		_expect(not _has_violation(validation, "screen_vertical_road_treatment_missing"), "seed %d must remove screen-vertical straight-road draws before visual approval" % map_seed)
		_expect(not _has_violation(validation, "central_plaza_exclusion_contract_missing"), "seed %d must publish the authored central-plaza no-road polygon" % map_seed)
		_expect(not _has_violation(validation, "central_plaza_road_crossing"), "seed %d compiled road draws must stop at the central-plaza rim" % map_seed)
		_expect(not _has_violation(validation, "central_plaza_forecourt_count_mismatch"), "seed %d must place exact entrance forecourts at both plaza rim gates" % map_seed)
		_expect(not _has_violation(validation, "basis_endcap_treatment_missing"), "seed %d must cover every exposed straight-piece endpoint" % map_seed)
		_expect(not _has_violation(validation, "basis_cap_overlap_contract_invalid"), "seed %d collinear continuation must use the authored cap-depth overlap" % map_seed)
		_expect(not _has_violation(validation, "exit_world_bleed_contract_invalid"), "seed %d exit road must bleed past the visible world instead of exposing a hard cap" % map_seed)
		_expect(not _has_violation(validation, "road_material_hierarchy_invalid"), "seed %d must bind the approved main/secondary/trail material hierarchy" % map_seed)
		_expect(not _has_violation(validation, "main_spine_turn_budget_exceeded"), "seed %d spawn-to-plaza spine must stay within four turns" % map_seed)
		if _has_violation(validation, "road_network_composition_unapproved"):
			composition_blocked_seed_count += 1
		var plan_metrics := validation.get("metrics", {}) as Dictionary
		var composition_metrics := plan_metrics.get("road_composition", {}) as Dictionary
		var layout_overlap_count := _dictionary_array(promoted.get("road_crossing_bindings", [])).size()
		_expect(int(plan_metrics.get("road_overlap_record_count", -1)) == layout_overlap_count, "seed %d compiler must preserve every explicit overlap record" % map_seed)
		_expect(layout_overlap_count == 0, "seed %d must compile a crossing-free road graph" % map_seed)
		_expect(int(composition_metrics.get("screen_vertical_segment_count", -1)) == 0, "seed %d must compile zero screen-vertical straight-road draws" % map_seed)
		_expect(bool(composition_metrics.get("road_width_hierarchy_valid", false)), "seed %d must retain main > approach > secondary > trail width hierarchy" % map_seed)
		_expect(bool(composition_metrics.get("road_material_hierarchy_valid", false)), "seed %d must retain ceremonial main/approach, trimless secondary, and earth/gravel trail materials" % map_seed)
		_expect(bool(composition_metrics.get("central_plaza_exclusion_contract_present", false)), "seed %d must consume the authored central-plaza exclusion polygon" % map_seed)
		_expect(int(composition_metrics.get("central_plaza_crossing_count", -1)) == 0, "seed %d must compile zero road draws through the central plaza" % map_seed)
		_expect(int(composition_metrics.get("central_plaza_forecourt_count", -1)) == 2, "seed %d must retain exact two central-plaza forecourts" % map_seed)
		_expect(int(composition_metrics.get("basis_endpoint_without_special_cover_count", -1)) == 0, "seed %d must leave zero exposed basis end caps" % map_seed)
		_expect(int(composition_metrics.get("basis_endpoint_hub_rim_cover_count", -1)) == PlazaMapRoadSkeletonR3.EXPECTED_CENTRAL_PLAZA_RIM_JOIN_COUNT, "seed %d must expose the exact authored set of unique hub-rim joins" % map_seed)
		_expect(int(composition_metrics.get("basis_endpoint_soft_turn_overlap_count", 0)) > 0, "seed %d approach/trail soft-turn overlap contract must be materially exercised" % map_seed)
		_expect(int(composition_metrics.get("basis_endpoint_exit_world_bleed_count", -1)) == 1, "seed %d must hide the one exit cap beyond the visible world" % map_seed)
		_expect(int(composition_metrics.get("turn_court_count", 999)) <= PlazaMapRoadSkeletonR3.MAX_ROAD_TURN_COURT_COUNT, "seed %d must keep rotation-symmetric turn courts within the composition budget" % map_seed)
		var turn_kind_counts := composition_metrics.get("turn_court_edge_kind_counts", {}) as Dictionary
		_expect(int(turn_kind_counts.get("trail", -1)) == 0 and int(turn_kind_counts.get("approach", -1)) == 0 and int(turn_kind_counts.get("other", -1)) == 0, "seed %d bright turn courts must remain limited to main/secondary streets" % map_seed)
		_expect(bool(composition_metrics.get("basis_cap_overlap_contract_valid", false)), "seed %d must extend every straight draw by the fixed cap overlap" % map_seed)
		_expect(bool(composition_metrics.get("exit_world_bleed_contract_valid", false)), "seed %d exit bleed must preserve its exact derived geometry" % map_seed)
		_expect(int(composition_metrics.get("rendered_spawn_to_plaza_turn_count", 999)) <= PlazaMapRoadSkeletonR3.MAX_MAIN_SPINE_TURN_COUNT, "seed %d rendered spawn-to-plaza main route must stay within the four-turn budget" % map_seed)
		aggregate_uncovered_basis_endcaps += int(composition_metrics.get("basis_endpoint_without_special_cover_count", 0))
		aggregate_overlap_count += layout_overlap_count
		_expect(str(plan.get("fingerprint", "")) == str(repeated.get("fingerprint", "")), "seed %d environment compilation must be deterministic" % map_seed)
		_expect(str(plan.get("fingerprint", "")).length() == 64, "seed %d environment plan must expose a fingerprint" % map_seed)
		var hub_binding := plan.get("walkable_hub_contract_binding", {}) as Dictionary
		_expect(str(hub_binding.get("contract_id", "")) == PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_HUB_CONTRACT_ID and str(hub_binding.get("layout_record_id", "")) == PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_HUB_ID, "seed %d compiler must bind the runtime hub to the independent art manifest" % map_seed)
		_expect(not fingerprints.has(str(plan.get("fingerprint", ""))), "seed %d must not collide with an earlier environment plan" % map_seed)
		fingerprints[str(plan.get("fingerprint", ""))] = map_seed
		var slopes := composition_metrics.get("basis_counts", {}) as Dictionary
		for basis in aggregate_basis.keys():
			aggregate_basis[basis] = int(aggregate_basis.get(basis, 0)) + int(slopes.get(basis, 0))
		total_segments += int(composition_metrics.get("basis_segment_count", 0))
		var road_draws := _dictionary_array(plan.get("road_draws", []))
		var basis_draws := road_draws.filter(func(record: Dictionary) -> bool: return str(record.get("role", "")) == "basis_segment")
		var expected_basis_draws := _dictionary_array(promoted.get("road_piece_bindings", [])).filter(func(record: Dictionary) -> bool: return str(record.get("role", "")) == "basis_segment")
		_expect(basis_draws.size() == expected_basis_draws.size(), "seed %d must bind every renderable non-vertical road segment exactly once" % map_seed)
		for record in road_draws:
			_expect(is_zero_approx(float(record.get("rotation_degrees", 999.0))), "seed %d road draw %s must not rotate an approved sprite" % [map_seed, str(record.get("id", ""))])
			_expect(not bool(record.get("flip_h", true)) and not bool(record.get("flip_v", true)), "seed %d road draw %s must not mirror an approved sprite" % [map_seed, str(record.get("id", ""))])
			aggregate_assets[str(record.get("asset_id", ""))] = int(aggregate_assets.get(str(record.get("asset_id", "")), 0)) + 1
		var pads := _dictionary_array(plan.get("plot_pad_draws", []))
		_expect(pads.size() == roster.size(), "seed %d must compile one plot pad per occupied building plot" % map_seed)
		var seed_decor_assets: Array[String] = []
		for record in _dictionary_array(plan.get("decor_draws", [])):
			var cluster_type := str(record.get("cluster_type", ""))
			var decor_asset_id := str(record.get("asset_id", ""))
			if not observed_cluster_types.has(cluster_type):
				observed_cluster_types.append(cluster_type)
			if not seed_decor_assets.has(decor_asset_id):
				seed_decor_assets.append(decor_asset_id)
			aggregate_decor_assets[decor_asset_id] = int(aggregate_decor_assets.get(decor_asset_id, 0)) + 1
			_expect(decor_asset_id == PlazaR3EnvironmentLayoutCompiler.get_decor_asset_id(cluster_type), "seed %d decor %s must use its explicit semantic mapping" % [map_seed, cluster_type])
		if seed_decor_assets.has("ritual_stone_garden") and seed_decor_assets.has("stone_lantern_rest") and visual_seed_with_both_new_assets < 0:
			visual_seed_with_both_new_assets = map_seed
	_expect(total_segments > 0, "production-selected 24-seed rendered basis census must remain non-vacuous")
	_expect(int(aggregate_basis.get("vertical", -1)) == 0, "production-selected rendered basis census must contain zero screen-vertical roads: %s" % aggregate_basis)
	_expect(int(aggregate_basis.get("horizontal", 0)) > 0 and int(aggregate_basis.get("positive", 0)) > 0 and int(aggregate_basis.get("negative", 0)) > 0, "three approved ground-hugging bases must all remain materially consumed: %s" % aggregate_basis)
	_expect(composition_blocked_seed_count == SEED_CENSUS_COUNT, "all 24 production seeds must expose the whole-road composition decision")
	_expect(aggregate_overlap_count == 0, "24-seed compiler must preserve zero non-node road crossings")
	_expect(aggregate_uncovered_basis_endcaps == 0, "24-seed compiler must leave zero uncovered basis endpoints")
	for asset_id in EXPECTED_ROAD_RENDER_ASSET_IDS:
		_expect(int(aggregate_assets.get(asset_id, 0)) > 0, "every approved rendered road asset %s must retain a concrete production-seed consumer" % asset_id)
	_expect(int(aggregate_assets.get("straight_vertical", 0)) == 0, "retired screen-vertical art must remain intentionally unbound")
	for asset_id in EXPECTED_ASSET_IDS:
		_expect(int(aggregate_decor_assets.get(asset_id, 0)) > 0, "every semantic decor asset %s must have a production-seed consumer" % asset_id)
	_expect(visual_seed_with_both_new_assets > 0, "24-seed corpus must contain a real layout displaying both new semantic decor assets")
	observed_cluster_types.sort()
	_expect(observed_cluster_types.size() >= 12, "24-seed production census must materially observe the known 12 decor types")
	print("plaza_r3a1_environment_layout_compiler_smoke: seeds=24 composition_blocked=%d overlaps=%d uncovered_endcaps=%d segments=%d slopes=%s observed_decor=%s visual_seed=%d decor_assets=%s" % [composition_blocked_seed_count, aggregate_overlap_count, aggregate_uncovered_basis_endcaps, total_segments, aggregate_basis, observed_cluster_types, visual_seed_with_both_new_assets, aggregate_decor_assets])
	_complete_leg("production_seed_census", assertion_start)


func _verify_plan_mutation_counterproofs() -> void:
	var assertion_start := _assertion_count
	var roster := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, false, false)
	var promoted := PlazaMapRoadSkeletonR3.generate(1, 5, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
	var plan := PlazaR3EnvironmentLayoutCompiler.compile_layout(promoted)
	_expect(not bool((plan.get("validation", {}) as Dictionary).get("valid", true)), "seed 5 fixture must preserve the whole-road composition blocker")
	_expect(_has_violation(plan.get("validation", {}) as Dictionary, "road_network_composition_unapproved"), "seed 5 baseline must expose unapproved road composition")
	_expect(not _has_violation(plan.get("validation", {}) as Dictionary, "road_special_orientation_unrepresentable"), "seed 5 baseline special pieces must be direction-compatible")
	var unmapped_plan := plan.duplicate(true)
	var decor_draws := _dictionary_array(unmapped_plan.get("decor_draws", []))
	if not decor_draws.is_empty():
		decor_draws[0] = decor_draws[0].duplicate(true)
		decor_draws[0]["cluster_type"] = "__unmapped_runtime_type__"
		unmapped_plan["decor_draws"] = decor_draws
		unmapped_plan["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(unmapped_plan)
		var unmapped_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(unmapped_plan, promoted)
		_expect(not bool(unmapped_validation.get("valid", true)), "runtime decor cluster mutation must fail closed even with a synchronized fingerprint")
		_expect(_has_violation(unmapped_validation, "decor_semantic_mapping_mismatch"), "runtime decor mutation must expose semantic mismatch")
	var rotated := plan.duplicate(true)
	var road_draws := _dictionary_array(rotated.get("road_draws", []))
	if not road_draws.is_empty():
		road_draws[0] = road_draws[0].duplicate(true)
		road_draws[0]["rotation_degrees"] = 13.0
		rotated["road_draws"] = road_draws
		rotated["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(rotated)
		var rotated_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(rotated, promoted)
		_expect(not bool(rotated_validation.get("valid", true)), "approved road rotation must remain a RED even with synchronized fingerprint")
		_expect(_has_violation(rotated_validation, "road_draw_invalid"), "road rotation RED must be reported by actual draw validation")
	var missing_segment := plan.duplicate(true)
	var shortened := _dictionary_array(missing_segment.get("road_draws", []))
	for index in range(shortened.size()):
		if str(shortened[index].get("role", "")) == "basis_segment":
			shortened.remove_at(index)
			break
	missing_segment["road_draws"] = shortened
	missing_segment["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(missing_segment)
	var missing_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(missing_segment, promoted)
	_expect(not bool(missing_validation.get("valid", true)), "removing one concrete basis draw must fail closed")
	_expect(_has_violation(missing_validation, "road_basis_coverage_mismatch"), "missing basis draw must expose coverage mismatch")
	var injected_overlap := plan.duplicate(true)
	injected_overlap["road_overlap_records"] = [{"id": "qa_fake_crossing"}]
	injected_overlap["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(injected_overlap)
	var overlap_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(injected_overlap, promoted)
	_expect(_has_violation(overlap_validation, "road_overlap_record_mismatch"), "injecting a fake non-node overlap must fail closed")
	var false_composition := plan.duplicate(true)
	var false_metrics := (false_composition.get("road_composition_metrics", {}) as Dictionary).duplicate(true)
	false_metrics["screen_vertical_segment_count"] = 1
	false_composition["road_composition_metrics"] = false_metrics
	false_composition["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(false_composition)
	var false_composition_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(false_composition, promoted)
	_expect(_has_violation(false_composition_validation, "road_composition_metrics_mismatch"), "caller-synchronized composition claims must be rederived from draw geometry")
	var stale_hub_binding := plan.duplicate(true)
	var hub_binding := (stale_hub_binding.get("walkable_hub_contract_binding", {}) as Dictionary).duplicate(true)
	hub_binding["polygon_sha256"] = "0".repeat(64)
	stale_hub_binding["walkable_hub_contract_binding"] = hub_binding
	stale_hub_binding["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(stale_hub_binding)
	var stale_hub_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(stale_hub_binding, promoted)
	_expect(_has_violation(stale_hub_validation, "walkable_hub_catalog_binding_mismatch"), "a rehashed plan must not replace the independently authored walkable-hub binding")
	var trail_court := plan.duplicate(true)
	var trail_court_draws := _dictionary_array(trail_court.get("road_draws", []))
	for draw_index in range(trail_court_draws.size()):
		if str(trail_court_draws[draw_index].get("asset_id", "")) != "turn_court":
			continue
		var trail_court_draw: Dictionary = trail_court_draws[draw_index].duplicate(true)
		trail_court_draw["edge_kind"] = "trail"
		trail_court_draws[draw_index] = trail_court_draw
		break
	trail_court["road_draws"] = trail_court_draws
	trail_court["fingerprint"] = PlazaR3EnvironmentLayoutCompiler.build_fingerprint(trail_court)
	var trail_court_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(trail_court, promoted)
	_expect(_has_violation(trail_court_validation, "turn_court_edge_kind_forbidden"), "a rehashed bright court on a dirt trail must turn the material-tier contract RED")
	_complete_leg("mutation_counterproofs", assertion_start)


func _verify_production_disconnection() -> void:
	var assertion_start := _assertion_count
	var plaza_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_expect(not plaza_source.contains("plaza_r3_environment_layout_compiler"), "R3-A1 compiler must remain absent from production PlazaScene")
	_expect(not project_source.contains("plaza_r3_environment_layout_compiler"), "R3-A1 compiler must remain absent from project wiring")
	_complete_leg("production_disconnection", assertion_start)


func _complete_leg(leg_name: String, assertion_start: int) -> void:
	if _leg_assertion_counts.has(leg_name):
		_failures.append("GRT-040 completion gate: verification leg completed twice: %s" % leg_name)
		return
	_leg_assertion_counts[leg_name] = _assertion_count - assertion_start
	_legs_completed += 1


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


func _has_violation(result: Dictionary, code: String) -> bool:
	for violation in _dictionary_array(result.get("violations", [])):
		if str(violation.get("code", "")) == code:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
