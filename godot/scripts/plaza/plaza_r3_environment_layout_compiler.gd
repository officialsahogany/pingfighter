extends RefCounted

# R3-A1 production-disconnected environment preflight compiler. It consumes a
# fully validated R3-A0.6 layout plus the three pinned runtime-art manifests and
# emits immutable draw records. Special-road orientation is already sealed
# against authored PNG alpha geometry. Its technical composition contract removes
# screen-vertical ribbons, stops road art at the authored plaza rim, covers every
# exposed straight endpoint, and gives main/secondary/trail distinct materials.
# A windowed Vulkan capture remains the separate whole-map visual approval gate.
# No Texture2D is loaded and no production scene is touched.

const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")

const SCHEMA_VERSION := "hwangyeok_r3a12_environment_layout_v5_hub_side_trees"
const WORLD_SIZE := Vector2(2400.0, 1500.0)
const BASE_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r2_environment_manifest.json"
const EXTENSION_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r3a1_decor_extension_manifest.json"
const ROAD_HIERARCHY_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r3a1_road_hierarchy_manifest.json"
const WALKABLE_HUB_CATALOG_KEY := "central_plaza_walkable_hub"

const DECOR_ASSET_BY_CLUSTER_TYPE := {
	"market_stalls": "market",
	"cloth_awning_cluster": "market",
	"small_vendor_court": "supply",
	"stone_lantern_gate": "stone_lantern_rest",
	"bench_and_lanterns": "stone_lantern_rest",
	"stone_marker_cluster": "wayfinder",
	"crossroad_lanterns": "wayfinder",
	"guardian_tree_grove": "pine",
	"spirit_tree_cluster": "pine",
	"boundary_pines": "pine",
	"quiet_pond": "pond",
	"jade_rock_garden": "ritual_stone_garden",
	"seal_stone_court": "ritual_stone_garden",
}

const EXPECTED_ASSET_KEYS := [
	"ground:map_ground",
	"road_piece:straight_horizontal",
	"road_piece:straight_vertical",
	"road_piece:straight_positive",
	"road_piece:straight_negative",
	"road_piece:three_way",
	"road_piece:plot_spur",
	"road_piece:terminus",
	"road_piece:entrance_forecourt",
	"road_piece:secondary_horizontal",
	"road_piece:secondary_positive",
	"road_piece:secondary_negative",
	"road_piece:trail_horizontal",
	"road_piece:trail_positive",
	"road_piece:trail_negative",
	"road_piece:turn_court",
	"plot_pad:plot_pad_large",
	"plot_pad:plot_pad_small",
	"decor_cluster:wayfinder",
	"decor_cluster:market",
	"decor_cluster:pond",
	"decor_cluster:pine",
	"decor_cluster:supply",
	"decor_cluster:ritual_stone_garden",
	"decor_cluster:stone_lantern_rest",
]
const ROAD_HIERARCHY_ASSET_CONTRACT := {
	"secondary_horizontal": {"edge_kind": "secondary", "basis": "horizontal"},
	"secondary_positive": {"edge_kind": "secondary", "basis": "positive"},
	"secondary_negative": {"edge_kind": "secondary", "basis": "negative"},
	"trail_horizontal": {"edge_kind": "trail", "basis": "horizontal"},
	"trail_positive": {"edge_kind": "trail", "basis": "positive"},
	"trail_negative": {"edge_kind": "trail", "basis": "negative"},
	"turn_court": {"edge_kind": "junction", "basis": "rotation_symmetric"},
}

const LARGE_PAD_PLOT_CLASSES := [
	"rear_landmark_large",
	"intersection_large",
	"edge_large",
]

const SPECIAL_ROAD_TARGET_WIDTH := PlazaMapRoadSkeletonR3.SPECIAL_ROAD_TARGET_WIDTH_WORLD

const AXIS_ROAD_TINT := Color(0.61, 0.61, 0.61, 1.0)
const SPECIAL_ROAD_ORIENTATION_CONTRACT := {
	"three_way": "north_east+north_west+south",
	"plot_spur": "trail_enters_south_east",
	"terminus": "terminus_opens_north_east",
	"entrance_forecourt": "approach_enters_north_east",
	"turn_court": "rotation_symmetric_degree_two",
}


static func compile_layout(layout: Dictionary) -> Dictionary:
	var source_validation := PlazaMapRoadSkeletonR3.validate_layout(layout)
	if not bool(source_validation.get("valid", false)):
		return _rejected_plan("source_r3a0_layout_invalid", source_validation.get("violations", []))
	var stored_fingerprint_value: Variant = layout.get("fingerprint", null)
	if not (stored_fingerprint_value is String):
		return _rejected_plan("source_fingerprint_invalid")
	var stored_fingerprint := stored_fingerprint_value as String
	if stored_fingerprint.length() != 64 or stored_fingerprint != PlazaMapRoadSkeletonR3.build_fingerprint(layout):
		return _rejected_plan("source_fingerprint_mismatch")
	var world_size := _coerce_vector2(layout.get("world_size", Vector2.INF))
	if not world_size.is_equal_approx(WORLD_SIZE):
		return _rejected_plan("source_world_size_mismatch")

	var catalog := load_asset_catalog()
	if not bool(catalog.get("valid", false)):
		return _rejected_plan("asset_catalog_invalid", catalog.get("violations", []))
	var assets := catalog.get("assets", {}) as Dictionary
	var hub_binding := _compile_walkable_hub_contract_binding(layout, catalog)
	if hub_binding.is_empty():
		return _rejected_plan("walkable_hub_catalog_binding_invalid")
	var road_draws := _compile_road_draws(layout, assets)
	var plan := {
		"schema_version": SCHEMA_VERSION,
		"layout_fingerprint": stored_fingerprint,
		"asset_catalog_fingerprint": str(catalog.get("fingerprint", "")),
		"walkable_hub_contract_binding": hub_binding,
		"world_size": world_size,
		"ground_draw": _compile_ground_draw(assets),
		"road_draws": road_draws,
		"road_overlap_records": _dictionary_array(layout.get("road_crossing_bindings", [])).duplicate(true),
		"road_composition_metrics": _build_road_composition_metrics(layout, road_draws),
		"plot_pad_draws": _compile_plot_pad_draws(layout, assets),
		"decor_draws": _compile_decor_draws(layout, assets),
		"candidate_only": true,
		"production_connected": false,
	}
	plan["fingerprint"] = build_fingerprint(plan)
	plan["validation"] = validate_plan(plan, layout)
	return plan


