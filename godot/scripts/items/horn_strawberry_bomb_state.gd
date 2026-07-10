extends RefCounted

const GAUGE_COST := 400.0
const COOLDOWN_SEC := 30.0
const HOLD_SEC := 0.5
const BOMB_COUNT := 30
const THROW_DURATION_SEC := 1.0
const THROW_INTERVAL_SEC := THROW_DURATION_SEC / float(BOMB_COUNT)
const HOP_INTERVAL_SEC := 0.38
const BASE_SPEED := 3.2
const HOP_HEIGHT := 55.0
const BOMB_SIZE := 12.0
const BOMB_LIFE_SEC := 4.0
const STUN_SEC := 1.0
const STUN_FRAMES := STUN_SEC * 60.0
const KNOCKBACK := 50.0
const KNOCKBACK_FRAMES := 36.0
const KNOCKBACK_DECAY := 0.85
const PAINT_DURATION_SEC := 5.0
const PAINT_SLOW_AMOUNT := 0.30
const PAINT_SLOW_MULTIPLIER := 1.0 - PAINT_SLOW_AMOUNT
const PAINT_RADIUS := 28.0
const EXPLOSION_DURATION_SEC := 0.5
const SUPPRESS_WINDOW_FRAMES := 4.0
# Python bomb-hit shake: screen_shake_timer=max(,8) frames, intensity=max(,12) px. Converted
# with the grenade/dynamite precedent (Python 40f/35 -> Godot amount 40/30, intensity 9.0).
const BOSS_HIT_SHAKE_AMOUNT := 8.0 / 30.0
const BOSS_HIT_SHAKE_INTENSITY := 12.0 * 9.0 / 35.0
const SOURCE := "horn_strawberry_bomb"
const PAINT_SOURCE := "horn_strawberry_bomb_paint"

var holding := false
var hold_timer_sec := 0.0
var throwing := false
var throw_timer_sec := 0.0
var throw_accumulator_sec := 0.0
var thrown_count := 0
var cooldown_sec := 0.0
var anchor_center_x := 380.0
var bombs: Array[Dictionary] = []
var explosions: Array[Dictionary] = []
var paint_splatters: Array[Dictionary] = []
var last_explosion_count := 0
var last_boss_hit_count := 0
var suppress_paddle_hit_knockback_frames := 0.0
var suppress_boss_vel := 0.0
var _next_bomb_id := 1


func reset() -> void:
	holding = false
	hold_timer_sec = 0.0
	throwing = false
	throw_timer_sec = 0.0
	throw_accumulator_sec = 0.0
	thrown_count = 0
	cooldown_sec = 0.0
	anchor_center_x = 380.0
	bombs.clear()
	explosions.clear()
	paint_splatters.clear()
	last_explosion_count = 0
	last_boss_hit_count = 0
	suppress_paddle_hit_knockback_frames = 0.0
	suppress_boss_vel = 0.0


func cancel_throwing_preserve_lingering() -> void:
	holding = false
	hold_timer_sec = 0.0
	throwing = false
	throw_timer_sec = 0.0
	throw_accumulator_sec = 0.0
	thrown_count = 0


func can_use(current_gauge: float) -> bool:
	return not throwing and cooldown_sec <= 0.0 and current_gauge + 0.001 >= GAUGE_COST


func update_input(input_snapshot: Dictionary, delta: float, owner: Object, runtime: Object, blocked: bool = false, registry: Object = null) -> bool:
	var both_pressed: bool = bool(input_snapshot.get("left_pressed", false)) and bool(input_snapshot.get("right_pressed", false))
	if blocked or not both_pressed:
		holding = false
		hold_timer_sec = 0.0
		return false
	if not holding:
		holding = true
		hold_timer_sec = 0.0
	hold_timer_sec += max(0.0, delta)
	if hold_timer_sec + 0.001 < HOLD_SEC:
		return false
	var current_gauge: float = _get_owner_gauge(runtime, owner)
	if not can_use(current_gauge):
		return false
	if owner != null:
		owner.set("special_gauge", max(0.0, current_gauge - GAUGE_COST))
	_start_throw(owner)
	_play_audio(runtime, registry, "_play_horn_strawberry_bomb_throw_audio")
	return true


func update(delta: float, owner: Object, registry: Object, transformed: bool, runtime: Object = null) -> void:
	var safe_delta: float = max(0.0, delta)
	if transformed:
		cooldown_sec = max(0.0, cooldown_sec - safe_delta)
	if suppress_paddle_hit_knockback_frames > 0.0:
		suppress_paddle_hit_knockback_frames = max(0.0, suppress_paddle_hit_knockback_frames - safe_delta * 60.0)
	if throwing:
		_update_throwing(safe_delta, owner)
	_update_bombs(safe_delta, owner, registry, runtime)
	_update_explosions(safe_delta)
	_update_paint_splatters(safe_delta, owner, registry)


