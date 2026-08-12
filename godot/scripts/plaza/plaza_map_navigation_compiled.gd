extends RefCounted

# R2-B activation-gate owner (MEDIUM performance gate): compiles a validated
# PlazaMapNavigation bound state ONCE into immutable packed geometry so the
# 60Hz walk path never re-hashes, re-validates, or rebuilds polygon arrays per
# tick (GRT-032-family contract). Movement semantics must stay result-identical
# to PlazaMapNavigation.move_actor on the same bound state: every shortcut in
# this file only skips provably no-op work (strictly separated polygons cannot
# change clip results; an axis-aligned allowed rect that fully contains the
# actor rect leaves zero uncovered area by definition).
#
# Shared predicates are intentionally CALLED on PlazaMapNavigation instead of
# copied here, so the exact geometric semantics keep a single canonical owner.

const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")

var _valid := false
var _binding_kind := ""
var _layout_fingerprint := ""
var _geometry_digest := ""
var _world_size := Vector2.ZERO

# Corridors occupy [0, _portal_start_index); portals follow. can_occupy with
# include_interaction_portals=false iterates only the corridor window, which
# preserves the legacy corridors-then-portals subtraction order.
var _allowed_polygons: Array[PackedVector2Array] = []
var _allowed_aabbs: Array[Rect2] = []
var _allowed_axis_rect: Array[bool] = []
var _portal_start_index := 0
var _blocker_polygons: Array[PackedVector2Array] = []
var _blocker_touch_aabbs: Array[Rect2] = []


static func compile(navigation_state: Dictionary) -> RefCounted:
	var compiled: RefCounted = new()
	# Full validation (including the geometry re-digest) happens exactly once
	# here. The instance keeps deep copies only, so later mutation of the source
	# dictionary cannot reach the compiled geometry.
	if not PlazaMapNavigation.is_bound_state_valid(navigation_state):
		return compiled
	compiled.call("_ingest_validated_state", navigation_state)
	return compiled


func is_valid() -> bool:
	return _valid


func get_layout_fingerprint() -> String:
	return _layout_fingerprint


func get_geometry_digest() -> String:
	return _geometry_digest


func get_binding_kind() -> String:
	return _binding_kind


func can_occupy(actor_position: Vector2, include_interaction_portals: bool = true) -> bool:
	if not _valid or not actor_position.is_finite():
		return false
	return _can_occupy_compiled(actor_position, include_interaction_portals)


func move_actor(actor_position: Vector2, input_direction: Vector2, delta: float) -> Dictionary:
	if not _valid:
		return _move_rejection(actor_position, "invalid_navigation_state")
	if not actor_position.is_finite():
		return _move_rejection(actor_position, "invalid_actor_position")
	if not input_direction.is_finite() or not is_finite(delta) or delta < 0.0:
		return _move_rejection(actor_position, "invalid_motion_input")
	if not _can_occupy_compiled(actor_position, true):
		return _move_rejection(actor_position, "actor_outside_navigation_union")

	var intended_motion := PlazaMapNavigation.compute_intended_motion(input_direction, delta)
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
	var substep_count := maxi(1, ceili(longest_axis / PlazaMapNavigation.MAX_SWEEP_STEP_WORLD))
	var substep := intended_motion / float(substep_count)
	var current := actor_position
	var blocked := false
	for _substep_index in range(substep_count):
		var direct_candidate := current + substep
		if _can_occupy_compiled(direct_candidate, true):
			current = direct_candidate
			continue

		blocked = true
		if not is_zero_approx(substep.x):
			var x_candidate := current + Vector2(substep.x, 0.0)
			if _can_occupy_compiled(x_candidate, true):
				current = x_candidate
		if not is_zero_approx(substep.y):
			var y_candidate := current + Vector2(0.0, substep.y)
			if _can_occupy_compiled(y_candidate, true):
				current = y_candidate

	return {
		"valid": true,
		"rejection_reason": "",
		"actor_position": current,
		"requested_delta": intended_motion,
		"applied_delta": current - actor_position,
		"blocked": blocked or not (current - actor_position).is_equal_approx(intended_motion),
		"sweep_substeps": substep_count,
	}


func _ingest_validated_state(navigation_state: Dictionary) -> void:
	_binding_kind = str(navigation_state.get("binding_kind", ""))
	_layout_fingerprint = str(navigation_state.get("layout_fingerprint", ""))
	_geometry_digest = str(navigation_state.get("geometry_digest", ""))
	_world_size = navigation_state.get("world_size", Vector2.ZERO)

	for corridor in _entries(navigation_state.get("walkable_corridor_polygons", [])):
		_append_allowed(corridor)
	_portal_start_index = _allowed_polygons.size()
	for portal in _entries(navigation_state.get("interaction_portals", [])):
		_append_allowed(portal)
	for blocker in _entries(navigation_state.get("blocked_polygons", [])):
		var polygon := _packed_copy(blocker.get("polygon_world", []))
		if polygon.size() < 3:
			continue
		_blocker_polygons.append(polygon)
		# _rect_touches_polygon reaches at most GEOMETRY_EPSILON beyond the
		# polygon, so the grown AABB prefilter can never skip a real touch.
		_blocker_touch_aabbs.append(_polygon_aabb(polygon).grow(PlazaMapNavigation.GEOMETRY_EPSILON))
	_valid = _portal_start_index > 0


func _can_occupy_compiled(actor_position: Vector2, include_interaction_portals: bool) -> bool:
	var half_size: Vector2 = PlazaMapNavigation.ACTOR_COLLISION_SIZE * 0.5
	var actor_rect := Rect2(actor_position - half_size, PlazaMapNavigation.ACTOR_COLLISION_SIZE)
	if (
		actor_rect.position.x < -PlazaMapNavigation.GEOMETRY_EPSILON
		or actor_rect.position.y < -PlazaMapNavigation.GEOMETRY_EPSILON
		or actor_rect.end.x > _world_size.x + PlazaMapNavigation.GEOMETRY_EPSILON
		or actor_rect.end.y > _world_size.y + PlazaMapNavigation.GEOMETRY_EPSILON
	):
		return false
	if _uncovered_area_exceeds(actor_rect, include_interaction_portals):
		return false
	for blocker_index in range(_blocker_polygons.size()):
		if not _blocker_touch_aabbs[blocker_index].intersects(actor_rect, true):
			continue
		if PlazaMapNavigation._rect_touches_polygon(actor_rect, _blocker_polygons[blocker_index]):
			return false
	return true


func _uncovered_area_exceeds(actor_rect: Rect2, include_interaction_portals: bool) -> bool:
	var limit := _allowed_polygons.size() if include_interaction_portals else _portal_start_index
	if limit <= 0:
		return true
	# Allocation-free common case: one axis-aligned allowed rect fully covering
	# the actor rect proves zero uncovered area without any clipping.
	for index in range(limit):
		if not _allowed_axis_rect[index]:
			continue
		var cover := _allowed_aabbs[index]
		if (
			actor_rect.position.x >= cover.position.x
			and actor_rect.position.y >= cover.position.y
			and actor_rect.end.x <= cover.end.x
			and actor_rect.end.y <= cover.end.y
		):
			return false
	var uncovered: Array[PackedVector2Array] = [PackedVector2Array([
		actor_rect.position,
		Vector2(actor_rect.end.x, actor_rect.position.y),
		actor_rect.end,
		Vector2(actor_rect.position.x, actor_rect.end.y),
	])]
	for index in range(limit):
		if not _allowed_aabbs[index].intersects(actor_rect, true):
			continue
		var next_uncovered: Array[PackedVector2Array] = []
		for fragment in uncovered:
			var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(fragment, _allowed_polygons[index])
			for remainder in clipped:
				if PlazaMapNavigation._polygon_area_abs(remainder) > PlazaMapNavigation.WALKABLE_UNCOVERED_AREA_EPSILON:
					next_uncovered.append(remainder)
		uncovered = next_uncovered
		if uncovered.is_empty():
			return false
	var uncovered_area := 0.0
	for fragment in uncovered:
		uncovered_area += PlazaMapNavigation._polygon_area_abs(fragment)
	return uncovered_area > PlazaMapNavigation.WALKABLE_UNCOVERED_AREA_EPSILON


func _append_allowed(entry: Dictionary) -> void:
	var polygon := _packed_copy(entry.get("polygon_world", []))
	if polygon.size() < 3:
		return
	_allowed_polygons.append(polygon)
	_allowed_aabbs.append(_polygon_aabb(polygon))
	_allowed_axis_rect.append(_is_axis_aligned_rect(polygon))


static func _polygon_aabb(polygon: PackedVector2Array) -> Rect2:
	var aabb := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()):
		aabb = aabb.expand(polygon[index])
	return aabb


static func _is_axis_aligned_rect(polygon: PackedVector2Array) -> bool:
	# Must be a proper rectangle traversal (4 axis-aligned edges over 4 distinct
	# corners). Corner-set membership alone would accept self-intersecting
	# bowties that do not cover their AABB interior.
	if polygon.size() != 4:
		return false
	for index in range(4):
		var start := polygon[index]
		var finish := polygon[(index + 1) % 4]
		var horizontal := start.y == finish.y and start.x != finish.x
		var vertical := start.x == finish.x and start.y != finish.y
		if not (horizontal or vertical):
			return false
	return true


static func _packed_copy(value: Variant) -> PackedVector2Array:
	var packed := PackedVector2Array()
	if value is PackedVector2Array:
		packed = (value as PackedVector2Array).duplicate()
		return packed
	if not (value is Array):
		return packed
	for item in value as Array:
		if not (item is Vector2):
			return PackedVector2Array()
		packed.append(item as Vector2)
	return packed


static func _entries(value: Variant) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	if not (value is Array):
		return typed
	for item in value as Array:
		if item is Dictionary:
			typed.append(item as Dictionary)
	return typed


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
