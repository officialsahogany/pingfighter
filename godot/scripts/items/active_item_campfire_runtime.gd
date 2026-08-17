extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const CAMPFIRE_SIZE := Vector2(52.0, 58.0)
# The installed object's lower edge is the real 750px playfield floor. Its
# 58px collision body still begins above the default paddle hitbox top, and
# BallMotionStepper checks it before the paddle when their bands overlap.
const CAMPFIRE_BOTTOM_Y := FIELD_HEIGHT
const AURA_RADIUS := 80.0
const VIGOR_RECOVERY_PER_SECOND := 30.0
const SKILL_COOLDOWN_RECOVERY_SPEED_BONUS := 0.80
const GLIDE_RECOVERY_SPEED_MULTIPLIER := 1.80
const IDLE_EMBER_INTERVAL_FRAMES := 8.0
const MAX_EMBER_PARTICLES := 28
const SKILL_COOLDOWN_STATE_KEYS := [
	"smasher_skill_state",
	"viper_skill_state",
	"commando_skill_state",
	"blacksmith_skill_state",
	"dalji_vision_chosik_state",
	"cheongringwi_vision_chosik_state",
	"yeonmyo_vision_chosik_state",
]


func build_spawn_campfire(owner: Object, registry: Object = null) -> Dictionary:
	var player_center: Vector2 = _read_player_center(owner)
	var player_rect: Rect2 = _read_player_rect(owner)
	var x: float = clampf(
		player_center.x - CAMPFIRE_SIZE.x * 0.5,
		0.0,
		FIELD_WIDTH - CAMPFIRE_SIZE.x
	)
	var y: float = CAMPFIRE_BOTTOM_Y - CAMPFIRE_SIZE.y
	return {
		"rect": Rect2(Vector2(x, y), CAMPFIRE_SIZE),
		"phase": randf_range(0.0, TAU),
		"ember_accumulator_frames": 0.0,
		"spawn_timer_frames": 18.0,
		"aura_active": true,
		"previous_player_rect": player_rect,
		"previous_dash_active": _read_dash_active(registry),
	}


func spawn_install_particles(particles: Array[Dictionary], campfire_rect: Rect2) -> void:
	_spawn_ember_burst(particles, campfire_rect.get_center(), 10, 1.0)


