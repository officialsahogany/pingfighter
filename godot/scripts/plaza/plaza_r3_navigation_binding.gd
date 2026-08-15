extends RefCounted

# R3-B candidate-only binding adapter. R3-A adds the approved central plaza as
# a walkable hub outside the edge-derived corridor manifest, so the R2 binding
# must not be reused unchanged: doing so would render the plaza walkable while
# silently making it impassable. This owner validates the complete R3 layout,
# seals its canonical fingerprint, then binds corridors + hubs exactly once
# into the existing compiled navigation owner.

const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")

const BINDING_KIND := "validated_r3_layout_with_walkable_hubs"


static func bind_layout(layout: Dictionary, expected_layout_fingerprint: String) -> Dictionary:
	var validation := PlazaMapRoadSkeletonR3.validate_layout(layout)
	if not bool(validation.get("valid", false)):
		return _rejected_state("r3_layout_validation_failed")
	var stored_value: Variant = layout.get("fingerprint", null)
	if not (stored_value is String) or str(stored_value) != expected_layout_fingerprint:
		return _rejected_state("expected_layout_fingerprint_mismatch")
	if PlazaMapRoadSkeletonR3.build_fingerprint(layout) != expected_layout_fingerprint:
		return _rejected_state("stale_r3_layout_fingerprint")

	var corridors := PlazaMapNavigation._copy_polygon_manifest(
		layout.get("walkable_corridor_polygons", []),
		["id", "edge_id", "edge_kind"]
	)
	var hubs := PlazaMapNavigation._copy_polygon_manifest(
		layout.get("walkable_hub_polygons", []),
		["id", "edge_id", "edge_kind", "source_contract_id"]
	)
	if corridors.is_empty():
		return _rejected_state("walkable_corridors_empty")
	if hubs.is_empty():
		return _rejected_state("walkable_hubs_empty")
	var seen_ids := {}
	for record in corridors:
		var record_id := str(record.get("id", ""))
		if record_id == "" or seen_ids.has(record_id):
			return _rejected_state("duplicate_or_empty_walkable_id")
		seen_ids[record_id] = true
	var seen_hub_ids := {}
	for hub in hubs:
		var hub_id := str(hub.get("id", ""))
		if hub_id == "" or seen_hub_ids.has(hub_id):
			return _rejected_state("duplicate_or_empty_walkable_id")
		seen_hub_ids[hub_id] = true
		# R3-A publishes the authored hub twice on purpose: the dedicated
		# manifest seals its provenance, while the corridor manifest is the
		# complete navigation union. Require those views to agree exactly and
		# keep the union entry once instead of appending a duplicate polygon.
		var union_match_count := 0
		for corridor in corridors:
			if str(corridor.get("id", "")) != hub_id:
				continue
			union_match_count += 1
			if (
				str(corridor.get("edge_id", "")) != str(hub.get("edge_id", ""))
				or str(corridor.get("edge_kind", "")) != str(hub.get("edge_kind", ""))
				or corridor.get("polygon_world", []) != hub.get("polygon_world", [])
			):
				return _rejected_state("walkable_hub_union_mismatch")
		if union_match_count != 1:
			return _rejected_state("walkable_hub_union_mismatch")

	var portals := PlazaMapNavigation._copy_polygon_manifest(
		layout.get("interaction_portals", []),
		["id", "building_type", "plot_id", "approach_edge_id"]
	)
	var blockers := PlazaMapNavigation._copy_polygon_manifest(
		layout.get("blocked_polygons", []),
		["owner_id", "kind"]
	)
	return PlazaMapNavigation._build_bound_state(
		BINDING_KIND,
		expected_layout_fingerprint,
		corridors,
		portals,
		blockers
	)


static func _rejected_state(reason: String) -> Dictionary:
	return {
		"valid": false,
		"schema_version": PlazaMapNavigation.SCHEMA_VERSION,
		"rejection_reason": reason,
		"binding_kind": BINDING_KIND,
	}
