extends RefCounted

# R2-B candidate-only navigation owner. It consumes only a fully validated
# PlazaMapLayoutGenerator snapshot; production PlazaScene remains disconnected
# until navigation, retained rendering, and the 2D minimap can move atomically.

const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")

const SCHEMA_VERSION := "plaza_map_navigation_r2b_v1"
const MAP_WORLD_SIZE := Vector2(2400.0, 1500.0)
const ACTOR_COLLISION_SIZE := PlazaPlayerController.PLAYER_COLLISION_SIZE
const PLAYER_SPEED_WORLD_PER_SECOND := PlazaPlayerController.PLAYER_SPEED_PER_FRAME_60 * 60.0
const MAX_SWEEP_STEP_WORLD := 4.0
const GEOMETRY_EPSILON := 0.01
const WALKABLE_UNCOVERED_AREA_EPSILON := 0.05
const SHA256_HEX_LENGTH := 64
const QA_FIXTURE_SCHEMA_VERSION := "plaza_map_navigation_qa_fixture_v1"


static func bind_layout(layout: Dictionary, expected_layout_fingerprint: String) -> Dictionary:
	var rejection_reason := _validate_bind_contract(layout, expected_layout_fingerprint)
	if rejection_reason != "":
		return _rejected_state(rejection_reason)

	var corridors := _copy_polygon_manifest(
		layout.get("walkable_corridor_polygons", []),
		["id", "edge_id", "edge_kind"]
	)
	var portals := _copy_polygon_manifest(
		layout.get("interaction_portals", []),
		["id", "building_type", "plot_id", "approach_edge_id"]
	)
	var blockers := _copy_polygon_manifest(
		layout.get("blocked_polygons", []),
		["owner_id", "kind"]
	)
	if corridors.is_empty():
		return _rejected_state("walkable_corridors_empty")

	return _build_bound_state(
		"validated_layout",
		expected_layout_fingerprint,
		corridors,
		portals,
		blockers
	)


# Explicitly test-only binding path. It lets counterproofs author a tiny
# geometry fixture without weakening bind_layout(): callers must hash and bind
# the complete fixture anew, and the resulting state is still mutation-sealed.
static func build_qa_geometry_fixture_fingerprint(fixture: Dictionary) -> String:
	if str(fixture.get("schema_version", "")) != QA_FIXTURE_SCHEMA_VERSION:
		return ""
	var world_value: Variant = fixture.get("world_size", null)
	if not (world_value is Vector2) or not (world_value as Vector2).is_equal_approx(MAP_WORLD_SIZE):
		return ""
	for key_value in ["walkable_corridor_polygons", "interaction_portals", "blocked_polygons"]:
		if not _is_polygon_manifest(fixture.get(str(key_value), null)):
			return ""
	var corridors := _copy_polygon_manifest(
		fixture.get("walkable_corridor_polygons", []),
		["id", "edge_id", "edge_kind"]
	)
	if corridors.is_empty():
		return ""
	var portals := _copy_polygon_manifest(
		fixture.get("interaction_portals", []),
		["id", "building_type", "plot_id", "approach_edge_id"]
	)
	var blockers := _copy_polygon_manifest(
		fixture.get("blocked_polygons", []),
		["owner_id", "kind"]
	)
	var geometry_digest := _compute_geometry_digest(MAP_WORLD_SIZE, corridors, portals, blockers)
	return ("%s\n%s" % [QA_FIXTURE_SCHEMA_VERSION, geometry_digest]).sha256_text()


static func bind_qa_geometry_fixture(
	fixture: Dictionary,
	expected_fixture_fingerprint: String
) -> Dictionary:
	if not _is_sha256_hex(expected_fixture_fingerprint):
		return _rejected_state("invalid_qa_fixture_fingerprint")
	var rebuilt_fingerprint := build_qa_geometry_fixture_fingerprint(fixture)
	if rebuilt_fingerprint == "" or rebuilt_fingerprint != expected_fixture_fingerprint:
		return _rejected_state("qa_fixture_fingerprint_mismatch")
	var corridors := _copy_polygon_manifest(
		fixture.get("walkable_corridor_polygons", []),
		["id", "edge_id", "edge_kind"]
	)
	var portals := _copy_polygon_manifest(
		fixture.get("interaction_portals", []),
		["id", "building_type", "plot_id", "approach_edge_id"]
	)
	var blockers := _copy_polygon_manifest(
		fixture.get("blocked_polygons", []),
		["owner_id", "kind"]
	)
	return _build_bound_state(
		"qa_geometry_fixture",
		expected_fixture_fingerprint,
		corridors,
		portals,
		blockers
	)


