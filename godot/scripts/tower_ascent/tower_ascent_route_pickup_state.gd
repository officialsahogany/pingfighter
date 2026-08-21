extends RefCounted

const ActiveItemFieldSpawnPool := preload(
	"res://scripts/items/active_item_field_spawn_pool.gd"
)
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const KIND_GOLD := "gold"
const KIND_MUHON := "muhon"
const KIND_ACTIVE_ITEM := "active_item"
const FIXTURE_FALLBACK_ACTIVE_ITEM_NAME := "gauge_charge"

var _spawn_pool: Object = ActiveItemFieldSpawnPool.new()
var _pickups: Array[Dictionary] = []
var _roll_count := 0


func prewarm_candidates(perf_logger: Object = null) -> void:
	_spawn_pool.prewarm_spawn_candidate_templates(perf_logger)


func build_active_candidates(registry: Object, owner: Object) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = _spawn_pool.build_spawn_candidates(registry, owner)
	# Existing route fixtures intentionally use a null or RefCounted owner and do
	# not build the production unlock registry. Keep that explicit fixture lane
	# deterministic without weakening unlock filtering for a real battle Node.
	if candidates.is_empty() and (owner == null or not (owner is Node)):
		var fallback := ActiveItemCatalog.new().build_item_by_name(
			FIXTURE_FALLBACK_ACTIVE_ITEM_NAME
		)
		if not fallback.is_empty():
			candidates.append(fallback)
	return candidates


func begin(
	gameplay_rng_state: Dictionary,
	targets: Array[Dictionary],
	active_candidates: Array[Dictionary]
) -> Dictionary:
	clear_route()
	var eligible_candidates := _eligible_active_candidates(active_candidates)
	if eligible_candidates.is_empty():
		return {
			"accepted": false,
			"reason": "no_active_item_candidates",
			"gameplay_rng_state": gameplay_rng_state.duplicate(true),
		}

	var seed_value := int(gameplay_rng_state.get("seed", 140913))
	if seed_value == 0:
		seed_value = 140913
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state_value := int(gameplay_rng_state.get("state", seed_value))
	if state_value != 0:
		rng.state = state_value

	var gold_count := rng.randi_range(
		TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MIN,
		TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MAX
	)
	var muhon_count := rng.randi_range(
		TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MIN,
		TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MAX
	)
	var active_item := _pick_weighted_active_candidate(eligible_candidates, rng.randf())
	if active_item.is_empty():
		return {
			"accepted": false,
			"reason": "active_item_roll_failed",
			"gameplay_rng_state": gameplay_rng_state.duplicate(true),
		}

	for index in range(gold_count):
		if not _append_pickup(KIND_GOLD, index, targets, rng):
			return _placement_failure(gameplay_rng_state)
	for index in range(muhon_count):
		if not _append_pickup(KIND_MUHON, index, targets, rng):
			return _placement_failure(gameplay_rng_state)
	if not _append_pickup(
		KIND_ACTIVE_ITEM,
		0,
		targets,
		rng,
		str(active_item.get("name", ""))
	):
		return _placement_failure(gameplay_rng_state)

	_roll_count += 1
	return {
		"accepted": true,
		"reason": "ready",
		"pickups": get_pickups(),
		"gameplay_rng_state": {
			"seed": int(rng.seed),
			"state": int(rng.state),
		},
	}


func clear_route() -> void:
	_pickups.clear()


func reset() -> void:
	clear_route()
	_roll_count = 0


func get_pickups() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pickup in _pickups:
		if not bool(pickup.get("consumed", false)):
			result.append(pickup.duplicate(true))
	return result


func get_pickup(pickup_id: String) -> Dictionary:
	for pickup in _pickups:
		if str(pickup.get("id", "")) == pickup_id:
			return pickup.duplicate(true)
	return {}


func consume(pickup_id: String) -> bool:
	for pickup in _pickups:
		if str(pickup.get("id", "")) != pickup_id:
			continue
		if bool(pickup.get("consumed", false)):
			return false
		pickup["consumed"] = true
		return true
	return false


func get_roll_count() -> int:
	return _roll_count