func consume_boss_hit_suppression(_ball_pos: Vector2, _ball_vel: Vector2, _context: Dictionary, _deps: Dictionary = {}) -> Dictionary:
	if suppress_paddle_hit_knockback_frames <= 0.0 or abs(suppress_boss_vel) <= 0.001:
		return {}
	suppress_paddle_hit_knockback_frames = 0.0
	return {
		"boss_vel": suppress_boss_vel,
		"horn_strawberry_bomb_hit": true,
		"horn_strawberry_bomb_consumed": true,
		"suppress_paddle_hit_knockback": true,
	}


func has_runtime_update_work() -> bool:
	return (
		holding
		or throwing
		or cooldown_sec > 0.0
		or suppress_paddle_hit_knockback_frames > 0.0
		or not bombs.is_empty()
		or not explosions.is_empty()
		or not paint_splatters.is_empty()
	)


func has_visible_effects() -> bool:
	return throwing or not bombs.is_empty() or not explosions.is_empty() or not paint_splatters.is_empty()


func get_context() -> Dictionary:
	return {
		"holding": holding,
		"hold_timer_sec": hold_timer_sec,
		"hold_sec": HOLD_SEC,
		"throwing": throwing,
		"throw_timer_sec": throw_timer_sec,
		"throw_duration_sec": THROW_DURATION_SEC,
		"thrown_count": thrown_count,
		"bomb_count": BOMB_COUNT,
		"cooldown_sec": cooldown_sec,
		"cooldown_max_sec": COOLDOWN_SEC,
		"gauge_cost": GAUGE_COST,
		"bombs": bombs.duplicate(true),
		"bomb_count_active": bombs.size(),
		"explosions": explosions.duplicate(true),
		"explosion_count": explosions.size(),
		"paint_splatters": paint_splatters.duplicate(true),
		"paint_count": paint_splatters.size(),
		"paint_duration_sec": PAINT_DURATION_SEC,
		"paint_slow_multiplier": PAINT_SLOW_MULTIPLIER,
		"paint_radius": PAINT_RADIUS,
		"last_explosion_count": last_explosion_count,
		"last_boss_hit_count": last_boss_hit_count,
		"suppress_paddle_hit_knockback_frames": suppress_paddle_hit_knockback_frames,
	}


func _start_throw(owner: Object) -> void:
	holding = false
	hold_timer_sec = 0.0
	throwing = true
	throw_timer_sec = THROW_DURATION_SEC
	throw_accumulator_sec = THROW_INTERVAL_SEC
	thrown_count = 0
	cooldown_sec = COOLDOWN_SEC
	anchor_center_x = _get_player_center(owner).x


func _update_throwing(delta: float, owner: Object) -> void:
	throw_timer_sec = max(0.0, throw_timer_sec - delta)
	throw_accumulator_sec += delta
	while thrown_count < BOMB_COUNT and throw_accumulator_sec + 0.0001 >= THROW_INTERVAL_SEC:
		_spawn_bomb(owner)
		throw_accumulator_sec -= THROW_INTERVAL_SEC
	if throw_timer_sec <= 0.0 or thrown_count >= BOMB_COUNT:
		throwing = false
		throw_timer_sec = 0.0
		throw_accumulator_sec = 0.0


func _spawn_bomb(owner: Object) -> void:
	var player_center: Vector2 = _get_player_center(owner)
	var denominator: float = max(1.0, float(BOMB_COUNT - 1))
	var progress: float = float(thrown_count) / denominator
	var sweep: float = progress * 2.0 - 1.0
	var wobble: float = sin(float(_next_bomb_id) * 1.73)
	var spawn_pos := Vector2(
		clamp(anchor_center_x + sweep * 58.0 + wobble * 7.0, BOMB_SIZE, 760.0 - BOMB_SIZE),
		player_center.y - 32.0
	)
	var velocity := Vector2(
		sweep * 3.9 + wobble * 0.9,
		-(BASE_SPEED + abs(sweep) * 0.75 + float(thrown_count % 5) * 0.08)
	)
	var first_hop_delay: float = 0.05 + _pseudo_unit(_next_bomb_id, 5.1) * (HOP_INTERVAL_SEC * 0.5 - 0.05)
	bombs.append({
		"id": _next_bomb_id,
		"position": spawn_pos,
		"base_position": spawn_pos,
		"visual_position": spawn_pos,
		"velocity": velocity,
		"age_sec": 0.0,
		"life_sec": BOMB_LIFE_SEC,
		"size": BOMB_SIZE,
		"rotation": wobble,
		"rot_speed": 0.18 + abs(sweep) * 0.08,
		"hop_timer_sec": first_hop_delay,
		"hop_phase_sec": 0.0,
		"hop_interval_sec": HOP_INTERVAL_SEC,
		"hop_height": HOP_HEIGHT,
	})
	_next_bomb_id += 1
	thrown_count += 1


func _update_bombs(delta: float, owner: Object, registry: Object, runtime: Object) -> void:
	if bombs.is_empty():
		return
	var boss_rect: Rect2 = _get_boss_rect(owner)
	var survivors: Array[Dictionary] = []
	for bomb in bombs:
		var next_bomb: Dictionary = bomb.duplicate(true)
		var base_position: Vector2 = _as_vector2(next_bomb.get("base_position", next_bomb.get("position", Vector2.ZERO)), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(next_bomb.get("velocity", Vector2.ZERO), Vector2.ZERO)
		var step: float = delta * 60.0
		var age_sec: float = float(next_bomb.get("age_sec", 0.0)) + delta
		var hop_timer_sec: float = float(next_bomb.get("hop_timer_sec", HOP_INTERVAL_SEC)) - delta
		var hop_phase_sec: float = float(next_bomb.get("hop_phase_sec", 0.0)) + delta
		if hop_timer_sec <= 0.0:
			var bomb_id: int = int(next_bomb.get("id", 0))
			hop_timer_sec += HOP_INTERVAL_SEC
			velocity.x += -2.0 + _pseudo_unit(bomb_id, age_sec * 8.0 + 1.7) * 4.0
			velocity.x = clamp(velocity.x, -5.8, 5.8)
			velocity.y = -(BASE_SPEED + _pseudo_unit(bomb_id, age_sec * 5.0 + 3.3) * 2.0)
			hop_phase_sec = 0.0
		base_position += velocity * step
		if base_position.x <= BOMB_SIZE or base_position.x >= 760.0 - BOMB_SIZE:
			velocity.x *= -0.90
			base_position.x = clamp(base_position.x, BOMB_SIZE, 760.0 - BOMB_SIZE)
		var hop_t: float = clamp(hop_phase_sec / HOP_INTERVAL_SEC, 0.0, 1.0)
		var visual_position: Vector2 = base_position + Vector2(0.0, -HOP_HEIGHT * sin(hop_t * PI))
		next_bomb["position"] = visual_position
		next_bomb["visual_position"] = visual_position
		next_bomb["base_position"] = base_position
		next_bomb["velocity"] = velocity
		next_bomb["age_sec"] = age_sec
		next_bomb["life_sec"] = max(0.0, float(next_bomb.get("life_sec", BOMB_LIFE_SEC)) - delta)
		next_bomb["hop_timer_sec"] = hop_timer_sec
		next_bomb["hop_phase_sec"] = hop_phase_sec
		next_bomb["rotation"] = float(next_bomb.get("rotation", 0.0)) + float(next_bomb.get("rot_speed", 0.0)) * step
		var hit_boss: bool = _bomb_hits_boss(base_position, boss_rect)
		var top_expired: bool = boss_rect.size.x > 0.0 and base_position.y <= boss_rect.position.y + boss_rect.size.y + 40.0
		var expired: bool = hit_boss or top_expired or float(next_bomb.get("life_sec", 0.0)) <= 0.0
		if expired:
			_create_explosion(base_position, hit_boss, boss_rect, registry, runtime)
		else:
			survivors.append(next_bomb)
	bombs = survivors


func _update_explosions(delta: float) -> void:
	if explosions.is_empty():
		return
	var alive: Array[Dictionary] = []
	for explosion in explosions:
		var next_explosion: Dictionary = explosion.duplicate(true)
		next_explosion["timer_sec"] = max(0.0, float(next_explosion.get("timer_sec", 0.0)) - delta)
		if float(next_explosion.get("timer_sec", 0.0)) > 0.0:
			alive.append(next_explosion)
	explosions = alive


func _update_paint_splatters(delta: float, owner: Object, registry: Object) -> void:
	if paint_splatters.is_empty():
		return
	var boss_rect: Rect2 = _get_boss_rect(owner)
	var alive: Array[Dictionary] = []
	var boss_in_paint := false
	for splatter in paint_splatters:
		var next_splatter: Dictionary = splatter.duplicate(true)
		next_splatter["timer_sec"] = max(0.0, float(next_splatter.get("timer_sec", 0.0)) - delta)
		if float(next_splatter.get("timer_sec", 0.0)) <= 0.0:
			continue
		if _circle_rect_overlap(
			_as_vector2(next_splatter.get("position", Vector2.ZERO), Vector2.ZERO),
			float(next_splatter.get("radius", PAINT_RADIUS)),
			boss_rect
		):
			boss_in_paint = true
		alive.append(next_splatter)
	paint_splatters = alive
	if boss_in_paint:
		_apply_boss_paint_slow(registry)


func _create_explosion(position: Vector2, hit_boss: bool, boss_rect: Rect2, registry: Object, _runtime: Object) -> void:
	explosions.append({
		"position": position,
		"timer_sec": EXPLOSION_DURATION_SEC,
		"duration_sec": EXPLOSION_DURATION_SEC,
		"hit_boss": hit_boss,
	})
	var radius_variation: float = 4.0 * sin(float(last_explosion_count + 1) * 1.37)
	paint_splatters.append({
		"position": position,
		"radius": max(8.0, PAINT_RADIUS + radius_variation),
		"timer_sec": PAINT_DURATION_SEC,
		"duration_sec": PAINT_DURATION_SEC,
		"blob_count": 4 + int(abs(sin(float(last_explosion_count + 2))) * 3.0),
	})
	last_explosion_count += 1
	if hit_boss:
		_apply_boss_hit(position, boss_rect, registry)


func _apply_boss_hit(position: Vector2, boss_rect: Rect2, registry: Object) -> void:
	last_boss_hit_count += 1
	var boss_center_x: float = boss_rect.position.x + boss_rect.size.x * 0.5
	var direction: float = 1.0 if position.x < boss_center_x else -1.0
	var knockback_vel: float = direction * KNOCKBACK
	_clear_ai_paddle_hit_knockback(registry)
	var status_state: Object = _get_instance(registry, "status_effect_state")
	var applied_status := false
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"boss",
			"stun",
			STUN_FRAMES,
			{
				"knockback_vel": knockback_vel,
				"knockback_active": abs(knockback_vel) > 0.001,
				"knockback_frames": KNOCKBACK_FRAMES,
				"knockback_decay_per_frame": KNOCKBACK_DECAY,
				"knockback_stop_threshold": 0.3,
				"suppress_paddle_hit_knockback": true,
				"suppress_stun_stars": false,
			},
			SOURCE
		)
		applied_status = true
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if not applied_status and ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, KNOCKBACK_FRAMES, KNOCKBACK_DECAY, true)
	suppress_paddle_hit_knockback_frames = SUPPRESS_WINDOW_FRAMES
	suppress_boss_vel = knockback_vel
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(BOSS_HIT_SHAKE_AMOUNT, BOSS_HIT_SHAKE_INTENSITY)


