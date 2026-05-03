extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 200.0
const PICKUP_EFFECT_DURATION_SEC := 2.0
const PICKUP_FADE_DURATION_SEC := 1.0
const PICKUP_TARGET := Vector2(100.0, FIELD_HEIGHT * 0.5)
const LONG_BOOST_DURATION_FRAMES := 480.0
const LONG_BOOST_TRANSITION_FRAMES := 60.0
const LONG_BOOST_TARGET_SCALE := 1.5
const REGENERATION_POTION_PARTICLE_DURATION_SEC := 0.78
const REGENERATION_POTION_RING_DURATION_SEC := 0.58

var regeneration_potion_particles: Array[Dictionary] = []
var regeneration_potion_rings: Array[Dictionary] = []
var pickup_particles: Array[Dictionary] = []
var pickup_effect: Dictionary = {}
var long_boost_active: bool = false
var long_boost_timer_frames: float = 0.0
var long_boost_initial_timer_frames: float = 0.0
var long_boost_scale: float = 1.0


func reset() -> void:
	regeneration_potion_particles.clear()
	regeneration_potion_rings.clear()
	pickup_particles.clear()
	pickup_effect.clear()
	long_boost_active = false
	long_boost_timer_frames = 0.0
	long_boost_initial_timer_frames = 0.0
	long_boost_scale = 1.0


func update(owner: Object, delta: float) -> void:
	_update_long_boost(delta)
	sync_long_boost_owner_state(owner)
	_update_regeneration_potion_effect(delta)
	_update_pickup_particles(delta)
	_update_pickup_effect(delta)


func apply_gauge_charge(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	var gauge_gain: float = float(item_data.get("gauge_gain", GAUGE_CHARGE_AMOUNT))
	var gauge_max: float = _get_effective_gauge_max(owner, item_data)
	var current_gauge: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0))
	var next_gauge: float = min(gauge_max, current_gauge + gauge_gain)
	owner.set("special_gauge", next_gauge)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null:
		if feedback.has_method("trigger_gauge_flash"):
			feedback.trigger_gauge_flash()
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.06, 1.6)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_drink"):
		audio.play_drink()

	return true


func activate_long_boost(owner: Object, registry: Object) -> bool:
	if long_boost_active:
		return false

	long_boost_active = true
	long_boost_timer_frames = LONG_BOOST_DURATION_FRAMES
	long_boost_initial_timer_frames = long_boost_timer_frames
	long_boost_scale = 1.0
	sync_long_boost_owner_state(owner)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_active_item"):
			audio.play_active_item()
		elif audio.has_method("play_drink"):
			audio.play_drink()

	return true


func apply_regeneration_potion(owner: Object, registry: Object) -> bool:
	_reset_skill_cooldowns(_get_instance(registry, "smasher_skill_state"))
	_reset_skill_cooldowns(_get_instance(registry, "viper_skill_state"))

	var drive_input_state: Object = _get_instance(registry, "smasher_drive_input_state")
	if drive_input_state != null and drive_input_state.has_method("reset_cooldowns"):
		drive_input_state.reset_cooldowns()

	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	var dash_snapshot: Dictionary = {}
	if dash_state != null:
		if dash_state.has_method("refill_tokens"):
			dash_state.refill_tokens()
		if dash_state.has_method("get_snapshot"):
			dash_snapshot = dash_state.get_snapshot()

	var orb_hud_state: Object = _get_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("reset_dash_tokens"):
		orb_hud_state.reset_dash_tokens(int(dash_snapshot.get("tokens", 1)))

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null:
		if feedback.has_method("trigger_dash_flash"):
			feedback.trigger_dash_flash()
		if feedback.has_method("trigger_gauge_flash"):
			feedback.trigger_gauge_flash()
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.04, 1.25)

	_spawn_regeneration_potion_effect(owner)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_drink"):
			audio.play_drink()
		if audio.has_method("play_active_item"):
			audio.play_active_item()

	return true


func can_store_item(item_name: String) -> bool:
	if item_name == "long_boost" and long_boost_active:
		return false
	return true