func _append_pickup(
	kind: String,
	index: int,
	targets: Array[Dictionary],
	rng: RandomNumberGenerator,
	item_name: String = ""
) -> bool:
	var position := _find_position(targets, rng)
	if position == Vector2.INF:
		return false
	var pickup := {
		"id": "route_pickup_%s_%02d" % [kind, index],
		"kind": kind,
		"position": position,
		"draw_radius": TowerAscentTuning.TEMP_ROUTE_PICKUP_DRAW_RADIUS,
		"hit_radius": TowerAscentTuning.TEMP_ROUTE_PICKUP_HIT_RADIUS,
		"amount": 1,
		"consumed": false,
	}
	if not item_name.is_empty():
		pickup["item_name"] = item_name
	_pickups.append(pickup)
	return true


func _find_position(
	targets: Array[Dictionary],
	rng: RandomNumberGenerator
) -> Vector2:
	var placement_rect := TowerAscentTuning.TEMP_ROUTE_PICKUP_PLACEMENT_RECT
	for _attempt in range(TowerAscentTuning.TEMP_ROUTE_PICKUP_PLACEMENT_ATTEMPTS):
		var candidate := Vector2(
			rng.randf_range(placement_rect.position.x, placement_rect.end.x),
			rng.randf_range(placement_rect.position.y, placement_rect.end.y)
		)
		if _is_position_clear(candidate, targets):
			return candidate

	var step := TowerAscentTuning.TEMP_ROUTE_PICKUP_FALLBACK_GRID_STEP
	var row_count := maxi(1, int(floor(placement_rect.size.y / step.y)) + 1)
	var column_count := maxi(1, int(floor(placement_rect.size.x / step.x)) + 1)
	var candidate_count := row_count * column_count
	var start_index := rng.randi_range(0, maxi(0, candidate_count - 1))
	for offset in range(candidate_count):
		var candidate_index := (start_index + offset) % candidate_count
		var row := floori(float(candidate_index) / float(column_count))
		var column := candidate_index % column_count
		var fallback_position := Vector2(
			minf(placement_rect.end.x, placement_rect.position.x + float(column) * step.x),
			minf(placement_rect.end.y, placement_rect.position.y + float(row) * step.y)
		)
		if _is_position_clear(fallback_position, targets):
			return fallback_position
	return Vector2.INF


func _is_position_clear(position: Vector2, targets: Array[Dictionary]) -> bool:
	for pickup in _pickups:
		var other_position := _vector2(pickup.get("position", Vector2.ZERO))
		if position.distance_to(other_position) < TowerAscentTuning.TEMP_ROUTE_PICKUP_MIN_CENTER_GAP:
			return false
	for target in targets:
		var target_position := _vector2(target.get("position", Vector2.ZERO))
		if position.distance_to(target_position) < TowerAscentTuning.TEMP_ROUTE_PICKUP_MIN_TARGET_CENTER_GAP:
			return false
		if _distance_to_segment(
			position,
			TowerAscentTuning.TEMP_ROUTE_PICKUP_ROUTE_ORIGIN,
			target_position
		) < TowerAscentTuning.TEMP_ROUTE_PICKUP_MIN_PATH_CENTER_GAP:
			return false
	return true


func _eligible_active_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in candidates:
		if (
			str(candidate.get("type", "")).to_lower() == "active"
			and not str(candidate.get("name", "")).is_empty()
			and float(candidate.get("chance", 0.0)) > 0.0
		):
			result.append(candidate)
	return result


func _pick_weighted_active_candidate(
	candidates: Array[Dictionary],
	unit_roll: float
) -> Dictionary:
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += maxf(0.0, float(candidate.get("chance", 0.0)))
	if total_weight <= 0.0:
		return {}
	var remaining := clampf(unit_roll, 0.0, 0.999999) * total_weight
	for candidate in candidates:
		remaining -= maxf(0.0, float(candidate.get("chance", 0.0)))
		if remaining <= 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func _placement_failure(previous_rng_state: Dictionary) -> Dictionary:
	clear_route()
	return {
		"accepted": false,
		"reason": "pickup_placement_failed",
		"gameplay_rng_state": previous_rng_state.duplicate(true),
	}


func _distance_to_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var ratio := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * ratio)


func _vector2(value: Variant) -> Vector2:
	return value as Vector2 if value is Vector2 else Vector2.ZERO