func update(
	campfires: Array[Dictionary],
	particles: Array[Dictionary],
	owner: Object,
	registry: Object,
	delta: float,
	vigor_accumulator: float,
	cooldown_bonus_msec_carry: float
) -> Dictionary:
	var safe_delta: float = maxf(0.0, delta)
	var fps_scale: float = safe_delta * 60.0
	var player_rect: Rect2 = _read_player_rect(owner)
	var player_center: Vector2 = player_rect.get_center()
	var dash_active: bool = _read_dash_active(registry)
	var player_in_range := false
	var dash_destroyed_count := 0

	for index in range(campfires.size() - 1, -1, -1):
		var campfire: Dictionary = campfires[index]
		var rect: Rect2 = _get_rect2(campfire, "rect")
		var previous_player_rect: Rect2 = _get_rect2(campfire, "previous_player_rect")
		if previous_player_rect.size.x <= 0.0 or previous_player_rect.size.y <= 0.0:
			previous_player_rect = player_rect
		var previous_dash_active: bool = bool(campfire.get("previous_dash_active", false))
		# A dash can end during the player-control update immediately before this
		# item update. Keep the prior active bit so that final movement segment is
		# still treated as dash motion instead of tunnelling through the campfire.
		if (
			(dash_active or previous_dash_active)
			and dash_sweep_intersects_campfire(previous_player_rect, player_rect, rect)
		):
			var impact_pos := Vector2(
				clampf(player_center.x, rect.position.x, rect.end.x),
				rect.get_center().y
			)
			_destroy_at(campfires, particles, index, impact_pos)
			dash_destroyed_count += 1
			continue
		campfire["previous_player_rect"] = player_rect
		campfire["previous_dash_active"] = dash_active
		var aura_active: bool = player_center.distance_to(rect.get_center()) <= AURA_RADIUS
		campfire["aura_active"] = aura_active
		player_in_range = player_in_range or aura_active
		campfire["phase"] = fmod(float(campfire.get("phase", 0.0)) + safe_delta * 5.4, TAU)
		campfire["spawn_timer_frames"] = maxf(0.0, float(campfire.get("spawn_timer_frames", 0.0)) - fps_scale)
		var ember_accumulator: float = float(campfire.get("ember_accumulator_frames", 0.0)) + fps_scale
		while ember_accumulator >= IDLE_EMBER_INTERVAL_FRAMES:
			ember_accumulator -= IDLE_EMBER_INTERVAL_FRAMES
			_spawn_idle_ember(particles, rect)
		campfire["ember_accumulator_frames"] = ember_accumulator

	_update_particles(particles, safe_delta)
	if not player_in_range:
		return {
			"player_in_range": false,
			"vigor_accumulator": 0.0,
			"cooldown_bonus_msec_carry": 0.0,
			"vigor_points_applied": 0,
			"cooldown_bonus_msec_applied": 0,
			"dash_destroyed_count": dash_destroyed_count,
		}

	var next_vigor_accumulator: float = vigor_accumulator + VIGOR_RECOVERY_PER_SECOND * safe_delta
	var vigor_points: int = int(floor(next_vigor_accumulator + 0.000001))
	if vigor_points > 0:
		next_vigor_accumulator -= float(vigor_points)
	var applied_vigor: int = _apply_integer_vigor(owner, vigor_points)
	if applied_vigor < vigor_points:
		# Do not bank recovery while already capped; leaving the aura must not
		# create an instant burst after vigor is spent later.
		next_vigor_accumulator = 0.0

	var next_cooldown_carry: float = (
		cooldown_bonus_msec_carry
		+ safe_delta * 1000.0 * SKILL_COOLDOWN_RECOVERY_SPEED_BONUS
	)
	var cooldown_bonus_msec: int = int(floor(next_cooldown_carry + 0.000001))
	if cooldown_bonus_msec > 0:
		next_cooldown_carry -= float(cooldown_bonus_msec)
		_advance_skill_cooldowns(registry, cooldown_bonus_msec)

	return {
		"player_in_range": true,
		"vigor_accumulator": next_vigor_accumulator,
		"cooldown_bonus_msec_carry": next_cooldown_carry,
		"vigor_points_applied": applied_vigor,
		"cooldown_bonus_msec_applied": cooldown_bonus_msec,
		"dash_destroyed_count": dash_destroyed_count,
	}


func destroy_on_ball_hit(
	campfires: Array[Dictionary],
	particles: Array[Dictionary],
	campfire_index: int,
	impact_pos: Vector2
) -> Dictionary:
	if campfire_index < 0 or campfire_index >= campfires.size():
		return {"destroyed": false}
	return _destroy_at(campfires, particles, campfire_index, impact_pos)


static func dash_sweep_intersects_campfire(
	previous_player_rect: Rect2,
	current_player_rect: Rect2,
	campfire_rect: Rect2
) -> bool:
	if previous_player_rect.intersects(campfire_rect) or current_player_rect.intersects(campfire_rect):
		return true
	var half_player_size := Vector2(
		maxf(previous_player_rect.size.x, current_player_rect.size.x) * 0.5,
		maxf(previous_player_rect.size.y, current_player_rect.size.y) * 0.5
	)
	var expanded_campfire: Rect2 = campfire_rect.grow_individual(
		half_player_size.x,
		half_player_size.y,
		half_player_size.x,
		half_player_size.y
	)
	return _segment_intersects_rect(
		previous_player_rect.get_center(),
		current_player_rect.get_center(),
		expanded_campfire
	)


static func _segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from_pos) or rect.has_point(to_pos):
		return true
	var top_left: Vector2 = rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right: Vector2 = rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(from_pos, to_pos, top_left, top_right) != null
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, top_right, bottom_right) != null
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, bottom_right, bottom_left) != null
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, bottom_left, top_left) != null
	)


func _destroy_at(
	campfires: Array[Dictionary],
	particles: Array[Dictionary],
	campfire_index: int,
	impact_pos: Vector2
) -> Dictionary:
	var campfire: Dictionary = campfires[campfire_index]
	var rect: Rect2 = _get_rect2(campfire, "rect")
	campfires.remove_at(campfire_index)
	var burst_origin: Vector2 = impact_pos if impact_pos != Vector2.ZERO else rect.get_center()
	_spawn_ember_burst(particles, burst_origin, 16, 1.5)
	return {
		"destroyed": true,
		"rect": rect,
		"impact_pos": burst_origin,
	}