func trigger_pickup_effect(
	field_item: Dictionary,
	display_name: String,
	item_color: Color,
	registry: Object
) -> void:
	var item_data: Dictionary = _get_dictionary(field_item, "item_data").duplicate(true)
	var start_pos: Vector2 = _get_vector2(field_item, "position", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5))
	pickup_effect = {
		"item_data": item_data,
		"display_name": display_name,
		"timer": PICKUP_EFFECT_DURATION_SEC,
		"alpha": 180.0 / 255.0,
		"position": start_pos,
		"start_position": start_pos,
	}
	_create_balloon_pop_particles(start_pos, item_color)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_item_get"):
		audio.play_item_get()


func sync_long_boost_owner_state(owner: Object) -> void:
	if owner == null:
		return

	var next_width: float = get_player_paddle_width(PLAYER_BASE_PADDLE_WIDTH)
	var current_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5 - current_width * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)
	)
	var center_x: float = player_pos.x + current_width * 0.5
	player_pos.x = clamp(center_x - next_width * 0.5, 0.0, max(0.0, FIELD_WIDTH - next_width))
	owner.set("player_pos", player_pos)
	owner.set("player_paddle_width", next_width)
	owner.set("player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)
	owner.set("player_paddle_scale", long_boost_scale)


func get_player_paddle_scale() -> float:
	return long_boost_scale


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return max(1.0, base_width * long_boost_scale)


func get_pickup_effect() -> Dictionary:
	return pickup_effect


func get_pickup_particles() -> Array[Dictionary]:
	return pickup_particles


func get_regeneration_potion_particles() -> Array[Dictionary]:
	return regeneration_potion_particles


func get_regeneration_potion_rings() -> Array[Dictionary]:
	return regeneration_potion_rings


func get_long_boost_timer_context() -> Dictionary:
	return {
		"active": long_boost_active,
		"timer_frames": long_boost_timer_frames,
		"initial_timer_frames": long_boost_initial_timer_frames,
	}


func _reset_skill_cooldowns(skill_state: Object) -> void:
	if skill_state == null:
		return
	if skill_state.has_method("reset_cooldowns"):
		skill_state.reset_cooldowns()
	elif skill_state.has_method("reset"):
		skill_state.reset()


func _spawn_regeneration_potion_effect(owner: Object) -> void:
	var fallback_pos := Vector2(FIELD_WIDTH * 0.5 - PLAYER_BASE_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", fallback_pos)
	var paddle_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var paddle_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var center := player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.45)

	regeneration_potion_rings.append({
		"position": center,
		"age": 0.0,
		"duration": REGENERATION_POTION_RING_DURATION_SEC,
	})

	var colors := [
		Color(1.0, 215.0 / 255.0, 0.0, 1.0),
		Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 1.0),
		Color(1.0, 200.0 / 255.0, 50.0 / 255.0, 1.0),
		Color(1.0, 1.0, 100.0 / 255.0, 1.0),
		Color(1.0, 180.0 / 255.0, 30.0 / 255.0, 1.0),
	]
	for _i in range(25):
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(6.0, 48.0)
		var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		regeneration_potion_particles.append({
			"position": start_pos,
			"velocity": Vector2(randf_range(-34.0, 34.0), randf_range(-104.0, -34.0)),
			"radius": randf_range(2.4, 5.2),
			"age": 0.0,
			"lifetime": randf_range(0.42, REGENERATION_POTION_PARTICLE_DURATION_SEC),
			"color": colors[randi() % colors.size()],
		})


