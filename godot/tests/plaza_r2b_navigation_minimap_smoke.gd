extends SceneTree

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")
const PlazaMapMinimapProjection2D := preload("res://scripts/plaza/plaza_map_minimap_projection_2d.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const MINIMAP_RECT := Rect2(Vector2(36.0, 24.0), Vector2(320.0, 200.0))
const SPEED_EPSILON := 0.001

var _failures: Array[String] = []


func _init() -> void:
	var selected_specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, false, false)
	var layout := PlazaMapLayoutGenerator.generate(
		1,
		5,
		WORLD_SIZE,
		selected_specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)
	var fingerprint := str(layout.get("fingerprint", ""))
	_expect(bool((layout.get("validation", {}) as Dictionary).get("valid", false)), "seed 5 prerequisite layout must be valid")
	var navigation := PlazaMapNavigation.bind_layout(layout, fingerprint)
	_expect(bool(navigation.get("valid", false)), "navigation must bind the validated seed 5 fingerprint: %s" % navigation.get("rejection_reason", ""))

	_verify_fingerprint_fail_closed(layout, fingerprint)
	_verify_bound_state_mutation_rejection(navigation)
	_verify_speed_contract(navigation)
	_verify_full_body_sampling_counterproof(navigation)
	_verify_exact_slit_counterproof()
	_verify_seed5_portal_reach(layout, navigation)
	_verify_blocker_sweep_counterproof(layout, navigation)
	_verify_axis_slide_counterproof(layout, navigation)
	_verify_outside_walkable_rejection(navigation)
	_verify_minimap_2d(layout, fingerprint)
	_verify_minimap_all_building_types()

	if _failures.is_empty():
		print("plaza_r2b_navigation_minimap_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_fingerprint_fail_closed(layout: Dictionary, fingerprint: String) -> void:
	var stale := PlazaMapNavigation.bind_layout(layout, "0".repeat(64))
	_expect(not bool(stale.get("valid", true)), "a stale caller fingerprint must fail closed")
	_expect(str(stale.get("rejection_reason", "")) == "expected_fingerprint_mismatch", "stale caller fingerprint must expose its exact rejection reason")

	var corrupt := layout.duplicate(true)
	# stage_id participates in the authoritative digest but does not alter this
	# already-materialized geometry. This isolates the rebuilt-fingerprint leg
	# from the generator's separate seed/assignment semantic validator.
	corrupt["stage_id"] = int(layout.get("stage_id", 0)) + 1
	var corrupt_bind := PlazaMapNavigation.bind_layout(corrupt, fingerprint)
	_expect(not bool(corrupt_bind.get("valid", true)), "geometry metadata changed under an old fingerprint must fail closed")
	_expect(str(corrupt_bind.get("rejection_reason", "")) == "layout_fingerprint_mismatch", "corrupt layout must be rejected by rebuilt fingerprint comparison")

	var malformed := PlazaMapNavigation.bind_layout(layout, "not-a-sha256")
	_expect(not bool(malformed.get("valid", true)), "a malformed fingerprint must fail closed")
	_expect(str(malformed.get("rejection_reason", "")) == "invalid_expected_fingerprint", "malformed fingerprint must not reach geometry binding")


func _verify_bound_state_mutation_rejection(navigation: Dictionary) -> void:
	var corridor_mutation := navigation.duplicate(true)
	var corridors := _dictionary_array(corridor_mutation.get("walkable_corridor_polygons", []))
	if not corridors.is_empty():
		var polygon := _vector2_array(corridors[0].get("polygon_world", []))
		polygon[0] += Vector2(1.0, 0.0)
		corridors[0]["polygon_world"] = polygon
		corridor_mutation["walkable_corridor_polygons"] = corridors
		_expect(not PlazaMapNavigation.can_occupy(corridor_mutation, SPAWN_ANCHOR, true), "post-bind corridor mutation must invalidate public occupancy")
		var corridor_move := PlazaMapNavigation.move_actor(corridor_mutation, SPAWN_ANCHOR, Vector2.RIGHT, 1.0 / 60.0)
		_expect(not bool(corridor_move.get("valid", true)), "post-bind corridor mutation must invalidate public movement")

	var portal_mutation := navigation.duplicate(true)
	var portals := _dictionary_array(portal_mutation.get("interaction_portals", []))
	if not portals.is_empty():
		var polygon := _vector2_array(portals[0].get("polygon_world", []))
		polygon[0] += Vector2(0.0, 1.0)
		portals[0]["polygon_world"] = polygon
		portal_mutation["interaction_portals"] = portals
		_expect(not PlazaMapNavigation.can_occupy(portal_mutation, SPAWN_ANCHOR, true), "post-bind portal mutation must invalidate public occupancy")
		var portal_move := PlazaMapNavigation.move_actor(portal_mutation, SPAWN_ANCHOR, Vector2.RIGHT, 1.0 / 60.0)
		_expect(not bool(portal_move.get("valid", true)), "post-bind portal mutation must invalidate public movement")

	var blocker_mutation := navigation.duplicate(true)
	var blockers := _dictionary_array(blocker_mutation.get("blocked_polygons", []))
	if not blockers.is_empty():
		blockers.remove_at(0)
		blocker_mutation["blocked_polygons"] = blockers
		_expect(not PlazaMapNavigation.can_occupy(blocker_mutation, SPAWN_ANCHOR, true), "post-bind blocker removal must invalidate public occupancy")
		var blocker_move := PlazaMapNavigation.move_actor(blocker_mutation, SPAWN_ANCHOR, Vector2.RIGHT, 1.0 / 60.0)
		_expect(not bool(blocker_move.get("valid", true)), "post-bind blocker removal must invalidate public movement")


func _verify_speed_contract(navigation: Dictionary) -> void:
	var frame_delta := 1.0 / 60.0
	var cardinal := PlazaMapNavigation.compute_intended_motion(Vector2.RIGHT, frame_delta)
	var diagonal := PlazaMapNavigation.compute_intended_motion(Vector2(1.0, 1.0), frame_delta)
	_expect(absf(cardinal.length() - diagonal.length()) <= SPEED_EPSILON, "diagonal navigation input must not outrun cardinal input")
	_expect(absf(cardinal.length() - PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60) <= SPEED_EPSILON, "R2-B navigation must reuse the production player speed")
	var legacy_result := PlazaPlayerController.move_player(
		Vector2(1200.0, 750.0),
		Vector2(1.0, 1.0),
		frame_delta,
		[],
		WORLD_SIZE
	)
	var legacy_delta: Vector2 = legacy_result.get("player_pos", Vector2.ZERO) - Vector2(1200.0, 750.0)
	_expect(legacy_delta.distance_to(diagonal) <= SPEED_EPSILON, "R2-B direction normalization must stay in parity with PlazaPlayerController (legacy=%s r2b=%s)" % [legacy_delta, diagonal])
	_expect(bool(navigation.get("valid", false)), "speed parity must be tested against a bound navigation state")


func _verify_full_body_sampling_counterproof(navigation: Dictionary) -> void:
	var center_only_candidate := Vector2.INF
	for corridor in _dictionary_array(navigation.get("walkable_corridor_polygons", [])):
		var polygon := _vector2_array(corridor.get("polygon_world", []))
		if polygon.size() < 3:
			continue
		var centroid := Vector2.ZERO
		for point in polygon:
			centroid += point
		centroid /= float(polygon.size())
		for index in range(polygon.size()):
			var edge_midpoint := polygon[index].lerp(polygon[(index + 1) % polygon.size()], 0.5)
			var candidate := edge_midpoint.lerp(centroid, 0.03)
			if Geometry2D.is_point_in_polygon(candidate, PackedVector2Array(polygon)) and not PlazaMapNavigation.can_occupy(navigation, candidate, true):
				center_only_candidate = candidate
				break
		if center_only_candidate != Vector2.INF:
			break
	_expect(center_only_candidate != Vector2.INF, "QA must find a corridor-center point whose 38 x 32 body crosses the union boundary")
	if center_only_candidate != Vector2.INF:
		_expect(not PlazaMapNavigation.can_occupy(navigation, center_only_candidate, true), "center-only acceptance must stay RED when positive actor area leaves the union")


func _verify_exact_slit_counterproof() -> void:
	# The 2px slit lies between the old center/corner/edge sample columns. All
	# nine historical samples are walkable, but 64 square world units of the
	# actual 38 x 32 body are not.
	var left_rect := Rect2(Vector2(500.0, 500.0), Vector2(157.0, 260.0))
	var right_rect := Rect2(Vector2(659.0, 500.0), Vector2(181.0, 260.0))
	var fixture := {
		"schema_version": PlazaMapNavigation.QA_FIXTURE_SCHEMA_VERSION,
		"world_size": WORLD_SIZE,
		"walkable_corridor_polygons": [
			{"id": "slit_left", "edge_id": "slit_left", "edge_kind": "qa", "polygon_world": _rect_polygon(left_rect)},
			{"id": "slit_right", "edge_id": "slit_right", "edge_kind": "qa", "polygon_world": _rect_polygon(right_rect)},
		],
		"interaction_portals": [],
		"blocked_polygons": [],
	}
	var state := _bind_qa_fixture(fixture)
	_expect(bool(state.get("valid", false)), "2px slit fixture must bind through the isolated QA path")
	if not bool(state.get("valid", false)):
		return
	var slit_body_center := Vector2(650.0, 630.0)
	_expect(_legacy_nine_samples_fit(slit_body_center, [left_rect, right_rect]), "2px slit must evade all nine historical body samples")
	_expect(not PlazaMapNavigation.can_occupy(state, slit_body_center, true), "exact actor Rect subtraction must reject the 2px uncovered slit")

	var start := Vector2(630.0, 630.0)
	var finish := Vector2(690.0, 630.0)
	_expect(PlazaMapNavigation.can_occupy(state, start, true), "slit sweep must start fully inside the left polygon")
	_expect(PlazaMapNavigation.can_occupy(state, finish, true), "slit sweep control target must fit fully inside the right polygon")
	var result := PlazaMapNavigation.move_actor(
		state,
		start,
		Vector2.RIGHT,
		start.distance_to(finish) / PlazaMapNavigation.PLAYER_SPEED_WORLD_PER_SECOND
	)
	var swept_position: Vector2 = result.get("actor_position", start)
	_expect(bool(result.get("valid", false)), "slit swept-movement leg must execute")
	_expect(bool(result.get("blocked", false)), "2px non-walkable slit must block a large-delta sweep")
	_expect(swept_position.x <= 638.01, "4px swept substeps must not tunnel the 38px body across the slit (got %.3f)" % swept_position.x)


func _verify_seed5_portal_reach(layout: Dictionary, navigation: Dictionary) -> void:
	if not bool(navigation.get("valid", false)):
		return
	var target_data := _find_real_portal_only_target(layout, navigation)
	_expect(not target_data.is_empty(), "seed 5 must expose a full-body portal position outside the corridor-only union")
	if target_data.is_empty():
		return
	var target: Vector2 = target_data.get("position", Vector2.INF)
	_expect(PlazaMapNavigation.can_occupy(navigation, target, true), "real seed 5 portal target must be occupiable in corridor + portal union")
	_expect(not PlazaMapNavigation.can_occupy(navigation, target, false), "the same portal target must be RED when interaction portals are removed")

	var building_type := str(target_data.get("building_type", ""))
	var waypoints := _route_waypoints_to_portal(layout, building_type, target)
	_expect(not waypoints.is_empty(), "seed 5 road graph must expose a spawn-to-%s portal route" % building_type)
	if waypoints.is_empty():
		return
	var actor_position := SPAWN_ANCHOR
	_expect(PlazaMapNavigation.can_occupy(navigation, actor_position, true), "seed 5 spawn must fit the full 38 x 32 actor body")
	var move_steps := 0
	for waypoint in waypoints:
		var target_waypoint := waypoint as Vector2
		var guard := 0
		while actor_position.distance_to(target_waypoint) > 0.05 and guard < 3000:
			guard += 1
			var remaining := actor_position.distance_to(target_waypoint)
			var delta := minf(1.0 / 60.0, remaining / PlazaMapNavigation.PLAYER_SPEED_WORLD_PER_SECOND)
			var result := PlazaMapNavigation.move_actor(
				navigation,
				actor_position,
				actor_position.direction_to(target_waypoint),
				delta
			)
			if not bool(result.get("valid", false)):
				_expect(false, "seed 5 portal traversal rejected at %s toward %s: %s" % [actor_position, target_waypoint, result.get("rejection_reason", "")])
				return
			var next_position: Vector2 = result.get("actor_position", actor_position)
			if next_position.distance_squared_to(actor_position) <= 0.000001:
				_expect(false, "seed 5 portal traversal stalled at %s toward %s" % [actor_position, target_waypoint])
				return
			actor_position = next_position
			move_steps += 1
		_expect(guard < 3000, "seed 5 portal traversal waypoint guard must not expire")
	_expect(actor_position.distance_to(target) <= 0.1, "actor must reach the real %s portal target from spawn" % building_type)
	print("plaza_r2b_navigation_minimap_smoke: portal=%s target=%s move_steps=%d" % [building_type, target, move_steps])


func _verify_blocker_sweep_counterproof(layout: Dictionary, navigation: Dictionary) -> void:
	if not bool(navigation.get("valid", false)):
		return
	var segment := _find_long_open_main_segment(layout, navigation)
	_expect(not segment.is_empty(), "seed 5 must expose a straight main-road segment for swept blocker QA")
	if segment.is_empty():
		return
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var finish: Vector2 = segment.get("finish", Vector2.ZERO)
	var midpoint := start.lerp(finish, 0.5)
	var tangent := start.direction_to(finish)
	var perpendicular := Vector2(-tangent.y, tangent.x)
	var half_along := 1.0
	var half_across := 76.0
	var barrier := [
		midpoint - tangent * half_along - perpendicular * half_across,
		midpoint + tangent * half_along - perpendicular * half_across,
		midpoint + tangent * half_along + perpendicular * half_across,
		midpoint - tangent * half_along + perpendicular * half_across,
	]
	var blocked_fixture := _qa_fixture_from_navigation(navigation)
	var blockers: Array = blocked_fixture.get("blocked_polygons", [])
	blockers.append({"owner_id": "qa_thin_barrier", "kind": "qa_counterproof", "polygon_world": barrier})
	blocked_fixture["blocked_polygons"] = blockers
	var blocked_state := _bind_qa_fixture(blocked_fixture)
	_expect(bool(blocked_state.get("valid", false)), "thin-barrier fixture must be rebound with its own geometry fingerprint")
	if not bool(blocked_state.get("valid", false)):
		return

	var requested_distance := start.distance_to(finish)
	var requested_delta := requested_distance / PlazaMapNavigation.PLAYER_SPEED_WORLD_PER_SECOND
	var clean_result := PlazaMapNavigation.move_actor(navigation, start, tangent, requested_delta)
	var blocked_result := PlazaMapNavigation.move_actor(blocked_state, start, tangent, requested_delta)
	_expect(bool(clean_result.get("valid", false)), "clean swept-road control must execute")
	_expect(bool(blocked_result.get("valid", false)), "thin-barrier swept-road leg must execute")
	var clean_position: Vector2 = clean_result.get("actor_position", start)
	var blocked_position: Vector2 = blocked_result.get("actor_position", start)
	_expect(clean_position.distance_to(finish) <= 0.1, "control motion must traverse the full open segment")
	_expect(blocked_position.distance_to(finish) >= PlazaMapNavigation.ACTOR_COLLISION_SIZE.x * 0.5, "4px swept substeps must not tunnel the full actor through a 2px barrier")
	_expect(bool(blocked_result.get("blocked", false)), "thin barrier must set blocked=true")

	var removed_fixture := blocked_fixture.duplicate(true)
	var retained_blockers: Array = []
	for blocker_value in removed_fixture.get("blocked_polygons", []) as Array:
		if blocker_value is Dictionary and str((blocker_value as Dictionary).get("owner_id", "")) == "qa_thin_barrier":
			continue
		retained_blockers.append(blocker_value)
	removed_fixture["blocked_polygons"] = retained_blockers
	var removed_state := _bind_qa_fixture(removed_fixture)
	_expect(bool(removed_state.get("valid", false)), "blocker-removal control must rebind instead of mutating a live state")
	var removed_result := PlazaMapNavigation.move_actor(removed_state, start, tangent, requested_delta)
	var removed_position: Vector2 = removed_result.get("actor_position", start)
	_expect(removed_position.distance_to(finish) <= 0.1, "removing the exact blocker must restore the open-road control")
	_expect(blocked_position.distance_to(removed_position) >= 20.0, "blocker add/remove counterproof must materially change the swept result")


func _verify_axis_slide_counterproof(layout: Dictionary, navigation: Dictionary) -> void:
	var segment := _find_long_open_main_segment(layout, navigation)
	if segment.is_empty():
		return
	var start: Vector2 = (segment.get("start", Vector2.ZERO) as Vector2).lerp(segment.get("finish", Vector2.ZERO) as Vector2, 0.5)
	var frame_delta := 1.0 / 30.0
	var intended := PlazaMapNavigation.compute_intended_motion(Vector2(1.0, 1.0), frame_delta)
	if not PlazaMapNavigation.can_occupy(navigation, start + Vector2(0.0, intended.y), true):
		# Mirror the open slide direction without changing normalized speed.
		intended = PlazaMapNavigation.compute_intended_motion(Vector2(1.0, -1.0), frame_delta)
	var blocker_left := start.x + PlazaMapNavigation.ACTOR_COLLISION_SIZE.x * 0.5 + 1.0
	var blocker_rect := Rect2(
		Vector2(blocker_left, start.y - 48.0),
		Vector2(2.0, 96.0)
	)
	var slide_fixture := _qa_fixture_from_navigation(navigation)
	var blockers: Array = slide_fixture.get("blocked_polygons", [])
	blockers.append({
		"owner_id": "qa_axis_slide_wall",
		"kind": "qa_counterproof",
		"polygon_world": [
			blocker_rect.position,
			Vector2(blocker_rect.end.x, blocker_rect.position.y),
			blocker_rect.end,
			Vector2(blocker_rect.position.x, blocker_rect.end.y),
		],
	})
	slide_fixture["blocked_polygons"] = blockers
	var slide_state := _bind_qa_fixture(slide_fixture)
	_expect(bool(slide_state.get("valid", false)), "axis-slide fixture must be rebound with its authored wall")
	if not bool(slide_state.get("valid", false)):
		return
	_expect(PlazaMapNavigation.can_occupy(slide_state, start, true), "axis-slide control must start outside the synthetic wall")
	var input_direction := intended.normalized()
	var result := PlazaMapNavigation.move_actor(slide_state, start, input_direction, frame_delta)
	var applied: Vector2 = result.get("applied_delta", Vector2.ZERO)
	_expect(bool(result.get("valid", false)), "axis-slide counterproof must execute")
	_expect(bool(result.get("blocked", false)), "axis-slide wall must reject the direct diagonal")
	_expect(absf(applied.x) <= 0.01, "axis slide must suppress the blocked x component (applied=%s)" % applied)
	_expect(absf(applied.y) >= 1.0, "axis slide must preserve the open y component (applied=%s)" % applied)


func _verify_outside_walkable_rejection(navigation: Dictionary) -> void:
	var outside := _find_outside_walkable_position(navigation)
	_expect(outside != Vector2.INF, "fixed world must contain a body-safe point outside the walkable union")
	if outside == Vector2.INF:
		return
	_expect(not PlazaMapNavigation.can_occupy(navigation, outside, true), "outside sample must fail the full-body walkable test")
	var result := PlazaMapNavigation.move_actor(navigation, outside, Vector2.RIGHT, 1.0 / 60.0)
	_expect(not bool(result.get("valid", true)), "movement must fail closed when the actor starts outside walkable geometry")
	_expect(str(result.get("rejection_reason", "")) == "actor_outside_navigation_union", "outside-walkable rejection must remain diagnosable")


func _verify_minimap_2d(layout: Dictionary, fingerprint: String) -> void:
	var camera_world_rect := Rect2(Vector2(600.0, 300.0), Vector2(760.0, 750.0))
	var first := PlazaMapMinimapProjection2D.build(
		layout,
		fingerprint,
		MINIMAP_RECT,
		Vector2(900.0, 540.0),
		camera_world_rect
	)
	var second := PlazaMapMinimapProjection2D.build(
		layout,
		fingerprint,
		MINIMAP_RECT,
		Vector2(900.0, 720.0),
		camera_world_rect
	)
	_expect(bool(first.get("valid", false)), "2D minimap must build from the validated seed 5 fingerprint: %s" % first.get("rejection_reason", ""))
	_expect(bool(second.get("valid", false)), "2D minimap y-delta control must build")
	if not bool(first.get("valid", false)) or not bool(second.get("valid", false)):
		return
	var first_player := (first.get("player_marker", {}) as Dictionary).get("position", Vector2.INF) as Vector2
	var second_player := (second.get("player_marker", {}) as Dictionary).get("position", Vector2.INF) as Vector2
	_expect(is_equal_approx(first_player.x, second_player.x), "a y-only world move must not change minimap marker x")
	_expect(second_player.y > first_player.y + 1.0, "a y-only world move must materially change minimap marker y")
	var projection := first.get("projection", {}) as Dictionary
	var expected_y_delta := 180.0 * float(projection.get("projection_scale", 0.0))
	_expect(absf((second_player.y - first_player.y) - expected_y_delta) <= 0.01, "minimap y delta must be the exact PlazaMapProjection result")

	var buildings := _dictionary_array(layout.get("building_specs", []))
	var markers := _dictionary_array(first.get("building_markers", []))
	_expect(markers.size() == buildings.size(), "2D minimap must project every selected building")
	var distinct_authored_y_pair_found := false
	for index in range(mini(markers.size(), buildings.size())):
		var spec := buildings[index]
		var marker := markers[index]
		var authored_world: Vector2 = spec.get("pivot_pos", Vector2.INF)
		var marker_world: Vector2 = marker.get("world_position", Vector2.INF)
		var marker_screen: Vector2 = marker.get("position", Vector2.INF)
		var expected_screen := PlazaMapProjection.world_to_screen(authored_world, projection)
		_expect(marker_world.is_equal_approx(authored_world), "%s marker must preserve its exact authored world position" % str(spec.get("type", "")))
		_expect(marker_screen.is_equal_approx(expected_screen), "%s marker must equal the exact two-axis PlazaMapProjection result" % str(spec.get("type", "")))
		var expected_color := PlazaMapMinimapProjection2D.resolve_marker_color(spec)
		_expect((marker.get("marker_color", Color.TRANSPARENT) as Color).is_equal_approx(expected_color), "%s minimap marker must consume its spec palette" % str(spec.get("type", "")))
		var source := "spec" if spec.get("marker_color", null) is Color else "legacy_fallback"
		_expect(str(marker.get("marker_color_source", "")) == source, "%s minimap color source must be explicit" % str(spec.get("type", "")))
		for other_index in range(index + 1, mini(markers.size(), buildings.size())):
			var other_world: Vector2 = buildings[other_index].get("pivot_pos", Vector2.INF)
			var other_screen: Vector2 = markers[other_index].get("position", Vector2.INF)
			if absf(other_world.y - authored_world.y) > 1.0:
				distinct_authored_y_pair_found = distinct_authored_y_pair_found or absf(other_screen.y - marker_screen.y) > 0.1
	_expect(distinct_authored_y_pair_found, "two buildings with distinct authored world y values must remain vertically distinct on the minimap")

	var exit_marker := first.get("exit_marker", {}) as Dictionary
	var expected_exit_world: Vector2 = (layout.get("exit_zone", Rect2()) as Rect2).get_center()
	var expected_exit_screen := PlazaMapProjection.world_to_screen(expected_exit_world, projection)
	_expect((exit_marker.get("world_position", Vector2.INF) as Vector2).is_equal_approx(expected_exit_world), "exit marker must preserve the exact exit-zone center")
	_expect((exit_marker.get("position", Vector2.INF) as Vector2).is_equal_approx(expected_exit_screen), "exit marker must equal the exact two-axis projection")

	var projected_camera := PlazaMapProjection.world_rect_to_screen(camera_world_rect, projection)
	_expect((first.get("camera_world_rect", Rect2()) as Rect2).is_equal_approx(camera_world_rect), "minimap must preserve the camera world rect on both axes")
	_expect((first.get("camera_screen_rect", Rect2()) as Rect2).is_equal_approx(projected_camera), "minimap camera rect position and size must exactly project on both axes")

	var authored_color := Color(0.13, 0.47, 0.91, 0.77)
	_expect(PlazaMapMinimapProjection2D.resolve_marker_color({"type": "bank", "marker_color": authored_color}).is_equal_approx(authored_color), "authored marker_color must win over every legacy palette entry")
	var legacy_color := PlazaMapMinimapProjection2D.resolve_marker_color({"type": "bank"})
	_expect(not legacy_color.is_equal_approx(authored_color), "legacy building palette must be fallback-only")

	var stale := PlazaMapMinimapProjection2D.build(layout, "f".repeat(64), MINIMAP_RECT, SPAWN_ANCHOR)
	_expect(not bool(stale.get("valid", true)), "2D minimap must reject a stale layout fingerprint")


func _verify_minimap_all_building_types() -> void:
	# The loader's seven-entry mode is fixture authority only. Each generated
	# layout remains a legal four-building public roster (bank + three optional).
	var full_specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, true, false)
	_expect(full_specs.size() == 7, "all-type minimap fixture source must expose seven manifests")
	if full_specs.size() != 7:
		return
	var roster_cases: Array[Dictionary] = [
		{"seed": 6, "types": ["bank", "shop", "gacha", "academy"]},
		{"seed": 7, "types": ["bank", "lingpet_store", "blacksmith", "tavern"]},
	]
	var covered_types := {}
	var flatten_counterproof_done := false
	var flatten_counterproof_violations: Array[String] = []
	for case in roster_cases:
		var requested_types: Array = case.get("types", [])
		var roster := _specs_for_types(full_specs, requested_types)
		_expect(roster.size() == requested_types.size(), "all-type roster fixture must resolve every requested manifest: %s" % [requested_types])
		if roster.size() != requested_types.size():
			continue
		var map_seed := int(case.get("seed", 0))
		var candidate := PlazaMapLayoutGenerator.generate(
			1,
			map_seed,
			WORLD_SIZE,
			roster,
			SPAWN_ANCHOR,
			EXIT_ZONE
		)
		var validation := candidate.get("validation", {}) as Dictionary
		_expect(bool(validation.get("valid", false)), "all-type minimap seed %d roster %s must remain a valid public 2..5 layout: %s" % [map_seed, requested_types, validation.get("violations", [])])
		if not bool(validation.get("valid", false)):
			continue
		var fingerprint := str(candidate.get("fingerprint", ""))
		var camera_world_rect := Rect2(
			Vector2(420.0 + map_seed * 7.0, 250.0 + map_seed * 5.0),
			Vector2(820.0, 690.0)
		)
		var snapshot := PlazaMapMinimapProjection2D.build(
			candidate,
			fingerprint,
			MINIMAP_RECT,
			Vector2(780.0, 620.0),
			camera_world_rect
		)
		_expect(bool(snapshot.get("valid", false)), "all-type minimap seed %d must build: %s" % [map_seed, snapshot.get("rejection_reason", "")])
		if not bool(snapshot.get("valid", false)):
			continue
		var exact_violations := _collect_minimap_exact_violations(candidate, snapshot, camera_world_rect)
		_expect(exact_violations.is_empty(), "all-type minimap seed %d exact projection violations: %s" % [map_seed, exact_violations])
		for building in _dictionary_array(candidate.get("building_specs", [])):
			covered_types[str(building.get("type", ""))] = true

		if requested_types.has("gacha") and requested_types.has("academy"):
			var flattened := snapshot.duplicate(true)
			var flattened_markers := _dictionary_array(flattened.get("building_markers", []))
			for marker in flattened_markers:
				if ["gacha", "academy"].has(str(marker.get("type", ""))):
					var flattened_position: Vector2 = marker.get("position", Vector2.ZERO)
					flattened_position.y = MINIMAP_RECT.position.y - 123.0
					marker["position"] = flattened_position
			flattened["building_markers"] = flattened_markers
			var flattened_violations := _collect_minimap_exact_violations(candidate, flattened, camera_world_rect)
			_expect(flattened_violations.has("marker_screen:gacha"), "gacha fixed-row branch must turn exact projection RED")
			_expect(flattened_violations.has("marker_screen:academy"), "academy fixed-row branch must turn exact projection RED")
			flatten_counterproof_violations = flattened_violations
			flatten_counterproof_done = true

	var actual_types: Array[String] = []
	for building_type in covered_types.keys():
		actual_types.append(str(building_type))
	actual_types.sort()
	var expected_types: Array[String] = []
	for building_type_value in PlazaMapLayoutGenerator.KNOWN_BUILDING_TYPES:
		expected_types.append(str(building_type_value))
	expected_types.sort()
	_expect(actual_types == expected_types, "valid 2..5 roster union must cover exactly all seven minimap building types (actual=%s expected=%s)" % [actual_types, expected_types])
	_expect(flatten_counterproof_done, "all-type minimap gate must execute the gacha + academy fixed-row counterproof")
	print("plaza_r2b_navigation_minimap_smoke: minimap_covered_types=%s fixed_row_red=%s" % [actual_types, flatten_counterproof_violations])


