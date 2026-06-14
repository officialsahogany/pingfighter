extends RefCounted

const Stage1PillarAmbientPayloadFactory := preload("res://scripts/stages/stage1/stage1_pillar_ambient_payload_factory.gd")
const Stage1PillarPetalState := preload("res://scripts/stages/stage1/stage1_pillar_petal_state.gd")
const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")

const TREE_SHAKE_DURATION := 0.28
const FIELD_WIDTH := 760.0
const BUTTERFLY_COOLDOWN_MIN := 20.0
const BUTTERFLY_COOLDOWN_MAX := 40.0
const BUTTERFLY_FLIGHT_SPEED := 300.0
const BUTTERFLY_ABSORB_DISTANCE := 10.0
const BUTTERFLY_ABSORB_DURATION := 1.0
const BUTTERFLY_TRAIL_LIMIT := 6
const BUTTERFLY_PARTICLE_LIMIT := 14
const BUTTERFLY_ABSORB_BURST_COUNT := 8
const BUTTERFLY_ABSORB_DRIP_CHANCE := 0.25

var time := 0.0
var butterflies: Array[Dictionary] = []
var last_view_size := Vector2.ZERO
var last_game_offset := Vector2.ZERO
var last_game_size := Vector2.ZERO
var geometry: Object = Stage1PillarLayerGeometry.new()
var petal_state: Object = Stage1PillarPetalState.new()
var tree_shakes: Dictionary = {
	"left": {"timer": 0.0, "strength": 0.0, "impact_y_ratio": 0.5},
	"right": {"timer": 0.0, "strength": 0.0, "impact_y_ratio": 0.5},
}
var flying_butterfly: Dictionary = {}
var absorbing_butterfly: Dictionary = {}
var absorption_particles: Array[Dictionary] = []
var flying_trail: Array[Vector2] = []
var butterfly_cooldown := 0.0
var absorbing_timer := 0.0
var gauge_recovered := false


func init_state() -> void:
	time = 0.0
	butterflies.clear()
	petal_state.reset()
	flying_butterfly.clear()
	absorbing_butterfly.clear()
	absorption_particles.clear()
	flying_trail.clear()
	gauge_recovered = false
	absorbing_timer = 0.0
	butterfly_cooldown = randf_range(BUTTERFLY_COOLDOWN_MIN, BUTTERFLY_COOLDOWN_MAX)
	butterflies = Stage1PillarAmbientPayloadFactory.build_idle_butterflies()


func reset() -> void:
	init_state()


func update_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	last_view_size = view_size
	last_game_offset = game_offset
	last_game_size = game_size
	petal_state.update_layout(view_size, game_offset, game_size)


func update(delta: float, context: Dictionary = {}) -> void:
	time += delta
	_update_tree_shakes(delta)
	_update_butterfly_absorption_particles(delta)
	_update_butterfly_event(delta, context)
	petal_state.update(delta, time)


func trigger_tree_shake(
	side: String,
	impact_y: float,
	impact_speed: float,
	field_height: float,
	layer_renderer: Object
) -> void:
	if side != "left" and side != "right":
		return
	var shake: Dictionary = tree_shakes[side]
	var strength: float = clamp((impact_speed - 6.0) / 18.0, 0.25, 1.0)
	shake["timer"] = TREE_SHAKE_DURATION
	shake["strength"] = max(strength, float(shake.get("strength", 0.0)) * 0.5)
	shake["impact_y_ratio"] = clamp(impact_y / max(1.0, field_height), 0.04, 0.96)
	tree_shakes[side] = shake
	petal_state.spawn_tree_drop_petals(side, strength, layer_renderer, tree_shakes)


func get_time() -> float:
	return time


func get_tree_shakes() -> Dictionary:
	return tree_shakes


func get_butterflies() -> Array[Dictionary]:
	return butterflies


func get_flying_butterfly() -> Dictionary:
	if flying_butterfly.is_empty():
		return {}
	return _butterfly_to_game_space(flying_butterfly)


func get_absorbing_butterfly() -> Dictionary:
	if absorbing_butterfly.is_empty():
		return {}
	var result: Dictionary = _butterfly_to_game_space(absorbing_butterfly)
	result["progress"] = clamp(1.0 - absorbing_timer / BUTTERFLY_ABSORB_DURATION, 0.0, 1.0)
	return result


func get_flying_trail() -> Array[Dictionary]:
	var trail: Array[Dictionary] = []
	for i in range(flying_trail.size()):
		var age_ratio: float = float(i + 1) / float(max(1, flying_trail.size()))
		trail.append(Stage1PillarAmbientPayloadFactory.build_flying_trail_entry(
			_view_to_game_pos(flying_trail[i]),
			age_ratio
		))
	return trail


func get_absorption_particles() -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	for particle in absorption_particles:
		var copy: Dictionary = particle.duplicate()
		copy["position"] = _view_to_game_pos(_as_vector2(copy.get("position", Vector2.ZERO)))
		particles.append(copy)
	return particles


func has_ingame_butterfly_effect() -> bool:
	return not flying_butterfly.is_empty() or not absorbing_butterfly.is_empty() or not absorption_particles.is_empty() or not flying_trail.is_empty()


func consume_gauge_recovery() -> bool:
	if not gauge_recovered:
		return false
	gauge_recovered = false
	return true


func get_floating_petals() -> Array[Dictionary]:
	return petal_state.get_floating_petals()


func get_tree_drop_petals() -> Array[Dictionary]:
	return petal_state.get_tree_drop_petals()


func _update_tree_shakes(delta: float) -> void:
	for side in ["left", "right"]:
		var shake: Dictionary = tree_shakes[side]
		var timer: float = float(shake.get("timer", 0.0))
		if timer > 0.0:
			timer = max(0.0, timer - delta)
			shake["timer"] = timer
			if timer <= 0.0:
				shake["strength"] = 0.0
			tree_shakes[side] = shake