static func load_asset_catalog() -> Dictionary:
	var violations: Array[Dictionary] = []
	var assets := {}
	var layout_geometry_contracts := {}
	for manifest_path in [BASE_MANIFEST_PATH, EXTENSION_MANIFEST_PATH, ROAD_HIERARCHY_MANIFEST_PATH]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not (parsed is Dictionary):
			_add_violation(violations, "manifest_parse_failed", manifest_path)
			continue
		var manifest := parsed as Dictionary
		if not bool(manifest.get("candidate_only", false)) or bool(manifest.get("production_connected", true)):
			_add_violation(violations, "manifest_candidate_boundary_mismatch", manifest_path)
		if manifest_path == ROAD_HIERARCHY_MANIFEST_PATH:
			var geometry_value: Variant = manifest.get("approved_layout_geometry", null)
			if not (geometry_value is Dictionary):
				_add_violation(violations, "manifest_layout_geometry_invalid", manifest_path)
			else:
				for geometry_key_value in (geometry_value as Dictionary).keys():
					var geometry_key := str(geometry_key_value)
					var contract_value: Variant = (geometry_value as Dictionary).get(geometry_key_value, null)
					if not (contract_value is Dictionary) or layout_geometry_contracts.has(geometry_key):
						_add_violation(violations, "manifest_layout_geometry_contract_invalid", geometry_key)
						continue
					layout_geometry_contracts[geometry_key] = (contract_value as Dictionary).duplicate(true)
		var values: Variant = manifest.get("assets", null)
		if not (values is Array):
			_add_violation(violations, "manifest_assets_invalid", manifest_path)
			continue
		for value in values as Array:
			if not (value is Dictionary):
				_add_violation(violations, "manifest_asset_invalid", manifest_path)
				continue
			var asset: Dictionary = (value as Dictionary).duplicate(true)
			var kind_value: Variant = asset.get("kind", null)
			var id_value: Variant = asset.get("asset_id", null)
			var path_value: Variant = asset.get("res_path", null)
			if not (kind_value is String) or not (id_value is String) or not (path_value is String):
				_add_violation(violations, "manifest_asset_identity_invalid", manifest_path)
				continue
			var key := "%s:%s" % [kind_value as String, id_value as String]
			if assets.has(key):
				_add_violation(violations, "manifest_asset_duplicate", key)
				continue
			if not FileAccess.file_exists(path_value as String):
				_add_violation(violations, "manifest_asset_missing", path_value as String)
				continue
			assets[key] = asset
	var actual_keys: Array[String] = []
	for key_value in assets.keys():
		actual_keys.append(str(key_value))
	actual_keys.sort()
	var expected_keys: Array[String] = []
	for key_value in EXPECTED_ASSET_KEYS:
		expected_keys.append(str(key_value))
	expected_keys.sort()
	if actual_keys != expected_keys:
		_add_violation(violations, "manifest_asset_set_mismatch", "actual=%s expected=%s" % [actual_keys, expected_keys])
	_validate_road_hierarchy_asset_contract(assets, violations)
	_validate_walkable_hub_catalog_contract(layout_geometry_contracts, violations)
	var semantic_catalog := validate_decor_mapping_catalog()
	if not bool(semantic_catalog.get("valid", false)):
		for violation in _dictionary_array(semantic_catalog.get("violations", [])):
			violations.append(violation)
	var fingerprint_parts: Array[String] = []
	for key in actual_keys:
		var asset := assets.get(key, {}) as Dictionary
		fingerprint_parts.append("%s:%s:%s" % [key, str(asset.get("res_path", "")), str((asset.get("qa", {}) as Dictionary).get("sha256", ""))])
	for geometry_key_value in layout_geometry_contracts.keys():
		var geometry_key := str(geometry_key_value)
		var contract := layout_geometry_contracts.get(geometry_key, {}) as Dictionary
		fingerprint_parts.append("layout_geometry:%s:%s:%s:%s:%s:%s" % [
			geometry_key,
			str(contract.get("id", "")),
			str(contract.get("layout_record_id", "")),
			str(contract.get("polygon_sha256", "")),
			str(contract.get("navigation_policy", "")),
			str(contract.get("road_render_policy", "")),
		])
	return {
		"valid": violations.is_empty(),
		"violations": violations,
		"assets": assets,
		"layout_geometry_contracts": layout_geometry_contracts,
		"fingerprint": "\n".join(PackedStringArray(fingerprint_parts)).sha256_text(),
	}


static func _validate_road_hierarchy_asset_contract(assets: Dictionary, violations: Array[Dictionary]) -> void:
	var luminance_by_asset := {}
	for asset_id_value in ROAD_HIERARCHY_ASSET_CONTRACT.keys():
		var asset_id := str(asset_id_value)
		var expected := ROAD_HIERARCHY_ASSET_CONTRACT.get(asset_id, {}) as Dictionary
		var asset := assets.get("road_piece:%s" % asset_id, {}) as Dictionary
		if asset.is_empty():
			_add_violation(violations, "road_hierarchy_asset_missing", asset_id)
			continue
		if str(asset.get("edge_kind", "")) != str(expected.get("edge_kind", "")) or str(asset.get("basis", "")) != str(expected.get("basis", "")):
			_add_violation(violations, "road_hierarchy_asset_semantics_mismatch", asset_id)
		var qa := asset.get("qa", {}) as Dictionary
		var luminance_value: Variant = qa.get("visible_mean_luminance_8bit", null)
		if not _is_positive_finite_number(luminance_value):
			_add_violation(violations, "road_hierarchy_asset_luminance_invalid", asset_id)
			continue
		luminance_by_asset[asset_id] = float(luminance_value)
		if asset_id == "turn_court":
			if float(qa.get("alpha_rotation_180_iou", 0.0)) < 0.96 or int(qa.get("directional_arm_count", -1)) != 0:
				_add_violation(violations, "turn_court_rotation_symmetry_invalid", str(qa))
	for basis in ["horizontal", "positive", "negative"]:
		var secondary_id := "secondary_%s" % basis
		var trail_id := "trail_%s" % basis
		if not luminance_by_asset.has(secondary_id) or not luminance_by_asset.has(trail_id):
			continue
		if float(luminance_by_asset[secondary_id]) <= float(luminance_by_asset[trail_id]) + 3.0:
			_add_violation(
				violations,
				"road_hierarchy_material_separation_invalid",
				"%s:secondary=%.3f trail=%.3f" % [basis, float(luminance_by_asset[secondary_id]), float(luminance_by_asset[trail_id])]
			)


static func _validate_walkable_hub_catalog_contract(
	contracts: Dictionary,
	violations: Array[Dictionary]
) -> void:
	if contracts.size() != 1 or not contracts.has(WALKABLE_HUB_CATALOG_KEY):
		_add_violation(violations, "walkable_hub_catalog_set_mismatch", str(contracts.keys()))
		return
	var contract_value: Variant = contracts.get(WALKABLE_HUB_CATALOG_KEY, null)
	if not (contract_value is Dictionary):
		_add_violation(violations, "walkable_hub_catalog_contract_invalid", WALKABLE_HUB_CATALOG_KEY)
		return
	var contract := contract_value as Dictionary
	for key in ["id", "layout_record_id", "polygon_sha256", "navigation_policy", "road_render_policy"]:
		var value: Variant = contract.get(key, null)
		if not (value is String) or (value as String).is_empty():
			_add_violation(violations, "walkable_hub_catalog_contract_invalid", key)
	var polygon := _json_polygon_to_vector2(contract.get("polygon_world", null))
	if polygon.size() < 3 or absf(_polygon_signed_area(polygon)) <= 0.01:
		_add_violation(violations, "walkable_hub_catalog_polygon_invalid", str(contract.get("polygon_world", null)))
		return
	var derived_sha := _polygon_token(polygon).sha256_text()
	if str(contract.get("polygon_sha256", "")) != derived_sha:
		_add_violation(violations, "walkable_hub_catalog_polygon_hash_mismatch", derived_sha)


static func _compile_walkable_hub_contract_binding(layout: Dictionary, catalog: Dictionary) -> Dictionary:
	var contracts := catalog.get("layout_geometry_contracts", {}) as Dictionary
	var contract := contracts.get(WALKABLE_HUB_CATALOG_KEY, {}) as Dictionary
	var layout_contract := layout.get("central_plaza_hub_contract", {}) as Dictionary
	var hubs := _dictionary_array(layout.get("walkable_hub_polygons", []))
	if contract.is_empty() or hubs.size() != 1:
		return {}
	var hub := hubs[0]
	var authored_polygon := _json_polygon_to_vector2(contract.get("polygon_world", null))
	var layout_polygon := _vector2_array(hub.get("polygon_world", []))
	var authored_sha := _polygon_token(authored_polygon).sha256_text()
	if (
		str(contract.get("id", "")) != str(layout_contract.get("id", ""))
		or str(contract.get("layout_record_id", "")) != str(hub.get("id", ""))
		or str(hub.get("edge_id", "")) != str(hub.get("id", ""))
		or str(hub.get("source_contract_id", "")) != str(contract.get("id", ""))
		or str(layout_contract.get("source_manifest_path", "")) != ROAD_HIERARCHY_MANIFEST_PATH
		or str(contract.get("polygon_sha256", "")) != authored_sha
		or str(layout_contract.get("polygon_sha256", "")) != authored_sha
		or authored_polygon != layout_polygon
		or str(contract.get("navigation_policy", "")) != str(layout_contract.get("navigation_policy", ""))
		or str(contract.get("road_render_policy", "")) != str(layout_contract.get("road_render_policy", ""))
	):
		return {}
	return {
		"catalog_key": WALKABLE_HUB_CATALOG_KEY,
		"contract_id": str(contract.get("id", "")),
		"layout_record_id": str(contract.get("layout_record_id", "")),
		"source_manifest_path": ROAD_HIERARCHY_MANIFEST_PATH,
		"polygon_sha256": authored_sha,
		"navigation_policy": str(contract.get("navigation_policy", "")),
		"road_render_policy": str(contract.get("road_render_policy", "")),
	}