func _collect_minimap_exact_violations(
	layout: Dictionary,
	snapshot: Dictionary,
	expected_camera_world_rect: Rect2
) -> Array[String]:
	var violations: Array[String] = []
	if not bool(snapshot.get("valid", false)):
		return ["snapshot_invalid"]
	var projection := snapshot.get("projection", {}) as Dictionary
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return ["projection_invalid"]
	var buildings := _dictionary_array(layout.get("building_specs", []))
	var markers := _dictionary_array(snapshot.get("building_markers", []))
	var marker_by_type := {}
	for marker in markers:
		var marker_type := str(marker.get("type", ""))
		if marker_type == "" or marker_by_type.has(marker_type):
			violations.append("marker_duplicate:%s" % marker_type)
		marker_by_type[marker_type] = marker
	if markers.size() != buildings.size():
		violations.append("marker_count")
	for building in buildings:
		var building_type := str(building.get("type", ""))
		if not marker_by_type.has(building_type):
			violations.append("marker_missing:%s" % building_type)
			continue
		var marker := marker_by_type.get(building_type, {}) as Dictionary
		var authored_world: Vector2 = building.get("pivot_pos", Vector2.INF)
		var marker_world: Vector2 = marker.get("world_position", Vector2.INF)
		var marker_screen: Vector2 = marker.get("position", Vector2.INF)
		if not marker_world.is_equal_approx(authored_world):
			violations.append("marker_world:%s" % building_type)
		if not marker_screen.is_equal_approx(PlazaMapProjection.world_to_screen(authored_world, projection)):
			violations.append("marker_screen:%s" % building_type)
		var expected_color := PlazaMapMinimapProjection2D.resolve_marker_color(building)
		var marker_color_value: Variant = marker.get("marker_color", null)
		if not (marker_color_value is Color) or not (marker_color_value as Color).is_equal_approx(expected_color):
			violations.append("marker_color:%s" % building_type)
		var expected_source := "spec" if building.get("marker_color", null) is Color else "legacy_fallback"
		if str(marker.get("marker_color_source", "")) != expected_source:
			violations.append("marker_color_source:%s" % building_type)
	for left_index in range(buildings.size()):
		for right_index in range(left_index + 1, buildings.size()):
			var left := buildings[left_index]
			var right := buildings[right_index]
			var left_world: Vector2 = left.get("pivot_pos", Vector2.INF)
			var right_world: Vector2 = right.get("pivot_pos", Vector2.INF)
			if is_equal_approx(left_world.y, right_world.y):
				continue
			var left_marker := marker_by_type.get(str(left.get("type", "")), {}) as Dictionary
			var right_marker := marker_by_type.get(str(right.get("type", "")), {}) as Dictionary
			var left_screen: Vector2 = left_marker.get("position", Vector2.INF)
			var right_screen: Vector2 = right_marker.get("position", Vector2.INF)
			if is_equal_approx(left_screen.y, right_screen.y):
				violations.append("marker_y_flattened:%s:%s" % [str(left.get("type", "")), str(right.get("type", ""))])

	var exit_marker := snapshot.get("exit_marker", {}) as Dictionary
	var expected_exit_world: Vector2 = (layout.get("exit_zone", Rect2()) as Rect2).get_center()
	if not (exit_marker.get("world_position", Vector2.INF) as Vector2).is_equal_approx(expected_exit_world):
		violations.append("exit_world")
	if not (exit_marker.get("position", Vector2.INF) as Vector2).is_equal_approx(PlazaMapProjection.world_to_screen(expected_exit_world, projection)):
		violations.append("exit_screen")
	if not (snapshot.get("camera_world_rect", Rect2()) as Rect2).is_equal_approx(expected_camera_world_rect):
		violations.append("camera_world_rect")
	if not (snapshot.get("camera_screen_rect", Rect2()) as Rect2).is_equal_approx(PlazaMapProjection.world_rect_to_screen(expected_camera_world_rect, projection)):
		violations.append("camera_screen_rect")
	return violations