func get_dash_cooldown_multiplier(player_in_range: bool) -> float:
	if not player_in_range:
		return 1.0
	return 1.0 / GLIDE_RECOVERY_SPEED_MULTIPLIER


func build_collision_context(campfires: Array[Dictionary]) -> Dictionary:
	return {"campfires": campfires}


func build_draw_context(
	campfires: Array[Dictionary],
	particles: Array[Dictionary],
	player_in_range: bool
) -> Dictionary:
	if campfires.is_empty() and particles.is_empty():
		return {}
	return {
		"campfires": campfires,
		"particles": particles,
		"aura_radius": AURA_RADIUS,
		"player_in_range": player_in_range,
	}


func _apply_integer_vigor(owner: Object, requested_points: int) -> int:
	if owner == null or requested_points <= 0:
		return 0
	var current_gauge: float = maxf(0.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0)))
	var gauge_max: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", 500.0)))
	var whole_current: int = int(floor(current_gauge + 0.000001))
	var whole_max: int = int(floor(gauge_max + 0.000001))
	var next_gauge: int = mini(whole_max, whole_current + requested_points)
	owner.set("special_gauge", float(next_gauge))
	return maxi(0, next_gauge - whole_current)


func _advance_skill_cooldowns(registry: Object, bonus_msec: int) -> void:
	if bonus_msec <= 0:
		return
	var current_msec: int = Time.get_ticks_msec()
	for state_key in SKILL_COOLDOWN_STATE_KEYS:
		var skill_state: Object = _get_instance(registry, str(state_key))
		if skill_state != null and skill_state.has_method("advance_cooldowns_by_msec"):
			skill_state.advance_cooldowns_by_msec(bonus_msec, current_msec)


func _read_player_center(owner: Object) -> Vector2:
	return _read_player_rect(owner).get_center()


func _read_player_rect(owner: Object) -> Rect2:
	var fallback_pos := Vector2(
		FIELD_WIDTH * 0.5 - PLAYER_BASE_PADDLE_WIDTH * 0.5,
		FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT
	)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", fallback_pos)
	var paddle_width: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(
		owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH
	)))
	var paddle_height: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(
		owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT
	)))
	return Rect2(player_pos, Vector2(paddle_width, paddle_height))


func _read_dash_active(registry: Object) -> bool:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state == null:
		return false
	if dash_state.has_method("is_active"):
		return bool(dash_state.is_active())
	if dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return bool((snapshot as Dictionary).get("active", false))
	return false


func _spawn_idle_ember(particles: Array[Dictionary], campfire_rect: Rect2) -> void:
	if particles.size() >= MAX_EMBER_PARTICLES:
		return
	var origin := Vector2(
		campfire_rect.get_center().x + randf_range(-10.0, 10.0),
		campfire_rect.position.y + campfire_rect.size.y * 0.33
	)
	particles.append({
		"position": origin,
		"velocity": Vector2(randf_range(-6.0, 6.0), randf_range(-34.0, -22.0)),
		"life": randf_range(0.42, 0.72),
		"initial_life": 0.72,
		"size": randf_range(1.3, 2.4),
		"color": Color(1.0, randf_range(0.38, 0.72), 0.08, 1.0),
	})


func _spawn_ember_burst(
	particles: Array[Dictionary],
	origin: Vector2,
	count: int,
	speed_scale: float
) -> void:
	for _index in range(count):
		if particles.size() >= MAX_EMBER_PARTICLES:
			break
		var angle: float = randf_range(PI * 1.08, PI * 1.92)
		var speed: float = randf_range(24.0, 58.0) * speed_scale
		particles.append({
			"position": origin + Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 3.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.38, 0.78),
			"initial_life": 0.78,
			"size": randf_range(1.7, 3.2),
			"color": Color(1.0, randf_range(0.28, 0.70), 0.04, 1.0),
		})


func _update_particles(particles: Array[Dictionary], delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		var remaining: float = float(particle.get("life", 0.0)) - delta
		if remaining <= 0.0:
			particles.remove_at(index)
			continue
		particle["life"] = remaining
		var velocity: Vector2 = _get_vector2(particle, "velocity")
		velocity += Vector2(0.0, -5.0) * delta
		particle["velocity"] = velocity
		particle["position"] = _get_vector2(particle, "position") + velocity * delta


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_rect2(source: Dictionary, key: String) -> Rect2:
	var value: Variant = source.get(key, Rect2())
	return value if value is Rect2 else Rect2()


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO
