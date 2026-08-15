extends SceneTree

# R3-A0.6 is a production-disconnected integrated generator. This smoke seals the
# complete 168-roster corpus, an independent 24-seed slope census, exact
# R2 selection/order/plot-class/RNG semantic preservation, regenerated
# coordinates and walkable corridors, and
# direction-compatible consumption of every approved road-piece role, including
# the rotation-symmetric degree-two turn court.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")
const PlazaMapNavigationCompiled := preload("res://scripts/plaza/plaza_map_navigation_compiled.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const SEED_CENSUS_COUNT := 24
const ENVIRONMENT_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r2_environment_manifest.json"
const EXTENSION_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r3a1_decor_extension_manifest.json"
const ROAD_HIERARCHY_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r3a1_road_hierarchy_manifest.json"
const SPECIAL_ARM_REQUIREMENTS := {
	"three_way": 60.0,
	"plot_spur": 64.0,
	"terminus": 60.0,
	"entrance_forecourt": 75.0,
}
const EXPECTED_COMPLETED_LEGS := 6
const MIN_ASSERTIONS_BY_LEG := {
	"approved_road_catalog": 12,
	"authored_png_orientation": 10,
	"seed_census": 480,
	"legal_roster_corpus": 170,
	"counterproofs": 15,
	"production_disconnection": 2,
}

var _failures: Array[String] = []
var _assertion_count := 0
var _legs_completed := 0
var _leg_assertion_counts := {}


func _init() -> void:
	var full_specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, true, false)
	_expect(full_specs.size() == 7, "fixture must expose all seven approved building manifests")
	_verify_approved_road_catalog()
	_verify_authored_png_orientation_contract()
	if full_specs.size() == 7:
		_verify_seed_census(full_specs)
		_verify_legal_roster_corpus(full_specs)
		_verify_counterproofs(full_specs)
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
		print("plaza_r3a0_oblique_road_skeleton_smoke: ok")
		print("plaza_r3a0_oblique_road_skeleton_smoke: legs=%d assertions=%d" % [_legs_completed, _assertion_count])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_seed_census(full_specs: Array[Dictionary]) -> void:
	var assertion_start := _assertion_count
	var aggregate_usage := _empty_usage()
	var aggregate_direction_compatible_usage := _empty_usage()
	var aggregate_slopes := {"horizontal": 0, "vertical": 0, "positive": 0, "negative": 0}
	var fingerprints := {}
	var promoted_segment_count := 0
	var promoted_crossing_count := 0
	var authored_special_vertical_count := 0
	var special_arm_runs := {
		"three_way": [] as Array[float],
		"plot_spur": [] as Array[float],
		"terminus": [] as Array[float],
		"entrance_forecourt": [] as Array[float],
	}
	for map_seed in range(1, SEED_CENSUS_COUNT + 1):
		var roster := PlazaAssetLoader.build_hwangyeok_building_specs(1, map_seed, false, false)
		var source := PlazaMapLayoutGenerator.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
		var promoted := PlazaMapRoadSkeletonR3.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
		var repeated := PlazaMapRoadSkeletonR3.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
		var validation := promoted.get("validation", {}) as Dictionary
		_expect(bool(validation.get("valid", false)), "seed %d integrated road-first layout must pass geometry validation: %s" % [map_seed, validation.get("violations", [])])
		if not bool(validation.get("valid", false)):
			continue
		_expect(str(promoted.get("fingerprint", "")).length() == 64, "seed %d must expose a concrete R3-A0.6 fingerprint" % map_seed)
		_expect(str(promoted.get("fingerprint", "")) == str(repeated.get("fingerprint", "")), "seed %d integrated generation must be deterministic" % map_seed)
		_expect(str(promoted.get("fingerprint", "")) != str(source.get("fingerprint", "")), "seed %d versioned road geometry must not retain the R2 fingerprint" % map_seed)
		_expect(str(promoted.get("source_layout_fingerprint", "")) == str(source.get("fingerprint", "")), "seed %d must bind its exact R2 source fingerprint" % map_seed)
		_verify_r2_semantics_preserved(source, promoted, roster, "seed=%d" % map_seed)
		_verify_compiled_main_route(promoted, map_seed)
		var metrics := validation.get("metrics", {}) as Dictionary
		_expect(int(metrics.get("arbitrary_segment_count", -1)) == 0, "seed %d must contain zero arbitrary road slopes" % map_seed)
		_expect(int(metrics.get("terminus_signature_count", -1)) == 1, "seed %d must expose one authored NE terminus at spawn" % map_seed)
		_expect(int(metrics.get("plot_spur_signature_count", -1)) == int((promoted.get("road_piece_usage", {}) as Dictionary).get("plot_spur", -2)), "seed %d every decor trail leaf must consume its authored NW spur arm" % map_seed)
		_expect(int(metrics.get("forecourt_signature_count", -1)) + 2 == int((promoted.get("road_piece_usage", {}) as Dictionary).get("entrance_forecourt", -2)), "seed %d occupied approaches plus two central-plaza gates must consume authored forecourts" % map_seed)
		_expect(int(metrics.get("three_way_signature_count", -1)) == _authored_node_role_count("road_piece_junction"), "seed %d every shared-trunk branch junction must expose the authored NE|NW|S three-way" % map_seed)
		_expect(int(metrics.get("effective_degree_four_count", -1)) == 0, "seed %d must eliminate effective degree-four junctions" % map_seed)
		_expect(float(metrics.get("minimum_art_arm_run_world", 0.0)) >= 54.0, "seed %d special directions must come from physical runs, never 2-world tokens" % map_seed)
		_expect(float(metrics.get("minimum_art_arm_to_half_piece_ratio", 0.0)) + 0.001 >= 1.0, "seed %d every measured direction must remain continuous beyond the centered art arm extent" % map_seed)
		_expect(int(metrics.get("forecourt_arm_below_required_count", -1)) == 0, "seed %d must reserve every 75-world entrance forecourt before plot placement" % map_seed)
		var crossings := _dictionary_array(promoted.get("road_crossing_bindings", []))
		_expect(crossings.is_empty(), "seed %d must promote or avoid every physical road crossing instead of hiding it with turn-court art" % map_seed)
		promoted_crossing_count += crossings.size()
		authored_special_vertical_count += int(metrics.get("authored_special_vertical_segment_count", 0))
		_expect(int(metrics.get("screen_vertical_straight_binding_count", -1)) == 0, "seed %d must never bind the retired screen-vertical straight sprite" % map_seed)
		_expect(int(metrics.get("main_spine_turn_count", 999)) <= PlazaMapRoadSkeletonR3.MAX_MAIN_SPINE_TURN_COUNT, "seed %d spawn-to-plaza spine must stay within the four-turn budget" % map_seed)
		_expect(int(metrics.get("turn_court_count", 999)) <= PlazaMapRoadSkeletonR3.MAX_ROAD_TURN_COURT_COUNT, "seed %d must keep authored turn courts within the twenty-court composition budget" % map_seed)
		_expect(int(metrics.get("shared_secondary_trunk_edge_count", -1)) == PlazaMapRoadSkeletonR3.R3_SECONDARY_EDGE_SPECS.size(), "seed %d must publish the exact authored shared secondary tree" % map_seed)
		_expect(int(metrics.get("upper_secondary_trunk_edge_count", -1)) == _authored_trunk_edge_count("upper"), "seed %d must publish every authored upper shared-trunk edge" % map_seed)
		_expect(int(metrics.get("lower_secondary_trunk_edge_count", -1)) == _authored_trunk_edge_count("lower"), "seed %d must publish every authored lower shared-trunk edge" % map_seed)
		_expect(int(metrics.get("southeast_secondary_trunk_edge_count", -1)) == _authored_trunk_edge_count("southeast"), "seed %d must publish both authored south-east branches" % map_seed)
		_expect(int(metrics.get("central_plaza_exclusion_zone_count", -1)) == 1, "seed %d must publish one authored central-plaza exclusion polygon" % map_seed)
		_expect(int(metrics.get("central_plaza_walkable_hub_count", -1)) == 1, "seed %d must publish one independently authored walkable plaza hub" % map_seed)
		_expect(int(metrics.get("plot_exclusion_overlap_count", -1)) == 0, "seed %d must place every plot outside the central-plaza art exclusion" % map_seed)
		_expect(int(metrics.get("forecourt_exclusion_overlap_count", -1)) == 0, "seed %d must reserve occupied forecourts outside the central-plaza art exclusion" % map_seed)
		_expect(int(metrics.get("missing_forecourt_reservation_count", -1)) == 0, "seed %d must publish every occupied 75-world forecourt reservation" % map_seed)
		_expect(int(metrics.get("plot_outside_semantic_band_count", -1)) == 0, "seed %d every resolved plot pivot must remain inside its authored semantic band" % map_seed)
		_expect(int(metrics.get("special_binding_inside_exclusion_count", -1)) == 0, "seed %d must keep all authored road plates outside the central-plaza interior" % map_seed)
		var slope_counts := metrics.get("slope_counts", {}) as Dictionary
		for slope_name in aggregate_slopes.keys():
			aggregate_slopes[slope_name] = int(aggregate_slopes.get(slope_name, 0)) + int(slope_counts.get(slope_name, 0))
		promoted_segment_count += int(metrics.get("segment_count", 0))
		var usage := promoted.get("road_piece_usage", {}) as Dictionary
		var compatible_usage := metrics.get("direction_compatible_usage", {}) as Dictionary
		var bindings := _dictionary_array(promoted.get("road_piece_bindings", []))
		_expect(not bindings.is_empty(), "seed %d must publish concrete road-piece binding records for A1" % map_seed)
		var turn_kind_counts := metrics.get("turn_court_edge_kind_counts", {}) as Dictionary
		_expect(int(turn_kind_counts.get("trail", -1)) == 0 and int(turn_kind_counts.get("approach", -1)) == 0 and int(turn_kind_counts.get("other", -1)) == 0, "seed %d turn courts must be limited to main/secondary roads" % map_seed)
		_measure_independent_arm_runs(promoted, bindings, special_arm_runs)
		for asset_id in PlazaMapRoadSkeletonR3.ROAD_PIECE_IDS:
			var binding_count := _binding_count(bindings, str(asset_id))
			_expect(binding_count == int(usage.get(asset_id, -1)), "seed %d usage for %s must equal its concrete binding count" % [map_seed, asset_id])
			_expect(int(compatible_usage.get(asset_id, -1)) == binding_count, "seed %d every %s binding must match the authored direction contract" % [map_seed, asset_id])
			aggregate_usage[asset_id] = int(aggregate_usage.get(asset_id, 0)) + binding_count
			aggregate_direction_compatible_usage[asset_id] = int(aggregate_direction_compatible_usage.get(asset_id, 0)) + int(compatible_usage.get(asset_id, 0))
		var fingerprint := str(promoted.get("fingerprint", ""))
		_expect(not fingerprints.has(fingerprint), "seed %d must not collide with an earlier R3-A0.6 fingerprint" % map_seed)
		fingerprints[fingerprint] = map_seed
	_expect(promoted_segment_count > 0, "24-seed physical segment census must remain non-vacuous")
	_expect(promoted_crossing_count == 0, "24-seed graph must contain zero non-node road crossings")
	_expect(int(aggregate_slopes.get("vertical", -1)) == authored_special_vertical_count, "every residual vertical segment must be owned by an authored three-way arm")
	_expect(int(aggregate_slopes.get("positive", 0)) > 0, "24-seed census must materially consume the previously absent +0.5 basis")
	_expect(int(aggregate_slopes.get("negative", 0)) > 0, "24-seed census must retain the -0.5 basis")
	_expect(int(aggregate_slopes.get("horizontal", 0)) > 0, "24-seed census must retain horizontal connectors")
	for asset_id in PlazaMapRoadSkeletonR3.ROAD_PIECE_IDS:
		_expect(int(aggregate_usage.get(asset_id, 0)) > 0, "approved road piece %s must have at least one concrete consumer" % asset_id)
		_expect(int(aggregate_direction_compatible_usage.get(asset_id, 0)) > 0, "approved road piece %s must have at least one direction-compatible consumer" % asset_id)
	_expect(not aggregate_usage.has("straight_vertical"), "retired screen-vertical art must not remain in the bindable road-piece contract")
	var special_arm_summary := _verify_independent_special_arm_census(special_arm_runs)
	print("plaza_r3a0_oblique_road_skeleton_smoke: seeds=24 segments=%d crossings=%d slopes=%s special_vertical=%d pieces=%s compatible=%s special_arms=%s" % [promoted_segment_count, promoted_crossing_count, aggregate_slopes, authored_special_vertical_count, aggregate_usage, aggregate_direction_compatible_usage, special_arm_summary])
	_complete_leg("seed_census", assertion_start)