func _specs_for_types(full_specs: Array[Dictionary], requested_types: Array) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for requested_type_value in requested_types:
		var requested_type := str(requested_type_value)
		for spec in full_specs:
			if str(spec.get("type", "")) == requested_type:
				roster.append(spec.duplicate(true))
				break
	return roster


func _find_real_portal_only_target(layout: Dictionary, navigation: Dictionary) -> Dictionary:
	var buildings_by_type := {}
	for building in _dictionary_array(layout.get("building_specs", [])):
		buildings_by_type[str(building.get("type", ""))] = building
	var edges := _dictionary_array((layout.get("road_graph", {}) as Dictionary).get("edges", []))
	for portal in _dictionary_array(layout.get("interaction_portals", [])):
		var building_type := str(portal.get("building_type", ""))
		var building := buildings_by_type.get(building_type, {}) as Dictionary
		var edge := _find_dictionary_by_id(edges, str(portal.get("approach_edge_id", "")))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() >= 2:
			var start := polyline[polyline.size() - 2]
			var finish := polyline[polyline.size() - 1]
			for step in range(101):
				var candidate := start.lerp(finish, float(step) / 100.0)
				if PlazaMapNavigation.can_occupy(navigation, candidate, true) and not PlazaMapNavigation.can_occupy(navigation, candidate, false):
					return {"position": candidate, "building_type": building_type}
		var polygon := _vector2_array(portal.get("polygon_world", []))
		var bounds := _polygon_aabb(polygon)
		var best := Vector2.INF
		var best_score := INF
		var reference: Vector2 = building.get("entrance_world_pos", bounds.get_center())
		var x := bounds.position.x
		while x <= bounds.end.x:
			var y := bounds.position.y
			while y <= bounds.end.y:
				var candidate := Vector2(x, y)
				if PlazaMapNavigation.can_occupy(navigation, candidate, true) and not PlazaMapNavigation.can_occupy(navigation, candidate, false):
					var score := candidate.distance_squared_to(reference)
					if score < best_score:
						best = candidate
						best_score = score
				y += 2.0
			x += 2.0
		if best != Vector2.INF:
			return {"position": best, "building_type": building_type}
	return {}