static func validate_decor_mapping_catalog(mapping_override: Dictionary = {}) -> Dictionary:
	var violations: Array[Dictionary] = []
	var mapping := DECOR_ASSET_BY_CLUSTER_TYPE if mapping_override.is_empty() else mapping_override
	var generator_types: Array[String] = []
	for kinds_value in PlazaMapLayoutGenerator.DECOR_KINDS_BY_PLOT_CLASS.values():
		if not (kinds_value is Array):
			_add_violation(violations, "generator_decor_catalog_invalid", str(kinds_value))
			continue
		for type_value in kinds_value as Array:
			var cluster_type := str(type_value)
			if not generator_types.has(cluster_type):
				generator_types.append(cluster_type)
	generator_types.sort()
	var mapped_types: Array[String] = []
	for type_value in mapping.keys():
		mapped_types.append(str(type_value))
	mapped_types.sort()
	if generator_types != mapped_types:
		_add_violation(violations, "decor_mapping_catalog_mismatch", "generator=%s mapped=%s" % [generator_types, mapped_types])
	var used_asset_ids: Array[String] = []
	for cluster_type in generator_types:
		var asset_id := get_decor_asset_id(cluster_type, mapping)
		if asset_id == "":
			_add_violation(violations, "decor_cluster_unmapped", cluster_type)
		elif not used_asset_ids.has(asset_id):
			used_asset_ids.append(asset_id)
	used_asset_ids.sort()
	var expected_asset_ids := ["market", "pine", "pond", "ritual_stone_garden", "stone_lantern_rest", "supply", "wayfinder"]
	if used_asset_ids != expected_asset_ids:
		_add_violation(violations, "decor_asset_semantic_coverage_mismatch", str(used_asset_ids))
	return {
		"valid": violations.is_empty(),
		"violations": violations,
		"generator_cluster_types": generator_types,
		"used_asset_ids": used_asset_ids,
	}


static func get_decor_asset_id(cluster_type: String, mapping_override: Dictionary = {}) -> String:
	var mapping := DECOR_ASSET_BY_CLUSTER_TYPE if mapping_override.is_empty() else mapping_override
	var value: Variant = mapping.get(cluster_type, null)
	return value as String if value is String else ""


static func validate_plan(plan: Dictionary, layout: Dictionary, allow_composition_visual_evaluation: bool = false) -> Dictionary:
	var violations: Array[Dictionary] = []
	if str(plan.get("schema_version", "")) != SCHEMA_VERSION:
		_add_violation(violations, "invalid_schema_version", str(plan.get("schema_version", "")))
	if not bool(plan.get("candidate_only", false)) or bool(plan.get("production_connected", true)):
		_add_violation(violations, "candidate_boundary_mismatch", "R3-A1 must remain production-disconnected")
	if str(plan.get("layout_fingerprint", "")) != str(layout.get("fingerprint", "")):
		_add_violation(violations, "layout_fingerprint_mismatch", str(plan.get("layout_fingerprint", "")))
	var catalog := load_asset_catalog()
	if not bool(catalog.get("valid", false)):
		_add_violation(violations, "asset_catalog_invalid", str(catalog.get("violations", [])))
	else:
		var expected_hub_binding := _compile_walkable_hub_contract_binding(layout, catalog)
		var actual_hub_value: Variant = plan.get("walkable_hub_contract_binding", null)
		var actual_hub_binding: Dictionary = actual_hub_value as Dictionary if actual_hub_value is Dictionary else {}
		if expected_hub_binding.is_empty() or actual_hub_binding != expected_hub_binding:
			_add_violation(violations, "walkable_hub_catalog_binding_mismatch", str(actual_hub_binding))
	var fingerprint_value: Variant = plan.get("fingerprint", null)
	if not (fingerprint_value is String) or (fingerprint_value as String).length() != 64:
		_add_violation(violations, "plan_fingerprint_invalid", str(fingerprint_value))
	elif fingerprint_value as String != build_fingerprint(plan):
		_add_violation(violations, "plan_fingerprint_mismatch", "stored plan digest does not bind draw records")
	var ground_value: Variant = plan.get("ground_draw", null)
	if not (ground_value is Dictionary) or not _draw_record_is_valid(ground_value as Dictionary, "ground"):
		_add_violation(violations, "ground_draw_invalid", str(ground_value))
	var road_draws := _dictionary_array(plan.get("road_draws", []))
	var bindings := _dictionary_array(layout.get("road_piece_bindings", []))
	if road_draws.size() != bindings.size():
		_add_violation(violations, "road_draw_count_mismatch", "%d != %d" % [road_draws.size(), bindings.size()])
	var expected_basis_count := 0
	for binding in bindings:
		if str(binding.get("role", "")) == "basis_segment":
			expected_basis_count += 1
	var actual_basis_count := 0
	for record in road_draws:
		if not _draw_record_is_valid(record, "road_piece"):
			_add_violation(violations, "road_draw_invalid", str(record.get("id", "")))
		if str(record.get("role", "")) == "basis_segment":
			actual_basis_count += 1
			var length_value: Variant = record.get("world_length", null)
			if not _is_positive_finite_number(length_value):
				_add_violation(violations, "road_basis_length_invalid", str(record.get("id", "")))
			var binding := _find_by_id(bindings, str(record.get("id", "")))
			var edge := _find_by_id(_dictionary_array((layout.get("road_graph", {}) as Dictionary).get("edges", [])), str(binding.get("edge_id", "")))
			var expected_asset_id := _road_render_asset_id(
				str(binding.get("asset_id", "")),
				str(edge.get("kind", "")),
				str(binding.get("basis", ""))
			)
			if str(record.get("asset_id", "")) != expected_asset_id or str(record.get("road_material_class", "")) != _road_material_class(str(edge.get("kind", ""))):
				_add_violation(violations, "road_material_hierarchy_mismatch", str(record.get("id", "")))
		else:
			if str(record.get("asset_id", "")) == "turn_court" and not ["main", "secondary"].has(str(record.get("edge_kind", ""))):
				_add_violation(violations, "turn_court_edge_kind_forbidden", "%s:%s" % [str(record.get("id", "")), str(record.get("edge_kind", ""))])
			var expected_orientation := str(SPECIAL_ROAD_ORIENTATION_CONTRACT.get(str(record.get("asset_id", "")), ""))
			var actual_orientation := _derive_special_road_orientation(record, layout)
			if expected_orientation == "" or actual_orientation != expected_orientation:
				_add_violation(
					violations,
					"road_special_orientation_unrepresentable",
					"%s:%s actual=%s expected=%s" % [str(record.get("id", "")), str(record.get("asset_id", "")), actual_orientation, expected_orientation]
				)
	if actual_basis_count != expected_basis_count:
		_add_violation(violations, "road_basis_coverage_mismatch", "%d != %d" % [actual_basis_count, expected_basis_count])
	var overlap_records := _dictionary_array(plan.get("road_overlap_records", []))
	var expected_overlap_records := _dictionary_array(layout.get("road_crossing_bindings", []))
	if overlap_records != expected_overlap_records:
		_add_violation(violations, "road_overlap_record_mismatch", "%d != %d" % [overlap_records.size(), expected_overlap_records.size()])
	var expected_composition_metrics := _build_road_composition_metrics(layout, road_draws)
	var composition_metrics_value: Variant = plan.get("road_composition_metrics", null)
	var composition_metrics := composition_metrics_value as Dictionary if composition_metrics_value is Dictionary else {}
	if composition_metrics != expected_composition_metrics:
		_add_violation(violations, "road_composition_metrics_mismatch", "compiled composition evidence changed")
	var width_hierarchy_valid := bool(expected_composition_metrics.get("road_width_hierarchy_valid", false))
	if not width_hierarchy_valid:
		_add_violation(violations, "road_width_hierarchy_invalid", str(expected_composition_metrics.get("road_width_by_edge_kind", {})))
	if not bool(expected_composition_metrics.get("road_material_hierarchy_valid", false)):
		_add_violation(violations, "road_material_hierarchy_invalid", str(expected_composition_metrics.get("road_material_classes_by_edge_kind", {})))
	if int(expected_composition_metrics.get("screen_vertical_segment_count", -1)) != 0:
		_add_violation(violations, "screen_vertical_road_treatment_missing", str(expected_composition_metrics.get("screen_vertical_segment_count", -1)))
	if int(expected_composition_metrics.get("central_plaza_crossing_count", -1)) != 0:
		_add_violation(violations, "central_plaza_road_crossing", str(expected_composition_metrics.get("central_plaza_crossing_count", -1)))
	if int(expected_composition_metrics.get("central_plaza_forecourt_count", -1)) != 2:
		_add_violation(violations, "central_plaza_forecourt_count_mismatch", str(expected_composition_metrics.get("central_plaza_forecourt_count", -1)))
	if int(expected_composition_metrics.get("basis_endpoint_without_special_cover_count", -1)) != 0:
		_add_violation(violations, "basis_endcap_treatment_missing", str(expected_composition_metrics.get("basis_endpoint_without_special_cover_count", -1)))
	if not bool(expected_composition_metrics.get("basis_cap_overlap_contract_valid", false)):
		_add_violation(violations, "basis_cap_overlap_contract_invalid", str(expected_composition_metrics.get("basis_cap_overlap_world", -1.0)))
	if (
		not bool(expected_composition_metrics.get("exit_world_bleed_contract_valid", false))
		or int(expected_composition_metrics.get("basis_endpoint_exit_world_bleed_count", -1)) != 1
	):
		_add_violation(
			violations,
			"exit_world_bleed_contract_invalid",
			str(expected_composition_metrics.get("basis_endpoint_exit_world_bleed_count", -1))
		)
	if int(expected_composition_metrics.get("rendered_spawn_to_plaza_turn_count", 999)) > PlazaMapRoadSkeletonR3.MAX_MAIN_SPINE_TURN_COUNT:
		_add_violation(violations, "main_spine_turn_budget_exceeded", str(expected_composition_metrics.get("rendered_spawn_to_plaza_turn_count", -1)))
	if int(expected_composition_metrics.get("turn_court_count", 999)) > PlazaMapRoadSkeletonR3.MAX_ROAD_TURN_COURT_COUNT:
		_add_violation(violations, "road_turn_court_budget_exceeded", str(expected_composition_metrics.get("turn_court_count", -1)))
	if int(expected_composition_metrics.get("explicit_basis_overlap_count", -1)) != 0:
		_add_violation(violations, "non_node_road_crossing_remaining", str(expected_composition_metrics.get("explicit_basis_overlap_count", -1)))
	if not allow_composition_visual_evaluation:
		_add_violation(
			violations,
			"road_network_composition_unapproved",
			"vertical=%d central_exclusion=%s uncovered_basis_endcaps=%d width_hierarchy=%s overlaps=%d" % [
				int(expected_composition_metrics.get("screen_vertical_segment_count", 0)),
				str(expected_composition_metrics.get("central_plaza_exclusion_contract_present", false)),
				int(expected_composition_metrics.get("basis_endpoint_without_special_cover_count", 0)),
				str(width_hierarchy_valid),
				expected_overlap_records.size(),
			]
		)
		if not bool(expected_composition_metrics.get("central_plaza_exclusion_contract_present", false)):
			_add_violation(violations, "central_plaza_exclusion_contract_missing", "approved ground art has no compiled no-road polygon")
	var pad_draws := _dictionary_array(plan.get("plot_pad_draws", []))
	if pad_draws.size() != _dictionary_array(layout.get("building_specs", [])).size():
		_add_violation(violations, "plot_pad_count_mismatch", str(pad_draws.size()))
	for record in pad_draws:
		if not _draw_record_is_valid(record, "plot_pad"):
			_add_violation(violations, "plot_pad_draw_invalid", str(record.get("id", "")))
	var decor_draws := _dictionary_array(plan.get("decor_draws", []))
	if decor_draws.size() != _dictionary_array(layout.get("decor_clusters", [])).size():
		_add_violation(violations, "decor_draw_count_mismatch", str(decor_draws.size()))
	for record in decor_draws:
		if not _draw_record_is_valid(record, "decor_cluster"):
			_add_violation(violations, "decor_draw_invalid", str(record.get("id", "")))
		if get_decor_asset_id(str(record.get("cluster_type", ""))) != str(record.get("asset_id", "")):
			_add_violation(violations, "decor_semantic_mapping_mismatch", str(record.get("id", "")))
	return {
		"valid": violations.is_empty(),
		"violations": violations,
		"metrics": {
			"road_draw_count": road_draws.size(),
			"basis_segment_draw_count": actual_basis_count,
			"road_overlap_record_count": overlap_records.size(),
			"road_composition": expected_composition_metrics,
			"plot_pad_draw_count": pad_draws.size(),
			"decor_draw_count": decor_draws.size(),
		},
	}


