extends RefCounted

const Stage2QuakeRockOffsetState := preload("res://scripts/stages/stage2/stage2_quake_rock_offset_state.gd")

const ABSORBED_ROCK_LEAF_STRENGTH := 1.15

var rock_state: Object = null
var rock_query: Object = null
var rock_lifecycle_coordinator: Object = null
var chaos_rock_coordinator: Object = null
var chaos_rock_state: Object = null
var rock_feedback_coordinator: Object = null
var ambient_state: Object = null
var rock_fragment_state: Object = null
var random_source: RandomNumberGenerator = null
var starpoint_coordinator: Object = null


func configure(
	rock_state_ref: Object,
	rock_query_ref: Object,
	rock_lifecycle_coordinator_ref: Object,
	chaos_rock_coordinator_ref: Object,
	chaos_rock_state_ref: Object,
	rock_feedback_coordinator_ref: Object,
	ambient_state_ref: Object,
	rock_fragment_state_ref: Object,
	random_source_ref: RandomNumberGenerator,
	starpoint_coordinator_ref: Object
) -> void:
	rock_state = rock_state_ref
	rock_query = rock_query_ref
	rock_lifecycle_coordinator = rock_lifecycle_coordinator_ref
	chaos_rock_coordinator = chaos_rock_coordinator_ref
	chaos_rock_state = chaos_rock_state_ref
	rock_feedback_coordinator = rock_feedback_coordinator_ref
	ambient_state = ambient_state_ref
	rock_fragment_state = rock_fragment_state_ref
	random_source = random_source_ref
	starpoint_coordinator = starpoint_coordinator_ref


func advance(
	delta: float,
	quake_timer: float,
	quake_duration: float,
	deps: Dictionary = {},
	context: Dictionary = {},
	debris_region_count: int = 0
) -> Dictionary:
	var result := {
		"expired": 0,
		"absorbed": 0,
		"absorption_cancelled": 0,
		"runtime_updated": 0,
	}
	if rock_state == null:
		advance_fragments(delta)
		return result
	var clamped_delta: float = max(0.0, delta)
	var rocks: Array = rock_state.rocks as Array
	for index in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[index]
		if rock_lifecycle_coordinator != null \
			and rock_lifecycle_coordinator.advance_lifetime(rock, clamped_delta):
			rock_state.remove_at(index)
			result["expired"] = int(result["expired"]) + 1
			continue
		if bool(rock.get("chaos_absorbing", false)):
			if chaos_rock_state == null or float(chaos_rock_state.timer) <= 0.0:
				rock["chaos_absorbing"] = false
				rock_state.replace_at(index, rock)
				result["absorption_cancelled"] = int(result["absorption_cancelled"]) + 1
				continue
			if update_chaos_absorbing_rock(rock, clamped_delta, deps, context, debris_region_count):
				rock_state.remove_at(index)
				result["absorbed"] = int(result["absorbed"]) + 1
				continue
			rock_state.replace_at(index, rock)
			continue
		if rock_query == null or not rock_query.needs_runtime_update(rock, quake_timer > 0.0):
			continue
		rock_state.update_visual_timers_at(index, clamped_delta)
		update_quake_rock_drop(rock, clamped_delta)
		Stage2QuakeRockOffsetState.update_offset(rock, clamped_delta, quake_timer, quake_duration)
		rock_state.replace_at(index, rock)
		result["runtime_updated"] = int(result["runtime_updated"]) + 1
	advance_fragments(clamped_delta)
	return result


func update_chaos_absorbing_rock(
	rock: Dictionary,
	delta: float,
	deps: Dictionary,
	context: Dictionary = {},
	debris_region_count: int = 0
) -> bool:
	if chaos_rock_coordinator == null:
		return false
	var motion_result: Dictionary = chaos_rock_coordinator.advance_absorbing_rock(rock, delta)
	if not bool(motion_result.get("destroyed", false)):
		return false
	var fallback_center: Vector2 = _get_rock_center(rock)
	destroy_chaos_absorbed_rock(
		rock,
		_get_vector2(motion_result.get("center", fallback_center), fallback_center),
		deps,
		context,
		debris_region_count
	)
	return true


func step_chaos_absorbing_rock(
	rock: Dictionary,
	center: Vector2,
	frame_step: float,
	deps: Dictionary,
	context: Dictionary = {},
	debris_region_count: int = 0
) -> bool:
	if chaos_rock_coordinator == null:
		return false
	var motion_result: Dictionary = chaos_rock_coordinator.step_absorbing_rock(rock, center, frame_step)
	if not bool(motion_result.get("destroyed", false)):
		return false
	var fallback_center: Vector2 = _get_rock_center(rock)
	destroy_chaos_absorbed_rock(
		rock,
		_get_vector2(motion_result.get("center", fallback_center), fallback_center),
		deps,
		context,
		debris_region_count
	)
	return true


func destroy_chaos_absorbed_rock(
	rock: Dictionary,
	center: Vector2,
	deps: Dictionary,
	context: Dictionary = {},
	debris_region_count: int = 0
) -> void:
	if rock_feedback_coordinator != null:
		rock_feedback_coordinator.emit_destruction_feedback(
			rock,
			center,
			ABSORBED_ROCK_LEAF_STRENGTH,
			ambient_state,
			rock_fragment_state,
			random_source,
			deps,
			Callable(self, "_spawn_starpoint_drop_at").bind(deps, context),
			maxi(0, debris_region_count)
		)
	if chaos_rock_coordinator != null:
		chaos_rock_coordinator.queue_absorbed_rock(rock, center)


func advance_fragments(delta: float) -> void:
	if rock_fragment_state != null and rock_fragment_state.has_method("advance"):
		rock_fragment_state.advance(max(0.0, delta))


func update_quake_rock_drop(rock: Dictionary, delta: float) -> bool:
	if rock_lifecycle_coordinator == null:
		return false
	return rock_lifecycle_coordinator.update_quake_rock_drop(rock, max(0.0, delta))


func _spawn_starpoint_drop_at(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	if starpoint_coordinator != null and starpoint_coordinator.has_method("spawn_drop_at"):
		starpoint_coordinator.spawn_drop_at(pos, deps, context)


func _get_rock_center(rock: Dictionary) -> Vector2:
	if rock_query != null and rock_query.has_method("get_center"):
		return rock_query.get_center(rock)
	return _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