func _route_waypoints_to_portal(layout: Dictionary, building_type: String, target: Vector2) -> Array[Vector2]:
	var road := layout.get("road_graph", {}) as Dictionary
	var edges := _dictionary_array(road.get("edges", []))
	var building := {}
	for candidate in _dictionary_array(layout.get("building_specs", [])):
		if str(candidate.get("type", "")) == building_type:
			building = candidate
			break
	if building.is_empty():
		return []
	var approach := _find_dictionary_by_id(edges, str(building.get("approach_edge_id", "")))
	if approach.is_empty():
		return []
	var spawn_node := str(road.get("spawn_node_id", ""))
	var approach_from := str(approach.get("from", ""))
	var main_edge_path := _find_edge_path(edges, spawn_node, approach_from, ["main"])
	if main_edge_path.is_empty() and spawn_node != approach_from:
		return []
	var waypoints: Array[Vector2] = []
	var current_node := spawn_node
	for edge in main_edge_path:
		var oriented := _oriented_polyline(edge, current_node)
		for index in range(1, oriented.size()):
			waypoints.append(oriented[index])
		current_node = str(edge.get("to", "")) if str(edge.get("from", "")) == current_node else str(edge.get("from", ""))
	var approach_polyline := _oriented_polyline(approach, approach_from)
	for index in range(1, maxi(1, approach_polyline.size() - 1)):
		waypoints.append(approach_polyline[index])
	waypoints.append(target)
	return waypoints