static func _derive_special_road_orientation(record: Dictionary, layout: Dictionary) -> String:
	var binding := _find_by_id(_dictionary_array(layout.get("road_piece_bindings", [])), str(record.get("id", "")))
	return str(binding.get("orientation_signature", ""))


static func _outgoing_directions_at_node(node_id: String, edges: Array[Dictionary]) -> Array[String]:
	var directions: Array[String] = []
	for edge in edges:
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() < 2:
			continue
		var direction := ""
		if str(edge.get("from", "")) == node_id:
			direction = _classify_directed_segment(polyline[0], polyline[1])
		elif str(edge.get("to", "")) == node_id:
			direction = _classify_directed_segment(polyline[polyline.size() - 1], polyline[polyline.size() - 2])
		if direction != "":
			directions.append(direction)
	directions.sort()
	return directions


static func _classify_directed_segment(start: Vector2, finish: Vector2) -> String:
	var basis := PlazaMapRoadSkeletonR3.classify_segment(start, finish)
	var delta := finish - start
	match basis:
		"horizontal":
			return "east" if delta.x > 0.0 else "west"
		"vertical":
			return "south" if delta.y > 0.0 else "north"
		"positive":
			return "south_east" if delta.x > 0.0 else "north_west"
		"negative":
			return "north_east" if delta.x > 0.0 else "south_west"
	return ""


static func build_fingerprint(plan: Dictionary) -> String:
	var parts: Array[String] = [
		"schema=%s" % str(plan.get("schema_version", "")),
		"layout=%s" % str(plan.get("layout_fingerprint", "")),
		"catalog=%s" % str(plan.get("asset_catalog_fingerprint", "")),
		"walkable_hub=%s" % str(plan.get("walkable_hub_contract_binding", {})),
	]
	var ground_value: Variant = plan.get("ground_draw", {})
	if ground_value is Dictionary:
		parts.append(_draw_token(ground_value as Dictionary))
	for key in ["road_draws", "plot_pad_draws", "decor_draws"]:
		for record in _dictionary_array(plan.get(key, [])):
			parts.append(_draw_token(record))
	for overlap in _dictionary_array(plan.get("road_overlap_records", [])):
		parts.append("overlap:%s:%s:%s:%s:%s" % [
			str(overlap.get("id", "")),
			str(overlap.get("kind", "")),
			_vector_token(_coerce_vector2(overlap.get("anchor_world", Vector2.ZERO))),
			str(overlap.get("orientation_signature", "")),
			str(overlap.get("edge_ids", [])),
		])
	var composition_value: Variant = plan.get("road_composition_metrics", null)
	if composition_value is Dictionary:
		parts.append(_road_composition_token(composition_value as Dictionary))
	return "\n".join(PackedStringArray(parts)).sha256_text()


static func _compile_ground_draw(assets: Dictionary) -> Dictionary:
	var asset := assets.get("ground:map_ground", {}) as Dictionary
	var texture_size := _asset_texture_size(asset)
	if texture_size == Vector2.ZERO:
		return {}
	return {
		"id": "map_ground",
		"kind": "ground",
		"asset_id": "map_ground",
		"texture_path": str(asset.get("res_path", "")),
		"texture_size": texture_size,
		"source_anchor_pixels": Vector2.ZERO,
		"content_rect_pixels": Rect2(Vector2.ZERO, texture_size),
		"world_position": Vector2.ZERO,
		"world_scale": WORLD_SIZE / texture_size,
		"rotation_degrees": 0.0,
		"flip_h": false,
		"flip_v": false,
		"world_rect": Rect2(Vector2.ZERO, WORLD_SIZE),
	}