static func _build_bound_state(
	binding_kind: String,
	source_fingerprint: String,
	corridors: Array[Dictionary],
	portals: Array[Dictionary],
	blockers: Array[Dictionary]
) -> Dictionary:
	var state := {
		"valid": true,
		"schema_version": SCHEMA_VERSION,
		"rejection_reason": "",
		"binding_kind": binding_kind,
		"layout_fingerprint": source_fingerprint,
		"world_size": MAP_WORLD_SIZE,
		"actor_collision_size": ACTOR_COLLISION_SIZE,
		"speed_world_per_second": PLAYER_SPEED_WORLD_PER_SECOND,
		"walkable_corridor_polygons": corridors,
		"interaction_portals": portals,
		"blocked_polygons": blockers,
	}
	state["geometry_digest"] = _compute_geometry_digest(MAP_WORLD_SIZE, corridors, portals, blockers)
	return state


static func compute_intended_motion(input_direction: Vector2, delta: float) -> Vector2:
	if not input_direction.is_finite() or not is_finite(delta) or delta <= 0.0:
		return Vector2.ZERO
	var direction := input_direction
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction * PLAYER_SPEED_WORLD_PER_SECOND * delta


static func move_actor(
	navigation_state: Dictionary,
	actor_position: Vector2,
	input_direction: Vector2,
	delta: float
) -> Dictionary:
	if not _is_valid_navigation_state(navigation_state):
		return _move_rejection(actor_position, "invalid_navigation_state")
	if not actor_position.is_finite():
		return _move_rejection(actor_position, "invalid_actor_position")
	if not input_direction.is_finite() or not is_finite(delta) or delta < 0.0:
		return _move_rejection(actor_position, "invalid_motion_input")
	if not _can_occupy_bound_state(navigation_state, actor_position, true):
		return _move_rejection(actor_position, "actor_outside_navigation_union")

	var intended_motion := compute_intended_motion(input_direction, delta)
	if intended_motion == Vector2.ZERO:
		return {
			"valid": true,
			"rejection_reason": "",
			"actor_position": actor_position,
			"requested_delta": intended_motion,
			"applied_delta": Vector2.ZERO,
			"blocked": false,
			"sweep_substeps": 0,
		}

	var longest_axis := maxf(absf(intended_motion.x), absf(intended_motion.y))
	var substep_count := maxi(1, ceili(longest_axis / MAX_SWEEP_STEP_WORLD))
	var substep := intended_motion / float(substep_count)
	var current := actor_position
	var blocked := false
	for _substep_index in range(substep_count):
		var direct_candidate := current + substep
		if _can_occupy_bound_state(navigation_state, direct_candidate, true):
			current = direct_candidate
			continue

		blocked = true
		var moved_on_axis := false
		if not is_zero_approx(substep.x):
			var x_candidate := current + Vector2(substep.x, 0.0)
			if _can_occupy_bound_state(navigation_state, x_candidate, true):
				current = x_candidate
				moved_on_axis = true
		if not is_zero_approx(substep.y):
			var y_candidate := current + Vector2(0.0, substep.y)
			if _can_occupy_bound_state(navigation_state, y_candidate, true):
				current = y_candidate
				moved_on_axis = true
		if not moved_on_axis:
			continue

	return {
		"valid": true,
		"rejection_reason": "",
		"actor_position": current,
		"requested_delta": intended_motion,
		"applied_delta": current - actor_position,
		"blocked": blocked or not (current - actor_position).is_equal_approx(intended_motion),
		"sweep_substeps": substep_count,
	}