func _find_edge_path(
	edges: Array[Dictionary],
	start_node: String,
	target_node: String,
	allowed_kinds: Array[String]
) -> Array[Dictionary]:
	if start_node == target_node:
		return []
	var queue: Array[String] = [start_node]
	var seen := {start_node: true}
	var previous_node := {}
	var previous_edge := {}
	while not queue.is_empty():
		var node: String = queue.pop_front()
		for edge in edges:
			if not allowed_kinds.has(str(edge.get("kind", ""))):
				continue
			var from_id := str(edge.get("from", ""))
			var to_id := str(edge.get("to", ""))
			var next := ""
			if from_id == node:
				next = to_id
			elif to_id == node:
				next = from_id
			if next == "" or seen.has(next):
				continue
			seen[next] = true
			previous_node[next] = node
			previous_edge[next] = edge
			if next == target_node:
				queue.clear()
				break
			queue.append(next)
	if not seen.has(target_node):
		return []
	var reverse_path: Array[Dictionary] = []
	var cursor := target_node
	while cursor != start_node:
		reverse_path.append(previous_edge.get(cursor, {}) as Dictionary)
		cursor = str(previous_node.get(cursor, ""))
	reverse_path.reverse()
	return reverse_path


func _oriented_polyline(edge: Dictionary, from_node: String) -> Array[Vector2]:
	var polyline := _vector2_array(edge.get("polyline_world", []))
	if str(edge.get("from", "")) != from_node:
		polyline.reverse()
	return polyline