func _update_butterfly_event(delta: float, context: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 1:
		return
	if last_view_size.x <= 0.0 or last_game_size.x <= 0.0:
		return

	var player_center_view: Vector2 = _get_player_center_view(context)
	if player_center_view == Vector2.INF:
		return

	if not absorbing_butterfly.is_empty():
		_update_absorbing_butterfly(delta)
		return

	if not flying_butterfly.is_empty():
		_update_flying_butterfly(delta, player_center_view)
		return

	if butterfly_cooldown > 0.0:
		butterfly_cooldown = max(0.0, butterfly_cooldown - delta)
		return

	if butterflies.is_empty():
		return
	_start_butterfly_flight()


func _update_flying_butterfly(delta: float, target_view: Vector2) -> void:
	var current_pos: Vector2 = _as_vector2(flying_butterfly.get("view_pos", Vector2.ZERO))
	var to_target: Vector2 = target_view - current_pos
	var distance: float = to_target.length()
	if distance > BUTTERFLY_ABSORB_DISTANCE:
		var step: float = min(distance, BUTTERFLY_FLIGHT_SPEED * delta)
		current_pos += to_target.normalized() * step
		flying_butterfly["view_pos"] = current_pos
		flying_butterfly["wing_speed"] = 12.0 + max(0.0, (1.0 - distance / 500.0) * 8.0)
		_record_flying_trail(current_pos)
		return

	absorbing_butterfly = flying_butterfly.duplicate(true)
	absorbing_butterfly["view_pos"] = current_pos
	absorbing_timer = BUTTERFLY_ABSORB_DURATION
	flying_butterfly.clear()
	flying_trail.clear()
	gauge_recovered = true
	_create_absorption_particles(current_pos, BUTTERFLY_ABSORB_BURST_COUNT)


func _update_absorbing_butterfly(delta: float) -> void:
	absorbing_timer = max(0.0, absorbing_timer - delta)
	if randf() < BUTTERFLY_ABSORB_DRIP_CHANCE:
		_create_absorption_particles(_as_vector2(absorbing_butterfly.get("view_pos", Vector2.ZERO)), 1)
	if absorbing_timer > 0.0:
		return
	absorbing_butterfly.clear()
	if not butterflies.is_empty():
		butterfly_cooldown = randf_range(BUTTERFLY_COOLDOWN_MIN, BUTTERFLY_COOLDOWN_MAX)


func _update_butterfly_absorption_particles(delta: float) -> void:
	if absorption_particles.is_empty():
		return
	var write_idx: int = 0
	for i in range(absorption_particles.size()):
		var particle: Dictionary = absorption_particles[i]
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = _as_vector2(particle.get("velocity", Vector2.ZERO))
		var life: float = float(particle.get("life", 0.0)) - delta * 1.8
		if life <= 0.0:
			continue
		pos += velocity * delta
		velocity *= 0.94
		particle["position"] = pos
		particle["velocity"] = velocity
		particle["life"] = life
		absorption_particles[write_idx] = particle
		write_idx += 1
	absorption_particles.resize(write_idx)


func _start_butterfly_flight() -> void:
	var candidates: Array[int] = []
	for i in range(butterflies.size()):
		if _is_butterfly_visible_for_flight(butterflies[i]):
			candidates.append(i)
	if candidates.is_empty():
		butterfly_cooldown = 1.0
		return

	var selected_index: int = candidates[randi() % candidates.size()]
	var selected: Dictionary = butterflies[selected_index].duplicate(true)
	selected["view_pos"] = _get_butterfly_view_position(selected)
	butterflies.remove_at(selected_index)
	flying_butterfly = selected
	flying_trail.clear()
	_record_flying_trail(_as_vector2(flying_butterfly.get("view_pos", Vector2.ZERO)))


func _is_butterfly_visible_for_flight(butterfly: Dictionary) -> bool:
	var side: String = str(butterfly.get("side", "left"))
	var side_rect: Rect2 = geometry.get_side_rect(side, last_view_size, last_game_offset, last_game_size)
	return side_rect.size.x > 24.0


func _get_butterfly_view_position(butterfly: Dictionary) -> Vector2:
	var side: String = str(butterfly.get("side", "left"))
	var side_rect: Rect2 = geometry.get_side_rect(side, last_view_size, last_game_offset, last_game_size)
	var scale_factor: float = _get_scale_factor()
	var phase: float = float(butterfly.get("phase", 0.0))
	var base_x: float = side_rect.position.x + side_rect.size.x * 0.5
	var base_y: float = last_view_size.y * float(butterfly.get("y_ratio", 0.5))
	return Vector2(
		base_x + sin(time * 0.5 + phase) * 15.0 * scale_factor,
		base_y + cos(time * 0.3 + phase) * 10.0 * scale_factor
	)


func _get_player_center_view(context: Dictionary) -> Vector2:
	if not context.has("player_pos"):
		return Vector2.INF
	var player_pos_value: Variant = context.get("player_pos", Vector2.ZERO)
	if not (player_pos_value is Vector2):
		return Vector2.INF
	var player_pos: Vector2 = player_pos_value
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)))
	var player_center_game := player_pos + paddle_size * 0.5
	return last_game_offset + player_center_game * _get_scale_factor()


func _record_flying_trail(pos: Vector2) -> void:
	flying_trail.append(pos)
	while flying_trail.size() > BUTTERFLY_TRAIL_LIMIT:
		flying_trail.pop_front()


func _create_absorption_particles(center: Vector2, count: int) -> void:
	for _i in range(count):
		absorption_particles.append(Stage1PillarAmbientPayloadFactory.build_absorption_particle(center))
	while absorption_particles.size() > BUTTERFLY_PARTICLE_LIMIT:
		absorption_particles.pop_front()


func _butterfly_to_game_space(butterfly: Dictionary) -> Dictionary:
	var result: Dictionary = butterfly.duplicate(true)
	result["position"] = _view_to_game_pos(_as_vector2(butterfly.get("view_pos", Vector2.ZERO)))
	return result


func _view_to_game_pos(view_pos: Vector2) -> Vector2:
	return (view_pos - last_game_offset) / _get_scale_factor()


func _get_scale_factor() -> float:
	return last_game_size.x / FIELD_WIDTH if last_game_size.x > 0.0 else 1.0


func _as_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	return fallback