static func can_occupy(
	navigation_state: Dictionary,
	actor_position: Vector2,
	include_interaction_portals: bool = true
) -> bool:
	if not _is_valid_navigation_state(navigation_state) or not actor_position.is_finite():
		return false
	return _can_occupy_bound_state(navigation_state, actor_position, include_interaction_portals)


static func is_bound_state_valid(navigation_state: Dictionary) -> bool:
	# One-time validation hook for compile-style consumers
	# (plaza_map_navigation_compiled.gd). Hot paths must never call this per
	# tick; the full geometry re-digest here is exactly the GRT-032-family cost
	# the compiled owner exists to remove.
	return _is_valid_navigation_state(navigation_state)


static func _can_occupy_bound_state(
	navigation_state: Dictionary,
	actor_position: Vector2,
	include_interaction_portals: bool
) -> bool:
	var world_size: Vector2 = navigation_state.get("world_size", Vector2.ZERO)
	var actor_rect := Rect2(actor_position - ACTOR_COLLISION_SIZE * 0.5, ACTOR_COLLISION_SIZE)
	if (
		actor_rect.position.x < -GEOMETRY_EPSILON
		or actor_rect.position.y < -GEOMETRY_EPSILON
		or actor_rect.end.x > world_size.x + GEOMETRY_EPSILON
		or actor_rect.end.y > world_size.y + GEOMETRY_EPSILON
	):
		return false

	var allowed_polygons: Array[PackedVector2Array] = []
	for corridor in _dictionary_array(navigation_state.get("walkable_corridor_polygons", [])):
		allowed_polygons.append(_packed_polygon(corridor.get("polygon_world", [])))
	if include_interaction_portals:
		for portal in _dictionary_array(navigation_state.get("interaction_portals", [])):
			allowed_polygons.append(_packed_polygon(portal.get("polygon_world", [])))
	if allowed_polygons.is_empty():
		return false
	if _actor_rect_uncovered_area(actor_rect, allowed_polygons) > WALKABLE_UNCOVERED_AREA_EPSILON:
		return false

	for blocker in _dictionary_array(navigation_state.get("blocked_polygons", [])):
		var blocker_polygon := _packed_polygon(blocker.get("polygon_world", []))
		if blocker_polygon.size() >= 3 and _rect_touches_polygon(actor_rect, blocker_polygon):
			return false
	return true


static func get_actor_collision_rect(actor_position: Vector2) -> Rect2:
	return Rect2(actor_position - ACTOR_COLLISION_SIZE * 0.5, ACTOR_COLLISION_SIZE)


static func _validate_bind_contract(layout: Dictionary, expected_fingerprint: String) -> String:
	if not _is_sha256_hex(expected_fingerprint):
		return "invalid_expected_fingerprint"
	var validation := PlazaMapLayoutGenerator.validate_layout(layout)
	if not bool(validation.get("valid", false)):
		return "layout_validation_failed"
	var world_value: Variant = layout.get("world_size", null)
	if not (world_value is Vector2) or not (world_value as Vector2).is_equal_approx(MAP_WORLD_SIZE):
		return "world_size_contract_mismatch"
	var stored_value: Variant = layout.get("fingerprint", null)
	if not (stored_value is String) or not _is_sha256_hex(stored_value as String):
		return "invalid_layout_fingerprint"
	var stored_fingerprint := stored_value as String
	if stored_fingerprint != expected_fingerprint:
		return "expected_fingerprint_mismatch"
	var rebuilt_fingerprint := PlazaMapLayoutGenerator.build_fingerprint(layout)
	if rebuilt_fingerprint != stored_fingerprint:
		return "layout_fingerprint_mismatch"
	return ""