func _find_long_open_main_segment(layout: Dictionary, navigation: Dictionary) -> Dictionary:
	var edges := _dictionary_array((layout.get("road_graph", {}) as Dictionary).get("edges", []))
	for edge in edges:
		if str(edge.get("kind", "")) != "main":
			continue
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for index in range(polyline.size() - 1):
			var segment_start := polyline[index]
			var segment_finish := polyline[index + 1]
			var length := segment_start.distance_to(segment_finish)
			if length < 150.0:
				continue
			var tangent := segment_start.direction_to(segment_finish)
			var midpoint := segment_start.lerp(segment_finish, 0.5)
			var start := midpoint - tangent * 60.0
			var finish := midpoint + tangent * 60.0
			if PlazaMapNavigation.can_occupy(navigation, start, true) and PlazaMapNavigation.can_occupy(navigation, finish, true):
				return {"start": start, "finish": finish}
	return {}


func _find_outside_walkable_position(navigation: Dictionary) -> Vector2:
	var half := PlazaMapNavigation.ACTOR_COLLISION_SIZE * 0.5
	var y := half.y + 8.0
	while y <= WORLD_SIZE.y - half.y - 8.0:
		var x := half.x + 8.0
		while x <= WORLD_SIZE.x - half.x - 8.0:
			var candidate := Vector2(x, y)
			if not PlazaMapNavigation.can_occupy(navigation, candidate, true):
				return candidate
			x += 80.0
		y += 80.0
	return Vector2.INF