static func _compile_road_draws(layout: Dictionary, assets: Dictionary) -> Array[Dictionary]:
	var draws: Array[Dictionary] = []
	var road := layout.get("road_graph", {}) as Dictionary
	var edges := _dictionary_array(road.get("edges", []))
	for binding in _dictionary_array(layout.get("road_piece_bindings", [])):
		var geometry_asset_id := str(binding.get("asset_id", ""))
		var edge := _find_by_id(edges, str(binding.get("edge_id", "")))
		var edge_kind := str(edge.get("kind", binding.get("edge_kind", "")))
		var basis := str(binding.get("basis", ""))
		var asset_id := _road_render_asset_id(geometry_asset_id, edge_kind, basis)
		var asset := assets.get("road_piece:%s" % asset_id, {}) as Dictionary
		var record := _base_draw_record(str(binding.get("id", "")), "road_piece", asset_id, asset)
		if record.is_empty():
			continue
		var role := str(binding.get("role", ""))
		record["role"] = role
		record["geometry_asset_id"] = geometry_asset_id
		record["road_material_class"] = _road_material_class(edge_kind)
		record["edge_kind"] = edge_kind
		record["edge_id"] = str(binding.get("edge_id", ""))
		record["segment_index"] = int(binding.get("segment_index", -1))
		record["orientation_contract"] = str(binding.get("orientation_contract", "basis_exact"))
		record["orientation_signature"] = str(binding.get("orientation_signature", ""))
		var placement := asset.get("placement", {}) as Dictionary
		var content_rect := _array_to_rect2(placement.get("runtime_content_rect", []))
		var source_anchor := _array_to_vector2(placement.get("runtime_anchor", []))
		var anchor := Vector2.ZERO
		var scale := Vector2.ZERO
		if role == "basis_segment":
			var start := _coerce_vector2(binding.get("start_world", Vector2.INF))
			var finish := _coerce_vector2(binding.get("finish_world", Vector2.INF))
			var delta := finish - start
			var draw_start := start - delta.normalized() * PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD
			var draw_finish := finish + delta.normalized() * PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD
			var exit_world_bleed := false
			var world_size := _coerce_vector2(layout.get("world_size", Vector2.ZERO))
			var exit_zone_value: Variant = layout.get("exit_zone", null)
			var exit_node_id := str(road.get("exit_node_id", ""))
			if (
				exit_zone_value is Rect2
				and (exit_zone_value as Rect2).has_point(finish)
				and str(edge.get("to", "")) == exit_node_id
				and world_size.is_finite()
				and world_size.x > finish.x
				and delta.x > 0.0
			):
				var exit_direction := delta.normalized()
				var bleed_distance := (world_size.x + PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD - finish.x) / exit_direction.x
				draw_finish = finish + exit_direction * bleed_distance
				exit_world_bleed = true
			var draw_delta := draw_finish - draw_start
			var road_width := float(edge.get("half_width_world", 0.0)) * 2.0
			anchor = (draw_start + draw_finish) * 0.5
			if basis == "vertical":
				scale = Vector2(road_width / maxf(1.0, content_rect.size.x), absf(draw_delta.y) / maxf(1.0, content_rect.size.y))
			elif basis == "horizontal":
				scale = Vector2(absf(draw_delta.x) / maxf(1.0, content_rect.size.x), road_width / maxf(1.0, content_rect.size.y))
			else:
				scale = Vector2(absf(draw_delta.x) / maxf(1.0, content_rect.size.x), absf(draw_delta.y) / maxf(1.0, content_rect.size.y))
			record["basis"] = basis
			record["start_world"] = start
			record["finish_world"] = finish
			record["draw_start_world"] = draw_start
			record["draw_finish_world"] = draw_finish
			record["cap_overlap_world"] = PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD
			record["exit_world_bleed"] = exit_world_bleed
			record["world_length"] = delta.length()
			record["road_width_world"] = road_width
		else:
			anchor = _coerce_vector2(binding.get("anchor_world", Vector2.INF))
			var target_width := float(SPECIAL_ROAD_TARGET_WIDTH.get(asset_id, 180.0))
			if asset_id == "turn_court":
				target_width = float(binding.get("target_width_world", target_width))
			var uniform_scale := target_width / maxf(1.0, content_rect.size.x)
			scale = Vector2.ONE * uniform_scale
		record["world_position"] = anchor
		record["world_scale"] = scale
		record["modulate"] = AXIS_ROAD_TINT if asset_id == "straight_horizontal" else Color.WHITE
		record["source_anchor_pixels"] = source_anchor
		record["content_rect_pixels"] = content_rect
		record["rotation_degrees"] = 0.0
		record["flip_h"] = false
		record["flip_v"] = false
		record["world_rect"] = _content_world_rect(content_rect, source_anchor, anchor, scale)
		draws.append(record)
	return draws


static func _road_render_asset_id(geometry_asset_id: String, edge_kind: String, basis: String) -> String:
	if geometry_asset_id.begins_with("straight_") and edge_kind == "secondary":
		return "secondary_%s" % basis
	if geometry_asset_id.begins_with("straight_") and edge_kind == "trail":
		return "trail_%s" % basis
	return geometry_asset_id


static func _road_material_class(edge_kind: String) -> String:
	match edge_kind:
		"secondary":
			return "trimless_stone"
		"trail":
			return "compacted_earth_gravel"
		"main", "approach":
			return "ceremonial_jade_gold_pavers"
	return "authored_special"