static func _is_valid_navigation_state(state: Dictionary) -> bool:
	if not bool(state.get("valid", false)):
		return false
	if str(state.get("schema_version", "")) != SCHEMA_VERSION:
		return false
	if not _is_sha256_hex(str(state.get("layout_fingerprint", ""))):
		return false
	if not [
		"validated_layout",
		"validated_r3_layout_with_walkable_hubs",
		"qa_geometry_fixture",
	].has(str(state.get("binding_kind", ""))):
		return false
	var world_value: Variant = state.get("world_size", null)
	if not (world_value is Vector2) or not (world_value as Vector2).is_equal_approx(MAP_WORLD_SIZE):
		return false
	var actor_size_value: Variant = state.get("actor_collision_size", null)
	if not (actor_size_value is Vector2) or not (actor_size_value as Vector2).is_equal_approx(ACTOR_COLLISION_SIZE):
		return false
	var speed_value: Variant = state.get("speed_world_per_second", null)
	var speed_type := typeof(speed_value)
	if not (speed_type == TYPE_FLOAT or speed_type == TYPE_INT) or not is_equal_approx(float(speed_value), PLAYER_SPEED_WORLD_PER_SECOND):
		return false
	for key_value in ["walkable_corridor_polygons", "interaction_portals", "blocked_polygons"]:
		var value: Variant = state.get(str(key_value), null)
		if not _is_polygon_manifest(value):
			return false
	var digest_value: Variant = state.get("geometry_digest", null)
	if not (digest_value is String) or not _is_sha256_hex(digest_value as String):
		return false
	var rebuilt_digest := _compute_geometry_digest(
		world_value as Vector2,
		_dictionary_array(state.get("walkable_corridor_polygons", [])),
		_dictionary_array(state.get("interaction_portals", [])),
		_dictionary_array(state.get("blocked_polygons", []))
	)
	return rebuilt_digest == (digest_value as String)


static func _actor_rect_uncovered_area(
	actor_rect: Rect2,
	allowed_polygons: Array[PackedVector2Array]
) -> float:
	# Successive subtraction is exactly A - (B union C ...), while avoiding an
	# order-sensitive global polygon merge. Any positive-area fragment left from
	# the actor rectangle is non-walkable body area.
	var uncovered: Array[PackedVector2Array] = [PackedVector2Array([
		actor_rect.position,
		Vector2(actor_rect.end.x, actor_rect.position.y),
		actor_rect.end,
		Vector2(actor_rect.position.x, actor_rect.end.y),
	])]
	for allowed_polygon in allowed_polygons:
		var next_uncovered: Array[PackedVector2Array] = []
		for fragment in uncovered:
			var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(fragment, allowed_polygon)
			for remainder in clipped:
				if _polygon_area_abs(remainder) > WALKABLE_UNCOVERED_AREA_EPSILON:
					next_uncovered.append(remainder)
		uncovered = next_uncovered
		if uncovered.is_empty():
			return 0.0
	var uncovered_area := 0.0
	for fragment in uncovered:
		uncovered_area += _polygon_area_abs(fragment)
	return uncovered_area


static func _point_in_or_on_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for index in range(polygon.size()):
		var start := polygon[index]
		var finish := polygon[(index + 1) % polygon.size()]
		if _point_segment_distance_squared(point, start, finish) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			return true
	return false


static func _rect_touches_polygon(rect: Rect2, polygon: PackedVector2Array) -> bool:
	var rect_polygon := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	for point in rect_polygon:
		if _point_in_or_on_polygon(point, polygon):
			return true
	for point in polygon:
		if _rect_contains_inclusive(rect, point):
			return true
	for rect_index in range(rect_polygon.size()):
		var rect_start := rect_polygon[rect_index]
		var rect_finish := rect_polygon[(rect_index + 1) % rect_polygon.size()]
		for polygon_index in range(polygon.size()):
			var polygon_start := polygon[polygon_index]
			var polygon_finish := polygon[(polygon_index + 1) % polygon.size()]
			if _segments_touch(rect_start, rect_finish, polygon_start, polygon_finish):
				return true
	return false