func _apply_boss_paint_slow(registry: Object) -> void:
	var status_state: Object = _get_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"slow",
		4.0,
		{
			"multiplier": PAINT_SLOW_MULTIPLIER,
			"cleansable": true,
			"visual": "horn_strawberry_bomb_paint",
		},
		PAINT_SOURCE
	)


func _bomb_hits_boss(position: Vector2, boss_rect: Rect2) -> bool:
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return false
	var bomb_rect := Rect2(position - Vector2(BOMB_SIZE * 0.5, BOMB_SIZE * 0.5), Vector2(BOMB_SIZE, BOMB_SIZE))
	return bomb_rect.intersects(boss_rect)


func _get_owner_gauge(runtime: Object, owner: Object) -> float:
	if runtime == null:
		return 0.0
	return max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))


func _get_player_center(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(380.0, 700.0)
	var pos: Vector2 = _as_vector2(owner.get("player_pos"), Vector2(300.0, 700.0))
	var width: float = _get_owner_float(owner, "player_paddle_width", 155.0)
	var height: float = _get_owner_float(owner, "player_paddle_height", 50.0)
	return pos + Vector2(width * 0.5, height * 0.5)


func _get_boss_rect(owner: Object) -> Rect2:
	if owner == null:
		return Rect2(Vector2(330.0, 35.0), Vector2(100.0, 40.0))
	var pos: Vector2 = _as_vector2(owner.get("boss_pos"), Vector2(330.0, 35.0))
	var width: float = _get_owner_float(owner, "boss_paddle_width", 100.0)
	var height: float = _get_owner_float(owner, "boss_hitbox_height", 40.0)
	return Rect2(pos, Vector2(max(1.0, width), max(1.0, height)))


func _circle_rect_overlap(center: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var closest := Vector2(
		clamp(center.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


func _clear_ai_paddle_hit_knockback(registry: Object) -> void:
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("clear_paddle_hit_knockback"):
		ai_state.clear_paddle_hit_knockback()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _play_audio(runtime: Object, registry: Object, method_name: String) -> void:
	if runtime == null:
		return
	var audio_router: Object = runtime.get("audio_router")
	if audio_router != null and audio_router.has_method("play_named"):
		audio_router.play_named(runtime, registry, method_name)


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return float(value)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _pseudo_unit(id: int, salt: float) -> float:
	return abs(sin(float(id) * 12.9898 + salt * 78.233))