static func _build_road_composition_metrics(layout: Dictionary, road_draws: Array[Dictionary]) -> Dictionary:
	var basis_counts := {"horizontal": 0, "vertical": 0, "positive": 0, "negative": 0}
	var segment_counts_by_edge_kind := {"main": 0, "secondary": 0, "trail": 0, "approach": 0}
	var road_width_by_edge_kind := {}
	var material_classes_by_edge_kind := {}
	var width_consistent := true
	var material_hierarchy_valid := true
	var basis_draws: Array[Dictionary] = []
	var special_rects: Array[Rect2] = []
	var vertical_world_length := 0.0
	var basis_cap_overlap_contract_valid := true
	var exit_world_bleed_contract_valid := true
	var central_plaza_forecourt_count := 0
	var turn_court_count := 0
	var turn_court_edge_kind_counts := {"main": 0, "secondary": 0, "trail": 0, "approach": 0, "other": 0}
	for record in road_draws:
		if str(record.get("role", "")) == "basis_segment":
			basis_draws.append(record)
			var basis := str(record.get("basis", ""))
			if basis_counts.has(basis):
				basis_counts[basis] = int(basis_counts.get(basis, 0)) + 1
			if basis == "vertical":
				vertical_world_length += float(record.get("world_length", 0.0))
			var edge_kind := str(record.get("edge_kind", ""))
			if segment_counts_by_edge_kind.has(edge_kind):
				segment_counts_by_edge_kind[edge_kind] = int(segment_counts_by_edge_kind.get(edge_kind, 0)) + 1
			var width := float(record.get("road_width_world", 0.0))
			if road_width_by_edge_kind.has(edge_kind) and not is_equal_approx(float(road_width_by_edge_kind[edge_kind]), width):
				width_consistent = false
			elif edge_kind != "":
				road_width_by_edge_kind[edge_kind] = width
			var material_class := str(record.get("road_material_class", ""))
			if material_classes_by_edge_kind.has(edge_kind) and str(material_classes_by_edge_kind[edge_kind]) != material_class:
				material_hierarchy_valid = false
			elif edge_kind != "":
				material_classes_by_edge_kind[edge_kind] = material_class
			var start := _coerce_vector2(record.get("start_world", Vector2.INF))
			var finish := _coerce_vector2(record.get("finish_world", Vector2.INF))
			var direction := (finish - start).normalized()
			var expected_draw_start := start - direction * PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD
			var expected_draw_finish := finish + direction * PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD
			if bool(record.get("exit_world_bleed", false)):
				var world_size := _coerce_vector2(layout.get("world_size", Vector2.ZERO))
				if direction.x <= 0.0 or not world_size.is_finite():
					exit_world_bleed_contract_valid = false
				else:
					var bleed_distance := (world_size.x + PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD - finish.x) / direction.x
					expected_draw_finish = finish + direction * bleed_distance
					if expected_draw_finish.x < world_size.x + PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD - 0.001:
						exit_world_bleed_contract_valid = false
			if (
				not is_equal_approx(float(record.get("cap_overlap_world", -1.0)), PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD)
				or not _coerce_vector2(record.get("draw_start_world", Vector2.INF)).is_equal_approx(expected_draw_start)
				or not _coerce_vector2(record.get("draw_finish_world", Vector2.INF)).is_equal_approx(expected_draw_finish)
			):
				basis_cap_overlap_contract_valid = false
		else:
			if str(record.get("role", "")) == "central_plaza_forecourt":
				central_plaza_forecourt_count += 1
			if str(record.get("asset_id", "")) == "turn_court":
				turn_court_count += 1
				var turn_edge_kind := str(record.get("edge_kind", ""))
				var turn_bucket := turn_edge_kind if turn_court_edge_kind_counts.has(turn_edge_kind) else "other"
				turn_court_edge_kind_counts[turn_bucket] = int(turn_court_edge_kind_counts.get(turn_bucket, 0)) + 1
			var rect_value: Variant = record.get("world_rect", null)
			if rect_value is Rect2 and (rect_value as Rect2).has_area():
				special_rects.append(rect_value as Rect2)
	var basis_endpoint_count := basis_draws.size() * 2
	var covered_endpoint_count := 0
	var hub_rim_covered_endpoint_count := 0
	var hub_rim_endpoint_tokens := {}
	var soft_turn_overlap_endpoint_count := 0
	var exit_world_bleed_endpoint_count := 0
	var uncovered_endpoint_records: Array[Dictionary] = []
	var exclusion_zones := _dictionary_array(layout.get("road_art_exclusion_zones", []))
	for record in basis_draws:
		for key in ["start_world", "finish_world"]:
			var point := _coerce_vector2(record.get(key, Vector2.INF))
			var covered := false
			if key == "finish_world" and bool(record.get("exit_world_bleed", false)):
				covered = true
				exit_world_bleed_endpoint_count += 1
			for zone in exclusion_zones:
				if covered:
					break
				if _point_on_polygon_boundary(point, _vector2_array(zone.get("polygon_world", []))):
					covered = true
					hub_rim_endpoint_tokens["%.3f,%.3f" % [point.x, point.y]] = true
					break
			for rect in special_rects:
				if covered:
					break
				var record_rect_value: Variant = record.get("world_rect", null)
				var record_rect := record_rect_value as Rect2 if record_rect_value is Rect2 else Rect2()
				var road_half_width := float(record.get("road_width_world", 0.0)) * 0.5
				if (
					rect.grow(0.5).has_point(point)
					or (
						record_rect.has_area()
						and rect.intersects(record_rect, true)
						and _point_rect_distance(point, rect) <= road_half_width + 0.5
					)
				):
					covered = true
					break
			if not covered:
				var continuation_cover := _basis_endpoint_continuation_cover_kind(record, point, basis_draws)
				covered = continuation_cover != ""
				if continuation_cover == "soft_turn_overlap":
					soft_turn_overlap_endpoint_count += 1
			if covered:
				covered_endpoint_count += 1
			else:
				uncovered_endpoint_records.append({
					"draw_id": str(record.get("id", "")),
					"edge_id": str(record.get("edge_id", "")),
					"edge_kind": str(record.get("edge_kind", "")),
					"basis": str(record.get("basis", "")),
					"endpoint": str(key),
					"world_position": [snappedf(point.x, 0.001), snappedf(point.y, 0.001)],
				})
	hub_rim_covered_endpoint_count = hub_rim_endpoint_tokens.size()
	var main_width := float(road_width_by_edge_kind.get("main", 0.0))
	var approach_width := float(road_width_by_edge_kind.get("approach", 0.0))
	var secondary_width := float(road_width_by_edge_kind.get("secondary", 0.0))
	var trail_width := float(road_width_by_edge_kind.get("trail", 0.0))
	var width_hierarchy_valid := (
		width_consistent
		and main_width > approach_width
		and approach_width > secondary_width
		and secondary_width > trail_width
		and trail_width > 0.0
	)
	var central_plaza_crossing_count := 0
	for record in basis_draws:
		var start := _coerce_vector2(record.get("start_world", Vector2.INF))
		var finish := _coerce_vector2(record.get("finish_world", Vector2.INF))
		for zone in exclusion_zones:
			if _segment_enters_polygon_interior(start, finish, _vector2_array(zone.get("polygon_world", []))):
				central_plaza_crossing_count += 1
				break
	var expected_materials := {
		"main": "ceremonial_jade_gold_pavers",
		"approach": "ceremonial_jade_gold_pavers",
		"secondary": "trimless_stone",
		"trail": "compacted_earth_gravel",
	}
	for edge_kind_value in expected_materials.keys():
		var edge_kind := str(edge_kind_value)
		if segment_counts_by_edge_kind.get(edge_kind, 0) > 0 and str(material_classes_by_edge_kind.get(edge_kind, "")) != str(expected_materials[edge_kind]):
			material_hierarchy_valid = false
	return {
		"basis_counts": basis_counts,
		"basis_segment_count": basis_draws.size(),
		"screen_vertical_segment_count": int(basis_counts.get("vertical", 0)),
		"screen_vertical_world_length": snappedf(vertical_world_length, 0.001),
		"screen_vertical_render_policy": str(layout.get("screen_vertical_road_render_policy", "")),
		"segment_counts_by_edge_kind": segment_counts_by_edge_kind,
		"road_width_by_edge_kind": road_width_by_edge_kind,
		"road_width_hierarchy_valid": width_hierarchy_valid,
		"road_material_classes_by_edge_kind": material_classes_by_edge_kind,
		"road_material_hierarchy_valid": material_hierarchy_valid,
		"basis_endpoint_count": basis_endpoint_count,
		"basis_endpoint_special_cover_count": covered_endpoint_count,
		"basis_endpoint_hub_rim_cover_count": hub_rim_covered_endpoint_count,
		"basis_endpoint_soft_turn_overlap_count": soft_turn_overlap_endpoint_count,
		"basis_endpoint_exit_world_bleed_count": exit_world_bleed_endpoint_count,
		"basis_endpoint_without_special_cover_count": basis_endpoint_count - covered_endpoint_count,
		"basis_endpoint_without_special_cover_records": uncovered_endpoint_records,
		"basis_cap_overlap_world": PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD,
		"basis_cap_overlap_contract_valid": basis_cap_overlap_contract_valid,
		"exit_world_bleed_contract_valid": exit_world_bleed_contract_valid,
		"basis_endpoint_render_policy": str(layout.get("basis_endpoint_render_policy", "")),
		"central_plaza_exclusion_contract_present": not exclusion_zones.is_empty(),
		"central_plaza_exclusion_zone_count": exclusion_zones.size(),
		"central_plaza_crossing_count": -1 if exclusion_zones.is_empty() else central_plaza_crossing_count,
		"central_plaza_forecourt_count": central_plaza_forecourt_count,
		"turn_court_count": turn_court_count,
		"turn_court_edge_kind_counts": turn_court_edge_kind_counts,
		"authored_main_spine_turn_count": int((layout.get("road_graph", {}) as Dictionary).get("main_spine_turn_count", -1)),
		"rendered_spawn_to_plaza_turn_count": _rendered_spawn_to_plaza_turn_count(layout),
		"explicit_basis_overlap_count": _dictionary_array(layout.get("road_crossing_bindings", [])).size(),
	}


static func _basis_endpoint_continuation_cover_kind(
	record: Dictionary,
	point: Vector2,
	basis_draws: Array[Dictionary]
) -> String:
	var record_direction := (
		_coerce_vector2(record.get("finish_world", Vector2.INF))
		- _coerce_vector2(record.get("start_world", Vector2.INF))
	).normalized()
	for candidate in basis_draws:
		if str(candidate.get("id", "")) == str(record.get("id", "")):
			continue
		var candidate_start := _coerce_vector2(candidate.get("start_world", Vector2.INF))
		var candidate_finish := _coerce_vector2(candidate.get("finish_world", Vector2.INF))
		if not point.is_equal_approx(candidate_start) and not point.is_equal_approx(candidate_finish):
			continue
		var candidate_direction := (candidate_finish - candidate_start).normalized()
		if absf(record_direction.dot(candidate_direction)) >= 0.999:
			return "collinear_overlap"
		var edge_kind := str(record.get("edge_kind", ""))
		if (
			["approach", "trail"].has(edge_kind)
			and str(candidate.get("edge_kind", "")) == edge_kind
			and str(candidate.get("edge_id", "")) == str(record.get("edge_id", ""))
			and is_equal_approx(float(record.get("cap_overlap_world", -1.0)), PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD)
			and is_equal_approx(float(candidate.get("cap_overlap_world", -1.0)), PlazaMapRoadSkeletonR3.STRAIGHT_CAP_OVERLAP_WORLD)
		):
			return "soft_turn_overlap"
	return ""