func _qa_fixture_from_navigation(navigation: Dictionary) -> Dictionary:
	return {
		"schema_version": PlazaMapNavigation.QA_FIXTURE_SCHEMA_VERSION,
		"world_size": WORLD_SIZE,
		"walkable_corridor_polygons": (navigation.get("walkable_corridor_polygons", []) as Array).duplicate(true),
		"interaction_portals": (navigation.get("interaction_portals", []) as Array).duplicate(true),
		"blocked_polygons": (navigation.get("blocked_polygons", []) as Array).duplicate(true),
	}


func _bind_qa_fixture(fixture: Dictionary) -> Dictionary:
	var fingerprint := PlazaMapNavigation.build_qa_geometry_fixture_fingerprint(fixture)
	if fingerprint == "":
		return {"valid": false, "rejection_reason": "qa_fixture_fingerprint_build_failed"}
	return PlazaMapNavigation.bind_qa_geometry_fixture(fixture, fingerprint)


func _legacy_nine_samples_fit(actor_position: Vector2, walkable_rects: Array[Rect2]) -> bool:
	var half_size := PlazaMapNavigation.ACTOR_COLLISION_SIZE * 0.5
	var inner := Vector2(half_size.x - 0.25, half_size.y - 0.25)
	var samples: Array[Vector2] = [
		actor_position,
		actor_position + Vector2(-inner.x, -inner.y),
		actor_position + Vector2(inner.x, -inner.y),
		actor_position + Vector2(inner.x, inner.y),
		actor_position + Vector2(-inner.x, inner.y),
		actor_position + Vector2(0.0, -inner.y),
		actor_position + Vector2(inner.x, 0.0),
		actor_position + Vector2(0.0, inner.y),
		actor_position + Vector2(-inner.x, 0.0),
	]
	for sample in samples:
		var covered := false
		for rect in walkable_rects:
			if sample.x >= rect.position.x and sample.y >= rect.position.y and sample.x <= rect.end.x and sample.y <= rect.end.y:
				covered = true
				break
		if not covered:
			return false
	return true


func _rect_polygon(rect: Rect2) -> Array[Vector2]:
	return [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]


func _find_dictionary_by_id(values: Array[Dictionary], value_id: String) -> Dictionary:
	for value in values:
		if str(value.get("id", "")) == value_id:
			return value
	return {}


func _polygon_aabb(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	if not (value is Array):
		return typed
	for item in value as Array:
		if item is Dictionary:
			typed.append(item as Dictionary)
	return typed


func _vector2_array(value: Variant) -> Array[Vector2]:
	var typed: Array[Vector2] = []
	if value is PackedVector2Array:
		for point in value as PackedVector2Array:
			typed.append(point)
		return typed
	if not (value is Array):
		return typed
	for item in value as Array:
		if not (item is Vector2):
			return []
		typed.append(item as Vector2)
	return typed


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