static func _segments_touch(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var intersection: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
	if intersection != null:
		return true
	return (
		_point_segment_distance_squared(a, c, d) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
		or _point_segment_distance_squared(b, c, d) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
		or _point_segment_distance_squared(c, a, b) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
		or _point_segment_distance_squared(d, a, b) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
	)


static func _point_segment_distance_squared(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_squared_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(start + segment * ratio)


static func _rect_contains_inclusive(rect: Rect2, point: Vector2) -> bool:
	return (
		point.x >= rect.position.x - GEOMETRY_EPSILON
		and point.y >= rect.position.y - GEOMETRY_EPSILON
		and point.x <= rect.end.x + GEOMETRY_EPSILON
		and point.y <= rect.end.y + GEOMETRY_EPSILON
	)


static func _compute_geometry_digest(
	world_size: Vector2,
	corridors: Array[Dictionary],
	portals: Array[Dictionary],
	blockers: Array[Dictionary]
) -> String:
	var parts: Array[String] = [
		"schema=%s" % SCHEMA_VERSION,
		"world=%s" % _vector_token(world_size),
		"actor=%s" % _vector_token(ACTOR_COLLISION_SIZE),
		"speed=%.6f" % PLAYER_SPEED_WORLD_PER_SECOND,
	]
	for corridor in corridors:
		parts.append("corridor:%s:%s:%s" % [
			str(corridor.get("id", "")),
			str(corridor.get("edge_id", "")),
			str(corridor.get("edge_kind", "")),
		])
		for point in _vector2_array(corridor.get("polygon_world", [])):
			parts.append("corridor_point:%s" % _vector_token(point))
	for portal in portals:
		parts.append("portal:%s:%s:%s:%s" % [
			str(portal.get("id", "")),
			str(portal.get("building_type", "")),
			str(portal.get("plot_id", "")),
			str(portal.get("approach_edge_id", "")),
		])
		for point in _vector2_array(portal.get("polygon_world", [])):
			parts.append("portal_point:%s" % _vector_token(point))
	for blocker in blockers:
		parts.append("blocker:%s:%s" % [
			str(blocker.get("owner_id", "")),
			str(blocker.get("kind", "")),
		])
		for point in _vector2_array(blocker.get("polygon_world", [])):
			parts.append("blocker_point:%s" % _vector_token(point))
	return "\n".join(PackedStringArray(parts)).sha256_text()


static func _polygon_area_abs(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(polygon.size()):
		twice_area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(twice_area) * 0.5


static func _vector_token(value: Vector2) -> String:
	return "%.6f,%.6f" % [value.x, value.y]


static func _copy_polygon_manifest(value: Variant, copied_keys: Array[String]) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for entry in _dictionary_array(value):
		var item := {}
		for key in copied_keys:
			item[key] = entry.get(key, "")
		item["polygon_world"] = _vector2_array(entry.get("polygon_world", [])).duplicate()
		copied.append(item)
	return copied


static func _is_polygon_manifest(value: Variant) -> bool:
	if not (value is Array):
		return false
	for entry_value in value as Array:
		if not (entry_value is Dictionary):
			return false
		var entry := entry_value as Dictionary
		var polygon := _vector2_array(entry.get("polygon_world", []))
		if polygon.size() < 3:
			return false
		for point in polygon:
			if not point.is_finite():
				return false
	return true


static func _packed_polygon(value: Variant) -> PackedVector2Array:
	return PackedVector2Array(_vector2_array(value))


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	if not (value is Array):
		return typed
	for item in value as Array:
		if item is Dictionary:
			typed.append(item as Dictionary)
	return typed


static func _vector2_array(value: Variant) -> Array[Vector2]:
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


static func _is_sha256_hex(value: String) -> bool:
	if value.length() != SHA256_HEX_LENGTH:
		return false
	const HEX := "0123456789abcdef"
	for index in range(value.length()):
		if HEX.find(value.substr(index, 1)) < 0:
			return false
	return true


static func _rejected_state(reason: String) -> Dictionary:
	return {
		"valid": false,
		"schema_version": SCHEMA_VERSION,
		"rejection_reason": reason,
	}


static func _move_rejection(actor_position: Vector2, reason: String) -> Dictionary:
	return {
		"valid": false,
		"rejection_reason": reason,
		"actor_position": actor_position,
		"requested_delta": Vector2.ZERO,
		"applied_delta": Vector2.ZERO,
		"blocked": true,
		"sweep_substeps": 0,
	}