func _verify_approved_road_catalog() -> void:
	var assertion_start := _assertion_count
	var actual_ids: Array[String] = []
	for manifest_path in [ENVIRONMENT_MANIFEST_PATH, EXTENSION_MANIFEST_PATH]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		_expect(parsed is Dictionary, "approved environment manifest must parse: %s" % manifest_path)
		if not (parsed is Dictionary):
			continue
		var manifest := parsed as Dictionary
		_expect(bool(manifest.get("candidate_only", false)) and not bool(manifest.get("production_connected", true)), "A0.4 must consume approved but production-disconnected environment catalogs")
		for asset_value in manifest.get("assets", []) as Array:
			if asset_value is Dictionary and str((asset_value as Dictionary).get("kind", "")) == "road_piece":
				actual_ids.append(str((asset_value as Dictionary).get("asset_id", "")))
	var hierarchy_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROAD_HIERARCHY_MANIFEST_PATH))
	_expect(hierarchy_parsed is Dictionary, "approved road-hierarchy manifest must parse")
	if hierarchy_parsed is Dictionary:
		var hierarchy := hierarchy_parsed as Dictionary
		_expect(bool(hierarchy.get("candidate_only", false)) and not bool(hierarchy.get("production_connected", true)), "turn-court art must remain production-disconnected in A0.6")
		for asset_value in hierarchy.get("assets", []) as Array:
			if asset_value is Dictionary and str((asset_value as Dictionary).get("asset_id", "")) == "turn_court":
				actual_ids.append("turn_court")
		var geometry_value: Variant = hierarchy.get("approved_layout_geometry", null)
		_expect(geometry_value is Dictionary, "road hierarchy manifest must publish authored layout geometry")
		if geometry_value is Dictionary:
			var hub_value: Variant = (geometry_value as Dictionary).get("central_plaza_walkable_hub", null)
			_expect(hub_value is Dictionary, "road hierarchy manifest must publish exactly the central plaza hub contract")
			if hub_value is Dictionary:
				var hub := hub_value as Dictionary
				var authored_polygon := _json_polygon_to_vector2(hub.get("polygon_world", null))
				_expect((geometry_value as Dictionary).size() == 1, "road hierarchy manifest must not hide extra layout geometry contracts")
				_expect(str(hub.get("id", "")) == PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_HUB_CONTRACT_ID, "manifest hub contract id must match the runtime binding id")
				_expect(str(hub.get("layout_record_id", "")) == PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_HUB_ID, "manifest hub record id must match the navigation manifest")
				_expect(authored_polygon == PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD, "runtime hub polygon must equal the independently authored manifest polygon")
				_expect(str(hub.get("polygon_sha256", "")) == _independent_polygon_token(authored_polygon).sha256_text(), "manifest hub polygon SHA must be derived from authored points")
				_expect(str(hub.get("navigation_policy", "")) == "full_body_walkable_union_member", "manifest hub must explicitly enter the full-body walkable union")
				_expect(str(hub.get("road_render_policy", "")) == "no_straight_stamp_inside_hub", "manifest hub must prohibit hidden straight-road stamps")
	var expected_ids: Array[String] = []
	for asset_id_value in PlazaMapRoadSkeletonR3.ROAD_PIECE_IDS:
		expected_ids.append(str(asset_id_value))
	expected_ids.append("straight_vertical")
	actual_ids.sort()
	expected_ids.sort()
	_expect(actual_ids == expected_ids, "R3-A0.6 must retain the approved vertical source only as an intentionally unbound catalog artifact")
	_complete_leg("approved_road_catalog", assertion_start)


