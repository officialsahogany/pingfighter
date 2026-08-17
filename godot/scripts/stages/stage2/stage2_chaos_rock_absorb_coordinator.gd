extends RefCounted

const Stage2ChaosAbsorbPayloadFactory := preload("res://scripts/stages/stage2/stage2_chaos_absorb_payload_factory.gd")
const Stage2ChaosRockAbsorbState := preload("res://scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd")
const Stage2RockRuntimeState := preload("res://scripts/stages/stage2/stage2_rock_runtime_state.gd")

const PULL_REFRESH_SEC := 0.18
const DESTROY_DISTANCE := 14.0
const ANGULAR_SPEED_MAX := 0.22
const ANGULAR_SPEED_NUMERATOR := 8.0
const RADIAL_SPEED_MIN := 4.0
const RADIAL_SPEED_MAX := 22.0
const RADIAL_SPEED_NUMERATOR := 460.0
const SPIN_MULTIPLIER := 1.8
const MAX_WHOLE_FRAME_STEPS := 240
const ACTIVATION_FLASH_SEC := 0.12

var rock_state: Object = null
var rock_query: Object = null
var water_visual_state: Object = null
var absorb_state: Object = null


func configure(
	rock_state_ref: Object,
	rock_query_ref: Object,
	water_visual_state_ref: Object,
	absorb_state_ref: Object
) -> void:
	rock_state = rock_state_ref
	rock_query = rock_query_ref
	water_visual_state = water_visual_state_ref
	absorb_state = absorb_state_ref


func advance_session(delta: float) -> void:
	if absorb_state != null:
		absorb_state.advance(delta)


func refresh_absorption(center: Vector2, radius: float) -> Array:
	if absorb_state == null:
		return []
	var absorbed: Array = absorb_state.refresh(center, PULL_REFRESH_SEC)
	_mark_landed_rocks(center)
	_absorb_water_splashes(center, radius, absorbed)
	return absorbed


func advance_absorbing_rock(rock: Dictionary, delta: float) -> Dictionary:
	var fallback_center: Vector2 = rock_query.get_center(rock) if rock_query != null else _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	var frame_step_total: float = max(0.0, delta) * 60.0
	if frame_step_total <= 0.0:
		return {"destroyed": false, "center": fallback_center}
	var session_center: Vector2 = absorb_state.center if absorb_state != null else Vector2.ZERO
	var absorb_center: Vector2 = _get_vector2(rock.get("chaos_absorb_center", session_center), session_center)
	var whole_steps: int = int(min(floor(frame_step_total), float(MAX_WHOLE_FRAME_STEPS)))
	var remainder: float = frame_step_total - float(whole_steps)
	var result := {"destroyed": false, "center": fallback_center}
	for _step in range(whole_steps):
		result = step_absorbing_rock(rock, absorb_center, 1.0)
		if bool(result.get("destroyed", false)):
			return result
	if remainder > 0.001:
		result = step_absorbing_rock(rock, absorb_center, remainder)
	return result


func step_absorbing_rock(rock: Dictionary, absorb_center: Vector2, frame_step: float) -> Dictionary:
	var rock_center: Vector2 = rock_query.get_center(rock) if rock_query != null else _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	var result: Dictionary = Stage2ChaosRockAbsorbState.step_absorbing_rock(
		rock,
		rock_center,
		absorb_center,
		frame_step,
		DESTROY_DISTANCE,
		ANGULAR_SPEED_MAX,
		ANGULAR_SPEED_NUMERATOR,
		RADIAL_SPEED_MIN,
		RADIAL_SPEED_MAX,
		RADIAL_SPEED_NUMERATOR,
		SPIN_MULTIPLIER
	)
	var result_center: Vector2 = _get_vector2(result.get("center", rock_center), rock_center)
	if bool(result.get("moved", false)) and rock_query != null:
		rock_query.set_center(rock, result_center)
	return result


func queue_absorbed_rock(rock: Dictionary, center: Vector2) -> void:
	if absorb_state == null:
		return
	var rock_radius: float = float(rock.get("radius", 28.0))
	absorb_state.queue_absorbed_entry(Stage2ChaosAbsorbPayloadFactory.build_absorbed_rock_payload(
		center,
		rock_radius
	))


func _mark_landed_rocks(center: Vector2) -> void:
	if rock_state == null or rock_query == null:
		return
	var rocks: Array = rock_state.rocks as Array
	for index in range(rocks.size()):
		var rock: Dictionary = rocks[index]
		if not rock_query.is_landed(rock):
			continue
		if bool(rock.get("chaos_absorbing", false)):
			continue
		var rock_center: Vector2 = rock_query.get_center(rock)
		rock_query.set_center(rock, rock_center)
		rock["chaos_spin_dir"] = 1.0 if (int(rock.get("id", index)) & 1) == 1 else -1.0
		rock["chaos_absorbing"] = true
		rock["chaos_absorb_center"] = center
		rock["flash"] = max(float(rock.get("flash", 0.0)), ACTIVATION_FLASH_SEC)
		Stage2RockRuntimeState.clear_water_target_flash(rock)
		rock_state.replace_at(index, rock)


func _absorb_water_splashes(center: Vector2, radius: float, absorbed: Array) -> void:
	if water_visual_state == null:
		return
	var splashes: Array = water_visual_state.splashes as Array
	var write_index := 0
	var splash_count := splashes.size()
	for index in range(splash_count):
		var splash: Dictionary = splashes[index]
		var splash_pos: Vector2 = _get_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO)
		var splash_radius: float = float(splash.get("radius", 10.0))
		if splash_pos.distance_to(center) <= radius + splash_radius:
			absorbed.append(Stage2ChaosAbsorbPayloadFactory.build_absorbed_splash_payload(splash_pos))
			continue
		splashes[write_index] = splash
		write_index += 1
	if write_index < splash_count:
		splashes.resize(write_index)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