func _get_effective_gauge_max(owner: Object, item_data: Dictionary) -> float:
	var fallback_max: float = max(1.0, float(item_data.get("gauge_max", GAUGE_MAX)))
	return max(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", fallback_max)))


func _update_pickup_particles(delta: float) -> void:
	if pickup_particles.is_empty():
		return
	var survivors: Array[Dictionary] = []
	for particle in pickup_particles:
		var age: float = float(particle.get("age", 0.0)) + delta
		var lifetime: float = max(0.01, float(particle.get("lifetime", 0.45)))
		if age >= lifetime:
			continue
		particle["age"] = age
		particle["position"] = _get_vector2(particle, "position", Vector2.ZERO) + _get_vector2(particle, "velocity", Vector2.ZERO) * delta
		particle["velocity"] = _get_vector2(particle, "velocity", Vector2.ZERO) * 0.94
		survivors.append(particle)
	pickup_particles = survivors


func _update_pickup_effect(delta: float) -> void:
	if pickup_effect.is_empty():
		return
	var timer: float = float(pickup_effect.get("timer", 0.0)) - delta
	if timer <= 0.0:
		pickup_effect.clear()
		return
	pickup_effect["timer"] = timer
	var progress: float = 1.0 - (timer / PICKUP_EFFECT_DURATION_SEC)
	var ease_progress: float = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 2.0)
	var start_pos: Vector2 = _get_vector2(pickup_effect, "start_position", Vector2.ZERO)
	pickup_effect["position"] = start_pos.lerp(PICKUP_TARGET, ease_progress)
	if timer < PICKUP_FADE_DURATION_SEC:
		pickup_effect["alpha"] = clamp(timer / PICKUP_FADE_DURATION_SEC, 0.0, 1.0)
	else:
		pickup_effect["alpha"] = 180.0 / 255.0


func _update_regeneration_potion_effect(delta: float) -> void:
	if not regeneration_potion_particles.is_empty():
		var particle_survivors: Array[Dictionary] = []
		for particle in regeneration_potion_particles:
			var age: float = float(particle.get("age", 0.0)) + delta
			var lifetime: float = max(0.001, float(particle.get("lifetime", REGENERATION_POTION_PARTICLE_DURATION_SEC)))
			if age >= lifetime:
				continue
			var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
			var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
			pos += velocity * delta
			velocity = velocity.lerp(Vector2.ZERO, min(1.0, delta * 1.8))
			velocity.y += 18.0 * delta
			particle["age"] = age
			particle["position"] = pos
			particle["velocity"] = velocity
			particle_survivors.append(particle)
		regeneration_potion_particles = particle_survivors

	if not regeneration_potion_rings.is_empty():
		var ring_survivors: Array[Dictionary] = []
		for ring in regeneration_potion_rings:
			var age: float = float(ring.get("age", 0.0)) + delta
			var duration: float = max(0.001, float(ring.get("duration", REGENERATION_POTION_RING_DURATION_SEC)))
			if age >= duration:
				continue
			ring["age"] = age
			ring_survivors.append(ring)
		regeneration_potion_rings = ring_survivors


func _update_long_boost(delta: float) -> void:
	if not long_boost_active:
		long_boost_timer_frames = 0.0
		long_boost_initial_timer_frames = 0.0
		long_boost_scale = 1.0
		return

	var fps_scale: float = delta * 60.0
	long_boost_timer_frames = max(0.0, long_boost_timer_frames - fps_scale)
	var elapsed_frames: float = max(0.0, long_boost_initial_timer_frames - long_boost_timer_frames)
	if elapsed_frames < LONG_BOOST_TRANSITION_FRAMES:
		var grow_progress: float = elapsed_frames / LONG_BOOST_TRANSITION_FRAMES
		long_boost_scale = lerp(1.0, LONG_BOOST_TARGET_SCALE, grow_progress)
	elif long_boost_timer_frames <= LONG_BOOST_TRANSITION_FRAMES:
		var shrink_progress: float = long_boost_timer_frames / LONG_BOOST_TRANSITION_FRAMES
		long_boost_scale = lerp(1.0, LONG_BOOST_TARGET_SCALE, shrink_progress)
	else:
		long_boost_scale = LONG_BOOST_TARGET_SCALE

	if long_boost_timer_frames <= 0.0:
		long_boost_active = false
		long_boost_timer_frames = 0.0
		long_boost_initial_timer_frames = 0.0
		long_boost_scale = 1.0


func _create_balloon_pop_particles(center: Vector2, item_color: Color) -> void:
	for i in range(22):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(90.0, 250.0)
		var color := item_color.lerp(Color.WHITE, randf_range(0.15, 0.55))
		pickup_particles.append({
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"radius": randf_range(2.0, 4.5),
			"age": 0.0,
			"lifetime": randf_range(0.28, 0.62),
			"color": color,
		})


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