func _verify_authored_png_orientation_contract() -> void:
	var assertion_start := _assertion_count
	var authored_paths := {}
	for manifest_path in [ENVIRONMENT_MANIFEST_PATH, EXTENSION_MANIFEST_PATH]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not (parsed is Dictionary):
			continue
		for asset_value in (parsed as Dictionary).get("assets", []) as Array:
			if not (asset_value is Dictionary):
				continue
			var asset := asset_value as Dictionary
			var asset_id := str(asset.get("asset_id", ""))
			if PlazaMapRoadSkeletonR3.SPECIAL_ROAD_ORIENTATION_SIGNATURES.has(asset_id):
				authored_paths[asset_id] = str(asset.get("res_path", ""))
	_expect(authored_paths.size() == 4, "all four special road PNGs must be present for independent alpha-direction QA")
	var derived := {}
	for asset_id_value in authored_paths.keys():
		var asset_id := str(asset_id_value)
		var res_path := str(authored_paths.get(asset_id, ""))
		var image := Image.load_from_file(ProjectSettings.globalize_path(res_path))
		_expect(image != null and image.get_size() == Vector2i(512, 512), "authored road PNG must load at 512x512: %s" % res_path)
		if image == null or image.get_size() != Vector2i(512, 512):
			continue
		var signature := _derive_special_art_signature_from_alpha(image)
		derived[asset_id] = signature
		_expect(signature == str(PlazaMapRoadSkeletonR3.SPECIAL_ROAD_ORIENTATION_SIGNATURES.get(asset_id, "")), "code direction for %s must match authored PNG alpha geometry, derived=%s" % [asset_id, signature])
	_expect(derived == {
		"three_way": "north_east+north_west+south",
		"plot_spur": "trail_enters_south_east",
		"terminus": "terminus_opens_north_east",
		"entrance_forecourt": "approach_enters_north_east",
	}, "authored PNGs must independently derive the exact special-piece orientation contract: %s" % derived)
	_complete_leg("authored_png_orientation", assertion_start)


func _derive_special_art_signature_from_alpha(image: Image) -> String:
	# These disjoint outer-arm ROIs are measured from the approved runtime PNGs,
	# not from promoter constants. They distinguish the two diagonal axes, the
	# three physical Y arms, and the forecourt's narrow SW connector from its pad.
	var alpha_counts := {
		"north_west": _alpha_pixels(image, Rect2i(16, 80, 144, 130)),
		"north_east": _alpha_pixels(image, Rect2i(352, 80, 144, 130)),
		"south_west": _alpha_pixels(image, Rect2i(16, 300, 144, 130)),
		"south_east": _alpha_pixels(image, Rect2i(352, 300, 144, 130)),
		"south": _alpha_pixels(image, Rect2i(210, 300, 92, 130)),
		"east": _alpha_pixels(image, Rect2i(352, 210, 144, 92)),
	}
	var north_west := int(alpha_counts.get("north_west", 0))
	var north_east := int(alpha_counts.get("north_east", 0))
	var south_west := int(alpha_counts.get("south_west", 0))
	var south_east := int(alpha_counts.get("south_east", 0))
	var south := int(alpha_counts.get("south", 0))
	var east := int(alpha_counts.get("east", 0))
	if north_west > 8000 and north_east > 8000 and south > 8000 and south_west < 1000 and south_east < 1000:
		return "north_east+north_west+south"
	if north_west > 7000 and south_east > 7000 and north_east < 1000 and south_west < 1000:
		return "trail_enters_south_east"
	if north_east > 7000 and south_west > 7000 and north_west < 1000 and south_east < 1000:
		return "terminus_opens_north_east"
	if south_west > 5000 and east > 10000 and south_west > north_east * 4:
		return "approach_enters_north_east"
	return "unclassified:%s" % alpha_counts