static func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var closest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)
	return point.distance_to(closest)


static func _rendered_spawn_to_plaza_turn_count(layout: Dictionary) -> int:
	var road := layout.get("road_graph", {}) as Dictionary
	var route_ids: Array[String] = []
	for value in road.get("main_route_node_ids", []) as Array:
		route_ids.append(str(value))
	var destination_index := route_ids.find("main_0")
	if destination_index <= 0:
		return 999
	var edges := _dictionary_array(road.get("edges", []))
	var previous_direction := ""
	var turn_count := 0
	for route_index in range(destination_index):
		var edge := {}
		for candidate in edges:
			if (
				str(candidate.get("kind", "")) == "main"
				and str(candidate.get("from", "")) == route_ids[route_index]
				and str(candidate.get("to", "")) == route_ids[route_index + 1]
			):
				edge = candidate
				break
		if edge.is_empty():
			return 999
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for segment_index in range(polyline.size() - 1):
			var direction := PlazaMapRoadSkeletonR3.classify_directed_segment(polyline[segment_index], polyline[segment_index + 1])
			if direction == "":
				continue
			if previous_direction != "" and direction != previous_direction:
				turn_count += 1
			previous_direction = direction
	return turn_count


static func _segment_corridor_polygon(start: Vector2, finish: Vector2, half_width: float) -> Array[Vector2]:
	var delta := finish - start
	if delta.length_squared() <= 0.000001 or half_width <= 0.0:
		return []
	var tangent := delta.normalized()
	var normal := Vector2(-tangent.y, tangent.x) * half_width
	var extension := tangent * half_width
	return [
		start - extension + normal,
		finish + extension + normal,
		finish + extension - normal,
		start - extension - normal,
	]


static func _segment_enters_polygon_interior(start: Vector2, finish: Vector2, polygon: Array[Vector2]) -> bool:
	if polygon.size() < 3 or start.is_equal_approx(finish):
		return false
	var cuts: Array[float] = [0.0, 1.0]
	var delta := finish - start
	var length_squared := delta.length_squared()
	for index in range(polygon.size()):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			start,
			finish,
			polygon[index],
			polygon[(index + 1) % polygon.size()]
		)
		if not (intersection is Vector2):
			continue
		var amount := clampf(((intersection as Vector2) - start).dot(delta) / length_squared, 0.0, 1.0)
		var duplicate := false
		for existing in cuts:
			if is_equal_approx(existing, amount):
				duplicate = true
				break
		if not duplicate:
			cuts.append(amount)
	cuts.sort()
	for index in range(cuts.size() - 1):
		if cuts[index + 1] - cuts[index] <= 0.000001:
			continue
		var midpoint := start.lerp(finish, (cuts[index] + cuts[index + 1]) * 0.5)
		if _point_strictly_inside_polygon(midpoint, polygon):
			return true
	return false


static func _point_strictly_inside_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	if not Geometry2D.is_point_in_polygon(point, PackedVector2Array(polygon)):
		return false
	for index in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if closest.distance_squared_to(point) <= 0.000001:
			return false
	return true


static func _point_on_polygon_boundary(point: Vector2, polygon: Array[Vector2]) -> bool:
	if not point.is_finite() or polygon.size() < 3:
		return false
	for index in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if closest.distance_squared_to(point) <= 0.001 * 0.001:
			return true
	return false


static func _polygon_intersection_area(left: Array[Vector2], right: Array[Vector2]) -> float:
	if left.size() < 3 or right.size() < 3:
		return 0.0
	var total := 0.0
	for polygon in Geometry2D.intersect_polygons(PackedVector2Array(left), PackedVector2Array(right)):
		total += absf(_packed_polygon_signed_area(polygon))
	return total


static func _packed_polygon_signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5


static func _compile_plot_pad_draws(layout: Dictionary, assets: Dictionary) -> Array[Dictionary]:
	var draws: Array[Dictionary] = []
	var plots := _dictionary_array(layout.get("plots", []))
	for building in _dictionary_array(layout.get("building_specs", [])):
		var plot_id := str(building.get("plot_id", ""))
		var plot := _find_by_id(plots, plot_id)
		if plot.is_empty():
			continue
		var plot_class := str(plot.get("plot_class", ""))
		var asset_id := "plot_pad_large" if LARGE_PAD_PLOT_CLASSES.has(plot_class) else "plot_pad_small"
		var asset := assets.get("plot_pad:%s" % asset_id, {}) as Dictionary
		var record := _base_draw_record("pad_%s" % plot_id, "plot_pad", asset_id, asset)
		if record.is_empty():
			continue
		var boundary_aabb := _polygon_aabb(_vector2_array(plot.get("boundary_polygon_world", [])))
		var placement := asset.get("placement", {}) as Dictionary
		var content_rect := _array_to_rect2(placement.get("runtime_content_rect", []))
		var source_anchor := _array_to_vector2(placement.get("runtime_anchor", []))
		var scale := boundary_aabb.size.x * 0.90 / maxf(1.0, content_rect.size.x)
		var anchor := _coerce_vector2(plot.get("pivot_pos", Vector2.INF))
		record["plot_id"] = plot_id
		record["building_type"] = str(building.get("type", ""))
		record["plot_class"] = plot_class
		record["world_position"] = anchor
		record["world_scale"] = Vector2.ONE * scale
		record["source_anchor_pixels"] = source_anchor
		record["content_rect_pixels"] = content_rect
		record["rotation_degrees"] = 0.0
		record["flip_h"] = false
		record["flip_v"] = false
		record["world_rect"] = _content_world_rect(content_rect, source_anchor, anchor, Vector2.ONE * scale)
		draws.append(record)
	return draws


static func _compile_decor_draws(layout: Dictionary, assets: Dictionary) -> Array[Dictionary]:
	var draws: Array[Dictionary] = []
	for cluster in _dictionary_array(layout.get("decor_clusters", [])):
		var cluster_type := str(cluster.get("cluster_type", ""))
		var asset_id := get_decor_asset_id(cluster_type)
		if asset_id == "":
			return []
		var asset := assets.get("decor_cluster:%s" % asset_id, {}) as Dictionary
		var record := _base_draw_record("decor_%s" % str(cluster.get("id", "")), "decor_cluster", asset_id, asset)
		if record.is_empty():
			continue
		var visual_bounds := cluster.get("visual_bounds_world", Rect2()) as Rect2
		var placement := asset.get("placement", {}) as Dictionary
		var content_rect := _array_to_rect2(placement.get("runtime_content_rect", []))
		var source_anchor := _array_to_vector2(placement.get("runtime_anchor", []))
		var scale := minf(
			visual_bounds.size.x / maxf(1.0, content_rect.size.x),
			visual_bounds.size.y / maxf(1.0, content_rect.size.y)
		)
		var anchor := _coerce_vector2(cluster.get("anchor_world", Vector2.INF))
		record["cluster_id"] = str(cluster.get("id", ""))
		record["cluster_type"] = cluster_type
		record["plot_id"] = str(cluster.get("plot_id", ""))
		record["world_position"] = anchor
		record["world_scale"] = Vector2.ONE * scale
		record["source_anchor_pixels"] = source_anchor
		record["content_rect_pixels"] = content_rect
		record["rotation_degrees"] = 0.0
		record["flip_h"] = false
		record["flip_v"] = false
		record["world_rect"] = _content_world_rect(content_rect, source_anchor, anchor, Vector2.ONE * scale)
		draws.append(record)
	return draws


static func _base_draw_record(id: String, kind: String, asset_id: String, asset: Dictionary) -> Dictionary:
	var texture_path := str(asset.get("res_path", ""))
	var texture_size := _asset_texture_size(asset)
	if id == "" or texture_path == "" or texture_size == Vector2.ZERO:
		return {}
	return {
		"id": id,
		"kind": kind,
		"asset_id": asset_id,
		"texture_path": texture_path,
		"texture_size": texture_size,
		"source_anchor_pixels": Vector2.ZERO,
		"content_rect_pixels": Rect2(Vector2.ZERO, texture_size),
	}


static func _draw_record_is_valid(record: Dictionary, expected_kind: String) -> bool:
	if str(record.get("id", "")) == "" or str(record.get("kind", "")) != expected_kind:
		return false
	if str(record.get("asset_id", "")) == "" or not FileAccess.file_exists(str(record.get("texture_path", ""))):
		return false
	var position := _coerce_vector2(record.get("world_position", Vector2.INF))
	var scale := _coerce_vector2(record.get("world_scale", Vector2.INF))
	var source_anchor := _coerce_vector2(record.get("source_anchor_pixels", Vector2.INF))
	var content_rect_value: Variant = record.get("content_rect_pixels", null)
	var rect_value: Variant = record.get("world_rect", null)
	var rotation_value: Variant = record.get("rotation_degrees", null)
	var modulate_value: Variant = record.get("modulate", Color.WHITE)
	return (
		position.is_finite()
		and scale.is_finite()
		and source_anchor.is_finite()
		and content_rect_value is Rect2
		and (content_rect_value as Rect2).has_area()
		and scale.x > 0.0
		and scale.y > 0.0
		and rect_value is Rect2
		and (rect_value as Rect2).has_area()
		and _is_finite_number(rotation_value)
		and modulate_value is Color
		and _color_is_finite(modulate_value as Color)
		and is_zero_approx(float(rotation_value))
		and not bool(record.get("flip_h", true))
		and not bool(record.get("flip_v", true))
	)


static func _asset_texture_size(asset: Dictionary) -> Vector2:
	var qa_value: Variant = asset.get("qa", null)
	if not (qa_value is Dictionary):
		return Vector2.ZERO
	return _array_to_vector2((qa_value as Dictionary).get("size", []))


static func _content_world_rect(
	content_rect: Rect2,
	source_anchor: Vector2,
	anchor: Vector2,
	scale: Vector2
) -> Rect2:
	return Rect2(anchor + (content_rect.position - source_anchor) * scale, content_rect.size * scale)


static func _draw_token(record: Dictionary) -> String:
	var world_rect := record.get("world_rect", Rect2()) as Rect2 if record.get("world_rect", null) is Rect2 else Rect2()
	var content_rect := record.get("content_rect_pixels", Rect2()) as Rect2 if record.get("content_rect_pixels", null) is Rect2 else Rect2()
	var modulate := record.get("modulate", Color.WHITE) as Color if record.get("modulate", null) is Color else Color.TRANSPARENT
	var token := "%s:%s:%s:%s:%s:%s:%s:%s:%s:%.3f:%d:%d:%s:%s:%s:%s:%s:%s" % [
		str(record.get("id", "")),
		str(record.get("kind", "")),
		str(record.get("asset_id", "")),
		str(record.get("texture_path", "")),
		_vector_token(_coerce_vector2(record.get("world_position", Vector2.ZERO))),
		_vector_token(_coerce_vector2(record.get("world_scale", Vector2.ZERO))),
		_vector_token(_coerce_vector2(record.get("source_anchor_pixels", Vector2.ZERO))),
		_rect_token(content_rect),
		_rect_token(world_rect),
		float(record.get("rotation_degrees", -999.0)),
		1 if bool(record.get("flip_h", true)) else 0,
		1 if bool(record.get("flip_v", true)) else 0,
		str(record.get("role", "")),
		str(record.get("edge_id", record.get("plot_id", ""))),
		str(record.get("cluster_type", record.get("building_type", ""))),
		str(record.get("orientation_contract", "")),
		str(record.get("orientation_signature", "")),
		"%.3f,%.3f,%.3f,%.3f" % [modulate.r, modulate.g, modulate.b, modulate.a],
	]
	return "%s:%s:%.3f:%s:%s:%s:%s:%.3f" % [
		token,
		str(record.get("edge_kind", "")),
		float(record.get("road_width_world", 0.0)),
		str(record.get("geometry_asset_id", "")),
		str(record.get("road_material_class", "")),
		_vector_token(_coerce_vector2(record.get("draw_start_world", Vector2.ZERO))),
		_vector_token(_coerce_vector2(record.get("draw_finish_world", Vector2.ZERO))),
		float(record.get("cap_overlap_world", 0.0)),
	]


static func _road_composition_token(metrics: Dictionary) -> String:
	var parts: Array[String] = [
		str(metrics.get("basis_counts", {})),
		str(metrics.get("segment_counts_by_edge_kind", {})),
		str(metrics.get("road_width_by_edge_kind", {})),
		str(metrics.get("road_width_hierarchy_valid", false)),
		str(metrics.get("road_material_classes_by_edge_kind", {})),
		str(metrics.get("road_material_hierarchy_valid", false)),
		str(metrics.get("screen_vertical_segment_count", -1)),
		str(metrics.get("screen_vertical_world_length", -1.0)),
		str(metrics.get("screen_vertical_render_policy", "")),
		str(metrics.get("basis_endpoint_count", -1)),
		str(metrics.get("basis_endpoint_special_cover_count", -1)),
		str(metrics.get("basis_endpoint_hub_rim_cover_count", -1)),
		str(metrics.get("basis_endpoint_soft_turn_overlap_count", -1)),
		str(metrics.get("basis_endpoint_exit_world_bleed_count", -1)),
		str(metrics.get("basis_endpoint_without_special_cover_count", -1)),
		str(metrics.get("basis_endpoint_without_special_cover_records", [])),
		str(metrics.get("basis_cap_overlap_world", -1.0)),
		str(metrics.get("basis_cap_overlap_contract_valid", false)),
		str(metrics.get("exit_world_bleed_contract_valid", false)),
		str(metrics.get("basis_endpoint_render_policy", "")),
		str(metrics.get("central_plaza_exclusion_contract_present", false)),
		str(metrics.get("central_plaza_exclusion_zone_count", -1)),
		str(metrics.get("central_plaza_crossing_count", -1)),
		str(metrics.get("central_plaza_forecourt_count", -1)),
		str(metrics.get("turn_court_edge_kind_counts", {})),
		str(metrics.get("authored_main_spine_turn_count", -1)),
		str(metrics.get("rendered_spawn_to_plaza_turn_count", -1)),
		str(metrics.get("explicit_basis_overlap_count", -1)),
	]
	return "composition:%s" % ":".join(PackedStringArray(parts))


static func _polygon_aabb(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


static func _find_by_id(records: Array[Dictionary], wanted_id: String) -> Dictionary:
	for record in records:
		if str(record.get("id", "")) == wanted_id:
			return record
	return {}


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


static func _vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Vector2:
			result.append(item as Vector2)
		elif item is Vector2i:
			result.append(Vector2(item as Vector2i))
	return result


static func _json_polygon_to_vector2(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for point_value in value as Array:
		if not (point_value is Array) or (point_value as Array).size() != 2:
			return []
		var pair := point_value as Array
		if not _is_finite_number(pair[0]) or not _is_finite_number(pair[1]):
			return []
		result.append(Vector2(float(pair[0]), float(pair[1])))
	return result


static func _polygon_signed_area(polygon: Array[Vector2]) -> float:
	var twice_area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5


static func _polygon_token(polygon: Array[Vector2]) -> String:
	var tokens: Array[String] = []
	for point in polygon:
		tokens.append(_vector_token(point))
	return ";".join(PackedStringArray(tokens))


static func _array_to_vector2(value: Variant) -> Vector2:
	if not (value is Array) or (value as Array).size() != 2:
		return Vector2.ZERO
	var values := value as Array
	if not _is_finite_number(values[0]) or not _is_finite_number(values[1]):
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))


static func _array_to_rect2(value: Variant) -> Rect2:
	if not (value is Array) or (value as Array).size() != 4:
		return Rect2()
	var values := value as Array
	for item in values:
		if not _is_finite_number(item):
			return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	return Vector2.INF


static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


static func _is_positive_finite_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0


static func _color_is_finite(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)


static func _vector_token(value: Vector2) -> String:
	return "%.3f,%.3f" % [value.x, value.y]


static func _rect_token(value: Rect2) -> String:
	return "%s:%.3f,%.3f" % [_vector_token(value.position), value.size.x, value.size.y]


static func _add_violation(violations: Array[Dictionary], code: String, detail: String) -> void:
	violations.append({"code": code, "detail": detail})


static func _rejected_plan(reason: String, details: Variant = null) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"candidate_only": true,
		"production_connected": false,
		"fingerprint": "",
		"validation": {
			"valid": false,
			"violations": [{"code": "compile_rejected", "detail": "%s:%s" % [reason, str(details)]}],
			"metrics": {},
		},
	}