func _alpha_pixels(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a8 >= 128:
				count += 1
	return count


func _verify_legal_roster_corpus(full_specs: Array[Dictionary]) -> void:
	var assertion_start := _assertion_count
	var bank := _find_by_type(full_specs, "bank")
	var optional: Array[Dictionary] = []
	for spec in full_specs:
		if str(spec.get("type", "")) != "bank":
			optional.append(spec)
	_expect(not bank.is_empty() and optional.size() == 6, "corpus fixture must expose one bank plus six unique optional buildings")
	if bank.is_empty() or optional.size() != 6:
		return
	var corpus_count := 0
	for map_seed in [5, 6, 7]:
		for mask in range(1, 1 << optional.size()):
			var optional_count := 0
			for index in range(optional.size()):
				if (mask & (1 << index)) != 0:
					optional_count += 1
			if optional_count < 1 or optional_count > 4:
				continue
			var roster: Array[Dictionary] = [bank.duplicate(true)]
			for index in range(optional.size()):
				if (mask & (1 << index)) != 0:
					roster.append(optional[index].duplicate(true))
			var source := PlazaMapLayoutGenerator.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
			var promoted := PlazaMapRoadSkeletonR3.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
			var validation := promoted.get("validation", {}) as Dictionary
			_expect(bool(validation.get("valid", false)), "corpus seed=%d roster=%s must pass oblique geometry/no-tunnel contracts: %s" % [map_seed, _building_types(roster), validation.get("violations", [])])
			if not bool(validation.get("valid", false)):
				continue
			_verify_r2_semantics_preserved(source, promoted, roster, "corpus seed=%d roster=%s" % [map_seed, _building_types(roster)])
			corpus_count += 1
	_expect(corpus_count == 168, "R3-A0.6 must revalidate all 56 legal rosters across three structural motifs")
	print("plaza_r3a0_oblique_road_skeleton_smoke: corpus=168")
	_complete_leg("legal_roster_corpus", assertion_start)


func _verify_counterproofs(full_specs: Array[Dictionary]) -> void:
	var assertion_start := _assertion_count
	var roster := _legal_roster_for_seed(full_specs, 5)
	var source := PlazaMapLayoutGenerator.generate(1, 5, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
	var promoted := PlazaMapRoadSkeletonR3.generate(1, 5, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
	var road := promoted.get("road_graph", {}) as Dictionary
	var edges := _dictionary_array(road.get("edges", []))
	_expect(not edges.is_empty(), "counterproof fixture must expose road edges")
	if edges.is_empty():
		return

	var right_edge_roster: Array[Dictionary] = [
		_find_by_type(full_specs, "bank").duplicate(true),
		_find_by_type(full_specs, "lingpet_store").duplicate(true),
	]
	var right_edge_layout := PlazaMapRoadSkeletonR3.generate(1, 1, WORLD_SIZE, right_edge_roster, SPAWN_ANCHOR, EXIT_ZONE)
	var right_edge_validation := right_edge_layout.get("validation", {}) as Dictionary
	_expect(bool(right_edge_validation.get("valid", false)), "the R3 east-edge lingpet fixture must generate valid geometry")
	var right_edge_store := _find_by_type(_dictionary_array(right_edge_layout.get("building_specs", [])), "lingpet_store")
	var fitted_label_value: Variant = right_edge_store.get("label_rect_world", null)
	var fitted_label_stem := right_edge_store.get("label_world_pos", Vector2.ZERO) as Vector2
	_expect(str(right_edge_layout.get("building_label_fit_policy", "")) == PlazaMapRoadSkeletonR3.BUILDING_LABEL_FIT_POLICY, "the layout must publish the explicit R3 label-fit policy")
	_expect(fitted_label_value is Rect2 and (fitted_label_value as Rect2).end.x < fitted_label_stem.x, "the east-edge label must physically use the R3 left-fit direction")
	_expect(fitted_label_value is Rect2 and (fitted_label_value as Rect2).position.x >= 0.0 and (fitted_label_value as Rect2).end.x <= WORLD_SIZE.x, "the fitted east-edge label must remain wholly inside the fixed map world")

	var wrong_r3_label_direction: Dictionary = right_edge_layout.duplicate(true)
	var wrong_r3_buildings := _dictionary_array(wrong_r3_label_direction.get("building_specs", []))
	for building_index in range(wrong_r3_buildings.size()):
		if str(wrong_r3_buildings[building_index].get("type", "")) != "lingpet_store":
			continue
		var wrong_building: Dictionary = wrong_r3_buildings[building_index].duplicate(true)
		var wrong_label := wrong_building.get("label_rect_world", Rect2()) as Rect2
		var label_stem := wrong_building.get("label_world_pos", Vector2.ZERO) as Vector2
		wrong_label.position = label_stem + Vector2(PlazaMapLayoutGenerator.LABEL_STEM_GAP_WORLD, -wrong_label.size.y * 0.5)
		wrong_building["label_rect_world"] = wrong_label
		wrong_r3_buildings[building_index] = wrong_building
		break
	wrong_r3_label_direction["building_specs"] = wrong_r3_buildings
	wrong_r3_label_direction["fingerprint"] = PlazaMapRoadSkeletonR3.build_fingerprint(wrong_r3_label_direction)
	var wrong_r3_label_validation := PlazaMapRoadSkeletonR3.validate_layout(wrong_r3_label_direction)
	_expect(
		_has_violation_detail(wrong_r3_label_validation, "r2_geometry_contract_failed", "label_rect_anchor_contract_mismatch"),
		"a rehashed right-growing label at the R3 east edge must turn the world-fit direction contract RED"
	)

	var r2_label_fixture := PlazaMapLayoutGenerator.generate(1, 1, WORLD_SIZE, right_edge_roster, SPAWN_ANCHOR, EXIT_ZONE)
	var r2_label_buildings := _dictionary_array(r2_label_fixture.get("building_specs", []))
	for building_index in range(r2_label_buildings.size()):
		if str(r2_label_buildings[building_index].get("type", "")) != "lingpet_store":
			continue
		var wrong_r2_building: Dictionary = r2_label_buildings[building_index].duplicate(true)
		var r2_label_rect := wrong_r2_building.get("label_rect_world", Rect2()) as Rect2
		var r2_label_stem := wrong_r2_building.get("label_world_pos", Vector2.ZERO) as Vector2
		r2_label_rect.position = r2_label_stem + Vector2(-PlazaMapLayoutGenerator.LABEL_STEM_GAP_WORLD - r2_label_rect.size.x, -r2_label_rect.size.y * 0.5)
		wrong_r2_building["label_rect_world"] = r2_label_rect
		r2_label_buildings[building_index] = wrong_r2_building
		break
	r2_label_fixture["building_specs"] = r2_label_buildings
	r2_label_fixture["fingerprint"] = PlazaMapLayoutGenerator.build_fingerprint(r2_label_fixture)
	var r2_label_validation := PlazaMapLayoutGenerator.validate_layout(r2_label_fixture)
	_expect(_has_violation(r2_label_validation, "label_rect_anchor_contract_mismatch"), "the production-disconnected R2 validator must retain its original right-growing label contract")

	var missing_label_policy: Dictionary = right_edge_layout.duplicate(true)
	missing_label_policy.erase("building_label_fit_policy")
	missing_label_policy["fingerprint"] = PlazaMapRoadSkeletonR3.build_fingerprint(missing_label_policy)
	var missing_label_policy_validation := PlazaMapRoadSkeletonR3.validate_layout(missing_label_policy)
	_expect(_has_violation(missing_label_policy_validation, "building_label_fit_policy_mismatch"), "removing and rehashing the R3 label-fit policy must turn the public contract RED")

	var arbitrary := promoted.duplicate(true)
	var arbitrary_road := arbitrary.get("road_graph", {}) as Dictionary
	var arbitrary_edges := _dictionary_array(arbitrary_road.get("edges", []))
	var arbitrary_edge := arbitrary_edges[0].duplicate(true)
	var arbitrary_polyline := _vector2_array(arbitrary_edge.get("polyline_world", []))
	if arbitrary_polyline.size() >= 2:
		arbitrary_polyline.insert(1, arbitrary_polyline[0] + Vector2(40.0, 13.0))
		arbitrary_edge["polyline_world"] = arbitrary_polyline
		arbitrary_edges[0] = arbitrary_edge
		arbitrary_road["edges"] = arbitrary_edges
		arbitrary["road_graph"] = arbitrary_road
		var arbitrary_validation := PlazaMapRoadSkeletonR3.validate_layout(arbitrary)
		_expect(_has_violation(arbitrary_validation, "road_segment_outside_oblique_basis"), "an arbitrary 0.325 segment must turn the oblique basis gate RED")

	var missing_positive := promoted.duplicate(true)
	var missing_usage := missing_positive.get("road_piece_usage", {}) as Dictionary
	missing_usage["straight_positive"] = 0
	missing_positive["road_piece_usage"] = missing_usage
	var missing_validation := PlazaMapRoadSkeletonR3.validate_layout(missing_positive)
	_expect(_has_violation(missing_validation, "approved_road_piece_unused"), "zero straight_positive consumers must turn the approved-piece gate RED")
	_expect(_has_violation(missing_validation, "road_piece_usage_mismatch"), "road-piece claims must be derived from actual geometry, not caller metadata")

	var missing_binding := promoted.duplicate(true)
	var bindings := _dictionary_array(missing_binding.get("road_piece_bindings", []))
	if not bindings.is_empty():
		bindings.remove_at(0)
		missing_binding["road_piece_bindings"] = bindings
		var binding_validation := PlazaMapRoadSkeletonR3.validate_layout(missing_binding)
		_expect(_has_violation(binding_validation, "road_piece_binding_mismatch"), "removing a concrete road-piece binding must turn validation RED")

	var leaf_direction_drift := promoted.duplicate(true)
	var leaf_road := leaf_direction_drift.get("road_graph", {}) as Dictionary
	var leaf_edges := _dictionary_array(leaf_road.get("edges", []))
	for edge_index in range(leaf_edges.size()):
		if str(leaf_edges[edge_index].get("kind", "")) != "trail":
			continue
		var leaf_edge := leaf_edges[edge_index].duplicate(true)
		var leaf_polyline := _vector2_array(leaf_edge.get("polyline_world", []))
		if leaf_polyline.size() < 3:
			continue
		leaf_polyline[leaf_polyline.size() - 2] = leaf_polyline[leaf_polyline.size() - 1] + Vector2.RIGHT * PlazaMapRoadSkeletonR3.PLOT_SPUR_ARM_RUN_WORLD
		leaf_edge["polyline_world"] = leaf_polyline
		leaf_edges[edge_index] = leaf_edge
		break
	leaf_road["edges"] = leaf_edges
	leaf_direction_drift["road_graph"] = leaf_road
	var leaf_direction_validation := PlazaMapRoadSkeletonR3.validate_layout(leaf_direction_drift)
	_expect(_has_violation(leaf_direction_validation, "canonical_plot_spur_signature_mismatch"), "an east-facing decor leaf must turn the authored NW plot-spur gate RED")
	_expect(_has_violation(leaf_direction_validation, "road_piece_orientation_incompatible"), "a direction-incompatible plot_spur binding must fail independently of raw ID counts")

	var junction_direction_drift := promoted.duplicate(true)
	var junction_road := junction_direction_drift.get("road_graph", {}) as Dictionary
	var junction_edges := _dictionary_array(junction_road.get("edges", []))
	for edge_index in range(junction_edges.size()):
		if str(junction_edges[edge_index].get("from", "")) != "upper_plot_junction_0" or not ["approach", "trail"].has(str(junction_edges[edge_index].get("kind", ""))):
			continue
		var junction_edge := junction_edges[edge_index].duplicate(true)
		var junction_polyline := _vector2_array(junction_edge.get("polyline_world", []))
		if junction_polyline.size() < 3:
			continue
		junction_polyline[1] = junction_polyline[0] + Vector2.RIGHT * PlazaMapRoadSkeletonR3.THREE_WAY_ARM_RUN_WORLD
		junction_edge["polyline_world"] = junction_polyline
		junction_edges[edge_index] = junction_edge
		break
	junction_road["edges"] = junction_edges
	junction_direction_drift["road_graph"] = junction_road
	var junction_direction_validation := PlazaMapRoadSkeletonR3.validate_layout(junction_direction_drift)
	_expect(_has_violation(junction_direction_validation, "canonical_three_way_signature_mismatch"), "an east arm at the split secondary junction must turn the authored NE|NW|S gate RED")
	_expect(_has_violation(junction_direction_validation, "road_piece_orientation_incompatible"), "a direction-incompatible three_way binding must fail independently of raw ID counts")

	var short_arm := promoted.duplicate(true)
	var short_road := short_arm.get("road_graph", {}) as Dictionary
	var short_edges := _dictionary_array(short_road.get("edges", []))
	for edge_index in range(short_edges.size()):
		if str(short_edges[edge_index].get("from", "")) != "upper_plot_junction_0" or not ["approach", "trail"].has(str(short_edges[edge_index].get("kind", ""))):
			continue
		var short_edge := short_edges[edge_index].duplicate(true)
		var short_polyline := _vector2_array(short_edge.get("polyline_world", []))
		if short_polyline.size() < 2:
			continue
		short_polyline[1] = short_polyline[0] + Vector2.DOWN * 2.0
		short_edge["polyline_world"] = short_polyline
		short_edges[edge_index] = short_edge
		break
	short_road["edges"] = short_edges
	short_arm["road_graph"] = short_road
	var short_validation := PlazaMapRoadSkeletonR3.validate_layout(short_arm)
	_expect(_has_violation(short_validation, "road_piece_arm_run_too_short"), "a 2-world token must not satisfy a 60-world authored arm contract")

	var non_junction_vertical: Dictionary = promoted.duplicate(true)
	var non_junction_road := non_junction_vertical.get("road_graph", {}) as Dictionary
	var non_junction_edges := _dictionary_array(non_junction_road.get("edges", []))
	for edge_index in range(non_junction_edges.size()):
		if str(non_junction_edges[edge_index].get("id", "")) != "secondary_upper_2":
			continue
		var vertical_edge: Dictionary = non_junction_edges[edge_index].duplicate(true)
		var vertical_polyline := _vector2_array(vertical_edge.get("polyline_world", []))
		if vertical_polyline.size() >= 2:
			vertical_polyline.insert(1, vertical_polyline[0] + Vector2.DOWN * 40.0)
			vertical_edge["polyline_world"] = vertical_polyline
			non_junction_edges[edge_index] = vertical_edge
		break
	non_junction_road["edges"] = non_junction_edges
	non_junction_vertical["road_graph"] = non_junction_road
	var non_junction_validation := PlazaMapRoadSkeletonR3.validate_layout(non_junction_vertical)
	_expect(_has_violation(non_junction_validation, "screen_vertical_road_segment_forbidden"), "a short vertical segment at a non-junction secondary node must stay RED")

	var raw_degree_four := promoted.duplicate(true)
	var degree_road := raw_degree_four.get("road_graph", {}) as Dictionary
	var degree_edges := _dictionary_array(degree_road.get("edges", []))
	var degree_source := {}
	for candidate in degree_edges:
		if str(candidate.get("from", "")) == "upper_plot_junction_0" and ["approach", "trail"].has(str(candidate.get("kind", ""))):
			degree_source = candidate
			break
	if not degree_source.is_empty():
		var duplicate_edge := degree_source.duplicate(true)
		duplicate_edge["id"] = "qa_duplicate_fourth_arm"
		degree_edges.append(duplicate_edge)
		degree_road["edges"] = degree_edges
		raw_degree_four["road_graph"] = degree_road
		var degree_validation := PlazaMapRoadSkeletonR3.validate_layout(raw_degree_four)
		_expect(_has_violation(degree_validation, "effective_degree_four_junction_remaining"), "raw fourth arms must fail before any direction deduplication")

	var injected_crossing := promoted.duplicate(true)
	injected_crossing["road_crossing_bindings"] = [{"id": "qa_fake_crossing"}]
	var crossing_validation := PlazaMapRoadSkeletonR3.validate_layout(injected_crossing)
	_expect(_has_violation(crossing_validation, "road_crossing_binding_mismatch"), "injecting a fake non-node overlap record must turn the crossing-free gate RED")

	var trunk_side_drift: Dictionary = promoted.duplicate(true)
	var trunk_road := trunk_side_drift.get("road_graph", {}) as Dictionary
	var trunk_edges := _dictionary_array(trunk_road.get("edges", []))
	for trunk_index in range(trunk_edges.size()):
		if str(trunk_edges[trunk_index].get("id", "")) != "secondary_upper_0":
			continue
		var trunk_edge: Dictionary = trunk_edges[trunk_index].duplicate(true)
		trunk_edge["trunk_side"] = "lower"
		trunk_edges[trunk_index] = trunk_edge
		break
	trunk_road["edges"] = trunk_edges
	trunk_side_drift["road_graph"] = trunk_road
	trunk_side_drift["fingerprint"] = PlazaMapRoadSkeletonR3.build_fingerprint(trunk_side_drift)
	var trunk_validation := PlazaMapRoadSkeletonR3.validate_layout(trunk_side_drift)
	_expect(_has_violation(trunk_validation, "r3_secondary_topology_mismatch"), "a rehashed upper/lower trunk ownership swap must turn the exact side-tree contract RED")

	var stale_hub_cap: Dictionary = promoted.duplicate(true)
	var stale_hubs := _dictionary_array(stale_hub_cap.get("walkable_hub_polygons", []))
	if not stale_hubs.is_empty():
		var stale_hub: Dictionary = stale_hubs[0].duplicate(true)
		stale_hub["cap_style"] = "square"
		stale_hubs[0] = stale_hub
		stale_hub_cap["walkable_hub_polygons"] = stale_hubs
		var stale_hub_validation := PlazaMapRoadSkeletonR3.validate_layout(stale_hub_cap)
		_expect(_has_violation(stale_hub_validation, "layout_fingerprint_mismatch"), "hub cap-style drift must alter the R3 fingerprint")

	var rehashed_hub_drift: Dictionary = promoted.duplicate(true)
	var drift_hubs := _dictionary_array(rehashed_hub_drift.get("walkable_hub_polygons", []))
	var drift_corridors := _dictionary_array(rehashed_hub_drift.get("walkable_corridor_polygons", []))
	if not drift_hubs.is_empty():
		var drift_hub: Dictionary = drift_hubs[0].duplicate(true)
		var drift_polygon := _vector2_array(drift_hub.get("polygon_world", []))
		if not drift_polygon.is_empty():
			drift_polygon[0] += Vector2(1.0, 0.0)
			drift_hub["polygon_world"] = drift_polygon
			drift_hubs[0] = drift_hub
			rehashed_hub_drift["walkable_hub_polygons"] = drift_hubs
			for corridor_index in range(drift_corridors.size()):
				if str(drift_corridors[corridor_index].get("id", "")) != PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_HUB_ID:
					continue
				drift_corridors[corridor_index] = drift_hub.duplicate(true)
			rehashed_hub_drift["walkable_corridor_polygons"] = drift_corridors
			var drift_contract := rehashed_hub_drift.get("central_plaza_hub_contract", {}) as Dictionary
			drift_contract["polygon_sha256"] = _independent_polygon_token(drift_polygon).sha256_text()
			rehashed_hub_drift["central_plaza_hub_contract"] = drift_contract
			rehashed_hub_drift["fingerprint"] = PlazaMapRoadSkeletonR3.build_fingerprint(rehashed_hub_drift)
			var rehashed_hub_validation := PlazaMapRoadSkeletonR3.validate_layout(rehashed_hub_drift)
			_expect(_has_violation(rehashed_hub_validation, "central_plaza_walkable_hub_manifest_mismatch"), "a self-consistently rehashed hub polygon must still fail the independent authored manifest contract")

	var stale_source := source.duplicate(true)
	stale_source["map_seed"] = 99
	var rejected := PlazaMapRoadSkeletonR3.promote_layout(stale_source)
	var rejected_validation := rejected.get("validation", {}) as Dictionary
	_expect(not bool(rejected_validation.get("valid", true)), "a source mutation under a stale fingerprint must fail closed")
	_expect(_has_violation(rejected_validation, "promotion_rejected"), "stale source rejection must be explicit")

	var invalid_source := source.duplicate(true)
	var invalid_road := invalid_source.get("road_graph", {}) as Dictionary
	var invalid_edges := _dictionary_array(invalid_road.get("edges", []))
	var invalid_edge := invalid_edges[0].duplicate(true)
	invalid_edge["half_width_world"] = 0.1
	invalid_edges[0] = invalid_edge
	invalid_road["edges"] = invalid_edges
	invalid_source["road_graph"] = invalid_road
	invalid_source["fingerprint"] = PlazaMapLayoutGenerator.build_fingerprint(invalid_source)
	# Keep the stale stored validation deliberately GREEN. A0.4 must still rerun
	# the source validator instead of trusting this caller-owned field.
	var invalid_rejected := PlazaMapRoadSkeletonR3.promote_layout(invalid_source)
	var invalid_validation := invalid_rejected.get("validation", {}) as Dictionary
	_expect(not bool(invalid_validation.get("valid", true)), "rehashed invalid source geometry must fail closed despite a stale GREEN validation field")
	_expect(_has_violation(invalid_validation, "promotion_rejected"), "source revalidation rejection must be explicit")

	var stale_promoted := promoted.duplicate(true)
	var stale_road := stale_promoted.get("road_graph", {}) as Dictionary
	var stale_edges := _dictionary_array(stale_road.get("edges", []))
	var stale_edge := stale_edges[0].duplicate(true)
	var stale_polyline := _vector2_array(stale_edge.get("polyline_world", []))
	if stale_polyline.size() >= 2:
		stale_polyline[1] += Vector2(0.0, 0.5)
		stale_edge["polyline_world"] = stale_polyline
		stale_edges[0] = stale_edge
		stale_road["edges"] = stale_edges
		stale_promoted["road_graph"] = stale_road
		var stale_promoted_validation := PlazaMapRoadSkeletonR3.validate_layout(stale_promoted)
		_expect(_has_violation(stale_promoted_validation, "layout_fingerprint_mismatch"), "post-generation geometry mutation must invalidate the stored R3-A0.6 fingerprint")

	var phase_tail_drift := promoted.duplicate(true)
	var semantic := phase_tail_drift.get("r2_semantic_invariants", {}) as Dictionary
	var phase_tails := semantic.get("phase_rng_tail_samples", {}) as Dictionary
	phase_tails["plots"] = int(phase_tails.get("plots", 0)) ^ 1
	semantic["phase_rng_tail_samples"] = phase_tails
	phase_tail_drift["r2_semantic_invariants"] = semantic
	phase_tail_drift["fingerprint"] = PlazaMapRoadSkeletonR3.build_fingerprint(phase_tail_drift)
	var phase_tail_validation := PlazaMapRoadSkeletonR3.validate_layout(phase_tail_drift)
	_expect(_has_violation(phase_tail_validation, "r2_phase_rng_tail_mismatch"), "a rehashed phase-tail mutation must still turn the four-stream semantic seal RED")

	# The accepted rear-landmark site must reserve the authored 60-world arm
	# against any compatible roster footprint before assignment materializes.
	# This old north-west candidate placed bank across junction_1's vertical arm.
	var bank_spec := _find_by_type(full_specs, "bank")
	var unsafe_rear_plot := PlazaMapRoadSkeletonR3._build_integrated_plot_record(
		"rear_landmark",
		"rear_landmark_large",
		2,
		"main_2",
		"upper_plot_junction_1",
		0.0,
		Vector2(1500.0, 285.0),
		[bank_spec] as Array[Dictionary]
	)
	var unsafe_bank := PlazaMapLayoutGenerator._place_building_spec(bank_spec, unsafe_rear_plot, 0)
	var unsafe_envelope := PlazaMapRoadSkeletonR3._build_roster_building_footprint_envelope([bank_spec] as Array[Dictionary], unsafe_rear_plot)
	var unsafe_arm_contract := PlazaMapRoadSkeletonR3._build_plot_route_contract(
		unsafe_rear_plot,
		{"position": Vector2(1500.0, 100.0), "role": "road_piece_junction"},
		unsafe_bank
	)
	_expect(
		PlazaMapRoadSkeletonR3._authored_branch_arm_envelope_rejection_reason(unsafe_arm_contract, unsafe_envelope) == "authored_branch_arm_overlap:roster_building_envelope",
		"the historical bank-vs-junction_1 arm collision must be rejected before plot assignment"
	)
	var shifted_envelope: Array[Vector2] = []
	for point in unsafe_envelope:
		shifted_envelope.append(point + Vector2.DOWN * 220.0)
	_expect(
		PlazaMapRoadSkeletonR3._authored_branch_arm_envelope_rejection_reason(unsafe_arm_contract, shifted_envelope) == "",
		"a roster footprint envelope physically clear of the authored arm must remain accepted"
	)

	var outside_band: Dictionary = promoted.duplicate(true)
	var outside_plots := _dictionary_array(outside_band.get("plots", []))
	if not outside_plots.is_empty():
		var outside_plot: Dictionary = outside_plots[0].duplicate(true)
		outside_plot["pivot_pos"] = Vector2(-1.0, -1.0)
		outside_plots[0] = outside_plot
		outside_band["plots"] = outside_plots
		outside_band["fingerprint"] = PlazaMapRoadSkeletonR3.build_fingerprint(outside_band)
		var outside_band_validation := PlazaMapRoadSkeletonR3.validate_layout(outside_band)
		_expect(_has_violation(outside_band_validation, "plot_outside_semantic_band"), "a rehashed pivot outside its authored class band must turn the semantic placement seal RED")
	_complete_leg("counterproofs", assertion_start)


func _verify_compiled_main_route(layout: Dictionary, map_seed: int) -> void:
	var fixture := {
		"schema_version": PlazaMapNavigation.QA_FIXTURE_SCHEMA_VERSION,
		"world_size": WORLD_SIZE,
		"walkable_corridor_polygons": layout.get("walkable_corridor_polygons", []),
		"interaction_portals": layout.get("interaction_portals", []),
		"blocked_polygons": layout.get("blocked_polygons", []),
	}
	var fixture_fingerprint := PlazaMapNavigation.build_qa_geometry_fixture_fingerprint(fixture)
	var state := PlazaMapNavigation.bind_qa_geometry_fixture(fixture, fixture_fingerprint)
	var compiled: Object = PlazaMapNavigationCompiled.compile(state)
	_expect(bool(state.get("valid", false)) and bool(compiled.call("is_valid")), "seed %d oblique corridor manifest must bind to the compiled navigation owner" % map_seed)
	if not bool(compiled.call("is_valid")):
		return
	var road := layout.get("road_graph", {}) as Dictionary
	var edges := _dictionary_array(road.get("edges", []))
	var ordered_ids: Array[String] = []
	for node_id_value in road.get("main_route_node_ids", []) as Array:
		ordered_ids.append(str(node_id_value))
	_expect(ordered_ids.size() == PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT + 2, "seed %d compiled route must include spawn, seven integrated plot junctions, and exit" % map_seed)
	var actor_position := SPAWN_ANCHOR
	var move_steps := 0
	for route_index in range(ordered_ids.size() - 1):
		var edge := _find_directed_edge(edges, ordered_ids[route_index], ordered_ids[route_index + 1], "main")
		_expect(not edge.is_empty(), "seed %d main route must retain edge %s -> %s" % [map_seed, ordered_ids[route_index], ordered_ids[route_index + 1]])
		if edge.is_empty():
			return
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for point_index in range(1, polyline.size()):
			var waypoint := polyline[point_index]
			var guard := 0
			while actor_position.distance_to(waypoint) > 0.05 and guard < 2000:
				guard += 1
				var remaining := actor_position.distance_to(waypoint)
				var delta := minf(1.0 / 60.0, remaining / PlazaMapNavigation.PLAYER_SPEED_WORLD_PER_SECOND)
				var move: Dictionary = compiled.call("move_actor", actor_position, actor_position.direction_to(waypoint), delta)
				var next_position: Vector2 = move.get("actor_position", actor_position)
				if not bool(move.get("valid", false)) or next_position.distance_squared_to(actor_position) <= 0.000001:
					_expect(false, "seed %d compiled full-body actor stalled at %s toward %s" % [map_seed, actor_position, waypoint])
					return
				actor_position = next_position
				move_steps += 1
			_expect(guard < 2000, "seed %d main-route segment traversal guard must not expire" % map_seed)
	_expect(actor_position.distance_to(EXIT_ZONE.get_center()) <= 0.1, "seed %d compiled actor must reach the exit through the integrated basis route" % map_seed)
	_expect(move_steps > 0, "seed %d no-tunnel traversal must execute real swept movement" % map_seed)


func _verify_r2_semantics_preserved(
	source: Dictionary,
	integrated: Dictionary,
	roster: Array[Dictionary],
	label: String
) -> void:
	for key in ["stage_id", "map_seed", "world_size", "spawn_anchor", "exit_zone", "selected_building_types", "plot_assignment_signature"]:
		_expect(source.get(key) == integrated.get(key), "%s must preserve R2 authority key %s" % [label, key])
	var source_plots := _dictionary_array(source.get("plots", []))
	var integrated_plots := _dictionary_array(integrated.get("plots", []))
	_expect(_plot_class_order(source_plots) == _plot_class_order(integrated_plots), "%s must preserve the exact plot-class order" % label)
	_expect(_building_types(_dictionary_array(source.get("building_specs", []))) == _building_types(_dictionary_array(integrated.get("building_specs", []))), "%s must preserve selected building assignment order" % label)
	var changed_coordinate_count := 0
	for index in range(mini(source_plots.size(), integrated_plots.size())):
		if source_plots[index].get("pivot_pos") != integrated_plots[index].get("pivot_pos"):
			changed_coordinate_count += 1
	_expect(changed_coordinate_count > 0, "%s R3 authority must deliberately regenerate coordinates instead of preserving R2 bytes" % label)
	var semantic := integrated.get("r2_semantic_invariants", {}) as Dictionary
	_expect(str(semantic.get("coordinate_policy", "")) == "versioned_r3_authority_not_r2_byte_preservation", "%s must state the coordinate migration boundary" % label)
	_expect(semantic.get("selected_building_types", []) == _building_types(roster), "%s semantic seal must retain selected types" % label)
	_expect(semantic.get("assignment_order", []) == _building_types(_dictionary_array(integrated.get("building_specs", []))), "%s semantic seal must retain assignment order" % label)
	_expect(semantic.get("plot_class_order", []) == _plot_class_order(integrated_plots), "%s semantic seal must retain plot classes" % label)
	_expect(str(integrated.get("source_layout_fingerprint", "")) == str(source.get("fingerprint", "")), "%s must bind the exact independently generated R2 layout" % label)
	_verify_phase_rng_tail_parity(int(integrated.get("map_seed", 0)), roster, semantic, label)


func _verify_phase_rng_tail_parity(
	map_seed: int,
	roster: Array[Dictionary],
	semantic: Dictionary,
	label: String
) -> void:
	var skeleton_rng := PlazaMapLayoutGenerator._build_phase_rng(1, map_seed, "skeleton")
	var plot_rng := PlazaMapLayoutGenerator._build_phase_rng(1, map_seed, "plots")
	var assignment_rng := PlazaMapLayoutGenerator._build_phase_rng(1, map_seed, "assignment")
	var decor_rng := PlazaMapLayoutGenerator._build_phase_rng(1, map_seed, "decor")
	var assignments := PlazaMapLayoutGenerator._build_plot_assignments(assignment_rng, map_seed)
	var road := PlazaMapLayoutGenerator._build_main_road_graph(SPAWN_ANCHOR, EXIT_ZONE.get_center(), WORLD_SIZE, skeleton_rng, map_seed)
	var plots := PlazaMapLayoutGenerator._build_plots(road, WORLD_SIZE, plot_rng, assignments)
	var buildings := PlazaMapLayoutGenerator._assign_buildings(roster, plots, assignment_rng)
	PlazaMapLayoutGenerator._append_plot_approach_edges(road, plots, buildings, WORLD_SIZE)
	PlazaMapLayoutGenerator._fill_unused_plots(plots, buildings, road, decor_rng)
	var expected_tails := {
		"skeleton": skeleton_rng.randi(),
		"plots": plot_rng.randi(),
		"assignment": assignment_rng.randi(),
		"decor": decor_rng.randi(),
	}
	_expect(semantic.get("phase_rng_tail_samples", {}) == expected_tails, "%s must preserve exact R2 four-phase RNG consumption" % label)


func _verify_production_disconnection() -> void:
	var assertion_start := _assertion_count
	var plaza_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_expect(not plaza_source.contains("plaza_map_road_skeleton_r3"), "R3-A0.6 must remain absent from production PlazaScene")
	_expect(not project_source.contains("plaza_map_road_skeleton_r3"), "R3-A0.6 must remain absent from project wiring")
	_complete_leg("production_disconnection", assertion_start)


func _complete_leg(leg_name: String, assertion_start: int) -> void:
	if _leg_assertion_counts.has(leg_name):
		_failures.append("GRT-040 completion gate: verification leg completed twice: %s" % leg_name)
		return
	_leg_assertion_counts[leg_name] = _assertion_count - assertion_start
	_legs_completed += 1


func _measure_independent_arm_runs(
	layout: Dictionary,
	bindings: Array[Dictionary],
	special_arm_runs: Dictionary
) -> void:
	var road := layout.get("road_graph", {}) as Dictionary
	var edges := _dictionary_array(road.get("edges", []))
	for binding in bindings:
		var asset_id := str(binding.get("asset_id", ""))
		if not SPECIAL_ARM_REQUIREMENTS.has(asset_id):
			continue
		if str(binding.get("role", "")) == "central_plaza_forecourt":
			continue
		var node_id := str(binding.get("node_id", ""))
		var runs_value: Variant = special_arm_runs.get(asset_id, null)
		_expect(node_id != "" and runs_value is Array, "special binding %s must expose a node and a typed census bucket" % str(binding.get("id", "")))
		if node_id == "" or not (runs_value is Array):
			continue
		var runs := runs_value as Array
		for edge in edges:
			var polyline := _vector2_array(edge.get("polyline_world", []))
			if polyline.size() < 2:
				continue
			var oriented: Array[Vector2] = []
			if str(edge.get("from", "")) == node_id:
				oriented = polyline
			elif str(edge.get("to", "")) == node_id:
				for index in range(polyline.size() - 1, -1, -1):
					oriented.append(polyline[index])
			if oriented.size() >= 2:
				runs.append(_independent_continuous_run(oriented))


func _independent_continuous_run(oriented: Array[Vector2]) -> float:
	if oriented.size() < 2:
		return 0.0
	var direction := _independent_direction(oriented[0], oriented[1])
	if direction == "":
		return 0.0
	var run_world := 0.0
	for index in range(oriented.size() - 1):
		if _independent_direction(oriented[index], oriented[index + 1]) != direction:
			break
		run_world += oriented[index].distance_to(oriented[index + 1])
	return run_world


func _independent_direction(start: Vector2, finish: Vector2) -> String:
	var delta := finish - start
	if delta.length_squared() <= 0.000001:
		return ""
	if absf(delta.y) <= 0.001:
		return "east" if delta.x > 0.0 else "west"
	if absf(delta.x) <= 0.001:
		return "south" if delta.y > 0.0 else "north"
	if absf(delta.y - delta.x * 0.5) <= 0.001:
		return "south_east" if delta.x > 0.0 else "north_west"
	if absf(delta.y + delta.x * 0.5) <= 0.001:
		return "north_east" if delta.x > 0.0 else "south_west"
	return ""


func _verify_independent_special_arm_census(special_arm_runs: Dictionary) -> Dictionary:
	var summary := {}
	for asset_id_value in SPECIAL_ARM_REQUIREMENTS.keys():
		var asset_id := str(asset_id_value)
		var runs_value: Variant = special_arm_runs.get(asset_id, [])
		var runs: Array[float] = []
		if runs_value is Array:
			for run_value in runs_value as Array:
				runs.append(float(run_value))
		runs.sort()
		var required := float(SPECIAL_ARM_REQUIREMENTS.get(asset_id, INF))
		var below_required := 0
		for run_world in runs:
			if run_world + 0.001 < required:
				below_required += 1
		var minimum := runs[0] if not runs.is_empty() else 0.0
		var p10 := runs[int(floor(float(runs.size() - 1) * 0.10))] if not runs.is_empty() else 0.0
		var p50 := runs[int(floor(float(runs.size() - 1) * 0.50))] if not runs.is_empty() else 0.0
		summary[asset_id] = {
			"samples": runs.size(),
			"required": required,
			"below_required": below_required,
			"min": snappedf(minimum, 0.001),
			"p10": snappedf(p10, 0.001),
			"p50": snappedf(p50, 0.001),
		}
		_expect(not runs.is_empty(), "%s independent arm census must inspect real authored arms" % asset_id)
		_expect(below_required == 0, "%s must have zero physical arms shorter than %.1f world units, got %d" % [asset_id, required, below_required])
	return summary


func _legal_roster_for_seed(full_specs: Array[Dictionary], map_seed: int) -> Array[Dictionary]:
	var bank := _find_by_type(full_specs, "bank")
	var optional: Array[Dictionary] = []
	for spec in full_specs:
		if str(spec.get("type", "")) != "bank":
			optional.append(spec)
	var roster: Array[Dictionary] = [bank.duplicate(true)]
	var optional_count := 1 + posmod(map_seed, 4)
	for index in range(optional_count):
		roster.append(optional[posmod(map_seed + index, optional.size())].duplicate(true))
	return roster


func _empty_usage() -> Dictionary:
	var usage := {}
	for asset_id in PlazaMapRoadSkeletonR3.ROAD_PIECE_IDS:
		usage[asset_id] = 0
	return usage


func _without_route_distance(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in _dictionary_array(value):
		var copy := record.duplicate(true)
		copy.erase("main_route_distance_world")
		result.append(copy)
	return result


func _binding_count(bindings: Array[Dictionary], asset_id: String) -> int:
	var count := 0
	for binding in bindings:
		if str(binding.get("asset_id", "")) == asset_id:
			count += 1
	return count


func _building_types(specs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for spec in specs:
		result.append(str(spec.get("type", "")))
	return result


func _plot_class_order(plots: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for plot in plots:
		result.append(str(plot.get("plot_class", "")))
	return result


func _authored_node_role_count(role: String) -> int:
	var result := 0
	for spec_value in PlazaMapRoadSkeletonR3.R3_SECONDARY_NODE_SPECS:
		var spec := spec_value as Dictionary
		if str(spec.get("role", "")) == role:
			result += 1
	return result


func _authored_trunk_edge_count(trunk: String) -> int:
	var result := 0
	for spec_value in PlazaMapRoadSkeletonR3.R3_SECONDARY_EDGE_SPECS:
		var spec := spec_value as Dictionary
		var actual_trunk := str(spec.get("trunk", ""))
		if actual_trunk == trunk or actual_trunk.begins_with("%s_" % trunk):
			result += 1
	return result


func _find_by_type(records: Array[Dictionary], wanted_type: String) -> Dictionary:
	for record in records:
		if str(record.get("type", "")) == wanted_type:
			return record
	return {}


func _find_by_id(records: Array[Dictionary], wanted_id: String) -> Dictionary:
	for record in records:
		if str(record.get("id", "")) == wanted_id:
			return record
	return {}


func _find_directed_edge(records: Array[Dictionary], from_id: String, to_id: String, kind: String) -> Dictionary:
	for record in records:
		if str(record.get("from", "")) == from_id and str(record.get("to", "")) == to_id and str(record.get("kind", "")) == kind:
			return record
	return {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


func _json_polygon_to_vector2(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for point_value in value as Array:
		if not (point_value is Array) or (point_value as Array).size() != 2:
			return []
		var pair := point_value as Array
		if not (pair[0] is int or pair[0] is float) or not (pair[1] is int or pair[1] is float):
			return []
		var point := Vector2(float(pair[0]), float(pair[1]))
		if not point.is_finite():
			return []
		result.append(point)
	return result


func _independent_polygon_token(polygon: Array[Vector2]) -> String:
	var tokens: Array[String] = []
	for point in polygon:
		tokens.append("%.3f,%.3f" % [point.x, point.y])
	return ";".join(PackedStringArray(tokens))


func _vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Vector2:
			result.append(item as Vector2)
		elif item is Vector2i:
			result.append(Vector2(item as Vector2i))
	return result


func _has_violation(validation: Dictionary, code: String) -> bool:
	for violation in _dictionary_array(validation.get("violations", [])):
		if str(violation.get("code", "")) == code:
			return true
	return false


func _has_violation_detail(validation: Dictionary, code: String, detail_fragment: String) -> bool:
	for violation in _dictionary_array(validation.get("violations", [])):
		if str(violation.get("code", "")) == code and str(violation.get("detail", "")).contains(detail_fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
